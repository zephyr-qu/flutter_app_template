# 复用思考指南

> **目的**：写新代码之前先停一下 —— 是不是已经有了？

---

## 问题

重复逻辑是最大的不一致来源。

---

## 写新代码之前

### 第 1 步：先搜一遍

```bash
grep -rn "getCachedItems" lib/    # 找同名 / 近名的定义
grep -rn "MockRule" lib/          # 找相似逻辑（关键词选项目里独特的那类）
```

### 第 2 步：问这几个问题

| 问题 | 如果是… |
|----------|-----------|
| 已经有类似的函数？ | 复用它，或扩展它 |
| 别处用过这个写法？ | 照既有写法来 |
| 能做成共享工具？ | 放 `core/` —— 但要先过下面「3 次」那道线 |
| 在从别的文件复制代码？ | **停** —— 抽到共享处 |

---

## 常见重复形态

| 形态 | ❌ | ✅ |
| --- | --- | --- |
| 复制粘贴的函数 | 把校验函数复制到别的文件 | 抽到共享工具，按需 import |
| 相似组件 | 新建与现有组件 80% 相似的组件 | 用 props / variant 扩展现有组件 |
| 重复常量 | 同一个常量定义在多个文件 | 单一出处，各处 import |

### 同一个转换散落在多个消费者里

**反例**：多个 Service 各自把 `DioException` 映射成 `Failure`，每个都维护一份「哪些状态码算超时」的判断。
**正例**：转换只发生在数据拥有者旁边 —— `handleDioError()`（`core/base/failure.dart`）。

**规则**：同一个转换/判断被写到**第 2 处**时就该抽出来，不要等到第 3 处。

---

## 什么时候该抽

**该抽的时候**：同一段代码出现 3+ 次、复杂到会出 bug、2+ 个 feature 都需要它（提到 `core/` 的门槛）。**转换 / 判断类例外** —— 第 2 处就抽。
**不该抽的时候**：只用一次、一行就写完、抽象比重复本身更复杂。

> ⚠️ **不要提前抽取不稳定的基类** —— 宁可重复写两次。见 [../frontend/directory-structure.md](../frontend/directory-structure.md) 的「共享层（core/）严格克制」。

---

## 批量改动之后

批量改完多处相似代码后：**复查**是否全改到了、**搜索**用 grep 找漏网的、**考虑**该不该就此抽象。

### 状态分支用穷尽 `switch`，不要散落 `if/else`

「由某个值决定走哪条分支」的地方，都应该收敛成一处穷尽 `switch` —— Dart 的 sealed class + `switch` 会在漏掉分支时**编译报错**：

```dart
// 反例 —— 新增一个 FailureCode 后，这里静默走 else
if (code == FailureCode.timeout) { ... }
else if (code == FailureCode.connection) { ... }
else { ... }

// 正例 —— 一处穷尽，漏了就编译不过
switch (code) {
  case FailureCode.timeout: ...
  case FailureCode.connection: ...
  // ...
}
```

`core/ui/failure_message.dart` 的 `localizedMessage` 与 `core/ui/async_view.dart` 的 `AsyncView` 都是这个形状：新增枚举值或状态子类型时，编译器会把你直接带到唯一需要改的地方。

---

## 提交前清单

- [ ] 搜过有没有类似代码
- [ ] 没有「该共享却复制粘贴」的逻辑
- [ ] 常量只定义在一处
- [ ] 相似写法结构一致
- [ ] 新增枚举值后，所有 `switch` 都是穷尽的（让编译器告诉你，不要靠搜）
