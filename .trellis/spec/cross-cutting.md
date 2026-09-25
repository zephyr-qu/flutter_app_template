# Cross-Cutting Concerns

> 不属于单一层、或同时管「门禁」与「发布」的约定。
> 层次内的规则见 [backend/](backend/index.md) 与 [frontend/](frontend/index.md)。

---

## 架构边界与形态约定（`packages/app_lints/` 插件）

四条规则由**分析插件**实现（`analysis_server_plugin`），不是脚本：

| 规则 | 效果 |
|------|------|
| `no_upper_import_in_core` | `core/**` 不能 import/export `features/**` 或 `app/**` —— 依赖方向只能是 features → core |
| `cross_feature_only_data` | 不能 import/export 其他 feature 的 `page/` / `logic/` —— 跨 feature 只共享 `data/` |
| `no_material_import_in_logic` | `features/*/logic/` 不得 import/export `package:flutter/material.dart` |
| `avoid_ref_read_in_build` | `build` 里不得用 `ref.read` 取 provider 值；`ref.read(xxx.notifier)` 不在管辖内 |

前两条是依赖方向；后两条是同一件事的两面：状态层与 UI 之间必须有明确的接线口（provider + `ref`），而不是自己建容器、或伸手进 widget 层去拿 `BuildContext`。

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

四条都用 `registerWarningRule` 注册 → **默认开**，不需要在 `diagnostics:` 里逐条打开（只有 `registerLintRule` 注册的才默认关）。

插件包是**独立 package**（自带 `pubspec.yaml` / `pubspec.lock` / `.dart_tool`），**不并进 workspace**：它要跟 SDK 自带的 `analysis_server_plugin`（0.3.23 → 连带 analyzer 14.4.0），而本工程钉 `analyzer ^13.3.0`（`drift_dev` / `retrofit_generator` 要），两者放不进同一次解析。所以 `just deps` 会分别解析根工程与 `packages/app_lints`——门禁的 analyze 与插件测试两步都依赖这两个 package config。换来的是插件能**跟着 SDK 单独升级**，不被本工程的 analyzer 上限拖住。

> `packages/` 只放**真正独立的工具包**（当前只有它）。app 代码不抽包——`lib/core/` 保持拍平（它曾经是 `packages/app_core`，2026-09-23 拍平回来）。门禁的 analyze 因此分两步：`lib + test`，与 `tool + packages`。

> 试过 workspace 方案（`workspace:` + `resolution: workspace`，插件钉 0.3.18 的 analyzer 13.3.0），**放弃了**：一次 pub get、插件源码天然进门禁，听着很好，但 (1) 成员包源码会进根工程的 **build_runner asset 图**——retrofit / json_serializable / drift_dev 遍历插件源码，在 `@reflectiveTest` 上解析失败、`drift_dev` 抛 `BuildStepCompletedException`，得靠 `build.yaml` 排除才不复现；(2) 插件与 app 的 analyzer 从此**绑定升降**，未来 SDK 要求插件升版时会**卡死整个仓库的 pub get**。这两条代价不值。

### 为什么必须是插件 + `dart analyze`

- **`dart analyze` 加载插件并输出诊断 —— 但只在显式传文件名时**：单文件、多文件都行，**传目录不行**。2026-09-24 复测：把违反 `no_material_import_in_logic` 的文件放进 `lib/features/*/logic/` 后，`dart analyze --fatal-infos lib` 只报普通 lint（`unused_import` 等），不报插件那条；同一次会话里 `dart analyze --fatal-infos <该文件>` 报了。机制未查（是 CLI 在目录模式下没给插件 package 上下文，还是插件某一步拿到 null，未定），但结论可用：**门禁与 CI 都必须显式传文件名**。这条比看上去重要——改成目录模式不报错、只是少跑规则，正是本文件下面警告的「有门禁的错觉」。
- **`flutter analyze` 不加载插件**：同样的 `plugins:` 配置下它只报「No issues found」；放一个不存在的插件名也不报错（对照 `dart analyze` 会报 `PluginManager` 错误）——它根本不进插件系统。这是上位 bug：[flutter#187999](https://github.com/flutter/flutter/issues/187999)（open，修复 [dart-lang/sdk#63805](https://github.com/dart-lang/sdk/pull/63805) 在途、未进 stable），不是设计取舍。
- 所以根 `justfile` 的两步 analyze 是 `dart analyze --fatal-infos <显式文件列表>`：`--fatal-infos` 对齐原 `flutter analyze`（默认 fatal-infos）的严格度；显式传文件是**必须的调用形式**，列表由 `tool/list_dart_files.dart` 生成（`git ls-files` + 磁盘存在性过滤，生成物已被 `.gitignore` 排除）。**CI 与 pre-commit 不再自己拼这两步，统一跑 `just verify`** —— 调用形式有讲究，抄错不报错只少跑，所以不留第二份。`flutter analyze` 只在改名脚本的端到端回归里出现（那里只关心 `error`）。
- 插件规则的 diagnostic **默认是 info 级**，`dart analyze` 会打印它但退出码 0；`--fatal-infos` 把它变致命（实测：info → 0、warning → 2、error → 3、info + `--fatal-infos` → 1）。规则本身也显式指定了 `DiagnosticSeverity.WARNING`。

`riverpod_lint` 走的是同一套机制（`plugins:` + warning 层默认开），见 `pubspec.yaml` 与 `analysis_options.yaml`。至此门禁规则**不再由自定义检查脚本实现**——根 `justfile` 只编排现成命令；原先剩下的覆盖率脚本也已移除（见下文「覆盖率门禁（已移除）」）。

历史教训——`features/profile/page` 引用过 `features/auth/logic`，而当时的门禁一直报告「No issues found」：问题不是规则写错了，而是**没有任何一道会被执行的门禁真的在跑它**。声明成规则却没人跑，比没有规则更糟（给人有门禁的错觉）。这条也是「规则必须挂在会被执行的命令上」的直接原因。

### 判据细节

- 全部规则先过 `context.isInLibDir`——只有 `lib/` 下的文件参与判断（`test/` 里 widget 测试的 `build` 不该被管）。
- **生成物豁免**：每条规则自带 `isGeneratedPath` 判断（`.g.dart` / `.freezed.dart` / `.gr.dart` / `.config.dart` / `.gen.dart` / `/gen/` / `app_localizations`）。生成器的产物只保证「能编译」，不保证遵守层次约定（路由要汇总所有 feature 的 `page/`），且里面的违规没法手工修。生成物虽已 gitignore（门禁列表天然列不到），IDE 或手工 `dart analyze` 单文件时仍可能碰到它们——豁免保留。口径与 `.gitignore` 一致，改动时要一起改。
- 放行的情况：feature 引用自己、组合根（`lib/app/`）引用任何 feature（FSD 的 app 层负责装配）、生成文件。`core/` 引用 `lib/core/` 内部也放行。
- `no_material_import_in_logic` 只认 `package:flutter/material.dart` 这一个 URI —— `foundation` / `widgets` 不管，页面层的 material 也不管（`lib/core/config/app_settings.dart` 为了 `ThemeMode` import material 是正当的）。
- `avoid_ref_read_in_build` 的判据是两个 AST 事实：「最近的 `MethodDeclaration` 祖先叫 `build`」（方法体里的闭包也算）与「实参不是 `.notifier`」。正则做不到——dart format 会把 `ref` 与 `.read` 折到两行，而「在不在 build 里」根本不是行内信息。豁免 `.notifier` 是因为 `ref.read(loginProvider.notifier)` 取的是 notifier 实例本身（身份稳定、不参与订阅），页面拿它当方法接收者用（`onChanged: notifier.updateEmail`）是正当写法，换成 `ref.watch(...notifier)` 只会白添一次重建。
- 包名 `package:my_app/` 在 `packages/app_lints/lib/src/paths.dart` 里硬编码（`selfPackagePrefix`），`tool/init_project.dart` 会全仓库替换它。

### 禁止模式

```dart
// ❌ 跨 feature 引用 page/logic
import 'package:my_app/features/sample/page/sample_list_page.dart';
import 'package:my_app/features/sample/logic/sample_list_notifier.dart';

// ✅ 允许：引用 core，或另一个 feature 的 data 层
import 'package:my_app/features/sample/data/sample_repository.dart';  // data 层可共享
import 'package:my_app/app/routing/router.dart';
```

```dart
// ❌ build 里用 ref.read 取值：不建立订阅，provider 变了界面停在旧值
final value = ref.read(sampleListProvider);

// ✅ 读值用 watch；一次性取值（方法 / 回调里）才用 read
final value = ref.watch(sampleListProvider);
await ref.read(userPreferencesProvider).setThemeMode(mode);
```

```dart
// ❌ core/ 反向依赖业务：底座一旦认识 features，抽象就报废了
import 'package:my_app/features/sample/data/sample_repository.dart';

// ✅ core 只依赖 core 与第三方包
import 'package:my_app/core/base/result.dart';
```

> **退役记录（2026-09-24，随脚本迁插件一并去掉两条）**：
> - `features/*/logic/` 不得手动建 `ProviderContainer` —— 触发频率低（防的是「手滑绕过注入」），判据还是脆的标识符匹配，用户决定不要了。
> - `comment_block_too_long`（连续注释块 ≤10 行）—— 同样是用户决定不要：长解释该进 spec 这条约定保留（见 [guides/comment-guidelines.md](guides/comment-guidelines.md)），但不再用门禁拦。另退役 `avoid_async_state_map`（随 signals 栈退役：`AsyncValue.when` 的回调具名且具类型，配错在编译期就是 error；三态渲染仍统一走 `AsyncView`，是约定不是门禁）。

> **页面不设构造注入点。** 测试替身一律走 `ProviderScope(overrides:)`，页面不持有 `final Xxx? viewModel;` 这类可注入字段。

---

## 目录树一致性（已移除）

> 2026-09-24 起 `check_readme_tree` 门禁已删除：README 与 [frontend/directory-structure.md](frontend/directory-structure.md) 里的 `lib/` 目录树不再有门禁核对，纯靠人工维护 —— 树里的路径是纯文本，编辑器与 Git 都不会报错，增删 `lib/` 文件后记得顺手同步这两处。

---

## 覆盖率门禁（已移除）

> 2026-09-24 起 `tool/check_coverage.dart` 与 `test/tool/check_coverage_test.dart` 一并删除：
> pre-commit 与 CI 都不再查覆盖率，**门禁里因此没有脚本了**（只剩 `dart format`、`dart analyze`、
> `dart test`、`flutter test` 这几条现成命令）。随之消失的是 80% 阈值、`--src` 差集检查与
> `loadingExemptions` 豁免清单；跑测试也从 `flutter test --coverage` 退回 `flutter test`，不再生成
> lcov —— 想临时看数字自己跑 `flutter test --coverage`，那是人工参考，不拦提交。历史实现在 `5508e2e` 的 `tool/check_coverage.dart`。

---

## 改名脚本（`tool/init_project.dart`）

```bash
dart run tool/init_project.dart                                  # 交互式
dart run tool/init_project.dart --yes --name=my_next_app --application-id=com.example.my_next_app   # 非交互（CI / 脚本）
```

覆盖范围见 [guides/rename-checklist.md](guides/rename-checklist.md) 的 9 项表（`pubspec` 包名、全仓库 `package:<旧名>/`、根组件类名、Android / iOS 的标识与显示名、`MainActivity.kt` 连目录一起搬）。其中 **`packages/app_lints/lib/src/paths.dart` 里硬编码的 `package:<包名>/` 前缀最要命** —— 漏了它，边界门禁会把所有 import 当成外部包静默放行。

两条语义，改了要同步 `test/tool/init_project_test.dart`：

- **全有或全无**：先规划、后写盘。任一必改点没匹配到 → 列出「哪一处没对上」并以非零退出码结束，磁盘不变。半改的仓库连 `flutter analyze` 都跑不起来，定位成本远高于直接报位置。
- **可选项不拦**：文档、`.gitignore`、`<旧名>.code-workspace` 这类文本里的裸包名改不到只提示，不影响退出码。

回归测试分两层（逐条见 rename-checklist「回归测试」）：fixture 跑在每次 `flutter test` 里；端到端那条要 `SCAFFOLD_E2E=1`（CI 的 `analyze` job 带了它），改名后跑 `flutter pub get` + `flutter analyze`，用 `--no-fatal-infos` —— 既存 info 与「改名顺带改变 import 字母序」（`directives_ordering`）不该算失败，要看的是 error。

---

## 依赖声明（`depend_on_referenced_packages`）

> 2026-09-24 改写：这里原来是一道独立门禁 `dependency_validator`，已移除 —— 理由与代价见本节末。

「声明与使用是否一致」现在只剩 analyzer 自带的一条 lint `depend_on_referenced_packages`。它在 `analysis_options.yaml` 的 `analyzer.errors` 里被显式提升为 **error**，**不依赖跑它的那条命令**。豁免就是就地一条 `// ignore: depend_on_referenced_packages -- 理由`。

| 检查 | 谁管 |
|------|------|
| 在 `lib/` 里 import 了只声明在 `dev_dependencies` 的包（under-promoted） | `depend_on_referenced_packages`（配置里是 error）；`dart analyze --fatal-infos` 拦 |
| import 了压根没声明的包（missing） | 同上 |
| **`tool/` 与 `packages/` 里的同类问题** | 同上 —— 门禁用显式文件列表执行 `dart analyze --fatal-infos`，口径没有分叉 |
| 声明成 `dependency` 却只在 `test/` `tool/` 里用（over-promoted） | **无人管**（有意） |
| 声明了但没人用（unused） | **无人管**（有意） |
| pubspec 里写了精确版本（pinned） | **无人管**（有意） |

后三类**从原理上**就看不见：「声明在 `dependencies`」永远能满足 import，所以「放上去了、但该放在下面」这种错它无从报起。

> **为什么级别写在配置里，而不是靠命令行 flag**：两条 `analyze` 命令的默认值不一样——实测（2026-09-24）同一个 info 级的依赖漏声明，`flutter analyze lib/ test/` → **exit 1**，`dart analyze lib` → **exit 0**。以前的做法是给 `tool/` 那一项补 `--fatal-infos` 把两边拉平，代价是「得记住这条命令要加 flag」成了必须维护的不显然知识，而且换个命令（裸跑 `dart analyze`）就静默放过。现在两端都消掉了对默认值的依赖：规则级别写进 `analysis_options.yaml`（`error`），门禁的两步 analyze 都使用 `dart analyze --fatal-infos` 并显式传文件列表 —— `tool/` 与 `packages/` 里的 info 也按 `lib/` `test/` 的严格度拦。

### 为什么移除 `dependency_validator`

- 它确实能拦后三类，但代价压过了收益：**豁免机制造成过一次真实损害，而它对那次事件全程沉默。** 它要求「声明了就得被 import」，而 `json_annotation` 恰好是「必须声明、却不会被 import」的包，于是仓库根多了一个需要长期维护的 `dart_dependency_validator.yaml`。删认证功能时，那条 `ignore` 的理由（`login_request.dart`）失真后被当成垃圾清掉，**连带把 `json_annotation` 依赖一起删了**；期间它一直报 `No dependency issues found!`，真正暴露问题的是 `build_runner` 的一条警告。
- 换来的三类（over-promoted / unused / pinned）在本仓库的**真实历史里一次都没触发过**。

**认下的代价**：over-promoted 会静默通过 —— 后果不是编译错，而是「派生工程把 dev 依赖打进 release 包」，只是体积变大，不报错。

### `json_annotation`：必须声明，别删

它是 `json_serializable` 的**构建期契约**，不是冗余声明：生成 `lib/` 下的代码时，该包要求 `json_annotation` 出现在 pubspec 的 `dependencies` 且下界 ≥ `4.12.0`（判据是 `json_serializable/lib/src/check_dependencies.dart` 的 `requiredJsonAnnotationMinVersion`）。源码里不会出现它的 import —— `@JsonKey` 只出现在生成的 `sample_item.freezed.dart` 里，符号经 `freezed_annotation` 的 re-export 提供。

> 违反这条契约的后果很隐蔽：codegen 照常能跑（`json_annotation` 由 10 个包传递带入），只是 `build_runner` 打一条警告——而**这条警告不在门禁里**（`just verify` 的 5 项没有 build_runner 那一步；跑 codegen 的是 CI 的 `analyze` job）。靠手动跑 `just codegen` 才能发现。

---

## 供应链门禁（`dart pub outdated` / OSV）

依赖声明（上一节）与「锁定的版本有没有已知漏洞」是两回事：后者由 CI 的两个新环节负责，**阻断语义刻意不同**：

| 环节 | 位置 | 语义 |
|------|------|------|
| `dart pub outdated` | `analyze` job 的一步，`continue-on-error: true` | **只报告**，不拦合并 |
| OSV 扫描 | 独立的 `osv-scan` job（官方 reusable workflow） | 发现漏洞即 **失败** |

为什么过期不拦：`pubspec.yaml` 里的约束与 `pubspec.lock` 落后于 pub.dev 是常态，做成硬门禁的结果是「每次上游发版都红一次」，最后所有人都学会忽略它。升级时机由人按 [docs/release-checklist.md](../../docs/release-checklist.md) 排；这里只保证信息可见。
为什么漏洞要拦：这条正是「过期也可能真的有害」的那一面，且判断不需要人做 —— OSV 库说有就有。所以它单独成一个 job，红了就是红的。

两个实现细节：

- 用官方的 reusable workflow（`google/osv-scanner-action/.github/workflows/osv-scanner-reusable.yml@v2.6.0`）而不是自己拼 `run: osv-scanner …`：CLI 在 v1 → v2 之间子命令化过，手写的调用会在某次升级后静默失效或直接报错。版本号是**固定 tag**，升级时同时改这一处即可。
- `scan-args` 显式给根工程与独立插件包两份 lockfile（默认的 `-r ./` 会连 `build/`、`.dart_tool/` 一起扫）；`upload-sarif: false` 让结果只落在 job 日志里，私有仓库 / 未开 Code Scanning 的仓库不会因为这一步变红。

> 与 [release-checklist.md](../../docs/release-checklist.md) 的分工：清单管「发版前必须人工确认的事」，这里管「每次 push / PR 自动挡住的事」。

---

## 代码生成与生成物（codegen）

### 策略：生成物不入库（gitignore）

`.gitignore` **排除**生成物，它们不提交进 git。判定「哪些是生成物」的口径与 `packages/app_lints/lib/src/paths.dart` 的 `isGeneratedPath()` 对齐（插件在 IDE / 手工 analyze 场景仍要豁免它们）：

| 形态 | 例子 |
|------|------|
| `*.g.dart` | `json_serializable` / `retrofit` / `drift` 的行类 / **`@riverpod` 生成的 provider** |
| `*.freezed.dart` | 模型 |
| `*.gr.dart` | `auto_route` 的路由类 |
| `*.config.dart` | `injectable` 的 DI 注册（本项目不使用 injectable，无此生成物） |
| `*.gen.dart`、路径含 `/gen/` | 资源访问器（当前不存在，`flutter_gen` 已移除） |
| 路径含 `app_localizations` | l10n 生成物（本项目已裁剪 l10n，见 [frontend/localization.md](frontend/localization.md)；口径保留给裁剪前的版本） |

- **理由**：生成物是机器产物，diff 噪声大，合并 / rebase 时冲突只能靠重跑 codegen 解决，入库没有 review 价值；clone 后跑 `just deps` + `just codegen` 即可得到与源一致的生成物，CI 在门禁前现场跑同一命令，不存在「忘了提交生成物」这类失败

**代价（知道就行，别当故障处理）**：

- clone 后**不跑 codegen 就 analyze / test 会失败**（缺 `part` / provider）——快速开始里 `just codegen` 是必做步骤
- 换生成器版本会静默改变生成代码的形状，且不会在 git diff 里露出来；升级 codegen 包后本地必须 `just codegen-reset` 并跑测试兜底

### 重新生成时机

| 时机 | 命令 |
|------|------|
| 改了注解，或新增模型 / API / DAO / `@RoutePage` / `@riverpod` | `just codegen` |
| 增删代码文件（含删掉整个 feature） | 同上。删文件后**必须**重跑，否则 provider 注册与路由仍指向已删的类 |
| clone 后首次构建 / analyze / test | `just codegen` |
| 改了 `lib/l10n/*.arb` | `flutter gen-l10n`（本项目已无 l10n，见 [frontend/localization.md](frontend/localization.md)） |
| 升级 / 降级任一 codegen 包（`freezed`、`json_serializable`、`drift_dev`、`retrofit_generator`、`auto_route_generator`、`riverpod_generator`、`build_runner`） | `just codegen-reset` |
| 升级 Flutter / Dart SDK | 同上 |
| 切分支、rebase / merge 后本地生成物与源不一致 | 重跑 `just codegen`（生成物不手工编辑） |

**不要加 `--delete-conflicting-outputs`**：它在 build_runner 2.16.0 起已是**被移除的选项**（源码注释 `// Removed options, kept to not break old command lines.`，`lib/src/build_runner_command_line.dart`，2.16.1 实测）——传进去不报错、也**不起任何作用**，只会在输出里多一条 warning。
它当年要解决的事（覆盖冲突输出、修掉被手改过的旧产物）**从那版起是默认行为**；想退回旧行为要用 `--keep-modified-outputs`（见本文「禁止模式」）。

### 门禁与 CI

- **本地 `just verify` 不跑 codegen**（假定生成物已在磁盘上，快速开始的 `just codegen` 已执行过）；**pre-commit 有意不跑** —— 完整 codegen 是几十秒量级，而 pre-commit 已经跑了 `flutter test`
- **CI 的 `analyze` job 在 `just verify` 前跑 `just codegen`**：现场生成，无需比对 git diff（生成物不入库，没有可比对象）。codegen 统一排在 analyze 之前 —— 生成物缺失时 analyze 会报一堆「找不到 `part` / provider」的噪声，先生成能让报错指向真正的原因
- `drift_dev` 生成 schema 需要 `sqlite3` 的动态库（本项目由 `sqlite3` 3.x 的 build hook 提供，`just deps` 会准备）。这一步若在 CI runner 上失败，报错会指向 `sqlite3` / `hooks_runner`，而不是 build_runner 本身
- **本项目没有 l10n**，所以这一步里**没有** `flutter gen-l10n`：那个命令在缺 `l10n.yaml` 时会直接失败（见 [frontend/localization.md](frontend/localization.md)）

### 禁止模式

```bash
# ❌ 手改生成物 —— 2.16.0 起 build_runner 默认会修正被改过的输出（旧行为要显式开 --keep-modified-outputs）
# ❌ 把生成物 `git add -f` 加回版本库 —— 策略是不入库；.gitignore 与 isGeneratedPath 是同一口径
# ❌ 用 --keep-modified-outputs 留住手改 —— 那是调试旧行为的开关，不是工作流
```

---

## build_runner 升级与 codegen 缓存（评估）

> 快照（2026-09）：版本与文件数会变，重估时用下面给的命令重新量。结论本身（要不要升级、要不要加缓存）在触发条件出现前不变。

**结论**：升级**暂时没有可升的版本**（已在 2.x 最新）；「目录级 cache」**不引入**。CI 的 codegen 每次全量构建，也不缓存。

- **现状（快照 2026-09）**：`pubspec.yaml` 约束 `build_runner: ^2.4.14`，`pubspec.lock` 解析到 **2.16.1**（pub.dev 上 2.x 线最新，无 3.x）
- 生成器六个：`freezed` / `json_serializable` / `drift_dev` / `retrofit_generator` / `auto_route_generator` / `riverpod_generator`（清单见上；本项目不使用 `injectable_generator`）
- 产物现场可查：`ls lib/**/*.g.dart lib/**/*.freezed.dart lib/**/*.gr.dart`（生成物不入库，`git ls-files` 看不见）

### 升级（要不要升、什么时候重估）

2.14.0 起除 `run` 外的命令**默认走 AOT 编译**，2.13.0 起增量构建有 1.4×~4× 的提升——这些收益**已经拿到**，因为实际版本由 lock 决定（2.16.1），不由 pubspec 里的 `^2.4.14` 决定。

- **不要**为了「看起来新」把约束收紧成 `^2.16.1`：那只会让以后重新解析依赖时被无谓卡住。**重估的信号**是某个生成器抬高了对 `build_runner` 的下限（`just deps` 会直接报冲突），或撞上 2.x 修不掉的构建 bug
- 真做升级时的顺序：改约束 → `flutter pub upgrade <pkg>` → **`dart run build_runner clean` 后全量重建** → 本地核对生成物形状变化（换版本常改变生成代码的形状，生成物不入库所以没有 diff 可 review，以测试为准）→ 跑 `flutter analyze` 与 `flutter test`

### 「目录级 cache」（结论：不引入）

先厘清一件事：build_runner **本来就有缓存**，粒度是 **asset（文件）级**，落在 `.dart_tool/build/`（已在 `.gitignore` 里），第二次 `just codegen` 只重建受影响的子图 —— 这就是它的增量模型，不需要额外引入什么；而「按目录切分 / 目录级 cache」的两条常见做法都不划算：

| 做法 | 为什么不 |
|------|---------|
| 按目录多次调用 `--build-filter=lib/features/xxx/**` | 每次调用都要重新加载 package config、重建 asset graph，固定开销是数十秒量级；而 builder 之间有跨目录依赖（路由汇总到 `lib/app/routing/router.gr.dart`、LazyDatabase 与表汇总到 `lib/core/data/database/app_database.g.dart`），拆开跑完还得再跑一次全量才正确 |
| 第三方「缓存 codegen 产物」的包（如 `cached_build_runner` 一类） | 把正确性押在 cache key 上：SDK 版本、依赖版本、`build.yaml`、builder 配置任一变化都可能让缓存与源不匹配，而它**不会报错，只会静默给出旧产物**。build_runner 官方的增量缓存都栽过跟头（workspace 与包构建间切换时的增量不正确，直到 2.15.1 才修）——用第三方缓存换来的秒数，不值得拿生成物正确性去赌 |

**CI 上不要 cache `.dart_tool/build/`**：该目录与 Dart SDK 版本、依赖解析结果强绑定。缓存命中不当时最坏的结果是「检查通过，但仓库里的生成物其实是旧的」——这道门禁的价值全在结论可信，快几秒不值这个风险。

> 真到 codegen 成为瓶颈那天（builder 数量或 `lib/` 文件数明显翻倍），正确顺序是：先用 `just codegen --verbose-durations`（2.13.0 起）量出时间花在哪个 builder，再决定砍 builder 还是改构建结构，**最后**才考虑缓存。不要从「加个 cache」起步。

---

## Memory Leak Detection (`leak_tracker`)

### 运行期检测（debug 模式）

在 `bootstrap.dart` 中通过 `_initLeakTracker()` 初始化，debug 模式下自动启用：

- 监听 `FlutterMemoryAllocations` 事件（Flutter 框架对象的创建/销毁），在控制台输出未释放的对象信息
- release 模式下不生效（`assert` 块仅在 debug 模式执行）

### 测试检测

`test/flutter_test_config.dart` 配置了全局泄漏检测：

- 所有 `testWidgets` 自动启用 `LeakTesting`，测试中未 dispose 的 Widget、Controller、流订阅等会被报告
- 通过 `withIgnored(createdByTestHelpers: true)` 过滤测试辅助创建的对象

### 检测范围

- 只能检测**已接入埋点**的类；Flutter Framework 的所有 disposable 类都已接入（`FocusNode`、`AnimationController` 等）
- `ConsumerWidget` / `ConsumerStatefulWidget` 最终也是 Flutter `Element`，在覆盖范围内
- 如果一个泄漏链中包含至少一个已埋点的对象，整个链都会被捕获

> ⚠️ **`leak_tracker` 看不见 provider 的状态对象**：`ProviderContainer` / `Notifier` / `AsyncValue` 是纯 Dart 对象，不上报 `FlutterMemoryAllocations`。所以「测试里没报警」**不等于**「状态没有泄漏」——真正的兜底是 `autoDispose` 与主动登记的清理（`ref.onDispose`），见 [frontend/state-management.md](frontend/state-management.md)「生命周期」。

---

## Integration Testing

### 本地运行

```bash
flutter test integration_test/
```

### CI 运行

CI 用 `reactivecircus/android-emulator-runner` 在 Android 模拟器上跑（目标平台是 Android / iOS，没有 `linux/` 平台目录，所以**不要**用 `xvfb-run`）。

### widget 测试里不要用真实 I/O

`testWidgets` 的 `pumpAndSettle` 走**假时钟**，真实的文件 / 数据库 I/O 不会在它推进的这段时间里完成。后果有两层：

- 断言可能**假通过**：初始值为空时，即使 `refresh()` 从未跑完也成立
- 操作后的断言会失败，因为 I/O 还没回来

约定：**真实依赖用普通 `test()` 测**（那些测试没有假时钟），**页面测试把依赖 mock 掉、用 `ProviderScope(overrides:)` 换成假实现**。范例：`test/features/sample/data/sample_dao_test.dart`（真实 Drift + 内存数据库）与 `test/features/sample/page/sample_list_page_test.dart`（overrides 假仓库 + 驱动 provider 状态）。另外 `ListView` 只布局可视区内的子节点，视口外的内容 finder 找不到——测长页面时要么放大视口（`tester.view.physicalSize`），要么先滚动。

### 测试内容

当前集成测试覆盖（快照 2026-09，实际以 `integration_test/app_test.dart` 为准）：

- 应用正常启动，经启动页（约 1.8s 动画，2.2s 后跳转）进入 `MainRoute` 主框架
- 底部导航栏存在、首页文案渲染出来
- 点击「示例」标签能切换，且 `NavigationBar.selectedIndex` 跟随

约束与注意事项：

- **`bootstrap()` 不可重入**：`prefsProvider` 的 override 与 leak_tracker 启动都只能执行一次。因此整个冒烟流程只在**一个** `testWidgets` 中调用一次 `app.main()`；拆成多个 `testWidgets` 各自启动会在第二次抛「Bad state: Leak tracking is already enabled.」
- **启动页要显式推进时钟**：`Future.delayed(2200ms)` 是计时器，`pumpAndSettle()` 之后补一次 `pump(Duration(seconds: 3))` 才稳
- **不需要清理登录态**：本项目没有认证，`SharedPreferences` 里没有会话可残留
- **字体**：主题（`lib/core/theme/app_theme.dart` 的 `_textTheme`）**不指定字体家族**，走平台默认字体，所以测试与设备上都不存在"渲染时联网拉字体"的问题。如果以后引入按需下载字体的方案（如 `google_fonts`），务必在测试里关掉运行时下载（`GoogleFonts.config.allowRuntimeFetching = false`）——否则 `pumpAndSettle` 会卡数分钟且结果不稳定。生产环境更该把字体打进产物，而不是运行时下载
- `msw_dio_interceptor` 的 mock 由 `.env` 的 `USE_MOCK` 控制（`.env.development` 默认 `true`）。写 mock 规则必踩的坑（必须 `MockRule.regex` 且锚定结尾）见 [backend/network-guidelines.md](backend/network-guidelines.md) 的 Mock 一节

---

## 环境配置与 release 构建

`.env` 文件按「环境名」加载，环境名的解析优先级见 `lib/bootstrap.dart` 的 `_activeEnv`：

1. `--dart-define=env=xxx`（显式指定）
2. 构建模式默认值：debug / profile → `development`，release → `production`

**不要**退回成 `String.fromEnvironment('env', defaultValue: 'development')`：那会让 release 也加载 `.env.development`，包静默跑在 localhost + `USE_MOCK=true` 上，界面正常但数据全假。

- `.env` / `.env.development` / `.env.production` 已提交，并作为 asset **打进产物**。因此只能放非密钥配置（`BASE_URL`、`USE_MOCK`）；密钥写进去既会进 git 也能从 apk 中提取。真实后端地址建议用 `--dart-define=BASE_URL=...` 传入。
- `BASE_URL` 缺失时 `bootstrap()` 直接抛异常（fail fast），不会静默启动。

### 有意留白（模板不提供的部分）

以下属于**目标应用**的职责，脚手架刻意不配置。它们不是遗漏，读到这段时不要当成待办：

- **release 签名**：`android/app/build.gradle.kts` 的 release 仍使用 debug keystore，没有 `key.properties` / `signingConfigs.release`
- **minify / 混淆**：未开启 `isMinifyEnabled` / `isShrinkResources`，也没有 `proguard-rules.pro`；构建脚本未加 `--obfuscate --split-debug-info`
- **build flavor**：未做 dev/staging/prod flavor，环境切换用上面的 `--dart-define=env=xxx` 代替
- **iOS release 签名**：描述文件与证书需在 Xcode 中配置
