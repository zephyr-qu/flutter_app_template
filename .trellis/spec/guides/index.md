# Thinking Guides

> **Purpose**: Expand your thinking to catch things you might not have considered.

---

## Why Thinking Guides?

**Most bugs and tech debt come from "didn't think of that"**, not from lack of skill：没想层边界 → 跨层 bug；没想重复 → 到处复制；没想边界情况 → 运行期错误；没想后续维护者 → 注释没人读。这些指南帮你 **ask the right questions before coding**。

---

## Available Guides

| Guide | Purpose | When to Use |
|-------|---------|-------------|
| [Code Reuse Thinking Guide](./code-reuse-thinking-guide.md) | Identify patterns and reduce duplication | 发现自己在复制粘贴时 |
| [Cross-Layer Thinking Guide](./cross-layer-thinking-guide.md) | Think through data flow across layers | 功能跨 Page / Notifier / Service / DAO 时 |
| [Comment Guidelines](./comment-guidelines.md) | 代码注释写什么、spec 引用与语言约定、长文放哪 | 写或改任何注释 / spec 时 |

---

## Quick Reference: Thinking Triggers

### When to Think About Cross-Layer Issues

- [ ] 功能跨 3+ 层（Page / Notifier / Service / DAO）
- [ ] 数据在两个层之间换了类型（`DioException` → `Failure`、模型 → drift 行类）
- [ ] 同一份数据既走网络又走缓存
- [ ] 不确定某段逻辑该放哪一层
- [ ] 要在 `core/` 和 feature 之间挪东西（先看依赖方向）

→ Read [Cross-Layer Thinking Guide](./cross-layer-thinking-guide.md)

### When to Think About Code Reuse

- [ ] You're writing similar code to something that exists
- [ ] You see the same pattern repeated 3+ times
- [ ] You're adding a new field to multiple places
- [ ] **You're modifying any constant or config**
- [ ] **You're creating a new utility/helper function** ← Search first!
- [ ] 同一个转换（如 `DioException` → `Failure`）被写到第 2 处

→ Read [Code Reuse Thinking Guide](./code-reuse-thinking-guide.md)

### When Verifying AI Cross-Review Results

- [ ] Reviewer claims "user input can be malicious" / "missing validation" → 先查数据真实来源（内部 manifest？用户配置？外部 API？）是不是本来就可信
- [ ] Reviewer says "behavior change" / flags a "bug" → 读代码注释确认是否为有意设计；把被测 feature 心理删掉，测试还过就是同义反复

**常见 AI 误报模式**：**信任边界混淆**（把内部数据当不可信外部输入）、**无视设计注释**（把注释里写明的有意行为报成 bug）、**变量读错**（没追到变量真正定义，如按 path 还是 name 建 key）。

**Verification rule**: Every CRITICAL/WARNING finding must be verified against the actual code before prioritizing. Budget ~35% false-positive rate for AI reviews.

---

## Pre-Modification Rule (CRITICAL)

> **Before changing ANY value, ALWAYS search first!** 这一个习惯就能挡住大多数「忘了同步 X」的 bug。

```bash
grep -r "value_to_change" .
```

---

## How to Use This Directory

**Before coding** 浏览相关思考指南；**During coding** 觉得重复或复杂时回来查；**After bugs** 把新教训写回对应指南。

---

## Contributing

Found a new "didn't think of that" moment? Add it to the relevant guide. 改写时注意：guides 只放**通用的思考方法**。具体的项目规则、命令、文件清单属于 `backend/` 或 `frontend/`，不要抄到这里 —— 两个地方写同一件事必然会漂。

---

**Core Principle**: 30 minutes of thinking saves 3 hours of debugging.
