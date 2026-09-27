# Flutter 通用脚手架

一个基于 Flutter 的中小型项目脚手架，采用 **Feature-Sliced Design (FSD)** 架构 + **Signals** 响应式状态管理，集成现代化技术栈，开箱即用。

## ✨ 特性

- **FSD 功能切片** — 按业务模块组织代码（page/logic/data），高内聚低耦合
- **Signals 响应式状态** — 细粒度响应式更新，无需 BuildContext，无 widget 树级重建
- **声明式路由** — `auto_route` 类型安全路由，支持 auth 守卫和参数解析（守卫实时读登录态，会话失效后自动回到登录页）
- **依赖注入** — `injectable` + `GetIt`，注解驱动自动注册
- **网络层封装** — `Dio` + `Retrofit` + 智能重试 + Mock 拦截
- **离线缓存** — 文章接口走「缓存旁路」：成功刷新 Drift 缓存，失败回退缓存，离线仍可阅读
- **认证与令牌** — 访问/刷新令牌存平台安全存储（KeyStore / Keychain）；令牌临近过期时主动刷新，401 时刷新并重放原请求，刷新失败才登出（登出不依赖网络）
- **错误处理** — 统一的 `Result<T, E>` + `Failure` 密封类（携带错误码，文案由 UI 层翻译），`PlatformDispatcher.onError` 兜底
- **MD3 主题** — `flex_color_scheme`，亮/暗主题完整支持
- **单语言** — 用户可见文案直接写中文，没有 ARB / `flutter_localizations`（要加回来看 [localization.md](.trellis/spec/frontend/localization.md)）
- **通用组件** — Loading / Error / Empty 三态组件
- **代码生成** — `freezed` / `json_serializable` / `retrofit`；生成物**不入库**，clone 后跑 `just codegen`
- **架构边界与形态约定** — 由 `packages/app_lints` 的**分析插件**强制：`core/` 不得依赖上层、跨 feature 只共享 `data/`、`logic/` 不得用 `getIt`、取 ViewModel 的页面必须给可选注入点、禁 `AsyncState.map`、注释块 ≤10 行
- **门禁** — `just verify` 一条命令跑完：format / 两步 `dart analyze --fatal-infos` / 依赖声明 / 插件规则测试 / 目录树一致性 / 测试 + **覆盖率门禁**（只统计手写代码、按行数加权，默认阈值 80%）
- **数据库** — `Drift`（SQLite ORM，可选按需使用）
- **测试基础设施** — `mocktail` 模拟，已含 ViewModel / Widget / 数据库测试

## 🛠️ 技术栈

| 类别 | 技术 |
| ------ | ------ |
| 状态管理 | `signals_flutter` `signals_hooks` `flutter_hooks` |
| 路由 | `auto_route` |
| 依赖注入 | `get_it` `injectable` |
| 网络 | `dio` `dio_smart_retry` `retrofit` `pretty_dio_logger` |
| Mock API | `msw_dio_interceptor` |
| 数据库 | `drift` `sqlite3`（原生库由 3.x 的 build hook 提供） |
| 本地存储 | `shared_preferences` `path_provider` `flutter_secure_storage`（令牌走安全存储） |
| 代码生成 | `freezed` `json_serializable` `build_runner` |
| 主题 | `flex_color_scheme` |
| 日志 | `logger` |
| 静态分析 | `very_good_analysis`（规则集）+ `packages/app_lints`（架构边界与形态约定的分析插件） |
| 测试 | `flutter_test` `mocktail` |

## 📁 目录结构

```
lib/
├── main.dart                               # 程序入口
├── bootstrap.dart                          # 启动初始化（环境 + DI + 异常兜底）
│
├── app/                                    # 应用层（组合根：只做装配）
│   ├── app.dart                            # 根组件（主题 + 路由装到一起）
│   ├── routing/                            # 路由配置（组合层）
│   │   ├── router.dart                     # auto_route 配置 + AuthGuard
│   │   ├── router.gr.dart                  # 生成的路由类
│   │   └── auth_reevaluate.dart            # 登录态 → 守卫重评桥接
│   └── pages/                              # 全局页面（不属于任何 feature）
│       ├── splash_page.dart                # 启动页
│       └── not_found_page.dart             # 404
│
├── core/                                   # 基础设施 + 状态耦合的适配层
│   ├── base/                               # Failure / Result / runCatching / runAsync
│   ├── config/                             # NetworkConfig、用户偏好（信号 + 持久化）
│   ├── data/
│   │   ├── database/                       # Drift 连接 + schema + 表
│   │   ├── network/                        # Dio 工厂 / 认证拦截器 / TokenStore 契约
│   │   └── storage/                        # FileStorage、AuthStorage（令牌 / 用户存储）
│   ├── logging/                            # 日志封装 + 调试日志脱敏
│   ├── models/                             # User / TokenSet
│   ├── theme/                              # 色板 / ThemeData 组装 / 设计 token
│   ├── ui/                                 # 共享 UI：AsyncView / EmptyWidget / 错误文案
│   └── core_module.dart                    # 共享依赖的 DI 装配（@module）
│
├── features/                               # 业务功能模块
│   ├── auth/                               # 认证（示例模块）
│   │   ├── logic/                          # ViewModel（信号 + 业务逻辑）
│   │   ├── data/                           # API + Service + Models
│   │   └── page/                           # UI 页面
│   ├── article/                            # 文章（示例模块）
│   ├── demo/                               # 本地存储示例（FileStorage + Drift 缓存）
│   ├── home/                               # 首页
│   └── profile/                            # 个人中心
│
└── di/                                     # 依赖注入注册
    ├── service_locator.dart                 # configureDependencies() 入口
    └── service_locator.config.dart          # injectable 自动生成
```

模块内部每层职责：

| 层 | 目录 | 职责 |
| ---- | ------ | ------ |
| **UI** | `page/` | 页面组件，获取 ViewModel，绑定信号 |
| **Logic** | `logic/` | ViewModel，信号管理，业务编排 |
| **Data** | `data/` | API (Retrofit)，Service，Models (freezed) |

依赖方向：`app → features → core`。`core/` 是基础设施底座，**不得** import `features/` 或 `app/`；`app/` 是组合根，可以 import 任何东西。全局页面（启动页、404）放在 `app/pages/`（而不在 `core/`），所以能用类型安全的路由类导航，不必退回字符串 path。

## 🚀 快速开始

### 环境要求

- Flutter SDK >= 3.44.0（开发与 CI 钉 3.47.5，见 `.fvmrc`）
- Dart SDK >= 3.13.0
- [`just`](https://just.systems) >= 1.58.0（门禁与常用命令的入口）

```bash
just deps       # flutter pub get + 插件包 dart pub get
just codegen    # 生成物不入库，clone 后必跑（详见下）

just run        # = flutter run --dart-define-from-file=.env.example（USE_MOCK=true，无需后端）

just verify     # 全部门禁：format / analyze / 依赖 / 插件规则 / 目录树 / 测试 + 覆盖率
```

### 代码生成（生成物不入库）

生成物**不提交进仓库**：`*.g.dart`、`*.freezed.dart`、`*.gr.dart`、`*.config.dart`、`*.gen.dart`、`app_localizations*`。它们由 `.gitignore` 排除，所以 clone 之后**必须**先 `just codegen`，否则 `dart analyze` / `flutter test` 会因为缺 `part` 与 provider 而失败。

改了注解（`@freezed` / `@JsonSerializable` / `@RoutePage` / `@injectable`、Drift 表）、增删了代码文件之后都要重新生成。CI 在门禁前**现场生成**，所以不存在「忘了提交生成物」这类失败，也没有「生成物与源不一致」的比对。

```bash
just codegen          # 改了注解 / 增删文件
just codegen-reset    # 升级 codegen 包 / SDK 后全量重建（clean + build）
```

生成物冲突时不要手工 merge，解决源文件冲突后重跑 codegen 覆盖。完整策略、重新生成时机表、以及 build_runner 升级与「目录级 cache」的评估结论见 [.trellis/spec/cross-cutting.md](.trellis/spec/cross-cutting.md)「代码生成与生成物」。

### 从脚手架创建新项目

```bash
# 交互式：逐个问包名 / applicationId / iOS Bundle ID / 显示名 / 描述
just init

# 非交互（CI、脚本里用这个）
just init --yes --name=my_next_app --application-id=com.example.my_next_app
```

一次改完：`pubspec.yaml`（`name` / `description`）、全仓库 `package:<旧名>/` 与根组件
类名、Android `namespace` + `applicationId` + `android:label` + `MainActivity.kt`
（连目录一起搬）、iOS `PRODUCT_BUNDLE_IDENTIFIER`（含 `RunnerTests`）与
`CFBundleDisplayName`。

语义是**全有或全无**：先规划、后写盘；任一必改点没匹配到就列出「哪一处没对上」并以
非零退出码结束，不写任何文件。覆盖范围与手工清单见
[.trellis/spec/guides/rename-checklist.md](.trellis/spec/guides/rename-checklist.md)，
回归测试见 `test/tool/init_project_test.dart`（设 `SCAFFOLD_E2E=1` 会真的复制仓库改名
再跑一遍 `flutter analyze`）。

### 环境配置与 release 构建

环境值以**编译期常量**注入（`String.fromEnvironment`），不走 `.env` 文件加载：

```bash
just run                                               # = flutter run --dart-define-from-file=.env.example
flutter run --dart-define-from-file=.env.development   # 自己的那份（已被 .gitignore 忽略）
flutter build apk --dart-define=BASE_URL=https://api.your-domain.com
```

- **只提交 `.env.example`**：它是默认值与示例（`USE_MOCK=true`，无需后端）。真实 `.env*` 不入库。
- 密钥只走 `--dart-define`（不进 git，但仍可从产物提取，敏感场景要放服务端）。
- 缺少 `BASE_URL` 时 `bootstrap()` 会直接抛异常（fail fast），不会静默启动。
- 没有 `dotenv`、也没有 `assets`：不加载文件、不进 `pubspec.yaml` 的 `assets`。
- `just init` 会从 `.env.example` 复制一份 `.env.development` 供你改，默认不用它。
**release 构建有意留白**，属于目标应用的职责，脚手架不做：release 仍用 debug keystore 签名、未开启 minify/混淆、未做 build flavor、iOS 签名需在 Xcode 配置。发版前按 [docs/release-checklist.md](docs/release-checklist.md) 逐项补齐（签名 / 混淆 / 符号表 / 真实 `BASE_URL` / 权限与上报接入点）。

### 文案（单语言）

用户可见文案**直接写中文**，没有 ARB、没有 `AppLocalizations`、没有语言切换（脚手架已用 `tool/prune.dart --l10n=single` 裁掉多语言形态）。

`Failure` 只携带 `FailureCode` 而不带文案，由 `lib/core/ui/failure_message.dart` 统一翻译成中文 —— 因此新增一个 `FailureCode` **不补文案就编译不过**。要加回多语言见 [localization.md](.trellis/spec/frontend/localization.md)（思路是反向做 `prune.dart` 的裁剪面）。

## 📖 示例代码说明

脚手架自带三个完整示例模块，开箱即用（无需后端）：

| 模块 | 路径 | 演示内容 |
|------|------|----------|
| 认证 | `lib/features/auth/` | 登录 → 存令牌（安全存储）→ 401 自动刷新 → 个人中心读取用户信息 |
| 文章 | `lib/features/article/` | 列表页 → 详情页，Retrofit + Drift 离线缓存 + 加载三态 |
| 本地存储 | `lib/features/demo/` | `FileStorage` 文件读写/占用统计 + Drift 缓存填充（入口：个人 → 设置） |

- **开箱即用**：`.env.example` 中 `USE_MOCK=true`，由 `msw_dio_interceptor` 拦截请求（Mock 规则见 `lib/core/data/network/dio_client.dart` 的 `_registerMockRules()`），无需后端即可跑通完整数据流。接入真实后端时把 `USE_MOCK` 改成 `false` 即可
- **学习路径**：`flutter run` 跑起来 → 从 `page/`（UI）→ `logic/`（ViewModel）→ `data/`（API / Service / Model）逐层阅读，新功能模块照此结构复制
- **删除示例**：确认了解结构后，删除 `lib/features/auth/` 与 `lib/features/article/` 两个目录，并同步清理：
  1. `lib/app/routing/router.dart` 中的对应路由与 `@RoutePage` 注解
  2. `lib/core/data/network/dio_client.dart` 中 `_registerMockRules()` 的对应 Mock 规则
  3. `lib/features/home/page/main_page.dart` 底部导航中的文章 Tab
  4. `lib/features/profile/page/profile_page.dart` 中对 `AuthViewModel` / `User` 的引用
  5. 最后执行 `just codegen` 重新生成 DI 注册与路由
- **删除本地存储示例**：用不到 `FileStorage` / Drift 缓存时，删掉 `lib/features/demo/`，再清理两处引用：
  1. `lib/app/routing/router.dart` 中的 `StorageDemoRoute`
  2. `lib/features/profile/page/profile_page.dart` 中「设置」里的示例入口

  （注意 `ArticleService` 的离线缓存仍在使用 `AppDatabase`；要连缓存一起删，见 `.trellis/spec/backend/database-guidelines.md`）

## 🧩 模板占位清单

脚手架刻意留了几处「有 UI、没功能」的位置，全部带 `TODO(template)` 注释，方便一眼分辨哪些是示例骨架、哪些是真接线。`grep -rn "TODO(template)" lib/` 可一次列全。

| 位置 | 现状 | 处理 |
|------|------|------|
| 「设置」→ 通知 / 隐私 / 帮助 | 只有入口，`onTap` 为空 | 替换 `onTap`，或整项删掉（连同其下的 `_Divider`） |
| 首页「最近动态」 | 静态空态占位 | 换成自己的数据源 |
| `.env.example` | 默认值与示例（`BASE_URL` / `USE_MOCK`），会提交；真实 `.env*` 已被 gitignore | 密钥改走 `--dart-define` |
| 应用图标 | `pubspec.yaml` 的 `flutter_launcher_icons.image_path` 指向 `assets/icon/icon.png`，**该文件不存在**（跑图标命令会直接失败） | 补上图标文件，或删掉这段配置 |
| release 构建 | 仍用 debug keystore、未 minify、无 flavor、iOS 未签名 | 见 [docs/release-checklist.md](docs/release-checklist.md) |

## 🧭 需要更多能力时

脚手架**有意不预装**很多东西，但"不预装"不等于"你不知道它们存在"。[docs/optional-additions.md](docs/optional-additions.md) 是一份带「什么时候才该加」触发条件的清单：

- **刚被移除的** —— `shimmer`（骨架屏）、`lottie`（动画）、`flutter_svg`、`flutter_gen`、`device_info_plus`，以及每一个的更轻替代方案
- **脚手架已留好接入点的** —— 崩溃上报 → `bootstrap.dart` 的三个错误钩子、深链 → `AppRouter` 初始路由、原生启动图 → native 层白屏
- **按业务需求查表** —— 权限、相机、分享、WebView、图表、二维码… 并标出哪些其实已内置（`intl` 格式化、`RefreshIndicator`、三态组件）
- **现有选型的替代方案与迁移成本** —— 不想用 signals / auto_route / Drift 时换什么、改动多大
- **不建议提前引入的** —— 第二套状态管理、`fpdart` 之类的 Either、大型 UI 组件库

它还前置了三条判断规则（基础设施 vs 设计选择、成本不对称、从需求出发），用来判断**清单之外**的包该不该加。

## 📐 如何添加新功能模块

### 目录模板

```
features/your_feature/
├── logic/
│   └── your_view_model.dart           # ViewModel（信号 + runAsync）
├── data/
│   ├── models/                        # 数据模型（@freezed）
│   ├── your_api.dart                  # Retrofit API 接口（可选）
│   ├── your_service.dart              # 业务实现
│   └── your_repository.dart           # 仓库抽象接口（按需）
└── page/
    └── your_page.dart                 # UI 页面
```

模板照抄 `lib/features/article/`：`data/`（API / DAO / Service / Repository / models）、
`logic/`（ViewModel）、`page/`（页面）三层的完整写法与对应测试都在那里；命名与「某个文件
该放哪」的裁决见 [.trellis/spec/frontend/directory-structure.md](.trellis/spec/frontend/directory-structure.md)。

## 🧪 测试

```bash
just test                                   # 全部测试
just test test/features/article/logic/article_view_model_test.dart   # 指定文件

just test-coverage && just check-coverage    # 覆盖率数据 + 门禁校验
just test-app-lints                          # 插件包自己的规则测试
```

测试原则：

- ViewModel 测试直接构造，无需 DI：`ArticleViewModel(mockRepo)`
- 使用 `mocktail` 模拟外部依赖
- widget 测试用 `test/support/app_test_harness.dart` 的 `wrapPage()`（负责测试环境：主题等）；生产页面统一是 `HookWidget` + `useSignalValue` + `AsyncView`，`SignalBuilder` 只是可选路线
- 取 ViewModel 的页面直接注入假实例：`LoginPage(viewModel: fakeVm)`，不必 `setUpTestApp()`——注入点的存在由 `page_must_expose_view_model_injection_point` 规则保证

### 覆盖率门禁

`just check-coverage` 读取 `flutter test --coverage` 产出的 lcov，按**手写代码**的行覆盖率与阈值比较：

- 剔除生成文件（`*.g.dart` / `*.freezed.dart` / `*.gr.dart` / `*.config.dart` / `*.gen.dart` / `app_localizations*`）——它们的行数不是人能守的
- 按行数加权，不是按文件平均
- 默认阈值 80%，低于阈值退出码为 1；`just verify` 与 CI 都跑它
- 打开**差集检查**（`--src=lib`）：扫描根下没被这份 lcov 覆盖的手写文件按「0 命中 / 非空行数」计入分母 —— 少了它，一个从没被加载过的新文件不会让阈值下降

```bash
just check-coverage                            # 默认 80%
dart run tool/check_coverage.dart coverage/lcov.info --src=lib --min=85
```

## 🔍 架构边界与代码形态（分析插件）

六条规则由 `packages/app_lints/` 的 **analyzer 插件**实现（`analysis_server_plugin`，声明在根 `analysis_options.yaml` 顶层的 `plugins:`）：

| 规则 | 说明 |
|------|------|
| `no_upper_import_in_core` | `core/**` 不能 import/export `features/**` / `app/**` |
| `cross_feature_only_data` | 跨 feature 只共享 `data/`，不能引用其他 feature 的 `page/` / `logic/` |
| `no_service_locator_in_logic` | `features/*/logic/` 里不能出现 `getIt`，强制构造器注入 |
| `page_must_expose_view_model_injection_point` | 用 `getIt<*ViewModel>()` 的页面要同时给出 `final T? viewModel;`、构造参数 `this.viewModel`、`viewModel ?? getIt<T>()` 兜底 |
| `avoid_async_state_map` | 三态渲染用 `AsyncView`（`map` 的 `error` 回调签名运行期才校验，写错整页红屏） |
| `comment_block_too_long` | 注释块 ≤10 行，超限就把解释搬进 `.trellis/spec/`，代码里只留一行链接 |

判据都是 **AST 级**，正则替代不了：`AsyncState.map` 要看「是否同时带 `data` 与 `error` 两个具名实参」（否则分不清它与 `list.map(...)`，误报会挡住提交）；注释块要看字符偏移（多行字符串里的 `//` 不是注释）。

**`flutter analyze` 不加载插件**，门禁是 `just analyze` 的两步 `dart analyze --fatal-infos`，且**必须显式传文件名**——传目录不报错、只是静默少跑规则。实现见 `packages/app_lints/lib/src/rules.dart`，正反例见它的 `test/rules_test.dart`；`test/tool/self_package_prefix_test.dart` 专门盯「包名前缀与 `pubspec.name` 不同步 → 规则静默失效」。

组合根（`lib/app/`）可以引用任何 feature——FSD 的 app 层负责装配。
`page_must_expose_view_model_injection_point` 不是依赖方向，是可测性约定（[ADR-0001](docs/adr/ADR-0001.md) 的缓解措施）：页面仍从容器取 ViewModel，但必须给测试留一个注入口，否则页面测试只能装配全局容器。`home_page` / `profile_page` 直接取 `AuthStorage` / `UserPreferences`（不是 ViewModel），不在此列。

## 🔧 开发工具

- **`.trellis/spec/`** — 项目规范入口（架构与目录、数据层、状态管理、组件、注释与文档约定）；改某一层的代码前先读对应的 spec
- **`justfile`** — 唯一命令清单（`deps` / `fmt` / `analyze` / `test` / `verify` / `codegen` / `init` / `prune`）
- **`packages/app_lints/`** — 架构边界与代码形态的分析插件（见上）
- **`tool/init_project.dart`** — 项目初始化，改包名 / `namespace` / iOS Bundle ID / 显示名（`just init`，交互或 `--yes` 非交互）
- **`tool/check_coverage.dart`** — 覆盖率门禁（见上）
- **`tool/check_readme_tree.dart`** — 校验文档里的 `lib/` 目录树与实际文件一致（见下）
- **`tool/prune.dart`** — 正交裁剪（如 `--l10n=single`）
- **`.githooks/pre-commit`** — 提交前跑 `just verify`（首个失败即停）。安装：`git config core.hooksPath .githooks`
- **`msw_dio_interceptor`** — 开发期 API Mock 拦截器

## 🎨 架构原则

### 数据流

```
Page (UI) → ViewModel → Service → API (Retrofit)
                ↕              ↕
            signals         Result<T, Failure>
                ↕
          Widget rebuild
```

- **View Model**：通过构造器注入依赖，管理信号，调用 `runAsync` 处理异步三态
- **Service**：业务逻辑实现，返回 `Result<T, Failure>`
- **Page**：通过 `getIt` 获取 ViewModel，用 `useSignalValue` 绑定信号，不写业务逻辑

### Feature 间通信

- 跨 feature 数据共享通过 `core/data/storage/` 中的全局信号
- 不使用事件总线（调试困难）
- 不引用其他 feature 的 `page/` 或 `logic/`（lint 规则强制）

## 📄 许可证

MIT
