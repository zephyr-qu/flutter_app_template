# Flutter 通用脚手架

基于 Flutter 的中小型项目脚手架：**Feature-Sliced Design (FSD)** 目录 + **Riverpod** 状态管理 + `auto_route` / Retrofit / Drift，开箱即用。技术栈以 [`pubspec.yaml`](pubspec.yaml) 为准。

## 特性

- **FSD 功能切片** — 按业务模块组织（`page/` `logic/` `data/`），依赖方向 `app → features → core`
- **状态与依赖都是 provider** — Riverpod 承担状态、装配与生命周期，`AsyncView` 统一三态渲染
- **声明式路由** — `auto_route`，启动页进主框架
- **网络与缓存** — Dio + Retrofit + 重试 + Mock
- **错误处理** — `Result<T, E>` + `Failure` 密封类（只带错误码，文案由 UI 翻译）
- **MD3 主题** — `flex_color_scheme`，亮 / 暗支持

## 目录结构

```
lib/
├── main.dart / bootstrap.dart
├── app/          # 组合根：主题、路由、全局页面（启动页 / 404）
├── core/         # 基础设施：Failure/Result、网络、数据库、主题、共享 UI
└── features/     # home、profile、sample（金标准示例）
```

feature 内三层 `page/` → `logic/` → `data/`；`core/` 不得引用 `features/` / `app/`。完整树与职责见 [directory-structure.md](.trellis/spec/frontend/directory-structure.md)。

## 快速开始

环境要求：Flutter >= 3.47.0（开发与 CI 钉 3.47.5，见 `.fvmrc`）、Dart >= 3.13.0、just >= 1.58.0。

```bash
just deps
just codegen    # 生成物不入库，clone 后必跑
flutter run     # 默认 .env.development，USE_MOCK=true，无需后端
```

### 常用命令

| 命令 | 用途 |
| --- | --- |
| `just` / `just verify` | 完整 5 项门禁，首个失败即停 |
| `just deps` | 解析根工程与 `packages/app_lints` 的依赖 |
| `just fmt` / `just fmt-check` / `just fix` | 格式化 / 只检查 / `dart fix --apply` |
| `just analyze` | 两组 `dart analyze --fatal-infos`（显式文件列表，见门禁） |
| `just test [文件]` | 全部或指定的 Flutter 测试 |
| `just codegen [参数]` / `just codegen-reset` | 增量生成 / 清缓存后全量生成 |
| `just init [参数]` | 交互式或非交互式创建新项目 |
| `just prune [参数]` | 裁剪 l10n 等可选脚手架能力 |

### 环境配置与 Release 构建

`.env` 按环境名加载：`--dart-define=env=xxx` 优先，否则 debug / profile → `development`、release → `production`。

```bash
flutter run --dart-define=env=production
flutter build apk --dart-define=env=production \
  --dart-define=BASE_URL=https://api.your-domain.com
```

三条容易踩的：

- **不要**给 `String.fromEnvironment('env')` 加 `defaultValue` —— release 会跟着加载 `.env.development`，包静默跑在 localhost + mock 上。
- `.env` / `.env.development` / `.env.production` **有意提交**且会打进产物：只放非密钥配置，密钥走 `--dart-define`。
- release 构建有意留白（debug keystore 签名、未 minify、无 flavor、iOS 未签名），发版前按 [docs/release-checklist.md](docs/release-checklist.md) 补齐。

### 代码生成

生成物**不提交**，clone 后先 `just codegen` 才能 analyze / test；改注解（`@freezed` / `@RoutePage` / `@riverpod` / Drift 表）或增删文件后再跑，升级 codegen 包或 SDK 用 `just codegen-reset`。生成物冲突**不要手工 merge**，解决源文件后重跑覆盖。时机表见 [cross-cutting.md](.trellis/spec/cross-cutting.md)。

### 从脚手架创建新项目

```bash
just init                                               # 交互式
just init --yes --name=my_next_app \
  --application-id=com.example.my_next_app              # 非交互
```

### 文案

单语言：中文直接写在 widget 里，没有 ARB。`Failure` 文案集中在 `lib/core/ui/failure_message.dart`，新增 `FailureCode` **不补文案就编译不过**。要加回多语言见 [localization.md](.trellis/spec/frontend/localization.md)。

## 示例模块

新 feature 照 `lib/features/sample/` 写（`home/`、`profile/` 只是骨架页），状态与测试约定见 [state-management.md](.trellis/spec/frontend/state-management.md)。

- **无需后端**：`.env.development` 默认 `USE_MOCK=true`（规则在 `dio_client.dart`）；阅读顺序 `page/` → `logic/` → `data/`
- **删除示例**
  - 删目录：`lib/features/sample/` 与 `test/features/sample/`
  - 清引用
    - 路由 `router.dart`（`SampleListRoute`）
    - mock `dio_client.dart`（`_registerMockRules()`）
    - Tab 与入口 `main_page.dart` / `home_page.dart` / `profile_page.dart`
    - 路由测试 `main_shell_test.dart`
  - 收尾 `just codegen`（连缓存一起删见 [database-guidelines.md](.trellis/spec/backend/database-guidelines.md)）

## 测试

`just test [文件]`（全部或指定文件）。

- 逻辑测试：`ProviderContainer` + `overrides`，模板是 `test/features/sample/logic/sample_list_notifier_test.dart`
- widget 测试：`test/support/app_test_harness.dart` 的 `setUpTestApp()` + `wrapPage(page, container:)`
- 硬约束（不要 `await provider.future`、`retry: noRetry`、mock 消耗命中次数）见 [state-management.md](.trellis/spec/frontend/state-management.md)「Testing Requirements」

## 门禁

`just verify` 一条命令跑完全部 5 项，首个失败即停。

| 项 | 规则 |
| --- | --- |
| `packages/app_lints/`（分析插件） | `core/` 不得 import/export `features/` / `app/`；跨 feature 只共享 `data/`；`logic/` 不得 import `material.dart`；`build` 里不得用 `ref.read` 取值 |
| 其余 | `dart format`、两组 `dart analyze --fatal-infos`（lib+test 与 tool+packages）、插件规则测试、`flutter test` |

`pre-commit` 与 CI 都跑它，根 `justfile` 是唯一命令清单，单项重跑用对应 recipe。analyze **必须显式传文件名**（传目录会丢插件诊断），理由见 [cross-cutting.md](.trellis/spec/cross-cutting.md)。

## 数据流

```
Page (ConsumerWidget) → Notifier → Repository → Service → API (Retrofit)
        ↑ ref.watch        ↕               ↕
        └── AsyncValue ← Result<T, Failure> ← DAO (Drift，缓存旁路)
```

Page 只订阅状态、转事件；跨 feature 只共享 `data/` 与 `core/` 暴露的 provider，不用事件总线。

## 其它

- **`.trellis/spec/`** — 分层规范入口，改某一层之前先读对应 spec
- **`TODO(template)`** — 刻意留空的骨架占位：`grep -rn "TODO(template)" lib/`
- **应用图标** — 默认占位图在 `assets/icon/icon.png`，发版前替换后跑 `dart run flutter_launcher_icons`
- **`docs/optional-additions.md`** — 有意不预装的包，以及每个包的「什么时候才该加」

## 许可证

MIT
