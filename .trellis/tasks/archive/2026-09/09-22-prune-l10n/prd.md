# l10n 正交裁剪：`tool/prune.dart --l10n=single`

## Goal

提供一条命令把多语言脚手架降为**单一语言**，得到的结果与手写单语言项目等价，且不破坏任何门禁。

## Requirements

- 入口固定为 `dart run tool/prune.dart --l10n=single`；不带 `--l10n` 时不改动任何文件
- 只做 `l10n` 一个轴；其它轴（`--theme` / `--examples` 等）**只留参数位置**，传了要明确报「未实现」而不是静默忽略
- **幂等**：在 `master` 上重复执行不产生额外差异
- 只改文件、不建分支、不提交（提交由使用者决定）
- 与 `master` 保持单一代码源：后续 `master` 改 `failure_message.dart`／`user_preferences.dart` 后，重跑即可，不需要手工合并

## 裁剪面（逐项清单）

| 类别 | 动作 |
|---|---|
| 配置 | 删 `l10n.yaml`；`pubspec.yaml` 删 `generate: true`、`flutter_localizations`、`intl`（若无其它用途） |
| 目录 | 删 `lib/l10n/**`（ARB + 生成物） |
| 页面 | 全部 `AppLocalizations.of(context)` / `l10n.*` → `const` 中文字符串 |
| core 横切 | `lib/core/ui/failure_message.dart` 的 `localizedMessage` → 常量表 |
| core 横切 | `lib/core/config/user_preferences.dart` 删 `locale` 信号、`setLocale`、`_keyLocale`、`_loadLocale` |
| 页面 | `lib/features/profile/page/profile_page.dart` 删「设置 → 语言」入口 |
| 测试 | 删 `test/l10n/**`；裁剪 `test/core/ui/failure_message_test.dart`、`test/core/config/user_preferences_test.dart` |
| 测试 | `test/support/app_test_harness.dart` 简化 `wrapPage(locale:)` 参数 |
| 门禁 | `README.md` 与 `.trellis/spec/frontend/directory-structure.md` 的目录树去掉 l10n 段（否则 `check_readme_tree` 必挂） |

## Acceptance Criteria

- [x] 在干净的 `master` 上一条命令完成裁剪
- [x] 裁剪后六道门禁全绿：format / check_boundaries / check_conventions / dependency_validator / analyze / check_coverage
- [x] 重复执行不产生差异（幂等）
- [x] `tool/prune.dart` 自带测试（沿用仓库「门禁脚本自带测试」的惯例：`test/tool/prune_test.dart`）
- [x] 传未实现的轴（如 `--theme=default`）时报错退出，退出码非 0

## Notes

- **为什么不做成分支**：l10n 横切 `core/ui/failure_message.dart` 与 `core/config/user_preferences.dart`，做成分支会在这些文件上与其它分支反复冲突；做成参数只需重跑
- `dependency_validator` 会报「声明了却没用」，所以删 import 必须同步删 `pubspec.yaml` 声明，三处要一起改
- 裁剪后 `FailureCode` 的穷尽 switch 不再需要覆盖文案分支，但枚举本身保留
- 参数命名与 `tool/` 下其它脚本保持一致（`--min=` 这种 `--k=v` 风格）
