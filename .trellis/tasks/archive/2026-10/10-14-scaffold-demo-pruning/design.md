# Design — 脚手架 demo 剪枝自动化

## 1. 边界与形态

新增 `tool/prune_examples.dart`（独立脚本，不并入 `init_project.dart`）。理由：

- 剪枝是**可选、可晚做**的步骤（`docs/template-pruning.md:16`「确认看懂结构后可以删」），
  独立入口随时可跑。
- `init_project.dart` 的写盘是「全或无」的事务：把剪枝并进去后，剪枝找不到锚点会导致整个事务中止，
  **连带改名也做不了** —— 已经全绿的能力会被新能力的失败模式拖累。
- `init_project.dart` 末尾加一行提示（「要删示例模块：`dart run tool/prune_examples.dart`」），
  成本一行，换来可发现性。

沿用 `init_project.dart` 已证明有效的契约：

| 契约 | 来源 | 本工具 |
|---|---|---|
| 只接受 `--key=value`，`--yes` / `-y`，`--help` / `-h` | `tool/init_project.dart:158-176` | 同 |
| `runCli(args, {root, prompt, out, runProcess})` 返回退出码，不直接 `exit()` | `tool/init_project.dart:15-22` | 同，另加 `runProcess` 注入 |
| plan-then-write：先规划全部必改点，任一匹配不到 → 非零退出 + 零写盘 | `tool/init_project.dart:119-128` | 同 |

## 2. 剪枝模型

### 2.1 数据形状

```
PruneModule (enum: article, demo)          // auth 不在其中，见 §5
  ├─ dirs:     List<String>                // 直接删除的目录
  ├─ files:    List<String>                // 直接删除的单文件（如 db_articles.dart）
  ├─ edits:    List<PruneEdit>             // 必须精确匹配的引用清理点
  └─ fingerprints: List<String>            // 残留扫描用的标识符
```

`PruneEdit` 的四种形态，全部按**锚点文本**定位，不按行号（行号会漂移）：

| kind | 语义 | 匹配要求 |
|---|---|---|
| `deleteLines` | 删掉锚点所在的连续区块（如 router 的 3 行 import） | 锚点首尾行各匹配 1 次 |
| `replaceText` | 行内替换（如 `tables: [DbArticles]` → `tables: []`） | 片段全仓库该文件内匹配 1 次 |
| `deleteFile` | 删单文件 | 文件存在 |
| `dropBlock` | 删一个函数/列表内的连续区块（如 dio_client 的一段 MockRule） | 起止锚点各匹配 1 次 |

**「恰好匹配 1 次」是本工具的核心防线**：0 次说明仓库已经和工具的认知不一致，>1 次说明锚点不够具体。
两种都中止，并打印「锚点 / 期望匹配数 / 实际匹配数 / 所在文件」。这条直接复刻
`init_project.dart` 的「必改点没匹配到就以非零退出码结束，不写任何文件」。

### 2.2 实测锚点清单（本任务立项时逐条核实）

**module=article**

| # | 文件 | 锚点 | kind |
|---|---|---|---|
| A1 | `lib/features/article/` | 整目录 | 目录 |
| A2 | `test/features/article/` | 整目录 | 目录 |
| A3 | `lib/core/data/database/tables/db_articles.dart` | 整文件 | `deleteFile` |
| A4 | `lib/core/data/database/app_database.dart:10` | `part 'tables/db_articles.dart';`（含上方 `:9` 注释行） | `deleteLines` |
| A5 | `lib/core/data/database/app_database.dart:13` | `@DriftDatabase(tables: [DbArticles])` → `@DriftDatabase()`（**删掉整个参数**） | `replaceText` |
| A6 | `lib/app/routing/router.dart:9-11` | 3 行 article import | `deleteLines` |
| A7 | `lib/app/routing/router.dart:59` | `AutoRoute(path: 'articles', page: ArticleListRoute.page),` | `deleteLines` |
| A8 | `lib/app/routing/router.dart:63-69` | `/articles/:id` 那段 `AutoRoute(...)` 及其上方注释 | `dropBlock` |
| A9 | `lib/core/data/network/dio_client.dart:46-68` | 两条 `/articles` `MockRegistry.register` 段 | `dropBlock` |
| A10 | `lib/features/home/page/main_page.dart:15-19` | `_tabs` 里 `ArticleListRoute(),` + 上方那条「不是 `const`」注释 | `replaceText`（列表项 + 注释一起改写） |
| A11 | `lib/features/home/page/main_page.dart:67-83` | NavigationRail 的「文章」destination | `dropBlock` |
| A12 | `lib/features/home/page/main_page.dart:132-151` | NavigationBar 的「文章」destination | `dropBlock` |
| A13 | `lib/features/home/page/home_page.dart:132` | `onTap: () => context.pushRoute(ArticleListRoute()),` 及其卡片 | `dropBlock` |
| A14 | `test/routing/main_shell_test.dart:141,160` | 两条 `navigate(ArticleListRoute())` 测试及其用例 | `dropBlock` |

`main_page.dart` 的 `labelStyle(int index)` 以索引取标签样式，删掉中间一项后 **IndexedStack
的索引会整体错位**（`selected == 1` 原本是「文章」）。A11/A12 执行后必须同步核对索引：
Rail 与 Bar 的 `labelStyle(0/1/2)` 要重排为 `0/1`。这是本次剪枝最容易漏的一处**语义**残留
（编译能过、门禁全绿、但标签高亮错位），因此需要一条夹具测试盯着 `main_page.dart` 的
剪枝后形态。

**module=demo**

| # | 文件 | 锚点 | kind |
|---|---|---|---|
| D1 | `lib/features/demo/` | 整目录 | 目录 |
| D2 | `test/features/demo/` | 整目录 | 目录 |
| D3 | `lib/app/routing/router.dart:14-15` | 2 行 demo import | `deleteLines` |
| D4 | `lib/app/routing/router.dart:71-76` | `/storage-demo` 那段 `AutoRoute(...)` 及注释 | `dropBlock` |
| D5 | `lib/features/profile/page/profile_settings.dart:54-62` | 「本地存储示例」`SettingItem` + 上方注释 | `dropBlock` |

### 2.3 残留扫描（R4）

剪枝后对每个被剪模块的 `fingerprints` 做全仓库 `git grep`（尊重 .gitignore，且不受 build/ 干扰）：

- 命中 `lib/**` 或 `test/**` → **失败**：打印 `文件:行:内容`，退出码 1。
- 命中 `*.md` / `.trellis/**` / `docs/**` → 打印清单（含 `AGENTS.md:117`、12 份 spec），
  退出码不变。文案要说清「这些是教学示例引用，自动改写会产出空话，请人工决定改写或删段」。

扫描面有效性由 AC8 兜住：剪枝**前**在同一仓库上跑，必须能命中已知的文档引用。否则这个扫描
就是永远输出空的摆设。

## 3. 决策

### 决策 1：为什么按锚点文本而不是按 import 图自动推导

自动推导（从模块目录出发做传递闭包）看起来更「智能」，但它会连带把 `core/` 拉进来
（`ArticleDao` → `AppDatabase` → `path_provider`），然后**静默删掉 core 能力**。对一个脚手架，
这是最不能接受的失败模式。硬编码锚点 + 匹配失败即中止，把「工具认知与仓库不一致」变成
响亮的失败而不是安静的错删。锚点清单的漂移由**工具自己的测试**（AC5）和残留扫描（R4）兜住。

### 决策 2：为什么工具默认自己跑 codegen + verify

删掉 `@RoutePage` / `@injectable` / Drift 表之后不重跑 codegen，`router.gr.dart` 与
`service_locator.config.dart` 里会留着已删类型。工具是破坏性操作，**自己收尾并自证**比打印
「请记得跑两条命令」可靠。代价是 1-2 分钟耗时，用 `--no-verify` 留给想手工看 diff 的人。
`runProcess` 注入出来，夹具测试不跑真实 build_runner。

### 决策 3：core 能力保留，不连带删

删掉 `article` + `demo` 后，`FileStorage` 与 `AppDatabase` 都没有应用内消费者了
（只剩 DI 注册与各自的单元测试）。本工具**保留它们**：

- `AppDatabase` 必须留 —— 它是 core 数据设施，`@DriftDatabase(tables: [])` 留一个空库，
  新项目加第一张表时不必重建整套连接/schema 骨架。
- `FileStorage` 同理，且 `docs/template-pruning.md` 已把它描述为可复用能力。
- 二者都属「你确定不要就手删」的范畴（5 秒的 `grep FileStorage`），自动化收益低、错删风险高。

本任务不提供 `--with-core`；真需要就是新需求。删掉后 `FileStorage` 成为孤儿这件事，
由工具在收尾提示里点名（避免「以为是漏删」）。

**空表已验证通过（本任务 §0.1 实测）**：drift 接受 `@DriftDatabase()`，codegen 生成
`allSchemaEntities => []` 的库，`dart analyze --fatal-infos` 干净。

但**不能写成 `tables: []`** —— 那会被 very_good_analysis 的 `avoid_redundant_argument_values`
判为冗余实参（info 级，`--fatal-infos` 下直接红）。因此 A5 是 `replaceText` 成
`@DriftDatabase()`，即连参数一起去掉。这条已实测，不需要再走「保留 `db_articles.dart`」的退路。

### 决策 4：auth 拒绝剪枝

`auth` 不是示例而是基础设施（证据见 prd.md「Confirmed Facts」）。工具接受
`--modules=auth` 这个输入但以退出码 2 拒绝，文案指向「手工改造需重做守卫/拦截器接线」。
拒绝要发生在**任何写盘之前**，这样 `--modules=article,auth` 不会删掉一半再报错。

## 4. 测试策略

镜像 `test/tool/init_project_test.dart`：

- 用 `Directory.systemTemp.createTempSync` 造一个**最小可剪枝夹具**：只放被锚点引用的文件
  （`router.dart` / `main_page.dart` / `home_page.dart` / `profile_settings.dart` /
  `dio_client.dart` / `app_database.dart` + 模块目录），内容用真实仓库里那几行的形态。
- 注入 `runProcess` 假实现，记录被调用的命令并返回成功，**不跑真实 build_runner**。
- 断言重点是**退出码 + 夹具文件零改动**（全或无），而不是输出全文。
- 另加一条「真实文件的扫描面」测试：对仓库里真实的 `main_page.dart` / `router.dart` 做
  `plan()`（不写盘），断言每个锚点都恰好匹配 1 次。这条能在锚点漂移时**立刻**红，
  是 R3 的长期保护 —— 如果只靠夹具测试，夹具和仓库会一起漂。
- **端到端验收在临时副本上做**（`SCAFFOLD_E2E=1` 门控，镜像 `init_project_test.dart` 的端到端做法）：
  把真实仓库复制到临时目录 → 剪枝 → `just codegen` → `just verify`。**不在本仓库直接剪枝** ——
  它是模板本身，`AGENTS.md:117` 与 12 份 spec 都靠 `lib/features/article/` 当范例（见 prd.md「Confirmed Facts」）。

`test/tool/prune_examples_test.dart` 需要把工具函数暴露成可 import 的顶层函数
（`runCli` / `buildPlan`），与 `init_project.dart` 一样（`main()` 只是薄壳）。

## 5. 不变量

- 工具**只删不建**：不生成新文件、不改写 `.trellis/spec/**`。
- 工具**不在未确认时写盘**：交互模式必须显式 `y`；非交互必须给 `--yes` 或一侧显式 `--modules`。
- 工作区不干净时拒绝（R7）：回滚手段只有 `git checkout -- .` / `git clean -fd`，这要求
  运行前有一个干净基线。提示文案里直接写这两条命令。**检查要忽略 `.trellis/`** ——
  任务元数据本就未入库，而剪枝正是在任务内运行（否则工具会把自己拒掉）。
- 退出码约定：`0` 成功（含幂等跳过）／`1` 锚点或残留失败／`2` 输入被拒（auth、脏工作区）／
  `3` codegen 或 verify 失败。沿用 `init_project.dart` 的「非零即失败 + 文案说原因」。

## 6. 顺带修掉的文档漂移

`docs/template-pruning.md` 现有的 article 清单缺 5 处（见 prd.md Background 表）。
改写后该文件变成：工具用法 → auth 手工改造 → 占位清单（`TODO(template)` / 图标 / release）。
`AGENTS.md` 的「开工前必读 / 改完必跑」区按需加一行入口，不重复工具语义（避免又一处副本）。

---

## 7. 实施中的偏差（实测后修正，均为设计层面的改进）

| # | 设计里写的 | 实际实现 | 为什么 |
|---|---|---|---|
| 1 | 四种 `PruneEdit`：`deleteLines` / `dropBlock` / `replaceText` / `deleteFile` | **两种**：`DeleteBlock` / `ReplaceBlock`（整块逐行 trim 匹配，全文件**唯一命中**） | 四种其实是同一件事的两组：`deleteLines`/`dropBlock` 语义完全相同，`deleteFile` 与 `files:` 重复。而「首尾行各匹配一次」在本仓库**做不到** —— `dio_client.dart` 里 `MockRegistry.register(` 出现 4 次、`  );` 出现 4 次，首尾锚点不可能唯一。唯一性改由**整块内容**保证 |
| 2 | `replaceText` 的替换文本直接写入 | 新增 `reindentReplacement()`：替换块按**命中行的缩进**整体重排（以块内非空行的最小缩进为基准剥离，再套上命中行缩进） | 实测踩到：替换块是逐字写进文件的，工具源码里那层缩进会一起落到目标文件 —— `@DriftDatabase()` 被写成了缩进 8 格。锚点表因此可以随手缩进，与 trim 比较保持一致 |
| 3 | 残留扫描只排除生成物 | 还要排除**工具自身**（`tool/prune_examples.dart`）与它的测试 | 这两份文件必然包含被剪模块的标识符（锚点表与断言就是它们）。不排除的话，工具每次运行都会「成功地」报出自己 —— 实测确实发生了 |
| 4 | 指纹 = 类名标识符 | 追加**路径形态** `features/article` / `features/demo` | `AGENTS.md:117` 是拿 `lib/features/article/` 指路的，纯类名指纹永远命中不了它，AC8 的自证会失效 |
| 5 | R7 的干净基线检查 | 忽略 `.trellis/` 前缀 | 任务元数据本就未入库，而剪枝正是在任务内运行 —— 不忽略会自己把自己拒掉 |
| 6 | 设计 §2.2 的锚点清单（19 条） | 实测 **35 条**，多出的 16 条来自五个设计没查到的位置 | `test/app/pages/splash_page_test.dart`、`test/core/data/database/app_database_test.dart`（直接用 `db.dbArticles`）、`test/features/home/page/home_page_test.dart`（断言「文章」卡片）、`test/core/base/signal_builder_widget_test.dart`（注释举例）、`test/support/fake_path_provider.dart`（注释举例），以及删掉示例入口后变孤儿的两个 import |

**这 16 条不是靠人读出来的**：12 条由设计阶段的 grep 补上，1 条由**残留扫描**抓出
（`signal_builder_widget_test.dart`，工具报「代码里还有 1 处残留」），3 条由 `just verify`
的 `unused_import` 抓出。这正是「响亮失败 + 自证门禁」该有的样子 —— 锚点不全时工具不会静默少删。

## 8. 验收证据

| 验收 | 证据 |
|---|---|
| AC1 | 临时副本上 `dart run tool/prune_examples.dart --yes --modules=article,demo` → 工具退出码 0；其内部 `just codegen` + `just verify` 均通过 |
| AC2 | 副本上 `grep -rn "features/article\|features/demo\|ArticleListRoute\|StorageDemoRoute" lib test` → **0 命中** |
| AC3 | `router.gr.dart` / `service_locator.config.dart` 中 `Article*` / `StorageDemo*` → **0** |
| AC4 | 真实仓库跑 `--modules=auth` → 退出码 **2**，输出说明是基础设施；前后都是 6 项未提交改动（零写盘） |
| AC5 | `锚点被改坏：非零退出、点名那处、夹具零改动`（退出码 1 + 指明「_tabs 与「不是 const」注释」+ 快照相等） |
| AC6 | `parseArgs` / auth 混合请求 / 脏工作区（含 `.trellis/` 不算脏）/ 幂等 / `--no-verify` / codegen 失败 → 3 / verify 失败 → 3 |
| AC7 | `docs/template-pruning.md` 重写为「工具用法 + auth 手工改造 + 占位清单」，无手工删除步骤 |
| AC8 | 文档残留清单实测命中 `AGENTS.md:117`、`AGENTS.md:121`、`.trellis/spec/**` 共 59 处 |
