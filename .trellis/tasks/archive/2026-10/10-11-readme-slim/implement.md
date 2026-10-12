# 实现记录：README 精简为入口页

## 结果

| 项 | 前 | 后 |
|---|---|---|
| `README.md` 行数 | 322 | **114**（−65%） |
| 一级标题 | 13 | **8** |
| 新增文档 | — | `docs/template-pruning.md` |
| 改动文件 | — | `README.md`、`docs/template-pruning.md`、`docs/optional-additions.md`、`docs/release-checklist.md` |

新 README 结构（8 节）：`这是什么` / `包含什么` / `快速开始`（常用命令、环境与构建、用它开新项目）/
`示例模块` / `添加新功能模块` / `目录结构` / `其它` / `许可证`。

## 删掉的是「复述」，不是信息

| 原 README 里的内容 | 现在在哪 |
|---|---|
| 7 条 lint 规则表 + AST 判据说明 | `.trellis/spec/cross-cutting.md`「架构边界与代码形态」+ `spec/index.md` 自检项 |
| `Test 原则`（ViewModel 直构 / mocktail / `wrapPage()` / 注入点） | 同上 spec；README 只留「`mocktail` + 覆盖率不设门禁」一行 |
| codegen 策略（重新生成时机表、CI 现场生成、冲突处理） | cross-cutting.md「代码生成与生成物」 |
| 环境配置细则（dotenv 只能加载 asset、密钥、`.env` 被忽略） | cross-cutting.md「环境配置与 release 构建」；README 压成 4 行要点 |
| `Release 构建有意留白`明细 | `docs/release-checklist.md` |
| 40 行逐文件目录树 | README 留 6 行素描树（门禁要求有以 `lib` 为根的树）；完整树在 `spec/directory-structure.md` |
| 数据流图 + Feature 间通信 | cross-cutting.md / `spec/directory-structure.md` |
| 技术栈表（13 行） | 标题下的一行技术栈 + `pubspec.yaml` |
| 开发工具清单（8 条） | `其它` 里 3 条（spec / AGENTS / optional-additions），其余以 `justfile` 与 spec 为准 |

## 搬走留档的两块（`docs/template-pruning.md`）

按 PRD 的落点决策新建 `docs/template-pruning.md`（与 `release-checklist.md` / `optional-additions.md` 同层）：

1. **删除示例模块**：`auth` + `article` 的 4 处引用、`demo` 的 2 处引用，含「删 `demo` 不会连带删掉
   `AppDatabase`」的提醒（指向 `spec/data/database-guidelines.md`）。
2. **`TODO(template)` 与其它占位**：原 5 行占位表。

**顺手修正了原 README 的一处不实陈述**：原文说占位「全部带 `TODO(template)` 注释」，实测
`grep -rn "TODO(template)" lib/` 只有 3 处，全在 `lib/features/profile/page/profile_settings.dart`；
「首页「最近动态」」其实在 `lib/features/home/page/home_page.dart`，**没有**标记。新文档把两类分开写，
并加了快照标注（`> 快照（2026-10）`）。

## 连带改动（门禁不会报、只能靠人发现）

`check_doc_links.dart` 规则 A 会剥掉 `#fragment`，所以 README 小节被删后，指过去的锚点**静默失效**：

| 位置 | 改动 |
|---|---|
| `docs/optional-additions.md:144` | `../README.md#环境配置与-release-构建` → `#环境与构建`（新 README 的标题） |
| `docs/release-checklist.md:4` | 同上 |
| `docs/optional-additions.md:243` | 原指 `../README.md` 的「模板占位清单」→ 改指 `./template-pruning.md` |

## 验证

- `just verify` → **All gates passed**（含 `test-readme-tree` / `test-doc-links`，339 项测试通过）
- `just check-anchors` → 章节关键词引用均能对上（139 个文件）
- README 的 `lib/` 树列全 6 个顶层项；未用 `main.dart / bootstrap.dart` 这种**合写**（会被门禁当成不存在的路径 —— 兄弟分支 `preset/ai-starter` 因为没有这道门禁才敢那么写）

## 与 AC 的偏差（如实记录）

- PRD 原写「≤ 110 行 / 一级标题 6 节」，实测 **114 行 / 8 节**。原因：`preset/ai-starter` 的 88 行里
  没有「示例模块表」与「添加新功能模块」两节，而这两节是拍板要保留的。AC 已改为 ≤ 115 行 / 8 节。
- 收窄「添加新功能模块」的目录模板树（17 → 5 行）是二次决策的结果，原 PRD 没说。

## 没做的事

- 未动 `AGENTS.md`（AI 契约与 README 的读者面不同，重复是刻意的）。
- 未动 `preset/ai-starter` 分支（两条分支不回流）。
- 未改 spec 正文。
