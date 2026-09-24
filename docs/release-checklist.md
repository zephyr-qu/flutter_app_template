# Release 检查清单

脚手架**有意**不包含发版配置——签名、混淆、flavor 都属于目标应用的职责（见
[README](../README.md#环境配置与-release-构建)）。但"有意留白"不等于"可以忘"，
这份清单把它变成可勾选的步骤。

> 现状（脚手架原样）：release 用 **debug keystore** 签名、未开 minify/混淆、
> 没有 build flavor、iOS 未配置签名、`BASE_URL` 还是占位地址。
> 下面每一项都是从"能跑"到"能发"必须补的。

---

## 1. 环境与地址

- [ ] `.env.production` 的 `BASE_URL` 换成真实域名（当前是 `https://api.example.com`）
- [ ] 确认 `USE_MOCK=false`——为 `true` 时请求会被 `msw_dio_interceptor` 拦截，
      界面一切正常但数据全是假的
- [ ] 真实地址优先用 `--dart-define` 传，而不是写进 env 文件：

```bash
flutter build apk --dart-define=env=production \
  --dart-define=BASE_URL=https://api.your-domain.com
```

- [ ] 复核 `.env` / `.env.development` / `.env.production` 里**没有密钥**。
      这三个文件会被提交进 git，并作为 asset 打进产物，任何有 apk 的人都能提取出来。
      密钥只能走 `--dart-define`（不进 git，但仍可从产物提取，敏感场景要放服务端）。
- [ ] **不要**把 `_activeEnv` 改成 `String.fromEnvironment('env', defaultValue: 'development')`：
      那样 release 也会加载 `.env.development`，包静默跑在 localhost + mock 上。
      （`bootstrap.dart` 里有详细注释）

## 2. 版本与标识

- [ ] `pubspec.yaml` 的 `version:`（`versionCode` / `versionName` 由它推导）
- [ ] `android/app/build.gradle.kts` 的 `applicationId`（当前 `com.example.flutter_app`）
      与 `namespace`
- [ ] `android/app/src/main/AndroidManifest.xml` 的 `android:label`
- [ ] `ios/Runner/Info.plist` 的 `CFBundleDisplayName` / Bundle Identifier

> 一次性改这些用 `dart run tool/init_project.dart`（交互式）。

## 3. Android 签名与混淆

当前 `release` 块用 debug 签名：

```kotlin
release {
    signingConfig = signingConfigs.getByName("debug")  // ← 必须替换
}
```

- [ ] 生成上传密钥（`keytool -genkey ...`），产物放**仓库外**或确保已被忽略
      （`.gitignore` 已含 `**/android/key.properties`、`*.jks`、`*.keystore`）
- [ ] 新建 `android/key.properties`：

```properties
storePassword=...
keyPassword=...
keyAlias=upload
storeFile=/absolute/path/to/upload-keystore.jks
```

- [ ] 在 `build.gradle.kts` 里读取它并定义 `signingConfigs.release`，把 `release`
      指向 `signingConfigs.getByName("release")`
- [ ] 打开混淆与资源收缩：

```kotlin
release {
    isMinifyEnabled = true
    isShrinkResources = true
    proguardFiles(
        getDefaultProguardFile("proguard-android-optimize.txt"),
        "proguard-rules.pro",
    )
}
```

- [ ] 补 `android/app/proguard-rules.pro`。**重点**：本项目大量使用反射式 codegen
      （freezed / json_serializable / retrofit / drift），开混淆后必须保留模型层：

```proguard
-keep class **$$Impl { *; }
-keepclassmembers class * {
    @com.google.gson.annotations.SerializedName <fields>;
}
-keep class * extends com.google.gson.TypeAdapter
```

  Drift 生成的类同样需要保留；首次开启后用真机跑一遍全流程再发。
- [ ] 关闭混淆时必须显式设置 `--split-debug-info` / `--obfuscate` 并留好符号表
      （`.gitignore` 已预留 `app.*.symbols`、`app.*.map.json`）：

```bash
flutter build appbundle --obfuscate --split-debug-info=build/symbols
```

## 4. 构建变体（按需）

脚手架用 `--dart-define=env=` 区分环境，**没有** build flavor。需要 dev/staging/prod
三个可同时安装的包时，照 [optional-additions.md](./optional-additions.md) 第七节的可复制
片段加 `productFlavors` + `flavorDimensions` + `applicationIdSuffix`（只有非 prod 的
flavor 加后缀，`namespace` 不动），并按那里的说明处理 iOS scheme 与「`--flavor` 必填」。

## 5. iOS

- [ ] Xcode 里配置 Signing Team 与 Development Team
- [ ] `ios/Runner/Info.plist` 的 `CFBundleDisplayName` 与 Bundle Identifier
- [ ] 需要时补 `ExportOptions.plist` / App Store Connect 配置
- [ ] 关掉不需要的能力（后台模式、推送）以免审核问询

## 6. 代码生成与质量门禁

- [ ] 重新生成产物（模型、provider、路由、Drift schema）——生成物不入库，发版前现场生成：

```bash
just codegen
```

- [ ] 门禁全绿：

```bash
just verify                               # 全套 5 项，首个失败即停
just test integration_test/               # 端到端冒烟（真机 / 模拟器，不进 just verify）
```

  `just verify` 覆盖：格式、`dart analyze --fatal-infos`（lib + test 与 tool 的手写文件，显式传参才
  会加载 riverpod_lint 与 `packages/app_lints` 插件；依赖声明 lint `depend_on_referenced_packages`
  在 `analysis_options.yaml` 里提升为 error，不依赖命令的默认值）、插件规则测试（`packages/app_lints`）、
  `flutter test`。语义见 [cross-cutting.md](../.trellis/spec/cross-cutting.md)。

- [ ] 新增 `FailureCode` 已在 `core/ui/failure_message.dart` 的 `localizedMessage` 里补上文案
      （不补会编译失败——`switch` 不再穷尽；`test/core/ui/failure_message_test.dart` 会遍历枚举逐个断言）

- [ ] 依赖过一遍：`dart pub outdated` 看 `Current / Upgradable / Resolvable / Latest` 四列，
      能升的走 `dart pub upgrade`（改动 `pubspec.lock` 后记得重跑测试与 codegen）；
      有**已知漏洞**的必须在发版前处理——CI 的 `osv-scan` job 会扫描根工程与插件包两份 `pubspec.lock`，
      口径见 [cross-cutting.md](../.trellis/spec/cross-cutting.md)「供应链门禁」
- [ ] 应用图标已更新：`dart run flutter_launcher_icons`

## 7. 发布前人工核查

- [ ] 真机跑一遍主流程：启动页 → 首页 → 示例列表（下拉刷新 / 断网重试）→ 个人中心改主题，
      重进 App 后主题仍是改过的那一个
- [ ] 断网启动：示例列表应回退到 Drift 缓存，而不是空白页（缓存旁路在
      `features/sample/data/sample_service.dart`）
- [ ] 关掉 mock 要改**当前环境那一份**文件：release 读 `.env.production`，
      `--dart-define=env=xxx` 读对应的 `.env.xxx` —— 裸 `.env` 从不被加载，
      改它没有任何效果（见 `bootstrap.dart` 的 `_envFileName`）。改完确认真实接口连通
- [ ] 权限清单符合实际使用（AndroidManifest / Info.plist 里不要留多余权限）
- [ ] 隐私政策与合规文案（若上架）已就位
- [ ] 崩溃/错误上报已接入——`bootstrap.dart` 的 `PlatformDispatcher.instance.onError` 与
      `Logging` 是天然接入点，现在只是打了日志（且 release 下只到 logcat）

> `leak_tracker` 只在 debug 生效（`bootstrap.dart` 用 `assert` 包裹），
> release 不会有额外开销，无需处理。
