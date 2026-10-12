# spec 单一入口收敛：根 index.md 与重复清理

## Goal

给 master 的 `.trellis/spec/` 一个**唯一入口**，并清掉本次对比（见父任务 `report.md`）查出的四类问题：
两份索引互相重复、清单已漂、`.cursor` 规则口径过期、两处标题缺陷。

**不做**目录改名（`backend/` → `data/`）与语言统一 —— 那是同级任务 `spec-naming-convergence` 的活，
本任务是它的**前置**（入口先收敛，改名才有唯一改动点）。

## 背景（已核实，逐条有证据）

| # | 问题 | 证据 |
|---|---|---|
| ① | 两份索引有**三段逐字重复** | `backend/index.md:20,26,34` vs `frontend/index.md:21,27,35`（`## 跨层与门禁` / `## 相关目录` / `## 写文档时的约定`） |
| ② | 重复已经**漂了** | `backend/index.md:22` 的清单**缺**「代码生成与生成物」，`frontend/index.md:23` **有** |
| ③ | `$L` 无「开工前必读 / 完成前自检」清单 | `grep -rn "开工前必读\|完成前自检" .trellis/spec` 无输出 |
| ④ | `.cursor/rules/project-conventions.mdc:32` 环境口径**过期** | 它写「编译期注入 `--dart-define`」，而 `lib/bootstrap.dart:3,35` 用 `flutter_dotenv`、`justfile:41` 注释也是 dotenv、justfile 里**没有任何 `dart-define`**。该文件 `alwaysApply: true` → 会主动误导 AI |
| ⑤ | `.cursor/rules/project-conventions.mdc` 说「六条规则」 | `packages/app_lints/lib/src/rules.dart` 实测 **7** 条；`AGENTS.md`、`cross-cutting.md` 都说七条 |
| ⑥ | `cross-cutting.md` 有两个同名小节 `### 禁止模式` | `:66`（架构边界下）与 `:235`（codegen 下）；按标题 grep 歧义 |
| ⑦ | `docs/optional-additions.md:197` 是**空标题**且编号撞车 | `:197 ### 2. 让 flavor 决定加载哪个 .env`（无正文）与 `:198 ### 2. flavor 与 env 的关系` |

参考实现：兄弟分支工作树的 `.trellis/spec/index.md`（`F:/App/新建文件夹/flutter_app_template`，
**只读**）。它已验证这套结构可行，但要按 master 口径改写：`@riverpod`→`@injectable` /
注解集不同 / `logic/` 的 UI 禁令 / `backend`+`frontend` 而非 `data`+`ui`。

## Requirements

### 1. 新建 `.trellis/spec/index.md`（唯一入口）

三块，缺一不可：

- **开工前必读**：按「要动什么」列 5–7 行检查项 → 指向现有 `backend/*`、`frontend/*`、
  `cross-cutting.md`、`guides/`。必须覆盖：写页面/ViewModel、UI 与组件、新建 feature、
  数据层（API/Service/DAO/Repository/模型）、门禁与 codegen 与集成测试与环境配置、思考指南。
- **完成前自检**：逐项可勾。必须包含 `just verify`、注解改动后 `just codegen`、
  架构边界（`packages/app_lints` 七条）、新增 `FailureCode` 补文案、增删 `lib/` 文件后同步
  `README.md` 与 `frontend/directory-structure.md` 的目录树（**无门禁，靠人**）、
  改动触到 spec 约定时同步对应 `.md`。
- **索引表**：分「工程结构 / 前端 / 数据层 / 跨层与门禁 / 思考指南」列出**全部**现有 spec 文件
  （21 篇都要出现，一篇不漏）。

### 2. 两份索引去重

- 删 `backend/index.md` 与 `frontend/index.md` 的 `## 跨层与门禁`、`## 相关目录`、`## 写文档时的约定` 三段。
- 各留一行指回根 `index.md`；两份各自的 `## Guidelines Index` 表**保留**（它们描述本层内容，不重复）。
- 修掉 ②：根 `index.md` 的「跨层与门禁」清单以 `frontend/index.md:23` 那版为准（它更全），并核对
  `cross-cutting.md` 的实际章节列表是否与之相符。

### 3. 指针统一改指根 `index.md`

| 文件 | 位置 | 改什么 |
|---|---|---|
| `AGENTS.md` | `:102-104` | 「数据层…见 `backend/index.md`；前端…见 `frontend/index.md`」→ 指根 `index.md` |
| `.cursor/rules/project-conventions.mdc` | `:20` | 「数据层 / 网络 / 数据库」那行 → 指根 `index.md` |
| `.trellis/spec/cross-cutting.md` | `:4` | 「层次内的规则见 [backend/](…) 与 [frontend/](…)」→ 指根 `index.md` |
| `tool/prune.dart` | `:143` | 提示语「同步 `frontend/index.md` 的链接」→ 同步根 `index.md` |

> `.pi/skills/trellis-meta/references/**` 里也有 `backend/index.md` 字样，那是 Trellis 自带示例文档
> （讲 context-injection 机制），**不是本仓库的引用，不要动**。

### 4. 修 `.cursor/rules/project-conventions.mdc` 的过期口径

- `:32` 规则 3「环境配置」整条改为 dotenv 口径，与 `README.md`「环境配置与 release 构建」一致：
  入库的 `.env.example` 是唯一 asset，dotenv 加载，`bootstrap()` 缺 `BASE_URL` 直接抛。
  **不要**再出现 `--dart-define` / `dart-define-from-file`。
- 「六条规则」→ 七条，并核对它列的判据与 `cross-cutting.md` 一致。

### 5. 消歧两处标题

- `cross-cutting.md:235` 的 `### 禁止模式` 改名（它属于 codegen 节）。**不要**改父标题
  `## 代码生成与生成物（codegen）` —— `.github/workflows/ci.yml:29`、`.gitignore:52`、
  `README.md:124` 都在引用它。
- 删 `docs/optional-additions.md:197` 那行空标题（保留 `:198` 有正文的那个）。

### 6. README 增加「常用命令」

现 `README.md:104-111` 已有一个 4 条命令的裸代码块且没有小节标题。把它升级为
`### 常用命令`，补齐 `justfile` 里实际存在的 recipe（`deps` / `fmt` / `fix` / `analyze` /
`codegen` / `codegen-reset` / `run` / `test` / `test-app-lints` / `init` / `verify`，
以 `justfile` 为准，不臆造），每条一行注释。
**只做组织，不删**现有的「代码生成」「从脚手架创建新项目」「环境配置与 release 构建」小节。

## Non-Goals

- 不改 `backend/` / `frontend/` 目录名、不把 `frontend/type-safety.md` 提到根。
- 不把 `backend/*` 的英文正文翻成中文。
- 不改 `lib/`、`test/`、`packages/` 的任何代码。
- 不碰兄弟分支工作树（`F:/App/新建文件夹/flutter_app_template`）。
- 不做报告 §4.2（`git grep` 段）、§4.3（routing 缺口）、§4.4（退出码表）—— 留给后续任务。

## Acceptance Criteria

- [ ] `.trellis/spec/index.md` 存在，含「开工前必读」「完成前自检」「索引表」三块，索引表覆盖 21 篇 spec
- [ ] `backend/index.md` 与 `frontend/index.md` 不再含 `## 跨层与门禁` / `## 相关目录` / `## 写文档时的约定`
- [ ] `git grep -n "backend/index.md\|frontend/index.md"` 只剩根 `index.md`、两份本层索引自身与其表内链接
- [ ] `.cursor/rules/project-conventions.mdc` 无 `dart-define`，规则条数 = 7
- [ ] `cross-cutting.md` 内 `### 禁止模式` 只出现一次
- [ ] `docs/optional-additions.md` 无连续两个 `### 2.`
- [ ] `README.md` 有 `### 常用命令`，列出的 recipe 在 `justfile` 中都存在
- [ ] `just verify` 全绿（尤其 `test-readme-tree` 与 `test-app-lints`）
- [ ] `git status` 不含生成物改动

## Notes

- 父任务 `.trellis/tasks/10-10-spec-drift-vs-preset-ai-starter/report.md` 是本次改动的依据清单。
- 下游任务 `spec-link-gate`（新增链接门禁）与 `spec-naming-convergence`（改名 + 语言统一）已建，
  本任务不阻塞它们，但它们是「先有唯一入口」的受益方。
