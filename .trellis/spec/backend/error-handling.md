# Error Handling

> How errors are handled in this project.

> **Scaffold note**: This is a personal Flutter scaffold/template. The typed Result pattern is the standard for all fallible operations across data and logic layers. The `Failure` hierarchy and `handleDioError()` utility are the intended patterns for all new features.

---

## Overview

This project uses a **typed Result pattern** instead of bare exceptions for all fallible operations. Every operation that can fail returns `Result<T, Failure>` — a sealed class with `Ok(T data)` or `Err(E error)` variants. This ensures **type-safe error handling** at every layer.

---

## Error Types

### Result Type (`lib/core/base/result.dart`)

```dart
sealed class Result<T, E> {
  const Result();

  const factory Result.success(T data) = Ok<T, E>;
  const factory Result.failure(E error) = Err<T, E>;

  R when<R>({required R Function(T data) success, required R Function(E error) failure});

  Result<R, E> map<R>(R Function(T data) transform);
  Result<T, F> mapError<F>(F Function(E error) transform);
  Result<R, E> flatMap<R>(Result<R, E> Function(T data) transform);

  bool get isSuccess => this is Ok<T, E>;
  bool get isFailure => this is Err<T, E>;
  T get getOrThrow;
}
```

**Always use `Result.when()`** for exhaustive pattern matching. `getOrThrow` is for tests only.

### Failure Hierarchy (`lib/core/base/failure.dart`)

```dart
sealed class Failure implements Exception {
  const Failure({required this.code, this.statusCode});

  final FailureCode code;   // 枚举，见下表
  final int? statusCode;    // 仅 serverError / requestFailed 会带上
}

class NetworkFailure extends Failure { ... }   // 四个子类的归类与 code 见下表
```

直接实例化子类（`const NetworkFailure(code: FailureCode.timeout)`）；没有 `Failure.network(...)` 这类工厂构造了。

| Failure Type | 归类口径 | 典型 code |
| ------------- | ------------- | --------- |
| `NetworkFailure` | 请求没能正常往返：超时、连接失败、证书校验失败 | `timeout`, `connection`, `badCertificate` |
| `AuthFailure` | 401 / 403，无凭证或没有权限 | `unauthorized`, `forbidden` |
| `ServerFailure` | 服务端返回了失败响应（其余 4xx / 5xx） | `notFound`, `invalidRequest`, `conflict`, `serverError`, `requestFailed` |
| `UnknownFailure` | 无法归类的兜底 | `cancelled`, `unexpected`, `unknown` |

**`Failure` 不携带用户可见文案**：它只有 `code`（`FailureCode` 枚举）与可选的 `statusCode`，文案由展示层给出（`core/ui/failure_message.dart` 的 `localizedMessage()`，当前是一张中文常量表）。因此：

- 数据层与状态层都不会把文案钉死在错误对象里；将来要接多语言，只需换掉展示层那一处（见 [frontend/localization.md](../frontend/localization.md)）
- 服务端的 `statusMessage`、`DioException.message` 这类原始文本**结构上就没有存放位置**，只进日志 —— 它们可能带 Dart 堆栈、请求 URL、内部字段名，展示给用户既没意义也不安全
- 新增一个 code，`localizedMessage` 的 switch 会因为不再穷尽而编译报错，提醒去补文案；`test/core/ui/failure_message_test.dart` 还会遍历 `FailureCode.values` 断言每个都有非空文案

已逐一映射的状态码：400 → `invalidRequest`、401 → `unauthorized`、403 → `forbidden`、404 → `notFound`、408 → `timeout`、409 → `conflict`、422 → `invalidPayload`、429 → `tooManyRequests`；其余 5xx → `serverError`（带状态码），其余 4xx → `requestFailed`（带状态码，文案里会显示它）。

### Dio Error Handling (`lib/core/base/failure.dart`)

`handleDioError()` converts a `DioException` to the appropriate `Failure` subtype. Services call it directly — there is no alias and no `Failure.fromApiError` factory.

```dart
Failure handleDioError(DioException e) {
  switch (e.type) {
    case DioExceptionType.connectionTimeout:
    case DioExceptionType.receiveTimeout:
    case DioExceptionType.sendTimeout:
      return const NetworkFailure(code: FailureCode.timeout);
    case DioExceptionType.connectionError:
      return const NetworkFailure(code: FailureCode.connection);
    case DioExceptionType.badCertificate:
      return const NetworkFailure(code: FailureCode.badCertificate);
    case DioExceptionType.badResponse:
      return _handleBadResponse(e); // 按状态码映射，见上表
    case DioExceptionType.cancel:
      return const UnknownFailure(code: FailureCode.cancelled);
    default:
      // 原始异常只进日志，这里给一个可翻译的通用 code
      return const UnknownFailure(code: FailureCode.unexpected);
  }
}
```

The Dio client does **not** pre-map errors — mapping happens once, in the Service layer, so there is a single source of truth.

`runCatching` 的兜底 `catch` 同理：异常写进日志，返回 `FailureCode.unknown`。

### 错误文案怎么到界面上

承载错误的是 **`Failure` 对象**，不是字符串。异步状态里 `AsyncNotifier.build()` 把 `Result` 的失败侧**抛出去**（抛的就是 `Failure` 本身）：

```dart
// lib/features/sample/logic/sample_list_notifier.dart
return switch (result) {
  Ok<List<SampleItem>, Failure>(:final data) => data,
  Err<List<SampleItem>, Failure>(:final error) => throw error,
};
```

`AsyncValue.error` 原样带着它，`AsyncView` 的 `error` 回调再交给 `ErrorText` 翻译：

```dart
// ErrorText 内部
final message = switch (error) {
  final Failure failure => failure.localizedMessage(),
  _ => '未知错误',
};
```

SnackBar 之类的场景直接 `error.localizedMessage()`。**新代码不要**：

- 另造一个包装异常，也不要 `throw Exception('...')`——错误码一丢，`ErrorText` 只剩「未知错误」
- 引入 `userErrorMessage(failure)` 那种「在数据层把文案拼好」的做法
- 在 Notifier 里留 `currentFailure` 字段——`Failure` 对象就在 `AsyncValue.error` 里

> 401 / 403 仍按上表映射成 `AuthFailure`（`unauthorized` / `forbidden`），但本项目**无认证**：没有任何拦截器会自动重试或刷新令牌，401 会原样走到 Service 层。需要时自行接入「令牌 + 401 自动刷新」（判断规则见 [optional-additions.md](../../../docs/optional-additions.md)）。

---

## Error Handling Patterns

### Service layer (data boundary)

```dart
class SampleService implements SampleRepository {
  new(this._api, this._cache);   // 构造器注入；装配在 sample_providers.dart

  @override
  Future<Result<List<SampleItem>, Failure>> getItems() async {
    final result = await runCatching(_api.getItems);
    // 成功 → 刷新缓存；失败 → 回退缓存，未命中才返回原始 Failure
    ...
  }
}
```

**Pattern rules**:

1. Catch `DioException` first (most specific) and convert via `handleDioError()`
2. Catch generic `Exception` last as `FailureCode.unknown`（实践中直接调 `runCatching(...)` 即可，它已包含这套 try/catch 顺序）
3. Never re-throw; always return `Result.failure()`

### Notifier layer (logic boundary)

状态层不手写三态迁移：`Result` 的失败侧**抛 `Failure` 本身**，剩下的交给 `AsyncValue` + `AsyncView`；完整示例与配套规则见「错误文案怎么到界面上」。

---

## API Error Responses

Not applicable — this is a Flutter client project. API error mapping is handled in `handleDioError()` based on HTTP status codes.

---

## Common Mistakes

- ❌ **Throwing exceptions from Service/Repository** — always return `Result.failure()`
- ❌ **Using `getOrThrow` in production code** — only in tests; use `when()` in production
- ❌ **Hand-rolling loading/data/error transitions in a Notifier** — `AsyncNotifier.build()` 从 `Result` 翻译一次就够，渲染交给 `AsyncView`
- ❌ **把 `Failure` 包成别的异常再抛** — 错误码会丢，界面只剩「未知错误」
- ❌ **Re-mapping the same `DioException` in multiple layers** — map once, in the Service
- ❌ **Not handling cancellation** — always include `DioExceptionType.cancel` in the switch
