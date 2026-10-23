import 'package:flutter_test/flutter_test.dart';
import 'package:my_app/core/ui/breakpoints.dart';

/// 断点是全项目**唯一来源**，改它等于改所有页面的宽屏形态。
/// 这两条断言的作用是：改值时必须连带改测试与 spec，不能悄悄漂移。
///
/// 「严格大于」这一语义本身在 `main_page.dart` 里（`>` 而非 `>=`），
/// 由 `test/routing/main_shell_test.dart` 的宽屏/窄屏两条用例覆盖。
void main() {
  test('宽屏阈值是 800', () {
    expect(Breakpoints.expanded, 800);
  });

  test('单列限宽必须窄于宽屏阈值，否则限宽永远不生效', () {
    expect(Breakpoints.contentMaxWidth, 720);
    expect(Breakpoints.contentMaxWidth, lessThan(Breakpoints.expanded));
  });
}
