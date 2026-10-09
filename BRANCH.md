# 分支说明

基线分支是 **`master`**（不是 `main`）。

## 这个仓库只有两条分支

| 分支 | 内容 | 状态 |
| --- | --- | --- |
| `master` | signals + `flutter_hooks` + get_it/injectable | 现行 |
| `preset/ai-starter` | Riverpod 3.x + provider 化装配 + 示例收敛为 `features/sample/` | 现行 |

**不再新增 `preset/*` 分支。** 「更小的骨架 / 更少模块」这类需求由正交裁剪参数承担，
不要复制分支：多一条分支就多一份要各自维护、各自验证的代码，而它们之间又无法互相合并（见下）。

正交裁剪轴：`--l10n=multi|single`（`just prune`，当前唯一实现的轴）。

## 两条硬约定

1. **两条分支是兄弟关系，不回流**。状态管理栈不同（signals 与 Riverpod 会互相覆盖），
   所以各自只往前走：`master` 的改动不会自动进入 `preset/ai-starter`，
   `preset/ai-starter` 的改动也不会 merge 回来。要跨分支搬一个**与栈无关**的做法时，
   手工移植并各自验证。
2. **每个分支 / 轴的差异都要留档**（写进本文或 `.trellis/spec/`）。差异靠口口相传时，
   下一个人一定会踩。

## `master` 的现状

- 状态管理：`signals_flutter` + `signals_hooks` + `flutter_hooks`（ViewModel 是 `@injectable` 的 `factory`）
- 依赖注入：`get_it` + `injectable`（装配在 `lib/di/`）
- 单包结构：应用代码全在 `lib/` 下；`packages/` 只放独立工具包 `app_lints`
- 单一门禁入口：`just verify`（清单见根 `justfile`）
- 生成物**不入库**（`.gitignore` 排除），clone 后先 `just codegen`
- 单语言中文（多语言已被 `tool/prune.dart` 裁掉，见 [localization.md](.trellis/spec/frontend/localization.md)）

## `preset/ai-starter` 的现状

- 状态管理：`flutter_riverpod` 3.x + `riverpod_annotation`（`riverpod_lint` / `riverpod_generator` 在 dev）
- 依赖注入：provider 化装配（`lib/app/providers.dart`、`lib/core/providers.dart`、feature 内的 `*_providers.dart`）——**没有** `lib/di/`
- 示例收敛：只有 `features/sample/` 一个 feature 承担 `page` / `logic` / `data` 三件套金标准；
  `auth` / `article` / `demo` 都不存在，`core/models/` 与网络层的认证部件
  （拦截器 / 令牌刷新 / `TokenStore`）随之消失，`core/data/storage/` 只剩 `FileStorage`
- 主题仍用 `flex_color_scheme`；规则集仍用 `very_good_analysis`
- 门禁：`just verify` = `fmt-check` + 两步 `dart analyze --fatal-infos` + 插件规则测试 + `flutter test`；
  **没有**目录树一致性那道（该分支的 `tool/` 不含 `check_readme_tree.dart`）
- 无 `lib/l10n`（未接入 ARB）
