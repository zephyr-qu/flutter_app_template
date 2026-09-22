# 抽 `packages/app_core` 供 signals / Riverpod 双栈共用

## Goal

把**不依赖状态管理**的基础设施抽成本地包，让 `master`（signals 栈）与 `preset/ai-starter`（Riverpod 栈）共用一份实现。

**要解决的量化问题**：两个栈目前有 **27 个文件共有**，每次改动都要手工同步两遍——其中包含 `auth_interceptor.dart`、`token_refresher.dart`、`dio_client.dart` 这类安全敏感 + 逻辑复杂的文件，恰恰是最需要同步的。抽包后共有面 **27 → 0**。

## Requirements

- 新建本地包 `packages/app_core`，以 path 依赖被 `master` 消费
- **包内不得出现** `signals_*`、`signals_core`、`riverpod*` 的 import（这是包能同时服务两栈的前提）
- `master` 行为完全不变：六道门禁全绿，现有测试一条不改地通过
- 不引入 melos 等额外工具链（用最朴素的 path 依赖 + 现有门禁）

## 包内容（27 个文件）

```
packages/app_core/
  pubspec.yaml
  lib/
    app_core.dart            # barrel 出口（可选）
    src/
      base/       failure, result, run_catching
      logging/    logging, log_redactor
      models/     user, token_set
      network/    dio_client, auth_interceptor, token_refresher, auth_extra_keys
      database/   app_database + tables
      theme/      app_color_scheme, app_theme, app_theme_extension
      ui/         loading_indicator, error_text, empty_widget
```

## 留在各分支的（状态耦合适配层）

- `auth_storage`（signals 版 / Riverpod 版各一份）
- `user_preferences`（同上）
- `async_view`（signals 版吃 `AsyncState`；Riverpod 版吃 `AsyncValue`）
- 全部 `page/` 与 `logic/`

## Acceptance Criteria

- [ ] `packages/app_core` 内 `grep -rE "signals|riverpod" lib/` 结果为空
- [ ] `master` 六道门禁全绿：format / check_boundaries / check_conventions / dependency_validator / analyze / check_coverage
- [ ] `lib/` 手写文件数下降约 27，且 `lib/core/` 只剩状态耦合的适配层与 `core_module`
- [ ] `tool/check_boundaries.dart` 已覆盖 `packages/app_core`（或明确记录未覆盖及理由）
- [ ] `tool/check_readme_tree.dart` 的校验目标已包含新包目录树（或明确记录不校验）
- [ ] `dependency_validator` 通过，path 依赖声明位置正确

## Notes

- **风险 1**：`check_boundaries.dart` 目前只扫 `lib/`，抽包后新包会成为**边界真空**。必须扩展扫描根，否则等于用新包换掉了一道门禁。
- **风险 2**：`check_readme_tree.dart` 校验 README 里的 `lib/` 目录树；抽包后 README 的树结构要重画。
- **参考**：仓库历史上用过 `packages/my_app_lint` 的同构结构（已在 `0ebe388` 移除），`pubspec.yaml` 写法可对照。
- 本任务是 `09-22-preset-ai-starter` 的**前置**，必须先完成。
