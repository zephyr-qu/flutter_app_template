import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_app/core/theme/app_theme.dart';
import 'package:my_app/core/ui/page_head.dart';

void main() {
  /// 页面头替代 `AppBar`，所以测试也直接挂在 `Scaffold.body` 上跑。
  Future<void> pumpHead(WidgetTester tester, Widget head) => tester.pumpWidget(
    MaterialApp(
      theme: buildLightTheme(),
      home: Scaffold(body: head),
    ),
  );

  testWidgets('渲染标题', (tester) async {
    await pumpHead(tester, const PageHead(title: '示例'));

    expect(find.text('示例'), findsOneWidget);
  });

  testWidgets('副标题是可选的：不传就不出', (tester) async {
    await pumpHead(tester, const PageHead(title: '示例'));
    expect(find.byType(Text), findsOneWidget);

    await pumpHead(tester, const PageHead(title: '示例', subtitle: '共 3 条'));

    expect(find.text('示例'), findsOneWidget);
    expect(find.text('共 3 条'), findsOneWidget);
  });

  testWidgets('leading 渲染在标题之前', (tester) async {
    await pumpHead(
      tester,
      PageHead(
        title: '详情',
        leading: IconButton(
          onPressed: () {},
          icon: const Icon(Icons.arrow_back_rounded),
        ),
      ),
    );

    expect(find.byIcon(Icons.arrow_back_rounded), findsOneWidget);
    expect(find.text('详情'), findsOneWidget);
  });

  testWidgets('actions 出现在右侧且可点', (tester) async {
    var tapped = 0;

    await pumpHead(
      tester,
      PageHead(
        title: '示例',
        actions: [
          IconButton(
            onPressed: () => tapped++,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
    );

    await tester.tap(find.byIcon(Icons.refresh_rounded));

    expect(tapped, 1);
  });
}
