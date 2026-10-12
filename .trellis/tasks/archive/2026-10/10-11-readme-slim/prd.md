# README 精简为入口页

## Goal

`README.md` 现在 322 行 / 13 个一级标题，其中大量内容是在**复述 `.trellis/spec/` 已经写过的规范**
（7 条 lint 规则表、codegen 策略、覆盖率口径、环境配置细节、测试原则）。README 的读者是
「从模板派生新项目的人」，它应该是入口页而非 spec 的镜子。本任务把它压到 ~100 行，
对齐兄弟分支已有的形状，并把 README 独有的内容搬到合适的地方留档。

## 已核实的事实

| # | 事实 | 证据 |
|---|---|---|
| ① | `README.md` **322 行**，13 个一级标题（特性 / 技术栈 / 目录结构 / 快速开始 / 示例代码说明 / 模板占位清单 / 需要更多能力时 / 如何添加新功能模块 / 测试 / 架构边界与代码形态 / 开发工具 / 架构原则 / 许可证） | `wc -l README.md`、`grep -n '^## ' README.md` |
| ② | 兄弟分支 `preset/ai-starter` 的 README 只有 **88 行 / 6 节**（这是什么 / 包含什么 / 快速开始 / 目录结构 / 其它 / 许可证），是本仓库内的现成先例 | `git show preset/ai-starter:README.md \| wc -l` |
| ③ | 但那边**没有目录树门禁**（`tool/` 只有 `init_project.dart` / `list_dart_files.dart` / `prune.dart`），其树里 `├── main.dart / bootstrap.dart` 的**合写**在 master 上会被判成「路径不存在」 | `git ls-tree --name-only preset/ai-starter:tool/`、`tool/check_readme_tree.dart` 的 `_parseLine` |
| ④ | 目录树门禁的关键规则：围栏首行必须是 `lib` / `lib/`；**根目录总是展开** → `lib/` 的 6 个顶层项（`app/` `bootstrap.dart` `core/` `di/` `features/` `main.dart`）必须**全列**；只写目录名不展开则内容不查；`#` 一律是注释起点；层级 = `├`/`└` 的列号 ÷ 4 | `tool/check_readme_tree.dart:78-205` |
| ⑤ | 文档链接门禁**不校验 `#锚点`**（相对链接剥掉 fragment 只查文件是否存在） | `tool/check_doc_links.dart` 规则 A |
| ⑥ | 因此下面两处链到 README 小节的**锚点**目前有效，但删掉该小节后**门禁不会报**，只会静默失效：`docs/optional-additions.md:144` 与 `docs/release-checklist.md:4` 都指向 `../README.md#环境配置与-release-构建` | `git grep -n "README.md#" -- docs` |
| ⑦ | 另有一处描述依赖 README 的小节名：`docs/optional-additions.md:243` 写「`../README.md` — 模板占位清单（哪些是示例骨架、哪些是真接线）」 | 同文件 |
| ⑧ | 没有任何文档以 `README.md「关键词」` 形式引用 README 的标题，所以 `check_doc_anchors` 侧无连带改动 | `git grep -n "README.md「"` → 空 |
| ⑨ | `.trellis/spec/guides/index.md` 明写边界：**「guides 只放通用的思考方法。具体的项目规则、命令、文件清单属于 `data/` 或 `ui/`，不要抄到这里」** —— 把「删除示例步骤」「占位清单」放进 `guides/` 与本仓库这条自定规矩冲突 | `.trellis/spec/guides/index.md`「新增指南」节 |
| ⑩ | README 里与 spec 重复的部分已有专章可指向 | `cross-cutting.md` 的「架构边界与代码形态」「代码生成与生成物」「覆盖率」「环境配置与 release 构建」；`ui/localization.md`；`directory-structure.md`；`docs/release-checklist.md` |

## 决策（已拍板）

| 项 | 结论 |
|---|---|
| 力度 | **重写为精简版**，对齐 `preset/ai-starter` 形状，目标 ~90-110 行 |
| 「删除示例模块的引用清单」 | 搬走留档；README 只留 1 行指向 |
| 「`TODO(template)` 模板占位清单」 | 搬走留档；README 只留 1 行指向 |
| 「如何添加新功能模块」 | **保留在 README**，压成目录模板代码块 + 一行指 `directory-structure.md` |
| 流程 | 轻量任务，PRD-only |

## 新 README 结构（草稿）

| 新节 | 内容 | 来源 |
|---|---|---|
| 标题 + 定位段 | 「起点不是成品」+ 技术栈一行（指 `pubspec.yaml`） | 改写自现有首段 |
| `## 这是什么` | 4 条：定位 / 不是 / 语言 / 面向 AI（spec + AGENTS.md） | 新写（照 preset） |
| `## 包含什么` | 7-8 条：功能切片、状态与 DI、路由、网络与缓存、错误模型、MD3、门禁 | 现「特性」15 条合并去重 |
| `## 快速开始` | 环境要求一行 + 3 条命令 | 现「环境要求」+「常用命令」 |
| `### 常用命令` | 表格（`verify` / `deps` / `codegen` / `run` / `test` / `init` / `fmt`+`fix`） | 现代码块改表 |
| `### 环境与构建` | `.env.example` 口径 + 密钥警告 + release 有意留白一行指向 `docs/release-checklist.md` | 现「环境配置与 release 构建」压缩 |
| `### 用它开新项目` | `just init` 两式 + 「全有或全无」语义 + 指 `guides/rename-checklist.md` | 现「从脚手架创建新项目」压缩 |
| `## 示例模块` | 三模块一行式 + 「照抄 `article/`」+ 删除步骤指向新落点 | 现「示例代码说明」压缩 |
| `## 添加新功能模块` | 三层职责一句话 + 照抄 `article/`，指 `directory-structure.md`（目录模板树删掉，17 → 5 行） | 现「如何添加新功能模块」**保留**（收窄） |
| `## 目录结构` | 6 行素描树（列全 `lib/` 顶层，见事实 ④）+ 依赖方向 + 指 `directory-structure.md` | 现 40 行逐文件树 → 压缩 |
| `## 其它` | `spec/`、`AGENTS.md`、`TODO(template)`→新落点、应用图标、`optional-additions.md`、测试与门禁各一行 | 现「开发工具」「测试」「需要更多能力时」合并 |
| `## 许可证` | MIT | 原样 |

**删掉不复述的节**：`技术栈`表（并入技术栈一行）、`测试`的测试原则 + 覆盖率、`架构边界与代码形态`（7 规则表）、`架构原则`（数据流图 + Feature 间通信）—— 每处各自留一行指向 spec 对应章节。

## 三块独有内容的落点（需你确认）

事实 ⑨ 让「搬进 `guides/`」这个选项与仓库既有规矩冲突，所以推荐换个地方：

- **推荐**：新建 `docs/template-pruning.md`，两节 ——「删除示例模块」（auth / article / demo 的引用清单，含 `ArticleService` 仍用 `AppDatabase` 的提醒）+「`TODO(template)` 占位清单」（现 5 行表格）。理由：`docs/` 本来就是「给人看的操作文档」层，与 `release-checklist.md` / `optional-additions.md` 同类；README 与之互相链接，不碰 spec 的 AI 契约层。
- **备选 A**：并入 `.trellis/spec/cross-cutting.md`（占位清单进「有意不设的项」，删除步骤单开一节）。理由：跨层与模板形态的裁决都在那里；代价是 cross-cutting 已有 423 行。
- **备选 B**：按你原话放 `.trellis/spec/guides/template-pruning.md`。代价是要同时改 `guides/index.md` 的边界规则（或明知冲突仍放进 guides）。

## Acceptance Criteria

- [ ] README ≤ 115 行（实测 **114**），一级标题 13 → 8（preset 把「示例模块」「添加新功能模块」并进了「包含什么」，本仓库按拍板保留这两节）
- [ ] README 的 `lib/` 树列全 6 个顶层项，且不含**合写路径**（事实 ④）
- [ ] README 不再复述 spec 已有内容（7 规则表 / codegen 策略 / 覆盖率 / 环境配置细节 / 测试原则各留一行指向）
- [ ] 事实 ⑥ 的两处锚点已改到实际存在的标题（或改用不带 fragment 的链接）
- [ ] 事实 ⑦ 对「模板占位清单」的描述跟着新落点走
- [ ] 新落点文档已登记（放 `docs/` 则 README + `docs/optional-additions.md` 互相可达；放 spec 则同时登记 `spec/index.md` 与对应 `index.md`）
- [ ] `just verify` 全绿（含 `test-readme-tree` / `test-doc-links`）；`just check-anchors` 无新增断引
- [ ] 未写入 `preset/ai-starter` 分支与主工作树之外的位置

## 不做什么

- **不动 `AGENTS.md`**：它是 AI 协作契约（开工前必读 / 改完必跑 / 照抄对象 / 禁止模式速查），与 README 的读者面不同，两者重复是刻意的。
- **不动 spec 正文**：除新增落点文档与必要的登记行外不改写既有规范。
- **不删 `preset/ai-starter` 的 README**：两条分支不回流，各自维护。
- **不做「对齐 preset 的其它差异」**：本任务只谈 README。
