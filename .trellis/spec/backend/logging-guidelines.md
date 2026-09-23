# Logging Guidelines

> How logging is done in this project.

---

## Overview

This project uses the **`logger`** package behind a custom `Logging` facade. All logging goes through `Logging.info()`, `Logging.debug()`, `Logging.warning()`, and `Logging.error()` — never call the `logger` package directly, and never use `print()`.

The facade lives at **`lib/core/logging/logging.dart`**.

---

## Log Levels

### `Logging.info(String message)`

- **When to use**: normal application flow — startup, config loaded, environment selected
- **Example**: `Logging.info('Environment: development (.env.development)')`

### `Logging.error(String message, {Object? exception, StackTrace? stackTrace})`

- **When to use**: unexpected failures and error boundaries
- **Example**: `Logging.error('Unhandled platform error', exception: e, stackTrace: stackTrace)`

### `Logging.debug(String message)`

- **When to use**: development-time diagnostics — state changes, branch decisions
- **Example**: `Logging.debug('reading cache: ${dir.path}')`

### `Logging.warning(String message)`

- **When to use**: recoverable / unexpected-but-handled conditions
- **Example**: `Logging.warning('响应体不是合法 JSON，保留原始字符串: $e')`

---

## Logger Configuration

Configured once inside the facade (`lib/core/logging/logging.dart`):

```dart
class Logging {
  static final _logger = Logger(
    printer: PrettyPrinter(
      methodCount: 0,       // no method trace for info/warning
      errorMethodCount: 8,  // stack depth shown for errors
      lineLength: 120,
      colors: true,
      printEmojis: true,
      dateTimeFormat: DateTimeFormat.onlyTimeAndSinceStart,
    ),
  );

  static void info(String message) => _logger.i(message);
  static void warning(String message) => _logger.w(message);
  static void debug(String message) => _logger.d(message);
  static void error(String message, {Object? exception, StackTrace? stackTrace}) { ... }
}
```

The pretty-printer applies colours/emojis unconditionally. There is no tree-shaking wrapper, so do not log high-frequency events (per-frame, per-request bodies) in release builds.

---

## 日志写在哪里

> 快照（2026-09）：改动相关代码时请同步本节。查全量：`grep -rn "Logging\." lib/`

按「谁在兜底」分四类：

| 位置 | 记什么 |
| --- | --- |
| `bootstrap.dart` | `PlatformDispatcher.instance.onError` 记一条 error；`FlutterError.onError` 保持默认的 `presentError`（不再重复记一遍） |
| `run_catching.dart` | 兜底 `catch` —— 原始异常只进日志，用户侧给一个可翻译的通用 code |
| `failure.dart` / `auth_interceptor.dart` / `token_refresher.dart` | 网络与令牌刷新路径的 warning / info（刷新成功、没有可用刷新令牌、未映射的状态码等） |
| `auth_storage.dart` / `sample_service.dart` / `file_storage.dart` / `user_preferences.dart` | 存储与缓存失败 —— 读失败降级记 warning；写失败按各自的失败策略处理（见 [database-guidelines.md](./database-guidelines.md) 的「读要软，写要硬」） |

`dio_client.dart` 另外会在 `text/plain` 响应体解析 JSON 失败时记一条 warning。

HTTP 请求/响应日志由 `PrettyDioLogger` 单独负责，条件是 `kDebugMode && preferences.enableDebugLogging`。

它的 `logPrint` 串了 `lib/core/logging/log_redactor.dart`：请求 / 响应体在落控制台之前逐行过
`LogRedactor.redact()`，`authorization` / `password` / `accessToken` / `refreshToken` 等字段的值
换成 `***` —— 上面「What NOT to Log」里的密码与令牌因此不会被调试日志带出去。

- 脱敏在**已成型的日志行**上做，是因为 `PrettyDioLogger` 只给了 `logPrint` 一个回调，
  拿不到可替换的 `RequestOptions` / `Response`（理由写在 `log_redactor.dart` 的文件注释里）
- 它是**跨行带状态**的：`PrettyDioLogger` 按 `maxWidth`（默认 90）给长值折行，只屏蔽命中那一行
  会把剩下的令牌漏出去。所以同一个 `LogRedactor` 实例要贯穿整条日志流，别在回调里现建
- 新增敏感字段时同步 `LogRedactor.sensitiveKeys`，并在 `test/core/logging/log_redactor_test.dart`
  里补一条 —— 漏了不会报错，只会静默漏值。

> **Notifier 里没有日志框架，也没有 `dispose()` 生命周期钩子。** Notifier 是 `@riverpod` 生成的
> 普通 Dart 类，没有 `addEffect` / 日志器可挂；状态错误通过 `AsyncValue.error`（携带 `Failure`）
> 流到界面，**不经过 logger**。需要在状态层记日志时直接用 `Logging` 门面，不要另建一套。
> 清理动作（流订阅、`Listenable`、控制器）登记在 `ref.onDispose`，
> 见 [frontend/state-management.md](../frontend/state-management.md)「生命周期」。

---

## What NOT to Log

🚫 **Never log**:

- Passwords or authentication tokens
- Full request/response bodies containing PII
- Credit card numbers, national IDs, or other sensitive personal data
- Device identifiers without anonymisation

✅ **Do log**:

- Lifecycle milestones (startup, environment, 装配完成)
- Error messages without credentials
- Recoverable anomalies (with `Logging.warning`)
