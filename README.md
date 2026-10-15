# Flutter 通用脚手架

面向中小型 App 的 Flutter 起点：目录、状态、错误模型、网络与缓存、主题都已定型，配套分层规范
（[`.trellis/spec/`](.trellis/spec/index.md)）与统一门禁（`just verify`）——**在既定的形状里写业务代码**。
技术栈：Feature-Sliced Design（FSD）目录 + Signals + `auto_route` + Retrofit/Dio + Drift，版本见
[`pubspec.yaml`](pubspec.yaml)。

## 这是什么

- **是**：中小型 App 的起点，新项目从这里 `just init` 派生。
- **不是**：可直接发布的成品——签名、混淆、build flavor、崩溃上报等发版配置**有意留白**。
- **语言**：单语言中文，文案直接写中文，无 ARB（要加回来见 [localization.md](.trellis/spec/ui/localization.md)）。
- **面向 AI**：分层规范在 [`.trellis/spec/`](.trellis/spec/index.md)，照抄对象与协作契约见 [`AGENTS.md`](AGENTS.md)。

## 已定型的能力

| 能力      | 说明                                                                                                                     |
| ------- | ---------------------------------------------------------------------------------------------------------------------- |
| 功能切片    | 按业务模块组织（`page/` `logic/` `data/`），依赖方向 `app → features → core`                                                         |
| 状态与依赖注入 | `signals_flutter` / `signals_hooks` 承担状态，`get_it` + `injectable` 装配                                                    |
| 声明式路由   | `auto_route` 类型安全路由 + 登录守卫（实时读登录态，会话失效自动回登录页）                                                                          |
| 网络与缓存   | Dio + Retrofit + 重试 + Mock；Drift 缓存旁路（失败回退缓存，离线可读）                                                                     |
| 认证与令牌   | 令牌存平台安全存储，临近过期主动刷新，401 刷新并重放，刷新失败才登出                                                                                   |
| 类型安全的错误 | `Result<T, E>` + `Failure` 密封类，只带错误码，文案由 UI 翻译                                                                         |
| MD3 主题  | `flex_color_scheme`，亮 / 暗主题完整支持                                                                                        |
| 架构边界与门禁 | `packages/app_lints` 强制七条规则；`just verify` 一条命令跑完所有门禁，判据见 [cross-cutting.md](.trellis/spec/cross-cutting.md)「架构边界与代码形态」 |

## 快速开始

要求：Flutter >= 3.47.0（开发与 CI 钉 3.47.5，见 `.fvmrc`）、Dart >= 3.13.0、[`just`](https://just.systems) >= 1.58.0。

```bash
just deps
just codegen    # 生成物不入库，clone 后必跑，否则 analyze / test 会缺 part
just run        # 默认带 Mock，无需后端
```

| 命令                                                       | 用途                                   |
| -------------------------------------------------------- | ------------------------------------ |
| `just` / `just verify`                                   | 完整门禁，首个失败即停（`pre-commit` 与 CI 跑的就是它） |
| `just deps` / `just codegen [参数]` / `just codegen-reset` | 解析依赖 / 增量生成 / 清缓存后全量生成               |
| `just run` / `just test [文件]`                            | 本地运行 / 全部或指定的测试                      |
| `just init`                                              | 从脚手架创建新项目                            |
| `just fmt` / `just fmt-check` / `just fix`               | 格式化 / 只检查 / `dart fix --apply`       |

全部命令用 `just --list`。`just analyze` 是唯一的静态门禁（两步 `dart analyze --fatal-infos`），必须**显式传文件名**
——传目录不报错，只是静默少跑插件规则；
生成物重新生成的时机与 CI 现场生成策略见 [cross-cutting.md](.trellis/spec/cross-cutting.md)「代码生成与生成物」。

### 环境与构建

配置只有 `BASE_URL` / `USE_MOCK` 两项，来自**入库的** [`.env.example`](.env.example)——`just run` 与
`flutter build apk` 用的是同一份。连自己的后端就改它（会显示为 dirty，预期行为）。

- **dotenv 只能加载 asset，而这份文件会打进产物**：新建 `.env*` 指望运行时加载无效，密钥也别写进去
  （本模板不做密钥注入，敏感值放服务端）——机制见 [cross-cutting.md](.trellis/spec/cross-cutting.md)「环境配置与 release 构建」。

release **有意留白**（仍用 debug keystore 签名、未 minify、无 flavor、iOS 未签名），发版前按
[release-checklist.md](docs/release-checklist.md) 逐项补齐。

### 用它开新项目

```bash
just init                                               # 交互式
just init --yes --name=my_next_app \
  --application-id=com.example.my_next_app              # 非交互
```

一次改完包名 / `namespace` / iOS Bundle ID / 显示名，语义是**全有或全无**；覆盖范围与失败行为见
[rename-checklist.md](.trellis/spec/guides/rename-checklist.md)。

## 示例模块

三个开箱即用示例（`USE_MOCK=true` 时由 `msw_dio_interceptor` 拦截请求，无需后端）：

- `auth/` — 登录 → 存令牌 → 401 自动刷新 → 个人中心读用户信息
- `article/` — 列表 → 详情，含 Retrofit + Drift 离线缓存 + 加载三态
- `demo/` — `FileStorage` 读写 / 占用统计 + Drift 缓存填充

跑起来后从 `page/`（UI）→ `logic/`（ViewModel）→ `data/`（API / Service / Model）逐层读；删掉这些示例的
清单见 [template-pruning.md](docs/template-pruning.md)。

## 加新模块与目录结构

新模块照抄 `lib/features/article/`（`page/` → `logic/` → `data/`，API / DAO / Service / Repository /
models 的完整写法与对应测试都在那里）；命名与「某个文件该放哪」的裁决见
[directory-structure.md](.trellis/spec/directory-structure.md)。

```
lib/
├── main.dart
├── bootstrap.dart
├── app/          # 组合根：主题、路由、全局页面（启动页 / 404）
├── core/         # 基础设施：Failure/Result、网络、数据库、主题、共享 UI
├── di/           # 依赖注入注册（service_locator + 生成的 config）
└── features/     # 业务模块：auth、article、demo、home、profile
```

依赖方向 `app → features → core`：`core/` **不得** import `features/` / `app/`；`app/` 是组合根，可以 import
任何东西。完整树、每层职责与数据流见 [directory-structure.md](.trellis/spec/directory-structure.md)。

## 其它

- **`.trellis/spec/`** — 分层规范（[入口](.trellis/spec/index.md)）：改某一层的代码前先读对应文档
- **[`AGENTS.md`](AGENTS.md)** — AI 协作契约：开工前必读 / 改完必跑 / 照抄对象 / 禁止模式速查
- **`TODO(template)`** — 刻意留空的骨架占位（含**尚不存在**的 `assets/icon/icon.png`），见
  [template-pruning.md](docs/template-pruning.md)
- **`docs/optional-additions.md`** — 有意不预装的包，以及每个包的「什么时候才该加」
- **测试** — `mocktail` 模拟外部依赖，含 ViewModel / Widget / 数据库测试；覆盖率**不设门禁**
  （取舍见 [cross-cutting.md](.trellis/spec/cross-cutting.md)「覆盖率」）

## 许可证

MIT
