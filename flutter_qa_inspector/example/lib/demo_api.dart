import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_qa_inspector/flutter_qa_inspector.dart';

/// The Dio client of the example.
///
/// A local adapter answers in place of a server, so the example runs
/// offline. A real app keeps its own adapter and only adds the interceptor.
final Dio demoDio = createDemoDio();

Dio createDemoDio() {
  final dio = Dio(
    BaseOptions(
      baseUrl: 'https://api.example.com',
      // A fake token: the report shows `REDACTED` instead.
      headers: {'Authorization': 'Bearer demo-token'},
    ),
  )..httpClientAdapter = DemoApiAdapter();
  // `true` only in builds made with --dart-define=FLUTTER_QA_INSPECTOR=true:
  // a production build leaves the interceptor out. Without a recorder, it
  // writes into FlutterQaInspector.networkRecorder, which
  // FlutterQaInspector.install creates. Add it last, after the interceptors
  // that change the request.
  if (BugInspector.enabledFromEnvironment) {
    dio.interceptors.add(const BugInspectorDioInterceptor());
  }
  return dio;
}

/// Answers `GET /products` with 30 products after 300 ms, and every other
/// request with a 404.
class DemoApiAdapter implements HttpClientAdapter {
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    await Future<void>.delayed(const Duration(milliseconds: 300));
    if (options.method == 'GET' && options.path == '/products') {
      return _json(200, {
        'items': [
          for (var i = 1; i <= 30; i++) {'id': i, 'name': 'Sản phẩm $i'},
        ],
      });
    }
    return _json(404, {'error': 'not_found', 'path': options.path});
  }

  static ResponseBody _json(int statusCode, Object body) {
    return ResponseBody.fromBytes(
      utf8.encode(jsonEncode(body)),
      statusCode,
      headers: {
        Headers.contentTypeHeader: ['application/json; charset=utf-8'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}
