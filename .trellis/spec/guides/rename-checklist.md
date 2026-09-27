# 改名清单

> 用这个脚手架开新项目时怎么改名。

## 首选：跑脚本，不要手工改

```bash
dart run tool/init_project.dart                 # 交互式：包名 / applicationId / iOS Bundle ID / 显示名
dart run tool/init_project.dart --yes --name=your_app \
  --application-id=com.yourcompany.yourapp      # 非交互（CI / 脚本）
```

脚本的语义是**全有或全无**：先规划、后写盘，任一必改点没匹配到就以非零退出码结束、磁盘保持原样。

覆盖范围（也就是手工改时要做完的事）：

| # | 位置 | 改什么 |
| --- | ------ | ------- |
| 1 | `pubspec.yaml` | `name:`（同时决定所有 import 路径）、`description:` |
| 2 | `lib/` `test/` `integration_test/` `tool/` | `package:<旧名>/` → `package:<新名>/`（含生成物，省得再跑 codegen） |
| 3 | `lib/app/app.dart`、`lib/bootstrap.dart` 及引用它们的测试 | 根组件类名 `MyApp` → 新类名（整词替换） |
| 4 | `android/app/build.gradle.kts` | `namespace` 与 `applicationId`（`applicationIdSuffix` 是 flavor 的事，见下） |
| 5 | `android/app/src/main/AndroidManifest.xml` | `android:label`（用户看到的桌面名） |
| 6 | `android/app/src/main/kotlin/**/MainActivity.kt` | `package` 声明，并把文件搬到与新 namespace 对应的目录，清掉空掉的旧目录 |
| 7 | `ios/Runner.xcodeproj/project.pbxproj` | `PRODUCT_BUNDLE_IDENTIFIER`（主 target 与 `.RunnerTests` 一起换） |
| 8 | `ios/Runner/Info.plist` | `CFBundleDisplayName`（显示名）、`CFBundleName`（跟着包名） |
| 9 | `.gitignore`、`<旧名>.code-workspace`、`README.md`、`.trellis/` 等文本 | 裸包名与工作区文件名（可选，缺了不拦） |

## 手工改时的坑

- **`namespace` 必须与 `MainActivity.kt` 的 `package` 一致**，且文件要待在
  `android/app/src/main/kotlin/<package 展开成目录>/` 下。
- **`PRODUCT_BUNDLE_IDENTIFIER` 不止一处**：主 target 在 Debug/Profile/Release 各一条，
  测试 target 还有三条 `.RunnerTests` 结尾的 —— 整体替换主 id 前缀即可。
- **`CFBundleDisplayName` 与 `CFBundleName` 是两个 key**，值也不同（`Flutter App` vs
  `flutter_app`）。按 key 定位，别按值匹配。
- **`packages/app_lints/lib/src/paths.dart` 硬编码了 `package:<包名>/` 前缀**（`selfPackagePrefix`，
  边界规则靠它把 import 解析成仓库内路径）。忘了它，边界门禁静默失效。
  `tool/init_project.dart` 会一起改掉。
- **`.dart_tool/package_config.json` 不用管**：由依赖解析重新生成，改完名跑一次 `just deps`。

## 之后

1. `just codegen` —— 仅当你同时改了注解或增删了文件才需要；纯改名不用跑（见覆盖范围第 2 项）
2. `flutter clean && just deps`
3. `flutter analyze` + `just verify`
4. 需要图标就 `dart run flutter_launcher_icons`（`assets/icon/icon.png` 得先存在）

## 回归测试

`test/tool/init_project_test.dart` 用临时目录 fixture 覆盖「改对了什么」与「必改点缺失就中止且不写盘」；`SCAFFOLD_E2E=1` 时再跑一条端到端：复制真实仓库 → 改名 → `flutter pub get` → `flutter analyze`。

## 附加配置

### CI Pipeline / 门禁

门禁清单以根 `justfile` 为准，`.github/workflows/ci.yml` 与 `.githooks/pre-commit` 都通过它执行（CI 会先现场跑 codegen；`packages/app_lints/` 分析插件）。唯一例外是**插件里硬编码的包名前缀**，见上面的坑。

### 环境校验

`lib/bootstrap.dart` 启动时校验 `_requiredEnvKeys`（当前是 `BASE_URL`，由 dotenv 从 `.env.example` 读入），缺失或为空直接抛异常（fail fast），任何构建模式都一样。

## 注意事项

- **applicationId**（`com.example.flutter_app`）是设备与商店里的唯一标识，首次发布前必须改掉。
- **package name** 影响 Dart import 路径。生成物（`*.g.dart` / `*.freezed.dart` / `*.gr.dart`）
  已经随脚本一起改；只有在你额外改了注解或增删了文件时才需要重跑 build_runner。
- **显示名**（`CFBundleDisplayName` / `android:label`）才是用户看到的那个名字。
- **build flavor** 会让 `applicationId` 分散到多个 flavor 块里，脚本届时会「找不到模式」而失败退出。
  顺序上建议先初始化、后加 flavor；已经加了 flavor 就先手工改 `applicationId` / `namespace`（或临时
  注释掉 flavor 块）。可复制片段见 [docs/optional-additions.md](../../../docs/optional-additions.md) 第七节。
