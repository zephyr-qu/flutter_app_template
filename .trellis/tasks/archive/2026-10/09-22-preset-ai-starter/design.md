# 技术设计：preset/ai-starter

## 1. 规模基线（迁移前实测）

| 项 | 数量 |
|---|---|
| `lib/` 手写文件 | 57 |
| 与 signals 耦合 | 15 |
| 与 getIt / injectable 耦合 | ~24（含少量文档性误报） |
| 两栈需重写 | ~30（全部 page + 全部 logic + core 状态适配层） |
| 两栈共有 | ~27（由 `09-22-extract-app-core` 消解为 0） |

## 2. 概念映射表

| master（signals） | ai-starter（Riverpod 3） |
|---|---|
| `AsyncState<T>`（sealed，含 `dataRefreshing`） | `AsyncValue<T>`（`.when` / `.valueOrNull` / `.isRefreshing`） |
| `asyncSignal<T>()` | `AsyncNotifier` / `FutureProvider` |
| `signal<T>()` | `Notifier` / `Provider` |
| `computed(() => ...)` | `Provider` + `ref.watch` |
| `ReadonlySignal<T>` getter | provider 天然对外只读 |
| `useSignalValue(vm.x)` | `ref.watch(xProvider)` |
| `runAsync()` 的 `Expando` 竞态保护 | **框架内建**：`ref.invalidateSelf()` + `AsyncValue.copyWithPrevious` |
| `dataRefreshing(previous)` 保留旧数据 | `AsyncValue` 刷新时**默认**保留旧值 |
| `getIt<X>()` | `ref.watch(xProvider)` |
| `@injectable` 构造器注入 | `@riverpod` 参数即依赖 |
| `@module`（4 个 Module 类） | `@riverpod` 顶层 provider 函数 |
| `HookWidget` + `useMemoized` | `ConsumerWidget` / `ConsumerStatefulWidget` |
| — | **新增** `ProviderScope` 包在 `runApp` 外层 |

> `lib/core/base/run_async.dart` 可整体删除——它手写的「最后一次胜出 + 保留旧数据」在 Riverpod 是框架默认行为。随之 `test/core/base/run_async_test.dart`（11.7 KB）也可删除。

## 3. 文件级改动分类

### 删除（6）

```
lib/di/service_locator.dart
lib/di/service_locator.config.dart
lib/core/base/run_async.dart
lib/core/core_module.dart                     → 内容迁为 @riverpod providers
lib/features/auth/data/auth_module.dart       → 同上
lib/features/article/data/article_module.dart → 同上
```

### 重写（约 24）

| 分组 | 文件 |
|---|---|
| page（7） | `article_list` `article_detail` `login` `home` `profile` `storage_demo` `splash` → `ConsumerWidget` |
| logic（4） | `article_view_model` `auth_view_model` `storage_demo_view_model` → `@riverpod` Notifier |
| core 适配层（3） | `async_view.dart`（改吃 `AsyncValue`）、`auth_storage.dart`、`user_preferences.dart` |
| DI → provider（4） | `dio_client`（`NetworkModule.dio()`）、`file_storage`、`auth_service`、`article_service` |
| 装配（3） | `app.dart`（`ProviderScope`）、`auth_reevaluate.dart`（`ref.listen`）、`router.dart`（守卫改读 provider） |

### 不动（约 27）

已由 `packages/app_core` 承载（`failure` / `result` / `run_catching` / `logging` / `models` / `network` / `database` / `theme` / 三态 UI 组件 / 各 feature 的 `api|service|model`）。

## 4. pubspec 变更

**移除**：`signals_flutter`、`signals_hooks`、`flutter_hooks`、`get_it`、`injectable`、`injectable_generator`、`flex_color_scheme`

**新增**：`flutter_riverpod`、`riverpod_annotation` + dev `riverpod_generator`、`riverpod_lint`、`custom_lint`

## 5. 门禁调整

| 门禁 | 调整 |
|---|---|
| `check_boundaries.dart` 规则 1 | 禁 `getIt` 失效 → 改为禁 `features/*/logic/` 出现 `ProviderContainer`（Riverpod 世界的等价 service locator） |
| `check_boundaries.dart` 新增规则 | `features/*/logic/` 不得 `import 'package:flutter/material.dart'`（保持 logic 纯 Dart；signals 栈做不到这条，Riverpod 栈可以） |
| `check_coverage.dart` | **无需改**——`riverpod_generator` 输出 `*.g.dart`，已在剔除列表 |
| `check_readme_tree.dart` | 目标树删 `lib/di/`、加 `ProviderScope`，否则必挂 |
| `dependency_validator` | 自动适配（依赖声明同步增删即可） |

## 6. spec 重写清单

| 文件 | 动作 |
|---|---|
| `frontend/state-management.md` | **重写** |
| `frontend/hook-guidelines.md` | **重写或删除** |
| `frontend/quality-guidelines.md` | **重写禁止/必须模式** |
| `frontend/directory-structure.md` | 删 `di/` 段并更新目录树 |
| `backend/*` | **不动**（网络/数据库/错误处理与状态管理无关） |
| `docs/adr/ADR-0002.md` | 标注「仅适用于 master（signals 栈）」 |
| `docs/architecture-review.md` | 同上标注，P1/P5/P7 结论仅对 signals 栈成立 |

## 7. AI 协作契约（AGENTS.md）

改写为：

1. **必读三份**（置顶）：新的 `state-management.md`、`quality-guidelines.md`、`directory-structure.md`
2. **`## 改完必跑`**：format → check_boundaries → check_conventions → dependency_validator → analyze → test --coverage → check_coverage
3. **禁止模式速查**：`ProviderContainer()` 手动 new、`logic/` 引 material、构建期用 `ref.read`、绕过 `AsyncValue` 手写三态
4. **`features/sample/` 金标准**：唯一照抄对象
5. **DoD**：新会话 AI 盲测新增 feature 并过全部门禁

## 8. 实施顺序

1. 从 `master` 切 `preset/ai-starter`
2. 依赖替换 + 删 `lib/di/` + 接 `ProviderScope` → `flutter analyze`
3. core 适配层（`async_view` / `auth_storage` / `user_preferences`）→ `flutter test`
4. features 迁移 → `flutter test`
5. 重写三份 spec + ADR 标注
6. `AGENTS.md` 契约 + `features/sample/` + README 目录树
7. 门禁全绿 → 盲测 DoD
8. 写 `BRANCH.md`

## 9. 回滚

分支隔离，`master` 不受影响；放弃即删分支。**不回流**，所以不存在合并冲突风险。
