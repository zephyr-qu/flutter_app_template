# 定 `.agents/skills` 的入库策略并清掉第三方本机痕迹

## Goal

`.agents/skills/**` 现在是「内容入库了，可还原性不在仓库里」的两头不靠状态。本任务给它一个
自洽的定位，并清掉公开仓库不该带的第三方本机路径。

## 已核实的事实

| # | 事实 | 证据 |
|---|---|---|
| ① | `.agents/skills/**` 有 **136 个已跟踪文件**，是全仓库最大的目录（`lib/core` 29、`test/core` 23、`.trellis/spec` 20） | `git ls-files .agents \| wc -l` |
| ② | 内容是从 GitHub 装来的 27 个第三方 skill：`dart-lang/skills` 12 条、`flutter/skills` 10 条、`rodydavis/signals.dart` 6 条 | `skills-lock.json` 的 `source` 分布 |
| ③ | `skills-lock.json`（173 行，根目录）记录了每个 skill 的 `source` / `sourceType` / `skillPath` / `computedHash` | 同文件 |
| ④ | **仓库里没有任何东西读它**：`justfile` 无 skills 命令，无脚本、无 CI 引用 | `git grep -ln "skills-lock"` → 空 |
| ⑤ | `.agents/` 目录**只有** `skills/`，没有别的内容 | `git ls-files .agents \| grep -v '^.agents/skills/'` → 空 |
| ⑥ | `.gitignore` 里**没有**任何 AI 工具目录的规则 | `grep -n "agents\|\.pi\|cursor\|skills" .gitignore` → 空 |
| ⑦ | `.pi/skills/**`（43 个）是 **Trellis 托管**的，与本任务无关 | `.trellis/.template-hashes.json` 里有 43 条 `.pi/skills/...` 记录 |
| ⑧ | 21 处第三方作者的本机绝对路径，集中在 `signals-hooks` 的 **2 个文件**里 | `git grep -c "file:///Users/" -- .agents` → `CONTEXT.md:1`、`SKILL.md:20` |
| ⑨ | 该平台**确实会读** `.agents/skills/`（本会话加载的 skill 列表里就有它们） | 会话上下文中的 available skills 指向 `F:\App\flutter_app_template\.agents\skills\...` |

## 待你拍板的分叉

现状的两种自洽定位只能选一个：

### 方案 A：按本仓库自己的原则办（内容不入库，lock 入库）

依据：本仓库已经有一条同名原则 —— **「生成物不入库」+ lock 入库**（`pubspec.lock` 入库、
`*.g.dart` 不入库、clone 后跑 `just codegen`）。`skills-lock.json` 与 `.agents/skills/**`
正是这个关系。

- 做法：`.gitignore` 加 `.agents/skills/`，保留 `skills-lock.json`，并在 README/AGENTS 写清
  「clone 后要跑什么命令还原」。
- **前提（必须先确认）**：存在一条**能从 lock 还原内容**的命令。仓库里没有（事实 ④），
  所以要确认是平台侧提供的（例如某个 `skills install` / `orca skills sync` 之类）。
- 若该命令不存在 → **不要选 A**：那等于「clone 后 skills 直接消失且无法恢复」，
  而 `AGENTS.md` 的托管块里还写着「`.agents/skills/` — reusable Trellis skills」，会变成假承诺。
- 附带影响（要写进结论）：`gitignore` 只是不跟踪，本地文件仍在，所以本机工具链不受影响；
  受影响的是 fresh clone / 另一台机器 / CI。

### 方案 B：承认它是「随仓库分发的资产」

- 做法：内容继续入库，但把来源与维护方式写清楚（`skills-lock.json` 的三个 source、
  怎么更新、更新后要提交什么），否则没人知道这 173 行 lock 是什么。
- 代价：仓库长期背着 136 个第三方文件；收益是 clone-and-go、离线可用。

### 无论选哪个都要做的（可以立刻做）

- **清掉 21 处第三方本机绝对路径**：`.agents/skills/signals-hooks/CONTEXT.md` 与 `SKILL.md`
  里的 `file:///Users/rodydavis/.gemini/antigravity/worktrees/...` 指向的是**作者机器上的路径**，
  在别人机器上全是死链。改成该 skill 的 GitHub 源路径（可从 `skills-lock.json` 的
  `source` + `skillPath` 推出），或改成相对路径。
- **`AGENTS.md` 的那句描述要跟着定论走**：它在 Trellis 托管块里，写「`.agents/skills/` —
  reusable Trellis skills」。若选 A，这句会失真（块内改动可能被 `trellis update` 覆盖，
  见 `10-10-spec-naming-convergence` 的同类处理）。

## Acceptance Criteria

- [ ] `.agents/skills/**` 的定位在 README 或 AGENTS 里写清楚（入库资产 / 安装产物，二者之一）
- [ ] 若选 A：`.gitignore` 有对应规则、`skills-lock.json` 仍在、还原命令写进文档且**实测可用**
- [ ] 若选 B：README 说清 `skills-lock.json` 是什么、来源三个仓库、怎么更新
- [ ] `signals-hooks` 的 21 处本机路径清零（`git grep -c "file:///Users/" -- .agents` → 无输出）
- [ ] `just verify` 全绿；`dart run tool/check_doc_links.dart` 全绿
- [ ] 兄弟工作树未被写入

## Notes

- **不要动 `.pi/skills/**`**（Trellis 托管，事实 ⑦）。
- 本任务的**第一步是确认还原命令存不存在**，它决定走 A 还是 B —— 不要在没确认前改 `.gitignore`。
- 参考：兄弟分支 `preset/ai-starter` 里没有 `.agents/skills/`（那边是另一套技能），
  其 `guides/public-release-checklist.md`（master 没有）专门讲公开前要洗掉 AI 工具目录与本机路径，
  与本任务同源。可只读参考。

## 已完成（2026-10-10）：清掉本机路径

`.agents/skills/signals-hooks/` 的 `CONTEXT.md` 与 `SKILL.md` 里 21 处
`file:///Users/rodydavis/.gemini/antigravity/worktrees/.../hooks/` 已改成**相对路径** `hooks/`
（20 个目标文件本来就在该 skill 的 `hooks/` 下，本地全部存在）。

**这是对 vendored 内容的本地补丁，有两条后果必须记住**：

1. `skills-lock.json` 里 `signals-hooks` 的 `computedHash`（`0142f2f6…`）**已对不上** ——
   实测它不是「本地 SKILL.md 的 sha256」（`7a945b3c…`），也不是行尾归一化后的值，
   所以**无法重新计算来保持 lock 一致**。仓库里没有任何东西读这个 hash，暂时无害；
   但将来若有一个会校验 hash 的安装器，它会报不一致。
2. **重新安装该 skill 会把这个补丁冲掉**（上游 `rodydavis/signals.dart` 里就是那些本机路径）。
   重装后要么重打补丁，要么按本 PRD 的方案 A/B 决定走「上游提 PR」或「安装后补丁步骤」。

顺带一个值得记的观察：`.agents/skills/**` **不在任何门禁的视野里**
（`check_doc_links.dart` 把它排除在外）—— 所以这些链接坏了三个月也没人知道。
若将来把它纳入链接门禁，前提是先确认所有 vendored skill 的链接都是相对的。
