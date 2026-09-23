# Code Reuse Thinking Guide

> **Purpose**: Stop and think before creating new code — does it already exist?

---

## The Problem

**Duplicated code is the #1 source of inconsistency bugs.**

When you copy-paste or rewrite existing logic:

- Bug fixes don't propagate
- Behavior diverges over time
- Codebase becomes harder to understand

---

## Before Writing New Code

### Step 1: Search First

```bash
# 找同名 / 近名的定义
grep -rn "getCachedItems" lib/

# 找相似逻辑（关键词选项目里独特的那类）
grep -rn "MockRule" lib/
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

**Bad**: Copying a validation function to another file

**Good**: Extract to shared utilities, import where needed

### Pattern 2: Similar Components

**Bad**: Creating a new component that's 80% similar to existing

**Good**: Extend existing component with props/variants

### Pattern 3: Repeated Constants

**Bad**: Defining the same constant in multiple files

**Good**: Single source of truth, import everywhere

### Pattern 4: 同一个转换散落在各个消费者里

**Bad**：多个 Service 各自把 `DioException` 映射成 `Failure`，每个都维护一份「哪些状态码算超时」的判断。

**Good**：转换只发生在数据拥有者旁边 —— `handleDioError()`（`core/base/failure.dart`）。

**Rule**：同一个转换/判断被写到**第 2 处**时就该抽出来，不要等到第 3 处 —— 那时两份已经不一致了。

---

## When to Abstract

**Abstract when**:

- Same code appears 3+ times
- Logic is complex enough to have bugs
- Multiple features need it（提到 `core/` 的门槛是 2+ 个 feature 用它）

**Don't abstract when**:

- Only used once
- Trivial one-liner
- Abstraction would be more complex than duplication

> ⚠️ **过早抽象是个人项目的头号杀手** —— 宁可重复写两次，也不要提前抽取不稳定的基类。见 [../frontend/directory-structure.md](../frontend/directory-structure.md) 的「共享层（core/）严格克制」。

---

## After Batch Modifications

When you've made similar changes to multiple files:

1. **Review**: Did you catch all instances?
2. **Search**: Run grep to find any missed
3. **Consider**: Should this be abstracted?

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
