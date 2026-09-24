# Database Guidelines

> Database and storage patterns for this project.

> **Scaffold note**: This is a personal Flutter scaffold/template for medium-small apps. Three persistence mechanisms ship with it: **SharedPreferences** (key-value), **Drift/SQLite** (relational cache), and **FileStorage** (files). You do not have to use all three — delete what the target app does not need.

---

## Overview

| Mechanism | Package | Implementation | Use for |
| ----------- | --------- | ---------------- | --------- |
| Key-value | `shared_preferences` | `UserPreferences` | Preferences, settings, non-secret data |
| Relational | `drift`（原生库由 `sqlite3` 3.x 的 build hook 提供） | `AppDatabase`（`lib/core/data/database/app_database.dart`） | Structured, queryable local cache |
| Files | `path_provider` | `FileStorage`（`lib/core/data/storage/file_storage.dart`） | Binary / large text data |

**不要**把令牌、密码之类的敏感数据放进 `SharedPreferences`——那是明文的 XML/plist，设备被 root / 越狱后可直接读出。本分支**不含认证**、没有凭证要存；将来要存时走平台安全存储（`flutter_secure_storage`），加回步骤见 [optional-additions.md](../../../docs/optional-additions.md) 的「登录 / 认证」。上表三者的实例都由 provider 装配（`lib/core/providers.dart`），业务代码只 `ref.watch`，不自己 new。

---

## 状态管理与存储的分工

本分支（`preset/ai-starter`，Riverpod）有一条贯穿全部存储的约定：
**存储对象不依赖状态管理，状态由另外一层 provider 负责。**

| 存储对象（`lib/core/`） | 状态层（provider） | 分工 |
| --- | --- | --- |
| `UserPreferences` | `core/config/app_settings.dart` 的 `AppSettingsNotifier` | 存储只读写 prefs；Notifier 持有内存快照并在写入后落盘 |

好处是存储对象能**脱开容器单测**（喂一个 mock 过的 `SharedPreferences` 即可），
而页面拿到的是「一份可订阅的快照」而不是「每次读盘」。写入顺序统一是**先改内存、再落盘**
（UI 立刻响应；落盘失败只记日志）。

### 存储的失败策略：读要软，写要硬

| 操作 | 失败时 | 为什么 |
| --- | --- | --- |
| 读（载入 / 解析） | 记 warning，降级为「没有这份数据」 | 数据损坏或平台实现缺失不该让 App 起不来 |
| 解析出错 | 记 warning，并**删掉那份损坏的数据** | 留着只会让每次启动都失败一次 |
| 写状态 | **向上抛**（`UserPreferences` 的 setter 即如此） | 只留下内存副本 = 假成功，重启后状态回退 |
| 写缓存 | 记 warning，不影响本次请求结果（`SampleService` 的 `_ignoreCacheFailure`） | 缓存是旁路，失败不该让用户看不到数据 |

判断口径一句话：**读失败可以降级，写失败不能假装成功。**

**Key naming convention**：`SharedPreferences` 用 `app.{domain}.{key}`（如 `app.theme.mode`）。
Always use `static const String _keyX = '...'` constants, never inline strings.

`prefs` 本身由 `bootstrap()` 预载后用 `prefsProvider.overrideWithValue(prefs)` 注入
（`SharedPreferences.getInstance()` 是异步的，而消费者都是同步构造的）。**不要**在别处再调
`SharedPreferences.getInstance()`，也不要把它做成 `FutureProvider`——理由见
`lib/core/providers.dart` 的 `prefsProvider`。

---

## Drift (Relational Cache)

`AppDatabase` 只负责**连接与 schema**：表定义（`DbArticles`）、`schemaVersion`、迁移。
它是 `lib/core/data/database/` 里的纯 Dart 类（不带装配注解），
由 `lib/core/providers.dart` 的 `databaseProvider` 建成单例。

**它已经被真正接进数据流**：`SampleService` 用「缓存旁路」消费 `SampleDao` —— 网络成功就刷新
缓存，网络失败就回退到缓存，让离线时还能读到上次的内容
（`features/sample/data/sample_service.dart`）。

### 分工：schema 在 `core/`，查询在 feature

| 内容 | 位置 | 为什么 |
| --- | --- | --- |
| 表结构、`schemaVersion`、迁移 | `lib/core/data/database/` | schema 是全局的，`@DriftDatabase` 必须看得见所有表；而 `core/` 不能 import feature（`packages/app_lints` 的 `no_upper_import_in_core` 强制） |
| 针对某张表的查询（DAO） | `features/{feature}/data/{feature}_dao.dart` | 查询按 feature 划分。写进 `AppDatabase` 就再也搬不出去（`core/` 不能反向依赖），只会随 feature 数无限膨胀 |

这样加一个 feature 时 `core/` 只多一张表，查询代码不堆在 `core/` 里。

### 表必须 part 进数据库文件（踩过的坑）

drift 的默认 codegen 有一条硬约束：**表必须和数据库类在同一个 library**。
表可以按表拆成独立文件，但必须写成 `part`：

```dart
// lib/core/data/database/app_database.dart
part 'app_database.g.dart';
part 'tables/db_articles.dart';    // ← 不是 import

// lib/core/data/database/tables/db_articles.dart
part of '../app_database.dart';    // ← part 文件不能有 import
```

写成 `import 'tables/db_articles.dart'` 的话，`AppDatabase` 仍能生成 schema，但
`@DriftAccessor` 会失败并报
`Could not read tables from @DriftAccessor annotation! Please make sure that all table classes exist.`

### DAO 用 `@DriftAccessor`（表与数据库同包）

表与数据库同在 `lib/core/data/database/`，是同一个 package，所以 DAO 用 idiomatic 的
`@DriftAccessor` 声明它要访问的表：

```dart
// features/sample/data/sample_dao.dart
part 'sample_dao.g.dart';

@DriftAccessor(tables: [DbArticles])
class SampleDao extends DatabaseAccessor<AppDatabase> with _$SampleDaoMixin {
  new(super.attachedDatabase);

  Future<List<DbArticle>> getCachedItems() => select(dbArticles).get();

  Future<void> cacheItem(DbArticle item) =>
      into(dbArticles).insertOnConflictUpdate(item);
}
```

`@DriftAccessor` 生成的 mixin（`_$SampleDaoMixin`）提供 `dbArticles` getter，方法体里直接写
`select(dbArticles)` / `into(dbArticles)` 即可。

装配在 feature 自己的 provider 文件里（**不要**用 `@DriftDatabase(daos: [...])` ——
那要求 `core/` 反 import feature，违反「core 不得依赖上层」）：

```dart
// features/sample/data/sample_providers.dart
@Riverpod(keepAlive: true)
SampleDao sampleDao(Ref ref) => SampleDao(ref.watch(databaseProvider));
```

- 行类 `DbArticle` 生成在 `lib/core/data/database/app_database.g.dart`，所以 feature
  的 DAO 需要 `import 'package:my_app/core/data/database/app_database.dart';` 才能拿到它。

> 历史背景：`master` 把表放进 `packages/app_core` 共享包时，`drift_dev` 解析不到另一个
> package 里的表（drift#3669），DAO 只能绕开 `@DriftAccessor`、直接持有 `AppDatabase`。
> 本分支已把该包拍平回 `lib/core/`，同包后这个坑不再存在。

### 加表 / 改表

- **加表**：新建 `tables/db_{name}.dart`，类名加 `Db` 前缀（见下节）→ 在
  `app_database.dart` 补一行 `part` → 加进 `@DriftDatabase(tables: [...])` →
  升 `schemaVersion` 并补 `MigrationStrategy` → `just codegen`
- **改表**：改 `tables/` 下的文件 → 升 `schemaVersion` 并补 `MigrationStrategy` →
  `just codegen`
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

两者字段目前一致，但**不要**合并：`core/` 不能依赖 feature，反过来让 feature 的模型去当 drift
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
// lib/core/data/storage/file_storage.dart
class FileStorage {
  /// 应用目录 / 临时目录下用来放本类文件的子目录名
  static const String namespace = 'file_storage';

  Future<Directory> get appDirectory;   // <documents>/file_storage
  Future<Directory> get tempDirectory;  // <tmp>/file_storage

  // text / bytes read + write, delete, temp cleanup, usage reporting
}
```

它是纯 Dart 类（不带装配注解——本分支用 provider 装配，没有 injectable），
由 `lib/core/providers.dart` 的 `fileStorageProvider` 建成 provider。精确签名见
`lib/core/data/storage/file_storage.dart`。

> **本分支没有 FileStorage 的示例页**：`features/demo/` 已随示例收敛删除。要看用法就照
> `test/core/data/storage/file_storage_test.dart`（真实文件 + 内存路径）写，
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
| SharedPrefs key | `app.{domain}.{key}` | `app.theme.mode`, `app.debug.logging` |
| Drift table | `Db` + PascalCase plural | `DbArticles` |
| Drift row class | drift 自动派生（表名单数） | `DbArticle` |
| Drift generated file | `{source}.g.dart` | `app_database.g.dart` |
| FileStorage filename | any valid filename | `'user_avatar.png'` |

---

## Common Mistakes

- ❌ **Calling `SharedPreferences.getInstance()` somewhere other than `bootstrap()`** — 它只在那里 await 一次，其余地方读 `prefsProvider`
- ❌ **把 `prefs` 做成 `FutureProvider`** — `AsyncValue` 会一路传染到所有消费者（见 `lib/core/providers.dart`）
- ❌ **给 `UserPreferences` 加状态管理依赖** — 它要能脱开容器单测；状态在 `AppSettingsNotifier` 里
- ❌ **把 DAO 的查询逻辑塞进 `AppDatabase`** — 加 feature 会让 `core/` 无限膨胀，且查询再也搬不出去；查询放 feature 的 DAO 里（`@DriftAccessor`）
- ❌ **Editing `*.g.dart` by hand** — regenerate with `just codegen`
- ❌ **Changing a Drift schema without bumping `schemaVersion`** — existing installs will not migrate
- ❌ **Storing secrets in `SharedPreferences`** — 明文 XML/plist；凭证要走平台安全存储（见上文与 [optional-additions.md](../../../docs/optional-additions.md)）
