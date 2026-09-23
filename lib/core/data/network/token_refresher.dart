import 'package:dio/dio.dart';
import 'package:my_app/core/data/network/auth_extra_keys.dart';
import 'package:my_app/core/data/network/token_store.dart';
import 'package:my_app/core/logging/logging.dart';
import 'package:my_app/core/models/token_set.dart';

/// 用刷新令牌换取新的访问令牌。
///
/// single-flight：并发调用共享同一个 Future，只发一次真实请求。
/// 为什么必须如此见 backend/error-handling.md。
///
/// 依赖 [TokenStore] 而非具体存储实现，理由见 auth_interceptor.dart。
class TokenRefresher {
  new(this._storage, this._dio);

  /// 刷新接口路径（相对 baseUrl）
  static const String path = '/refresh';

  final TokenStore _storage;
  final Dio _dio;

  Future<String?>? _inFlight;

  /// 返回新的访问令牌；没有刷新令牌或刷新失败时返回 null
  Future<String?> refresh() {
    return _inFlight ??= _refresh().whenComplete(() => _inFlight = null);
  }

  Future<String?> _refresh() async {
    final refreshToken = _storage.getRefreshToken();
    if (refreshToken == null || refreshToken.isEmpty) {
      Logging.info('没有可用的刷新令牌，跳过刷新');
      return null;
    }

    try {
      // 直接调 dio 而非 Retrofit：要显式带上 kSkipAuthRefresh 标记，
      // 否则刷新接口返回 401 会再次触发刷新、无限递归
      final response = await _dio.post<Map<String, dynamic>>(
        path,
        data: {'refreshToken': refreshToken},
        options: Options(extra: const {kSkipAuthRefresh: true}),
      );

      final data = response.data;
      if (data == null) {
        Logging.warning('刷新接口返回空响应');
        return null;
      }

      final tokens = TokenSet.fromApi(data);
      await _storage.saveTokens(tokens);
      Logging.info('访问令牌已刷新');
      return tokens.accessToken;
    } catch (e) {
      // 刷新失败一律按会话失效处理，由调用方决定清凭证
      Logging.warning('刷新令牌失败: $e');
      return null;
    }
  }
}
