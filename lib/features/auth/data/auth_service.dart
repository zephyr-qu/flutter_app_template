import 'package:app_core/base/failure.dart';
import 'package:app_core/base/result.dart';
import 'package:app_core/base/run_catching.dart';
import 'package:app_core/logging/logging.dart';
import 'package:app_core/models/user.dart';
import 'package:injectable/injectable.dart';
import 'package:my_app/core/data/storage/auth_storage.dart';
import 'package:my_app/features/auth/data/auth_api.dart';
import 'package:my_app/features/auth/data/auth_repository.dart';
import 'package:my_app/features/auth/data/models/login_request.dart';
import 'package:my_app/features/auth/data/models/login_response.dart';

/// 认证服务实现：调用远程 API，用 [runCatching] 把底层错误转成 [Failure]。
@LazySingleton(as: AuthRepository)
class AuthService implements AuthRepository {
  new(this._api, this._storage);
  final AuthApi _api;
  final AuthStorage _storage;

  @override
  Future<Result<User, Failure>> login(String email, String password) =>
      runCatching(() async {
        final response = await _api.login(
          LoginRequest(email: email, password: password),
        );
        // 顺序不能反：先存令牌再存用户（原因见 backend/database-guidelines.md）
        await _storage.saveTokens(response.tokens);
        await _storage.saveUser(response.user);
        return response.user;
      });

  /// 登出：先尽力通知服务端，**无论成功与否都清本地凭证**
  /// （见 backend/error-handling.md「登出语义」）。
  @override
  Future<Result<void, Failure>> logout() async {
    final remote = await runCatching<void>(() async {
      await _api.logout();
    });

    await _storage.clearAuth();

    if (remote.isFailure) {
      Logging.warning(
        '通知服务端登出失败，已仅在本地登出: '
        '${remote.when(success: (_) => '', failure: (f) => '$f')}',
      );
    }

    return const Result.success(null);
  }
}
