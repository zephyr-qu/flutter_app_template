import 'package:app_core/base/failure.dart';
import 'package:app_core/base/result.dart';
import 'package:app_core/models/user.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:my_app/features/auth/data/auth_repository.dart';
import 'package:my_app/features/auth/logic/auth_view_model.dart';

class MockAuthRepository extends Mock implements AuthRepository;

void main() {
  late MockAuthRepository mockRepo;
  late AuthViewModel vm;

  setUp(() {
    mockRepo = MockAuthRepository();
    vm = AuthViewModel(mockRepo);
  });

  group('AuthViewModel', () {
    test('初始状态为 data(null), 不 loading', () {
      expect(vm.user.value.value, isNull);
      expect(vm.user.value.isLoading, isFalse);
      expect(vm.user.value.hasError, isFalse);
    });

    group('login()', () {
      const testUser = User(id: 1, name: '测试用户');

      test('成功后更新 user 信号', () async {
        when(() => mockRepo.login(any(), any()))
            .thenAnswer((_) async => const Result.success(testUser));

        final result = await vm.login();

        expect(result.isSuccess, isTrue);
        expect(vm.user.value.value?.name, '测试用户');
        expect(vm.user.value.isLoading, isFalse);
        expect(vm.user.value.hasError, isFalse);
      });

      test('失败后返回 Failure 并设置 error 状态', () async {
        when(() => mockRepo.login(any(), any())).thenAnswer(
          (_) async =>
              const Result.failure(AuthFailure(code: FailureCode.unauthorized)),
        );

        final result = await vm.login();

        expect(result.isFailure, isTrue);
        expect(vm.user.value.hasError, isTrue);
        expect(vm.user.value.value, isNull);
        expect(vm.user.value.isLoading, isFalse);
      });

      test('登录中时 isLoading 为 true', () {
        when(() => mockRepo.login(any(), any())).thenAnswer((_) async {
          await Future<void>.delayed(const Duration(seconds: 1));
          return const Result.success(testUser);
        });

        final future = vm.login();

        expect(vm.user.value.isLoading, isTrue);
        expect(future, completes);
      });
    });

    group('logout()', () {
      test('成功后清空 user 信号', () async {
        // 先登录
        when(() => mockRepo.login(any(), any())).thenAnswer(
          (_) async => const Result.success(User(id: 1, name: '测试用户')),
        );
        await vm.login();

        // 登出
        when(() => mockRepo.logout())
            .thenAnswer((_) async => const Result.success(null));

        final result = await vm.logout();

        expect(result.isSuccess, isTrue);
        expect(vm.user.value.value, isNull);
        expect(vm.user.value.isLoading, isFalse);
      });

      test('失败后返回 Failure', () async {
        when(() => mockRepo.logout()).thenAnswer(
          (_) async => const Result.failure(
            ServerFailure(code: FailureCode.serverError),
          ),
        );

        final result = await vm.logout();

        expect(result.isFailure, isTrue);
        expect(vm.user.value.hasError, isTrue);
      });
    });

    group('canSubmit', () {
      test('邮箱和密码都满足条件时为 true', () {
        vm
          ..updateEmail('test@example.com')
          ..updatePassword('password123');
        expect(vm.canSubmit.value, isTrue);
      });

      test('邮箱为空时为 false', () {
        vm
          ..updateEmail('')
          ..updatePassword('password123');
        expect(vm.canSubmit.value, isFalse);
      });

      test('密码长度不足时为 false', () {
        vm
          ..updateEmail('test@example.com')
          ..updatePassword('12345');
        expect(vm.canSubmit.value, isFalse);
      });
    });

    group('resetForm()', () {
      test('清空邮箱和密码', () {
        vm
          ..updateEmail('test@example.com')
          ..updatePassword('password123')
          ..resetForm();

        expect(vm.email.value, isEmpty);
        expect(vm.password.value, isEmpty);
      });
    });
  });
}
