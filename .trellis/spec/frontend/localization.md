# Localization (l10n)

> 用户可见文案的组织方式，以及如何新增文案 / 新增语言。

---

## 配置

| 项 | 位置 |
| --- | --- |
| 生成配置 | `l10n.yaml` |
| 资源文件 | `lib/l10n/app_zh.arb`（**模板语言**）、`lib/l10n/app_en.arb` |
| 生成物 | `lib/l10n/app_localizations*.dart` —— **不要手改** |
| 构建开关 | `pubspec.yaml` 的 `flutter: generate: true` |

模板语言是**中文**：这个项目面向用户的主语言是中文，英文是第二语言，这样「设置 → 语言」才有切换目标。新增 key 时先加到 `app_zh.arb`，再补 `app_en.arb`。

```bash
flutter gen-l10n      # 只重新生成资源类
flutter analyze       # 生成物有问题会在这里暴露
```

### 漏补翻译会被闸门拦下

`test/l10n/app_localizations_test.dart` 断言两个 ARB 的 key 集合相等（多一个少一个都红），失败信息里会**直接列出缺失的 key**：

```
Expected: empty
Actual: Set:['someMissingKey']
这些 key 缺少英文翻译，会静默回退成中文
```

**编译期不会报错**，这一点必须知道：gen-l10n 只打印一行 `"en": N untranslated message(s).`，`flutter analyze` 保持干净，运行时则是英文界面里静默冒出一句中文。所以唯一拦得住的是那条测试。

> **不要**为了「让提示更显眼」而在 `l10n.yaml` 里加 `untranslated-messages-file`。实测：开了之后那句终端提示会**消失**，信息被搬进项目根目录的 `untranslated.json`——还得加 `.gitignore`，且不再生成时它不会被自动清理（会留下一份过期清单）。测试的失败信息已经是同一份内容，而且它是**阻塞性**的。

## 在代码里使用

```dart
@override
Widget build(BuildContext context) {
  final l10n = AppLocalizations.of(context);
  return Text(l10n.loginButton);
}
```

- **禁止**在 widget 里硬编码用户可见文案；注释写中文没问题，那是刻意的约定
- 带参数的文案用占位符，不要在 Dart 里拼字符串：
  ```dart
  l10n.homeGreeting(user.name)     // "你好, {name}" / "Hello, {name}"
  l10n.articleReadingTime(5)       // "{minutes} 分钟阅读"
  ```
- 语言选择器里，语言名用它自己的语言书写（`中文` / `English`），只有「跟随系统」跟随界面语言
- **主题名相反**：`深色` / `Dark` 用**当前界面语言**书写，不用「它自己的语言」——主题没有自己的语言
- 选择器里表示「跟随系统」时用**专门的枚举**（如 `_LanguageChoice.system`），不要用 `null`：`showDialog` 返回 `null` 表示用户取消，两者混在一起就分不清「选了跟随系统」和「什么都没选」

## 语言设置

- 状态存在 `UserPreferences.locale`（`null` = 跟随系统），持久化为 `app.locale`
- 入口在「个人 → 设置 → 语言」，选择结果写入 `UserPreferences.setLocale`
- `MyApp` 订阅了该信号并传给 `MaterialApp.locale`，所以切换后界面**立即**生效；`themeMode` 同理
- 读取本地保存的语言时会校验是否在 `AppLocalizations.supportedLocales` 内，越界值回退到跟随系统

### 新增一门语言

1. 加 `lib/l10n/app_<code>.arb`，补齐 `app_zh.arb` 的所有 key
2. 在「个人 → 设置 → 语言」的选择器里加一项（`profile_page.dart` 的 `_LanguageChoice`）
3. `flutter gen-l10n`
4. **把新语言加进 `test/l10n/app_localizations_test.dart`** —— 那道 key 对齐断言目前写死了 zh / en 两个文件，第三门语言不会被自动覆盖

## 测试

- 页面 widget 测试**必须**挂上 delegate，否则 `AppLocalizations.of(context)` 会空断言；同时必须用 `buildLightTheme()`，因为页面通过 `AppThemeExtension.of(context)!` 取圆角等 token。用 `test/support/app_test_harness.dart` 的 `wrapPage()` / `setUpTestApp()` 一次搞定：
  ```dart
  final app = await setUpTestApp();    // prefs + AuthStorage + UserPreferences
  await tester.pumpWidget(wrapPage(const SomePage()));
  ```
- `test/l10n/app_localizations_test.dart` 保证两个 ARB 的 key 完全对齐 —— 缺翻译不会报错，只会静默回退成中文，所以这条测试是必要的
- `test/l10n/language_switch_test.dart` 挂载真实的 `MyApp`，验证「改 `UserPreferences.locale` → 界面文案跟着变」这条链路

## 错误文案

`Failure` **不携带文案**，只有 `code`（`FailureCode`）与可选的状态码；翻译在展示层：

```dart
// core/ui/failure_message.dart
extension FailureMessage on Failure {
  String localizedMessage(AppLocalizations l10n) { ... }
}
```

- `runAsync` 写进 `AsyncState.error` 的是 `Failure` **对象**，`ErrorText` 认识它并翻译
- SnackBar 等场景直接 `error.localizedMessage(l10n)`
- 新增 `FailureCode` 时，`localizedMessage` 的 switch 会因为不再穷尽而编译失败，同时提醒去补 ARB（`error*` 系列 key）
- `test/core/ui/failure_message_test.dart` 会遍历 `FailureCode.values`，断言中英文都有非空文案

**不要**在 `Failure` 上加回 `message`，也不要在 core 层拼用户可见文案——那样语言就被钉死了，切到英文时错误提示会保持中文。
