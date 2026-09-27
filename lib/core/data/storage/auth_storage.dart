import 'dart:async';
import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:injectable/injectable.dart';
import 'package:my_app/core/data/network/token_store.dart';
import 'package:my_app/core/logging/logging.dart';
import 'package:my_app/core/models/token_set.dart';
import 'package:my_app/core/models/user.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:signals_flutter/signals_flutter.dart';

/// 认证存储：用户信息走 [SharedPreferences]，令牌走 [FlutterSecureStorage]。
///
/// 令牌整条 [TokenSet]（含绝对过期时刻）序列化成 JSON 存在安全存储的**单个键**下，
/// 内存里缓存一份，所以 [getAccessToken] / [getRefreshToken] 是同步的。
/// 一个键 = 一处状态，[saveTokens] / [clearAuth] 不必再维护多份副本的一致性。
///
/// 存储划分与读写失败策略（读软写硬）见 backend/database-guidelines.md。
///
/// 实现 [TokenStore]（`AuthInterceptor` / `TokenRefresher` 只认这个接口）；
/// [currentUser] / [isLoggedInSignal] 供路由守卫重评登录态。
@Singleton()
class AuthStorage implements TokenStore {
  new(this._prefs, this._secure) {
    _loadUserFromStorage();
    ready = _loadTokensFromStorage();
  }
  final SharedPreferences _prefs;
  final FlutterSecureStorage _secure;

  /// 当前用户信号
  final FlutterSignal<User?> currentUser = signal<User?>(null);

  /// 可被监听的登录态（路由守卫据此重评）；同步判断用 [isLoggedIn]
  late final FlutterComputed<bool> isLoggedInSignal = computed(
    () => currentUser.value != null,
  );

  /// 令牌的内存缓存；[ready] 完成后与安全存储一致
  TokenSet? _tokens;

  /// 令牌载入内存的完成信号；`AuthInterceptor` 附加 Authorization 前会 await 它
  @override
  late final Future<void> ready;

  static const String _keyUser = 'auth.user';

  /// 令牌整体（访问令牌 + 刷新令牌 + 绝对过期时刻）只占这一个键
  static const String _keyTokens = 'auth.tokens';

  void _loadUserFromStorage() {
    final userJson = _prefs.getString(_keyUser);
    if (userJson == null) return;

    try {
      currentUser.value = User.fromJson(
        jsonDecode(userJson) as Map<String, dynamic>,
      );
    } catch (e) {
      // 损坏的数据留着只会让每次启动都失败一次
      Logging.warning('本地用户数据损坏，已清理: $e');
      unawaited(_prefs.remove(_keyUser));
    }
  }

  Future<void> _loadTokensFromStorage() async {
    try {
      final raw = await _secure.read(key: _keyTokens);
      if (raw == null) return;
      _tokens = TokenSet.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (e) {
      // 安全存储不可用（或数据损坏）不该让 App 起不来，降级为「未持有令牌」
      Logging.warning('读取安全存储中的令牌失败，按未持有令牌处理: $e');
    }
  }

  /// 保存用户信息（prefs + 信号）
  Future<void> saveUser(User? user) async {
    currentUser.value = user;
    if (user != null) {
      await _prefs.setString(_keyUser, jsonEncode(user.toJson()));
    } else {
      await _prefs.remove(_keyUser);
    }
  }

  /// 保存令牌（安全存储 + 内存缓存）
  ///
  /// [tokens] 的刷新令牌为空时**沿用当前值**——服务端只在轮换时才返回新的，
  /// 用 null 覆盖会把可用的会话丢掉。
  @override
  Future<void> saveTokens(TokenSet tokens) async {
    final refreshed = tokens.refreshToken;
    final merged = refreshed == null || refreshed.isEmpty
        ? TokenSet(
            accessToken: tokens.accessToken,
            refreshToken: _tokens?.refreshToken,
            expiresAt: tokens.expiresAt,
          )
        : tokens;

    // 先写盘再更新内存：写失败必须抛出去，只留下内存副本 = 重启即被登出的假登录态
    await _secure.write(key: _keyTokens, value: jsonEncode(merged.toJson()));
    _tokens = merged;
  }

  /// 获取访问令牌（读内存缓存，同步）
  @override
  String? getAccessToken() => _tokens?.accessToken;

  /// 获取刷新令牌（读内存缓存，同步）
  @override
  String? getRefreshToken() => _tokens?.refreshToken;

  /// 是否临近过期（默认提前 [skew]）；没有过期时刻时恒为 false
  @override
  bool isAccessTokenExpiring({Duration skew = defaultTokenExpirySkew}) {
    final expiresAt = _tokens?.expiresAt;
    if (expiresAt == null) return false;
    return !DateTime.now().add(skew).isBefore(expiresAt);
  }

  /// 清除认证信息（登出、刷新失败时调用）
  ///
  /// 安全存储删除失败只记日志不外抛——本地登出必须成功。
  @override
  Future<void> clearAuth() async {
    currentUser.value = null;
    _tokens = null;
    await _prefs.remove(_keyUser);
    try {
      await _secure.delete(key: _keyTokens);
    } catch (e) {
      Logging.warning('清除安全存储中的令牌失败: $e');
    }
  }

  /// 检查是否已登录
  bool get isLoggedIn => currentUser.value != null;

  /// 获取当前用户 ID
  int? get currentUserId => currentUser.value?.id;
}
