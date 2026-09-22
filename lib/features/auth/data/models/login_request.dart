import 'package:freezed_annotation/freezed_annotation.dart';

part 'login_request.freezed.dart';
part 'login_request.g.dart';

/// 登录请求体。字段名保持后端的 `pwd`（而非 `password`）。
@freezed
sealed class LoginRequest with _$LoginRequest {
  const factory({
    required String email,
    @JsonKey(name: 'pwd') required String password,
  }) = _LoginRequest;

  factory fromJson(Map<String, dynamic> json) => _$LoginRequestFromJson(json);
}
