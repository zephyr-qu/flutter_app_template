import 'package:app_core/data/database/app_database.dart';
import 'package:app_core/data/storage/file_storage.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:injectable/injectable.dart';
import 'package:shared_preferences/shared_preferences.dart';

@module
abstract class CoreModule {
  @preResolve
  Future<SharedPreferences> get prefs => SharedPreferences.getInstance();

  /// 敏感数据（访问令牌）的平台安全存储。
  ///
  /// v11 的默认配置已经是安全的（Android: KeyStore 包装的 AES-GCM，API 23+；
  /// iOS/macOS: Keychain），无需额外传 options。
  @singleton
  FlutterSecureStorage get secureStorage => const FlutterSecureStorage();

  @singleton
  AppDatabase get database => AppDatabase();

  /// [FileStorage] 来自 `app_core`，包内不带 DI 注解（包不依赖 injectable），
  /// 所以由本装配层显式注册。见 design 6.3。
  @singleton
  FileStorage get fileStorage => FileStorage();
}
