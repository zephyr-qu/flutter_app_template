# Journal - zs (Part 1)

> AI development session journal
> Started: 2026-07-08

---

## 2026-07-08: Bootstrap Guidelines — Completed

**Summary**: Filled all 11 spec files for the P1 Bootstrap Guidelines task.

**Backend (data layer) — 5 files**:

- `directory-structure.md` — Clean Architecture feature-first layout with layer dependency rules
- `database-guidelines.md` — SharedPreferences + FileStorage patterns (no SQLite)
- `error-handling.md` — Result<T,E> sealed class, Failure hierarchy, DioException→Failure conversion
- `logging-guidelines.md` — `logger` package facade with 4 levels, what to log/not log
- `quality-guidelines.md` — Forbidden patterns, DI annotations, code review checklist

**Frontend (UI layer) — 6 files**:

- `directory-structure.md` — Feature page organization, shared widgets
- `component-guidelines.md` — Flutter widget patterns, Theme-based styling, three-state rendering
- `hook-guidelines.md` — flutter_hooks usage (app root only), ViewModel pattern for state
- `state-management.md` — Signals + BaseViewModel pattern, async/sync/derived state categories
- `type-safety.md` — Dart sealed classes, @JsonSerializable, generated code patterns
- `quality-guidelines.md` — UI-layer forbidden patterns, code review checklist, linter rules

All specs reference real code paths and examples from the actual codebase (no aspirational/placeholder content).

---


## Session 1: P0 Scaffold Quality Audit and Fix

**Date**: 2026-07-08
**Task**: P0 Scaffold Quality Audit and Fix
**Branch**: `master`

### Summary

Completed full P0 quality audit: R1 LoginPage memory leak (Stateless→StatefulWidget), R2 ArticleDetailPage type-safe routing + body field, R3 FileStorage @Singleton annotation, R4 systematic audit (Profile Chinese template, runAsync helper, disposed guards, rename checklist), R5 spec updates for personal scaffold vision. All fixes pass flutter analyze with zero errors.

### Main Changes

(Add details)

### Git Commits

| Hash | Message |
|------|---------|
| `3032915` | (see git log) |

### Testing

- [OK] (Add test results)

### Status

[OK] **Completed**

### Next Steps

- None - task complete


## Session 2: Dependency upgrade: signals v7 + signals_lint

**Date**: 2026-07-08
**Task**: Dependency upgrade: signals v7 + signals_lint
**Branch**: `master`

### Summary

Upgraded 59+ dependencies: signals_flutter 6→7 (Watch.builder→SignalBuilder), injectable 2→3, analyzer 10→13, flutter_gen 5.12→5.14, and many more. Added signals_lint 7.1 via analysis_server_plugin. Fixed deprecated onDispose→EffectOptions API. All flutter analyze zero issues.

### Main Changes

(Add details)

### Git Commits

| Hash | Message |
|------|---------|
| `0993b51` | (see git log) |

### Testing

- [OK] (Add test results)

### Status

[OK] **Completed**

### Next Steps

- None - task complete


## Session 3: Extract lib/app/ layer, flatten core/ui, record architecture review

**Date**: 2026-09-21
**Task**: Architecture review follow-up — app layer + ui flattening
**Branch**: `master`

### Summary

Extracted an explicit `lib/app/` application layer (composition root) and flattened `core/presentation/` into `core/ui/`, then recorded a full architecture review (`docs/architecture-review.md`) with the current status of every finding. The review corrected one of its own conclusions: the "ViewModel needs dispose" finding was a false alarm, and the suggested fix would have introduced a runtime exception.

### Main Changes

**Structure**

- Added `lib/app/` — `app.dart`, `routing/` (router.dart, router.gr.dart, auth_reevaluate.dart), `pages/` (splash_page.dart, not_found_page.dart)
- Removed `lib/app.dart`, `lib/routing/`, `lib/core/presentation/pages/`
- Flattened `lib/core/presentation/` → `lib/core/ui/` (parallel to `core/theme/`); moved `test/core/presentation/` → `test/core/ui/`
- Global pages now use typed routing instead of string paths: `replacePath('/')` → `replaceRoute(const MainRoute())` / `const LoginRoute()`

**Tooling**

- `tool/check_boundaries.dart` — `compositionDirs` `['lib/routing/']` → `['lib/app/']`; rule 1 target changed to `lib/app/`; removed `compositionFiles`
- `tool/init_project.dart` — rewrites `lib/app/app.dart`

**Tests**

- Updated imports in 5 feature pages, 3 test files, and the boundary-checker test cases
- `test/core/ui/failure_message_test.dart` (migrated)

**Docs**

- New `docs/architecture-review.md` — P1–P7 findings with per-item status and source-level evidence
- `docs/adr/ADR-0001.md` / `ADR-0002.md` — "关联候选" now links to the review; ADR-0002 gained the dispose boundary condition
- `.trellis/spec/frontend/state-management.md` — new section "什么时候才需要 dispose（上一条的边界）"
- `README.md`, `AGENTS.md`, `docs/optional-additions.md`, and 4 spec files synced to the new paths

### Review Findings (status)

- **P1 ViewModel dispose** — **false alarm, retracted.** `signals_core` / `signals_flutter` have no `FlutterMemoryAllocations` integration (grep: 0 matches), so `leak_tracker` cannot see signals; `useSignalValue` → `SignalHookState.dispose()` unsubscribes correctly, so the VM + its signals form a collectable island. Worse, adding `vm.dispose()` would throw `SignalsWriteAfterDisposeError` (from `Signal.set`) when an in-flight response lands after the page is popped.
- **P4 boundary check is regex-based** — **partially valid.** Only conditional-import branches are a real gap; `part` and `.config.dart` are model-incompleteness that is not currently exploitable.
- **P5 runAsync lacks request de-duplication** — **resolved** prior to this session (`Expando<int> _latestCallId` + `AsyncState.dataRefreshing`).
- **P7 global page placement / string paths** — **resolved** by the `lib/app/` extraction in this session.
- **P2 / P3 / P6** — still valid, but long-term governance rather than defects.

### Git Commits

(No commits - planning session)

### Testing

- [SKIP] Cannot run in this environment — `flutter` and `dart` are not on PATH (verified with `where.exe`). Static edits only.
- Verification left to the user: `dart run tool/check_boundaries.dart`, `flutter analyze lib/ test/`, `dart analyze tool/`, `flutter test`
- `build_runner` is NOT required: `router.gr.dart` is a `part` file whose content is path-independent, and the DI config does not reference `app/` or `routing/`

### Status

[P] **Blocked** — pending local verification

### Next Steps

- Run the four verification commands above and fix any import left behind
- When conditional imports (`if (dart.library.…)`) are first used, migrate `check_boundaries.dart` to `package:analyzer`'s AST API


## Session 4: 补齐 app_core 覆盖率分母（差集检查 + 纯包测试）

**Date**: 2026-09-22
**Task**: 补齐 app_core 覆盖率分母（差集检查 + 纯包测试）
**Branch**: `master`

### Summary

给覆盖率门禁补上差集检查：扫描根下的手写文件减去 lcov 的 SF 集合，差集按 0 命中 / 非空行数计入分母，结构上无可执行行的走 loadingExemptions 并逐条写理由。网络层测试迁入 app_core 改成纯包测试（手写 FakeTokenStore / FakeTokenRefresher 替代 mocktail），并补 dio_factory / database / theme / ui / token_set 与根组件 test/app/app_test.dart。结果：根 89.4%（33 文件，6 豁免）、包 89.8%（18 文件，2 豁免），包内测试 44 -> 104。附带发现：pre-commit 钩子单次约 20 分钟，根因是每个 dart run 都触发 sqlite3 的 build hook。

### Main Changes

(Add details)

### Git Commits

| Hash | Message |
|------|---------|
| `163d2a1` | (see git log) |
| `f88f0b2` | (see git log) |
| `dd41ac8` | (see git log) |
| `8a3b6e4` | (see git log) |
| `4e68ee3` | (see git log) |

### Testing

- [OK] (Add test results)

### Status

[OK] **Completed**

### Next Steps

- None - task complete


## Session 5: 10-09 → 10-12 批次补记：.git 事故恢复、删 integration_test、skills 策略落定

**Date**: 2026-10-12
**Task**: 10-09 → 10-12 批次补记：.git 事故恢复、删 integration_test、skills 策略落定
**Branch**: `master`

### Summary

本条目为**批次补记** —— 上个 journal 提交（`4150ee6`，2026-09-22）之后的 38 个提交没有逐次记录，这里一次补齐（09-27 → 10-12）。

最重的一段是 **2026-10-12 的 `.git` 事故**：本仓库原为 linked worktree，`.git` 实体所在的主仓目录被删除，17 个未推送提交的历史丢失（**内容零丢失**）。已克隆远端接管 `.git` 并按净效果重建提交，全部已推送。

### Main Changes

本条目覆盖 `4150ee6`（2026-09-22）之后到 10-12 的全部 38 个提交。**只有 10-12 这一天是逐条记录的**；
更早的 30 个（09-27 → 10-09）当时没记录，下面按主题概览补齐。

#### 10-12（逐条）

- **`.git` 丢失与恢复**（`f575e61` `f5dfcb8`）：原仓库是 linked worktree，`.git` 实体在
  `F:\App\新建文件夹\flutter_app_template\.git\worktrees\flutter_app_template`，该目录
  2026-10-12 15:06–15:09 被删除且**未进回收站**。远端 `master` 停在 `ced6626`，17 个本地提交
  在任何远端 ref 上都不存在（逐个 `ls-remote` 核对过），**提交边界与消息不可恢复**；工作区文件
  **零丢失**（内容等于 `ace3565` 那棵树）。恢复方式：克隆远端、把 clone 的真 `.git` 目录接管进
  本目录，再按净效果重建两个提交（内容 + 任务记账）。原 worktree 指针备份在
  `F:/App/flutter_app_template.gitdir-pointer.bak` —— 若哪天把主仓从备份/卷影副本找回，凭它可接回
  那 17 个提交的真实历史。教训：**linked worktree 的存活依赖主仓目录；本地提交不推等于没有备份。**
- **删掉 `integration_test` 端到端冒烟**（`020235d`）：目录、`just e2e`、CI 的 `integration-test` job
  （Android 模拟器 + KVM）、`integration_test` 依赖声明，以及 README / release-checklist / spec ×4 /
  `.cursor` 规则里的全部引用。原「集成测试」节里两块**不属于**集成测试的内容拆成独立小节保留
  （`## Android 依赖仓库镜像`、`## widget 测试里不要用真实 I/O`）。代价已如实记入提交消息：
  **真机/真引擎启动那一层不再有自动化覆盖**。端到端需要时按 `docs/optional-additions.md` 上 `patrol`。
- **`.agents/skills` 入库策略定为「随仓库分发的资产」（方案 B）**（`ade6977` `1cde4f0` `c8fc71b`）：
  方案 A（内容不入库、只留 lock）被否，因为前提不成立 —— `orca` 不在 PATH、仓库里无任何东西读
  `skills-lock.json`、且 lock 与磁盘已不一致（28 条 vs 27 个目录，`signals_hooks` 那条指向不存在的
  路径）。README 写清来源三仓库（`dart-lang/skills` 12、`flutter/skills` 10、`rodydavis/signals.dart` 6）
  与更新方式；`AGENTS.md` 托管块内那句描述跟着改。
- **10-12 任务的规划与收窄**（`d81ed5f` `3604193`）：`integration_test` 删除后，其触发点消失，
  收窄为 R2–R5 的**纯预防性断言**（顶层目录覆盖完整性 + root 产出非空）。

#### 09-27 → 10-09（未记录批次的主题概览，30 个提交）

- **单包化**：拍平 `packages/app_core` 回 `lib/core`；生成物不入库、忽略规则收敛；env 走编译期注入
  —— 后来又回到 dotenv 口径
- **门禁换代**：`app_lints` 分析插件接管架构边界与代码形态规则（新增 `no_material_import_in_logic`）；
  门禁收敛为一条 `just verify`；覆盖率**不再**设门禁；`pre-commit` 两处修复（生成物备份改用真实 git
  目录、stash pop 失败不再静默放行）
- **文档治理**：spec 层目录按主题改名 `backend/frontend` → `data/ui`；spec 索引收敛为单入口；
  新增文档链接门禁（`tool/check_doc_links.dart`）与锚点报告工具；删 `BRANCH.md` 与失效的架构评估快照；
  README 精简 322 → 114 行
- **分支与任务**：分支收敛为 `master` + `preset/ai-starter` 两条；归档 09-22 / 09-29 各任务；
  依赖升级（含 6 个 dependabot PR 与 `pub upgrade`）


### Git Commits

| Hash | Message |
|------|---------|
| `3604193` | (see git log) |
| `c8fc71b` | (see git log) |
| `1cde4f0` | (see git log) |
| `ade6977` | (see git log) |
| `020235d` | (see git log) |
| `d81ed5f` | (see git log) |
| `f5dfcb8` | (see git log) |
| `f575e61` | (see git log) |
| `ced6626` | (see git log) |
| `611509c` | (see git log) |
| `4f81f85` | (see git log) |
| `be326b9` | (see git log) |
| `5362e26` | (see git log) |
| `a85885d` | (see git log) |
| `6d8e1d8` | (see git log) |
| `d0cabd3` | (see git log) |
| `904e8d7` | (see git log) |
| `bd2728f` | (see git log) |
| `7eb64c8` | (see git log) |
| `41443cd` | (see git log) |
| `9e189b4` | (see git log) |
| `c33027f` | (see git log) |
| `04d3e6b` | (see git log) |
| `9021580` | (see git log) |
| `023ee49` | (see git log) |
| `17dc22e` | (see git log) |
| `25d78b4` | (see git log) |
| `79e1ab8` | (see git log) |
| `c57d1e1` | (see git log) |
| `05749ce` | (see git log) |
| `4b23e0e` | (see git log) |
| `d6707e5` | (see git log) |
| `e41f90f` | (see git log) |
| `8aa46bf` | (see git log) |
| `23ca765` | (see git log) |
| `3cc6aab` | (see git log) |
| `4410d31` | (see git log) |
| `a36e4f0` | (see git log) |

### Testing

- [OK] `just verify` 全绿：339 项测试（含 `test-readme-tree` / `test-doc-links`）；本批次每个提交都过了 `pre-commit` 钩子
- [OK] `just check-anchors`：138 个文件全对上，无新增告警
- [OK] `dart run tool/check_doc_links.dart`：138 个文件全绿，exit 0
- [OK] `git fsck` 干净；另有 2 个 dangling commit，是 `pre-commit` 钩子自己的 stash 快照（无害，`git gc` 可清）
- [!!] **未覆盖**：删掉 `integration_test` 后，真机 / 真引擎上启动那一层不再有任何自动化覆盖（有意接受的代价，已写进 `020235d` 的提交消息）

### Status

[OK] **Completed**

### Next Steps

- `10-12-analyze-coverage-guard`：唯一活跃任务（planning），已收窄为 R2–R5 的预防性断言，待开工
- 模板的端到端能力现在是留白：需要时按 `docs/optional-additions.md` 上 `patrol`
- 若哪天把 `F:\App\新建文件夹` 从备份 / 卷影副本找回，凭 `F:/App/flutter_app_template.gitdir-pointer.bak` 可接回那 17 个提交的真实历史
- `.agents/skills` 的两处遗留（`computedHash` 对不上、不在任何门禁视野内）见归档任务
  `.trellis/tasks/archive/2026-10/10-10-skills-vendoring-policy/implement.md`


## Session 6: 给 analyze 门禁加覆盖完整性断言（10-12）

**Date**: 2026-10-12
**Task**: 给 analyze 门禁加覆盖完整性断言（10-12）
**Branch**: `master`

### Summary

10-12「analyze 覆盖完整性断言」从收窄一路做完：新增 `test/tool/analyze_coverage_test.dart`（276 行 / 15 用例），两条仓库级断言挂到既有的 `test` 步上（不加工具、不加 recipe），并在 `cross-cutting.md` 补了对应说明。

Phase 2.1 / 2.2 分别由 `trellis-implement` / `trellis-check` 子代理完成，check 未发现需修的问题。任务已归档，活跃任务清零。

### Main Changes

- **收窄**（`3604193`，本会话早段）：`integration_test` 被删后，原 R1 与事实 ①②③ 作废，任务改为 R2–R5 的**纯预防性断言** —— 详见 `archive/2026-10/10-12-analyze-coverage-guard/prd.md` 的「收窄记录」。
- **实现**（`db6b53e`）：新增 `test/tool/analyze_coverage_test.dart`（276 行 / 15 用例）。
  - 三个纯函数：`topLevelDirsWithDart` / `uncoveredDirs` / `parseAnalyzeRoots` —— **比计划多一个**：把正则解析也拆成纯函数，好让「正则写松了 → 静默无 root」这条风险自身也有假输入测试盖住。
  - **R2** 每个含 Dart 源码的顶层目录必须被某个 root 覆盖或在排除名单里（失败**点名目录**）；**R3** 每个 root **各自**必须列得到 ≥1 个 `.dart`（失败说明「该 root 产出 0 个文件」）。
  - 唯一真相是 justfile（测试内不抄第二份 root 列表）；文件清单走 `git ls-files --cached --others --exclude-standard`，与 `tool/list_dart_files.dart` 同一命令；roots 解析不到时**显式 fail**，不退化成空集合。
  - 挂到既有的 `test` 步上：`justfile` 的 `verify` 链**未改动**，不加工具、不加 recipe。
  - `.trellis/spec/cross-cutting.md` 的「`dart analyze` 必须显式传文件名」那条后补一条子弹（**未新开标题**）：扫描面来自 justfile、漏目录不报错的形态、两条断言的失败信息与测试路径。
- **Phase 2.2**（`trellis-check`，full-scope）：逐条核过 R2 / R3 / 纯逻辑与仓库现状分离 / R5 写法 / prd 的「不做什么」，**未发现需要修的问题**，并独立复跑了全部命令。
- **归档**（`4da2b27`）：任务移入 `.trellis/tasks/archive/2026-10/`。


### Git Commits

| Hash | Message |
|------|---------|
| `db6b53e` | (see git log) |
| `2dd358d` | (see git log) |
| `4da2b27` | (see git log) |

### Testing

- [OK] `just verify` 全绿：**354 用例**（339 基线 + 15 新增）；两个内容提交各自过了一次 `pre-commit` 钩子
- [OK] `just check-anchors`：139 个文件，无新增告警
- [OK] `dart analyze --fatal-infos test/tool/analyze_coverage_test.dart` → `No issues found!`
- [OK] 三条反向验证（**均已还原现场**：`git diff justfile` 为空、`example/` 已删）：造 `example/foo.dart` → 点名 `example`；roots 去掉一个仍存在的目录 → 点名它；root 改成 `nosuchdir` → 报「该 root 产出 0 个文件」
- [!!] **已记边界**（见 `implement.md` 的遗留风险）：R2 不管仓库根下的裸 `.dart` 文件（符合 prd「顶层**目录**」的措辞）；`_analyzeDartFiles` 的生成物过滤无独立单测；测试依赖 `git` 可执行文件

### Status

[OK] **Completed**

### Next Steps

- 无活跃任务（`task.py list` 为空），`archive/2026-10/` 现有 13 个任务
- 若要给这道门补「生成物过滤」的独立单测、或把 `.agents/skills/**` 纳入链接门禁，另开任务


## Session 7: 清理冗余文件：46 个 Trellis 占位 jsonl + code-workspace

**Date**: 2026-10-12
**Task**: 清理冗余文件：46 个 Trellis 占位 jsonl + code-workspace
**Branch**: `master`

### Summary

全库审计后只清掉两类真冗余：23 个归档任务里的 46 个模板占位 jsonl（零信息量）与一个与 `.gitignore` 矛盾、却一直被跟踪的 `my_app.code-workspace`。

已跟踪文件 591 → 544。门禁无影响 —— 这些文件本就不在任何扫描面内，删前删后 `just verify` 都是全绿（354 用例）。

### Main Changes

- **先盘后删**（全库审计，不先斩后奏）：
  - 「被 `.gitignore` 命中却仍在版本库里」全库只有 2 条 —— `my_app.code-workspace`（真矛盾）与 `.env.example`（`!.env.example` 反向规则的正常结果，误报）
  - 「内容完全相同」的已跟踪文件 47 组：其中 46 个是 Trellis 模板占位 jsonl；其余是 vendored skills 的内部重复页与 iOS / Android 上游样板
  - 无 `.bak` / `.orig` / `.tmp` / 零字节文件，也无 `.DS_Store` / `Thumbs.db`
- **删除 47 个文件**（`b07e4d4`）：
  - 46 个占位 jsonl：`.trellis/tasks/archive/**/{check,implement}.jsonl`。23 个归档任务**两个文件都是**占位（没有「一个填了、一个没填」的半吊子状态），内容只有模板那两行 `_example` 提示，合计 11.6 KB。只删占位的，**已填内容的 12 个**（6 个任务，含 `10-12`）保留。
  - `my_app.code-workspace`：`.gitignore:42` 明写忽略它、它却一直在库里，而内容只有 `{"folders":[{"path":"."}],"settings":{}}` —— 比那条规则更没道理。
- **删前查过两处依赖**：这些 jsonl 不在任何门禁扫描面内（`check_doc_links` / `check_readme_tree` 都排除 `.trellis/tasks/**`），也未登记在 `.trellis/.template-hashes.json`（`tasks/` 零条）→ 既不影响门禁，也不影响 `trellis update`。
- **有意没动的**：vendored skills 的内部重复页（10-10 方案 B：内容原样入库，手改只会让 `computedHash` 差得更远）、iOS / Android 模板占位（`Contents.json` / Gradle 引用着，删了破构建）、空 `assets/`（`template-pruning.md` 记录的 `TODO(template)` 留白）、`build/` + `.dart_tool/`（是缓存不是冗余）、以及仓库外的 `flutter_app_template.gitdir-pointer.bak`（接回那 17 个丢失提交真实历史的唯一凭据）。


### Git Commits

| Hash | Message |
|------|---------|
| `b07e4d4` | (see git log) |

### Testing

- [OK] `just verify` 全绿：**354 用例** —— 删前删后无差别（被删的文件不在任何门禁扫描面内）
- [OK] `pre-commit` 钩子在提交时又独立跑了一次完整 `just verify`
- [OK] 与远端同步（`0 / 0`），远端 `master` = `b07e4d4`
- [OK] 已跟踪文件数 591 → 544；`git status` 干净；`jsonl` 只剩已填内容的 12 个

### Status

[OK] **Completed**

### Next Steps

- 无活跃任务（`task.py list` 为空）
- 仓库外的 `F:/App/flutter_app_template.gitdir-pointer.bak` **别删** —— 若哪天把主仓从备份 / 卷影副本找回，凭它可接回那 17 个提交的真实历史
- 这次没清的只剩本地产物 `build/` + `.dart_tool/`（约 192MB 缓存，非冗余；清完要重跑 `just deps` + `just codegen`）


## Session 8: 门禁自证任务收口 + 仓库冗余清理

**Date**: 2026-10-14
**Task**: 门禁自证任务收口 + 仓库冗余清理
**Branch**: `master`

### Summary

收口 10-12-lint-self-proof：规则 3/4 认得 getIt<X>()（FunctionExpressionInvocation 形态），单测桩改回生产对象形态；补插件接线四条静态断言与生成物口径守卫；spec 记入节点形态、新断言与「已知边界」。归档前用真实 dart analyze 探针复核 AC1/AC2 均报出。另做一轮仓库冗余清理：删死组件 ScreenLoadingIndicator、只测 signals 包的测试、.commandcode/，guides/index.md 去重并改中文，修 cross-cutting.md 的 scan-args 口径漂移；just verify 全绿（381 passed / 1 skipped）。

### Main Changes

(Add details)

### Git Commits

| Hash | Message |
|------|---------|
| `a3857af` | (see git log) |
| `ac67ef4` | (see git log) |
| `9cd5259` | (see git log) |
| `7db08b5` | (see git log) |

### Testing

- [OK] (Add test results)

### Status

[OK] **Completed**

### Next Steps

- None - task complete


## Session 9: 规则 4 判据 AST 化 + 重试收窄 + CI 平台构建门禁

**Date**: 2026-10-14
**Task**: 规则 4 判据 AST 化 + 重试收窄 + CI 平台构建门禁
**Branch**: `master`

### Summary

四批收口上一轮审计的 P1/P2 与三条零散项：①规则 4 的「三件套」判据从整文件字符串包含改成 AST（字段 / this.viewModel 字段形参 / ?? 兜底），并按 cross-cutting.md 的原文收窄到页面路径（features/*/page/、lib/app/pages/）—— 用真实 dart analyze 探针证明「三件套只写在注释里」现在会被报出、data 路径不报、4 个真实页面零诊断；实现期发现 ?? 的节点在 V1/V2 两套 AST 视图里不同（V1=BinaryExpression，V2=IfNull 且没有 FunctionExpressionInvocation），判据必须留在 V1。②RetryInterceptor 接上 retryEvaluator 只重试 GET/HEAD（写请求超时不再重发），清单自带 408/429/5xx，并补齐 spec 里漏掉的一半口径（传输层错误）。③README 补 Android cleartext / iOS ATS / 模拟器 10.0.2.2；skills-lock 删掉重复且路径约定不符的 signals_hooks（27 条 = 磁盘 27 个目录）+ 新增三条 lock↔磁盘一致性断言；dependabot 覆盖 packages/app_lints。④CI 加 build-apk job（just build-apk = flutter build apk --debug，本地冷缓存 325s / 热缓存 45s）。just verify 全绿 396 passed / 1 skipped。子代理派发在本机不可用（spawn pi ENOENT），实现与自查改为主会话内联完成。

### Main Changes

(Add details)

### Git Commits

| Hash | Message |
|------|---------|
| `a05987d` | (see git log) |
| `7c85a8a` | (see git log) |
| `50477dc` | (see git log) |
| `ba340ee` | (see git log) |

### Testing

- [OK] (Add test results)

### Status

[OK] **Completed**

### Next Steps

- None - task complete


## Session 10: 删掉文档类门禁与生成物口径断言

**Date**: 2026-10-14
**Task**: 删掉文档类门禁与生成物口径断言
**Branch**: `master`

### Summary

按用户决定删掉四类非必要门禁：工具 tool/check_readme_tree.dart、check_doc_links.dart、check_doc_anchors.dart、generated_paths.dart 与对应 4 个测试（−1803 行），justfile 去掉 test-readme-tree / test-doc-links / check-anchors 三个 recipe，verify 从 6 步回到 4 步（fmt-check analyze test-app-lints test），与兄弟分支 preset/ai-starter 逐字相同；断言数 396 → 347。文档落点清干净：cross-cutting.md 两节 + 一致性断言段 + 「有意不设」表两行 + 生成物口径「三处同步」改「两处」，spec/index.md、comment-guidelines.md、.cursor/rules 各一处。三处判断：①插件里的生成物豁免（paths.dart 的 isGeneratedPath）保留 —— 删了会让七条规则对生成物报违规、analyze 直接红，spec 改成「.gitignore ↔ 插件两处同步」；②analyze_coverage_test 里对已删 generated_paths 的依赖去掉（git 的 --exclude-standard 本就不列生成物，那层过滤是防御性重复）；③spec/index.md 的「增删 lib 文件 → 同步目录树」清单项保留为人工约定，只去掉门禁半句。按用户要求未在「有意不设的项」登记这些决定。实测 verify 各步：fmt-check 7s、analyze-app 42s、analyze-tool 30s、test-app-lints 10s、test 34s（合计约 123s）；合并 analyze 两步实测 85s vs 分步 72s，没有收益，故保持两步。

### Main Changes

(Add details)

### Git Commits

| Hash | Message |
|------|---------|
| `b8b90f6` | (see git log) |

### Testing

- [OK] (Add test results)

### Status

[OK] **Completed**

### Next Steps

- None - task complete


## Session 11: docs 局部冗余收敛：段落级去重 + 删 ADR-0002

**Date**: 2026-10-14
**Task**: docs 局部冗余收敛：段落级去重 + 删 ADR-0002
**Branch**: `master`

### Summary

release-checklist §6/§7 的复述改指路（门禁口径回归 cross-cutting）、图标缺失收敛到 template-pruning 占位表、删 ADR-0002 并把日期+来源并进 state-management。净 −67 行（+12/−79，5 文件），just verify 全绿。子代理分派在本机不可用（spawn pi ENOENT，Windows Node 解析不了无扩展名 pi 脚本），改 inline 实施，本次没有独立复核。踩坑一次：指路时锚点取错行，覆盖了 optional-additions 的「原生启动图」，已 undo 重做。

### Main Changes

(Add details)

### Git Commits

| Hash | Message |
|------|---------|
| `9dcce59` | (see git log) |
| `f7fbe52` | (see git log) |
| `5777ee4` | (see git log) |

### Testing

- [OK] (Add test results)

### Status

[OK] **Completed**

### Next Steps

- None - task complete


## Session 12: 脚手架 demo 剪枝自动化：tool/prune_examples.dart

**Date**: 2026-10-14
**Task**: 脚手架 demo 剪枝自动化：tool/prune_examples.dart
**Branch**: `master`

### Summary

新增 tool/prune_examples.dart：一条命令删 article/demo 两个示例模块并清干净全部引用点（锚点按文本定位、每条必须恰好命中 1 次，不命中即零写盘并以非零退出），随后自动跑 just codegen + just verify 自证，残留扫描代码侧命中即失败、文档侧只打印清单，auth 在写盘前以退出码 2 拒绝。锚点实测 35 条（design 原估 19 条，多出的由 grep、残留扫描与 unused_import 三条门禁补出）；核心防线是「匹配失败就响亮失败」而不是静默少删。测试 test/tool/prune_examples_test.dart 28 个用例 + 1 个 SCAFFOLD_E2E 端到端（默认跳过）。docs/template-pruning.md 的 article/demo 手工清单（已漂移 5 处）整体删除，改为工具用法 + auth 手工改造 + 占位清单；spec/cross-cutting.md 新增「示例模块剪枝」一节，生成物口径改三处同步。just verify 全绿（375 passed / 2 skipped）。子代理在本机不可用（spawn pi ENOENT），本轮 inline 实施 + inline 复核。

### Main Changes

(Add details)

### Git Commits

| Hash | Message |
|------|---------|
| `1351c1e` | (see git log) |
| `2c3c097` | (see git log) |

### Testing

- [OK] (Add test results)

### Status

[OK] **Completed**

### Next Steps

- None - task complete
