# 架构评估（Architecture Review）

> 本脚手架的架构评估、判断依据，以及每条判断在代码演进后的**最新状态**。
>
> 首次评估：2026-09-21。本文件是 [ADR-0001](adr/ADR-0001.md) / [ADR-0002](adr/ADR-0002.md) 中「关联候选」的来源。

---

## 阅读提示

> **本文是当时（一次架构评审）的快照，不是现行规范。** 其中的 `tool/check_boundaries.dart` /
> `tool/check_conventions.dart` 两个脚本**已退役**：六条规则改由 `packages/app_lints` 的分析插件
> 实现（现行口径见 `.trellis/spec/cross-cutting.md`「架构边界与代码形态」）。凡本文提到脚本的地方，
> 都当作历史记录读。

评估覆盖 `lib/` 全部代码、`tool/check_boundaries.dart`、`tool/init_project.dart`、`.trellis/spec/` 与 `test/`。

**本仓库在评估期间仍在演进**，下面每一条都带「最新状态」。引用本文件时**先看状态，不要只看原始判断**。

| 状态 | 含义 |
|------|------|
| 仍成立 | 问题当前存在 |
| 部分成立 | 原始表述过宽，需按「准确表述」理解 |
| 误报 | 判断错误，建议已撤回 |
| 已解决 | 后续代码变更已修复 |

---

## 一、已落地的结构性变更

评估期间完成的重构，它们直接改变了 P7 的结论。

### 1. 引入 `lib/app/` 应用层

| 迁移前 | 迁移后 |
|--------|--------|
| `lib/app.dart` | `lib/app/app.dart` |
| `lib/routing/{router,router.gr,auth_reevaluate}.dart` | `lib/app/routing/…` |
| `lib/core/presentation/pages/{splash,not_found}_page.dart` | `lib/app/pages/…` |

`tool/check_boundaries.dart` 的 `compositionDirs` 由 `lib/routing/` 改为 `lib/app/`，规则 1（core 不得依赖上层）的目标目录同步改为 `lib/app/`。

**收益**：全局页面（启动页 / 404）现在可以用类型安全的路由类导航，不再依赖 `'/'` 这类字符串 path。

**注意**：`lib/di/` 与 `lib/l10n/` **不能**移入 `app/`——它们分别被 `features/`（6 个页面的 `getIt`）和 `core/`（`failure_message.dart`、`error_text.dart`、`user_preferences.dart`）依赖，移进去会立刻触发反向依赖违规。

### 2. `core/presentation/` → `core/ui/`

收成扁平结构，与 `core/theme/` 并列，去掉多余的中间层：

```
lib/core/ui/
├── failure_message.dart       # FailureCode → 用户文案
├── loading_indicator.dart
├── error_text.dart
└── empty_widget.dart
```

`test/core/presentation/` 同步为 `test/core/ui/`。

### 3. `state-management.md` 补充 dispose 边界

新增「什么时候才需要 dispose（上一条的边界）」，见 P1。

---

## 二、评估条目

### P1 — ViewModel 生命周期 / 是否需要 dispose

**原始判断**：VM 注册为 `factory`、其 `asyncSignal` 从不 dispose，判为技术债；建议在 `useEffect` 的 cleanup 里调 `vm.dispose()`。

**最新状态**：**误报——建议已撤回。**

原文有两处不准确：

1. 「依赖 `leak_tracker` 兜底」不成立。`signals_core` / `signals_flutter` 中**没有任何** `FlutterMemoryAllocations` / `LeakTracking` 集成（grep 0 匹配）。`Signal` / `AsyncSignal` / `Computed` 是纯 Dart 对象，而 `leak_tracker` 追踪的是 `State` / `Element` / `ChangeNotifier` 这类 Flutter 对象。
2. 「不加 dispose 会泄漏」不成立。信号图的订阅关系确实是强引用，但 `useSignalValue` 最终走到 `SignalHookState.dispose()`，会在 widget 销毁时**正确退订**（`signals_hooks` 的 `base.dart`）。随后 VM 与其信号成为一个无外部引用的「孤岛」，可被 GC 整体回收。

反过来，**按原建议加 `vm.dispose()` 会引入 bug**：`signals_core` 的 `Signal.set` 在 disposed 之后**直接抛异常**：

```dart
if (disposed) {
  throw SignalsWriteAfterDisposeError(this);
}
```

页面在请求飞行中被 pop 时，cleanup 里的 `dispose()` 会让随后返回的网络响应在 `runAsync` 写 signal 时抛错。要避免它就得给 `runAsync` 加 `disposed` 守卫——而那正是 [ADR-0002](adr/ADR-0002.md) 明确拒绝的。

**准确表述**：ADR-0002 的「不 dispose」是自洽的有意决策，不是欠债。唯一的失效条件是 **VM 订阅了长生命周期的全局信号**——此时 `computed` 被全局信号强引用，而 `Computed.dispose()` 只做标记、**不遍历 `sources` 退订**（只有 `Effect.dispose()` 会），于是 VM 无法回收。解法是给这类 computed 加 `autoDispose`，而不是给所有 VM 加 `dispose()`。

**已文档化**：`.trellis/spec/frontend/state-management.md` 的「什么时候才需要 dispose（上一条的边界）」。

---

### P2 — `core/models/` 的准入标准

**原始判断**：`core/models/`（`user`、`token_set`）有变成「共享杂物间」的趋势，命名与 FSD 惯用的 `shared/entities` 脱节。

**最新状态**：**仍成立**（属长期治理，非缺陷）。

当前只有 2 个模型，且 `directory-structure.md` §3 已写明准入条件（被 2+ feature 共享，或 core 自身要用——`TokenSet` 属于后者，因为 `TokenRefresher` 在 core 里解析它）。风险随 feature 数量增长而上升。

可选改进：改名为 `core/entities/`，或把准入标准写得更可操作。

---

### P3 — 页面层使用 `getIt` 的可测性代价

**原始判断**：[ADR-0001](adr/ADR-0001.md) 只消除了 ViewModel 内部的 `getIt`，页面仍是 `getIt<VM>()`，导致 widget 测试必须先初始化 GetIt。

**最新状态**：**仍成立**（属有意权衡），但代价已被「可选注入点」削掉一部分，而且这条约定现在有门禁。

- 取 ViewModel 的 4 个页面（`login_page`、`article_list_page`、`article_detail_page`、`storage_demo_page`）都留了可选注入点，对应测试直接 `Page(viewModel: fake)`，不碰 GetIt。
- `tool/check_boundaries.dart` 规则 4 强制这三行（字段 / 构造参数 / `??` 兜底），新页面漏给会拦提交——**不加门禁的话，正是这部分会随时间失效**。
- 仍必须 `setUpTestApp()` 的：`test/routing/*`、`test/l10n/language_switch_test.dart`（挂的是真实 `MyApp`，绕不开容器）、`home_page_test`、`profile_page_test`（页面直接取 `AuthStorage` / `UserPreferences`，不是 ViewModel）。

脚本管不到的是「测试是否真的走注入路径」（那要扫 `test/`）：注入点在、测试仍用 `setUpTestApp()` 是允许的，只是没拿到 ADR 承诺的收益。

---

### P4 — 边界检查是正则级，不是语义级

> **已完成迁移**：本节描述的边界脚本已退役，六条规则改由 `packages/app_lints` 的分析插件（AST）实现。下面的分析保留为当时的判断依据与迁移理由。

**原始判断**：多行 `import`、`part` / `part of`、条件导入都会漏；`.config.dart` 整文件豁免也是缺口。

**最新状态**：**部分成立**——原始表述过宽，需按缺口类型区分。

| 缺口 | 是否真实 | 说明 |
|------|---------|------|
| 条件导入的 `if` 分支漏检 | **是**，已加 warning | 正则 `^\s*(import\|export)\s+['"]([^'"]+)['"]` 只取**第一个**字符串字面量，`import 'a.dart' if (dart.library.io) 'b.dart';` 的 `b.dart` 逃检 |
| 多行 `import` 漏检 | **是**，已加 warning；但逃检的不是 URI 那一行 | 原判断「实际不会发生」**不准确**：`lib/di/service_locator.config.dart:35` 就有一条被折行的 import（`as _i406` 折到下一行）。dart format 在超过 80 列时会折指令，不过只折 `as` / `show` / `if`，**不会把 URI 折到下一行**——所以 URI 所在的头一行照旧被检查，漏的是后半截 |
| 块注释里的 `import` 行误报 | 低概率但存在 | `/*` 之后独占一行且行首无 `*` 的 `import` 会被判为违规。漏报放过问题，误报挡住提交，后者更烦人 |
| `part` / `part of` 不解析 | 模型不完整，**当前不可利用** | part 文件不能有自己的 `import`，依赖只能经 library 的 `import` 表达，而后者会被检查。项目里的 `lib/core/data/database/tables/db_articles.dart`（手写 part）会因后缀不匹配而**被扫描**，但其中没有 import，扫描空转 |
| `.config.dart` 整文件豁免 | **必要** | `service_locator.config.dart` 是组合根，必须 import 每个 feature 的 VM / Repository。豁免正确，但意味着 **DI 装配不受边界规则保护** |

**当前是否需要迁移到 AST**：**不需要**（2026-09 复核：`lib/` 零条件导入、`part` 全部是生成物、5 个 feature，三条信号一条都没亮）。

**触发迁移的信号**：开始用条件导入做平台适配 / feature 数量增长到容易走歪 / 真的发生一次「漏检导致违规合入」。前两条现在由脚本**自己**发现——warning 命中就说明出现了正则读不懂的指令。

**便宜的缓解**：**已落地**。`tool/check_boundaries.dart` 对两类写法打 warning（写 stderr，**不影响退出码**，因为「工具看不懂」不等于「代码有问题」）：

1. 行以 `import` / `export` 开头却没解析出 URI（`import` 与 URI 分行）；
2. 解析出了 URI，但这一行还有没被吃下的部分——条件导入的 `if` 分支，或折行的续行。

第 1 条就是本节原先设想的写法，实测它**盖不住**条件导入：折行后 `if (...)` 独占一行、不以 `import` 开头，单行写法则第一个 URI 已经匹配成功。所以补了第 2 条（看 `directive.end` 之后还剩什么）。真实仓库中唯一命中该判定的文件是生成的 `lib/di/service_locator.config.dart`，按既有规则豁免——这也是 warning 必须让生成文件继续豁免的直接证据。回归测试 `test/tool/check_boundaries_test.dart` 把 warning 也当失败，命中即代表该按本节触发条件迁 AST。

**澄清**：迁移到 `package:analyzer` 的 `parseString` 是**用 analyzer 的解析能力写脚本**，执行模型仍是 CI 里的 `dart run`——与「analyzer 插件只在 IDE 生效」是两回事，不是退回插件。

**2026-09 追加**：这条路**已经走了一段**。新增的 `tool/check_conventions.dart` 用 `parseString` 直接建 AST——`AsyncState.map` 的判据是「同时带 `data` 与 `error` 两个具名实参」，正则分不清它和 `list.map(...)`，而误报会挡住提交；`package:analyzer` 也因此成为显式 dev_dependency。`check_boundaries.dart` **仍留在正则级**：本节的三条触发信号一条都没亮，它的规则也不需要 AST（口径见 `.trellis/spec/cross-cutting.md`「代码形态约定」）。

---

### P5 — `runAsync` 缺少请求去重 / 取消

**原始判断**：`runAsync` 不做请求去重，快速重复触发（下拉刷新 + 首屏）时旧响应可能覆盖新状态；建议加「最后一次胜出」保护。

**最新状态**：**已解决。**

`lib/core/base/run_async.dart` 现在：

- 用 `Expando<int> _latestCallId` 按 signal 记录调用序号，**被取代的调用照常返回自己的 `Result`，但不再回写 signal**
- 用 `AsyncState.dataRefreshing(previous)` 在刷新时保留旧数据，不闪整屏 loading；`data(null)` 视同没有数据
- 选 `Expando` 而非全局 Map：按对象**身份**存值，且不阻止 signal 被 GC

配套的页面侧要求（空态也要能刷新、显式 `AlwaysScrollableScrollPhysics`）见 `.trellis/spec/frontend/state-management.md`。

---

### P6 — 离线缓存命中无法区分新鲜度

**原始判断**：`ArticleService` 的 cache-aside 在回退缓存时直接返回 `Result.success(cached)`，调用方无法区分「实时数据」与「过期缓存」，UI 也就无法展示 stale 提示。

**最新状态**：**仍成立。**

注意与 `AsyncState.dataRefreshing` 区分：

| | 含义 | 层次 |
|---|---|---|
| `dataRefreshing` | 请求进行中，暂时沿用旧数据 | **网络层**的传输状态 |
| `fromCache`（缺失） | 这一份数据来自 Drift 缓存而非网络 | **数据来源**标记 |

要加的话，是在返回类型上带一个 `fromCache` 标志，与 `dataRefreshing` 正交。

---

### P7 — 全局页面的归属与字符串 path 导航

**原始判断**：`splash` / `404` 放在 `core/presentation/pages/` 是错位——它们属于 app 层职责；因为「core 不得依赖 routing」的边界规则，被迫改用 `context.router.replacePath('/')` 这类**无类型检查**的字符串。

**最新状态**：**已解决。**

见第一节的结构性变更：全局页面移入 `lib/app/pages/`，导航改为

```dart
await context.router.replaceRoute(
  isLoggedIn ? const MainRoute() : const LoginRoute(),
);
```

副作用：`splash_page.dart` 现在 import `router.dart`，与 `router.dart` 引入 `splash_page.dart` 形成**循环 import**——与 feature 页面引用 `router.dart` 是同一模式（Dart 允许，且本仓库已有先例）。

---

## 三、结论

- **骨架是稳的**：依赖方向单向、错误语义清晰（`Failure` 只带 code、文案在 UI 翻译）、认证与并发这类易错点处理到位、门禁可执行、决策可追溯。
- 本轮 7 条判断中：**1 条误报（P1）、2 条已解决（P5、P7）、1 条需修正表述（P4）**；其余 3 条（P2、P3、P6）仍成立，但都属于「长期治理」而非缺陷。
- **教训**：P1 把一个有意的设计决策（ADR-0002 不 dispose）误判成技术债，而它给出的「修复」会引入 `SignalsWriteAfterDisposeError`。评估运行时涉及框架/库的语义，**必须回到依赖源码确认**，不要凭对同类库的印象推断。

---

## 四、待办（按优先级）

| # | 事项 | 触发条件 |
|---|------|---------|
| 1 | **已完成**：把边界检查迁到 `package:analyzer` 的 AST | 已由 `packages/app_lints` 的分析插件承担（六条规则，见 `.trellis/spec/cross-cutting.md`「架构边界与代码形态」） |
| 2 | ✅ **已完成** —— 边界脚本已加「import 行没被完整解析」的 warning（`isWarning`，不拦退出码） | — |
| 3 | 给 `ArticleService` 的缓存回退结果加 `fromCache` 标记 | 需要「离线数据」的 UI 提示时 |
| 4 | 明确 `core/models/` 的准入标准（或改名 `core/entities/`） | 模型数量超过 ~5 个 |
| 5 | 让注入点真被用上：脚本只保证它「在」，管不到页面测试是否仍走 `setUpTestApp()`（要扫 `test/`） | 页面数量继续增长，或出现「注入点在、测试却没用」 |
