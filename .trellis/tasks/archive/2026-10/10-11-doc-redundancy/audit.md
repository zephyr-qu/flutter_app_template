# 冗余文档盘点

> 盘点范围：`git ls-files '*.md'` 去掉第三方（`.agents/` `.pi/` `.cursor/` `.commandcode/`）、
> Trellis 归档（`.trellis/tasks/`）与开发者日志（`.trellis/workspace/`），共 **35 份**。
> 方法：入链统计、快照标记扫描、跨文档重复行/重复块比对。所有数字可复现（脚本见本文件末尾）。

## 结论先说

- **大块重复几乎不存在**：跨文档 ≥3 行连续块只有 **6 行**（`component-guidelines` ↔ `hook-guidelines`）。
- 名义上「34 处重复行」几乎全是**单行代码片段**（同一段 `useMemoized(...)` 横跨四份 spec）。
- 真正的「冗余文档」（内容已被取代/自认失效）**只有 1 份**：`docs/architecture-review.md`。
- 另有 1 份**无人引用的上游样板**：`ios/.../LaunchImage.imageset/README.md`。

## 候选清单（勾选后执行）

### ① `docs/architecture-review.md` — 222 行，内容已失效 · 建议删

| 证据 | 内容 |
|---|---|
| 自认 | 开头：「**本文是当时（一次架构评审）的快照，不是现行规范。**」并声明 `tool/check_boundaries.dart` / `tool/check_conventions.dart` **已退役**（七条规则改由 `packages/app_lints` 插件实现） |
| 入链 | 只剩 2 处，且都是 ADR 的「关联候选」：`ADR-0001.md`（2 次）、`ADR-0002.md`（2 次） |
| 已结案 | 归档的 drift 报告（`10-10-spec-drift-vs-preset-ai-starter/report.md:267`）判定：`architecture-review.md` 222 行「**已删**（在 `preset/ai-starter` 侧），不适用（`$L` 的候选清单已由 ADR 结案）」 |
| 重合度 | 全仓库最低（1.4%），即它记录的判断**没有被任何现行文档吸收** |
| 最后改动 | `280627f`（2026-10-10）—— 只是被锚点工具顺手改了一处链接，不是内容更新 |

**处置**：删文件 + 改 `ADR-0001` / `ADR-0002` 各 2 处链接（「关联候选」改成文字描述，保留决策来源的可追溯性）。

### ② `ios/Runner/Assets.xcassets/LaunchImage.imageset/README.md` — 11 行，无引用 · 建议删

| 证据 | 内容 |
|---|---|
| 内容 | 上游 Flutter 样板：「换掉本目录图片即可自定义启动图」+ 用 Xcode 拖图 |
| 入链 | **0**。先前统计出的 5 条是 `LaunchImage` 这个词在 `Contents.json` / `LaunchScreen.storyboard` 里的**同名匹配**，不是对本文档的引用 |
| 已有更权威去处 | `docs/optional-additions.md:63` 的「原生启动图」条目（`flutter_native_splash` + 「native 层冷启动白屏」） |
| 现引用处 | 无（README / spec / docs 都没提它） |

**处置**：删文件；若想保住「去哪儿换启动图」这条信息，把一句话并进 `docs/optional-additions.md:63` 那行。

### ③ `ui/` 三份 spec 的 `ArticleListPage` 示例重叠 —— 34 行 · 建议**不动**

| 文档 | 行数 | 与他文重叠行 | 主要重叠对象 |
|---|---|---|---|
| `.trellis/spec/ui/hook-guidelines.md` | 144（54 行计入统计） | 25.9% | `component-guidelines.md`（13 行） |
| `.trellis/spec/ui/component-guidelines.md` | 219（72 行） | 22.2% | `hook-guidelines.md`（13 行） |
| `.trellis/spec/ui/quality-guidelines.md` | 132（53 行） | 18.9% | `component-guidelines.md`（8 行） |

**为什么建议不动**：重复的是同一段「页面骨架」示例（`useMemoized(() => viewModel ?? getIt<...>())`、
`ErrorText(error: error, onRetry: ...)` 之类），每份文档靠它自足；`guides/comment-guidelines.md` 明确
「**示例可以留** —— 调用方要照着写的形状留在代码里」。收敛成「一处 + 两处指路」会让每份 spec 读一半要跳转，
换来的只是 34 行（占全仓 5590 行的 0.6%）。**若你仍要收敛，我按 ③ 执行，但这是三条里收益最低的。**

## 明确「不清理」的部分（免得被当成漏项）

| 文档 | 为什么不清理 |
|---|---|
| `.trellis/workflow.md`（708 行）、`.trellis/agents/{implement,check}.md` | Trellis 托管，`.trellis/.template-hashes.json` 有登记，`trellis update` 会覆盖 |
| `.trellis/workspace/**`（`index.md` 125 行、`journal-1.md` 198 行） | 开发者日志，按设计只增不删（2000 行后轮转） |
| `docs/adr/ADR-0001.md` / `ADR-0002.md`（105 / 80 行） | 重叠率虽最高（ADR-0002 30.8%），但重叠的是**引用示例**；drift 报告判定两条 ADR 在 master（GetIt + 构造器注入）**仍然有效** |
| `.trellis/spec/index.md`（83 行）与 `guides/index.md`（102 行） | 两个索引分工不同：前者是「要动什么 → 读哪份」，后者是「思考指南 + 什么时候该触发」 |
| `docs/optional-additions.md`（244 行）、`docs/release-checklist.md`（145 行） | 入链健康（3–5 处），内容与 spec 不重复（一个讲「什么时候才该加」，一个讲发版补齐项） |

## 复现方法

```bash
# 入链 / 快照标记 / 章节重名
git ls-files '*.md' | grep -v -E '^(\.agents|\.pi|\.cursor|\.commandcode|\.trellis/tasks|\.trellis/workspace)/'

# 跨文档连续块重复（>=3 行、非表格、>=25 字）
#   逐份切块做集合交集，见本任务记录里的临时脚本；全仓库只有 6 行命中

# 七条规则名枚举在几处（判断「枚举会不会漂」）
git grep -c "no_upper_import_in_core"
```
