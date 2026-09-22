# Cross-Cutting Concerns

> 不属于单一层、或同时管「门禁」与「发布」的约定。
> 层次内的规则见 [backend/](backend/index.md) 与 [frontend/](frontend/index.md)。

---

## 架构边界检查（`tool/check_boundaries.dart`）

边界规则**不是** analyzer 插件，而是一个脚本：

```bash
dart run tool/check_boundaries.dart     # 退出码 0 = 通过，1 = 有违规
                                        # 默认扫 lib 与 packages/app_core/lib
```

它跑在 pre-commit 与 CI（`analyze` job）里，`test/tool/check_boundaries_test.dart` 也会在 `flutter test` 时跑一遍真实仓库。

**扫描根是两处，不是一处**：`lib` 与 `packages/app_core/lib`。抽包之后如果只扫 `lib/`，
新包就成了**边界真空**——等于用一次重构把一道门禁换成没有门禁。

**为什么不用 analyzer 插件**：`analysis_server_plugin` 规则只在 IDE 里生效，CLI 与 CI 不执行。历史教训——`features/profile/page` 引用过 `features/auth/logic`，而 `flutter analyze` 一直报告「No issues found」。声明成 `error` 却没有任何东西验证它会触发，比没有规则更糟（给人有门禁的错觉）。

| 规则 | 效果 |
|------|------|
| `core/` 不得 import 上层 | `core/**` 不能 import `features/**` 或 `app/**` |
| 跨 feature 只共享 `data/` | 不能引用其他 feature 的 `page/` / `logic/` |
| ViewModel 不得用 service locator | `features/*/logic/` 里不得出现 `getIt` / `GetIt.I`（构造器注入，理由见 [ADR-0001](../../docs/adr/ADR-0001.md)） |
| 页面必须给出可选注入点 | 用 `getIt<*ViewModel>()` 取 ViewModel 的页面，三件套缺一不可：`final T? viewModel;`、构造参数 `this.viewModel`、`viewModel ?? getIt<T>()` 兜底 |
| `packages/app_core` 不得依赖状态管理 / DI | 包内不得出现 `signals_*` / `riverpod*` / `get_it` / `injectable` |

前三条是依赖方向，第四条是可测性约定（[ADR-0001](../../docs/adr/ADR-0001.md) 的缓解措施）：页面仍从容器取 ViewModel，但必须留一个只有测试会用的注入口，否则页面测试会被推回 `setUpTestApp()` 装配全局容器——而且**没有任何编译器会提醒**，漏一个页面就少一处，所以用退出码兜住。

第五条是共享基础设施包的**存在前提**：`packages/app_core` 要同时服务 signals 栈与 Riverpod 栈，
包里一旦出现 `signals` / `riverpod`，另一个栈就用不了它，抽包的意义直接归零；
`get_it` / `injectable` 同理——它们是装配方式，注册归各分支的装配层
（拆分依据见 `.trellis/tasks/09-22-extract-app-core/design.md` 6.1 / 6.5）。

```dart
// ✅ 页面取 ViewModel 的标准三行
final ArticleViewModel? viewModel;                       // 只有测试会传
const ArticleListPage({super.key, this.viewModel});      // 参数可选，路由代码不用改
final vm = useMemoized(() => viewModel ?? getIt<ArticleViewModel>());
```

放行的情况：feature 引用自己、组合根（`lib/app/`）引用任何 feature（FSD 的 app 层负责装配）、生成文件（`.g.dart` / `.freezed.dart` / `.gr.dart` / `.config.dart`）。

规则 4 只看 `*ViewModel` 类型：页面直接取依赖（`getIt<AuthStorage>()` / `getIt<UserPreferences>()`，如 `home_page`、`profile_page`）不在管辖内；`features/*/logic/` 也由规则 3 直接禁止取容器，不重复报。

### 解析能力与 warning

脚本是**正则级**的，不是语义级：它只认「单行、单个 URI」的 `import` / `export`。两类写法它读不懂，会往 stderr 打 `⚠️ 疑似漏检`：

| 写法 | warning 文案 |
|------|-------------|
| `import` 与 URI 分行 | 以 import/export 开头但没解析出 URI |
| 条件导入 `import 'a.dart' if (dart.library.io) 'b.dart';`，或 format 把 `as x` / `if (...)` 折到下一行 | 边界规则只检查了第一个 URI |

**warning 不影响退出码**：它说的是「工具看不懂这一行」，不是「这行违规」，硬拦等于把工具的局限变成提交阻塞。拦提交的只有上面三条规则。

两条现实约束：

- 生成文件必须继续豁免——`lib/di/service_locator.config.dart` 里就有一条折行的 `import`，不豁免会天天误报。
- `test/tool/check_boundaries_test.dart` 的「真实仓库」用例**把 warning 也判失败**：`lib/` 一旦出现 warning，就说明该按 [architecture-review.md](../../docs/architecture-review.md) P4 的触发条件把脚本迁到 `package:analyzer` 的 AST（用 `parseString` 写脚本，执行模型仍是 CI 里的 `dart run`，不是退回 IDE-only 的插件）。

### 禁止模式

```dart
// ❌ ViewModel 里不能用 getIt()
class ArticleViewModel {
  final repo = getIt<ArticleRepository>();
}

// ✅ 正确：构造器注入
class ArticleViewModel {
  final ArticleRepository repo;
  ArticleViewModel(this.repo);
}
```

```dart
// ❌ 跨 feature 引用 page/logic
import 'package:my_app/features/auth/page/login_page.dart';
import 'package:my_app/features/auth/logic/auth_view_model.dart';

// ✅ 允许：引用 core，或另一个 feature 的 data 层
import 'package:my_app/core/models/user.dart';
import 'package:my_app/features/auth/data/auth_repository.dart';  // data 层可共享
import 'package:my_app/app/routing/router.dart';
```

实际例子：`profile` 需要「登出」这项能力时，引用的是 `features/auth/data/auth_repository.dart`（data 层），不是 auth 的 `logic/auth_view_model.dart`。

---

## 代码形态约定（`tool/check_conventions.dart`）

边界脚本管「谁能依赖谁」，这个管「代码写成什么样」。同样不是 analyzer 插件，同样跑在 pre-commit 与 CI 的 `analyze` job 里：

```bash
dart run tool/check_conventions.dart     # 默认扫 lib/，退出码 0 = 通过，1 = 有违规
```

| 规则 | 效果 |
|------|------|
| `avoid_async_state_map` | 不得调用 `AsyncState.map`，三态渲染用 `AsyncView`（理由见 [frontend/state-management.md](frontend/state-management.md)「渲染状态」） |
| `comment_block_too_long` | 连续注释块最多 10 行，超限就把解释搬进 spec |

**为什么这条用 `package:analyzer` 而不是正则**：`AsyncState.map` 的判据是**具名实参**（`data` + `error` 同时出现），正则分不清它和 `list.map(...)` —— 而误报会挡住提交。所以这个脚本用 `parseString` 拿 AST 判断；执行模型仍是 CI 里的 `dart run`，与 [architecture-review.md](../../docs/architecture-review.md) P4 说的「迁到 AST」是同一件事，只是先落在新增的规则上。

**为什么注释也进门禁**：长解释留在代码里会和实现抢注意力，且改了一处、另一处就成了假信息（见 [guides/comment-guidelines.md](guides/comment-guidelines.md)）。扫描根与边界脚本一致（`lib` + `packages/app_core/lib`）；`tool/` 脚本的头注释本身就是门禁的设计说明，`test/` 的说明性注释同理，都不扫。

> 判据是纯形态的，不看类型：只要一个 `map` 同时带 `data` 与 `error` 就判违规，自定义的同名 API 会被误报。真遇到再加豁免，别提前放一个用不到的逃生口。

---

## 目录树一致性（`tool/check_readme_tree.dart`）

文档里的 `lib/` 目录树是**结构性快照**：加删文件时它不会自己更新，而 markdown 链接检查也管不到它 —— 树里的路径是纯文本，不是链接，编辑器和 Git 都不会报错。真实发生过：README 写着早已搬走的 `lib/core/routing/`，同时又漏着 `run_catching.dart`、`async_view.dart`、`features/demo/`。

```bash
dart run tool/check_readme_tree.dart        # 退出码 0 = 一致，1 = 有出入
```

两条规则：

1. 树里列出的每个路径都必须真实存在
2. 树里**已展开**的目录，其实际内容（生成物除外）必须全部列出

「已展开」= 该目录下面还有缩进更深的条目。只写到目录名、不展开子项的（如 `features/article/`）视为刻意省略，不检查其内容；用模板占位符展开的（如 `features/{feature}/`）同样跳过。

`targets` 是「文档 → 目录树根」**对**的列表（不是 doc → root 的映射），因为一个文档里可以有多棵树：

| 文档 | 根 |
|------|----|
| `README.md` | `lib` |
| `README.md` | `packages/app_core/lib` |
| [frontend/directory-structure.md](frontend/directory-structure.md) | `lib` |

包那棵树的根取 `packages/app_core/lib` 而不是 `packages/app_core`：后者的直接子项里有
`.dart_tool` / `build` / `coverage` / `pubspec.lock` 这些产物，列进树里只会变成噪音。

---

## 覆盖率门禁（`tool/check_coverage.dart`）

架构边界管「谁能依赖谁」，覆盖率管「有没有测过」，两者互补。

```bash
flutter test --coverage                                   # 根工程 → coverage/lcov.info
(cd packages/app_core && flutter test --coverage)         # 包 → 包内 coverage/lcov.info
dart run tool/check_coverage.dart coverage/lcov.info packages/app_core/coverage/lcov.info \
  --src=lib --src=packages/app_core/lib
dart run tool/check_coverage.dart --min=85                # 不传路径则只查 coverage/lcov.info
```

- 跑在 pre-commit 与 CI 的 `unit-test` job 里
- **只统计手写代码**：`*.g.dart` / `*.freezed.dart` / `*.gr.dart` / `*.config.dart` / `*.gen.dart` / `app_localizations*` 不计入。生成代码的行数不是人能守的，算进去只会稀释阈值
- 判定复用 `tool/check_boundaries.dart` 的 `isGeneratedPath`，两处口径不会漂移
- 按**行数加权**，不是按文件平均——500 行的文件与 5 行的文件不该等权
- 阈值默认 80%（`test/tool/check_coverage_test.dart` 覆盖脚本自身的解析与差集逻辑）

**为什么必须分两份 lcov**：`app_core` 是独立 package，根工程跑 `flutter test --coverage` 时，
包内文件的命中**不会被归集**（根 lcov 里一条 `packages/` 记录都没有），只能在包目录里单独采集。
两份 lcov **逐份独立校验，不合并**：它们的路径都是相对各自包根的 `lib/...`，合并会把命名空间
搅在一起；而且包内的低覆盖不该被 `lib/` 的高覆盖稀释。

### 差集检查（`--src`）

`--src` 与位置参数的 lcov **按序配对**，开启差集检查：拿扫描根下（`dartFiles()`，与
`handwrittenOnly()` 同一口径）的手写文件清单，减去该 lcov 的 `SF:` 集合。

```bash
dart run tool/check_coverage.dart coverage/lcov.info packages/app_core/coverage/lcov.info \
  --src=lib --src=packages/app_core/lib
```

- 个数不匹配直接以非零退出码结束：按序配对的参数错位**不会报错、只会静默算错分母**，这是这里最坏的失败形态
- 差集里的文件按 `0 命中 / 非空行数` **计入分母**（不是只报告）：没有豁免时门禁自动变严，
  新增一个没测的大文件不必等谁记得加规则。行数是代理值——精确的可执行行数拿不到，
  用非空行数刻意从严
- 路径匹配是**边界感知的后缀**匹配：lcov 的 `SF:` 相对包根（`lib/data/network/token_store.dart`），
  扫描根是仓库相对路径，用 `repoPath == sfPath || repoPath.endsWith('/$sfPath')` 对上，
  不需要额外传「这个包的 lib 前缀」

**豁免清单**（`tool/check_coverage.dart` 的 `loadingExemptions`）是唯一的逃生口，只放
**结构上不可能被加载**的文件，每条必须写理由。这来自一个反例：`auth_extra_keys.dart`
与 `token_store.dart` 被 `auth_interceptor.dart` 的 import 链加载了，却仍不出现在 lcov 里——
它们只有 `const` 与声明，没有可执行行。所以「不在 lcov 里」有两种成因，**差集检查只能看见
第一种**，第二种必须显式写进豁免（理由即证据）。过期豁免（已进分母）只打 warning，不拦提交。

| 类别 | 例子 | 处理 |
|---|---|---|
| 抽象声明 / redirecting factory | `article_api.dart`、`article_repository.dart` | 豁免（无可执行行） |
| 只有 `const` / 纯接口 | `auth_extra_keys.dart`、`token_store.dart` | 豁免（无可执行行） |
| 只被 `integration_test` 执行的入口 | `main.dart`、`bootstrap.dart` | 豁免（`flutter test --coverage` 不含 `integration_test/`） |
| **本该被测但没测** | —— | **补测试，不许豁免** |

快照（2026-09-22，落这条门禁时的实测）：

| | 手写文件 | 进分母 | 豁免 | 覆盖率 |
|---|---|---|---|---|
| 根 `lib/` | 39 | 33 | 6 | 89.4% |
| `packages/app_core` | 20 | 18 | 2 | 89.8% |

同一个快照里 `lib/app/app.dart` 从「差集里的一个文件」变成了
`test/app/app_test.dart`：它是组合根，装配错了集成测试才会红，而集成测试不进覆盖率统计。

> 加豁免时先问一句：这是「结构上不可能被加载」，还是「暂时来不及测」？
> 后者要补测试。条目变多本身就是信号。

---

## 改名脚本（`tool/init_project.dart`）

```bash
dart run tool/init_project.dart                                  # 交互式
dart run tool/init_project.dart --yes --name=my_next_app \
  --application-id=com.example.my_next_app                       # 非交互（CI / 脚本）
```

覆盖范围（每一项都是「必改点」）：`pubspec.yaml` 的 `name` / `description`、全仓库
`package:<旧名>/`、根组件类名、Android `namespace` + `applicationId` + `android:label` +
`MainActivity.kt`（连目录一起搬）、iOS `PRODUCT_BUNDLE_IDENTIFIER`（含 `.RunnerTests`）
与 `CFBundleDisplayName` / `CFBundleName`。**`tool/check_boundaries.dart` 里硬编码的
`package:<包名>/` 前缀也在替换范围内**——漏了它，边界门禁会把所有 import 当成外部包
静默放行。

两条语义，改了要同步 `test/tool/init_project_test.dart`：

- **全有或全无**：先规划、后写盘。任一必改点没匹配到 → 列出「哪一处没对上」并以非零
  退出码结束，磁盘不变。半改的仓库连 `flutter analyze` 都跑不起来，定位成本远高于
  直接报位置。
- **可选项不拦**：文档、`.gitignore`、`<旧名>.code-workspace` 这类文本里的裸包名改不到
  只提示，不影响退出码。

回归测试分两层：fixture（临时目录里的最小仓库）覆盖「改对了什么 / 缺失即中止」，跑在
每次 `flutter test` 里；端到端那条要 `SCAFFOLD_E2E=1`（CI 的 `analyze` job 带了它），
把真实仓库复制到临时目录改名后跑 `flutter pub get` + `flutter analyze`，专门兜「改完名
import 全断」。analyze 用 `--no-fatal-infos`：既存 info 与「改名顺带改变 import 字母序」
（`directives_ordering`）都不该算失败，要看的是 error。

---

## 依赖检查（`dependency_validator`）

```bash
dart run dependency_validator     # 退出码 1 = 有问题，0 = 干净
```

它报四类：**用了没声明** / **该在 dev 却在 dependencies** / **声明了却没用** / 版本被 pin。因为发现问题时**退出码为 1**，所以它同时是 CI 闸门（`analyze` job 里的一步）。

配置在仓库根目录的 `dart_dependency_validator.yaml`，**不要**写进 `pubspec.yaml` —— 那个位置已废弃，`pub publish` 会对未识别的键报警告。

当前忽略一项：`json_annotation`（快照 2026-09，配置在仓库根的 `dart_dependency_validator.yaml`）。`@JsonKey` 只在 `login_request.dart` 用到，符号经 `freezed_annotation` 的 re-export 提供，源码里不会出现它的 import —— 是**误报**，依赖本身要保留。

> 这类工具的产出是「声明与使用一致」；`tool/check_boundaries.dart` 管的是「谁能依赖谁」。
> 两者互补，都不能替代对方。

---

## 供应链门禁（`dart pub outdated` / OSV）

`dependency_validator` 管的是「声明与使用一致」，与「锁定的版本有没有已知漏洞」无关。
后者由 CI 的两个新环节负责，两者的**阻断语义刻意不同**：

| 环节 | 位置 | 语义 |
|------|------|------|
| `dart pub outdated` | `analyze` job 的一步，`continue-on-error: true` | **只报告**，不拦合并 |
| OSV 扫描 | 独立的 `osv-scan` job（官方 reusable workflow） | 发现漏洞即 **失败** |

为什么过期不拦：`pubspec.yaml` 里的约束与 `pubspec.lock` 落后于 pub.dev 是常态，
把它做成硬门禁的结果是「每次上游发版都红一次」，最后所有人都学会忽略它。升级时机由人按
[docs/release-checklist.md](../../docs/release-checklist.md) 排；这里只保证信息可见。

为什么漏洞要拦：这条正是「过期也可能真的有害」的那一面，且判断不需要人做 —— OSV 库说
有就有。所以它单独成一个 job，红了就是红的。

两个实现细节：

- 用官方的 reusable workflow（`google/osv-scanner-action/.github/workflows/osv-scanner-reusable.yml@v2.6.0`）
  而不是自己拼 `run: osv-scanner …`：CLI 在 v1 → v2 之间子命令化过，手写的调用会在某次
  升级后静默失效或直接报错。版本号是**固定 tag**，升级时同时改这一处即可。
- `scan-args` 只给 `--lockfile=./pubspec.lock`（默认是 `-r ./`，会连 `build/`、`.dart_tool/`
  一起扫）；`upload-sarif: false` 让结果只落在 job 日志里，私有仓库 / 未开 Code Scanning
  的仓库不会因为这一步变红。

> 与 [release-checklist.md](../../docs/release-checklist.md) 的分工：清单管「发版前必须
> 人工确认的事」，这里管「每次 push / PR 自动挡住的事」。

---

## 代码生成与生成物（codegen）

### 策略：生成物提交入库

`.gitignore` **不排除**生成物，它们全部提交进 git。判定「哪些是生成物」只有一个口径——`tool/check_boundaries.dart` 的 `isGeneratedPath()`（`tool/check_coverage.dart` 与 `tool/check_readme_tree.dart` 都复用它）：

| 形态 | 例子 |
|------|------|
| `*.g.dart` | `json_serializable` / `retrofit` / `drift` 的行类 |
| `*.freezed.dart` | 模型 |
| `*.gr.dart` | `auto_route` 的路由类 |
| `*.config.dart` | `injectable` 的 DI 注册 |
| `*.gen.dart`、路径含 `/gen/` | 资源访问器（当前不存在，`flutter_gen` 已移除） |
| 路径含 `app_localizations` | `lib/l10n/app_localizations*.dart` |

理由：

- clone 下来 `flutter pub get` 之后**不跑 codegen** 就能 `flutter analyze` / `flutter test`；CI 里只有「生成物是否与源一致」那一步会执行 `build_runner`
- 生成物与源在同一个 commit 里，review 时能看见真实影响（多了哪些 API、Drift schema 改了什么）；不提交的话，换生成器版本会静默改变运行行为
- 快照不依赖「codegen 工具链在当前机器上装得成功」

代价（知道就行，别当故障处理）：

- diff 会变长，`.g.dart` 体积不小
- 合并 / rebase 时生成物会冲突——解法**不是**手工 merge，而是解决源文件冲突后重跑 codegen 覆盖

### 重新生成时机

| 时机 | 命令 |
|------|------|
| 改了注解，或新增模型 / API / DAO / `@RoutePage` / `@injectable` | `dart run build_runner build --delete-conflicting-outputs` |
| 增删代码文件（含删掉整个 feature） | 同上。删文件后**必须**重跑，否则 DI 注册与路由仍指向已删的类 |
| 改了 `lib/l10n/*.arb` | `flutter gen-l10n`（l10n 不经过 build_runner） |
| 升级 / 降级任一 codegen 包（`freezed`、`json_serializable`、`drift_dev`、`retrofit_generator`、`auto_route_generator`、`injectable_generator`、`build_runner`） | `dart run build_runner clean` 后全量重建 |
| 升级 Flutter / Dart SDK | 同上 |
| 切分支、rebase / merge 后生成物冲突 | 解决源文件冲突后全量重建，生成物不手工编辑 |
| CI 的 `Check generated code is up to date` 失败 | 按上表重跑，把生成物一起提交 |

`--delete-conflicting-outputs` 不是可选装饰：builder 版本变化或删过文件时旧输出会与新预期冲突，不加它构建**直接失败**（报 conflicting outputs）。

### 门禁：生成物是否与源一致

CI 的 `analyze` job 有一步（见 `.github/workflows/ci.yml`）：

```bash
dart run build_runner build --delete-conflicting-outputs
flutter gen-l10n
git add -N -- lib          # 让「新增」的生成物也进入 diff
git diff --exit-code -- lib
```

几个不显然的点：

- **为什么要 `git add -N`**：`git diff --exit-code` 看不见未跟踪文件，而最常见的漂移形态恰恰是「新增一个 `@freezed` 模型 → 多出一个 `.freezed.dart`」——只用 `git diff` 会放过它
- **为什么只看 `lib/`**：生成物全部落在这里；全仓库 diff 会把 `flutter pub get` 的附带产物一起算进来
- 比的是 `build_runner build` 写盘后的结果，而不是 `--only-check`：两者等价，但后者要求 `build_runner` ≥ 2.16.0。当前 lock 是 2.16.1（可用），保留 `build` 是为了不把门禁绑死在小版本上
- **pre-commit 有意不做这一步**：它要跑完整 codegen（本项目量级是几十秒），而 pre-commit 已经跑了 `flutter test --coverage`。漏提交由 CI 兜
- 这一步排在 `flutter analyze` 之前：生成物缺失时 analyze 会报一堆「找不到 `part`/`AppLocalizations`」的噪声，先跑它能让报错指向真正的原因
- `drift_dev` 生成 schema 需要 `sqlite3` 的动态库（本项目由 `sqlite3` 3.x 的 build hook 提供，`flutter pub get` 会准备）。这一步若在 CI runner 上失败，报错会指向 `sqlite3` / `hooks_runner`，而不是 build_runner 本身

### 禁止模式

```bash
# ❌ 手改生成物 —— 2.16.0 起 build_runner 默认会修正被改过的输出（旧行为要显式开 --keep-modified-outputs）
# ❌ 把 *.g.dart / app_localizations* 加进 .gitignore
#    漂移检查、覆盖率口径、目录树检查三处都建立在「生成物提交」之上
# ❌ 用 --keep-modified-outputs 留住手改 —— 那是调试旧行为的开关，不是工作流
```

---

## build_runner 升级与 codegen 缓存（评估）

> 快照（2026-09）：版本与文件数会变，重估时用下面给的命令重新量。结论本身（要不要升级、要不要加缓存）在触发条件出现前不变。

**结论**：升级**暂时没有可升的版本**（已在 2.x 最新）；「目录级 cache」**不引入**。CI 的漂移检查每次全量构建，也不缓存。

现状（快照 2026-09）：

- `pubspec.yaml` 约束 `build_runner: ^2.4.14`，`pubspec.lock` 解析到 **2.16.1**（pub.dev 上 2.x 线最新，无 3.x）
- 生成器六个：`freezed` / `json_serializable` / `drift_dev` / `retrofit_generator` / `auto_route_generator` / `injectable_generator`；l10n 走 `flutter gen-l10n`，与 build_runner 无关
- 产物现场可查：`git ls-files lib | grep -E '\.(g|freezed|config|gr)\.dart$'`

### 升级（要不要升、什么时候重估）

2.14.0 起除 `run` 外的命令**默认走 AOT 编译**，2.13.0 起增量构建有 1.4×~4× 的提升——这些收益**已经拿到**，因为实际版本由 lock 决定（2.16.1），不由 pubspec 里的 `^2.4.14` 决定。

- **不要**为了「看起来新」把约束收紧成 `^2.16.1`：那只会让以后重新解析依赖时被无谓卡住
- **重估的信号**：某个生成器抬高了对 `build_runner` 的下限（`flutter pub get` 会直接报冲突），或撞上 2.x 修不掉的构建 bug
- 真做升级时的顺序：改约束 → `flutter pub upgrade <pkg>` → **`dart run build_runner clean` 后全量重建** → 生成物的 diff 单独成一个 commit 并完整过一遍（换版本常改变生成代码的形状）→ 跑 `flutter analyze` 与 `flutter test --coverage`

### 「目录级 cache」（结论：不引入）

先厘清一件事：build_runner **本来就有缓存**，粒度是 **asset（文件）级**，落在 `.dart_tool/build/`（已在 `.gitignore` 里）。第二次 `dart run build_runner build` 只重建受影响的子图——这就是它的增量模型，不需要额外引入什么。

「按目录切分 / 目录级 cache」的两条常见做法都不划算：

| 做法 | 为什么不 |
|------|---------|
| 按目录多次调用 `--build-filter=lib/features/xxx/**` | 每次调用都要重新加载 package config、重建 asset graph，固定开销是数十秒量级；而 builder 之间有跨目录依赖（DI 汇总到 `lib/di/service_locator.config.dart`、路由汇总到 `lib/app/routing/router.gr.dart`），拆开跑完还得再跑一次全量才正确 |
| 第三方「缓存 codegen 产物」的包（如 `cached_build_runner` 一类） | 把正确性押在 cache key 上：SDK 版本、依赖版本、`build.yaml`、builder 配置任一变化都可能让缓存与源不匹配，而它**不会报错，只会静默给出旧产物**。build_runner 官方的增量缓存都栽过跟头（workspace 与包构建间切换时的增量不正确，直到 2.15.1 才修）——用第三方缓存换来的秒数，不值得拿生成物正确性去赌 |

**CI 上不要 cache `.dart_tool/build/`**：该目录与 Dart SDK 版本、依赖解析结果强绑定。缓存命中不当时最坏的结果是「检查通过，但仓库里的生成物其实是旧的」——这道门禁的价值全在结论可信，快几秒不值这个风险。

> 真到 codegen 成为瓶颈那天（builder 数量或 `lib/` 文件数明显翻倍），正确顺序是：先用 `dart run build_runner build --verbose-durations`（2.13.0 起）量出时间花在哪个 builder，再决定砍 builder 还是改构建结构，**最后**才考虑缓存。不要从「加个 cache」起步。

---

## Memory Leak Detection (`leak_tracker`)

`leak_tracker` 已集成到脚手架中，用于开发期自动检测内存泄漏。

### 运行期检测（debug 模式）

在 `bootstrap.dart` 中通过 `_initLeakTracker()` 初始化，debug 模式下自动启用：

- 监听 `FlutterMemoryAllocations` 事件（Flutter 框架对象的创建/销毁）
- 在控制台输出未释放的对象信息
- release 模式下不生效（`assert` 块仅在 debug 模式执行）

### 测试检测

`test/flutter_test_config.dart` 配置了全局泄漏检测：

- 所有 `testWidgets` 自动启用 `LeakTesting`
- 测试中未 dispose 的 Widget、Controller、信号订阅等会被报告
- 通过 `withIgnored(createdByTestHelpers: true)` 过滤测试辅助创建的对象

### 检测范围

`leak_tracker` 只能检测到**已接入埋点**的类。好消息是：

- Flutter Framework 的所有 disposable 类都已接入（`FocusNode`、`AnimationController` 等）
- `SignalBuilder` 等 signals_flutter 组件在 `dispose` 时会自动取消订阅
- 如果一个泄漏链中包含至少一个已埋点的对象，整个链都会被捕获

> ⚠️ **`leak_tracker` 看不见 signals**：`Signal` / `AsyncSignal` / `Computed` 是纯 Dart 对象，不上报 `FlutterMemoryAllocations`。所以「测试里没报警」**不等于**「信号没有泄漏」——信号那条边界见 [frontend/state-management.md](frontend/state-management.md) 的「什么时候才需要 dispose」。

---

## Integration Testing

`integration_test/app_test.dart` 包含基础的端到端冒烟测试。

### 本地运行

```bash
flutter test integration_test/
```

### CI 运行

CI 使用 `xvfb-run`（虚拟显示）运行集成测试。

### widget 测试里不要用真实 I/O

`testWidgets` 的 `pumpAndSettle` 走**假时钟**，真实的文件 / 数据库 I/O 不会在它推进的这段时间里完成。后果有两层：

- 断言可能**假通过**：初始值为空时，即使 `refresh()` 从未跑完也成立
- 操作后的断言会失败，因为 I/O 还没回来

约定：**真实依赖用普通 `test()` 测**（那些测试没有假时钟），**页面测试把依赖 mock 掉、由测试直接推信号值**。范例：`test/features/demo/logic/storage_demo_view_model_test.dart`（真实 FileStorage + 内存数据库）与 `test/features/demo/page/storage_demo_page_test.dart`（mock ViewModel + 推信号）。

另外 `ListView` 只布局可视区内的子节点，视口外的内容 finder 找不到——测长页面时要么放大视口（`tester.view.physicalSize`），要么先滚动。

### 测试内容

当前集成测试覆盖（快照 2026-09，实际以 `integration_test/app_test.dart` 为准）：

- 应用正常启动并显示登录页面
- 输入邮箱和密码后登录按钮启用
- 空字段时登录按钮禁用
- 点击登录（走 `USE_MOCK` 的 mock）后进入 `MainRoute` 主框架，底部导航栏存在

约束与注意事项：

- **`bootstrap()` 不可重入**：DI 注册与 leak_tracker 启动都只能执行一次。因此整个冒烟流程只在**一个** `testWidgets` 中调用一次 `app.main()`；拆成多个 `testWidgets` 各自启动会在第二次抛「Bad state: Leak tracking is already enabled.」
- **测试需清理登录态**：`SharedPreferences` 在设备上跨运行保留，测试开头要 `prefs.clear()`，否则上一次运行残留的登录态会让启动直接进主框架
- **字体**：主题（`lib/core/theme/app_theme.dart` 的 `_textTheme`）**不指定字体家族**，走平台默认字体，所以测试与设备上都不存在"渲染时联网拉字体"的问题。如果以后引入按需下载字体的方案（如 `google_fonts`），务必在测试里关掉运行时下载（`GoogleFonts.config.allowRuntimeFetching = false`）——否则 `pumpAndSettle` 会卡数分钟且结果不稳定。生产环境更该把字体打进产物，而不是运行时下载
- `msw_dio_interceptor` 的 mock 由 `.env` 的 `USE_MOCK` 控制（`.env.development` 默认 `true`）。写 mock 规则必踩的坑（必须 `MockRule.regex` 且锚定结尾）见 [backend/network-guidelines.md](backend/network-guidelines.md) 的 Mock 一节

---

## 环境配置与 release 构建

`.env` 文件按「环境名」加载，环境名的解析优先级见 `lib/bootstrap.dart` 的 `_activeEnv`：

1. `--dart-define=env=xxx`（显式指定）
2. 构建模式默认值：debug / profile → `development`，release → `production`

**不要**退回成 `String.fromEnvironment('env', defaultValue: 'development')`：那会让 release 也加载 `.env.development`，包静默跑在 localhost + `USE_MOCK=true` 上，界面正常但数据全假。

其他约束：

- `.env` / `.env.development` / `.env.production` 已提交，并作为 asset **打进产物**。因此只能放非密钥配置（`BASE_URL`、`USE_MOCK`）；密钥写进去既会进 git 也能从 apk 中提取。真实后端地址建议用 `--dart-define=BASE_URL=...` 传入。
- `BASE_URL` 缺失时 `bootstrap()` 直接抛异常（fail fast），不会静默启动。

### 有意留白（模板不提供的部分）

以下属于**目标应用**的职责，脚手架刻意不配置。它们不是遗漏，读到这段时不要当成待办：

- **release 签名**：`android/app/build.gradle.kts` 的 release 仍使用 debug keystore，没有 `key.properties` / `signingConfigs.release`
- **minify / 混淆**：未开启 `isMinifyEnabled` / `isShrinkResources`，也没有 `proguard-rules.pro`；构建脚本未加 `--obfuscate --split-debug-info`
- **build flavor**：未做 dev/staging/prod flavor，环境切换用上面的 `--dart-define=env=xxx` 代替
- **iOS release 签名**：描述文件与证书需在 Xcode 中配置
