# 给 analyze 门禁加「覆盖完整性」断言

## Goal

`just analyze` 的扫描面由根 `justfile` 里两个硬编码的 root 列表决定（`lib test` 与 `tool packages`）。
root 列表漏掉哪个目录、或哪个 root 被改名/删掉，门禁都不报错 —— 只会少扫，绿得毫无区别。

本任务做两件事：**补上当前已经漏掉的那个目录**（`integration_test`），并让
「每个含 Dart 源码的顶层目录，要么在 analyze roots 里、要么在排除名单里」成为一条会拦住提交的断言。

## 已核实的事实

| # | 事实 | 证据（本会话实测） |
|---|---|---|
| ① | `integration_test/app_test.dart` **今天不被任何 analyze 覆盖** | `git grep -n integration_test -- justfile` 只命中 `justfile:47`（`just e2e` 的 `flutter test integration_test/`）；roots 是 `lib test` + `tool packages`，该文件在 `integration_test/` 下 |
| ② | 把它纳入扫描**零成本**：显式传文件（插件生效）时它是干净的 | `dart analyze --fatal-infos integration_test/app_test.dart` → `No issues found!`，exit 0 |
| ③ | 传目录 ≠ 跑了插件：同一目录两种传法都报 "No issues found" | `dart analyze --fatal-infos integration_test` → 也是 `No issues found!`（目录模式假绿，`cross-cutting.md:49` 已写） |
| ④ | root 为空**不报错**：CLI 只过滤「已不存在的路径」，不校验 root 是否存在 | `dart run tool/list_dart_files.dart nosuchdir` → 输出空、exit 0（`tool/list_dart_files.dart` 共 41 行） |
| ⑤ | root 为空之后 analyze **会跑错东西，且失败原因指向别处** | `dart analyze --fatal-infos`（无参数）= 全仓目录模式 → `Analyzing flutter_app_template...`，命中 `pubspec.yaml:21` / `:66` 的 `sort_pub_dependencies`，exit 1；哪天 pubspec 排好序，它就变成 **exit 0 的纯假绿**（插件规则一条不跑） |
| ⑥ | 顶层含 `.dart` 的目录共 6 个：`lib` 61、`test` 49、`tool` 6、`packages` 4、`.agents` 2、`integration_test` 1 | `git ls-files --cached --others --exclude-standard \| grep '\.dart$' \| awk -F/ '{print $1}' \| sort \| uniq -c` |
| ⑦ | `.agents` 下那 2 个文件是 vendored 第三方 skill 的示例（`dart-use-path-package/examples/*.dart`），与 `check_doc_links.dart` 排除 `.agents/skills`、`.pi/skills` 的口径一致 | 同上 + `tool/check_doc_links.dart` 头部「排除项与理由」 |
| ⑧ | 同源前例：本仓库已有的「防门禁静默失效」防线是 `test/tool/self_package_prefix_test.dart`；「纯函数 + 注入输入 + 单测」的写法见 `tool/check_doc_links.dart` + `test/tool/check_doc_links_test.dart`；测试里起子进程是既有写法 | `test/tool/init_project_test.dart:650`、`:743`（`Process.run`） |

**前置状态**：工作区有 12 处未提交改动（属 `10-11-doc-redundancy` 任务）。本任务不碰它们；
`just verify` 已在当前工作区跑过全绿（339 测试 + fmt / 两步 analyze / 插件自测 / 文档链接 / 目录树）。

## 决定：断言落成**纯测试**（不新增工具与 recipe）

选 B（用户 2026-10-11 拍板），落地为 `test/tool/analyze_coverage_test.dart`；
`just verify` 里 `test` 那一步已经覆盖它，**不动 `verify` recipe**。

被否的两个方案与理由：

- **A｜`tool/check_analyze_coverage.dart` + 具名 recipe**：可见性最好，但为一个约 20 行的不变量
  多背一个工具 + 一个测试文件 + 一道 recipe + 一节文档，与本仓库正在做的文档减法相反。
- **C｜给 `list_dart_files.dart` 加 `--check`**：改动最小，但让一个 41 行的工具同时承担
  「列文件」与「校验覆盖」，名字与职责不符。

**代价与补偿**（用户已知并接受）：`just verify` 输出里看不出有这样一道门。
补偿方式 —— R5 在 `cross-cutting.md` 的「`dart analyze` 必须显式传文件名」一条里
**点名该测试的路径**，让读 spec 的人能顺路径找到它；测试名写成自解释的一句话，
失败信息里必须出现「未覆盖的目录名」，不要求读者先去读测试正文。

## 需求

- **R1** `integration_test` 纳入 analyze 的 app 组（对应事实 ①②）。
- **R2** 断言「每个含 Dart 源码的顶层目录，要么被某个 root 覆盖，要么在排除名单里」。
  新增顶层目录（如 `example/`）时，失败信息**点名那个目录**。
- **R3** 断言「每个声明的 root 各自产出 ≥1 个 `.dart` 文件」（按 root 逐个判，不按组判 ——
  `lib test` 里 `test` 空掉时组仍非空，正是会漏的形态）。堵掉事实 ④⑤。
- **R4** 排除名单目前只有 `.agents/`（理由：vendored 第三方示例），理由写在断言旁边；
  以 `.` 开头的隐藏目录按规则默认排除；生成物不入扫描面（复用 `tool/generated_paths.dart` 的口径）。
- **R5** `cross-cutting.md` 里「`dart analyze` 必须显式传文件名」那一条补上本断言、
  其失败形态与测试路径（**改现有小节，不新开文档**）。

## 技术要点

- **唯一真相是 justfile**：测试用正则解析根 `justfile` 里 `app_files :=` / `tool_files :=`
  两行的 `list_dart_files.dart` 参数，得出 roots 集合 —— 不在测试里再抄一份 root 列表。
  于是「justfile 去掉 `integration_test`」会直接表现为「`integration_test` 未被覆盖」。
- **文件清单走 `git ls-files --cached --others --exclude-standard`**，与 `tool/list_dart_files.dart`
  同一命令：测试看到的与门禁看到的必须是同一批文件（`build/`、`.dart_tool/`、生成物自动不在内）。
  测试内起子进程是既有写法（`test/tool/init_project_test.dart:650`）。
- **纯逻辑与仓库现状分开测**：`topLevelDirsWithDart(paths)` / `uncoveredDirs(dirs, roots, excluded)`
  用假输入覆盖正反例；仓库级断言只有两条（R2 / R3），读真实 justfile 与真实文件清单。
- 测试名自解释，让 `just verify` 输出里那一行就能看懂是什么门。

## Acceptance Criteria

- [ ] 本地新建 `example/foo.dart` → `just test` 失败，输出**点名 `example`**
- [ ] 把 justfile 的 roots 改回 `lib test` → 失败并点名 `integration_test`
- [ ] 把某个 root 改成不存在的名字（或删掉该目录）→ 失败，并说明「该 root 产出 0 个文件」
- [ ] 正常状态 `just verify` 全绿（339 项基础上 + 新增用例）
- [ ] `.agents/` 不在扫描面内，且排除理由在断言处可被 review 直接读到
- [ ] `cross-cutting.md` 该节里能查到测试路径（R5）
- [ ] `just check-anchors` 无新增告警

## 不做什么

- 不把门禁换回 `flutter analyze`、不改 `app_lints` 规则、不动 `very_good_analysis`
- 不引入覆盖率类门禁；不为 `pubspec.yaml` 的 `sort_pub_dependencies` 加门禁
  （事实 ⑤ 里那个失败是旁证，不是待办）
- 不扫 `build/`、`.dart_tool/`、生成物；不动 `.agents/skills` 内容
- 新增工具、recipe 或独立文档（已否的 A / C 两案）
- 不清理 `10-11-doc-redundancy` 的未提交改动、不动兄弟分支
