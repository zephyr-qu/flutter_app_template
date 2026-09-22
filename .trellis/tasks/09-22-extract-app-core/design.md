# 技术设计：packages/app_core

## 1. 边界判定

**唯一判据**：该文件是否 import 了状态管理库。

| 文件 | 是否有状态管理 import | 归属 |
|---|---|---|
| `core/base/failure.dart` | 否 | app_core |
| `core/base/result.dart` | 否 | app_core |
| `core/base/run_catching.dart` | 否 | app_core |
| `core/base/run_async.dart` | **是**（signals） | 留 master |
| `core/logging/*` | 否 | app_core |
| `core/models/*` | 否 | app_core |
| `core/data/network/*` | 否 | app_core |
| `core/data/database/*` | 否 | app_core |
| `core/theme/*` | 否 | app_core |
| `core/ui/{loading_indicator,error_text,empty_widget}.dart` | 否 | app_core |
| `core/ui/{async_view,failure_message}.dart` | 部分是 | async_view 留分支；failure_message 需摘掉 `AppLocalizations` 依赖 |
| `core/data/storage/auth_storage.dart` | **是**（signal + computed） | 留 master / ai-starter 各一份 |
| `core/config/user_preferences.dart` | **是**（signal） | 同上 |
| `core/core_module.dart` | 否，但用 `@module`（injectable 注解） | 需拆分：依赖注入方式本身是栈相关的 |

### 关键设计决策：`failure_message.dart` 怎么办

它把 `FailureCode` 翻译成用户文案，当前直接依赖 `AppLocalizations`。

**方案**：拆成两半。
- `app_core` 提供 `String failureMessageZh(FailureCode code)`——**纯常量映射，无 l10n 依赖**
- 各分支的 `core/ui/failure_message.dart` 负责本地化包装（master 走 `AppLocalizations`，ai-starter 同）

这样 `--l10n=single` 裁剪时只需改分支侧，包侧不动。

### 关键设计决策：`core_module.dart` 怎么办

`@module`（injectable）本身是 DI 方式，不是基础设施。拆法：

- 包内保留**纯工厂函数**：`Dio createDio({required NetworkConfig config, required AuthStorage auth, ...})`
- 各分支的 DI 层（`@module` 或 `@riverpod`）只负责把这些工厂接进容器

即包负责「怎么造」，分支负责「谁来提供」。

## 2. pubspec 设计

```yaml
# packages/app_core/pubspec.yaml
name: app_core
description: 与状态管理无关的基础设施（网络 / 数据库 / 主题 / 日志 / 模型）
publish_to: "none"

environment:
  sdk: ">=3.13.0 <4.0.0"
  flutter: ">=3.44.0"

dependencies:
  flutter: {sdk: flutter}
  dio: ...
  retrofit: ...
  drift: ...
  flex_color_scheme: ...
  logger: ...
  flutter_secure_storage: ...
  # 不出现：signals_* / riverpod* / get_it / injectable

dev_dependencies:
  build_runner: ...
  retrofit_generator: ...
  drift_dev: ...
  json_serializable: ...
```

根 `pubspec.yaml` 增加：

```yaml
dependencies:
  app_core:
    path: packages/app_core
```

## 3. 生成物与 codegen

包内 `*.g.dart` / `*.freezed.dart` 会跟着移动到 `packages/app_core/lib/**`。两条约束：

1. `tool/check_boundaries.dart` 的 `isGeneratedPath` 与 `dartFiles` 要能覆盖 `packages/app_core/lib`
2. `tool/check_coverage.dart` 的剔除口径复用同一个 `isGeneratedPath`，无需额外改

**生成命令**：`dart run build_runner build` 需要在根与包内各跑一次，或在 README/spec 记录统一入口。

## 4. 实施顺序（降低中途破损的窗口）

1. 建包骨架 + pubspec，根 pubspec 加 path 依赖，`flutter pub get`
2. 先搬**零依赖**的文件（`base/failure`、`base/result`、`base/run_catching`、`logging/`、`models/`），跑一次 analyze
3. 再搬 `network/`、`database/`（含 codegen）
4. 再搬 `theme/`、`ui/` 三件套
5. 最后处理 `failure_message` 拆分与 `core_module` 工厂化
6. 扩展 `check_boundaries` 的扫描根 → 跑门禁
7. 更新 README 目录树 → 跑 `check_readme_tree`

每步之后 `flutter analyze lib/` 应保持干净（用 IDE 的自动 import 修正或逐文件改 import 路径）。

## 5. 回滚

整体是一个可 `git revert` 的提交序列；过程中任一步失败可 `git checkout -- .` 回到上一步。不改动任何业务行为，因此**不需要数据迁移或分阶段发布**。
