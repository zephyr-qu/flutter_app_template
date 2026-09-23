import 'dart:async';
import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:my_app/core/data/network/token_store.dart';
import 'package:my_app/core/logging/logging.dart';
import 'package:my_app/core/models/token_set.dart';
import 'package:my_app/core/models/user.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 认证存储：用户信息走 [SharedPreferences]，令牌走 [FlutterSecureStorage]。
///
/// 令牌整条 [TokenSet]（含绝对过期时刻）序列化成 JSON 存在安全存储的**单个键**下，
/// 内存里缓存一份，所以 [getAccessToken] / [getRefreshToken] 是同步的。
///
/// 实现 [TokenStore] 供 `core/data/network/` 的网络层使用；**本类不含任何状态管理依赖** ——
/// 登录态的可订阅镜像在 `core/auth/session.dart`，它订阅 [userChanges]。
/// 存储划分、读写失败策略与这层分工见 backend/database-guidelines.md。
class AuthStorage implements TokenStore {
  new(this._prefs, this._secure) {
    _loadUserFromStorage();
    ready = _loadTokensFromStorage();
  }
  final SharedPreferences _prefs;
  final FlutterSecureStorage _secure;

  /// 当前用户（同步真源；未登录为 null）
  User? get currentUser => _currentUser;
  User? _currentUser;

  /// 令牌的内存缓存；[ready] 完成后与安全存储一致
  TokenSet? _tokens;

  final StreamController<User?> _changes = StreamController<User?>.broadcast();

  /// 登录态变化流。**订阅时会立刻收到当前值**（对齐 signals 的「读即有值」），
  /// 所以消费者不必先读 [currentUser] 再订阅。
  Stream<User?> get userChanges async* {
    yield _currentUser;
    yield* _changes.stream;
  }

  /// 登录态变化（是否已登录）；不需要值、只想知道「变了」时用它
  bool get isLoggedIn => _currentUser != null;

  /// 关闭变化流（容器销毁时调用；App 生命周期内不会发生）
  Future<void> dispose() => _changes.close();

  void _notify() {
    // 流已关闭说明容器已销毁，此时再写状态是无意义的
    if (!_changes.isClosed) _changes.add(_currentUser);
  }

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
      final decoded = jsonDecode(userJson) as Map<String, dynamic>;
      _currentUser = User.fromJson(decoded);
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

  /// 保存用户信息（prefs + 通知订阅者）
  Future<void> saveUser(User? user) async {
    _currentUser = user;
    _notify();

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
    _currentUser = null;
    _tokens = null;
    _notify();

    await _prefs.remove(_keyUser);
    try {
      await _secure.delete(key: _keyTokens);
    } catch (e) {
      Logging.warning('清除安全存储中的令牌失败: $e');
    }
  }

  /// 获取当前用户 ID
  int? get currentUserId => _currentUser?.id;
}
