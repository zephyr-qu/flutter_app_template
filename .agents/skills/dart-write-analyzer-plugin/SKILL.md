---
name: dart-write-analyzer-plugin
description: 编写、启用、测试 Dart 分析服务器插件（analysis_server_plugin）：Plugin/PluginRegistry 注册规则，AnalysisRule + SimpleAstVisitor 写规则，ResolvedCorrectionProducer 写 quick fix / quick assist，AnalysisRuleTest + assertDiagnostics 写测试，analysis_options.yaml 顶层 plugins 段启用与抑制诊断。Use when the user asks about analyzer plugins, analysis_server_plugin, custom lint rules, AnalysisRule, SimpleAstVisitor, RuleVisitorRegistry, registerWarningRule, registerLintRule, registerFixForRule, registerAssist, ResolvedCorrectionProducer, AnalysisRuleTest, assertDiagnostics, or enabling and suppressing plugin diagnostics.
---

# Dart 分析服务器插件

新系统（非 legacy `analyzer_plugin`）的分析器插件：可以报诊断（warning / lint），也可以在 IDE 里提供 quick fix 与 quick assist。

## 按任务选文档

| 要做什么 | 参考文件 |
|---|---|
| 启用插件、按需开 lint、抑制 `// ignore: plugin/code` | [reference/using_plugins.md](reference/using_plugins.md) |
| 插件骨架：`pubspec.yaml`、`lib/main.dart`、`Plugin`、调试 | [reference/writing_a_plugin.md](reference/writing_a_plugin.md) |
| 写规则：`AnalysisRule` + `SimpleAstVisitor` + 注册 | [reference/writing_rules.md](reference/writing_rules.md) |
| 测规则：`AnalysisRuleTest`、`assertDiagnostics`、stub 包 | [reference/testing_rules.md](reference/testing_rules.md) |
| 写 quick fix（**挂在某条诊断上**） | [reference/writing_fixes.md](reference/writing_fixes.md) |
| 写 quick assist（**不挂诊断**，如小重构） | [reference/writing_assists.md](reference/writing_assists.md) |

写规则前先读 `writing_a_plugin.md`（骨架）和 `writing_rules.md`（主体）；`writing_fixes.md` 与 `writing_assists.md` 的类结构几乎相同，差别只在 `FixKind` vs `AssistKind`、`fixKind` vs `assistKind`、以及注册方法。

## 本仓库的现成例子

`tool/lints/` 是本仓库自己的插件（包名 `app_lints`），可以直接照抄形状：

| 想看什么 | 文件 |
|---|---|
| 入口与注册（4 条规则全注册为 warning） | `tool/lints/lib/main.dart` |
| 规则实现（`AnalysisRule` + `_Visitor`） | `tool/lints/lib/src/rules.dart` |
| 规则测试（`AnalysisRuleTest` + `newFile` / `newPackage`） | `tool/lints/test/rules_test.dart` |
| 包配置 | `tool/lints/pubspec.yaml` |

## 容易踩的坑

- **新系统 `plugins` 是顶层段**，不是 `analyzer:` 的子段（legacy 系统才在 `analyzer:` 下）。
- **plugin 的 lint 默认关闭**，必须在 `diagnostics:` 下逐个 `true`；plugin 的 warning 默认开启。
- 改完 `plugins` 段必须**重启分析服务器**才生效。
- 每个 `LintCode` / `WarningCode` 必须是 `static const` 单实例——这是功能要求，不是风格问题。多个实例会让分析服务器无法匹配诊断，用户 `// ignore:` 也会失效。
- `registerNodeProcessors` 里必须用 `RuleVisitorRegistry` 的 `addXxx` 注册访问方法，否则 visitor 方法不会被调用。
- plugin 注册的 fix 只能声明 `CorrectionApplicability.singleLocation` 或 `acrossSingleFile`，批量应用不支持。
- plugin 里 **`print` 不能用来调试**（输出不会显示），需要写日志文件；插件崩溃可在 analyzer diagnostics 页面看到。
- 测试里 `newPackage` 必须在 `super.setUp()` **之前**调用。

## 参考文档来源

`reference/` 下六份文档原样摘自 `analysis_server_plugin` 0.3.23 包（Dart SDK，BSD-3），

```
<PUB_CACHE>/hosted/pub.dev/analysis_server_plugin-0.3.23/doc/
```

注意文档里的版本示例已滞后：`writing_a_plugin.md` 写的是 `analysis_server_plugin: ^0.2.2` / `analyzer: ^8.0.0`，本仓库实际用 `^0.3.23` / `analyzer: ^14.4.0`（见 `tool/lints/pubspec.yaml`）。API 形状仍一致。升级依赖后可按上面路径重新同步 `reference/`。
