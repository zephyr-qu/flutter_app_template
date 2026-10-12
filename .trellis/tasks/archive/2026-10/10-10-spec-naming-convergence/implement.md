# 执行计划：spec 命名与语言收敛（分两阶段）

## 前置

| 读什么 | 为什么 |
|---|---|
| `.trellis/tasks/10-10-spec-drift-vs-preset-ai-starter/report.md` §3.1 §7 | 每篇的「借结构不借内容」判定 |
| `F:/App/新建文件夹/flutter_app_template/.trellis/spec/`（**只读**） | 目标结构的形态参考（Riverpod 口径，只借结构） |

**只读约束**：`F:/App/新建文件夹/flutter_app_template` 全程只读。**不要提交**（用户逐轮授权）。

## 目标结构

```
.trellis/spec/
├── index.md                     # 唯一入口（改写：分层改为 工程结构 / UI / 数据层 / 跨层与门禁 / 思考指南）
├── cross-cutting.md             # 跨层与门禁
├── directory-structure.md       # 由 frontend/directory-structure.md 并入 backend/directory-structure.md 的内容
├── type-safety.md               # ← frontend/type-safety.md
├── guides/                      # 不动目录名
│   ├── index.md  comment-guidelines.md  code-reuse-thinking-guide.md
│   ├── cross-layer-thinking-guide.md  rename-checklist.md
├── data/                        # ← backend/ 的 5 篇细则
│   ├── database-guidelines.md  error-handling.md  logging-guidelines.md
│   ├── network-guidelines.md   quality-guidelines.md
└── ui/                          # ← frontend/ 的 5 篇
    ├── component-guidelines.md  quality-guidelines.md  state-management.md
    ├── localization.md          hook-guidelines.md
```

**删除**：`backend/index.md`、`frontend/index.md`（职责已由根 `index.md` 承担）、
`backend/directory-structure.md`（内容并入根 `directory-structure.md` 后删）。

---

## Phase A：改名 + 链接同步（先做完并让门禁绿灯，再进 B）

### A1. `git mv`

| 从 | 到 |
|---|---|
| `backend/{database-guidelines,error-handling,logging-guidelines,network-guidelines,quality-guidelines}.md` | `data/` 同名 |
| `frontend/{component-guidelines,quality-guidelines,state-management,localization,hook-guidelines}.md` | `ui/` 同名 |
| `frontend/type-safety.md` | `type-safety.md` |
| `frontend/directory-structure.md` | `directory-structure.md` |

用 `git mv`（保留历史），不要手写新文件再删旧文件。

### A2. 合并根 `directory-structure.md`

以 `frontend/directory-structure.md` 为基底，并入 `backend/directory-structure.md` 的两件事：

- **数据层的文件角色**表（`{feature}_api/_service/_repository/_dao/_module` + `models/`）——
  放在「Feature 目录模板」小节下，作为该节的一部分。
- **数据流**要点（`page/ → logic/ → data/ → core/` 的依赖方向、`Dto/Model` 只在该层转换、
  **缓存旁路**）。注意 `guides/cross-layer-thinking-guide.md` 已有层图与跨层契约的详解 ——
  这里只留**布局事实**，细节指向那篇，别抄第二份。
- `backend/directory-structure.md` 的 `## Generated Code` 两条**不要抄进来**：
  `cross-cutting.md` 的「代码生成与生成物」是唯一权威，这里留一行指过去即可。
- 合并后**必须仍然含 `lib/` 的完整目录树**（`check_readme_tree.dart` 要解析它，见 A4）。

引用的写法（`<层>/<文件>.md「<章节关键词>」`）照 `guides/comment-guidelines.md`，合并后本文件里的
指向也要改成新路径（例：原来指向 `../frontend/type-safety.md` → 指向 `./type-safety.md`）。

### A3. 同步路径引用（Phase A 实测：51 个文件 / 146 处）

规则（按顺序替换，避免二次替换踩到自己的输出）：

| 旧 | 新 |
|---|---|
| `backend/database-guidelines.md` 等 5 篇细则 | `data/<同名>` |
| `backend/directory-structure.md` | `directory-structure.md` |
| `backend/index.md`、`frontend/index.md` | `index.md`（根 spec 索引） |
| `frontend/{component-guidelines,quality-guidelines,state-management,localization,hook-guidelines}.md` | `ui/<同名>` |
| `frontend/type-safety.md` | `type-safety.md` |
| `frontend/directory-structure.md` | `directory-structure.md` |

覆盖面自查（同一条命令应只剩**允许的残留**）：

```bash
git grep -n "backend/\|frontend/" -- . ':!.trellis/tasks/archive' ':!.pi' ':!.agents' \
  ':!.trellis/workspace' ':!.trellis/scripts/task.py' ':!.trellis/workflow.md'
```

**允许残留**（不要改，各有理由）：

| 位置 | 理由 |
|---|---|
| `.trellis/tasks/archive/**` | 历史记录（归档任务里的旧路径是当时的真实状态） |
| `.pi/**`、`.agents/**` | vendored 第三方文档 |
| `.trellis/workspace/**` | 开发者 journal 是日志 |
| `.trellis/scripts/task.py`、`.trellis/workflow.md` | Trellis 自带的 **`cli/backend` 示例路径**（不是本仓库 spec），改了会被 `trellis update` 覆盖 |

其余**一处不留**：`lib/`（29 个 dart 文件 38 条）、`test/`、`tool/`、`test/tool/`、
`packages/app_lints/lib/src/rules.dart`、`README.md`、`AGENTS.md`、`BRANCH.md`、`docs/**`、
`.cursor/rules/*.mdc`、`.trellis/spec/**`。

### A4. 代码与门禁的同步（**最易静默失效，逐条做**）

| 文件 | 改什么 | 不改会怎样 |
|---|---|---|
| `tool/check_doc_links.dart:56` | 规则 B 正则 `(?:backend|frontend|guides)` → `(?:data|ui|guides)`；文件头注释里的 `backend/xxx.md` 例子同步 | 门禁**永远绿灯**，因为它再也不匹配任何引用 |
| `test/tool/check_doc_links_test.dart` | 所有 fixture 与断言里的 `backend/error-handling.md` → `data/...`、`frontend/state-management.md` → `ui/...` | 测试仍绿但测的是废弃形态 |
| `tool/check_readme_tree.dart:30` | `targets` 里的 `.trellis/spec/frontend/directory-structure.md` → `.trellis/spec/directory-structure.md`（**外加**新增 `localization.md` 那类裁剪后仍在的文档时另议） | `just test-readme-tree` 报「文档不存在」，或更糟：指向已删文件 |
| `tool/prune.dart` | `:142`、`:637`（`Replacement` 的**目标路径**）、`:710`、`:711`、`:785` 的 spec 路径 | prune 对着不存在的文件做替换，静默不生效；写进派生项目的注释也带错路径 |
| `.trellis/spec/cross-cutting.md:97` | 目录树门禁的 targets 表路径同步 | 文档与实现不一致 |

### A5. 改写根 `index.md`

- 分层改为：**工程结构 / UI / 数据层 / 跨层与门禁 / 思考指南**。
- 索引表路径全部改指新结构（`ui/*`、`data/*`、根 `directory-structure.md`、根 `type-safety.md`）。
- 「完成前自检」里目录树那句的门禁覆盖范围改为 `README.md` 与 **根 `directory-structure.md`**。
- 索引表仍要覆盖 **21 篇**（数量不变，只是路径变）：

```bash
find .trellis/spec -name '*.md' | grep -v 'spec/index.md' | wc -l    # → 18（改名后共 19 篇，含 index.md）
```

### A6. Phase A 验证（必须全绿才进 B）

```bash
dart run tool/check_doc_links.dart     # ✅ 全绿
just verify                            # 全绿（含 test-readme-tree、test-doc-links、app_lints 规则测试）
git grep -n "backend/\|frontend/" -- . ':!.trellis/tasks/archive' ':!.pi' ':!.agents' \
  ':!.trellis/workspace' ':!.trellis/scripts/task.py' ':!.trellis/workflow.md'   # 应无输出
git status --short                     # 无生成物
git -C "F:/App/新建文件夹/flutter_app_template" status --short   # 仍为 M 7 / ?? 4
```

---

## Phase B：标题中文化

### B1. 范围（收窄的决定）

- **改**：每份 spec 的文档标题（`#`）与所有 `##` / `###` 标题里的英文 → 中文（含 `index.md` 的 `## UI` → `## 界面（UI）`，中文在前、术语在后）。
**并同步 `guides/comment-guidelines.md` 的「spec 文档的语言」条款** —— 它现在写着「固定章节名用英文」
与「文档标题（`# Database Guidelines`）」，不改则 Phase B 做完当场自相矛盾。
- **不改**：表格表头、代码块内的 `// BAD` / `// GOOD` 之类标签、代码与标识符。

**理由**：表头与代码内标签不参与 `路径「章节」` 引用，改它们只增 churn 不改可读性；
标题才是引用与导航的锚点。这与 `guides/comment-guidelines.md` 的「层目录 + 章节关键词」引用约定直接相关。

### B2. 统一译法（同一概念只用一种译法）

| 英文 | 中文 | 英文 | 中文 |
|---|---|---|---|
| Overview | 概览 | Common Mistakes | 常见错误 |
| Naming Conventions | 命名约定 | Code Review Checklist | Code Review 清单 |
| What NOT to Log | 什么不该记 | Testing Requirements | 测试要求 |
| Log Levels | 日志级别 | Type Organization | 类型组织 |
| Logger Configuration | Logger 配置 | Validation | 校验 |
| Query Patterns | 查询范式 | Forbidden Patterns | 禁止模式 |
| Error Types | 错误类型 | Required Patterns | 必须遵守 |
| Error Handling Patterns | 错误处理范式 | Page Structure | 页面结构 |
| Data flow | 数据流 | Props Conventions | Props 约定 |
| Generated Code | 生成代码 | Styling Patterns | 样式范式 |
| Theme Layer | 主题层 | Shared Widgets | 共享组件 |
| Three-State Rendering | 三态渲染 | Accessibility | 无障碍 |
| Page Template | 页面模板 | Data Fetching | 取数 |
| Metrics / Layout | （按实际标题定） | Integration Testing | 集成测试 |
| Memory Leak Detection | 内存泄漏检测 | Cross-Cutting Concerns | 跨层与门禁 |

原则：**专有名词保持原文**（Drift、Dio、Provider、ViewModel、Code Review、l10n、lint、Mock）。

### B3. 改每个标题时同步引用

已知会被引用的英文标题与引用数（`git grep -n "「<旧标题>」"` 逐个核，**以实测为准**）：

| 旧标题 | 引用处 |
|---|---|
| `Theme Layer` | 4 处（含 `lib/core/theme/*.dart` 注释） |
| `Naming Conventions` | 2 处（含 `.cursor/rules/project-conventions.mdc`） |
| `What NOT to Log` | 1 处 |
| `Memory Leak Detection` / `Integration Testing` | `cross-cutting.md` 内引用 |

**流程**：改一个标题 → 立刻 `git grep -n "「<旧标题>」"` → 把引用一起改掉 → 下一个。
不要先批量改标题再统一找引用（会漏）。

### B4. Phase B 验证

```bash
# 英文标题应为 0（专有名词开头的标题除外，逐条判断并在报告里说明）
grep -rnE "^#{1,3} [A-Za-z]" .trellis/spec/ | grep -vE "^.*:# (Drift|Dio|Provider|HTTP|Code Review|Mock|l10n|lint)"
dart run tool/check_doc_links.dart
just verify
git grep -n "「Theme Layer」\|「Naming Conventions」\|「What NOT to Log」"   # 应无输出
```

---

## 不改清单（写进结论）

- `.trellis/tasks/archive/**`、`.pi/**`、`.agents/**`、`.trellis/workspace/**` —— 历史/vendored。
- `.trellis/scripts/task.py`、`.trellis/workflow.md` —— Trellis 自带 `cli/backend` 示例路径。
- 兄弟分支工作树 —— 只读。
- **`backend/*` 的英文正文不翻译**：`report.md` §7 已核过，本地正文信息量（key 命名、读软写硬、
  drift `part` 约束、`@DriftAccessor` 报错文本）比兄弟版足，翻译是净损失。只改标题。

## 回滚点

两阶段各自可独立回滚：Phase A 是 `git mv` + 文本替换，`git checkout` / `git mv` 反向即可；
Phase B 是标题与引用文本。**Phase A 完成后先让它全绿再进 B**，便于定位是哪一阶段引入的问题。
