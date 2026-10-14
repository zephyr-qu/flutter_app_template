# docs 局部冗余收敛：段落级去重 + ADR-0002 复核

## Goal

`docs/` 5 份文档都健康（无孤儿、无断链），但存在**段落级**重复：同一条信息（门禁口径、崩溃上报接入点、
图标文件缺失、env 密钥）在 2–4 处被不同措辞复述。本任务把这些复述收敛成「一处权威表述 + 其余一句指路」，
并复核 ADR-0002 是否已整体被 spec 覆盖。

判据：**每处信息只有一个权威表述位置**；文档总量下降；链接与章节引用不断。

---

## 背景：与既有决策的关系（必读）

上一轮 `10-11-doc-redundancy`（已归档）的结论与本任务**部分冲突**，必须先摊开：

| 上轮结论 | 出处 | 本任务的关系 |
|---|---|---|
| 跨文档大块重复「几乎不存在」，≥3 行连续块只有 6 行 | `archive/2026-10/10-11-doc-redundancy/prd.md` 事实 ② | **不冲突**：那是「整行连续块」口径；本任务处理「同一事实被不同措辞复述」（句子级） |
| `release-checklist.md` / `optional-additions.md`「内容与 spec 不重复」 | 同任务 `audit.md:60` | **需修正**：§6 与 cross-cutting 的门禁 / 覆盖率 / OSV 语义确有复述 |
| **不删 ADR**（ADR-0002 重叠率 30.8%，但重叠的是「引用示例」；drift 报告判定两条 ADR 在 master 仍有效） | 同任务 `audit.md:58`、`implement.md`「没做的事」 | **已重新决策为 B**（2026-10-14）：删 ADR-0002 并入 spec |

不重复上轮已完结的：`docs/architecture-review.md` 已删、iOS `LaunchImage.imageset/README.md` 已删、
`ui/` 三份 spec 的重复示例收敛已完成。

---

## 已核实事实（本次重查，2026-10-14，均带证据）

### ① `release-checklist.md` §6 复述 cross-cutting 的口径

| 复述内容 | `docs/release-checklist.md` | 权威位置 |
|---|---|---|
| 「覆盖率**不设门禁**，要看数字自己跑 `flutter test --coverage`」 | :121-123 | `cross-cutting.md`「覆盖率」 |
| OSV / `dart pub outdated` 的阻断语义与升级时机 | :126-130 | `cross-cutting.md`「供应链门禁」 |
| `just verify` 是唯一门禁、清单以 justfile 为准 | :115-119 | `README.md` 常用命令表 + `cross-cutting.md` |

且 `.trellis/spec/cross-cutting.md:198-200` 已自己声明分工：**清单管「发版前必须人工确认的事」，
spec 管「每次 push 自动挡住的事」**。§6 抄的正是后者。

### ② 「崩溃上报接入点」近逐字重复

- `docs/release-checklist.md:138`：「`bootstrap.dart` 的 `runZonedGuarded`、`FlutterError.onError`、
  `PlatformDispatcher.onError` 是天然接入点，现在只是打了日志」
- `docs/optional-additions.md:58`：「`bootstrap.dart` 的 `FlutterError.onError`、
  `PlatformDispatcher.instance.onError`、`runZonedGuarded`——**现在只打日志，是天然接入点**」

### ③ 「图标文件缺失」在 4 份文档 + `pubspec.yaml` 共 5 处

`assets/icon/` 目录**不存在**（`ls` 失败，本次核实），`pubspec.yaml:99` 的 `image_path` 指向它：

| 位置 | 性质 | 处置 |
|---|---|---|
| `docs/template-pruning.md:53` | 「占位清单」表格 | **定为唯一权威行** |
| `docs/optional-additions.md:64` | ⚠️ 同一条警告复述 | 改成一行指路 |
| `README.md:111` | 已是指路（「清单见 template-pruning」） | 保留 |
| `.trellis/spec/guides/rename-checklist.md:55` | 改名流程里的操作步骤 | 保留 |

### ④ `.env.example`「密钥别写」三处 —— 低优先

`README.md`（环境与构建）、`docs/release-checklist.md:19`、`docs/template-pruning.md:52`
都在说「它会入库、会打进产物，别写密钥」。三处读者场景不同（概览 / 发版核查 / 裁剪清单），
**可能判为「不清理」**。

### ⑤ 文档类门禁已不存在（决定验证方式）

`justfile` 现有 recipe：`deps / fmt / fmt-check / fix / analyze / analyze-app / analyze-tool /
test / run / build-apk / test-app-lints / verify / codegen / codegen-reset / init`。
**没有** `test-doc-links`、`check-anchors` —— `b8b90f6` 已删（4 工具 + 4 测试 + 3 recipe）。
`verify = fmt-check analyze test-app-lints test`，不覆盖 `.md`。

**后果**：本任务的链接与章节锚点正确性**没有任何自动化兜底**，只能人工 grep 核对。

---

## ADR-0002 处置（已决策）

**决策（2026-10-14，用户选定）：B —— 删 `docs/adr/ADR-0002.md`，把「日期 + 来源」两行并进
`state-management.md` 段尾，清理 `docs/adr/ADR-0001.md:104` 的关联行。**
下表 A / C 仅作为决策记录保留。

### ADR-0002 处置

**支持收敛的证据（本轮新增）**

- **活入链为 0**：`git grep "ADR-0002"` 在 `lib/`、`.trellis/spec/`、`README.md` 下**无任何引用**；
  唯一入链是 `docs/adr/ADR-0001.md:104` 的「关联」一行。
- 实质内容与 `.trellis/spec/ui/state-management.md:107-117`「为什么没有 BaseViewModel」同构
  （三条理由一一对应），且 spec 版本更细（含 `dispose` 失效边界与 `autoDispose` 解法）。
- ADR-0002 自己在「关联」里就写「结论见 state-management.md」。

**支持保留的证据**

- 上轮 `audit.md:58` 判定：重叠的是「引用示例」；结论在 master（GetIt + ViewModel 栈）**仍然有效**。
- ADR 与 spec 是**不同体裁**：ADR 记「什么时候、为什么这么定」（日期 `2026-09-19`、
  来源「架构评估候选 2，评估文档已删除」），spec 记「现在怎么写」。删 ADR 丢掉溯源；
  `docs/optional-additions.md` 的「相关文档」也把 `adr/` 列为独立一类。

| 选项 | 动作 | 规模 | 代价 |
|---|---|---|---|
| **A（推荐）** | 保留 ADR-0002；在 `state-management.md`「为什么没有 BaseViewModel」段尾加**一行反链**；ADR 侧与 spec 重复的三条理由压成一行指路 | 净 +1 行上下 | 无损失；补上 spec → ADR 这唯一缺失的方向 |
| **B（已选）** | 删 ADR-0002，「日期 + 来源」两行并进 spec 段尾；`ADR-0001.md:104` 关联行一并清理 | −65 行 | 丢独立决策记录体裁；推翻上轮结论 |
| C | 不动 ADR | 0 | 冗余保留 |

> 决策依据：活入链为 0 + 内容与 spec 同构 + 溯源只剩两行（可无损并进 spec）。
> 已知并接受的代价：失去独立决策记录体裁；上轮 `10-11-doc-redundancy` 的「不删 ADR」结论被本次推翻。

---

## Requirements

- **R1** 收窄 `release-checklist.md` §6：保留「重跑 codegen」与「`just verify` 全绿」两条**动作**；
  删掉对门禁清单、覆盖率口径、OSV 语义、`dart pub outdated` 四列说明的复述，改为指向
  `cross-cutting.md` 的对应章节。
- **R2** 去重「崩溃上报接入点」：`release-checklist.md:138` 只留 checklist 项本体 + 一句指路到
  `optional-additions.md` 的「崩溃 / 错误上报」行。
- **R3** 收敛「图标文件缺失」：`template-pruning.md:53` 定为唯一权威行；
  `optional-additions.md:64` 改为一行指路（保留「`flutter_launcher_icons` 已在依赖里」这一信息点）。
- **R4**（已定 B）删 `docs/adr/ADR-0002.md`；把「日期 `2026-09-19` + 来源：架构评估候选 2
  （评估文档已删除）」两行并进 `state-management.md`「为什么没有 BaseViewModel」段尾；
  清理 `docs/adr/ADR-0001.md:104` 的关联行。
- **R5**（可选，可判不做）收敛 `.env.example`「密钥别写」：`template-pruning.md:52` 压成一句并指
  `README.md`「环境与构建」；若判断三处读者场景确实不同，则记「不清理 + 理由」。

## Constraints

- 只动 `docs/**`，以及（A / B 选项下）`.trellis/spec/ui/state-management.md` 与 `docs/adr/**`；
  **不改写 spec 正文口径**（B 选项只允许把两行溯源并进 spec 段尾）。
- 不删 ADR-0001（6 处活入链，是 spec 的引用源头）。
- 不动 `.trellis/workflow.md`、`.trellis/agents/**`、`.trellis/workspace/**`（Trellis 托管 / 只增不减）。
- 不动 `.trellis/tasks/archive/**`（历史记录）。
- 不动兄弟分支 `preset/ai-starter`。
- 每处「指路」必须给可点击的相对路径 + 章节名，不留「见上文」式模糊引用。
- 不新增文档、不新建 markdown 说明文件。

## Acceptance Criteria

- [ ] 每条重复事实只剩**一处权威表述**，其余为一句指路（含相对路径 + 章节名）
- [ ] `git grep "ADR-0002"` 的结果与 R4 决策一致（A / C 保留；B 下无残留引用）
- [ ] 所有改动的相对链接目标文件存在，被引用的章节名能在目标文件里 grep 到（人工核对）
- [ ] `just verify` 全绿（不覆盖 `.md`，作为「改完必跑」契约与无副作用证据）
- [ ] 文档总量与逐项改动在 `implement.md` 的「结果」里如实记录（含「没做的事」与理由）
- [ ] 若判 R5「不做」，理由落实到 `implement.md`

## 不做什么

- 不重做上轮 `10-11-doc-redundancy` 的整份文档存废判定（两个文件已处置完毕）。
- 不重写 spec 正文结构，不合并 spec 文档。
- 不为文档改动新建门禁（`b8b90f6` 刚删掉文档类门禁，本任务不反向加回）。
- 不动 `optional-additions.md` 的包选型表（第一、三、五、六节）—— 上轮已判定与 spec 不重复。
