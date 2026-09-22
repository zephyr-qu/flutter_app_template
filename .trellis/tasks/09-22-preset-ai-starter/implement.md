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

**下一步**：阶段 1（删 `lib/di/`、`core_module` → providers、`bootstrap` 去 `configureDependencies()`、
`app/app.dart` 接 `ProviderScope`）。

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

- [ ] 删：`core/base/run_async_test.dart`、`signal_basics_test.dart`、`signal_builder_widget_test.dart`、
      `features/article/**`、`features/demo/**` 下的测试
- [ ] 改造：`core/ui/async_view_test.dart`、`core/config/user_preferences_test.dart`、
      `core/data/storage/auth_storage_test.dart`、`routing/*`、`app/pages/splash_page_test.dart`、
      `app/app_test.dart`、`support/app_test_harness.dart`（`GetIt` → `ProviderContainer`）
- [ ] 新增 `features/sample/**` 的对应测试（provider 测试用 `ProviderContainer` + `overrides`）
- [ ] `test/tool/check_boundaries_test.dart`、`check_conventions_test.dart`：随规则改动同步用例

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

- [ ] `frontend/state-management.md` **重写**：`AsyncState`→`AsyncValue`、`asyncSignal`→
      `AsyncNotifier`、`computed`→provider、dispose 边界→`autoDispose` 语义、
      `runAsync` 的竞态与刷新语义→框架内建行为（**哪些坑不再是坑、哪些仍然要守**要写清楚）
- [ ] `frontend/hook-guidelines.md` **删除**（D3），内容并入上一条的 Consumer 一节
- [ ] `frontend/quality-guidelines.md`：禁止/必须模式按 Riverpod 改写（`getIt` → `ProviderContainer`）
- [ ] `frontend/directory-structure.md`：删 `di/` 段 + 目录树
- [ ] `cross-cutting.md`：六道门禁的规则变化；覆盖率豁免清单复核
- [ ] `backend/network-guidelines.md`：`TokenStore` 的实现指向（`AuthStorage` → Riverpod 版）
- [ ] `docs/adr/ADR-0001.md` / `ADR-0002.md` / `docs/architecture-review.md`：**加适用范围标注**
      「仅对 master（signals 栈）成立」，不是删掉重写
- [ ] `README.md`：目录树 + 依赖表

## 阶段 8：AI 协作契约 + DoD

- [ ] `AGENTS.md`：必读三份（新的 state-management / quality-guidelines / directory-structure）
      置顶 + `## 改完必跑` 命令块 + 禁止模式速查 + `features/sample/` 金标准指向 + DoD
- [ ] `BRANCH.md`：基于 master、换了什么、**为什么是兄弟分支不回流**
- [ ] **盲测 DoD**：新开一个 AI 会话（不给任何解释，只给仓库），让它新增一个 feature，
      要求结构与 `features/sample/` 一致并通过全部六道门禁。**结果（成功/卡在哪）要写进
      `research/` 或 task notes——这条不达标则本任务未完成**

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
