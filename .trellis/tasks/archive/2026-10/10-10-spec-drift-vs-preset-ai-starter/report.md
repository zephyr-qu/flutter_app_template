# 兄弟分支 spec 重构对比报告

**结论先行**：值得移植的只有**结构性改进**（单一入口、消重、写作约束、几处缺口），
**不能**整篇照搬 —— 两侧 spec 各自与自己的代码一致，差异的一半来自 Riverpod / Signals 的栈分野。

| 项 | 值 |
|---|---|
| 本地 `$L` | `F:/App/flutter_app_template`，branch `master`，HEAD `ced6626` |
| 兄弟 `$S` | `F:/App/新建文件夹/flutter_app_template`，branch `preset/ai-starter`，HEAD `14fe982` + **未提交**改动 |
| 分叉点 | `4150ee6`（2026-09-22 之后互不回流） |
| 栈 | `$L` = Signals + ViewModel + GetIt/injectable + 有认证；`$S` = Riverpod + Notifier + provider + 无认证 |
| 只读证据 | 调查前后 `git -C "$S" status --short` 一致（M 7 / ?? 4） |

---

## 1. 关键前提修正

原假设「兄弟项目更全，本地落后」不成立，两处都要纠正：

1. **`F:/App/zephyr_*` 不是兄弟项目**，是从本仓库克隆出去的下游应用（各有独立 `.git`），
   其 spec 层是更早的通用种子版，本次不作取料源。
2. **`$S` 不是 `$L` 的新版本**，是另一条栈的兄弟分支。逐项核实后：

| 我核到的事实 | 证据 |
|---|---|
| `$L` spec 仍描述 `CoreModule` + `AuthStorage`，而 `$L` 代码里这两者**确实还在** | `ls lib/core/core_module.dart`、`grep -rl AuthStorage lib/`（10 个文件） |
| `$S` spec 描述 `lib/core/providers.dart` + 无认证，`$S` 代码同样如此 | `ls $S/lib/core/providers.dart` |
| `$L` 的 `just verify` 含目录树一致性门禁，`$S` 已无此脚本 | `$L/justfile:53` → `tool/check_readme_tree.dart`；`$S/tool/` 无该文件 |

**所以这次要取的是 S 的「编辑工艺」，不是 S 的「技术结论」。** 术语也必须换回来：
`$S` 用 `SampleItem` / `Notifier` / `data/` / `ui/`，`$L` 用 `Article` / `ViewModel` / `backend/` / `frontend/`。

---

## 2. 判定口径

| 判定 | 含义 |
|---|---|
| **可原样移植** | 栈无关，且 `$L` 确实没有 |
| **需改写后移植** | 思路可用，正文要走 `$L` 口径（术语 / 注解 / 目录名） |
| **不适用** | 依赖 Riverpod 或 `$S` 特有结构 |
| **不取** | `$L` 已更好，或 `$S` 侧是退化 |

---

## 3. spec 层全清单（无遗漏）

`$L` 21 个文件 / `$S` 30 个文件（含 4 个未跟踪新增）。

### 3.1 只在 `$S` 侧（13）

| `$S` 文件 | `$L` 对应 | 判定 |
|---|---|---|
| `index.md` | `backend/index.md` + `frontend/index.md`（二合一） | **可原样移植**（见 §4.1） |
| `directory-structure.md` | `backend/directory-structure.md`(46) + `frontend/directory-structure.md`(201) | 需改写后移植（内容 `$L` 已有，S 只是合并 + 换目录名） |
| `type-safety.md` | `frontend/type-safety.md` | 需改写后移植（仅位置从 `frontend/` 提到根） |
| `data/database-guidelines.md` | `backend/database-guidelines.md` | **不取**（`$L` 已更全，见 §7） |
| `data/error-handling.md` | `backend/error-handling.md` | **不取**（`$L` 独有 401 / 令牌刷新 / 登出语义） |
| `data/logging-guidelines.md` | `backend/logging-guidelines.md` | 不适用（镜像，`$L` 更长） |
| `data/network-guidelines.md` | `backend/network-guidelines.md` | **不取**（`$L` 独有「`extra` 标记而不是判断 URL」节） |
| `data/quality-guidelines.md` | `backend/quality-guidelines.md` | 不适用（镜像） |
| `ui/component-guidelines.md` | `frontend/component-guidelines.md` | **不取**（`$L` 独有 `Three-State Rendering` 节与更完整页面模板） |
| `ui/localization.md` | `frontend/localization.md` | **需改写后移植**（`$S` 更细，见 §5.1） |
| `ui/quality-guidelines.md` | `frontend/quality-guidelines.md` | 不适用（镜像，`$L` 更长） |
| `ui/routing.md` | `$L` 无专篇，散落在 `frontend/directory-structure.md:100,102` | **可原样移植**（见 §4.3） |
| `ui/state-management.md` | `frontend/state-management.md` | **不适用**（全篇 Riverpod provider / Consumer） |

### 3.2 只在 `$L` 侧（4）

| `$L` 文件 | 说明 | 判定 |
|---|---|---|
| `backend/index.md` | 被 `$S` 的根 `index.md` 取代 | 它的「跨层与门禁 / 相关目录 / 写文档时的约定」三段与 `frontend/index.md` **逐字重复**，且已漂（见 §4.1） |
| `frontend/index.md` | 同上 | 同上 |
| `backend/directory-structure.md` | `$S` 合并成根 `directory-structure.md` | 保留（数据层文件角色表） |
| `frontend/hook-guidelines.md` | `$S` 无（Riverpod 不用 hooks） | **保留**：`$L` 用 `signals_hooks`，`hook-guidelines.md` 是 `$L` 独有财富 |

### 3.3 两侧都有但内容不同（17）

| 文件 | 差异性质 | 判定 |
|---|---|---|
| `cross-cutting.md` | `$L` 7 条插件规则 / `$S` 4 条；`$S` 多「退出码表」「不要新加的门禁规则」「flutter#187999 链接」 | 需改写后移植（挑 §4.4 两项，其余不取） |
| `guides/index.md` | `$S` 多「用 `git grep`，别只用 Grep / ripgrep」一段 | **可原样移植**（见 §4.2） |
| `guides/comment-guidelines.md` | `$S` 多「只写结果与现状」「判据必须留」；语言政策改为全中文 | **可原样移植**（前两条）；语言政策 → §9 未决 |
| `guides/code-reuse-thinking-guide.md` | `$S` 精简 + 表格化；`$L` 有 Pattern 1–3 的英文展开 | 不适用（内容等价，各写各的） |
| `guides/cross-layer-thinking-guide.md` | 术语绑定（`$S` Notifier/`AsyncValue`，`$L` ViewModel/`AsyncState`） | 不适用 |
| `guides/rename-checklist.md` | `$S` 第 2 项写「含生成物，省得再跑 codegen」且**漏了 `packages/`**；`$L` 有「两个包各跑一次 `pub get`」 | **不取**（`$L` 口径与其 `tool/` 现状一致且更细） |
| `backend/database-guidelines.md` | `$L` 296 / `$S` 215；key `app.{domain}.{key}`、`part of`、`@DriftAccessor`、读软写硬 **`$L` 全都有**（`:81,:144,:148,:89`） | **不取** |
| `backend/error-handling.md` | `$L` 独有 401 / 令牌刷新 / 登出语义（`:128,:149`） | **不取**（`$L` 有认证） |
| `backend/logging-guidelines.md` | 镜像，`$L` 更长 | 不适用 |
| `backend/network-guidelines.md` | `$L` 独有「`extra` 标记而不是判断 URL」(`:112`) | **不取** |
| `backend/quality-guidelines.md` | 镜像 | 不适用 |
| `frontend/component-guidelines.md` | `$L` 独有 `## Three-State Rendering`(`:178`) | **不取** |
| `frontend/directory-structure.md` | `$S` 把它拆进根 `directory-structure.md` | 不适用（保留 `$L` 的） |
| `frontend/localization.md` | `$S` 76 / `$L` 47，`$S` 更细 | 需改写后移植 |
| `frontend/quality-guidelines.md` | 镜像 | 不适用 |
| `frontend/state-management.md` | 栈分野（`$L` 401 行 Signals 全套） | 不适用 |
| `frontend/type-safety.md` | `$S` 把「Signal state checking」改成「异步状态判定」 | 不适用（`$L` 的才对） |

---

## 4. 可原样移植

### 4.1 根 `spec/index.md`：单一入口 + 两张清单（收益最大）

`$S/.trellis/spec/index.md:7` 的「开工前必读」（按你要动的东西选该读哪份）与 `:19` 的
「完成前自检」（`just verify`、codegen、架构边界、`FailureCode` 文案、目录树同步）在 `$L` **完全缺失**
（`grep -rn "开工前必读\|完成前自检" $L/.trellis/spec` 无输出）。

**驱动这条的不只是「好看」，是 `$L` 已经在漂**：

| 文件 | 「跨层与门禁」清单 |
|---|---|
| `backend/index.md:22` | 边界 / 覆盖率 / 依赖声明 / `leak_tracker` / 集成测试 / 环境配置 —— **没有「代码生成与生成物」** |
| `frontend/index.md:23` | 同上 **+ 代码生成与生成物（生成物不入库、重新生成时机、CI 现场生成）** |

两份索引的 `## 跨层与门禁` / `## 相关目录` / `## 写文档时的约定` 三段本来就逐字重复
（`backend/index.md:20,26,34` vs `frontend/index.md:21,27,35`），漂是必然结果。

**落点**（最小改动版，不动目录结构）：

1. 新建 `.trellis/spec/index.md`：抄 `$S` 的「开工前必读」+「完成前自检」两张清单，
   链接改指 `$L` 现有路径（`backend/…` / `frontend/…`）。
2. 清单里的 `@riverpod` 换成 `$L` 的注解集（`@freezed` / `@RoutePage` / `@injectable` / Drift 表）。
3. 删掉 `backend/index.md` 与 `frontend/index.md` 尾部的三段重复，改为一行指回根 `index.md`。
4. 同步 `AGENTS.md` 的「开工前必读」（现写「数据层…见 `backend/index.md`；前端…见 `frontend/index.md`」）。

**成本**：中（约 4 个文件、改动都在索引层）。

### 4.2 `guides/index.md` 的 `git grep` 洞见（成本最低）

`$S/.trellis/spec/guides/index.md` 的「改任何值之前先搜」一节新增：

> 用 `git grep`，别只用 `Grep` / ripgrep —— 它们默认跳过点号目录（`.trellis/` `.cursor/`
> `.github/` `.agents/`），「全仓库扫描」会漏掉 spec、规则与 CI 配置。

**我在 `$L` 实测这条成立**：

```bash
rg -l "prune.dart" .          # 5 个文件，全部缺 .trellis/
rg -l --hidden "prune.dart" . # 8 个文件，才出现 .trellis/spec/frontend/localization.md
git grep -ln "prune.dart"     # 8 个，与 --hidden 一致
```

`$L` 的 `guides/index.md` 只有 `grep -r "value_to_change" .` 一行，**没有这条警告**。
落点：`$L/.trellis/spec/guides/index.md`「Pre-Modification Rule」节后加 3 行。成本：极低。

### 4.3 `ui/routing.md` 的三条行为约定

`$L` 无路由专篇，其中两条散在 `frontend/directory-structure.md:100,102`，第三条**是缺口**：

| `$S` 的约定 | `$L` 现状 |
|---|---|
| 不要随状态变化重建路由器（会丢导航栈） | ✅ 已有：`frontend/directory-structure.md:100`、`hook-guidelines.md:82` |
| 主框架标签用 `AutoTabsRouter`，不要在 `State` 里存 `_currentIndex` | ✅ 已有：`frontend/directory-structure.md:102` |
| `AutoRoute(initial: true)` **只对没写 `path` 的路由生效**；冷启动 initial location 由 `routerProvider` 设置，且**必须在 `config()` 之前** | ❌ `$L` 无（`grep -rn "initial location" $L/.trellis/spec` 无输出） |
| **改动底部导航标签必须同步 `test/routing/main_shell_test.dart`，且不在任何门禁拦截范围内** | ⚠️ `$L` 只在 `cross-cutting.md:314` 的集成测试例子与 `database-guidelines.md:194` 的 import 例子里出现过这个文件名，没有「必须同步」这条规则 |

落点：`$L/.trellis/spec/frontend/` 新增 `routing.md`（25 行量级），或把第 3、4 条并入
`directory-structure.md` 的应用层小节。成本：低。

### 4.4 `cross-cutting.md` 的两处可借

1. **analyzer 退出码表**（`$S/.trellis/spec/cross-cutting.md`）：info → 0、warning → 2、
   error → 3、info + `--fatal-infos` → 1。`$L` 的 `cross-cutting.md` 只说「用退出码兜住」，
   没给这张表 —— 而 `$L` 的门禁正是靠 `--fatal-infos`（`justfile` 两组 analyze）。
2. **「不要新加的门禁规则」的写法**：`$S` 把三条「有意不设」集中成一节并注明由 review 兜底。
   `$L` 的同类内容散落（`cross-cutting.md:103` 覆盖率、`:150` 未使用依赖），
   `AGENTS.md` 也只给了一句「「有意不设门禁」的项见 `cross-cutting.md`」。集中一节即可。

---

## 5. 需改写后移植

### 5.1 `localization.md`（`$L` 47 行 → 补到 `$S` 的 76 行量级）

`$S` 版比 `$L` 版多三样，都是 `$L` 缺的：

1. **「现状」核对表 + 每行的核对命令**（`$S/ui/localization.md` 「现状」节）：
   `l10n.yaml` / `lib/l10n/**` / `pubspec` 依赖 / 文案位置 / `Failure` 文案 逐项列现状 +
   `grep -rn "AppLocalizations" lib/` 应无输出。`$L` 只写了散文。
2. **加回多语言的 9 步清单**（`$S` 的 9 步 vs `$L` 的 6 步），且 `$S` 指出两个抓点：
   `depend_on_referenced_packages`（`analysis_options.yaml` 提升为 error）会拦「声明了不用」，
   第 9 步（同步目录树）**没有门禁兜**。
3. **「不要做的事」4 条**，其中「以为 `wrapPage()` 需要挂 l10n delegate —— `$L` 没有 l10n，
   `wrapPage()` 只挂主题」这条 `$L` 没有。

**改写点**：`$S` 的第 5 步是「加回 `_keyLocale` 与 `locale` 的读写（照 `_keyThemeMode` 的写法，
落盘失败抛 `PreferenceWriteException`）」—— 与 `$L` 的 `UserPreferences` signal 写法可对齐；
但 `$L` 的 `localization.md` 第 4 步还牵涉 `AuthGuard` / 登录态，需按 `$L` 现状重写，
不能连 `app_test_harness.dart` 的 `wrapPage` 签名一起抄。

### 5.2 `comment-guidelines.md` 的两条写作约束

`$S` 版新增、`$L` 版没有：

> **只写结果与现状**：不写原因与推导（「因为…所以」「为了…才」）、不写后果与现象描述、
> 不写历史与被否决的方案、不写日期叙事与 commit 号。跨层约定写进 `cross-cutting.md`。
>
> 属于**判据**的部分必须留 —— 拦截范围、全等比较、穷尽 `switch` 这类判定条件，
> 读者要靠它判断某写法算不算违规。

这两条与 `$S` 的 6 处「消重」提交（`367a07f docs: 收敛文档里的 6 处重复，每处只留一个权威`）
是同一套方法。落点：`$L/.trellis/spec/guides/comment-guidelines.md`「spec 该怎么写」节。
**注意**：`$S` 同一文件里还有「语言政策改为全中文」，那条与 `$L` 现行政策冲突 → §9。

---

## 6. 不适用（栈绑定，别抄）

- `ui/state-management.md` 全篇：`ProviderContainer` / `ConsumerWidget` / `@riverpod` /
  `autoDispose` / `ref.watch` —— `$L` 是 `ViewModel` + `signals` + `runAsync`。
  其中「渲染状态一律走 `AsyncView`」「副作用不要写在 `build` 里」「测试三条硬约束」
  在 `$L` 已有对应写法（`frontend/state-management.md:282`、`hook-guidelines.md`）。
- `cross-cutting.md` 的 `avoid_ref_read_in_build` 规则（`$L` 无 `ref`）。
- `data/database-guidelines.md` 的「provider 装配」段（`prefsProvider.overrideWithValue`）。
- 术语替换类差异：`ViewModel→Notifier`、`AsyncState→AsyncValue`、
  `backend/→data/`、`frontend/→ui/`、`Article→SampleItem`、`CoreModule→providers.dart`。
  这些是**噪音**，不是可移植内容。

---

## 7. 不取清单（含为何 `$S` 更弱）

| 项 | 理由 |
|---|---|
| `$S` `cross-cutting.md`「目录树一致性（无门禁）」 | `$L` **有**门禁：`justfile:52-53` → `tool/check_readme_tree.dart`（`$S/tool/` 已无此脚本）。取 `$S` 的说法等于自愿放弃一道门禁 |
| `$S` `rename-checklist.md` 第 2 项「含生成物，省得再跑 codegen」 | `$L` 口径是「生成物不入库 → 改名后跑 `just codegen`」，与 `$L` 的 `tool/`、`.gitignore` 一致；`$S` 该项还**漏了 `packages/`** |
| `$S` 删除 `docs/adr/ADR-0001/0002` 与 `docs/architecture-review.md` | `$S` 删它们是因为改成了 Riverpod，ADR-0001（ViewModel 构造器注入）/ ADR-0002（不引入 ViewModel 基类）在 `$L` **仍然有效**（`$L` 还在用 GetIt + ViewModel） |
| `$S` `data/error-handling.md` 去掉的 401 / 令牌刷新 / 登出语义 | `$L` 有认证（`lib/features/auth/`、`AuthStorage`），这三节是 `$L` 的资产 |
| `$S` `data/network-guidelines.md` 去掉的「`extra` 标记而不是判断 URL」 | `$L` 独有且仍适用（`core/data/network/`） |
| `$S` `ui/component-guidelines.md` 去掉的 `Three-State Rendering` | `$L` 的 `AsyncState` 三态渲染比 `$S` 的 `AsyncValue` 更需要这节 |
| `$L` spec 的英文内容（如 `backend/database-guidelines.md` 正文） | `$L` 的正文信息量更足（key 命名 / 失败策略 / drift part 约束 / `@DriftAccessor` 报错文本都在），**不要**为了「统一成 `$S` 的样子」把它翻掉 |

---

## 8. 上层文档（`AGENTS.md` / `README.md` / `BRANCH.md` / `docs/`）

### 8.1 `AGENTS.md`：两侧是**两套不同的东西**，不是新旧版

| | `$L`（130 行） | `$S`（92 行） |
|---|---|---|
| Trellis 托管块 | ✅ `TRELLIS:START/END`（由 `trellis update` 管理） | ❌ 无 |
| 项目契约 | 开工前必读 / 改完必跑 / 照抄对象 `lib/features/article/` / 禁止模式速查 | 开工前先读（指 `spec/index.md`）/ 改完必跑 / 照抄对象 `features/sample/` / 删除示例 |
| 治理章节 | ❌ 无 | ✅ 工作原则 / 范围与授权 / 工程实现 / 验证与交付 / 联网与工具 / Shell 与 Git |

`$S` 的治理章节是**通用 AI 行为契约**（与项目技术栈无关），`$L` 完全没有这一层。
这部分**不是文档漂移**，是两种主张；是否并入 → §9。

### 8.2 `README.md`：`$S` 88 行 vs `$L` 313 行

`$S` 删掉了 `$L` 的「示例代码说明」「模板占位清单」「架构原则」等节。
**不建议照抄这次精简**：`$L` 的 `README` 面向「拿这个脚手架开新项目的人」，
那几节正是使用者要读的；`$S` 精简后反而要去 `AGENTS.md` 补。
只有一处值得单独考虑：`$S` 的「常用命令」「环境与构建」把命令与口径并到一节，比 `$L` 分散三处好查。

### 8.3 `BRANCH.md`：`$S` 已删除

`$S` 侧 `15842ea docs: 精简 AI 协作契约与过时文档` 删掉了 `BRANCH.md`（`git log -- BRANCH.md` 可复现）。
`$L` 的 `BRANCH.md`（45 行）描述 master 与 `preset/ai-starter` 两条分支的关系，
**仍准确**（本次调查反而验证了它的分叉描述）→ 保留。

### 8.4 `docs/`：`$S` 少两个文件、`optional-additions.md` 明显收敛

| 文件 | `$L` | `$S` | 判定 |
|---|---|---|---|
| `adr/ADR-0001/0002` | 2 篇 | 已删 | **不取**（§7） |
| `architecture-review.md` | 222 行 | 已删 | 不适用（`$L` 的候选清单已由 ADR 结案） |
| `optional-additions.md` | 245 行 | 162 行 | **部分借**：`$S` 把 §7 build flavor 从 104 行压成 25 行判据清单 |
| `release-checklist.md` | 145 行 | 143 行 | 等价，无增量 |

§7 这一节还顺手修掉了 `$L` 的一处**真实缺陷**：

```
$L/docs/optional-additions.md:197  ### 2. 让 flavor 决定加载哪个 `.env`   ← 空标题，无正文
$L/docs/optional-additions.md:198  ### 2. flavor 与 env 的关系            ← 与上一行编号撞车
```

（`$S` 的第七节没有这两个 `### 2.`，整段改为「四个判据（不看会返工）」清单。）
这条与 §4.1 的索引漂移是同一类问题：`$L` 的文档已经积累了「重复 + 编辑残留」，
而 `$S` 这一轮 WIP 的工作主题正是清理它们。

---

## 9. 未决问题（需你拍板）

1. **是否采用 `$S` 的主题化分层**（`data/` + `ui/` + 根 `directory-structure.md` / `type-safety.md` / `index.md`）？
   只做 §4.1 的「单一入口」是低风险；连目录一起改则会牵动 `AGENTS.md`、
   `guides/comment-guidelines.md` 的「层目录不能省（`backend/` / `frontend/`）」约定与全仓库注释里的 spec 引用。
2. **是否接受 `$S` 的「全中文标题」语言政策**？`$L` 现行政策（`guides/comment-guidelines.md`）明写
   「固定章节名用英文，正文用中文」，并特意注明「不要为了统一成英文把正文翻一遍」——
   `$S` 把它整个反了过来。这是政策选择，不是对错。
3. **是否把 `$S` AGENTS.md 的治理章节并入 `$L`**（工作原则 / 范围与授权 / 工程实现 / 验证与交付 /
   联网与工具 / Shell 与 Git）？它与 Trellis 托管块并存需要注意不冲突。
4. **是否吸收 `$S` README 的命令组织方式**（`$L` 313 → 部分收敛）？§8.2 建议只并命令节。

---

## 10. 复核方式

```bash
L="F:/App/flutter_app_template"; S="F:/App/新建文件夹/flutter_app_template"
git -C "$S" status --short                       # 应仍为 M 7 / ?? 4
comm -3 <(cd "$S" && find .trellis/spec -name '*.md'|sort) \
        <(cd "$L" && find .trellis/spec -name '*.md'|sort)   # §3 三态
grep -n "跨层与门禁" "$L"/.trellis/spec/{backend,frontend}/index.md  # §4.1 漂移
rg -l "prune.dart" .; rg -l --hidden "prune.dart" .; git grep -ln "prune.dart"  # §4.2
sed -n '195,200p' "$L/docs/optional-additions.md"                     # §8.4 缺陷
```

**Top 3 + 成本**：根 `spec/index.md` 单一入口（中，修的是已发生的漂移）＞ `git grep` 段与
「只写结果与现状」两条写作约束（极低，纯增量）＞ 路由两条缺口（低）。
