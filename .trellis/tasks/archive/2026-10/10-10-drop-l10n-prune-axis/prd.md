# 删掉 l10n 正交裁剪轴（`tool/prune.dart` 及引用）

## Goal

把「单语言」从**可裁剪出来的形态**变成脚手架的**既定形态**：删掉 `--l10n` 裁剪轴。
因为它是 `prune.dart` **唯一实现的轴**（归档 PRD `09-22-scaffold-branch-strategy` 写明
「其它轴只留接口位置」），所以删轴 = 删掉这个工具本身。

## 背景（已核实）

| # | 事实 | 证据 |
|---|---|---|
| ① | `prune.dart` 只做 multi → single，**没有反向** | 全文只有 `_applyReplacements(plan, _l10nReplacements)` / `_applyRemovals(plan, _l10nRemovals)`；`ui/localization.md` 也写着「没有反向工具」 |
| ② | 当前仓库就是它的产物，所以那 43 条（17 Replacement + 26 Removal）在**当前仓库上本来就全部 no-op** | 目标路径普查：43 条指向 16 个文件，全部存在；但没有任何一条的 `from` 串在当前仓库里 |
| ③ | 删它是**静默回归**，没有测试会拦 | `test/tool/prune_test.dart` 只覆盖纯函数（`parseArb` / `rewriteLocalizations` / …），**不覆盖那两份列表** |
| ④ | 引用面共 6 处 + 2 个文件 | 见 Requirements |

## Requirements

### 1. 删除

- `tool/prune.dart`（886 行）
- `test/tool/prune_test.dart`（214 行）

### 2. `justfile`

删 `prune *args:` recipe（`verify` 链不引用它，删了不影响门禁）。
`tool/list_dart_files.dart` 是动态生成文件列表，analyze 会自动少一个文件，不用改。

### 3. 文档与规则（口径要**自洽**，不是只删句子）

| 文件 | 位置 | 改什么 |
|---|---|---|
| `README.md` | `:174` | 「（脚手架已用 `tool/prune.dart --l10n=single` 裁掉多语言形态）」→ 改成「有意保持单语言」这类**现状陈述** |
| `README.md` | `:176` | 去掉「（思路是反向做 `prune.dart` 的裁剪面）」 |
| `README.md` | `:290` | justfile recipe 列表去掉 `prune` |
| `README.md` | `:294` | 删掉 `tool/prune.dart` 那一行；**顺带补上 `tool/check_doc_links.dart`**（上一轮新增的门禁没进这份清单） |
| `.cursor/rules/project-conventions.mdc` | `:57` | `tool/` 的描述去掉 prune，改为「init / 文档一致性门禁（目录树 + 文档链接）」 |
| `BRANCH.md` | `:11-15` | 「这类需求由正交裁剪参数承担」+「正交裁剪轴：`--l10n=multi|single`」两处论点随轴一起失效 → 改成「手工裁剪即可，脚手架不提供裁剪工具」 |
| `BRANCH.md` | `:22` | 硬约定 2 写「每个分支 / **轴**的差异都要留档」→ 轴没了，去掉「轴」 |
| `BRANCH.md` | `:33` | 「（多语言已被 `tool/prune.dart` 裁掉）」→ 现状陈述 |
| `.trellis/spec/ui/localization.md` | `:9` | 去掉「它已被 `tool/prune.dart` 的 `--l10n=single` 裁掉」，改成「这是**有意**的裁剪」 |
| `.trellis/spec/ui/localization.md` | `:38` | 「把 `tool/prune.dart` 的裁剪面反过来做即可 —— 那份清单就是差集」→ 改成「没有反向工具，加回来是手工活」+ 后面 6 步原样保留 |

**关键要求**：`ui/localization.md` 的「要加回多语言时」那 6 步必须**独立成立**（不再依赖任何工具）。
这 6 步本来就不引用工具，只是引导句要改。

### 4. 不要动

- `.trellis/tasks/archive/**` —— 历史（归档 PRD 里对 `--l10n` 轴的描述是当时的真实状态）。
- `tool/init_project.dart` 的 `_pruneEmptyDirs` —— **同名巧合**，那是「改名后清空目录」，与 l10n 无关。
- `ui/localization.md` 的「要加回多语言时」章节本身 —— 仍然有用。
- 兄弟分支工作树。

## Acceptance Criteria

- [ ] `tool/prune.dart`、`test/tool/prune_test.dart` 已删；`justfile` 无 `prune` recipe
- [ ] `git grep -n "prune" -- . ':!.trellis/tasks/archive' ':!.pi' ':!.agents' ':!.trellis/workspace'` 只剩 `tool/init_project.dart` 的 `_pruneEmptyDirs`（同名巧合）
- [ ] `README.md` 的工具清单里有 `tool/check_doc_links.dart`
- [ ] `ui/localization.md` 的「要加回多语言时」6 步不引用任何工具，且步骤本身未被删改
- [ ] `BRANCH.md` 不再有「正交裁剪轴」这一概念，但「不再新增 preset/* 分支」的结论仍在
- [ ] `dart run tool/check_doc_links.dart` 全绿
- [ ] `just verify` 全绿
- [ ] 兄弟工作树 `git status` 仍为 `M 7 / ?? 4`

## Notes

- **这是你确认过的取舍**：那 43 条列表是仓库里对「多语言形态与单语言形态差集」最精确的描述，
  删掉后只留在 git 历史里（`git show b9ad09f:tool/prune.dart`）。反向（single → multi）从来就不存在。
- 上一轮我误把 `:636` 那条判成「死条目」（用了「在当前仓库上不生效」这个无效判据）——
  本任务是「按你的决定删掉整条轴」，不是「因为那条死了才删」。
