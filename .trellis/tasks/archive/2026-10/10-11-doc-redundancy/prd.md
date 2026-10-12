# 盘点并清理冗余文档

## Goal

仓库有 35 份非第三方、非归档的 `.md`。本任务先产出**可勾选的冗余清单**（含证据与收益/代价），
再由用户勾选决定删哪些 —— 不先斩后奏。判定「冗余」需要人的取舍（例如 spec 里的重复示例可能是刻意的），
所以本任务的产出物是**报告 + 勾选后的执行**。

## 已核实的事实

见 [audit.md](./audit.md)。三条关键：

| # | 事实 | 证据 |
|---|---|---|
| ① | 全仓库**唯一的失效快照**是 `docs/architecture-review.md`（222 行）：自认「不是现行规范」，引用的两个 `tool/` 脚本**已退役**，入链只剩 ADR 的「关联候选」 | 文件头 11–14 行；`git grep -n architecture-review` |
| ② | **跨文档大块重复几乎不存在**：≥3 行连续块只有 **6 行**；所谓「34 处重复行」几乎全是单行代码片段 | 切块集合交集脚本（见 audit.md） |
| ③ | `ios/.../LaunchImage.imageset/README.md`（11 行）**没有任何文档引用**；先前的 5 条「入链」是 `LaunchImage` 同名词在 storyboard / `Contents.json` 里的误匹配 | `git grep -n LaunchImage` |

## 处置（已勾选并执行 —— 结果见 [implement.md](./implement.md)）

| 编号 | 动作 | 规模 | 建议 |
|---|---|---|---|
| ① | 删 `docs/architecture-review.md` + 改 ADR-0001/0002 各 2 处链接 | −222 行 | 做 |
| ② | 删 `ios/.../LaunchImage.imageset/README.md`（可选：一句话并进 `optional-additions.md:63`） | −11 行 | 做 |
| ③ | 收敛 `ui/` 三份 spec 的 `ArticleListPage` 示例为「一处 + 两处指路」 | 34 行 | 不做（收益最低，伤文档自足性） |

## Acceptance Criteria

- [x] `audit.md` 给出每条候选的**证据**（入链、快照标记、重复行数）与**代价**，可勾选
- [x] 勾选后的删除**不留断链**：`just verify`（含 `test-doc-links`）全绿、`just check-anchors` 无新增告警
- [x] 删除文档中若含 spec 引用（`data/xxx.md` 形态），同步确认引用方已改
- [x] 明确列出「不清理」清单及理由（Trellis 托管文件 / 日志 / 仍有效的 ADR / 两个分工不同的索引）
- [x] **不动** `.trellis/workflow.md`、`.trellis/agents/**`、`.trellis/workspace/**`（Trellis 托管或按设计只增不减）

## 不做什么

- 不改写 spec 正文（本任务只处理「整份文档是否冗余」，不重写内容）。
- 不动兄弟分支 `preset/ai-starter`。
- 不删 ADR（drift 报告已判定其在 master 仍有效）。
