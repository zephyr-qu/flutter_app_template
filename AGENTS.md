<!-- TRELLIS:START -->
# Trellis Instructions

These instructions are for AI assistants working in this project.

## Project Nature: Personal Flutter Scaffold

This project is a **personal Flutter scaffold/template** for medium-small apps, not a production application. It provides a clean starting point with:

- **Feature-Sliced Design (FSD 简化版)** feature-first structure
- **Riverpod 3** state management（provider + `ConsumerWidget`；没有 signals / ViewModel）
- **auto_route** declarative routing
- **Riverpod provider** dependency injection（没有 DI 容器，`lib/di/` 已删除）
- **Material Design 3** theming
- **Retrofit + Dio** API client pattern
- **Chinese-first UI**（用户可见文案直接写中文，单语言，没有 l10n）+ **English identifiers**、**Chinese comments**

### Starting a New Project From This Scaffold

#### Quick way (automated)

```bash
dart run tool/init_project.dart
```

This interactive script updates the following files:

- `pubspec.yaml` → `name`, `description`
- 全仓库 → `package:<旧名>/` → `package:<新名>/`（含生成物）与根组件类名
- `android/app/build.gradle.kts` → `namespace`, `applicationId`
- `android/app/src/main/AndroidManifest.xml` → `android:label`
- `android/app/src/main/kotlin/**/MainActivity.kt` → `package` 声明（文件同步搬到新目录）
- `ios/Runner/Info.plist` → `CFBundleDisplayName`, `CFBundleName`
- `ios/Runner.xcodeproj/project.pbxproj` → `PRODUCT_BUNDLE_IDENTIFIER`（含 `.RunnerTests`）

任一必改点没匹配到就以非零退出码结束，**不写任何文件**（先规划、后写盘）。

非交互用法（不提问，缺失项按默认值推导）：

```bash
dart run tool/init_project.dart --yes --name=my_next_app \
  --application-id=com.example.my_next_app
```

After the script:

```bash
dart run build_runner build
flutter analyze
```

#### Manual way

1. Update `pubspec.yaml` → `name`, then replace `package:<old>/` across the repo
2. Update `android/app/build.gradle.kts` → `namespace` + `applicationId`
3. Move `android/app/src/main/kotlin/**/MainActivity.kt` into the directory matching the
   new namespace and update its `package` declaration（两者必须一致）
4. Update `android/app/src/main/AndroidManifest.xml` → `android:label`
5. Update `ios/Runner/Info.plist` → `CFBundleDisplayName`, `CFBundleName`
6. Update `ios/Runner.xcodeproj/project.pbxproj` → `PRODUCT_BUNDLE_IDENTIFIER`（含 `.RunnerTests`）
7. Replace the `MyApp` class name in `lib/app/app.dart`, `lib/bootstrap.dart` and its usages
8. Run `dart run build_runner build` to regenerate configs

### Pre-commit Hooks

This scaffold includes a pre-commit hook in `.githooks/pre-commit`（格式、架构边界、目录树一致性、依赖声明、analyze、测试覆盖率等多项检查）。

清单以脚本本身为准；每道门禁的语义与阈值见 `.trellis/spec/cross-cutting.md` —— 本文件不再逐项维护，内联的清单一定会过时。

To activate:

```bash
git config core.hooksPath .githooks
```

To skip (emergency only): `git commit --no-verify`

### Working Knowledge

The working knowledge you need lives under `.trellis/`:

- `.trellis/workflow.md` — development phases, when to create tasks, skill routing
- `.trellis/spec/` — package- and layer-scoped coding guidelines (read before writing code in a given layer); 跨层的门禁与发布约定在 `.trellis/spec/cross-cutting.md`
- `.trellis/workspace/` — per-developer journals and session traces
- `.trellis/tasks/` — active and archived tasks (PRDs, research, jsonl context)

If a Trellis command is available on your platform (e.g. `/trellis:finish-work`, `/trellis:continue`), prefer it over manual steps. Not every platform exposes every command.

If you're using an agent-capable tool, additional project-scoped helpers live in:

- `.agents/skills/` — reusable Trellis skills

Managed by Trellis. Edits outside this block are preserved; edits inside may be overwritten by a future `trellis update`.

<!-- TRELLIS:END -->

<!-- ═══════════════════════════════════════════════════════════════════════════
     以下内容由 preset/ai-starter 分支维护，**不在 Trellis 托管块内**，
     `trellis update` 不会覆盖它。改动时只维护这一段。
     ═══════════════════════════════════════════════════════════════════════════ -->

# AI 协作契约（preset/ai-starter）

本仓库是 `preset/ai-starter` 分支：状态管理 / 依赖注入 / 页面组合已从
**signals + get_it + flutter_hooks 换成 Riverpod 3**。分支基线、换掉了什么、
明确**不换**什么、以及为什么不回流 master，见 [`BRANCH.md`](./BRANCH.md)。

## 开工前必读三份

| 要做什么 | 先读 |
|---|---|
| 写页面 / provider / Notifier，或动 `core/` 的状态适配层 | [`.trellis/spec/frontend/state-management.md`](.trellis/spec/frontend/state-management.md) |
| 新增或改动 UI、组件、主题 | [`.trellis/spec/frontend/quality-guidelines.md`](.trellis/spec/frontend/quality-guidelines.md) |
| 新建 feature、增删文件、判断某文件该放哪 | [`.trellis/spec/frontend/directory-structure.md`](.trellis/spec/frontend/directory-structure.md) |

跨层的事（门禁、覆盖率、codegen、集成测试、环境配置）看
[`.trellis/spec/cross-cutting.md`](.trellis/spec/cross-cutting.md)；
数据层与网络看 [`.trellis/spec/backend/index.md`](.trellis/spec/backend/index.md)。

## 照抄对象：`lib/features/sample/`

新增 feature 时**先读 `features/sample/`**，按它的形状写。它覆盖了三种 data 形态
（Retrofit API / Drift DAO / `Result` 包装的 Service）与三种 provider 形态：

| 想看什么 | 文件 |
|---|---|
| Retrofit API 定义 | `lib/features/sample/data/sample_api.dart` |
| Drift 查询（**用** `@DriftAccessor`，见 `database-guidelines.md`） | `lib/features/sample/data/sample_dao.dart` |
| Service（`Result` + 错误映射） | `lib/features/sample/data/sample_service.dart` |
| Repository 抽象 + provider 装配 | `lib/features/sample/data/sample_repository.dart`、`sample_providers.dart` |
| `@freezed` 模型 | `lib/features/sample/data/models/sample_item.dart` |
| `AsyncNotifier` + `AsyncView` 页面 | `lib/features/sample/logic/sample_list_notifier.dart`、`page/sample_list_page.dart` |
| 对应的四类测试 | `test/features/sample/**` |

## 禁止模式速查（Riverpod 版）

上一代（master 的 signals + get_it 栈）的这些写法在本分支**都不存在**，
看到它们等于看到 bug：

| ❌ 不要写 | ✅ 本分支的写法 |
|---|---|
| `signal(...)` / `computed(...)` / `effect(...)` | `@riverpod` 顶层 provider、`Notifier`、`AsyncNotifier` |
| `asyncSignal<T>(AsyncState.data(...))` | `AsyncNotifier` 的 `Future<T> build()` → `AsyncValue<T>` |
| `AsyncState` / `AsyncState.map` | `AsyncValue` + `AsyncView`（**不要**用 `AsyncValue.when`） |
| `runAsync` / `runAsyncVoid` / `core/base/run_async.dart` | 框架内建：刷新 `ref.refresh(p.future)`、重试 `ref.invalidate(p)` |
| `getIt<Xxx>()` / `GetIt.I` / `@injectable` / `@LazySingleton` / `@module` / `*.config.dart` | provider + `ProviderScope(overrides:)` |
| `HookWidget` / `useMemoized` / `useEffect` / `useSignalValue` | `ConsumerWidget` / `ConsumerStatefulWidget` + `ref.watch` / `ref.listen` |
| `final VM? viewModel;` 这类可选注入点参数 | 不需要：注入口就是 `ProviderScope(overrides:)` |
| 业务代码里 `ProviderContainer(...)` | `ref`；容器只属于测试与 `bootstrap()`（`check_boundaries` 拦） |
| `build` 里 `ref.read(p)` 取**值** | `ref.watch(p)`；`ref.read(p.notifier)` 取实例是允许的（`check_conventions` 拦） |
| `AppLocalizations.of(context)` / ARB / `l10n.x` | 用户可见文案**直接写中文**（本分支已裁剪 l10n） |
| 手写 `fromJson` / `toJson` | `@freezed` + `json_serializable` 生成 |
| `features/*/logic/` 里 `import 'package:flutter/material.dart'` | logic 层不认识 widget 层（`check_boundaries` 拦） |

## `## 改完必跑`

```bash
dart run tool/verify.dart
```

一条命令跑完下面 9 项，**首个失败即停**。4 道脚本门禁在**同一个进程**里依次调用
（它们都是「纯函数 + 薄 main」），省掉 3 次 `dart run` 的 VM 启动与 sqlite3 build hook
—— 整块只快几秒（实测 44.3s → 39.1s），大头在 `flutter test` 与两次 analyze；
真正的收益是「只记一条命令」与「早停」：

```bash
dart format --output=none --set-exit-if-changed lib test tool   # 1 格式
dart run tool/check_boundaries.dart                            # 2 架构边界（lib）
dart run tool/check_conventions.dart                           # 3 build 里禁 ref.read 取值 / 注释块上限
dart run tool/check_readme_tree.dart                           # 4 README + spec 的目录树
dart run dependency_validator                                  # 5 声明与使用一致
flutter analyze lib/ test/                                     # 6
dart analyze tool/                                             # 7
flutter test --coverage                                        # 8
dart run tool/check_coverage.dart coverage/lcov.info --src=lib  # 9 阈值 80%
```

想只跑其中一项就直接跑上面那条命令。语义、阈值与理由见
[`.trellis/spec/cross-cutting.md`](.trellis/spec/cross-cutting.md)。

两条容易漏的：

- 增删了 `lib/` 下的文件或目录后，`README.md` 与 `frontend/directory-structure.md`
  里的目录树要同步，否则 `check_readme_tree` 会红；
- 改了注解 / 模型 / 文件增删后要重跑 codegen，并把生成物一起提交 —— CI 会比对这份 diff。

## 完成定义（DoD）

一项改动算完成，必须同时满足：

1. 上面那套命令**全部**退出码 0 —— 阈值与规则不许为了「让门禁变绿」而下调；
2. 新增 / 改动的用户可见代码有测试，且覆盖**错误分支**（只测 happy path 不算）；
3. 结构与 `lib/features/sample/` 一致；
4. 文档与代码一致：改了行为就同步 `.trellis/spec/` 或 `README.md`，
   **不留「照原文做会出错」的说明**。

> 本分支的提交约定是 `git commit --no-verify` + **手工跑完上面那套命令**（本地 pre-commit
> 在 Windows 上单次约 20 分钟，每次 `dart run` 都被 sqlite3 的 build hook 拖住）。
> 关掉钩子换来的是「必须自己跑并报出结果」的义务，**不是「可以不跑」**。
