import 'package:dio/dio.dart';
import 'package:my_app/features/auth/data/models/login_request.dart';
import 'package:my_app/features/auth/data/models/login_response.dart';
import 'package:retrofit/retrofit.dart';

part 'auth_api.g.dart';

@RestApi()
abstract class AuthApi {
  factory(Dio dio, {String baseUrl}) = _AuthApi;

  /// 登录。凭证通过请求体传输，避免出现在 URL / 日志中。
  ///
  /// 返回 [LoginResponse]，其中带有用于后续请求的 access token。
  @POST('/login')
  Future<LoginResponse> login(@Body() LoginRequest request);
  @GET('/logout')
  Future<void> logout();
}
