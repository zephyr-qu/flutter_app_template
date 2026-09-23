# Flutter 通用脚手架

一个基于 Flutter 的中小型项目脚手架，采用 **Feature-Sliced Design (FSD)** 架构 + **Riverpod** 状态管理，集成现代化技术栈，开箱即用。

> **这是 `preset/ai-starter` 分支**：状态管理、依赖注入与页面组合三件事换成了 AI 语料最丰富的 Riverpod 栈，
> 面向「AI 打开仓库就能照着写」的目标。它与 `master`（signals 栈）是**兄弟分支，不互相合并**，
> 理由与改动清单一律在 `BRANCH.md`（阶段 8 产出）。

## ✨ 特性

- **FSD 功能切片** — 按业务模块组织代码（page/logic/data），高内聚低耦合
- **Riverpod 状态与依赖** — provider 同时承担状态、装配与生命周期；没有 `lib/di/`，没有 get_it
- **声明式路由** — `auto_route` 类型安全路由，支持 auth 守卫和参数解析（守卫实时读登录态，会话失效后自动回到登录页）
- **网络层封装** — `Dio` + `Retrofit` + 智能重试 + Mock 拦截
- **离线缓存** — 示例接口走「缓存旁路」：成功刷新 Drift 缓存，失败回退缓存，离线仍可读取
- **认证与令牌** — 访问/刷新令牌存平台安全存储（KeyStore / Keychain）；令牌临近过期时主动刷新，401 时刷新并重放原请求，刷新失败才登出（登出不依赖网络）
- **错误处理** — 统一的 `Result<T, E>` + `Failure` 密封类（携带错误码，文案由 UI 层翻译），`PlatformDispatcher.onError` 兜底
- **MD3 主题** — `flex_color_scheme`，亮/暗主题完整支持
- **通用组件** — Loading / Error / Empty 三态组件（`AsyncView` 统一三态渲染入口）
- **代码生成** — `freezed` / `json_serializable` / `retrofit_generator` / `riverpod_generator`
- **架构边界检查** — `tool/check_boundaries.dart`（core 不得依赖上层、跨 feature 只共享 data 层、logic 不得手动建容器 / 不得 import material、`app_core` 不得依赖状态管理），跑在 pre-commit 与 CI
- **代码形态约定** — `tool/check_conventions.dart`（build 里禁用 `ref.read` 取值、注释块 ≤10 行），同样跑在 pre-commit 与 CI
- **覆盖率门禁** — `tool/check_coverage.dart`，只统计手写代码、按行数加权，默认阈值 80%，同样是 pre-commit 与 CI 的一道门
- **数据库** — `Drift`（SQLite ORM，可选按需使用）
- **测试基础设施** — `mocktail` 模拟，已含 Notifier / Widget / 数据库测试

## 🛠️ 技术栈

| 类别 | 技术 |
| ------ | ------ |
| 状态管理 | `flutter_riverpod` `riverpod_annotation` `riverpod_generator` |
| 依赖注入 | Riverpod provider（无独立容器 / 无 `lib/di/`） |
| 路由 | `auto_route` |
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
├── bootstrap.dart                          # 启动初始化（环境 + ProviderScope + 异常兜底）
│
├── app/                                    # 应用层（组合根：只做装配）
│   ├── app.dart                            # 根组件（主题 + 路由装到一起）
│   ├── providers.dart                      # 组合根自己的 provider（AppRouter 等）
│   ├── routing/                            # 路由配置（组合层）
│   │   ├── router.dart                     # auto_route 配置 + AuthGuard
│   │   ├── router.gr.dart                  # 生成的路由类
│   │   └── auth_reevaluate.dart            # 登录态 → 守卫重评桥接
│   └── pages/                              # 全局页面（不属于任何 feature）
│       ├── splash_page.dart                # 启动页
│       └── not_found_page.dart             # 404
│
├── core/                                   # 只剩「状态耦合的适配层」（基础设施已抽到 packages/app_core）
│   ├── auth/
│   │   └── session.dart                    # 登录态 provider（AuthStorage.userChanges 的镜像）
│   ├── config/
│   │   ├── app_settings.dart               # 偏好快照 + Notifier（主题 / 调试日志 / 页大小）
│   │   └── user_preferences.dart           # 偏好的裸存储（读写 SharedPreferences）
│   ├── data/
│   │   ├── network/
│   │   │   └── dio_client.dart             # Dio 的 provider 装配 + 应用专属 Mock 规则
│   │   └── storage/
│   │       └── auth_storage.dart           # 令牌/用户存储（实现 app_core 的 TokenStore）
│   ├── providers.dart                      # 基础设施 provider（prefs / 安全存储 / 数据库 / 文件）
│   └── ui/                                 # 共享 UI（要读项目文案与主题，故留应用侧）
│       ├── async_view.dart                 # AsyncValue → Widget（三态渲染入口）
│       ├── failure_message.dart            # FailureCode → 用户文案
│       ├── loading_indicator.dart          # LoadingIndicator / ScreenLoadingIndicator
│       └── error_text.dart                 # 错误 + 重试
│
└── features/                               # 业务功能模块
    ├── auth/                               # 认证（示例模块）
    │   ├── logic/                          # Notifier（状态 + 业务逻辑）
    │   ├── data/                           # API + Service + Models
    │   └── page/                           # UI 页面
    ├── home/                               # 首页 + 主框架
    ├── profile/                            # 个人中心
    └── sample/                             # 金标准示例（retrofit / drift / Result 三种 data 形态）
```

与状态管理无关的基础设施抽到了本地包，由 signals 栈与 Riverpod 栈共用
（拆分依据见 `.trellis/tasks/09-22-extract-app-core/design.md`）：

```
packages/app_core/lib/
├── base/                               # Failure / Result / runCatching
├── config/                             # NetworkConfig（环境变量值对象）
├── data/
│   ├── database/                       # Drift 连接 + schema + 表
│   ├── network/                        # Dio 工厂 / 认证拦截器 / TokenStore 契约
│   └── storage/                        # FileStorage
├── logging/                            # 日志封装 + 调试日志脱敏
├── models/                             # User / TokenSet
├── theme/                              # 色板 / ThemeData 组装 / 设计 token
└── ui/                                 # 无业务文案的共享组件（EmptyWidget）
```

模块内部每层职责：

| 层 | 目录 | 职责 |
| ---- | ------ | ------ |
| **UI** | `page/` | 页面组件（`ConsumerWidget`），`ref.watch` 状态，转事件给 Notifier |
| **Logic** | `logic/` | Notifier（`@riverpod`），状态 + 业务编排 |
| **Data** | `data/` | API (Retrofit)，Service，Models (freezed)，DAO (Drift) |

依赖方向：`app → features → core`。`core/` 是基础设施底座，**不得** import `features/` 或 `app/`；`app/` 是组合根，可以 import 任何东西。全局页面（启动页、404）放在 `app/pages/`（而不在 `core/`），所以能用类型安全的路由类导航，不必退回字符串 path。

## 🚀 快速开始

### 环境要求

- Flutter SDK >= 3.44.0（开发与 CI 钉 3.47.5，见 `.fvmrc`）
- Dart SDK >= 3.13.0

```bash
# 安装依赖
flutter pub get

# 代码生成（生成物已提交进仓库；改了注解 / 模型后再跑一次即可）
dart run build_runner build --delete-conflicting-outputs

# 运行
flutter run

# 代码分析
flutter analyze

# 运行测试
flutter test
```

### 代码生成（生成物提交策略）

生成物是**提交进仓库**的：`*.g.dart`（含 `@riverpod` 生成的 provider）、`*.freezed.dart`、`*.gr.dart`。所以 clone 之后不跑 codegen 也能 `flutter analyze` / `flutter test`。

改了注解（`@freezed` / `@JsonSerializable` / `@RoutePage` / `@riverpod`、Drift 表）、增删了代码文件，或升级了任一 codegen 依赖之后，**必须重新生成并把生成物一起提交**——CI 会跑一遍 `build_runner build` 再比对 `git diff`，漏提交直接红（`analyze` job 的 `Check generated code is up to date`）。

```bash
# 根工程
dart run build_runner build --delete-conflicting-outputs
# 共享包（独立 package，根目录的 build_runner 不会碰它）
(cd packages/app_core && dart run build_runner build --delete-conflicting-outputs)
# 升级 codegen 包 / SDK 后全量重建
dart run build_runner clean && dart run build_runner build -d
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

### 文案与多语言

本分支是**单语言**（中文文案直接写在 widget 里），没有 ARB / `AppLocalizations`：这是
`tool/prune.dart --l10n=single` 有意裁剪的结果。`Failure` 的用户文案集中在
`lib/core/ui/failure_message.dart` 的 `switch` 常量表，新增 `FailureCode` 时**不补文案就编译不过**。

要加回多语言时的步骤（以及为什么它是一条命令而不是一个分支）见
[.trellis/spec/frontend/localization.md](.trellis/spec/frontend/localization.md)。

## 📖 示例代码说明

脚手架自带两个可照抄的示例模块，开箱即用（无需后端）：

| 模块 | 路径 | 演示内容 |
|------|------|----------|
| 认证 | `lib/features/auth/` | 登录 → 存令牌（安全存储）→ 401 自动刷新 → 个人中心读取用户信息 |
| 示例 | `lib/features/sample/` | 列表页（`ConsumerWidget` + `AsyncView`）→ Retrofit + Drift 缓存旁路 + provider 装配，**新增 feature 时照抄它** |

另外 `home/`（首页 + 主框架）与 `profile/`（个人中心 / 设置）是可运行但更偏骨架的页面。

- **开箱即用**：`.env.development` 中 `USE_MOCK=true`，由 `msw_dio_interceptor` 拦截请求（Mock 规则见 `lib/core/data/network/dio_client.dart` 的 `_registerMockRules()`），无需后端即可跑通完整数据流。接入真实后端时把 `USE_MOCK` 改成 `false` 即可
- **学习路径**：`flutter run` 跑起来 → 从 `features/sample/page/`（UI）→ `logic/`（Notifier）→ `data/`（API / Service / DAO / Model）逐层阅读
- **删除示例**：确认了解结构后，删掉 `lib/features/sample/` 与它的测试，并同步清理：
  1. `lib/app/routing/router.dart` 中的 `SampleListRoute`
  2. `lib/core/data/network/dio_client.dart` 中 `_registerMockRules()` 的 `/sample-items` 规则
  3. `lib/features/home/page/main_page.dart` 底部导航中的「示例」Tab
  4. `lib/features/home/page/home_page.dart` 的「示例」快捷入口
  5. 最后执行 `dart run build_runner build` 重新生成路由与 provider

  （`SampleService` 的缓存旁路仍在用 `AppDatabase`；要连缓存一起删，见
  [.trellis/spec/backend/database-guidelines.md](.trellis/spec/backend/database-guidelines.md)）

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
- **按业务需求查表** —— 权限、相机、分享、WebView、图表、二维码… 并标出哪些其实已内置（`RefreshIndicator`、三态组件）
- **现有选型的替代方案与迁移成本** —— 不想用 riverpod / auto_route / Drift 时换什么、改动多大
- **不建议提前引入的** —— 第二套状态管理、`fpdart` 之类的 Either、大型 UI 组件库

它还前置了三条判断规则（基础设施 vs 设计选择、成本不对称、从需求出发），用来判断**清单之外**的包该不该加。

## 📐 如何添加新功能模块

**结构照抄 `features/sample/`** —— 它是金标准。下面是同样的形状。

### 目录模板

```
features/your_feature/
├── logic/
│   └── your_notifier.dart             # @riverpod Notifier / AsyncNotifier
├── data/
│   ├── models/                        # 数据模型（@freezed）
│   ├── your_api.dart                  # Retrofit API 接口（可选）
│   ├── your_service.dart              # 业务实现
│   ├── your_providers.dart            # 数据层 provider 装配
│   └── your_repository.dart           # 仓库抽象接口（按需）
└── page/
    └── your_page.dart                 # UI 页面（ConsumerWidget）
```

### Notifier 模板（异步数据）

```dart
// logic/sample_list_notifier.dart 的形状
part 'your_notifier.g.dart';

@riverpod
class YourNotifier extends _$YourNotifier {
  @override
  Future<List<YourItem>> build() async {
    final result = await ref.watch(yourRepositoryProvider).getItems();

    // 失败时抛 Failure 本身：AsyncValue.error 要带着它，ErrorText 才翻译得出错误码
    return switch (result) {
      Ok<List<YourItem>, Failure>(:final data) => data,
      Err<List<YourItem>, Failure>(:final error) => throw error,
    };
  }
}
```

同步状态（表单这类）用 `LoginNotifier` 的形状：`build()` 返回一个不可变快照，写入走方法。

### 页面模板

```dart
@RoutePage()
class YourPage extends ConsumerWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = ref.watch(yourProvider);   // 注意 provider 名：类名去掉 Notifier 后缀

    return Scaffold(
      appBar: AppBar(title: const Text('标题')),
      body: AsyncView<List<YourItem>>(
        state: items,
        loading: () => const LoadingIndicator(),
        error: (error, stackTrace) => ErrorText(
          error: error,
          onRetry: () => ref.invalidate(yourProvider),
        ),
        data: (list) => RefreshIndicator(
          onRefresh: () => ref.refresh(yourProvider.future),
          child: /* 列表 / 空态，两者都要可滚动 */,
        ),
      ),
    );
  }
}
```

页面**不需要**任何注入点构造参数：测试用 `ProviderScope(overrides:)` 换实现。

## 🧪 测试

```bash
# 全部测试
flutter test

# 特定测试文件
flutter test test/features/sample/logic/sample_list_notifier_test.dart

# 共享包的测试（独立 package，必须进包目录跑）
cd packages/app_core && flutter test

# 覆盖率数据 + 门禁校验
flutter test --coverage
(cd packages/app_core && flutter test --coverage)
dart run tool/check_coverage.dart coverage/lcov.info packages/app_core/coverage/lcov.info \
  --src=lib --src=packages/app_core/lib
```

测试原则：

- 逻辑测试用 `ProviderContainer` + `overrides` 注入假仓库（`test/features/sample/logic/sample_list_notifier_test.dart` 是模板），不需要任何全局注册表
- 使用 `mocktail` 模拟外部依赖
- widget 测试用 `test/support/app_test_harness.dart` 的 `setUpTestApp()` + `wrapPage(page, container:)`；页面统一是 `ConsumerWidget` + `ref.watch` + `AsyncView`
- widget 测试的三条硬约束：不要 `await provider.future`（假时钟下会挂到超时）、容器传 `retry: noRetry`、`mocktail` 的 `verify` 会消耗命中次数（见 [.trellis/spec/frontend/state-management.md](.trellis/spec/frontend/state-management.md)「Testing Requirements」）

### 覆盖率门禁

`tool/check_coverage.dart` 读取 `flutter test --coverage` 产出的 lcov，按**手写代码**的行覆盖率与阈值比较：

- 剔除生成文件（`*.g.dart` / `*.freezed.dart` / `*.gr.dart` / `*.config.dart` / `*.gen.dart` / `app_localizations*`）——它们的行数不是人能守的
- 按行数加权，不是按文件平均
- 默认阈值 80%，低于阈值退出码为 1；已接入 pre-commit 与 CI 的 `unit-test` job

```bash
dart run tool/check_coverage.dart          # 默认 80%，只查 coverage/lcov.info
dart run tool/check_coverage.dart --min=85
```

**必须采集两份 lcov**：`app_core` 是独立 package，根工程跑 `--coverage` 时包内文件的命中不会被
归集（根 lcov 里一条 `packages/` 记录都没有），只能在包目录里单独跑一次。两份**逐份独立校验、
不合并**：路径都是相对各自包根的 `lib/...`，合并会搅在一起；包内的低覆盖也不该被 `lib/` 稀释。

## 🔍 架构边界检查

边界规则由一个脚本执行（**不是** analyzer 插件——插件规则只在 IDE 生效，CLI/CI 跑不到）：

```bash
dart run tool/check_boundaries.dart          # 默认扫 lib 与 packages/app_core/lib
```

已接入 pre-commit 与 CI 的 `analyze` job，`flutter test` 里也有一条针对真实仓库的回归测试。

| 规则 | 说明 |
|------|------|
| core 不得依赖上层 | `core/**` 不能 import `features/**` / `app/**` |
| 跨 feature 只共享 data 层 | 不能引用其他 feature 的 `page/` / `logic/` |
| logic 不得手动建容器 | `features/*/logic/` 里不能出现 `ProviderContainer(...)`，依赖从 `ref` 或构造器取 |
| logic 不得依赖 Flutter UI | `features/*/logic/` 不能 import `package:flutter/material.dart` |
| app_core 不得依赖状态管理 | `packages/app_core` 里不能出现 `signals_*` / `riverpod*` / `get_it` / `injectable` |

**扫描根是两处**：`lib` 与 `packages/app_core/lib`。抽包之后只扫 `lib/` 的话，新包就成了边界真空。
最后一条是共享包的**存在前提**——包里一旦出现 signals / Riverpod，另一个栈就用不了它。

组合根（`lib/app/`）可以引用任何 feature——FSD 的 app 层负责装配。
中间两条是同一件事的两面：状态层与 UI 之间必须有明确的接线口（provider + `ref`）。
页面层的 material 不在管辖内（`lib/core/config/app_settings.dart` 为了 `ThemeMode` import material 是正当的）。

> 上一代（master 的 signals 栈）有一条「页面必须给可选注入点」，对应 [ADR-0001](docs/adr/ADR-0001.md) 的缓解措施。Riverpod 栈的注入口是 `ProviderScope(overrides:)`，页面不持有可注入字段，那条规则与它的 ADR 只对 master 成立。

## 📏 代码形态约定

边界脚本管「谁能依赖谁」，`tool/check_conventions.dart` 管「代码写成什么样」：

```bash
dart run tool/check_conventions.dart
```

| 规则 | 说明 |
|------|------|
| build 里禁用 `ref.read` 取值 | `ref.read` 不建立订阅，provider 变了界面不重建；读值用 `ref.watch`（`ref.read(xxx.notifier)` 取 notifier 调方法不在管辖内） |
| 注释块 ≤10 行 | 超限就把解释搬进 `.trellis/spec/`，代码里只留一行链接（口径见 `.trellis/spec/guides/comment-guidelines.md`） |

它用 `package:analyzer` 的 `parseString` 判 AST 而不是正则：「调用点在不在 `build` 方法体里」「实参是不是 `.notifier`」都不是行内信息，而 dart format 还会把 `ref` 与 `.read` 折到两行。已接入 pre-commit 与 CI 的 `analyze` job。

> 上一代的 `avoid_async_state_map` 随 signals 栈退役：`AsyncValue.when` 的回调具名且具类型，配错在编译期就报错，不需要门禁兜运行期分派。

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
Page (ConsumerWidget) → Notifier → Repository → Service → API (Retrofit)
        ↑  ref.watch           ↕              ↕
        └── AsyncValue ←  Result<T, Failure>  ←  Dao (Drift，缓存旁路)
```

- **Notifier**：依赖从 `ref` 取（`ref.watch` 装配好的 provider），把 `Result` 翻译成 `AsyncValue`，失败时抛 `Failure` 本身
- **Service**：业务逻辑实现，返回 `Result<T, Failure>`
- **Page**：`ConsumerWidget`，`ref.watch` 订阅状态、`ref.refresh` / `ref.invalidate` 刷新重试，不写业务逻辑

### Feature 间通信

- 跨 feature 数据共享通过 `core/` 暴露的 provider（如 `sessionProvider`、`appSettingsProvider`）
- 不使用事件总线（调试困难）
- 不引用其他 feature 的 `page/` 或 `logic/`（`check_boundaries` 强制）

## 📄 许可证

MIT
