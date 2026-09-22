import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:injectable/injectable.dart';
import 'package:my_app/core/data/database/app_database.dart';
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
}
