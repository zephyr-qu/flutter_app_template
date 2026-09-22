import 'package:app_core/models/token_set.dart';
import 'package:app_core/models/user.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'login_response.freezed.dart';
part 'login_response.g.dart';

/// 登录响应（字段名不同就在字段上加 `@JsonKey`）。后端约定的形状：
/// ```json
/// {
///   "user": { "id": 1, "name": "开发者" },
///   "accessToken": "...",
///   "refreshToken": "...",
///   "expiresIn": 3600
/// }
/// ```
/// 令牌部分的语义见 [TokenSet]。
@freezed
sealed class LoginResponse with _$LoginResponse {
  const factory({
    required User user,
    required String accessToken,
    String? refreshToken,
    int? expiresIn,
  }) = _LoginResponse;

  factory fromJson(Map<String, dynamic> json) => _$LoginResponseFromJson(json);
}

/// 取令牌部分；`expiresIn`（秒）在这里换算成绝对过期时刻。
///
/// 用扩展而非类成员：freezed 生成的实现类是 `implements LoginResponse`，
/// 往类里加具体 getter 会让生成类缺实现而编译失败。
extension LoginResponseTokens on LoginResponse {
  TokenSet get tokens => TokenSet.withExpiresIn(
    accessToken: accessToken,
    refreshToken: refreshToken,
    expiresIn: expiresIn,
  );
}
