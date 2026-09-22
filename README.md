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
- **国际化** — `flutter_localizations` + ARB，内置中文/英文，设置里可切换并持久化
- **通用组件** — Loading / Error / Empty 三态组件
- **代码生成** — `freezed` / `json_serializable` / `retrofit_generator`
- **架构边界检查** — `tool/check_boundaries.dart`（core 不得依赖上层、跨 feature 只共享 data 层、ViewModel 不得用 getIt、页面必须给可选注入点），跑在 pre-commit 与 CI
- **代码形态约定** — `tool/check_conventions.dart`（禁用 `AsyncState.map`、注释块 ≤10 行），同样跑在 pre-commit 与 CI
- **覆盖率门禁** — `tool/check_coverage.dart`，只统计手写代码、按行数加权，默认阈值 80%，同样是 pre-commit 与 CI 的一道门
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
| 静态分析 | `very_good_analysis`（规则集）+ `tool/check_boundaries.dart` / `tool/check_conventions.dart`（架构边界与形态约定） |
| 测试 | `flutter_test` `mocktail` |

## 📁 目录结构

```
lib/
├── main.dart                               # 程序入口
├── bootstrap.dart                          # 启动初始化（环境 + DI + 异常兜底）
│
├── app/                                    # 应用层（组合根：只做装配）
│   ├── app.dart                            # 根组件（主题 + 路由 + l10n 装到一起）
│   ├── routing/                            # 路由配置（组合层）
│   │   ├── router.dart                     # auto_route 配置 + AuthGuard
│   │   ├── router.gr.dart                  # 生成的路由类
│   │   └── auth_reevaluate.dart            # 登录态 → 守卫重评桥接
│   └── pages/                              # 全局页面（不属于任何 feature）
│       ├── splash_page.dart                # 启动页
│       └── not_found_page.dart             # 404
│
├── core/                                   # 共享基础设施（精简克制）
│   ├── base/                               # 基础抽象
│   │   ├── result.dart                     # Result<T, E> 统一结果类型
│   │   ├── failure.dart                    # Failure 密封类
│   │   ├── run_async.dart                  # runAsync 三态助手
│   │   └── run_catching.dart               # runCatching：异常 → Failure 兜底
│   ├── config/                             # 应用配置
│   │   ├── network_config.dart             # 环境变量（只读值对象）
│   │   └── user_preferences.dart           # 用户偏好（信号 + 持久化）
│   ├── data/
│   │   ├── database/                       # Drift 数据库连接
│   │   ├── network/                        # Dio 客户端 + 拦截器
│   │   └── storage/                        # 本地持久化信号
│   ├── logging/                            # 日志封装
│   ├── models/                             # 跨 feature 共享的数据模型（User 等）
│   ├── ui/                                 # 共享 UI（与 theme/ 并列）
│   │   ├── async_view.dart                 # AsyncState → Widget（三态渲染入口）
│   │   ├── failure_message.dart            # FailureCode → 用户文案
│   │   ├── loading_indicator.dart          # LoadingIndicator / ScreenLoadingIndicator
│   │   ├── error_text.dart                 # 错误 + 重试
│   │   └── empty_widget.dart               # 空状态
│   ├── theme/                              # 主题（色板 / 组装 / token）
│   │   ├── app_color_scheme.dart           # 品牌色板 + 语义色覆盖
│   │   ├── app_theme.dart                  # 组装 ThemeData（对外唯一入口）
│   │   └── app_theme_extension.dart        # 设计 token（圆角/间距）
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
├── l10n/                                   # 国际化文案（ARB + 生成物）
│   ├── app_zh.arb                          #   模板语言：中文
│   └── app_en.arb                          #   第二语言：英文
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

- Flutter SDK >= 3.44.0
- Dart SDK >= 3.13.0

```bash
# 安装依赖
flutter pub get

# 代码生成（生成物已提交进仓库；改了注解 / 模型后再跑一次即可）
dart run build_runner build --delete-conflicting-outputs
flutter gen-l10n        # 只在改了 lib/l10n/*.arb 时需要

# 运行
flutter run

# 代码分析
flutter analyze

# 运行测试
flutter test
```

### 代码生成（生成物提交策略）

生成物是**提交进仓库**的：`*.g.dart`、`*.freezed.dart`、`*.gr.dart`、`*.config.dart`、`lib/l10n/app_localizations*.dart`。所以 clone 之后不跑 codegen 也能 `flutter analyze` / `flutter test`。

改了注解（`@freezed` / `@JsonSerializable` / `@RoutePage` / `@injectable`、Drift 表）、增删了代码文件，或升级了任一 codegen 依赖之后，**必须重新生成并把生成物一起提交**——CI 会跑一遍 `build_runner build` 再比对 `git diff`，漏提交直接红（`analyze` job 的 `Check generated code is up to date`）。

```bash
dart run build_runner build --delete-conflicting-outputs   # 改了注解 / 增删文件
flutter gen-l10n                                          # 改了 lib/l10n/*.arb
dart run build_runner clean && dart run build_runner build -d  # 升级 codegen 包 / SDK 后全量重建
```

生成物冲突时不要手工 merge，解决源文件冲突后重跑 codegen 覆盖。完整策略、重新生成时机表、以及 build_runner 升级与「目录级 cache」的评估结论见 [.trellis/spec/cross-cutting.md](.trellis/spec/cross-cutting.md)「代码生成与生成物」。

### 从脚手架创建新项目

```bash
# 交互式：逐个问包名 / applicationId / iOS Bundle ID / 显示名 / 描述
dart run tool/init_project.dart

# 非交互（CI、脚本里用这个）
dart run tool/init_project.dart --yes --name=my_next_app \
  --application-id=com.example.my_next_app
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

`.env` 文件按「环境名」加载，环境名的解析优先级：

1. `--dart-define=env=xxx`（显式指定，发版脚本 / CI 用这个）
2. 构建模式默认值：debug / profile → `development`，release → `production`

```bash
flutter run                                                        # 加载 .env.development（USE_MOCK=true，无需后端）
flutter run --dart-define=env=production                           # 加载 .env.production
flutter build apk --dart-define=env=production \
  --dart-define=BASE_URL=https://api.your-domain.com               # 真实地址建议这样传
```

需要注意：

- **不要**改成 `String.fromEnvironment('env', defaultValue: 'development')`——那会让 release 也加载 `.env.development`，包静默跑在 localhost + mock 上，界面正常但数据全假。
- `.env` / `.env.development` / `.env.production` 是**有意提交**的（`pubspec.yaml` 的 `assets` 里列着它们，会随包打进产物），**没有**被 `.gitignore` 忽略——不要把它们加回忽略列表，那只会让「本地改了以为不会提交」的误解一直存在。也正因如此，它们**只能放非密钥配置**（`BASE_URL`、`USE_MOCK`）；密钥写进去既会进 git，也能从 apk 里提取，只能走 `--dart-define`。
- `.env.example` 只是模板（`tool/init_project.dart` 会拿它生成 `.env.development`），**运行时不会被加载**——加载的永远是 `.env.<环境名>`。
- 缺少 `BASE_URL` 时 `bootstrap()` 会直接抛异常（fail fast），不会静默启动。

**release 构建有意留白**，属于目标应用的职责，脚手架不做：release 仍用 debug keystore 签名、未开启 minify/混淆、未做 build flavor、iOS 签名需在 Xcode 配置。发版前按 [docs/release-checklist.md](docs/release-checklist.md) 逐项补齐（签名 / 混淆 / 符号表 / 真实 `BASE_URL` / 权限与上报接入点）。

### 国际化

文案放在 `lib/l10n/app_zh.arb`（模板语言：中文）与 `app_en.arb`，生成 `AppLocalizations`；`l10n.yaml` 是配置，生成物 `lib/l10n/app_localizations*.dart` 不要手改。

```dart
final l10n = AppLocalizations.of(context);
Text(l10n.loginButton);
```

「个人 → 设置 → 语言」可切换跟随系统 / 中文 / English，结果持久化到 `app.locale`，切换后界面立即生效。新增文案先加 `app_zh.arb` 再补 `app_en.arb`（`test/l10n/` 会校验两边 key 对齐）。

错误提示同样走 l10n：`Failure` 只携带 `FailureCode` 而不带文案，由展示层按当前语言翻译，所以切到英文后错误提示也是英文。

## 📖 示例代码说明

脚手架自带三个完整示例模块，开箱即用（无需后端）：

| 模块 | 路径 | 演示内容 |
|------|------|----------|
| 认证 | `lib/features/auth/` | 登录 → 存令牌（安全存储）→ 401 自动刷新 → 个人中心读取用户信息 |
| 文章 | `lib/features/article/` | 列表页 → 详情页，Retrofit + Drift 离线缓存 + 加载三态 |
| 本地存储 | `lib/features/demo/` | `FileStorage` 文件读写/占用统计 + Drift 缓存填充（入口：个人 → 设置） |

- **开箱即用**：`.env.development` 中 `USE_MOCK=true`，由 `msw_dio_interceptor` 拦截请求（Mock 规则见 `lib/core/data/network/dio_client.dart` 的 `_registerMockRules()`），无需后端即可跑通完整数据流。接入真实后端时把 `USE_MOCK` 改成 `false` 即可
- **学习路径**：`flutter run` 跑起来 → 从 `page/`（UI）→ `logic/`（ViewModel）→ `data/`（API / Service / Model）逐层阅读，新功能模块照此结构复制
- **删除示例**：确认了解结构后，删除 `lib/features/auth/` 与 `lib/features/article/` 两个目录，并同步清理：
  1. `lib/app/routing/router.dart` 中的对应路由与 `@RoutePage` 注解
  2. `lib/core/data/network/dio_client.dart` 中 `_registerMockRules()` 的对应 Mock 规则
  3. `lib/features/home/page/main_page.dart` 底部导航中的文章 Tab
  4. `lib/features/profile/page/profile_page.dart` 中对 `AuthViewModel` / `User` 的引用
  5. 最后执行 `dart run build_runner build` 重新生成 DI 注册
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
| `.env*` 三个文件 | 只放非密钥配置（`BASE_URL` / `USE_MOCK`），会提交并打进产物 | 密钥改走 `--dart-define` |
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

### ViewModel 模板

```dart
@injectable
class YourViewModel {
  final YourService _service;

  YourViewModel(this._service);

  final items = asyncSignal<List<Item>>(AsyncState.data([]));

  Future<void> load() async {
    await runAsync(items, () => _service.getItems());
  }
}
```

### 页面模板

```dart
@RoutePage()
class YourPage extends HookWidget {
  /// 可选注入点——只有测试会传值（ADR-0001；漏了会被 check_boundaries 规则 4 拦）
  final YourViewModel? viewModel;

  const YourPage({super.key, this.viewModel});

  @override
  Widget build(BuildContext context) {
    final vm = useMemoized(() => viewModel ?? getIt<YourViewModel>());
    final async = useSignalValue(vm.items);

    useEffect(() {
      vm.load();
      return null;
    }, []);

    return Scaffold(
      body: AsyncView<List<Item>>(
        state: async,
        loading: () => const LoadingIndicator(),
        error: (Object error, StackTrace stackTrace) =>
            ErrorText(error: error, onRetry: vm.load),
        data: (items) => ListView.builder(/* ... */),
      ),
    );
  }
}
```

## 🧪 测试

```bash
# 全部测试
flutter test

# 特定测试文件
flutter test test/features/article/logic/article_view_model_test.dart

# 覆盖率数据 + 门禁校验
flutter test --coverage
dart run tool/check_coverage.dart
```

测试原则：

- ViewModel 测试直接构造，无需 DI：`ArticleViewModel(mockRepo)`
- 使用 `mocktail` 模拟外部依赖
- widget 测试用 `test/support/app_test_harness.dart` 的 `wrapPage()`（负责挂 l10n delegate 与主题）；生产页面统一是 `HookWidget` + `useSignalValue` + `AsyncView`，`SignalBuilder` 只是可选路线
- 取 ViewModel 的页面直接注入假实例：`LoginPage(viewModel: fakeVm)`，不必 `setUpTestApp()`——注入点的存在由 `tool/check_boundaries.dart` 规则 4 保证

### 覆盖率门禁

`tool/check_coverage.dart` 读取 `flutter test --coverage` 产出的 lcov，按**手写代码**的行覆盖率与阈值比较：

- 剔除生成文件（`*.g.dart` / `*.freezed.dart` / `*.gr.dart` / `*.config.dart` / `*.gen.dart` / `app_localizations*`）——它们的行数不是人能守的
- 按行数加权，不是按文件平均
- 默认阈值 80%，低于阈值退出码为 1；已接入 pre-commit 与 CI 的 `unit-test` job

```bash
dart run tool/check_coverage.dart          # 默认 80%
dart run tool/check_coverage.dart --min=85
```

## 🔍 架构边界检查

边界规则由一个脚本执行（**不是** analyzer 插件——插件规则只在 IDE 生效，CLI/CI 跑不到）：

```bash
dart run tool/check_boundaries.dart
```

已接入 pre-commit 与 CI 的 `analyze` job，`flutter test` 里也有一条针对真实仓库的回归测试。

| 规则 | 说明 |
|------|------|
| core 不得依赖上层 | `core/**` 不能 import `features/**` / `app/**` |
| 跨 feature 只共享 data 层 | 不能引用其他 feature 的 `page/` / `logic/` |
| ViewModel 不得用 service locator | `features/*/logic/` 里不能出现 `getIt`，强制构造器注入 |
| 页面必须给可选注入点 | 用 `getIt<*ViewModel>()` 的页面要同时给出 `final T? viewModel;`、构造参数 `this.viewModel`、`viewModel ?? getIt<T>()` 兜底 |

组合根（`lib/app/`）可以引用任何 feature——FSD 的 app 层负责装配。
最后一条不是依赖方向，是可测性约定（[ADR-0001](docs/adr/ADR-0001.md) 的缓解措施）：页面仍从容器取 ViewModel，但必须给测试留一个注入口，否则页面测试只能装配全局容器。`home_page` / `profile_page` 直接取 `AuthStorage` / `UserPreferences`（不是 ViewModel），不在此列。

## 📏 代码形态约定

边界脚本管「谁能依赖谁」，`tool/check_conventions.dart` 管「代码写成什么样」：

```bash
dart run tool/check_conventions.dart
```

| 规则 | 说明 |
|------|------|
| 禁用 `AsyncState.map` | 三态渲染用 `AsyncView`（`map` 的 `error` 回调签名运行期才校验，写错整页红屏） |
| 注释块 ≤10 行 | 超限就把解释搬进 `.trellis/spec/`，代码里只留一行链接（口径见 `.trellis/spec/guides/comment-guidelines.md`） |

它用 `package:analyzer` 的 `parseString` 判 AST 而不是正则：`AsyncState.map` 的判据是「同时带 `data` 与 `error` 两个具名实参」，正则分不清它和 `list.map(...)`，而误报会挡住提交。已接入 pre-commit 与 CI 的 `analyze` job。

## 🔧 开发工具

- **`.trellis/spec/`** — 项目规范入口（架构与目录、数据层、状态管理、组件、注释与文档约定）；改某一层的代码前先读对应的 spec
- **代码生成** — 生成物提交入库 + 重生成时机 + CI 漂移检查；build_runner 升级与 codegen 缓存评估见 `.trellis/spec/cross-cutting.md`
- **`tool/init_project.dart`** — 项目初始化，改包名 / `namespace` / iOS Bundle ID / 显示名（交互或 `--yes` 非交互）
- **`tool/check_boundaries.dart`** — 架构边界检查（见上）
- **`tool/check_conventions.dart`** — 代码形态约定检查（见上）
- **`.githooks/pre-commit`** — 提交前跑一组检查（格式、架构边界、形态约定、目录树一致性、依赖声明、analyze、覆盖率门禁…），清单以脚本本身为准。安装：`git config core.hooksPath .githooks`
- **`tool/check_readme_tree.dart`** — 校验文档里的 `lib/` 目录树与实际文件一致（见下）
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
