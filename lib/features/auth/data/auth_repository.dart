import 'package:my_app/core/base/failure.dart';
import 'package:my_app/core/base/result.dart';
import 'package:my_app/core/models/user.dart';

/// 认证仓库抽象：返回 `Result`，不抛异常。
abstract class AuthRepository {
  Future<Result<User, Failure>> login(String email, String password);

  Future<Result<void, Failure>> logout();
}
