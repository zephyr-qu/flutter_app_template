# README 按读者分层：移出「数据流」与「测试与门禁」两节

## Goal

README 只承担「人」要读的东西：这是什么、怎么跑起来、目录长什么样、去哪找细节。
实现链路与门禁细节归 `.trellis/spec/`（AI 读的那一份），避免同一件事在 README 和 spec 各存一份。

## 判定标准

一个章节留在 README 的条件：**读者是「评估/派生这个脚手架的人」，且内容不是仓库里另一份 canonical 文档的复制品**。
两条都不满足 → 移出。

## Requirements

### 1. 移出「数据流」整节

原内容：`Page (ConsumerWidget) → Notifier → Repository → Service → API (Retrofit)` 的 ASCII 图，
加一句「跨 feature 只共享 `data/` 与 `core/` 暴露的 provider，不用事件总线」。

移出理由（第二真源）：

- 图本身在 spec 里有等价且更完整的版本 —— `.trellis/spec/guides/cross-layer-thinking-guide.md` 开头的
  `Page → Notifier → Repository (接口) → Service → Api (Retrofit) → Dio ↓ DAO / Drift（本地缓存）`。
- 「跨 feature 只共享 `data/`」是门禁规则 `cross_feature_only_data`，权威在
  `.trellis/spec/cross-cutting.md`；`.trellis/spec/frontend/directory-structure.md` §5 另有展开。
- README `## 包含什么` 已用自然语言覆盖同一批卖点（状态/网络/缓存/错误模型），ASCII 图属于第三遍。

**但一句话的架构约束要留** —— 它是脚手架的形状声明，不是实现细节。并入「目录结构」末句：

> feature 内三层 `page/` → `logic/` → `data/`；`core/` 不得引用 `features/` / `app/`，跨 feature 只共享 `data/` 与 `core/` 暴露的 provider。完整树与职责见 directory-structure.md。

### 2. 移出「测试与门禁」整节

原两行的独有信息只有「`pre-commit` 与 CI 都跑它」+ 一条 spec 链接；
`just test` / `just e2e` / `just verify` 都已在「常用命令」表里。

处理：删节，在常用命令表下留一行脚注：

> `just verify` 就是 `pre-commit` 与 CI 跑的那套门禁（首个失败即停）；规则细节与测试基建见 cross-cutting.md。

### 3. 不自造 spec 内容

两节的 canonical 版本都已存在，**不往 spec 里补任何东西**（补就是制造第二份真源，方向反了）。

## Acceptance Criteria

- [x] `README.md` 不再有 `## 数据流` / `## 测试与门禁` 两个标题
- [x] 「跨 feature 只共享 `data/`」这条约束在 README 仍可读到（并入目录结构末句）
- [x] 指向 `cross-cutting.md` 的门禁入口在 README 仍可读到（表下脚注）
- [x] 无入站锚点失效：全仓只有 `#环境与构建` 被 `docs/` 引用，未受影响
- [x] 未改动任何代码或 spec 正文
- [x] README 行数 101 → 88

## 验证

- 凭证：改动纯 Markdown，未跑 `just verify`（format / analyze×2 / 插件规则测试 / flutter test 覆盖不到文档，按 `AGENTS.md` 不跑不相关门禁）。
- 链接检查：逐个确认脚注与末句指向的 `.trellis/spec/cross-cutting.md`、`.trellis/spec/frontend/directory-structure.md` 存在。
- 结构检查：回读改动区间，确认无残留空节、无连续空行、`## 其它` 与 `## 许可证` 结构完好。
- 全仓检索 `数据流` / `README.*#` 确认无指向被删章节的引用。

## 残余风险

无功能风险。唯一判断性取舍：把「数据流图」当架构速览保留 VS 按标准移出 —— 本次选后者（一致性优先）；
若后续认为脚手架需要一张首页大图，应作为**刻意保留的速览**重新加入，并在本文件记录该决定，而不是让 README 与 spec 长期各有一份。
