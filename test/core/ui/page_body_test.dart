import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_app/core/theme/app_theme.dart';
import 'package:my_app/core/ui/breakpoints.dart';
import 'package:my_app/core/ui/page_body.dart';

void main() {
  /// 用 key 量出 `PageBody` 实际留给内容的宽度。
  const probe = Key('probe');

  Future<Size> pumpAt(WidgetTester tester, double width) async {
    tester.view.physicalSize = Size(width, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        theme: buildLightTheme(),
        home: const Scaffold(
          body: PageBody(child: SizedBox.expand(key: probe)),
        ),
      ),
    );

    return tester.getSize(find.byKey(probe));
  }

  testWidgets('窄屏铺满内容区（等于断点仍算窄屏）', (tester) async {
    final size = await pumpAt(tester, Breakpoints.expanded);

    expect(size.width, Breakpoints.expanded);
  });

  testWidgets('再窄一些同样铺满，不做任何限宽', (tester) async {
    final size = await pumpAt(tester, 400);

    expect(size.width, 400);
  });

  testWidgets('宽屏限宽到 contentMaxWidth，并保持高度撑满', (tester) async {
    final size = await pumpAt(tester, 1200);

    expect(size.width, Breakpoints.contentMaxWidth);
    // 高度不能被限宽带走：正文里的 Expanded 依赖它
    expect(size.height, 800);
  });
}
