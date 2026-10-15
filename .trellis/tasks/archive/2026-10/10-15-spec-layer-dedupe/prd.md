# 文档层精简：经审计后收窄

## Goal

用户要求对"文档/规范层"（`docs/` + `.trellis/spec/`，24 份 3816 行）做精简优化。开工前审计发现：
**这一层已被连续多轮专职任务清理过，最初设想的四处目标里三处有既有决策覆盖或已完成。**
本任务因此从"大幅精简"收窄为"记录审计结论 + 处理残余 12 行"（R1 + R2，2026-10-15 用户确认）。
**审计结论本身是主要产物**：它解释了这一层为何无需再精简，以及哪些"重复"其实是设计。

## 审计测量（本次可复现）

按行类型拆解 24 份文档（脚本口径见 Notes）：

| 类型 | 行数 | 占比 |
|---|---|---|
| 空行 | 1050 | 27.5% |
| 代码块 | 880 | 23.1% |
| 列表 | 794 | 20.8% |
| **散文** | **488** | **12.8%** |
| 表格 | 348 | 9.1% |
| 标题 | 256 | 6.7% |

**只有 12.8% 是散文** —— 这个层里几乎没有可挤的"水词"，它已主要是代码样例、列表与表格。
"删字造句"式精简的天花板在 3–5%。

## 已核实事实

### 一、最初设想的四项目标，三项不成立

| # | 我的初始判断 | 审计结论 | 证据 |
|---|---|---|---|
| ① | `spec/index.md` 把同一份文件索引列了两遍（20-31 清单 + 34-80 索引表），约 35 行自重复 | **不成立：这是设计** | `10-10-spec-single-entry/prd.md:94` 验收项明写"含「开工前必读」「完成前自检」「索引表」三块"；`10-10-spec-report-leftovers/prd.md:35` 还专门核对过两块收录一致（"spec 共 20 篇，索引无遗漏"）；`10-11-doc-redundancy/audit.md:60` 把 `spec/index.md` 列入"明确不清理"。两块是两种查法（任务优先 vs 浏览），不是重复 |
| ② | UI 三份 spec 的 `ArticleListPage` 样例"被复制了 4 份"，应收敛 | **已处理过，且残余被明确决定保留** | `10-11-doc-redundancy` 已收敛（`hook-guidelines` 144→131、`quality-guidelines` 132→120，三对重合 26→10 行）；其 `implement.md` 记录"再收敛就等于删掉该文档"。本次复查确认三处是**变体**：`component-guidelines` 是完整骨架，`hook-guidelines` 已明写"只列与 hook 有关的部分，完整骨架见 component-guidelines"，`state-management` 是注入点/生命周期视角 |
| ③ | 文档层没有门禁，是漂移的根因 | **不成立：昨天刚按决定删掉** | `b8b90f6`（2026-10-14）删 4 工具 + 4 测试 + 3 recipe，共 −1803 行（`check_doc_links` / `check_doc_anchors` / `check_readme_tree` / `generated_paths`）；`10-14-docs-redundancy-convergence/prd.md:149` 明写"不为文档改动新建门禁（`b8b90f6` 刚删掉文档类门禁，本任务不反向加回）" |

### 二、过去一个月针对文档层的专职任务（归档）

`10-10-doc-anchor-report`、`10-10-spec-link-gate`、`10-10-spec-naming-convergence`、`10-10-spec-single-entry`、
`10-10-spec-report-leftovers`、`10-11-doc-redundancy`、`10-11-readme-slim`、`10-14-docs-redundancy-convergence`。
**文档层是这个仓库最被主动维护的部分**，不是被忽视的部分。

### 三、本次仍成立的残余（未被任何既有决策覆盖）

| # | 位置 | 内容 | 规模 |
|---|---|---|---|
| R1 | `.trellis/spec/directory-structure.md:225-232` | 「与旧结构的区别」对照表（`application/`→`logic/`、`domain/`+`data/`→`data/`）。同一"已迁走旧 Clean Architecture 布局"的事实已在同文件 `:55` 表述；这里是第二处表述 + 一张迁移映射表 | 8 行 |
| R2 | `.trellis/spec/index.md:27` | 「完成前自检」里内联枚举七条 lint 规则（第 4 处枚举；`cross-cutting.md` 是权威） | 4 行 |

**R2 的处置已拍板（2026-10-15，用户选择「R1 + R2 都做」）**：这**明确反转**了
`10-11-readme-slim/implement.md:19` 记录的落点决定（当年把 README 的"7 条 lint 规则表"迁到
"`cross-cutting.md` + `spec/index.md` 自检项"）。反转理由是 `guides/comment-guidelines.md:114` 的反枚举约定
（"枚举会过期，指针不会"）：规则清单的唯一权威留在 `cross-cutting.md`，自检项只判断边界有没有破并指路。

### 四、明确出界（有既有决策，不在本任务内）

- `spec/index.md` 三块结构、UI spec 的代码样例残余、`docs/optional-additions.md` / `docs/release-checklist.md` 的分工 —— 见上表。
- `docs/adr/ADR-0002.md` 的缺失是 **2026-10-14 的有意删除**（`10-14-docs-redundancy-convergence` 决策 B：删 ADR-0002，
  把 dispose 边界条件并入 `state-management.md`），不是断链。
- 文档类门禁的增删 —— 见事实 ③。
- `docs/release-checklist.md` §1 的逐项复述（勾选项需自足）、8 处 `just verify` 指针（`comment-guidelines.md:114` 定为约定）。

## Requirements

- **R1**：删掉 `directory-structure.md`「与旧结构的区别」整节（含映射表），**不建 ADR**。两旁证据：
  "已迁走旧 Clean Architecture"的事实已在同文件 `:55` 表述（并警告别处引用它即过期）；表里唯一带约定的行
  "必须写 repository 接口 → 按需"已在 `:106`「### 4. Repository 接口按需使用」独立成节。`docs/adr/` 只放
  架构决策（ADR-0001 头部即声明一次性快照已删、结论以本 ADR 为准），目录改名映射不属此类。
- **R2**：`spec/index.md:27` 的七条内联枚举改为指向 `cross-cutting.md`「架构边界与代码形态」（反转决定见上）。
- **R3**：本次审计结论（技术事实、测量、既有决策索引）留在本任务，作为"文档层为何不再精简"的可查依据。

## Acceptance Criteria

- [ ] AC1：`directory-structure.md` 中"已迁走旧 Clean Architecture"这一事实只有一处权威表述；文件行数下降且无信息丢失。
- [ ] AC2：文档内所有指向 `directory-structure.md` / `ADR` 的相对链接仍可解析（`grep` 复核）。
- [ ] AC3：`index.md` 不再内联枚举七条规则名，改为指向 `cross-cutting.md`「架构边界与代码形态」；`just verify` 全绿。
- [ ] AC4：审计结论与三处"不成立"的判断（含各自的归档证据路径）记录在本文件或本任务产物中。

### 实施后复核发现（2026-10-15，check 代理独立复核）

- **被删表里有三行事实是全仓唯一的**：`application/`→`logic/`、`domain/`+`data/`→`data/`（合并）、`page/` 不变。
  复核逐条比对后确认这三行只在被删的映射表里出现过。**决定接受删除**：它们是历史改名映射而非现行约束，
  git 历史可回溯，且对派生项目读者无意义（新项目既无旧布局也无迁移史）。
  → AC1 的「无信息丢失」按**现行约束**口径成立；按**逐字事实**口径丢了 3 行，此处如实记录，不粉饰。
- **未修、建议另立任务**：`index.md:66` 索引表行仍写死「（`packages/app_lints` 插件，七条规则）」，同类计数
  还散在 `README.md:26`、`.cursor/rules/project-conventions.mdc:27`、`analysis_options.yaml:44`、
  `cross-cutting.md:14` / `:47`、`test/tool/lint_wiring_test.dart:193`、`packages/app_lints/test/rules_test.dart:5`。
  无门禁覆盖（`lint_wiring_test` 只核 `cross-cutting.md` 规则表 ↔ 代码），加第 8 条规则时静默过期。
  本次不动（R2 精确限定 `:27`），避免补丁式改一处。
  依据：`guides/comment-guidelines.md:83`「快照式内容要单独标注」已把「数量断言 / 枚举式清单」列为会静默过期的内容。

## Notes

- 测量口径：按行首形态分类 —— 代码围栏内计 `code`；空行计 `blank`；`#` 计 `heading`；`|` 计 `table`；
  `-` / `*` / `>` / `1.`–`9.` 计 `bullet`；其余计 `prose`。
- 本任务的判断原则：**有既有决策覆盖的项不动**，除非用户明确重新拍板。归档任务里的决定与新判断冲突时，
  写进 Open Questions 而不是默默执行。
- 本任务定为 **lightweight**（PRD-only，不写 `design.md` / `implement.md`）：改动为 2 文件共 12 行，
  不触运行时行为、不涉跨层契约与数据流。
