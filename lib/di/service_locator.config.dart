// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format width=80

// **************************************************************************
// InjectableConfigGenerator
// **************************************************************************

// ignore_for_file: type=lint
// coverage:ignore-file

// ignore_for_file: no_leading_underscores_for_library_prefixes

import 'package:dio/dio.dart' as _i361;
import 'package:flutter_secure_storage/flutter_secure_storage.dart' as _i558;
import 'package:get_it/get_it.dart' as _i174;
import 'package:injectable/injectable.dart' as _i526;
import 'package:app_core/config/network_config.dart' as _i734;
import 'package:my_app/core/config/user_preferences.dart' as _i257;
import 'package:my_app/core/core_module.dart' as _i316;
import 'package:app_core/data/database/app_database.dart' as _i157;
import 'package:my_app/core/data/network/dio_client.dart' as _i426;
import 'package:my_app/core/data/storage/auth_storage.dart' as _i70;
import 'package:app_core/data/storage/file_storage.dart' as _i477;
import 'package:my_app/features/article/data/article_api.dart' as _i582;
import 'package:my_app/features/article/data/article_dao.dart' as _i1011;
import 'package:my_app/features/article/data/article_module.dart' as _i481;
import 'package:my_app/features/article/data/article_repository.dart' as _i144;
import 'package:my_app/features/article/data/article_service.dart' as _i86;
import 'package:my_app/features/article/logic/article_view_model.dart' as _i913;
import 'package:my_app/features/auth/data/auth_api.dart' as _i738;
import 'package:my_app/features/auth/data/auth_module.dart' as _i145;
import 'package:my_app/features/auth/data/auth_repository.dart' as _i409;
import 'package:my_app/features/auth/data/auth_service.dart' as _i514;
import 'package:my_app/features/auth/logic/auth_view_model.dart' as _i572;
import 'package:my_app/features/demo/logic/storage_demo_view_model.dart'
    as _i406;
import 'package:shared_preferences/shared_preferences.dart' as _i460;

extension GetItInjectableX on _i174.GetIt {
  // initializes the registration of main-scope dependencies inside of GetIt
  Future<_i174.GetIt> init({
    String? environment,
    _i526.EnvironmentFilter? environmentFilter,
  }) async {
    final gh = _i526.GetItHelper(this, environment, environmentFilter);
    final coreModule = _$CoreModule();
    final networkModule = _$NetworkModule();
    final articleModule = _$ArticleModule();
    final authModule = _$AuthModule();
    await gh.factoryAsync<_i460.SharedPreferences>(
      () => coreModule.prefs,
      preResolve: true,
    );
    gh.singleton<_i558.FlutterSecureStorage>(() => coreModule.secureStorage);
    gh.singleton<_i157.AppDatabase>(() => coreModule.database);
    gh.singleton<_i477.FileStorage>(() => _i477.FileStorage());
    gh.lazySingleton<_i734.NetworkConfig>(() => networkModule.networkConfig());
    gh.singleton<_i70.AuthStorage>(
      () => _i70.AuthStorage(
        gh<_i460.SharedPreferences>(),
        gh<_i558.FlutterSecureStorage>(),
      ),
    );
    gh.lazySingleton<_i1011.ArticleDao>(
      () => articleModule.articleDao(gh<_i157.AppDatabase>()),
    );
    gh.singleton<_i257.UserPreferences>(
      () => _i257.UserPreferences(gh<_i460.SharedPreferences>()),
    );
    gh.factory<_i406.StorageDemoViewModel>(
      () => _i406.StorageDemoViewModel(
        gh<_i477.FileStorage>(),
        gh<_i1011.ArticleDao>(),
      ),
    );
    gh.lazySingleton<_i361.Dio>(
      () => networkModule.dio(
        gh<_i257.UserPreferences>(),
        gh<_i70.AuthStorage>(),
        gh<_i734.NetworkConfig>(),
      ),
    );
    gh.lazySingleton<_i582.ArticleApi>(
      () => articleModule.articleApi(gh<_i361.Dio>()),
    );
    gh.lazySingleton<_i738.AuthApi>(() => authModule.authApi(gh<_i361.Dio>()));
    gh.lazySingleton<_i144.ArticleRepository>(
      () =>
          _i86.ArticleService(gh<_i582.ArticleApi>(), gh<_i1011.ArticleDao>()),
    );
    gh.factory<_i913.ArticleViewModel>(
      () => _i913.ArticleViewModel(gh<_i144.ArticleRepository>()),
    );
    gh.lazySingleton<_i409.AuthRepository>(
      () => _i514.AuthService(gh<_i738.AuthApi>(), gh<_i70.AuthStorage>()),
    );
    gh.factory<_i572.AuthViewModel>(
      () => _i572.AuthViewModel(gh<_i409.AuthRepository>()),
    );
    return this;
  }
}

class _$CoreModule extends _i316.CoreModule {}

class _$NetworkModule extends _i426.NetworkModule {}

class _$ArticleModule extends _i481.ArticleModule {}

class _$AuthModule extends _i145.AuthModule {}
