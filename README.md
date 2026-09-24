# Flutter 通用脚手架

基于 Flutter 的中小型项目脚手架：**Feature-Sliced Design (FSD)** 目录 + **Riverpod** 状态管理 + `auto_route` / Retrofit / Drift，开箱即用。

## ✨ 特性

- **FSD 功能切片** — 按业务模块组织（`page/` `logic/` `data/`）
- **状态与依赖都是 provider** — Riverpod provider 同时承担状态、装配与生命周期
- **声明式路由** — `auto_route`，全局路由表 + `AutoTabsRouter` 标签框架；冷启动经启动页进入主框架
- **网络层** — Dio + Retrofit + 智能重试 + Mock 拦截
- **离线缓存** — 示例接口走缓存旁路：成功刷新 Drift 缓存，失败回退缓存
- **错误处理** — `Result<T, E>` + `Failure` 密封类（只带错误码，文案由 UI 翻译）
- **三态渲染** — `AsyncView` 是 `AsyncValue → Widget` 的唯一入口
- **MD3 主题** — `flex_color_scheme`，亮 / 暗完整支持
- **门禁脚本** — 架构边界、代码形态、目录树一致性、覆盖率（见「门禁」）

## 🛠️ 技术栈

| 类别 | 技术 |
| ------ | ------ |
| 状态管理 / 依赖装配 | `flutter_riverpod` `riverpod_annotation` `riverpod_generator` |
| 路由 | `auto_route` |
| 网络 | `dio` `dio_smart_retry` `retrofit` `pretty_dio_logger` |
| Mock API | `msw_dio_interceptor` |
| 数据库 / 本地存储 | `drift` `sqlite3`（原生库由 3.x 的 build hook 提供）、`shared_preferences`、`path_provider` |
| 代码生成 | `freezed` `json_serializable` `build_runner` |
| 主题 / 日志 | `flex_color_scheme`、`logger` |
| 静态分析 / 测试 | `very_good_analysis`、`flutter_test` `mocktail` |

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
│   │   ├── router.dart                     # auto_route 配置
│   │   └── router.gr.dart                  # 生成的路由类
│   └── pages/                              # 全局页面（不属于任何 feature）
│       ├── splash_page.dart                # 启动页
│       └── not_found_page.dart             # 404
│
├── core/                                   # 基础设施 + 状态耦合的适配层
│   ├── base/                               # Failure / Result / runCatching
│   ├── config/
│   │   ├── app_settings.dart               # 偏好快照 + Notifier（主题 / 调试日志 / 页大小）
│   │   ├── network_config.dart             # NetworkConfig（环境变量值对象）
│   │   └── user_preferences.dart           # 偏好的裸存储（读写 SharedPreferences）
│   ├── data/
│   │   ├── database/                       # Drift 连接 + schema + 表
│   │   ├── network/                        # Dio 工厂 / 拦截器栈 / 应用侧 Dio 装配
│   │   └── storage/                        # FileStorage
│   ├── logging/                            # 日志封装 + 调试日志脱敏
│   ├── providers.dart                      # 基础设施 provider（prefs / 数据库 / 文件）
│   ├── theme/                              # 色板 / ThemeData 组装 / 设计 token
│   └── ui/                                 # 共享 UI
│       ├── async_view.dart                 # AsyncValue → Widget（三态渲染入口）
│       ├── empty_widget.dart               # 无业务文案的空态组件
│       ├── error_text.dart                 # 错误 + 重试
│       ├── failure_message.dart            # FailureCode → 用户文案
│       └── loading_indicator.dart          # LoadingIndicator / ScreenLoadingIndicator
│
└── features/                               # 业务功能模块
    ├── home/                               # 首页 + 主框架
    ├── profile/                            # 个人中心
    └── sample/                             # 金标准示例（retrofit / drift / Result 三种 data 形态）
```

单包结构（无 `packages/`）：`dart analyze`、覆盖率与门禁都只针对 `lib/`。

feature 内部三层，依赖方向 `app → features → core`：

| 层 | 目录 | 职责 |
| ---- | ------ | ------ |
| **UI** | `page/` | 页面组件（`ConsumerWidget`），`ref.watch` 状态，把事件转给 Notifier |
| **Logic** | `logic/` | Notifier（`@riverpod`），状态 + 业务编排 |
| **Data** | `data/` | API (Retrofit)、Service、Models (freezed)、DAO (Drift) |

`core/` 是底座，**不得** import `features/` 或 `app/`；`app/` 是组合根，可以 import 任何东西。

## 🚀 快速开始

环境要求：Flutter >= 3.44.0（开发与 CI 钉 3.47.5，见 `.fvmrc`）、Dart >= 3.13.0。

```bash
flutter pub get
dart run build_runner build   # 生成物已入库；改了注解 / 模型后再跑一次
flutter run                   # 默认 .env.development，USE_MOCK=true，无需后端
flutter test
```

### 环境配置

`.env` 按环境名加载：`--dart-define=env=xxx` 优先，否则 debug / profile → `development`、release → `production`。

```bash
flutter run --dart-define=env=production
flutter build apk --dart-define=env=production \
  --dart-define=BASE_URL=https://api.your-domain.com
```

三条容易踩的：

- **不要**给 `String.fromEnvironment('env')` 加 `defaultValue` —— release 会跟着加载 `.env.development`，包静默跑在 localhost + mock 上。
- `.env` / `.env.development` / `.env.production` **有意提交**，且在 `pubspec.yaml` 的 assets 里会打进产物：只放非密钥配置，密钥走 `--dart-define`。
- `.env.example` 只是模板（`tool/init_project.dart` 拿它生成 `.env.development`），运行时永不加载。缺 `BASE_URL` 时 `bootstrap()` 直接抛异常。

release 构建有意留白（仍用 debug keystore 签名、未 minify、无 flavor、iOS 未签名），发版前按 [docs/release-checklist.md](docs/release-checklist.md) 补齐。

### 代码生成

生成物（`*.g.dart` / `*.freezed.dart` / `*.gr.dart`）**提交进仓库**，clone 后不跑 codegen 也能 analyze / test。改了注解（`@freezed` / `@RoutePage` / `@riverpod`、Drift 表）、增删了文件、升级了 codegen 依赖后，必须重新生成并一起提交 —— CI 会再跑一遍并比对 `git diff`：

```bash
dart run build_runner build
dart run build_runner clean && dart run build_runner build   # 升级 codegen 包 / SDK 后
```

生成物冲突**不要手工 merge**：解决源文件冲突后重跑 codegen 覆盖。时机表见 [.trellis/spec/cross-cutting.md](.trellis/spec/cross-cutting.md)。

### 从脚手架创建新项目

```bash
dart run tool/init_project.dart                                  # 交互式
dart run tool/init_project.dart --yes --name=my_next_app \
  --application-id=com.example.my_next_app                       # 非交互
```

一次改完 `pubspec.yaml`（`name` / `description`）、全仓库 `package:<旧名>/` 与根组件类名、Android `namespace` + `applicationId` + `android:label` + `MainActivity.kt`（连目录一起搬）、iOS bundle id（含 `RunnerTests`）与显示名。语义是**全有或全无**：任一必改点没匹配到就报出位置并非零退出，不写任何文件。

### 文案

单语言：中文直接写在 widget 里，没有 ARB / `AppLocalizations`。`Failure` 的文案集中在 `lib/core/ui/failure_message.dart` 的 `switch` 常量表，新增 `FailureCode` **不补文案就编译不过**。要加回多语言见 [.trellis/spec/frontend/localization.md](.trellis/spec/frontend/localization.md)。

## 📖 示例模块

`lib/features/sample/` 是唯一需要照抄的对象，覆盖三种 data 形态（Retrofit API / Drift DAO / `Result` 包装的 Service）与三种 provider 形态。`home/`（首页 + 主框架）、`profile/`（个人中心）是更偏骨架的页面。

- **无需后端**：`.env.development` 的 `USE_MOCK=true` 由 `msw_dio_interceptor` 拦截，规则在 `lib/core/data/network/dio_client.dart` 的 `_registerMockRules()`
- **阅读顺序**：`page/` → `logic/` → `data/`
- **删除示例**：删掉 `lib/features/sample/` 与它的测试，再清理 ① `router.dart` 的 `SampleListRoute` ② `_registerMockRules()` 里的 `/sample-items` 规则 ③ `main_page.dart` 的「示例」Tab ④ `home_page.dart` 的「示例」快捷入口 ⑤ 跑一次 `dart run build_runner build`。（`SampleService` 的缓存旁路还在用 `AppDatabase`，连缓存一起删见 [database-guidelines.md](.trellis/spec/backend/database-guidelines.md)）

## 📐 新增 feature

结构照抄 `features/sample/`：

```
features/your_feature/
├── logic/   your_notifier.dart      # @riverpod Notifier / AsyncNotifier
├── data/    models/  your_api.dart  your_service.dart
│            your_providers.dart  your_repository.dart（按需）
└── page/    your_page.dart          # ConsumerWidget
```

异步 Notifier：`build()` 就是首屏加载，把 `Result` 翻成 `AsyncValue`，**失败时抛 `Failure` 本身**（`ErrorText` 要靠它翻译错误码）。完整形状见 `sample/logic/sample_list_notifier.dart`：

```dart
@riverpod
class YourNotifier extends _$YourNotifier {
  @override
  Future<List<YourItem>> build() async {
    final result = await ref.watch(yourRepositoryProvider).getItems();
    return switch (result) {
      Ok<List<YourItem>, Failure>(:final data) => data,
      Err<List<YourItem>, Failure>(:final error) => throw error,
    };
  }
}
```

页面：`ref.watch(provider)` + `AsyncView` 渲染三态，`ref.refresh` / `ref.invalidate` 刷新重试（形状见 `sample/page/sample_list_page.dart`）。同步状态（设置项这类）见 `core/config/app_settings.dart`。页面**不需要**注入点构造参数 —— 测试用 `ProviderScope(overrides:)` 换实现。

## 🧪 测试

```bash
flutter test
flutter test test/features/sample/logic/sample_list_notifier_test.dart
```

- 逻辑测试用 `ProviderContainer` + `overrides` 注入假仓库，模板是 `test/features/sample/logic/sample_list_notifier_test.dart`
- widget 测试用 `test/support/app_test_harness.dart` 的 `setUpTestApp()` + `wrapPage(page, container:)`
- 三条硬约束：不要 `await provider.future`（假时钟下会挂到超时）、容器传 `retry: noRetry`、`mocktail` 的 `verify` 会消耗命中次数（见 [state-management.md](.trellis/spec/frontend/state-management.md)「Testing Requirements」）

## ✅ 门禁

```bash
dart run tool/verify.dart     # 一条命令跑完全部 9 项，首个失败即停
```

| 项 | 规则 |
|---|---|
| `check_boundaries.dart` | `core/` 不得 import `features/` / `app/`；跨 feature 只共享 `data/`；`features/*/logic/` 不得建 `ProviderContainer`、不得 import `material.dart` |
| `check_conventions.dart` | `build` 里不得用 `ref.read` 取值；连续注释块 ≤10 行 |
| `check_readme_tree.dart` | 本文件与 `.trellis/spec/frontend/directory-structure.md` 里的 `lib/` 目录树必须与实际一致 |
| `check_coverage.dart` | 手写代码行覆盖率 ≥ 80%（剔除生成物，按行数加权，扫描根 `lib`）；没被测的新文件一样计入分母 |
| 其余 | `dart format`、`dependency_validator`、`flutter analyze lib/ test/`、`dart analyze tool/`、`flutter test --coverage` |

两条边界规则用脚本而不是 analyzer 插件，因为插件规则只在 IDE 生效、CLI 与 CI 跑不到。单项重跑就跑上表对应的原始命令；阈值与理由见 [.trellis/spec/cross-cutting.md](.trellis/spec/cross-cutting.md)。`pre-commit` 钩子跑的就是 `verify.dart`。

## 🎨 数据流

```
Page (ConsumerWidget) → Notifier → Repository → Service → API (Retrofit)
        ↑ ref.watch        ↕               ↕
        └── AsyncValue ← Result<T, Failure> ← DAO (Drift，缓存旁路)
```

Notifier 从 `ref` 取依赖，把 `Result` 翻成 `AsyncValue`；Service 返回 `Result<T, Failure>`；Page 只订阅状态、转事件，不写业务逻辑。跨 feature 共享只走 `core/` 暴露的 provider，不引其他 feature 的 `page/` / `logic/`，也不用事件总线。

## 🔧 其它

- **`.trellis/spec/`** — 分层规范入口，改某一层之前先读对应 spec
- **`BRANCH.md`** — 与同项目 `master`（另一套状态管理栈）的差异说明；`docs/` 与部分 spec 里带「仅对 master 成立」的段落，读到时先看它
- **`TODO(template)`** — 刻意留空的骨架占位：`grep -rn "TODO(template)" lib/` 可列全，目前是「设置 → 通知 / 隐私 / 帮助」三项与首页「最近动态」
- **应用图标** — `pubspec.yaml` 的 `flutter_launcher_icons.image_path` 指向不存在的 `assets/icon/icon.png`，跑图标命令会直接失败：补文件或删掉那段配置
- **`docs/optional-additions.md`** — 有意不预装的包，以及每个包的「什么时候才该加」
- **`tool/`** — `init_project.dart`（改名）、`verify.dart`（门禁一条命令）、四个 `check_*.dart`、`prune.dart`（l10n 裁剪）

## 📄 许可证

MIT
