# Release 检查清单

脚手架**有意**不包含发版配置——签名、混淆、flavor 都属于目标应用的职责（见
[README](../README.md#环境配置与-release-构建)）。但"有意留白"不等于"可以忘"，
这份清单把它变成可勾选的步骤。

> 现状（脚手架原样）：release 用 **debug keystore** 签名、未开 minify/混淆、
> 没有 build flavor、iOS 未配置签名、`BASE_URL` 还是占位地址。
> 下面每一项都是从"能跑"到"能发"必须补的。

---

## 1. 环境与地址

- [ ] `BASE_URL` 换成真实域名：用 `--dart-define=BASE_URL=...` 传，或把它写进你自己的
      `.env.production`（已被 `.gitignore` 忽略）再用 `--dart-define-from-file=.env.production` 注入。
- [ ] 确认 `USE_MOCK=false`——为 `true` 时请求会被 `msw_dio_interceptor` 拦截，
      界面一切正常但数据全是假的
- [ ] 复核 `.env.example` 里**没有密钥**——它会被提交进 git。
      密钥只能走 `--dart-define`（不进 git，但仍可从产物提取，敏感场景要放服务端）。
- [ ] 确认 `.env.production` / `.env.development` 没被 `git add -f` 带进仓库：
      它们已列入 `.gitignore`，真实地址与密钥都只该留在本地或 CI secret 里。

```bash
flutter build apk --dart-define-from-file=.env.production \
  --dart-define=BASE_URL=https://api.your-domain.com
```
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

脚手架用 `--dart-define-from-file=<file>` 区分环境，**没有** build flavor。需要 dev/staging/prod
三个可同时安装的包时，照 [optional-additions.md](./optional-additions.md) 第七节的可复制
片段加 `productFlavors` + `flavorDimensions` + `applicationIdSuffix`（只有非 prod 的
flavor 加后缀，`namespace` 不动），并按那里的说明处理 iOS scheme 与「`--flavor` 必填」。

## 5. iOS

- [ ] Xcode 里配置 Signing Team 与 Development Team
- [ ] `ios/Runner/Info.plist` 的 `CFBundleDisplayName` 与 Bundle Identifier
- [ ] 需要时补 `ExportOptions.plist` / App Store Connect 配置
- [ ] 关掉不需要的能力（后台模式、推送）以免审核问询

## 6. 代码生成与质量门禁

- [ ] 重新生成产物（模型、DI、路由）—— 生成物**不入库**，本地那份必须与源一致：

```bash
just codegen
```

- [ ] 门禁全绿（本地与 CI 是同一条命令）：

```bash
just verify        # format / analyze / 依赖 / 插件规则 / 目录树 / 测试
```

  逐项对照：`just analyze` 的两组 `dart analyze --fatal-infos`（含 `depend_on_referenced_packages`）、
  `just deps-check`、`just test-app-lints`、`just check-readme-tree`、`just test`。
  覆盖率**不设门禁**：要看数字自己跑 `flutter test --coverage`（见
  [.trellis/spec/cross-cutting.md](../.trellis/spec/cross-cutting.md)「覆盖率」）。

- [ ] 端到端冒烟：`just e2e`

- [ ] 依赖过一遍：`dart pub outdated` 看 `Current / Upgradable / Resolvable / Latest` 四列，
      能升的走 `dart pub upgrade`（改动 `pubspec.lock` 后记得重跑测试与 codegen）；
      有**已知漏洞**的必须在发版前处理——CI 的 `osv-scan` job 会拿 `pubspec.lock` 查 OSV，
      口径见 `.trellis/spec/cross-cutting.md` 的「供应链门禁」
- [ ] 应用图标已更新：`dart run flutter_launcher_icons`

## 7. 发布前人工核查

- [ ] 真机跑一遍：登录 → 令牌过期（可把 `expiresIn` 调小）→ 自动刷新不弹登录页
- [ ] 断网启动：文章列表应回退到 Drift 缓存，而不是空白页
- [ ] 首次冷启动：确认没有「首个请求少带 `Authorization`」导致的多余 401
- [ ] 关掉 env 里的 mock（`.env.example` / 你自己那份），确认真实接口连通
- [ ] 权限清单符合实际使用（AndroidManifest / Info.plist 里不要留多余权限）
- [ ] 隐私政策与合规文案（若上架）已就位
- [ ] 崩溃/错误上报已接入——`bootstrap.dart` 的 `runZonedGuarded`、
      `FlutterError.onError`、`PlatformDispatcher.onError` 是天然接入点，
      现在只是打了日志

> `leak_tracker` 只在 debug 生效（`bootstrap.dart` 用 `assert` 包裹），
> release 不会有额外开销，无需处理。
