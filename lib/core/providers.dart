import 'package:my_app/core/config/user_preferences.dart';
import 'package:my_app/core/data/database/app_database.dart';
import 'package:my_app/core/data/storage/file_storage.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';

part 'providers.g.dart';

/// 应用级基础设施单例的装配。
///
/// Riverpod 里「单例」就是一个 `keepAlive` 的 provider，不需要额外的注册表，
/// 也不需要 `lib/di/`。
///
/// **不得**在这里读取 `dotenv`：`NetworkConfig` 只有 `networkConfigProvider`
/// 一个来源（约定见 backend/network-guidelines.md）。

/// 用户偏好的底层存储。
///
/// **必须**由 `bootstrap()` 用 `overrides` 注入（`prefsProvider.overrideWithValue`）：
/// `SharedPreferences.getInstance()` 是异步的，而它的消费者
/// （`UserPreferences`）是同步构造的。用 `FutureProvider`
/// 会把 `AsyncValue` 一路传染到页面，等于让「启动期解析一次」变成「处处异步」。
///
/// 直接 `ref.watch` 它会抛异常——这是有意的：漏了 override 应该立刻炸，
/// 而不是拿到一个未初始化的实例。
@Riverpod(keepAlive: true)
SharedPreferences prefs(Ref ref) =>
    throw UnimplementedError('prefsProvider 必须在 bootstrap() 里用 overrides 注入');

@Riverpod(keepAlive: true)
AppDatabase database(Ref ref) => AppDatabase();

/// [FileStorage]（`core/data/storage/`）是纯 Dart 类，不带任何装配注解（本项目用
/// provider 装配，没有 injectable），所以在这里显式建成 provider。
@Riverpod(keepAlive: true)
FileStorage fileStorage(Ref ref) => FileStorage();

/// 用户偏好的持久化层（同步读）。
///
/// 页面要订阅的是它的**快照** `appSettingsProvider`，不是这一层：
/// 每次偏好变更都重建存储对象没有意义（见 core/config/app_settings.dart）。
@Riverpod(keepAlive: true)
UserPreferences userPreferences(Ref ref) =>
    UserPreferences(ref.watch(prefsProvider));
