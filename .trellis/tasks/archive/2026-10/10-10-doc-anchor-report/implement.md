# 执行计划：锚点报告工具 + 写法约定

## 前置

| 读什么 | 为什么 |
|---|---|
| `tool/check_doc_links.dart`（全文） | **复用它的扫描面定义**（目标文件集合、排除项、生成物判定、围栏与行内代码跳过），别抄第二份 |
| `test/tool/check_doc_links_test.dart` | 测试形状（纯函数 + 注入文件系统） |
| `.trellis/spec/guides/comment-guidelines.md`「引用 spec 的写法」 | 引用的写法约定（`<层>/<文件>.md「<章节关键词>」`） |
| `.trellis/spec/cross-cutting.md`「文档链接一致性」+「有意不设的项」 | 新工具要在这两处留痕 |

## 步骤

### 1. `tool/check_doc_anchors.dart`

**复用而非复制**：扫描面（哪些文件、排除哪些、怎么判生成物、怎么跳过围栏与行内代码）
必须从 `check_doc_links.dart` 拿。若那些定义目前是私有的，把它们改成可导入的
（`const` / 顶层函数），**不要在新文件里再写一遍** —— 两份扫描面必然漂。

**判据**：

1. 找 `路径.md「关键词」` 形态的引用（同一行内，路径与「」相邻）。
2. 读目标文件，取出**全部标题**（`#` 到 `######`）的文本。
3. 只要**任一标题包含该关键词**即通过（引用约定写的是关键词，不是完整标题）。
4. 无 `「」` 的引用**跳过**（文件级校验已由 `check_doc_links.dart` 负责）。

**退出码**：默认 `0`（只报告）；`--strict` 且有发现时 `1`。

**输出**：与 `check_doc_links.dart` 同形态 —— `文件:行号` + 一句人话，
例如 `cross-cutting.md:161  引用「不存在的东西」，但目标文件里没有标题包含它`。

**文件头注释要写清**（照 `check_doc_links.dart` 的风格）：

- 为什么需要它（改标题是常态；文件级门禁看不到章节名）
- **为什么默认不拦提交**（误伤成本 > 收益；它不进 `verify`）
- 已知容差：引用正文短语而非标题时会误报（如 `「读要软，写要硬」`）。先按实测结果决定是否收紧判据
  （例如只认 `##` 及以上标题）——**以首次审计的实际误报为准**，不要凭空收紧。

### 2. `justfile`

```make
check-anchors:
    dart run tool/check_doc_anchors.dart
```

**不要**加进 `verify` 链。

### 3. 首次审计（新工具第一次跑就是审计）

逐条判断报出来的每一条，并在回报里列表：哪条 / 判定（真错引 or 工具容差）/ 处理。
真错引就修（改引用或改标题，选改动小的）。

### 4. `guides/comment-guidelines.md` 加约定

在「spec 该怎么写」一节加：**提到门禁只写「见 `justfile` 的 `verify`」，不写数量与项名。**

### 5. `cross-cutting.md` 两处

- `:171` 那句「`tool/` 现有的两个脚本都是文档一致性门禁」→ 只留结论（覆盖率没有自定义脚本），
  不描述 `tool/` 有几个脚本。
- 「有意不设的项」表格**加一行**：锚点/章节关键词校验 = 只报告不拦（见 `tool/check_doc_anchors.dart`）。

## 验证

```bash
dart run tool/check_doc_anchors.dart            # 默认 exit 0；报告内容自己判断
dart run tool/check_doc_anchors.dart --strict   # 无真实错引时应 exit 0
just check-anchors                              # recipe 存在
just verify                                     # 全绿（新工具不在 verify 链里）
dart run tool/check_doc_links.dart              # ✅ 全绿
flutter test test/tool/check_doc_anchors_test.dart
git status --short                              # 无生成物
git -C "F:/App/新建文件夹/flutter_app_template" status --short   # 仍为 M 7 / ?? 4
```

**不要提交**（用户逐轮授权）。

## 回滚点

新增 2 个文件（工具 + 测试）+ `justfile` 一行 recipe + 3 处文档。删除新增文件、
`git checkout --` 改过的文件即可。无 schema、无生成物。
