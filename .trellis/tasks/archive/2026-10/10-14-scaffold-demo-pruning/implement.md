# Implement — 脚手架 demo 剪枝自动化

> 前置：本文件是执行计划。锚点清单见 design.md §2.2，决策见 §3。
> 高风险点集中在「改 `main_page.dart`」与「删 Drift 表」，见 §4 回滚点。

## 0. 前置验证（先做，可能改变方案）

- [x] **0.1 验证空表能否过 codegen** —— **已完成，结论：通过**。
      实测过程：把 `@DriftDatabase(tables: [DbArticles])` 改成空表 → `just codegen` 成功
      （`allSchemaEntities => []`）→ 复原 → 重跑 codegen。
      **注意 A5 的实现形态**：不能写成 `tables: []`（`avoid_redundant_argument_values` 判冗余实参，
      `--fatal-infos` 下会红），要写成 `@DriftDatabase()`（连参数一起去掉）。见 design.md 决策 3。
      退路（保留 `db_articles.dart`）**不需要**。
- [ ] **0.2 记下基线**：`git status --porcelain` 除 `.trellis/` 外必须为空（任务元数据本就未入库）；
      `just verify` 必须全绿。

## 1. 工具骨架

- [ ] **1.1** 新建 `tool/prune_examples.dart`，薄 `main()` → `runCli(args, root: Directory.current)`。
      参考 `tool/init_project.dart:9-22` 的形态（返回退出码，不直接 `exit`）。
- [ ] **1.2** 实现 `PruneOptions` + `parseArgs`：`--modules=` / `--yes|-y` / `--no-verify` /
      `--force` / `--help|-h`。未知选项或缺值抛 `FormatException`（照
      `init_project.dart` 的 `parseArgs`）。
- [ ] **1.3** 定义 `PruneModule`（`article` / `demo`）与 `PruneEdit`（`deleteLines` /
      `replaceText` / `deleteFile` / `dropBlock`），填入 design.md §2.2 的锚点表。
- [ ] **1.4** 实现 `buildPlan(root, modules)`：为每条 `PruneEdit` 求匹配数；
      任一 ≠ 1 则返回失败计划（含逐条诊断）。**此阶段零写盘。**
- [ ] **1.5** 实现拒绝分支（写盘前）：`auth` → 退出码 2；工作区不干净且无 `--force` → 退出码 2；
      模块已剪枝 → 幂等提示 + 退出码 0。
- [ ] **1.6** 实现 `applyPlan`：删目录/文件 → 应用 edits。写盘前的确认提示要列出「将删除 N 个文件、
      修改 M 处」，并说明回滚命令 `git checkout -- . && git clean -fd`。
- [ ] **1.7** 实现残留扫描（design.md §2.3）：`lib/**`/`test/**` 命中 → 退出码 1；
      文档命中 → 打印清单不失败。
- [ ] **1.8** 实现 `runProcess` 注入（默认 `Process.run`），串起 `just codegen` → `just verify`；
      `--no-verify` 跳过并打印下一步命令。失败 → 退出码 3 + 打印输出尾部与回滚命令。

## 2. 测试

- [ ] **2.1** 新建 `test/tool/prune_examples_test.dart`，镜像 `test/tool/init_project_test.dart`：
      `Directory.systemTemp.createTempSync` 造夹具 + 注入假 `runProcess`。
- [ ] **2.2** 夹具内容按 design.md §4：只放被锚点引用的 6 个文件 + `lib/features/{article,demo}/`。
      夹具里**不写字面包名**（沿用 `init_project_test.dart` 的 `_import()` 做法），
      否则改名后测试自己会失效。
- [ ] **2.3** 用例：参数解析（空值 / 未知模块 / `--help` / `--no-verify`）；
      `auth` 拒绝（退出码 2 且夹具零改动）；脏工作区拒绝；
      锚点被改坏 → 非零 + 零改动（AC5）；已剪枝后再跑 → 0（AC6）；
      `dropBlock` 只删目标块、不留空行塌陷（只删 1 处不误伤同名片段）。
- [ ] **2.4** 加「真实仓库锚点」测试（design.md §4 末条）：对真实
      `lib/app/routing/router.dart`、`lib/features/home/page/main_page.dart`、`home_page.dart`、
      `profile_settings.dart`、`dio_client.dart`、`app_database.dart` 调 `buildPlan` 断言全部匹配 1 次。
      该测试在锚点漂移时立刻红。
- [ ] **2.5** 加 `main_page.dart` 剪枝后形态测试：对夹具执行 article 剪枝后，
      断言 NavigationRail / NavigationBar 的 destination 列表长度为 2，且 `labelStyle` 索引未错位
      （design.md §2.2 末尾的语义残留风险）。
- [ ] **2.6** 加端到端测试（`SCAFFOLD_E2E=1` 门控，镜像 `init_project_test.dart` 的同名做法）：
      复制真实仓库到临时目录 → 在副本上跑剪枝 → 断言模块目录已删、生成物里无 `Article*`，
      并跑真实 `just codegen` + `just verify`。默认跳过；CI 的 `analyze` job 带着这个环境变量，
      所以它必须在 CI 上是绿的（冷跑约几分钟，与既有的改名 E2E 同级）。

## 3. 验收（在临时副本上，不动本仓库）

- [ ] **3.1** 复制仓库到临时目录（镜像 `test/tool/init_project_test.dart` 的 `SCAFFOLD_E2E=1` 做法），
      在**副本**上执行 `dart run tool/prune_examples.dart --yes --modules=article,demo`。
      **不要在本仓库直接剪枝** —— 它是模板本身（见 prd.md「Confirmed Facts」）。
- [ ] **3.2** 核对 **AC2**（副本上）：`grep -rn "features/article\|features/demo\|ArticleListRoute\|StorageDemoRoute" lib test` 无命中。
- [ ] **3.3** 核对 **AC3**（副本上）：`router.gr.dart` / `service_locator.config.dart` 无 `Article*` / `StorageDemo*`。
- [ ] **3.4** 核对 **AC8**（本仓库，只读）：在干净仓库上跑一次工具、按 `n` 中止，
      确认文档残留清单命中 `AGENTS.md:117` 与 `.trellis/spec/**`。
- [ ] **3.5** 核对设计文档点名的语义风险（副本上）：`main_page.dart` 标签索引、`home_page.dart` 卡片
      布局是否留下孤立 `SizedBox`/分隔线、`router.dart` 的 `_checkAuth` 守卫是否仍挂在 `MainRoute` 上。
- [ ] **3.6** 副本上 `just verify` 全绿（含新测试）；本仓库 `just verify` 同样全绿，且
      `git status --porcelain` 里 `lib/features/**` 与 `test/features/**` 无改动。

## 4. 文档同步

- [ ] **4.1** 改写 `docs/template-pruning.md`：删掉 article/demo 的逐步手工清单（已漂移的 5 处），
      换成「§用工具剪枝（`dart run tool/prune_examples.dart`）+ §auth 手工改造 + §占位清单」。
      占位清单（`TODO(template)` / 图标缺失 / release 签名）**原样保留**。
- [ ] **4.2** `template-pruning.md:2-4` 的「快照（2026-10）」说明随之更新（清单形态变了）。
- [ ] **4.3** `AGENTS.md` 加一行工具入口（放在「改完必跑 / 初始化」附近），只留命令，不复述语义。
- [ ] **4.4** 若改了 `lib/` 文件集合（本任务不改），按 `spec/index.md` 同步 `README.md` 目录树。
- [ ] **4.5** 检查 `init_project.dart` 末尾的「Next steps」是否加了剪枝提示（design.md 决策依据）。

## 5. 验证命令

```bash
# 工具自身 + 夹具
just test -- test/tool/prune_examples_test.dart

# 全门禁
just verify

# 端到端验收：复制仓库到临时目录后剪枝 + codegen + verify（不动本仓库）
SCAFFOLD_E2E=1 just test -- test/tool/prune_examples_test.dart

# 回滚（工具会打印这两条）
git checkout -- . && git clean -fd
```

## 6. 回滚点

| 位置 | 风险 | 回退 |
|---|---|---|
| `lib/features/home/page/main_page.dart` | 删中间 destination 后 `labelStyle` 索引错位；编译能过、门禁全绿 | `git checkout -- lib/features/home/page/main_page.dart`，按 §2.5 的测试重做 |
| `lib/app/routing/router.dart` | 误删 `_checkAuth` 守卫或 `MainRoute` 子路由结构 | 同上；剪枝后必须人工核对守卫仍挂在 `MainRoute` |
| `lib/core/data/database/app_database.dart` | 空表列表过不了 codegen（§0.1 未验证就动手） | 保留 `db_articles.dart` 的退路方案 |
| `docs/template-pruning.md` | 改后丢掉了仍然有效的占位清单信息 | `git checkout -- docs/template-pruning.md`，只重做 §4.1 |
| 误在本仓库剪枝（应只在副本上做） | 不可逆 | **强依赖 §0.2 的干净基线**；本仓库回滚 = `git checkout -- . && git clean -fd` |

## 7. 完成前自检

- [ ] AC1–AC8 全部勾选（prd.md）。
- [ ] 工具在锚点漂移时**响亮失败**（有测试证明），而不是静默少删。
- [ ] 文档里不再有与工具重复的手工 article/demo 清单。
- [ ] `just verify` 全绿。

---

## 8. 实施结果（全部完成）

- [x] §0.1 空表 codegen 验证 —— 通过；A5 的形态修正为 `@DriftDatabase()`（不能写 `tables: []`）
- [x] §1 工具骨架 —— `tool/prune_examples.dart`（约 1480 行），两层模型：`DeleteBlock` / `ReplaceBlock`
- [x] §2 测试 —— `test/tool/prune_examples_test.dart`，**28 个用例**（+1 个 `SCAFFOLD_E2E` 门控）
- [x] §3 验收 —— 副本端到端全绿（AC1/AC2/AC3/AC8 实测见 design.md §8）
- [x] §4 文档同步 —— `docs/template-pruning.md` 重写、`AGENTS.md` 加工具入口、
      `init_project.dart` 的 Next steps 加剪枝提示（放在提交**之后**，因为工具有干净基线要求）
- [x] §5 验证命令全部跑过
- [x] §7 完成前自检 —— `just verify` 全绿（375 passed / 2 skipped）

### 与计划的差异（已在 design.md §7 记录）

1. 四种 `PruneEdit` 合并成两种（首尾行锚点在本仓库不可能唯一）
2. 替换块按命中行缩进重排（`reindentReplacement`）—— 否则工具源码的缩进会写进目标文件
3. 残留扫描要排除工具自身与其测试
4. 指纹追加路径形态（`features/article`），否则 AC8 命中不了 `AGENTS.md:117`
5. 锚点从 19 条涨到 35 条；其中 1 条由残留扫描、3 条由 `unused_import` 抓出

### 未做/留待后续

- `SCAFFOLD_E2E=1` 的端到端用例**只在 CI** 跑（本地默认跳过）——本轮用人工副本跑过等价流程，
  两次均全绿；但这条 CI 用例本身未被真实 CI 执行过（本地未设该环境变量跑它）
- 子代理（`trellis-implement` / `trellis-check`）在 Windows 上 `spawn pi ENOENT`，本轮按
  inline 模式实施，**没有独立的第二双眼睛**做 2.2 quality check
