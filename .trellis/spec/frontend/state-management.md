# State Management

> 状态怎么管。Riverpod 3：provider 是唯一的状态载体。

---

## Overview

**Provider 同时承担状态、依赖装配与生命周期**：

| 职责 | 落点 |
|---|---|
| 状态 | `@riverpod` 的 `Notifier` / `AsyncNotifier` / 顶层函数 provider |
| 依赖 | provider 之间的 `ref.watch` |
| 生命周期 | `@Riverpod(keepAlive: true)` / 默认 `autoDispose` |

没有 `lib/di/`，页面不从容器取 ViewModel：页面是
`ConsumerWidget` / `ConsumerStatefulWidget`，用 `ref.watch` 订阅。

三个要点：

- **状态私有。** `Notifier` 的 `state` 只有类内能写（Dart 的库私有可见性），页面拿不到
  写入手段，只能 `ref.watch` 读、调方法改。
- **没有基类。** 不引入 `BaseNotifier`：异步三态由 `AsyncValue` 承载，刷新/竞态由框架
  承载，项目侧没有可收敛的样板。
- **没有 hooks。** 不依赖 `flutter_hooks`：没有 `HookWidget` / `useMemoized` /
  `useEffect`。对应写法见「Consumer 一节」。

---

## State Categories

| Category | Where | Pattern |
| ---------- | ------- | --------- |
| **Async Data** (API results) | `logic/` | `@riverpod class XxxNotifier extends _$XxxNotifier` 且 `Future<T> build()` |
| **Sync Data** (form inputs) | `logic/` | `@riverpod class XxxNotifier` 且同步 `build()` 返回**不可变快照** |
| **Derived State** | 快照的 `bool get canSubmit => ...`，或 provider 里 `ref.watch` 组合 | 不另存一份状态 |
| **无状态服务 / 依赖装配** | `data/*_providers.dart`、`core/providers.dart` | `@Riverpod(keepAlive: true)` 顶层函数 |
| **Global Config** (theme) | `core/config/` | `keepAlive` Notifier / 顶层 provider |
| **UI-Only State** (animation, scroll) | 页面局部 | `setState()`（`ConsumerStatefulWidget`） |

---

## 三种 Provider 形态

三个形态各有一个金标准文件，新增代码照抄它们（`features/sample/` 是「AI 唯一照抄对象」）。

### 1. 顶层函数 provider —— 无状态服务与装配

```dart
// lib/features/sample/data/sample_providers.dart
@Riverpod(keepAlive: true)
SampleApi sampleApi(Ref ref) => SampleApi(ref.watch(dioProvider));

@Riverpod(keepAlive: true)
SampleRepository sampleRepository(Ref ref) =>
    SampleService(ref.watch(sampleApiProvider), ref.watch(sampleDaoProvider));
```

无状态服务**都带 `keepAlive`**：让它们随页面生灭只会把实例化成本挪到每次 `ref.read`，
换不来任何隔离收益。需要换实现（真实后端 / 测试假件）一律走 `ProviderScope(overrides:)`。

### 2. 同步 Notifier —— 内存快照 + 落盘

```dart
// lib/core/config/app_settings.dart
@Riverpod(keepAlive: true)
class AppSettingsNotifier extends _$AppSettingsNotifier {
  @override
  AppSettings build() {
    final prefs = ref.watch(userPreferencesProvider);
    return AppSettings(
      themeMode: prefs.themeMode,
      enableDebugLogging: prefs.enableDebugLogging,
      defaultPageSize: prefs.defaultPageSize,
    );
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    if (state.themeMode == mode) return;
    state = state.copyWith(themeMode: mode); // 先改内存：UI 立刻响应
    await ref.read(userPreferencesProvider).setThemeMode(mode); // 再落盘
  }
}
```

- 状态是**不可变快照**（`@immutable` + `copyWith`），不是一组可写字段。一次 `state = ...`
  就是一次通知，页面只重建一趟。
- 写入走方法、不开 setter —— 这是「状态私有」的落地方式。
- 写入顺序统一是**先改内存、再落盘**：UI 立刻响应，落盘失败只记日志
  （见 [backend/database-guidelines.md](../backend/database-guidelines.md)）。
- 生命周期看需求：设置这类要活到 App 结束的带 `keepAlive`；表单这类**页面级**状态用默认的
  `autoDispose`，页面离开即释放，内容不跨页面残留。

### 3. 异步 Notifier —— API 数据

```dart
// lib/features/sample/logic/sample_list_notifier.dart
@riverpod
class SampleListNotifier extends _$SampleListNotifier {
  @override
  Future<List<SampleItem>> build() async {
    final result = await ref.watch(sampleRepositoryProvider).getItems();

    return switch (result) {
      Ok<List<SampleItem>, Failure>(:final data) => data,
      Err<List<SampleItem>, Failure>(:final error) => throw error,
    };
  }
}
```

一条不能破的约定：**抛 `Failure` 本身，不要另造包装异常**。

`AsyncValue.error` 允许携带任意对象，`ErrorText` 要靠这个对象翻译错误码；包一层就只剩
「未知错误」。`Failure implements Exception`，所以 `only_throw_errors` 不会报。

`build()` 是**唯一的读取点**：首屏加载就是 build，刷新与重试退回框架原语（见「刷新与重试」），
所以 Notifier 里通常没有 `load()` 方法。

### Provider 命名由生成器决定

`riverpod_generator` 按**去掉 `Notifier` 后缀的类名**命名 provider：

| 声明 | 生成的 provider |
|---|---|
| `class AppSettingsNotifier extends _$AppSettingsNotifier` | `appSettingsProvider`（**不是** `appSettingsNotifierProvider`） |
| `class SampleListNotifier extends _$SampleListNotifier` | `sampleListProvider` |
| `SampleApi sampleApi(Ref ref)` | `sampleApiProvider` |

容易写成 `appSettingsNotifierProvider`，编译器会直接报「未定义」，没有 lint 兜——但也不会静默错。

---

## 读写：`watch` vs `read`

| 场景 | 用法 |
|---|---|
| provider 的 `build()` 里、页面的 `build()` 里 | `ref.watch(...)` —— 建订阅，变了跟着重建 |
| Notifier 的方法里、事件回调里 | `ref.read(...)` —— 一次性取值 |
| 页面要调 Notifier 的方法 | `ref.read(xxxProvider.notifier)` —— 取的是实例本身 |

`ref.read(xxxProvider.notifier)` 在 `build` 里是**正当写法**：notifier 实例身份稳定、
不参与订阅，页面拿它当方法接收者（`onPressed: () => notifier.setThemeMode(mode)`）。门禁
`avoid_ref_read_in_build` 只管「取**值**的 read」，实参是 `.notifier` 时放行
（口径见 [cross-cutting.md](../cross-cutting.md)「代码形态约定」）。

`ref.watch` 只能在 `build` 里；在方法里 `watch` 会抛（`Ref.watch` 的生命周期约束）。
需要「状态变了做件事」时不要自己订阅，用 `ref.listen`（页面）或 `ref.listenSelf`（Notifier）。

---

## 渲染状态：一律走 `AsyncView`

**页面渲染 `AsyncValue` 一律走 `core/ui/async_view.dart` 的 `AsyncView`**，不要用
`AsyncValue.when`，也不要手写 `isLoading` / `hasError` 分支。

`AsyncValue` 允许「既有值又有错」（刷新失败时旧值还在），所以判定顺序有硬约束：

| `AsyncValue` 的形态 | `AsyncView` 渲染 |
| --- | --- |
| 有值 + `isRefreshing`（`ref.refresh`） | `refreshing`，缺省 `data(旧值)` |
| 有值 + `isReloading`（依赖变化 / `invalidate(asReload: true)`） | `reloading`，缺省 `data(旧值)` |
| 有值、稳定 | `data` |
| 出错 + `isRefreshing` | `refreshing`，缺省 `error` |
| 出错 + `isReloading` | `reloading`，缺省 `error` |
| 出错、稳定 | `error` |
| 无值无错 | `loading` |

1. **判定顺序不能改**：必须先判 `isRefreshing` / `isReloading`，再看值，最后才是错误。
   顺序一换，中间态就被旧值（或错误）吞掉了。
2. **旧值为 `null` 视同没有数据**：`hasValue` 只看「有没有那份记录」，`data(null)` 也算有值；
   而屏幕上要的是「真的有东西可渲染」，所以 `AsyncView` 额外判了一次 `value != null`。

`refreshing` / `reloading` / `data(null)` 这三条各有一条测试钉在
`test/core/ui/async_view_test.dart`，**行为不能静默丢**。

### 页面侧的两个配套要求

1. **空状态也要能刷新。** `RefreshIndicator` 得存在于树里，刷新才有可能被触发；空态直接
   返回 `EmptyWidget` 就是「列表为空 → 想刷新 → 刷不动」的死胡同。做法是用
   `CustomScrollView` + `SliverFillRemaining` 包成可滚动的，再套 `RefreshIndicator`。
2. **显式给 `AlwaysScrollableScrollPhysics`。** 刷新依赖子级可滚动（实测换成
   `NeverScrollableScrollPhysics` 后页面刷新测试全挂）；显式声明就不必赌「内容撑不满一屏时
   默认 physics 是否接受下拉」——这一点会随 Flutter 版本和平台变化。

两处的金标准都在 `features/sample/page/sample_list_page.dart`。

### 为什么不用 `AsyncValue.when`

`when` 的回调是具名且具类型的，签名配错在编译期就是 error。仍然统一走
`AsyncView` 的理由有两个，都与类型安全无关：

- 它封装了上表的判定顺序，页面不必各自记住「先刷新后错误」
- `refreshing` / `reloading` / `data(null)` 这三条是项目定制语义，换回 `when` 要让每个
  页面重写一遍（两条可选回调是给「后台更新时想显示别的东西」用的，缺省退回旧值）

这条现在是**约定**，不是门禁（见 [cross-cutting.md](../cross-cutting.md)「代码形态约定」）。

---

## 刷新与重试：不要自己写 request token

```dart
// 下拉刷新：返回 Future，交给 RefreshIndicator 等它结束
onRefresh: () => ref.refresh(sampleListProvider.future),

// 重试：丢弃当前状态、重新执行 build
onRetry: () => ref.invalidate(sampleListProvider),
```

刷新与重试的并发语义**全部由框架提供**，页面与 Notifier 都不该再实现一遍：

| 语义 | 落点 |
|---|---|
| 并发时「最后一次胜出」 | provider 重新执行 build 后，上一次仍在飞行中的 future 结果直接作废 |
| 刷新时保留旧数据 | `AsyncValue.isRefreshing` + `copyWithPrevious` |
| `data(null)` 视同没有数据 | `AsyncView` 的 `value != null` 判定（项目定制，需保留） |

两点要知道：

- `ref.refresh(p)`（不带 `.future`）**同步返回刷新后的 `AsyncValue`**（`isRefreshing == true`），
  逻辑测试用它断言中间态；页面里给 `RefreshIndicator` 用带 `.future` 的那个。
- 被取代的那次调用仍然会正常完成——它只是不再改写状态。需要按结果分支的方法
  （如提交成功后跳转）要自己看返回值，不能假设「state 是新的 = 这次成功了」。

---

## 生命周期：`autoDispose` / `keepAlive` / `ref.onDispose`

`@riverpod` **默认 `autoDispose`**：没有监听者时释放，由框架显式管理。

`@Riverpod(keepAlive: true)` 用于**跨页面共享、或重建有代价**的对象。当前清单：

| provider | 为什么 keepAlive |
|---|---|
| `core/providers.dart` 的 `prefs` / `database` / `fileStorage` / `userPreferences` | 基础设施单例 |
| `core/config/app_settings.dart` 的 `AppSettingsNotifier` | 主题等偏好，改一次全 App 受影响 |
| `core/data/network/dio_client.dart` 的 `networkConfig` / `dio` | **Dio 必须单例**（重建会丢在飞请求、重试状态与 mock 注册） |
| `app/providers.dart` 的 `router` | 重建路由器会丢掉整个导航栈 |
| 各 feature 的 `*_providers.dart` | 无状态服务，见上文 |

两条写法：

```dart
// 1. 飞行中的异步回写前判 mounted：provider 已被释放时写 state 会抛
if (ref.mounted) state = state.copyWith(isSubmitting: false);

// 2. 主动订阅就要主动退订：登记清理，别指望 GC
final subscription = someStream.listen((value) { ... });
ref.onDispose(subscription.cancel);
```

当前仓库里没有正在用第 2 条的 provider——新增流订阅、`Listenable`、控制器时按第 2 条登记即可。

`ref.watch` 建立的依赖由 provider 生命周期管理，provider 销毁时框架负责退订，
不存在「谁把谁钉住」的写法。需要记住的只有那条**原则**：主动 `listen` 的流、
`Listenable`、`StreamController` 必须自己在 `ref.onDispose` 里收尾（见上）。

> ⚠️ **`leak_tracker` 看不见 provider 状态对象**：`ProviderContainer` / `Notifier` /
> `AsyncValue` 是纯 Dart 对象，不上报 `FlutterMemoryAllocations`。它追踪的是
> `State` / `Element` / `ChangeNotifier` 这类 Flutter 对象（`ConsumerWidget` 的 Element
> 在覆盖范围内）。所以「测试里没报警」**不等于**「状态没有泄漏」——见
> [cross-cutting.md](../cross-cutting.md)「Memory Leak Detection」。

---

## Consumer 一节

> 页面的生命周期与副作用写法收在这里（不使用 `flutter_hooks`）。

### 页面模板

金标准是 `features/sample/page/sample_list_page.dart`，形状如下：

```dart
@RoutePage()
class SampleListPage extends ConsumerWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = ref.watch(sampleListProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('示例')),
      body: AsyncView<List<SampleItem>>(
        state: items,
        loading: () => const LoadingIndicator(),
        error: (error, stackTrace) => ErrorText(
          error: error,
          onRetry: () => ref.invalidate(sampleListProvider),
        ),
        data: (list) => RefreshIndicator(
          onRefresh: () => ref.refresh(sampleListProvider.future),
          child: /* 可滚动的列表 / 空态，见上文两条要求 */,
        ),
      ),
    );
  }
}
```

### 需要 State 的时候

动画控制器、`initState` 里发起的跳转这类有生命周期的页面用
`ConsumerStatefulWidget` + `ConsumerState`（范例：`lib/app/pages/splash_page.dart`）。
注意：

- `ConsumerState` 里**直接就有 `ref`**，不需要从 `build` 参数拿
- `dispose()` 里照常释放自己创建的 `AnimationController` 等
- 跳转前判 `mounted`（页面可能在 `await` 期间被 pop）

### 副作用不要写在 `build` 里

导航、`SnackBar`、`showDialog` 都放在事件回调或 `initState` / `ref.listen` 里。`build` 里做
副作用会随每次重建重复执行；`ref.read` 取值也一样（那是 `avoid_ref_read_in_build` 管的事）。

---

## Testing Requirements

**注入点就是 `ProviderScope(overrides:)`**，页面因此**不需要任何可注入的构造参数**
（不要加 `final Xxx? viewModel;` 这类字段）。

### 逻辑测试：`ProviderContainer` + `overrides`

```dart
container = ProviderContainer(
  retry: noRetry,
  overrides: [sampleRepositoryProvider.overrideWithValue(repo)],
);
addTearDown(container.dispose);

expect(await container.read(sampleListProvider.future), [item]);
```

用真实的 `UserPreferences`，只替换网络与仓库 —— 它有单元测试，
页面测试再 mock 一遍既重复、又容易掩盖接线错误（`test/support/app_test_harness.dart`）。

### widget 测试：`wrapPage(page, container: container)`

`wrapPage` 用 `UncontrolledProviderScope` 接上测试自己建的容器。换成 `ProviderScope`
会另建一个，测试对 provider 的读写就与页面断开了。

### 三条硬约束（都踩过）

1. **widget 测试里不要 `await provider.future`**。widget 测试的时钟是假的，riverpod 的调度
   任务只有 `tester.pump()` 才跑得动，那个 await 会一直卡到用例超时（10 分钟）。要构造
   refreshing / reloading 这类中间态，就「先渲染首帧 → 完成 `Completer` → `pump()` → 读状态」。
2. **容器统一传 `retry: noRetry`**（`test/support/app_test_harness.dart`）。Riverpod 3 默认
   对失败的 provider 自动重试（200ms 起、指数退避、最多 10 次），在 widget 测试里表现为收尾
   时报 `A Timer is still pending even after the widget tree was disposed`，并让「仓库被调用
   了几次」的断言凭空多出几次。**生产保留默认重试，只关测试。**
3. **autoDispose 的 provider 在两次 `read` 之间会被释放**。逻辑测试要先建一个订阅保住它
   （`container.listen(p, (_, _) {})`），而且必须在**打桩之后**调用 —— `listen` 会立刻跑一次
   `build()`，提前调用等于拿一个还没打桩的 mock 去调仓库（mocktail 返回 null，当场类型错）。

### 测试文件路径

跟随源码结构：`test/features/{feature}/{subdir}/` 对应 `lib/features/{feature}/{subdir}/`。

---

## Common Mistakes

| 错误 | 正确做法 |
| --- | --- |
| 页面写 `ref.read(xxxProvider)` 取值 | 用 `ref.watch`（`ref.read` 不建立订阅，变了不重建）；门禁 `avoid_ref_read_in_build` 会拦 |
| 在方法里 `ref.watch` | 方法里用 `ref.read`；需要跟随变化用 `ref.listen` |
| 在 `Notifier` 外部写 `state` | 写入只能在 Notifier 内，对外只暴露方法 |
| 异步失败时抛包装异常 | 抛 `Failure` 本身，否则 `ErrorText` 只剩「未知错误」 |
| 把 `Failure` 的类型信息丢掉、只存字符串 | `AsyncValue.error` 存对象，文案在展示层翻译（[backend/error-handling.md](../backend/error-handling.md)） |
| 一个字段一个 Notifier | 一份存储 / 同生命周期 / 页面一起读的偏好做成一个快照（`AppSettings`） |
| 页面自己维护 loading / request token | 用 `AsyncView` + `ref.refresh` / `ref.invalidate` |
| 用 `AsyncValue.when` 渲染三态 | 用 `AsyncView`（判定顺序与 `data(null)` 语义已封装） |
| 空列表直接返回 `EmptyWidget` | 包成可滚动 + `AlwaysScrollableScrollPhysics`，否则刷新是死路 |
| 给「无状态服务」不加 `keepAlive` | 加 `@Riverpod(keepAlive: true)`，否则每次 `ref.read` 都重建 |
| `ref.onDispose` 里漏掉流订阅 | 订阅了就要退订（主动 listen 必须在 `ref.onDispose` 里收尾） |
| 跨页面共享状态放进某个 feature 的 Notifier | 放到 `core/`（共享层严格克制，见 [directory-structure.md](./directory-structure.md)） |
