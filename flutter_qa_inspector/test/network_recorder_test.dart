import 'dart:async';
import 'dart:convert';
import 'dart:io' show SocketException;

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_qa_inspector/flutter_qa_inspector.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/build_mode.dart';
import 'support/test_host.dart';

void main() {
  group('BugNetworkRecorder', () {
    test('keeps the newest maxRecords calls and replaces by id', () {
      final recorder = BugNetworkRecorder(maxRecords: 2);
      recorder
        ..add(_record('1'))
        ..add(_record('2'))
        ..add(_record('3'));
      expect(recorder.records.map((record) => record.id), ['2', '3']);

      recorder.add(_record('2', status: BugNetworkRecordStatus.completed));
      expect(recorder.records.map((record) => record.id), ['2', '3']);
      expect(recorder.records.first.status, BugNetworkRecordStatus.completed);

      recorder.clear();
      expect(recorder.length, 0);
    });

    test('recordsSince keeps running calls and calls ended in the window', () {
      final now = DateTime.utc(2026, 11, 13, 10);
      final recorder = BugNetworkRecorder(clock: () => now)
        ..add(_record('old', endedAt: now.subtract(const Duration(minutes: 2))))
        ..add(_record('recent',
            endedAt: now.subtract(const Duration(seconds: 10))))
        ..add(_record('running'))
        ..add(
            _record('future', startedAt: now.add(const Duration(seconds: 1))));

      expect(
        recorder
            .recordsSince(const Duration(minutes: 1))
            .map((record) => record.id),
        ['recent', 'running'],
      );
      expect(
        recorder.recordsSince(null).map((record) => record.id),
        ['old', 'recent', 'running'],
      );
    });

    test('a report has the newest maxReportRecords calls, oldest first', () {
      final now = DateTime.utc(2026, 11, 13, 10);
      List<String> ids(BugNetworkRecorder recorder, [Duration? window]) =>
          recorder.reportRecords(window).map((record) => record.id).toList();
      BugNetworkRecorder filled(BugNetworkRecorder recorder) {
        for (var i = 1; i <= 12; i++) {
          recorder.add(
            _record(
              '$i',
              endedAt: now.subtract(Duration(minutes: 12 - i)),
            ),
          );
        }
        return recorder;
      }

      final byDefault = filled(BugNetworkRecorder(clock: () => now));
      expect(BugNetworkRecorder.defaultMaxReportRecords, 10);
      expect(byDefault.length, 12);
      expect(ids(byDefault), [for (var i = 3; i <= 12; i++) '$i']);
      // The window applies first: fewer calls than the limit.
      expect(ids(byDefault, const Duration(minutes: 2)), ['10', '11', '12']);

      final three =
          filled(BugNetworkRecorder(maxReportRecords: 3, clock: () => now));
      expect(ids(three), ['10', '11', '12']);
      // The history keeps every call.
      expect(three.records, hasLength(12));

      final none =
          filled(BugNetworkRecorder(maxReportRecords: 0, clock: () => now));
      expect(ids(none), isEmpty);
    });

    test('toJson has the request, the response and the error', () {
      final record = BugNetworkRecord(
        id: '00002a',
        status: BugNetworkRecordStatus.failed,
        method: 'GET',
        url: 'https://api.example.com/items',
        startedAtUtc: DateTime.utc(2026, 11, 13, 10),
        endedAtUtc: DateTime.utc(2026, 11, 13, 10, 0, 0, 250),
        requestHeaders: const {'accept': 'application/json'},
        statusCode: 500,
        responseHeaders: const {'content-type': 'application/json'},
        responseBody: const BugNetworkBody(
          kind: BugNetworkBodyKind.json,
          value: {'code': 'internal'},
          size: 19,
        ),
        errorType: 'badResponse',
        errorMessage: 'Bad response',
      );

      expect(jsonDecode(jsonEncode(record.toJson())), {
        'id': '00002a',
        'status': 'failed',
        'method': 'GET',
        'url': 'https://api.example.com/items',
        'startedAtUtc': '2026-11-13T10:00:00.000Z',
        'endedAtUtc': '2026-11-13T10:00:00.250Z',
        'durationMs': 250,
        'request': {
          'headers': {'accept': 'application/json'},
        },
        'response': {
          'statusCode': 500,
          'headers': {'content-type': 'application/json'},
          'body': {
            'kind': 'json',
            'value': {'code': 'internal'},
            'size': 19,
          },
        },
        'error': {'type': 'badResponse', 'message': 'Bad response'},
      });
    });

    test('a selection lists its calls under network', () {
      final selection = BugWidgetSelection(
        id: 'catalog',
        widgetType: 'CatalogPage',
        bounds: Rect.zero,
        capturedAtUtc: DateTime.utc(2026, 11, 13),
        network: [_record('1')],
      );
      final json = selection.toJson();
      expect(json['network'], [_record('1').toJson()]);
      expect(
        BugWidgetSelection(
          id: 'x',
          widgetType: 'X',
          bounds: Rect.zero,
          capturedAtUtc: DateTime.utc(2026),
        ).toJson()['network'],
        isEmpty,
      );
    });
  });

  productionBuildOnly(() {
    test('the interceptor records nothing and passes the call on', () async {
      final recorder = BugNetworkRecorder();
      final dio = _dio(
        recorder,
        (options) async => _json({'ok': true}),
      );

      final response = await dio.get<Object?>('https://api.example.com/ok');

      expect(response.data, {'ok': true});
      expect(recorder.length, 0);
      expect(
        response.requestOptions.extra,
        isNot(contains(BugInspectorDioInterceptor.extraKey)),
      );
    });
  });

  qaBuildOnly(() {
    late DateTime now;
    setUp(() => now = DateTime.utc(2026, 11, 13, 10));

    BugNetworkRecorder newRecorder({int maxBodyLength = 1000}) =>
        BugNetworkRecorder(maxBodyLength: maxBodyLength, clock: () => now);

    test('records a successful call without changing it', () async {
      final recorder = newRecorder();
      final dio = _dio(recorder, (options) async {
        now = now.add(const Duration(milliseconds: 120));
        return _json({
          'items': [1, 2],
        });
      });

      final response = await dio.get<Object?>(
        'https://api.example.com/items',
        queryParameters: {'page': 2},
      );

      expect(response.data, {
        'items': [1, 2],
      });
      final record = recorder.records.single;
      expect(record.status, BugNetworkRecordStatus.completed);
      expect(record.method, 'GET');
      expect(record.url, 'https://api.example.com/items?page=2');
      expect(record.statusCode, 200);
      expect(record.duration, const Duration(milliseconds: 120));
      expect(record.requestBody, isNull);
      expect(record.responseHeaders['content-type'], 'application/json');
      expect(record.responseBody!.kind, BugNetworkBodyKind.json);
      expect(record.responseBody!.value, {
        'items': [1, 2],
      });
      expect(
        response.requestOptions.extra[BugInspectorDioInterceptor.extraKey],
        record.id,
      );
    });

    test('redacts secret headers, query parameters and body fields', () async {
      final recorder = newRecorder();
      final dio = _dio(recorder, (options) async {
        return _json(
          {
            'access_token': 'a-token',
            'user': {'name': 'Tester', 'refreshToken': 'r-token'},
          },
          headers: {
            'set-cookie': ['session=1', 'theme=dark'],
          },
        );
      });

      await dio.post<Object?>(
        'https://user:pw@api.example.com/login?api_key=k1&lang=vi',
        data: {
          'email': 'qa@example.com',
          'Password': 'p@ss',
          'devices': [
            {'pin': '1234', 'model': 'Pixel'},
          ],
        },
        options: Options(
          headers: {'Authorization': 'Bearer abc', 'X-Trace': 't1'},
        ),
      );

      final json = jsonEncode(recorder.records.single.toJson());
      for (final secret in ['abc', 'p@ss', '1234', 'a-token', 'r-token']) {
        expect(json, isNot(contains(secret)));
      }
      final record = recorder.records.single;
      expect(
        record.url,
        'https://api.example.com/login?api_key=REDACTED&lang=vi',
      );
      expect(record.requestHeaders['Authorization'], 'REDACTED');
      expect(record.requestHeaders['X-Trace'], 't1');
      expect(record.responseHeaders['set-cookie'], 'REDACTED');
      expect(record.requestBody!.value, {
        'email': 'qa@example.com',
        'Password': 'REDACTED',
        'devices': [
          {'pin': 'REDACTED', 'model': 'Pixel'},
        ],
      });
      expect(record.responseBody!.value, {
        'access_token': 'REDACTED',
        'user': {'name': 'Tester', 'refreshToken': 'REDACTED'},
      });
    });

    test('a rejected status code fails the call and keeps the response',
        () async {
      final recorder = newRecorder();
      final dio = _dio(
        recorder,
        (options) async => _json({'code': 'internal'}, statusCode: 500),
      );

      await expectLater(
        dio.get<Object?>('https://api.example.com/fail'),
        throwsA(
          isA<DioException>().having(
            (error) => error.type,
            'type',
            DioExceptionType.badResponse,
          ),
        ),
      );

      final record = recorder.records.single;
      expect(record.status, BugNetworkRecordStatus.failed);
      expect(record.errorType, 'badResponse');
      expect(record.statusCode, 500);
      expect(record.responseBody!.value, {'code': 'internal'});
      expect(record.toJson(),
          containsPair('response', isA<Map<String, Object?>>()));
    });

    test('a connection error fails the call without a response', () async {
      final recorder = newRecorder();
      final dio = _dio(
        recorder,
        (options) async => throw const SocketException('no route'),
      );

      await expectLater(
        dio.get<Object?>('https://api.example.com/down'),
        throwsA(isA<DioException>()),
      );

      final record = recorder.records.single;
      expect(record.status, BugNetworkRecordStatus.failed);
      expect(record.hasResponse, isFalse);
      expect(record.errorCauseType, 'SocketException');
      expect(record.toJson(), isNot(contains('response')));
    });

    test('cuts long bodies and keeps only the size of bytes', () async {
      final recorder = newRecorder(maxBodyLength: 10);
      final dio = _dio(
        recorder,
        (options) async => ResponseBody.fromString('0123456789abcdef', 200),
      );

      await dio.post<Object?>(
        'https://api.example.com/text',
        data: {'list': List<int>.filled(20, 7)},
        options: Options(responseType: ResponseType.plain),
      );
      await dio.get<Object?>(
        'https://api.example.com/bytes',
        options: Options(responseType: ResponseType.bytes),
      );

      final text = recorder.records.first;
      expect(text.requestBody!.kind, BugNetworkBodyKind.json);
      expect(text.requestBody!.truncated, isTrue);
      expect(text.requestBody!.value, '{"list":[7');
      expect(text.responseBody!.kind, BugNetworkBodyKind.text);
      expect(text.responseBody!.value, '0123456789');
      expect(text.responseBody!.size, 16);
      expect(text.responseBody!.truncated, isTrue);

      final bytes = recorder.records.last.responseBody!;
      expect(bytes.kind, BugNetworkBodyKind.bytes);
      expect(bytes.size, 16);
      expect(bytes.value, isNull);
    });

    test('lists the fields and the files of a FormData', () async {
      final recorder = newRecorder();
      final dio = _dio(recorder, (options) async => _json({}));

      await dio.post<Object?>(
        'https://api.example.com/upload',
        data: FormData.fromMap({
          'title': 'Crash',
          'otp': '999111',
          'file': MultipartFile.fromString('log', filename: 'log.txt'),
        }),
      );

      final body = recorder.records.single.requestBody!;
      expect(body.kind, BugNetworkBodyKind.formData);
      expect(body.value, {
        'fields': [
          {'name': 'title', 'value': 'Crash'},
          {'name': 'otp', 'value': 'REDACTED'},
        ],
        'files': [
          {
            'field': 'file',
            'filename': 'log.txt',
            'contentType': 'text/plain; charset=utf-8',
            'length': 3,
          },
        ],
      });
    });

    test('a running call is pending', () async {
      final recorder = newRecorder();
      final response = Completer<ResponseBody>();
      final dio = _dio(recorder, (options) => response.future);

      final call = dio.get<Object?>('https://api.example.com/slow');
      await pumpEventQueue();
      expect(recorder.records.single.status, BugNetworkRecordStatus.pending);
      expect(recorder.records.single.toJson(), isNot(contains('endedAtUtc')));

      response.complete(_json({}));
      await call;
      expect(recorder.records.single.status, BugNetworkRecordStatus.completed);
    });

    test('a retry with dio.fetch gets its own record', () async {
      final recorder = newRecorder();
      var attempts = 0;
      final dio = _dio(recorder, (options) async {
        attempts++;
        return _json({}, statusCode: attempts == 1 ? 503 : 200);
      });

      final options = await dio
          .get<Object?>('https://api.example.com/retry')
          .then<RequestOptions>((response) => response.requestOptions)
          .catchError((Object error) => (error as DioException).requestOptions);
      await dio.fetch<Object?>(options);

      expect(
        recorder.records.map((record) => record.statusCode),
        [503, 200],
      );
      expect(recorder.records.first.id, isNot(recorder.records.last.id));
    });

    test('filter leaves calls out, and its errors never reach the call',
        () async {
      final recorder = newRecorder();
      final dio = Dio()
        ..httpClientAdapter = _FakeAdapter((options) async => _json({}))
        ..interceptors.add(
          BugInspectorDioInterceptor(
            recorder: recorder,
            filter: (options) {
              if (options.path.contains('boom')) throw StateError('filter');
              return !options.path.contains('health');
            },
          ),
        );

      await dio.get<Object?>('https://api.example.com/health');
      await dio.get<Object?>('https://api.example.com/boom');
      await dio.get<Object?>('https://api.example.com/items');

      expect(
        recorder.records.map((record) => record.url),
        ['https://api.example.com/items'],
      );
    });

    test('without a recorder it writes into FlutterQaInspector', () async {
      final dio = Dio()
        ..httpClientAdapter = _FakeAdapter((options) async => _json({}))
        ..interceptors.add(const BugInspectorDioInterceptor());

      // Before install: nothing to write into.
      await dio.get<Object?>('https://api.example.com/early');

      FlutterQaInspector.install();
      addTearDown(FlutterQaInspector.debugReset);
      await dio.get<Object?>('https://api.example.com/late');

      expect(
        FlutterQaInspector.networkRecorder!.records.map((record) => record.url),
        ['https://api.example.com/late'],
      );
    });

    testWidgets('a selection has at most maxReportRecords calls',
        (tester) async {
      final recorder = BugNetworkRecorder(maxReportRecords: 2, clock: () => now)
        ..add(_record('a', endedAt: now))
        ..add(_record('b', endedAt: now))
        ..add(_record('c'));
      final selections = await pumpHost(
        tester,
        networkRecorder: recorder,
        home: Scaffold(
          body: Center(child: BugInspectable(id: 'button', child: box(80, 40))),
        ),
      );

      await enable(tester);
      await tapCenterOf(tester, inspectable('button'));

      expect(
        selections.single.network.map((record) => record.id),
        ['b', 'c'],
      );
      expect(selections.single.toJson()['network'], hasLength(2));
    });

    testWidgets('a selection captures the calls of the recorder',
        (tester) async {
      final recorder = BugNetworkRecorder(clock: () => now)
        ..add(_record('done', endedAt: now))
        ..add(_record('running'));
      final selections = await pumpHost(
        tester,
        networkRecorder: recorder,
        home: Scaffold(
          body: Center(child: BugInspectable(id: 'button', child: box(80, 40))),
        ),
      );

      await enable(tester);
      await tapCenterOf(tester, inspectable('button'));

      final network = selections.single.network;
      expect(network.map((record) => record.id), ['done', 'running']);
      expect(network.last.status, BugNetworkRecordStatus.pending);
      // The selection keeps the calls as they were.
      recorder.add(_record('running', status: BugNetworkRecordStatus.failed));
      expect(network.last.status, BugNetworkRecordStatus.pending);
    });
  });
}

BugNetworkRecord _record(
  String id, {
  BugNetworkRecordStatus? status,
  DateTime? startedAt,
  DateTime? endedAt,
}) {
  return BugNetworkRecord(
    id: id,
    status: status ??
        (endedAt == null
            ? BugNetworkRecordStatus.pending
            : BugNetworkRecordStatus.completed),
    method: 'GET',
    url: 'https://api.example.com/$id',
    startedAtUtc: startedAt ?? DateTime.utc(2026, 11, 13, 9),
    endedAtUtc: endedAt,
  );
}

Dio _dio(
  BugNetworkRecorder recorder,
  Future<ResponseBody> Function(RequestOptions options) handler,
) {
  return Dio()
    ..httpClientAdapter = _FakeAdapter(handler)
    ..interceptors.add(BugInspectorDioInterceptor(recorder: recorder));
}

ResponseBody _json(
  Object? body, {
  int statusCode = 200,
  Map<String, List<String>> headers = const {},
}) {
  return ResponseBody.fromString(
    jsonEncode(body),
    statusCode,
    headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType],
      ...headers,
    },
  );
}

class _FakeAdapter implements HttpClientAdapter {
  _FakeAdapter(this.handler);

  final Future<ResponseBody> Function(RequestOptions options) handler;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) =>
      handler(options);

  @override
  void close({bool force = false}) {}
}
