# 执行计划：输入框装饰下沉主题 + 死面 API 与失效注释清理

对应 [prd.md](./prd.md)（R1/R2/R3/R5、AC1-AC8）与 [design.md](./design.md)（D1-D6）。
按顺序执行；每步末尾的验证命令必须真的跑过再看下一步。

---

## 0. 前置检查（改任何东西之前）

```bash
git status --porcelain        # 期望：只有 .trellis/ 下的任务文件（任务元数据未入库）
just codegen                  # 基线确认：现在也无漂移
```

- [ ] 基线 `git status` 里 `lib/`、`test/`、`.trellis/spec/` **零改动**。
      若 `just codegen` 产出改动，先停下 —— 说明基线才有问题，不属于本任务。

---

## 1. R1 主题层：新增 `inputDecorationTheme`

文件：`lib/core/theme/app_theme.dart`

- [ ] 把 `_buildTheme` 里的 `applyBrandOverrides(base.colorScheme)` 提成局部变量
      `final colorScheme = applyBrandOverrides(base.colorScheme);`（design D3）。
- [ ] 在 `base.copyWith(...)` 里：
      - `colorScheme:` 改传上面这个局部变量；
      - 新增 `inputDecorationTheme: InputDecorationThemeData(...)`，
        内容照 design.md §2 的片段（`filled` / `fillColor` / `border`，圆角走
        `AppThemeExtension.base.radiusSm`）。
- [ ] 不加 `enabledBorder` / `focusedBorder` / `disabledBorder`（design D2）。
- [ ] 新增项的注释不超过 1-2 行（`comment_block_too_long` 限连续注释块 ≤10 行）。

验证：

```bash
grep -n "inputDecorationTheme\|InputDecorationThemeData\|OutlineInputBorder\|colorScheme" lib/core/theme/app_theme.dart
just analyze-app
```

- [ ] `analyze-app` 干净。若报 `InputDecorationThemeData` 未定义 → design.md 事实 5 需要重核，
      退路是改用 `InputDecorationTheme(...)`（`copyWith` 两种都收，见事实 2）。

---

## 2. R1 页面侧：删掉重复的装饰

文件：`lib/features/auth/page/login_page.dart`（两处：邮箱框、密码框）、
`lib/features/demo/page/storage_demo_page.dart`（一处）

- [ ] 每个 `InputDecoration(...)` 删掉 `filled: true`、`fillColor: ...`、
      `border: OutlineInputBorder(...)` 三项。
- [ ] 保留 `labelText` / `hintText` / `prefixIcon`，以及 `TextField` 上的
      `obscureText` / `keyboardType` / `textInputAction`（design §2 的表格）。
- [ ] 若删完 `InputDecoration` 只剩一项且短，不要顺手改成位置参数或换写法 ——
      本任务只去重，不改风格。

验证（AC1、AC2）：

```bash
grep -rn "OutlineInputBorder" lib/            # 期望：只命中 lib/core/theme/app_theme.dart
grep -rn "fillColor" lib/                     # 期望：只命中 lib/core/theme/app_theme.dart
grep -rn "InputDecoration(" lib/features/     # 期望：命中数不变，但里面没有上面两项
dart format lib/core/theme/app_theme.dart lib/features/auth/page/login_page.dart lib/features/demo/page/storage_demo_page.dart
```

---

## 3. 新增回归测试（AC3）

文件：`test/core/theme/app_theme_test.dart`，放进已有的 `group('主题组装')`
（紧邻 `test('卡片 / chip / snackBar 的圆角都取自 token')`）

- [ ] 加 1 条 `test`：断言 `buildLightTheme().inputDecorationTheme` 的
      `filled == true`、`fillColor == theme.colorScheme.surfaceContainerLow`、
      `border` 是 `OutlineInputBorder` 且 `borderRadius == BorderRadius.circular(base.radiusSm)`、
      `borderSide == BorderSide.none`。亮暗两份都断言（与同 group 的圆角测试同形）。
- [ ] 加 1 条 `testWidgets`：在 `MaterialApp(theme: buildLightTheme())` 下 pump 一个
      **只带 `labelText`** 的 `TextField`，断言
      `tester.widget<InputDecorator>(find.byType(InputDecorator)).decoration` 的
      `filled == true` —— 这一步才是「装饰真的走了主题」的证明（design.md 事实 4）。
      只断言主题对象字段是不够的：那样测的是 `ThemeData`，不是页面拿到的合过默认值的装饰。

验证：

```bash
flutter test test/core/theme/app_theme_test.dart
flutter test test/features/auth/page/login_page_test.dart test/features/demo/page/storage_demo_page_test.dart
```

- [ ] 全绿。**这一步全绿之前不要进入第 4 步** —— 这是 design.md §6 说的回滚检查点。

---

## 4. R2：修正 `getOrThrow` 的注释

文件：`lib/core/base/result.dart`（第 20 行前后）

- [ ] 把「取成功值；在 [Err] 上会抛 [StateError]，只用于测试」改成与事实一致的表述：
      它是**给调用方就近取值用的逃生口**，当前仓库无调用点（`grep` 结果），
      不要在注释里声称测试在用。
- [ ] `mapError` / `flatMap` / `isSuccess` 一行不动（R2 的决定：API 全留）。

验证（AC7）：

```bash
grep -rn "mapError\|flatMap\|getOrThrow" lib test --include=*.dart
grep -rn "只用于测试" lib/core/base/result.dart    # 期望：无命中
```

---

## 5. R3：清理 5 处失效引用

文件与锚点见 design.md §1。逐处按 D5 处理：删掉失效指引与已不存在的语境，保留「为什么」。

- [ ] `lib/core/data/network/dio_factory.dart:21-22` —— 保留「不知道 signals / Riverpod 的
      存在」想表达的**解耦意图**，改成不依赖「有多个分支」这个前提的说法；
      删掉「归各分支的装配层（见 design 6.5）」。
- [ ] `lib/core/data/network/token_store.dart:12-13` —— 删掉「各分支」「Riverpod 分支」，
      保留「网络层只需要读写令牌这一组能力」这个**反转的动机**。
- [ ] `lib/core/data/network/token_store.dart:17` —— 删掉「见 design.md 6.1」；
      该 doc 里「本文件不得 import `auth_interceptor.dart` / `token_refresher.dart`（循环依赖）」
      这句是**真实约束**，必须留着。
- [ ] `lib/core/data/storage/file_storage.dart:13-14` —— 删掉「各分支的装配层」，
      保留「本包不依赖 injectable / get_it」与 `lib/core/core_module.dart` 这个真实位置。
- [ ] `.trellis/spec/data/network-guidelines.md:17` —— 表格里
      「不知道 signals / Riverpod 的存在」改成与 lib 一致的表述，**同一句话两处必须同批改**。

验证（AC5、AC6）：

```bash
grep -rn "design 6.5\|design\.md 6.1" lib/     # 期望：无命中
grep -rn "各分支\|Riverpod 分支" lib/          # 期望：无命中
grep -rn "Riverpod" .trellis/spec/             # 期望：无命中（docs/optional-additions.md 不在范围）
just analyze-app                               # comment_block_too_long 必须仍然干净
```

---

## 6. R5：给主题层补第三条边界规则

文件：`.trellis/spec/ui/component-guidelines.md`（「主题层」小节的「两条边界规则」处）

- [ ] 小标题「两条边界规则（各配一条命令，破了就能看出来）」→「三条边界规则（……）」。
- [ ] 在第 2 条规则之后追加第 3 条，格式与现有两条一致（一句为什么 + 一条命令 + 期望输出）：
      输入框装饰只写在主题层，页面只留文案与控件行为。
- [ ] 命令用 design.md D6 里那条：

```bash
grep -rn "OutlineInputBorder\|fillColor" lib/   # 期望：只命中 lib/core/theme/app_theme.dart
```

- [ ] 该命令**现在跑一次必须通过** —— 不能写一条必然失败的规则（AC8）。

---

## 7. 全量验证（AC4）

```bash
just codegen        # 确认无漂移（本次不触注解）
just verify         # fmt-check + analyze-app + analyze-tool + test-app-lints + test
```

- [ ] 两条都退出码 0，且 `git status --porcelain` 里 codegen 没有新增/改动生成物。
- [ ] 若 `fmt-check` 失败：跑 `dart format lib test` 再来，不要用 `--no-verify` 绕。

---

## 8. 逐条核对 AC

- [ ] AC1 `grep -rn "OutlineInputBorder" lib/` / `grep -rn "fillColor" lib/` 只命中 `app_theme.dart`
- [ ] AC2 两个页面的 `InputDecoration` 里没有 `filled: true` / `fillColor:` / `OutlineInputBorder`
- [ ] AC3 `app_theme_test.dart` 的两条新测试存在且能证明「合过主题」
- [ ] AC4 `just codegen` + `just verify` 全绿
- [ ] AC5 `design 6.5` / `design.md 6.1` / `各分支` 在 `lib/` 无命中
- [ ] AC6 `comment_block_too_long` 仍干净
- [ ] AC7 `result.dart` 不再声称 `getOrThrow` 只用于测试
- [ ] AC8 第三条边界规则存在，小标题已改，命令当前可过
- [ ] 未触碰 Out of Scope 里列出的任何一项（`EmptyWidget`/`ErrorText` 骨架、渐变 Container、
      `FlexThemeData` 两份参数、`runAsync` 三函数、任何运行时行为）

---

## 9. 收尾

- [ ] `.trellis/spec/ui/component-guidelines.md` 已改 → 看是否需要同步
      `spec/index.md` 的「完成前自检」清单（本次只加一条规则，预计不需要）。
- [ ] 无新增 `lib/` 文件 → 不需要同步 `README.md` / `directory-structure.md` 目录树。
- [ ] 提交前把本任务的 `prd.md` / `design.md` / `implement.md` 一并留档（任务元数据未入库）。

---

## 风险与回滚点

| 风险 | 触发信号 | 处置 |
|---|---|---|
| `InputDecorationThemeData` 在 floor 3.47.0 上不可用 | 第 1 步 `analyze-app` 报未定义 | 改用 `InputDecorationTheme(...)`（design 事实 2 已确认两种都收）；同步修 design.md 事实 5 |
| 主题的 `filled: true` 影响到了预期外的控件 | 第 7 步 `test` 有页面测试变红（含截图类断言） | 先看是哪个页面；`lib/` 里只有 3 个 `TextField`（design §5），超出这个范围说明前提有误，回 Plan |
| 改注释时把「为什么」也删了 | 第 5 步 review 时发现 doc 只剩一句「不得 import X」没有理由 | 按 R3 的「不丢失原本承载的信息」补回动机（这是本任务最容易出的错） |
| 页面改动引入视觉差异 | 人工跑 `just run` 看登录页 / 示例页 | 先 diff 主题里的值与页面里原来的值是否逐字段等价（design §5） |

**回滚点**：第 3 步结束、第 7 步之前 —— 此时 R1 已完成且有测试保护，回退用
`git checkout -- lib/core/theme/app_theme.dart lib/features/auth/page/login_page.dart
lib/features/demo/page/storage_demo_page.dart test/core/theme/app_theme_test.dart`（A 簇必须成对回退）。
