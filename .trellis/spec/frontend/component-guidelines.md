# 组件规范

> 本项目的组件（widget）怎么写。

---

## 概览

本项目是**使用 Material Design 3**（Material You）的 Flutter 工程。组件按标准 Flutter 写法来，重点在：

- 用**组合**，不自己画
- 尽可能用 **const 构造**
- **样式取自主题**（不写死颜色 / 字体）
- 用 `LayoutBuilder` 做**响应式布局**
- **零依赖的加载态**（`LoadingIndicator` 里的 `CircularProgressIndicator`；脚手架不预装动画 / 骨架屏包）

---

## 页面结构

### 标准页面（带状态）

- 页面**不持有**任何可注入字段（注入口是 `ProviderScope(overrides:)`），也不注册 `getIt`
- 状态与业务逻辑在 `logic/` 的 Notifier 里，页面只 `ref.watch` + 转事件
- 完整模板、生命周期与测试见 [state-management.md](./state-management.md)「Consumer 一节」（金标准 `features/sample/page/sample_list_page.dart`）

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

## Props 约定

- **数据**：构造器里用 `required` 具名参数传入；**回调**：具名参数，类型 `VoidCallback?`；**可选项**：具名参数 + 合理默认值

```dart
class ErrorText extends StatelessWidget {
  const ErrorText({
    super.key,
    required this.error,
    this.onRetry,
    this.icon,
  });

  final Object error;
  final VoidCallback? onRetry;
  final IconData? icon;
}
```

---

## 样式范式

**不要写死颜色与字体**，一律走 `Theme.of(context)`：

```dart
// 正例
Text(item.title, style: theme.textTheme.titleLarge),
Text(
  '点击阅读更多...',
  style: theme.textTheme.bodyMedium?.copyWith(
    color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
  ),
),

// 反例
Text(item.title, style: TextStyle(fontSize: 18, color: Colors.black)),
```

## 主题层

主题拆成三个文件（`lib/core/theme/`），**各有唯一职责**：

| 文件 | 职责 |
|---|---|
| `app_color_scheme.dart` | 品牌色板 + 需要偏离 Material 的语义色。**唯一**允许 import `flex_color_scheme` 的文件 |
| `app_theme.dart` | 组装 `ThemeData`，对外只暴露 `buildLightTheme()` / `buildDarkTheme()`。**内部不写裸数字**——圆角、间距取自 `app_theme_extension.dart` 的 token，不写 `BorderRadius.circular(12)` 这种字面量。`_textTheme` 的字号 / 字重是主题定义本身，不在此列 |
| `app_theme_extension.dart` | 设计 token：**只放 `ColorScheme` 表达不了的东西**（圆角、间距） |

想自己创建配色时，按想要的粒度分三档：

| 想要 | 改哪 | 代价 |
| --- | --- | --- |
| 换品牌色 | `app_color_scheme.dart` 的 `brandColors` | 6 行 |
| 微调个别语义角色 | `app_color_scheme.dart` 的 `applyBrandOverrides` | 1~N 行 |
| 完全掌控整套配色 | 用 `ColorScheme.fromSeed` 或手写 `ColorScheme` 替换 `app_theme.dart` 里的 `FlexThemeData.light/dark` 调用 | 一个 `_buildTheme` 函数体；手写要自己补齐 40+ 个角色 |

### 两条边界规则（各配一条命令）

**规则 1 —— token 不放颜色。** `app_theme_extension.dart` 只放 `ColorScheme` 表达不了的东西（圆角、间距），**不出现任何 `Color` 字段**。

```bash
grep -n "Color" lib/core/theme/app_theme_extension.dart   # 期望：无输出
```

**规则 2 —— `flex_color_scheme` 只允许出现在 `lib/core/theme/`。** 页面与组件不得 import 它，配色只在 `app_color_scheme.dart` 里定义。

```bash
grep -rln "flex_color_scheme" lib/   # 期望：只命中 lib/core/theme/app_color_scheme.dart
```

**主题入口只有两个函数，不内联在 `lib/app/app.dart`。**

```dart
ThemeData buildLightTheme();   // app_theme.dart
ThemeData buildDarkTheme();
```

`lib/app/app.dart` 把两份 `ThemeData` 缓存在顶层 `final`。

---

## 共享组件

共享组件都在 `lib/core/ui/`（其中 `EmptyWidget` 不读项目文案，其余会用到文案 / 主题）：

| Widget | 位置 | 用途 | Props |
| -------- | ------ | --------- | ------- |
| `AsyncView<T>` | `lib/core/ui/` | 把 `AsyncValue<T>` 渲染成 Widget，**类型安全**（判定表见 [state-management.md](./state-management.md)） | `state`, `data`, `loading`, `error`, `refreshing?`, `reloading?` |
| `LoadingIndicator` | `lib/core/ui/` | 居中转圈（`CircularProgressIndicator`，零依赖） | `size` |
| `ScreenLoadingIndicator` | `lib/core/ui/` | 全屏加载态（转圈 + 一行 `加载中...`） | — |
| `ErrorText` | `lib/core/ui/` | 带重试的错误展示；靠 `Failure` 的错误码翻译文案 | `error`, `onRetry?`, `icon?` |
| `EmptyWidget` | `lib/core/ui/` | 空状态占位（不读文案，文案由调用方给） | `message`, `icon?`, `actionLabel?`, `onAction?` |

---

## 无障碍

- 自定义组件用 `Semantics` 或 Material 自带的语义；能用 Material 组件就别自己造，内置组件的无障碍是现成的
- 触摸目标至少 48x48 dp
- 颜色取自 `Theme.of(context)` —— 系统高对比度设置才会生效

---

## 常见错误

- ❌ **写死颜色 / 字体、把业务逻辑写进 widget、用 `AsyncValue.when` 渲染三态、给页面加注入点** — 规则与正确做法见 [quality-guidelines.md](./quality-guidelines.md)「禁止模式」/「必须遵守」
- ❌ **不用 `const` 构造** — lint `prefer_const_constructors` 会拦
- ❌ **漏写 `super.key`** — widget 构造器一律写 `super.key`
