# 新增 spec 文档链接门禁

## Goal

给「文档里的路径引用」加一道门禁，为后续改名 / 改章节名（`spec-naming-convergence`）兜底。

## 为什么需要（已核实）

`tool/` 现有 5 个脚本，唯一的文档相关门禁是 `check_readme_tree.dart`，它只校验
**README 的目录树 vs 实际 `lib/`**，**不校验 markdown 链接**。因此：

| 改动类型 | 波及面 | 现状 |
|---|---|---|
| 目录改名（`backend/`→`data/` 等） | `git grep -l "backend/\|frontend/"` → **80 个已跟踪文件**（36 md、32 dart、8 jsonl、2 json、1 py、1 mdc） | 断链**无任何门禁发现** |
| 章节改名 | `lib/`+`test/` 里 38 条注释引用散在 29 个 dart 文件 | 同上 |
| spec 内部互链 | 11 条 | 同上 |

## Requirements

1. 检查 **markdown 链接目标存在**：`.trellis/spec/**/*.md`、`README.md`、`AGENTS.md`、
   `docs/**/*.md`、`.cursor/rules/*.mdc` 里的相对链接（含 `#锚点` 时锚点可先只校验文件）；
   外部 URL 与代码块内的内容跳过。
2. 检查 **dart 注释里的 spec 引用**是否符合 `guides/comment-guidelines.md` 的写法约定
   `<层>/<文件>.md「<章节>」`，且目标文件存在。**章节关键词的校验可延后**（需要解析标题，见下）。
3. 接入 `just verify`（新 recipe 或并入 `test-readme-tree`），失败给非零退出码并逐条列出位置。
4. 自带测试（照 `test/tool/check_readme_tree_test.dart` 的形状）。

## 未定：是否校验章节关键词

`comment-guidelines.md` 要求引用写「章节关键词」而非编号。要校验关键词存在就必须解析标题，
误报风险高于文件级校验。**建议先只做「文件存在」，运行一段时间后再评估**；否则改名任务会被
误报卡住。这条需要执行时拍板。

## Acceptance Criteria

- [ ] 构造一个断链（如把某 `.md` 链接指向不存在的文件）能被门禁拦下（正反例测试覆盖）
- [ ] `just verify` 含这道门禁
- [ ] 现有仓库在该门禁下全绿（若发现既有断链，先修或先记为豁免，不静默放过）

## Notes

- 依赖关系：`spec-naming-convergence` 依赖本任务先落地。
- 参考：`tool/generated_paths.dart` 被目录树门禁复用的做法，生成物应豁免。
