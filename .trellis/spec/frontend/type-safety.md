# Type Safety

> Type safety patterns in this project.

> **Scaffold note**: This is a personal Flutter scaffold/template for medium-small apps. The type-safety patterns below (sealed `Result` / `Failure`, `@freezed` models, typed route params) are the standard for all features built from this scaffold.

---

## Overview

This project is written in **Dart 3+** with full **null safety** enabled. Type safety is enforced through:

- **Sealed classes** (`sealed class`) for exhaustive pattern matching — `Result`, `Failure`, `AsyncState`
- **`@freezed`** for every model: value semantics (`copyWith` / `==` / `hashCode`) + generated `fromJson` / `toJson`
- **`strict-casts` / `strict-inference`** plus `always_declare_return_types`（见 `analysis_options.yaml`）
- **Generic Result type** `Result<T, E>` for typed error handling

---

## Type Organization

### Models (per feature, in `data/models/`)

脚手架里的模型**全部**用 `@freezed`（`Article` / `User` / `LoginRequest` / `LoginResponse`）——没有手写的，也没有直接用 `@JsonSerializable` 的：

```dart
// lib/features/article/data/models/article.dart
@freezed
sealed class Article with _$Article {
  const factory Article({
    required int id,
    required String title,
    required String body,
  }) = _Article;

  factory Article.fromJson(Map<String, dynamic> json) => _$ArticleFromJson(json);
}
```

**Rules**:

- `fromJson` / `toJson` 由 freezed 生成（内部走 `json_serializable`），**不要手写**
- 后端字段名与 Dart 命名不一致时用 `@JsonKey(name: ...)`，例如登录请求体保持后端的 `pwd`（`features/auth/data/models/login_request.dart`）
- **不要为了简单 DTO 换一套注解** —— 哪怕只有两个字段（`LoginRequest` 就是），也仍然用 `@freezed`。混进 `@JsonSerializable` 等于多出第二套生成流程和第二种 `fromJson` 写法，`build_runner` 与 review 都要记两份，而省下的只是一个 `const factory`
- All fields are `final` and non-nullable (unless explicitly nullable)
- Constructors use `required` named parameters
- 生成物 `*.g.dart` / `*.freezed.dart` 与源文件同目录，**不要手改**

### Global types (`core/base/`)

```dart
sealed class Result<T, E> { ... }  // Generic result type
sealed class Failure { ... }        // Error hierarchy
```

### Generated types

- `*.g.dart` — JSON serialization、`@injectable`、Retrofit、Drift
- `*.freezed.dart` — `copyWith` / `==` / `hashCode`
- `*.gr.dart` — auto_route
- `*.config.dart` — injectable service locator（`lib/di/service_locator.config.dart`）
- 改完注解跑 `dart run build_runner build`；**never edit generated files manually**

---

## Validation

Runtime validation follows **primitive validation at the boundary** pattern:

```dart
// ViewModel 侧：简单字段校验用 computed getter
bool get canSubmit => email.value.isNotEmpty && password.value.length >= 6;

// API 侧：Retrofit 定义。凭据只走请求体，不进 query（见 frontend/quality-guidelines.md）
@POST('/login')
Future<LoginResponse> login(@Body() LoginRequest request);
```

- Client-side: Simple field validation in ViewModel computed getters
- Server-side: All complex validation delegated to the backend
- No schema validation library (no Zod equivalent) — use Dart type system

---

## Common Patterns

### Sealed class pattern matching

```dart
result.when(
  success: (user) => context.router.replaceRoute(const HomeRoute()),
  failure: (failure) => _showError(context, failure),
);
```

`Failure` **不携带用户可见文案**（只有 `code` 与可选 `statusCode`），文案在展示层按当前语言翻译：

```dart
final message = failure.localizedMessage(AppLocalizations.of(context));
```

### Signal state checking

用 `AsyncView` 渲染，**不需要 `!` 强解包**——分支由 sealed class 的穷尽 `switch` 保证，`data` / `error` 回调拿到的都是非空类型：

```dart
final async = useSignalValue(vm.articles);

AsyncView<List<Article>>(
  state: async,
  loading: () => const LoadingIndicator(),
  error: (Object error, StackTrace stackTrace) => ErrorText(error: error),
  data: (items) => ListView.builder(...), // items: List<Article>（非空）
)
```

### Type-related lints actually enabled

`analysis_options.yaml` 里与类型有关的规则只有这些（写新代码时按此预期，别假设有更多）：

| 规则 | 作用 |
| --- | --- |
| `strict-casts` | 禁止隐式 `dynamic` 向下转型 |
| `strict-inference` | 推断失败时报错，而不是退化成 `dynamic` |
| `always_declare_return_types` | 方法必须写返回类型 |
| `prefer_final_locals` | 不重新赋值的局部变量用 `final` |
| `prefer_const_constructors_in_immutables` | 不可变类用 `const` 构造 |

---

## Forbidden Patterns

以下大部分是 **review 约定**，不都是 lint error（想确认强度请对照 `analysis_options.yaml`）：

- ❌ **`dynamic` type** — Use typed generics or `Object?` instead
- ❌ **`as` casts without null checks** — Use pattern matching or `is` checks
- ❌ **Raw `Map<String, dynamic>` as API response** — Always deserialize into typed models
- ❌ **`print()` for debugging** — Use `Logging.debug()` or `Logging.error()`（`avoid_print` 未启用）
- ❌ **Manually written `fromJson`/`toJson`** — 交给 `@freezed` 生成
- ❌ **`!` null assertions without prior null check** — Use pattern matching or early returns
- ❌ **给 `Failure` 加回 `message`** — 文案在展示层翻译，见 `backend/error-handling.md`
