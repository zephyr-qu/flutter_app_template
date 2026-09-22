# Component Guidelines

> How components (widgets) are built in this project.

> **Scaffold note**: This is a personal Flutter scaffold/template. Component patterns below are examples to build upon — adapt them as needed for specific apps.

---

## Overview

This is a **Flutter project using Material Design 3** (Material You). Widgets follow standard Flutter patterns with a focus on:

- **Composition** over custom painting
- **const constructors** wherever possible
- **Theme-based styling** (no hardcoded colors/fonts)
- **Responsive layouts** with `LayoutBuilder`
- **Dependency-free loading states** (`CircularProgressIndicator` inside `LoadingIndicator`; 加载态的表现形式由业务 App 自己决定，脚手架不预装动画/骨架屏包)

---

## Page Structure

### 标准页面（带 ViewModel）

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
        data: (items) => ListView.builder(/* ... */),
      ),
    );
  }
}
```

### 无状态页面（无需 ViewModel）

```dart
class ArticleDetailPage extends StatelessWidget {
  final Article article;
  const ArticleDetailPage({super.key, required this.article});

  @override
  Widget build(BuildContext context) { ... }
}
```

---

## Props Conventions

- **Data**: Pass via `required` named parameters in constructor
- **Callbacks**: Named params with `VoidCallback?` for optional actions
- **Options**: Named params with sensible defaults

```dart
class ErrorText extends StatelessWidget {
  const ErrorText({
    super.key,
    required this.error,          // Required data
    this.onRetry,                 // Optional callback
    this.icon,                    // Optional customization
  });

  final Object error;
  final VoidCallback? onRetry;
  final IconData? icon;
}
```

---

## Styling Patterns

**Never hardcode colors or typography**. Always use `Theme.of(context)`:

```dart
// GOOD
Text(
  article.title,
  style: theme.textTheme.titleLarge,
),
Text(
  '点击阅读更多...',
  style: theme.textTheme.bodyMedium?.copyWith(
    color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
  ),
),

// BAD
Text(article.title, style: TextStyle(fontSize: 18, color: Colors.black)),
```

## Theme Layer

主题拆成三个文件（`lib/core/theme/`），**各有唯一职责**：

| 文件 | 职责 |
|---|---|
| `app_color_scheme.dart` | 品牌色板 + 需要偏离 Material 的语义色。**唯一**允许 import `flex_color_scheme` 的文件 |
| `app_theme.dart` | 组装 `ThemeData`，对外只暴露 `buildLightTheme()` / `buildDarkTheme()`。**内部不写裸数字**——圆角、间距取自 `app_theme_extension.dart` 的 token，不写 `BorderRadius.circular(12)` 这种字面量（数字一旦在主题里写死，页面想统一调整时就找不到它）。`_textTheme` 的字号 / 字重是主题定义本身，不在此列 |
| `app_theme_extension.dart` | 设计 token：**只放 `ColorScheme` 表达不了的东西**（圆角、间距） |

想自己创建配色时，按想要的粒度分三档：

| 想要 | 改哪 | 代价 |
| --- | --- | --- |
| 换品牌色 | `app_color_scheme.dart` 的 `brandColors` | 6 行 |
| 微调个别语义角色 | `app_color_scheme.dart` 的 `applyBrandOverrides` | 1~N 行 |
| 完全掌控整套配色 | 用 `ColorScheme.fromSeed` 或手写 `ColorScheme` 替换 `app_theme.dart` 里的 `FlexThemeData.light/dark` 调用 | 一个 `_buildTheme` 函数体；手写要自己补齐 40+ 个角色 |

### 两条边界规则（各配一条命令，破了就能看出来）

**规则 1 —— token 不放颜色。** `app_theme_extension.dart` 只放 `ColorScheme` 表达不了的东西（圆角、间距），**不出现任何 `Color` 字段**：能用「语义角色」表达的东西就不该另造一个 token，否则换主题时会漏掉它。

```bash
grep -n "Color" lib/core/theme/app_theme_extension.dart   # 期望：无输出
```

**规则 2 —— `flex_color_scheme` 只允许出现在 `lib/core/theme/`。** 页面与组件不得 import 它，配色只在 `app_color_scheme.dart` 里定义。

```bash
grep -rln "flex_color_scheme" lib/   # 期望：只命中 lib/core/theme/app_color_scheme.dart
```

第三档之后 `lib/` 里不再有 `flex_color_scheme`，规则 2 的 `grep` 验证会变成「无输出」——
这也是它可被验证的意义：边界会不会破，一条命令就能看出来。

**主题入口只有两个函数，不内联在 `lib/app/app.dart`。**

```dart
ThemeData buildLightTheme();   // app_theme.dart
ThemeData buildDarkTheme();
```

内联在组合根也能跑，但那样测试只能自己拼一套主题，于是出现「测试里一套、线上另一套」，
主题相关的断言全部失去意义。公开成函数后，测试挂的就是同一份。

---

## Shared Widgets

Core shared widgets in `lib/core/ui/`:

| Widget | Purpose | Props |
| -------- | --------- | ------- |
| `AsyncView<T>` | 把 `AsyncState<T>` 渲染成 Widget，**类型安全**（取代 `AsyncState.map`） | `state`, `data`, `loading`, `error`, `refreshing?`, `reloading?` |
| `LoadingIndicator` | 居中转圈（`CircularProgressIndicator`，零依赖） | `size` |
| `ScreenLoadingIndicator` | 全屏加载态（转圈 + 一行 `l10n.loading`） | — |
| `ErrorText` | Error with retry | `error`, `onRetry?`, `icon?` |
| `EmptyWidget` | Empty state placeholder | `message`, `icon?`, `actionLabel?`, `onAction?` |

---

## Three-State Rendering

所有异步页面遵循统一的渲染模式——**用 `AsyncView`**：

```dart
// 推荐：状态与分支都由 AsyncView 承载
AsyncView<List<Article>>(
  state: async,
  loading: () => const LoadingIndicator(),
  error: (Object error, StackTrace stackTrace) =>
      ErrorText(error: error, onRetry: retry),
  data: (items) => items.isEmpty
      ? const EmptyWidget(message: '暂无数据')
      : ListView.builder(...),
)

// 不推荐：AsyncState.map 的 error 回调签名在运行期才校验（见 frontend/state-management.md）
// 不推荐：手写 is-loading / has-error 分支，三态逻辑会被抄散到每个页面
```

`AsyncView` 覆盖稳定态（loading / data / error）；后台刷新与重载用可选的
`refreshing` / `reloading` 回调，缺省时退回 `data`（旧数据）。

---

## Accessibility

- Use `Semantics` widget or Material's built-in semantics for custom widgets
- Ensure touch targets are at least 48x48 dp
- Use `Theme.of(context)` colors — respects system high-contrast settings
- Prefer Material Design components for built-in accessibility

---

## Common Mistakes

- ❌ **Hardcoding colors/fonts** — Always use `Theme.of(context)` and `colorScheme`
- ❌ **Not using `const` constructors** — The linter enforces `prefer_const_constructors`
- ❌ **Missing `super.key`** — Always include `super.key` in widget constructors
- ❌ **Business logic in widgets** — Delegate to ViewModel for all state mutations
- ❌ **Creating ViewModel in `build()` without `useMemoized`** — Creates new instance per rebuild
- ❌ **Using `Watch.builder` / `Watch()`** — These are deprecated; use `SignalBuilder` or `useSignalValue`
