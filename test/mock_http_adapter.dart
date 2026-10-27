import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';

/// 把请求交给一个同步函数处理，函数返回 (状态码, body, headers)。
typedef MockHandler = MockReply Function(RequestOptions options);

class MockReply {
  MockReply(
    this.statusCode,
    this.body, {
    this.headers = const <String, List<String>>{},
    this.bytes,
  });

  final int statusCode;
  final String body;
  final Map<String, List<String>> headers;
  final Uint8List? bytes;
}

/// 单测/集成测试用的假传输层：不联网，只走我们写好的规则。
class MockHttpAdapter implements HttpClientAdapter {
  MockHttpAdapter(this.handler);

  final MockHandler handler;
  final List<RequestOptions> log = <RequestOptions>[];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    log.add(options);
    final MockReply reply = handler(options);
    final ResponseBody body = reply.bytes != null
        ? ResponseBody.fromBytes(
            reply.bytes!,
            reply.statusCode,
            headers: reply.headers,
          )
        : ResponseBody.fromString(
            reply.body,
            reply.statusCode,
            headers: reply.headers,
          );
    return body;
  }

  @override
  void close({bool force = false}) {}

  /// 便捷构造：按路径片段分派的 mock。
  factory MockHttpAdapter.routes(Map<String, MockReply> routes) {
    return MockHttpAdapter((RequestOptions o) {
      final String uri = o.uri.toString();
      for (final MapEntry<String, MockReply> e in routes.entries) {
        if (uri.contains(e.key)) return e.value;
      }
      return MockReply(404, 'no route for $uri');
    });
  }
}

/// JSON 应答。
MockReply mockJson(Object? data, {int status = 200}) {
  return MockReply(
    status,
    jsonEncode(data),
    headers: <String, List<String>>{
      'content-type': <String>['application/json; charset=utf-8'],
    },
  );
}

/// HTML 应答（默认 UTF-8）。
MockReply mockHtml(String html, {int status = 200}) {
  return MockReply(
    status,
    html,
    headers: <String, List<String>>{
      'content-type': <String>['text/html; charset=utf-8'],
    },
  );
}
