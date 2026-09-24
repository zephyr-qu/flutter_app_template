# Localization (l10n)

> 本脚手架是**单语言**的：用户可见文案直接写成中文字面量，没有 ARB，也没有
> `AppLocalizations`。这是**有意**的裁剪结果，不是漏掉的能力——`tool/prune.dart
> --l10n=single` 就是把多语言版本降为单语言的那条命令，它仍在仓库里（幂等，可重跑）。

---

## 现状

> 快照（2026-09）：改动相关代码时请同步本节。核对命令见下方每行。

| 项 | 现状 |
| --- | --- |
| `l10n.yaml` | 不存在 |
| `lib/l10n/**`（ARB + 生成物） | 不存在 |
| `flutter_localizations` / `intl` | 不在 `pubspec.yaml` |
| 用户可见文案 | 直接写在 widget 里的中文字面量（`const Text('设置')`） |
| `Failure` 的文案 | `lib/core/ui/failure_message.dart` 的 `switch` 常量表 |

核对：`grep -rn "AppLocalizations" lib/` 应无输出（只有 `failure_message.dart` 的注释里提到 l10n 这个词）。

---

## 文案写在哪

- **页面**：字面量，`const Text('设置')` / `hintText: 'your@email.com'`
- **共享组件**：文案由调用方传（`EmptyWidget(message: '暂无数据')`），组件自己不携带文案
- **错误**：`error.localizedMessage()`（**无参数**），返回中文常量

```dart
// lib/core/ui/failure_message.dart
extension FailureMessage on Failure {
  String localizedMessage() {
    return switch (code) {
      FailureCode.timeout => '请求超时',
      // ...
      FailureCode.unknown => '未知错误',
    };
  }
}
```

`Failure` **只携带 `code`**、不携带文案。这条结构不变：文案始终在展示层，切换语言的那天
只需要改展示层（见 [backend/error-handling.md](../backend/error-handling.md)）。

---

## 常见错误

| 错误 | 为什么 |
| --- | --- |
| 在 `Failure` 上加回 `message` | 文案是展示职责；模型层带着用户文案，语言就被钉死在数据里 |
| 提前抽一层「文案常量表」 | 单语言下它只是多一层间接；真要多语言时该引入的是 l10n，不是自制的表 |
| 在 core / data 层拼用户可见文案 | 展示层才认识语言（现在没有语言层，但结构要留着给以后） |
| 以为 `wrapPage()` 需要挂 l10n delegate | 本项目没有 l10n；`wrapPage()` 只挂主题（`buildLightTheme()`） |

---

## 需要多语言时怎么加回来

没有反向工具（`prune.dart` 只做裁剪，不做恢复），这是一次手工活。标准做法：

1. `pubspec.yaml`：加 `flutter_localizations`、`intl`，`flutter:` 下开 `generate: true`
2. 新增 `l10n.yaml`、`lib/l10n/app_zh.arb`（模板语言）、`app_en.arb`；`flutter gen-l10n`
3. 页面文案换成 `AppLocalizations.of(context).xxx`
4. `failure_message.dart` 的 `localizedMessage` 改为接收 `AppLocalizations`
5. 补 key 对齐测试（两个 ARB 的 key 集合相等）与语言切换测试
6. `tool/prune.dart --l10n=single` 的**裁剪面清单**就是上面这些位置的完整列表
   （`.trellis/tasks/archive/2026-09/09-22-prune-l10n/prd.md`），照着逐条反向做，不会漏

之所以不做成分支：l10n 横切 `core/ui/failure_message.dart` 与 `core/config/user_preferences.dart`，
做成分支会在这些文件上与其它分支反复冲突，做成一条可重跑的命令更省事。
