# Rename Checklist

> How to rename this scaffold when starting a new project.

## 首选：跑脚本，不要手工改

```bash
dart run tool/init_project.dart                 # 交互式：包名 / applicationId / iOS Bundle ID / 显示名
dart run tool/init_project.dart --yes --name=your_app \
  --application-id=com.yourcompany.yourapp      # 非交互（CI / 脚本）
```

脚本的语义是**全有或全无**：先规划、后写盘，任一必改点没匹配到就以非零退出码结束，
并列出「哪一处没对上」，磁盘保持原样。所以不会出现「改了一半、连 `flutter analyze`
都跑不起来」的中间状态。

覆盖范围（也就是手工改时要做完的事）：

| # | 位置 | 改什么 |
| --- | ------ | ------- |
| 1 | `pubspec.yaml` | `name:`（同时决定所有 import 路径）、`description:` |
| 2 | `lib/` `test/` `integration_test/` `tool/` `packages/` | `package:<旧名>/` → `package:<新名>/`（生成物不入库，不必管它们） |
| 3 | `lib/app/app.dart`、`lib/bootstrap.dart` 及引用它们的测试 | 根组件类名 `MyApp` → 新类名（整词替换） |
| 4 | `android/app/build.gradle.kts` | `namespace` 与 `applicationId`（`applicationIdSuffix` 是 flavor 的事，见下） |
| 5 | `android/app/src/main/AndroidManifest.xml` | `android:label`（用户看到的桌面名） |
| 6 | `android/app/src/main/kotlin/**/MainActivity.kt` | `package` 声明，并把文件搬到与新 namespace 对应的目录，清掉空掉的旧目录 |
| 7 | `ios/Runner.xcodeproj/project.pbxproj` | `PRODUCT_BUNDLE_IDENTIFIER`（主 target 与 `.RunnerTests` 一起换） |
| 8 | `ios/Runner/Info.plist` | `CFBundleDisplayName`（显示名）、`CFBundleName`（跟着包名） |
| 9 | `.gitignore`、`<旧名>.code-workspace`、`README.md`、`.trellis/` 等文本 | 裸包名与工作区文件名（可选，缺了不拦） |

## 手工改时的坑

- **`namespace` 必须与 `MainActivity.kt` 的 `package` 一致**，且文件要待在
  `android/app/src/main/kotlin/<package 展开成目录>/` 下。只改 gradle 不改 Kotlin，
  或只改内容不搬文件，编译期才会报错，定位成本很高。
- **`PRODUCT_BUNDLE_IDENTIFIER` 不止一处**：主 target 在 Debug/Profile/Release 三个
  configuration 里各有一条，测试 target 还有三条 `.RunnerTests` 结尾的。整体替换主
  id 前缀就能全带上。
- **`CFBundleDisplayName` 与 `CFBundleName` 是两个 key**，值也不同（`Flutter App`
  vs `flutter_app`）。按 key 定位，别按值匹配。
- **`packages/app_lints/lib/src/paths.dart` 里硬编码了 `selfPackagePrefix`（`package:<包名>/`）**——
  规则 1/2 靠它把 import 解析成仓库内路径。忘了它，门禁会**静默失效**：所有 import 都被当成
  外部包放行。`tool/init_project.dart` 改名会一起改掉，`test/tool/self_package_prefix_test.dart`
  会在 `flutter test` 时复核两者一致。
- **`.dart_tool/package_config.json` 不用管**：它由 `flutter pub get` 重新生成，
  改完名跑一次 `flutter pub get` 即可。

## 之后

1. `just codegen` —— 改了注解 / 增删文件后必须重跑（生成物不入库，改名后本地那份已经不匹配源）
2. `flutter clean && flutter pub get`
3. `just verify`（清单以根 `justfile` 为准）
4. 需要图标就 `dart run flutter_launcher_icons`（`assets/icon/icon.png` 得先存在）

## 回归测试

`test/tool/init_project_test.dart` 用临时目录里的 fixture 覆盖了「改对了什么」与
「必改点缺失就中止且不写盘」。设 `SCAFFOLD_E2E=1` 时还会多跑一条端到端：
把真实仓库复制到临时目录 → 改名 → `flutter pub get` → `flutter analyze`，
用来兜住「改完名 import 全断」这类问题。

## 附加配置

### CI Pipeline / 门禁

清单以 `.github/workflows/ci.yml` 与 `.githooks/pre-commit` 为准 —— 两处都只是 `just verify`
（format、两组 `dart analyze --fatal-infos`、依赖检查、插件规则测试、目录树一致性、覆盖率门禁）。
改名不影响这些步骤，但**插件包里的包名前缀**是例外，见上面的坑。

### Environment Validation

`lib/bootstrap.dart` 在启动时校验 `_requiredEnvKeys`（当前是 `BASE_URL`），缺失或为空
直接抛异常（fail fast），任何构建模式都一样。

## 注意事项

- **applicationId**（`com.example.flutter_app`）是设备与商店里的唯一标识，首次发布前
  必须改掉。
- **package name** 影响 Dart import 路径。生成物不入库（`.gitignore` 排除），改名后本地那份
  已经不匹配源，跑一次 `just codegen` 即可。
- **显示名**（`CFBundleDisplayName` / `android:label`）才是用户看到的那个名字。
- **build flavor** 会让 `applicationId` 分散到多个 flavor 块里，脚本届时会「找不到
  模式」而失败退出。顺序上建议先初始化、后加 flavor；已经加了 flavor 就先手工改
  `applicationId` / `namespace`（或临时注释掉 flavor 块）。可复制片段见
  [docs/optional-additions.md](../../../docs/optional-additions.md) 第七节。
