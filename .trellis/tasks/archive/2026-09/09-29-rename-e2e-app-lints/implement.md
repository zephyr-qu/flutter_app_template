# implement — 执行顺序、验证命令、回滚点

> 全程不 `task.py start` 之前不动代码。每步的产出与判据写在下面，照序做。

## 0. 复现红（先留证据，再改任何代码）

```bash
SCAFFOLD_E2E=1 flutter test test/tool/init_project_test.dart
```

判据：`30 tests passed, 1 failed`（或等价），failure 落在「改名后 analyze 失败」那条，
`reason` 里带 error 清单；确认 error 集中在 `packages/app_lints/test/rules_test.dart`。
把关键输出贴进 `prd.md` 的 Notes 或本文件末尾。

⚠ Windows 会真复制整个仓库 + 两次 pub get + analyze，慢（数分钟）；不要为了快而跳过复制。

## 1. 改 E2E 的 bootstrap

文件：`test/tool/init_project_test.dart`

- [ ] 新增/改造一个 helper，语义 = `just deps` 两步：temp 根 `flutter pub get`，
      再 `temp/packages/app_lints` 的 `dart pub get`
- [ ] 沿用「先 `--offline` 后联网」与 `runInShell: Platform.isWindows`（子包同样）
- [ ] 注释（≤10 行）写清：为什么必须给子包单独跑一次（它有自己的 package config、
      它是 `analysis_options.yaml` 的路径插件、本地 `just deps` 就是这么做的）
- [ ] 不复制 `.dart_tool`、不缩小 analyze 范围

**自查点**：`_pubGet(flutter, temp)` 的旧调用点全部收敛到新 helper，不留两套写法。

## 2. 转绿

```bash
SCAFFOLD_E2E=1 flutter test test/tool/init_project_test.dart
```

判据：全绿且 `reason` 里不再出现 error 清单。

## 3. 反向验证（AC3，必做 —— 这步验证的是「防线还在」）

- [ ] 临时改 `tool/init_project.dart`，让它**漏掉** `packages/app_lints/lib/src/paths.dart` 的
      `selfPackagePrefix`（或整段跳过 `package:<旧名>/` 替换）
- [ ] 重跑第 2 步的命令 → **必须失败**
- [ ] `git checkout -- tool/init_project.dart` 还原，`git diff --stat` 确认工作区干净
- [ ] 若它**没**失败：停下来，说明补 bootstrap 把 E2E 变成永远绿了，回到第 1 步查断言

## 4. 全门禁

```bash
just verify
```

（`fmt-check` / 两组 `dart analyze --fatal-infos` / `deps` 检查 / 插件规则测试 / 目录树 / 全部测试）

## 5. 文档（AC5，按需）

- [ ] `.trellis/spec/guides/rename-checklist.md`：在 `packages/app_lints` 那节补一句
      「E2E 的 bootstrap 必须与 `just deps` 同步，含子包那一次 `dart pub get`」
- [ ] 若结论推翻了 `cross-cutting.md` 里对 E2E 的描述，同步改它

## 6. 交付与 CI 验证（AC2）

- [ ] 分支：`fix/rename-e2e-app-lints`（base `master`）
- [ ] 提交信息：`test(tool): rename E2E 补 app_lints 的 pub get`（型如仓库既有风格）
- [ ] 开 PR → 等 `analyze` job，**必须看到** `Regression test (rename scaffold in temp dir)`
      这一步是绿的（这是 AC2，也是本任务唯一无法本地替代的验证）
- [ ] 顺手确认同一 run 里 `integration-test` 不再被 `analyze` 拖成 skipped

## 回滚点

| 位置 | 回滚动作 |
| --- | --- |
| 第 1 步后发现问题 | 单文件 `git checkout -- test/tool/init_project_test.dart` |
| 第 5 步文档改错 | `git checkout -- .trellis/spec/...` |
| PR 已开、CI 仍红 | 保留分支继续查；master 不受影响（改动只在分支上） |

## 完成判据（全部满足才算完）

AC1–AC5 逐条打勾；AC2 的 CI 绿必须是**亲眼看到的 run 结论**，不接受「本地绿所以应该没问题」。
