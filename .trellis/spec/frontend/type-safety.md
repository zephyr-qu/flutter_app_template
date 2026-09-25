# Type Safety

> Type safety patterns in this project.

> **Scaffold note**: This is a personal Flutter scaffold/template for medium-small apps. The type-safety patterns below (sealed `Result` / `Failure`, `@freezed` models, typed route params) are the standard for all features built from this scaffold.

---

## Overview

This project is written in **Dart 3+** with full **null safety** enabled. Type safety comes from four things: `sealed` 的 `Result` / `Failure`（穷举匹配）、`@freezed` 模型（值语义 + 生成的 `fromJson` / `toJson`）、`strict-casts` / `strict-inference` 等类型 lint（全表见「Type-related lints actually enabled」）、泛型 `Result<T, E>`。

---

## Type Organization

### Models (per feature, in `data/models/`)

脚手架里的模型**全部**用 `@freezed`（现存唯一一个是 `SampleItem`）——没有手写的，也没有直接用 `@JsonSerializable` 的：

```dart
// lib/features/sample/data/models/sample_item.dart
@freezed
sealed class SampleItem with _$SampleItem {
  const factory({
    required int id,
    required String title,
    required String body,
  }) = _SampleItem;

  factory fromJson(Map<String, dynamic> json) => _$SampleItemFromJson(json);
}
```

**Rules**:

- `fromJson` / `toJson` 由 freezed 生成（内部走 `json_serializable`），**不要手写**
- 后端字段名与 Dart 命名不一致时用 `@JsonKey(name: ...)`；`json_annotation` 必须留在 `dependencies`（它是 `json_serializable` 的构建期契约，别删，见 [cross-cutting.md](../cross-cutting.md)「依赖声明」）
- **不要为了简单 DTO 换一套注解** —— 哪怕只有两个字段也仍然用 `@freezed`：混进 `@JsonSerializable` 就是第二套生成流程与第二种 `fromJson` 写法，`build_runner` 与 review 都要记两份
- All fields are `final` and non-nullable (unless explicitly nullable); constructors use `required` named parameters
- 生成物 `*.g.dart` / `*.freezed.dart` 与源文件同目录，**不要手改**
- **构造器不重复类名**：统一写成 `const new({super.key})` / `const factory({...})` / `factory fromJson(...)`（Dart 3.13 允许省略类名的构造器声明），而不是 `const SampleItem({...})`；照抄 `features/sample/` 的形状，不要「顺手改成老写法」

### Global types (`core/base/`)

`sealed class Result<T, E>`（泛型结果）与 `sealed class Failure`（错误层级）都在 `lib/core/base/`。

### Generated types

- `*.g.dart` — JSON serialization（`json_serializable`）、Retrofit、Drift、**Riverpod 的 provider**（`@riverpod` 生成 `<file>.g.dart`，provider 名由生成器决定）
- `*.freezed.dart` — `copyWith` / `==` / `hashCode`；`*.gr.dart` — auto_route；`*.config.dart` — 本项目**不存在**（不使用 injectable，没有 service locator 生成物）
- 改完注解跑 `just codegen`；**never edit generated files manually**

---

## Validation

Runtime validation follows **primitive validation at the boundary** pattern:

```dart
// 状态快照上的 getter（如「提交按钮是否可用」这类判据）
bool get canSubmit => name.isNotEmpty && note.length >= 6;

// API 侧：Retrofit 定义（features/sample/data/sample_api.dart 的形状）
@GET('/sample-items')
Future<List<SampleItem>> getItems();
```

- Client-side: 简单字段校验做成快照上的 getter，不引入校验库
- Server-side: 复杂校验全部交给 backend；不引入 schema 校验库（没有 Zod 等价物），靠 Dart 类型系统

---

## Common Patterns

### Sealed class pattern matching

```dart
result.when(
  success: (user) => context.router.replaceRoute(const HomeRoute()),
  failure: (failure) => _showError(context, failure),
);
```

`Failure` **不携带用户可见文案**（只有 `code` 与可选 `statusCode`），展示层用 `failure.localizedMessage()`（无参数）按当前语言取中文常量；文案写在哪见 [localization.md](./localization.md)「文案写在哪」。

### Async state checking

用 `AsyncView` 渲染**不需要 `!` 强解包**：`data` 回调拿到的 `T` 非空，`error` 回调拿到的 `Object` / `StackTrace` 也非空（`AsyncView` 内部判过 `hasValue` / `hasError`）。调用形状见 [quality-guidelines.md](./quality-guidelines.md)「Required Patterns」；判定顺序与 `data(null)` 这条定制语义见 [state-management.md](./state-management.md)「渲染状态」。

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
