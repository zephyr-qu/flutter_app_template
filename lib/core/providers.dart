import 'package:app_core/data/database/app_database.dart';
import 'package:app_core/data/storage/file_storage.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';

part 'providers.g.dart';

/// 应用级基础设施单例的装配。
///
/// 这一层是 master（signals）分支上 `core/core_module.dart` 的 `@module` 注解的替代：
/// Riverpod 里「单例」就是一个 `keepAlive` 的 provider，不需要额外的注册表，
/// 也就不需要 `lib/di/`（见 BRANCH.md）。
///
/// **不得**在这里读取 `dotenv`：`NetworkConfig` 只有 `NetworkModule` 一个来源
/// （约定见 backend/network-guidelines.md）。

/// 用户偏好 / 令牌存储的底层存储。
///
/// **必须**由 `bootstrap()` 用 `overrides` 注入（`prefsProvider.overrideWithValue`）：
/// `SharedPreferences.getInstance()` 是异步的，而它的消费者
/// （`UserPreferences` / `AuthStorage`）都是同步构造的。用 `FutureProvider`
/// 会把 `AsyncValue` 一路传染到页面，等于让「启动期解析一次」变成「处处异步」。
///
/// 直接 `ref.watch` 它会抛异常——这是有意的：漏了 override 应该立刻炸，
/// 而不是拿到一个未初始化的实例。
@Riverpod(keepAlive: true)
SharedPreferences prefs(Ref ref) =>
    throw UnimplementedError('prefsProvider 必须在 bootstrap() 里用 overrides 注入');

/// 敏感数据（访问令牌）的平台安全存储。
///
/// v11 的默认配置已经是安全的（Android: KeyStore 包装的 AES-GCM，API 23+；
/// iOS/macOS: Keychain），无需额外传 options。
@Riverpod(keepAlive: true)
FlutterSecureStorage secureStorage(Ref ref) => const FlutterSecureStorage();

@Riverpod(keepAlive: true)
AppDatabase database(Ref ref) => AppDatabase();

/// [FileStorage] 来自 `app_core`，包内不带任何装配注解（包不依赖状态管理），
/// 所以在这里显式建成 provider。
@Riverpod(keepAlive: true)
FileStorage fileStorage(Ref ref) => FileStorage();
