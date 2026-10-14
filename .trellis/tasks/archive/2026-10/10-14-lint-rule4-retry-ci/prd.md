# 规则 4 AST 化 + 重试幂等 + CI 平台验证

## Goal

把上一轮全仓库审计中「已有证据、且不属已登记的有意留白」的问题收口：修掉一条**能被注释绕过的门禁**（规则 4），补齐**重试语义的一半口径**并决定非幂等请求的重试边界，把**明文 HTTP 的平台默认阻断**写进文档，顺带清掉三条零散维护项。

## 背景（已核实事实，带锚点）

| # | 事实 | 证据 |
|---|---|---|
| F1 | 规则 4 `page_must_expose_view_model_injection_point` 的「三件套」判据是**整文件字符串包含**，不是 AST：`content.contains('final $type? viewModel;')`、`content.contains('this.viewModel')`，兜底用正则 `viewModel\s*\?\?\s*getIt<\s*Type\s*>` 直接扫文件原文（含注释与字符串） | `packages/app_lints/lib/src/rules.dart:385-393`、`:571-572` |
| F2 | 该规则**可被注释绕过**（已复现）：探针页面真调用 `getIt<ProbeViewModel>()`、三件套只写在 `//` 注释里 → `dart analyze --fatal-infos` 只报两条无关 info，规则一声不响 | 探针文件已删净；`git status` 干净 |
| F3 | 该规则对**所有非 `features/*/logic/` 的 lib 文件**生效（含 `core/`、`features/*/data/`），报的却是「页面」文案 | `rules.dart:378` |
| F4 | `RetryInterceptor` 用库默认 evaluator：**除 `badResponse` 外的任何错误，只要不是 `cancel` / `FormatException` 就重试** —— 连接/发送/接收超时、connectionError 一律重试，**不看 HTTP 方法** | 库真源 `dio_smart_retry-7.0.1/lib/src/default_retry_evaluator.dart` |
| F5 | 本仓只传 `retries: config.retries`（默认 3），没有 `retryEvaluator` / `retryableExtraStatuses` | `lib/core/data/network/dio_factory.dart:59`、`lib/core/config/network_config.dart:10` |
| F6 | 本仓 spec 的 Retry 口径**只写了状态码那一半**：「默认只重试 408/429/5xx，401 不在其中」 | `.trellis/spec/data/network-guidelines.md:67` |
| F7 | `.env.example` 默认 `http://`，但 Android manifest 无 `usesCleartextTraffic`、`android/app/src/**` 无 network_security_config，`Info.plist` 无 `NSAppTransportSecurity`；README/AGENTS/spec/docs 全仓库无一处提到 cleartext / ATS / `10.0.2.2` | `.env.example`、`android/app/src/main/AndroidManifest.xml`、`ios/Runner/Info.plist`；`git grep` 三关键词均空 |
| F8 | `skills-lock.json` 28 条 vs `.agents/skills/` 27 个目录；悬挂项 `signals_hooks` 的 `skillPath` 指向不存在的 `.agents/skills/signals_hooks/SKILL.md`（磁盘实为 `signals-hooks`） | lock 与 `ls .agents/skills` 实测 |
| F9 | `README.md:109` 同句自相矛盾：写「27 个目录 / 136 个文件」，紧接着列 `12 + 10 + 6`（合 28） | `README.md:109-111` |
| F10 | `.github/dependabot.yml` 只有 `directory: "/"`；`packages/app_lints` 的 lock 既入库又被 OSV 扫，却收不到升级 PR | `.github/dependabot.yml`、`.github/workflows/ci.yml:77`、`packages/app_lints/pubspec.yaml:14-15` |
| F11 | CI 只有 `analyze`(ubuntu) + `osv-scan`，**无任何 `flutter build`** → Gradle / Podfile / 插件注册类问题不被覆盖，且这条**不在** cross-cutting.md「有意不设的项」表里 | `.github/workflows/ci.yml` |
| F12 | 兄弟分支 `origin/preset/ai-starter` 有现成的 `integration-test` job（`needs: analyze`、KVM、JDK17、`reactivecircus/android-emulator-runner@v2` api-30/pixel_5、`script: just e2e`）+ `justfile` 的 `e2e: flutter test integration_test/` + `integration_test/`，跑在同一 Flutter 3.47.5 | `origin/preset/ai-starter:.github/workflows/ci.yml:54-96`、`:justfile:46-47` |
| F13 | 但 `docs/optional-additions.md:101` 已登记「本模板不预装端到端测试」——与 F11 的取舍是同一个决策面 | `docs/optional-additions.md:101` |

### 借鉴判定（S = `origin/preset/ai-starter`，分叉点 `4150ee6`）

| 本任务要修的 | S 侧情况 | 判定 |
|---|---|---|
| 规则 4 | S 的插件只有 4 条规则，**没有这条规则** | 修复自己写 |
| 重试口径 / 幂等 | S 写法一字不差，spec 也只写状态码一半 | 自己写（S 的「Retry 在解码之前判定」表述可抄） |
| cleartext / ATS | S 同样空白 | 自己写 |
| lock 漂移 | S 是**反方向**漂移（lock 40 全部命中，磁盘多 1 个未登记项） | 无正确侧可抄 |
| dependabot | S 的 `dependabot.yml` 与 L 逐字节相同 | 自己写 |
| CI 平台构建 | **S 有现成 job（F12）** | **唯一可借鉴项** |

## Requirements

### R1 规则 4 改 AST 判据并收窄到页面路径（P1，门禁漏报）

判据不再读文件原文：从 AST 判「类里有没有 `final X? viewModel;` 字段」「构造参数有没有 `this.viewModel`」「有没有 `viewModel ?? getIt<X>()` 兜底」。
生效范围按 spec 收窄到**页面路径**（`features/*/page/` 与 `lib/app/pages/`）：`cross-cutting.md:22` 的判据原文是「取 ViewModel 的**页面**」、`:56` 明说「只看 `*ViewModel`；页面直接取依赖不在管辖内」，而当前实现（`rules.dart:378` 只排除 `features/*/logic/`）与这两句都不符 —— 属实现漂移，不是设计选择。收窄不会漏掉今天的真实用例：现仓 4 个取 ViewModel 的文件全在 `features/*/page/`（`article_detail_page.dart:28`、`article_list_page.dart:27`、`login_page.dart:31`、`storage_demo_page.dart:28`）。

覆盖 F1/F2/F3。

### R2 补齐 Retry 口径（P2，spec 不完整）

`data/network-guidelines.md` 的 Retry 一节写清**实际判据是两部分**：状态码（408/429/5xx，401 不在内）**与传输层错误**（连接/发送/接收超时、connectionError）。S 那句「Retry 在解码之前判定 —— 重试看的是原始响应」比现文更准，一并采纳。覆盖 F4/F6。

### R3 重试收窄到幂等方法（P2，已定：方案 a）

`dio_factory.dart` 给 `RetryInterceptor` 传 `retryEvaluator`：非 `GET` / `HEAD` **直接不重试**；状态码与传输层错误的语义沿用现状。两个实现约束（写进 design.md）：

- `dio_smart_retry` 的 `retryEvaluator` 与 `retryableExtraStatuses` **互斥**（同传会抛 `ArgumentError`），所以 evaluator 必须自带 `{408, 429, 500, 502, 503, 504}` 清单，否则会把 5xx 重试一起弄丢。
- `POST /login` 与 `POST /refresh`（`auth_api.dart:15`、`token_refresher.dart:39`）是现仓仅有的两处写请求，收窄后它们超时不再重发，需有测试钉住。

覆盖 F5；「401 不吞」的既有语义不变。

### R4 明文与平台阻断写进 README（P2，文档空白）

README「环境与构建」加三点：Android 9+ 默认阻断 cleartext、iOS ATS 默认阻断 http、Android 模拟器上 `localhost` 指设备自身（用 `10.0.2.2`）。覆盖 F7。

### R5 lock 与磁盘对齐（P3）

`skills-lock.json` 与 `.agents/skills/` 二者取一改到一致；`README.md:109` 的数字自洽。覆盖 F8/F9。

### R6 dependabot 覆盖独立包（P3）

`.github/dependabot.yml` 增加 `packages/app_lints` 一段 pub 配置。覆盖 F10。

### R7 CI 增加平台构建验证（P3，已定：方案 b）

`.github/workflows/ci.yml` 增加 `build-apk` job（`needs: analyze`）：`just deps` → `flutter build apk --debug`。
**不**引入 `integration_test/`、**不**加 `e2e` recipe、`docs/optional-additions.md:101`（不预装端到端测试）保持不变 —— 那条决定管的是端到端，与平台构建不是同一件事。覆盖 F11。S 的 job（F12）只算「这条路在本仓库可行」的旁证，不整段搬；F13 的冲突因此不存在。

## Acceptance Criteria

- [ ] A1 `rules.dart` 不再出现对 `currentUnit.content` 的 `contains` / 正则匹配；「真取容器 + 三件套只写在注释里」的探针**必须**报出 `page_must_expose_view_model_injection_point`（用真实 `dart analyze --fatal-infos` 验，探针不残留）。
- [ ] A2 规则 4 的 AST 版在 `packages/app_lints/test/rules_test.dart` 有正例与反例，**含「三件套写在注释里」这条反例**（当前若不加会漏）。
- [ ] A3 规则 4 的生效范围 = `features/*/page/` 与 `lib/app/pages/`；`cross-cutting.md` 规则表与 `rules.dart` 的规则描述同步，不得再留「所有非 logic 文件」的口径。
- [ ] A4 `data/network-guidelines.md` 的 Retry 口径写明状态码与传输层错误两部分，并记录「重试只看 GET/HEAD」这条新判据。
- [ ] A5 README 提到 cleartext / ATS / `10.0.2.2` 三点。
- [ ] A6 `skills-lock.json` 与 `.agents/skills/` 一致，`README.md:109` 数字自洽。
- [ ] A7 `dependabot.yml` 覆盖 `packages/app_lints`。
- [ ] A8 `ci.yml` 的 `build-apk` job 真跑 `flutter build apk --debug`；`docs/optional-additions.md:101` 保持原样（该登记只管端到端，与本次 job 不冲突）。
- [ ] A9 `just verify` 全绿；若要加 CI job，本地等价命令先跑通并记进 `implement.md`。

## Out of Scope

- 覆盖率门槛（`cross-cutting.md「有意不设的项」`已登记为决定）
- `lib/app/pages/not_found_page.dart` 覆盖盲区（1/18 行）、`lib/core/base/result.dart` 未覆盖的 `isSuccess` / `getOrThrow`（有意的公共 API 面）
- release 签名 / 混淆 / flavor（README 已声明有意留白）
- `flex_color_scheme` 9.0.0 大版本升级（另立任务）
- S 的 `tool/prune.dart`（不在本次发现清单）
- 文案层面：`test/app/app_test.dart:19` 那句覆盖率表述（若顺手则改，不单列验收）

