import 'dart:async';

import 'package:app_core/base/failure.dart';
import 'package:app_core/base/result.dart';
import 'package:app_core/models/user.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:my_app/features/auth/data/auth_providers.dart';
import 'package:my_app/features/auth/data/auth_repository.dart';
import 'package:my_app/features/auth/logic/login_notifier.dart';

class MockAuthRepository extends Mock implements AuthRepository;

void main() {
  const testUser = User(id: 1, name: '测试用户');

  late MockAuthRepository mockRepo;

  /// `loginProvider` 是 autoDispose：不发一个订阅，它在两次 read 之间就会被
  /// 释放掉，表单状态随之丢失。
  ProviderContainer createContainer() {
    final container = ProviderContainer(
      overrides: [authRepositoryProvider.overrideWithValue(mockRepo)],
    );
    addTearDown(container.dispose);
    container.listen(loginProvider, (_, _) {});
    return container;
  }

  setUp(() {
    mockRepo = MockAuthRepository();
  });

  group('LoginNotifier — 初始状态', () {
    test('空表单、未提交、不可提交', () {
      final container = createContainer();

      final state = container.read(loginProvider);
      expect(state.email, isEmpty);
      expect(state.password, isEmpty);
      expect(state.isSubmitting, isFalse);
      expect(state.canSubmit, isFalse);
    });
  });

  group('LoginNotifier — canSubmit', () {
    test('邮箱非空 + 密码至少 6 位时为 true', () {
      final container = createContainer();
      container.read(loginProvider.notifier)
        ..updateEmail('test@example.com')
        ..updatePassword('password123');

      expect(container.read(loginProvider).canSubmit, isTrue);
    });

    test('邮箱为空时为 false', () {
      final container = createContainer();
      container.read(loginProvider.notifier)
        ..updateEmail('')
        ..updatePassword('password123');

      expect(container.read(loginProvider).canSubmit, isFalse);
    });

    test('密码不足 6 位时为 false', () {
      final container = createContainer();
      container.read(loginProvider.notifier)
        ..updateEmail('test@example.com')
        ..updatePassword('12345');

      expect(container.read(loginProvider).canSubmit, isFalse);
    });
  });

  group('LoginNotifier — login()', () {
    test('成功后返回 success，并把 isSubmitting 复位', () async {
      when(() => mockRepo.login(any(), any()))
          .thenAnswer((_) async => const Result.success(testUser));
      final container = createContainer();
      final notifier = container.read(loginProvider.notifier)
        ..updateEmail('test@example.com')
        ..updatePassword('password123');

      final result = await notifier.login();

      expect(result.isSuccess, isTrue);
      expect(container.read(loginProvider).isSubmitting, isFalse);
      // 登录态不在这里写：AuthService 落盘 → AuthStorage.userChanges → Session
      verify(() => mockRepo.login('test@example.com', 'password123')).called(1);
    });

    test('失败后返回 Failure，并把 isSubmitting 复位', () async {
      when(() => mockRepo.login(any(), any())).thenAnswer(
        (_) async =>
            const Result.failure(AuthFailure(code: FailureCode.unauthorized)),
      );
      final container = createContainer();
      final notifier = container.read(loginProvider.notifier)
        ..updateEmail('test@example.com')
        ..updatePassword('password123');

      final result = await notifier.login();

      expect(result.isFailure, isTrue);
      expect(
        result.when(success: (_) => '', failure: (f) => f.code),
        FailureCode.unauthorized,
      );
      expect(container.read(loginProvider).isSubmitting, isFalse);
    });

    test('请求飞行中 isSubmitting 为 true', () async {
      final pending = Completer<Result<User, Failure>>();
      when(() => mockRepo.login(any(), any()))
          .thenAnswer((_) => pending.future);
      final container = createContainer();
      final notifier = container.read(loginProvider.notifier)
        ..updateEmail('test@example.com')
        ..updatePassword('password123');

      final future = notifier.login();
      expect(container.read(loginProvider).isSubmitting, isTrue);

      pending.complete(const Result.success(testUser));
      await future;
      expect(container.read(loginProvider).isSubmitting, isFalse);
    });
  });

  group('LoginNotifier — resetForm()', () {
    test('清空输入并回到未提交', () {
      final container = createContainer();
      container.read(loginProvider.notifier)
        ..updateEmail('test@example.com')
        ..updatePassword('password123')
        ..resetForm();

      final state = container.read(loginProvider);
      expect(state.email, isEmpty);
      expect(state.password, isEmpty);
      expect(state.isSubmitting, isFalse);
    });
  });
}
