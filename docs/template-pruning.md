# 模板裁剪与占位清单

从这个脚手架派生新项目时，三件事在本文件里：**用不到的示例模块怎么删**（一条命令）、
**auth 怎么手工改造**（改造，不是删目录）、以及**哪些位置是刻意留空的骨架**。

> 示例模块的「删哪里」清单**不再由本文件手工维护**。它已经漂移过一次 —— 漏了首页快捷入口、
> Drift 表声明、测试里的路由与注释里的散文引用。清单的唯一权威是
> `tool/prune_examples.dart` 的锚点表，由 `test/tool/prune_examples_test.dart` 盯着：
> 任何一处锚点对不上，测试立刻红。

---

## 用工具剪枝（`article` / `demo`）

```bash
dart run tool/prune_examples.dart                                  # 交互式
dart run tool/prune_examples.dart --yes --modules=article,demo      # 非交互
```

工具按固定顺序做四件事：

1. 删 `lib/features/{article,demo}/` 与 `test/features/{article,demo}/`，并清理**全部**引用点 ——
   路由表、底部导航标签、首页快捷入口、Mock 规则、`@DriftDatabase` 的表声明、相关测试与注释
2. 重跑 `just codegen`（删掉 `@RoutePage` / `@injectable` / Drift 表后不重生成，产物里会留着已删类型）
3. 按模块指纹扫描残留：**代码侧残留 = 失败**，**文档侧残留 = 打印清单**
4. 跑 `just verify` 自证

| 约定 | 说明 |
| --- | --- |
| 全或无 | 任一锚点没匹配到就中止，**一个字节都不写**，并逐条列出没对上的位置 |
| 前置 | 工作区必须干净（工具做的是不可逆删除），`--force` 可越过 |
| 幂等 | 模块目录已不存在时提示「已经剪过」并以 0 退出 |
| 回滚 | `git checkout -- . && git clean -fd` |
| 退出码 | `0` 成功／`1` 锚点或残留失败／`2` 输入被拒／`3` codegen 或 verify 失败 |
| 绕过自证 | `--no-verify` 只打印下一步命令，不跑 codegen 与门禁 |

**`auth` 不参与剪枝** —— 工具接受 `--modules=auth` 但以退出码 2 拒绝，理由见下一节。

剪枝后 `FileStorage` 与 `AppDatabase` 会没有应用内消费者，但**工具有意保留**它们：
它们是 core 能力而不是示例，错删的代价高于留下的代价。确定不要就手删 ——
`grep -rn "FileStorage" lib/` 能把引用列全。

### 工具报「文档里有残留」时

那是提示，不是失败。`.trellis/spec/**`、`AGENTS.md`、`README.md` 把 `lib/features/article/`
当作「照抄这个形状」的教学范例，自动改写只会产出空话 —— **要人工决定改写还是删掉整段**。
`AGENTS.md` 的「照抄对象」一节最先需要处理：它整节都在指一个已经不存在的目录。

---

## `auth` 的手工改造

`auth` 既是示例又是基础设施：`AuthStorage` 被路由守卫在**每次导航时**实时读取，
`auth_interceptor` / `token_refresher` / `token_store` 挂在网络层，`lib/app/app.dart` 用
`AuthReevaluateListenable` 把登录态桥给路由器。**所以它不是「删一个目录」的事，是一次架构改造**，
工具不代劳。要改成无登录的应用，下面是会被牵动的面（按依赖顺序读一遍再动手）：

| 位置 | 处理 |
| --- | --- |
| `lib/features/auth/` + `test/features/auth/` | 删（登录页、ViewModel、API、Service、Repository、模型） |
| `lib/app/routing/router.dart` | 去掉 `_checkAuth` 守卫、`LoginRoute` 与 `authStorage` 字段 |
| `lib/app/app.dart`、`lib/app/routing/auth_reevaluate.dart` | 去掉登录态桥接与 `reevaluateListenable` |
| `lib/app/pages/splash_page.dart` | 去掉「已登录 / 未登录」分流，直接进主框架 |
| `lib/core/data/storage/auth_storage.dart`、`network/auth_interceptor.dart`、`network/token_refresher.dart`、`network/token_store.dart`、`network/auth_extra_keys.dart` | 删；`dio_factory.dart` 的拦截器装配随之简化 |
| `lib/core/models/user.dart`、`core/models/token_set.dart` | 删（`profile_header` / `profile_page` 对 `User` 的用法一起改） |
| `lib/features/profile/**` | 登出按钮与 `AuthRepository` 引用 |
| `.env.example` | `USE_MOCK` 若不再需要 Mock，一并去掉 |

> 官方 Mock 规则（`/login`、`/refresh`）在 `lib/core/data/network/dio_client.dart` 里，
> 剪掉 `article` 后**仍然保留** —— 它们是给 auth 用的。

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
