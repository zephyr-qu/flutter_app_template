# 门禁自证：修插件 3/4 号规则 + 接线断言 + 口径守卫

## Goal

让「架构边界由退出码兜住」这句话在**实测**下成立。

现状：`just verify` 全绿，但七条插件规则里有两条（`no_service_locator_in_logic`、
`page_must_expose_view_model_injection_point`）对仓库自己的写法完全不生效，
而 `cross-cutting.md` 与 `ADR-0001` 都宣称它们「已门禁」。同时「插件被正确加载」
与「生成物口径三处一致」这两件事没有任何断言兜着。

本任务把这三件事一次补齐：修规则 → 让判定与真实形态一致；加静态接线断言 →
让接线断掉时门禁变红而不是空转；加口径守卫 → 让重复实现不再能静默漂移。

## Requirements

### R1 修规则 3：`no_service_locator_in_logic`

- 在 `features/*/logic/` 里，下列**全部**形态都必须被报出：
  1. `getIt<X>()` —— 对象上的隐式 `call`（仓库真实写法，当前失效）
  2. `GetIt.I<X>()`（当前失效）
  3. `GetIt.instance<X>()`（当前失效）
  4. `GetIt.I.get<X>()`（当前生效，不能改坏）
  5. 顶层函数 `T getIt<T>()` 形态（当前生效，不能改坏）
- 判定不得依赖「`getIt` 是函数」这一前提 —— 生产代码里它是 `final GetIt getIt = GetIt.instance;`。

### R2 修规则 4：`page_must_expose_view_model_injection_point`

- 页面里 `getIt<XxxViewModel>()`（隐式 `call` 形态）必须能触发三件套检查，缺任一项即报。
- 仍然只认以 `ViewModel` 结尾的显式类型实参；`getIt<AuthStorage>()` 这类不归它管（口径不变）。

### R3 插件的单测必须镜像生产形态

- `packages/app_lints/test/rules_test.dart` 的 locator 桩改成生产形态：
  `getIt` 是**对象**（带 `call` / `get`），不是顶层函数。
- 正反例都覆盖：真实形态在 `logic/` 里报、在 `page/` 里触发三件套、在非 logic 位置不报。
- 桩退回「函数形态」时要有断言拦下（否则规则会再次对生产代码失效而测试全绿）。

### R4 静态接线断言（不 spawn `dart analyze`）

在 `just verify` 里加一条断言，覆盖三类静默失效：

1. 根 `analysis_options.yaml` 的 `plugins.app_lints.path` 指向真实存在的包，且含 `lib/main.dart`；
2. 插件注册的规则集合 == `rules.dart` 里声明的 `LintCode` 集合 == `cross-cutting.md` 表格里的规则清单；
3. R3 的桩形态与 `lib/di/service_locator.dart` 的实际声明一致。

失败信息必须点名「哪一处对不上」，不是一句 `expect` 失败。

### R5 生成物口径三处一致

- 加断言：根 `.gitignore` 的生成物模式、`tool/generated_paths.dart`、
  `packages/app_lints/lib/src/paths.dart` 三者的判定一致。
- 比对方式要能在**任一**处漂移时报出具体差异（哪个模式、哪一处漏了）。

### R6 约束

- 不新增 recipe、不新增 `tool/` 脚本；新增的只有测试文件（与 10-12 那条「纯测试，无新工具」同一口径）。
- 不改 `just verify` 的清单顺序，不引入 `dart analyze` 的第二次调用。
- 生产代码行为不变：不从 `logic/` 或页面里移除 `getIt`，只是让规则认得它。

## Acceptance Criteria

- [ ] AC1 `getIt<Object>()` / `GetIt.I<Object>()` / `GetIt.instance<Object>()` / `GetIt.I.get<Object>()`
      四种形态在 `features/*/logic/` 里**都**被 `no_service_locator_in_logic` 报出（单测覆盖）
- [ ] AC2 `getIt<XxxViewModel>()` 在页面里缺三件套时被 `page_must_expose_view_model_injection_point` 报出，
      三件套齐全时不报（单测覆盖）
- [ ] AC3 `packages/app_lints` 的 locator 桩是生产形态；把桩改回函数形态时门禁变红
- [ ] AC4 接线断言：把 `registerWarningRule` 注释掉一条 / 把 `plugins.path` 改错 /
      改一下 `cross-cutting.md` 表格，三者各自都能让门禁变红（手工验证一次，见 implement.md）
- [ ] AC5 口径守卫：单独改一处（只改 `.gitignore`，或只改任一份 Dart 实现）能被报出具体差异
- [ ] AC6 `just verify` 全绿；`just analyze` 的扫描面与调用形式未变
- [ ] AC7 `.trellis/spec/cross-cutting.md` 已同步：新断言的位置与语义、规则 3/4 的判定口径、
      「插件装载」这类静默失效的已知边界（含**不**采用活体探针的理由）
- [ ] AC8 `rules.dart` 里「本项目里它是顶层函数，不是可调用对象」这类与生产代码相反的注释已改正

## Notes

- 证据与 AST 形态：本目录 `research/lint-plugin-wiring-findings.md`
- 有意不做：活体探针（真跑 `dart analyze` 断言诊断端到端出现）。理由与实测成本记在 research 第 5 节，
  PRD 明确接受其残留风险：**没有自动化门禁能证明「`dart analyze` 真的会把诊断打出来」**，
  由 R3 + R4 间接覆盖「判定退化」与「接线断掉」，由 R1/R2 覆盖「规则本身失效」。
- 有意不做：覆盖率门禁、`dart pub outdated` 硬门禁 —— 与本任务无关，口径见 `cross-cutting.md`「有意不设的项」。
