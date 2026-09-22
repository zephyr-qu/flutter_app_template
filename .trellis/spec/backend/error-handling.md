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

  R when<R>({
    required R Function(T data) success,
    required R Function(E error) failure,
  });

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

class NetworkFailure extends Failure { ... }
class AuthFailure extends Failure { ... }
class ServerFailure extends Failure { ... }
class UnknownFailure extends Failure { ... }
```

直接实例化子类（`const NetworkFailure(code: FailureCode.timeout)`）；没有 `Failure.network(...)` 这类工厂构造了。

| Failure Type | 归类口径 | 典型 code |
| ------------- | ------------- | --------- |
| `NetworkFailure` | 请求没能正常往返：超时、连接失败、证书校验失败 | `timeout`, `connection`, `badCertificate` |
| `AuthFailure` | 401 / 403，需要重新登录或没有权限 | `unauthorized`, `forbidden` |
| `ServerFailure` | 服务端返回了失败响应（其余 4xx / 5xx） | `notFound`, `invalidRequest`, `conflict`, `serverError`, `requestFailed` |
| `UnknownFailure` | 无法归类的兜底 | `cancelled`, `unexpected`, `unknown` |

**`Failure` 不携带用户可见文案**：它只有 `code`（`FailureCode` 枚举）与可选的 `statusCode`，文案由展示层按当前语言翻译（`core/ui/failure_message.dart` 的 `localizedMessage`）。因此：

- core 层不会把语言钉死，切换语言后错误提示也跟着变
- 服务端的 `statusMessage`、`DioException.message` 这类原始文本**结构上就没有存放位置**，只进日志 —— 它们可能带 Dart 堆栈、请求 URL、内部字段名，展示给用户既没意义也不安全
- 新增一个 code，`localizedMessage` 的 switch 会因为不再穷尽而编译报错，同时提醒去补 ARB

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

`runCatching` / `runAsync` 的兜底 `catch` 同理：异常写进日志，返回 `FailureCode.unknown`。

### 错误文案怎么到界面上

`runAsync` 写进 `AsyncState.error` 的是 **`Failure` 对象**，不是字符串：

```dart
signal.value = AsyncState.error(failure);
```

展示层再用 `localizedMessage` 翻译：

```dart
// ErrorText 内部
final message = switch (error) {
  Failure failure => failure.localizedMessage(l10n),
  _ => l10n.errorUnknown,
};
```

SnackBar 之类的场景直接 `error.localizedMessage(l10n)`。**新代码不要**再引入 `userErrorMessage(failure)` 那种「core 里把文案拼好」的做法。

---

## 401 与令牌刷新

401 在到达 Service 层之前就由 `AuthInterceptor` 处理掉了，绝大多数情况下调用方根本看不到 401：

1. 请求带上 `Authorization: Bearer <accessToken>`
2. 收到 401 → `TokenRefresher.refresh()` 用刷新令牌换新令牌
3. 成功 → 用新令牌**重放原请求**，调用方拿到正常响应
4. 失败（没有刷新令牌 / 刷新接口也 401 / 网络错误）→ `AuthStorage.clearAuth()` 清除凭证 → 由路由守卫把用户送回登录页

**主动刷新**：服务端返回 `expiresIn`（秒）时，`AuthStorage` 会记下过期时刻；`onRequest` 里若判断「临近过期」（默认提前 30 秒）就先刷新再发请求，省掉一次「先 401 再刷新」的往返。服务端不给 `expiresIn` 时该判断恒为 false，退化成纯被动刷新。

几条不能破坏的约束：

- **`TokenRefresher` 必须是 single-flight 的**（并发调用共享同一个 Future）。服务端一旦轮换刷新令牌，并发刷新会让先到的那次把令牌换掉，后面几次拿着已失效的刷新令牌必然失败，用户被误登出。
- **`Dio` 必须是单例**。每个客户端各建一个 Dio 就会各带一套拦截器，single-flight 随之失效，mock 规则也会被重复注册。
- **防递归靠两个 `extra` 标记**（见 `auth_extra_keys.dart`）：刷新请求带 `kSkipAuthRefresh`，重放过的请求带 `kAuthRetried`，两者都不再触发刷新。缺少它们会导致刷新接口 401 时无限递归。
- **重放必须走同一个 Dio**，否则 mock / 日志 / 重试拦截器会被绕过——mock 模式下重放会直接打到真实网络。
- **刷新请求不携带访问令牌**：部分后端会因为无效的 `Authorization` 直接拒绝整个请求，连刷新都做不了。

以上行为由 `test/core/data/network/token_refresh_test.dart` 覆盖（真实 AuthStorage + TokenRefresher + AuthInterceptor，跑在真实 Dio 管道里，仅替换网络适配器）。

### 登出语义

`AuthService.logout()` 的约定：

1. 尽力通知服务端（带令牌，服务端据此吊销刷新令牌）
2. **无论第 1 步成功与否，都清掉本地凭证**
3. 返回 `Result.success` —— 对用户而言「登出」就是本地会话结束

第 2 步不能省：本地登出依赖网络的话，离线时 token 会一直留在设备上。
第 3 步的返回值也不该是服务端调用的结果，否则会出现「提示登出失败、实际已经登出」的矛盾。
服务端通知失败只记一条 warning。

登出成功后**调用方不需要自己导航**：`AuthStorage` 清空 → 登录态信号翻转 → `AppRouter` 的 `reevaluateListenable` → 守卫把用户送回登录页。自己再跳一次会产生两个 `LoginRoute`。

---

## Error Handling Patterns

### Service layer (data boundary)

```dart
@LazySingleton(as: ArticleRepository)
class ArticleService implements ArticleRepository {
  ArticleService(this._api, this._cache);   // 构造器注入（见 ADR-0001）

  @override
  Future<Result<List<Article>, Failure>> getArticles() async {
    final result = await runCatching(() => _api.getArticles());
    // 成功 → 刷新缓存；失败 → 回退缓存，未命中才返回原始 Failure
    ...
  }
}
```

实践中直接 `runCatching(...)` 即可，它已经包含了下面这套 try/catch 顺序。

**Pattern rules**:

1. Catch `DioException` first (most specific) and convert via `handleDioError()`
2. Catch generic `Exception` last as `FailureCode.unknown`（实践中直接调 `runCatching` 即可）
3. Never re-throw; always return `Result.failure()`

### ViewModel layer (logic boundary)

ViewModels do not hand-roll the tri-state transition — use the `runAsync` helper (`lib/core/base/run_async.dart`), which sets the signal to loading, then data or error, and returns the `Result` unchanged:

```dart
@injectable
class ArticleViewModel {
  final ArticleRepository _repo;
  final articles = asyncSignal<List<Article>>(AsyncState.loading());

  Future<void> loadArticles() async {
    await runAsync(articles, () => _repo.getArticles());
  }
}
```

There is no separate `currentFailure` signal — the `Failure` **object** is stored on `AsyncState.error(...)` itself, and the UI reads it through `async.map(loading:, error:, data:)`，再用 `localizedMessage(l10n)` 翻译成当前语言的文案（见「错误文案怎么到界面上」）。

---

## API Error Responses

Not applicable — this is a Flutter client project. API error mapping is handled in `handleDioError()` based on HTTP status codes.

---

## Common Mistakes

- ❌ **Throwing exceptions from Service/Repository** — always return `Result.failure()`
- ❌ **Using `getOrThrow` in production code** — only in tests; use `when()` in production
- ❌ **Hand-rolling loading/data/error transitions in a ViewModel** — use `runAsync`
- ❌ **Re-mapping the same `DioException` in multiple layers** — map once, in the Service
- ❌ **Not handling cancellation** — always include `DioExceptionType.cancel` in the switch
