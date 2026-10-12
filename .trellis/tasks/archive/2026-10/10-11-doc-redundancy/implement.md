# 实现记录：冗余文档清理

## 结果

| 编号 | 动作 | 结果 |
|---|---|---|
| ① | 删 `docs/architecture-review.md` + 改 ADR 引用 | **−222 行**；`ADR-0001` / `ADR-0002` 各 2 处「关联候选」链接改成文字描述（来源与结论以 ADR 为准） |
| ② | 删 `ios/Runner/Assets.xcassets/LaunchImage.imageset/README.md` | **−11 行**；「换启动图去哪儿」一句并进 `docs/optional-additions.md` 的「原生启动图」条目（iOS + Android 两侧真实路径） |
| ③ | 收敛 `ui/` 三份 spec 的重复示例 | `hook-guidelines` 144 → **131**、`quality-guidelines` 132 → **120**；三对重合 **26 行 → 10 行** |

## ③ 的实际做法（范围比报告里的描述更窄）

| 位置 | 处理 |
|---|---|
| `hook-guidelines.md`「页面模板」 | 只保留与 hook 有关的行（`useMemoized` / `useSignalValue` / `useEffect` / 注入点），`Scaffold` + `AsyncView` 骨架改为指 `component-guidelines.md`「页面结构」 |
| `ui/quality-guidelines.md`「必须遵守 1」 | 8 行 `AsyncView` 片段（与 `component-guidelines.md`「三态渲染」**是同一份**）→ 压成一行指路，规则文字保留 |
| **保留未动** | ① `quality-guidelines`「必须遵守 3 / 5」的两条**单行**插图（`final theme = Theme.of(context);`、`final async = useSignalValue(vm.articles);`）—— 删掉后规则只剩口号，而重复的只有 1 行；② `component-guidelines` 内部「页面结构」与「三态渲染」两处 `AsyncView` 片段 —— 各自讲不同的点（页面骨架 vs 推荐/不推荐对照） |

**残余重合 10 行**（可复核）：

- `hook-guidelines ↔ component-guidelines` 7 行 —— 全是 hook 行本身（`class ArticleListPage extends HookWidget`、`final vm = useMemoized(...)`、`final async = useSignalValue(...)`、注入点三件套）。这是 `hook-guidelines` 的**主题**，再收敛就等于删掉该文档。
- `component-guidelines ↔ quality-guidelines` 2 行、`hook-guidelines ↔ quality-guidelines` 1 行 —— 就是上面保留的那三条单行插图。

## 验证

- `just verify` → **All gates passed**（339 项测试；含 `test-readme-tree` / `test-doc-links`）
- `just check-anchors` → 章节关键词引用均能对上（**138** 个文件；比上次少 1，是删掉的 `docs/architecture-review.md` 原本在扫描面内）
- 残留引用：`docs/architecture-review.md` 只剩 `.trellis/workspace/zs/journal-1.md` 的两处**历史日志**（日志按设计只增不减，保留）；`git grep` 在 `docs/`、`.trellis/spec/`、`tool/` 下已无引用
- 删除的 iOS 样板文件**入链为 0**（先前的 5 条是 `LaunchImage` 同名词在 `LaunchScreen.storyboard` / `Contents.json` 里的误匹配）

## 与报告的偏差（如实记录）

- 报告里对 ③ 的建议是「**不做**」（收益最低、伤文档自足性），用户选择做 —— 执行时把范围收窄到「真正被抄两份的多行片段」，单行插图保留。
- 报告说 ③ 是「−34 行」；实际口径不同：那次统计的是**单行重复计数**（含巧合重合），实际删减为 `hook-guidelines` −13 行、`quality-guidelines` −12 行，共 **−25 行**，其余是改写而非删除。

## 没做的事

- 未动 Trellis 托管文件（`.trellis/workflow.md`、`.trellis/agents/**`、`.trellis/workspace/**`）。
- 未删 ADR（`10-10-spec-drift-vs-preset-ai-starter/report.md` 已判定两条 ADR 在 master 仍有效）。
- 未动兄弟分支 `preset/ai-starter`。
