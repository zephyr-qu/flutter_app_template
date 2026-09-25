# Code Reuse Thinking Guide

> **Purpose**: Stop and think before creating new code — does it already exist?

---

## The Problem

**Duplicated code is the #1 source of inconsistency bugs.** 复制粘贴或重写已有逻辑，会让修复不传播、行为逐渐分叉、代码更难读懂。

---

## Before Writing New Code

### Step 1: Search First

```bash
grep -rn "getCachedItems" lib/    # 找同名 / 近名的定义
grep -rn "MockRule" lib/          # 找相似逻辑（关键词选项目里独特的那类）
```

### Step 2: Ask These Questions

| Question | If Yes... |
|----------|-----------|
| Does a similar function exist? | Use or extend it |
| Is this pattern used elsewhere? | Follow the existing pattern |
| Could this be a shared utility? | 放 `core/` —— 但要先过下面「3 次」那道线 |
| Am I copying code from another file? | **STOP** — extract to shared |

---

## Common Duplication Patterns

### Pattern 1: Copy-Paste Functions

**Bad**: 复制一个校验函数到别的文件 → **Good**: 抽到共享工具，按需 import。

### Pattern 2: Similar Components

**Bad**: 新建一个与现有组件 80% 相似的组件 → **Good**: 用 props / variant 扩展现有组件。

### Pattern 3: Repeated Constants

**Bad**: 同一个常量定义在多个文件 → **Good**: 单一出处，各处 import。

### Pattern 4: 同一个转换散落在各个消费者里

**Bad**：多个 Service 各自把 `DioException` 映射成 `Failure`，每个都维护一份「哪些状态码算超时」的判断。
**Good**：转换只发生在数据拥有者旁边 —— `handleDioError()`（`core/base/failure.dart`）。

**Rule**：同一个转换/判断被写到**第 2 处**时就该抽出来，不要等到第 3 处 —— 那时两份已经不一致了。

---

## When to Abstract

**Abstract when**: 同一段代码出现 3+ 次、复杂到会出 bug、2+ 个 feature 都需要它（提到 `core/` 的门槛）。
**Don't abstract when**: 只用一次、一行就写完、抽象比重复本身更复杂。

> ⚠️ **过早抽象是个人项目的头号杀手** —— 宁可重复写两次，也不要提前抽取不稳定的基类。见 [../frontend/directory-structure.md](../frontend/directory-structure.md) 的「共享层（core/）严格克制」。

---

## After Batch Modifications

批量改完多处相似代码后：**Review** 是否全改到了、**Search** 用 grep 找漏网的、**Consider** 该不该就此抽象。

### 状态分支用穷尽 `switch`，不要散落 `if/else`

「由某个值决定走哪条分支」的地方，都应该收敛成一处穷尽 `switch` —— Dart 的 sealed class + `switch` 会在漏掉分支时**编译报错**：

```dart
// BAD —— 新增一个 FailureCode 后，这里静默走 else
if (code == FailureCode.timeout) { ... }
else if (code == FailureCode.connection) { ... }
else { ... }

// GOOD —— 一处穷尽，漏了就编译不过
switch (code) {
  case FailureCode.timeout: ...
  case FailureCode.connection: ...
  // ...
}
```

`core/ui/failure_message.dart` 的 `localizedMessage` 与 `core/ui/async_view.dart` 的 `AsyncView` 都是这个形状：新增枚举值或状态子类型时，编译器会把你直接带到唯一需要改的地方。

---

## Checklist Before Commit

- [ ] Searched for existing similar code
- [ ] No copy-pasted logic that should be shared
- [ ] 常量只定义在一处
- [ ] Similar patterns follow same structure
- [ ] 新增枚举值后，所有 `switch` 都是穷尽的（让编译器告诉你，不要靠搜）
