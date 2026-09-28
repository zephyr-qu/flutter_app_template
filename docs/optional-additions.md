# 可选增强清单

> 本文只写包名与用途，**不锁版本号**。加的时候用 `flutter pub add <pkg>`，让 pub
> 挑当前与你的 SDK 兼容的版本，别照抄别人 pubspec 里的 `^x.y.z`。

***

## 先看判断规则，再看清单

**1. 它是「基础设施」还是「设计选择」？**

| <br /> | 例子                  | 该不该预装                          |
| ------ | ------------------- | ------------------------------ |
| 基础设施   | DI、路由、错误模型、网络栈、存储抽象 | **该**。横切关注点，每个 App 都要，写错了全仓库返工 |
| 设计选择   | 骨架屏、品牌动画、字体、图标、空态插画 | **不该**。每个 App 都会换成自己的设计语言      |

**2. 成本是不对称的**

| <br /> | 成本                                          |
| ------ | ------------------------------------------- |
| 现在不装   | 需要时 `flutter pub add`，5 分钟                  |
| 装了不用   | 每次 SDK 大版本跟着升级 + 构建变慢 + README 要写它 + 新人要判断它 |

不对称到这个程度，**默认不装**就是对的。

**3. 从需求出发，不要从包出发。**
正确顺序是「我要接崩溃上报」→「上报要带机型」→「所以加 `device_info_plus`」。
反过来说"我有个 `device_info_plus`，哪里能用上"，写出来的一定是没人要的代码。

***

## 一、刚被移除的（需要时加回来就行）

| 包                  | 能力                         | 什么时候加                  | 更轻的替代                                                                                                                                                                              |
| ------------------ | -------------------------- | ---------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `shimmer`          | 骨架屏（灰块 + 高光扫过）             | 列表/详情首屏想避免"转圈 → 内容跳变"  | 手写灰色块 + `AnimatedOpacity`，零依赖                                                                                                                                                      |
| `lottie`           | Lottie 动画（品牌动画、空态插画）       | 设计确实给了 Lottie JSON     | 成本不低：单个动画 JSON 常几十\~几百 KB。先确认收益                                                                                                                                                    |
| `flutter_svg`      | SVG 图标与插画按矢量渲染             | 设计稿给的就是 SVG            | 让设计导出 PNG（`@2x`/`@3x`）；或先用 `Icon`                                                                                                                                                  |
| `flutter_gen`      | 资源类型安全访问器（`Assets.xxx`）    | assets 多到记不住路径、且改动频繁   | 手写 `lib/core/assets.dart` 常量，20 行搞定                                                                                                                                                |
| `device_info_plus` | 机型、系统版本、`isPhysicalDevice` | **接崩溃上报时**当上下文用        | 只要系统版本的话，`dart:io` 的 `Platform.operatingSystemVersion` 够                                                                                                                           |
| `google_fonts`     | Google Fonts 的 1000+ 款字体   | 需要**品牌字体**、且不想自己管字体文件时 | 把 ttf 放进 `assets/`，在 `pubspec.yaml` 的 `flutter: fonts:` 里声明——没有网络依赖。⚠️ 明确不要走它的默认模式（渲染时从 `fonts.gstatic.com` 下载）：弱网/无网下字体不生效，冷启动会先渲染系统字体再"跳"一下。另外中文字体（如思源黑体）全字库单个字重常有数 MB，要有子集裁剪的准备 |
| `flutter_dotenv`   | 从 `.env` 文件读环境变量（需声明为 asset） | 想在运行时读文件，而非编译期注入 | **本项目在用**：`bootstrap()` 用 dotenv 加载入库的 `.env.example`（见 [README](../README.md#环境与构建)） |

> `lottie` 和 `flutter_gen` 是联动的：想用类型安全访问器读 Lottie，`flutter_gen` 会
> 一起回来（多一个 `build_runner` builder，首次构建会变慢）。加之前想清楚这笔账。

***

## 二、脚手架已经给它们留好位置的（优先级最高）

这几个不是"顺便提一下"——项目里已经有明确的接入点，加进来改动面很小。

| 能力                | 推荐包                                                | 脚手架里已有的落点                                                                                          |
| ----------------- | -------------------------------------------------- | -------------------------------------------------------------------------------------------------- |
| 崩溃 / 错误上报         | `sentry_flutter`、`firebase_crashlytics`            | `bootstrap.dart` 的 `FlutterError.onError`、`PlatformDispatcher.instance.onError`——**现在只打日志，是天然接入点** |
| 上报上下文             | `device_info_plus`                                 | 同上，配合上报一起加                                                                                         |
| 深链 / 分享链接打开 App   | `app_links`                                        | `AppRouter` 的初始路由（`lib/app/routing/router.dart`）                                                   |
| 网络调试 UI（真机上抓包看请求） | `talker_flutter`（`alice` 的后继）                      | 替换 `dio_client.dart` 里 `PrettyDioLogger` 的挂载位置                                                     |
| 本地通知 / 推送         | `flutter_local_notifications`、`firebase_messaging` | `ProfilePage` 的 `TODO(template): 接入通知设置页`                                                          |
| 原生启动图             | `flutter_native_splash`                            | `splash_page.dart` 是 **Flutter 层**启动页；native 层冷启动白屏要靠它                                             |
| 应用图标              | `flutter_launcher_icons`（已在依赖里）                    | 默认占位图 `assets/icon/icon.png` 已存在；发版前换成自己的图再跑                                                       |
| 主题模式 UI           | 不需要新包                                              | 已闭环：`appSettingsProvider` 的 `themeMode` + `ProfilePage` 的「外观」弹窗                                    |

***

## 三、按需求查表（业务能力）

| 你要做             | 包                                                                                           |
| --------------- | ------------------------------------------------------------------------------------------- |
| 权限申请（相机/定位/通知）  | `permission_handler`                                                                        |
| 调起浏览器 / 邮件 / 电话 | `url_launcher`                                                                              |
| 分享内容出去          | `share_plus`                                                                                |
| 拍照 / 选相册 / 裁剪   | `image_picker`、`image_cropper`                                                              |
| 选文件             | `file_picker`                                                                               |
| 指纹 / 面容解锁       | `local_auth`                                                                                |
| 内嵌网页            | `webview_flutter`（官方）、`flutter_inappwebview`（功能全）                                           |
| 网络图片（带磁盘缓存）     | `cached_network_image`                                                                      |
| 二维码生成 / 扫描      | `qr_flutter`、`mobile_scanner`                                                               |
| 图表              | `fl_chart`                                                                                  |
| 声明式动画           | `flutter_animate`（比手写 `AnimationController` 省事）                                             |
| 分页加载            | `infinite_scroll_pagination`（或照 `SampleListNotifier` 自己写）                                   |
| 表单校验            | `formz`（或在状态快照上写 `bool get canSubmit => ...`）                                               |
| 日期 / 货币格式化      | **需要时加**：`flutter pub add intl`，用它的 `DateFormat` / `NumberFormat`（本项目已裁剪 l10n，`intl` 不在依赖里） |
| 下拉刷新            | **已有**：`RefreshIndicator`（见 `sample_list_page.dart`）                                        |
| 列表三态            | **已有**：`LoadingIndicator` / `ErrorText` / `EmptyWidget`                                     |

**⚠️ 一个反模式**：`connectivity_plus` 不要用来决定"要不要发请求"，也不要用来决定
"要不要显示网络错误"。连着 WiFi 但没有出口流量、公司网络强制门户等场景下它会骗你。
正确做法是**以请求失败为准**——本项目的 `Failure` + `ErrorText` 已经是这么做的。
`connectivity_plus` 只适合"网络切换时给条提示"这种弱决策。

***

## 四、开发期工具

| 工具                                   | 用途                  | 备注                                                                                                                                                             |
| ------------------------------------ | ------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `patrol`                             | 端到端测试               | 比 `integration_test/` 强：能操作系统弹窗、原生权限框                                                                                                                          |
| `alchemist` / 内建 `matchesGoldenFile` | 视觉回归测试              | 改主题时的护栏                                                                                                                                                        |
| `dio_cache_interceptor`              | HTTP 缓存拦截器          | 比 `SampleService` 手写的缓存旁路完整（ETag / max-age / 过期策略）；需求简单就别上                                                                                                     |
| `custom_lint`                        | 自定义 lint 规则框架       | ⚠️ 建在官方的 legacy `analyzer_plugin` 协议上（该包页面自己标注 "not recommended for new plugin development"），最新 0.8.1 停在 2025-09。写自己的 lint 规则应走 `analysis_server_plugin`，别从它起步 |
| `flutter_flavorizr`                  | 生成 build flavor 脚手架 | 需要 dev/staging/prod 同机共存时用它最省事；只改 Android 的话照第七节的片段手改即可，不用装                                                                                                    |

***

## 五、不想用现有某个选择时，换什么

技术选型不是不能换，这里附上迁移成本，便于评估：

| 现在用的                 | 替代                                                            | 迁移成本                                                        |
| -------------------- | ------------------------------------------------------------- | ----------------------------------------------------------- |
| `riverpod`           | `signals` / `bloc` / `provider`                               | **高**。Notifier 与页面订阅写法全变，`ref.watch` 要逐个换掉                  |
| `auto_route`         | `go_router`（官方，无 codegen）                                     | 中。`@RoutePage` 全删，路由表改写成 `GoRouter` 的 `routes` / `redirect` |
| provider 装配（无 DI 容器） | `get_it` + `injectable`                                       | 低 \~ 中。装配方式整体换掉，页面侧还要重新开注入口                                 |
| `retrofit`           | 手写 Dio 调用                                                     | **低**。只有 1 个 API 文件                                         |
| `freezed`            | 只留 `json_serializable` + 手写 `copyWith`/`==`                   | 中。只有 1 个模型（`SampleItem`）                                    |
| `Drift`              | `shared_preferences`（纯 KV）、`sqflite`（手写 SQL）、`objectbox`（性能好） | **低**。只影响 `SampleService` 的缓存与 `SampleDao`                  |
| `dio`                | `http`（官方）                                                    | 低，但会失去整套拦截器生态                                               |

***

## 六、不建议提前引入的

这几类加进来通常弊大于利：

- **第二套状态管理**（`signals` / `bloc` / `provider`）——会和 `riverpod` 并存成两套
  状态源，后面想拆都拆不干净。要换就整体换，别混用。
- **`fpdart`** **/** **`dartz`** **这类函数式 Either** ——项目已有自实现的 `Result<T, E>` +
  `Failure`，再加一套会让错误处理彻底分裂。
- **`equatable`** ——`freezed` 已经生成 `==` / `hashCode`，重复。
- **大型 UI 组件库**（`fluent_ui` / `shadcn_ui` / `forui`）——会覆盖 MD3 主题与
  `AppThemeExtension`，先确认真的需要，否则等于把主题层推倒重来。
- **埋点 / 分析 SDK** ——等产品和合规定下来再选，各厂商 SDK 差异大且不好替换。

***

## 七、可选脚手架：build flavor（dev / staging / prod 同机共存）

脚手架默认**不做 flavor**：环境靠改入库的 `.env.example` 切换（见
[README](../README.md#环境与构建)），一套代码、一个包，构建时换地址。
什么时候才值得加 flavor？只有一种场景——**同一台手机上要同时装多个环境**
（dev 包连测试服、prod 包连线上，互不覆盖、不用卸载）。如果只是「构建时换地址」，
改一处 `.env.example` 就够了，别为它引入 flavor 的复杂度。

需要时按下面四步加，Android 部分可以直接复制。

### 1. `android/app/build.gradle.kts`

```kotlin
android {
    // ← 由 tool/init_project.dart 写入；flavor 不改变它
    namespace = "com.example.my_app"

    // AGP 8+ 的写法；更老的是 flavorDimensions "env"
    flavorDimensions += "env"
    productFlavors {
        create("dev") {
            dimension = "env"
            applicationIdSuffix = ".dev"          // 与 prod 共存的关键
            versionNameSuffix = "-dev"
            resValue("string", "app_name", "MyApp Dev")
        }
        create("staging") {
            dimension = "env"
            applicationIdSuffix = ".staging"
            versionNameSuffix = "-staging"
            resValue("string", "app_name", "MyApp Staging")
        }
        create("prod") {
            dimension = "env"                     // 刻意不加后缀：上架的就是它
            resValue("string", "app_name", "MyApp")
        }
    }

    defaultConfig {
        // ← 仍然留在这里：flavor 只是在它之上加后缀
        applicationId = "com.example.my_app"
    }
}
```

三个容易踩的点：

- **`applicationIdSuffix`** **只能加在非 prod 的 flavor 上**。prod 必须是商店里那个唯一
  的 id，否则上传时会报「包名与已有应用不符」。
- **`namespace`** **不跟着 flavor 变**：它只决定 R 类 / BuildConfig 的包名，与设备上的
  安装身份无关。
- **桌面显示名**：`resValue` 只是定义字符串资源，manifest 还得从字面量
  `android:label="..."` 改成 `@string/app_name` 才会生效（脚手架当前是字面量，由
  `tool/init_project.dart` 写入）。不想动 manifest 就改用
  `manifestPlaceholders["appName"]` + `android:label="${appName}"`。

### 2. flavor 与 env 的关系

env 只有一份、且是入库的 asset（`.env.example`）：**dotenv 只能加载 asset**，所以 flavor
无法在构建时挑另一份 env 文件。要按 flavor 分环境，得自己加一层（本模板不提供）：

- 让 `bootstrap()` 按 `String.fromEnvironment('env')` 选不同的 asset 名（各 flavor 一份
  `.env.*` 并都声明进 `pubspec.yaml` 的 `assets:`），构建时传 `--dart-define=env=dev`
- 或者去掉 dotenv，整体改成读 `String.fromEnvironment`

Flutter 会把 flavor 自动注入成 `FLUTTER_APP_FLAVOR`，但那与本项目的 env 加载无关。

### 3. iOS：一个 flavor 一个 scheme

iOS 上 Flutter 是**按 scheme 名找 flavor** 的，所以要在 Xcode 里
`Product → Scheme → Manage Schemes` 把 `Runner` 复制成 `dev` / `staging` / `prod`，
再逐个配置 Bundle Identifier 后缀与 Display Name。手动维护三套 scheme 很啰嗦——
这一步交给 `flutter_flavorizr` 更划算；只先跑通 Android 的话跳过这步即可。

### 4. 加上之后「必须带 `--flavor`」

一旦定义了 flavor，构建与运行**都必须指定**，否则 Flutter 直接报
「You must specify a --flavor option」。不想每次敲，就在 `pubspec.yaml` 里给个默认值：

```yaml
flutter:
  default-flavor: dev     # 不传 --flavor 时用它
```

```bash
flutter run --flavor dev
flutter build apk --flavor staging
flutter build appbundle --flavor prod
flutter build ipa --flavor prod
flutter test                        # 测试不受 flavor 影响
```

> ⚠️ 与 `tool/init_project.dart` 的顺序：**先初始化、后加 flavor**。初始化脚本按
> `applicationId = "..."` 这种形态改 Android 标识，而 flavor 会让这个值分散到多个
> flavor 块里。真撞上了不会半改——脚本会列出「哪一处没匹配到」并以非零退出码结束，
> 手工改完那两处再跑一次即可。

***

## 相关文档

- [release-checklist.md](./release-checklist.md) — 从"能跑"到"能发"的检查清单
- [../README.md](../README.md) — 模板占位清单（哪些是示例骨架、哪些是真接线）

