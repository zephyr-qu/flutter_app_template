# 执行计划：删掉 l10n 裁剪轴

## 前置

| 读什么 | 为什么 |
|---|---|
| `tool/prune.dart` 头部注释与 `_l10nReplacements` / `_l10nRemovals` 的规模 | 确认删的是整条轴（43 条），不是某一条 |
| `.trellis/spec/ui/localization.md` 全文（48 行） | 「要加回多语言时」那 6 步必须独立成立 |
| `BRANCH.md` 全文（45 行） | 有两处论点依赖「存在裁剪轴」 |
| `.trellis/spec/guides/comment-guidelines.md`「只写结果与现状」 | 改写口径时的写法约定：**不写历史、不写被否决的方案** |

## 步骤

### 1. 删文件

```bash
git rm tool/prune.dart test/tool/prune_test.dart
```

### 2. `justfile`

删掉：

```make
prune *args:
    dart run tool/prune.dart {{ args }}
```

（`verify` 链不引用它；`tool/list_dart_files.dart` 动态生成文件列表，无需改 analyze 段。）

### 3. 文档口径（逐处，改完要**自洽**）

按 PRD 的表格逐条改。写法要求：

- **改成现状陈述**，不要写「以前有个 prune 工具」这类历史叙事 —— `comment-guidelines.md` 明写
  spec 不写历史与被否决的方案。
- `BRANCH.md` 的「不再新增 `preset/*` 分支」这个**结论要保留**，只是把它的论据从
  「由正交裁剪参数承担」换成「手工裁剪即可，脚手架不提供裁剪工具」。
- `ui/localization.md` 的引导句改成「没有反向工具，加回来是手工活」，**后面 6 步一个字不改**。
- `README.md:294` 附近那份工具清单：删 `tool/prune.dart` 行的同时补 `tool/check_doc_links.dart`
  （上一轮新增的门禁漏在清单外了）。

### 4. 自查：有没有漏掉的引用

```bash
git grep -n "prune" -- . ':!.trellis/tasks/archive' ':!.pi' ':!.agents' ':!.trellis/workspace'
```

期望只剩 `tool/init_project.dart` 的 `_pruneEmptyDirs`（改名后清空目录，与 l10n 无关）。
另外单独确认没有「正交裁剪」「--l10n」这类**不带 prune 字样**的残留：

```bash
git grep -n "正交裁剪\|--l10n\|l10n=single" -- . ':!.trellis/tasks/archive' ':!.pi' ':!.agents' ':!.trellis/workspace'
```

## 验证

```bash
just verify                                            # 全绿（analyze 会自动少一个 tool 文件）
dart run tool/check_doc_links.dart                     # ✅ 全绿
ls tool/ test/tool/                                    # 确认两个文件没了
git grep -n "prune" -- . ':!.trellis/tasks/archive' ':!.pi' ':!.agents' ':!.trellis/workspace'
git status --short                                     # 无生成物；删除是 git rm（D 状态）
git -C "F:/App/新建文件夹/flutter_app_template" status --short   # 仍为 M 7 / ?? 4
```

**不要提交**（用户逐轮授权）。

## 回滚点

`git checkout HEAD -- tool/prune.dart test/tool/prune_test.dart` 即可完整恢复工具；
文档改动同样 `git checkout`。无 schema、无生成物、无数据影响。
