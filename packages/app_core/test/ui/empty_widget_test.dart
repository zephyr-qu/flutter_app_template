import 'package:app_core/theme/app_theme.dart';
import 'package:app_core/ui/empty_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  /// 必须带 `buildLightTheme()`：`EmptyWidget` 通过
  /// `AppThemeExtension.of(context)` 取圆角，缺了会空断言。
  Future<void> pumpEmpty(WidgetTester tester, Widget widget) =>
      tester.pumpWidget(
        MaterialApp(
          theme: buildLightTheme(),
          home: Scaffold(body: widget),
        ),
      );

  testWidgets('渲染文案与默认图标', (tester) async {
    await pumpEmpty(tester, const EmptyWidget(message: '暂无数据'));

    expect(find.text('暂无数据'), findsOneWidget);
    expect(find.byIcon(Icons.inbox_rounded), findsOneWidget);
    expect(find.byType(FilledButton), findsNothing);
  });

  testWidgets('自定义图标替换默认图标', (tester) async {
    await pumpEmpty(
      tester,
      const EmptyWidget(message: '没有搜索到结果', icon: Icons.search_off),
    );

    expect(find.byIcon(Icons.search_off), findsOneWidget);
    expect(find.byIcon(Icons.inbox_rounded), findsNothing);
  });

  testWidgets('actionLabel 与 onAction 齐备时才出按钮，点击回调生效', (tester) async {
    var tapped = 0;

    await pumpEmpty(
      tester,
      EmptyWidget(message: '加载失败', actionLabel: '重试', onAction: () => tapped++),
    );

    final button = find.widgetWithText(FilledButton, '重试');
    expect(button, findsOneWidget);

    await tester.tap(button);
    expect(tapped, 1);
  });

  testWidgets('只给 actionLabel 不给 onAction 时不出按钮（避免露出点不动的按钮）', (tester) async {
    await pumpEmpty(
      tester,
      const EmptyWidget(message: '加载失败', actionLabel: '重试'),
    );

    expect(find.byType(FilledButton), findsNothing);
  });
}
