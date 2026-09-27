import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:my_app/core/base/result.dart';
import 'package:my_app/core/models/user.dart';
import 'package:my_app/core/theme/app_theme.dart';
import 'package:my_app/features/auth/data/auth_repository.dart';
import 'package:my_app/features/auth/logic/auth_view_model.dart';
import 'package:my_app/features/auth/page/login_page.dart';

class MockAuthRepository extends Mock implements AuthRepository;

void main() {
  late AuthViewModel viewModel;

  setUp(() {
    final mockRepo = MockAuthRepository();

    when(mockRepo.logout).thenAnswer((_) async => const Result.success(null));
    when(
      () => mockRepo.login(any(), any()),
    ).thenAnswer((_) async => const Result.success(User(id: 1, name: '测试用户')));

    // 直接构造 ViewModel 并从构造参数注入页面：不需要 GetIt，
    // 也不需要 `setUpTestApp()` 去装配全局容器。
    viewModel = AuthViewModel(mockRepo);
  });

  group('LoginPage', () {
    /// 页面通过 AppLocalizations 取文案，所以必须挂上 delegate
    Widget wrap(Widget child) =>
        MaterialApp(theme: buildLightTheme(), home: child);

    testWidgets('renders email and password fields', (tester) async {
      await tester.pumpWidget(wrap(LoginPage(viewModel: viewModel)));
      expect(find.text('邮箱'), findsOneWidget);
      expect(find.text('密码'), findsOneWidget);
      expect(find.text('登录'), findsOneWidget);
    });

    testWidgets('button is disabled when fields are empty', (tester) async {
      await tester.pumpWidget(wrap(LoginPage(viewModel: viewModel)));
      final button = tester.widget<FilledButton>(find.byType(FilledButton));
      expect(button.onPressed, isNull);
    });

    testWidgets('button is enabled when email and password are valid', (
      tester,
    ) async {
      await tester.pumpWidget(wrap(LoginPage(viewModel: viewModel)));
      await tester.enterText(find.byType(TextField).first, 'test@example.com');
      await tester.enterText(find.byType(TextField).last, 'password123');
      await tester.pump();
      final button = tester.widget<FilledButton>(find.byType(FilledButton));
      expect(button.onPressed, isNotNull);
    });
  });
}
