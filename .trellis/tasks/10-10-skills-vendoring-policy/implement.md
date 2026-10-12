# 实现记录：`.agents/skills` 入库策略

## 决定

选 **方案 B** —— 承认 `.agents/skills/**` 是「随仓库分发的资产」（2026-10-12 用户拍板）。

A 被否的理由是**前提不成立**（本会话实测，不是推断）：

| 要确认的东西 | 实测结果 |
|---|---|
| 存在「从 lock 还原内容」的命令 | `orca` 不在 PATH（`command not found`） |
| 仓库里有东西读 `skills-lock.json` | 除本任务的笔记外**没有** |
| lock 是可信的还原清单 | **不是**：28 条 vs 磁盘 27 个目录，`signals_hooks`（下划线）那条指向 `.agents/skills/signals_hooks/SKILL.md`，该路径不存在 |

所以选 A 等于 fresh clone 后 skills 消失且无从还原，而 `AGENTS.md` 托管块里那句
「reusable Trellis skills」会变成假承诺。

## 落地

| 位置 | 动作 |
|---|---|
| `README.md`「其它」 | 新增一条：定位（三方资产、随仓库分发、clone 即用）、来源三个仓库与条数、更新方式，并写明**本仓库不提供安装 / 还原命令**这个选 B 的理由；另记 `signals-hooks` 有本地补丁、重装会冲掉 |
| `AGENTS.md` **托管块内** | `- .agents/skills/ — reusable Trellis skills` → `vendored third-party agent skills (sources in skills-lock.json)` |
| `.agents/skills/signals-hooks/{CONTEXT,SKILL}.md` | 21 处作者本机绝对路径 → 相对路径（**2026-10-10 已完成**，提交 `7a7f373`） |

托管块那处**是第二次改块内文字**（第一次见 `10-10-spec-link-gate`，同类处理见
`10-10-spec-naming-convergence` 的 prd）。若被 `trellis update` 还原，按同口径再改一次。

## 没做的事（有意）

- **没改 `.gitignore`**、没删 `.agents/skills/**` —— 选 B 就是继续入库。
- **没手改 `skills-lock.json`**：它是平台生成物。`signals_hooks` 那条与磁盘不一致的记录
  如实写进文档，不靠手改掩盖。
- 未动 `.pi/skills/**`（Trellis 托管）；未动兄弟分支 `preset/ai-starter`。

## 遗留（如实记）

- `signals-hooks` 的 `computedHash` 与 lock 对不上（本地补丁所致；实测既非本地文件的 sha256、
  也非行尾归一化后的值，**无法重算**）。若有会校验 hash 的安装器会报不一致，且重装会冲掉补丁。
- `.agents/skills/**` **不在任何门禁的视野里**（`check_doc_links.dart` 显式排除）—— 里面的链接坏了
  没人会发现。将来若要纳管，前提是先确认所有 vendored skill 的链接都是相对的。

## 验证

- `just verify` → **All gates passed**（339 项测试，含 `test-readme-tree` / `test-doc-links`）
- `dart run tool/check_doc_links.dart` → 138 个文件全绿，exit 0
- `git grep -c "file:///Users/" -- .agents` → **无输出**
- `just check-anchors` → 138 个文件全对上，无新增告警
