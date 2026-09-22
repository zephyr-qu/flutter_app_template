# Database Guidelines

> Database and storage patterns for this project.

> **Scaffold note**: This is a personal Flutter scaffold/template for medium-small apps. Three persistence mechanisms ship with it: **SharedPreferences** (key-value), **Drift/SQLite** (relational cache), and **FileStorage** (files). You do not have to use all three — delete what the target app does not need.

---

## Overview

| Mechanism | Package | Implementation | Use for |
| ----------- | --------- | ---------------- | --------- |
| Key-value | `shared_preferences` | `UserPreferences`, `AuthStorage`（仅用户信息） | Preferences, settings, non-secret data |
| Secrets | `flutter_secure_storage` | `AuthStorage`（整条令牌 JSON） | Tokens and other credentials |
| Relational | `drift`（原生库由 `sqlite3` 3.x 的 build hook 提供） | `AppDatabase` (`lib/core/data/database/app_database.dart`) | Structured, queryable local cache |
| Files | `path_provider` | `FileStorage` (`lib/core/data/storage/file_storage.dart`) | Binary / large text data |

**不要**把令牌之类的敏感数据放进 `SharedPreferences`——那是明文的 XML/plist。令牌一律走 `flutter_secure_storage`（Android：KeyStore 包装的 AES-GCM，API 23+；iOS/macOS：Keychain；Windows：凭据管理器）。两种存储都在 `CoreModule` 里注册，直接注入即可。

---

## SharedPreferences (Key-Value)

`SharedPreferences` is resolved once via `@preResolve` in `CoreModule` and **injected** into the classes that need it. Never call `SharedPreferences.getInstance()` yourself.

```dart
// lib/core/core_module.dart
@module
abstract class CoreModule {
  @preResolve
  Future<SharedPreferences> get prefs => SharedPreferences.getInstance();

  @singleton
  AppDatabase get database => AppDatabase();
}
```

```dart
// lib/core/config/user_preferences.dart
@Singleton()
class UserPreferences {
  final SharedPreferences _prefs;

  UserPreferences(this._prefs) {
    _loadFromStorage();
  }

  final themeMode = signal<ThemeMode>(ThemeMode.system);
  final apiTimeout = signal<int>(30);

  void setThemeMode(ThemeMode mode) {
    themeMode.value = mode;
    _prefs.setInt(_keyThemeMode, mode.index);
  }
}
```

`AuthStorage` 把两类数据分开存：用户信息走 `SharedPreferences` 并镜像成信号；令牌走安全存储——整条 `TokenSet`（访问令牌 + 刷新令牌 + 绝对过期时刻）序列化成 JSON 存在**单个键**下，并在内存里缓存一份（因此 `getAccessToken()` 是同步的，拦截器不必每个请求都过一遍平台通道）。一个键就是一处状态，`saveTokens` / `clearAuth` 不必再维护多份副本的一致性。

```dart
@Singleton()
class AuthStorage {
  final SharedPreferences _prefs;
  final FlutterSecureStorage _secure;

  final currentUser = signal<User?>(null);

  /// 令牌载入内存的完成信号；拦截器在附加 Authorization 前会 await 它
  late final Future<void> ready;

  Future<void> saveUser(User? user);    // prefs + 信号
  Future<void> saveTokens(TokenSet t);  // 安全存储（单键 JSON）+ 内存缓存
  String? getAccessToken();             // 同步读内存缓存
  String? getRefreshToken();
  bool isAccessTokenExpiring();         // 是否临近过期（默认提前 30s）
  Future<void> clearAuth();             // 用户与令牌一起清
  bool get isLoggedIn;                  // 由 currentUser 推导
}
```

**Key naming convention**：`SharedPreferences` 用 `app.{domain}.{key}`（如 `app.theme.mode`）；认证相关只有两个键：`auth.user`（prefs，用户信息）与 `auth.tokens`（安全存储，整条令牌 JSON）。

- Always use `static const String _keyX = '...'` constants, never inline strings
- Because `SharedPreferences` is injected (not fetched in a lifecycle hook), there is no `init()` / `@PostConstruct` to call；安全存储在构造时异步载入，通过 `ready` 暴露完成时机
- `clearAuth()` 必须在本地总是成功：安全存储删除失败只记日志不外抛，否则离线/异常时会卡在「登不出去」的状态
- `saveTokens()` 相反——写不进安全存储就该让登录失败，不要留下只有内存副本的假登录态
- `TokenSet` 承担两件事，别在调用方重复做：传入的刷新令牌为空时**沿用当前值**（服务端只在轮换时才返回新的）；`expiresIn`（秒）在构造 `TokenSet` 时就换算成**绝对过期时刻**，因为落盘之后相对秒数已经没有意义

### AuthStorage 的失败策略：读要软，写要硬

| 操作 | 失败时 | 为什么 |
| --- | --- | --- |
| 构造时读安全存储 | 记 warning，降级为「未持有令牌」 | 安全存储不可用（如缺少平台实现）或 JSON 损坏，不该让 App 起不来；后续请求按未授权处理 |
| 读用户信息解析失败 | 记 warning，**删掉该键** | 损坏的数据留着只会让每次启动都失败一次 |
| 写安全存储（登录 / 刷新） | **向上抛** | 只有内存副本 = 假登录态，重启即「被登出」 |
| 删安全存储（登出） | 记 warning，不抛 | 本地登出必须成功；此时内存与 prefs 已清空，登录态已经正确 |

判断口径一句话：**读失败可以降级，写失败不能假装成功。**

**登录时的写入顺序**：`saveTokens()` 必须先于 `saveUser()`。`isLoggedIn` 由 `currentUser`
推导，先存用户会出现「已登录但拦截器还没拿到令牌」的窗口，紧随其后的第一个请求就不带
`Authorization`。

### 登录态：信号给监听，getter 给判断

`AuthStorage` 同时暴露两者，不要混用：

- `currentUser` / `isLoggedInSignal`（signals）—— 可被监听。`app.dart` 把它桥接成
  `AppRouter` 的 `reevaluateListenable`，401 触发的登出才能让栈上受保护路由的守卫重新生效。
- `isLoggedIn` / `currentUserId`（getter）—— 同步读一次，用于「这一刻」的判断
  （守卫内部、拦截器）。

用 getter 驱动 UI 重建不会生效（它不可监听）；只在需要读一次的地方包 signal 则是多余开销。

---

## Drift (Relational Cache)

`AppDatabase` 只负责**连接与 schema**：表定义（`DbArticles`）、`schemaVersion`、迁移。它在 `CoreModule` 里注册为 `@singleton`，首次解析时创建（即启动时打开数据库文件）。

**它已经被真正接进数据流**：`ArticleService` 用「缓存旁路」消费 `ArticleDao` —— 网络成功就刷新缓存，网络失败就回退到缓存，让离线时还能读到上次的内容。见 `features/article/data/article_service.dart`。

### 分工：schema 在 core，查询在 feature

| 内容 | 位置 | 为什么 |
| --- | --- | --- |
| 表结构、`schemaVersion`、迁移 | `core/data/database/tables/*.dart` | schema 是全局的，`@DriftDatabase` 必须看得见所有表；而 core 不能 import feature |
| 针对某张表的查询（DAO） | `features/{feature}/data/{feature}_dao.dart` | 查询按 feature 划分。写进 `AppDatabase` 就再也搬不出去（core 不能反向依赖），只会随 feature 数无限膨胀 |

这样加一个 feature 时 core 只多一个表文件，查询代码不堆在 core。

### drift 要求「表与数据库同一个 library」（踩过的坑）

当前用的是 drift 默认 codegen，它有一条硬约束：

- **表必须和数据库类**在同一个 library。表可以按表拆成独立文件，但必须写成 `part`：

  ```dart
  // core/data/database/app_database.dart
  part 'app_database.g.dart';
  part 'tables/db_articles.dart';

  // core/data/database/tables/db_articles.dart
  part of '../app_database.dart';   // ← part 文件不能有 import
  ```

  如果改用 `import 'tables/db_articles.dart'`：`AppDatabase` 仍能生成 schema，但
  `@DriftAccessor` 会失败并报
  `Could not read tables from @DriftAccessor annotation! Please make sure that all table classes exist.`
- **DAO 可以放独立 library**（所以能放 feature）。但**不要**用 `@DriftDatabase(daos: [...])`
  注册它 —— 那要求 core 反 import feature。改为在 feature 自己的 module 里构造注册：

  ```dart
  // features/article/data/article_module.dart
  @LazySingleton()
  ArticleDao articleDao(AppDatabase db) => ArticleDao(db);
  ```

- 行类 `DbArticle` 仍然生成在 `app_database.g.dart`，所以 feature 的 DAO 需要
  `import 'package:my_app/core/data/database/app_database.dart';` 才能拿到它。

- **加表**：新建 `tables/db_{name}.dart`，类名加 `Db` 前缀（见下节）→ 在
  `app_database.dart` 补一行 `part` → 加进 `@DriftDatabase(tables: [...])` →
  升 `schemaVersion` 并补 `MigrationStrategy` → `dart run build_runner build`
- **改表**：改 `tables/` 下的文件 → 升 `schemaVersion` 并补 `MigrationStrategy` →
  `dart run build_runner build`
- 测试用内存数据库（`NativeDatabase.memory()`）——DAO 见
  `test/features/article/data/article_dao_test.dart`，缓存旁路见
  `test/features/article/data/article_service_test.dart`

### 命名规范：加表就是加前缀

**加表 = 类名加 `Db` 前缀，就这一步。** 行类名、SQL 表名、表访问器全部由 drift
自动派生，**任何注解都不用写**（既不写 `@DataClassName`，也不写 `tableName`）：

| 层级 | 规则 | 例子 |
| --- | --- | --- |
| 表类 | `Db` + PascalCase 复数 | `DbArticles` |
| 行类 | drift **自动**按表名单数派生 | `DbArticle` |
| SQL 表名 | drift **自动**取类名 snake_case | `db_articles` |
| 文件名 | 类名的 snake_case | `tables/db_articles.dart` |

前缀的意义是让「数据库那一侧」和「业务模型」天然分得开，不用每个类单独起名：

| 类型 | 位置 | 语义 |
| --- | --- | --- |
| `DbArticle` | `app_database.g.dart`（生成） | 数据库里的一行 |
| `Article` | `features/article/data/models/article.dart` | 业务模型（freezed） |

两者字段目前一致，但**不要**合并：core 不能依赖 feature，反过来让 feature 的模型去当 drift 行类也会把两层绑死。

**互转也不放在模型上**，而是留在 `ArticleService` 的私有 `_toRow` / `_toModel` 里：

- `article.dart` 目前只 import `freezed_annotation`，**零 core 依赖**。一旦加上 `Article.fromRow(DbArticle)`，它就要 import `core/data/database/app_database.dart`（drift），而 import `Article` 的文件会全部被拖上 drift（写这份 spec 时是 13 个）—— 包括 `test/routing/main_shell_test.dart` 这种跟文章、缓存完全无关的测试
- `Article` 回答的是「一篇文章是什么」，「它怎么存在库里」是持久化的细节。模型已经知道 JSON（它同时是 API DTO），再加一个 drift 就同时绑住两层基础设施，换缓存实现时模型也得跟着改

转换出现**第二个消费者**时再抽出来 —— 抽成 `features/article/data/article_mapper.dart` 里的 extension（`DbArticle.toModel()` / `Article.toRow()`），**而不是塞进模型**。理由同上：模型不该知道 drift。

SQL 表名带 `db_` 前缀是**有意的**：SQL 里一眼能看出属于本 app，也不容易和 SQLite 保留字 / 将来共用的系统表撞。个别表确实需要干净的 SQL 名时，单独覆盖即可：

```dart
@override
String get tableName => 'articles';
```

> 已发布的库改 `tableName` 等于换表：旧数据还在文件里但没人读，需要清库或写
> `MigrationStrategy` 搬数据。

### 写缓存的两种语义，别用错

- `cacheArticles(list)` —— **先清后写**，用于整表快照（服务端删掉的文章不该留在缓存里）
- `cacheArticle(row)` —— upsert 单行，**不影响其它行**

写单篇时误用 `cacheArticles` 会把整个列表缓存清掉，所以两者都有测试盯着。

### 缓存自身的失败不该影响请求

缓存读/写抛异常时 `ArticleService` 只记 warning：数据已经拿到，磁盘问题不该把一次成功的请求变成失败。
反过来，**缓存未命中且网络也失败**时要返回**原始的** `Failure`（保留错误码），不要降级成「未知错误」。

> **sqlite3 的来源**：`pubspec.yaml` 不覆盖 `sqlite3` 的 hook 配置，走包默认行为——从 sqlite3.dart 的 release 下载带 SHA-256 校验的预编译库，并作为 code asset 打进产物。因此 Windows 上的 `flutter test` 和各平台 App 都不依赖系统 SQLite，**不需要**手动往项目根目录放 `sqlite3.dll`。
>
> 若确实想改用系统 SQLite（例如减小包体），可以加回 `hooks.user_defines.sqlite3.source: system`；但那样 Android/iOS 仍能用系统库，而 Windows 上跑 `flutter test` 就必须自己提供 `sqlite3.dll`，CI/新克隆会开箱即红。

---

## FileStorage

File-based storage for text and bytes。根目录是**自己拥有的两个子目录**，不是 `path_provider` 给的根：

```dart
@Singleton()
class FileStorage {
  /// 应用目录 / 临时目录下用来放本类文件的子目录名
  static const String namespace = 'file_storage';

  Future<Directory> get appDirectory;   // <documents>/file_storage
  Future<Directory> get tempDirectory;  // <tmp>/file_storage

  // text / bytes read + write, delete, temp cleanup, usage reporting
}
```

> **调用方**：「本地存储示例」页（`lib/features/demo/`）演示了它的用法——写入应用目录与临时目录、统计占用、清空临时目录。目标应用需要文件缓存时照着用即可；完全用不到就删掉这个示例页与 `file_storage.dart`。

See `lib/core/data/storage/file_storage.dart` for the exact signatures.

- Use `appDirectory` for persistent data and `tempDirectory` for cache

### 为什么必须有自己的子目录

临时目录**是全 App 共用的**：图片缓存、下载、播放器之类的插件都往同一个根目录里放文件。所以：

- `clearTemp()` 只清 `tempDirectory`。**不要**写成「把临时根目录 `listSync()` 后逐个 `delete(recursive: true)`」——那会连带删掉其他插件的缓存，而这段代码是要被复制走的模板，坑会跟着传播
- 读写路径一律由 `_buildPath` 拼到自己的子目录下，不直接落根目录

### 不用同步 IO

`listSync()` / `readAsStringSync()` / `existsSync()` 会把整个遍历或读写同步走完，**直接阻塞 UI isolate**。遍历一律用 `Directory.list()` 的流式接口（`await for`）：

```dart
await for (final entry in dir.list(recursive: true, followLinks: false)) {
  if (entry is File) total += await entry.length();
}
```

逐个 `await` 比一次性 `Future.wait` 铺开所有 stat 慢，但占用统计不在热路径上，稳定优先。

---

## Query Patterns

- Remote reads go through Retrofit `@GET` / `@POST` definitions in each feature's `*_api.dart`; errors are normalised to `Result<T, Failure>` (see [error-handling.md](./error-handling.md))
- Local relational reads go through Drift's generated query API on `AppDatabase`

---

## Naming Conventions

| Element | Convention | Example |
| --------- | ----------- | --------- |
| SharedPrefs key | `app.{domain}.{key}` | `app.theme.mode`, `auth.user` |
| Drift table | `Db` + PascalCase plural | `DbArticles` |
| Drift row class | drift 自动派生（表名单数） | `DbArticle` |
| Drift generated file | `{source}.g.dart` | `app_database.g.dart` |
| FileStorage filename | any valid filename | `'user_avatar.png'` |

---

## Common Mistakes

- ❌ **Calling `SharedPreferences.getInstance()` in multiple places** — inject the pre-resolved instance from `CoreModule`
- ❌ **Adding an `init()` / `@PostConstruct` to fetch preferences** — the dependency is already injected and resolved
- ❌ **Editing `*.g.dart` by hand** — regenerate with `dart run build_runner build`
- ❌ **Changing a Drift schema without bumping `schemaVersion`** — existing installs will not migrate
- ❌ **Storing secrets in `SharedPreferences`** — add a secure-storage dependency if you need it; do not assume one is present
