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
| 结构 | **单包**（`lib/`）。`master` 的 `packages/app_core` 共享包在本分支已拍平回 `lib/core/`（见下） |

重新量差异规模：

```bash
git diff master --shortstat                 # 文件 / 行数
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
- **`packages/app_core` 拍平回 `lib/core/`**（2026-09-23）：抽包的原始理由是「signals /
  Riverpod 双栈共用」，但本仓库是**脚手架**、不会长期演化，双栈同步的前提不成立；且抽包已经
  产生实际代价——`drift#3669` 让 Drift 表跨 package 解析不到，`SampleDao` 被迫放弃
  idiomatic 的 `@DriftAccessor`。拍平后本分支回到单包结构，`SampleDao` 恢复 `@DriftAccessor`。
  （`master` 仍是双包结构，不动。）

---

## 明确**没有**换的（不是漏做）

| 项 | 状态 | 理由 |
|---|---|---|
| 主题 `flex_color_scheme` | **保留** | 它只在 `lib/core/theme/` 用（抽包时曾随共享包走，拍平后回到 `lib/core/`）。与状态管理正交，换它是独立议题，收益为负 |
| `auto_route` | 保留 | 本身已是主流，换 `go_router` 要重写路由表 + 全部 `@RoutePage`，收益不足 |
| `dio` + `retrofit` | 保留 | 同上 |
| `freezed` + `json_serializable` | 保留 | 同上 |
| `drift` / `shared_preferences` | 保留 | 同上 |
| l10n | **不涉及** | 基线（`master`）就已经没有 l10n —— 它被 `09-22-prune-l10n` 裁掉了。本分支的换栈范围里从来没有这一项，别把它当成「砍掉了」 |

---

## 另外删掉的：认证功能（2026-09-23）

本分支把**整条认证链路**删掉了：

| 删了什么 | 具体 |
|---|---|
| 登录流程 | `features/auth/**`（登录页 / API / Service / Repository / Notifier / 模型） |
| 令牌 | `TokenSet`、`AuthStorage`、`flutter_secure_storage` 依赖 |
| 401 自动刷新 | `AuthInterceptor`、`TokenRefresher`、`TokenStore`、`auth_extra_keys` |
| 登录态与守卫 | `core/auth/session.dart`、`core/models/user.dart`、`auth_reevaluate.dart`、路由守卫 |

结果：**无登录脚手架**，冷启动「启动页（2.2s）→ 主框架」，所有路由公开；首页 / 个人中心里原本显示
用户名、头像、退出登录的位置改成静态品牌信息。

理由：脚手架是**起点**而不是成品。认证是每个目标 App 都会自己重做一遍的东西（后端形状、令牌轮换
策略、是否走 SSO 各不相同），预置一套的代价是「先读懂再删掉」。加回来的步骤见
[docs/optional-additions.md](docs/optional-additions.md) 的「登录 / 认证」。

> 与 `master` 的差异：`master`（signals 栈）仍带完整认证，这一条只对本分支成立。

---

## 为什么不回流 `master`

`signals` 与 Riverpod 的写法没有一一对应的机械映射（`signal`/`computed`/`effect` 与
`Ref`/`Notifier`/`AsyncValue` 是两套模型），强行合并只会两边互相覆盖。所以两条分支
各自背负一套栈。

---

## CI 与提交约定

- **CI 的触发分支仍然是 `branches: [master]`**，有意**不**加 `preset/*`（2026-09-23 决定）。
  含义：推本分支不会跑任何 CI job。
- 因此本分支的**门禁只有本地那一层**。提交约定是 `git commit --no-verify` +
  **手工跑完整个门禁块** —— 关掉钩子换来的是「必须自己跑并报出结果」的义务，
  不是「可以不跑」。门禁块现在是一条命令：

  ```bash
  dart run tool/verify.dart
  ```

  （它按顺序跑 9 项、首个失败即停。4 道脚本门禁在同一个进程里，省掉 3 次 `dart run`
  的 VM 启动与 sqlite3 build hook —— 只快几秒，收益主要是「只记一条命令」+「早停」。
  完整清单见 `AGENTS.md` 的 `## 改完必跑`。）
- 生效一次本地钩子：

  ```bash
  git config core.hooksPath .githooks
  ```

- 残余风险（知道就行）：本分支没有 CI 兜底，回归只能靠本地那一次跑。想改这个决定，
  改 `.github/workflows/ci.yml` 的 `on.push.branches` 即可。

---

## 门禁（脚本，不是 IDE 插件）

```bash
dart run tool/verify.dart                 # 全套，首个失败即停
```

单项重跑用下面的原始命令（`verify.dart` 转发给的就是它们）：

```bash
dart format --output=none --set-exit-if-changed lib test tool
dart run tool/check_boundaries.dart        # 架构边界（lib）
dart run tool/check_conventions.dart       # build 里禁 ref.read 取值 / 注释块上限
dart run tool/check_readme_tree.dart       # README + spec 的目录树
dart run dependency_validator              # 声明与使用一致
flutter analyze lib/ test/
dart analyze tool/
flutter test --coverage
dart run tool/check_coverage.dart coverage/lcov.info --src=lib   # 阈值 80%
```

规则语义、阈值与「为什么这么做」都在
[`.trellis/spec/cross-cutting.md`](.trellis/spec/cross-cutting.md)。
