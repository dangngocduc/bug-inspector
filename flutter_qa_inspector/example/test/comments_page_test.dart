import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_qa_inspector/flutter_qa_inspector.dart';
import 'package:flutter_qa_inspector_example/comments_page.dart';
import 'package:flutter_qa_inspector_example/jsonplaceholder_api.dart';
import 'package:flutter_test/flutter_test.dart';

/// The QA flows need `flutter test --dart-define=FLUTTER_QA_INSPECTOR=true`.
const _needsQaBuild = !BugInspector.enabledFromEnvironment;

void main() {
  testWidgets('lists the comments and opens one', (tester) async {
    final adapter = _JsonPlaceholderAdapter();
    await _pumpComments(tester, adapter);

    expect(find.text('comment one'), findsOneWidget);
    expect(find.text('comment two'), findsOneWidget);

    await tester.tap(find.text('comment two'));
    await tester.pumpAndSettle();
    expect(find.text('Comment 2'), findsOneWidget);
    expect(find.text('body of 2'), findsOneWidget);
    expect(adapter.paths, ['/comments', '/comments/2']);
  });

  testWidgets('a missing comment shows the 404 and retries', (tester) async {
    final adapter = _JsonPlaceholderAdapter();
    await _pumpComments(tester, adapter);

    await tester.tap(find.byTooltip('Comment không tồn tại (404)'));
    await tester.pumpAndSettle();
    expect(
      find.text('Không tải được comment ${CommentsPage.missingCommentId} '
          '(HTTP 404)'),
      findsOneWidget,
    );

    await tester.tap(find.text('Thử lại'));
    await tester.pumpAndSettle();
    expect(
      adapter.paths.where((path) => path.endsWith('999999')),
      hasLength(2),
    );
  });

  testWidgets('QA flow: the report lists the comment calls, e-mails redacted',
      skip: _needsQaBuild, (tester) async {
    // What main.dart does.
    FlutterQaInspector.install(networkRecorder: exampleNetworkRecorder());
    addTearDown(FlutterQaInspector.debugReset);
    await _pumpComments(tester, _JsonPlaceholderAdapter(), qa: true);
    await tester.tap(find.text('comment one'));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(BugInspector.launcherKey));
    await tester.pump();
    await tester.pump();
    await tester.pump();
    await tester.tap(find.text('Select screen'));
    await tester.pumpAndSettle();

    // The vertical list of the page on screen: the form, then the call.
    final list = find
        .byWidgetPredicate(
          (widget) =>
              widget is Scrollable &&
              widget.axisDirection == AxisDirection.down,
        )
        .first;
    // Newest first.
    final detail = find.text('GET /comments/1');
    await tester.scrollUntilVisible(detail, 200, scrollable: list);
    expect(find.text('GET /comments'), findsOneWidget);
    expect(
      tester.getTopLeft(detail).dy,
      lessThan(tester.getTopLeft(find.text('GET /comments')).dy),
    );

    await tester.tap(detail);
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.textContaining('"email": "REDACTED"'),
      200,
      scrollable: list,
    );
    expect(find.textContaining('qa1@example.com'), findsNothing);
    // The response shows as a JSON tree.
    expect(
      find.byKey(
        const ValueKey('bug_report.json.response.collapse_all'),
        skipOffstage: false,
      ),
      findsOneWidget,
    );
  });
}

Future<void> _pumpComments(
  WidgetTester tester,
  _JsonPlaceholderAdapter adapter, {
  bool qa = false,
}) async {
  final api = CommentsApi(createJsonPlaceholderDio(adapter: adapter));
  await tester.pumpWidget(
    MaterialApp(
      builder: (context, child) => FlutterQaInspector.wrap(
        enabled: qa,
        captureScreenshot: false,
        child: child ?? const SizedBox.shrink(),
      ),
      home: BugInspectablePage(
        id: 'comments',
        child: CommentsPage(api: api),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

/// Answers like jsonplaceholder, with two comments, without the network.
class _JsonPlaceholderAdapter implements HttpClientAdapter {
  final List<String> paths = [];

  static Map<String, Object?> _comment(int id, String name) => {
        'postId': 1,
        'id': id,
        'name': name,
        'email': 'qa$id@example.com',
        'body': 'body of $id',
      };

  static final _comments = {
    1: _comment(1, 'comment one'),
    2: _comment(2, 'comment two'),
  };

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    paths.add(options.path);
    if (options.path == '/comments') {
      return _json(200, _comments.values.toList());
    }
    final id = int.tryParse(options.path.split('/').last);
    final comment = _comments[id];
    return comment == null ? _json(404, {}) : _json(200, comment);
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
