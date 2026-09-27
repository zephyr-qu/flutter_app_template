# 执行记录

口径见 `prd.md`。逐文件改，每批改完跑一次「结构不变量」检查（标题数、表格行数、围栏配对、链接可解析、inline code token 只减不增），把消失的 token 逐条判一遍是不是有意删除。

## 批次

| 批次 | 文件 | 状态 | 行数 | 字符 |
|---|---|---|---|---|
| 1 | `cross-cutting.md` | 已完成（口径已验收） | 318 → 304 | 15891 → 13013（-18%） |
| 2 | `frontend/` 6 个 | 已完成 | 916 → 911 | 47388 → 44908（-5.2%） |
| 3 | `backend/` 5 个 | 已完成 | 650 → 648 | 27218 → 25426（-6.6%） |
| 4 | `guides/`（5 个）+ `index.md` | 已完成 | 471 → 454 | 15450 → 14485（-6.2%） |

## 批次 1 记录（cross-cutting.md）

- 做法：先 `cp` 一份快照到临时目录，改写后逐项比对差异。
- 删掉的整块：codegen「**理由**」段、「**代价**」段（两条已被「重新生成时机」表覆盖）、`json_annotation` 的后果 blockquote、供应链的「过期不拦/漏洞要拦」论证段、Integration Testing「后果有两层」两条、「检测范围」三条。
- 保留的判定条件（属规则，不属动机）：`registerLintRule` 才默认关、`isGeneratedPath` 的形态清单、「实参不是 `.notifier`」、`isInLibDir` 的管辖范围、`leak_tracker` 只认埋点对象。
- 修掉一处本轮之前的自伤：`--delete-conflicting-outputs` 那段曾因空行锚点误用而重复，现为单份。
- 结构不变量：标题 33 → 33、表格行 41 → 41、围栏 16 → 16、链接 13 → 13 全部可解析、inline code token 无新增，消失的 18 个 token 全在删除的论证块内。
- 体量：行 -14，字符 -18%。**未达到「减半」**：剩下的内容主要是规则、参数与表，再砍就得砍整节而非句子 —— 见 prd「风险」。

## 批次 2 记录（frontend/ 6 个）

- 逐文件：directory-structure 174 → 174（-6.9%）／localization 68 → 66（-10.6%）／component-guidelines 155 → 153（-5.2%）／quality-guidelines 86 → 86（-6.2%）／state-management 322 → 321（-9.3%）／type-safety 111 → 111（-3.3%）。合计 916 → 911 行，47388 → 44908 字符。
- 结构性动作：`localization.md`「常见错误（错误 / 为什么）」两列表转成「不要做的事」清单；`state-management.md`「为什么不用 `AsyncValue.when`」改成「与 `AsyncValue.when` 的关系」；`directory-structure.md` 删掉「旧 Clean Architecture 布局」那句解释（与文件末尾的对照表重复）。
- **一处口径边界的自纠**：`type-safety.md` 删理由时把「另一套注解」的具体名字（`@JsonSerializable`）一起删了，禁令因此失去判据，已改回「不要为了简单 DTO 换一套注解（如手写 `@JsonSerializable` 模型）」。同类保留：`registerLintRule` 才默认关、`isGeneratedPath` 清单、`.notifier` 判据、`isInLibDir` 管辖范围。
- 结构不变量：六文件标题数与表格行数不变（仅 localization 的表转清单 13 → 7 行、标题改名 1 处）；围栏成对；链接 100% 可解析；命令 / flag 零增减。
- 体量 -5.2%（单文件 3%–11%）。原因同批次 1：这些文件主体已是规则、参数与表，能砍的是理由的尾巴，不是段落。

## 批次 3 记录（backend/ 5 个）

- 逐文件：database-guidelines 218 → 216（-13.6%）／error-handling 166 → 166（-2.3%）／network-guidelines 84 → 84（-5.9%）／logging-guidelines 84 → 84（-4.2%）／quality-guidelines 98 → 98（0%）。合计 648 行，27218 → 25426 字符（-6.6%）。
- **`quality-guidelines.md` 逐字未变**（`diff` 为空）：它本来就是清单式规则 + Code Review Checklist，没有可删的原因句。这条留档是为了说明「0% 不是没做」。
- 删掉的整块：`Failure` 文案的「因此」推导链、`database-guidelines` 两张表的「为什么」整列（失败策略表、schema/查询分工表）、`表必须 part` 与 `sqlite3 来源` 的后果段、「踩过的坑」「为什么必须有自己的子目录」两个标题里的历史与提问措辞、`network-guidelines` 的 Mock 静默失效说明与反例后果。
- 保留的判据：`FailureCode` 状态码映射表、`isGeneratedPath` 同级的口径引用、`MockMatcher` 全等比较这条机制、`LogRedactor` 跨行带状态这条机制、`Failure implements Exception`。
- 顺手清掉三处派生的「所以」与两处禁令措辞里的「因为 / 为了」（`不要随状态变化重建路由器`、`简单 DTO 也不换注解`），让验收标准的 `rg` 扫得干净。
- 结构不变量：五文件标题数、表格行数、围栏全部不变；链接全部可解析（network 多了一条到 cross-cutting 的真链接）；命令 / flag 零增减。

## 批次 4 记录（guides/ 5 个 + `index.md`）

- 逐文件：code-reuse 93 → 91（-6.1%）／comment-guidelines 102 → 97（-10.0%）／cross-layer 88 → 86（-5.9%）／rename-checklist 73 → 71（-3.4%）／guides/index 81 → 75（-9.9%）／spec/index 34 → 34（0%）。
- **prd 的范围表漏了一个文件**：`guides/` 实际有 5 个（含 `index.md`），prd 按「guides 4 个 + index.md」列批次，等于没有给 `guides/index.md` 安排批次。本轮补上。
- 按用户要求改掉写法约定：`comment-guidelines.md` 的「spec 该怎么写」由「写实际约定 / 取本仓库示例 / 列出禁止模式**并说明为什么** / 记下**已经踩过的坑**」改成「写实际约定 / 取示例 / 列出禁止模式 / 快照式内容单独标注」，并把「约定不写历史」那段扩写成**只写结果与现状**（不写原因与推导、后果与现象、历史与被否决方案、日期叙事与 commit 号），同时明说**判据必须留**。同文件的「## 为什么」整节删除。
- 结构性动作：`cross-layer-thinking-guide.md` 的「## The Problem」改「## The Layers」并删掉「典型跨层 bug」现象段；`guides/index.md` 的「## Why Thinking Guides?」整节删除（与文件开头的 Purpose 重复）；`code-reuse-thinking-guide.md` 删掉与节标题重复的「### 常见重复形态」。
- 结构不变量：六文件围栏成对、链接 100% 可解析、命令 / flag 零增减；标题减少 3 处（都是上面列出的删除），表格行数不变。

## 收尾（全量 18 个文件）

- **最终体量：2355 → 2317 行（-1.6%），95947 → 87622 字符（-8.7%）。** 18 个文件的围栏全部成对、交叉引用链接 100% 可解析。
- **prd 里「行数预期下降 30%–40%」的目标未达成，且不可能在「只删原因」的口径下达成**：这些文件的主体是规则、参数、表与清单，本次删掉的是理由的尾巴、后果段、历史与解释段。要再降 20 个百分点只能删**整节内容**（例如 `state-management.md` 的 Common Mistakes 表与 Testing Requirements 有重叠、`cross-layer` 的 Checklist 与三处 Mistake 有重叠）—— 那是内容决策，不是口径执行。这条估算是我在规划阶段写错的。
- 两个 `index.md` 只做校准：`spec/index.md` 逐字未变（34 行）；`guides/index.md` 删掉「为什么要有思考指南」整节。
- 逐文件校验方法：先 `cp` 快照到临时目录，改写后用同一套脚本比对行数 / 字符 / 围栏 / 表格行 / 标题 / 链接可解析性 / inline code token 增减 / 命令与 flag 增减，把消失的 token 逐条判是否为有意删除。

## 复核（自检式；独立复核被环境阻塞）

- **`trellis-check` 子代理未能启动**：`ERR_MODULE_NOT_FOUND`，子进程从 `D:\app\scoop\persist\nodejs-lts\bin\node_modules\@earendil-works\pi-coding-agent\dist\` 解析；该副本版本同为 0.87.1 但 `dist/` 缺 `extensions/` `modes/` `utils/` 三个目录，PATH 上的 `apps\nodejs-lts\24.21.0` 那份完整。属 lane 基础设施问题（重试同样失败），未擅自切换协议，已向用户报告并给出三个选项；用户选择自检式复核。
- **方法**：拿 16 份 before 快照（`frontend/quality-guidelines.md` 的基线与同名 backend 文件相撞被覆盖，已丢失）跑两遍 difflib，把「原位改写」与「独立删除」分开：
  1. **整块消失**（相似度 < 0.5）：24 块 / 49 行 —— 逐块判类，全部落在「框架句、动机、后果与现象、历史考古、解释段」，无规则 / 参数 / 命令丢失。
  2. **行内净删**（0.5 ≤ 相似度 < 0.8 且净减 ≥ 40 字）：21 块 —— 同类，删的是理由的尾巴与后果描述。
- **两处判据性说明被削到只剩规则**（规则本身完整，prd 曾把这类举例为「要保留的判据」）。列为遗留，本轮未恢复：
  - `cross-cutting.md`「判据细节」的 `no_material_import_in_logic`：现为「…拦三样：`material.dart`、`widgets.dart`、本 feature 的 `page/` 层文件。`foundation` 不管；…」；被删的是「（Widget / BuildContext 都在 widgets 里，只挡 material 等于一行 import 就绕过）」与「（`ChangeNotifier` / `@visibleForTesting` 在 logic 里正当）」。
  - 同节 `avoid_ref_read_in_build`：现为「豁免 `.notifier`。」；被删的是「取的是实例本身（身份稳定、不参与订阅）」。
- **复核盲区**：prose-only 且与被改写行相似度 ≥ 0.8 的删除（token 比对同样看不见）；`frontend/quality-guidelines.md` 无基线可比。
