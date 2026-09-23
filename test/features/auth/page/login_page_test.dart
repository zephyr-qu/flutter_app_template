import 'package:app_core/base/result.dart';
import 'package:app_core/models/user.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:my_app/features/auth/data/auth_providers.dart';
import 'package:my_app/features/auth/data/auth_repository.dart';
import 'package:my_app/features/auth/page/login_page.dart';

import '../../../support/app_test_harness.dart';

class MockAuthRepository extends Mock implements AuthRepository;

void main() {
  late MockAuthRepository mockRepo;
  late ProviderContainer container;

  setUp(() {
    mockRepo = MockAuthRepository();
    when(() => mockRepo.logout())
        .thenAnswer((_) async => const Result.success(null));
    when(
      () => mockRepo.login(any(), any()),
    ).thenAnswer((_) async => const Result.success(User(id: 1, name: '测试用户')));

    // 页面只依赖 loginProvider，而它只在提交时读 authRepositoryProvider；
    // 覆盖掉就可以完全不装配网络层（不需要 prefs，也不需要 harness）。
    container = ProviderContainer(
      overrides: [authRepositoryProvider.overrideWithValue(mockRepo)],
    );
    addTearDown(container.dispose);
  });

  group('LoginPage', () {
    testWidgets('renders email and password fields', (tester) async {
      await tester.pumpWidget(
        wrapPage(const LoginPage(), container: container),
      );
      expect(find.text('邮箱'), findsOneWidget);
      expect(find.text('密码'), findsOneWidget);
      expect(find.text('登录'), findsOneWidget);
    });

    testWidgets('button is disabled when fields are empty', (tester) async {
      await tester.pumpWidget(
        wrapPage(const LoginPage(), container: container),
      );
      final button = tester.widget<FilledButton>(find.byType(FilledButton));
      expect(button.onPressed, isNull);
    });

    testWidgets('button is enabled when email and password are valid', (
      tester,
    ) async {
      await tester.pumpWidget(
        wrapPage(const LoginPage(), container: container),
      );
      await tester.enterText(find.byType(TextField).first, 'test@example.com');
      await tester.enterText(find.byType(TextField).last, 'password123');
      await tester.pump();
      final button = tester.widget<FilledButton>(find.byType(FilledButton));
      expect(button.onPressed, isNotNull);
    });
  });
}
