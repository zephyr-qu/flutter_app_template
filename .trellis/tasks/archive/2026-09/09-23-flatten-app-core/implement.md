# 执行计划：拍平 `packages/app_core`

> 环境：Windows + PowerShell。`dart` / `flutter` 不在 PATH，命令前先
> `$env:PATH="D:\scoop\apps\flutter\current\bin;$env:PATH"`。
> 提交约定：`git commit --no-verify` + 手工跑完整门禁（本分支既有约定）。
> 全程在 `preset/ai-starter` 分支。

## 阶段 A：搬迁与 import（不跑 codegen）

- [ ] A1 记录基线：`git status --porcelain` 干净（除未提交的 `.gitignore`）；记下 `packages/app_core/lib` 23 文件、`test` 17 文件的清单
- [ ] A2 `git mv` 七个 `lib` 子目录 → `lib/core/{base,config,data,logging,models,theme,ui}`
      （先 `git status` 确认无同名覆盖）
- [ ] A3 `git mv packages/app_core/test test/core`
- [ ] A4 全局改 import 前缀 `package:app_core/` → `package:my_app/core/`（lib 9 + test 16 + 外部 40 文件）
- [ ] A5 自检：`git grep "package:app_core"` 为空

## 阶段 B：依赖与 DAO（不跑 codegen）

- [ ] B1 改 `pubspec.yaml`：删 `app_core` path 依赖；补 `dio_smart_retry` / `pretty_dio_logger` /
      `logger` / `path_provider` / `flex_color_scheme`；`drift` 从 dev 升为 dependencies
- [ ] B2 `flutter pub get`（重生成 `pubspec.lock`；删掉 `packages/app_core/.dart_tool` 若有）
- [ ] B3 改 `lib/features/sample/data/sample_dao.dart`：恢复 `@DriftAccessor(tables: [DbArticles])`
      + `part 'sample_dao.g.dart';` + `extends DatabaseAccessor<AppDatabase> with _$SampleDaoMixin`，
      删绕行注释，方法体去 `_db.` 前缀
- [ ] B4 `flutter analyze lib/ test/` → 收敛（预期只剩 `sample_dao.g.dart` 缺失类错误）

## 阶段 C：codegen（**必须 B4 收敛后**）

- [ ] C1 `dart run build_runner build`（一次性覆盖 auto_route / drift / freezed / riverpod / retrofit）
- [ ] C2 核对生成物 diff：
      - 新增 `lib/features/sample/data/sample_dao.g.dart`
      - `lib/core/data/database/app_database.g.dart` 仅路径/导入变化
      - `lib/app/routing/router.gr.dart` **无 `dynamic key` 之类降级**（红窗口事故特征）
- [ ] C3 `flutter analyze lib/ test/` → No issues found

## 阶段 D：清残留 + 门禁脚本

- [ ] D1 删 `packages/`（含 `pubspec.yaml` / `analysis_options.yaml` / 残留 `.dart_tool`）；
      `test -d packages` 应为假
- [ ] D2 `tool/check_boundaries.dart`：扫描根收敛为 `lib`
- [ ] D3 `tool/check_coverage.dart` / `tool/check_readme_tree.dart` / `tool/prune.dart`：去 app_core
- [ ] D4 `.githooks/pre-commit` 与 `.github/workflows/ci.yml`：去 `packages/app_core` 步骤与 `--src` 参数
- [ ] D5 `test/tool/check_boundaries_test.dart` 等脚本测试：同步引用

## 阶段 E：文档 / spec

- [ ] E1 `README.md`：删 app_core 目录树、依赖表、命令块里的包步骤
- [ ] E2 `AGENTS.md`：`## 改完必跑` 去包步骤
- [ ] E3 `BRANCH.md`：删「共用资产 / 包零改动」段
- [ ] E4 `docs/release-checklist.md`
- [ ] E5 `.trellis/spec/`：backend×6 + cross-cutting + frontend×2（路径改回 `lib/core/...`；
      `@DriftAccessor` 口径按 design §6 更新）
- [ ] E6 `.cursor/rules/project-conventions.mdc`

## 阶段 F：六道门禁（全绿才算完成）

```powershell
$env:PATH="D:\scoop\apps\flutter\current\bin;$env:PATH"
dart format --output=none --set-exit-if-changed lib test tool
dart run tool/check_boundaries.dart
dart run tool/check_conventions.dart
dart run tool/check_readme_tree.dart
dart run dependency_validator
flutter analyze lib/ test/
flutter test --coverage
dart run tool/check_coverage.dart coverage/lcov.info --src=lib
```

- [ ] F1 上述全部退出码 0
- [ ] F2 覆盖率 ≥ 80%（搬迁不改逻辑，应与搬迁前持平：根 `lib/` 约 90%）
- [ ] F3 `git grep "package:app_core"` 全仓为空；`packages/` 不存在
- [ ] F4 复核 `git diff master..HEAD --stat`：差异仅限本任务预期文件，未误触 master

## 阶段 G：提交（Trellis Phase 3.4）

- [ ] G1 分批提交（搬迁 / 依赖+DAO / 门禁 / 文档 各一批，或按 review 结论合并）
- [ ] G2 单独立一个 `chore: ignore .codebuddy/`（携带目前未提交的 `.gitignore`）

## 回滚点

- 阶段 A–E 任一步出错：`git restore .` / `git checkout -- .`（未提交状态可直接丢弃）
- codegen 产物异常：`git restore` 生成物后回阶段 A 重来
- 已提交：按提交粒度 `git revert`
- 全程不影响 `master`

## Review gates

- **Gate 1**（阶段 A 前）：规划产出 `prd.md` / `design.md` / `implement.md` 经用户确认后才 `task.py start`
- **Gate 2**（阶段 C 前）：B4 `flutter analyze` 收敛确认后才允许跑 codegen
- **Gate 3**（阶段 G 前）：F 全绿 + 覆盖率达标才允许提交

---

## 实施记录（2026-09-23）

**阶段 A–F 全部完成**，六道门禁 + format 全绿。

### 门禁实测

| 门禁 | 结果 |
|---|---|
| `dart format --set-exit-if-changed lib test tool` | 0 changed（132 文件） |
| `check_boundaries` / `check_conventions` / `check_readme_tree` / `dependency_validator` | 全绿 |
| `flutter analyze lib/ test/` | No issues found |
| `dart analyze tool/` | 退出码 0（10 条 info 全在 `prune.dart` 既有行，非本次引入） |
| `flutter test --coverage` | 346 passed / 1 skipped（`SCAFFOLD_E2E`） |
| `check_coverage --src=lib` | 90.0%（进分母 49 文件，豁免 8），达标 |

### 与设计的偏差

1. **`@DriftAccessor` 恢复成功，无需回退**（design §6 的备用方案未启用）：codegen 干净、
   `sample_dao_test` / `sample_list_notifier_test` 绿。新增生成物
   `lib/features/sample/data/sample_dao.g.dart`。
2. **合并了 `scripted_http_adapter.dart` 的两份副本**（design §2.2 原计划保留两份）：拍平后
   两份同处一个 package、且都被 `test/core/data/network/` 的测试使用，跨包去重的理由消失；
   两份**仅文档注释不同**、代码逐字节相同，故合并为 `test/support/` 一份，3 处
   `../../support/` import 改为 `../../../support/`，删除 `test/core/support/` 那份。
3. **import 前缀改写连带触发 `directives_ordering`**（`app_core` → `my_app` 改变了字母序）：
   用 `dart fix --apply --code=directives_ordering` 修掉，未手工干预。
4. **`.gitignore` 的 `.codebuddy/` 忽略**：与本任务无关的独立改动，单独成一个 commit。
5. `packages/` 删除时被一个隔夜遗留的 `flutter_tester` 进程占用，清掉该进程后才删净。
6. `test/tool/check_coverage_test.dart` 里的 `packages/app_core/...` 是**合成夹具**（验证
   `coversPath` 的前缀匹配能力，`master` 侧仍需要），**有意保留**。
