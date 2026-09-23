# Database Guidelines

> Database and storage patterns for this project.

> **Scaffold note**: This is a personal Flutter scaffold/template for medium-small apps. Three persistence mechanisms ship with it: **SharedPreferences** (key-value), **Drift/SQLite** (relational cache), and **FileStorage** (files). You do not have to use all three — delete what the target app does not need.

---

## Overview

| Mechanism | Package | Implementation | Use for |
| ----------- | --------- | ---------------- | --------- |
| Key-value | `shared_preferences` | `UserPreferences`、`AuthStorage`（仅用户信息） | Preferences, settings, non-secret data |
| Secrets | `flutter_secure_storage` | `AuthStorage`（整条令牌 JSON） | Tokens and other credentials |
| Relational | `drift`（原生库由 `sqlite3` 3.x 的 build hook 提供） | `AppDatabase`（`packages/app_core/lib/data/database/app_database.dart`） | Structured, queryable local cache |
| Files | `path_provider` | `FileStorage`（`packages/app_core/lib/data/storage/file_storage.dart`） | Binary / large text data |

**不要**把令牌之类的敏感数据放进 `SharedPreferences`——那是明文的 XML/plist。令牌一律走 `flutter_secure_storage`（Android：KeyStore 包装的 AES-GCM，API 23+；iOS/macOS：Keychain；Windows：凭据管理器）。两者的实例都由 provider 装配（`lib/core/providers.dart`），业务代码只 `ref.watch`，不自己 new。

---

## 状态管理与存储的分工

本分支（`preset/ai-starter`，Riverpod）有一条贯穿全部存储的约定：
**存储对象不依赖状态管理，状态由另外一层 provider 负责。**

| 存储对象（`lib/core/`） | 状态层（provider） | 分工 |
| --- | --- | --- |
| `AuthStorage` | `core/auth/session.dart` 的 `Session` | 存储暴露同步 getter + `userChanges` 流；`Session` 订阅它，给 UI 一份可 watch 的登录态 |
| `UserPreferences` | `core/config/app_settings.dart` 的 `AppSettingsNotifier` | 存储只读写 prefs；Notifier 持有内存快照并在写入后落盘 |

好处是存储对象能**脱开容器单测**（喂一个 mock 过的 `SharedPreferences` / 安全存储即可），
而页面拿到的是「一份可订阅的快照」而不是「每次读盘」。写入顺序统一是**先改内存、再落盘**
（UI 立刻响应；落盘失败只记日志）。

### AuthStorage 的接口

`AuthStorage` 实现 `app_core` 的 `TokenStore`，对外只有同步 getter 与一条流：

```dart
class AuthStorage implements TokenStore {
  User? get currentUser;          // 同步真源；未登录为 null
  bool get isLoggedIn;           // 由 currentUser 推导
  Stream<User?> get userChanges; // 广播流，订阅时立刻吐当前值
  late final Future<void> ready; // 令牌载入内存的完成信号

  Future<void> saveUser(User? user);    // prefs + 通知订阅者
  Future<void> saveTokens(TokenSet t);  // 安全存储（单键 JSON）+ 内存缓存
  String? getAccessToken();             // 同步读内存缓存
  String? getRefreshToken();
  bool isAccessTokenExpiring();         // 是否临近过期（默认提前 30s）
  Future<void> clearAuth();             // 用户与令牌一起清
  Future<void> dispose();               // 关闭变化流（容器销毁时由 ref.onDispose 调）
}
```

`saveTokens` 里两条容易漏的：

- **刷新令牌为空时沿用当前值** —— 服务端只在轮换时返回新的，用 null 覆盖会把可用会话丢掉
- **`expiresIn`（秒）在构造 `TokenSet` 时就换算成绝对过期时刻**，因为落盘之后相对秒数已经没有意义

登录时的**写入顺序**：`saveTokens()` 必须先于 `saveUser()`。`isLoggedIn` 由 `currentUser`
推导，先存用户会出现「已登录但拦截器还没拿到令牌」的窗口，紧随其后的第一个请求就不带
`Authorization`。

### 登录态：provider 给订阅，getter 给判断

`AuthStorage` 同时暴露两者，不要混用：

- `Session` provider（`core/auth/session.dart`）—— 可订阅的镜像。`app.dart` 接的是
  `authReevaluateProvider`，401 触发的登出才能让栈上受保护路由的守卫重新生效，
  页面用 `ref.watch(sessionProvider)` 拿用户。
- `isLoggedIn` / `currentUserId`（getter）—— 同步读一次，用于「这一刻」的判断
  （路由守卫内部、拦截器、`SplashPage` 的跳转）。

用 getter 驱动 UI 重建不会生效（它不可订阅）；只在需要读一次的地方订阅 provider 则是多余开销。
**守卫不要改成读 provider**：那会引入「状态还没 emit → 先判成未登录」的空窗。

### 为什么 401 之后的登出要经 `userChanges` 回流

`AuthInterceptor` 在 `app_core` 里，只认识 `TokenStore`，不认识 Riverpod。所以「凭证被清了」
这件事只能由存储经 `userChanges` 广播出来，`Session` 与路由守卫才有得订阅——完整链路见
[error-handling.md](./error-handling.md)「登出语义」。

`userChanges` 是**广播流**并且在订阅时立刻吐出当前值，消费者不必先读 `currentUser` 再订阅。

### AuthStorage 的失败策略：读要软，写要硬

| 操作 | 失败时 | 为什么 |
| --- | --- | --- |
| 构造时读安全存储 | 记 warning，降级为「未持有令牌」 | 安全存储不可用（如缺少平台实现）或 JSON 损坏，不该让 App 起不来；后续请求按未授权处理 |
| 读用户信息解析失败 | 记 warning，**删掉该键** | 损坏的数据留着只会让每次启动都失败一次 |
| 写安全存储（登录 / 刷新） | **向上抛** | 只有内存副本 = 假登录态，重启即「被登出」 |
| 删安全存储（登出） | 记 warning，不抛 | 本地登出必须成功；此时内存与 prefs 已清空，登录态已经正确 |

判断口径一句话：**读失败可以降级，写失败不能假装成功。**

**Key naming convention**：`SharedPreferences` 用 `app.{domain}.{key}`（如 `app.theme.mode`）；
认证相关只有两个键：`auth.user`（prefs，用户信息）与 `auth.tokens`（安全存储，整条令牌 JSON）。
Always use `static const String _keyX = '...'` constants, never inline strings.

`prefs` 本身由 `bootstrap()` 预载后用 `prefsProvider.overrideWithValue(prefs)` 注入
（`SharedPreferences.getInstance()` 是异步的，而消费者都是同步构造的）。**不要**在别处再调
`SharedPreferences.getInstance()`，也不要把它做成 `FutureProvider`——理由见
`lib/core/providers.dart` 的 `prefsProvider`。

---

## Drift (Relational Cache)

`AppDatabase` 只负责**连接与 schema**：表定义（`DbArticles`）、`schemaVersion`、迁移。
它在 `packages/app_core` 里（`app_core` 不依赖状态管理，所以没有装配注解），
由 `lib/core/providers.dart` 的 `databaseProvider` 建成单例。

**它已经被真正接进数据流**：`SampleService` 用「缓存旁路」消费 `SampleDao` —— 网络成功就刷新
缓存，网络失败就回退到缓存，让离线时还能读到上次的内容
（`features/sample/data/sample_service.dart`）。

### 分工：schema 在共享包，查询在 feature

| 内容 | 位置 | 为什么 |
| --- | --- | --- |
| 表结构、`schemaVersion`、迁移 | `packages/app_core/lib/data/database/` | schema 是全局的，`@DriftDatabase` 必须看得见所有表；而共享包不能 import feature |
| 针对某张表的查询（DAO） | `features/{feature}/data/{feature}_dao.dart` | 查询按 feature 划分。写进 `AppDatabase` 就再也搬不出去（共享包不能反向依赖），只会随 feature 数无限膨胀 |

这样加一个 feature 时共享包只多一张表，查询代码不堆在共享包里。

### 表必须 part 进数据库文件（踩过的坑）

drift 的默认 codegen 有一条硬约束：**表必须和数据库类在同一个 library**。
表可以按表拆成独立文件，但必须写成 `part`：

```dart
// packages/app_core/lib/data/database/app_database.dart
part 'app_database.g.dart';
part 'tables/db_articles.dart';    // ← 不是 import

// packages/app_core/lib/data/database/tables/db_articles.dart
part of '../app_database.dart';    // ← part 文件不能有 import
```

写成 `import 'tables/db_articles.dart'` 的话，`AppDatabase` 仍能生成 schema，但
`@DriftAccessor` 会失败并报
`Could not read tables from @DriftAccessor annotation! Please make sure that all table classes exist.`

### ⚠️ 跨 package 时不要用 `@DriftAccessor`

抽包之后 `@DriftAccessor(tables: [DbArticles])` **不再可用**：`drift_dev` 解析不到另一个 package
里的表（drift#3669），生成出来的 mixin 是**空的** —— 报
`The referenced element, DbArticles, is not understood by drift`，然后 `dbArticles` 未定义、
DAO 编译不过。

实测边界：同 package 内**无论表在 part 文件还是与数据库同一文件都正常**，只有跨 package 会失败。

所以 DAO 直接持有 `AppDatabase`，用它的生成 getter 取表：

```dart
// features/sample/data/sample_dao.dart
class SampleDao {
  new(this._db);
  final AppDatabase _db;

  Future<List<DbArticle>> getCachedItems() => _db.select(_db.dbArticles).get();

  Future<void> cacheItem(DbArticle item) =>
      _db.into(_db.dbArticles).insertOnConflictUpdate(item);
}
```

装配在 feature 自己的 provider 文件里（**不要**用 `@DriftDatabase(daos: [...])` —— 那要求共享包
反 import feature）：

```dart
// features/sample/data/sample_providers.dart
@Riverpod(keepAlive: true)
SampleDao sampleDao(Ref ref) => SampleDao(ref.watch(databaseProvider));
```

- 行类 `DbArticle` 生成在 `packages/app_core/lib/data/database/app_database.g.dart`，所以 feature
  的 DAO 需要 `import 'package:app_core/data/database/app_database.dart';` 才能拿到它。

> 根治要动共享包（例如把表与 DAO 各自独立成 library，或等 drift 修 #3669）。
> 在此之前，**新增 DAO 一律照 `SampleDao` 的写法**。

### 加表 / 改表

- **加表**：新建 `tables/db_{name}.dart`，类名加 `Db` 前缀（见下节）→ 在
  `app_database.dart` 补一行 `part` → 加进 `@DriftDatabase(tables: [...])` →
  升 `schemaVersion` 并补 `MigrationStrategy` → `dart run build_runner build`
- **改表**：改 `tables/` 下的文件 → 升 `schemaVersion` 并补 `MigrationStrategy` →
  `dart run build_runner build`
- 测试用内存数据库（`NativeDatabase.memory()`）：DAO 见
  `test/features/sample/data/sample_dao_test.dart`，缓存旁路见
  `test/features/sample/data/sample_service_test.dart`

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
| `SampleItem` | `features/sample/data/models/sample_item.dart` | 业务模型（freezed） |

两者字段目前一致，但**不要**合并：共享包不能依赖 feature，反过来让 feature 的模型去当 drift
行类也会把两层绑死。

**互转也不放在模型上**，而是留在 `SampleService` 的私有 `_toRow` / `_toModel` 里：

- `sample_item.dart` 只 import `freezed_annotation`，**零数据库依赖**。一旦加上
  `SampleItem.fromRow(DbArticle)`，它就要 import drift 生成物，而所有 import `SampleItem` 的文件
  都会被动拖上 drift —— 包括跟缓存完全无关的页面与测试
- 模型回答的是「一条数据是什么」，「它怎么存在库里」是持久化的细节。模型同时还是 API DTO，
  再加一个 drift 就同时绑住两层基础设施，换缓存实现时模型也得跟着改

转换出现**第二个消费者**时再抽出来 —— 抽成 `features/{feature}/data/{feature}_mapper.dart` 里的
extension，**而不是塞进模型**。理由同上：模型不该知道 drift。

SQL 表名带 `db_` 前缀是**有意的**：SQL 里一眼能看出属于本 app，也不容易和 SQLite 保留字 /
将来共用的系统表撞。个别表确实需要干净的 SQL 名时，单独覆盖即可：

```dart
@override
String get tableName => 'articles';
```

> 已发布的库改 `tableName` 等于换表：旧数据还在文件里但没人读，需要清库或写
> `MigrationStrategy` 搬数据。

### 写缓存的两种语义，别用错

- `cacheItems(list)` —— **先清后写**，用于整表快照（服务端删掉的条目不该留在缓存里）
- `cacheItem(row)` —— upsert 单行，**不影响其它行**

写单条时误用 `cacheItems` 会把整个列表缓存清掉，所以两者都有测试盯着。

### 缓存自身的失败不该影响请求

缓存读/写抛异常时 `SampleService` 只记 warning：数据已经拿到，磁盘问题不该把一次成功的请求变成失败。
反过来，**缓存未命中且网络也失败**时要返回**原始的** `Failure`（保留错误码），不要降级成「未知错误」。

> **sqlite3 的来源**：`pubspec.yaml` 不覆盖 `sqlite3` 的 hook 配置，走包默认行为——从 sqlite3.dart 的 release 下载带 SHA-256 校验的预编译库，并作为 code asset 打进产物。因此 Windows 上的 `flutter test` 和各平台 App 都不依赖系统 SQLite，**不需要**手动往项目根目录放 `sqlite3.dll`。
>
> 若确实想改用系统 SQLite（例如减小包体），可以加回 `hooks.user_defines.sqlite3.source: system`；但那样 Android/iOS 仍能用系统库，而 Windows 上跑 `flutter test` 就必须自己提供 `sqlite3.dll`，CI/新克隆会开箱即红。

---

## FileStorage

File-based storage for text and bytes。根目录是**自己拥有的两个子目录**，不是 `path_provider` 给的根：

```dart
// packages/app_core/lib/data/storage/file_storage.dart
class FileStorage {
  /// 应用目录 / 临时目录下用来放本类文件的子目录名
  static const String namespace = 'file_storage';

  Future<Directory> get appDirectory;   // <documents>/file_storage
  Future<Directory> get tempDirectory;  // <tmp>/file_storage

  // text / bytes read + write, delete, temp cleanup, usage reporting
}
```

它不带装配注解（共享包不依赖状态管理），由 `lib/core/providers.dart` 的
`fileStorageProvider` 建成 provider。精确签名见
`packages/app_core/lib/data/storage/file_storage.dart`。

> **本分支没有 FileStorage 的示例页**：`features/demo/` 已随示例收敛删除。要看用法就照
> `packages/app_core/test/data/storage/file_storage_test.dart`（真实文件 + 内存路径）写，
> 需要文件缓存的目标应用再自己建页面。

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
- Local relational reads go through Drift's generated query API on `AppDatabase`（DAO 由 feature 持有，见上文）

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

- ❌ **Calling `SharedPreferences.getInstance()` somewhere other than `bootstrap()`** — 它只在那里 await 一次，其余地方读 `prefsProvider`
- ❌ **把 `prefs` 做成 `FutureProvider`** — `AsyncValue` 会一路传染到所有消费者（见 `lib/core/providers.dart`）
- ❌ **给 `AuthStorage` / `UserPreferences` 加状态管理依赖** — 它们要能脱开容器单测；状态在 `Session` / `AppSettingsNotifier` 里
- ❌ **路由守卫改成读 provider** — 会引入「状态还没 emit → 先判成未登录」的空窗；守卫读 `AuthStorage.isLoggedIn`
- ❌ **用 `@DriftAccessor` 写跨 package 的 DAO** — 生成的 mixin 是空的，编译不过（drift#3669）
- ❌ **Editing `*.g.dart` by hand** — regenerate with `dart run build_runner build`
- ❌ **Changing a Drift schema without bumping `schemaVersion`** — existing installs will not migrate
- ❌ **Storing secrets in `SharedPreferences`** — 令牌走 `flutter_secure_storage`
