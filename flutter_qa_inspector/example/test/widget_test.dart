import 'dart:typed_data';

import 'package:bloc/bloc.dart';
import 'package:flutter/material.dart';
import 'package:flutter_qa_inspector/flutter_qa_inspector.dart';
import 'package:flutter_qa_inspector_example/app.dart';
import 'package:flutter_qa_inspector_example/bug_report_sheet.dart';
import 'package:flutter_test/flutter_test.dart';

/// Pumps until the inspect mode change is on screen.
Future<void> _pumpModeChange(WidgetTester tester) async {
  await tester.pump();
  await tester.pump();
  // The page button appears one frame after the borders.
  await tester.pump();
}

/// A valid 1x1 transparent PNG.
final Uint8List _onePixelPng = Uint8List.fromList(<int>[
  0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D, //
  0x49, 0x48, 0x44, 0x52, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
  0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4, 0x89, 0x00, 0x00, 0x00,
  0x0A, 0x49, 0x44, 0x41, 0x54, 0x78, 0x9C, 0x63, 0x00, 0x01, 0x00, 0x00,
  0x05, 0x00, 0x01, 0x0D, 0x0A, 0x2D, 0xB4, 0x00, 0x00, 0x00, 0x00, 0x49,
  0x45, 0x4E, 0x44, 0xAE, 0x42, 0x60, 0x82,
]);

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

    await tester.tap(find.byKey(BugInspector.launcherKey));
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

  testWidgets('QA flow: mark the screenshot with a rectangle',
      skip: _needsQaBuild, (tester) async {
    final screenshot = BugScreenshot(
      pngBytes: _onePixelPng,
      width: 800,
      height: 600,
      pixelRatio: 1,
      contentBounds: const Rect.fromLTWH(0, 0, 800, 600),
      capturedAtUtc: DateTime.utc(2026, 11, 12),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: BugReportSheet(
            selection: BugWidgetSelection(
              id: 'counter.increment',
              widgetType: 'FilledButton',
              bounds: const Rect.fromLTWH(100, 100, 200, 50),
              capturedAtUtc: DateTime.utc(2026, 11, 12),
            ),
            screenshot: screenshot,
          ),
        ),
      ),
    );

    expect(find.text('Chạm vào ảnh để đánh dấu vùng lỗi'), findsOneWidget);
    // Tapping the image opens the editor.
    await tester.tap(find.byType(BugScreenshotEditor));
    await tester.pumpAndSettle();
    expect(find.text('Xong'), findsOneWidget);

    final editor = tester.getRect(find.byType(BugScreenshotEditor));
    await tester.dragFrom(
      editor.topLeft + const Offset(20, 20),
      const Offset(120, 80),
    );
    await tester.pump();
    expect(find.byKey(BugScreenshotEditor.deleteButtonKey), findsOneWidget);

    await tester.tap(find.text('Xong'));
    await tester.pumpAndSettle();

    // Back on the form, the hint counts the rectangle.
    expect(
      find.text('Đã đánh dấu 1 vùng · Chạm vào ảnh để sửa'),
      findsOneWidget,
    );
  });
}
