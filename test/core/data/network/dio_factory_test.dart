import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:dio_smart_retry/dio_smart_retry.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:msw_dio_interceptor/msw_dio_interceptor.dart';
import 'package:my_app/core/config/network_config.dart';
import 'package:my_app/core/data/network/dio_factory.dart';
import 'package:pretty_dio_logger/pretty_dio_logger.dart';

import '../../../support/scripted_http_adapter.dart';

/// `createDio` 是网络层的装配：拦截器顺序承载语义（Retry 在解码之前判定、
/// Mock 命中即短路），改顺序会静默改变线上行为，所以这里既钉住拦截器清单，
/// 也在真实 Dio 管道里跑一遍。
const _config = NetworkConfig(baseUrl: 'http://test.local', retries: 2);

/// 只取 [createDio] 装上去的拦截器。
///
/// 不能直接断言 `dio.interceptors` 整个列表：`Dio` 自己会在最前面插一个
/// `ImplyContentTypeInterceptor`（`msw_dio_interceptor` 还会再加一个），
/// 数量断言会因此变成「Dio 内部实现」的测试。
List<Interceptor> appInterceptors(Dio dio) => dio.interceptors
    .where(
      (i) =>
          i is RetryInterceptor ||
          i is InterceptorsWrapper ||
          i is MockInterceptor,
    )
    .toList();

/// 返回 `text/plain` 的适配器：专门喂给「后端把 JSON 当字符串返回」的兜底解码分支。
class _PlainTextAdapter implements HttpClientAdapter {
  new(this.body);

  final String body;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async => ResponseBody.fromString(
    body,
    200,
    headers: {
      Headers.contentTypeHeader: ['text/plain'],
    },
  );

  @override
  void close({bool force = false}) {}
}

void main() {
  Dio build({
    bool isMock = false,
    bool enableDebugLogging = false,
    void Function()? registerMockRules,
    HttpClientAdapter? adapter,
  }) {
    final dio = createDio(
      config: _config,
      enableDebugLogging: enableDebugLogging,
      isMock: isMock,
      registerMockRules: registerMockRules,
    );
    if (adapter != null) dio.httpClientAdapter = adapter;
    return dio;
  }

  group('拦截器栈', () {
    test('顺序固定为 解码 → Retry', () {
      final dio = build();

      expect(appInterceptors(dio).map((i) => i.runtimeType.toString()), [
        'InterceptorsWrapper',
        'RetryInterceptor',
      ]);
    });

    test('isMock 为 true 时追加 Mock 拦截器，并调用注册回调', () {
      var registered = false;

      final dio = build(
        isMock: true,
        registerMockRules: () => registered = true,
      );

      expect(appInterceptors(dio).last, isA<MockInterceptor>());
      expect(registered, isTrue);
    });

    test('isMock 为 false 时不装 Mock 拦截器，也不调注册回调', () {
      var registered = false;

      final dio = build(registerMockRules: () => registered = true);

      expect(appInterceptors(dio).any((i) => i is MockInterceptor), isFalse);
      expect(registered, isFalse);
    });

    test('调试日志由开关控制，且不与 mock 开关耦合', () {
      expect(
        build(enableDebugLogging: true).interceptors
            .any((i) => i is PrettyDioLogger),
        isTrue,
      );
      expect(build().interceptors.any((i) => i is PrettyDioLogger), isFalse);
    });

    test('BaseOptions 全部来自 NetworkConfig', () {
      final dio = build();

      expect(dio.options.baseUrl, _config.baseUrl);
      expect(
        dio.options.connectTimeout,
        Duration(milliseconds: _config.connectTimeout),
      );
      expect(
        dio.options.receiveTimeout,
        Duration(milliseconds: _config.receiveTimeout),
      );
      expect(dio.options.headers, _config.defaultHeaders);
    });
  });

  group('真实管道语义', () {
    test('5xx 交给 RetryInterceptor，重试后成功', () async {
      final adapter = ScriptedHttpAdapter()
        ..on('/articles', [
          503,
          {'ok': true},
        ]);

      final response = await build(adapter: adapter)
          .get<Map<String, dynamic>>('/articles');

      expect(response.data, {'ok': true});
      expect(adapter.requestCount('/articles'), 2);
    });

    test('text/plain 但内容是 JSON 时被兜底解码成 Map', () async {
      final dio = build(adapter: _PlainTextAdapter('{"ok":true}'));

      final response = await dio.get<Map<String, dynamic>>('/anything');

      expect(response.data, {'ok': true});
    });

    test('不是合法 JSON 时保留原始字符串，不抛异常', () async {
      final dio = build(adapter: _PlainTextAdapter('not json at all'));

      final response = await dio.get<dynamic>('/anything');

      expect(response.data, 'not json at all');
    });
  });
}
