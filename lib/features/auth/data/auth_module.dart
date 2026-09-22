import 'package:dio/dio.dart';
import 'package:injectable/injectable.dart';

import 'package:my_app/features/auth/data/auth_api.dart';

@module
abstract class AuthModule {
  @LazySingleton()
  AuthApi authApi(Dio dio) => AuthApi(dio);
}
