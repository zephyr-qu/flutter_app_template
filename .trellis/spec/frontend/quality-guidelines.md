# 质量规范：UI 层

> UI 层（页面 / 组件 / 状态消费）的代码规范。门禁、测试基建与发布相关的约定见 [../cross-cutting.md](../cross-cutting.md)。

---

## 禁止模式

❌ **这些写法一律不要用**：

1. **生产代码里的 `print()`** — 用 `Logging.info()` / `Logging.error()`
2. **写死颜色 / 字体 / 间距** — 一律走 `Theme.of(context)` 或 `colorScheme`
3. **把业务逻辑写进 widget** — 异步操作都归 Notifier / Service
4. **页面自己建 `ProviderContainer`** — 依赖从 `ref` 取。这条**没有门禁**，靠约定与 review。
5. **在 `build` 里用 `ref.read` 取 provider 的值** — `ref.read(xxxProvider.notifier)` 取实例是允许的。门禁：`packages/app_lints` 插件的 `avoid_ref_read_in_build`（`dart analyze` 下生效）。
6. **用 `setState()` 管异步 / API 数据** — 数据加载用 `@riverpod` 的 `AsyncNotifier`（`Future<T> build()`），渲染用 `AsyncView`；`setState` 只留给动画 / 滚动这类纯 UI 状态。
7. **用 `withOpacity()`** — 用 `Color.withValues(alpha: X)`（Dart 3+）。
8. **`ref.read` / `ref.watch` 在 `logic/` 里绕过 provider 拿依赖** — logic 层的依赖要么走 `ref`（`ref.watch` / `ref.read` provider），要么走构造器；不得手动 new 服务，也不得碰 UI（`features/*/logic/` 禁 material / widgets import 与本 feature `page/` 层引用，由 `packages/app_lints` 插件的 `no_material_import_in_logic` 拦）。
9. **跨 feature import / export `page/` 或 `logic/`** — 只允许引用 `core/` 与别的 feature 的 `data/`。门禁：`packages/app_lints` 插件的 `cross_feature_only_data`；它同时禁止 `core/` import / export `features/` 或 `app/`（`no_upper_import_in_core`）。
10. **凭据放进 URL query** — 密码、令牌这类敏感值只能走**请求体**。本项目无认证；接入凭证时按此执行。
11. **页面自己维护 loading / request token** — 首屏加载就是 provider 的 `build()`，刷新与重试退回 `ref.refresh` / `ref.invalidate`。
12. **页面加 `final Xxx? viewModel;` 构造注入点** — 注入口是 `ProviderScope(overrides:)`，页面不持有可注入字段。

---

## 必须遵守

✅ **这些写法一律照做**：

1. **每个异步页面都用三态渲染** — 用 `AsyncView`（`core/ui/async_view.dart`），**不要用 `AsyncValue.when`**。判定表、页面模板与 `refreshing` / `reloading` 回调见 [state-management.md](./state-management.md)「渲染状态」与「Consumer 一节」。
2. **异步数据用 `AsyncNotifier` 的 `Future<T> build()`**（体内把 `Result` 映射成 `AsyncValue`），失败时**抛 `Failure` 本身**，不要另造包装异常（形状见 [state-management.md](./state-management.md)「三种 Provider 形态」）。
3. **`build` 开头取 `Theme.of(context)`**：`final theme = Theme.of(context);`
4. **所有 widget 用 `const` 构造**
5. **读状态用 `ref.watch`** —— `ref.read` 只在方法 / 回调里取一次性值（门禁口径见本文件「禁止模式」）。

---

## 错误处理层级

```
FlutterError.onError        → Flutter 框架错误（保持默认 presentError：红屏 + 完整堆栈）
PlatformDispatcher.onError  → 未捕获的异步错误（根 zone，兜底）→ 记一条 error 日志
  └─ Result<_, Failure>         → 业务层错误（类型安全）
  └─ AsyncNotifier + AsyncView  → 状态层错误统一落到 AsyncValue.error
```

- 所有 API 调用返回 `Result<T, Failure>`（业务层不抛异常）
- 三态由 `AsyncNotifier` + `AsyncView` 承载；**不要在页面里 try/catch 后自己翻译错误**
- 本项目**没有**认证拦截器：401 / 403 会原样走到 Service 层，按 `failure.dart` 的映射变成 `AuthFailure`（`unauthorized` / `forbidden`），文案见 `core/ui/failure_message.dart`
- 以上都漏掉的由 `PlatformDispatcher.instance.onError` 兜底并记日志

两条容易被「顺手加回来」的：

- **不要再用 `runZonedGuarded`** —— 兜底走 `PlatformDispatcher.instance.onError`。
- **`FlutterError.onError` 不要再包一层 `Logging.error`** —— 保持默认的 `presentError`。

> ⚠️ **这些兜底的产物只到控制台。** `Logging` 用的是 `logger` 的默认输出（stdout，没有自定义 `output:`）。生产环境的真兜底要靠崩溃上报（Sentry / Crashlytics）或写本地日志文件，**目前都没有**。

### 拦截器顺序（`dioProvider`）

顺序图、两条不可破的语义与相关的两个测试见 [backend/network-guidelines.md](../backend/network-guidelines.md)「拦截器顺序」，本文件不再重复。

---

## 门禁、测试与发布

以下内容不属于 UI 层，已移到 [跨层与门禁](../cross-cutting.md)，本文件不重复：

| 内容 | 见 |
| --- | --- |
| 架构边界与形态约定（`packages/app_lints/` 插件：依赖方向、logic 层纯度、build 里禁 `ref.read`）与禁止模式 | [../cross-cutting.md](../cross-cutting.md)「架构边界与形态约定」 |
| 依赖声明（`depend_on_referenced_packages`，以及有意不设门禁的几类） | [../cross-cutting.md](../cross-cutting.md)「依赖声明」 |
| 内存泄漏检测（`leak_tracker`） | [../cross-cutting.md](../cross-cutting.md)「内存泄漏检测」 |
| 集成测试（`integration_test/`，含「widget 测试里不要用真实 I/O」） | [../cross-cutting.md](../cross-cutting.md)「集成测试」 |
| 环境配置与 release 构建（含「有意留白」） | [../cross-cutting.md](../cross-cutting.md)「环境配置与 release 构建」 |

---

## 测试要求

- 测试文件路径跟随源码结构：`test/features/{feature}/{subdir}/` 对应 `lib/features/{feature}/{subdir}/`
- 状态/逻辑测试用 `ProviderContainer` + `overrides` 注入假仓库，不需要任何全局注册表（模板：`test/features/sample/logic/sample_list_notifier_test.dart`）
- 页面测试用 `test/support/app_test_harness.dart` 的 `setUpTestApp()` + `wrapPage(page, container:)`，依赖同样通过 `overrides` 换掉
- widget 测试的三条硬约束见 [state-management.md](./state-management.md)「测试要求」
- 集成测试：`integration_test/` 目录（跑法与注意事项见 [../cross-cutting.md](../cross-cutting.md)「集成测试」）
- 新增 widget 测试时确保 `flutter_test_config.dart` 中的 `LeakTesting` 配置合适
