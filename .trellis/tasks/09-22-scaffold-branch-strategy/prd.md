# 脚手架分支化策略：预设分支 + 正交裁剪

## Goal

让脚手架以**少数预设分支 + 正交裁剪参数**的方式提供变体，而不是复制出十几个各自维护的分支。

核心判据：**模块组合用预设（数量固定），横切关注点用参数（不乘法）**。

## 已确认的决策

| # | 决策 | 结论 |
|---|---|---|
| ① | 状态管理（仅 ai-starter） | Riverpod 3.x |
| ② | ai-starter 与 master 的关系 | 兄弟分支，**不回流** |
| ③ | 路由 | 保留 auto_route |
| ④ | Flutter 版本 | `.fvmrc` + CI 钉 3.47.1；`pubspec.yaml` 下限保持 `>=3.44.0` |

## Requirements

### 保留的预设分支

`preset/minimal`、`preset/local-only`、`preset/online-only`、`preset/offline-first`、`preset/empty-feature`、`preset/ai-starter`

### 正交裁剪轴

`--l10n=multi|single`（默认 `multi`）。这是当前唯一实现的轴，其它轴（theme/examples 等）只留接口位置。

### 明确不做

- A 组单点减法分支（`slim/no-auth`、`slim/no-network`、`slim/no-database`、`slim/no-theme`、`slim/no-hooks`、`slim/no-di`、`slim/no-examples`）——「无登录 / 无网络 / 无数据库」由预设承担
- C 组增强分支（`plus/flavors`、`plus/crash-report`、`plus/web`、`plus/desktop`、`plus/graphql`、`plus/firebase`）
- `preset/hello-world`（职责被 `preset/minimal` 覆盖）
- `slim/no-l10n` 分支（降级为正交轴 `--l10n=single`）

## 任务地图

| 子任务 | 内容 | 依赖 |
|---|---|---|
| `09-22-prune-l10n` | `--l10n=single` 正交裁剪 | 无 |
| `09-22-extract-app-core` | 抽 `packages/app_core` 供双栈共用 | 无（但需先于 ai-starter） |
| `09-22-preset-ai-starter` | Riverpod 3.x 栈 + spec 重写 + AI 契约 | **依赖 `09-22-extract-app-core`** |

> 依赖是写在各自子任务 PRD 里的约定，不是靠树的位置暗示。

## 已完成的前置（2026-09-22）

积压的未提交重构已按「6 + 1」提交方案落地，`master` 工作区干净：

```
0ebe388  chore: 移除自定义 lint 包、flutter_gen 与 lottie 资源
d177996  refactor: 引入 lib/app 组合根，core 收束为 theme/ui/models
8b8cb40  feat: 认证与网络增强（令牌主动刷新、请求标记、日志脱敏）
775e51c  feat: 引入 l10n 双语（zh/en）与错误文案本地化
92800a3  chore: 门禁体系、规范文档与 AI 规则
69e8348  chore: 平台配置对齐
38692d4  chore: 统一 Flutter 到 3.47.1（.fvmrc 与 CI）
b5574ca  chore: 添加 .gitattributes 统一换行符与二进制识别
```

## Acceptance Criteria（跨子任务）

- [ ] 每个子任务完成后，`master` 上六道门禁仍全绿（format / check_boundaries / check_conventions / dependency_validator / analyze / check_coverage）
- [ ] `--l10n=single` 可幂等重复执行，且 `tool/prune.dart` 自带测试
- [ ] `packages/app_core` 内不出现 `signals` 或 `riverpod` 的 import
- [ ] `preset/ai-starter` 通过 DoD：新会话 AI 在无人解释下新增一个 feature 并过全部门禁
- [ ] 每个分支/轴的差异都有文档记录（spec 或 `BRANCH.md`），不靠口口相传

## Notes

- 基线分支名是 **`master`**（不是 `main`），所有子任务的 `base_branch` 均为 `master`
- ② 之所以是兄弟分支而非新主线：Riverpod 与 signals 无法互相合并，强行回流会导致两栈代码互相覆盖
- 双栈维护成本由 `09-22-extract-app-core` 单独消解（共有面 27 个文件 → 0）
