# 脚手架 demo 剪枝自动化

## Goal

从这个脚手架派生新项目时，不再手工删示例模块。新增一个可独立运行的剪枝工具，一次完成
「删示例目录 → 清干净所有引用 → 重跑 codegen → 自证门禁全绿」，并保证不会静默留下
编译错误或指向已删文件的文档引用。

用户价值：新项目起手最痛的一步（`docs/template-pruning.md` 那两张手工清单）从
「照着文档逐处找、漏一处就编译不过」变成一条命令。

## Background

`docs/template-pruning.md` 目前用手工清单描述「怎么删干净」，共 54 行。这份清单**已经漂移**，
本任务立项时已核实：

| # | 手工清单（`docs/template-pruning.md`）写的 | 实际引用点 | 差异 |
|---|---|---|---|
| 1 | 删 `article` 要清 3 处（router / dio_client / main_page） | 5 处 | 漏 `lib/features/home/page/home_page.dart:132`（首页「查看全部」`pushRoute(ArticleListRoute())`） |
| 2 | 未提 Drift 表 | `lib/core/data/database/tables/db_articles.dart` + `app_database.dart:10,13` | 漏整张缓存表与 `@DriftDatabase(tables:)` / `part` 声明 |
| 3 | 未提测试 | `test/routing/main_shell_test.dart:141,160` | 漏测试里的路由引用 |
| 4 | 未提注释残留 | `main_page.dart:15-16` | 「不是 `const`：`ArticleListRoute` 带路由参数」剪枝后变成空话 |
| 5 | 未提 spec 引用 | 12 份 spec + `AGENTS.md:117` 共 ~20 处 | `lib/features/article/` 是全仓库的「照抄对象」，删掉后这些引用指向不存在的文件 |

结论：问题不是「删文件累」（`rm -rf` 30 秒），而是**引用图会静默烂掉**，且没有任何门禁能抓
（`.trellis/spec/index.md` 明确写了目录树同步「靠人，没有门禁」）。

## Confirmed Facts

已在本仓库核实（`10-14` 立项调查）：

- `tool/init_project.dart`（905 行）已有的契约，本工具沿用：只接受 `--key=value`；plan-then-write；
  **任一必改点匹配不到就非零退出且不写任何文件**；`runCli(args, {root, prompt, out})` 把 IO 注入
  出来以便回归测试（`tool/init_project.dart:15-22`）。
- `main.dart` / `justfile` 的门禁链：`verify: fmt-check analyze test-app-lints test`；
  `codegen: dart run build_runner build`。
- `test/tool/init_project_test.dart` 的夹具做法可直接镜像：`Directory.systemTemp.createTempSync`
  造最小仓库快照，再对 `runCli` 断言退出码与输出文案。
- `@RoutePage` / `@injectable` / Drift 表都是注解驱动的生成物来源；删掉页面后**必须重跑 codegen**，
  否则 `router.gr.dart` / `service_locator.config.dart` 里仍留着已删类型（`docs/template-pruning.md:20`）。
- `auth` 模块的实际耦合面（决定它不可自动化剪枝）：`AuthStorage` 被 `lib/app/routing/router.dart:36`
  的登录守卫消费；`auth_interceptor` / `token_refresher` / `token_store` 在网络层；
  `lib/app/app.dart:20-26` 用 `AuthReevaluateListenable` 接线；`splash_page` 判断登录态；
  `profile_page` 的登出走 `AuthRepository`。删它等于重做认证/守卫骨架。
- `FileStorage` 的消费者：`lib/core/core_module.dart`（DI 注册）、`lib/features/demo/**`、
  `test/core/data/storage/file_storage_test.dart`。删 `demo` 后它是孤儿但仍是 core 能力。
- `dart analyze` 需要显式文件列表（`justfile:7-8` 的 `list_dart_files.dart`），
  新增 `tool/` 文件会被 `analyze-tool` 的 root 自动覆盖。
- **本仓库就是模板本身**：剪枝的验收必须在**临时副本**上做（复制仓库 → 剪枝 → `just verify`），
  仓库里已有先例 —— `test/tool/init_project_test.dart` 的端到端测试在 `SCAFFOLD_E2E=1` 时
  也是「复制真实仓库到临时目录再跑」。在本仓库直接剪枝会删掉 `AGENTS.md:117` 与 12 份 spec
  依赖的教学范例。
- **R7 的「工作区干净」检查必须忽略 `.trellis/`**：任务元数据（`prd.md` / `task.json` 等）本就未入库，
  而剪枝正是在任务内运行 —— 不忽略就会自己把自己拒掉。

## Requirements

- **R1 新增独立工具** `tool/prune_examples.dart`，可独立运行（不并入 `init_project.dart`）。
  支持交互模式与 `--modules=<逗号分隔>` 非交互模式；沿用 `--yes` / `--help` 的既有语义。
- **R2 剪枝范围**：只删 `lib/features/{module}/**`、`test/features/{module}/**` 与精确引用点。
  `core/` 能力（`FileStorage`、`AppDatabase`、`AuthStorage`、网络拦截器栈）**保留**，
  见 design.md「决策 3」。
- **R3 全或无**：先用「锚点文本」而非行号规划全部必清点；任一锚点匹配数 ≠ 1 时非零退出、
  不写任何文件，并逐条列出未匹配的锚点。契约与 `init_project.dart` 一致。
- **R4 残留必须被报告**：剪枝后按模块指纹标识符（`ArticleListRoute` / `ArticleViewModel` /
  `ArticleService` / `ArticleDao` / `DbArticle` / `StorageDemoRoute` / `StorageDemoViewModel`）
  全仓库扫描。**代码侧残留 = 失败（非零退出）**；**文档侧残留 = 打印清单 + 提示，不算失败**。
- **R5 `auth` 拒绝剪枝**：`--modules=auth` 或交互中选中 `auth` 时，以退出码 2 拒绝并说明
  「它是基础设施不是示例，需人工改造」，同时在改动前中止。
- **R6 自证**：剪枝成功后自动跑 `just codegen`，再跑 `just verify`；两步都通过才报成功。
  提供 `--no-verify` 跳过（并打印下一步命令）。跑失败时打印失败输出与回滚命令。
- **R7 安全前置**：工作区不干净（`git status --porcelain` 非空）时拒绝运行 —— 本工具做的是
  不可逆删除。`--force` 可越过（供测试）。
- **R8 幂等**：模块目录已不存在时识别为「已剪枝」，提示并以 0 退出，不报错。
- **R9 同步文档**：改写 `docs/template-pruning.md` —— 手工清单降级为「工具用法 + auth 手工改造
  + 占位清单」，不再保留与工具重复的 article/demo 逐步清单。`AGENTS.md` 的入口描述按需补一行。
- **R10 spec 引用不自动重写**：`.trellis/spec/**` 里对示例模块的 ~20 处引用只输出清单
  （那些位置写的是「照抄这个形状」，自动改会产出空话，必须人工决定改写还是删掉整段）。

## Acceptance Criteria

- [x] **AC1** 把仓库复制到临时副本（镜像 `test/tool/init_project_test.dart` 的 `SCAFFOLD_E2E=1` 端到端做法），
      在副本上执行 `dart run tool/prune_examples.dart --yes --modules=article,demo` 后 `just verify` 全绿
      （含新的 `test/tool/prune_examples_test.dart`）。**本仓库自身的 `lib/features/{article,demo}` 保持不动** ——
      它是模板的示例，剪枝是给派生项目用的。
- [x] **AC2** 副本上剪枝后 `grep -rn "features/article\|features/demo\|ArticleListRoute\|StorageDemoRoute" lib test`
      无任何命中。
- [x] **AC3** 副本上剪枝后重跑 codegen，`lib/app/routing/router.gr.dart` 与 `lib/di/service_locator.config.dart`
      中不含 `Article*` / `StorageDemo*` 标识符，且 `just analyze-app` 干净。
- [x] **AC4** `dart run tool/prune_examples.dart --modules=auth` 退出码为 2，输出说明 auth 是基础设施，
      且仓库无任何改动（`git status --porcelain` 为空）。
- [x] **AC5** 夹具测试：把 `main_page.dart` 里的 `ArticleListRoute(),` 那一行改坏后运行工具，
      退出码非 0、输出指明未匹配的锚点、且**夹具文件零改动**（全或无）。
- [x] **AC6** 夹具测试覆盖参数解析（`--modules` 空值 / 未知模块 / `--help`）、已剪枝后再跑（幂等，
      退出码 0）、工作区不干净时拒绝（R7）。
- [x] **AC7** `docs/template-pruning.md` 不再包含逐步手工删除 `article` / `demo` 的清单，
      改为指向工具；文件内不再有本任务立项时列出的 5 处漂移。
- [x] **AC8** 工具输出的文档残留清单能在剪枝前的仓库里命中 `AGENTS.md:117` 与
      `.trellis/spec/**` 的示例引用（自证 R10 的扫描面有效，而不是永远输出空）。

## Out of Scope

- **`auth` 模块的自动化剪枝**：需重做登录守卫、`AuthStorage` 消费点、`app.dart` 接线与拦截器栈，
  属架构改造而非剪枝。工具只拒绝并指向文档。
- **自动重写 spec / docs 的示例引用**：只输出清单（R10）。
- **连带删除只被示例消费的 core 能力**（`FileStorage`、`AppDatabase`）：见 design.md「决策 3」，
  默认保留；本任务不提供 `--with-core`。
- **目录树一致性门禁**（断言 `README.md` / `directory-structure.md` 的树与 `lib/` 实际布局一致）：
  独立候选任务，不在本任务内。
- **示例模块之外的模板占位**（`TODO(template)` 三个设置项、应用图标缺失、release 签名）：
  仍由 `docs/template-pruning.md` 的占位表描述，不自动化。

## Open Questions

无阻塞项。下列已在 design.md 中作为显式决策记录，供复核时否决：

1. core 能力保留（不连带删 `FileStorage` / `AppDatabase`）—— 见 design.md 决策 3。
2. 工具默认自动跑 `just codegen` + `just verify`（约 1-2 分钟），可用 `--no-verify` 跳过 —— 见 R6。
