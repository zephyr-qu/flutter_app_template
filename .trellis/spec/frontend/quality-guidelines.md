# Quality Guidelines

> UI 层（页面 / 组件 / 状态消费）的代码规范。门禁、测试基建与发布相关的约定见 [../cross-cutting.md](../cross-cutting.md)。

---

## Forbidden Patterns

❌ **Never use these patterns**:

1. **`print()` in production code** — Use `Logging.info()` / `Logging.error()` instead.

2. **Hardcoded colors/fonts/padding** — Always use `Theme.of(context)` or `colorScheme`.

3. **Business logic in widgets** — All async operations belong in Notifier / Service.

4. **页面自己建 `ProviderContainer`** — 依赖从 `ref` 取（容器是测试与 `bootstrap()` 的东西，不是业务代码的）。这条**已无门禁**（2026-09-24 起不再拦），靠约定与 review。

5. **在 `build` 里用 `ref.read` 取 provider 的值** — `ref.read` 不建立订阅，provider 变了界面不重建。`ref.read(xxxProvider.notifier)` 取实例是允许的（身份稳定、不参与订阅）。门禁：`packages/app_lints` 插件的 `avoid_ref_read_in_build`（`dart analyze` 下生效）。

6. **`setState()` for async/API data** — 数据加载用 `@riverpod` 的 `AsyncNotifier`（`Future<T> build()`），渲染用 `AsyncView`；`setState` 只留给动画 / 滚动这类纯 UI 状态。

7. **`withOpacity()`** — Use `Color.withValues(alpha: X)` (Dart 3+).

8. **`ref.read` / `ref.watch` 在 `logic/` 里绕过 provider 拿依赖** — logic 层的依赖要么走 `ref`（`ref.watch` / `ref.read` provider），要么走构造器；不得手动 new 服务、也不得 import/export widget 层（`features/*/logic/` 禁 `package:flutter/material.dart`，由 `packages/app_lints` 插件的 `no_material_import_in_logic` 拦）。

9. **Feature imports or exports another feature's page/ or logic/** — Only core/ and another feature's data/ are allowed. Also enforced by the `packages/app_lints` plugin (`cross_feature_only_data`); it additionally forbids `core/` importing or exporting `features/` or `app/` (`no_upper_import_in_core`).

10. **凭据放进 URL query** — 密码、令牌这类敏感值只能走**请求体**：query 会进入服务端访问日志、代理日志、浏览器或崩溃上报，等同于明文泄露。本项目无认证，这条是给将来接入凭证时立的规矩。

11. **页面自己维护 loading / request token** — 首屏加载就是 provider 的 `build()`，刷新与重试退回 `ref.refresh` / `ref.invalidate`。手写序号、`Completer`、竞态判断等于把框架已经保证的事重做一遍，且容易做错。

12. **页面加 `final Xxx? viewModel;` 构造注入点** — 注入口是 `ProviderScope(overrides:)`，页面不持有可注入字段。

---

## Required Patterns

✅ **Always use these patterns**:

1. **Three-state rendering in every async page** — 用 `AsyncView`（`core/ui/async_view.dart`）：

   ```dart
   AsyncView<List<SampleItem>>(
     state: items,                                   // ref.watch(xxxProvider)
     loading: () => const LoadingIndicator(),
     error: (error, stackTrace) => ErrorText(
       error: error,
       onRetry: () => ref.invalidate(sampleListProvider),
     ),
     data: (list) => list.isEmpty
         ? const EmptyWidget(message: '暂无数据')
         : ListView.builder(...),
   )
   ```

   **不要用 `AsyncValue.when`**：三态判定顺序与 `data(null)` 语义都封装在 `AsyncView` 里，
   页面各自重写一遍就会漂移（见 [state-management.md](./state-management.md)「渲染状态」）。

2. **异步数据用 `AsyncNotifier` 的 `build()`**:

   ```dart
   @riverpod
   class SampleListNotifier extends _$SampleListNotifier {
     @override
     Future<List<SampleItem>> build() async { /* Result → AsyncValue */ }
   }
   ```

   失败时**抛 `Failure` 本身**，不要另造包装异常。

3. **`Theme.of(context)` at start of build**:

   ```dart
   final theme = Theme.of(context);
   ```

4. **`const` constructors** for all widgets.

5. **`ref.watch` for state consumption**:

   ```dart
   final items = ref.watch(sampleListProvider);
   ```

---

## Error Handling Hierarchy

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

- **不要再用 `runZonedGuarded`** —— 它与 `PlatformDispatcher.instance.onError` 覆盖同一批错误，Flutter 现行推荐后者。
- **`FlutterError.onError` 不要再包一层 `Logging.error`** —— 框架错误本来就会经过它，默认的 `presentError` 已经把红屏与完整堆栈打出来了。

> ⚠️ **这些兜底的产物只到控制台。** `Logging` 用的是 `logger` 的默认输出（stdout），没有自定义 `output:` ——
> release 版上 Android 进 logcat、iOS 基本丢弃，用户和你都拿不到。生产环境的真兜底要靠崩溃上报
> （Sentry / Crashlytics）或写本地日志文件，**目前都没有**。

### 拦截器顺序（`dioProvider`）

见 [backend/network-guidelines.md](../backend/network-guidelines.md) —— 顺序图、两条不可破的
语义、以及相关的两个测试都记在那里，本文件不再重复。

---

## 门禁、测试与发布

以下内容不属于 UI 层，已移到 [Cross-Cutting Concerns](../cross-cutting.md)，本文件不重复：

| 内容 | 见 |
| --- | --- |
| 架构边界与形态约定（`packages/app_lints/` 插件：依赖方向、logic 层纯度、build 里禁 `ref.read`）与禁止模式 | [../cross-cutting.md](../cross-cutting.md)「架构边界与形态约定」 |
| 依赖声明（`depend_on_referenced_packages`，以及有意不设门禁的几类） | [../cross-cutting.md](../cross-cutting.md)「依赖声明」 |
| 内存泄漏检测（`leak_tracker`） | [../cross-cutting.md](../cross-cutting.md)「Memory Leak Detection」 |
| 集成测试（`integration_test/`，含「widget 测试里不要用真实 I/O」） | [../cross-cutting.md](../cross-cutting.md)「Integration Testing」 |
| 环境配置与 release 构建（含「有意留白」） | [../cross-cutting.md](../cross-cutting.md)「环境配置与 release 构建」 |

---

## Testing Requirements

- 测试文件路径跟随源码结构：`test/features/{feature}/{subdir}/` 对应 `lib/features/{feature}/{subdir}/`
- 状态/逻辑测试用 `ProviderContainer` + `overrides` 注入假仓库，不需要任何全局注册表
  （`test/features/sample/logic/sample_list_notifier_test.dart` 是模板）
- 页面测试用 `test/support/app_test_harness.dart` 的 `setUpTestApp()` + `wrapPage(page, container:)`，
  依赖同样通过 `overrides` 换掉
- widget 测试的三条硬约束（不要 `await provider.future`、容器传 `retry: noRetry`、mocktail 的
  `verify` 会消耗命中次数）见 [state-management.md](./state-management.md)「Testing Requirements」
- Integration tests: `integration_test/` 目录（跑法与注意事项见 [../cross-cutting.md](../cross-cutting.md)）
- 新增 widget 测试时确保 `flutter_test_config.dart` 中的 `LeakTesting` 配置合适
