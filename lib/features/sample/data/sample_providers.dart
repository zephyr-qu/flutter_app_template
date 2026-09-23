import 'package:my_app/core/data/network/dio_client.dart';
import 'package:my_app/core/providers.dart';
import 'package:my_app/features/sample/data/sample_api.dart';
import 'package:my_app/features/sample/data/sample_dao.dart';
import 'package:my_app/features/sample/data/sample_repository.dart';
import 'package:my_app/features/sample/data/sample_service.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'sample_providers.g.dart';

/// sample 数据层的装配。
///
/// 三者都是无状态服务，所以 `keepAlive`：让它们随页面生灭只会把实例化成本
/// 挪到每次 `ref.read`。换实现（接真实后端、或在测试里塞 fake）一律走
/// `ProviderScope(overrides:)` —— 这就是本栈的注入点。

@Riverpod(keepAlive: true)
SampleApi sampleApi(Ref ref) => SampleApi(ref.watch(dioProvider));

@Riverpod(keepAlive: true)
SampleDao sampleDao(Ref ref) => SampleDao(ref.watch(databaseProvider));

@Riverpod(keepAlive: true)
SampleRepository sampleRepository(Ref ref) =>
    SampleService(ref.watch(sampleApiProvider), ref.watch(sampleDaoProvider));
