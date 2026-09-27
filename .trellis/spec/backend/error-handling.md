# 错误处理

> 本项目的错误处理约定。

---

## 概览

本项目所有会失败的操作都走 **typed `Result` 模式**，不裸抛异常：统一返回 `Result<T, Failure>` —— 一个 sealed class，两个变体 `Ok(T data)` / `Err(E error)`。这样每一层都拿到类型安全的错误。

---

## 错误类型

### `Result` 类型（`lib/core/base/result.dart`）

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

**一律用 `Result.when()`** 做穷尽匹配；`getOrThrow` 只给测试用。

### `Failure` 层级（`lib/core/base/failure.dart`）

```dart
sealed class Failure implements Exception {
  const Failure({required this.code, this.statusCode});

  final FailureCode code;   // 枚举，见下表
  final int? statusCode;    // 仅 serverError / requestFailed 会带上
}

class NetworkFailure extends Failure { ... }   // 四个子类的归类与 code 见下表
```

直接实例化子类（`const NetworkFailure(code: FailureCode.timeout)`）；没有 `Failure.network(...)` 这类工厂构造了。

| Failure 类型 | 归类口径 | 典型 code |
| ------------- | ------------- | --------- |
| `NetworkFailure` | 请求没能正常往返：超时、连接失败、证书校验失败 | `timeout`, `connection`, `badCertificate` |
| `AuthFailure` | 401 / 403，无凭证或没有权限 | `unauthorized`, `forbidden` |
| `ServerFailure` | 服务端返回了失败响应（其余 4xx / 5xx） | `notFound`, `invalidRequest`, `conflict`, `serverError`, `requestFailed` |
| `UnknownFailure` | 无法归类的兜底 | `cancelled`, `unexpected`, `unknown` |

**`Failure` 不携带用户可见文案**：它只有 `code`（`FailureCode` 枚举）与可选的 `statusCode`，文案由展示层给出（`core/ui/failure_message.dart` 的 `localizedMessage()`，当前是一张中文常量表）。约束：

- 文案只在展示层；接多语言时只换展示层那一处（见 [frontend/localization.md](../frontend/localization.md)）
- 服务端的 `statusMessage`、`DioException.message` 这类原始文本只进日志（结构上没有存放位置）
- 新增 `FailureCode` 时补 `localizedMessage` 的 `switch`（穷尽性由编译器保证）。`test/core/ui/failure_message_test.dart` 既有逐条精确文案断言，也遍历 `FailureCode.values` 断言每个 code 的文案非空

已逐一映射的状态码：400 → `invalidRequest`、401 → `unauthorized`、403 → `forbidden`、404 → `notFound`、408 → `timeout`、409 → `conflict`、422 → `invalidPayload`、429 → `tooManyRequests`；其余 5xx → `serverError`（带状态码），其余 4xx → `requestFailed`（带状态码，文案里会显示它）。

### Dio 错误映射（`lib/core/base/failure.dart`）

`handleDioError()` 把 `DioException` 转成对应的 `Failure` 子类。Service 直接调它；没有别名，也没有 `Failure.fromApiError` 工厂。

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

Dio 客户端**不做**预映射 —— 映射只在 Service 层发生一次，保持单一出处。

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

- 另造包装异常，也不要 `throw Exception('...')`
- 引入 `userErrorMessage(failure)` 那种「在数据层把文案拼好」的做法
- 在 Notifier 里留 `currentFailure` 字段——`Failure` 对象就在 `AsyncValue.error` 里

> 401 / 403 按上表映射成 `AuthFailure`（`unauthorized` / `forbidden`）；本项目**无认证**，401 原样走到 Service 层。需要时自行接入「令牌 + 401 自动刷新」（见 [optional-additions.md](../../../docs/optional-additions.md)）。

---

## 错误处理范式

### Service 层（数据边界）

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

**范式规则**：

1. 先捕 `DioException`（最具体），用 `handleDioError()` 转换
2. 最后捕通用 `Exception`，记为 `FailureCode.unknown`（直接调 `runCatching(...)` 即可，它已包含这套 try/catch 顺序）
3. 永不重抛；一律返回 `Result.failure()`

### Notifier 层（逻辑边界）

状态层不手写三态迁移：`Result` 的失败侧**抛 `Failure` 本身**，剩下的交给 `AsyncValue` + `AsyncView`；完整示例与配套规则见「错误文案怎么到界面上」。

---

## 常见错误

- ❌ **Service / Repository 抛异常** — 一律返回 `Result.failure()`
- ❌ **生产代码里用 `getOrThrow`** — 只给测试；生产用 `when()`
- ❌ **在 Notifier 里手写 loading/data/error 迁移** — `AsyncNotifier.build()` 从 `Result` 翻译一次就够，渲染交给 `AsyncView`
- ❌ **把 `Failure` 包成别的异常再抛**
- ❌ **同一个 `DioException` 在多层各映射一次** — 只在 Service 映射一次
- ❌ **不处理取消** — `switch` 里必须含 `DioExceptionType.cancel`
