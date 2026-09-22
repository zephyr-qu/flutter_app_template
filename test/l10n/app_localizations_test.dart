import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:my_app/l10n/app_localizations.dart';
import 'package:my_app/l10n/app_localizations_en.dart';
import 'package:my_app/l10n/app_localizations_zh.dart';

/// 这些测试防止「加了 key 却忘了翻译」这类静默回退：
/// 缺失的英文翻译不会报错，运行时会直接显示中文。
void main() {
  Map<String, Object?> readArb(String path) =>
      jsonDecode(File(path).readAsStringSync()) as Map<String, Object?>;

  Iterable<String> messageKeys(Map<String, Object?> arb) =>
      arb.keys.where((k) => !k.startsWith('@'));

  test('支持的语言包含中文与英文', () {
    final codes = AppLocalizations.supportedLocales
        .map((l) => l.languageCode)
        .toSet();

    expect(codes, containsAll(<String>{'zh', 'en'}));
  });

  test('英文 ARB 覆盖了中文模板里的每一个 key', () {
    final zhKeys = messageKeys(readArb('lib/l10n/app_zh.arb')).toSet();
    final enKeys = messageKeys(readArb('lib/l10n/app_en.arb')).toSet();

    expect(zhKeys, isNotEmpty);
    expect(enKeys.difference(zhKeys), isEmpty, reason: '英文 ARB 有多余的 key');
    expect(
      zhKeys.difference(enKeys),
      isEmpty,
      reason: '这些 key 缺少英文翻译，会静默回退成中文',
    );
  });

  test('两个语言都提供了非空文案', () {
    for (final localizations in <AppLocalizations>[
      AppLocalizationsZh(),
      AppLocalizationsEn(),
    ]) {
      expect(localizations.loading, isNotEmpty);
      expect(localizations.loginButton, isNotEmpty);
      expect(localizations.settingsLanguage, isNotEmpty);
      expect(localizations.themeTitle, isNotEmpty);
      expect(localizations.themeDark, isNotEmpty);
      expect(localizations.homeGreeting('X'), contains('X'));
      expect(localizations.articleReadingTime(5), contains('5'));
    }
  });

  test('英文资源确实生效，而不是回退到中文', () {
    expect(AppLocalizationsZh().loginButton, '登录');
    expect(AppLocalizationsEn().loginButton, 'Sign in');
    expect(
      AppLocalizationsEn().loginButton,
      isNot(AppLocalizationsZh().loginButton),
    );
  });
}
