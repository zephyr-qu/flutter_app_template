import 'package:my_app/core/data/network/token_store.dart';
import 'package:my_app/core/models/token_set.dart';

/// 内存版 [TokenStore]：网络层测试不依赖 `AuthStorage`。
///
/// 不用 mocktail：这里只关心「读写令牌 + 被调用了几次」，
/// 手写比 mock 更直白，还能表达 mock 不方便表达的状态（[ready] 尚未完成、
/// [clearAuth] 失败）。
class FakeTokenStore implements TokenStore {
  new({this.clearAuthError});

  /// 设置后 [clearAuth] 会抛出它（模拟安全存储不可用）
  final Exception? clearAuthError;

  TokenSet? _tokens;

  /// [clearAuth] 被调用的次数
  int clearAuthCount = 0;

  /// [saveTokens] 被调用的次数
  int saveTokensCount = 0;

  /// 令牌「载入完成」信号。默认已完成；测试可换成未完成的 Future
  /// 来验证拦截器确实会等它（冷启动后的首个请求漏带令牌的成因）。
  @override
  Future<void> ready = Future<void>.value();

  @override
  String? getAccessToken() => _tokens?.accessToken;

  @override
  String? getRefreshToken() => _tokens?.refreshToken;

  @override
  bool isAccessTokenExpiring({Duration skew = defaultTokenExpirySkew}) {
    final expiresAt = _tokens?.expiresAt;
    if (expiresAt == null) return false;
    return !DateTime.now().add(skew).isBefore(expiresAt);
  }

  @override
  Future<void> saveTokens(TokenSet tokens) async {
    saveTokensCount++;
    _tokens = tokens;
  }

  @override
  Future<void> clearAuth() async {
    clearAuthCount++;
    _tokens = null;
    final error = clearAuthError;
    if (error != null) throw error;
  }
}
