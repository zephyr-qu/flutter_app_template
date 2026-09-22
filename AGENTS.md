<!-- TRELLIS:START -->
# Trellis Instructions

These instructions are for AI assistants working in this project.

## Project Nature: Personal Flutter Scaffold

This project is a **personal Flutter scaffold/template** for medium-small apps, not a production application. It provides a clean starting point with:

- **Feature-Sliced Design (FSD 简化版)** feature-first structure
- **Signals + ViewModel** state management
- **auto_route** declarative routing
- **Injectable + GetIt** dependency injection
- **Material Design 3** theming
- **Retrofit + Dio** API client pattern
- **Chinese-first UI**（用户可见文案走 l10n，模板语言中文，另有英文）+ **English identifiers**、**Chinese comments**

### Starting a New Project From This Scaffold

#### Quick way (automated)

```bash
dart run tool/init_project.dart
```

This interactive script updates the following files:

- `pubspec.yaml` → `name`, `description`
- 全仓库 → `package:<旧名>/` → `package:<新名>/`（含生成物）与根组件类名
- `android/app/build.gradle.kts` → `namespace`, `applicationId`
- `android/app/src/main/AndroidManifest.xml` → `android:label`
- `android/app/src/main/kotlin/**/MainActivity.kt` → `package` 声明（文件同步搬到新目录）
- `ios/Runner/Info.plist` → `CFBundleDisplayName`, `CFBundleName`
- `ios/Runner.xcodeproj/project.pbxproj` → `PRODUCT_BUNDLE_IDENTIFIER`（含 `.RunnerTests`）

任一必改点没匹配到就以非零退出码结束，**不写任何文件**（先规划、后写盘）。

非交互用法（不提问，缺失项按默认值推导）：

```bash
dart run tool/init_project.dart --yes --name=my_next_app \
  --application-id=com.example.my_next_app
```

After the script:

```bash
dart run build_runner build
flutter analyze
```

#### Manual way

1. Update `pubspec.yaml` → `name`, then replace `package:<old>/` across the repo
2. Update `android/app/build.gradle.kts` → `namespace` + `applicationId`
3. Move `android/app/src/main/kotlin/**/MainActivity.kt` into the directory matching the
   new namespace and update its `package` declaration（两者必须一致）
4. Update `android/app/src/main/AndroidManifest.xml` → `android:label`
5. Update `ios/Runner/Info.plist` → `CFBundleDisplayName`, `CFBundleName`
6. Update `ios/Runner.xcodeproj/project.pbxproj` → `PRODUCT_BUNDLE_IDENTIFIER`（含 `.RunnerTests`）
7. Replace the `MyApp` class name in `lib/app/app.dart`, `lib/bootstrap.dart` and its usages
8. Run `dart run build_runner build` to regenerate configs

### Pre-commit Hooks

This scaffold includes a pre-commit hook in `.githooks/pre-commit`（格式、架构边界、目录树一致性、依赖声明、analyze、测试覆盖率等多项检查）。

清单以脚本本身为准；每道门禁的语义与阈值见 `.trellis/spec/cross-cutting.md` —— 本文件不再逐项维护，内联的清单一定会过时。

To activate:

```bash
git config core.hooksPath .githooks
```

To skip (emergency only): `git commit --no-verify`

### Working Knowledge

The working knowledge you need lives under `.trellis/`:

- `.trellis/workflow.md` — development phases, when to create tasks, skill routing
- `.trellis/spec/` — package- and layer-scoped coding guidelines (read before writing code in a given layer); 跨层的门禁与发布约定在 `.trellis/spec/cross-cutting.md`
- `.trellis/workspace/` — per-developer journals and session traces
- `.trellis/tasks/` — active and archived tasks (PRDs, research, jsonl context)

If a Trellis command is available on your platform (e.g. `/trellis:finish-work`, `/trellis:continue`), prefer it over manual steps. Not every platform exposes every command.

If you're using an agent-capable tool, additional project-scoped helpers live in:

- `.agents/skills/` — reusable Trellis skills

Managed by Trellis. Edits outside this block are preserved; edits inside may be overwritten by a future `trellis update`.

<!-- TRELLIS:END -->
