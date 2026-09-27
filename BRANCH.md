# 分支说明

基线分支是 **`master`**（不是 `main`）—— 所有 `preset/*` 都以它为 base。

## 这个仓库怎么分叉

脚手架用「**少数预设分支 + 正交裁剪参数**」提供变体，而不是复制出十几个各自维护的分支
（决策见 `.trellis/tasks/archive/2026-09/09-22-scaffold-branch-strategy/prd.md`）：
**模块组合用预设（数量固定），横切关注点用参数（不乘法）**。

| 分支 | 内容 | 状态 |
| --- | --- | --- |
| `master` | 基线：signals + `flutter_hooks` + get_it/injectable | 现行 |
| `preset/ai-starter` | Riverpod 3.x 栈 + 单包化 + 分析插件门禁 + 生成物不入库 | 已建 |
| `preset/minimal`、`preset/local-only`、`preset/online-only`、`preset/offline-first`、`preset/empty-feature` | 模块组合的其它预设 | 未建（只在 PRD 里规划） |

正交裁剪轴：`--l10n=multi|single`（`just prune`，当前唯一实现的轴）。

## 两条硬约定

1. **`preset/*` 与 `master` 是兄弟分支，不回流**。状态管理栈不同的分支无法互相合并
   （Riverpod 与 signals 会互相覆盖），所以预设只往前走：`master` 的改动不会自动进入预设，
   预设的改动也不会 merge 回来。要跨分支搬一个**与栈无关**的做法时，手工移植并各自验证。
2. **每个分支 / 轴的差异都要留档**（spec 或本文）。差异靠口口相传时，下一个人一定会踩。

## `master` 的现状

- 状态管理：`signals_flutter` + `signals_hooks` + `flutter_hooks`（ViewModel 是 `@injectable` 的 `factory`）
- 依赖注入：`get_it` + `injectable`（装配在 `lib/di/`）
- 单包结构：应用代码全在 `lib/` 下；`packages/` 只放独立工具包 `app_lints`
- 单一门禁入口：`just verify`（清单见根 `justfile`）
- 生成物**不入库**（`.gitignore` 排除），clone 后先 `just codegen`
- 单语言中文（多语言已被 `tool/prune.dart` 裁掉，见 [localization.md](.trellis/spec/frontend/localization.md)）
