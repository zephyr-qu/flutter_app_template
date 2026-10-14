# implement: 门禁自证

前置：`just deps` + `just codegen`（生成物不入库）。本任务不涉及注解，无需重跑 codegen。

约定：每一步末尾的「验证」必须**实际跑过**再勾选。涉及 `dart analyze` 的步骤不要与其他
`dart analyze` 并发（见 research 5.1 的那次未复现异常）。

---

## A. 修规则 3/4（`packages/app_lints/lib/src/rules.dart`）

- [ ] **A1 抽出接收者谓词。** 把「是不是 locator 的接收者」从 `_isServiceLocatorLookup` 里拆出来：
  `_isLocatorReceiver(Expression?)` = `_isNamed(expression, 'getIt')` ∨ 访问 `GetIt` 的单例
  （`GetIt.I` 与 `GetIt.instance` 都认）。现有 `_isGetItInstance` 只认 `I`，扩成同时认 `instance`
  （`PropertyAccess` 分支要覆盖 `GetIt.instance`）。命名随之改成表达「访问单例」的语义。
  - 验证：`cd packages/app_lints && dart analyze lib/src/rules.dart`（退出码 0）
- [ ] **A2 规则 3 加订阅点。** `ServiceLocatorInLogicRule.registerNodeProcessors` 除
  `addMethodInvocation` 外再加 `addFunctionExpressionInvocation`；新增 visitor 只做
  「文件在 `features/*/logic/` 且是 locator 隐式 call」判定后 `reportAtNode(node)`。
  路径判断复用现有 `currentPath` / `isGeneratedPath` / `_isFeatureLogic`，不另写一份。
  - 验证：单测（B2）跑通前，用 C 阶段之后的 `dart analyze` 复核
- [ ] **A3 规则 4 收集隐式 call。** `_ContainerLookupCollector` 增加
  `visitFunctionExpressionInvocation`，从 `node.typeArguments` 取类型名，复用现有
  `*ViewModel` 与 `NamedType` 口径（抽成共用的 `_viewModelTypeFrom(TypeArgumentList?)`，两处都调它）。
  - 注意：`_PageInjectionPointVisitor` 的 `content.contains(...)` 三件套检查与 `_fallbackPattern`
    正则**不改**（它们检查的是页面源码文本，与节点形态无关）
- [ ] **A4 改注释。** 删掉/改正 `rules.dart` 里与生产代码相反的说法（「本项目里它是顶层函数，
  不是可调用对象」），把记录改为现状：`getIt` 是对象，对象上的调用落成
  `FunctionExpressionInvocation`，所以两条规则都要订阅该节点。
  - 注意：`packages/app_lints` 有自己的 `analysis_options.yaml`，**不加载**根插件，
    所以「注释块 ≤10 行」不作用于该包；仍按仓库风格保持简短，超出的解释写进 spec。
  - 验证：`just analyze-tool`

---

## B. 让插件单测镜像生产形态（`packages/app_lints/test/rules_test.dart`）

- [ ] **B1 改 locator 桩。** `_locatorStub` 从顶层函数形态改为生产形态：
  `class GetIt` 提供 `static GetIt instance`、`static GetIt get I`、`T call<T>()`、`T get<T>()`，
  外加重塑 `final GetIt getIt = GetIt.instance;`。桩里**不能**出现真的 locator 取用表达式被规则误抓
  （现有注释已说明这条约束，保持）。
- [ ] **B2 补/改用例。** 规则 3 覆盖五种形态（`getIt<X>()`、`GetIt.I<X>()`、`GetIt.instance<X>()`、
  `GetIt.I.get<X>()` 报；非 logic 位置不报）；规则 4 覆盖 `getIt<XxxViewModel>()` 缺三件套报、
  齐全不报、`getIt<AuthStorage>()` 不报。
  - 验证：`just test-app-lints`（= `cd packages/app_lints && dart test`）
  - **回滚点**：此时只动插件包，`git checkout -- packages/app_lints` 即可回到现状

---

## C. 静态接线断言（新文件 `test/tool/lint_wiring_test.dart`）

- [ ] **C1 W1**：解析根 `analysis_options.yaml` 的 `plugins.app_lints.path` → 目录存在且含
  `lib/main.dart`。解析不到即 fail（不静默通过）。只解析这一段，不引入 yaml 依赖。
- [ ] **C2 W2**：`main.dart` 的 `registerWarningRule(<XxxRule>())` 类名集合 == `rules.dart` 里
  具体规则类（`class X extends AnalysisRule|_\w+`，排除下划线开头的基类）的类名集合；差集点名。
- [ ] **C3 W3**：`rules.dart` 的 `LintCode('<name>')` 名集合 == `cross-cutting.md`
  「架构边界与代码形态」那张表里以 `` | `name` | `` 形态出现的规则名集合。
- [ ] **C4 W4**：`lib/di/service_locator.dart` 里 `getIt` 的声明形态（对象 vs 函数）
  == `rules_test.dart` 的 locator 桩形态；且生产侧形态必须是「对象」。
  形态不符时的失败信息要写清「生产形态变了 → 规则判据与桩要一起改」。
- [ ] **C5 破坏式验证（每项一次，验完还原）**：
  1. 注释掉 `main.dart` 里一条 `registerWarningRule` → W2 红
  2. 把 `analysis_options.yaml` 的 `path` 改成 `packages/app_lints_x` → W1 红
  3. 在 `cross-cutting.md` 表格里改掉一个规则名 → W3 红
  4. 把桩改回顶层函数形态 → W4 红
  - 验证：`just test test/tool/lint_wiring_test.dart`
  - **回滚点**：四次破坏全部还原后 `git status` 只应留下 C1–C4 的新增内容

---

## D. 生成物口径守卫（新文件 `test/tool/generated_paths_consistency_test.dart`）

- [ ] **D1** 从根 `.gitignore` 抽生成物段落（注释头 `# 代码生成物：不入库…` 到下一个 `#` 注释行），
  把每条模式归一成 `endsWith('…')` / `contains('…')` 谓词项；解析不到 → fail 并提示注释头。
- [ ] **D2** 从 `tool/generated_paths.dart` 与 `packages/app_lints/lib/src/paths.dart` 各抽一份
  谓词项集合；三份集合互相相等，差集点名（哪一项只出现在哪一份）。
- [ ] **D3 破坏式验证（每项一次，验完还原）**：只改一份实现（例如从 plugin 那份删掉 `.gen.dart`）
  → 红且点名；只改 `.gitignore` 一行 → 红且点名。
- [ ] **D4** 补一条行为用例：对同一批样例路径，两个 `isGeneratedPath` 实现返回值一致。
  - 验证：`just test test/tool/generated_paths_consistency_test.dart`

---

## E. 收口

- [ ] **E1 真实环境复核（一次性探针，不进门禁）**：在 `lib/` 下建临时探针，跑真 `dart analyze`
  确认规则 3/4 现在**真的报**，然后**删除探针并确认 `git status` 干净**：
  ```bash
  mkdir -p lib/features/zz_probe/logic lib/features/zz_probe/page
  printf "import 'package:my_app/di/service_locator.dart';\n\nObject? a() => getIt<Object>();\n" > lib/features/zz_probe/logic/a.dart
  printf "import 'package:my_app/di/service_locator.dart';\nimport 'package:my_app/features/article/logic/article_view_model.dart';\n\nObject? b() => getIt<ArticleViewModel>();\n" > lib/features/zz_probe/page/b.dart
  dart analyze --fatal-infos lib/features/zz_probe/logic/a.dart lib/features/zz_probe/page/b.dart
  rm -rf lib/features/zz_probe && git status --porcelain
  ```
  期望：`a.dart` 报 `no_service_locator_in_logic`；`b.dart` 报
  `page_must_expose_view_model_injection_point`。**这一步是 AC1/AC2 在真实门禁通道里的复核**，
  单测只能证明规则逻辑对。
- [ ] **E2** `just analyze`（确认仓库现有代码 0 新增违规）
- [ ] **E3** `just verify` 全绿
- [ ] **E4** 更新 `.trellis/spec/cross-cutting.md`：
  - 「架构边界与代码形态」补 W1–W4 与 D1–D2 两道断言的位置与语义（照现有「防『门禁静默失效』」小节的口径）
  - 修正规则 3/4 的判定口径描述（节点形态：对象上的隐式 `call` 是 `FunctionExpressionInvocation`）
  - 「已知边界」写清：**没有自动化门禁证明 `dart analyze` 会输出诊断**，本仓库有意不采用活体探针（+约 13s），残留风险与替代方案记在任务 research
- [ ] **E5** 提交（等用户确认分组后一次提交；不 push）

---

## 验收对照

| AC | 落在哪一步 |
| --- | --- |
| AC1 / AC2 | B2（单测）+ E1（真实通道复核） |
| AC3 | B1 + C4（W4 是它的守卫） |
| AC4 | C1–C3 + C5 |
| AC5 | D1–D3 |
| AC6 | E2 + E3 |
| AC7 | E4 |
| AC8 | A4 |
