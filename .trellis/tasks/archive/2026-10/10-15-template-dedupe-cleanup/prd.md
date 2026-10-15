# 收敛脚手架重复：输入框装饰下沉主题 + 死面 API 与失效注释清理

## Goal

模板里三处逐字重复的输入框装饰应收进主题层，让派生项目改一次就能全局生效；零引用的公开 API
与指向已消失文档的注释不应误导下一个读者。目标是**减少重复表达**，不改变任何运行时行为
（除了输入框装饰的写法位置）。

用户价值：这个仓库是派生新项目的起点，任何一处「抄了 3 份的样式」和「注释指着不存在的
design.md 6.5」都会被复制到每个下游项目。

## Background

立项调查（2026-10-15，静态证据：行块比对 + 引用计数 + 逐文件读）确认以下事实，均已在本仓库核实：

### 一、输入框装饰逐字重复 3 份

| 位置 | 重复内容 |
|---|---|
| `lib/features/auth/page/login_page.dart:92-106` | `filled: true` + `fillColor: colorScheme.surfaceContainerLow` + `OutlineInputBorder(borderRadius: radiusSm, borderSide: BorderSide.none)` |
| `lib/features/auth/page/login_page.dart:114-128` | 同上（密码框），仅 `labelText` / `hintText` / `prefixIcon` / `obscureText` 不同 |
| `lib/features/demo/page/storage_demo_page.dart:50-57` | 同上（示例页输入框） |

- `grep -rn "inputDecorationTheme" lib/` → **无命中**：主题层目前没有这一项。
- 三处的共同项恰好是 `InputDecoration` 的**全局默认**，页面侧真正特有的只有
  `labelText` / `hintText` / `prefixIcon` / `obscureText` / `keyboardType`。
- 现有测试**没有任何一条**断言输入框装饰：`grep -n "InputDecoration\|fillColor\|OutlineInputBorder\|labelText" test/features/auth/page/login_page_test.dart test/features/demo/page/storage_demo_page_test.dart` → 无输出。所以这次改动不会碰现有断言，但也意味着**必须新增一条**才有回归保护。
- spec 已经把「主题层收敛」写成硬约定且留了位置：
  `.trellis/spec/ui/component-guidelines.md:117-126` 规定 `app_theme.dart` 组装 `ThemeData`、
  **内部不写裸数字**（圆角取自 token）、`app_theme_extension.dart` 只放 `ColorScheme`
  表达不了的东西。`lib/core/theme/app_theme_extension.dart:12` 的 `radiusSm` 注释已写明
  「小圆角：标签、按钮、**输入框**」——主题层至今没兑现这句话。
- `app_theme.dart` 已有 `cardTheme` / `chipTheme` / `snackBarTheme` 三项同类收敛，写法可照抄。

### 二、零引用的公开 API（"死面"）

| 符号 | lib 内引用 | test 内引用 | 备注 |
|---|---|---|---|
| `Result.mapError`（`lib/core/base/result.dart:35`） | 0 | 0 | 全仓无调用点 |
| `Result.flatMap`（`result.dart:42`） | 0 | 0 | 全仓无调用点 |
| `Result.getOrThrow`（`result.dart:21`） | 0 | 0 | **注释写「只用于测试」，而测试也没用** —— 注释与事实不符 |
| `Result.isSuccess`（`result.dart:16`） | 0 | 有 | lib 内无调用 |
| `EmptyWidget.actionLabel` / `onAction` | 0（`article_list_page.dart:56` 两个都不传） | 有 | |
| `FileStorage.saveBytes` / `readBytes` / `exists` | 0 | 仅 `test/core/data/storage/file_storage_test.dart` | |
| `AuthStorage.currentUserId` | 0 | 仅 `test/core/data/storage/auth_storage_test.dart:249` | |

判断口径：`grep -rn "<symbol>" lib test --include=*.dart` 后排除定义处自身。

### 三、指向已消失文档 / 已不存在语境的注释

`design.md` 只存在于 `.trellis/tasks/archive/` 下（7 份），仓库里没有活的 `design.md`，
但 `lib/` 里有注释指着它：

| 位置 | 现状文本 | 问题 |
|---|---|---|
| `lib/core/data/network/dio_factory.dart:22` | 「谁来提供」归**各分支**的装配层（见 **design 6.5**） | 两个引用都失效 |
| `lib/core/data/network/token_store.dart:12-13` | **各分支**用自己栈的类实现（signals 分支：`AuthStorage`；**Riverpod 分支**：对应的 `Notifier`） | 本仓库只有 signals 一支，没有 Riverpod 分支 |
| `lib/core/data/network/token_store.dart:17` | 为什么需要这层反转、边界怎么定，见 **design.md 6.1** | 同上 |
| `lib/core/data/storage/file_storage.dart:13-14` | 注册由**各分支**的装配层负责（signals 分支见 `lib/core/core_module.dart`） | 同上 |
| `.trellis/spec/data/network-guidelines.md:17` | `createDio()`：……**不知道 signals / Riverpod 的存在** | 同源表述 |

**同源但不算失效**：`docs/optional-additions.md:116,118,130` 提 `riverpod` 是在讲
「换状态管理要付什么代价」，是正当用法，不在清理范围。

### 四、明确不动的项（避免误判为遗漏）

- `runAsync` / `runAsyncVoid` / `runCatching`：契约不同，`run_async.dart` 已写明为何不能合并。
- `lib/core/ui/empty_widget.dart`(69 行) 与 `lib/core/ui/error_text.dart`(83 行) 的
  `Center > Padding(32) > Column > [圆角 Icon 容器, SizedBox(20), 文案, 可选按钮]` 骨架同形。
- `splash_page.dart:86-95` 与 `login_page.dart:37-46` 的渐变 `Container`。
- `app_theme.dart:19-36` 里 `FlexThemeData.light` / `.dark` 的 9 个参数逐字重复。
- `features/demo/` 与 `profile_settings.dart` 的 `TODO(template)` 占位：模板设计，由
  `tool/prune_examples.dart` 负责移除。

## Requirements

- **R1 输入框装饰下沉主题。** 在 `lib/core/theme/app_theme.dart` 增加全局输入框装饰默认值，
  覆盖上面三处的公共部分（`filled` / `fillColor` / 边框形状与圆角）；三处页面各自只保留
  自己特有的属性。圆角必须取自 `AppThemeExtension` 的 token，颜色必须取自（已过
  `applyBrandOverrides` 的）`colorScheme` —— 遵守 `component-guidelines.md:117-126` 的
  「`app_theme.dart` 内部不写裸数字」。
- **R2 死面 API：只改注释，API 全留。** 修正 `result.dart:20` 对 `getOrThrow` 的「只用于测试」
  表述 —— 它全仓（`lib` + `test`）零调用，与事实不符。以下一律保留：`Result.mapError` /
  `flatMap` / `isSuccess`、`EmptyWidget.actionLabel`+`onAction`、
  `FileStorage.saveBytes`+`readBytes`+`exists`、`AuthStorage.currentUserId`。
  理由：这是模板，`Result` 与 `FileStorage` 是**故意留宽**的公开工具面，派生项目会用到；
  删掉只会让下游自己补回来。
- **R3 失效注释清理（`lib/` 4 处 + 同源 spec 1 处）。** 改写 Background 三、列出的 5 处：
  去掉「各分支 / Riverpod 分支」这类**已不存在的语境**，把 `design 6.5` / `design.md 6.1`
  换成仓库里真实存在、读者能打开的目标（或直接删掉这句指引），且**不丢失注释原本承载的信息**
  —— 即「为什么需要这层反转（`TokenStore`）」「Mock 规则为什么放在 `dio_client` 而不是
  `dio_factory`」「`FileStorage` 为什么不带 DI 注解」。`.trellis/spec/data/network-guidelines.md:17`
  与 `dio_factory.dart:21-22` 是同一句话，必须同批改，否则失效语境只是换了地方。
- **R4 注释块长度。** 改后的注释仍受 `comment_block_too_long`（连续注释块 ≤10 行）约束；
  修注释时不得把解释从 spec 搬进代码注释（`guides/comment-guidelines.md`）。

## Acceptance Criteria

- [ ] **AC1** `grep -rn "OutlineInputBorder" lib/` 只在 `lib/core/theme/app_theme.dart` 命中；
      `grep -rn "fillColor" lib/` 只在 `app_theme.dart` 命中。
- [ ] **AC2** `login_page.dart` 与 `storage_demo_page.dart` 的 `InputDecoration(...)` 里不再出现
      `filled: true` / `fillColor:` / `OutlineInputBorder`。
- [ ] **AC3** 新增一条 widget 测试证明「装饰真的走了主题」而不是被删掉了：在
      `buildLightTheme()` 下 pump 一个只带 `labelText` 的 `TextField`，断言
      `tester.widget<InputDecorator>(find.byType(InputDecorator)).decoration`
      的 `filled == true` 且 `fillColor` / `border` 与主题一致。
      （依据：Flutter 3.47.2 `text_field.dart:1769` 把 `_getEffectiveDecoration()` 交给
      `InputDecorator`，而 `text_field.dart:1204-1209` 里它是
      `decoration.applyDefaults(InputDecorationTheme.of(context))` —— 已在本机 SDK 核实。）
- [ ] **AC4** `just codegen` 与 `just verify` 全绿（`fmt-check` / `analyze-app` / `analyze-tool` /
      `test-app-lints` / `test`）；本次改动不触注解，但仍按仓库约定跑一次 codegen 确认无漂移。
- [ ] **AC5** R3 清理后，`grep -rn "design 6.5\|design\.md 6.1" lib/` 无命中，且
      `grep -rn "各分支" lib/` 无命中。
- [ ] **AC6** 改后的注释块仍通过 `comment_block_too_long`（由 `just analyze-app` 覆盖）。
- [ ] **AC7** `grep -rn "mapError\|flatMap\|getOrThrow" lib test --include=*.dart` 后，只命中
      `lib/core/base/result.dart` 的定义处与 `getOrThrow` 的 message 字符串；
      `result.dart` 中关于 `getOrThrow` 用途的表述与「全仓零调用」这一事实一致（不再写「只用于测试」）。
- [ ] **AC8** `.trellis/spec/ui/component-guidelines.md` 的「主题层」小节含第三条边界规则及其
      grep 命令，小标题已由「两条边界规则」改为「三条边界规则」；该命令在当前代码上**真的能通过**
      （不是写了一条必然失败的规则）。

## Out of Scope

- **`EmptyWidget` / `ErrorText` 的骨架合并**（Background 四）：需要引入一个带 icon 尺寸 / 配色 /
  标题开关的中间组件，是组件重构而非去重，改动面覆盖 `core/ui` 与页面测试。
- **渐变 `Container` 的抽取**（splash / login）：只有 2 处，抽出来反而多一层间接。
- **`app_theme.dart` 两份 `FlexThemeData` 参数合并（已定：不纳入）**：`switch` 表达式表达亮暗两档
  更直白；合并只能写成「把 `FlexThemeData.light` / `.dark` 放进 `switch` 再调用」，
  用可读性换 8 行，不划算。
- **`runAsync` / `runAsyncVoid` / `runCatching` 三者合并**：契约不同。
- **任何运行时行为变更**：包括 `Failure` / `Result` 的语义、输入框的视觉表现。
- **`docs/optional-additions.md` 里的 riverpod 表述**：正当用法。
