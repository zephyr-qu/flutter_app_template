# 技术设计：补齐 app_core 的覆盖率分母

## 1. 实测基线（2026-09-22，非估算）

**根工程**：`lib/` 手写文件 39，lcov 里 38 → **7 个未进分母**：

```
lib/main.dart                                  一行转发到 bootstrap()
lib/bootstrap.dart                             只在真机 / integration_test 里执行
lib/app/app.dart                               根组件，只被 runApp 使用
lib/features/article/data/article_api.dart     Retrofit 抽象接口 + redirecting factory
lib/features/article/data/article_repository.dart   纯抽象类
lib/features/auth/data/auth_api.dart           同 article_api
lib/features/auth/data/auth_repository.dart    同上
```

前四个是**结构上不可能有可执行行**的声明（抽象类 / redirecting factory），后三个只被集成测试加载 —— 而 `flutter test --coverage` 不含 `integration_test/`。

**包**：20 手写文件，lcov 里 8 → **12 个未进分母**：

```
data/database/app_database.dart
data/database/tables/db_articles.dart
data/network/auth_extra_keys.dart
data/network/auth_interceptor.dart
data/network/dio_factory.dart
data/network/token_refresher.dart
data/network/token_store.dart
models/token_set.dart
theme/app_color_scheme.dart
theme/app_theme.dart
theme/app_theme_extension.dart
ui/empty_widget.dart
```

> PRD 写的「约 11」漏了 `models/token_set.dart`：它只在根侧 `token_refresh_test` 里被加载，
> 而根 lcov 不归集 `packages/` 路径。这也说明「靠根测试顺便覆盖包」这条路走不通。

---

## 2. 差集检查（本任务的核心）

### 2.1 CLI 形态

新增可重复的 `--src=<扫描根>`，与位置参数 lcov **按序配对**：

```bash
dart run tool/check_coverage.dart \
  coverage/lcov.info packages/app_core/coverage/lcov.info \
  --src=lib --src=packages/app_core/lib \
  --min=80
```

- `--src` 个数必须等于 lcov 个数；`0` 个 = 跳过差集检查（保持脚本可单独用于临时排查）
- 个数不匹配 → stderr 报错 + 退出码 1（静默按位置错配是这里最坏的失败形态）
- 扫描根复用 `check_boundaries.dart` 的 `dartFiles()`：它已经剔除了生成物，与
  `handwrittenOnly()` 是同一口径，不再造第二套「什么算手写文件」的判定

### 2.2 路径匹配：边界感知的后缀

lcov 的 `SF:` 是**相对包根**的（`lib/data/network/token_store.dart`），扫描根是仓库相对路径。
匹配用一个纯函数：

```dart
bool coversPath(String repoPath, String sfPath) =>
    repoPath == sfPath || repoPath.endsWith('/$sfPath');
```

不需要额外传「这个包的 lib 前缀」，也不会把 `lib/base/failure.dart` 和
`packages/app_core/lib/base/failure.dart` 混淆 —— 配对是**逐份独立**的，包 lcov 只跟
`packages/app_core/lib` 这一个扫描根比。

### 2.3 未加载文件的口径：计入分母

| 方案 | 做法 | 评价 |
|---|---|---|
| 只报告 | 打印清单，不进分母 | 半成品：新增一个没测的大文件照样不影响阈值 |
| **计入分母（选中）** | 按 `hit=0 / found=非空行数` 加进统计 | 数字立刻反映真实；口径刻意从严 |
| 差集非空即失败 | 退出码 1 | 把「是文件就该被加载」当公理，抽象声明类文件会永远挂 |

**选中「计入分母」**：没有豁免时门禁自动变严（新增未测文件 → 分母涨、比例跌），
而豁免清单是唯一的、必须写理由的逃生口。

未加载文件没有 lcov 行数信息，`found` 取**非空行数**作代理（不是精确的可执行行数）。
代理刻意从严：注释与空行不计，但 `import` / `}` 这类不可执行行会算进去。

### 2.4 豁免清单（唯一的逃生口）

`tool/check_coverage.dart` 里一个 const map，**每条必须带理由**：

```dart
const Map<String, String> loadingExemptions = {
  'lib/main.dart': '入口转发（main → bootstrap），只被集成测试加载',
  // ...
};
```

- 缺失但已豁免 → 从差集里剔除，不进分母
- **过期豁免**（已不再缺失）→ 打 warning，不影响退出码。语义与
  `check_boundaries.dart` 的「疑似漏检」warning 一致：提示而非拦截

预期豁免（实现时以实测为准）：

| 路径 | 理由 |
|---|---|
| `lib/main.dart` | 一行转发到 `bootstrap()` |
| `lib/bootstrap.dart` | 只在真机 / `integration_test` 里执行 |
| `lib/app/app.dart` | 根组件，只被 `runApp` 使用 |
| `lib/features/article/data/article_api.dart` | Retrofit 抽象接口 + redirecting factory，无可执行行 |
| `lib/features/article/data/article_repository.dart` | 纯抽象类 |
| `lib/features/auth/data/auth_api.dart` | 同上 |
| `lib/features/auth/data/auth_repository.dart` | 同上 |
| `packages/app_core/lib/data/network/token_store.dart` | 纯 `abstract interface`（先确认它是否真的不进 lcov） |
| `packages/app_core/lib/data/network/auth_extra_keys.dart` | 只有两个 const 字符串 |

---

## 3. 测试迁移与新增

### 3.1 迁移（根 → 包）

| 根 | 包 | 改法 |
|---|---|---|
| `test/core/data/network/auth_interceptor_test.dart` | `packages/app_core/test/data/network/auth_interceptor_test.dart` | `MockAuthStorage` → 手写 `FakeTokenStore`；`MockTokenRefresher` → 手写 `FakeTokenRefresher`；删掉 mocktail 与 lib 侧 import |
| `test/core/data/network/token_refresh_test.dart` | `packages/app_core/test/data/network/token_refresh_test.dart` | 同上；`AuthStorage` → `FakeTokenStore`，真实 `TokenRefresher` + 真实 Dio 管道不变 |
| — | `packages/app_core/test/support/scripted_http_adapter.dart` | 从 `test/support/` 复制（只依赖 dio）。两份互相标注同步关系 —— 与 `fake_path_provider.dart` 是同一先例 |

`interceptor_stack_test.dart` **留在根、不动**：它测的就是 lib 侧的 `NetworkModule.dio()`
装配，本来就没有「直测 createDio」的部分，不需要拆分。

### 3.2 为什么用手写 fake 而不是 mocktail

包内没有 `mocktail`（为 3 个测试引入一个 mock 框架不划算）。两个 fake 各只有一个成员，
手写比 mock 更直白，调用次数收敛成可读字段（`clearAuthCount` / `refreshCount`），
还能表达 mock 表达不了的状态（如「令牌已过期但还没刷」）。

### 3.3 新增包内测试

| 新测试 | 覆盖 | 要点 |
|---|---|---|
| `test/data/network/dio_factory_test.dart` | `dio_factory.dart` | 拦截器顺序语义：401 重放不被 Retry 吞、5xx 走重试、`isMock=false` 不注册 mock、debug 日志开关 |
| `test/data/database/app_database_test.dart` | `app_database.dart`、`db_articles.dart` | `AppDatabase.connect(NativeDatabase.memory())` 建表 + 行类读写往返；`schemaVersion == 1` |
| `test/theme/app_theme_test.dart` | `theme/*`（3） | 亮/暗主题组装、品牌色生效、`AppThemeExtension.base` 在 extensions 里、`onSurfaceVariant` 覆盖、**不指定字体家族**、`copyWith` / `lerp` |
| `test/ui/empty_widget_test.dart` | `ui/empty_widget.dart` | 文案与默认图标；`actionLabel` + `onAction` 齐备才出按钮；点击回调 |
| `test/models/token_set_test.dart` | `models/token_set.dart` | `fromApi` / `toJson` / `fromJson` / `withExpiresIn` / 过期判定 |

### 3.4 根侧保留与审计

- `test/core/data/network/interceptor_stack_test.dart`：不动
- `test/core/data/storage/auth_storage_test.dart`：逐成员审计 `TokenStore`
  的 6 个成员（`ready` / `getAccessToken` / `getRefreshToken` / `isAccessTokenExpiring` /
  `saveTokens` / `clearAuth`）—— 当前已全覆盖，**预期不改**

---

## 4. 门禁接线

pre-commit 与 CI 的覆盖率步骤各加 `--src=lib --src=packages/app_core/lib`。
两处命令保持字面一致（CI 多一个显式 `--min=80`）。

---

## 5. 阈值决策（先看数字，不先定数）

实现完 3.3 后跑一次拿真实数字：

- 包分母 8 → 约 18（20 减去结构性豁免）
- 根分母保持 38（7 个缺失都进豁免）

**80% 阈值不动**。若实测低于 80%，优先补测试；只有确实补不动的才考虑调阈值，
且必须在 PRD 留下「为什么」——调阈值以迁就实现是本任务要消灭的那种行为。

---

## 6. 风险与处置

| 风险 | 处置 |
|---|---|
| `sqlite3` 原生库在包目录里不可用（drift 的 build hook 不覆盖子包） | 先在包内跑一次 `flutter test` 验证；不可用就把数据库测试放回根，并把 `data/database/*` 列入豁免（理由写进 spec） |
| 纯接口 / 纯 const 文件根本不进 lcov → AC 的「`token_store` 出现在包 lcov」不成立 | 用豁免清单兜住；AC 按「出现**或**已豁免」判定，并把这一条写进 spec |
| 未加载文件按代理行数计入后，包覆盖率先掉到 80% 以下 | 属**预期**：先看数字，再决定补测试还是加豁免。不知道数字就调阈值才是真风险 |
| 迁移后根侧少两条测试文件 | 不影响根分母：那两个文件本来就没进过根 lcov 的 `packages/` 记录 |

---

## 7. 明确不做

- 不给覆盖率脚本加 `--strict` 开关（用不到就别留逃生口，与 `check_conventions` 的同款判断一致）
- 不合并两份 lcov（口径不变：逐份独立校验）
- 不把 mocktail 引入包内
- 不改阈值与豁免口径去迁就当前数字
- 不为了「让分母好看」给 `bootstrap.dart` / `main.dart` 写假测试
