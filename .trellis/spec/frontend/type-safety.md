# 类型安全

> 本项目的类型安全约定。

---

## 概览

本项目用 **Dart 3+**、开启完整 **null safety**。类型安全来自四样东西：`sealed` 的 `Result` / `Failure`（穷举匹配）、`@freezed` 模型（值语义 + 生成的 `fromJson` / `toJson`）、`strict-casts` / `strict-inference` 等类型 lint（全表见「实际启用的类型相关 lint」）、泛型 `Result<T, E>`。

---

## 类型组织

### 模型（放在各 feature 的 `data/models/`）

脚手架里的模型**全部**用 `@freezed`（现存唯一一个是 `SampleItem`）：

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

**规则**：

- `fromJson` / `toJson` 由 freezed 生成（内部走 `json_serializable`），**不要手写**
- 后端字段名与 Dart 命名不一致时用 `@JsonKey(name: ...)`；`json_annotation` 必须留在 `dependencies`（它是 `json_serializable` 的构建期契约，别删，见 [cross-cutting.md](../cross-cutting.md)「依赖声明」）
- **简单 DTO 也不换注解**（如手写 `@JsonSerializable` 模型）—— 哪怕只有两个字段也仍然用 `@freezed`
- 字段一律 `final` 且非空（显式可空的除外）；构造器用 `required` 具名参数
- 生成物 `*.g.dart` / `*.freezed.dart` 与源文件同目录，**不要手改**
- **构造器不重复类名**：统一写成 `const new({super.key})` / `const factory({...})` / `factory fromJson(...)`（Dart 3.13 允许省略类名的构造器声明），而不是 `const SampleItem({...})`；照抄 `features/sample/` 的形状

### 全局类型（`core/base/`）

`sealed class Result<T, E>`（泛型结果）与 `sealed class Failure`（错误层级）都在 `lib/core/base/`。

### 生成类型

- `*.g.dart` — JSON serialization（`json_serializable`）、Retrofit、Drift、**Riverpod 的 provider**（`@riverpod` 生成 `<file>.g.dart`，provider 名由生成器决定）
- `*.freezed.dart` — `copyWith` / `==` / `hashCode`；`*.gr.dart` — auto_route；`*.config.dart` — 本项目**不存在**（不使用 injectable，没有 service locator 生成物）
- 改完注解跑 `just codegen`；**不要手改生成文件**

---

## 校验

运行时校验遵循「**简单校验放在边界**」的写法：

```dart
// 状态快照上的 getter（如「提交按钮是否可用」这类判据）
bool get canSubmit => name.isNotEmpty && note.length >= 6;

// API 侧：Retrofit 定义（features/sample/data/sample_api.dart 的形状）
@GET('/sample-items')
Future<List<SampleItem>> getItems();
```

- 客户端：简单字段校验做成快照上的 getter，不引入校验库
- 服务端：复杂校验全部交给后端；不引入 schema 校验库（没有 Zod 等价物），靠 Dart 类型系统

---

## 常见范式

### sealed class 模式匹配

```dart
result.when(
  success: (user) => context.router.replaceRoute(const HomeRoute()),
  failure: (failure) => _showError(context, failure),
);
```

`Failure` **不携带用户可见文案**（只有 `code` 与可选 `statusCode`），展示层用 `failure.localizedMessage()`（无参数）取中文常量；文案写在哪见 [localization.md](./localization.md)「文案写在哪」。

### 异步状态判定

用 `AsyncView` 渲染**不需要 `!` 强解包**：`data` 回调拿到的 `T` 非空，`error` 回调拿到的 `Object` / `StackTrace` 也非空（`AsyncView` 内部判过 `hasValue` / `hasError`）。调用形状见 [quality-guidelines.md](./quality-guidelines.md)「必须遵守」；判定顺序与 `data(null)` 这条定制语义见 [state-management.md](./state-management.md)「渲染状态」。

### 实际启用的类型相关 lint

`analysis_options.yaml` 里与类型有关的规则只有这些（写新代码时按此预期，别假设有更多）：

| 规则 | 作用 |
| --- | --- |
| `strict-casts` | 禁止隐式 `dynamic` 向下转型 |
| `strict-inference` | 推断失败时报错，而不是退化成 `dynamic` |
| `always_declare_return_types` | 方法必须写返回类型 |
| `prefer_final_locals` | 不重新赋值的局部变量用 `final` |
| `prefer_const_constructors_in_immutables` | 不可变类用 `const` 构造 |

---

## 禁止模式

以下大部分是 **review 约定**，不都是 lint error（想确认强度请对照 `analysis_options.yaml`）：

- ❌ **用 `dynamic` 类型** — 用带类型的泛型或 `Object?`
- ❌ **不判空就 `as` 强转** — 用模式匹配或 `is` 判断
- ❌ **把裸 `Map<String, dynamic>` 当 API 响应** — 一律反序列化成带类型的模型
- ❌ **没判空就用 `!`** — 用模式匹配或提前返回
- ❌ **给 `Failure` 加回 `message`** — 文案在展示层翻译，见 `backend/error-handling.md`
