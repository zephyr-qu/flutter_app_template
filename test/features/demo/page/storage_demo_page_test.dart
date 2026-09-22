import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:my_app/features/demo/logic/storage_demo_view_model.dart';
import 'package:my_app/features/demo/page/storage_demo_page.dart';
import 'package:signals_flutter/signals_flutter.dart';

import '../../../support/app_test_harness.dart';

class MockStorageDemoViewModel extends Mock implements StorageDemoViewModel;

/// 页面测试只关心「渲染 + 按钮接线」，所以 ViewModel 用 mock 的，
/// 由测试直接推信号值来控制界面状态。
///
/// 真实行为（文件 I/O、数据库、失败处理）在
/// `test/features/demo/logic/storage_demo_view_model_test.dart` 里用真实依赖覆盖——
/// widget 测试的假时钟推不动真实的文件 / 数据库 I/O。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockStorageDemoViewModel vm;
  // useSignalValue 要求 FlutterSignal（signals_flutter 的 signal() 返回的就是它），
  // 声明成 core 的 Signal 会窄化类型导致 stub 失败
  late FlutterSignal<String?> savedContent;
  late FlutterSignal<int> usageKb;
  late FlutterSignal<int> cachedCount;
  late FlutterSignal<bool> lastActionFailed;

  setUp(() {
    savedContent = signal<String?>(null);
    usageKb = signal(0);
    cachedCount = signal(0);
    lastActionFailed = signal(false);

    vm = MockStorageDemoViewModel();
    when(() => vm.savedContent).thenReturn(savedContent);
    when(() => vm.usageKb).thenReturn(usageKb);
    when(() => vm.cachedCount).thenReturn(cachedCount);
    when(() => vm.lastActionFailed).thenReturn(lastActionFailed);
    when(() => vm.refresh()).thenAnswer((_) async {});
  });

  Future<void> pumpPage(WidgetTester tester) async {
    // 页面比默认测试视口（800x600）高，放大一点：ListView 只布局可视区内的
    // 子节点，视口外的内容 finder 找不到
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(wrapPage(StorageDemoPage(viewModel: vm)));
    await tester.pumpAndSettle();
  }

  group('StorageDemoPage — 渲染', () {
    testWidgets('显示两个区块的标题与说明', (tester) async {
      await pumpPage(tester);

      expect(find.text('本地存储示例'), findsOneWidget);
      expect(find.text('文件缓存'), findsOneWidget);
      expect(find.text('数据库缓存'), findsOneWidget);
      expect(find.text('填充示例数据'), findsOneWidget);
    });

    testWidgets('空文件与空缓存时的文案', (tester) async {
      await pumpPage(tester);

      expect(find.text('（无）'), findsOneWidget);
      expect(find.text('占用：0 KB'), findsOneWidget);
      expect(find.text('已缓存 0 篇文章'), findsOneWidget);
      expect(find.text('操作失败'), findsNothing);
    });

    testWidgets('信号变化时界面跟着变', (tester) async {
      await pumpPage(tester);
      expect(find.text('（无）'), findsOneWidget);

      // 直接推信号，验证页面确实是订阅着这些信号的
      savedContent.value = '磁盘上的内容';
      usageKb.value = 3;
      cachedCount.value = 2;
      await tester.pumpAndSettle();

      expect(find.text('磁盘上的内容'), findsOneWidget);
      expect(find.text('（无）'), findsNothing);
      expect(find.text('占用：3 KB'), findsOneWidget);
      expect(find.text('已缓存 2 篇文章'), findsOneWidget);
    });

    testWidgets('失败标志打开时显示错误行', (tester) async {
      await pumpPage(tester);

      lastActionFailed.value = true;
      await tester.pumpAndSettle();

      expect(find.text('操作失败'), findsOneWidget);
    });
  });

  group('StorageDemoPage — 按钮接线', () {
    testWidgets('文件区块的按钮各调用对应方法', (tester) async {
      when(() => vm.saveNote()).thenAnswer((_) async {});
      when(() => vm.deleteNote()).thenAnswer((_) async {});
      when(() => vm.clearTemp()).thenAnswer((_) async {});

      await pumpPage(tester);

      await tester.tap(find.text('保存'));
      await tester.tap(find.text('删除'));
      await tester.tap(find.text('清空临时目录'));
      await tester.pumpAndSettle();

      verify(() => vm.saveNote()).called(1);
      verify(() => vm.deleteNote()).called(1);
      verify(() => vm.clearTemp()).called(1);
    });

    testWidgets('数据库区块的按钮各调用对应方法', (tester) async {
      when(() => vm.seedCache()).thenAnswer((_) async {});
      when(() => vm.clearCache()).thenAnswer((_) async {});

      await pumpPage(tester);

      await tester.ensureVisible(find.text('填充示例数据'));
      await tester.tap(find.text('填充示例数据'));
      await tester.tap(find.text('清空缓存'));
      await tester.pumpAndSettle();

      verify(() => vm.seedCache()).called(1);
      verify(() => vm.clearCache()).called(1);
    });

    testWidgets('输入框把内容交给 ViewModel', (tester) async {
      await pumpPage(tester);

      await tester.enterText(find.byType(TextField), '要保存的内容');

      verify(() => vm.updateNote('要保存的内容')).called(1);
    });

    testWidgets('进入页面时刷新一次状态', (tester) async {
      await pumpPage(tester);

      verify(() => vm.refresh()).called(1);
    });
  });
}
