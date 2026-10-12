# 类型安全

## 概览

项目用 Dart 3+（完整 null safety）。类型安全靠三件事：`sealed` 的 `Result` / `Failure`（穷举匹配）、`@freezed` 模型（值语义 + 生成 `fromJson` / `toJson`）、`strict-casts` / `strict-inference` 等 lint。这三项分别对应下方「类型组织」（模型与全局类型）、「常见范式」（使用方式）与「实际启用的类型相关 lint」（约束清单）。

---

## 类型组织

### 模型（放在各 feature 的 `data/models/`）

模型一律用 `@freezed`（当前唯一示例是 `SampleItem`）：

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

- `fromJson` / `toJson` 由 freezed 生成，不要手写
- 字段名与后端不一致用 `@JsonKey(name: ...)`；`json_annotation` 留在 `dependencies`（见 [cross-cutting.md](./cross-cutting.md)「依赖声明」）
- 即使简单 DTO 也用 `@freezed`，不要手写 `@JsonSerializable`
- 字段一律 `final` 且非空（显式可空除外）；构造器用 `required` 具名参数
- 生成物 `*.g.dart` / `*.freezed.dart` 与源文件同目录，不要手改
- 构造器省略类名：写 `const factory({...})` / `factory fromJson(...)`，照抄 `features/sample/`

### 全局类型（`core/base/`）

`sealed class Result<T, E>`（泛型结果）与 `sealed class Failure`（错误层级）都在 `lib/core/base/`。

### 生成类型

- `*.g.dart` — `json_serializable`、Retrofit、Drift、Riverpod provider 的生成物
- `*.freezed.dart` — `copyWith` / `==` / `hashCode`；`*.gr.dart` — auto_route
- `*.config.dart` — 本项目不用（无 injectable）
- 改完注解跑 `just codegen`，不要手改生成文件

---

## 校验

遵循「简单校验放在边界」：

```dart
// 状态快照上的 getter（提交按钮是否可用等判据）
bool get canSubmit => name.isNotEmpty && note.length >= 6;

// API 侧（features/sample/data/sample_api.dart 的形状）
@GET('/sample-items')
Future<List<SampleItem>> getItems();
```

- 客户端：简单字段校验做成快照 getter，不引入校验库
- 服务端：复杂校验交给后端，靠 Dart 类型系统

---

## 常见范式

### sealed class 模式匹配

```dart
result.when(
  success: (user) => context.router.replaceRoute(const HomeRoute()),
  failure: (failure) => _showError(context, failure),
);
```

`Failure` 不携带用户可见文案，文案由展示层翻译（`failure.localizedMessage()` 取中文常量）；约束见 [error-handling.md](./data/error-handling.md)「错误类型」。

### 异步状态判定

用 `AsyncView` 渲染不需要 `!` 强解包：`data` / `error` 回调的对象都已判空。调用形状见 [quality-guidelines.md](./ui/quality-guidelines.md)「必须遵守」；`data(null)` 的定制语义见 [state-management.md](./ui/state-management.md)「渲染状态」。

---

## 实际启用的类型相关 lint

`analysis_options.yaml` 中与类型有关的规则只有这些：

| 规则 | 作用 |
| --- | --- |
| `strict-casts` | 禁止隐式 `dynamic` 向下转型 |
| `strict-inference` | 推断失败时报错，而不是退化成 `dynamic` |
| `always_declare_return_types` | 方法必须写返回类型 |
| `prefer_final_locals` | 不重新赋值的局部变量用 `final` |
| `prefer_const_constructors_in_immutables` | 不可变类用 `const` 构造 |

---

## 禁止模式

以下大部分是 review 约定，不都是 lint error：

- ❌ **用 `dynamic` 类型** — 用带类型的泛型或 `Object?`
- ❌ **不判空就 `as` 强转** — 用模式匹配或 `is` 判断
- ❌ **把裸 `Map<String, dynamic>` 当 API 响应** — 一律反序列化成带类型的模型
- ❌ **没判空就用 `!`** — 用模式匹配或提前返回
- ❌ **给 `Failure` 加回 `message`** — 文案在展示层翻译，见 `data/error-handling.md`
