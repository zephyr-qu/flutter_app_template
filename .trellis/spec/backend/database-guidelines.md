# 数据库规范

> 本项目的数据库与存储约定。

---

## 概览

三种机制按需取用，目标应用用不到的直接删。

| 机制 | 包 | 实现 | 用途 |
| ----------- | --------- | ---------------- | --------- |
| Key-value | `shared_preferences` | `UserPreferences` | 偏好、设置、非敏感数据 |
| 关系型 | `drift`（原生库由 `sqlite3` 3.x 的 build hook 提供） | `AppDatabase`（`lib/core/data/database/app_database.dart`） | 结构化、可查询的本地缓存 |
| 文件 | `path_provider` | `FileStorage`（`lib/core/data/storage/file_storage.dart`） | 二进制 / 大文本 |

**不要**把令牌、密码之类的敏感数据放进 `SharedPreferences`；凭证走平台安全存储（`flutter_secure_storage`）。本项目**无认证**。上表三者的实例都由 provider 装配（`lib/core/providers.dart`），业务代码只 `ref.watch`，不自己 new。

---

## 状态管理与存储的分工

本项目有一条贯穿全部存储的约定：**存储对象不依赖状态管理，状态由另外一层 provider 负责。**

| 存储对象（`lib/core/`） | 状态层（provider） | 分工 |
| --- | --- | --- |
| `UserPreferences` | `core/config/app_settings.dart` 的 `AppSettingsNotifier` | 存储只读写 prefs；Notifier 持有内存快照并在写入后落盘 |

- 存储对象要能**脱开容器单测**（喂一个 mock 过的 `SharedPreferences`）；页面拿到的是可订阅快照
- 写入顺序统一**先改内存、再落盘**（落盘失败只记日志）

### 存储的失败策略：读要软，写要硬

| 操作 | 失败时 |
| --- | --- |
| 读（载入 / 解析） | 记 warning，降级为「没有这份数据」 |
| 解析出错 | 记 warning，并**删掉那份损坏的数据** |
| 写状态 | **向上抛**（`UserPreferences` 的 setter 在 `setX` 返回 `false` 时抛 `PreferenceWriteException`；`AppSettingsNotifier` 接住并回滚内存） |
| 写缓存 | 记 warning，不影响本次请求结果（`SampleService` 的 `_ignoreCacheFailure`） |

> 落盘失败的链路：`setX` 返回 `false` → setter 抛 `PreferenceWriteException` → `AppSettingsNotifier` 把内存快照**回滚**到写入前的值并记一条 warning（见 `lib/core/config/app_settings.dart`）。

**Key 命名约定**：`SharedPreferences` 用 `app.{domain}.{key}`（如 `app.theme.mode`）。统一写成 `static const String _keyX = '...'` 常量，不要内联字符串。

`prefs` 由 `bootstrap()` 预载后用 `prefsProvider.overrideWithValue(prefs)` 注入。**不要**在别处再调 `SharedPreferences.getInstance()`，也不要把它做成 `FutureProvider`（见 `lib/core/providers.dart` 的 `prefsProvider`）。

---

## Drift（关系型缓存）

`AppDatabase` 只负责**连接与 schema**：表定义（`DbArticles`）、`schemaVersion`、迁移。它是 `lib/core/data/database/` 里的纯 Dart 类（不带装配注解），由 `lib/core/providers.dart` 的 `databaseProvider` 建成单例，已通过 `SampleService` 的「缓存旁路」接进数据流（见 `features/sample/data/sample_service.dart`）。

### 分工：schema 在 `core/`，查询在 feature

| 内容 | 位置 |
| --- | --- |
| 表结构、`schemaVersion`、迁移 | `lib/core/data/database/` |
| 针对某张表的查询（DAO） | `features/{feature}/data/{feature}_dao.dart` |

### 表必须 part 进数据库文件

drift 的默认 codegen 有一条硬约束：**表必须和数据库类在同一个 library**。表可以按表拆成独立文件，但必须写成 `part`：

```dart
// lib/core/data/database/app_database.dart
part 'app_database.g.dart';
part 'tables/db_articles.dart';    // ← 不是 import

// lib/core/data/database/tables/db_articles.dart
part of '../app_database.dart';    // ← part 文件不能有 import
```

### DAO 用 `@DriftAccessor`（表与数据库同包）

表与数据库同在 `lib/core/data/database/`、同一个 package：DAO 用 idiomatic 的 `@DriftAccessor` 声明它要访问的表（行类 `DbArticle` 生成在 `lib/core/data/database/app_database.g.dart`，feature 的 DAO 需要 `import 'package:my_app/core/data/database/app_database.dart';` 才能拿到它）：

```dart
// features/sample/data/sample_dao.dart
part 'sample_dao.g.dart';

@DriftAccessor(tables: [DbArticles])
class SampleDao extends DatabaseAccessor<AppDatabase> with _$SampleDaoMixin {
  new(super.attachedDatabase);

  Future<List<DbArticle>> getCachedItems() => select(dbArticles).get();

  Future<void> cacheItem(DbArticle item) => into(dbArticles).insertOnConflictUpdate(item);
}
```

生成的 mixin（`_$SampleDaoMixin`）提供 `dbArticles` getter，方法体里直接写 `select(dbArticles)` / `into(dbArticles)`。装配在 feature 自己的 provider 文件里，**不要**用 `@DriftDatabase(daos: [...])`：

```dart
// features/sample/data/sample_providers.dart
@Riverpod(keepAlive: true)
SampleDao sampleDao(Ref ref) => SampleDao(ref.watch(databaseProvider));
```

### 加表 / 改表

- **加表**：新建 `tables/db_{name}.dart`，类名加 `Db` 前缀（见「命名规范：加表就是加前缀」）→ 在 `app_database.dart` 补一行 `part` → 加进 `@DriftDatabase(tables: [...])` → 升 `schemaVersion` 并补 `MigrationStrategy` → `just codegen`
- **改表**：改 `tables/` 下的文件 → 升 `schemaVersion` 并补 `MigrationStrategy` → `just codegen`
- 测试用内存数据库（`NativeDatabase.memory()`）：DAO 见 `test/features/sample/data/sample_dao_test.dart`，缓存旁路见 `test/features/sample/data/sample_service_test.dart`

### 命名规范：加表就是加前缀

**加表 = 类名加 `Db` 前缀，就这一步。** 行类名、SQL 表名、表访问器全部由 drift 自动派生，**任何注解都不用写**（既不写 `@DataClassName`，也不写 `tableName`）：

| 层级 | 规则 | 例子 |
| --- | --- | --- |
| 表类 | `Db` + PascalCase 复数 | `DbArticles` |
| 行类 | drift **自动**按表名单数派生 | `DbArticle` |
| SQL 表名 | drift **自动**取类名 snake_case | `db_articles` |
| 文件名 | 类名的 snake_case | `tables/db_articles.dart` |

数据库行类与业务模型的对照：

| 类型 | 位置 | 语义 |
| --- | --- | --- |
| `DbArticle` | `app_database.g.dart`（生成） | 数据库里的一行 |
| `SampleItem` | `features/sample/data/models/sample_item.dart` | 业务模型（freezed） |

两者字段目前一致，但**不要**合并。

**互转也不放在模型上**，而是留在 `SampleService` 的私有 `_toRow` / `_toModel` 里：

- `sample_item.dart` 只 import `freezed_annotation`，**零数据库依赖**
- 转换出现**第二个消费者**时再抽成 `features/{feature}/data/{feature}_mapper.dart` 的 extension，**而不是塞进模型**——模型不该知道 drift。

SQL 表名带 `db_` 前缀；个别表需要干净的 SQL 名时单独覆盖：

```dart
@override
String get tableName => 'articles';
```

> 改已发布库的 `tableName` 等于换表：需要清库或写 `MigrationStrategy` 搬数据。

### 写缓存的两种语义，别用错

- `cacheItems(list)` —— **先清后写**，用于整表快照（服务端删掉的条目不该留在缓存里）
- `cacheItem(row)` —— upsert 单行，**不影响其它行**；写单条时误用 `cacheItems` 会把整个列表缓存清掉，两者都有测试盯着

### 缓存自身的失败不该影响请求

- 缓存读/写抛异常时 `SampleService` 只记 warning
- **缓存未命中且网络也失败**时返回**原始的** `Failure`（保留错误码），不要降级成「未知错误」

> **sqlite3 的来源**：`pubspec.yaml` 不覆盖 `sqlite3` 的 hook 配置，走包默认行为——下载带 SHA-256 校验的预编译库并作为 code asset 打进产物。**不需要**手动往项目根目录放 `sqlite3.dll`。
> 要改用系统 SQLite（例如减小包体），加回 `hooks.user_defines.sqlite3.source: system`；那样 Windows 上跑 `flutter test` 需要自己提供 `sqlite3.dll`。

---

## FileStorage

文本与字节的文件存储。根目录是**自己拥有的两个子目录**，不是 `path_provider` 给的根：

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

纯 Dart 类（不带装配注解——本项目用 provider 装配，没有 injectable），由 `lib/core/providers.dart` 的 `fileStorageProvider` 建成 provider，精确签名见 `lib/core/data/storage/file_storage.dart`。**没有 FileStorage 的示例页**，用法照 `test/core/data/storage/file_storage_test.dart`（真实文件 + 内存路径）写，需要文件缓存的目标应用再自己建页面。持久数据用 `appDirectory`，缓存用 `tempDirectory`。

### 必须有独立的子目录

临时目录**是全 App 共用的**（图片缓存、下载、播放器等都往同一个根目录放文件）：

- `clearTemp()` 只清 `tempDirectory`。**不要**写成「把临时根目录 `listSync()` 后逐个 `delete(recursive: true)`」
- 读写路径一律由 `_buildPath` 拼到自己的子目录下，不直接落根目录

### 不用同步 IO

`listSync()` / `readAsStringSync()` / `existsSync()` **直接阻塞 UI isolate**，不要用。遍历一律用 `Directory.list()` 的流式接口（`await for`），逐个 `await` 而不是 `Future.wait` 铺开：

```dart
await for (final entry in dir.list(recursive: true, followLinks: false)) {
  if (entry is File) total += await entry.length();
}
```

---

## 查询范式

- 远程读取走各 feature `*_api.dart` 里的 Retrofit `@GET` / `@POST`；错误统一成 `Result<T, Failure>`（见 [error-handling.md](./error-handling.md)）
- 本地关系型读取走 `AppDatabase` 上 drift 生成的查询 API（DAO 由 feature 持有，见「分工：schema 在 `core/`，查询在 feature」）

---

## 命名约定

| 元素 | 约定 | 示例 |
| --------- | ----------- | --------- |
| SharedPrefs key | `app.{domain}.{key}` | `app.theme.mode`, `app.debug.logging` |
| Drift 表 | `Db` + PascalCase 复数 | `DbArticles` |
| Drift 行类 | drift 自动派生（表名单数） | `DbArticle` |
| Drift 生成文件 | `{source}.g.dart` | `app_database.g.dart` |
| FileStorage 文件名 | 任意合法文件名 | `'user_avatar.png'` |

---

## 常见错误

- ❌ **在 `bootstrap()` 以外调用 `SharedPreferences.getInstance()`** — 它只在那里 await 一次，其余地方读 `prefsProvider`
- ❌ **把 `prefs` 做成 `FutureProvider`** — `AsyncValue` 会一路传染到所有消费者（见 `lib/core/providers.dart`）
- ❌ **给 `UserPreferences` 加状态管理依赖** — 它要能脱开容器单测；状态在 `AppSettingsNotifier` 里
- ❌ **把 DAO 的查询逻辑塞进 `AppDatabase`** — 查询放 feature 的 DAO 里（`@DriftAccessor`）
- ❌ **手改 `*.g.dart`** — 用 `just codegen` 重新生成
- ❌ **改 Drift schema 却不升 `schemaVersion`** — 已安装的应用不会迁移
- ❌ **把密钥存进 `SharedPreferences`** — 凭证走平台安全存储（见「概览」与 [optional-additions.md](../../../docs/optional-additions.md)）
