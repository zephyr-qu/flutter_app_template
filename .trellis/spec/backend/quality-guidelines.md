# Quality Guidelines

> Code quality standards for the data and logic layers.

---

## Overview

These guidelines apply to:

- `lib/core/` — shared infrastructure
- `lib/features/*/data/` — API, service, repository, models
- `lib/features/*/logic/` — ViewModels

**架构边界**（`core/` 不得 import 上层、跨 feature 只共享 `data/`、ViewModel 不得用 service locator）以及所有门禁、测试基建与发布的约定，见 [../cross-cutting.md](../cross-cutting.md) —— 本文件不重复。

---

## Forbidden Patterns

❌ **Never use these patterns**:

1. **Bare `try/catch` without a `Result` type on public APIs** — all fallible repository/service methods must return `Result<T, Failure>`

   ```dart
   // BAD
   Future<List<Article>> getArticles() async { ... }

   // GOOD
   Future<Result<List<Article>, Failure>> getArticles() async { ... }
   ```

2. **`print()` in production code** — use the `Logging` facade (`Logging.info/debug/warning/error`). (`avoid_print` is not currently enabled in `analysis_options.yaml`; this is a review convention, not a lint error.)

3. **Raw `DioException` propagation to the ViewModel** — convert to a typed `Failure` in the Service layer

   ```dart
   // BAD
   throw e;  // letting DioException escape

   // GOOD
   return Result.failure(handleDioError(e));
   ```

4. **Cyclic imports between features** — a feature never imports another feature's `page/` or `logic/`

   ```dart
   // BAD — article feature reaching into auth's UI/logic
   import 'package:my_app/features/auth/page/login_page.dart';
   ```

5. **Business logic in the data layer** — 业务规则的**判断**（分支、阈值、策略）放 ViewModel；Service 只做转换与 I/O：调 API、读写缓存、把 `DioException` 映射成 `Failure`

6. **`getOrThrow` in production code** — only in tests; use `when()` for exhaustive matching

7. **Calling `getIt()` from a ViewModel** — inject the dependency through the constructor instead

---

## Required Patterns

✅ **Always use these patterns**:

1. **`Result<T, Failure>`** for all fallible operations in repository interfaces and service implementations

2. **Service annotation**: `@LazySingleton(as: SomeRepository)` — register the implementation against its interface

   ```dart
   @LazySingleton(as: ArticleRepository)
   class ArticleService implements ArticleRepository { ... }
   ```

3. **DI modules** for third-party/API dependencies:

   ```dart
   @module
   abstract class ArticleModule {
     @LazySingleton()
     ArticleApi articleApi(Dio dio) => ArticleApi(dio);
   }
   ```

4. **Repository abstraction is optional** — write `{Feature}Repository` only when there is a genuine multi-implementation need (mock / online switching). Simple features call the Service directly. When both exist, the interface is `{feature}_repository.dart` and the implementation `{feature}_service.dart` — both live in the feature's `data/` layer (there is no `domain/` layer).

5. **Sealed Failure subtypes**: 直接实例化子类并给出 `FailureCode`（`const NetworkFailure(code: FailureCode.timeout)`）。`Failure` 不携带用户可见文案——文案由展示层翻译，见 [error-handling.md](./error-handling.md)

6. **Private fields prefixed with `_`**

7. **Doc comments on public APIs**: `///` on repository/service methods, stating what the method does and which `Result` variants it returns

8. **Models**: annotate with `@freezed` (value semantics, `copyWith`, generated `fromJson`/`toJson`). 脚手架里所有模型都是 freezed（`Article` / `User` / `LoginRequest` / `LoginResponse`）。Never hand-edit the generated `*.g.dart` / `*.freezed.dart`

---

## Testing Requirements

- **Unit tests required for**:
  - ViewModel state transitions (loading → data, loading → error)
  - Failure paths, via `Result.failure()` mocks
  - Repository/Service error mapping where non-trivial
- **Test file location**: `test/features/{feature}/`
- **Testing libraries**: `flutter_test`, `mocktail`

---

## Code Review Checklist

When reviewing data-layer code, check:

- [ ] Does the method return `Result<T, Failure>` instead of throwing?
- [ ] Are all `DioException`s caught and converted via `handleDioError()`?
- [ ] Is the `catch` ordering correct? (specific → generic)
- [ ] Are DI annotations correct? (`@LazySingleton(as:)`, `@Singleton`, `@module`)
- [ ] Does the ViewModel use constructor injection rather than `getIt()`?
- [ ] Are generated files (`*.g.dart`) regenerated after model/annotation changes?
- [ ] Is there no import of another feature's `page/` or `logic/`?
- [ ] Does the module class only provide dependencies (no business logic)?
- [ ] Are debug prints avoided in production paths?
