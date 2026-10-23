import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_app/core/theme/app_theme.dart';
import 'package:my_app/core/ui/list_group.dart';

void main() {
  Future<void> pumpGroup(WidgetTester tester, Widget child) =>
      tester.pumpWidget(
        MaterialApp(
          theme: buildLightTheme(),
          home: Scaffold(body: child),
        ),
      );

  group('ListGroup', () {
    testWidgets('子项全渲染，项间分隔线 = 子项数 - 1', (tester) async {
      await pumpGroup(
        tester,
        const ListGroup(
          children: [
            ListGroupRow(title: '外观'),
            ListGroupRow(title: '通知'),
            ListGroupRow(title: '隐私'),
          ],
        ),
      );

      expect(find.text('外观'), findsOneWidget);
      expect(find.text('通知'), findsOneWidget);
      expect(find.text('隐私'), findsOneWidget);
      expect(find.byType(Divider), findsNWidgets(2));
    });

    testWidgets('单个子项没有分隔线', (tester) async {
      await pumpGroup(
        tester,
        const ListGroup(children: [ListGroupRow(title: '外观')]),
      );

      expect(find.byType(Divider), findsNothing);
    });
  });

  group('ListGroupRow', () {
    testWidgets('onTap 触发整行回调，并且画 chevron', (tester) async {
      var tapped = 0;

      await pumpGroup(
        tester,
        ListGroup(
          children: [ListGroupRow(title: '外观', onTap: () => tapped++)],
        ),
      );

      expect(find.byIcon(Icons.chevron_right), findsOneWidget);

      await tester.tap(find.text('外观'));

      expect(tapped, 1);
    });

    testWidgets('没有 onTap 时不可点、也不画 chevron（不骗用户）', (tester) async {
      await pumpGroup(
        tester,
        const ListGroup(
          children: [ListGroupRow(title: '版本号', value: '1.0.0')],
        ),
      );

      expect(find.text('1.0.0'), findsOneWidget);
      expect(find.byIcon(Icons.chevron_right), findsNothing);
    });

    testWidgets('自定义 trailing 顶掉默认的「值 + chevron」', (tester) async {
      await pumpGroup(
        tester,
        ListGroup(
          children: [
            ListGroupRow(
              title: '深色模式',
              value: '跟随系统',
              onTap: () {},
              trailing: const Icon(Icons.toggle_on),
            ),
          ],
        ),
      );

      expect(find.byIcon(Icons.toggle_on), findsOneWidget);
      expect(find.byIcon(Icons.chevron_right), findsNothing);
      expect(find.text('跟随系统'), findsNothing);
    });
  });

  group('SliverListGroup', () {
    testWidgets('大列表只构建可视项，不会首帧全量建树', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: buildLightTheme(),
          home: Scaffold(
            body: CustomScrollView(
              slivers: [
                SliverListGroup(
                  itemCount: 5000,
                  itemBuilder: (context, index) =>
                      ListGroupRow(title: '第 $index 行'),
                ),
              ],
            ),
          ),
        ),
      );
      // 5000 项若一次建完，这里会直接超时
      await tester.pumpAndSettle();

      expect(find.text('第 0 行'), findsOneWidget);
      expect(find.text('第 4999 行'), findsNothing);
      expect(find.byType(ListGroupRow).evaluate().length, lessThan(100));
    });
  });
}
