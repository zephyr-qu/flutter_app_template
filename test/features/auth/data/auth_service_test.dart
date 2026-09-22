import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:my_app/core/base/failure.dart';
import 'package:my_app/core/data/storage/auth_storage.dart';
import 'package:my_app/core/models/token_set.dart';
import 'package:my_app/core/models/user.dart';
import 'package:my_app/features/auth/data/auth_api.dart';
import 'package:my_app/features/auth/data/auth_service.dart';
import 'package:my_app/features/auth/data/models/login_request.dart';
import 'package:my_app/features/auth/data/models/login_response.dart';

class MockAuthApi extends Mock implements AuthApi;

class MockAuthStorage extends Mock implements AuthStorage;

void main() {
  late MockAuthApi api;
  late MockAuthStorage storage;
  late AuthService service;

  setUpAll(() {
    registerFallbackValue(const LoginRequest(email: '', password: ''));
    registerFallbackValue(const User(id: 0, name: ''));
    registerFallbackValue(const TokenSet(accessToken: ''));
  });

  setUp(() {
    api = MockAuthApi();
    storage = MockAuthStorage();
    service = AuthService(api, storage);

    when(() => storage.saveTokens(any())).thenAnswer((_) async {});
    when(() => storage.saveUser(any())).thenAnswer((_) async {});
    when(() => storage.clearAuth()).thenAnswer((_) async {});
  });

  group('AuthService.login', () {
    test('凭证通过请求体传递，而不是 URL query', () async {
      when(() => api.login(any())).thenAnswer(
        (_) async => const LoginResponse(
          user: User(id: 1, name: '开发者'),
          accessToken: 'tok',
        ),
      );

      await service.login('user@example.com', 'password123');

      verify(
        () => api.login(
          const LoginRequest(
            email: 'user@example.com',
            password: 'password123',
          ),
        ),
      ).called(1);
    });

    test('成功后先保存令牌再保存用户，过期时间一并落盘', () async {
      when(() => api.login(any())).thenAnswer(
        (_) async => const LoginResponse(
          user: User(id: 1, name: '开发者'),
          accessToken: 'tok-abc',
          refreshToken: 'refresh-abc',
          expiresIn: 3600,
        ),
      );

      final result = await service.login('user@example.com', 'password123');

      expect(result.isSuccess, isTrue);
      // 顺序很关键：登录态由用户信号推导，若先存用户会有一个
      // 「已登录但没有令牌」的窗口，首个请求会漏带 Authorization
      final verified = verifyInOrder([
        () => storage.saveTokens(captureAny()),
        () => storage.saveUser(const User(id: 1, name: '开发者')),
      ]);

      final saved = verified.first.captured.single as TokenSet;
      expect(saved.accessToken, 'tok-abc');
      expect(saved.refreshToken, 'refresh-abc');
      // expiresIn 已换算成绝对过期时刻，不再是相对秒数
      expect(saved.expiresAt, isNotNull);
    });

    test('接口失败时不保存令牌 / 用户', () async {
      when(
        () => api.login(any()),
      ).thenThrow(DioException(requestOptions: RequestOptions(path: '/login')));

      final result = await service.login('user@example.com', 'password123');

      expect(result.isFailure, isTrue);
      verifyNever(() => storage.saveTokens(any()));
      verifyNever(() => storage.saveUser(any()));
    });

    test('401 映射为认证失败', () async {
      final requestOptions = RequestOptions(path: '/login');
      when(() => api.login(any())).thenThrow(
        DioException(
          requestOptions: requestOptions,
          // 真实场景里 401 来自 badResponse，type 不设置会落到 unknown 分支
          type: DioExceptionType.badResponse,
          response: Response<void>(
            requestOptions: requestOptions,
            statusCode: 401,
          ),
        ),
      );

      final result = await service.login('user@example.com', 'password123');

      expect(result.isFailure, isTrue);
      expect(
        result.when(success: (_) => '', failure: (f) => f.code),
        FailureCode.unauthorized,
      );
      verifyNever(() => storage.saveTokens(any()));
    });
  });

  group('AuthService.logout', () {
    test('成功时清除本地凭证', () async {
      when(() => api.logout()).thenAnswer((_) async {});

      final result = await service.logout();

      expect(result.isSuccess, isTrue);
      verify(() => storage.clearAuth()).called(1);
    });

    test('服务端调用失败时仍然清掉本地凭证，并返回成功', () async {
      when(() => api.logout()).thenThrow(
        DioException(
          requestOptions: RequestOptions(path: '/logout'),
          type: DioExceptionType.connectionError,
        ),
      );

      final result = await service.logout();

      // 本地登出不应该依赖网络，否则离线时 token 会一直留在设备上
      verify(() => storage.clearAuth()).called(1);
      // 对用户而言「登出」就是本地会话结束，不该报错
      expect(result.isSuccess, isTrue);
    });
  });
}
