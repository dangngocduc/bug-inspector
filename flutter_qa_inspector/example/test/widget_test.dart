import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_qa_inspector/flutter_qa_inspector.dart';
import 'package:flutter_qa_inspector_example/app.dart';
import 'package:flutter_test/flutter_test.dart';

// The report form itself is tested in the package, see
// `test/bug_report_page_test.dart`.

/// Pumps until the inspect mode change is on screen.
Future<void> _pumpModeChange(WidgetTester tester) async {
  await tester.pump();
  await tester.pump();
  // The page button appears one frame after the borders.
  await tester.pump();
}

/// The QA flows need `flutter test --dart-define=FLUTTER_QA_INSPECTOR=true`.
const _needsQaBuild = !BugInspector.enabledFromEnvironment;

void main() {
  testWidgets(
      'a production build has no inspector, even when the app enables it',
      skip: BugInspector.enabledFromEnvironment, (tester) async {
    await tester.pumpWidget(const ExampleApp(qaEnabled: true));

    expect(find.byKey(BugInspector.launcherKey), findsNothing);
    final context = tester.element(find.text('Counter'));
    expect(BugInspector.maybeModeCubitOf(context), isNull);
    await tester.tap(find.text('Tăng (0)'));
    await tester.pump();
    expect(find.text('Tăng (1)'), findsOneWidget);
  });

  testWidgets('without QA there is no floating bug button', (tester) async {
    await tester.pumpWidget(const ExampleApp(qaEnabled: false));

    expect(find.byKey(BugInspector.launcherKey), findsNothing);
    // The host is built but disabled: nothing below it sees an inspector.
    final context = tester.element(find.text('Counter'));
    expect(BugInspector.maybeModeCubitOf(context), isNull);
    await tester.tap(find.text('Tăng (0)'));
    await tester.pump();
    expect(find.text('Tăng (1)'), findsOneWidget);
  });

  testWidgets('QA flow: inspect the counter button and open the report',
      skip: _needsQaBuild, (tester) async {
    final previousObserver = Bloc.observer;
    // What main.dart does.
    FlutterQaInspector.install();
    addTearDown(FlutterQaInspector.debugReset);
    expect(Bloc.observer, isNot(same(previousObserver)));

    await tester.pumpWidget(
      const ExampleApp(qaEnabled: true, captureScreenshots: false),
    );

    await tester.tap(find.text('Tăng (0)'));
    await tester.pump();
    await tester.tap(find.text('Tăng (1)'));
    await tester.pump();

    await tester.tap(find.byKey(BugInspector.launcherKey));
    await _pumpModeChange(tester);
    await tester.tapAt(tester.getCenter(find.text('Tăng (2)')));
    await tester.pumpAndSettle();

    // The report is a page above the counter, which is now offstage. The
    // selection tap does not press the button.
    expect(find.byType(BugReportPage), findsOneWidget);
    expect(find.text('Tăng (2)', skipOffstage: false), findsOneWidget);
    expect(find.text(BugReportStrings.en.title), findsOneWidget);
    // The floating bug button does not cover the report.
    expect(find.byKey(BugInspector.launcherKey), findsNothing);
    expect(find.textContaining('"id": "counter.increment"'), findsOneWidget);
    expect(find.textContaining('"value": 2'), findsOneWidget);
    // The timeline comes from the recorder that install set up.
    expect(find.textContaining('"kind": "change"'), findsOneWidget);

    // The cancel button closes the whole report, at once when nothing was
    // written or drawn.
    await tester.tap(find.text(BugReportStrings.en.cancel));
    await tester.pumpAndSettle();
    expect(find.byType(BugReportPage), findsNothing);
    expect(find.text('Tăng (2)'), findsOneWidget);
    // Back on the app, the button is back.
    expect(find.byKey(BugInspector.launcherKey), findsOneWidget);
  });

  testWidgets('QA flow: select the whole catalog screen', skip: _needsQaBuild,
      (tester) async {
    await tester.pumpWidget(
      const ExampleApp(qaEnabled: true, captureScreenshots: false),
    );
    await tester.tap(find.text('Mở danh mục'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '2');
    await tester.pump();
    expect(find.text('Sản phẩm 1'), findsNothing);

    await tester.tap(find.byKey(BugInspector.launcherKey));
    await _pumpModeChange(tester);
    expect(find.text('Select screen'), findsOneWidget);
    expect(find.text('Danh mục'), findsWidgets);

    await tester.tap(find.text('Select screen'));
    await tester.pumpAndSettle();

    expect(find.textContaining('"kind": "page"'), findsOneWidget);
    expect(find.textContaining('"id": "catalog"'), findsOneWidget);
    expect(find.textContaining('"name": "/catalog"'), findsOneWidget);
    expect(find.textContaining('"id": "catalog_bloc"'), findsOneWidget);
    // The search query lives in the State of the screen.
    expect(find.textContaining('"type": "_CatalogViewState"'), findsOneWidget);
    expect(find.textContaining('"query": "2"'), findsOneWidget);
  });
}
