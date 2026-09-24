import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:my_app/core/config/user_preferences.dart';
import 'package:my_app/core/providers.dart';
import 'package:my_app/core/theme/app_theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 测试用的装配上下文。
///
/// `container` 就是注入点（Riverpod 世界里没有第二个）：页面测试用 [wrapPage]
/// 把它挂成 `UncontrolledProviderScope`，逻辑测试直接 `read` / `listen`。
typedef TestAppContext = ({
  ProviderContainer container,
  SharedPreferences prefs,
  UserPreferences preferences,
});

/// 关掉 Riverpod 3 的**自动重试**（默认 200ms 起、指数退避、最多 10 次）。
///
/// 两条测试特有的理由（生产保留默认重试）：
/// - 失败的 provider 会不停排新的定时器，widget 测试收尾时直接判失败
///   （`A Timer is still pending even after the widget tree was disposed`）；
/// - 「仓库被调用了几次」这类断言会被后台重试悄悄加一。
Duration? noRetry(int retryCount, Object error) => null;

/// 装配一个测试容器。
///
/// 用**真实的** `UserPreferences`——它有自己的单元测试，页面测试再 mock 一遍既重复、
/// 又容易掩盖接线错误。要换掉的是网络与仓库，通过 [overrides] 逐个替换具体 provider。
///
/// `prefsProvider` 必须 override：它没有默认实现（理由见 `core/providers.dart`）。
/// 容器在测试结束后自动 dispose，调用方不必写 tearDown。
Future<TestAppContext> setUpTestApp({
  List<Override> overrides = const [],
}) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();

  final container = ProviderContainer(
    retry: noRetry,
    overrides: [prefsProvider.overrideWithValue(prefs), ...overrides],
  );
  addTearDown(container.dispose);

  return (
    container: container,
    prefs: prefs,
    preferences: container.read(userPreferencesProvider),
  );
}

/// 页面测试专用外壳。
///
/// 必须做的事：用 `buildLightTheme()` —— 页面通过 `AppThemeExtension.of(context)!`
/// 取圆角等 token，缺了会空断言。
///
/// 传 [container] 时用 `UncontrolledProviderScope` 接上测试自己建的容器：
/// 换成 `ProviderScope` 会另建一个，测试对 provider 的读写就与页面断开了。
Widget wrapPage(Widget page, {ProviderContainer? container}) {
  final app = MaterialApp(theme: buildLightTheme(), home: page);
  if (container == null) return ProviderScope(child: app);
  return UncontrolledProviderScope(container: container, child: app);
}
