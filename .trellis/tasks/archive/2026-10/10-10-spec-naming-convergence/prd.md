# spec 命名与语言收敛：backend/frontend → data/ui

## Goal

把 `.trellis/spec/` 的目录名与章节名从 Trellis 种子继承的 `backend/` + `frontend/` 换成
按主题命名的 `data/` + `ui/`（+ 根 `index.md` / `directory-structure.md` / `type-safety.md`），
并把文档标题统一为中文。

**动机是名字本身错了**：Flutter 应用没有前后端，`backend/` 里装的是数据层与 `logic/`，
`frontend/` 里装的是 UI。

## 前置（硬性）

`10-10-spec-link-gate` 必须先落地。理由：本任务波及
`git grep -l "backend/\|frontend/"` → **80 个已跟踪文件**（36 md、32 dart、8 jsonl、2 json、
1 py、1 mdc），其中 `lib/`+`test/` 的注释引用 38 条散在 29 个 dart 文件、spec 内部互链 11 条，
**目前没有任何门禁能发现断链**（`check_readme_tree.dart` 只管 README 的目录树）。

## Requirements

1. **目录改名**（对齐兄弟分支工作树的形态，只读参考 `F:/App/新建文件夹/flutter_app_template/.trellis/spec/`）：
   `backend/*` → `data/*`；`frontend/{component,quality,state-management,localization}-guidelines.md`
   → `ui/*`；`frontend/{directory-structure,type-safety}.md` → 根目录；两份 `index.md` 的职责
   已在 `spec-single-entry` 收敛到根 `index.md`；`frontend/hook-guidelines.md` → `ui/hook-guidelines.md`。
2. **章节名与标题统一中文**：只改**标题**（文档标题与 `##` / `###`）。
   **不改表格表头、代码块内的 `// BAD` / `// GOOD` 标签** —— 它们不参与「章节关键词」引用，
   改动只增 churn 不改可读性（这是对兄弟版做法的有意收窄）。
   **不翻译正文** —— master 的 `backend/*` 英文正文信息量比兄弟版足（key 命名规则、读软写硬、
   drift `part` 约束、`@DriftAccessor` 的真实报错文本都在）。
3. **同步全部引用**：`AGENTS.md`、`.cursor/rules/*.mdc`、`README.md`、`docs/**`、
   `guides/comment-guidelines.md` 里的「层目录不能省（`backend/` / `frontend/`）」约定、
   `tool/prune.dart` 的提示语、以及 `lib/`+`test/` 的 38 条注释引用。
4. **`.trellis/tasks/archive/**` 与 `.pi/skills/trellis-meta/references/**` 不改**：
   前者是历史记录，后者是 Trellis 自带示例文档。

## Acceptance Criteria

- [ ] `.trellis/spec/` 下不再有 `backend/` `frontend/` 目录
- [ ] 链接门禁（`spec-link-gate`）在全仓库绿灯
- [ ] `just verify` 全绿
- [ ] `guides/comment-guidelines.md` 的语言政策与「层目录」约定已按新结构改写
- [ ] 归档任务里的旧路径**不**被改写（历史不动）

## Notes

- 这是 `report.md` §9 未决问题 1 + 2 的合并落地；两项共用同一笔改动成本，必须一次做完，
  分开做会付两遍（章节名变更会断掉同一批 38 条注释引用）。
- 兄弟分支的 `data/` 与 `ui/` 在 `report.md` §3.1 已逐篇判过：**只借结构，不借内容** ——
  它的正文是 Riverpod 口径，且 `data/network-guidelines.md`、`data/error-handling.md`、
  `ui/component-guidelines.md` 都比 master 弱（见 report §7）。

- **`AGENTS.md` 的 `TRELLIS:START/END` 托管块内已被改过一处**（`10-10-spec-link-gate` 把
  Pre-commit 段的门禁枚举换成指针，见该任务）。动手前先确认它是否还在 —— 若已被
  `trellis update` 还原成枚举，按同一口径再换一次（块内文字在模板里本就自相矛盾：
  枚举清单下一行写着「本文件不再逐项维护，内联的清单一定会过时」）。
