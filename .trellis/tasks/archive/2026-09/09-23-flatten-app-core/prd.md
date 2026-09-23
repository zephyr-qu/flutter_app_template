# preset/ai-starter：拍平 `packages/app_core` 回根工程

## Goal

在 `preset/ai-starter` 分支上，把 `packages/app_core`（双栈共用基础设施包）的代码
**拍平回根工程 `lib/core/`**，删除该 path 依赖与整个 `packages/` 目录，使本分支回到
**单体 `lib/` 结构**。

**只动 `preset/ai-starter`，`master` 与其它分支保持原样。**

## 背景 / 为什么

`09-22-extract-app-core` 抽包的原始理由是「signals / Riverpod 双栈共用、跨分支保持同一份」。
但本仓库是**脚手架**：不会长期演化，双栈长期同步的前提不成立，因此这层包对该用途属
over-engineering，并已产生实际代价——`SampleDao` 因 `drift#3669`（`@DriftAccessor`
解析不到另一个 package 里的表）被迫放弃 idiomatic 写法，改成手写绕行。

用户决策：**在本分支拆掉它**（不改其它分支）。

## Requirements

### R1 代码搬迁（原位）

`packages/app_core/lib/` 下 **23 个文件** → 根工程 `lib/core/` 下：

| 包内路径 | 根工程落点 |
|---|---|
| `base/`（failure, result, run_catching） | `lib/core/base/` |
| `config/network_config.dart` | `lib/core/config/` |
| `data/database/`（app_database + tables/db_articles） | `lib/core/data/database/` |
| `data/network/`（auth_extra_keys, auth_interceptor, dio_factory, token_refresher, token_store） | `lib/core/data/network/` |
| `data/storage/file_storage.dart` | `lib/core/data/storage/` |
| `logging/`（log_redactor, logging） | `lib/core/logging/` |
| `models/`（token_set, user） | `lib/core/models/` |
| `theme/`（app_color_scheme, app_theme, app_theme_extension） | `lib/core/theme/` |
| `ui/empty_widget.dart` | `lib/core/ui/` |

`packages/app_core/test/` 下 **17 个文件** → 根工程 `test/core/...`（保持镜像结构）。

> 落点就是 `09-22-extract-app-core` 抽取前的原位，等于把那次抽取在本分支上回退。

### R2 import 重写

`lib/` + `test/` 下 **40 个文件**的 `package:app_core/xxx` → `package:my_app/core/xxx`。

### R3 依赖与包收敛

- `pubspec.yaml`：删 `app_core: { path: packages/app_core }`；
  补入只在包内声明过的依赖 —— `dio_smart_retry`、`logger`、`path_provider`、
  `pretty_dio_logger`、`flex_color_scheme`；
  `drift` 由 `dev_dependencies` **升为 `dependencies`**（数据库/表代码回到根工程，运行期需要）。
- 删除 `packages/`（`app_core/lib`、`test`、`pubspec.yaml`、`analysis_options.yaml` 全部）。
- 重新生成 `pubspec.lock`。

### R4 恢复 `@DriftAccessor`

表回到同一个 package 后 `drift#3669` 不再成立：
`lib/features/sample/data/sample_dao.dart` 恢复 idiomatic 的
`@DriftAccessor(tables: [DbArticles])`，删掉现有「因为跨包所以不用」的绕行与注释。
（同步更新 spec 里「跨 package 禁 `@DriftAccessor`」那条口径。）

### R5 门禁 / 工具 / CI

- `tool/check_boundaries.dart`：扫描根由「`lib` + `packages/app_core/lib`」收敛为 `lib`
- `tool/check_coverage.dart` / `tool/check_readme_tree.dart` / `tool/prune.dart`：去掉 app_core 相关
- `.githooks/pre-commit`、`.github/workflows/ci.yml`：去掉 `packages/app_core` 步骤与
  `--src=packages/app_core/lib` 参数

### R6 文档 / spec

- `README.md`（两棵目录树 + 依赖表）、`AGENTS.md`（改动必跑命令块）、`BRANCH.md`
  （删「共用资产 / 包零改动」段）、`docs/release-checklist.md`
- `.trellis/spec/`：`backend/{database-guidelines,error-handling,logging-guidelines,network-guidelines,quality-guidelines,directory-structure}.md`、
  `cross-cutting.md`、`frontend/{component-guidelines,directory-structure}.md`
- `.cursor/rules/project-conventions.mdc`

## Constraints

- **只改 `preset/ai-starter`**；`master` 等分支一个字节都不动。
- 不放宽任何门禁阈值或规则来「让门禁变绿」。
- 生成物（`.g.dart` / `.freezed.dart` / `router.gr.dart`）一并提交。
- codegen 顺序：**先让 `flutter analyze` 收敛，再跑 `build_runner`**（`09-22` 的红窗口教训：
  编译不过时跑 codegen 会静默覆盖生成物）。

## Acceptance Criteria（DoD）

- [ ] `packages/` 目录不存在；`git grep "package:app_core"` 在 `lib/`+`test/` 为空
- [ ] `lib/core/{base,config,data,logging,models,theme,ui}/` 就位，内容与搬迁前逐文件一致（除 import 前缀）
- [ ] `test/core/**` 就位，17 个包测试并入根测试套件
- [ ] `sample_dao.dart` 使用 `@DriftAccessor(tables: [DbArticles])`，无绕行注释
- [ ] `pubspec.yaml` 无 `app_core` path 依赖，R3 列出的依赖已就位，`drift` 在 `dependencies`
- [ ] 六道门禁全绿（format / check_boundaries / check_conventions / check_readme_tree /
      dependency_validator / analyze / test+coverage）
- [ ] 文档与代码一致：README 树、AGENTS 命令块、BRANCH.md、相关 spec 中无 `app_core` 残留口径
- [ ] `master` 等其它分支零改动

## Notes

- 这是本分支幅度最大的一次改动（配置 + codegen + 门禁 + 文档全动）。
- 提交约定沿用本分支：`git commit --no-verify` + 手工跑完整门禁。
- 参考任务 `09-22-extract-app-core`（其逆操作，已归档）。
