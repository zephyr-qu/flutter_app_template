# research: 插件门禁的真实接线与失效形态

> 规划期（Phase 1.2）的一次性实验记录。用于 `design.md` 的结论支撑，不属于 spec。
> 所有实验都在真实仓库上跑，探针文件用完即删（`git status` 已确认干净）。

## 1. 结论速览

| 编号 | 结论 | 证据 |
| --- | --- | --- |
| F1 | `no_service_locator_in_logic`（规则 3）与 `page_must_expose_view_model_injection_point`（规则 4）对**仓库自己的写法**完全不生效 | 见 2.1 |
| F2 | 根因不是「合成节点无法 report」，而是**节点类型不同**：`getIt<X>()` 是 `FunctionExpressionInvocation`，不是 `MethodInvocation`，而两条规则只订阅了 `addMethodInvocation` | 见 3 |
| F3 | `isGeneratedPath` 有两份 Dart 实现 + `.gitignore` 一处口径，三者无同步守卫（`selfPackagePrefix` 有） | 见 4 |
| F4 | 活体探针（真跑 `dart analyze`）技术上可行，成本 +13s；本任务**不采用**，理由与残留风险见 5 | 见 5 |

## 2. 失效证据

### 2.1 四种 `getIt` 形态的实测（探针写在 `lib/` 下，`dart analyze --fatal-infos <文件>`）

| 探针位置与写法 | 规则 3 是否报 | 说明 |
| --- | --- | --- |
| `lib/features/x/logic/a.dart` → `getIt<Object>()` | ❌ 不报 | **仓库真实形态**（`final GetIt getIt = GetIt.instance;`） |
| `lib/features/x/logic/b.dart` → `GetIt.I.get<Object>()` | ✅ 报 | 仓库从不使用这种写法 |
| `lib/features/x/logic/c.dart` → 顶层函数 `T getIt<T>()` | ✅ 报 | 仓库里**不存在**这种形态（只有 `rules_test.dart` 的桩这么写） |
| `lib/features/x/page/q.dart` → `getIt<ArticleViewModel>()` | ❌ 规则 4 不报 | 缺三件套也照样放行 |

同时确认：这些探针文件在场时 `just analyze` 的退出码是 **2**（有 warning），即探针确实被真门禁扫描到，不是环境问题。

### 2.2 为什么 `rules_test.dart` 全绿

`packages/app_lints/test/rules_test.dart` 的 `_locatorStub` 把 `getIt` 声明成**顶层函数**：

```dart
T getIt<T>() => _zero as T;
```

而生产代码 `lib/di/service_locator.dart` 是 `final GetIt getIt = GetIt.instance;`（对象，靠 `GetIt.call` 调用）。
`rules.dart` 里那句注释「本项目里它是顶层函数，不是可调用对象」与生产代码相反 —— 桩测的是一个仓库里不存在的形态。

## 3. `getIt<X>()` 的解析后 AST（spike 实测）

用 `analyzer_testing` 的 `AnalysisRuleTest` + 一个只做 AST dump 的临时规则，桩为生产形态（对象 + `call` / `get`）：

```
a: getIt<Object>()          → FunctionExpressionInvocation
                              function=SimpleIdentifierImpl(src=getIt) typeArgs=<Object>
                              offset=219 length=15
                              SimpleIdentifier: getIt synthetic=false offset=219
b: GetIt.I.get<Object>()    → MethodInvocation
                              target=PrefixedIdentifierImpl(GetIt.I) methodName=get typeArgs=<Object>
c: GetIt.I<Object>()        → FunctionExpressionInvocation function=PropertyAccessImpl(src=GetIt.I)
d: GetIt.instance<Object>() → FunctionExpressionInvocation function=PropertyAccessImpl(src=GetIt.instance)
```

要点：

- **对象上的隐式 `call` 调用解析为 `FunctionExpressionInvocation`**（`function` 是那个对象表达式，这里是 `SimpleIdentifier(getIt)`），不是 `MethodInvocation`。
- `node.function` 与整个调用节点**都不是合成节点**（`getIt` 的 `offset=219` 是真实源码偏移），所以「report 不上报」不是问题；问题只在于规则没订阅这个节点类型。
- `typeArguments` 在 `FunctionExpressionInvocation` 上同样可读（`<Object>`），规则 4 取 `*ViewModel` 类型名的逻辑可以复用。
- 订阅点存在：`analyzer-14.4.0/lib/analysis_rule/rule_visitor_registry.g.dart` 有
  `void addFunctionExpressionInvocation(AbstractAnalysisRule rule, AstVisitor visitor)`。
- 因此现有 `_isServiceLocatorLookup` 里的 `_isNamed(node.target, 'getIt')` 分支对形态 a 是**死代码**：`visitMethodInvocation` 永远不会拿到它。

## 4. 生成物口径的重复实现

同一个判定存在于三处，且互相没有断言：

| 位置 | 形态 |
| --- | --- |
| 根 `.gitignore` | `*.g.dart` / `*.freezed.dart` / `*.gr.dart` / `*.config.dart` / `*.gen.dart` / `**/gen/` / `*app_localizations*` |
| `tool/generated_paths.dart` → `isGeneratedPath()` | Dart 实现（门禁文件列表用） |
| `packages/app_lints/lib/src/paths.dart` → `isGeneratedPath()` | Dart 实现（插件豁免用） |

`selfPackagePrefix` 有守卫（`test/tool/self_package_prefix_test.dart` 比对 `pubspec.name`），
生成物口径没有 —— 改 `.gitignore` 而漏改插件那份时，规则照旧全绿。

## 5. 活体探针的可行性（本任务不采用，留档）

已实测可行：

- 探针必须落在规则判定所依赖的路径下（`lib/core/`、`lib/features/*/logic/`、`lib/features/*/page/`），
  因为规则先过 `context.isInLibDir` 再按仓库相对路径判断。
- 一次 `dart analyze --fatal-infos <N 个文件>` 能同时报出多条，不必每个规则一次进程。
- 成本：热态单次 `dart analyze` ≈ **13s**（冷态 36s）；`just analyze`（123 文件）本身 24s。
- 探针是「未跟踪且未被 gitignore」的文件，会被 `tool/list_dart_files.dart` 收进扫描面 ——
  残留文件会让下一次 `just analyze` **变红报错**（响，不静默），而不是被悄悄忽略。

代价与风险决定了本任务不采用它：需要把临时文件写进 `lib/`（崩溃时会残留）、
以及在测试里 spawn `dart analyze`（`packages/app_lints` 的测试环境与根工程的分析上下文不同）。

### 5.1 一次未复现的异常

实验过程中见过一次 `just analyze` 退出码 **4**（analysis server 抛异常，栈里有
`LegacyAnalysisServer.handleRequest`）。当时有另一个 `dart analyze` 进程并发在跑。
随后用同样的文件集重跑两次均为退出码 2；3 路并发跑小文件集 3 次也全部为 0。
按**偶发**记录，不作为结论；但它是一条实测线索：同仓库并发跑两个 `dart analyze` 出现过一次异常。
