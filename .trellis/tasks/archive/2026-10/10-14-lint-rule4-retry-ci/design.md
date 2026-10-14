# 设计：规则 4 AST 化 + 重试幂等 + CI 平台验证

## 改动面

| 归属 | 文件 | 改动 |
|---|---|---|
| 插件 | `packages/app_lints/lib/src/rules.dart` | 规则 4 判据改 AST + 生效范围收窄 |
| 插件 | `packages/app_lints/lib/src/paths.dart` | 新增 `isPagePath()` 纯函数 |
| 插件测试 | `packages/app_lints/test/rules_test.dart` | 规则 4 正例 / 反例（含注释反例、非页面路径不报） |
| 网络 | `lib/core/data/network/retry_policy.dart`（新） | `retryableStatuses` + `shouldRetryRequest()` 纯函数 |
| 网络 | `lib/core/data/network/dio_factory.dart` | `RetryInterceptor` 接 `retryEvaluator` |
| 网络测试 | `test/core/data/network/retry_policy_test.dart`（新）、`dio_factory_test.dart` | 纯函数判据表 + 一条集成断言 |
| CI | `.github/workflows/ci.yml` | 新增 `build-apk` job |
| 依赖 | `.github/dependabot.yml` | 新增 `packages/app_lints` 一段 |
| 元数据 | `skills-lock.json`、`test/tool/skills_lock_consistency_test.dart`（新） | 修悬挂 `skillPath` + 防再漂断言 |
| 文档 | `.trellis/spec/data/network-guidelines.md`、`.trellis/spec/cross-cutting.md`、`README.md` | 口径同步 |

## R1 规则 4：AST 判据 + 收窄

### 判据（替代 `content.contains` / 正则）

1. **收集**：保留现有 `_ContainerLookupCollector`（按 `*ViewModel` 类型记首次出现的那次取容器调用）。
2. **判定**：对每个类型 `T`，在**同一个 CompilationUnit 的 AST** 上判三件事 ——
   - **字段**：存在 `FieldDeclaration`，其类型为 `NamedType(name == T)` 且 `NamedType.question != null`（即 `T?`），变量名 `viewModel`，且是 `final`；
   - **构造参数**：任一 `ConstructorDeclaration` 的形参含 `FieldFormalParameter` 且名 == `viewModel`（即 `this.viewModel`）；
   - **兜底**：`visitBinaryExpression` 判 `operator.lexeme == '??'`，左操作数为标识符 `viewModel`、右操作数是「取容器且泛型实参 == T」的调用。
     **判据必须留在 V1 视图**：V1 把 `??` 表示成 `BinaryExpression`，而 V2 的 `IfNull` 在 v1 遍历里不存在、且 V2 换掉了整套表达式节点（没有 `FunctionExpressionInvocation`），迁到 V2 会让「取容器」整片看不见。
3. **复用而非另造**：右侧的「什么算取容器」继续用既有 `_isLocatorLookup` / `_isLocatorImplicitCall`（规则 3 已在用），不要出现第二套 locator 判据 —— 否则两种写法会在两条规则间漂移。
4. **诊断不变**：位置仍是那次取容器的节点，文案仍是「取 {0} 的页面必须给可选注入点（ADR-0001），缺 {1}」。

### 生效范围（收窄到页面路径）

- `paths.dart` 新增 `bool isPagePath(String path)`：`layerOf(path) == 'page'`（覆盖 `features/*/page/`）或 `path.startsWith('lib/app/pages/')`（覆盖全局页面，`directory-structure.md:19`）。
- 规则里 `if (_isFeatureLogic(fromPath)) return;` → `if (!isPagePath(fromPath)) return;`；生成物豁免与「非 lib 目录直接返回」不变。
- 依据见 `prd.md` R1；收窄只影响 `core/`、`features/*/data/` 这类误报面，现仓 4 个取 ViewModel 的文件全在 `features/*/page/`。

### 兼容性与回滚

- 4 个现有页面（`article_detail_page`、`article_list_page`、`login_page`、`storage_demo_page`）必须继续**零诊断** —— 它们是这次改判据的回归基线。
- 纯代码改动，回滚 = revert 该 commit；无数据 / 迁移。

## R2 / R3 重试：判据抽成纯函数

### 形状

新文件 `lib/core/data/network/retry_policy.dart`：

- `const Set<int> retryableStatuses = {408, 429, 500, 502, 503, 504};`
  —— 必须自带清单：`dio_smart_retry` 的 `retryEvaluator` 与 `retryableExtraStatuses` **互斥**（同传抛 `ArgumentError`），只传 evaluator 会让 5xx 重试静默消失。
- `bool shouldRetryRequest(DioException error, int attempt)`

### 判据顺序（照库语义，只加一道方法闸门）

1. `error.requestOptions.method` 非 `GET` / `HEAD` → `false`
2. `badResponse` → `retryableStatuses.contains(statusCode)`；`statusCode == null` 时保持库的 `true`（不擅自收紧）
3. 其它 → `type != DioExceptionType.cancel && error.error is! FormatException`

`dio_factory.dart`：`RetryInterceptor(dio: dio, retries: config.retries, retryEvaluator: shouldRetryRequest)`。

### 取舍

写请求超时只发一次 —— 用一点成功率换「不重发副作用」。`retries` 的语义（GET/HEAD 最大重试次数）不变，`NetworkConfig.retries` 不动。

### 测试

- 纯函数 9 条：GET×{超时, 408, 429, 500, 502, 401, cancel} + POST×{超时, 500}（后两条必须 `false`）。
- 集成 1~2 条：`ScriptedHttpAdapter` 造超时，断言 POST 只发 1 次、GET 发 1 + retries 次（复用现有 `adapter.requestCount(path)`）。

## R4 ~ R7

- **R4**：README「环境与构建」加三点（Android 9+ 默认阻断 cleartext；iOS ATS 默认阻断 http;模拟器上 `localhost` 指设备自身，用 `10.0.2.2`）。只写文档，**不改** manifest / plist —— 加 debug-only 例外属于另一个决策，不在本次范围。
- **R5**：改 `skills-lock.json` 而不是改目录名 —— README 已说明 `signals-hooks` 被本地打过补丁，且目录名与其它 `signals-*` 一致（`signals-dart` / `signals-flutter` / `signals-lint` / `signals-migration-6-to-7` 均为连字符）。README 数字改为「27 个目录 / 136 个文件」+ 来源计数 `12 + 10 + 5`。
  - 附带新增 `test/tool/skills_lock_consistency_test.dart`：读 lock 的每个 `skillPath`，断言其在磁盘存在（纯测试、不新增 recipe，做法同 `self_package_prefix_test.dart`）。这是**一条新断言**，需在 `cross-cutting.md` 的测试清单里提一句。
- **R6**：`dependabot.yml` 加 `packages/app_lints` 的 pub 段（`/` 那段保留）。
- **R7**：`ci.yml` 新增 `build-apk`（`needs: analyze`）：checkout → flutter-action(3.47.5) → setup-just → `just deps` → `flutter build apk --debug`。action 版本对齐 master 现状（`checkout@v7`、`setup-just@v4`），**不抄** S 的 `@v4` / `@v3`。

## 运营与回滚

| 风险 | 处置 |
|---|---|
| CI 新增 job 首次变红（JDK / SDK 差异） | 先本地跑通 `flutter build apk --debug` 再提交；job 内不设 `continue-on-error`（不设半道门禁） |
| CI 时长 +3~5 分钟 | 认可（PRD R7 已定：方案 b）；若日后反悔，回滚 = 删 job 并把取舍登记进 `cross-cutting.md「有意不设的项」` |
| 规则 4 收窄后放过真实违规 | 真实违规面（`core/` / `data/` 取 ViewModel）目前不存在；若将来出现，属于「按 spec 另立规则」而不是放宽这条 |
| 重试收窄导致写请求失败率上升 | 只影响 2 处现有写请求；`spec` 与 README 写清，`release-checklist` 可加一句幂等键提醒 |
