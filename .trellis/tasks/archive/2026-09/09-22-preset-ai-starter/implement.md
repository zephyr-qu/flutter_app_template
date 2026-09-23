# 执行计划：preset/ai-starter

> 环境：Windows + PowerShell。`dart` / `flutter` 不在 PATH 上，每条命令前先
> `$env:PATH="D:\scoop\apps\flutter\current\bin;$env:PATH"`。
>
> 提交约定（用户已确认）：**全部 `git commit --no-verify`** + 手工跑完整门禁。本地钩子在
> Windows 上单次约 20 分钟（每次 `dart run` 都被 sqlite3 的 build hook 拖住），关掉它换来的是
> 「必须自己报结果」的义务，不是「可以不跑」。

## 进度

**2026-09-22 · 阶段 0 完成（分支 `preset/ai-starter`，从 master `4150ee6` 起）**

- 依赖落地：`flutter_riverpod` / `riverpod` **3.4.3**、`riverpod_annotation` **4.0.7**、
  `riverpod_generator` **4.0.9**（dev，版本经 `pub add --dry-run` 实测解析）
- **明确不装**：`custom_lint`（所有版本要求 `analyzer <8 或 ^8`，本项目钉 13.3.0）、
  `riverpod_lint`（3.1.9 起走 `analysis_server_plugin`，IDE-only，与「门禁逻辑一律脚本」的立场冲突）
- **主题不动**：`flex_color_scheme` 只在 `packages/app_core`，本分支零改动该包（PRD 已同步「范围调整」）
- `lib/core/providers.dart` 建成（4 个 provider），**`@riverpod` 代码生成已实测通过**
  （`dart run build_runner build --build-filter=lib/core/providers.g.dart` → 产出 4 个输出）
- ⚠️ 分支当前**编译不过**：signals / get_it / hooks 依赖已移除，而 `lib/` 下的代码还没迁
  （阶段 1–4 的预期中间态，见上文「基线与取舍」）

**顺带查实的一处既有文档错误（影响 master，不属本任务范围）**：
`--delete-conflicting-outputs` 在 build_runner **2.16.0** 起已移除、传入会被忽略并在输出里警告
（"always fix incorrect generated files" 变成默认行为）。而 `.github/workflows/ci.yml`、
`cross-cutting.md`、`docs` 里都还在传它，并且 spec 里写着「不加它构建**直接失败**」——这句已经不成立。
需要单独在 master 上修（改文档 + CI 命令），本分支的阶段 7 只负责自己这份 spec。

**2026-09-22 · 阶段 1 + 2 完成（core 装配层，`flutter analyze lib/core lib/app ...` 零 issue）**

阶段 1 与 2 是**咬合**的（`Dio` 需要 `AuthStorage`，而 `AuthStorage` 正在被改写），所以合并做：

| 动作 | 文件 |
|---|---|
| 删 | `lib/di/service_locator.dart`、`service_locator.config.dart`、`core/core_module.dart`、`core/base/run_async.dart`、`features/{auth,article}/data/*_module.dart` |
| 新增 | `core/providers.dart`（prefs/secureStorage/database/fileStorage/userPreferences/authStorage）、`core/auth/session.dart`、`core/config/app_settings.dart`、`app/providers.dart` |
| 改写 | `core/data/storage/auth_storage.dart`（去 signals + 新增 `userChanges` 流）、`core/config/user_preferences.dart`（纯存储）、`core/data/network/dio_client.dart`（`@module` → provider，mock 端点改 `/sample-items`）、`app/routing/auth_reevaluate.dart`（信号 → 流）、`app/app.dart`（`ConsumerWidget`）、`bootstrap.dart`（`ProviderScope` + `prefs` override）、`core/ui/async_view.dart`（`AsyncState` → `AsyncValue`） |

三个值得记的实现决定（阶段 7 要写进 spec）：

1. **`prefsProvider` 用 override 注入，不用 `FutureProvider`**：`SharedPreferences.getInstance()`
   是异步的，而消费者（`UserPreferences` / `AuthStorage`）都是同步构造的。做成 `FutureProvider`
   会把 `AsyncValue` 一路传染到页面。所以 `bootstrap()` 先 await，再用
   `ProviderScope(overrides: [prefsProvider.overrideWithValue(prefs)])` 注入；漏了 override
   会当场抛（`UnimplementedError`），不静默降级。
2. **登录态有两层，别把守卫改成读 provider**：真源是 `AuthStorage`（同步可读，`AppRouter`
   的守卫直接用它，master 的 `router.dart` 因此**一行都不用改**）；`Session` provider 只是
   它 `userChanges` 流的镜像，供 UI 订阅。改成守卫读 provider 会引入「状态还没 emit →
   先判成未登录」的空窗。
3. **`dioProvider` 读 `userPreferencesProvider` 而不是 `appSettingsProvider`**：后者一变
   provider 就会重建，而「Dio 必须单例」优先（重建会丢掉在飞请求、重放状态与 mock 注册）。
   代价是调试开关与 master 一致：**重启后生效**。

⚠️ **新增一条 codegen 纪律（阶段的血泪，阶段 7 要进 spec）**：
**不要在项目编译不过的时候跑 `build_runner`**。本次在「依赖已换、代码未迁」的红窗口里跑了一次全量构建，
`auto_route` 因为解析不到 `Key` / `Widget` 类型，把 `router.gr.dart` 里的 `Key? key` 全部降级写成
`dynamic key`，并**静默覆盖**了正确产物（`drift` 也丢了 3 行）。已用 `git restore` 回滚。
换栈这种「必然有红窗口」的迁移里，正确做法是：先让 `flutter analyze` 收敛，再跑 codegen；
或跑完立刻核对生成物 diff。

**2026-09-22 · 阶段 3 + 4 合并完成（features 迁移 + sample 金标准，`flutter analyze lib/` 零 issue）**

阶段 3 与 4 合并做：`features/demo` 与 `features/article` 在阶段 4 整体删除，先按 Riverpod 迁一遍再删是纯浪费，
所以这一轮把「存活页面迁移」与「sample 替换 article/demo」一次做完。

| 动作 | 文件 |
|---|---|
| 删 | `features/article/`、`features/demo/`、`features/auth/logic/auth_view_model.dart`、`lib/di/`（空目录） |
| 新增 | `features/auth/data/auth_providers.dart`、`features/auth/logic/login_notifier.dart`、`features/sample/`（data 三形态 + logic + page） |
| 改写 | `login_page` / `home_page` / `profile_page` / `splash_page`（HookWidget → Consumer*）、`router.dart`、`main_page`（tab 文章→示例）、`error_text.dart`（doc） |

四条实现细节（阶段 7 要进 spec）：

1. **provider 命名会被收敛**：`riverpod_generator` 把 `XxxNotifier` 的 provider 命名成 `xxxProvider` ——
   `LoginNotifier` → `loginProvider`（**不是** `loginNotifierProvider`）。写页面时容易踩，没有 lint 兜。
2. **`AsyncView` 的错误对象就应该是 `Failure` 本身**：`AsyncNotifier.build()` 里 `throw error`
   （`Failure implements Exception`，`only_throw_errors` 不报），`AsyncValue.error` 原样带着它，
   `ErrorText` 才翻译得出错误码。**不要**另造一个包装异常，否则页面只剩「未知错误」。
3. **刷新 / 重试不需要 request token**：页面用 `ref.refresh(xxxProvider.future)`（下拉刷新）
   与 `ref.invalidate(xxxProvider)`（重试）；竞态与「刷新保留旧值」由框架保证，`AsyncView` 的
   refreshing / reloading 分支直接接上。
4. **页面不再需要 `final VM? viewModel;` 三件套**（D2 落地）：注入点就是 `ProviderScope(overrides:)`。
   `check_boundaries` 规则 4 因此**自然失效**（它只扫 `getIt<XxxViewModel>`），阶段 6 删规则时不会误报。

⚠️ **新发现（影响 master，不属本任务范围）：`@DriftAccessor(tables: [...])` 解析不到另一个 package 里的表。**

`packages/app_core` 抽包之后，`features/*/data/*_dao.dart` 里 `@DriftAccessor(tables: [DbArticles])`
生成出来的 mixin 是**空的**（`drift_dev` 报 `The referenced element, DbArticles, is not understood by drift`，
对应 drift 未关闭的 issue #3669），于是 `dbArticles` 未定义、DAO 编译不过（实测）。

- 已实测的边界：同 package 内**无论表在 part 文件还是与数据库同一文件都正常**，只有跨 package 会失败。
- 所以 master 的 `article_dao.g.dart` 还完好，只是因为停在 `8b8cb40`（抽包之前），而上次红窗口
  `build_runner` 的产物被 `git restore` 回滚了 —— **master 上跑一次全量 `build_runner` 就会把
  `article_dao.g.dart` 打空并当场编译失败**。
- 本分支处置：`SampleDao` 不用 `@DriftAccessor`，直接持有 `AppDatabase` 并用生成 getter
  `dbArticles` 取表（`app_core` 零改动），理由写在类注释里。根治要动共享包，留给你定。

**本阶段遗留（阶段 5–7 处理）**：

- ~~`test/` 471 个 issue~~ —— **阶段 5 已清零**：`flutter analyze lib/ test/` 干净，241 条测试全绿。
- ~~`check_conventions` 2 处违规~~ —— **阶段 5 已处理**（比计划早一步）：两处注释块的详细内容已搬进
  spec —— `AsyncView` 的 Riverpod 判定表进 `frontend/state-management.md`「渲染状态」、
  `AuthStorage` 不含状态管理依赖进 `backend/database-guidelines.md`；代码里只留一行指针。
  先写 spec 再删代码，知识不会在中间态丢失。
- ~~`check_readme_tree` 红~~ —— **阶段 6 已处理**：README 与 `directory-structure.md` 的树按实际 `lib/` 重画。
  顺带照出两个删除动作留下的空目录（`lib/core/base`、`test/core/base`、`test/features/article`、
  `test/features/demo`），一并清掉 —— 目录树门禁的价值就在这里：残留物自己会露出来。
- `dart analyze tool/` 有 10 个 info，全部在 `tool/prune.dart`（本任务未改动它，疑似 master 侧既有问题）
  —— **本阶段有意不动**：实测 `dart analyze` 对 info 的退出码是 0，门禁本来就不红；
  而它是 master 侧的工具脚本，在这里顺手改等于把一个 750 行脚本的重排混进换栈分支。

**2026-09-23 · 阶段 6 完成（门禁调整，六道门禁全绿）**

| 脚本 | 改动 |
|---|---|
| `check_boundaries.dart` | 规则 1 由「不得用 `getIt`」改成「不得手动建容器」（`ProviderContainer(` / `.test(`）；规则 4「页面必须给可选注入点」退役（D2）；新增「`features/*/logic/` 不得 import `package:flutter/material.dart`」 |
| `check_conventions.dart` | `avoid_async_state_map` 退役；新增 `avoid_ref_read_in_build`（`build` 里不得用 `ref.read` 取 provider 值） |
| `check_readme_tree.dart` | 脚本未改，改的是目标树（README ×2 棵 + `directory-structure.md`） |

两个判断要记下来：

1. **`ref.read(xxx.notifier)` 必须放行，否则门禁一上线就红**：`login_page.dart:25` 在 `build` 里
   `ref.read(loginProvider.notifier)`，把 `updateEmail` / `updatePassword` 当 tear-off 传给输入框。
   取的是 notifier 实例本身（身份稳定、不参与订阅），是正当写法。所以判据落在「取**值**的 read」
   （实参不是 `.notifier`），而不是「所有 read」—— 回调里 `ref.read(repoProvider).logout()` 照旧放行。
   这条偏差是实现时按既有代码定的，不是 PRD 原文的字面口径。
2. **规则 4 退役后，`findViolations` 的 sort 也一起删了**：那次排序是为「规则 4 的文件级结果
   先入列」服务的；规则一走，行扫描本身就是行号升序。

顺带修掉三处会被下一个人当真的过期描述：`analysis_options.yaml` 的规则清单注释、
`docs/release-checklist.md` 的门禁说明、pre-commit 与 CI 里指向旧规则的步骤注释。
`docs/adr/`、`docs/architecture-review.md`、`frontend/{state-management,quality-guidelines,hook-guidelines,component-guidelines}.md`
里的 signals 口径**留给阶段 7**（加适用范围标注 / 重写 / 删除），本阶段不碰。

**阶段 6 门禁实测（2026-09-23）**

| 门禁 | 结果 |
|---|---|
| `dart format --set-exit-if-changed` | 0 changed（132 文件） |
| `check_boundaries` / `check_conventions` / `check_readme_tree` / `dependency_validator` | 全绿（目录树由 19 处 → 0） |
| `flutter analyze lib/ test/` | No issues found |
| `dart analyze tool/` / `dart analyze packages/` | 退出码 0（`tool/` 仍打 10 个 info，全在 `prune.dart`，见上） |
| `flutter test` | 242 passed / 1 skipped；`app_core` 104 passed |
| `check_coverage --src` | 根 `lib/` 90.0%（31 文件）、`app_core` 89.8%；无未加载文件、无过期豁免 |
| 脚本自身用例 | `check_boundaries_test` / `check_conventions_test` 全绿，新规则各有正反例 + 真实仓库回归 |

**下一步**：阶段 7（spec 与文档重写：`state-management.md` 重写、`hook-guidelines.md` 删除、
`quality-guidelines.md` / `directory-structure.md` 改口径、ADR 与 `architecture-review.md` 加适用范围标注、README 主体重写）。

---

**2026-09-23 · 阶段 7 完成（spec 与文档重写）**

原则：**正文只写仓库里真实成立的事**，master 的旧口径不删原文、改成显式的适用范围框；
能用命令验证的写法优先给命令。涉及状态的每个断言都对着代码核过（provider 名、`ref.mounted`、
`wrapPage(page, container:)`、`AsyncView` 的四条分支、`keepAlive` 清单、`NoRetry` 等）。

| 文件 | 改动 |
|---|---|
| `frontend/state-management.md` | **全文重写**：三种 provider 形态（顶层函数 / 同步 Notifier / `Future<T> build()`）+ 各自的金标准文件、`watch` vs `read`、`AsyncView` 判定表与两条页面要求、刷新重试（对照 master 的 `runAsync` 三条语义）、`autoDispose` / `keepAlive` 清单 / `ref.mounted` / `ref.onDispose`、**Consumer 一节**（原 hook-guidelines）、Testing Requirements 三条硬约束 |
| `frontend/hook-guidelines.md` | **删除**（D3），内容并入上一条的「Consumer 一节」；`frontend/index.md` 的索引同步去掉 |
| `frontend/quality-guidelines.md` | 禁止/必须模式按 Riverpod 改写（`getIt` → `ProviderContainer`/`ref`、`asyncSignal` → `AsyncNotifier`、`useSignalValue` → `ref.watch`）；原第 11 条「可选注入点」改成「**不要**再加注入点参数」并说明理由 |
| `frontend/directory-structure.md` | `logic/` 改 Notifier；Feature 间通信改「core/ 的 provider」（范例换成 `Session`）；命名表去掉 DI module / ViewModel 行、加 providers / Notifier 行；数据库一节改「表在共享包、查询在 feature、**不要** `@DriftAccessor`」 |
| `frontend/component-guidelines.md` | 页面模板改 `ConsumerWidget`；共享组件表 `AsyncState` → `AsyncValue` 并标出 `EmptyWidget` 在包里；三态渲染段与 Common Mistakes 去 hooks/signals |
| `frontend/type-safety.md` | `AsyncState` 删除、`@injectable` → `@riverpod`、`*.config.dart` 标「本分支不存在」、`Signal state checking` → `Async state checking`；新增一条写法约定：**构造器不重复类名**（`const new({...})` / `const factory({...})` / `factory fromJson(...)` 是本分支的统一形状，别「顺手改成老写法」） |
| `frontend/localization.md` | **重写**：仓库**已经没有 l10n**（master 的 `09-22-prune-l10n` 把脚手架降为单语言），原文整份在描述一个不存在的配置。改成「单语言约定 + 文案写在哪 + 要加回来时照 `prune.dart` 的裁剪面反向做」 |
| `frontend/index.md` | 索引与描述改口径 |
| `backend/network-guidelines.md` | `TokenStore` 的实现指向（本分支就是 `AuthStorage`）；`NetworkModule` → `networkConfigProvider` / `dioProvider`；调试开关重启生效的理由；Mock 规则换 `/sample-items*` |
| `backend/error-handling.md` | 「错误文案怎么到界面上」改成「`AsyncNotifier.build()` 抛 `Failure` 本身」；ViewModel layer → Notifier layer；Service 例子换 `SampleService`；`lib/core/base/*` → `packages/app_core/lib/base/*`；`token_refresh_test` 路径 |
| `backend/database-guidelines.md` | **大改**：「状态管理与存储的分工」表（存储不带状态管理）、`AuthStorage` 的接口与失败策略、跨 package **禁** `@DriftAccessor`（drift#3669）、表在共享包 / 查询在 feature、缓存旁路与行↔模型转换换 `Sample*`、FileStorage 已无示例页 |
| `backend/quality-guidelines.md` | `getIt()` → `ref` / `ProviderContainer`；`@LazySingleton` / `@module` → provider 装配；review 清单同步 |
| `backend/directory-structure.md` | data flow 的 `ViewModel` → `Notifier`；`{feature}_module.dart` → `{feature}_providers.dart`；删 `service_locator.config.dart` |
| `backend/logging-guidelines.md` | 「没有 per-Notifier 日志」；`lib/core/logging` → `packages/app_core/lib/logging`；示例与测试路径换口径 |
| `guides/{index,cross-layer-thinking-guide,comment-guidelines,code-reuse-thinking-guide}.md` | `ViewModel` → `Notifier`、`Article(Service)` → `SampleItem(Service)`、`getCachedArticle` → `getCachedItems`、mock 端点示例换 `/sample-items` |
| `cross-cutting.md` | codegen 表（`@riverpod` 生成 `.g.dart`、`*.config.dart` 已无、`app_localizations` 标注）；生成器清单（`riverpod_generator` 顶替 `injectable_generator`）；CI 漂移检查去掉 `gen-l10n`；`leak_tracker` 段改成 provider 口径；集成测试的 CI 段改「Android 模拟器，不要 xvfb」；测试范例换 sample |
| `docs/adr/ADR-0001.md`、`ADR-0002.md`、`docs/architecture-review.md` | 顶部加「⚠️ 适用范围：仅对 master（signals 栈）成立」的框 + 逐条对照表；**正文一字不动** |
| `docs/release-checklist.md`、`docs/optional-additions.md` | 可执行项与替代方案表改口径（生成物清单、`intl` 不在依赖里、riverpod 是现状而 signals 是替代、缓存示例换 `SampleService`） |
| `README.md` | 主体重写：特性 / 技术栈表 / 示例模块（auth + sample）/「如何添加新功能模块」的 Notifier 与页面模板 / 测试原则 / 数据流图 / Feature 间通信；**两棵目录树只改注释、路径未动**（`check_readme_tree` 仍绿） |

**顺带发现并修掉的过期描述**（都不在阶段 7 清单里，但都属「会被下一个人当真」）：

1. **仓库已经没有 l10n，而 CI 还在跑 `flutter gen-l10n`** —— 缺 `l10n.yaml` 时该命令会直接失败。
   已从 `.github/workflows/ci.yml` 删掉（连同报错文案），README / `release-checklist.md` /
   `cross-cutting.md` 同步。**这是 master 侧的既有问题**：`09-22-prune-l10n` 只验了六道门禁，
   CI 的那一步不在其中，所以裁剪完之后 CI 的 `analyze` job 应该一直是红的。
2. `integration_test/app_test.dart` 还写着「应用默认跟随系统语言」并设置 `app.locale`（l10n 已裁剪，那行是死代码）；
   同一文件的注释还把 `bootstrap()` 说成「DI 注册」。
3. `lib/core/ui/error_text.dart` 的文档注释说「按当前语言翻译」。
4. `pubspec.yaml` 的 `description` 还写着 `Signals`（`tool/init_project.dart` 会把这句写进新项目）。
5. `docs/release-checklist.md` 的崩溃上报接入点还列着早已删掉的 `runZonedGuarded`。
6. `cross-cutting.md` 说集成测试在 CI 里用 `xvfb-run` —— 实际是 `reactivecircus/android-emulator-runner`
   （`ci.yml` 自己写着「不要用 xvfb」）。

**阶段 7 门禁实测（2026-09-23）**

| 门禁 | 结果 |
|---|---|
| `dart format --set-exit-if-changed` | 0 changed（132 文件） |
| `check_boundaries` / `check_conventions` | ✅ |
| `check_readme_tree` | ✅ 3 棵树一致（README ×2 + `directory-structure.md`） |
| `dependency_validator` | ✅ No dependency issues |
| `flutter analyze lib/` / `flutter analyze test/` | No issues found |
| `flutter test` | 242 passed / 1 skipped（`SCAFFOLD_E2E`）；`app_core` 104 passed |
| `check_coverage --src` | 根 `lib/` 90.0%（31 文件）、`app_core` 89.8%；无未加载文件、无过期豁免 |

**下一步**：阶段 8（`AGENTS.md` 升级为 AI 协作契约、新建 `BRANCH.md`、跑盲测 DoD）。

---

**2026-09-23 · 阶段 8 完成（AI 协作契约 + 技能/规则面收敛）**

用户对开工前两个问题的拍板：**① 换成 riverpod 版 ② CI 不临时加 `preset/*` ③ AGENTS.md 更新**；
对第二轮新发现的两个问题的拍板：**① `.cursor/rules` 只留总纲、其余 5 个删掉 ② 4 个栈冲突技能一并删掉**；
提交策略：**分批次提交**。

| 动作 | 内容 |
|---|---|
| 技能换装 | 删 5 个 `signals-*`（112 文件）+ 4 个栈冲突的 `flutter-*`，装 23 个 `riverpod-*`（`serverpod/skills-registry` 的 `skills/riverpod/*`，25 文件）。`.agents/skills/` 由 27 个目录变成 41 个，`skills-lock.json` 同步（顺带清掉里面的僵尸条目 `signals_hooks`——lock 有 28 条而磁盘只有 27 个目录） |
| `.cursor/rules/` | 删 5 个（`architecture-boundaries` / `data-layer` / `quality-gates` / `state-management` / `ui-pages`），只留并重写 `project-conventions.mdc`（总纲 + 必读指路 + 不存在的东西） |
| `AGENTS.md` | 块内改掉三处事实错误（11/13/16 行）；`TRELLIS:END` **之后**新增契约块：必读三份 / `features/sample/` 照抄表 / 禁止模式速查 / `## 改完必跑` / DoD |
| `BRANCH.md` | 新建：基点 `4150ee6`、换掉的三件事、**明确没换的**（主题 / auto_route / dio+retrofit / freezed / drift / l10n / `packages/app_core` 零改动）、为什么不回流、CI 决策与残余风险、六道门禁 |
| `--delete-conflicting-outputs` | 从 5 处清掉（`ci.yml` ×3、`README.md` ×4、`release-checklist.md` ×2、`cross-cutting.md` ×4、`rename-checklist.md` ×1），并把 `cross-cutting.md` 里「不加它构建**直接失败**」这句**假话**改成实测结论 |
| 盲测材料 | `.trellis/tasks/09-22-preset-ai-starter/research/blind-test.md`：隔离副本的造法、严格盲测（A）与 PRD 字面（B）两版 prompt、观察点表、六道门禁核对表、结果记录段 |

**四条判断与实测**

1. **`.cursor/rules/` 是比技能目录更严重的一处**，而且它不在任何清单里。6 个文件整份是 signals 口径，
   其中 `project-conventions.mdc` 与 `architecture-boundaries.mdc` 是 `alwaysApply: true`；
   `ui-pages.mdc` 给的模板是 `HookWidget` + `useMemoized(() => getIt<XxxViewModel>())` + `useSignalValue`，
   `data-layer.mdc` 是 `@LazySingleton` / `@module` / `CoreModule`。技能要 AI 主动读，规则默认进上下文。
   处置选了「删 5 留 1」而不是全部重写：**真正防漂移的是 `.trellis/spec/` + 门禁脚本**，
   这 6 个文件是第二份真相，而换栈七个阶段没人发现它们过期，正是「第二份真相」的代价。
2. **`npx skills` 的三个实测坑**（都先在临时目录验过，没在仓库里试错）：
   - 不加 `--agent universal` 会往**9 个** agent 目录各写一份（`.claude`/`.codebuddy`/`.kiro`/`.lingma`/`.pi`/`.qoder`/`.trae`/`.zcode`），与 Trellis 的 `.pi/skills`、`.codebuddy` 打架；
   - `--skill 'riverpod-*'` **不支持通配**，也不支持逗号分隔，只能重复 `--skill <名字>`；
   - `npx skills remove` **不可靠**（报 "Successfully removed 1 skill(s)"，文件与 lock 条目都还在），
     所以删除走文件系统 + 手工剪 `skills-lock.json`，删完用 `npx skills list` 对账。
3. **`--delete-conflicting-outputs` 已定论**（这次查的是 build_runner 2.16.1 的源码，不是猜）：
   `lib/src/build_runner_command_line.dart` 里它被列进 `removedOptions`，
   注释原文是 `// Removed options, kept to not break old command lines.`——
   传进去不报错、也不起作用，只在输出里多一条 warning（2.15.0 的 changelog 也是这么写的）。
   它当年要解决的事从那版起是**默认行为**，旧行为的开关换成了 `--keep-modified-outputs`。
   所以文档与 CI 里的引用可以放心去掉，`cross-cutting.md` 那句「不加它直接失败」是既成假话。
4. **审计方法本身有个坑，值得记下来**：`Grep` / ripgrep **默认跳过点号目录**
   （`.trellis` / `.cursor` / `.github` / `.agents` / `.commandcode`）。
   前一版对 `signals` 与 l10n 的「全仓库扫描」因此是**漏的**——`.cursor/rules/` 的 6 个文件、
   `.github/workflows/ci.yml` 里的 flag、`cross-cutting.md` 的口径，一个都没进结果。
   以后做这类一致性审计，要么显式把点号目录列为搜索根，要么用 `git grep`（它按 git 索引走，不吃这套）。
   另外 `-g '!{a,b}/**'` 这种带 `!` 的组合 glob 也会让结果失真，别用。

**顺带查实、但本轮不动的一处**：`.commandcode/taste/taste/taste.md` 第 23 行是「widget 要响应式读 signals
（`useSignalValue` / `HookWidget`）」。那是工具自动学的用户画像文件，手改会被覆盖，所以只记录不修改。

**阶段 8 门禁实测（2026-09-23）**

| 门禁 | 结果 | 说明 |
|---|---|---|
| `dart format --set-exit-if-changed` | 0 changed（132 文件） | 复跑 |
| `check_readme_tree` | ✅ 3 棵树一致 | 复跑（README 改过） |
| `check_boundaries` | ✅（`lib` + `packages/app_core/lib`） | 复跑 |
| `check_conventions` | ✅（`lib` + `packages/app_core/lib`） | 复跑 |
| `dependency_validator` | ✅ No dependency issues | 复跑 |
| `flutter analyze lib/` / `flutter test` / `check_coverage` | **本阶段未重跑** | 阶段 8 只碰 `.agents/` `.cursor/` `AGENTS.md` `BRANCH.md` `.trellis/` `docs/` `README.md` `ci.yml`，`lib/` `test/` `packages/` 一个字节都没改（`git diff --name-only` 可核），这三道不可能受影响 |

**下一步（必须由用户在另一个会话里做）**：跑 `research/blind-test.md` 的盲测 DoD。
A 版不通过就先跑 B 版区分「入口不显眼」还是「规范缺失」，再把卡点写回该文件的第 6 节，
按需回到阶段 7 补 spec 后重测。**这条不达标则本任务未完成。**

---

## 基线与取舍

| 项 | 实测（2026-09-22，`lib/` 手写文件 39 个） |
|---|---|
| 与 signals 耦合 | 17 |
| 与 getIt / injectable 耦合 | 21 |
| 与 flutter_hooks 耦合 | 10 |
| 需重写 | 约 30（全部 page + 全部 logic + core 适配层 + 装配层） |
| 两栈共有（已抽包，不动） | 27（`packages/app_core`） |

**换栈不是可分阶段全绿的改动**：依赖一旦替换，中间态必然有编译错误。所以计划按
「阶段 = 一次可验证的推进」组织，**只在阶段边界要求全绿**（阶段 1–4 之间允许红，
第 5 阶段起必须逐渐收敛到绿）。这与常规 feature 开发不同，不要照搬「每个提交都绿」。

## 决策（我已按默认选定，可推翻）

| # | 决策 | 理由 |
|---|---|---|
| D1 | `features/sample/` **新写**一个完整三件套（`data/`(api+dao+service+repository+model) + `logic/` + `page/` + 对应测试），端点改名为 `/sample-items`；`features/article/` 与 `features/demo/` 整体删除 | 「AI 唯一照抄对象」必须覆盖全部三种 data 形态（retrofit / drift / Result 包装），否则 AI 抄不到 dao 与 service 的写法 |
| D2 | `check_boundaries` **规则 4（页面可选注入点）退役**；规则 1 改为禁 `ProviderContainer` | Riverpod 下 `ProviderScope(overrides:)` 就是注入点，`final VM? viewModel;` 三件套失去存在理由；ADR-0001 的缓解措施随之作废（文档标注适用范围） |
| D3 | `hook-guidelines.md` **删除**，内容并入 `state-management.md` 的 Consumer 一节 | 整份文件的存在前提就是 `flutter_hooks`；换掉后留一个 20 行空壳只会让人以为 hooks 还能用 |
| D4 | `main_page` 的中间 tab 由「文章」改为「示例」；`home_page` 的快捷入口、`profile_page` 的「本地存储示例」入口同步改指 `sample` | 删掉 article/demo 后这三处入口会指向不存在的路由 |
| D5 | `async_view.dart` 改为吃 `AsyncValue<T>`，**保留** `refreshing` / `reloading` 两个可选回调与 `data(null)` 视同无数据这两条自家语义 | 这两条是项目定制（spec 有专段 + 测试依赖），换成库默认会静默改变页面行为 |

---

## 阶段 0：分支与依赖可解性（**先做，失败就停**）

```powershell
git switch -c preset/ai-starter        # 从 master 4150ee6 起
python ./.trellis/scripts/task.py set-branch 09-22-preset-ai-starter preset/ai-starter
```

- [ ] `pubspec.yaml`：移除 `signals_flutter` / `signals_hooks` / `flutter_hooks` / `get_it` /
      `injectable` / `injectable_generator` / `flex_color_scheme`
- [ ] `pubspec.yaml`：加 `flutter_riverpod` / `riverpod_annotation`，dev 加 `riverpod_generator` /
      `riverpod_lint` / `custom_lint`
- [ ] `flutter pub get` 解得开
- [ ] **只跑一次** `dart run build_runner build --delete-conflicting-outputs`，确认 `@riverpod`
      能生成 `.g.dart`

> 这里是最实的一个风险：`riverpod_lint` + `custom_lint` 对 analyzer 版本敏感（本项目
> analyzer 13.x / Dart 3.13）。**解不开就先只上 `flutter_riverpod` + `riverpod_annotation`，
> 把 lint 包降到后面再试**，不要为了让 lint 装上而反过来降 analyzer。

## 阶段 1：装配层换血（删 DI，接 ProviderScope）

- [ ] 删 `lib/di/service_locator.dart`、`lib/di/service_locator.config.dart`（整个目录）
- [ ] `core/core_module.dart` → `lib/core/providers.dart`（`prefs` / `secureStorage` /
      `database` / `fileStorage` 四个 `@riverpod` 顶层 provider；`prefs` 是 async 的，
      用 `FutureProvider`）
- [ ] `features/auth/data/auth_module.dart`、`features/article/data/article_module.dart` →
      各自 feature 的 `*_providers.dart`（article 的随 D1 一起变成 sample）
- [ ] `bootstrap.dart`：去掉 `configureDependencies()`
- [ ] `app/app.dart`：`ProviderScope` 包在 `runApp` 外层；`MyApp` → `ConsumerWidget`
- [ ] README / `frontend/directory-structure.md` 的目录树删 `lib/di/`（否则 `check_readme_tree` 必挂）

## 阶段 2：core 适配层

- [ ] 删 `core/base/run_async.dart`（Riverpod 的 `AsyncValue` 自带「最后一次胜出 + 刷新保留旧值」）
- [ ] `core/ui/async_view.dart` → 吃 `AsyncValue<T>`（见 D5）
- [ ] `core/ui/error_text.dart`、`loading_indicator.dart` 摘掉 `AsyncState` 依赖
      （这两个文件**仍在 lib**，抽包时因耦合 signals/主题而留下）
- [ ] `core/data/storage/auth_storage.dart`：拆成「裸存储类（`TokenStore` 实现）」+ `@riverpod`
      暴露 `currentUser` / `isLoggedIn` 的 provider
- [ ] `core/config/user_preferences.dart`：同上，三个偏好各一个 `Notifier`
- [ ] `app/routing/auth_reevaluate.dart`：`signal.subscribe` → `ref.listen`
- [ ] `app/routing/router.dart`：守卫改读 provider（不再是构造器注入的 `AuthStorage`）

## 阶段 3：features 迁移

- [ ] 7 个 page → `ConsumerWidget` / `ConsumerStatefulWidget`（`useMemoized`→provider、
      `useSignalValue`→`ref.watch`、`useEffect`→`ref.listen`/`initState` 语义等价物）
- [ ] logic → `@riverpod` `Notifier` / `AsyncNotifier`（`AsyncState` → `AsyncValue`）
- [ ] 保留页面测试的可注入口：Riverpod 下靠 `ProviderScope(overrides:)`，
      **不再需要** `final VM? viewModel;` 三件套（见 D2）

## 阶段 4：示例收敛（D1）

- [ ] 新增 `features/sample/`：`data/sample_api.dart`（retrofit）+ `data/sample_dao.dart`（drift）+
      `data/sample_service.dart` + `data/sample_repository.dart` + `data/models/sample_item.dart`
      + `logic/sample_list_notifier.dart` + `page/sample_list_page.dart`
- [ ] 删除 `features/article/`、`features/demo/`（含各自 `*.g.dart` 生成物）
- [ ] `dio_client.dart` 的 Mock 规则端点 `/articles*` → `/sample-items*`（仍须 `MockRule.regex` + 锚定结尾）
- [ ] `main_page.dart` tab、`home_page.dart` 快捷入口、`profile_page.dart` 的示例入口（D4）
- [ ] `integration_test/app_test.dart`：登录流程保留，落地页断言改为示例页

## 阶段 5：测试与测试基建（这一步起必须全绿）

- [x] 删：`core/base/run_async_test.dart`、`signal_basics_test.dart`、`signal_builder_widget_test.dart`、
      `features/article/**`、`features/demo/**` 下的测试（另删 demo 测试专用的
      `support/fake_path_provider.dart`；包内那份仍被 app_core 测试使用，未动）
- [x] 改造：`core/ui/async_view_test.dart`、`core/config/user_preferences_test.dart`、
      `core/data/storage/auth_storage_test.dart`、`routing/*`、`app/pages/splash_page_test.dart`、
      `app/app_test.dart`、`support/app_test_harness.dart`（`GetIt` → `ProviderContainer`）
- [x] 新增 `features/sample/**` 的对应测试（provider 测试用 `ProviderContainer` + `overrides`）；
      另外补上 `core/auth/session_test.dart`、`core/config/app_settings_test.dart`、
      `auth/logic/login_notifier_test.dart`、`core/data/network/dio_client_test.dart` ——
      这些都是本分支新写/大改的文件，不留覆盖率盲区
- [x] `test/tool/check_boundaries_test.dart`、`check_conventions_test.dart`：阶段 5 不动脚本规则，
      两条「真实仓库」回归用例保持绿；规则改动在阶段 6

### 阶段 5 实测（2026-09-23）

> 阶段 0–4 的复选框未回填，以各阶段末的叙述为准；从这里起逐阶段记实测数字。

| 门禁 | 结果 |
|---|---|
| `flutter test` | **241 passed / 1 skipped**（`SCAFFOLD_E2E` 端到端），0 failed |
| `flutter test --coverage` + `check_coverage` | 根 `lib/` **90.2%**（31 个文件）、`app_core` 89.8%，均达标；豁免清单无过期项 |
| `check_boundaries` / `check_conventions` / `dependency_validator` / `flutter analyze lib+test` | 全绿 |
| `dart format --set-exit-if-changed` | 0 changed |
| `check_readme_tree` | **仍红 19 处**（README 与 `directory-structure.md` 的树）——阶段 6 |

四个「不改就红」的坑，已写进 spec（`state-management.md`「渲染状态」+ `database-guidelines.md`）：

1. **`AsyncView` 的 `data(null)` 语义在阶段 3/4 的实现里丢了**。master 的 `runAsync` 在
   `previous == null` 时直接置 `loading`，而刷新 / 重载分支原先直接渲染 `data(null)`。
   已按 D5 修回（额外判一次 `value != null`），并为 refreshing / reloading / `data(null)`
   各留一条测试钉住。
2. **widget 测试里不能 `await provider.future`**：假时钟下 riverpod 的调度任务只有
   `tester.pump()` 才跑得动，那个 await 会悬挂到该用例超时（10 分钟/条）。改为
   「先渲染首帧 → 完成 Completer → `pump()` → 读状态」。
3. **Riverpod 3 默认对失败的 provider 自动重试**（200ms 起、指数退避、最多 10 次）：
   widget 测试收尾会报 `A Timer is still pending...`，`verify` 的调用次数也会被悄悄加一。
   测试容器统一传 `noRetry`（`test/support/app_test_harness.dart`），生产保留默认行为。
4. **`mocktail` 的 `verify` 会消耗命中的调用**：先 `called(1)` 再 `called(2)` 只看得见剩下
   那一次；要断言总数就只 verify 一次。

顺带修掉一处与阶段 5 无关的红：`pubspec.yaml` 的 `drift` 从 `dependencies` 挪到
`dev_dependencies`（数据库与表都在 `app_core`，根工程只在测试里用 `drift/native.dart`
建内存库），`dependency_validator` 因此转绿。

## 阶段 6：门禁调整

| 脚本 | 调整 |
|---|---|
| `check_boundaries.dart` | 规则 1：`getIt` → `ProviderContainer`（`features/*/logic/` 内禁手动 new 容器）；规则 4 退役；新增「`features/*/logic/` 不得 import `package:flutter/material.dart`」（Riverpod 栈做得到，signals 栈做不到） |
| `check_conventions.dart` | `avoid_async_state_map` 退役（`AsyncValue.when` 的回调是具名具类型的，原来那条运行期分派风险消失）；新增「`build` 里不得 `ref.read`」 |
| `check_readme_tree.dart` | 目标树同步（`lib/` 树 + `directory-structure.md` 树） |
| `check_coverage.dart` | 无需改；但 `lib/di/` 消失 + 文件增减后要重跑一遍确认豁免清单仍然准确（**过期豁免会打 warning**） |
| `analysis_options.yaml` / `pubspec.yaml` | 规则集不变；`dependency_validator` 的声明同步（应用侧不再需要 `injectable`） |

> 顺序不能反：**先改脚本再删代码**会让门禁误报一堆，**先删代码再改脚本**则中间态无门禁。
> 按「阶段 4 完成 → 阶段 5 绿 → 阶段 6 改脚本」走，每步都能解释。

## 阶段 7：spec 与文档重写（成败关键）

- [x] `frontend/state-management.md` **重写**：`AsyncState`→`AsyncValue`、`asyncSignal`→
      `AsyncNotifier`、`computed`→provider、dispose 边界→`autoDispose` 语义、
      `runAsync` 的竞态与刷新语义→框架内建行为（**哪些坑不再是坑、哪些仍然要守**要写清楚）
- [x] `frontend/hook-guidelines.md` **删除**（D3），内容并入上一条的 Consumer 一节
- [x] `frontend/quality-guidelines.md`：禁止/必须模式按 Riverpod 改写（`getIt` → `ProviderContainer`）
- [x] `frontend/directory-structure.md`：删 `di/` 段 + 目录树
- [x] `cross-cutting.md`：六道门禁的规则变化；覆盖率豁免清单复核
- [x] `backend/network-guidelines.md`：`TokenStore` 的实现指向（`AuthStorage` → Riverpod 版）
- [x] `docs/adr/ADR-0001.md` / `ADR-0002.md` / `docs/architecture-review.md`：**加适用范围标注**
      「仅对 master（signals 栈）成立」，不是删掉重写
- [x] `README.md`：目录树 + 依赖表
- [x] **清单外但必须做**（同一个「spec 与代码一致」的口径）：`frontend/{type-safety,localization,index,component-guidelines}.md`、
      `backend/{error-handling,database-guidelines,quality-guidelines,directory-structure,logging-guidelines}.md`、
      `guides/*`、`docs/{release-checklist,optional-additions}.md`；`localization.md` 是重写（仓库已无 l10n），
      其余是逐处换口径

## 阶段 8：AI 协作契约 + DoD

- [ ] `AGENTS.md`：必读三份（新的 state-management / quality-guidelines / directory-structure）
      置顶 + `## 改完必跑` 命令块 + 禁止模式速查 + `features/sample/` 金标准指向 + DoD
      —— **注意两处现存的事实错误**（阶段 7 有意留着没改，因为整块在 `<!-- TRELLIS:START -->` 托管区里，
      `trellis update` 可能覆盖）：第 11 行仍写 `Signals + ViewModel state management`、
      第 13 行仍写 `Injectable + GetIt dependency injection`、第 16 行仍写「用户可见文案走 l10n」
- [ ] `BRANCH.md`：基于 master、换了什么、**为什么是兄弟分支不回流**
- [ ] **盲测 DoD**：新开一个 AI 会话（不给任何解释，只给仓库），让它新增一个 feature，
      要求结构与 `features/sample/` 一致并通过全部六道门禁。**结果（成功/卡在哪）要写进
      `research/` 或 task notes——这条不达标则本任务未完成**

### 阶段 8 开工前要用户拍板的两件事

1. **`.agents/skills/signals-*` 还在仓库里**（`signals-dart` / `signals-flutter` / `signals-hooks` /
   `signals-lint` / `signals-migration-6-to-7`，共五个技能目录）。本分支已经没有 signals，
   而 AI 会按技能描述去写 signals 代码 —— 与「AI 打开仓库就能在边界内产出符合规范的代码」直接冲突。
   建议随本阶段一起删掉（或换成 riverpod 版），但删技能文件影响面较大，先确认。
2. **CI 的触发分支仍是 `branches: [master]`**（`.github/workflows/ci.yml`，阶段 6 提出，仍未决）：
   推 `preset/ai-starter` 不会跑任何 CI，而本分支的提交约定是 `--no-verify` —— 六道门禁全靠本地自觉。
   要不要临时加上 `preset/*`？

> **两条都已决，见上文「阶段 8 完成」**：① 换成 riverpod 版（并且顺带删掉 4 个栈冲突的 `flutter-*`）；
> ② **不加** `preset/*`，本分支的 CI 空转是刻意接受的代价，残余风险记在 `BRANCH.md`。

### `## 改完必跑` 命令块（AGENTS.md 里要落的版本）

```bash
dart format lib test tool packages
dart run tool/check_boundaries.dart
dart run tool/check_conventions.dart
dart run tool/check_readme_tree.dart
dart run dependency_validator
flutter analyze lib/ test/
dart analyze tool/ && dart analyze packages/
flutter test --coverage
(cd packages/app_core && flutter test --coverage)
dart run tool/check_coverage.dart coverage/lcov.info packages/app_core/coverage/lcov.info \
  --src=lib --src=packages/app_core/lib
```

## 全量验证（每阶段边界 + 收尾）

```powershell
$env:PATH="D:\scoop\apps\flutter\current\bin;$env:PATH"
cd e:/code/rust/flutter_app_template
dart format --output=none --set-exit-if-changed lib test tool packages
dart run tool/check_boundaries.dart
dart run tool/check_conventions.dart
dart run tool/check_readme_tree.dart
dart run dependency_validator
flutter analyze lib/ test/
dart analyze tool/
dart analyze packages/
flutter test --coverage
cd packages/app_core; flutter test --coverage; cd ../..
dart run tool/check_coverage.dart coverage/lcov.info packages/app_core/coverage/lcov.info --src=lib --src=packages/app_core/lib
```

## 风险与处置

| 风险 | 处置 |
|---|---|
| `riverpod_lint` / `custom_lint` 与 analyzer 13.x 版本冲突 | 阶段 0 先验；冲突就先不装 lint 包，**不要反过来降 analyzer** |
| `riverpod_generator` 生成的 `.g.dart` 让 `check_coverage` 的剔除清单失效 | `*.g.dart` 已在 `isGeneratedPath` 里，无需改；阶段 6 复核 |
| `AsyncValue` 语义与 `runAsync` 的差异（`dataRefreshing` / `reloading` / `data(null)`） | 由 D5 的 `AsyncView` 承载，并为这三条各留一条测试（spec 里的行为不能静默丢） |
| `leak_tracker` 对 provider 的可见性未知 | 测试报泄漏时先判断是 provider 生命周期问题还是误报，不要直接 `withIgnored` 掩盖 |
| 中间态长时间红，误判为「改坏了」 | 阶段 0–4 的红是预期的；每阶段结束跑一次 `flutter analyze lib/` 看错误**数量趋势**是否收敛 |
| 盲测 DoD 不达标 | 这是本任务的核心验收；不达标就回到阶段 7 补 spec，而不是把 DoD 改成「能跑就行」 |

## 回滚点

| 位置 | 回滚方式 |
|---|---|
| 阶段 0/1 依赖解不开 | `git switch master`，删除分支；master 不受影响（兄弟分支隔离） |
| 阶段 3 迁移到一半发现 Riverpod 语义与某页面不兼容 | 单独记录该页面，先 `stash`/提交到分支，评估是否需要在 sample 里换一种写法 |
| 阶段 8 盲测暴露 spec 缺口 | 回到阶段 7 补 spec，重跑盲测；**不要**改 DoD 的判定标准 |

## 明确不做

- 不回流 master（Riverpod 与 signals 无法互相合并，强行回流会互相覆盖）
- 不换 `auto_route` / `dio` / `retrofit` / `drift` / l10n
- 不引入两套状态管理并存（「渐进迁移」在这个仓库没有意义：栈就是分支的差异本身）
- 不为「让门禁过」放宽任何阈值或规则
