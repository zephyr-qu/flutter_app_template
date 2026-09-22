import 'package:dio/dio.dart';
import 'package:my_app/core/data/network/auth_extra_keys.dart';
import 'package:my_app/core/data/network/token_refresher.dart';
import 'package:my_app/core/data/storage/auth_storage.dart';
import 'package:my_app/core/logging/logging.dart';

/// 认证拦截器：请求附加令牌；401 时刷新并重放原请求，刷新用尽则清凭证。
///
/// 防递归标记、为何不在这里跳转等约定见 backend/error-handling.md「401 与令牌刷新」。
class AuthInterceptor extends Interceptor {
  new(this._auth, this._refresher, this._dio);

  final AuthStorage _auth;
  final TokenRefresher _refresher;

  /// 用于重放。必须是同一个 Dio，否则重放会绕开 mock / 重试拦截器。
  final Dio _dio;

  /// 并发 401 会同时进来多个错误；用它保证 `clearAuth()` 不会重入执行。
  ///
  /// 这是 in-flight 守卫，不是「只清一次」：清理完成后到达的 401 仍会再次清理，
  /// 且复位是必需的 —— 用户重新登录后新会话失效时，必须还能清。
  bool _clearAuthInFlight = false;

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    if (options.extra[kSkipAuthRefresh] == true) {
      // 刷新请求自身不带过期令牌（部分后端会因此直接拒绝整个请求）
      handler.next(options);
      return;
    }

    // 等令牌从安全存储载入内存，避免冷启动后的首个请求漏带
    await _auth.ready;

    // 临近过期就先换，省掉一次「先 401 再刷新」的往返；失败不阻塞本次请求
    // ——带着旧令牌发出去，交给下面的 401 路径兜底
    if (_auth.isAccessTokenExpiring()) {
      await _refresher.refresh();
    }

    final token = _auth.getAccessToken();
    if (token != null && token.isNotEmpty) {
      options.headers['Authorization'] = 'Bearer $token';
    }
    handler.next(options);
  }

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    if (!_shouldRefresh(err)) {
      if (err.response?.statusCode == 401) {
        // 刷新这条路已用尽（刷新接口自己 401，或重放后仍 401）→ 会话确定失效
        await _clearAuthOnce();
      }
      handler.next(err);
      return;
    }

    final newToken = await _refresher.refresh();
    if (newToken == null) {
      await _clearAuthOnce();
      handler.next(err);
      return;
    }

    try {
      handler.resolve(await _replay(err.requestOptions, newToken));
    } on DioException catch (e) {
      if (e.response?.statusCode == 401) await _clearAuthOnce();
      handler.next(e);
    }
  }

  bool _shouldRefresh(DioException err) {
    final options = err.requestOptions;
    return err.response?.statusCode == 401 &&
        options.extra[kSkipAuthRefresh] != true &&
        options.extra[kAuthRetried] != true;
  }

  Future<Response<dynamic>> _replay(RequestOptions options, String token) {
    options
      ..headers['Authorization'] = 'Bearer $token'
      ..extra[kAuthRetried] = true;
    return _dio.fetch<dynamic>(options);
  }

  Future<void> _clearAuthOnce() async {
    if (_clearAuthInFlight) return;
    _clearAuthInFlight = true;
    try {
      await _auth.clearAuth();
    } catch (e, stackTrace) {
      // 清理失败不能外抛：一旦抛出去，调用方的 handler.next() 就不再执行，
      // dio 会把该异常 reject 给调用方（_observeInterceptorCallback），
      // 原本的 401 因此被替换成一个无意义的异常 —— 错误语义就丢了
      Logging.error('清除凭证失败', exception: e, stackTrace: stackTrace);
    } finally {
      _clearAuthInFlight = false;
    }
  }
}
