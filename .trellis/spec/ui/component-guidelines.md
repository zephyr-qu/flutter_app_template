# 组件规范

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


### 页面骨架（新增页面照这个形状写）

页面的骨架固定成一圈**限宽层 + 四件套**，都在 `lib/core/ui/`。页面头、区块头、
分组列表不再手写 `AppBar` / `Text(...).copyWith(w600)` / `Container + Column`。

```dart
Scaffold(
  body: PageBody(          // 宽屏限宽居中（> 800 → 720），窄屏铺满
    child: Column(
      children: [
        const PageHead(title: '示例'), // 页面头（替代 AppBar）
        Expanded(                     // 内容区：AsyncView 或滚动区
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SectionHead(title: '快捷功能'), // 区块头
                ListGroup(children: [ ... ]),        // 分组列表（小列表）
              ],
            ),
          ),
        ),
      ],
    ),
  ),
)
```

| 骨架件 | Widget | 用在哪 |
| --- | --- | --- |
| 页面层 | `PageBody` | 最外层：宽屏限宽居中，`PageHead` 与正文都在它里面 |
| 页面头 | `PageHead` | 每个页面的第一行（标题 / 副标题 / 返回键 / 右侧动作） |
| 区块头 | `SectionHead` | 每个成块内容之前（标题 + 说明 + 右侧动作） |
| 分组卡片 | `ListGroup` + `ListGroupRow` | ≤ 50 项的分组列表（设置项、条目组；分隔线自动加） |
| 大列表 | `SliverListGroup` | > 50 项，接在 `CustomScrollView.slivers` 里，只构建可视项 |

`PageHead` 放在 `Column` 顶部、**不塞进滚动区**——它内部套 `SafeArea`，
滚走状态栏内边距会顶到刘海。

金标准：`features/sample/page/sample_list_page.dart`（`PageHead` + `SliverListGroup`）、
`features/profile/page/profile_page.dart`（`SectionHead` + `ListGroup`）、
`features/home/page/home_page.dart`（`PageHead` + 两个 `SectionHead`）。

**反例（review 直接打回）**：

```dart
// ❌ 用 AppBar 做页面头：固定 56dp 高度、样式由 Material 决定，对不上设计稿
Scaffold(appBar: AppBar(title: const Text('示例')), body: ...)

// ❌ 用 NavigationBar 做页内二级切换：它属于主框架（features/home/page/main_page.dart）
bottomNavigationBar: NavigationBar(destinations: [...]),

// ❌ 几百项用 Column 铺（含 shrinkWrap 的 ListView）：首帧全量建树，
//    动作库这类页面在 widget 测试里 pumpAndSettle 直接超时
SingleChildScrollView(child: Column(children: [...])),
```

**什么时候才允许 `AppBar`**：需要折叠头（`SliverAppBar`）或搜索 / 多选这类系统级
动作时才用，并在同一处写一行理由注释。`NavigationBar` / `NavigationRail` 只属于
主框架 `main_page.dart`，feature 页面里不出现。

**边界校验 —— 页面头一律走 `PageHead`**：

```bash
grep -rn "appBar: AppBar\|SliverAppBar(" lib/   # 期望：无输出（有命中就是没走 PageHead）
```

### 布局断点与响应式

全项目**只有一条断点**，值在 `lib/core/ui/breakpoints.dart`：

| 常量 | 值 | 含义 |
| --- | --- | --- |
| `Breakpoints.expanded` | `800` | **严格大于**才是宽屏（`== 800` 仍算窄屏，`>` 不能写成 `>=`） |
| `Breakpoints.contentMaxWidth` | `720` | 单列页面在宽屏下的内容最大宽度（居中限宽） |

跨过 `Breakpoints.expanded` 要同时变两件事，只变一半就是半成品：

| 层 | 窄屏（≤ 800） | 宽屏（> 800） |
| --- | --- | --- |
| 导航壳（`features/home/page/main_page.dart`） | 底部 `NavigationBar` | 侧边 `NavigationRail` |
| 页面内容 | 单列铺满，左右边距 `AppThemeExtension.s20` | 二选一：**双列 / 主从**（列表 + 详情），或**单列限宽居中**（`ConstrainedBox(maxWidth: Breakpoints.contentMaxWidth)`） |

写法（页面侧一律用 `PageBody`，不要自己拼 `LayoutBuilder`）：

```dart
Scaffold(
  body: PageBody(          // 内部就是 LayoutBuilder + Align + 限宽，按内容区宽度判断
    child: Column(children: [ const PageHead(title: '示例'), Expanded(child: /* 正文 */) ]),
  ),
)
```

`PageBody` 必须放在**有界高度**里（`Scaffold.body` / `Expanded`）；它按父级高度撑满，
限宽只作用于宽度，不影响正文里的 `Expanded` 与滚动。

**禁止**：

- ❌ 页面里再写 `if (width > 600)` / `> 900` 这类第二个断点 —— 断点只有一条；确实需要新断点时先在本文登记常量与理由，再改代码
- ❌ 用 `MediaQuery.of(context).size.width` 判断点 —— 它拿的是**屏幕**宽度，在侧栏 / 分屏 / 浮窗下与内容区实际宽度不一致。用 `LayoutBuilder` 的 `constraints.maxWidth`
- ❌ 只改导航壳不改页面（或反过来）—— 宽屏下会出现「侧栏 + 一列拉满整个平板」的拉伸正文

**现状（2026-10）**：导航壳已按本约定实现（`main_page.dart` 用 `Breakpoints.expanded`）；`home` / `profile` / `sample` 三页已统一用 `PageBody` 做**单列限宽居中**。**双列 / 主从**形态目前没有页面用到——需要时按上表实现，并同步更新本节。

**边界校验 —— 断点值只允许出现在一个地方**：

```bash
grep -rnE "\b800\b" lib/ | grep -v "breakpoints.dart"   # 期望：无输出（页面与壳层一律用 > Breakpoints.expanded；不加 -E 会把 1800ms 也算进来）
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

**间距标尺**（`AppThemeExtension` 的静态常量，按 dp 值命名，可直接用在 `const` 构造里）：

| token | 值 | 典型用途 |
| --- | --- | --- |
| `AppThemeExtension.s4` | 4dp | 行内紧邻间隙（值 ↔ chevron） |
| `AppThemeExtension.s8` | 8dp | 图标与文字、标题与副标题 |
| `AppThemeExtension.s12` | 12dp | 区块标题下方、列表项之间 |
| `AppThemeExtension.s16` | 16dp | 卡片内边距（紧凑）、图标块尺寸 |
| `AppThemeExtension.s20` | 20dp | **页面左右边距**（全项目统一 20dp） |
| `AppThemeExtension.s24` | 24dp | 卡片内边距（宽松） |
| `AppThemeExtension.s32` | 32dp | 大区块分隔、空状态内边距 |

不在表里的数值（如 2、10、56）要么改成最近的 token，要么在原地写一行理由
（例：`ListGroup` 的分隔线左缩 56dp 是为了与 `ListGroupRow` 的图标对齐）。
字号不走 token：它是 `app_theme.dart` 的 `_textTheme`（M3 命名角色），页面只取
`textTheme.titleLarge` 这类角色，不自己写 `fontSize`。

想自己创建配色时，按想要的粒度分三档：

| 想要 | 改哪 | 代价 |
| --- | --- | --- |
| 换品牌色 | `app_color_scheme.dart` 的 `brandColors` | 6 行 |
| 微调个别语义角色 | `app_color_scheme.dart` 的 `applyBrandOverrides` | 1~N 行 |
| 完全掌控整套配色 | 用 `ColorScheme.fromSeed` 或手写 `ColorScheme` 替换 `app_theme.dart` 里的 `FlexThemeData.light/dark` 调用 | 一个 `_buildTheme` 函数体；手写要自己补齐 40+ 个角色 |

### 两条边界规则（各配一条命令）

**规则 1 —— token 不放颜色。** `app_theme_extension.dart` 只放 `ColorScheme` 表达不了的东西（圆角、间距），**不出现任何 `Color` 字段**。

圆角是实例字段（`radiusSm` / `radiusMd` / `radiusLg`，亮暗共用 `AppThemeExtension.base`），间距是静态常量（`s4` … `s32`）—— 间距不随主题变，且静态常量才能用在 `const` 构造里。

```bash
grep -n "Color" lib/core/theme/app_theme_extension.dart | grep -v "///"   # 期望：无输出（`///` 是文档说明「不放 Color」，不是字段）
```

**规则 2 —— `flex_color_scheme` 只允许出现在 `lib/core/theme/`。** 页面与组件不得 import 它，配色只在 `app_color_scheme.dart` 里定义。

```bash
grep -rln "flex_color_scheme" lib/   # 期望：只命中 lib/core/theme/ 下的 app_color_scheme.dart 与 app_theme.dart
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
| `PageBody` | `lib/core/ui/` | 宽屏限宽居中（> `Breakpoints.expanded` → `contentMaxWidth`），窄屏铺满；包住整页含 `PageHead` | `child` |
| `PageHead` | `lib/core/ui/` | 页面头：标题 + 副标题 / 前置控件 / 右侧动作（**替代 `AppBar`**） | `title`, `subtitle?`, `leading?`, `actions`, `padding` |
| `SectionHead` | `lib/core/ui/` | 区块标题 + 说明 + 右侧动作 | `title`, `caption?`, `trailing?`, `padding` |
| `ListGroup` | `lib/core/ui/` | 分组卡片：圆角底 + 子项间自动分隔线（**≤ 50 项**） | `children` |
| `ListGroupRow` | `lib/core/ui/` | 分组内一行：图标 + 标题 + 当前值 + chevron（有 `onTap` 才画箭头） | `title`, `icon?`, `value?`, `onTap?`, `trailing?` |
| `SliverListGroup` | `lib/core/ui/` | 分组列表的 sliver 版，**只构建可视项**（大列表用） | `itemCount`, `itemBuilder` |

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
