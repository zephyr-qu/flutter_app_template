# 执行计划：spec 漂移对比报告

## 前置

| 角色 | 路径 | 变量 |
|---|---|---|
| 本地（master，Signals 栈） | `F:/App/flutter_app_template` | `$L` |
| 兄弟分支工作树（`preset/ai-starter`，Riverpod 栈） | `F:/App/新建文件夹/flutter_app_template` | `$S` |

**只读约束**：全部命令以 `$L` 为 cwd，对 `$S` 只用 `read` / `git -C "$S"` 读取类操作。
调查前后各跑一次 `git -C "$S" status --short` 比对，作为"未改动兄弟工作树"的证据。

## 对比维度（判定规则）

每条差异按两个正交问题打分，落到四态之一：

1. **栈耦合度**：正文是否出现 `riverpod` / `@riverpod` / `AsyncValue` / `ref.watch` / `ProviderScope`？
   - 否 → 栈无关，可原样移植
   - 是 → 需改写或直接不适用
2. **对 master 是否增量**：master 对应文件是否已覆盖同一主题？
   - 已覆盖且更完整 → 反向判定「master 更好，不取」
   - 未覆盖 → 是真缺口

## 步骤

### 1. spec 层三态清单

```bash
# 兄弟侧（含未跟踪新文件）
git -C "$S" status --short -- .trellis/spec
find "$S/.trellis/spec" -name '*.md' | sort
find "$L/.trellis/spec" -name '*.md' | sort
```

产出：只在 S / 只在 L / 两侧皆有 三组文件清单。

### 2. 兄弟侧新增目录的定位

对 `$S/.trellis/spec/{index.md,type-safety.md,directory-structure.md,data/,ui/}` 逐个读：

- 它取代了 `backend/` 还是 `frontend/` 的哪几篇？
- 与 master 现存的哪篇对应？（例：`data/` ↔ master `backend/`；`ui/` ↔ master `frontend/`）

产出：新结构 → master 旧结构的映射表。

### 3. 两侧都有但不同的文件：取 diff

对每个同名文件跑：

```bash
diff -u "$L/.trellis/spec/<f>" "$S/.trellis/spec/<f>"
```

判读要点：

- 差异是**结构性**（拆分/合并/索引）还是**内容性**（规则增删）？结构性差异优先看，收益最大。
- 兄弟侧把规则写短了 → 检查是否只是精简，别把 master 的信息量抄丢。
- 逐条 diff 落地成表格一行，别贴大段 diff 到报告里。

### 4. 上层文档对比

`AGENTS.md` / `README.md` / `BRANCH.md`：跑 `diff -u`，只记**读者面与契约**层面的差异
（谁能读到什么、AI 被要求做什么），不记措辞微调。

`docs/`：先看兄弟侧 `$S/docs/` 现有文件清单，再对同名文件 diff。注意 master 的
`docs/adr/`、`architecture-review.md` 在兄弟分支**已删除**——需判断是「过时」还是「被别处取代」。

### 5. 写报告

`report.md` 结构：

1. 结论摘要（Top 3 可移植项 + 成本）
2. 取料源与判据（$L/$S 路径、两分支 HEAD、四态判定定义）
3. spec 层三态全清单表（**覆盖每一个文件**）
4. 逐条可移植项：落点文件 + 具体改哪节 + 栈耦合度
5. 需改写项：原思路 + Signals 口径怎么落地
6. 「不取」清单 + 理由
7. 未决问题（需用户拍板的，如是否采用 `data/`+`ui/` 的主题化分层）

## 验证

- [ ] `find "$S/.trellis/spec" -name '*.md'` 的每个文件都出现在报告的表里
- [ ] `find "$L/.trellis/spec" -name '*.md'` 同上
- [ ] 报告里每条"可移植"都能指到具体文件+小节
- [ ] `git -C "$S" status --short` 与步骤 0 一致
- [ ] 本地 `git status` 只有新任务目录与 `.trellis/.developer`（后者为 gitignore 内）

## 回滚点

只写 `.trellis/tasks/10-10-spec-drift-vs-preset-ai-starter/report.md` 一个文件；
要回滚就删它 + 归档任务目录，`$L` 的既有文档全程未被触碰。
