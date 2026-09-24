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

### 标准页面（带状态）

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
          child: /* 列表 / 空态 */,
        ),
      ),
    );
  }
}
```

- 页面**不持有**任何可注入字段（注入口是 `ProviderScope(overrides:)`），也不注册 `getIt`
- 状态与业务逻辑在 `logic/` 的 Notifier 里，页面只 `ref.watch` + 转事件
- 详细的写法、生命周期与测试见 [state-management.md](./state-management.md)「Consumer 一节」

### 无状态页面（无需状态）

```dart
class SampleCard extends StatelessWidget {
  const new({super.key, required this.item});

  final SampleItem item;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Text(item.title, style: theme.textTheme.titleMedium);
  }
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
  item.title,
  style: theme.textTheme.titleLarge,
),
Text(
  '点击阅读更多...',
  style: theme.textTheme.bodyMedium?.copyWith(
    color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
  ),
),

// BAD
Text(item.title, style: TextStyle(fontSize: 18, color: Colors.black)),
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

第三档之后 `lib/core/theme/` 里不再有 `flex_color_scheme`，规则 2 的 `grep` 验证会变成「无输出」——
这也是它可被验证的意义：边界会不会破，一条命令就能看出来。

**主题入口只有两个函数，不内联在 `lib/app/app.dart`。**

```dart
ThemeData buildLightTheme();   // app_theme.dart
ThemeData buildDarkTheme();
```

内联在组合根也能跑，但那样测试只能自己拼一套主题，于是出现「测试里一套、线上另一套」，
主题相关的断言全部失去意义。公开成函数后，测试挂的就是同一份
（`app.dart` 把两份 `ThemeData` 缓存在顶层 `final`，理由见该文件注释）。

---

## Shared Widgets

共享组件都在 `lib/core/ui/`（其中 `EmptyWidget` 不读项目文案，其余会用到文案 / 主题）：

| Widget | 位置 | Purpose | Props |
| -------- | ------ | --------- | ------- |
| `AsyncView<T>` | `lib/core/ui/` | 把 `AsyncValue<T>` 渲染成 Widget，**类型安全**（判定表见 [state-management.md](./state-management.md)） | `state`, `data`, `loading`, `error`, `refreshing?`, `reloading?` |
| `LoadingIndicator` | `lib/core/ui/` | 居中转圈（`CircularProgressIndicator`，零依赖） | `size` |
| `ScreenLoadingIndicator` | `lib/core/ui/` | 全屏加载态（转圈 + 一行 `加载中...`） | — |
| `ErrorText` | `lib/core/ui/` | Error with retry；靠 `Failure` 的错误码翻译文案 | `error`, `onRetry?`, `icon?` |
| `EmptyWidget` | `lib/core/ui/` | Empty state placeholder（不读文案，文案由调用方给） | `message`, `icon?`, `actionLabel?`, `onAction?` |

---

## Three-State Rendering

所有异步页面遵循统一的渲染模式——**用 `AsyncView`**：

```dart
// 推荐：状态与分支都由 AsyncView 承载
AsyncView<List<SampleItem>>(
  state: items,                                   // ref.watch(xxxProvider)
  loading: () => const LoadingIndicator(),
  error: (error, stackTrace) => ErrorText(error: error, onRetry: retry),
  data: (list) => list.isEmpty
      ? const EmptyWidget(message: '暂无数据')
      : ListView.builder(...),
)

// 不推荐：AsyncValue.when —— 判定顺序与 data(null) 语义要各自重写一遍
// 不推荐：手写 is-loading / has-error 分支，三态逻辑会被抄散到每个页面
```

`AsyncView` 覆盖稳定态（loading / data / error）；后台刷新与重载用可选的
`refreshing` / `reloading` 回调，缺省时退回 `data`（旧数据）。判定顺序表与
`data(null)` 这条定制语义见 [state-management.md](./state-management.md)「渲染状态」。

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
- ❌ **Business logic in widgets** — Delegate to the Notifier for all state mutations
- ❌ **在页面里 `ref.read(xxxProvider)` 取值** — 用 `ref.watch`（门禁 `avoid_ref_read_in_build` 会拦）
- ❌ **用 `AsyncValue.when` 渲染三态** — 用 `AsyncView`（判定顺序与 `data(null)` 语义已封装）
- ❌ **给页面加 `final Xxx? viewModel;` 注入点** — 注入口是 `ProviderScope(overrides:)`，页面不持有可注入字段
