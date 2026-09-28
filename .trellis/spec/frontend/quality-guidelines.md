# Quality Guidelines

> UI 层（页面 / 组件 / hooks）的代码规范。门禁、测试基建与发布相关的约定见 [../cross-cutting.md](../cross-cutting.md)。

---

## Forbidden Patterns

❌ **Never use these patterns**:

1. **`print()` in production code** — Use `Logging.info()` / `Logging.error()` instead.

2. **Hardcoded colors/fonts/padding** — Always use `Theme.of(context)` or `colorScheme`.

3. **Business logic in widgets** — All async operations belong in ViewModels or Services.

4. **Direct ViewModel instantiation** — Always `getIt<ArticleViewModel>()`.

5. **ViewModel creation in `build()`** — Creates new instance per rebuild, old one leaks. Use `getIt` + `useMemoized`.

6. **`setState()` for async/API data** — Use `asyncSignal` for data fetching.

7. **`withOpacity()`** — Use `Color.withValues(alpha: X)` (Dart 3+).

8. **`getIt()` in ViewModels** — ViewModels must use constructor injection. `no_service_locator_in_logic` enforces this for `features/*/logic/`.

9. **Feature imports another feature's page/ or logic/** — Only core/ and another feature's data/ are allowed. Also enforced by `packages/app_lints`; it additionally forbids `core/` importing `features/` or `app/`.

10. **凭据放进 URL query** — 密码、访问令牌、刷新令牌等只能走**请求体**。query 会进入服务端访问日志、代理日志、浏览器或崩溃上报，等同于明文泄露。同理不要把令牌拼进 query 参数——`Authorization` 头统一由 `AuthInterceptor` 附加（见 `features/auth/data/models/login_request.dart`）。

11. **页面取 ViewModel 却不留可选注入点** — 只有 `getIt<XxxViewModel>()` 而没有那三行，页面测试就只能退回 `setUpTestApp()` 装配全局容器。必须有 `final XxxViewModel? viewModel;`、构造参数 `this.viewModel`、`viewModel ?? getIt<XxxViewModel>()`；`page_must_expose_view_model_injection_point` 规则拦提交，理由见 [ADR-0001](../../../docs/adr/ADR-0001.md)。

12. **logic 层 import UI** — `features/*/logic/` 里出现 `material.dart` / `widgets.dart` 或本 feature 的 `page/` 文件，说明把 Widget / BuildContext 塞进了状态层。`no_material_import_in_logic` 规则拦提交（`foundation` 放行，`ChangeNotifier` / `@visibleForTesting` 在 ViewModel 里正当），见 [cross-cutting.md](../cross-cutting.md)「架构边界与代码形态」。

---

## Required Patterns

✅ **Always use these patterns**:

1. **Three-state rendering in every async page** — 用 `AsyncView`（`core/ui/async_view.dart`）：

   ```dart
   AsyncView<List<Article>>(
     state: async,
     loading: () => const LoadingIndicator(),
     error: (Object error, StackTrace stackTrace) =>
         ErrorText(error: error, onRetry: vm.loadArticles),
     data: (items) => items.isEmpty
         ? const EmptyWidget(message: '暂无数据')
         : ListView.builder(...),
   )
   ```

   **不要用 `AsyncState.map`**：它的 `error` 回调签名在运行期才校验，写错会直接红屏（见 [state-management.md](./state-management.md)）。`lib/` 里的调用会被 `avoid_async_state_map` 拦下来（[cross-cutting.md](../cross-cutting.md)「架构边界与代码形态」）。

2. **`runAsync` for async operations**:

   ```dart
   await runAsync(_articles, () => _repo.getArticles());
   ```

3. **`Theme.of(context)` at start of build**:

   ```dart
   final theme = Theme.of(context);
   ```

4. **`const` constructors** for all widgets.

5. **`useSignalValue` for hook-based signal consumption**:

   ```dart
   final async = useSignalValue(vm.articles);
   ```

---

## Error Handling Hierarchy

```
FlutterError.onError        → Flutter 框架错误（保持默认 presentError：红屏 + 完整堆栈）
PlatformDispatcher.onError  → 未捕获的异步错误（根 zone，兜底）→ 记一条 error 日志
  └─ AuthInterceptor.onError    → 401 先刷新令牌并重放，失败才登出
  └─ Result<_, Failure>         → 业务层错误（类型安全）
  └─ runAsync                   → ViewModel 层错误统一处理
```

- 所有 API 调用返回 `Result<T, Failure>`（业务层不抛异常）
- 所有 ViewModel 用 `runAsync` 处理 async 三态
- 401 由 `AuthInterceptor` 自动处理：刷新令牌 → 重放原请求 → 仍失败则清除 auth 并由守卫跳登录页
- 以上都漏掉的由 `PlatformDispatcher.instance.onError` 兜底并记日志

两条容易被「顺手加回来」的：

- **不要再用 `runZonedGuarded`** —— 它与 `PlatformDispatcher.instance.onError` 覆盖同一批错误，Flutter 现行推荐后者。
- **`FlutterError.onError` 不要再包一层 `Logging.error`** —— 框架错误本来就会经过它，默认的 `presentError` 已经把红屏与完整堆栈打出来了。

> ⚠️ **这些兜底的产物只到控制台。** `Logging` 用的是 `logger` 的默认输出（stdout），没有自定义 `output:` ——
> release 版上 Android 进 logcat、iOS 基本丢弃，用户和你都拿不到。生产环境的真兜底要靠崩溃上报
> （Sentry / Crashlytics）或写本地日志文件，**目前都没有**。

### 拦截器顺序（`NetworkModule.dio()`）

见 [backend/network-guidelines.md](../backend/network-guidelines.md) —— 顺序图、两条不可破的
语义、以及相关的两个测试都记在那里，本文件不再重复。

---

## 门禁、测试与发布

以下内容不属于 UI 层，已移到 [Cross-Cutting Concerns](../cross-cutting.md)，本文件不重复：

| 内容 | 见 |
| --- | --- |
| 架构边界（`no_upper_import_in_core` / `cross_feature_only_data` / `no_material_import_in_logic` / `no_service_locator_in_logic` / `page_must_expose_view_model_injection_point`）与禁止模式 | [../cross-cutting.md](../cross-cutting.md)「架构边界与代码形态」 |
| 代码形态约定（`avoid_async_state_map`、`comment_block_too_long`） | [../cross-cutting.md](../cross-cutting.md)「架构边界与代码形态」 |
| 覆盖率（不设门禁） | [../cross-cutting.md](../cross-cutting.md)「覆盖率」 |
| 依赖声明（`depend_on_referenced_packages`） | [../cross-cutting.md](../cross-cutting.md)「依赖声明」 |
| 内存泄漏检测（`leak_tracker`） | [../cross-cutting.md](../cross-cutting.md)「Memory Leak Detection」 |
| 集成测试（`integration_test/`，含「widget 测试里不要用真实 I/O」） | [../cross-cutting.md](../cross-cutting.md)「Integration Testing」 |
| 环境配置与 release 构建（含「有意留白」） | [../cross-cutting.md](../cross-cutting.md)「环境配置与 release 构建」 |

---

## Testing Requirements

- 测试文件路径跟随源码结构：`test/features/{feature}/{subdir}/` 对应 `lib/features/{feature}/{subdir}/`
- ViewModel 测试直接构造，无需 DI（`ArticleViewModel(mockRepo)`）
- 需要 DI 的 widget 测试：`setUp`/`tearDown` 中注册/清理 mock
- Integration tests: `integration_test/` 目录（跑法与注意事项见 [../cross-cutting.md](../cross-cutting.md)）
- 新增 widget 测试时确保 `flutter_test_config.dart` 中的 `LeakTesting` 配置合适
