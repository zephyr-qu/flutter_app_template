import 'package:app_core/data/network/token_refresher.dart';

/// 可脚本化的 [TokenRefresher]：只实现 [refresh]。
///
/// 用它而不是真的 `TokenRefresher` 时，测的是**拦截器怎么用刷新结果**
/// （失败要不要清凭证、要不要重放）；真刷新器自己的语义
/// （single-flight、防递归）由 `token_refresh_test.dart` 用真实实现验证。
class FakeTokenRefresher implements TokenRefresher {
  new({this.result});

  /// 每次 [refresh] 的返回值；`null` 表示刷新失败
  String? result;

  /// 每次 [refresh] 时执行的副作用（例如把新令牌写回存储）
  Future<void> Function()? onRefresh;

  /// [refresh] 被调用的次数
  int refreshCount = 0;

  @override
  Future<String?> refresh() async {
    refreshCount++;
    await onRefresh?.call();
    return result;
  }
}
