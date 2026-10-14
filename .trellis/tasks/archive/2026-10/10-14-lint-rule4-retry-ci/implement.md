# 执行清单

> 状态：**全部完成**，四批提交 `a05987d`（规则）/ `7c85a8a`（网络）/ `50477dc`（文档+元数据）/ `ba340ee`（CI）。

## 1. R1 规则 4（门禁优先级最高）

- [x] 1.1 `paths.dart` 加 `isPagePath()`（`layerOf == 'page'` 或 `lib/app/pages/` 前缀）
- [x] 1.2 `rules.dart`：`_PageInjectionPointVisitor` 三件套判据改 AST；范围 `_isFeatureLogic` → `!isPagePath`；删掉 `_fallbackPattern` 与 `content.contains`
- [x] 1.3 `rules_test.dart`：新增「三件套只写在注释里 → 必须报」「缺 `this.viewModel`（走初始化列表）→ 必须报」；新增 `PageInjectionPointOutsidePageRuleTest`（`features/a/data/` 取 ViewModel → 不报）
- [x] 1.4 `cd packages/app_lints && dart test` → 41 passed
- [x] 1.5 真实通道探针（已删净，`git status` 只剩任务目录）
      - 页面路径 + 三件套只在注释 → **报出** `page_must_expose_view_model_injection_point`（命中 1）
      - `data/` 路径 + 取 ViewModel → **不报**（命中 0）
      - 页面路径 + 三件套齐备 → 不报
- [x] 1.6 回归基线：`just analyze-app` 全绿（4 个真实页面零诊断）

## 2. R2 / R3 重试

- [x] 2.1 新建 `lib/core/data/network/retry_policy.dart`（`retryableStatuses` + `shouldRetryRequest`）
- [x] 2.2 `dio_factory.dart`：`RetryInterceptor(..., retryEvaluator: shouldRetryRequest)`（拦截器顺序未动）
- [x] 2.3 新建 `test/core/data/network/retry_policy_test.dart`（11 条判据）
- [x] 2.4 `dio_factory_test.dart` 加 `_TimeoutAdapter` 与集成断言：POST 超时只发 1 次；GET 超时发 1 + retries 次
- [x] 2.5 `just test test/core/data/network` → 44 passed

## 3. 文档

- [x] 3.1 `data/network-guidelines.md` Retry 节：两部分判据 + 「只重试 GET/HEAD」+ 清单为何自带一份
- [x] 3.2 `cross-cutting.md`：规则 4 行加范围与「判据走 AST」；「后两条的判据必须是 AST」扩成三条
- [x] 3.3 `README.md`「环境与构建」：cleartext / ATS / `10.0.2.2` 三点
- [x] 3.4 `README.md`：skills 来源计数 `rodydavis/signals.dart` 6 → 5

## 4. 元数据

- [x] 4.1 `skills-lock.json`：删掉重复且路径约定不符的 `signals_hooks` 条目（正确的 `signals-hooks` 保留）→ 27 条 = 磁盘 27 个目录
- [x] 4.2 新建 `test/tool/skills_lock_consistency_test.dart`（三条断言：lock→磁盘、磁盘→lock、`skillPath` 用上游相对路径）
- [x] 4.3 `.github/dependabot.yml`：加 `packages/app_lints` 段
- [x] 4.4 `cross-cutting.md`「依赖声明」补 vendored skill 的登记一致性说明

## 5. CI

- [x] 5.1 本地跑通 `flutter build apk --debug`：冷缓存 **325s**（Gradle 320.6s），产物 `build/app/outputs/flutter-apk/app-debug.apk`
- [x] 5.2 `ci.yml` 加 `build-apk`（`needs: analyze`，action 版本对齐 master）+ justfile 加 `build-apk` recipe（热缓存实测 45s）

## 6. 收口

- [x] 6.1 `just verify` 全绿（396 passed / 1 skipped，比任务开始时 +15 条断言）
- [x] 6.2 探针残留检查：`git status` 只有任务目录
- [x] 6.3 分批提交（四批，每批都过 pre-commit）

## 实现期发现（已同步进 design.md）

1. **`??` 的 AST 节点在 V1/V2 两套视图里完全不同**：V1 是 `BinaryExpression`，V2 才有 `IfNull`（且 `IfNullImpl.accept` 在 v1 视图直接抛 `StateError`）。更要命的是 V2 换掉了整套表达式节点 —— 没有 `FunctionExpressionInvocation`，`getIt<X>()` 会变成 `UnqualifiedFunctionInvocation`。所以规则判据**必须留在 V1 视图**：迁到 V2 会让「取容器」整片看不见。design.md 的兜底判据已按此修正。
2. **规则 4 的字符串判据彻底退场**：`content.contains` 与 `_fallbackPattern` 正则删除，三件套各判一次真实 AST 声明。

## 偏离与未做

- **子代理派发不可用**：`trellis_subagent` 报 `spawn pi ENOENT`（Windows 下 spawn 无扩展名 shim；`pi` 本体在 `~/.pi/agent/bin/pi` 且可运行）。实现与自查均改为**主会话内联**完成，未重试派发、未改用其它 CLI。
- `docs/optional-additions.md:101`（不预装端到端测试）**未改** —— 按 Q1 方案 b，平台构建与端到端是两个决策面。
- 明文 HTTP 只写文档，**未改** manifest / plist（加 debug-only 例外属于另一个决策）。
