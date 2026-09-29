# 修复 rename E2E：temp 副本缺 app_lints 的 package config

## 背景

CI `analyze` job 的最后一步 `Regression test (rename scaffold in temp dir)`
（`just test test/tool/init_project_test.dart`，`SCAFFOLD_E2E: 1`）失败：改名后的临时仓库里
`flutter analyze --no-fatal-infos` 退出码非 0，164 个 issue，绝大多数是
`packages/app_lints/test/rules_test.dart` 的 `undefined_method` / `extends_non_class`
（`assertDiagnostics` / `assertNoDiagnostics` / `newFile` / `newPackage` / `testPackageLibPath` /
`lint` / `reflectiveTest` / `ReflectiveTest`）。

这条失败被前两个更早的错误长期挡住，从未在 CI 上被跑到：08-19 那次是 freezed 需要 Dart ≥3.12
而 CI 钉的 Flutter 太旧；09-22 引入 `osv-scan` 后整个 workflow 直接 `startup_failure`（已由
PR #17 修好并合入 master）。它是「前面修好之后露出来的下一层」。

## Goal

让 rename E2E 恢复成可信的回归防线：临时副本的 bootstrap 与正式流程一致、步骤转绿，同时它
仍然能抓到「改名把 import 改断」。

## Requirements

- **R1** 临时副本里 `packages/app_lints` 必须能有自己的 package config。`analyzer_testing` 与
  `test_reflective_loader` 是它的 **dev_dependencies**，根工程的解析图里没有它们，只跑根
  `flutter pub get` 时 `packages/app_lints/test/**` 的 import 必然断。
- **R2** bootstrap 与 `just deps` 对齐 —— 那就是 `flutter pub get` +
  `cd packages/app_lints && dart pub get`。不许在测试里另造第二套流程。
- **R3** 不许把 `.dart_tool` 复制进临时副本。`package_config.json` 里写的是**绝对路径**，
  复制过去会把本机路径带进副本，换目录/换机器即失效。
- **R4** 不许把 `packages/` 从 E2E 的 analyze 范围里排除。`packages/app_lints/lib/src/paths.dart`
  里硬编码的 `selfPackagePrefix` 恰恰是改名最危险的一处（漏了它规则 1/2 静默放行），E2E 必须
  继续覆盖它 —— 缩小范围等于把这道防线删掉。
- **R5** 对外契约不变：仍然只在 `SCAFFOLD_E2E=1` 时跑，仍然断言「改名后 analyze 干净」
  （`exitCode == 0` 且无 `error -`）。
- **R6** E2E 必须仍然对「改名把 import 改断」敏感：补 bootstrap 不能把这道防线变成永远绿。

## Acceptance Criteria

- [ ] **AC1** 本地 `SCAFFOLD_E2E=1 flutter test test/tool/init_project_test.dart` 由红转绿；
  红的输出先留证据（164 issue / 1 failed）。
- [ ] **AC2** CI `analyze` job 的 `Regression test (rename scaffold in temp dir)` 步骤通过
  （以本次改动的 PR run 为准，不看本地）。
- [ ] **AC3** 反向验证：临时让改名脚本漏掉 `packages/app_lints/lib/src/paths.dart` 的
  `selfPackagePrefix`，E2E 必须失败；验证完还原，`git diff` 干净。
- [ ] **AC4** `just verify` 全绿（含 `.githooks/pre-commit`）。
- [ ] **AC5** 若「E2E 的 bootstrap 必须与 `just deps` 同步」属于下一个人会踩的知识，落进
  `.trellis/spec/guides/rename-checklist.md`（`packages/app_lints` 那一节是现成的坑位）。

## 约束

- 改动面限定在 `test/tool/init_project_test.dart`（必要时 `tool/init_project.dart` 的复制清单）
  + 文档；不动 `.github/workflows/ci.yml` 的结构。
- 生成物不入库；注释块 ≤10 行；注释与断言文案走中文，与既有风格一致。

## Notes（本任务的证据来源）

- 失败 run：`36517517564`（PR #17）步骤 `Regression test (rename scaffold in temp dir)`，
  日志末尾 `30 tests passed, 1 failed` + `164 issues found`。
- `packages/app_lints/pubspec.yaml`：dev_dependencies `analyzer_testing: ^0.4.2`、
  `test_reflective_loader: ^0.4.0`。
- 根 `.dart_tool/package_config.json` 里 `analyzer_testing|test_reflective_loader` 出现 **0** 次；
  根 `pubspec.yaml` 也**不引用** `app_lints`（它是 `analysis_options.yaml` 的路径插件）。
- `tool/init_project.dart`：`buildArtifactDirs` 含 `.dart_tool`（复制时跳过）；
  `_pubGet()` 由 E2E 只在 temp 根目录调用一次。
- `justfile`：`deps: flutter pub get` + `cd packages/app_lints && dart pub get`。
