import 'package:my_app/core/models/token_set.dart';

/// 访问令牌临近过期时提前刷新的默认提前量。
///
/// 定义在接口侧而不是实现侧：调用方经 [TokenStore] 静态类型调用时，
/// 默认值取自接口声明。
const Duration defaultTokenExpirySkew = Duration(seconds: 30);

/// 令牌存取的能力契约。
///
/// 网络层（`AuthInterceptor` / `TokenRefresher`）只需要「读写令牌」这一组能力，
/// 不需要知道令牌存在哪里、也不需要知道登录态用什么状态管理暴露；本项目的实现是
/// `lib/core/data/storage/auth_storage.dart` 的 `AuthStorage`。
///
/// 本文件**不得** import `auth_interceptor.dart` / `token_refresher.dart`（循环依赖）；
/// 提到这两个类时用反引号而非 `[...]`，否则 `dart fix` 会自动补 import。
abstract interface class TokenStore {
  /// 令牌从持久化载入内存的完成信号。
  ///
  /// 拦截器在附加 `Authorization` 前会 `await` 它：冷启动后的首个请求
  /// 若不等这次载入，会因为「内存里还没有令牌」而漏带，白白触发一次 401。
  Future<void> get ready;

  /// 当前访问令牌；未持有或尚未载入完成时为 null
  String? getAccessToken();

  /// 当前刷新令牌；未持有或尚未载入完成时为 null
  String? getRefreshToken();

  /// 是否临近过期（默认提前 [defaultTokenExpirySkew]）；
  /// 服务端未给过期时刻时恒为 false（只能等 401 兜底）
  bool isAccessTokenExpiring({Duration skew = defaultTokenExpirySkew});

  /// 保存令牌（含轮换后的刷新令牌）
  Future<void> saveTokens(TokenSet tokens);

  /// 清除认证信息（登出、刷新失败时调用）
  Future<void> clearAuth();
}
