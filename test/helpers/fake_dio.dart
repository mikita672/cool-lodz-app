import 'dart:async';
import 'dart:typed_data';

import 'package:dio/dio.dart';

typedef FakeHandler = FutureOr<ResponseBody> Function(RequestOptions options);

/// Dio adapter that answers with [handler] instead of the network.
class FakeAdapter implements HttpClientAdapter {
  FakeAdapter(this.handler);

  final FakeHandler handler;
  final requests = <RequestOptions>[];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    return handler(options);
  }

  @override
  void close({bool force = false}) {}
}

ResponseBody jsonBody(String json, [int status = 200]) =>
    ResponseBody.fromString(
      json,
      status,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );

Dio fakeDio(FakeAdapter adapter) =>
    Dio(BaseOptions(baseUrl: 'https://api.test'))..httpClientAdapter = adapter;
