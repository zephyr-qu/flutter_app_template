# 盲测 DoD 的执行材料

> 这是 `preset/ai-starter` 的**核心验收**（PRD 的 Acceptance Criteria 第一条）：
> 新会话 AI 在无人解释下新增一个 feature，并通过全部六道门禁，且结构与 `features/sample/` 一致。
> **不达标则本任务未完成**——回到阶段 7 补 spec，不要改判定标准。
>
> 执行必须由**另一个 AI 会话**（不含本任务的任何上下文）完成。下面是可以直接复制的 prompt。

---

## 0. 先准备一个隔离副本

别在 `preset/ai-starter` 的工作区里跑：AI 会改一堆文件，和本分支的改动混在一起就分不清了。

```bash
git clone "e:/code/rust/flutter_app_template" "$TEMP/blind-test-ai-starter"
cd "$TEMP/blind-test-ai-starter"
git switch preset/ai-starter          # clone 后仍在同一分支；确认 HEAD 是收尾那次提交
flutter pub get
```

跑完直接删掉那个目录即可。要重测就重新 clone（**不要**在原副本上原地重试——第一次的残留会误导第二次）。

---

## 1. 两个版本，先跑 A 再跑 B

| 版本 | prompt 里是否提示 `features/sample/` 与门禁 | 测的是 |
|---|---|---|
| **A（严格盲测）** | 不提示 | 仓库**自足性**：AI 能不能自己从 `AGENTS.md` / `.cursor/rules/` / spec 找到规范与门禁 |
| **B（PRD 字面）** | 明说要与 `features/sample/` 一致、要通过全部门禁 | 照抄对象是否**够用**（B 通过而 A 不通过 → 问题在「入口不够显眼」，不是规范缺失） |

先跑 A。A 通过就不用跑 B 了。

---

## 2. Prompt A（严格盲测 —— 只给需求）

```text
当前目录是一个 Flutter 项目。请新增一个「待办事项」feature：

- 列表页：从后端拉取待办列表，支持下拉刷新；请求失败时要能在页面上重试
- 列表数据落到本地数据库；断网时先显示本地缓存，并在界面上体现数据来源是缓存
- 点列表项进入详情页，详情页只显示单条待办的完整信息
- 在主导航里给出入口（底部标签或首页快捷入口，跟着现有做法走）
- 补齐测试

做完告诉我你改了哪些文件、以及怎么验证的。
```

## 3. Prompt B（PRD 字面 —— 给出验收口径）

在上面那段末尾追加：

```text
补充要求：新 feature 的目录结构与 lib/features/sample/ 保持一致，
并且要通过这个项目自己的全部门禁。
```

---

## 4. 回头看什么（不要只看「能不能编译」）

| 观察点 | 期望 | 不通过说明 |
|---|---|---|
| 有没有自己找到 `.trellis/spec/` 与门禁 | 是。`AGENTS.md` 的「必读三份」「改完必跑」应当被读到 | 入口不够显眼 → 改 `AGENTS.md` 的位置/措辞 |
| 有没有写出 signals / `getIt` / `HookWidget` / `useSignalValue` / `AppLocalizations` | 没有 | 仓库里还有残留的旧口径 → 定位是哪个文件把它带偏的 |
| provider 形态 | 与 sample 的三种形态对得上（顶层 provider / 同步 `Notifier` / `AsyncNotifier`） | spec 的「三种 Provider 形态」不够可操作 |
| 三态渲染 | 用 `AsyncView`，不是 `AsyncValue.when` | 这条是约定不是门禁，最容易漂 |
| 错误分支测试 | 有（把页面驱动到 error 态），不是只测 happy path | `quality-guidelines.md` 的 Testing Requirements 不够醒目 |
| 有没有手工改 `*.g.dart` 或忘提交生成物 | 没有 | codegen 纪律没传达到 |
| 有没有往页面加 `final Xxx? viewModel;` 注入点 | 没有 | 退役的 ADR 缓解措施被当成了规范 |
| 有没有为了过门禁而下调阈值 / 加豁免 | 没有 | 性质最严重的一条，直接判不通过 |

**逐条把「卡在哪」记下来**：卡住的点就是 spec 的缺口，写清楚「AI 在哪一步做错了什么」，
比写「失败」有用得多。

---

## 5. 六道门禁核对清单

在副本里跑（与 `AGENTS.md` 的 `## 改完必跑` 一致）：

```bash
dart format --output=none --set-exit-if-changed lib test tool packages
dart run tool/check_boundaries.dart
dart run tool/check_conventions.dart
dart run tool/check_readme_tree.dart
dart run dependency_validator
flutter analyze lib/ test/
dart analyze tool/ && dart analyze packages/
flutter test --coverage
(cd packages/app_core && flutter test --coverage)
dart run tool/check_coverage.dart coverage/lcov.info packages/app_core/coverage/lcov.info \
  --src=lib --src=packages/app_core/lib
```

> Windows 上每次 `dart run` 都会被 sqlite3 的 build hook 拖住，整套跑完要 20 分钟量级。
> 这是预期的，不是卡死。

| # | 门禁 | 退出码 | 备注 |
|---|---|---|---|
| 1 | `dart format --set-exit-if-changed` | | |
| 2 | `check_boundaries` | | |
| 3 | `check_conventions` | | |
| 4 | `check_readme_tree` | | 新增了目录却没更新 README 的树，这一步会红 |
| 5 | `dependency_validator` | | |
| 6 | 覆盖率（含 `--src` 差集） | | 新文件没测会被算进分母 |
| 7 | `flutter analyze lib/ test/` | | |
| 8 | `dart analyze tool/ packages/` | | |

---

## 6. 结果记录（执行后填这里）

> 留空 = 尚未执行。**这条不填，本任务不算完成。**

| 项 | 结果 |
|---|---|
| 执行日期 | |
| 副本路径 | |
| 用的版本（A / B） | |
| 新增的 feature 名 | |
| 六道门禁 | |
| DoD 四条（AGENTS.md） | |
| 结论（通过 / 卡在哪） | |

### 卡住的地方（逐条）

1.

### 由此需要的 spec 改动（回到阶段 7 补，然后重测）

1.
