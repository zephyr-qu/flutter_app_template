# 对比兄弟分支 spec 重构，产出可移植清单报告

## Goal

`preset/ai-starter` 分支的工作树（`F:/App/新建文件夹/flutter_app_template`）里有一批**未提交**的
`.trellis/spec/` 重构，把按「后端/前端」切分的规范重组成按**主题**切分的结构。本任务把两侧文档差异
摸清，产出一份报告：**哪些能原样移植到 master，哪些必须按 Signals 栈改写，哪些不适用**。

本任务**不改任何本地文档**——报告是唯一交付物；是否落地由后续任务决定。

## 背景事实（已核实）

| # | 事实 | 证据 |
|---|---|---|
| ① | 「兄弟分支」= `preset/ai-starter`，工作树在 `F:/App/新建文件夹/flutter_app_template`，HEAD `14fe982` | `git worktree list` |
| ② | 两分支在 `4150ee6` 分叉后**互不回流**（Riverpod 与 Signals 无法合并） | `09-22-scaffold-branch-strategy/prd.md` 决策 ② |
| ③ | 兄弟工作树有**未提交**改动：改 `index.md`/`cross-cutting.md`/5 个 guides；新增未跟踪 `data/`、`ui/`、`type-safety.md`、`directory-structure.md` | `git status --short` |
| ④ | master 的 spec 是 `backend/` + `frontend/` 二分 + `cross-cutting.md` + `guides/`，**没有根 `spec/index.md`** | 本仓库 `.trellis/spec/` 实测 |
| ⑤ | 兄弟分支是 **Riverpod** 栈，master 是 **Signals + ViewModel** 栈 | 同 ②，及两侧 `frontend/state-management.md` |

> 前提修正：`F:/App/zephyr_*` 不是「兄弟项目」，是从本仓库克隆出去的下游应用（各有独立 `.git`），
> 其 spec 层比 master **旧且小**，不是本次的取料对象。

## Requirements

### 对比范围

1. `.trellis/spec/` —— 重点。逐文件列出：只在兄弟侧存在 / 两侧都有但内容不同 / 只在 master 存在。
2. `AGENTS.md`、`README.md`、`BRANCH.md` —— 读者面与协作契约的差异。
3. `docs/` —— `adr/`、`architecture-review.md`、`optional-additions.md`、`release-checklist.md`。

### 每条差异必须给出判定

| 判定 | 含义 |
|---|---|
| **可原样移植** | 与状态管理栈无关，master 直接可用（如目录结构、注释、界边界规则表述） |
| **需改写后移植** | 思路可用，但正文绑定 Riverpod/`AsyncValue`，须换成 Signals 口径 |
| **不适用** | 依赖 Riverpod 或兄弟独有结构（如 `data/` 与 master `backend/` 的映射需人工定夺） |
| **反向：master 更好** | master 已更完整，兄弟侧是精简或退化，明确写"不取" |

### 约束

- **只读**：不得修改兄弟工作树的任何文件（那是用户正在进行的未提交工作）。
- 报告中的结论必须有可复核的依据（文件路径 + 行号或 diff 片段），不写"看起来更好"。
- 不评估代码，只看文档层。

## Acceptance Criteria

- [ ] 报告落在 `.trellis/tasks/10-10-spec-drift-vs-preset-ai-starter/report.md`
- [ ] `.trellis/spec/` 下**每一个**文件在报告中都有归属（三态之一 + 判定），无遗漏
- [ ] 每条「可原样移植 / 需改写后移植」给出具体落点（改哪个文件、动哪一节）
- [ ] 明确列出「不取」清单及理由，避免后续误抄
- [ ] 兄弟工作树 `git status` 与调查前一致（证明只读）
- [ ] 报告含一句总结：值得移植的 Top 3 与各自成本

## Notes

- 本任务不收 `design.md`：交付物是只读分析报告，没有需要落地的架构设计；
  对比维度与判定规则写在 `implement.md`。
- master 的 `.trellis/tasks/archive/` 内 prd 有兄弟分支已删的版本，可作为各自分支历史的旁证。
