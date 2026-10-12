# 跨层与门禁

> 不属于单一层、或同时管「门禁」与「发布」的约定。
> 唯一入口见 [Spec 索引](index.md)。

**本文件的写法约定**：只写**现行约束** —— 现在时、命令式、一条能执行的规则配一两句为什么。
历史、被否决的方案、退役的规则不写进 spec：需要禁止的行为直接写成命令式「不要做 X」，不解释来龙去脉。
正文不出现日期叙事与 commit 号 —— 出现了就改写成现状陈述。

---

## 架构边界与代码形态（`packages/app_lints/` 插件）

这七条规则由**分析插件**实现（`analysis_server_plugin`），不是脚本：

| 规则 | 效果 |
|------|------|
| `no_upper_import_in_core` | `core/**` 不能 import/export `features/**` 或 `app/**` |
| `cross_feature_only_data` | 不能引用其他 feature 的 `page/` / `logic/`，跨 feature 只共享 `data/` |
| `no_material_import_in_logic` | `features/*/logic/` 不得 import/export `material.dart` / `widgets.dart`，也不得引**本 feature** 的 `page/`（logic 是纯 Dart 状态层；`ChangeNotifier` / `@visibleForTesting` 所在的 `foundation` 放行） |
| `no_service_locator_in_logic` | `features/*/logic/` 里不得取 service locator（`getIt<X>()` / `GetIt.I<X>()` / `GetIt.instance<X>()` / `GetIt.I.get<X>()`，构造器注入，理由见 [ADR-0001](../../docs/adr/ADR-0001.md)） |
| `page_must_expose_view_model_injection_point` | 用 `getIt<*ViewModel>()`（含 `GetIt.I<*ViewModel>()` / `GetIt.instance<*ViewModel>()`）取 ViewModel 的页面，三件套缺一不可：`final T? viewModel;`、构造参数 `this.viewModel`、`viewModel ?? getIt<T>()` 兜底 |
| `avoid_async_state_map` | 不得调用 `AsyncState.map`，三态渲染用 `AsyncView`（理由见 [ui/state-management.md](ui/state-management.md)「渲染状态」） |
| `comment_block_too_long` | 连续注释块最多 10 行，超限就把解释搬进 spec（见 [guides/comment-guidelines.md](guides/comment-guidelines.md)） |

前两条与规则 7 都是「谁能依赖谁」：前两条管依赖方向，规则 7 管同一 feature 内的层次。第三、四条是同一件事的两面：ViewModel 的依赖要能从构造器签名读出来，页面也要给测试留一个只有测试会用的注入口（[ADR-0001](../../docs/adr/ADR-0001.md) 的缓解措施）。这两条**没有任何编译器会提醒**——漏一个页面就少一处，所以用退出码兜住。

后两条的判据必须是 AST：`AsyncState.map` 要看是否**同时带 `data` 与 `error` 两个具名实参**（正则分不清它与 `list.map(...)`，而误报会挡住提交）；注释块要看**字符偏移**（多行字符串里的 `//` 不是注释）。

| 想看什么 | 文件 |
|---|---|
| 规则实现（AST 适配 + 判据） | `packages/app_lints/lib/src/rules.dart` |
| 路径 / URI 解析（纯函数） | `packages/app_lints/lib/src/paths.dart` |
| 规则测试（`analyzer_testing`，正反例） | `packages/app_lints/test/rules_test.dart` |
| 插件入口（`final plugin = ...`） | `packages/app_lints/lib/main.dart` |

### 启用点与调用形式

根 `analysis_options.yaml` 顶层的 `plugins:` 声明它：

```yaml
plugins:
  app_lints:
    path: packages/app_lints
```

七条都用 `registerWarningRule` 注册 → **默认开**，不需要在 `diagnostics:` 里逐条打开（只有 `registerLintRule` 注册的才默认关）。

- **`dart analyze` 必须显式传文件名**：插件诊断只在显式传文件时输出，单文件、多文件都行，**传目录不行**——目录模式不报错、只是静默少跑规则，正是「有门禁的错觉」的形态。
- **analyze 的扫描面来自 justfile，漏目录不会报错**：roots 由根 `justfile` 的 `app_files` / `tool_files` 两条 `list_dart_files.dart` 调用决定；`git ls-files` 对不存在的路径返回空、退出码 0，所以「少写一个目录」只表现为门禁少看一批文件，与全绿毫无差别。两条断言兜住：每个含 Dart 源码的顶层目录必须被某个 root 覆盖，或在排除名单里（失败信息点名目录）；每个 root 各自必须列得到文件（失败信息说明「该 root 产出 0 个文件」）。新增顶层目录、给 root 改名或删目录时它会拦下 —— 见 [test/tool/analyze_coverage_test.dart](../../test/tool/analyze_coverage_test.dart)。
- **`flutter analyze` 不加载插件**：同一份 `plugins:` 配置它只报「No issues found」。所以门禁是 `justfile` 里的两步 `dart analyze --fatal-infos`（`lib + test` 与 `tool + packages`），文件列表由 `tool/list_dart_files.dart` 生成（`git ls-files` + 磁盘存在性过滤）。**CI 与 pre-commit 都不自己拼这两步，统一跑 `just verify`** —— 调用形式抄错不报错、只少跑，所以不留第二份。
- **读门禁输出要看退出码**：info → 0、warning → 2、error → 3；带 `--fatal-infos` 时 info 也变 1。CI 与 pre-commit 只认退出码，别用终端有没有红字判断。
- **生成物豁免**：每条规则自带 `isGeneratedPath` 判断（`.g.dart` / `.freezed.dart` / `.gr.dart` / `.config.dart` / `.gen.dart` / `/gen/` / `app_localizations`）。生成器只保证产物「能编译」，不保证遵守层次约定（路由要汇总所有 feature 的 `page/`），且里面的违规没法手工修。口径与根 `.gitignore`、`tool/generated_paths.dart` 一致，改动时要一起改（漂移由 `test/tool/generated_paths_consistency_test.dart` 拦下）。
- **判据细节**：全部规则先过 `context.isInLibDir`——只有 `lib/` 下的文件参与判断（`test/` 里 widget 测试的 `build` 不该被管）。放行的情况：feature 引用自己、组合根（`lib/app/`）引用任何 feature（FSD 的 app 层负责装配）、生成文件。
- **规则 3/4 的节点形态**：生产代码的 `getIt` 是**对象**（`lib/di/service_locator.dart` 的 `final GetIt getIt = GetIt.instance;`），对象上的 `getIt<X>()` 走隐式 `call`，解析成 `FunctionExpressionInvocation`；`GetIt.I.get<X>()` 才是 `MethodInvocation`。两条规则都按**接收者名字**判定（`getIt` / `GetIt.I` / `GetIt.instance`）并同时订阅 `addMethodInvocation` 与 `addFunctionExpressionInvocation` —— 只订阅前者会让规则对仓库自己的写法静默失效。插件单测的桩必须镜像这个对象形态，由 `test/tool/lint_wiring_test.dart` 的 W4 拦下。
- 规则 4 只看 `*ViewModel` 类型：页面直接取依赖（`getIt<AuthStorage>()` / `getIt<UserPreferences>()`，如 `home_page`、`profile_page`）不在管辖内；`features/*/logic/` 也由规则 3 直接禁止取容器，不重复报。

```dart
// ✅ 页面取 ViewModel 的标准三行
final ArticleViewModel? viewModel;                       // 只有测试会传
const ArticleListPage({super.key, this.viewModel});      // 参数可选，路由代码不用改
final vm = useMemoized(() => viewModel ?? getIt<ArticleViewModel>());
```

### 防「门禁静默失效」

规则 1/2 靠 `packages/app_lints/lib/src/paths.dart` 里硬编码的 `selfPackagePrefix`（`package:my_app/`）把 `package:` URI 解析成仓库相对路径。它与根 `pubspec.yaml` 的 `name` 不同步时，解析静默返回 `null` —— 规则不报错、也不再报违规，**门禁变成空转**。`tool/init_project.dart` 改名会同步替换两者，手工改名漏掉一边由 `test/tool/self_package_prefix_test.dart` 拦下。

「插件没被加载」「规则没被注册」「文档漂移」同样是静默失效：`dart analyze` 照常退出 0。`test/tool/lint_wiring_test.dart` 用四条静态断言兜住（**不** spawn `dart analyze`）：

| 断言 | 抓什么失效 |
| --- | --- |
| W1 根 `analysis_options.yaml` 的 `plugins.app_lints.path` 指向的目录存在且含 `lib/main.dart` | 插件路径写错 / 包改名 / 入口搬走 → 插件根本不加载 |
| W2 `main.dart` 里 `registerWarningRule(<XxxRule>())` 的类名集合 == `rules.dart` 里声明的具体规则类集合 | 漏注册某条规则 / 注册了不存在的类 |
| W3 `rules.dart` 里 `LintCode('<name>', …)` 的名字集合 == 本文档规则表格里的清单 | 规则改名后文档漂移、spec 漏写新规则 |
| W4 插件单测的 locator 桩形态 == `lib/di/service_locator.dart` 的实际声明形态，且生产侧必须是「对象」 | 桩退回函数形态 → 规则判据与生产形态脱节，测试全绿但规则对生产代码失效 |

`test/tool/generated_paths_consistency_test.dart` 用两条断言兜住生成物口径的三处副本：把根 `.gitignore` 的生成物段落当**唯一真源**，归一成谓词集合，与 `tool/generated_paths.dart`、`packages/app_lints/lib/src/paths.dart` 各自抽取的谓词集合比对（D2 点名差异项），再用样例路径核对三处判定一致（D4）。口径来源见上「生成物豁免」。

### 已知边界：`dart analyze` 真的会输出诊断吗

W1–W4 覆盖「接线断掉」与「判定退化」，`rules_test.dart` 覆盖「规则逻辑对」，但**没有自动化门禁证明 `dart analyze` 真的会把诊断打出来** —— 插件 API 语义变化、`registerWarningRule` 行为变化都落在这一层。唯一能兜住它的是**活体探针**（把探针文件写进 `lib/`，真跑 `dart analyze` 断言诊断出现），单次热态实测约 +13s，本仓库有意不采用：探针必须写进 `lib/`（崩溃会残留），且要在测试里 spawn `dart analyze`。残留风险的取舍与替代方案记在 `.trellis/tasks/10-12-lint-self-proof/research/lint-plugin-wiring-findings.md`。

### 禁止模式

- ❌ `features/*/logic/` 里出现 `getIt()` —— 依赖走构造器注入
- ❌ 跨 feature 引用别人的 `page/` / `logic/` —— 只允许 `data/` 层与 `core/`
- ❌ 在越界处加 `// ignore: <规则名>` 绕过：插件诊断走 analyzer 的豁免机制，**加了就真的放行**

实际例子：`profile` 需要「登出」这项能力时，引用的是 `features/auth/data/auth_repository.dart`
（data 层），不是 auth 的 `logic/auth_view_model.dart`。

---

## 目录树一致性（`tool/check_readme_tree.dart`）

文档里的 `lib/` 目录树是**结构性快照**：加删文件时它不会自己更新，而 markdown 链接检查也管不到它 —— 树里的路径是纯文本，不是链接，编辑器和 Git 都不会报错。

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
| [directory-structure.md](directory-structure.md) | `lib` |

`packages/` 下的独立工具包（当前只有 `app_lints`）是工具、不是应用代码，不进任何目录树。

---

## 文档链接一致性（`tool/check_doc_links.dart`）

目录树门禁只管树里的**纯文本路径**；markdown 链接与 dart 注释里的 spec 引用不在它视野里 ——
目录改名或文件改名会静默留下断链，编辑器和 Git 都不报。这道门禁补上：

```bash
dart run tool/check_doc_links.dart        # 退出码 0 = 全绿，1 = 有断链
```

两条规则：

1. **markdown 行内链接**（`[text](target)`）的相对目标必须存在（文件或目录）
2. **dart 注释里的 spec 引用**（`data/xxx.md`）必须指向真实文件

扫描面：根 `README.md` / `AGENTS.md`、`docs/**/*.md`、`.trellis/spec/**/*.md`、
`.cursor/rules/*.mdc`、`lib/**/*.dart`、`test/**/*.dart`。

| 排除 | 理由 |
|------|------|
| `.trellis/tasks/**` | 任务笔记：活动任务会引用**尚未创建**的目标路径，归档任务是历史 |
| `.pi/skills/**`、`.agents/skills/**` | vendored 第三方文档，含作者本机的 `file://` 绝对链接 |
| `packages/**` | 独立包，自带 README 的链接面向 pub 场景 |
| 生成物 | 复用 `tool/generated_paths.dart`：里面的引用没法手工修 |

围栏代码块与行内代码里的 `](...)` 不是链接（文档里写正则的例子会被误判），带 scheme 的目标
（`https:` / `mailto:` / `file:`…）与纯锚点一律跳过。规则 B 只认 `(data|ui|guides)/<名>.md`
与裸 `cross-cutting.md`，且只看 `//` 注释行 —— **宁可少报也不误报**：误报会直接挡住提交。

**锚点与章节关键词不进这道门禁**（`guides/comment-guidelines.md` 要求引用写章节关键词而非编号）：
校验关键词要解析每份 `.md` 的标题集合，而改章节名是本仓库的常规操作，误报会先卡住改名任务。
这类引用由 `tool/check_doc_anchors.dart` 承担 —— **只报告，不拦提交**：

```bash
just check-anchors                              # 改完标题顺手跑一下；退出码恒为 0
dart run tool/check_doc_anchors.dart --strict    # 有关键词对不上时退出码 1
```

判据：`路径.md「关键词」` 的引用，目标文件里**任一标题包含**该关键词即通过（引用写的是关键词，
不是完整标题）；无 `「」` 的引用跳过。扫描面直接调 `check_doc_links.dart` 的 `collectFiles()`，
不抄第二份。也不做自动修复（`--fix`），只报告 `文件:行号`。

### 已知盲区（全绿 ≠ 无问题）

这条门禁是**文件级**的，下面这些不被覆盖 —— 遇到时靠 review：

- **大小写笔误**：规则 B 只认小写文件名，`data/No-Such.md` 不报（当前 spec 全小写，无实际漏报）
- **`%20` 等 URL 编码**：链接目标不做解码
- **引用式链接**（`[x][ref]` + `[ref]: target`）与带标题的 `[x](target "t")`：规则 A 只认行内形式
- **跨行 code span** 与 4 个以上反引号围栏里嵌 3 个反引号：可能误报

排除项 `.pi/`、`.agents/`、`packages/`、`.trellis/tasks/` 在现有扫描面下本就不可达，
列出来是**防御性**的：将来把扫描面放宽时别忘了一起看。

---

## 有意不设的项

下面这些「缺失的门禁」是**决定**，不是待办。列在这里，免得每次 review 都被重新提一遍：

| 不设 | 为什么 | 靠什么兜 |
| --- | --- | --- |
| 覆盖率阈值 / lcov | 阈值对个人项目没有意义：它不反映可维护性，只会诱导凑数字 | 人工看 `flutter test --coverage` |
| 「清理未使用依赖」的自动化 | 见「依赖声明」：只拦「声明了却没用」，反向没有门禁 | 改代码的人顺手删 |
| 文档引用的**锚点与章节关键词**校验 | 见「文档链接一致性」：改章节名是本仓库常规操作，误报会卡住它 | [tool/check_doc_anchors.dart](../../tool/check_doc_anchors.dart)（只报告）+ review |
| 目录树的**全仓库**核对 | 见「目录树一致性」：门禁只覆盖 `README.md` 与 `directory-structure.md` | 人工同步其余位置 |
| 导航标签与测试的同步 | 见 [ui/routing.md](ui/routing.md)「主框架标签」 | review |
| 「不存在的东西」的守卫（事件总线、per-ViewModel 日志、`domain/` 层…） | 没有稳定判据，硬做成门禁只会误报 | [`../../.cursor/rules/project-conventions.mdc`](../../.cursor/rules/project-conventions.mdc)「不存在的东西」清单 + review |

---

## 覆盖率（不设门禁）

覆盖率**不进门禁**：没有阈值脚本、不生成 lcov，`just verify` 里跑的就是 `flutter test`。

- 想临时看数字自己跑 `flutter test --coverage` —— 那是人工参考，不拦提交
- 因此也不再需要「只统计手写代码」的剔除逻辑：生成物已由 `.gitignore` 排除，不必再为它们写豁免
- 没有自定义脚本，也没有阈值：覆盖率不是一个门禁，只是一条人工参考（取舍见「有意不设的项」）

---

## 改名脚本（`tool/init_project.dart`）

```bash
just init                                                              # 交互式
just init --yes --name=my_next_app --application-id=com.example.my_next_app   # 非交互（CI / 脚本）
```

覆盖范围（每一项都是「必改点」）：`pubspec.yaml` 的 `name` / `description`、全仓库
`package:<旧名>/`、根组件类名、Android `namespace` + `applicationId` + `android:label` +
`MainActivity.kt`（连目录一起搬）、iOS `PRODUCT_BUNDLE_IDENTIFIER`（含 `.RunnerTests`）
与 `CFBundleDisplayName` / `CFBundleName`。**`packages/app_lints/lib/src/paths.dart` 里硬编码的
`selfPackagePrefix`（`package:<包名>/`）最要命**——漏了它，规则 1/2 会把所有 import 当成
外部包静默放行（见上「防门禁静默失效」）。

两条语义，改了要同步 `test/tool/init_project_test.dart`：

- **全有或全无**：先规划、后写盘。任一必改点没匹配到 → 列出「哪一处没对上」并以非零
  退出码结束，磁盘不变。半改的仓库连 `flutter analyze` 都跑不起来，定位成本远高于
  直接报位置。
- **可选项不拦**：文档、`.gitignore`、`<旧名>.code-workspace` 这类文本里的裸包名改不到
  只提示，不影响退出码。

回归测试分两层（逐条见 [guides/rename-checklist.md](guides/rename-checklist.md)）：fixture
跑在每次 `flutter test` 里；端到端那条要 `SCAFFOLD_E2E=1`（CI 的 `analyze` job 带了它），把
真实仓库复制到临时目录改名后按 `just deps` 的两步 bootstrap（根 `flutter pub get` + 子包
`dart pub get`）再 `flutter analyze`，专门兜「改完名 import
全断」。`test/tool/self_package_prefix_test.dart` 是另一条防线：它盯 `pubspec.name` 与
`selfPackagePrefix` 是否一致，手工改名漏掉一边会被它拦下。

---

## 依赖声明（`depend_on_referenced_packages`）

依赖声明的一致性**只剩一个方向有门禁**：import 了却没在 `pubspec.yaml` 声明，由
`analysis_options.yaml` 打开的 analyzer 规则 `depend_on_referenced_packages: error` 拦下 —— 它跟着
`just analyze` 的两步一起跑，没有额外进程。

反向「声明了却没用」**没有门禁**：脚手架不做「清理未使用依赖」的自动化，靠改代码的人顺手删。
这是刻意的取舍 —— 上一任工具 `dependency_validator` 两个方向都管，但它是第三方可执行文件，
每次门禁都要重新解析一遍整棵包图；换成 analyzer 规则后这项检查零增量成本。

> 这条规则管「声明与使用一致」；`packages/app_lints` 的规则 1/2 管的是「谁能依赖谁」。
> 两者互补，都不能替代对方。

---

## 供应链门禁（`dart pub outdated` / OSV）

「声明与使用一致」（`depend_on_referenced_packages`）与「锁定的版本有没有已知漏洞」无关。
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

### 策略：生成物不入库（gitignore）

`.gitignore` **排除**生成物，它们不提交进 git。判定「哪些是生成物」的口径与 `tool/generated_paths.dart` 的 `isGeneratedPath()`、`packages/app_lints/lib/src/paths.dart` 的同名函数一致（三处改动要同步）：

| 形态 | 例子 |
|------|------|
| `*.g.dart` | `json_serializable` / `retrofit` / `drift` 的行类 |
| `*.freezed.dart` | 模型 |
| `*.gr.dart` | `auto_route` 的路由类 |
| `*.config.dart` | `injectable` 的 DI 注册 |
| `*.gen.dart`、路径含 `/gen/` | 资源访问器（当前不存在，`flutter_gen` 已移除） |
| 路径含 `app_localizations` | l10n 生成物（本项目已裁剪 l10n，口径保留给裁剪前的版本） |

理由：

- 生成物是机器产物，diff 噪声大；合并 / rebase 时冲突只能靠重跑 codegen 解决，入库没有 review 价值
- clone 后跑一次 `just deps` + `just codegen` 就能得到与源一致的结果；CI 在门禁前现场跑同一命令，**不存在「忘了提交生成物」这类失败**

代价（知道就行，别当故障处理）：

- clone 后**不跑 codegen 就 analyze / test 会失败**（缺 `part` / provider）——快速开始里 `just codegen` 是必做步骤
- 换生成器版本会**静默**改变生成代码的形状，且不会在 git diff 里露出来；升级 codegen 包后本地必须 `just codegen-reset` 并跑测试兜底

### 重新生成时机

| 时机 | 命令 |
|------|------|
| clone 后首次构建 / analyze / test | `just codegen` |
| 改了注解，或新增模型 / API / DAO / `@RoutePage` / `@injectable` | 同上 |
| 增删代码文件（含删掉整个 feature） | 同上。删文件后**必须**重跑，否则 DI 注册与路由仍指向已删的类 |
| 升级 / 降级任一 codegen 包（`freezed`、`json_serializable`、`drift_dev`、`retrofit_generator`、`auto_route_generator`、`injectable_generator`、`build_runner`） | `just codegen-reset`（clean + 全量重建） |
| 升级 Flutter / Dart SDK | 同上 |
| 切分支、rebase / merge 后本地生成物与源不一致 | 重跑 `just codegen`（生成物不手工编辑） |

**不要加 `--delete-conflicting-outputs`**：它在 build_runner 2.16.0 起已是**被移除的选项** —— 传进去不报错、也**不起任何作用**，只会在输出里多一条 warning（源码注释 `// Removed options, kept to not break old command lines.`）。它当年要解决的事（覆盖冲突输出、修掉被手改过的旧产物）从那版起是默认行为；想退回旧行为要用 `--keep-modified-outputs`。

### 门禁与 CI

- **本地 `just verify` 不跑 codegen**（假定生成物已在磁盘上，快速开始的 `just codegen` 已执行过）；**pre-commit 有意不跑** —— 完整 codegen 是几十秒量级
- **CI 的每个 job 都在门禁前跑 `just codegen`**：生成物不入库，checkout 之后现场生成是唯一来源。codegen 统一排在 analyze / test 之前 —— 生成物缺失时 analyze 会报一堆「找不到 `part` / provider」的噪声，先生成能让报错指向真正的原因
- `drift_dev` 生成 schema 需要 `sqlite3` 的动态库（本项目由 `sqlite3` 3.x 的 build hook 提供，`just deps` 会准备）。这一步若在 CI runner 上失败，报错会指向 `sqlite3` / `hooks_runner`，而不是 build_runner 本身
- **本项目没有 l10n**，所以这里**没有** `flutter gen-l10n`：那个命令在缺 `l10n.yaml` 时会直接失败（见 [ui/localization.md](ui/localization.md)）

### codegen 的禁止模式

```bash
# ❌ 手改生成物 —— 2.16.0 起 build_runner 默认会修正被改过的输出（旧行为要显式开 --keep-modified-outputs）
# ❌ 把生成物 `git add -f` 加回版本库 —— 策略是不入库；.gitignore 与 isGeneratedPath 是同一口径
# ❌ 用 --keep-modified-outputs 留住手改 —— 那是调试旧行为的开关，不是工作流
```

---

## build_runner 升级与 codegen 缓存（评估）

**结论**：没有可升的版本（2.x 线已最新，无 3.x）；「目录级 cache」**不引入**；CI 不缓存 `.dart_tool/build/`。

- 版本由 `pubspec.lock`（2.16.1）决定，不由 `pubspec.yaml` 的 `^2.4.14` 决定 —— 2.13 / 2.14 带来的增量与 AOT 收益已经拿到。
  **不要**为了「看起来新」收紧约束；重估的信号是某个生成器抬高了下限（`flutter pub get` 直接报冲突）。
- 真升级的顺序：改约束 → `flutter pub upgrade <pkg>` → `just codegen-reset` 全量重建 → 测试核对生成物
  （生成物不入库，没有 diff 可 review）→ `just verify`。
- build_runner **本来就有 asset 级增量缓存**（`.dart_tool/build/`），不需要额外引入。按目录切 `--build-filter`
  每次都要重建 asset graph（固定开销数十秒），而 DI / 路由产物是跨目录汇总的，拆开跑还得再全量跑一次才正确。
- 第三方「缓存 codegen 产物」的包把正确性押在 cache key 上：SDK / 依赖 / `build.yaml` 任一变化都可能**静默给出
  旧产物**。CI 缓存 `.dart_tool/build/` 同理 —— 这道门禁的价值全在结论可信，快几秒不值这个风险。
- 真到 codegen 成为瓶颈那天，先用 `dart run build_runner build --verbose-durations` 量出时间花在哪个 builder，
  再决定砍 builder 或改构建结构，**最后**才考虑缓存。不要从「加个 cache」起步。
---

## 内存泄漏检测（`leak_tracker`）

开发期自动检测：`bootstrap.dart` 的 `_initLeakTracker()` 在 debug 下监听 `FlutterMemoryAllocations`
并把未释放对象打到控制台；`test/flutter_test_config.dart` 让所有 `testWidgets` 自动启用 `LeakTesting`
（`withIgnored(createdByTestHelpers: true)` 过滤测试辅助对象）。release 模式不生效（`assert` 块）。

只能检测**已埋点**的类：Flutter Framework 的可释放类都已接入（`FocusNode`、`AnimationController` 等），
signals_flutter 的组件在 `dispose` 时会自动取消订阅；泄漏链里只要有一个已埋点对象，整条链都会被捕获。

> ⚠️ **`leak_tracker` 看不见 signals**：`Signal` / `AsyncSignal` / `Computed` 是纯 Dart 对象，不上报
> `FlutterMemoryAllocations`。「测试里没报警」**不等于**「信号没泄漏」——那条边界见
> [ui/state-management.md](ui/state-management.md) 的 dispose 判据。

---

## Android 依赖仓库镜像

`android/build.gradle.kts` 与 `android/settings.gradle.kts` 里的阿里云镜像**默认不启用**，
只在 `ALIYUN_MAVEN_MIRROR=1` 或 `-PaliyunMirror` 时插入。原因是实测：runner 上它回过 502，
而 Gradle 遇到首个仓库报错会把该仓库禁掉、直接判定依赖不可解析 —— 构建失败。
镜像要有效必须排在官方仓库之前，所以只能整体开/关。

## widget 测试里不要用真实 I/O

`testWidgets` 的 `pumpAndSettle` 走**假时钟**，真实的文件 / 数据库 I/O 不会在它推进的这段时间里完成。后果有两层：

- 断言可能**假通过**：初始值为空时，即使 `refresh()` 从未跑完也成立
- 操作后的断言会失败，因为 I/O 还没回来

约定：**真实依赖用普通 `test()` 测**（那些测试没有假时钟），**页面测试把依赖 mock 掉、由测试直接推信号值**。范例：`test/features/demo/logic/storage_demo_view_model_test.dart`（真实 FileStorage + 内存数据库）与 `test/features/demo/page/storage_demo_page_test.dart`（mock ViewModel + 推信号）。

另外 `ListView` 只布局可视区内的子节点，视口外的内容 finder 找不到——测长页面时要么放大视口（`tester.view.physicalSize`），要么先滚动。

- **字体**：主题（`lib/core/theme/app_theme.dart` 的 `_textTheme`）**不指定字体家族**，走平台默认字体，所以测试与设备上
  都不存在「渲染时联网拉字体」的问题。若以后引入按需下载字体的方案（如 `google_fonts`），测试里必须关掉运行时下载
  （`GoogleFonts.config.allowRuntimeFetching = false`），否则 `pumpAndSettle` 会卡数分钟且结果不稳定；生产环境更该把字体打进产物。
- `msw_dio_interceptor` 的 mock 由 `USE_MOCK` 控制（`.env.example` 默认 `true`）。写 mock 规则必踩的坑（必须 `MockRule.regex` 且锚定结尾）见 [data/network-guidelines.md](data/network-guidelines.md) 的 Mock 一节

---

## 环境配置与 release 构建

环境值放在**入库的 `.env.example`**，由 `bootstrap()` 用 dotenv 加载
（`await dotenv.load(fileName: '.env.example')`）；`lib/bootstrap.dart` 校验 `BASE_URL`，
`NetworkConfig.fromEnv(dotenv.env)` 是唯一消费者：

```bash
just run                # = flutter run（dotenv 自己读 .env.example）
flutter build apk       # 发版构建，配置同样来自 .env.example
```

- **只提交 `.env.example`**：它同时声明在 `pubspec.yaml` 的 `assets:` 里，而 **dotenv 只能加载 asset** ——
  所以换环境不能靠换文件：要连自己的后端就改它（会显示为 dirty，预期行为）。
- **只能放非密钥配置**：这份文件会入库、并作为 asset 打进产物，拿到包的人都能提取出来 ——
  本模板不做密钥注入，敏感值放服务端。
- `.env` / `.env.*` 已被 `.gitignore` 忽略，dotenv 也不会读它们：**新建这类文件并指望运行时加载是无效的**。
- `BASE_URL` 缺失时 `bootstrap()` 直接抛异常（fail fast），不会静默启动。

### 有意留白（模板不提供的部分）

以下属于**目标应用**的职责，脚手架刻意不配置。它们不是遗漏，读到这段时不要当成待办：

- **release 签名**：`android/app/build.gradle.kts` 的 release 仍使用 debug keystore，没有 `key.properties` / `signingConfigs.release`
- **minify / 混淆**：未开启 `isMinifyEnabled` / `isShrinkResources`，也没有 `proguard-rules.pro`；构建脚本未加 `--obfuscate --split-debug-info`
- **build flavor**：未做 dev/staging/prod flavor，环境切换靠改入库的 `.env.example` 代替
- **iOS release 签名**：描述文件与证书需在 Xcode 中配置
