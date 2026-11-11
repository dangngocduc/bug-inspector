import 'package:bloc/bloc.dart';
import 'package:flutter_qa_inspector/flutter_qa_inspector.dart';
import 'package:flutter_qa_inspector_example/app.dart';
import 'package:flutter_test/flutter_test.dart';

/// Pumps until the inspect mode change is on screen.
Future<void> _pumpModeChange(WidgetTester tester) async {
  await tester.pump();
  await tester.pump();
  // The page button appears one frame after the borders.
  await tester.pump();
}

void main() {
  testWidgets('without QA the inspect action is hidden', (tester) async {
    await tester.pumpWidget(const ExampleApp(qaEnabled: false));

    expect(find.text('Inspect'), findsNothing);
    expect(find.byType(BugInspector), findsNothing);
    await tester.tap(find.text('Tăng (0)'));
    await tester.pump();
    expect(find.text('Tăng (1)'), findsOneWidget);
  });

  testWidgets('QA flow: inspect the counter button and open the report',
      (tester) async {
    final recorder = BugStateRecorder();
    final previousObserver = Bloc.observer;
    Bloc.observer = MultiBlocObserver(
      observers: [
        previousObserver,
        BugInspectorBlocObserver(recorder: recorder),
      ],
    );
    addTearDown(() => Bloc.observer = previousObserver);

    await tester.pumpWidget(
      ExampleApp(
        qaEnabled: true,
        recorder: recorder,
        captureScreenshots: false,
      ),
    );

    await tester.tap(find.text('Tăng (0)'));
    await tester.pump();
    await tester.tap(find.text('Tăng (1)'));
    await tester.pump();

    await tester.tap(find.text('Inspect'));
    await _pumpModeChange(tester);
    await tester.tapAt(tester.getCenter(find.text('Tăng (2)')));
    await tester.pumpAndSettle();

    // The selection tap does not press the button.
    expect(find.text('Tăng (2)'), findsOneWidget);
    expect(find.text('Báo lỗi'), findsOneWidget);
    expect(find.textContaining('"id": "counter.increment"'), findsOneWidget);
    expect(find.textContaining('"value": 2'), findsOneWidget);
    expect(find.textContaining('"kind": "change"'), findsOneWidget);
  });

  testWidgets('QA flow: select the whole catalog screen', (tester) async {
    await tester.pumpWidget(
      const ExampleApp(qaEnabled: true, captureScreenshots: false),
    );
    await tester.tap(find.text('Mở danh mục'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Inspect'));
    await _pumpModeChange(tester);
    expect(find.text('Select screen'), findsOneWidget);
    expect(find.text('Danh mục'), findsWidgets);

    await tester.tap(find.text('Select screen'));
    await tester.pumpAndSettle();

    expect(find.textContaining('"kind": "page"'), findsOneWidget);
    expect(find.textContaining('"id": "catalog"'), findsOneWidget);
    expect(find.textContaining('"name": "/catalog"'), findsOneWidget);
    expect(find.textContaining('"id": "catalog_bloc"'), findsOneWidget);
  });
}
