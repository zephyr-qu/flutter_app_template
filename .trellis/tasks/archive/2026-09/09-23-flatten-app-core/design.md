# 技术设计：拍平 `packages/app_core`

## 1. 目标与不变量

把 `packages/app_core` 的代码整体搬回根工程 `lib/core/`，删除 path 依赖与 `packages/` 目录。

**不变量**
- 只改 `preset/ai-starter`；`master` 等分支零改动。
- 搬迁后**行为不变**：不重命名类/方法、不改逻辑，只改「所在 package / import 前缀 / 依赖声明位置」。
- 不放宽任何门禁。

## 2. 目录落点

### 2.1 `lib/` —— 映射表见 `prd.md` R1

落点 = 抽取前原位。搬迁方式是「整目录移动」，不是重写：

```powershell
git mv packages/app_core/lib/base        lib/core/base
git mv packages/app_core/lib/config       lib/core/config
git mv packages/app_core/lib/data         lib/core/data
git mv packages/app_core/lib/logging      lib/core/logging
git mv packages/app_core/lib/models       lib/core/models
git mv packages/app_core/lib/theme        lib/core/theme
git mv packages/app_core/lib/ui           lib/core/ui
```

`lib/core/{config,data,ui}/` 已存在（应用适配层），`git mv` 是**目录内容合并**，
同名文件需逐一确认无覆盖（实测无同名冲突：包内 `config/network_config.dart`、
`data/network/dio_factory.dart` 等与根侧 `config/app_settings.dart`、`data/network/dio_client.dart`
文件名不同）。

### 2.2 `test/` —— 整个子树搬到 `test/core/`

```powershell
git mv packages/app_core/test  test/core
```

**为什么整体搬能零改相对 import**：包内测试用相对路径引用 support，例如
`test/data/network/auth_interceptor_test.dart` 里写的是 `../../support/scripted_http_adapter.dart`。
搬到 `test/core/data/network/…` 后，`../../support/…` 正好解析到 `test/core/support/…` —— 相对层级不变，
**所有 support 引用无需改动**。

由此 `packages/app_core/test/support/`（4 个文件：`fake_path_provider` / `fake_token_refresher` /
`fake_token_store` / `scripted_http_adapter`）落到 `test/core/support/`。

> **实施后修订**：`scripted_http_adapter.dart` 原计划保留两份。实施时发现两份**仅文档注释不同、
> 代码逐字节相同**，且拍平后都被 `test/core/data/network/` 的测试使用 —— 「跨包」的去重理由已消失。
> 故合并为 `test/support/` 一份，删除 `test/core/support/` 那份，3 处 import 上移一级。
> 其余 3 个 support 文件（`fake_path_provider` 等）按原计划留在 `test/core/support/`。

## 3. import 重写

全局替换，一处都不例外：

```
package:app_core/  →  package:my_app/core/
```

覆盖三类：
- **外部引用**：`lib/` + `test/` 下 40 个文件
- **包内自引用（lib）**：9 处（如 `failure.dart` → `package:app_core/logging/logging.dart`）
- **包内自引用（test）**：16 处

执行方式：`git grep -l "package:app_core" | xargs sed -i 's#package:app_core/#package:my_app/core/#g'`
（Git Bash / `sed`）；完成后 `git grep "package:app_core"` 必须为空。

## 4. Lint 配置

`packages/app_core/analysis_options.yaml` **直接删**，不往根配置加任何东西。

实测根 `analysis_options.yaml` 已包含包配置的三处豁免（`public_member_api_docs: false`、
`avoid_catches_without_on_clauses: false`、`avoid_slow_async_io: false`）与相同的
`strict-casts` / `strict-inference`。搬迁后 lint 面**不增不减**。

## 5. 依赖收敛（`pubspec.yaml`）

| 动作 | 依赖 | 说明 |
|---|---|---|
| 删 | `app_core: { path: packages/app_core }` | 包消失 |
| 补 | `dio_smart_retry` `^7.0.1` | 原只在包内声明，`dio_factory.dart` 用 |
| 补 | `pretty_dio_logger` `^1.4.0` | 原只在包内声明 |
| 补 | `logger` `^2.6.2` | 原只在包内声明，`logging.dart` 用 |
| 补 | `path_provider` `^2.1.0` | 原只在包内声明，`app_database` / `file_storage` 用 |
| 补 | `flex_color_scheme` `^8.4.0` | 原只在包内声明，`theme/` 用 |
| **升** | `drift` `^2.34.1` | `dev_dependencies` → `dependencies`（数据库/表代码回到运行期路径） |

其余依赖（`dio` / `msw_dio_interceptor` / `freezed_annotation` / `json_annotation` /
`shared_preferences` / `flutter_secure_storage` 等）根侧已有，不动。
补完后重生成 `pubspec.lock`，`dependency_validator` 必须绿。

## 6. 恢复 `@DriftAccessor`（R4）

`sample_dao.dart` 改为 drift canonical DAO 形态：

```dart
import 'package:my_app/core/data/database/app_database.dart';
import 'package:drift/drift.dart';

part 'sample_dao.g.dart';

@DriftAccessor(tables: [DbArticles])
class SampleDao extends DatabaseAccessor<AppDatabase> with _$SampleDaoMixin {
  SampleDao(super.db);

  Future<void> cacheItems(List<DbArticle> items) =>
      batch((b) => b..deleteAll(dbArticles)..insertAll(dbArticles, items));
  // 其余方法把 `_db.select(...)` → `select(...)`、`_db.dbArticles` → `dbArticles`
  // （DatabaseAccessor 自带 select/into/delete/batch 与 mixin 的 dbArticles getter）
}
```

- `AppDatabase` 的 `@DriftDatabase(tables: [DbArticles])` **保留**（canonical 模式允许同一表同时
  出现在 database 与 DAO；见 drift 文档 TodoDao 示例）。
- 删掉类头那段「不写 `@DriftAccessor`…drift#3669」注释。
- 新增生成物 `sample_dao.g.dart`（此前该文件不存在，因为它不用 `@DriftAccessor`）。
- **验证点**：codegen 无告警、`sample_dao_test` 绿、`sample_list_notifier_test` 绿。
  （若 `@DriftAccessor` + `@DriftDatabase` 同表在本 drift 版本报错，回退到
  「DAO 不含表、经 `attachedDatabase.dbArticles` 取表」的等价写法，并在 design 记录偏差。）

同步改口径：`backend/database-guidelines.md` 里「跨 package 禁 `@DriftAccessor`（drift#3669）」
那节 —— 本分支已无跨 package 表，改为「表与数据库同包，DAO 用 `@DriftAccessor`」。

## 7. 门禁 / 工具 / CI

| 文件 | 改动 |
|---|---|
| `tool/check_boundaries.dart` | 扫描根 `['lib', 'packages/app_core/lib']` → `['lib']` |
| `tool/check_coverage.dart` | 默认 `--src` / 相关常量去掉 `packages/app_core/lib` |
| `tool/check_readme_tree.dart` | 目标树去掉 `packages/app_core/lib` 那棵 |
| `tool/prune.dart` | 去掉 app_core 相关裁剪面（若有） |
| `.githooks/pre-commit` | 去掉 `cd packages/app_core && …` 与 `--src=packages/app_core/lib` |
| `.github/workflows/ci.yml` | 同上（`app_core` 的 test/analyze/codegen 步骤与 `--src` 参数） |
| `test/tool/check_boundaries_test.dart` | 断言里的扫描根 / 用例路径若引用 app_core，同步 |

## 8. 文档 / spec

- `README.md`：删 `packages/app_core/lib` 那棵目录树；依赖表去掉 app_core；
  「改完必跑」去掉 `(cd packages/app_core && …)` 与第二个 `--src`
- `AGENTS.md`：命令块同样去重；`lib/` 说明里「基础设施已抽到 packages/app_core」改成回流口径
- `BRANCH.md`：删「共用资产 `packages/app_core`（两栈完全一致）」段与「包零改动」行；
  说明本分支已单栈化
- `docs/release-checklist.md`：生成物清单 / 命令去掉 app_core
- `.trellis/spec/`：`backend/{database-guidelines,error-handling,logging-guidelines,network-guidelines,quality-guidelines,directory-structure}.md`、
  `cross-cutting.md`、`frontend/{component-guidelines,directory-structure}.md` —— 把
  `packages/app_core/lib/xxx` 一律改回 `lib/core/xxx`，`@DriftAccessor` 口径按 §6 更新
- `.cursor/rules/project-conventions.mdc`：去掉 app_core 相关指路

## 9. 执行顺序（关键：codegen 时机）

沿用 `09-22` 的红窗口教训 —— **编译不过时绝不跑 `build_runner`**（会静默覆盖生成物）：

1. `git mv` 搬迁代码 + `git mv` 测试树
2. 全局改 import 前缀
3. 改 `pubspec.yaml`，`flutter pub get`
4. 改 `sample_dao.dart`（此时它引用的 `my_app/...` 已就位，但不跑 codegen）
5. `flutter analyze lib/ test/` 收敛到只剩「`sample_dao.g.dart` 不存在」这类**预期**错误
6. **此时才**跑 `dart run build_runner build`（一次性生成 auto_route / drift / freezed /
   riverpod / retrofit；新增 `sample_dao.g.dart`）
7. 核对生成物 diff 只有预期变化（尤其 `router.gr.dart`、`app_database.g.dart`）
8. 删除 `packages/`（若还有残留：pubspec / analysis_options / .dart_tool）
9. 改门禁脚本 / CI / 文档
10. 跑六道门禁全绿（见 `implement.md` 验证清单）

## 10. 风险与回滚

| 风险 | 处置 |
|---|---|
| `git mv` 目录合并覆盖同名文件 | 已核无同名；执行前再 `git status` 确认 |
| codegen 在红窗口跑坏生成物 | §9 顺序强制：先 analyze 收敛再 build_runner；跑完核对 diff |
| `@DriftAccessor` 同表组合报错 | §6 回退等价写法并记录 |
| 覆盖率阈值掉下 80% | 搬迁不改逻辑，应持平；若掉，查是否漏搬测试（`test/core/**` 数量 = 17） |
| 文档遗漏导致 `check_readme_tree` 红 | 门禁本身即是检查；README 两棵树必须同步 |
| 误改到 master | 全程在 `preset/ai-starter`；收尾用 `git diff master..HEAD --stat` 复核差异仅限预期文件 |

**回滚**：本任务全部改动集中在分支工作区，未提交前 `git restore` / `git checkout .` 即可；
提交后按提交粒度 `git revert`。不影响 master。

## 11. 验收命令（GoD）

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

外加断言：`git grep "package:app_core"`（lib/test/tool/docs）为空；`packages/` 不存在。
