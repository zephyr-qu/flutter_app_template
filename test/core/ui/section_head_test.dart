import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_app/core/theme/app_theme.dart';
import 'package:my_app/core/ui/section_head.dart';

void main() {
  Future<void> pumpHead(WidgetTester tester, Widget head) => tester.pumpWidget(
    MaterialApp(
      theme: buildLightTheme(),
      home: Scaffold(
        body: Align(alignment: Alignment.topLeft, child: head),
      ),
    ),
  );

  testWidgets('渲染标题', (tester) async {
    await pumpHead(tester, const SectionHead(title: '快捷功能'));

    expect(find.text('快捷功能'), findsOneWidget);
  });

  testWidgets('caption 与 trailing 可以同时出现', (tester) async {
    await pumpHead(
      tester,
      SectionHead(
        title: '最近动态',
        caption: '共 3 条',
        trailing: TextButton(onPressed: () {}, child: const Text('全部')),
      ),
    );

    expect(find.text('最近动态'), findsOneWidget);
    expect(find.text('共 3 条'), findsOneWidget);
    expect(find.text('全部'), findsOneWidget);
  });

  testWidgets('trailing 的回调可点', (tester) async {
    var tapped = 0;

    await pumpHead(
      tester,
      SectionHead(
        title: '最近动态',
        trailing: TextButton(
          onPressed: () => tapped++,
          child: const Text('全部'),
        ),
      ),
    );

    await tester.tap(find.text('全部'));

    expect(tapped, 1);
  });
}
