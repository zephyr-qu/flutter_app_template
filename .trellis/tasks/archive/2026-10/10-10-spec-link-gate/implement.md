# 执行计划：文档链接门禁

## 前置

| 读什么 | 为什么 |
|---|---|
| `tool/check_readme_tree.dart` + `test/tool/check_readme_tree_test.dart` | **照它的形状写**：纯函数 + 注入 `exists`/`read`，普通 `test()` 覆盖；`main` 只做 IO 与输出；失败 `exitCode = 1` 并逐条列出 `文件:行号` |
| `tool/generated_paths.dart` | 生成物豁免的统一口径，复用 `isGeneratedPath` |
| `.trellis/spec/guides/comment-guidelines.md`「引用 spec 的写法」 | 规则 B 要校验的写法约定 |
| `justfile` | 新 recipe 与 `verify` 链 |

## 已核实的前提

- **全仓库没有任何 markdown 链接检查**：`git grep -l "markdown-link\|link-check\|check_links\|lychee\|mdlink"` 无输出；`.github/workflows/ci.yml` 也没有。本任务是从 0 到 1。
- **当前真实断链 0 处**。预扫结果（180 个 md）：21 处是 `.agents/skills/signals-hooks/**` 里指向作者本机 `file:///Users/rodydavis/...` 的**第三方绝对链接**；1 处是 `docs/architecture-review.md:132` 的正则被误当链接。
  → 所以门禁**不加豁免豁免**也能立刻绿灯，但**必须**排除 `.agents/`、`.pi/` 这类 vendored 目录，且**必须跳过行内代码与围栏代码块**（否则上面那 1 处误报会再次出现）。
- `justfile` 的 `tool_files := \`dart run tool/list_dart_files.dart tool packages\`` 是**动态生成**的 → 新增 `tool/*.dart` 自动进 `analyze-tool`，无需改 `justfile` 的 analyze 段。

## 步骤

### 1. 新增 `tool/check_doc_links.dart`

**扫描面**（显式列出，且每条排除都写进文件头注释说明理由）：

| 包含 | 排除（写理由） |
|---|---|
| 根 `README.md` / `AGENTS.md` / `BRANCH.md` | `.trellis/tasks/**` —— 任务产物是工作笔记：活动任务会引用**尚未存在**的目标路径（如 `spec-naming-convergence/prd.md` 里的 `ui/*`），归档任务是历史 |
| `docs/**/*.md` | `.pi/skills/**`、`.agents/skills/**` —— vendored 第三方文档，含作者本机绝对路径 |
| `.trellis/spec/**/*.md` | `packages/app_lints/**` —— 独立包，自带 README 的链接面向 pub 场景 |
| `.cursor/rules/*.mdc` | 生成物（复用 `isGeneratedPath`） |

**规则 A：markdown 相对链接必须存在**

- 只认行内链接 `[text](target)`；跳过围栏代码块与行内代码（`` ` `` 包裹）。
- 跳过 `http://` / `https://` / `mailto:` / 纯锚点 `#...` / `file:` 开头。
- 去掉 `#锚点` 部分，相对当前文件目录 resolve，要求目标是存在的文件**或目录**。
- **不校验锚点是否存在**（见「有意不做」）。

**规则 B：dart 注释里的 spec 引用必须存在**

- 扫 `lib/**/*.dart`、`test/**/*.dart`（生成物豁免）。
- 匹配 `(backend|frontend|guides)/[\w.-]+\.md` 与裸 `cross-cutting\.md`，解析到 `.trellis/spec/<相对路径>`，要求文件存在。
- 正则要**拿真实语料校准**再定，至少覆盖这些真实写法（`git grep -n "backend/.*\.md\|frontend/.*\.md\|guides/.*\.md" -- lib test` 可复现）：
  - `见 backend/error-handling.md「登出语义」`
  - `见 frontend/state-management.md`
  - `见 backend/network-guidelines.md「配置：dotenv 只读一次」`
- 若校准时发现无法与普通文本区分的写法，**宁可少报也不要误报**，并把取舍写进文件头注释。

**形状**（与 `check_readme_tree.dart` 对齐）：

```dart
// 为什么需要它：……
/// 纯函数：文件系统由 [exists] / [readFile] 注入
List<String> findDocLinkViolations({required List<String> docs, required bool Function(String) exists, required String Function(String) readFile})
```

### 2. 测试 `test/tool/check_doc_links_test.dart`

照 `check_readme_tree_test.dart` 的分组方式，至少覆盖正反例：

- 相对链接存在 → 不报；指向不存在的文件 → 报且带 `文件:行号`
- 锚点 `./a.md#section` → 只比 `a.md`
- 围栏代码块内的 `[x](y.md)` 与行内代码 `` `[x](y.md)` `` → **不报**
- `https://` / `mailto:` / `#anchor` → 不报
- `file:` 绝对链接 → 不报
- 规则 B：`backend/error-handling.md` 存在 → 不报；`backend/no-such.md` → 报
- `../../AGENTS.md` 这类带 `..` 的链接能正确 resolve

### 3. 接入 `justfile`

```make
test-doc-links:
    dart run tool/check_doc_links.dart
```

并把 `verify` 链改为（doc 类门禁放在最慢的 `test` 之前）：

```make
verify: fmt-check analyze test-app-lints test-readme-tree test-doc-links test
```

### 4. 新增 `cross-cutting.md` 的门禁章节

在 `## 目录树一致性（tool/check_readme_tree.dart）` 之后新增 `## 文档链接一致性（tool/check_doc_links.dart）`：
覆盖什么、扫描面与排除项及理由、**有意不校验锚点与章节关键词**、失败输出形态。

同时改掉 `cross-cutting.md:109` 那句「门禁里也因此**没有自定义脚本**了：`tool/` 只剩目录树一致性那一个」—— 现在有两个。

### 5. 消掉「门禁清单被复述」的漂移面（本任务必须做，否则刚引入就漂）

现状：同一条 `just verify` 的清单被**枚举**在 6 处（`AGENTS.md:112`、`README.md:20`、
`.trellis/spec/guides/rename-checklist.md:69`、`.github/workflows/ci.yml:42`、
`.cursor/rules/project-conventions.mdc:57`、`.trellis/spec/index.md:67`），加一道门禁就要改 6 处 ——
这也是 `.trellis/spec/cross-cutting.md` 在本任务里被引用的原因。

做法：

- **`AGENTS.md:112` 与 `README.md:20` 的枚举改为指针**：只保留「一条命令 `just verify` + 清单以根 `justfile` 为准 + 新增门禁见 `cross-cutting.md`」，不再逐项列出。
- 其余 4 处只做**必要同步**（提到「目录树一致性」的地方补上文档链接一致性，或同样改为不枚举）。
- **不动** `BRANCH.md:44`：那句说的是 `preset/ai-starter` 分支没有目录树门禁，是分支差异描述。

## 有意不做（写进结论，不要默默略过）

- **不校验锚点与章节关键词**。理由：`comment-guidelines.md` 要求引用写「章节关键词」而非编号，要校验关键词就必须解析每个 `.md` 的标题集合，误报会直接挡住提交；而改名任务（`spec-naming-convergence`）恰恰要批量改章节名。**先只做文件级**，跑一段时间后再评估。
- 不扫 `.trellis/tasks/**`（理由见上表）。
- 不做自动修复（`--fix`），只报告。

## 验证

```bash
dart run tool/check_doc_links.dart          # 期望：✅ 全绿（当前真实断链 0 处）
just verify                                 # 全绿
flutter test test/tool/check_doc_links_test.dart   # 新测试通过
# 反例必须被抓到（临时改坏一处再改回）：
#   把 README.md 里任一相对链接指向不存在文件 → 退出码 1 且打印 文件:行号
git grep -n "目录树一致性" | grep -v "^tool/\|^test/\|^BRANCH.md"   # 复述点已收敛
git -C "F:/App/新建文件夹/flutter_app_template" status --short       # 与调查前一致（只读）
```

本任务**不提交**，完成后停下等确认。

## 回滚点

新增 2 个文件（`tool/check_doc_links.dart`、`test/tool/check_doc_links_test.dart`）；改 `justfile`、
`cross-cutting.md`、`AGENTS.md`、`README.md`（+ 其余复述点的必要同步）。
回滚：删两个新文件 + `git checkout --` 改过的文件。无代码依赖、无 schema、无生成物。
