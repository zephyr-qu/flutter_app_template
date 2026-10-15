# 技术设计：输入框装饰下沉主题 + 死面 API 与失效注释清理

对应 [prd.md](./prd.md) 的 R1 / R2 / R3 / R5。本文件只记**边界、契约、已核实事实与决策**，
执行顺序见 [implement.md](./implement.md)。

---

## 1. 边界：谁改哪个文件

| 文件 | 改动 | 对应 |
|---|---|---|
| `lib/core/theme/app_theme.dart` | `_buildTheme` 里新增 `inputDecorationTheme` | R1 |
| `lib/features/auth/page/login_page.dart` | 两个 `InputDecoration` 只留 `labelText` / `hintText` / `prefixIcon` | R1 |
| `lib/features/demo/page/storage_demo_page.dart` | 同上，只留 `labelText` | R1 |
| `test/core/theme/app_theme_test.dart` | `group('主题组装')` 里加 1 条 `test` + 1 条 `testWidgets` | AC3 |
| `lib/core/base/result.dart` | `getOrThrow` 的 doc 注释（`result.dart:20`） | R2 |
| `lib/core/data/network/dio_factory.dart` | doc 注释 `dio_factory.dart:21-22` | R3 |
| `lib/core/data/network/token_store.dart` | doc 注释 `token_store.dart:12-13` 与 `:17` | R3 |
| `lib/core/data/storage/file_storage.dart` | doc 注释 `file_storage.dart:13-14` | R3 |
| `.trellis/spec/data/network-guidelines.md` | 第 17 行表格里的同源表述 | R3 |
| `.trellis/spec/ui/component-guidelines.md` | 「主题层」小节：两条边界规则 → 三条 | R5 |

不新增文件：测试复用已有的 `app_theme_test.dart`，避免触发 `spec/index.md` 的
「增删 `lib/` 文件 → 同步目录树（靠人，没有门禁）」这条人工同步项。

---

## 2. 契约：主题放什么、页面留什么

**主题层**（全局默认，三处的公共部分）：

```dart
inputDecorationTheme: InputDecorationThemeData(
  filled: true,
  fillColor: colorScheme.surfaceContainerLow,
  border: OutlineInputBorder(
    borderRadius: BorderRadius.circular(AppThemeExtension.base.radiusSm),
    borderSide: BorderSide.none,
  ),
),
```

**页面侧**只留控件行为与自己特有的装饰：

| 保留 | 为什么不算装饰 |
|---|---|
| `labelText` / `hintText` | 文案，每个输入框都不同 |
| `prefixIcon` | 图标选择；颜色由主题的 `prefixIconColor` 兜底 |
| `obscureText` / `keyboardType` / `textInputAction` | 控件行为，不是样式 |

即 `InputDecoration(...)` 里头不再出现 `filled` / `fillColor` / `OutlineInputBorder`。

---

## 3. 已核实的 Flutter 事实

本机 SDK 实测 **3.47.2**；`pubspec.yaml` 的 floor 是 `flutter: ">=3.47.0"`，CI 用 `3.47.5`
（`.github/workflows/ci.yml:17,67`）。

1. `ThemeData.inputDecorationTheme` 字段类型已是 `InputDecorationThemeData`
   —— `<sdk>/packages/flutter/lib/src/material/theme_data.dart:1005`。
2. 但构造器与 `copyWith` 收 `Object?`，两种类型都吃，并且会把 legacy 的
   `InputDecorationTheme` 拆成 `.data`（`theme_data.dart:388-398`、`1495-1628`），
   所以 `base.copyWith(inputDecorationTheme: ...)` 可直接传新类型。
3. `InputDecoration.applyDefaults` 对每个字段 `??` 取主题值，`filled` / `fillColor` /
   `border` / `enabledBorder` / `focusedBorder` / `disabledBorder` 都在列
   （`input_decorator.dart` 的 `applyDefaults`）。
4. `TextField.build` 把 `_getEffectiveDecoration()` 交给 `InputDecorator`
   （`text_field.dart:1769`），而它就是
   `(widget.decoration ?? const InputDecoration()).applyDefaults(InputDecorationTheme.of(context))`
   （`text_field.dart:1204-1215`）—— **这就是 AC3 可断言的锚点**：
   `tester.widget<InputDecorator>(find.byType(InputDecorator)).decoration` 拿到的是已经
   合过主题的那份 `InputDecoration`。
5. `InputDecorationThemeData` 是 public class 且经
   `packages/flutter/lib/material.dart:111` 导出。

---

## 4. 决策

**D1 用 `InputDecorationThemeData`，不用 legacy `InputDecorationTheme` 包装类。**
字段本身就是这个类型，SDK 里还留着
`TODO(bleroux): Clean this up once the type of inputDecorationTheme is changed to
InputDecorationThemeData`；floor 3.47.0 已可用。用旧类型不会报错，但会往模板里种一份
快要退役的写法。

**D2 只设 `border`，不设 `enabledBorder` / `focusedBorder` / `disabledBorder`。**
三处页面原本就只写了 `border`，`InputDecorator` 对 enabled / focused 的回退落到 `border`
（事实 3）。补齐四个状态等于给模板增加**从未被验证过的视觉状态**。

**D3 把 `applyBrandOverrides(base.colorScheme)` 提成局部变量。**
主题里的 `fillColor` 必须取自**已过 `applyBrandOverrides`** 的 colorScheme，否则输入框底色
会和 `surfaceContainerLow` 的语义覆盖漂开。做法是在同一次 `base.copyWith` 里既传
`colorScheme:` 也传 `fillColor:`，用局部变量 `final colorScheme = ...` 串起来 —— 不引入
第二次 `copyWith`（多一层等于把「主题被覆盖了几次」变成需要读两遍才知道的事）。

**D4 圆角写 `AppThemeExtension.base.radiusSm`。**
与同文件 `cardTheme` / `chipTheme` / `snackBarTheme` 的现有写法逐字一致，满足
`component-guidelines.md:117-126` 的「`app_theme.dart` 内部不写裸数字」。
`app_theme_extension.dart:12` 的 `radiusSm` 注释已经写着「小圆角：标签、按钮、**输入框**」，
本次是兑现这句话，不改 token 定义。

**D5 R3 的失效指引句直接删掉，不做「改指向」。**
活的 `design.md` 不存在（仓库里只有 `.trellis/tasks/archive/**/design.md` 7 份）。把指引从
一份归档文档改成另一份归档文档没有意义；指向 spec 又会变成「注释转述 spec」。
所以：删掉「见 design X.Y」与「各分支 / Riverpod 分支」这类已不存在的语境，
**保留**注释里真正的「为什么」（`TokenStore` 这层反转的必要性、Mock 规则为什么放在
`dio_client`、`FileStorage` 为什么不带 DI 注解）。

**D6 R5 做成 spec 里的 grep 命令，不做 `app_lints` 规则。**
spec 的「主题层」小节已有两条同形规则（各配一条命令）。第三条：

```bash
grep -rn "OutlineInputBorder\|fillColor" lib/   # 期望：只命中 lib/core/theme/app_theme.dart
```

不做成插件规则的取舍：`app_lints` 七条规则的判据都是 AST 级（见 `cross-cutting.md`），
因为「三件套」「具名实参」「字符偏移」这类判据正则写不出来；而这条判据是**逐字字符串**，
grep 足够且误报率更低。另外「页面永远不得覆写装饰」不是绝对命题，AST 规则会在
派生项目合理地覆写时变成噪音。

---

## 5. 爆炸半径与兼容性

- **全局 `filled: true` + `fillColor` 作用于所有 `InputDecorator`。**
  实测 `grep -rn "TextFormField\|TextEditingController\|SearchBar\|DropdownButtonFormField\|Autocomplete\|InputDecorator" lib/ --include=*.dart` → **无命中**，
  `lib/` 里只有这 3 个 `TextField`。影响面就是它们，且逐字段等价（同一组值换了存放位置），
  视觉不应变化。
- **测试侧无既有断言。** `grep -n "InputDecoration\|fillColor\|OutlineInputBorder\|labelText"` 在
  `test/features/auth/page/login_page_test.dart`、`test/features/demo/page/storage_demo_page_test.dart`
  均无命中，不会有断言被改红 —— 这也是必须新增 AC3 那条测试的原因。
- **不触注解**（无 `@freezed` / `@RoutePage` / `@injectable` / Drift 表改动），codegen 应无漂移；
  仍按仓库约定跑一次确认。
- **spec 文件不受 lint 管辖**（`app_lints` 规则只作用于 `lib/`，见 `cross-cutting.md` 的
  「判据细节：全部规则先过 `context.isInLibDir`」），但 R5 新增的 grep 命令本身要能在当前代码上通过。

---

## 6. 回滚

改动分三簇，可独立回退：

| 簇 | 文件 | 单独回退的后果 |
|---|---|---|
| A 主题 + 页面 + 测试（R1/AC3） | `app_theme.dart`、两个页面、`app_theme_test.dart` | **必须成对回退**：只回退主题会留下「页面不写装饰 + 主题不提供」= 输入框退回 Material 默认外观；只回退页面则重复回来，视觉不变 |
| B 注释（R2/R3） | 5 个 lib 文件 + 1 个 spec | 纯注释，无行为影响，可任意单独回退 |
| C spec 规则（R5） | 1 个 spec | 删掉命令即回退；不影响 `just verify`（spec 不在门禁扫描面内） |

回滚点：A 簇改完并新增测试后、`just verify` 之前是一个天然检查点；B/C 簇不涉及可执行行为，
不需要中间检查点。
