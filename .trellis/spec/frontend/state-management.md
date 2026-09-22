# State Management

> How state is managed in this project.

---

## Overview

Uses **`signals_flutter`** for reactive state. Signals provide fine-grained reactivity without widget tree rebuilds.

No base ViewModel class — ViewModels are plain `@injectable` classes. A standalone `runAsync` / `runAsyncVoid` helper handles the common async tri-state pattern.

**Signals are private; expose them as `ReadonlySignal` getters.** Hold the writable signal in a private field, expose a `ReadonlySignal<T>` getter, and keep every mutation inside a ViewModel method:

```dart
final _email = signal('');
ReadonlySignal<String> get email => _email;
void updateEmail(String value) => _email.value = value;
```

Cost: one line per signal. What it buys: the rule in 「常见错误」（不要在 widget 里直接 `vm.x.value = x`）stops being a convention nobody can enforce and becomes a **compile error** — without the wrapper, `flutter analyze` stays silent and only review catches it.

Three boundaries worth knowing:

- **Compile-time only.** `Signal<T>` is `with ReadonlySignal<T>`, and `Signal.readonly()` is literally `=> this`（`signals_core` 的 `src/core/signal.dart`），so `(vm.email as Signal<String>).value = 'x'` still compiles and runs. It stops the accidental write, not a determined one.
- **`computed` needs no wrapper** — it is already `with ReadonlySignal<T>` and has no setter, so `canSubmit` stays a plain public field.
- **Internal calls need the private field** — `runAsync` / `runAsyncVoid` take `Signal<AsyncState<T>>`（可写），so they receive `_user`, never `user`.

---

## State Categories

| Category | Where | Pattern |
| ---------- | ------- | --------- |
| **Async Data** (API results) | `logic/` ViewModels | `asyncSignal<T>(AsyncState.data([]))` |
| **Sync Data** (form inputs) | `logic/` ViewModels | `signal<T>(initialValue)` |
| **Derived State** | ViewModel getters/computed | `computed(() => ...)` or `bool get canSubmit => ...` |
| **Global Config** (theme, auth) | `core/theme/` `core/config/` `core/data/storage/` | signal + SharedPreferences |
| **UI-Only State** (animation, scroll) | Local widget state | `setState()` or local `ValueNotifier` |

---

## Pattern: ViewModel + Signals

```dart
@injectable
class ArticleViewModel {
  final ArticleRepository _repo;

  ArticleViewModel(this._repo);

  // 私有可变；name 是 v7 的调试标签
  final _articles = asyncSignal<List<Article>>(
    AsyncState.data([]),
    options: AsyncSignalOptions<List<Article>>(
      name: 'articleViewModel.articles',
    ),
  );
  final _selectedArticle = asyncSignal<Article?>(AsyncState.data(null));

  // 对外只读（computed 不用包，它天生没有 setter）
  ReadonlySignal<AsyncState<List<Article>>> get articles => _articles;
  ReadonlySignal<AsyncState<Article?>> get selectedArticle => _selectedArticle;

  // 写入只能在类内部：runAsync 要求可写的 Signal<AsyncState<T>>，所以传私有字段
  Future<Result<void, Failure>> loadArticles() =>
      runAsync(_articles, () => _repo.getArticles());
}
```

### 两条写法约定

**1. 一次改多个信号用 `batch()`。** `batch` 是**同步**事务：先把 `await` 全部做完，
再进 batch（跨 `await` 的 batch 无效）。

```dart
// ❌ 三次写入 = 三次通知 = 页面（订阅了这三个信号）重建三趟
savedContent.value = await _files.readString(name);
usageKb.value = await _files.getUsage();
cachedCount.value = (await _dao.getCachedArticles()).length;

// ✅ 先 await，再一次性提交
final String? content = await _files.readString(name);
final int usage = await _files.getUsage();
final int count = (await _dao.getCachedArticles()).length;
batch(() {
  savedContent.value = content;
  usageKb.value = usage;
  cachedCount.value = count;
});
```

`runAsync` / `runAsyncVoid` 只操作**一个** signal，不存在「多个信号要一起提交」的问题，
所以不需要包 `batch`。但要说清楚：它们一次调用会写**两次** signal —— 进 `loading` /
`dataRefreshing` 一次，收尾写 `data` / `error` 一次。两次都是有意义的状态迁移，不要
试图合并成一次。

**2. 旧的读值用 `peek()`。** `runAsync` 启动时要读「上一次的值」来判定是首屏 loading
还是刷新（`lib/core/base/run_async.dart`），那里用的是 `signal.peek().value`：
命令式读取不该建立订阅关系，否则从 `SignalBuilder` 的 builder 或 `computed` 里发起
加载时会把 signal 挂成调用方的依赖，形成自触发循环。**不要把它改回 `.value`。**

`signal` / `computed` / `asyncSignal` 分别用 `SignalOptions` / `ComputedOptions` /
`AsyncSignalOptions`，且**必须写全类型参数**（`analysis_options.yaml` 开了
`strict-inference`，省略类型参数会推断失败）。

### 为什么没有 BaseViewModel

早期版本有 `BaseViewModel`，后来发现：

- ViewModel 之间共享的行为只有 `runAsync` 这一个模式
- 一个顶层函数比一个抽象类更简单，而且不影响 ViewModel 的构造方式
- **不需要 dispose 机制**：ViewModel 由 `@injectable` 注册为 `factory`，每次 `getIt<VM>()` 返回一个新实例（配合页面 `useMemoized` 即为每页一个）。它的 signal 只被当前页面的 widget 订阅，页面销毁后没有监听者——此时 `runAsync` 再写入一次 signal 只是无意义的赋值，不会崩溃，实例也会被 GC 回收。因此 `runAsync` 不提供 `disposed` 守卫。

### 什么时候才需要 dispose（上一条的边界）

「不需要 dispose」的前提是 **ViewModel 的信号只与它自己的信号建立订阅关系**——这样它们形成一个无外部引用的「孤岛」，可被 GC 整体回收。前提一旦打破就会真的泄漏：

```dart
// ❌ VM 里订阅了长生命周期的全局信号
final items = computed(() => globalCacheSignal.value);
```

`computed` 会把自己挂上 `globalCacheSignal` 的订阅链（**强引用**）。而 `Computed.dispose()` 只做标记、**不遍历 `sources` 退订**（只有 `Effect.dispose()` 会做这件事），所以即使页面和 ViewModel 都被丢弃，这个 computed 仍被全局信号钉住，ViewModel 跟着无法回收。

任何「VM 订阅全局 signal」的写法都适用：`core/data/storage/` 里的信号、`UserPreferences` 的信号、以及将来新增的全局缓存信号。

**解法**是给这类 computed 加 `autoDispose`（没有订阅者时自动释放），**不是**给所有 ViewModel 加 `dispose()`：

```dart
final items = computed(
  () => globalCacheSignal.value,
  options: const ComputedOptions(autoDispose: true),
);
```

**不要「顺手」补 `vm.dispose()`**。`Signal.set` 在 disposed 之后是直接抛异常的（`signals_core` 的 `Signal.set`）：

```dart
if (disposed) {
  throw SignalsWriteAfterDisposeError(this);
}
```

页面在请求飞行中被 pop 时，若 `useEffect` 的 cleanup 调了 `vm.dispose()`，随后返回的网络响应会在 `runAsync` 里写 signal 并当场抛错。要避开它就得给 `runAsync` 加 `disposed` 守卫——而那正是本节选择不做的。

另外，**`leak_tracker` 看不见 signals**：`Signal` / `AsyncSignal` / `Computed` 是纯 Dart 对象，不上报 `FlutterMemoryAllocations`（`signals_core` / `signals_flutter` 里没有任何集成），它追踪的是 `State` / `Element` / `ChangeNotifier` 这类 Flutter 对象。所以「测试里 `leak_tracker` 没报警」**不等于**「信号没有泄漏」。

#### 边界规则：什么时候必须加 `autoDispose`

**规则**：这个 `computed`（或 `effect`）读到的每一个信号，生命周期**都不长于它自己**时才不加
`autoDispose`。只要有一个来自长生命周期对象——`@Singleton` 的 `AuthStorage` /
`UserPreferences`、将来新增的全局缓存信号——就**必须**加：

```dart
// 只要读了全局信号，就带上 autoDispose（注意 strict-inference 要写全类型参数）
final items = computed(
  () => globalCacheSignal.value,
  options: const ComputedOptions<List<Item>>(autoDispose: true),
);
```

新增 `computed` / `effect` 时按这个清单过一遍：

1. 列出它读到的**所有**信号（含通过方法间接读到的）
2. 逐个问：**谁持有这个信号**？是本 ViewModel 自己，还是某个 `@Singleton`？
3. 出现后者 → 加 `autoDispose: true`；一个都没有 → 保持不加
4. **不要**改用 `vm.dispose()` 兜底（理由见上：飞行中的请求仍会回写 signal，而
   `Signal.set` 在 disposed 之后抛异常）

**现状核对**（写这份 spec 时全项目只有两处 `computed`，都不越界；查当前全量：
`grep -rn "computed(" lib/`）：

| computed | 读到的信号 | 归属 | 结论 |
| --- | --- | --- | --- |
| `AuthStorage.isLoggedInSignal` | `currentUser` | 同一个单例自己 | 安全：持有者本就活到进程结束，不存在「谁被谁钉住」 |
| `AuthViewModel.canSubmit` | `_email` / `_password` | ViewModel 自己 | 安全：孤岛，随页面一起被 GC |

全项目唯一的手动订阅在 `app/routing/auth_reevaluate.dart`（`isLoggedIn.subscribe(...)`），
它在 `dispose()` 里显式调了 `_unsubscribe()`——这正是同一类边界的正确写法：**主动订阅就要
主动退订**（`effect` 的 teardown 语义），不能指望 `Computed.dispose()` 替你遍历 `sources`。

⚠️ 这条边界**没有代码约束**，只能靠人过清单：`computed(() => globalSignals.value)` 能正常
编译、`flutter analyze` 也不会报，`leak_tracker` 又看不见（见上一段）。想变成机械检查，
需要 `signals_lint` 之类的自定义规则——本项目**尚未接入**。

---

## runAsync 使用

```dart
// 旧：每个 ViewModel 手写 7 行样板
_articles.value = AsyncState.loading();
final result = await repo.getArticles();
result.when(
  success: (d) => _articles.value = AsyncState.data(d),
  failure: (f) => _articles.value = AsyncState.error(f),
);

// 新：一行
await runAsync(_articles, () => repo.getArticles());
```

### ViewModel 方法的返回约定

**所有异步方法统一返回 `Result<void, Failure>`**，直接 `return runAsync(...)`：

```dart
Future<Result<void, Failure>> loadArticles() =>
    runAsync(_articles, () => _repo.getArticles());

Future<Result<void, Failure>> loadDetail(int id) =>
    runAsync(_selectedArticle, () => _repo.getArticle(id));
```

- 调用方不需要返回值时忽略即可；需要分支处理时（如登录成功后跳转）直接 `when(...)`，见 `AuthViewModel`
- **不要**丢掉 `runAsync` 的返回值再用 `signal.value.hasError` 反推失败：那会把原始 `Failure` 换成 `Failure.unknown`，错误码就丢了

### 任务只报成败：`runAsyncVoid`

任务的 `Result` 里没有值（`Result<void, _>`，例如登出）时用 `runAsyncVoid`，把「成功
时信号该是什么值」显式写出来：

```dart
Future<Result<void, Failure>> logout() =>
    runAsyncVoid(_user, _repo.logout, onSuccess: null);
```

**不要把 `void` 任务直接交给 `runAsync`。** `T` 同时被「信号」和「任务结果」约束，而
`void` 是所有类型的父类型：`LUB(T信号, void) = void`，于是 `AsyncState<void>` 在运行时
等于 `AsyncState<dynamic>`，写进 `Signal<AsyncState<User?>>` 会当场抛 `TypeError`。
给出 `onSuccess` 之后 `T` 只由信号与非 `void` 的值决定，推断是安全的。

这条不是理论推演——`test/core/base/run_async_test.dart` 里有一条对照测试把这个
`TypeError` 钉住了。若哪天 Dart 的推断不再这样解，那条测试会失败，届时可以删掉
`runAsyncVoid`，而不是以为代码坏了。

### 并发：最后一次胜出

`runAsync` 内部按 signal 记录调用序号，**同一个 signal 上后发起的调用会作废先前仍在飞行中的调用**——后者照常返回自己 task 的 `Result`，但不再回写 signal。

```dart
// 首屏（慢）+ 下拉刷新（快）同时触发：刷新的结果胜出，首屏的旧响应后到时被丢弃
vm.loadArticles();   // 旧
vm.loadArticles();   // 新 —— 只有它写 signal
```

因此**不需要**在每个 ViewModel 里手写 request token 或取消逻辑，也不会出现「旧响应覆盖新状态」。两点要知道：

- 序号**按 signal 隔离**，两个不同 signal 上的并发互不影响（`ArticleViewModel` 的 `loadArticles` / `loadDetail` 就是各记各的）
- 被取代的调用返回的是它自己 task 的真实结果，**不代表状态已被更新**。需要分支处理的方法（如登录成功后跳转）不能假设「返回成功 = 这次成功了」

### 刷新时保留旧数据

`runAsync` **已有数据时不回到 loading**，而是置成 `AsyncState.dataRefreshing(旧数据)`：

| 调用时的状态 | runAsync 置为 | 页面 `map` 走哪个分支 |
| --- | --- | --- |
| 无数据（首次加载 / 出错后重试） | `loading` | `loading`（整屏 spinner） |
| 已有数据（下拉刷新 / 重新拉取） | `dataRefreshing` | **`data`**（继续渲染旧数据） |

这是 `signals` 自带的类型（`AsyncDataRefreshing` 的 `hasValue` 为 true），所以**页面不需要任何改动**：下拉刷新时列表留在屏幕上，`RefreshIndicator` 自己转圈；只有首次加载和重试才显示整屏 loading。

```dart
// 想在刷新时显示别的东西（例如顶部一条细进度条），显式传 refreshing 回调即可
AsyncView<List<Article>>(
  state: async,
  loading: () => const LoadingIndicator(),
  refreshing: () => const _TopProgressBar(),   // 不传则走 data
  data: (list) => ...,
  error: (Object error, StackTrace stackTrace) => ErrorText(error: error),
)
```

注意 `AsyncDataRefreshing.isLoading` 仍为 `true`，所以「是否在进行中」照旧看 `isLoading`；`data(null)` 视同没有数据（屏幕上本来就是空的，保留它不如给个 loading）。

**页面侧有两个配套要求**（见 `features/article/page/article_list_page.dart`）：

1. **空状态也要能刷新**。`RefreshIndicator` 得存在于树里，刷新才可能被触发；空状态若直接返回 `EmptyWidget`，「列表为空 → 想刷新 → 刷不动」就是死胡同。做法是用 `CustomScrollView` + `SliverFillRemaining` 把它包成可滚动的，再套 `RefreshIndicator`。
2. **显式给 `AlwaysScrollableScrollPhysics`**。刷新依赖子级可滚动（实测换成 `NeverScrollableScrollPhysics` 后页面刷新测试全挂）；显式声明就不必赌「内容撑不满一屏时默认 physics 是否接受下拉」——这一点会随 Flutter 版本和平台变化。

### 渲染状态：用 `AsyncView`，不要用 `AsyncState.map`

**页面渲染 `AsyncState` 一律走 `core/ui/async_view.dart` 的 `AsyncView`。**

`AsyncState.map` 的 `error` 参数类型是 `Function`，它**在运行期**用 `error is Function(dynamic, dynamic)` / `is Function(dynamic)` 判断回调签名。第二个参数写成 `StackTrace?` 时**不满足 `dynamic` 的逆变要求**，两个分支都不匹配，最后落到 `error()` 零参调用 → `NoSuchMethodError`，整页变红屏：

```dart
// ❌ 编译通过，运行期崩溃
error: (Object? error, StackTrace? stackTrace) => ErrorText(...),
```

`AsyncView` 用 sealed class 的穷尽 `switch` 代替运行期分派，回调全部具名具类型：

```dart
AsyncView<List<Article>>(
  state: async,
  loading: () => const LoadingIndicator(),
  error: (Object error, StackTrace stackTrace) =>
      ErrorText(error: error, onRetry: () => vm.loadArticles()),
  data: (List<Article> list) => ...,
)
```

- 回调签名写错 → **编译期**报错，不再是运行期红屏。
- signals 将来新增 `AsyncState` 子类型 → `switch` 不再穷尽，同样编译期报错。
- `refreshing` / `reloading` 可选，缺省时退回 `data`（旧数据）/ `error`，与 `map` 行为一致；分支顺序约束（`AsyncLoading` 必须排在 `AsyncData*` 之后）已封装在 `AsyncView` 内部。

⚠️ 上述坑曾经真实存在于 `article_list_page.dart`，直到页面测试把列表打到 error 态才暴露。**新增 error 分支后，仍要写一条「进入 error 态」的页面测试**——`AsyncView` 保证的是回调签名不会在运行期崩，不保证你的分支渲染逻辑本身正确。

---

## 为什么不用 `futureSignal` / `computedAsync`

signals v7 自带声明式的异步原语，本项目**没有**用它们承载 API 请求，而是 `asyncSignal` +
`runAsync`。这是有意的取舍，不是漏掉的选项——两者能力高度重叠：

| 维度 | `futureSignal` / `computedAsync` | 本项目的 `asyncSignal` + `runAsync` |
| --- | --- | --- |
| 何时执行 | **声明式**：随回调里读到的信号变化自动重跑（`FutureSignal` 手动跟踪这些依赖） | **命令式**：由页面事件显式调用（首屏 `useEffect`、下拉刷新、点重试、按钮） |
| 刷新 / 重载 | `refresh()` → `AsyncDataRefreshing`（保留旧数据）、`reload()` → `AsyncDataReloading` | 同样两个状态，由 `runAsync` 按「有没有旧数据」自动选 |
| 竞态保护 | 自带（新执行作废旧响应） | 自带（按 signal 记调用序号，最后一次胜出） |
| 调用方拿结果 | `await signal.future`，失败走 `completeError`（异常） | 方法直接返回 `Result<void, Failure>`，失败带 `Failure` 错误码 |
| 单测 | 需要 signals 运行时在场 | `runAsync` 是纯函数，喂 `Signal` + `Future` 即可 |

三点让它不适配本项目：

1. **触发源不是信号。** 首屏加载、下拉刷新、点重试都不是「某个信号变了」。硬用
   `computedAsync` 就得先造一个「触发器信号」再手动 bump，等于把命令式意图编码成假的声明式
   依赖，比现状更绕。
2. **调用方要的是带 `Failure` 的 `Result`。** `login()` 的调用方要按成功 / 失败分支跳转或弹
   提示，失败时还需要 `Failure` 里的错误码去翻译文案（`error.localizedMessage(l10n)`）。
   `AsyncSignal` 有 `future` getter，`await signal.future` 也能拿到值，但失败那条路是
   `completer.completeError(...)`——异常承载不了 `Failure` 的错误码语义，页面侧得改成
   try/catch，等于把「错误模型」劈成两套。
3. **三态细节是项目定制的。**「已有数据时不回 loading，只置 `dataRefreshing`」和
   「`data(null)` 视同没有数据」都已经写进 `runAsync`，页面（`AsyncView` 的 refreshing 分支）
   与测试都依赖它。换成库的 `lazy` / `init` 生命周期，这两条得再包一层。

**什么时候该用它们**：当异步结果**确实是**某个信号的函数时，用声明式原语，别手写：

```dart
// ✅ 搜索建议：结果 = f(query)，且需要「后到的旧响应不能覆盖新结果」
final query = signal('');
final suggestions = computedAsync(
  () => _api.searchSuggestions(query.value),   // Future<List<Suggestion>>
  options: AsyncSignalOptions<List<Suggestion>>(
    name: 'searchViewModel.suggestions',
  ),
);

// ✅ 合并多个异步信号：任一在 loading 就整体 loading，全部成功才是 data
final dashboard = computedFrom([profileSignal, statsSignal], () => ...);
```

判据一句话：**「用户 / 事件决定何时发起」→ `asyncSignal` + `runAsync`；
「上游信号的值决定结果」→ `futureSignal` / `computedAsync`。** 两者可以共存，
但**不要叠着写**：同一个状态只用一种原语承载——两条路都能写它时，谁最后写谁说了算，
三态语义会被劈成两套。

---

## 页面 ↔ ViewModel 生命周期

页面通过 `getIt` 获取 ViewModel（`factory` 实例随页面生命周期，由 GC 回收，无需手动 dispose——只有 VM 订阅了全局信号时才需要处理，见「什么时候才需要 dispose」），**但必须留出可选注入点**给页面测试（[ADR-0001](../../../docs/adr/ADR-0001.md) 的缓解措施，`tool/check_boundaries.dart` 规则 4 会拦）：

```dart
@RoutePage()
class ArticleListPage extends HookWidget {
  /// 可选注入点——只有测试会传值
  final ArticleViewModel? viewModel;

  const ArticleListPage({super.key, this.viewModel});

  @override
  Widget build(BuildContext context) {
    final vm = useMemoized(() => viewModel ?? getIt<ArticleViewModel>());

    useEffect(() {
      vm.loadArticles();
      return null;
    }, []);
  }
}
```

---

## 常见错误

| 错误 | 正确做法 |
| --- | --- |
| 在 `build()` 中 `var vm = ArticleViewModel()` | 使用 `getIt` + `useMemoized` |
| 用 `signal` 存 API 数据 | 用 `asyncSignal`（自带 loading/error/data 三态） |
| 在 widget 里直接 `vm.articles.value = x` | **编译不过**（信号对外是 `ReadonlySignal`，没有 setter）；写入走 ViewModel 方法 |
| 派生状态存成新 signal | 用 `computed()` 或 getter |
| `computed` 读了全局 signal，却没加 `autoDispose` | 加 `options: ComputedOptions<T>(autoDispose: true)`（见「什么时候才需要 dispose」） |
| 一次改多个信号，逐条赋值 | 先把 `await` 做完，再用 `batch()` 一次提交 |
| 用 `futureSignal` 承载「点按钮才发起」的请求 | 命令式加载用 `asyncSignal` + `runAsync`（见「为什么不用 futureSignal」） |
| 任务返回 `Result<void, _>` 却用 `runAsync` | 用 `runAsyncVoid(..., onSuccess: 值)`，否则 `T` 塌成 `void` 并抛 `TypeError` |
| 跨组件共享 feature 状态 | 放到 Global State（core/） |
