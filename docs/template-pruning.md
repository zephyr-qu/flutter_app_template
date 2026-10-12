# 模板裁剪与占位清单

从这个脚手架派生新项目时，两件事在本文件里：**用不到的示例模块怎么删干净**，
以及**哪些位置是刻意留空的骨架**。

> 快照（2026-10）：删除清单里的具体路径会随代码改动过期，改动相关代码时请同步本文件。

---

## 删除示例模块

三个示例模块（`auth` / `article` / `demo`）用来演示数据流，确认看懂结构后可以删。
顺序别颠倒：**先删目录 → 再清引用 → 最后重跑 codegen**。

### 认证与文章（`auth` + `article`）

删除 `lib/features/auth/` 与 `lib/features/article/` 两个目录，再同步清理四处引用：

| # | 位置 | 要清掉的东西 |
|---|------|--------------|
| 1 | `lib/app/routing/router.dart` | 两个模块的路由与 `@RoutePage` 注解 |
| 2 | `lib/core/data/network/dio_client.dart` | `_registerMockRules()` 里的对应 Mock 规则 |
| 3 | `lib/features/home/page/main_page.dart` | 底部导航中的文章 Tab |
| 4 | `lib/features/profile/page/profile_page.dart` | 对 `AuthViewModel` / `User` 的引用 |

最后跑 `just codegen` —— 不生成的话，删掉的路由类仍留在 `router.gr.dart` 与 DI 注册里。

### 本地存储（`demo`）

用不到 `FileStorage` / Drift 缓存时，删掉 `lib/features/demo/`，再清掉两处引用：

| # | 位置 | 要清掉的东西 |
|---|------|--------------|
| 1 | `lib/app/routing/router.dart` | `StorageDemoRoute` |
| 2 | `lib/features/profile/page/profile_page.dart` | 「设置」里的示例入口 |

注意 `ArticleService` 的离线缓存**仍在**使用 `AppDatabase`：删 `demo` 不会连带删掉数据库。
要连缓存一起删，见 [database-guidelines.md](../.trellis/spec/data/database-guidelines.md)。

---

## `TODO(template)` 与其它占位

脚手架刻意留了几处「有 UI、没功能」的位置。带标记的那几处用
`grep -rn "TODO(template)" lib/` 可列全（都在 `lib/features/profile/page/profile_settings.dart`）；
下表还包括几处**没有标记**、但同样只是占位的地方 —— 它们靠本文件记录，别当成已实现的功能：

| 位置 | 现状 | 处理 |
|------|------|------|
| 「设置」→ 通知 / 隐私 / 帮助 | 只有入口，`onTap` 为空（带 `TODO(template)` 标记） | 替换 `onTap`，或整项删掉（连同其下的 `_Divider`） |
| 首页「最近动态」 | `lib/features/home/page/home_page.dart` 里的静态空态，无标记 | 换成自己的数据源 |
| `.env.example` | 默认值与示例（`BASE_URL` / `USE_MOCK`），会提交；真实 `.env*` 已被 gitignore | 要连自己的后端就改它（密钥别写进去，它会被打进产物） |
| 应用图标 | `pubspec.yaml` 的 `flutter_launcher_icons.image_path` 指向 `assets/icon/icon.png`，**该文件不存在**（跑图标命令会直接失败） | 补上图标文件，或删掉这段配置 |
| release 构建 | 仍用 debug keystore 签名、未 minify、无 flavor、iOS 未签名 | 按 [release-checklist.md](./release-checklist.md) 补齐 |
