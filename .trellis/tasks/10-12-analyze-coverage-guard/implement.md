# 实现计划：analyze 覆盖完整性断言

轻量任务。**形状 B**（纯测试），`just verify` recipe 不变。

## 步骤（按序）

1. **`justfile`**：`app_files` 的 root 列表加 `integration_test`
   （`lib test` → `lib test integration_test`）。事实 ② 已确认该文件当前干净，不会因此冒出待修问题。
2. **`test/tool/analyze_coverage_test.dart`**（新文件）：
   - 纯函数 + 假输入的正反例（照 `test/tool/check_doc_links_test.dart` 的写法）：
     - `topLevelDirsWithDart(paths)`：取顶层目录、去重排序、跳过 `.` 开头的隐藏目录
     - `uncoveredDirs(dirs, roots, excluded)`：返回未被覆盖且未排除的目录
   - 仓库级断言（两条）：
     - **R2**：解析根 `justfile` 的 `app_files` / `tool_files` 得 roots →
       `git ls-files --cached --others --exclude-standard` 得 `.dart` 清单 →
       断言 `uncoveredDirs(...)` 为空；失败信息点名目录，并提示「加进 justfile 的 root 或写进排除名单」
     - **R3**：对每个 root 单独跑一次 git ls-files（pathspec 为该 root），断言 `.dart` 结果非空；
       失败信息说明「该 root 产出 0 个文件，可能被改名/删掉，或写错了名字」
   - 文件头写「为什么有这个测试」：roots 漏目录时 analyze 不报错，只会少扫（附事实 ④⑤ 的形态）
3. **`.trellis/spec/cross-cutting.md`**：在「`dart analyze` 必须显式传文件名」那一条上补
   本断言 + 失败形态 + `test/tool/analyze_coverage_test.dart` 路径，改现有小节，不新开标题。
4. **`just verify`**：全绿（339 + 新增用例）。

## 验证命令

```bash
just test test/tool/analyze_coverage_test.dart   # 先单跑
just verify                                      # 全量门禁
# 三条 AC 的反向验证（都要还原现场）：
#   1) touch example/foo.dart       → 失败并点名 example        ；rm -rf example
#   2) justfile 去掉 integration_test → 失败并点名 integration_test
#   3) root 改成 nosuchdir            → 失败并说明「产出 0 个文件」
just check-anchors                               # 只报告，确认无新增告警
```

## 风险与回滚

| 风险 | 说明 | 处理 |
|---|---|---|
| 反向验证会**临时改坏** justfile | 第 2/3 条 AC 要改 `app_files` / root | 改完立刻还原；用 `git diff justfile` 复核只剩一行改动 |
| 新建的 `example/` 被误提交 | 反向验证产物 | `rm -rf example`，并在提交前 `git status` 确认 |
| 测试依赖 `git` 可执行文件 | CI 与本地都有；`tool/list_dart_files.dart` 已同样依赖 | 无需额外处理，失败时 git 的 stderr 直接透出 |
| 测试读 justfile 的正则写松了 | 改了 justfile 写法会导致解析不到 root，静默变成「无 root」→ R3 会报 0 文件，不静默 | 解析不到时**显式 fail**，不要退化成空集合 |
| 仓库级断言与 CI 环境差异 | CI 在干净 checkout 上跑，`--others` 不会有本地临时文件 | 反向验证产生的临时文件不要留在工作区 |

## 提交前检查

- `git status` 里只有 3 个文件变动：`justfile`、`test/tool/analyze_coverage_test.dart`、
  `.trellis/spec/cross-cutting.md`（+ 任务目录）
- 未触碰 `10-11-doc-redundancy` 留下的 12 处未提交改动
- 计划完成后由用户决定是否提交（本任务不含提交步骤）
