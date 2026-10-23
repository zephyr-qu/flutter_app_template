/// 布局断点：**全项目唯一来源**，页面与壳层都从这里取，不要在各处重写
/// `maxWidth > 800` 这种字面量。
///
/// 约定与反例见 ui/component-guidelines.md「布局断点与响应式」。
abstract final class Breakpoints {
  /// 宽屏阈值。**超过**它才是宽屏（等于 800 仍按窄屏处理，与
  /// `main_page.dart` 的 `>` 语义一致，别改成 `>=`）。
  ///
  /// 跨过这条线要同时变两件事：
  /// - 导航：底部 `NavigationBar` → 侧边 `NavigationRail`
  /// - 页面：单列铺满 → 双列 / 限宽居中
  static const double expanded = 800;

  /// 单列页面的内容最大宽度。窄屏用不上；宽屏时居中限宽，避免一行正文在
  /// 平板上拉满 1200dp 以上不可读。按设计稿调这里，不要在页面里各写一个。
  static const double contentMaxWidth = 720;
}
