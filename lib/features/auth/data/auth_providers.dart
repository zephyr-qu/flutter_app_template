import 'package:my_app/core/data/network/dio_client.dart';
import 'package:my_app/core/providers.dart';
import 'package:my_app/features/auth/data/auth_api.dart';
import 'package:my_app/features/auth/data/auth_repository.dart';
import 'package:my_app/features/auth/data/auth_service.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'auth_providers.g.dart';

/// auth 数据层的装配：Retrofit 客户端与 `AuthRepository` 的实现绑定。
///
/// 两者都是无状态服务，所以 `keepAlive`：让它们随页面生灭只会把实例化成本
/// 挪到每次 `ref.read`，换不来任何隔离收益。替换实现一律走
/// `ProviderScope(overrides:)`。
///
/// 这里是 master 分支 `auth_module.dart`（`@module` / `@LazySingleton`）的替代。

@Riverpod(keepAlive: true)
AuthApi authApi(Ref ref) => AuthApi(ref.watch(dioProvider));

@Riverpod(keepAlive: true)
AuthRepository authRepository(Ref ref) =>
    AuthService(ref.watch(authApiProvider), ref.watch(authStorageProvider));
