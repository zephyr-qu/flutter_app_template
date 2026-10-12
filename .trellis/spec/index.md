# Spec 索引

> 总入口：本文件只列入口与共享约定，每层细则见各自目录下的 `.md`。
>
> 工程结构（**canonical** 布局）见 [directory-structure.md](./directory-structure.md)；
> 跨层与门禁见 [cross-cutting.md](./cross-cutting.md)。

---

## 开工前必读

按「要动什么」选该读哪份，写代码前先读完对应文件：

- [ ] 写页面 / ViewModel / 状态适配，或动 `core/` 的状态耦合层 → [ui/state-management.md](./ui/state-management.md)
- [ ] 新增或改动 UI、组件、主题 → [ui/component-guidelines.md](./ui/component-guidelines.md)、[ui/quality-guidelines.md](./ui/quality-guidelines.md)
- [ ] 新建 feature、增删文件、判断某文件该放哪（**canonical 布局**）→ [directory-structure.md](./directory-structure.md)
- [ ] 动路由 / 导航（路由表、冷启动入口、登录守卫、底部导航标签）→ [ui/routing.md](./ui/routing.md)
- [ ] 动数据层（API / Service / DAO / Repository / 模型 / 网络 / 错误 / 日志）→ [data/database-guidelines.md](./data/database-guidelines.md)、[data/network-guidelines.md](./data/network-guidelines.md)、[data/error-handling.md](./data/error-handling.md)
- [ ] 动门禁、codegen、集成测试、环境配置，或判断某写法算不算违规 → [cross-cutting.md](./cross-cutting.md)
- [ ] 动手前先把思路铺开（跨层 / 重复 / 注释）→ [guides/index.md](./guides/index.md)
- [ ] 改名 / 从脚手架初始化新项目 → [guides/rename-checklist.md](./guides/rename-checklist.md)

## 完成前自检

- [ ] `just verify` 全绿（清单与先后顺序见根 `justfile`）
- [ ] 涉及 `@freezed` / `@RoutePage` / `@injectable` / Drift 表，或增删代码文件 → 已跑 `just codegen`
- [ ] 架构边界没破（`core/` 不引上层、跨 feature 只共享 `data/`、`features/*/logic/` 不碰 `material`/`widgets` 与本 feature 的 `page/`、`logic/` 不用 `getIt`、取 ViewModel 的页面给足可选注入点三件套、不用 `AsyncState.map`、注释块 ≤10 行）—— 判据与放行条件见 [cross-cutting.md](./cross-cutting.md)「架构边界与代码形态」
- [ ] 新增 `FailureCode` 已补 `lib/core/ui/failure_message.dart` 的文案，`test/core/ui/failure_message_test.dart` 能覆盖到
- [ ] 增删 `lib/` 文件 → 同步 `README.md` 与 [directory-structure.md](./directory-structure.md) 的目录树（`just verify` 的目录树门禁只覆盖 `README.md` 与 `directory-structure.md`，其余位置**靠人**）
- [ ] 改动触到 spec 描述的约定 → 同步对应的 `.md`

---

## 工程结构

| Guide | 内容 |
| ------- | ------------- |
| [目录结构](./directory-structure.md) | FSD 简化版布局（**canonical**）、数据层文件角色与数据流、命名约定 |

## 界面（UI）

| Guide | 内容 |
| ------- | ------------- |
| [状态管理](./ui/state-management.md) | Signals + ViewModel、`runAsync`、`dispose` 边界 |
| [路由与导航](./ui/routing.md) | 冷启动入口、登录守卫的实时读取、`AutoTabsRouter` 标签与测试同步 |
| [组件规范](./ui/component-guidelines.md) | 页面结构、主题层、共享组件、三态渲染 |
| [Hook 规范](./ui/hook-guidelines.md) | `flutter_hooks` / `signals_hooks` 用法 |
| [类型安全](./type-safety.md) | sealed `Result` / `Failure`、`@freezed` 模型、实际启用的 lint |
| [本地化](./ui/localization.md) | l10n 配置、文案写法、语言设置 |
| [质量规范：界面层](./ui/quality-guidelines.md) | UI 层的禁止模式、必须遵守、错误处理层级 |

## 数据层

| Guide | 内容 |
| ------- | ------------- |
| [数据库规范](./data/database-guidelines.md) | SharedPreferences / 安全存储 / Drift / FileStorage |
| [网络规范](./data/network-guidelines.md) | Dio 装配、拦截器顺序、Mock、配置 |
| [错误处理](./data/error-handling.md) | `Result` / `Failure`、401 与令牌刷新、登出语义 |
| [质量规范：数据与逻辑层](./data/quality-guidelines.md) | 数据/逻辑层的禁止模式、必须遵守、Code Review 清单 |
| [日志规范](./data/logging-guidelines.md) | `Logging` 门面、日志级别、什么不该记 |

## 跨层与门禁

| Guide | 内容 |
| ------- | ------------- |
| [跨层与门禁](./cross-cutting.md) | 架构边界与代码形态（`packages/app_lints` 插件，七条规则）、目录树一致性（`tool/check_readme_tree.dart`）、文档链接一致性（`tool/check_doc_links.dart`）、覆盖率（不设门禁）、依赖声明（`depend_on_referenced_packages`）、供应链门禁（`dart pub outdated` / OSV）、改名脚本（`tool/init_project.dart`）、代码生成与生成物（生成物不入库、重新生成时机、CI 现场生成）、build_runner 升级与缓存评估、`leak_tracker`、集成测试、环境配置与 release 构建 |

## 思考指南

| Guide | 内容 |
| ------- | ------------- |
| [思考指南](./guides/index.md) | 思考指南总入口：跨层、代码复用、AI 交叉复核 |
| [注释规范](./guides/comment-guidelines.md) | 代码注释写什么、spec 引用写法、语言政策、spec 该怎么写 |
| [复用思考指南](./guides/code-reuse-thinking-guide.md) | 新建代码前先找已有的 |
| [跨层思考指南](./guides/cross-layer-thinking-guide.md) | 跨 Page / ViewModel / Service / DAO 的数据流 |
| [改名清单](./guides/rename-checklist.md) | 改名与初始化新项目的完整清单 |

---

## 相关文档

- 一次任务的工作流与任务目录约定：[../workflow.md](../workflow.md)
- 仓库级 AI 协作契约（开工前必读 / 改完必跑 / 照抄对象 / 禁止模式速查）：[../../AGENTS.md](../../AGENTS.md)
