# Quality Guidelines

> Code quality standards for the data and logic layers.

---

## Overview

These guidelines apply to `lib/core/`（shared infrastructure）、`lib/features/*/data/`（API, service, repository, models）与 `lib/features/*/logic/`（Notifier：状态 + 业务编排）。

**架构边界**（`core/` 不得 import/export 上层、跨 feature 只共享 `data/`、`logic/` 不得 import/export `package:flutter/material.dart`）以及所有门禁、测试基建与发布的约定，见 [../cross-cutting.md](../cross-cutting.md) —— 本文件不重复。

---

## Forbidden Patterns

❌ **Never use these patterns**:

1. **Bare `try/catch` without a `Result` type on public APIs** — all fallible repository/service methods must return `Result<T, Failure>`

   ```dart
   Future<List<SampleItem>> getItems() async { ... }                            // BAD
   Future<Result<List<SampleItem>, Failure>> getItems() async { ... }            // GOOD
   ```

2. **`print()` in production code** — use the `Logging` facade (`Logging.info/debug/warning/error`). (`avoid_print` is not currently enabled in `analysis_options.yaml`; this is a review convention, not a lint error.)

3. **Raw `DioException` propagation to the Notifier** — convert to a typed `Failure` in the Service layer

   ```dart
   throw e;                                        // BAD — letting DioException escape
   return Result.failure(handleDioError(e));        // GOOD
   ```

4. **Cyclic imports between features** — a feature never imports another feature's `page/` or `logic/`

   ```dart
   // BAD — profile feature reaching into sample's UI/logic
   import 'package:my_app/features/sample/page/sample_list_page.dart';
   ```

5. **Business logic in the data layer** — 业务规则的**判断**（分支、阈值、策略）放 `logic/`；Service 只做转换与 I/O：调 API、读写缓存、把 `DioException` 映射成 `Failure`

6. **`getOrThrow` in production code** — only in tests; use `when()` for exhaustive matching

---

## Required Patterns

✅ **Always use these patterns**:

1. **`Result<T, Failure>`** for all fallible operations in repository interfaces and service implementations

2. **Service 与第三方 / API 依赖的绑定都在 provider 里** —— `{feature}_providers.dart` 让 provider 返回抽象类型：

   ```dart
   // features/sample/data/sample_providers.dart
   @Riverpod(keepAlive: true)
   SampleRepository sampleRepository(Ref ref) =>
       SampleService(ref.watch(sampleApiProvider), ref.watch(sampleDaoProvider));

   @Riverpod(keepAlive: true)
   SampleApi sampleApi(Ref ref) => SampleApi(ref.watch(dioProvider));
   ```

   （provider 本身就是注册表，见 [frontend/state-management.md](../frontend/state-management.md)「三种 Provider 形态」。）

3. **Repository abstraction is optional** — write `{Feature}Repository` only when there is a genuine multi-implementation need (mock / online switching). Simple features call the Service directly. When both exist, the interface is `{feature}_repository.dart` and the implementation `{feature}_service.dart` — both live in the feature's `data/` layer (there is no `domain/` layer).

4. **Sealed Failure subtypes**: 直接实例化子类并给出 `FailureCode`（`const NetworkFailure(code: FailureCode.timeout)`）。`Failure` 不携带用户可见文案——文案由展示层翻译，见 [error-handling.md](./error-handling.md)

5. **Private fields prefixed with `_`**

6. **Doc comments on public APIs**: `///` on repository/service methods, stating what the method does and which `Result` variants it returns

7. **Models**: annotate with `@freezed` (value semantics, `copyWith`, generated `fromJson`/`toJson`). 脚手架里所有模型都是 freezed（`SampleItem` 是现存唯一一个）。Never hand-edit the generated `*.g.dart` / `*.freezed.dart`

---

## Testing Requirements

- **Unit tests required for**: Notifier 的状态迁移（loading → data、loading → error）、Failure paths（`Result.failure()` mocks）、非平凡的 Repository/Service 错误映射
- **Test file location**: `test/features/{feature}/`
- **Testing libraries**: `flutter_test`, `mocktail`；provider 测试用 `ProviderContainer` + `overrides`（模板：`test/features/sample/logic/sample_list_notifier_test.dart`）

---

## Code Review Checklist

- [ ] Does the method return `Result<T, Failure>` instead of throwing?
- [ ] Are all `DioException`s caught and converted via `handleDioError()`?
- [ ] Is the `catch` ordering correct? (specific → generic)
- [ ] Are the providers wired correctly? (`@Riverpod(keepAlive: true)` for stateless services, provider 返回抽象类型)
- [ ] Does the Notifier take its dependencies from `ref`（而不是自己 new 或建容器）?
- [ ] Are generated files (`*.g.dart`) regenerated after model/annotation changes?
- [ ] Is there no import of another feature's `page/` or `logic/`?
- [ ] Does the Notifier hold no business I/O of its own (it delegates to Service / Repository)?
- [ ] Are debug prints avoided in production paths?
