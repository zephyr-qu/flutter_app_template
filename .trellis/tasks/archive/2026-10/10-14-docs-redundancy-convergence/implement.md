# 实现记录：docs 局部冗余收敛

> 状态：**in_progress**（D0 已定为 B，2026-10-14）
> 执行者：主会话（文档改动，无需 sub-agent 分派）
> 验证方式见「验证」节 —— 文档类门禁已在 `b8b90f6` 删除，**没有自动化兜底**。

---

## 前置：决策闸门（挡住全部实施）

- [x] **D0** 已定：**B**（2026-10-14 用户选定）—— 删 `docs/adr/ADR-0002.md`，把「日期 `2026-09-19` +
      来源」两行并进 `state-management.md` 段尾，清理 `ADR-0001.md:104` 关联行。
      备选 A / C 与代价见 `prd.md`「ADR-0002 处置（已决策）」。

## 实施步骤（顺序不可颠倒）

- [x] **S1 — R1 收窄 `docs/release-checklist.md` §6**
      - 保留：`just codegen` 代码块、「`just verify` 全绿」checklist 项。
      - 删除：覆盖率不设门禁的解释（:121-123）、OSV / `dart pub outdated` 语义（:126-130）、
        「清单以 justfile 为准」的复述（:115-119）。
      - 替换为一句指路：`.trellis/spec/cross-cutting.md` 的「代码生成与生成物」「供应链门禁」「覆盖率」。
      - 注意：`optional-additions.md` / `README.md` 对 `release-checklist.md` 的入链不受影响。

- [x] **S2 — R2 去重「崩溃上报接入点」**
      - `release-checklist.md:138`：保留「崩溃/错误上报已接入」这个**动作项**，理由压成一句 +
        指 `docs/optional-additions.md` 的「崩溃 / 错误上报」行。
      - 反向检查：`optional-additions.md:58` 那行是否已含全部信息（三段接入点 + 「现在只打日志」）—— 是则它成为权威。

- [x] **S3 — R3 收敛「图标文件缺失」**
      - `docs/template-pruning.md:53` 保持不动，成为唯一权威行。
      - `docs/optional-additions.md:64`：保留 `flutter_launcher_icons` 在依赖里这一信息点，
        警告部分改为指 `docs/template-pruning.md` 的占位清单。
      - `README.md:111`、`.trellis/spec/guides/rename-checklist.md:55` **不动**（前者已是指路，后者是操作步骤）。

- [x] **S4 — R4（已定 B）**
      - 删 `docs/adr/ADR-0002.md`。
      - `state-management.md`「为什么没有 BaseViewModel」段尾追加两行溯源（日期 + 来源，含「评估是一次性快照，已删除」）。
      - 清理 `docs/adr/ADR-0001.md:104` 的「关联」行。
      - 复核 `docs/optional-additions.md`「相关文档」里 `adr/` 的整类指路仍成立（只剩一份 ADR）。

- [x] **S5 — R5 判为「不做」**（理由记在「结果」的「没做的事」）

## 验证

文档类门禁不存在 → 逐项人工核对，命令可直接复制：

```bash
# 1) 相对链接目标存在：挑出本次改动的链接，逐个 test -f
git diff --name-only            # 确认改动面只在 docs/** 与（可选）state-management.md
git diff -U0 | grep -o '](\.\./[^)]*\.md)' | sort -u

# 2) 章节锚点可解析：把链接里的 #片段 拿去目标文件里正文 grep（不是靠锚点工具，已删）
git grep -n "覆盖率" -- .trellis/spec/cross-cutting.md
git grep -n "供应链门禁" -- .trellis/spec/cross-cutting.md
git grep -n "崩溃 / 错误上报" -- docs/optional-additions.md

# 3) R4 一致性
git grep -n "ADR-0002" -- docs/ .trellis/spec/ README.md lib/   # A/C 保留；B 应无输出

# 4) 无新增孤儿 / 无新增断链面：docs 的 5 个入链点仍指向存在的文件
ls docs/adr/ docs/*.md

# 5) 契约门禁（不覆盖 .md，但「改完必跑」）
just verify
```

- [x] **V1** 已逐条跑并记录实际输出 —— 见「结果」的「验证实测」
- [x] **V2** `just verify` → `All gates passed.`（347 tests + 1 skipped）
- [x] **V3** 已去权威位置读过原文：三段接入点 + 「现在只打日志」确实都在 `optional-additions.md:58`；
      「覆盖率不设门禁」与 OSV 语义确实都在 `cross-cutting.md`（含独立小节标题）

## 复核门禁（提交前自问）

- [x] 每条信息是否只剩一处权威？—— 是。§6 只留两条动作 + 指路；崩溃上报接入点只剩 `optional-additions.md:58`；
      图标缺失只剩 `template-pruning.md:53`
- [x] 「指路」都给了可点击路径 + 章节名（`../.trellis/spec/cross-cutting.md`、`./optional-additions.md`、`./template-pruning.md`）
- [x] 未越界改 spec 正文口径 —— spec 只 +3 行（空行 + 两行溯源），三条理由原文未动
- [x] `docs/optional-additions.md`「相关文档」里 `- [adr/](./adr/) — 已经做过的架构决策与理由` 仍成立
      （目录链接，`docs/adr/` 下仍有 ADR-0001）

## 回滚点

- 按文件分 3 次提交（S1 + S2 合并在 release-checklist），每个文件仍可单独 `git revert`。
- S4-B 是唯一删文件的步骤，单独提交，便于单独回滚。


## 结果

`just verify` → `All gates passed.`（347 tests + 1 skipped）· 净 **−67 行**（+12 / −79，5 个文件）
· 集中改在 `docs/**` 与 `state-management.md` 的 3 行溯源。

| 步骤 | 文件 | 改动 | 行数 |
|---|---|---|---|
| S1 | `docs/release-checklist.md` §6 | 删「清单以 justfile 为准」的展开、覆盖率口径、`dart pub outdated` 四列说明；两句「复述」压成一句指路（三章节名）；`dart pub outdated` 的**动作**保留 | +4 / −5 |
| S2 | `docs/release-checklist.md` §7 | 崩溃/错误上报：保留动作项，三段接入点 + 「现在只打日志」压成指路到 `optional-additions.md` | +2 / −3 |
| S3 | `docs/optional-additions.md` §二 | 「应用图标」行的警告改为指 `template-pruning.md` 占位表（该行成为权威）；`flutter_launcher_icons` 已在依赖里这一信息点保留 | +1 / −1 |
| S4 | `docs/adr/ADR-0002.md` | **删除**（`git rm`） | −65 |
| S4 | `.trellis/spec/ui/state-management.md` | 「为什么没有 BaseViewModel」段尾 + 两行溯源（日期 + 来源），三条理由**原文未动** | +3 |
| S4 | `docs/adr/ADR-0001.md` | 「关联」节删掉指向 ADR-0002 的一行 | −1 |

### 验证实测（V1）

```
$ git status --short
 M .trellis/spec/ui/state-management.md
 M docs/adr/ADR-0001.md
D  docs/adr/ADR-0002.md
 M docs/optional-additions.md
 M docs/release-checklist.md

$ git grep -n "ADR-0002" -- docs/ .trellis/spec/ README.md lib/
(无输出)

$ git diff -U0 HEAD | grep "^+" | grep -o '](\.\.\?/[^)]*)' | sort -u   # 只统计新增行
](./template-pruning.md)  ](./optional-additions.md)  ](../.trellis/spec/cross-cutting.md)
→ 三个目标文件均存在

$ for s in 代码生成与生成物 供应链门禁 覆盖率; do git grep -c "$s" -- .trellis/spec/cross-cutting.md; done
1 / 1 / 4        # 三个指路章节名都 grep 得到

$ ls docs/adr/
ADR-0001.md
```

### 与计划的偏差（如实记录）

- **子代理分派失败**：`spawn pi ENOENT` —— 本机 Windows 上 Node 解析不了 `~/.pi/agent/bin/pi`
  这个无扩展名脚本（`pi` 在 PATH 上但无 `.cmd` / `.exe` 变体）。改用 workflow 的 inline 路径由主会话实施，
  **独立复核那道保险没有了**：下文的 V1–V3 与复核门禁都是同一个会话自检，不是独立验证。
  修插件不属本任务范围。
- **一次锚点错误已撤销**：首次给 `optional-additions.md` 的「应用图标」行换指路时，误把锚点取在
  「原生启动图」行上（`crEm`），覆盖掉了原生启动图那条（其中含上轮任务并进来的 `LaunchImage` 信息）。
  已 `undo_last_change` 还原并对正确行（`JMJa`）重做 —— 上面的 diff 是重做后的终态。
- **提交粒度**：原计划 S1–S5 各一次提交；实际按**文件**分 3 次（S1+S2 同在 release-checklist），
  每个文件仍可单独 `git revert`。回滚粒度一点没变差，但撤销一次 release-checklist 会同时回退 S1 与 S2。

### 没做的事

- **S5 不做**：`.env.example` 的「密钥别写」在 `README.md`「环境与构建」、`release-checklist.md:19`、
  `template-pruning.md:52` 三处 —— 判断为**三种读者场景**（概览 / 发版核查 / 裁剪清单），
  压成一处会让裁剪清单或发版清单出现「本条为什么不展开」的空白，收益低于损失，故意保留。
- 未动 `docs/template-pruning.md`（S3 的唯一权威行、S5 的保留点）。
- 未动 `README.md:111`、`.trellis/spec/guides/rename-checklist.md:55`（前者已是指路，后者是改名流程里的操作步骤）。
- 未动 `optional-additions.md` 的包选型表（第一、三、五、六节）。
- 未为文档改动新建门禁（`b8b90f6` 刚删掉文档类门禁，不反向加回）。
- 未动 Trellis 托管文件与 `.trellis/tasks/archive/**`。
