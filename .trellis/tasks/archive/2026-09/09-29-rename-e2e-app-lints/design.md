# design — rename E2E 的 bootstrap 缺一个包

## 根因（假设，Phase 2 第一步先本地复现确认）

链条：E2E 复制仓库时按 `buildArtifactDirs` 跳过 `.dart_tool`（**含**
`packages/app_lints/.dart_tool/`）→ 复制完只在 temp **根目录**跑一次 `pub get` → temp 里的
`packages/app_lints/` 没有任何 package config，分析器向上回退到根 config，而根 config 里没有
`app_lints` 本身，也没有它的 dev_dependencies（`analyzer_testing` / `test_reflective_loader`）
→ `packages/app_lints/test/rules_test.dart` 的三个 import 全解析失败 → 基类
`AnalysisRuleTest` / 注解 `ReflectiveTest` 未知 → 所有继承成员变成 `undefined_method`，一个文件
贡献上百条 error。

**本地为什么绿**：本地 `packages/app_lints/.dart_tool/package_config.json` 存在（`just deps`
的第二条命令生成），`just analyze-tool` 分析 `packages/**` 时用它。

补充证据（与假设一致、但不足以单独定案）：164 条里点名未定义的都是
`analyzer_testing` / `test_reflective_loader` 提供的符号，外加 `CommentBlockTooLongRule`
这类 `package:app_lints/...` 里的符号 —— 即 `rules.dart` 那条 import 也一起断了。

## 候选方案

| 方案 | 内容 | 判定 |
| --- | --- | --- |
| **A（选定）** | 临时副本里对 `packages/app_lints` 补一次 `dart pub get`，与 `just deps` 对齐 | 语义正确：E2E 要模拟的就是「clone 之后 bootstrap」；覆盖 `packages/**` 不变 |
| B | temp 里的 `flutter analyze` 只扫 `lib test tool`（排除 `packages/`） | ✗ 违反 R4：`selfPackagePrefix` 是改名最危险的一处，正好被排除掉；这是绕开问题 |
| C | 复制时不跳过 `.dart_tool` | ✗ 违反 R3：config 里是绝对路径；而且会把本机 pub 缓存路径写进副本 |
| D | 把 `analyzer_testing` / `test_reflective_loader` 提到根 `pubspec.yaml` 的 dev_dependencies | ✗ 为了测试方便污染应用工程的依赖图；`app_lints` 刻意「自带 package config，与根工程互不干扰」 |

## 方案 A 的落地形态

1. `test/tool/init_project_test.dart`：把 E2E 里的 `_pubGet(flutter, temp)` 换成「按 `just deps`
   的两步走」——先 temp 根，再 `temp/packages/app_lints`。抽一个
   `_pubGetAll(String flutter, Directory root)` 承载这个语义，避免以后再漂移。
2. 子包用 `dart pub get`（与 `just deps` 一致；`app_lints` 不依赖 Flutter，`dart` 二进制可从
   `FLUTTER_ROOT` 推导）。若推导在多平台下太绕，退回 `flutter pub get`（对非 Flutter 包等价），
   但**注释里要写清这是等价而非同一条命令**。
3. 沿用现有 `_pubGet` 的「先 `--offline` 再联网」策略与 `runInShell: Platform.isWindows`
   处理；子包同样走这套，否则 Windows CI 会踩 `dart.bat`。
4. 可选的更强做法：在 temp 里直接跑 `just deps`（temp 自带 justfile，CI 装了 just）。它把
   「bootstrap 的定义」唯一化，但要依赖 temp 里 `just` 的可用性与 PATH 行为 —— 实现时评估，
   不通过就停在方案 1。

## 契约与影响面

- 生产代码/CI 结构：**不变**。只动 E2E 测试（可选：`.trellis/spec/guides/rename-checklist.md`）。
- 执行时间：CI 上多一次 `dart pub get`（离线优先，通常命中 `~/.pub-cache`）；换取这条 E2E
  第一次真正生效。
- 兼容性：`SCAFFOLD_E2E=1` 的开关契约不变；`PUB_CACHE` 语义不变。

## 风险

- **把防线改成永远绿**：若补 bootstrap 后 E2E 仍不因「import 改断」失败，说明断言被削弱 ——
  AC3 就是专门盯这个的反向验证，**必做**。
- **漂移**：以后新增第二个独立包，`just deps` 与 E2E 会再次不同步。这是本任务要留档的知识
  （AC5）：E2E 的 bootstrap 必须与 `just deps` 同步，二者定义在同一处或在文档里互指。
- 子包的 `pub get` 在离线缓存缺失时会联网 —— CI 允许，本地无网时该测试会失败。这与现状
  一致（根 pub get 也一样），不新增处理。

## 回滚

只动测试文件 → `git revert` / 单文件还原即可，无数据迁移、无发布影响。
