<!-- TRELLIS:START -->
# Trellis Instructions

These instructions are for AI assistants working in this project.

This project is managed by Trellis. The working knowledge you need lives under `.trellis/`:

- `.trellis/workflow.md` — development phases, when to create tasks, skill routing
- `.trellis/spec/` — package- and layer-scoped coding guidelines (read before writing code in a given layer)
- `.trellis/workspace/` — per-developer journals and session traces
- `.trellis/tasks/` — active and archived tasks (PRDs, research, jsonl context)

If a Trellis command is available on your platform (e.g. `/trellis:finish-work`, `/trellis:continue`), prefer it over manual steps. Not every platform exposes every command.

If you're using Codex or another agent-capable tool, additional project-scoped helpers may live in:
- `.agents/skills/` — reusable Trellis skills
- `.codex/agents/` — optional custom subagents

Managed by Trellis. Edits outside this block are preserved; edits inside may be overwritten by a future `trellis update`.

<!-- TRELLIS:END -->

<!-- TRELLIS:START/END 之间由 `trellis update` 托管：块内与上游模板保持逐字一致，
     这样 update 只会重写同一份内容。项目自己的事实一律写在本行以下。 -->

# 项目契约

## 这是什么

个人 Flutter 脚手架 / 模板（**不是**生产应用），面向中小型 App：FSD 目录、Signals + ViewModel
状态管理、`auto_route`、`injectable` + GetIt、MD3、Retrofit + Dio。文案写中文、标识符英文、注释中文。
`.agents/skills/` 是从 GitHub 装来的第三方资产（来源见 `skills-lock.json`），不由 Trellis 托管。

## 从脚手架开新项目

`dart run tool/init_project.dart`（即 `just init`）；加 `--yes --name=<新名> --application-id=<id>`
可免交互。脚本语义是**全有或全无**，改名落点与手工坑见
[`rename-checklist.md`](.trellis/spec/guides/rename-checklist.md)；改完 `just codegen` 再 `just verify`。

删示例模块（可选，看懂结构后再做）：`dart run tool/prune_examples.dart --yes --modules=article,demo`
清掉 `article` / `demo` 的全部引用点，之后自己重跑 codegen 与 verify。`auth` 不参与（它是基础设施，
不是示例）。见 [`template-pruning.md`](docs/template-pruning.md)。

## 开工前必读

门禁、codegen、环境配置与各层细则的入口是 [`.trellis/spec/index.md`](.trellis/spec/index.md)——它按
「要动什么」列了该先读哪份，是唯一入口。**写之前先读对应索引**，别凭印象写。

## 改完必跑

`just verify` —— 它跑什么以根 `justfile` 的 `verify` 为准（`just --list` 列出全部 recipe），这里不逐项
复述，免得新增门禁时漂移；每道门的语义、阈值与「有意不设门禁」的项见
[`cross-cutting.md`](.trellis/spec/cross-cutting.md)。pre-commit hook 跑的就是它：
`git config core.hooksPath .githooks` 激活，`git commit --no-verify` 紧急跳过。

**生成物不入库**：改了注解（`@freezed` / `@RoutePage` / `@injectable` / Drift 表）或增删文件后，先
`just codegen` 再验证（clone 后同理，否则 analyze / test 会因为缺 `part` 而失败）。不要手改生成物，
也不要 `git add -f` 把生成物加回版本库。

## 照抄对象：`lib/features/article/`

新增 feature 时**先读**它，按它的形状写：`data/` 覆盖 Retrofit API + `@DriftAccessor` DAO + Service
（`Result` + 错误映射 + 缓存旁路）+ Repository 抽象与 DI 装配 + `@freezed` 模型；`logic/` 与 `page/`
是 signals ViewModel 与页面的标准写法；`test/features/article/**` 是对应测试。

## 禁止模式速查

`packages/app_lints` 插件把「谁能依赖谁」与代码形态固化成规则，`just analyze` 会拦下违规。完整清单、判据
与放行条件见 [`cross-cutting.md`](.trellis/spec/cross-cutting.md)「架构边界与代码形态」——这里不枚举，枚举会漂。

