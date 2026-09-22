import 'package:app_core/base/failure.dart';
import 'package:app_core/base/result.dart';
import 'package:app_core/models/user.dart';

/// 认证仓库抽象：返回 `Result`，不抛异常。
abstract class AuthRepository {
  Future<Result<User, Failure>> login(String email, String password);

  Future<Result<void, Failure>> logout();
}
