part of '../flutter_qa_inspector.dart';

/// Where the request of a [BugNetworkRecord] is.
enum BugNetworkRecordStatus {
  /// The request went out and [BugInspectorDioInterceptor] has not seen its
  /// response or error yet: it was still running when the tester made the
  /// selection, or an interceptor added before this one ended it (for example
  /// a retry interceptor that resolves the error).
  pending,

  /// A response was received and accepted by `validateStatus`.
  completed,

  /// The request ended with a `DioException`: a status code rejected by
  /// `validateStatus`, a timeout, a connection error, a cancel, etc. The
  /// response is part of the record when there was one.
  failed,
}

/// What a [BugNetworkBody] holds.
enum BugNetworkBodyKind {
  /// A JSON value: a map, a list, or an object with a `toJson` method.
  json,

  /// A string.
  text,

  /// Bytes, for example the data of `ResponseType.bytes`. Only the size is
  /// kept.
  bytes,

  /// A Dio `FormData`: its text fields and the names of its files.
  formData,

  /// A stream, for example the data of `ResponseType.stream`. Nothing of it
  /// is read.
  stream,

  /// Any other value. Only its runtime type is kept.
  other,
}

/// The body of a request or a response, as kept in a [BugNetworkRecord].
@immutable
class BugNetworkBody {
  /// Creates a body.
  const BugNetworkBody({
    required this.kind,
    this.value,
    this.valueType,
    this.size,
    this.truncated = false,
  });

  /// What the body holds.
  final BugNetworkBodyKind kind;

  /// The content of the body:
  ///
  /// * [BugNetworkBodyKind.json]: the JSON value, where the fields of
  ///   [BugNetworkRecorder.redactedFields] are replaced by
  ///   [BugNetworkRecorder.redactedValue]. When [truncated], the start of its
  ///   encoded text instead.
  /// * [BugNetworkBodyKind.text]: the text, or its start when [truncated].
  /// * [BugNetworkBodyKind.formData]: `{'fields': [{'name': ..., 'value':
  ///   ...}], 'files': [{'field': ..., 'filename': ..., 'contentType': ...,
  ///   'length': ...}]}`. Field values are redacted like JSON fields, file
  ///   contents are never read.
  /// * Other kinds: `null`.
  final Object? value;

  /// The runtime type of a [BugNetworkBodyKind.other] value.
  final String? valueType;

  /// The length of the whole body: characters of the text or of the encoded
  /// JSON, number of bytes. `null` when it is unknown.
  final int? size;

  /// Whether [value] only holds the first [BugNetworkRecorder.maxBodyLength]
  /// characters of the body.
  final bool truncated;

  /// Converts the body into a JSON compatible map.
  Map<String, Object?> toJson() => <String, Object?>{
        'kind': kind.name,
        if (value != null) 'value': value,
        if (valueType != null) 'valueType': valueType,
        if (size != null) 'size': size,
        if (truncated) 'truncated': true,
      };

  @override
  String toString() => 'BugNetworkBody(${toJson()})';
}

/// One API call recorded by [BugInspectorDioInterceptor].
///
/// Header values and body fields that may hold secrets are redacted, see
/// [BugNetworkRecorder.redactedHeaders] and
/// [BugNetworkRecorder.redactedFields].
@immutable
class BugNetworkRecord {
  /// Creates a record.
  const BugNetworkRecord({
    required this.id,
    required this.status,
    required this.method,
    required this.url,
    required this.startedAtUtc,
    this.endedAtUtc,
    this.requestHeaders = const <String, String>{},
    this.requestBody,
    this.statusCode,
    this.statusMessage,
    this.responseHeaders = const <String, String>{},
    this.responseBody,
    this.errorType,
    this.errorMessage,
    this.errorCauseType,
  });

  /// Identifies the call within the current run, for example `00002a`.
  final String id;

  /// Whether the call is running, succeeded or failed.
  final BugNetworkRecordStatus status;

  /// The HTTP method, upper case, for example `GET`.
  final String method;

  /// The full URL with the query, with the values of the query parameters of
  /// [BugNetworkRecorder.redactedFields] and the user info redacted.
  final String url;

  /// When the request went through the interceptor, in UTC.
  final DateTime startedAtUtc;

  /// When the response or the error went through the interceptor, in UTC.
  /// `null` while [status] is [BugNetworkRecordStatus.pending].
  final DateTime? endedAtUtc;

  /// The request headers, with the values of
  /// [BugNetworkRecorder.redactedHeaders] redacted. A header with several
  /// values has them joined with `, `.
  final Map<String, String> requestHeaders;

  /// The request data, or `null` without one.
  final BugNetworkBody? requestBody;

  /// The HTTP status code of the response, or `null` without a response.
  final int? statusCode;

  /// The HTTP status message of the response, when the adapter gives one.
  final String? statusMessage;

  /// The response headers, redacted like [requestHeaders].
  final Map<String, String> responseHeaders;

  /// The response data, or `null` without a response or without data.
  final BugNetworkBody? responseBody;

  /// The `DioExceptionType` name of a failed call, for example `badResponse`
  /// or `connectionTimeout`.
  final String? errorType;

  /// The message of the `DioException`.
  final String? errorMessage;

  /// The runtime type of the error that caused the `DioException`, for
  /// example `SocketException`.
  final String? errorCauseType;

  /// The time between [startedAtUtc] and [endedAtUtc], or `null` while
  /// pending.
  Duration? get duration => endedAtUtc?.difference(startedAtUtc);

  /// Whether the record has a response, possibly with an error status code.
  bool get hasResponse =>
      statusCode != null || responseBody != null || responseHeaders.isNotEmpty;

  /// Converts the record into a JSON compatible map.
  Map<String, Object?> toJson() {
    final duration = this.duration;
    final endedAtUtc = this.endedAtUtc;
    return <String, Object?>{
      'id': id,
      'status': status.name,
      'method': method,
      'url': url,
      'startedAtUtc': startedAtUtc.toUtc().toIso8601String(),
      if (endedAtUtc != null)
        'endedAtUtc': endedAtUtc.toUtc().toIso8601String(),
      if (duration != null) 'durationMs': duration.inMilliseconds,
      'request': <String, Object?>{
        'headers': requestHeaders,
        if (requestBody != null) 'body': requestBody!.toJson(),
      },
      if (hasResponse)
        'response': <String, Object?>{
          if (statusCode != null) 'statusCode': statusCode,
          if (statusMessage != null) 'statusMessage': statusMessage,
          'headers': responseHeaders,
          if (responseBody != null) 'body': responseBody!.toJson(),
        },
      if (errorType != null)
        'error': <String, Object?>{
          'type': errorType,
          if (errorMessage != null) 'message': errorMessage,
          if (errorCauseType != null) 'causeType': errorCauseType,
        },
    };
  }

  @override
  String toString() => 'BugNetworkRecord($id: ${status.name} $method $url'
      '${statusCode == null ? '' : ' -> $statusCode'}'
      '${errorType == null ? '' : ' ($errorType)'})';
}

/// Keeps a bounded, in-memory list of the API calls of a Dio client.
///
/// Feed it with [BugInspectorDioInterceptor] and pass the same instance to
/// [BugInspector.networkRecorder] so selections include the calls.
/// `FlutterQaInspector.install` creates one, [FlutterQaInspector.networkRecorder].
///
/// The recorder never writes to disk. Before a call is kept, the values of
/// [redactedHeaders] and [redactedFields] are replaced by [redactedValue],
/// and bodies longer than [maxBodyLength] are cut. Other personal data in
/// the bodies is kept: add its field names to [redactedFields], or leave the
/// endpoint out with [BugInspectorDioInterceptor.filter].
///
/// It is a [Listenable]: listeners are notified after every [add] and
/// [clear], for example by [BugNetworkHistoryPage], which lists the calls as
/// they happen.
class BugNetworkRecorder with ChangeNotifier {
  /// Creates a recorder that keeps at most [maxRecords] calls.
  ///
  /// Header names in [redactedHeaders] are compared case insensitively. Field
  /// names in [redactedFields] are compared ignoring case, `_` and `-`, so
  /// `accessToken` also redacts `access_token` and `ACCESS-TOKEN`. To add
  /// names, keep the defaults:
  /// `redactedFields: {...BugNetworkRecorder.defaultRedactedFields, 'iban'}`.
  ///
  /// [clock] returns the current time and defaults to [DateTime.now]. It is
  /// mainly useful in tests.
  BugNetworkRecorder({
    this.maxRecords = defaultMaxRecords,
    this.maxBodyLength = defaultMaxBodyLength,
    Set<String> redactedHeaders = defaultRedactedHeaders,
    Set<String> redactedFields = defaultRedactedFields,
    DateTime Function()? clock,
  })  : assert(maxRecords > 0, 'maxRecords must be greater than zero'),
        assert(maxBodyLength >= 0, 'maxBodyLength must not be negative'),
        redactedHeaders = Set<String>.unmodifiable(
          <String>{for (final name in redactedHeaders) name.toLowerCase()},
        ),
        redactedFields = Set<String>.unmodifiable(
          <String>{for (final name in redactedFields) _normalizeField(name)},
        ),
        _clock = clock ?? DateTime.now;

  /// The default value of [maxRecords].
  static const int defaultMaxRecords = 100;

  /// The default value of [maxBodyLength].
  static const int defaultMaxBodyLength = 16 * 1024;

  /// What replaces a redacted value.
  static const String redactedValue = 'REDACTED';

  /// The default value of [redactedHeaders].
  static const Set<String> defaultRedactedHeaders = <String>{
    'authorization',
    'proxy-authorization',
    'cookie',
    'set-cookie',
    'x-api-key',
    'x-auth-token',
    'x-access-token',
    'x-refresh-token',
  };

  /// The default value of [redactedFields].
  static const Set<String> defaultRedactedFields = <String>{
    'password',
    'passwd',
    'currentPassword',
    'oldPassword',
    'newPassword',
    'confirmPassword',
    'passwordConfirmation',
    'secret',
    'clientSecret',
    'token',
    'accessToken',
    'refreshToken',
    'idToken',
    'apiKey',
    'authorization',
    'otp',
    'pin',
    'cvv',
    'cardNumber',
  };

  /// The maximum number of calls kept. The oldest call is dropped when a new
  /// one is added to a full recorder.
  final int maxRecords;

  /// The maximum number of characters kept of a text or JSON body. `0` keeps
  /// no content, only the size.
  final int maxBodyLength;

  /// The headers whose values are replaced by [redactedValue], lower case.
  final Set<String> redactedHeaders;

  /// The JSON fields, form fields and query parameters whose values are
  /// replaced by [redactedValue], lower case without `_` and `-`.
  final Set<String> redactedFields;

  final DateTime Function() _clock;
  // At most maxRecords: a list is fast enough, and replaces in place.
  final List<BugNetworkRecord> _records = <BugNetworkRecord>[];
  int _nextId = 0;

  /// The number of calls currently kept.
  int get length => _records.length;

  /// All calls currently kept, in the order they started, oldest first.
  List<BugNetworkRecord> get records =>
      List<BugNetworkRecord>.unmodifiable(_records);

  /// The current time of this recorder's clock, in UTC.
  DateTime nowUtc() => _clock().toUtc();

  /// Adds [record], or replaces the kept record with the same
  /// [BugNetworkRecord.id]. Drops the oldest records when the recorder is
  /// full.
  void add(BugNetworkRecord record) {
    final index = _indexOf(record.id);
    if (index != null) {
      _records[index] = record;
    } else {
      _records.add(record);
      if (_records.length > maxRecords) {
        _records.removeRange(0, _records.length - maxRecords);
      }
    }
    notifyListeners();
  }

  /// Returns the calls that started before [nowUtc] and were still running
  /// or ended within [window] before it, oldest first. Every kept call when
  /// [window] is `null`.
  ///
  /// [nowUtc] defaults to the recorder's clock.
  List<BugNetworkRecord> recordsSince(Duration? window, {DateTime? nowUtc}) {
    final now = (nowUtc ?? this.nowUtc()).toUtc();
    final cutoff = window == null ? null : now.subtract(window);
    return List<BugNetworkRecord>.unmodifiable(
      _records.where(
        (record) =>
            !record.startedAtUtc.isAfter(now) &&
            (cutoff == null || !(record.endedAtUtc ?? now).isBefore(cutoff)),
      ),
    );
  }

  /// Removes every call.
  void clear() {
    _records.clear();
    notifyListeners();
  }

  int? _indexOf(String id) {
    // Most lookups are for a recent call: search from the end.
    for (var index = _records.length - 1; index >= 0; index--) {
      if (_records[index].id == id) return index;
    }
    return null;
  }

  BugNetworkRecord? _find(String id) {
    final index = _indexOf(id);
    return index == null ? null : _records[index];
  }

  String _newId() => (++_nextId).toRadixString(16).padLeft(6, '0');

  static String _normalizeField(String name) =>
      name.toLowerCase().replaceAll(RegExp('[-_]'), '');

  bool _isRedactedField(String name) =>
      redactedFields.contains(_normalizeField(name));

  /// [headers] as strings, with the values of [redactedHeaders] redacted.
  Map<String, String> _headers(Map<String, Object?> headers) {
    return Map<String, String>.unmodifiable(<String, String>{
      for (final entry in headers.entries)
        if (entry.value != null)
          entry.key: redactedHeaders.contains(entry.key.toLowerCase())
              ? redactedValue
              : _headerValue(entry.value),
    });
  }

  static String _headerValue(Object? value) =>
      value is Iterable<Object?> ? value.join(', ') : '$value';

  /// [uri] with the user info and the redacted query parameters replaced.
  String _url(Uri uri) {
    var result = uri;
    if (uri.userInfo.isNotEmpty) result = result.replace(userInfo: '');
    final parts = uri.query.isEmpty ? const <String>[] : uri.query.split('&');
    if (parts.any(_isRedactedQueryPart)) {
      result = result.replace(
        query: <String>[
          for (final part in parts)
            _isRedactedQueryPart(part)
                ? '${part.split('=').first}=$redactedValue'
                : part,
        ].join('&'),
      );
    }
    return result.toString();
  }

  bool _isRedactedQueryPart(String part) {
    final name = part.split('=').first;
    try {
      return _isRedactedField(Uri.decodeQueryComponent(name));
    } on ArgumentError {
      return _isRedactedField(name);
    }
  }

  /// A copy of the JSON [value] with the fields of [redactedFields]
  /// redacted.
  Object? _redactJson(Object? value) {
    if (value is Map<String, Object?>) {
      return <String, Object?>{
        for (final entry in value.entries)
          entry.key: _isRedactedField(entry.key)
              ? redactedValue
              : _redactJson(entry.value),
      };
    }
    if (value is List<Object?>) {
      return <Object?>[for (final item in value) _redactJson(item)];
    }
    return value;
  }

  /// [data], a request or response data, as a body.
  BugNetworkBody? _body(Object? data) {
    if (data == null) return null;
    if (data is String) return _text(BugNetworkBodyKind.text, data);
    if (data is List<int>) {
      return BugNetworkBody(kind: BugNetworkBodyKind.bytes, size: data.length);
    }
    if (data is FormData) {
      return BugNetworkBody(
        kind: BugNetworkBodyKind.formData,
        value: <String, Object?>{
          'fields': <Object?>[
            for (final field in data.fields)
              <String, Object?>{
                'name': field.key,
                'value':
                    _isRedactedField(field.key) ? redactedValue : field.value,
              },
          ],
          'files': <Object?>[
            for (final file in data.files)
              <String, Object?>{
                'field': file.key,
                if (file.value.filename != null)
                  'filename': file.value.filename,
                if (file.value.contentType != null)
                  'contentType': file.value.contentType.toString(),
                'length': file.value.length,
              },
          ],
        },
      );
    }
    if (data is ResponseBody || data is Stream<Object?>) {
      return const BugNetworkBody(kind: BugNetworkBodyKind.stream);
    }
    final json = _jsonOf(data);
    if (json == null) {
      return BugNetworkBody(
        kind: BugNetworkBodyKind.other,
        valueType: data.runtimeType.toString(),
      );
    }
    final redacted = _redactJson(json.value);
    final encoded = jsonEncode(redacted);
    if (encoded.length <= maxBodyLength) {
      return BugNetworkBody(
        kind: BugNetworkBodyKind.json,
        value: redacted,
        size: encoded.length,
      );
    }
    return _text(BugNetworkBodyKind.json, encoded);
  }

  /// [data] as a JSON value, or `null` when it is not one. Objects with a
  /// `toJson` method are converted, as Dio does when it sends them.
  static ({Object? value})? _jsonOf(Object data) {
    try {
      return (value: _copyJsonValue(data));
    } on BugSnapshotFormatException {
      try {
        return (value: jsonDecode(jsonEncode(data)));
      } catch (_) {
        return null;
      }
    }
  }

  BugNetworkBody _text(BugNetworkBodyKind kind, String text) {
    final truncated = text.length > maxBodyLength;
    final value = truncated ? text.substring(0, maxBodyLength) : text;
    return BugNetworkBody(
      kind: kind,
      value: value.isEmpty && truncated ? null : value,
      size: text.length,
      truncated: truncated,
    );
  }
}

/// Decides whether [BugInspectorDioInterceptor] records the call of
/// [options].
typedef BugNetworkRequestFilter = bool Function(RequestOptions options);

/// A Dio interceptor that writes every API call, its request, its response
/// and its error, into a [BugNetworkRecorder].
///
/// ```dart
/// final dio = Dio();
/// if (BugInspector.enabledFromEnvironment) {
///   // Last, so it sees the request as it is sent.
///   dio.interceptors.add(BugInspectorDioInterceptor());
/// }
/// ```
///
/// Without [recorder], it writes into [FlutterQaInspector.networkRecorder],
/// read at every request, so the Dio client can be created before or after
/// `FlutterQaInspector.install`. A call made while there is no recorder is
/// not recorded.
///
/// Without `--dart-define=FLUTTER_QA_INSPECTOR=true` it records nothing and
/// only passes every request, response and error on. Still, add it inside
/// `if (BugInspector.enabledFromEnvironment) { ... }` so that such a build
/// leaves it out.
///
/// Recording never interferes with the call: the interceptor always passes
/// the request, the response or the error on unchanged, and an error while
/// recording is dropped. It only adds [extraKey] to `RequestOptions.extra`
/// to match a response with its request.
///
/// Add it after the interceptors that change the request, such as the one
/// that adds the access token (its value is redacted anyway). Dio runs the
/// interceptors in the order they were added for the request, the response
/// and the error alike, so an interceptor before it can hide part of a call:
///
/// * One that answers in `onRequest`, such as a cache, keeps the call from
///   this interceptor: it is not recorded.
/// * One that ends the call in `onError`, such as a retry interceptor that
///   resolves the error, hides its end: the record stays
///   [BugNetworkRecordStatus.pending].
///
/// A retry made with `dio.fetch` goes through the interceptor again and gets
/// its own record.
class BugInspectorDioInterceptor extends Interceptor {
  /// Creates an interceptor that writes into [recorder].
  ///
  /// When [filter] is given, only the calls it accepts are recorded.
  const BugInspectorDioInterceptor({this.recorder, this.filter});

  /// Where the calls are written. [FlutterQaInspector.networkRecorder] when
  /// `null`.
  final BugNetworkRecorder? recorder;

  /// Optional filter applied to every request.
  final BugNetworkRequestFilter? filter;

  /// The key of `RequestOptions.extra` that holds the
  /// [BugNetworkRecord.id] of the call.
  static const String extraKey = 'flutter_qa_inspector.network_record_id';

  BugNetworkRecorder? get _recorder =>
      recorder ?? FlutterQaInspector.networkRecorder;

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    if (BugInspector.enabledFromEnvironment) _start(options);
    handler.next(options);
  }

  @override
  void onResponse(
    Response<dynamic> response,
    ResponseInterceptorHandler handler,
  ) {
    if (BugInspector.enabledFromEnvironment) {
      _finish(response.requestOptions, response: response);
    }
    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    if (BugInspector.enabledFromEnvironment) {
      _finish(err.requestOptions, response: err.response, error: err);
    }
    handler.next(err);
  }

  void _start(RequestOptions options) {
    // The interceptor runs inside the app's request: never throw there.
    try {
      // A retry of a recorded call is a new call.
      options.extra.remove(extraKey);
      final recorder = _recorder;
      if (recorder == null) return;
      if (filter != null && !filter!(options)) return;
      final record = _requestRecord(recorder, options, recorder._newId());
      options.extra[extraKey] = record.id;
      recorder.add(record);
    } catch (error) {
      _debugReport('request', error);
    }
  }

  void _finish(
    RequestOptions options, {
    Response<dynamic>? response,
    DioException? error,
  }) {
    try {
      final id = options.extra[extraKey];
      final recorder = _recorder;
      if (id is! String || recorder == null) return;
      final started =
          recorder._find(id) ?? _requestRecord(recorder, options, id);
      recorder.add(
        BugNetworkRecord(
          id: id,
          status: error == null
              ? BugNetworkRecordStatus.completed
              : BugNetworkRecordStatus.failed,
          method: started.method,
          url: started.url,
          startedAtUtc: started.startedAtUtc,
          endedAtUtc: recorder.nowUtc(),
          requestHeaders: started.requestHeaders,
          requestBody: started.requestBody,
          statusCode: response?.statusCode,
          statusMessage: response?.statusMessage,
          responseHeaders: response == null
              ? const <String, String>{}
              : recorder._headers(response.headers.map),
          responseBody: response == null ? null : recorder._body(response.data),
          errorType: error?.type.name,
          errorMessage: error?.message,
          errorCauseType: error?.error?.runtimeType.toString(),
        ),
      );
    } catch (error) {
      _debugReport('response', error);
    }
  }

  static BugNetworkRecord _requestRecord(
    BugNetworkRecorder recorder,
    RequestOptions options,
    String id,
  ) {
    return BugNetworkRecord(
      id: id,
      status: BugNetworkRecordStatus.pending,
      method: options.method.toUpperCase(),
      url: recorder._url(options.uri),
      startedAtUtc: recorder.nowUtc(),
      requestHeaders: recorder._headers(options.headers),
      requestBody: recorder._body(options.data),
    );
  }

  static void _debugReport(String what, Object error) {
    assert(() {
      debugPrint('flutter_qa_inspector: could not record a $what: $error');
      return true;
    }());
  }
}
