import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:leak_tracker_flutter_testing/leak_tracker_flutter_testing.dart';
import 'package:mocktail/mocktail.dart';
import 'package:my_app/app/app.dart';
import 'package:my_app/core/config/user_preferences.dart';
import 'package:my_app/core/data/storage/auth_storage.dart';
import 'package:my_app/features/auth/data/auth_repository.dart';
import 'package:my_app/features/auth/logic/auth_view_model.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MockAuthRepository extends Mock implements AuthRepository;

/// 验证「设置里的语言」这条链路真的通到 MaterialApp：
/// UserPreferences.locale 信号 → MyApp 重建 → MaterialApp.locale → 页面文案。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late UserPreferences preferences;

  setUp(() {
    // 本测试挂载真实的 MyApp，其内部创建的 router / notifier 无法由此处释放
    LeakTesting.settings = LeakTesting.settings.withIgnored(
      createdByTestHelpers: true,
      allNotDisposed: true,
    );
  });

  Future<void> pumpApp(WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    final storage = AuthStorage(prefs, const FlutterSecureStorage());
    await storage.ready;
    // 显式指定中文：测试环境的系统语言是 en，跟随系统会落到英文
    preferences = UserPreferences(prefs)..setLocale(const Locale('zh'));

    await GetIt.I.reset();
    GetIt.I.registerSingleton<AuthStorage>(storage);
    GetIt.I.registerSingleton<UserPreferences>(preferences);
    GetIt.I.registerFactory<AuthViewModel>(
      () => AuthViewModel(MockAuthRepository()),
    );

    await tester.pumpWidget(const MyApp());
    await tester.pumpAndSettle();
    // 启动页有 2.2s 品牌动画
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();
  }

  testWidgets('切换语言后整个界面立即换成对应文案', (tester) async {
    await pumpApp(tester);

    // 中文
    expect(find.text('登录'), findsOneWidget);
    expect(find.text('邮箱'), findsOneWidget);
    expect(find.text('Sign in'), findsNothing);

    // 在「设置」里切换语言
    preferences.setLocale(const Locale('en'));
    await tester.pumpAndSettle();

    expect(find.text('Sign in'), findsOneWidget);
    expect(find.text('Email'), findsOneWidget);
    expect(find.text('登录'), findsNothing);

    // 切回跟随系统（测试环境下解析为 en）
    preferences.setLocale(null);
    await tester.pumpAndSettle();

    expect(find.text('Sign in'), findsOneWidget);
    await GetIt.I.reset();
  });
}
