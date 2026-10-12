# 落地报告中的三个小项

## Goal

把父任务报告里判定为「可原样移植」的三项小增量落到本地文档。本任务**不开新方向**，
只兑现 `report.md` 已经查证过的三条。

## Requirements

### ① `report.md` §4.2 —— `git grep` 洞见（栈无关，本地确实没有）

`guides/index.md` 的「改任何值之前先搜」只给了 `grep -r "value_to_change" .`，没有点出
**ripgrep 系工具默认跳过点号目录**。已实测：`rg -l "prune.dart" .` 得 5 个文件、漏掉
`.trellis/`；加 `--hidden` 或换 `git grep` 得 8 个。

### ② `report.md` §4.3 —— 路由两条缺口

本地无路由专篇，约定散在 `directory-structure.md` 与 `hook-guidelines.md`；两条**完全缺失**：

- 根初始路由是 `AppRouter.routes` 的第一项（`/splash`），冷启动落点由 `SplashPage` 的
  `replaceRoute` 分流决定，登录态在跳转那一刻实时读。
- **改动底部导航标签必须同步 `test/routing/main_shell_test.dart`**（含宽屏 `NavigationRail` 分支），
  这条不在任何门禁的拦截范围内。

### ③ `report.md` §4.4 —— `cross-cutting.md` 两处

- analyzer 的退出码表（info 0 / warning 2 / error 3；`--fatal-infos` 时 info 变 1）。
- 把「有意不设的门禁」集中成一节 —— `AGENTS.md` 本来就写着「有意不设门禁的项见
  `cross-cutting.md`」，但那里其实是散落的，这节兑现那句话。

## Acceptance Criteria

- [x] `guides/index.md` 的搜索节写明「用 `git grep`，别只用 Grep / ripgrep」及其原因
- [x] 新增 `.trellis/spec/ui/routing.md`，内容与 `lib/app/routing/**` 的真实实现一致
- [x] 根 `index.md` 的「开工前必读」与索引表都收录 `ui/routing.md`（spec 共 20 篇，索引无遗漏）
- [x] `cross-cutting.md` 有退出码条目，以及 `## 有意不设的项` 一节
- [x] 新增的章节引用**都指向真实存在的标题**（`「应用层」`、`「登出语义」`、`「不存在的东西」`
      落在 `.cursor/rules/project-conventions.mdc:70`，不是 `directory-structure.md`）
- [x] `dart run tool/check_doc_links.dart` 全绿（139 个文件）
- [x] `just verify` 全绿

## Notes

- 撰写 `ui/routing.md` 时**不照抄**兄弟分支的同名文件：那份是 Riverpod + 无认证口径
  （`routerProvider` / `keepAlive` / 深链优先判断 `defaultRouteName`），与本地不符。
  本地是 `AppRouter` 构造注入 `AuthStorage` + `AutoRouteGuard` 实时读 + `AuthReevaluateListenable` 桥接。
- 顺手做的一处：`guides/index.md` 搜索节里两行英文残留中文化（该节是本次唯一动过的正文，
  混排会看着像没做完）。`data/*.md` 的英文正文依旧不翻 —— 那是 `spec-naming-convergence` 的既定决定。
