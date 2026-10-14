# design: 门禁自证

## 1. 现状与根因（实测，证据见 research/lint-plugin-wiring-findings.md）

`just verify` 全绿，但规则 3（`no_service_locator_in_logic`）与规则 4
（`page_must_expose_view_model_injection_point`）对仓库真实写法不生效。

根因是**节点类型**，不是「合成节点报不出来」：

| 写法 | 解析后的节点 |
| --- | --- |
| `getIt<X>()`（生产真实形态） | `FunctionExpressionInvocation`（`function` = `SimpleIdentifier(getIt)`） |
| `GetIt.I<X>()` / `GetIt.instance<X>()` | `FunctionExpressionInvocation`（`function` = `PropertyAccess`） |
| `GetIt.I.get<X>()` | `MethodInvocation` |

生产代码是 `final GetIt getIt = GetIt.instance;`（对象，靠 `GetIt.call` 调用），
所以对象上的调用走隐式 `call`，落成 `FunctionExpressionInvocation`。
两条规则只订阅了 `registry.addMethodInvocation(...)` → 形态 1/2/3 全部收不到。
`rules_test.dart` 的桩把 `getIt` 写成顶层函数，于是测试测的是仓库里不存在的形态，全绿。

## 2. 边界与契约

- **不改**：`LintCode` 名与 `severity`、`justfile`、CI、`analysis_options.yaml`、`tool/` 脚本、`pubspec.yaml`。
- **不改**：规则的路径判据（`context.isInLibDir` + `currentPath` + `isGeneratedPath`）与「只认 `data` 层跨 feature」等既有口径。
- **可变**：`packages/app_lints` 内部判据的实现方式（新增订阅点、抽取共用谓词、改注释）。
- 新增文件只有两个测试文件（R6）。

## 3. 规则 3/4 的修复设计

### 3.1 判据从「MethodInvocation 的方法名」提升为「调用表达式的接收者形态」

现有 `_isServiceLocatorLookup(MethodInvocation)` 把「是 locator 取用」与
「是哪种节点」耦合在一起，这是失效的结构性原因。拆成两层：

```dart
/// 接收者是不是本项目的 locator —— 一律按**名字**判定，与既有 _isNamed 风格一致。
/// 认 `getIt`（顶层变量）、`GetIt.I`、`GetIt.instance` 三种写法。
bool _isLocatorReceiver(Expression? expression);

/// MethodInvocation 形态：显式成员调用 `GetIt.I.get<X>()` / `getIt.get<X>()`，
/// 以及顶层函数形态 `getIt<X>()`（methodName 为 getIt、无接收者）。
bool _isLocatorLookup(MethodInvocation node);

/// FunctionExpressionInvocation 形态：对象上的隐式 call —— `getIt<X>()` /
/// `GetIt.I<X>()` / `GetIt.instance<X>()`。
bool _isLocatorImplicitCall(FunctionExpressionInvocation node);
```

- `_isGetItInstance` 目前只认 `GetIt.I`，需扩成同时认 `GetIt.instance`
  （`PropertyAccess` 形态的 `GetIt.instance`）。两者都是「访问单例」，合并为一个谓词。
- 顶层函数形态（`methodName.name == 'getIt' && target == null`）保留，它不属于本项目，
  但删除会让「同一个规则在不同工程里行为不同」这件事变成隐性假设。
- 现有 `_isServiceLocatorLookup` 里那条 `_isNamed(node.target, 'getIt')` 分支保留：
  它覆盖 `getIt.get<X>()` 这类显式调用，虽然仓库不用。

### 3.2 订阅点

- `ServiceLocatorInLogicRule`：`registry.addMethodInvocation` **加上**
  `registry.addFunctionExpressionInvocation`（`analyzer 14.4.0` 的
  `RuleVisitorRegistry` 已提供该订阅点）。
- `PageInjectionPointRule`：`_ContainerLookupCollector` 是
  `RecursiveAstVisitor`，加 `visitFunctionExpressionInvocation` 收集同一批类型
  （`typeArguments` 在 `FunctionExpressionInvocation` 上同样可读，取
  `NamedType` 的 `name.lexeme` 与 `endsWith('ViewModel')` 的口径不变）。

### 3.3 报出位置

`reportAtNode(node)`。实测 `FunctionExpressionInvocation` 节点本身与它的 `function`
标识符都**不是**合成节点（`offset` 是真实源码偏移），所以不需要退到 `reportAtOffset`。
`CommentBlockTooLongRule` 用 `reportAtOffset` 是因为它要报「注释块」这个没有节点对应的区间，与本处无关。

### 3.4 取舍：为什么不按「静态类型是 GetIt」判定

按类型判定要依赖解析结果，而在 `dart analyze` 的插件通道里规则会同时拿到未解析与已解析的
AST（实测：探针文件里 `GetIt.I.get` 的接收者未定义时规则照样报出）。按名字判定在两种上下文
都成立，且与仓库既有风格一致。代价：一个恰好叫 `getIt` 的无关局部变量会误报 ——
但那个名字在本仓库就是 locator，且误报方向是「更严格」，可接受。

### 3.5 为什么不改成 `addCompilationUnit` 全量自走 AST

订阅点存在就用订阅点，减少自写遍历。`CommentBlockTooLongRule` 与
`_PageInjectionPointVisitor` 之所以自己走，是因为需要字符偏移 / 需要「整个文件里的全部取用」，
本处不需要（规则 3 逐节点报，规则 4 的收集器本来就在自走）。

## 4. R3：插件的单测桩镜像生产形态

`packages/app_lints/test/rules_test.dart` 的 `_locatorStub` 改成生产形态的等价物：

```dart
class GetIt {
  static GetIt instance = GetIt();
  static GetIt get I => instance;
  T call<T>() => _zero as T;
  T get<T>() => _zero as T;
}

final Object _zero = 0;
final GetIt getIt = GetIt.instance;
```

用例从「函数形态」改为「真实形态」，并补齐四种形态的正反例（见 implement.md 的清单）。
桩要**同时**提供 `call` 与 `get`：只有这样 `getIt<X>()` 与 `GetIt.I.get<X>()` 才都能解析。

## 5. R4：静态接线断言

新文件 `test/tool/lint_wiring_test.dart`（进 `just test`，因而在 `just verify` 内）。三组断言：

| 编号 | 断言 | 抓什么失效 |
| --- | --- | --- |
| W1 | 根 `analysis_options.yaml` 的 `plugins.app_lints.path` 解析出的目录存在，且含 `lib/main.dart` | 插件路径写错 / 包改名 / 文件搬走 → 插件根本不加载 |
| W2 | `packages/app_lints/lib/main.dart` 里 `registerWarningRule(<XxxRule>())` 的类名集合 == `rules.dart` 里具体规则类的类名集合 | 漏注册某条规则 / 注册了不存在的类 |
| W3 | `rules.dart` 里全部 `LintCode('name', …)` 的名字集合 == `cross-cutting.md` 规则表格里 `` `name` `` 的集合 | 规则改名后文档漂移；spec 表格漏写新规则 |
| W4 | locator 桩形态（`rules_test.dart`）== `lib/di/service_locator.dart` 的实际声明形态（对象 vs 函数） | 桩退回函数形态（F1 复发） |

设计要点（与仓库既有做法对齐）：

- **解析口径单一来源**：W1 读根 `analysis_options.yaml`、W3 读 `cross-cutting.md`，
  不抄第二份清单。解析不到时**显式 fail**（不静默通过），照 `parseAnalyzeRoots` 的约定。
- **失败信息点名**：每个断言都给出「哪一处对不上」的差集（`只在一侧出现的项`），
  照 `analyze_coverage_test.dart` 的 `reason:` 风格。
- W2 的「具体规则类」= `class <Name> extends _ImportRule|AnalysisRule`，排除以下划线开头的抽象基类。
- W4 用形态标签比对（`object` / `function`），两侧都从文本抽取：生产侧抽
  `lib/di/service_locator.dart` 的 `getIt` 声明，测试侧抽 `rules_test.dart` 的 locator 桩。
- 不给 `cross-cutting.md` 表格加第二份规则清单 —— W3 读的就是那张表。

### 已知边界（写进 spec）

W1–W4 覆盖「接线断掉」与「判定退化」，**不覆盖**「`dart analyze` 真的把诊断输出出来」这一层
（插件 API 语义变化、`registerWarningRule` 行为变化）。这一层只能靠活体探针（真跑
`dart analyze`）兜，实测成本 +13s，本任务有意不采用 —— 理由与残留风险记在 research 第 5 节，
并由 PRD 的 Notes 明确接受。

## 6. R5：生成物口径守卫

新文件 `test/tool/generated_paths_consistency_test.dart`。

**真源是根 `.gitignore`**（它决定哪些文件不入库，也间接决定门禁的扫描面）：

1. 从 `.gitignore` 抽「生成物段落」的模式行 —— 段落由注释头 `# 代码生成物：不入库…` 界定，
   到下一个 `#` 开头的注释行为止。解析不到模式行 → 显式 fail。
2. 把每条模式归一化成「单谓词」形式（与两处 Dart 实现的写法同构）：
   `*.g.dart` → `endsWith('.g.dart')`；`**/gen/` → `contains('/gen/')`；
   `*app_localizations*` → `contains('app_localizations')`。
3. 从两个 Dart 实现里抽取谓词项（`path.endsWith('…')` / `path.contains('…')`），
   得到两个集合。
4. 三个集合互相相等，差集点名（`只在 .gitignore 出现` / `只在 plugin 实现出现` / …）。

取舍：不引入第三份长期维护的样例表（那只是又一个副本，抓不到漂移）；只用**转换规则**
（三条形态，写在测试里）把 `.gitignore` 翻成谓词集合。将来某处实现改成更复杂的判定时，
这条断言会先红 —— 那正是想要的信号，代价是当时要同步改归一化规则。

## 7. 风险与回滚

| 风险 | 应对 |
| --- | --- |
| 插件判据变严后，仓库现有代码出现新违规 | 先跑 `just analyze`：当前 `logic/` 里无 `getIt`、4 个取 ViewModel 的页面三件套齐全（`ADR-0001` 记录），预期 0 新增 |
| 改 `rules.dart` 后 `packages/app_lints` 自身被 `dart analyze` 扫到（`packages` 是 analyze root） | `just analyze` 已包含该包；新增文件会让 `justfile` 的 `tool_files` 覆盖到（它按 `git ls-files` 列文件，无需改 justfile） |
| W1–W4 的文本解析与真实文件写法脱节 | 每条解析都 fail-fast（解析不到即失败），照 `parseAnalyzeRoots` 先例 |
| `.gitignore` 段落结构被改（注释头被删） | 断言显式 fail 并提示「生成物段落的注释头不见了」 |

回滚：全部改在一个提交批次里，`git revert` 即可；不涉及数据迁移与外部契约。
