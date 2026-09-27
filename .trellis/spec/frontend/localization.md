# Localization (l10n)

> 用户可见文案写在哪，以及要加回多语言时怎么做。

---

## 现状：单语言中文

脚手架**没有 l10n**：没有 ARB、没有 `l10n.yaml`、没有 `AppLocalizations`、没有 `generate: true`，也没有语言选择器 —— 它已被 `tool/prune.dart` 的 `--l10n=single` 裁掉。

| 项 | 位置 |
| --- | --- |
| 用户可见文案 | **直接写在 widget 里**（中文） |
| `Failure` 的文案 | `lib/core/ui/failure_message.dart`，一处集中翻译 |

- **不要**为了「规范化」再引入 `intl` / ARB：单语言形态下它们没有收益，只多一个构建步骤
- 注释与文档写中文是**刻意的约定**（见 [guides/comment-guidelines.md](../guides/comment-guidelines.md)），与用户可见文案无关

## 错误文案

`Failure` **不携带文案**，只有 `code`（`FailureCode`）与可选的状态码；翻译在展示层：

```dart
// lib/core/ui/failure_message.dart
extension FailureMessage on Failure {
  String localizedMessage() { ... }   // 单语言形态：无实参
}
```

- `runAsync` 写进 `AsyncState.error` 的是 `Failure` **对象**，`ErrorText` 认识它并翻译
- 新增 `FailureCode` 时 `localizedMessage()` 的 `switch` 会因为不再穷尽而**编译失败** —— 这就是「必须补文案」的护栏
- `test/core/ui/failure_message_test.dart` 遍历 `FailureCode.values`，断言每个都有非空文案

**不要**在 `Failure` 上加回 `message`，也不要在 core 之外拼用户可见文案。

## 要加回多语言时

把 `tool/prune.dart` 的裁剪面**反过来做**即可 —— 那份 `Replacement` / `Removal` 清单就是「多语言形态」与「单语言形态」的差集，逐条倒过来：

1. `pubspec.yaml`：加回 `flutter_localizations`（`sdk: flutter`）与 `intl`，以及 `flutter: generate: true`
2. 新建 `l10n.yaml` 与 `lib/l10n/app_zh.arb`（模板语言：中文）、`lib/l10n/app_en.arb`
3. `MaterialApp` 挂回 `localizationsDelegates` / `supportedLocales` / `locale`
4. 语言偏好的存储与切换入口（`UserPreferences` 的一个 signal + 「个人 → 设置 → 语言」）
5. `flutter gen-l10n` 生成资源类；生成物落在 `lib/l10n/`，已被 `.gitignore` 的 `app_localizations*` 覆盖
6. 页面 widget 测试要挂 delegate，否则 `AppLocalizations.of(context)` 空断言；`test/support/app_test_harness.dart` 的 `wrapPage()` 是统一入口

> `intl` 只在多语言形态下有用，纯单语言项目里它是多余依赖；`test/l10n/` 下的 key 对齐测试也是那个形态才需要。
