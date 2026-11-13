import 'dart:convert';

import 'package:archive/archive.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_qa_inspector/flutter_qa_inspector.dart';
import 'package:flutter_test/flutter_test.dart';

const _en = BugReportStrings.en;

void main() {
  testWidgets('the form lists the calls, newest first, and opens one',
      (tester) async {
    await _pumpReport(tester, _selection([_ok, _failed]));

    final section = find.text(_en.sectionNetwork.toUpperCase());
    await tester.scrollUntilVisible(section, 200, scrollable: _list);
    expect(find.text(_en.networkCount(2)), findsOneWidget);
    final okTile = find.byKey(const ValueKey('bug_report.network.000001'));
    final failedTile = find.byKey(const ValueKey('bug_report.network.000002'));
    expect(
      tester.getTopLeft(failedTile).dy,
      lessThan(tester.getTopLeft(okTile).dy),
    );
    expect(find.text('GET /items?page=2'), findsOneWidget);
    expect(find.text('api.example.com · 120 ms'), findsOneWidget);
    expect(find.text('500'), findsOneWidget);

    // The preview of the payload leaves the calls to their own section.
    final payload = tester
        .widgetList<SelectableText>(find.byType(SelectableText))
        .single
        .data!;
    expect(jsonDecode(payload), isNot(contains('network')));

    await tester.tap(failedTile);
    await tester.pumpAndSettle();
    expect(find.text('POST 500'), findsOneWidget);
    expect(find.text(_en.networkRequestBody.toUpperCase()), findsOneWidget);
    expect(find.textContaining('"email": "qa@example.com"'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text(_en.networkError.toUpperCase()),
      200,
      scrollable: _list,
    );
    expect(find.textContaining('badResponse'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text(_en.networkTruncated(4, 30)),
      200,
      scrollable: _list,
    );

    // Back to the form, in the report's navigator.
    await tester.tap(find.text(_en.title));
    await tester.pumpAndSettle();
    expect(find.text(_en.send), findsOneWidget);
  });

  testWidgets('a JSON body shows as a tree that expands and collapses',
      (tester) async {
    // Tall enough for the whole tree.
    tester.view.physicalSize = const Size(800, 2000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await _pumpReport(tester, _selection([_ok, _failed]));
    await tester.scrollUntilVisible(
      find.text('GET /items?page=2'),
      200,
      scrollable: _list,
    );
    await tester.tap(find.text('GET /items?page=2'));
    await tester.pumpAndSettle();

    final expandAll =
        find.byKey(const ValueKey('bug_report.json.response.expand_all'));
    final collapseAll =
        find.byKey(const ValueKey('bug_report.json.response.collapse_all'));
    await tester.scrollUntilVisible(collapseAll, 200, scrollable: _list);
    // A small body shows whole, right in the page.
    expect(find.text(_en.networkResponseBody.toUpperCase()), findsOneWidget);
    expect(find.text(_en.jsonItemCount(4)), findsOneWidget);
    expect(find.textContaining('"total": 1'), findsOneWidget);
    expect(find.textContaining('"ok": true'), findsOneWidget);
    expect(find.textContaining('"next": '), findsOneWidget);
    expect(find.textContaining('"id": 7'), findsOneWidget);
    expect(find.textContaining('"new"'), findsOneWidget);

    // Collapse all keeps the root open: its keys stay, every object and list
    // below closes.
    await tester.tap(collapseAll);
    await tester.pumpAndSettle();
    expect(find.textContaining('"total": 1'), findsOneWidget);
    expect(find.textContaining('"id": 7'), findsNothing);
    expect(find.textContaining('"new"'), findsNothing);

    // A tap on a list opens it: its object stays closed.
    await tester.tap(find.textContaining('"items": '));
    await tester.pumpAndSettle();
    expect(find.text(_en.jsonItemCount(2)), findsOneWidget);
    expect(find.textContaining('"id": 7'), findsNothing);

    await tester.tap(expandAll);
    await tester.pumpAndSettle();
    expect(find.textContaining('"id": 7'), findsOneWidget);
    expect(find.textContaining('"new"'), findsOneWidget);
  });

  testWidgets('only a whole JSON object or list body is a tree',
      (tester) async {
    await _pumpReport(tester, _selection([_failed]));
    final call = find.text('POST /orders?lang=vi&q=a%20b');
    await tester.scrollUntilVisible(call, 200, scrollable: _list);
    await tester.tap(call);
    await tester.pumpAndSettle();

    // The JSON request body is a tree, the cut text response is text.
    expect(
      find.byKey(
        const ValueKey('bug_report.json.request.expand_all'),
        skipOffstage: false,
      ),
      findsOneWidget,
    );
    await tester.scrollUntilVisible(
      find.text(_en.networkTruncated(4, 30)),
      200,
      scrollable: _list,
    );
    expect(
      find.byKey(
        const ValueKey('bug_report.json.response.expand_all'),
        skipOffstage: false,
      ),
      findsNothing,
    );
    expect(find.text('oops'), findsOneWidget);
  });

  testWidgets('the request shows its path, query and headers to copy',
      (tester) async {
    final copied = <String>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          copied.add(
              (call.arguments as Map<Object?, Object?>)['text']! as String);
        }
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, null),
    );
    await _pumpReport(tester, _selection([_ok, _failed]));
    final call = find.text('POST /orders?lang=vi&q=a%20b');
    await tester.scrollUntilVisible(call, 200, scrollable: _list);
    await tester.tap(call);
    await tester.pumpAndSettle();

    expect(find.text(_en.networkRequest.toUpperCase()), findsOneWidget);
    expect(find.text('https://api.example.com'), findsOneWidget);
    // The method, the path, then each query parameter in its own span.
    final path = tester
        .widget<SelectableText>(
          find.byWidgetPredicate(
            (widget) =>
                widget is SelectableText &&
                (widget.textSpan?.toPlainText().startsWith('POST ') ?? false),
          ),
        )
        .textSpan!;
    expect(path.toPlainText(), 'POST /orders?lang=vi&q=a b');
    final spans = <String>[];
    path.visitChildren((span) {
      if (span is TextSpan && span.text != null) spans.add(span.text!);
      return true;
    });
    expect(spans,
        ['POST ', '/orders', '?', 'lang', '=', 'vi', '&', 'q', '=', 'a b']);

    // A header value is copied with its button; a redacted one has none.
    expect(find.text('X-Trace'), findsOneWidget);
    expect(find.text('t-1'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('bug_report.header.copy.Authorization')),
      findsNothing,
    );
    await tester
        .tap(find.byKey(const ValueKey('bug_report.header.copy.X-Trace')));
    await tester.pump();
    expect(copied, ['t-1']);
    await tester.pump(const Duration(seconds: 2));

    // The response: status and duration.
    await tester.scrollUntilVisible(
      find.text(_en.networkResponse.toUpperCase()),
      200,
      scrollable: _list,
    );
    expect(find.text('1000 ms'), findsOneWidget);
  });

  testWidgets('the zip has the calls in inspector.json', (tester) async {
    final shared = <ShareParams>[];
    await _pumpReport(
      tester,
      _selection([_ok]),
      share: (params) async {
        shared.add(params);
        return const ShareResult('done', ShareResultStatus.success);
      },
    );

    await tester.tap(find.text(_en.send));
    await tester.pumpAndSettle();

    final zip = ZipDecoder()
        .decodeBytes(await shared.single.files!.single.readAsBytes());
    final json = jsonDecode(
      utf8.decode(
          zip.findFile(BugReportBundle.inspectorFileName)!.readBytes()!),
    ) as Map<String, Object?>;
    final inspector = json['inspector']! as Map<String, Object?>;
    expect(inspector['network'], [
      jsonDecode(jsonEncode(_ok.toJson())),
    ]);
  });

  testWidgets('a selection without calls has no network section',
      (tester) async {
    await _pumpReport(tester, _selection(const []));

    expect(
      find.text(_en.sectionNetwork.toUpperCase(), skipOffstage: false),
      findsNothing,
    );
  });

  test('the network texts default to English and copy', () {
    const strings = BugReportStrings(
      selectionHint: '',
      pageButtonLabel: '',
      title: '',
      cancel: '',
      send: '',
      sectionTarget: '',
      kindScreen: '',
      kindWidget: '',
      sectionScreenshot: '',
      annotateHint: '',
      annotatedCount: _count,
      sectionDescription: '',
      descriptionPlaceholder: '',
      sectionPayload: '',
      copyJson: '',
      copied: '',
      discardTitle: '',
      discardMessage: '',
      discardConfirm: '',
      keepEditing: '',
      shareFailed: '',
      ok: '',
      shareSubject: _subject,
      markup: '',
      annotateTitle: '',
      annotateClearAll: '',
      annotateClearAllTitle: '',
      annotateClearAllConfirm: '',
      annotateDone: '',
      annotateDeleteBox: '',
      annotateResetZoom: '',
      annotateInstructions: '',
    );
    expect(strings.sectionNetwork, _en.sectionNetwork);
    expect(strings.networkCount(3), _en.networkCount(3));
    expect(BugReportStrings.vi.networkPending, 'Đang chờ');
    expect(
      _en.copyWith(networkError: 'Failure').networkError,
      'Failure',
    );
  });
}

/// The scrollable of the page on screen: the form or a call.
final Finder _list = find
    .byWidgetPredicate(
      (widget) =>
          widget is Scrollable && widget.axisDirection == AxisDirection.down,
    )
    .first;

String _count(int count) => '$count';
String _subject(String name) => name;

final BugNetworkRecord _ok = BugNetworkRecord(
  id: '000001',
  status: BugNetworkRecordStatus.completed,
  method: 'GET',
  url: 'https://api.example.com/items?page=2',
  startedAtUtc: DateTime.utc(2026, 11, 13, 10),
  endedAtUtc: DateTime.utc(2026, 11, 13, 10, 0, 0, 120),
  statusCode: 200,
  responseHeaders: const {'content-type': 'application/json'},
  responseBody: const BugNetworkBody(
    kind: BugNetworkBodyKind.json,
    value: {
      'items': [
        {
          'id': 7,
          'tags': ['new'],
        },
      ],
      'total': 1,
      'next': null,
      'ok': true,
    },
    size: 64,
  ),
);

final BugNetworkRecord _failed = BugNetworkRecord(
  id: '000002',
  status: BugNetworkRecordStatus.failed,
  method: 'POST',
  url: 'https://api.example.com/orders?lang=vi&q=a%20b',
  startedAtUtc: DateTime.utc(2026, 11, 13, 10, 0, 1),
  endedAtUtc: DateTime.utc(2026, 11, 13, 10, 0, 2),
  requestHeaders: const {'Authorization': 'REDACTED', 'X-Trace': 't-1'},
  requestBody: const BugNetworkBody(
    kind: BugNetworkBodyKind.json,
    value: {'email': 'qa@example.com'},
    size: 24,
  ),
  statusCode: 500,
  responseBody: const BugNetworkBody(
    kind: BugNetworkBodyKind.text,
    value: 'oops',
    size: 30,
    truncated: true,
  ),
  errorType: 'badResponse',
  errorMessage: 'The request failed',
);

BugWidgetSelection _selection(List<BugNetworkRecord> network) =>
    BugWidgetSelection(
      id: 'catalog',
      widgetType: 'CatalogPage',
      bounds: const Rect.fromLTWH(0, 0, 100, 100),
      capturedAtUtc: DateTime.utc(2026, 11, 13, 10, 0, 5),
      network: network,
    );

Future<void> _pumpReport(
  WidgetTester tester,
  BugWidgetSelection selection, {
  BugReportShare? share,
}) async {
  await tester.pumpWidget(
    MaterialApp(home: BugReportPage(selection: selection, share: share)),
  );
  await tester.pumpAndSettle();
}
