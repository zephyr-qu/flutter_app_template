# 技术设计：packages/app_core

## 1. 边界判定

**唯一判据**：该文件是否 import 了状态管理库。

| 文件 | 是否有状态管理 import | 归属 |
|---|---|---|
| `core/base/failure.dart` | 否 | app_core |
| `core/base/result.dart` | 否 | app_core |
| `core/base/run_catching.dart` | 否 | app_core |
| `core/base/run_async.dart` | **是**（signals） | 留 master |
| `core/logging/*` | 否 | app_core |
| `core/models/*` | 否 | app_core |
| `core/data/network/*` | 否 | app_core |
| `core/data/database/*` | 否 | app_core |
| `core/theme/*` | 否 | app_core |
| `core/ui/{loading_indicator,error_text,empty_widget}.dart` | 否 | app_core |
| `core/ui/{async_view,failure_message}.dart` | 部分是 | async_view 留分支；failure_message 需摘掉 `AppLocalizations` 依赖 |
| `core/data/storage/auth_storage.dart` | **是**（signal + computed） | 留 master / ai-starter 各一份 |
| `core/config/user_preferences.dart` | **是**（signal） | 同上 |
| `core/core_module.dart` | 否，但用 `@module`（injectable 注解） | 需拆分：依赖注入方式本身是栈相关的 |

### 关键设计决策：`failure_message.dart` 怎么办

它把 `FailureCode` 翻译成用户文案，当前直接依赖 `AppLocalizations`。

**方案**：拆成两半。
- `app_core` 提供 `String failureMessageZh(FailureCode code)`——**纯常量映射，无 l10n 依赖**
- 各分支的 `core/ui/failure_message.dart` 负责本地化包装（master 走 `AppLocalizations`，ai-starter 同）

这样 `--l10n=single` 裁剪时只需改分支侧，包侧不动。

### 关键设计决策：`core_module.dart` 怎么办

`@module`（injectable）本身是 DI 方式，不是基础设施。拆法：

- 包内保留**纯工厂函数**：`Dio createDio({required NetworkConfig config, required AuthStorage auth, ...})`
- 各分支的 DI 层（`@module` 或 `@riverpod`）只负责把这些工厂接进容器

即包负责「怎么造」，分支负责「谁来提供」。

## 2. pubspec 设计

```yaml
# packages/app_core/pubspec.yaml
name: app_core
description: 与状态管理无关的基础设施（网络 / 数据库 / 主题 / 日志 / 模型）
publish_to: "none"

environment:
  sdk: ">=3.13.0 <4.0.0"
  flutter: ">=3.44.0"

dependencies:
  flutter: {sdk: flutter}
  dio: ...
  retrofit: ...
  drift: ...
  flex_color_scheme: ...
  logger: ...
  flutter_secure_storage: ...
  # 不出现：signals_* / riverpod* / get_it / injectable

dev_dependencies:
  build_runner: ...
  retrofit_generator: ...
  drift_dev: ...
  json_serializable: ...
```

根 `pubspec.yaml` 增加：

```yaml
dependencies:
  app_core:
    path: packages/app_core
```

## 3. 生成物与 codegen

包内 `*.g.dart` / `*.freezed.dart` 会跟着移动到 `packages/app_core/lib/**`。两条约束：

1. `tool/check_boundaries.dart` 的 `isGeneratedPath` 与 `dartFiles` 要能覆盖 `packages/app_core/lib`
2. `tool/check_coverage.dart` 的剔除口径复用同一个 `isGeneratedPath`，无需额外改

**生成命令**：`dart run build_runner build` 需要在根与包内各跑一次，或在 README/spec 记录统一入口。

## 4. 实施顺序（降低中途破损的窗口）

1. 建包骨架 + pubspec，根 pubspec 加 path 依赖，`flutter pub get`
2. 先搬**零依赖**的文件（`base/failure`、`base/result`、`base/run_catching`、`logging/`、`models/`），跑一次 analyze
3. 再搬 `network/`、`database/`（含 codegen）
4. 再搬 `theme/`、`ui/` 三件套
5. 最后处理 `failure_message` 拆分与 `core_module` 工厂化
6. 扩展 `check_boundaries` 的扫描根 → 跑门禁
7. 更新 README 目录树 → 跑 `check_readme_tree`

每步之后 `flutter analyze lib/` 应保持干净（用 IDE 的自动 import 修正或逐文件改 import 路径）。

## 5. 回滚

整体是一个可 `git revert` 的提交序列；过程中任一步失败可 `git checkout -- .` 回到上一步。不改动任何业务行为，因此**不需要数据迁移或分阶段发布**。

---

## 6. 实测后的修正（2026-09-22，执行阶段发现）

原始设计假设「27 个文件可直接搬」。实际读取依赖后发现有 **3 处耦合未覆盖**，其中第 1 处影响最大。

### 6.1 `AuthStorage` 被网络层依赖（设计未覆盖）

`auth_interceptor.dart` 与 `token_refresher.dart` 都 import `core/data/storage/auth_storage.dart`，
而 `auth_storage.dart` 含 `signal` + `computed`，**必须留在 lib**。

**后果**：不解决的话，双栈最有价值共享的两个网络文件反而共享不了（它们在原评估里正是"最需要同步"的文件）。

**解法：依赖反转**。包内定义抽象接口，lib 侧实现：

```dart
// packages/app_core/lib/core/data/network/token_store.dart（新增）
abstract interface class TokenStore {
  Future<void> get ready;
  String? getAccessToken();
  String? getRefreshToken();
  bool isAccessTokenExpiring({Duration skew});
  Future<void> saveTokens(TokenSet tokens);
  Future<void> clearAuth();
}

// lib/core/data/storage/auth_storage.dart
class AuthStorage implements TokenStore { /* 原实现不变 */ }
```

`AuthInterceptor` / `TokenRefresher` 的字段类型由 `AuthStorage` 改成 `TokenStore`，行为不变。

### 6.2 l10n 耦合不止 `failure_message`（设计只列了 1 个，实际 3 个）

| 文件 | l10n 用法 |
|---|---|
| `ui/failure_message.dart` | 整个 extension 吃 `AppLocalizations` |
| `ui/loading_indicator.dart` | `ScreenLoadingIndicator` 用 `l10n.loading` |
| `ui/error_text.dart` | `l10n.errorTitle` / `l10n.retry` / `failure.localizedMessage(l10n)` |

l10n 是**分支相关**的（`--l10n=single` 会整体裁掉），包不能依赖它。

**决策：这三个文件留在 lib**，只有无 l10n 依赖的 `ui/empty_widget.dart` 进包。

- 备选方案（文案参数化进包）会改 `ErrorText` / `ScreenLoadingIndicator` 的公开 API，牵连约 6 处页面调用点与对应测试
- 代价不抵收益：UI 组件体量小、复制成本低；而网络层体量大、复制成本高，那才是必须共享的部分

### 6.3 `FileStorage` 自带 `@Singleton`

进包后不能留 injectable 注解。

**解法**：去掉 `@Singleton()`，由 lib 的 `CoreModule` 显式注册（`@singleton FileStorage get fileStorage => FileStorage();`）。

### 6.4 修正后的最终划分

**进包（22 个）**

```
base/           failure, result, run_catching
logging/        logging, log_redactor
models/         user, user.freezed, user.g, token_set
config/         network_config
theme/          app_color_scheme, app_theme, app_theme_extension
data/database/  app_database, app_database.g, tables/db_articles
data/network/   auth_extra_keys, auth_interceptor, token_refresher
                + token_store.dart   （新增：接口）
                + dio_factory.dart   （新增：从 dio_client.dart 抽出的纯工厂）
data/storage/   file_storage         （去掉 @Singleton）
ui/             empty_widget
```

**留 lib（9 个）**

```
base/run_async.dart               signals
config/user_preferences.dart      signals + l10n
data/storage/auth_storage.dart    signals；改为 implements TokenStore
data/network/dio_client.dart      只剩 NetworkModule，调用 createDio
ui/async_view.dart                signals
ui/loading_indicator.dart         l10n
ui/error_text.dart                l10n
ui/failure_message.dart           l10n
core_module.dart                  DI；+ FileStorage 注册
```

### 6.5 `dio_client.dart` 的拆分（原设计的"工厂化"具体化）

`NetworkModule.dio()` 当前依赖 `UserPreferences`（signals）取 `enableDebugLogging`。反转方式：

```dart
// 包内：纯工厂，不依赖 signals / injectable
Dio createDio({
  required NetworkConfig config,
  required TokenStore tokenStore,
  required bool enableDebugLogging,
  required bool isMock,
})

// lib：DI 装配层，负责把 signals 值取出来传进去
@module
abstract class NetworkModule {
  @lazySingleton
  Dio dio(UserPreferences preferences, AuthStorage authStorage, NetworkConfig config) =>
      createDio(
        config: config,
        tokenStore: authStorage,
        enableDebugLogging: preferences.enableDebugLogging.value,
        isMock: config.isMock,
      );
}
```

`_registerMockRules()` 的归属也要定：它只依赖 `msw_dio_interceptor`，可一并进包（由 `isMock` 开关控制）。

### 6.6 影响面（实测）

`package:my_app/core/(base/{failure,result,run_catching}|logging|models|config/network_config|theme|data/|ui/empty_widget)`
的引用点约 **71 处**，分布在 `lib/` 与 `test/`。全部是 `package:` 绝对导入（`lib/core/` 内无相对导入），
因此改写是**纯文本替换**，不涉及路径推算。

### 6.7 待确认

- [ ] 6.1 的 `TokenStore` 接口方案
- [ ] 6.2 的「三个 UI 文件留 lib」范围决策

---

## 7. 执行结果与**遗留门禁削弱**（2026-09-22 收尾）

### 7.1 已达成

| 项 | 结果 |
|---|---|
| 包内文件 | 22 个源文件（20 手写 + 2 生成物组），含新增 `token_store.dart` / `dio_factory.dart` |
| `lib/` 手写文件数 | 57 → **39**（−18；原估 −27 偏高，因为 l10n/DI 耦合的文件留在了 lib） |
| 七道门禁 | 全绿（format / boundaries / conventions / docs tree / deps / analyze×3 / test / coverage） |
| 测试 | 344 passed（与基线一致，未减） |
| 边界规则 | 新增规则 5：`app_core` 不得依赖 signals / riverpod / get_it / injectable |
| 扫描根 | `check_boundaries` 与 `check_conventions` 均已覆盖 `packages/app_core/lib` |
| 门禁链路 | CI 与 pre-commit 均已纳入 `packages/`（format / analyze / 生成物新鲜度） |

### 7.2 ⚠️ 遗留问题：包内代码掉出了覆盖率统计

**现象**：`coverage/lcov.info` 全部 42 条 `SF:` 记录都是 `lib\...`，**没有一条 `packages\...`**。

**原因**：根工程跑 `flutter test --coverage` 时，覆盖率报告只按根工程的 `lib/` 归集；
`packages/app_core/lib` 是另一个 package，命中了也不会被记进去。

**后果**（量化）：

| | 基线 | 现在 |
|---|---|---|
| 覆盖率统计的文件数 | 50 | 33 |
| 覆盖率 | 88.9% | 90.0% |
| **未被统计的手写文件** | 6（lib 内从未被加载的） | **26**（lib 6 + **包内 20**） |

其中包含 `auth_interceptor.dart`、`token_refresher.dart`、`dio_factory.dart`——
本轮抽包的**主要动机**就是让这三个安全关键文件被两个栈共用，结果它们现在完全不受覆盖率门禁约束。
测试仍在跑（`test/core/data/network/*` 依然通过），只是**命中无法归属到包内文件**。

**这不是可以忽略的瑕疵**：抽包把边界门禁做强了（规则 5），却把覆盖率门禁削弱了。

### 7.3 三种修法

| 方案 | 内容 | 成本 | 评价 |
|---|---|---|---|
| A. 把纯包测试移进包 | 6 个纯包测试（failure / run_catching / log_redactor / user / network_config / file_storage）迁到 `packages/app_core/test/`，包加 `flutter_test` + `mocktail` dev 依赖；CI 在包内也跑 `flutter test --coverage` | 中 | **推荐**。测试与代码同处一包是本来就该有的结构 |
| B. `check_coverage` 支持多 lcov 合并 | 在 A 之上，让 `tool/check_coverage.dart` 接受多个 lcov 路径并合并统计 | 小 | A 的必要配套 |
| C. 记录为已知缺口，后续处理 | 只写文档，门禁维持现状 | 零 | 等于接受「安全关键代码不受覆盖率保护」 |

**未决**：混合测试（`auth_interceptor_test` / `token_refresh_test` / `interceptor_stack_test`
同时引用包的 `TokenStore` 与 lib 的 `AuthStorage`）怎么归属——它们本质是跨包的集成测试，
可以留在根 `test/`，但那样包内三个网络文件仍不被覆盖。彻底解决需要把它们改写成
「用假 `TokenStore` 测包」+「用真 `AuthStorage` 测 lib」两组。

**建议**：A + B 一起做，作为本任务的直接后继（不要拖成独立大任务，否则遗留会变永久）。
混合测试按上句拆成两组。

### 7.4 本轮顺带修复的两个隐患

1. **`dart fix` 会自动为文档注释里的 `[Class]` 引用补 import**：`token_store.dart` 因此被加了
   `auth_interceptor` / `token_refresher` 的 import，形成 `token_store → auth_interceptor →
   token_store` 的循环依赖。已改为反引号写法并在文件里写明原因，防止回归。
2. **`dart format` 的 tall style 会折行长 import**，触发 `check_boundaries` 的
   「指令没有以 `;` 结束」warning（该 warning 是**设计如此**，用来暴露正则级检查的缺口）。
   包内最长的 import 已控制在不会折行的长度内。

---

## 8. A+B 已落地（2026-09-22）

### 8.1 做了什么

| 步骤 | 内容 |
|---|---|
| A | 6 个纯包测试 + `fake_path_provider.dart` 迁入 `packages/app_core/test/`（`git mv`，保留历史）；包新增 `flutter_test` dev 依赖 |
| A | 根 `test/support/fake_path_provider.dart` 保留**副本**——`storage_demo_view_model_test` 是跨包测试（`FileStorage` 在包、demo ViewModel 在 lib），根侧仍需要它。测试辅助代码无法跨包共享（放进 `lib/` 会污染包的公开 API 并计入覆盖率），接受这一处重复，两份文件互相标注了同步关系 |
| B | `tool/check_coverage.dart` 支持多份 lcov，**逐份独立校验**（不合并——两份路径都是相对各自包根的 `lib/...`，合并会搅乱命名空间；包内低覆盖也不该被 lib/ 稀释） |
| B | pre-commit 与 CI 增加「包内 `flutter test --coverage`」步骤，并把两份 lcov 一起传给门禁 |

### 8.2 结果

| | 根工程 | 包 |
|---|---|---|
| 测试 | 300 passed（原 344，44 个移入包） | 44 passed |
| 覆盖率 | 90.0%（33 文件） | 82.5%（8 文件） |
| 阈值 80% | ✅ | ✅ |

### 8.3 仍然存在的口子（7.3 的「尾巴」，未解决）

包内 20 个手写文件里**只有 8 个进了分母**。`data/network/*`（认证拦截器、刷新器、Dio 工厂、
TokenStore）、`data/database/*`、`theme/*`、`ui/empty_widget.dart` 共约 11 个文件
**仍在覆盖率统计之外**——它们没有对应的包内测试，而「从未被加载的文件不进分母」这条
已知机制会静默放过它们。

所以包内那个 82.5% **不代表包的覆盖率，只代表被加载的 8 个文件的覆盖率**。

**下一步**：已开任务 **`09-22-app-core-coverage`** 跟踪——把
`test/core/data/network/` 的三个测试改成纯包测试（用假 `TokenStore` 替代 lib 的
`AuthStorage`），补 `theme` 与 `ui` 的包内测试，并给 `check_coverage` 加差集检查
（拿文件清单减 lcov 的 `SF:` 集合）。做完之后才有资格说「包的覆盖率」。
