# 加锚点报告门禁与「提门禁不写数量」写法约定

## Goal

补两类**没有门禁兜、且本轮实际发生过**的文档腐坏：

1. **章节引用指向不存在的标题**（本轮亲手踩到一次）。
2. **用数量描述会变的东西**（本轮修了 8 处同类，仍漏一处）。

## 背景（已核实）

| # | 事实 | 证据 |
|---|---|---|
| ① | `check_doc_links.dart` 只校验**文件级**，明确写着「有意不校验锚点与章节关键词」 | 该文件头注释 + `cross-cutting.md`「文档链接一致性」 |
| ② | 本轮我自己写出过一处错引：`cross-cutting.md` 里引用 `directory-structure.md「不存在的东西」`，而该清单实际在 `.cursor/rules/project-conventions.mdc:70` | 已修，但当时**没有任何工具会报** |
| ③ | 章节名变更在本仓库是**常态**（`10-10-spec-naming-convergence` 一轮改了 118 个标题） | 那个任务的提交 |
| ④ | 同类腐坏还有一个实例：`cross-cutting.md:171` 写「`tool/` **现有的两个脚本**都是文档一致性门禁」，实际 `tool/` 有 5 个文件（2 个文档门禁 + `init_project` / `list_dart_files` / `generated_paths`） | `ls tool/` |
| ⑤ | 门禁清单曾被枚举在 **8 处**，每加一道门禁要全改一遍；上一轮已收敛为指针 | commit `360c9f2` |

## Requirements

### 1. 新增 `tool/check_doc_anchors.dart` + `just check-anchors`（**只报告，不进门禁**）

- **扫描面**复用 `tool/check_doc_links.dart` 的那套（根 `README.md` / `AGENTS.md` / `BRANCH.md`、
  `docs/**/*.md`、`.trellis/spec/**/*.md`、`.cursor/rules/*.mdc`、`lib/**/*.dart`、`test/**/*.dart`；
  排除 `.trellis/tasks/**`、`.pi/**`、`.agents/**`、`packages/**`、生成物）。**直接复用它的常量或函数**，
  不要抄第二份（两份扫描面必然漂）。
- **判据**：找 `路径.md「章节关键词」` 形态的引用；把目标文件的**全部标题**（`#` 到 `######`）取出来，
  判断有没有任一标题**包含**该关键词。包含即通过 —— 引用约定本来写的就是「关键词」而不是完整标题
  （见 `guides/comment-guidelines.md`「引用 spec 的写法」）。
- **默认退出码 0**（只报告）；另给 `--strict` 时发现不一致才返回 1。
  **不要把它加进 `verify` 链** —— 改标题是常态，拦会误伤；报告的价值在于"改完标题顺手看一眼"。
- 输出形态与 `check_doc_links.dart` 一致：`文件:行号` + 一句人话。
- 自带测试（照 `test/tool/check_doc_links_test.dart` 的形状：纯函数 + 注入文件系统）。

### 2. 用它做一次审计，并修掉报出来的真实错引

新工具第一次运行本身就是审计。**报出来的每一条都要判断**：

- 确实是错引（指向的标题不存在）→ **修掉**（改引用，或改标题，二选一，选改动小的那个）。
- 引用的是**描述性说法**而非标题（例如 `「读要软，写要硬」` 这种正文短语）→ 记为**工具容差**，
  在工具的文件头注释里写明这类会被误报，并考虑把判据收紧（如只认 `##` 及以上标题）。
- 报告里逐条列出：哪条、判定、改了什么。

### 3. 写法约定：提到门禁不写数量与项名

`guides/comment-guidelines.md` 的「spec 该怎么写」一节加一条：

> **提到门禁时只写「见 `justfile` 的 `verify`」，不写数量与项名。** 数量必然过期：
> 门禁清单曾在 8 处被枚举，加一道就要全改一遍；`tool/` 的脚本数也被写成「两个」而实际是 5 个。

### 4. 修 `cross-cutting.md:171`

「覆盖率相关的自定义脚本一个都没有：`tool/` 现有的两个脚本都是文档一致性门禁」——
按第 3 条的约定改写（只保留「覆盖率没有自定义脚本」这个**结论**，不描述 `tool/` 有几个脚本）。

## Acceptance Criteria

- [ ] `tool/check_doc_anchors.dart` 存在，默认退出码 0、`--strict` 才返回 1；**不在 `verify` 链里**
- [ ] 扫描面**复用** `check_doc_links.dart` 的定义（不是抄一份）
- [ ] `test/tool/check_doc_anchors_test.dart` 覆盖：命中 / 不命中 / 描述性关键词容差 / 无 `「」` 的引用跳过
- [ ] 首次审计的结果逐条列出并处理（错引已修，或说明为何不是错引）
- [ ] `guides/comment-guidelines.md` 有「不写数量与项名」这条约定
- [ ] `cross-cutting.md:171` 不再描述 `tool/` 的脚本数量
- [ ] `just verify` 全绿（新工具不进 verify，所以是既有门禁全绿）
- [ ] `dart run tool/check_doc_links.dart` 全绿
- [ ] 兄弟工作树未被写入

## Notes

- 这是一条**刻意不设门禁**的工具：它的价值在「改名/改标题后跑一下看看」，不在拦提交。
  这个取舍要写进 `cross-cutting.md`「有意不设的项」那节的表格里（新增一行）。
- 参考：兄弟分支 `preset/ai-starter` 的 `cross-cutting.md` 里也**没有**这类工具，这是本仓库独有的补强。
