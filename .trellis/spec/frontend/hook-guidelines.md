# Hook Guidelines

> How hooks (`flutter_hooks`) are used in this project.

---

## Overview

This project uses **`flutter_hooks`** (for lifecycle management in `HookWidget`) and **`signals_hooks`** (for signals integration with hooks).

The primary hook usage is:

- **`useSignalValue`** — Read signal values reactively in widget tree
- **`useMemoized`** — Memoize ViewModel instances across rebuilds
- **`useEffect`** — Trigger data loading on mount

---

## Page Template

All feature pages use the same pattern:

```dart
@RoutePage()
class ArticleListPage extends HookWidget {
  /// 可选注入点——只有测试会传值（ADR-0001 的缓解措施，脚本规则 4 会拦缺失）
  final ArticleViewModel? viewModel;

  const ArticleListPage({super.key, this.viewModel});

  @override
  Widget build(BuildContext context) {
    final vm = useMemoized(() => viewModel ?? getIt<ArticleViewModel>());
    final async = useSignalValue(vm.articles);

    useEffect(() {
      vm.loadArticles();
      return null;
    }, []);

    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('文章列表')),
      body: AsyncView<List<Article>>(
        state: async,
        loading: () => const LoadingIndicator(),
        error: (Object error, StackTrace stackTrace) =>
            ErrorText(error: error, onRetry: vm.loadArticles),
        data: (items) => ListView.builder(
          itemCount: items.length,
          itemBuilder: (context, index) => Text(items[index].title),
        ),
      ),
    );
  }
}
```

**关键点**：

- `useMemoized` 确保 ViewModel 只创建一次（不是每次 build 都重新创建）
- **可选注入点不是可选项**：`final T? viewModel;`、构造参数 `this.viewModel`、`viewModel ?? getIt<T>()` 三件套缺一不可——少写编译器不会报错，`tool/check_boundaries.dart` 规则 4 会（理由见 [ADR-0001](../../../docs/adr/ADR-0001.md)）
- `useSignalValue` 在 Widget 销毁时自动取消订阅（无需手动 dispose）
- `useEffect` 在首次挂载时触发数据加载
- 用 `AsyncView` 渲染 loading / error / data 三态；**不要用 `AsyncState.map`**（回调签名在运行期才校验，见 [state-management.md](./state-management.md)）

---

## App Root (MyApp)

```dart
class MyApp extends HookWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = getIt<AuthStorage>();
    final preferences = getIt<UserPreferences>();

    // 路由器只创建一次（无依赖）：登录态由 AuthGuard 在导航时实时读取。
    // 不要依赖 isLoggedIn 变化来重建路由器——重建会丢弃整个导航栈。
    final router = useMemoized(() => AppRouter(auth));

    // 订阅信号：设置里改完语言/主题要立刻生效
    final themeMode = useSignalValue(preferences.themeMode);

    // 主题在 lib/core/theme/ 里组装，这里只接线（见 frontend/component-guidelines.md）
    final themeLight = useMemoized(buildLightTheme);
    final themeDark = useMemoized(buildDarkTheme);

    return MaterialApp.router(
      routerConfig: router.config(),
      theme: themeLight,
      darkTheme: themeDark,
      themeMode: themeMode,
    );
  }
}
```

---

## Data Fetching

Data fetching 由 ViewModel 负责，**不在 hook 里执行**：

```
Page (useEffect → vm.load()) → ViewModel (runAsync) → Service → API
```

- **ViewModel** (`logic/`) 调用 `runAsync` 管理 asyncSignal 三态
- **Page** (`HookWidget`) 通过 `useEffect` 触发加载
- **`useSignalValue`** 响应式更新 UI

```dart
// ViewModel
Future<void> load() async {
  await runAsync(articles, () => _repo.getArticles());
}

// Page
useEffect(() {
  vm.load();
  return null;
}, []);
```

---

## Naming Conventions

- **HookWidgets** follow the same naming as regular widgets (PascalCase)
- **Custom hooks** (if needed) follow the `use` prefix convention from `flutter_hooks`
- Signal variables use descriptive names: `articles`, `selectedArticle`, `isLoggedIn`

---

## Common Mistakes

- ❌ **Overusing hooks** — ViewModels handle business logic, hooks only handle widget lifecycle
- ❌ **Missing dependency arrays in `useMemoized`/`useEffect`** — Causes stale closure bugs
- ❌ **Calling hooks conditionally** — All hooks must be called in the same order every build
- ❌ **Creating ViewModel in `build()` without `useMemoized`** — Creates new instance per rebuild, old one leaks
