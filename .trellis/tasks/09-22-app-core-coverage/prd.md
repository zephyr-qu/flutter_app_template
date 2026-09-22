# 补齐 app_core 的覆盖率分母

## 背景（问题有多真）

`09-22-extract-app-core` 把 20 个手写文件抽进了 `packages/app_core`，代价是覆盖率门禁出现了盲区：

1. **根 lcov 不含包内文件** —— 根工程跑 `flutter test --coverage` 时包内文件的命中不会被归集
   （根 lcov 里一条 `packages/` 记录都没有）。已用「包内单独采集 + 两份 lcov 逐份校验」解决。
2. **包内分母严重不完整** ← 本任务

第 2 点被那条**已知机制**放大了：`check_coverage` 只统计「lcov 里出现的文件」，
从未被任何测试加载的文件不进分母。包内实测：

| | 数量 |
|---|---|
| 包内手写文件 | 20 |
| 进了分母的 | **8** |
| **仍在统计之外的** | **约 11**：`data/network/*`（auth_extra_keys / auth_interceptor / token_refresher / token_store / dio_factory）、`data/database/*`（app_database / db_articles）、`theme/*`（3）、`ui/empty_widget.dart` |

所以包内那个 **82.5% 不代表包的覆盖率**，只代表被加载的 8 个文件。

**最讽刺的一点**：抽包的主要动机就是让 `auth_interceptor` / `token_refresher` /
`dio_factory` 被两个栈共用，而这三个安全关键文件恰恰是现在完全不受覆盖率门禁约束的。

## Requirements

### 1. 网络层测试转纯包测试

`test/core/data/network/` 的三个测试同时引用包的 `TokenStore` 与 lib 的 `AuthStorage`，
属跨包混合测试。改成用**假 `TokenStore`** 驱动，迁入 `packages/app_core/test/data/network/`：

- `auth_interceptor_test.dart`
- `token_refresh_test.dart`
- `interceptor_stack_test.dart`（测 `createDio` 的部分进包；测 lib 侧 `NetworkModule`
  装配的部分留在根）

### 2. 保留 lib 侧适配层测试

`AuthStorage implements TokenStore` 是 lib 的适配层，需要独立的测试覆盖
「TokenStore 接口 ↔ SharedPreferences / FlutterSecureStorage」这层映射
（`test/core/data/storage/auth_storage_test.dart` 已存在，确认它覆盖了接口暴露的全部成员）。

### 3. 补 theme / ui 的包内测试

`theme/`（色板 / ThemeData 组装 / 设计 token）与 `ui/empty_widget.dart` 目前两侧都没有测试。

### 4. 给 check_coverage 补差集检查（**本任务的核心价值**）

拿扫描根下的手写文件清单减去 lcov 的 `SF:` 集合，把差集报出来。两种处理：

- 差集里的文件按 0% 计入分母（口径变严，可能立刻低于阈值）
- 或只报告，并给 `--strict` 开关让它逐项失败

**先实现「报告 + 计入分母」**，跑一遍拿到真实数字，再决定阈值。

> 不做这一条，本任务只是把当下的口子堵一次；做了，以后不会随包增长继续静默扩大。

### 5. 落地为硬门禁

差集检查接入 pre-commit 与 CI（与现有覆盖率门禁同一处）。目标状态：
**任何新增的包内 / lib 内手写文件如果没被任何测试加载，提交就会被拦下。**

## Acceptance Criteria

- [ ] `data/network/` 的 4 个手写文件（auth_extra_keys / auth_interceptor / token_refresher / token_store）出现在包 lcov 里
- [ ] `dio_factory.dart` 出现在包 lcov 里
- [ ] `theme/*`（3）与 `ui/empty_widget.dart` 出现在包 lcov 里
- [ ] `check_coverage` 的差集检查已实现，并被 pre-commit + CI 执行
- [ ] 包覆盖率的分母 ≈ 20（即全部手写文件），数字 ≥ 80%
- [ ] 根工程与包的门禁全绿

## Notes

- 依赖 `09-22-extract-app-core` **已完成**（包与 `TokenStore` 接口均已就位，见其 design.md 8.3）
- 混合测试的归属判据：**测试目标在包里 → 用假对象让它成为纯包测试；测试目标是 lib 的装配/适配层 → 留根**
- 差集检查落地后会立刻暴露「根 `lib/` 里 6 个从未被加载的手写文件」这个**既有**问题
  （基线时就存在，见 `cross-cutting.md` 覆盖率一节的说明）——先确认这 6 个是哪些，
  再决定是补测试还是加显式豁免
