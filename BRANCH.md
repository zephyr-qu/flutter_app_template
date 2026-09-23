# BRANCH.md — `preset/ai-starter`

> 这是一条**兄弟分支**，不回流 `master`。读完这份就能知道它和 `master` 差在哪、
> 哪些差异是刻意的、以及为什么两边不能合并。

---

## 它是什么

| | |
|---|---|
| 分支 | `preset/ai-starter` |
| 基点 | `master` @ `4150ee6`（2026-09-22） |
| 目的 | 把状态管理 / 依赖注入 / 页面组合换成 **AI 语料最丰富的主流栈**，并让仓库对 AI 自足——任何 AI 工具打开即可在边界内产出符合规范的代码 |
| 与 `master` 的关系 | 兄弟分支。两个栈无法互相合并，强行回流会互相覆盖 |
| 共用资产 | `packages/app_core`（两栈**完全一致**，见下） |

重新量差异规模：

```bash
git diff master --shortstat                 # 文件 / 行数
git diff master --stat -- packages/         # 应为空：共享包零改动
git rev-list --count master..HEAD           # 提交数
```

---

## 换掉了什么（只有三件事）

| 能力 | `master` | 本分支 |
|---|---|---|
| 状态管理 | `signals` / `signals_flutter` / `signals_hooks` | **`flutter_riverpod` 3.4.3** + `riverpod_annotation` 4.0.7（生成器 `riverpod_generator` 4.0.9） |
| 页面组合 | `flutter_hooks` + `HookWidget` / `useMemoized` / `useSignalValue` | `ConsumerWidget` / `ConsumerStatefulWidget` + `ref.watch` / `ref.listen` |
| 依赖注入 | `get_it` + `injectable`(+generator)，整个 `lib/di/` | **Riverpod provider** + `ProviderScope(overrides:)`，`lib/di/` 整体消失 |

围绕这三件事的连带改动：

- 没装 `custom_lint` / `riverpod_lint`：所有版本要么与项目的 `analyzer` 13.3.0 冲突，
  要么走 `analysis_server_plugin`（IDE-only）。本仓库的立场是**门禁逻辑一律是脚本**，
  装一个只在 IDE 生效的 lint 会造出「有门禁」的错觉。代价是 provider 命名一类的事
  没有 lint 兜（`riverpod_generator` 把 `XxxNotifier` 命名成 `xxxProvider`，写页面时容易踩）。
- `features/article/` 与 `features/demo/` 的业务内容删掉，收敛成一个 **`features/sample/`**
  金标准：它同时覆盖三种 data 形态（Retrofit API / Drift DAO / `Result` 包装的 Service）
  与三种 provider 形态，是 AI 唯一需要照抄的对象。
- `.trellis/spec/` 与 `docs/` 的 Riverpod 口径重写；`docs/adr/ADR-0001.md`、`ADR-0002.md`、
  `docs/architecture-review.md` **正文一字未动**，只在顶部加了「仅对 master 成立」的适用范围框。
- 门禁脚本按 Riverpod 调口径（见下）。
- `.agents/skills/` 的技能目录：删掉 signals 系与栈冲突的 `flutter-*`，
  换成 `riverpod-*` 系列（来源 `serverpod/skills-registry`，记录在 `skills-lock.json`）。
- `.cursor/rules/` 只留 `project-conventions.mdc`（总纲 + 指路），
  其余 5 个规则文件是 spec 的复制品且已整份过期，随本次换栈删掉。

---

## 明确**没有**换的（不是漏做）

| 项 | 状态 | 理由 |
|---|---|---|
| 主题 `flex_color_scheme` | **保留** | 它只存在于 `packages/app_core`（pubspec + `theme/`），根工程一处都没引用。换它等于改共享包，而「共享包两栈完全一致」正是抽包换来的东西；为一件与状态管理正交的事拆掉它，收益为负 |
| `auto_route` | 保留 | 本身已是主流，换 `go_router` 要重写路由 + 守卫 + 全部 `@RoutePage`，收益不足 |
| `dio` + `retrofit` | 保留 | 同上 |
| `freezed` + `json_serializable` | 保留 | 同上 |
| `drift` / `shared_preferences` / `flutter_secure_storage` | 保留 | 同上 |
| l10n | **不涉及** | 基线（`master`）就已经没有 l10n —— 它被 `09-22-prune-l10n` 裁掉了。本分支的换栈范围里从来没有这一项，别把它当成「砍掉了」 |
| `packages/app_core` | **零改动** | 它是两栈共用的基础设施包。`tool/check_boundaries.dart` 里有一条专门的门禁：「包内不得出现 `signals_*` / `riverpod*` / `get_it` / `injectable`」——这条同时服务两个栈，也保证了两个分支的这个包永远一致 |

---

## 为什么不回流 `master`

`signals` 与 Riverpod 的写法没有一一对应的机械映射（`signal`/`computed`/`effect` 与
`Ref`/`Notifier`/`AsyncValue` 是两套模型），强行合并只会两边互相覆盖。所以两条分支各自
背负一套栈，靠**共享包 + 门禁规则**维持「基础设施只有一份」。

---

## CI 与提交约定

- **CI 的触发分支仍然是 `branches: [master]`**，有意**不**加 `preset/*`（2026-09-23 决定）。
  含义：推本分支不会跑任何 CI job。
- 因此本分支的**六道门禁只有本地那一层**。提交约定是 `git commit --no-verify` +
  **手工跑完整个命令块**（本地 pre-commit 在 Windows 上单次约 20 分钟，每次 `dart run`
  都被 sqlite3 的 build hook 拖住）——关掉钩子换来的是「必须自己跑并报出结果」的义务，
  不是「可以不跑」。完整命令块见 `AGENTS.md` 的 `## 改完必跑`。
- 生效一次本地钩子：

  ```bash
  git config core.hooksPath .githooks
  ```

- 残余风险（知道就行）：本分支没有 CI 兜底，回归只能靠本地那一次跑。想改这个决定，
  改 `.github/workflows/ci.yml` 的 `on.push.branches` 即可。

---

## 六道门禁（脚本，不是 IDE 插件）

```bash
dart format --output=none --set-exit-if-changed lib test tool packages
dart run tool/check_boundaries.dart        # 架构边界（lib + packages/app_core/lib）
dart run tool/check_conventions.dart       # build 里禁 ref.read 取值 / 注释块上限
dart run tool/check_readme_tree.dart       # README ×2 + spec 的目录树
dart run dependency_validator              # 声明与使用一致
flutter analyze lib/ test/
dart analyze tool/ && dart analyze packages/
flutter test --coverage
(cd packages/app_core && flutter test --coverage)
dart run tool/check_coverage.dart coverage/lcov.info packages/app_core/coverage/lcov.info \
  --src=lib --src=packages/app_core/lib   # 阈值 80%，两份 lcov 各自校验
```

规则语义、阈值与「为什么这么做」都在
[`.trellis/spec/cross-cutting.md`](.trellis/spec/cross-cutting.md)。
