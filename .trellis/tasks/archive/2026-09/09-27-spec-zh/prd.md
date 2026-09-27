# spec 中文化：标题与正文全量换成中文

## 目标

`.trellis/spec/` 现在有 16 个文件带英文 H1（共 17 个）、**90 个英文二三级标题**、**75 行英文正文**，另有 **9 处交叉引用**按英文章节名指路。全部换成中文，并让写法约定与之一致。

顺手补一个既存缺口：Trellis 模板指望 layer index 里有 `Pre-Development Checklist` / `Quality Check` 两个节（`.pi/skills/trellis-before-dev/SKILL.md:29`、`trellis-check/SKILL.md:31`、`.trellis/workflow.md:31` 都按名字找），本仓（含已删的 `frontend/index.md`、`backend/index.md`）从来没有 → 在 `spec/index.md` 用中文节名补上「开工前必读」「完成前自检」。

## 口径

### 不翻译（保持原文）

- 代码、标识符、类名 / 方法名 / 属性名：`AsyncView`、`ref.watch`、`Result<T, Failure>`、`FailureCode`、`getOrThrow`
- 路径与文件名、包名、命令与参数：`lib/core/ui/`、`just verify`、`--dart-define-from-file`
- 技术专名：Drift、Dio、Retrofit、Riverpod、Mock、lint、`leak_tracker`、`build_runner`、`json_annotation`、`shared_preferences`
- 表格里的字段名（`state` / `data` / `loading` / `error` / `refreshing`）与代码块内容
- 快照标注的格式（`> 快照（2026-09）：…`）

### 翻译

- 所有 `#` / `##` / `###` 标题（已是中文的除外）
- 正文里的英文句子与英文标签：`**Bad**` / `**Good**` → `**反例**` / `**正例**`、`When to use` → `什么时候用`、`**Rules**:` → `**规则**：`、`**Pattern rules**:` → `**范式规则**：`、`Purpose` / `When to Use` 表头等
- 引用块的英文引言行：`> Database and storage patterns for this project.` → `> 本项目的数据库与存储约定。`

## 标题译名表（唯一权威，跨文件必须一致）

### H1

| 原文 | 中文 |
|---|---|
| `# Database Guidelines` | `# 数据库规范` |
| `# Error Handling` | `# 错误处理` |
| `# Logging Guidelines` | `# 日志规范` |
| `# Network Guidelines` | `# 网络规范` |
| `# Quality Guidelines`（backend/） | `# 质量规范：数据与逻辑层` |
| `# Quality Guidelines`（frontend/） | `# 质量规范：UI 层` |
| `# Cross-Cutting Concerns` | `# 跨层与门禁` |
| `# Component Guidelines` | `# 组件规范` |
| `# Directory Structure` | `# 目录结构` |
| `# Localization (l10n)` | `# 本地化（l10n）` |
| `# State Management` | `# 状态管理` |
| `# Type Safety` | `# 类型安全` |
| `# Code Reuse Thinking Guide` | `# 复用思考指南` |
| `# Comment Guidelines` | `# 注释规范` |
| `# Cross-Layer Thinking Guide` | `# 跨层思考指南` |
| `# Thinking Guides` | `# 思考指南` |
| `# Rename Checklist` | `# 改名清单` |

`# Spec 索引` 已是中文，不动。

### H2 / H3

| 原文 | 中文 |
|---|---|
| `## Overview` | `## 概览` |
| `## Error Types` | `## 错误类型` |
| `### Result Type (…)` | `### `Result` 类型（…）` |
| `### Failure Hierarchy (…)` | `### `Failure` 层级（…）` |
| `### Dio Error Handling (…)` | `### Dio 错误映射（…）` |
| `## Error Handling Patterns` | `## 错误处理范式` |
| `### Service layer (data boundary)` | `### Service 层（数据边界）` |
| `### Notifier layer (logic boundary)` | `### Notifier 层（逻辑边界）` |
| `## Common Mistakes` | `## 常见错误` |
| `## Log Levels` | `## 日志级别` |
| `## Logger Configuration` | `## Logger 配置` |
| `## What NOT to Log` | `## 什么不该记` |
| `## Drift (Relational Cache)` | `## Drift（关系型缓存）` |
| `## FileStorage` | 不译（类名） |
| `## Query Patterns` | `## 查询范式` |
| `## Naming Conventions` | `## 命名约定` |
| `## Forbidden Patterns` | `## 禁止模式` |
| `## Required Patterns` | `## 必须遵守` |
| `## Testing Requirements` | `## 测试要求` |
| `## Code Review Checklist` | `## Code Review 清单` |
| `## Page Structure` | `## 页面结构` |
| `## Props Conventions` | `## Props 约定` |
| `## Styling Patterns` | `## 样式范式` |
| `## Theme Layer` | `## 主题层` |
| `## Shared Widgets` | `## 共享组件` |
| `## Accessibility` | `## 无障碍` |
| `## State Categories` | `## 状态分类` |
| `## Type Organization` | `## 类型组织` |
| `### Models (per feature, in …)` | `### 模型（放在各 feature 的 …）` |
| `### Global types (…)` | `### 全局类型（…）` |
| `### Generated types` | `### 生成类型` |
| `## Validation` | `## 校验` |
| `## Common Patterns` | `## 常见范式` |
| `### Sealed class pattern matching` | `### sealed class 模式匹配` |
| `### Async state checking` | `### 异步状态判定` |
| `### Type-related lints actually enabled` | `### 实际启用的类型相关 lint` |
| `## Memory Leak Detection (…)` | `## 内存泄漏检测（…）` |
| `## Integration Testing` | `## 集成测试` |
| `## The Problem` | `## 问题` |
| `## Before Writing New Code` | `## 写新代码之前` |
| `### Step 1: Search First` | `### 第 1 步：先搜一遍` |
| `### Step 2: Ask These Questions` | `### 第 2 步：问这几个问题` |
| `## Common Duplication Patterns` | `## 常见重复形态` |
| `## When to Abstract` | `## 什么时候该抽` |
| `## After Batch Modifications` | `## 批量改动之后` |
| `## Checklist Before Commit` | `## 提交前清单` |
| `## The Layers` | `## 本项目有哪些层` |
| `## Before Implementing Cross-Layer Features` | `## 动手前的三步` |
| `### Step 1: Map the Data Flow` | `### 第 1 步：画数据流` |
| `### Step 2: Identify Boundaries` | `### 第 2 步：找出边界` |
| `### Step 3: Define Contracts` | `### 第 3 步：定契约` |
| `## Common Cross-Layer Mistakes` | `## 常见跨层错误` |
| `### Mistake 1: Implicit Format Assumptions` | `### 错误 1：默认格式假设` |
| `### Mistake 2: Scattered Validation` | `### 错误 2：校验散落各处` |
| `### Mistake 3: Leaky Abstractions` | `### 错误 3：抽象泄漏` |
| `## Checklist for Cross-Layer Features` | `## 跨层功能清单` |
| `## When to Create Flow Documentation` | `## 什么时候写流程图文档` |
| `## Available Guides` | `## 有哪些指南` |
| `## Quick Reference: Thinking Triggers` | `## 速查：什么时候该想这些` |
| `### When to Think About Cross-Layer Issues` | `### 该想跨层问题时` |
| `### When to Think About Code Reuse` | `### 该想复用时` |
| `### When Verifying AI Cross-Review Results` | `### 核查 AI 交叉复核结论时` |
| `## Pre-Modification Rule (CRITICAL)` | `## 改任何值之前先搜（硬性）` |
| `## How to Use This Directory` | `## 怎么用这个目录` |
| `## Contributing` | `## 新增指南` |
| `### Environment Validation` | `### 环境校验` |
| `## Mock` / `## 拦截器顺序（…）` / `## 目录树一致性（无门禁）` 等已中文 | 不动 |

## 批次

| 批次 | 文件 | 状态 |
|---|---|---|
| 1 | `backend/` 5 个 | 已完成 | 650 行不变；字符 25419 → 22888（-10.0%） |
| 2 | `frontend/` 6 个 | 已完成 | 911 行不变；字符 34724 → 32806（-5.5%） |
| 3 | `guides/` 5 个（含改语言约定） | 已完成 | 417 行；字符 13866 → 10893（-21.4%） |
| 4 | `cross-cutting.md` + `index.md`（含补两个约定节）+ 交叉引用同步 | 已完成 | cross-cutting 303 行（-2.4%）；index 34 → 56 行（新增两个 checklist） |

快照：改写前 18 个文件已备份到 `/tmp/speczh/spec_*.md`（命名 `spec_<目录>_<文件>`）。

## 验收标准

- [x] 18 个文件里没有 ASCII-only 的 `#` / `##` / `###` 标题（全库扫只剩 6 个按译名表**故意不译**的：`## FileStorage`、4 个 `### Logging.xxx(...)` 代码签名、`## Mock`）
- [x] 代码 / 标识符 / 路径 / 命令零改动：逐文件比对 inline code token 集合，18 个文件全部「零消失」，命令与 flag 零增减
- [x] 9 处引英文章节名的交叉引用已同步（全仓扫「Forbidden Patterns / Required Patterns / Common Mistakes / Testing Requirements / Memory Leak Detection / Integration Testing / Cross-Cutting Concerns」→ 零命中，已排除 tasks/archive）
- [x] `comment-guidelines.md` 的语言约定改为「标题与正文都用中文，代码与标识符保持原文」，并写明表头 / 英文标签 / `// BAD` 这类代码注释标签也写中文
- [x] `spec/index.md` 有「开工前必读」「完成前自检」两节（中文名，对应 Trellis 约定的 Pre-Development Checklist / Quality Check）
- [x] 链接全部可解析、围栏成对（全库扫：无失效链接、无围栏奇数、无连续空行）

## 风险

- 90 个标题分散在 16 个文件，若中途改译名会留下不一致；故先落译名表。
- 交叉引用按章节名指路，改标题必须同批改引用，否则指路失效（验收里有专项）。
