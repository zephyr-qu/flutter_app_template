# 执行计划：spec 单一入口收敛

## 前置

| 读什么 | 为什么 |
|---|---|
| `.trellis/tasks/10-10-spec-drift-vs-preset-ai-starter/report.md` §4.1 §8.4 | 本任务全部改动的依据与行号 |
| `F:/App/新建文件夹/flutter_app_template/.trellis/spec/index.md`（**只读**） | 唯一入口的结构参考；正文按 master 口径重写 |
| `justfile` | README「常用命令」只能列它里面真实存在的 recipe |
| `lib/bootstrap.dart`、`README.md`（环境配置节） | 校准 `.cursor` 规则的 dotenv 口径 |

**只读约束**：`F:/App/新建文件夹/flutter_app_template` 全程只读，不得写入。

## 步骤

### 1. 新建 `.trellis/spec/index.md`

结构（顺序固定）：

```
# Spec 索引
> 总入口：本文件只列入口与共享约定，每层细则见各自目录下的 .md。
## 开工前必读      ← 按「要动什么」列检查项，每条指向一个文件
## 完成前自检      ← 可勾选
## 工程结构 / 前端 / 数据层 / 跨层与门禁 / 思考指南   ← 索引表，21 篇全覆盖
## 相关文档        ← workflow.md、guides/comment-guidelines.md
```

**开工前必读**至少覆盖（指向 master 现有路径）：

- 写页面 / ViewModel / 状态适配 → `frontend/state-management.md`
- UI、组件、主题 → `frontend/component-guidelines.md`、`frontend/quality-guidelines.md`
- 新建 feature、增删文件、判断文件该放哪 → `frontend/directory-structure.md`（canonical 布局）
- 数据层（API / Service / DAO / Repository / 模型 / 网络 / 错误 / 日志）→ `backend/index.md`
- 门禁、codegen、集成测试、环境配置、架构边界规则 → `cross-cutting.md`
- 动手前先铺思路 → `guides/index.md`
- 改名 / 初始化新项目 → `guides/rename-checklist.md`

**完成前自检**（master 口径，逐条核对后写）：

- [ ] `just verify` 全绿（清单见根 `justfile`）
- [ ] 涉及 `@freezed` / `@RoutePage` / `@injectable` / Drift 表或增删文件 → 已跑 `just codegen`
- [ ] 架构边界没破（`core/` 不引上层、跨 feature 只共享 `data/`、`logic/` 不碰 `material`/`widgets`
      与本 feature 的 `page/`、`logic/` 不用 `getIt`、取 ViewModel 的页面给足注入点三件套、
      不用 `AsyncState.map`、注释块 ≤10 行）—— 判据见 `cross-cutting.md`
- [ ] 新增 `FailureCode` 已补 `lib/core/ui/failure_message.dart` 的文案，
      `test/core/ui/failure_message_test.dart` 能覆盖到
- [ ] 增删 `lib/` 文件 → 同步 `README.md` 与 `frontend/directory-structure.md` 的目录树（**无门禁，靠人**）
- [ ] 改动触到 spec 描述的约定 → 同步对应 `.md`

**索引表**：把 `find .trellis/spec -name '*.md'` 的每一篇都排进去（本文件自己除外）。写完用这条核对：

```bash
find .trellis/spec -name '*.md' | grep -v 'spec/index.md' | wc -l   # → 21
```

### 2. 两份索引去重

`backend/index.md`：保留 `## Guidelines Index` 表，删掉 `## 跨层与门禁`(20)、`## 相关目录`(26)、
`## 写文档时的约定`(34) 三段，代之以一行：

```markdown
---

跨层与门禁、其它层的入口见 [Spec 索引](../index.md)。
```

`frontend/index.md` 同法（删 21 / 27 / 35）。两份的 `## Guidelines Index` 与开头引言保留。

### 3. 指针改指根 index（4 个文件，逐处核对行号后再改）

- `AGENTS.md:102-104`
- `.cursor/rules/project-conventions.mdc:20`
- `.trellis/spec/cross-cutting.md:4`
- `tool/prune.dart:143`

改完核对：

```bash
git grep -n "backend/index.md\|frontend/index.md"
```

应当只剩：根 `index.md` 的索引表、`backend/index.md` 自指、`frontend/index.md` 自指（及其表内互链）。

### 4. 修 `.cursor/rules/project-conventions.mdc`

- 规则 3「环境配置」整条改写为 dotenv 口径。核对来源：`README.md`「环境配置与 release 构建」
  与 `lib/bootstrap.dart:3,35,48`。**验收时该文件不得再出现 `dart-define`**。
- 「六条规则」→ 七条；与 `cross-cutting.md:12` 那节列出的 7 个规则名对齐。

### 5. 消歧两处标题

- `cross-cutting.md:235` 的 `### 禁止模式` → 改成不与 `:66` 撞名的写法
  （如 `### codegen 的禁止模式`）。**不要**改 `## 代码生成与生成物（codegen）` 这一父标题。
- 删 `docs/optional-additions.md:197`；保留 `:198` 及以下正文。

### 6. README「常用命令」

把 `README.md:104-111` 的裸代码块升级为 `### 常用命令` 小节：命令清单**只准**取自 `justfile`，
每条一行注释。不要动其余小节（「代码生成」「从脚手架创建新项目」「环境配置与 release 构建」
「从脚手架创建新项目」等都留着）。

## 验证

```bash
just verify                                            # 全部门禁，含 test-readme-tree
git grep -n "backend/index.md\|frontend/index.md"      # 只剩 3 处
git grep -n "dart-define" .cursor/                     # 应无输出
grep -c "### 禁止模式" .trellis/spec/cross-cutting.md  # → 1
find .trellis/spec -name '*.md' | grep -v 'spec/index.md' | wc -l   # → 21
git status --short                                     # 无生成物
git -C "F:/App/新建文件夹/flutter_app_template" status --short   # 与调查前一致（只读）
```

本任务**不提交**（用户明确要求），改完停在这里等确认。

## 回滚点

全部是文本改动，无代码、无 schema、无生成物。要回滚 `git checkout -- <文件>` 即可；
新增的 `.trellis/spec/index.md` 删掉即可回到原状。
