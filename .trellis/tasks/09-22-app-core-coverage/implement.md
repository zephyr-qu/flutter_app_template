# 执行计划：补齐 app_core 的覆盖率分母

> 环境：Windows + PowerShell。`dart` / `flutter` 不在 PATH 上，每条命令前先
> `$env:PATH="D:\scoop\apps\flutter\current\bin;$env:PATH"`。

## 0. 前置验证（先做，失败就改走 design 6 的降级方案）

```powershell
cd packages/app_core
flutter test --coverage        # 确认包内测试与 sqlite3 原生库在本机可用
```

- [ ] 包内测试全绿
- [ ] 若 `flutter test` 在包内失败于 `sqlite3` / `drift` 相关，停下来：说明
      `data/database/*` 无法在包内测，按 design 6 第一行降级（数据库测试留根 + 豁免）

---

## 1. `tool/check_coverage.dart`：加差集检查

- [ ] `--src=<根>` 解析（可重复）+ 与位置参数 lcov 按序配对；个数不匹配 → stderr + 退出码 1
- [ ] 纯函数 `coversPath(repoPath, sfPath)`（边界感知后缀匹配）
- [ ] 纯函数 `missingFiles({handwritten, covered})` → 未被该 lcov 覆盖的仓库相对路径
- [ ] 纯函数 `nonBlankLines(content)` → 代理分母
- [ ] `const Map<String, String> loadingExemptions`（每条带理由）+ 过期豁免 warning
- [ ] `main()`：把缺失文件按 `hit=0 / found=非空行数` 并入统计后再算比例；报告口径写进
      输出文案（让人一眼看出「哪些文件是按 0 计进去的」）
- [ ] `check_coverage.dart` 头注释更新：`--src` 用法、为什么计入分母、豁免怎么加

**纯函数优先**：FS 读取只发生在 `main()`，其余逻辑都能用 `test()` 覆盖。

---

## 2. 迁移网络层测试进包

- [ ] 新建 `packages/app_core/test/support/scripted_http_adapter.dart`（从
      `test/support/scripted_http_adapter.dart` 复制 + 头注释标注同步关系；
      同时给根侧那份补一句反向标注）
- [ ] 新建 `packages/app_core/test/support/fake_token_store.dart`：
      内存 `TokenStore` 实现 + `clearAuthCount` / `saveTokensCount` / `clearAuthError`
- [ ] 新建 `packages/app_core/test/support/fake_token_refresher.dart`：
      `implements TokenRefresher`，`refreshCount` + 可脚本化的返回值
- [ ] `git mv test/core/data/network/auth_interceptor_test.dart packages/app_core/test/data/network/auth_interceptor_test.dart`
      并改写成 fake 驱动
- [ ] `git mv test/core/data/network/token_refresh_test.dart packages/app_core/test/data/network/token_refresh_test.dart`
      并把 `AuthStorage` 换成 `FakeTokenStore`（`TokenRefresher` 用真的）
- [ ] `test/core/data/network/interceptor_stack_test.dart` 保持不动
- [ ] 包内 `flutter analyze` + `flutter test` 通过

**验证点：迁移不得改变断言**。断言条目数只能增（fake 能表达的状态比 mock 多），
不能少 —— 少了就是悄悄降级了安全关键代码的测试强度。

---

## 3. 新增包内测试

- [ ] `test/data/network/dio_factory_test.dart`（4 条：401 不被 Retry 吞 / 5xx 重试 /
      `isMock=false` 无 mock 拦截器 / debug 日志开关）
- [ ] `test/data/database/app_database_test.dart`
- [ ] `test/theme/app_theme_test.dart`
- [ ] `test/ui/empty_widget_test.dart`
- [ ] `test/models/token_set_test.dart`

---

## 4. 根侧审计

- [ ] 核对 `test/core/data/storage/auth_storage_test.dart` 覆盖 `TokenStore` 全部 6 个成员
      （`ready` / `getAccessToken` / `getRefreshToken` / `isAccessTokenExpiring` /
      `saveTokens` / `clearAuth`）；缺哪个补哪个，全有则在 PR 说明里记一句「已审计」

---

## 5. 跑一遍拿真实数字，再定豁免与阈值

```powershell
flutter test --coverage
cd packages/app_core; flutter test --coverage; cd ../..
dart run tool/check_coverage.dart coverage/lcov.info packages/app_core/coverage/lcov.info --src=lib --src=packages/app_core/lib
```

- [ ] 记录两边的「文件名 / 分母 / 比例」到 task 的 notes
- [ ] 差集里**合法**的（抽象声明、const-only、入口）→ 加进 `loadingExemptions` 并写理由
- [ ] 差集里**不合法**的（本该测但没测）→ 回到第 3 步补测试，不许豁免
- [ ] 包分母 ≈ 20 - 豁免数；两边比例 ≥ 80%
- [ ] 若包比例 < 80%：补测试，**不改阈值**

---

## 6. 工具自身测试

- [ ] `test/tool/check_coverage_test.dart` 增补：`coversPath` 后缀边界（
      `lib/a.dart` 不匹配 `xlib/a.dart`）、`missingFiles` 差集、`nonBlankLines`、
      豁免过滤、过期豁免
- [ ] `flutter test test/tool/check_coverage_test.dart` 通过

---

## 7. 门禁接线

- [ ] `.githooks/pre-commit` 覆盖率步骤加 `--src=lib --src=packages/app_core/lib`
- [ ] `.github/workflows/ci.yml` 的 `Check coverage threshold` 同步（保留 `--min=80`）

---

## 8. 全量验证（提交前）

```powershell
dart format --output=none --set-exit-if-changed lib test tool packages
dart run tool/check_boundaries.dart
dart run tool/check_conventions.dart
dart run tool/check_readme_tree.dart
dart run dependency_validator
flutter analyze lib/ test/
dart analyze tool/
dart analyze packages/
flutter test --coverage
cd packages/app_core; flutter test --coverage; cd ../..
dart run tool/check_coverage.dart coverage/lcov.info packages/app_core/coverage/lcov.info --src=lib --src=packages/app_core/lib
```

- [ ] 全绿（包括 `dependency_validator`：包内新增测试不得引入未声明依赖）
- [ ] `flutter analyze test/` 对**迁移后**的根 `test/` 也通过

---

## 9. 文档与 spec 更新（Phase 3.3）

- [ ] `.trellis/spec/cross-cutting.md`「覆盖率门禁」一节：把「要补上这个口子，得做差集，
      目前没做」改写为已落地的机制 + 豁免口径
- [ ] `.trellis/spec/backend/network-guidelines.md`：更新测试文件位置（网络测试现在在
      `packages/app_core/test/data/network/`）、以及开头「网络能力收敛在
      `lib/core/data/network/` 四个文件」这句已经过时的描述
- [ ] PRD 的 Acceptance Criteria 按实测结果勾选，并把「`token_store` 出现在包 lcov」
      改写为「出现**或**已豁免（附理由）」

---

## 回滚点

| 位置 | 回滚方式 |
|---|---|
| 第 2 步（迁移）出错 | `git mv` 反向搬回，根侧测试未改断言，可原地复活 |
| 第 5 步发现包比例远低于 80% | 不调阈值：先补测试；补不动则把缺口写进 notes 并向用户报告，不擅自放宽口径 |
| 第 7 步门禁接线导致提交被卡 | 门禁改动独立成 commit，可单独 revert |
