# 日志规范

> 本项目的日志约定。

---

## 概览

本项目在 `logger` 包外面包了一层 `Logging` 门面。所有日志都走 `Logging.info()` / `Logging.debug()` / `Logging.warning()` / `Logging.error()` —— 不直接调 `logger` 包，也不用 `print()`。

门面在 **`lib/core/logging/logging.dart`**。

---

## 日志级别

### `Logging.info(String message)`

- **什么时候用**：正常流程 —— 启动、配置载入、环境选择。例：`Logging.info('Network: BASE_URL=..., USE_MOCK=...')`

### `Logging.error(String message, {Object? exception, StackTrace? stackTrace})`

- **什么时候用**：非预期失败与错误兜底边界。例：`Logging.error('Unhandled platform error', exception: e, stackTrace: stackTrace)`

### `Logging.debug(String message)`

- **什么时候用**：开发期诊断 —— 状态变化、分支决策。例：`Logging.debug('reading cache: ${dir.path}')`

### `Logging.warning(String message)`

- **什么时候用**：可恢复 / 非预期但已处理的情况。例：`Logging.warning('响应体不是合法 JSON，保留原始字符串: $e')`

---

## Logger 配置

在门面里配置一次（`lib/core/logging/logging.dart`）：

```dart
class Logging {
  static final _logger = Logger(
    printer: PrettyPrinter(
      methodCount: 0, // 不打印调用栈（0 = 关闭）
      dateTimeFormat: DateTimeFormat.onlyTimeAndSinceStart,
    ),
  );
}
```

其余参数走 `PrettyPrinter` 默认值。彩色与 emoji 无条件开启，也没有按构建模式 tree-shaking 的包装：**不要在 release 里打高频日志**（每帧、每请求体）。

---

## 日志写在哪里

> 快照（2026-09）：改动相关代码时请同步本节。查全量：`grep -rn "Logging\." lib/`

| 位置（文件名相对 `lib/`） | 记什么 |
| --- | --- |
| `bootstrap.dart` | `PlatformDispatcher.instance.onError` 记一条 error；`FlutterError.onError` 保持默认的 `presentError`（不再重复记一遍） |
| `run_catching.dart` | 兜底 `catch` —— 原始异常只进日志，用户侧给一个可翻译的通用 code |
| `failure.dart` | 网络错误的 warning（未映射的状态码、响应缺少状态码等） |
| `sample_service.dart` / `file_storage.dart` / `user_preferences.dart` | 存储与缓存失败 —— 读失败降级记 warning；写失败按各自的失败策略处理（见 [database-guidelines.md](./database-guidelines.md) 的「读要软，写要硬」） |

`dio_factory.dart` 的解码拦截器会在 `text/plain` 响应体解析 JSON 失败时记一条 warning。

HTTP 请求/响应日志由 `PrettyDioLogger` 单独负责，条件是 `kDebugMode && preferences.enableDebugLogging`。

它的 `logPrint` 串了 `lib/core/logging/log_redactor.dart`：请求 / 响应体在落控制台之前逐行过 `LogRedactor.redact()`，`authorization` / `password` / `accessToken` / `refreshToken` 等字段的值换成 `***`。

- 脱敏在**已成型的日志行**上做（`PrettyDioLogger` 只给了 `logPrint` 一个回调，拿不到 `RequestOptions` / `Response`）
- `LogRedactor` 是**跨行带状态**的：`PrettyDioLogger` 按 `maxWidth`（默认 90）给长值折行。同一个实例要贯穿整条日志流，不要在回调里现建
- 新增敏感字段时同步 `LogRedactor.sensitiveKeys`，并在 `test/core/logging/log_redactor_test.dart` 里补一条

> **Notifier 里没有日志框架，也没有 `dispose()` 生命周期钩子。** Notifier 是 `@riverpod` 生成的普通 Dart 类；状态错误通过 `AsyncValue.error`（携带 `Failure`）流到界面，**不经过 logger**。需要在状态层记日志时直接用 `Logging` 门面，不要另建一套。
> 清理动作（流订阅、`Listenable`、控制器）登记在 `ref.onDispose`，见 [frontend/state-management.md](../frontend/state-management.md)「生命周期」。

---

## 什么不该记

🚫 **绝不记**：密码与认证令牌；含 PII 的完整请求 / 响应体；信用卡号、身份证号等敏感个人数据；未匿名化的设备标识。

✅ **要记**：生命周期里程碑（启动、环境、装配完成）；不含凭据的错误消息；可恢复的异常（`Logging.warning`）。
