import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';

/// 按路径脚本化响应的假适配器：在**真实的 Dio 管道**里验证拦截器
/// （手工调拦截器回调拿不到 protected 的 `handler.future`）。
///
/// 同一路径可依次给出多个响应（如「先 401、刷新后 200」）；只剩一项时会一直复用。
///
/// 与 `test/support/scripted_http_adapter.dart` 是**两份副本**：根侧测
/// `NetworkModule.dio()` 的装配，包侧测 `createDio`。测试辅助代码无法跨包共享
/// （放进包的 `lib/` 会污染公开 API 并计入覆盖率），所以接受这一处重复——
/// 改这里时同步改那一份，反之亦然。
class ScriptedHttpAdapter implements HttpClientAdapter {
  /// 按到达顺序记录所有请求，便于断言请求头与调用次数
  final List<RequestOptions> requests = [];

  final Map<String, List<Object>> _scripts = {};

  /// 响应前的钩子，可用来把某个请求卡住（测试并发场景）
  Future<void> Function(RequestOptions options)? beforeRespond;

  /// 为「以 [pathSuffix] 结尾」的请求排队响应。
  ///
  /// 每一项要么是状态码（[int]），要么是要以 200 JSON 返回的 [Map]。
  void on(String pathSuffix, List<Object> responses) {
    _scripts[pathSuffix] = List<Object>.of(responses);
  }

  /// 命中该路径的请求次数
  int requestCount(String pathSuffix) =>
      requests.where((r) => r.path.endsWith(pathSuffix)).length;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    await beforeRespond?.call(options);

    List<Object>? queue;
    for (final entry in _scripts.entries) {
      if (options.path.endsWith(entry.key)) {
        queue = entry.value;
        break;
      }
    }

    if (queue == null || queue.isEmpty) {
      return _json(200, const {});
    }

    final response = queue.length > 1 ? queue.removeAt(0) : queue.first;
    if (response is int) {
      return _json(response, const {'message': 'scripted error'});
    }
    return _json(200, response as Map);
  }

  ResponseBody _json(int statusCode, Map<Object?, Object?> body) =>
      ResponseBody.fromString(
        jsonEncode(body),
        statusCode,
        headers: {
          Headers.contentTypeHeader: [Headers.jsonContentType],
        },
      );

  @override
  void close({bool force = false}) {}
}
