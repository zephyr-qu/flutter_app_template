# Flutter 通用脚手架

面向「**AI 驱动快速开发**」的 Flutter 起点：架构、目录、状态管理、错误模型、网络与缓存、主题都已定型，
配套分层规范（`.trellis/spec/`）与统一门禁（`just verify`）——**AI 在既定的形状里写业务代码，人负责提需求、看结果、验收**。

技术栈：Feature-Sliced Design（FSD）目录 + Riverpod 3 + `auto_route` + Retrofit/Dio + Drift。版本以 [`pubspec.yaml`](pubspec.yaml) 为准。

## 这是什么

- **定位**：中小型 App 的**起点**（脚手架 / 模板），新项目从这里 `just init` 派生。
- **不是**：可直接发布的成品——发版配置（签名、混淆、build flavor、崩溃上报）**有意留白**。
- **语言**：单语言中文（用户可见文案直接写中文，无 ARB）。
- **面向 AI**：`features/sample/` 是唯一的「照抄金标准」，`.trellis/spec/` 是分层规范；协作契约与硬约束在 [`AGENTS.md`](AGENTS.md)。

## 包含什么

- **功能切片** — 按业务模块组织（`page/` `logic/` `data/`），依赖方向 `app → features → core`
- **状态与依赖都是 provider** — Riverpod 承担状态、装配与生命周期，`AsyncView` 统一三态渲染
- **声明式路由** — `auto_route`，启动页进主框架
- **网络与缓存** — Dio + Retrofit + 重试 + Mock；Drift 缓存旁路（离线可读）
- **类型安全的错误** — `Result<T, E>` + `Failure` 密封类（只带错误码，文案由 UI 翻译）
- **MD3 主题** — `flex_color_scheme`，亮 / 暗

## 快速开始

环境要求：Flutter >= 3.47.0（开发与 CI 钉 3.47.5，见 `.fvmrc`）、Dart >= 3.13.0、just >= 1.58.0。

```bash
just deps
just codegen    # 生成物不入库，clone 后必跑
just run        # dotenv 加载 .env.example（默认带 Mock，无需后端）
```

### 常用命令

| 命令                                         | 用途                               |
| ------------------------------------------ | -------------------------------- |
| `just` / `just verify`                     | 完整门禁，首个失败即停                      |
| `just deps`                                | 解析依赖（根工程 + `packages/app_lints`） |
| `just codegen [参数]` / `just codegen-reset` | 增量生成 / 清缓存后全量生成                  |
| `just run` / `just e2e`                    | 本地运行（读 `.env.example`）/ 端到端冒烟         |
| `just test [文件]`                           | 全部或指定的 Flutter 测试                |
| `just init` / `just prune`                 | 创建新项目 / 裁剪可选能力（l10n 等）           |
| `just fmt` / `just fmt-check` / `just fix` | 格式化 / 只检查 / `dart fix --apply`   |

`just verify` 就是 `pre-commit` 与 CI 跑的那套门禁（首个失败即停）；规则细节与测试基建见 [cross-cutting.md](.trellis/spec/cross-cutting.md)。

### 环境与构建

`just run` 开箱即用（默认带 Mock，无需后端）。连自己的后端就改 `.env.example` 里的 `BASE_URL`（改完会显示为 dirty，预期行为）：

```bash
just run                                # 开发运行（dotenv 读 .env.example）
flutter build apk                       # 发版构建，配置同样来自 .env.example
```

配置只有 `BASE_URL` / `USE_MOCK` 两项；密钥别写进 env 文件，走 `--dart-define`。release 有意留白（签名、混淆、flavor、iOS 签名），发版按 [release-checklist.md](docs/release-checklist.md) 补齐。

### 用它开新项目

```bash
just init                                               # 交互式
just init --yes --name=my_next_app \
  --application-id=com.example.my_next_app              # 非交互
```

## 目录结构

```
lib/
├── main.dart / bootstrap.dart
├── app/          # 组合根：主题、路由、全局页面（启动页 / 404）
├── core/         # 基础设施：Failure/Result、网络、数据库、主题、共享 UI
└── features/     # home、profile、sample（金标准示例）
```

feature 内三层 `page/` → `logic/` → `data/`；`core/` 不得引用 `features/` / `app/`，跨 feature 只共享 `data/` 与 `core/` 暴露的 provider。完整树与职责见 [directory-structure.md](.trellis/spec/frontend/directory-structure.md)。

## 其它

- **`.trellis/spec/`** — 分层规范；**[`AGENTS.md`](AGENTS.md)** — AI 协作契约与硬约束
- **`TODO(template)`** — 刻意留空的骨架占位：`grep -rn "TODO(template)" lib/`
- **应用图标** — 默认占位图在 `assets/icon/icon.png`，发版前替换后跑 `dart run flutter_launcher_icons`
- **`docs/optional-additions.md`** — 有意不预装的包，以及每个包的「什么时候才该加」

## 许可证

MIT
