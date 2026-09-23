# preset/ai-starter：Riverpod 主流栈 + AI 协作契约

## Goal

产出 `preset/ai-starter` 兄弟分支。它要同时满足两件事：

1. **依赖用主流生态**——换成 AI 训练语料最丰富、社区示例最多的方案，让 AI 写得更顺手
2. **仓库面向 AI 自足**——任何 AI 工具打开即可在边界内产出符合规范的代码，并自己完成验证

## 前置依赖

**必须先完成 `09-22-extract-app-core`**。否则 27 个共有文件要在两个栈里各写一遍，且迁移完再抽包要返工两次。

## Requirements

### 依赖替换

| 能力 | master（现状） | ai-starter |
|---|---|---|
| 状态管理 | signals / signals_flutter / signals_hooks | **Riverpod 3.x** |
| 页面组合 | flutter_hooks + HookWidget | `ConsumerWidget` / `ConsumerStatefulWidget` |
| 依赖注入 | get_it + injectable (+generator) | **Riverpod provider**（`lib/di/` 整体消失） |
| 主题 | flex_color_scheme | **保留、不动**（见下方「范围调整」） |
| 路由 | auto_route | auto_route（**保留**） |
| 网络 / 序列化 / 数据库 / l10n | dio+retrofit / freezed+json_serializable / drift / ARB | **全部保留** |

### 示例收敛

删掉 `features/article`、`features/demo` 的**业务内容**，但保留一个 `features/sample/` 三件套金标准（`page/` + `logic/` + `data/` + **对应测试**），作为 AI 唯一照抄对象。

### 范围调整（2026-09-22，实测后）

原计划把主题从 `flex_color_scheme` 换成官方 `ColorScheme.fromSeed`。**实测后撤掉这一条**：

- `flex_color_scheme` 现在只存在于 `packages/app_core`（pubspec + `theme/app_theme.dart` +
  `app_color_scheme.dart`），根工程一处都没引用——换主题 = 改**共有包**
- 而共有包「两个分支完全一致」正是 `09-22-extract-app-core` 花整个任务换来的东西。
  为了一个与状态管理正交的主题库把它拆掉，收益为负
- `flex_color_scheme` 本身是主流库、社区示例充足，不违背本分支「AI 语料丰富度」的判据

结论：**本分支主题保持现状**，`packages/app_core` 零改动（除测试）；换栈范围只限根工程的
状态管理 / DI / 页面组合三件事。`BRANCH.md` 里要写明这一条，免得后来者以为漏做了。

### spec 重写（成败关键）

`.trellis/spec/frontend/` 下三份是**专为 signals + hooks 写的**，必须按 Riverpod 重写：

- `state-management.md`（`runAsync` / `AsyncSignal` / dispose 边界 → Notifier / AsyncNotifier / `ref.watch`）
- `hook-guidelines.md`（hooks 范式 → Consumer 范式，或删除）
- `quality-guidelines.md`（禁止模式里的 `getIt` → `ProviderContainer`）

另需标注 `docs/adr/ADR-0002.md` 与 `docs/architecture-review.md`：其结论**仅对 master（signals 栈）成立**。

### AI 协作契约

`AGENTS.md` 升级，包含：必读三份 spec、`## 改完必跑` 命令块、Riverpod 版禁止模式速查、`features/sample/` 金标准指向、DoD。

## Acceptance Criteria（DoD）

- [ ] **新会话 AI 在无人解释下新增一个 feature，并通过全部六道门禁，且结构与 `features/sample/` 一致**（这条不达标则本任务未完成）
- [ ] `grep -rE "signals" lib/` 为空；`grep -rE "getIt|GetIt\.I" lib/` 为空
- [ ] `lib/di/` 目录已删除，`ProviderScope` 已接在 `runApp` 外层
- [ ] `.trellis/spec/frontend/` 三份已按 Riverpod 重写，且与代码一致（不是照抄旧文换名词）
- [ ] `tool/check_boundaries.dart` 的 service-locator 规则已改为 Riverpod 等价约束（禁 `ProviderContainer` 手动 new）
- [ ] 六道门禁全绿；`check_readme_tree` 的目标树已更新（删 `lib/di/`、加 `ProviderScope`）
- [ ] 分支上有 `BRANCH.md`，写明「基于 master、换栈内容、不回流的原因」

## Notes

- **兄弟分支，不回流 master**：Riverpod 与 signals 无法互相合并，强行回流会互相覆盖
- 保留 auto_route 的理由：它本身已是主流，换 go_router 要重写路由 + 守卫 + 全部 `@RoutePage`，收益不足
- 参考历史任务 `07-09-refactor-mainstream-signals`——当时把 signals 当作「主流」重构进去。本次是同一问题的第二次评估，判据（AI 语料丰富度 + 社区示例量）已写死，避免第三次反复
