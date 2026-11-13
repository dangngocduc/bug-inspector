import 'package:flutter/material.dart';
import 'package:flutter_qa_inspector/flutter_qa_inspector.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/build_mode.dart';
import 'support/test_host.dart';

const _en = BugReportStrings.en;

final Finder _networkButton = find.byKey(BugInspector.networkButtonKey);

void main() {
  testWidgets('the history lists the calls as they happen and clears them',
      (tester) async {
    final recorder = BugNetworkRecorder();
    await tester.pumpWidget(
      MaterialApp(home: BugNetworkHistoryPage(recorder: recorder)),
    );
    expect(find.text(_en.networkHistoryTitle), findsOneWidget);
    expect(find.text(_en.networkHistoryEmpty), findsOneWidget);

    recorder.add(_record('000001', statusCode: 200));
    await tester.pump();
    expect(find.text('GET /calls/000001'), findsOneWidget);
    expect(find.text(_en.networkCount(1)), findsOneWidget);

    // A call that ends updates its row.
    recorder.add(_record('000002'));
    await tester.pump();
    expect(find.text(_en.networkPending), findsOneWidget);
    recorder.add(_record('000002', statusCode: 500));
    await tester.pump();
    expect(find.text(_en.networkPending), findsNothing);
    expect(find.text('500'), findsOneWidget);

    // A call opens with the history on its back button.
    await tester.tap(find.text('GET /calls/000002'));
    await tester.pumpAndSettle();
    expect(find.text('GET 500'), findsOneWidget);
    await tester.tap(find.text(_en.networkHistoryTitle));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(BugNetworkHistoryPage.clearButtonKey));
    await tester.pump();
    expect(recorder.length, 0);
    expect(find.text(_en.networkHistoryEmpty), findsOneWidget);
  });

  test('the subtitle of the network button counts the failed calls', () {
    expect(_en.networkButtonSubtitle(0, 0), 'No API calls yet');
    expect(_en.networkButtonSubtitle(1, 0), '1 API call');
    expect(_en.networkButtonSubtitle(3, 2), '3 API calls · 2 failed');
    expect(
      BugReportStrings.vi.networkButtonSubtitle(3, 1),
      '3 API call · 1 lỗi',
    );
  });

  qaBuildOnly(() {
    testWidgets('without a network recorder the toolbar has no network button',
        (tester) async {
      await pumpHost(tester, home: const Scaffold(body: SizedBox()));
      await enable(tester);

      expect(exitButton, findsOneWidget);
      expect(_networkButton, findsNothing);
    });

    testWidgets('Inspect network leaves the mode and opens the history',
        (tester) async {
      final recorder = BugNetworkRecorder()
        ..add(_record('000001', statusCode: 200))
        ..add(_record('000002', statusCode: 404));
      final selections = await pumpHost(
        tester,
        networkRecorder: recorder,
        home: const BugInspectablePage(
          id: 'home',
          child: Scaffold(body: SizedBox()),
        ),
      );
      await enable(tester);

      // Below the page button, with a count that follows the calls.
      expect(pageButton, findsOneWidget);
      expect(
        tester.getTopLeft(_networkButton).dy,
        greaterThan(tester.getTopLeft(pageButton).dy),
      );
      expect(find.text(_en.networkButtonLabel), findsOneWidget);
      expect(find.text(_en.networkButtonSubtitle(2, 1)), findsOneWidget);
      recorder.add(_record('000003', statusCode: 200));
      await tester.pump();
      expect(find.text(_en.networkButtonSubtitle(3, 1)), findsOneWidget);

      final mode = modeOf(tester);
      await tester.tap(_networkButton);
      await tester.pumpAndSettle();

      expect(mode.isSelecting, isFalse);
      expect(selections, isEmpty);
      expect(find.byType(BugNetworkHistoryPage), findsOneWidget);
      expect(
        ModalRoute.of(tester.element(find.byType(BugNetworkHistoryPage)))
            ?.settings
            .name,
        BugNetworkHistoryPage.routeName,
      );
      expect(find.text('GET /calls/000003'), findsOneWidget);
      // The bug button stays hidden while the history is open.
      expect(launcher, findsNothing);

      await tester.tap(find.byKey(BugNetworkHistoryPage.closeButtonKey));
      await tester.pumpAndSettle();
      expect(find.byType(BugNetworkHistoryPage), findsNothing);
      expect(launcher, findsOneWidget);
    });

    testWidgets('the facade gives the toolbar its strings and recorder',
        (tester) async {
      FlutterQaInspector.install();
      addTearDown(FlutterQaInspector.debugReset);
      await tester.pumpWidget(
        MaterialApp(
          builder: (context, child) => FlutterQaInspector.wrap(
            captureScreenshot: false,
            strings: (_) => BugReportStrings.vi,
            child: child!,
          ),
          home: const Scaffold(body: SizedBox()),
        ),
      );
      await enable(tester);

      expect(find.text(BugReportStrings.vi.networkButtonLabel), findsOneWidget);
      expect(find.text('Chưa có API call'), findsOneWidget);
      await tester.tap(_networkButton);
      await tester.pumpAndSettle();
      expect(
        find.text(BugReportStrings.vi.networkHistoryTitle),
        findsOneWidget,
      );
    });
  });
}

BugNetworkRecord _record(String id, {int? statusCode}) => BugNetworkRecord(
      id: id,
      status: statusCode == null
          ? BugNetworkRecordStatus.pending
          : statusCode >= 400
              ? BugNetworkRecordStatus.failed
              : BugNetworkRecordStatus.completed,
      method: 'GET',
      url: 'https://api.example.com/calls/$id',
      startedAtUtc: DateTime.utc(2026, 11, 13, 10),
      endedAtUtc:
          statusCode == null ? null : DateTime.utc(2026, 11, 13, 10, 0, 1),
      statusCode: statusCode,
    );
