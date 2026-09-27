# 跨层与门禁

> 不属于单一层、或同时管「门禁」与「发布」的约定。
> 层次内的规则见 [spec/index.md](index.md)。

---

## 架构边界与形态约定（`packages/app_lints/` 插件）

四条规则由**分析插件**实现（`analysis_server_plugin`），不是脚本：

| 规则 | 效果 |
|------|------|
| `no_upper_import_in_core` | `core/**` 不能 import/export `features/**` 或 `app/**` —— 依赖方向只能是 features → core |
| `cross_feature_only_data` | 不能 import/export 其他 feature 的 `page/` / `logic/` —— 跨 feature 只共享 `data/` |
| `no_material_import_in_logic` | `features/*/logic/` 不得 import/export `package:flutter/material.dart` / `widgets.dart`，也不得 import 本 feature 的 `page/` 层文件 |
| `avoid_ref_read_in_build` | `build` 里不得用 `ref.read` 取 provider 值；`ref.read(xxx.notifier)` 不在管辖内 |

| 想看什么 | 文件 |
|---|---|
| 规则实现（AST 适配 + 判据） | `packages/app_lints/lib/src/rules.dart` |
| 路径 / URI 解析（纯函数） | `packages/app_lints/lib/src/paths.dart` |
| 规则测试（`analyzer_testing`） | `packages/app_lints/test/rules_test.dart` |
| 插件入口（`final plugin = ...`） | `packages/app_lints/lib/main.dart` |

**启用点**（根 `analysis_options.yaml`）：

```yaml
plugins:
  app_lints:
    path: packages/app_lints
```

四条都用 `registerWarningRule` 注册 → **默认开**，不需要在 `diagnostics:` 里逐条打开（只有 `registerLintRule` 注册的才默认关）。`riverpod_lint` 走同一套机制（`plugins:` + warning 层默认开），见 `pubspec.yaml` 与 `analysis_options.yaml`。

### 包的摆法

- 插件是**独立 package**，**不并进 workspace**（`just deps` 分别解析根工程与 `packages/app_lints`）。
- `packages/` 只放**真正独立的工具包**；app 代码不抽包，`lib/core/` 保持拍平。
- 包名硬编码在 `packages/app_lints/lib/src/paths.dart`（`selfPackagePrefix`），改包名时 `tool/init_project.dart` 会一起替换。

### 调用形式：`dart analyze` 必须显式传文件名

- **插件诊断只在显式传文件名时输出**：单文件、多文件都行，**传目录不行**。
- **不要用 `flutter analyze` 当架构门禁**：它不加载 `plugins:`（[flutter#187999](https://github.com/flutter/flutter/issues/187999)）。
- **不要自己拼 analyze 命令，跑 `just verify`** —— 根 `justfile` 两步 analyze 已带显式文件列表（列表由 `tool/list_dart_files.dart` 生成）。
- 读门禁输出要用的退出码：info → 0、warning → 2、error → 3、info + `--fatal-infos` → 1。
- **规则必须挂在会被执行的命令上**：门禁全部由分析插件与现成命令实现，没有自定义检查脚本。

### 判据细节

- 全部规则先过 `context.isInLibDir`——只有 `lib/` 下的文件参与判断。
- **生成物豁免**：每条规则自带 `isGeneratedPath` 判断（`.g.dart` / `.freezed.dart` / `.gr.dart` / `.config.dart` / `.gen.dart` / `/gen/` / `app_localizations`）。口径与 `.gitignore` 一致，改动要一起改。
- 放行的情况：feature 引用自己、组合根（`lib/app/`）引用任何 feature（FSD 的 app 层负责装配）、生成文件。`core/` 引用 `lib/core/` 内部也放行。
- `no_material_import_in_logic` 拦三样：`package:flutter/material.dart`、`package:flutter/widgets.dart`、本 feature 的 `page/` 层文件。`foundation` 不管；跨 feature 的 `page/` 由 `cross_feature_only_data` 拦；管辖范围只有 `features/*/logic/`。
- `avoid_ref_read_in_build` 的判据是三个 AST 事实：「最近的 `MethodDeclaration` 祖先叫 `build`」（方法体里的闭包也算）、「目标是 `ref` 或 `.ref` 属性（`this.ref` 同样拦）」与「实参不是 `.notifier`」。豁免 `.notifier`。

### 禁止模式

```dart
// ❌ 跨 feature 引用 page/logic
import 'package:my_app/features/sample/page/sample_list_page.dart';
import 'package:my_app/features/sample/logic/sample_list_notifier.dart';

// ✅ 允许：引用 core，或另一个 feature 的 data 层
import 'package:my_app/features/sample/data/sample_repository.dart';
import 'package:my_app/app/routing/router.dart';
```

```dart
// ❌ build 里用 ref.read 取值
final value = ref.read(sampleListProvider);

// ✅ 读值用 watch；一次性取值（方法 / 回调里）才用 read
final value = ref.watch(sampleListProvider);
await ref.read(userPreferencesProvider).setThemeMode(mode);
```

```dart
// ❌ core/ 反向依赖业务
import 'package:my_app/features/sample/data/sample_repository.dart';

// ✅ core 只依赖 core 与第三方包
import 'package:my_app/core/base/result.dart';
```

> **页面不设构造注入点。** 测试替身一律走 `ProviderScope(overrides:)`，页面不持有 `final Xxx? viewModel;` 这类可注入字段。

### 不要新加的门禁规则

这三条**不要**当「缺失的门禁」补上，由 review 兜底：

- 在 `features/*/logic/` 手动建 `ProviderContainer`
- 连续注释块 ≤10 行（`comment_block_too_long`）——「长解释进 spec」照旧，见 [guides/comment-guidelines.md](guides/comment-guidelines.md)，不用 lint 拦
- `avoid_async_state_map`

---

## 目录树一致性（无门禁）

README 与 [frontend/directory-structure.md](frontend/directory-structure.md) 里的 `lib/` 目录树**没有门禁核对**，纯靠人工维护。增删 `lib/` 文件后同步这两处。

---

## 覆盖率（不设门禁）

`just verify` 不含覆盖率，pre-commit 与 CI 也不查覆盖率：跑测试就是 `flutter test`，不带 `--coverage`、不生成 lcov。临时看数字自己跑 `flutter test --coverage`，不拦提交。

---

## 改名脚本（`tool/init_project.dart`）

```bash
dart run tool/init_project.dart                                  # 交互式
dart run tool/init_project.dart --yes --name=my_next_app --application-id=com.example.my_next_app   # 非交互（CI / 脚本）
```

覆盖范围见 [guides/rename-checklist.md](guides/rename-checklist.md) 的 9 项表（`pubspec` 包名、全仓库 `package:<旧名>/`、根组件类名、Android / iOS 的标识与显示名、`MainActivity.kt` 连目录一起搬）。其中 **`packages/app_lints/lib/src/paths.dart` 里硬编码的 `package:<包名>/` 前缀最要命**。

两条语义，改了要同步 `test/tool/init_project_test.dart`：

- **全有或全无**：先规划、后写盘。任一必改点没匹配到 → 列出「哪一处没对上」并以非零退出码结束，磁盘不变。
- **可选项不拦**：文档、`.gitignore`、`<旧名>.code-workspace` 这类文本里的裸包名改不到只提示，不影响退出码。

回归测试分两层（逐条见 rename-checklist「回归测试」）：fixture 跑在每次 `flutter test` 里；端到端那条要 `SCAFFOLD_E2E=1`（CI 的 `analyze` job 带了它），改名后跑 `flutter pub get` + `flutter analyze`，用 `--no-fatal-infos` —— 只看 error，既存 info 与 `directives_ordering` 不算失败。

---

## 依赖声明（`depend_on_referenced_packages`）

「声明与使用是否一致」只由 analyzer 自带的一条 lint `depend_on_referenced_packages` 负责，它在 `analysis_options.yaml` 的 `analyzer.errors` 里被显式提升为 **error**，**不依赖跑它的那条命令**。豁免就是就地一条 `// ignore: depend_on_referenced_packages -- 理由`。

| 检查 | 谁管 |
|------|------|
| 在 `lib/` 里 import 了只声明在 `dev_dependencies` 的包（under-promoted） | `depend_on_referenced_packages`（配置里是 error）；`dart analyze --fatal-infos` 拦 |
| import 了压根没声明的包（missing） | 同上 |
| **`tool/` 与 `packages/` 里的同类问题** | 同上 —— 门禁用显式文件列表执行 `dart analyze --fatal-infos`，口径没有分叉 |
| 声明成 `dependency` 却只在 `test/` `tool/` 里用（over-promoted） | **无人管**（有意） |
| 声明了但没人用（unused） | **无人管**（有意） |
| pubspec 里写了精确版本（pinned） | **无人管**（有意） |

后三类**无人管**（有意）—— **不要**引入 `dependency_validator` 这类工具来管它们。

**级别写在配置里，不靠命令行 flag**：规则级别进 `analysis_options.yaml`，两步 analyze 统一 `dart analyze --fatal-infos` 并显式传文件，于是 `tool/` 与 `packages/` 的 info 也按 `lib/` `test/` 的严格度拦。

### `json_annotation`：必须声明，别删

它是 `json_serializable` 的**构建期契约**：生成 `lib/` 下的代码时，该包要求 `json_annotation` 出现在 pubspec 的 `dependencies` 且下界 ≥ `4.12.0`（判据是 `json_serializable/lib/src/check_dependencies.dart` 的 `requiredJsonAnnotationMinVersion`）。源码里不会出现它的 import —— `@JsonKey` 只出现在生成的 `sample_item.freezed.dart` 里，符号经 `freezed_annotation` 的 re-export 提供。

---

## 供应链门禁（`dart pub outdated` / OSV）

| 环节 | 位置 | 语义 |
|------|------|------|
| `dart pub outdated` | `analyze` job 的一步，`continue-on-error: true` | **只报告**，不拦合并 |
| OSV 扫描 | 独立的 `osv-scan` job（官方 reusable workflow） | 发现漏洞即 **失败** |

升级时机由人按 [docs/release-checklist.md](../../docs/release-checklist.md) 排。

两个实现细节：

- 用官方 reusable workflow（`google/osv-scanner-action/.github/workflows/osv-scanner-reusable.yml@v2.6.0`），不自己拼 `run: osv-scanner …`。版本是**固定 tag**，升级只改这一处。
- `scan-args` 显式给根工程与独立插件包两份 lockfile（默认 `-r ./` 会连 `build/`、`.dart_tool/` 一起扫）；`upload-sarif: false`。

> 与 [release-checklist.md](../../docs/release-checklist.md) 的分工：清单管「发版前必须人工确认的事」，这里管「每次 push / PR 自动挡住的事」。

---

## 代码生成与生成物（codegen）

### 策略：生成物不入库（gitignore）

`.gitignore` **排除**生成物，它们不提交进 git。判定「哪些是生成物」的口径与 `packages/app_lints/lib/src/paths.dart` 的 `isGeneratedPath()` 对齐（插件在 IDE / 手工 analyze 场景也要豁免它们）：

| 形态 | 例子 |
|------|------|
| `*.g.dart` | `json_serializable` / `retrofit` / `drift` 的行类 / **`@riverpod` 生成的 provider** |
| `*.freezed.dart` | 模型 |
| `*.gr.dart` | `auto_route` 的路由类 |
| `*.config.dart` | `injectable` 的 DI 注册（本项目不使用 injectable，无此生成物） |
| `*.gen.dart`、路径含 `/gen/` | 资源访问器（当前不存在，本项目不用 `flutter_gen`） |
| 路径含 `app_localizations` | l10n 生成物（本项目已裁剪 l10n，见 [frontend/localization.md](frontend/localization.md)） |

### 重新生成时机

| 时机 | 命令 |
|------|------|
| 改了注解，或新增模型 / API / DAO / `@RoutePage` / `@riverpod` | `just codegen` |
| 增删代码文件（含删掉整个 feature） | 同上。删文件后**必须**重跑 |
| clone 后首次构建 / analyze / test | `just codegen` |
| 改了 `lib/l10n/*.arb` | `flutter gen-l10n`（本项目已无 l10n，见 [frontend/localization.md](frontend/localization.md)） |
| 升级 / 降级任一 codegen 包（`freezed`、`json_serializable`、`drift_dev`、`retrofit_generator`、`auto_route_generator`、`riverpod_generator`、`build_runner`） | `just codegen-reset` |
| 升级 Flutter / Dart SDK | 同上 |
| 切分支、rebase / merge 后本地生成物与源不一致 | 重跑 `just codegen`（生成物不手工编辑） |

**不要加 `--delete-conflicting-outputs`**（已从 build_runner 移除）。要退回旧行为是 `--keep-modified-outputs`（见「禁止模式」）。

### 门禁与 CI

- **本地 `just verify` 不跑 codegen**（假定生成物已在磁盘上）；**pre-commit 有意不跑**。
- **CI 的 `analyze` job 在 `just verify` 前跑 `just codegen`**：现场生成，无需比对 git diff（生成物不入库，没有可比对象）。codegen 统一排在 analyze 之前。
- `drift_dev` 生成 schema 需要 `sqlite3` 的动态库（本项目由 `sqlite3` 3.x 的 build hook 提供，`just deps` 会准备）。
- 这一步**没有** `flutter gen-l10n`（本项目没有 l10n，见 [frontend/localization.md](frontend/localization.md)）。

### 禁止模式

```bash
# ❌ 编译不过时跑 build_runner —— 先让 `dart analyze` 收敛再生成
# ❌ 手改生成物
# ❌ 把生成物 `git add -f` 加回版本库 —— 策略是不入库；.gitignore 与 isGeneratedPath 是同一口径
# ❌ 用 --keep-modified-outputs 留住手改
```

---

## build_runner 升级与缓存：现行结论

- **不升级**：已在 2.x 最新，没有可升的版本。**不要**把 pubspec 约束收紧成 `^2.16.1`。重估信号：某个生成器抬高对 build_runner 的下限（`just deps` 会直接报冲突），或撞上 2.x 修不掉的构建 bug。
- **真要升级的顺序**：改约束 → `flutter pub upgrade <pkg>` → `dart run build_runner clean` 后全量重建 → 以测试核对生成物形状（生成物不入库，没有 diff 可 review）→ `flutter analyze` + `flutter test`。
- **不引入目录级 cache，CI 也不 cache `.dart_tool/build/`**：build_runner 自带 asset 级增量（`.dart_tool/build/`，已在 `.gitignore` 里）。
- codegen 真成瓶颈时的顺序：先 `just codegen --verbose-durations` 量出时间花在哪个 builder，再决定砍 builder 还是改构建结构，**最后**才考虑缓存。不要从「加个 cache」起步。

---

## 内存泄漏检测（`leak_tracker`）

### 运行期检测（debug 模式）

在 `bootstrap.dart` 中通过 `_initLeakTracker()` 初始化，debug 模式下自动启用：

- 监听 `FlutterMemoryAllocations` 事件（Flutter 框架对象的创建/销毁），在控制台输出未释放的对象信息
- release 模式下不生效

### 测试检测

`test/flutter_test_config.dart` 配置了全局泄漏检测：

- 所有 `testWidgets` 自动启用 `LeakTesting`，测试中未 dispose 的 Widget、Controller、流订阅等会被报告
- 通过 `withIgnored(createdByTestHelpers: true)` 过滤测试辅助创建的对象
- `ConsumerWidget` / `ConsumerStatefulWidget` 最终也是 Flutter `Element`，在覆盖范围内

> ⚠️ **`leak_tracker` 看不见 provider 的状态对象**：`ProviderContainer` / `Notifier` / `AsyncValue` 是纯 Dart 对象，不上报 `FlutterMemoryAllocations`。**「测试里没报警」不等于「状态没有泄漏」** —— 兜底是 `autoDispose` 与 `ref.onDispose`，见 [frontend/state-management.md](frontend/state-management.md)「生命周期」。

---

## 集成测试

### 本地运行

```bash
flutter test integration_test/
```

### CI 运行

CI 用 `reactivecircus/android-emulator-runner` 在 Android 模拟器上跑（目标平台是 Android / iOS）。**不要**用 `xvfb-run`。

### widget 测试里不要用真实 I/O

`testWidgets` 的 `pumpAndSettle` 走**假时钟**，真实的文件 / 数据库 I/O 不会在它推进的这段时间里完成。

约定：**真实依赖用普通 `test()` 测**（那些测试没有假时钟），**页面测试把依赖 mock 掉、用 `ProviderScope(overrides:)` 换成假实现**。范例：`test/features/sample/data/sample_dao_test.dart`（真实 Drift + 内存数据库）与 `test/features/sample/page/sample_list_page_test.dart`（overrides 假仓库 + 驱动 provider 状态）。另外 `ListView` 只布局可视区内的子节点，视口外的内容 finder 找不到——测长页面时要么放大视口（`tester.view.physicalSize`），要么先滚动。

### 测试内容

当前集成测试覆盖（快照 2026-09，实际以 `integration_test/app_test.dart` 为准）：

- 应用正常启动，经启动页（约 1.8s 动画，2.2s 后跳转）进入 `MainRoute` 主框架
- 底部导航栏存在、首页文案渲染出来
- 点击「示例」标签能切换，且 `NavigationBar.selectedIndex` 跟随

约束与注意事项：

- **`bootstrap()` 不可重入**：`prefsProvider` 的 override 与 leak_tracker 启动都只能执行一次。整个冒烟流程只在**一个** `testWidgets` 中调用一次 `app.main()`。
- **启动页要显式推进时钟**：`Future.delayed(2200ms)` 是计时器，`pumpAndSettle()` 之后补一次 `pump(Duration(seconds: 3))`。
- **不需要清理登录态**：本项目没有认证。
- **字体**：主题（`lib/core/theme/app_theme.dart` 的 `_textTheme`）**不指定字体家族**，走平台默认。引入按需下载字体（`google_fonts` 等）时，测试里设 `GoogleFonts.config.allowRuntimeFetching = false`，生产把字体打进产物。
- `msw_dio_interceptor` 的 mock 由注入的 `USE_MOCK` 控制（示例 `.env.example` 默认 `true`）。写 mock 规则必须 `MockRule.regex` 且锚定结尾，见 [backend/network-guidelines.md](backend/network-guidelines.md) 的 Mock 一节。

---

## 环境配置与 release 构建

环境值放在**入库的 `.env.example`**，由 `bootstrap()` 用 dotenv 加载（`await dotenv.load(fileName: '.env.example')`；`lib/bootstrap.dart` 校验 `BASE_URL`，`NetworkConfig.fromEnv(dotenv.env)` 消费）。它同时声明在 `pubspec.yaml` 的 `assets:` 里 —— **dotenv 只能加载 asset**，所以换环境不能靠换文件；真实 `.env` / `.env.*` 已被 `.gitignore` 忽略，密钥走 `--dart-define`。

```bash
just run                # = flutter run（dotenv 自己读 .env.example）
flutter build apk       # 发版构建，配置同样来自 .env.example
```

- **不要**加 `.env` / `.env.development` 这类文件并指望运行时加载：它们不在 `assets:` 里，dotenv 读不到。密钥只能走 `--dart-define`。
- `flutter test` 的单元 / 组件测试不需要 env —— 用 `networkConfigProvider.overrideWithValue` 注入配置。
- `BASE_URL` 缺失时 `bootstrap()` 直接抛异常。

### 有意留白（模板不提供的部分）

以下属于**目标应用**的职责，脚手架刻意不配置：

- **release 签名**：`android/app/build.gradle.kts` 的 release 仍使用 debug keystore，没有 `key.properties` / `signingConfigs.release`
- **minify / 混淆**：未开启 `isMinifyEnabled` / `isShrinkResources`，也没有 `proguard-rules.pro`；构建脚本未加 `--obfuscate --split-debug-info`
- **build flavor**：未做 dev/staging/prod flavor，环境切换改 `.env.example`（或用 `--dart-define` 覆盖单个值）代替
- **iOS release 签名**：描述文件与证书需在 Xcode 中配置
