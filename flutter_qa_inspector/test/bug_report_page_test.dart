import 'dart:convert';
import 'dart:ui' as ui;

import 'package:archive/archive.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_qa_inspector/flutter_qa_inspector.dart';
import 'package:flutter_test/flutter_test.dart';

/// A valid 1x1 transparent PNG.
final Uint8List _onePixelPng = Uint8List.fromList(<int>[
  0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D, //
  0x49, 0x48, 0x44, 0x52, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
  0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4, 0x89, 0x00, 0x00, 0x00,
  0x0A, 0x49, 0x44, 0x41, 0x54, 0x78, 0x9C, 0x63, 0x00, 0x01, 0x00, 0x00,
  0x05, 0x00, 0x01, 0x0D, 0x0A, 0x2D, 0xB4, 0x00, 0x00, 0x00, 0x00, 0x49,
  0x45, 0x4E, 0x44, 0xAE, 0x42, 0x60, 0x82,
]);

/// The editor needs `flutter test --dart-define=FLUTTER_QA_INSPECTOR=true`:
/// without it, [BugScreenshotEditor] builds an empty box.
const _needsQaBuild = !BugInspector.enabledFromEnvironment;

const _en = BugReportStrings.en;

void main() {
  testWidgets('QA flow: mark the screenshot with a rectangle',
      skip: _needsQaBuild, (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: BugReportPage(selection: _selection(), screenshot: _screenshot()),
      ),
    );

    expect(find.text(_en.annotateHint), findsOneWidget);
    // Tapping the image opens the editor.
    await tester.tap(find.byType(BugScreenshotEditor));
    await tester.pumpAndSettle();
    expect(find.text(_en.annotateDone), findsOneWidget);

    final editor = tester.getRect(find.byType(BugScreenshotEditor));
    await tester.dragFrom(
      editor.topLeft + const Offset(20, 20),
      const Offset(120, 80),
    );
    await tester.pump();
    expect(find.byKey(BugScreenshotEditor.deleteButtonKey), findsOneWidget);

    await tester.tap(find.text(_en.annotateDone));
    await tester.pumpAndSettle();

    // Back on the form, the hint counts the rectangle.
    expect(
      find.text(_en.annotatedCount(1)),
      findsOneWidget,
    );
  });

  testWidgets('QA flow: the editor is a page of the report navigator',
      skip: _needsQaBuild, (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: TextButton(
                onPressed: () => BugReportPage.open(
                  context,
                  selection: _selection(),
                  screenshot: _screenshot(),
                ),
                child: const Text('Open report'),
              ),
            ),
          ),
        ),
      ),
    );
    final appNavigator = tester.state<NavigatorState>(find.byType(Navigator));

    await tester.tap(find.text('Open report'));
    await tester.pumpAndSettle();
    expect(find.text(_en.title), findsOneWidget);
    expect(find.text('Open report'), findsNothing);

    await tester.tap(find.byType(BugScreenshotEditor));
    await tester.pumpAndSettle();
    expect(find.text(_en.annotateDone), findsOneWidget);
    // The editor is pushed in the report's own navigator, not the app's.
    final editorNavigator =
        Navigator.of(tester.element(find.text(_en.annotateDone)));
    expect(editorNavigator, isNot(same(appNavigator)));
    expect(
      ModalRoute.of(tester.element(find.text(_en.title, skipOffstage: false)))
          ?.navigator,
      same(editorNavigator),
    );

    // The system back closes the editor first and keeps the report open.
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text(_en.annotateDone), findsNothing);
    expect(find.text(_en.title), findsOneWidget);

    // On the form, the system back closes the whole report.
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.byType(BugReportPage), findsNothing);
    expect(find.text('Open report'), findsOneWidget);
  });

  testWidgets('sending zips the report and shares the image, zip and text',
      (tester) async {
    final shared = <ShareParams>[];
    await _openReport(tester, (params) async {
      shared.add(params);
      return const ShareResult('done', ShareResultStatus.success);
    });

    await tester.enterText(
      find.byType(CupertinoTextField),
      'Nút Tăng không đổi số',
    );
    await _tapSend(tester);

    expect(shared, hasLength(1));
    final params = shared.single;
    expect(params.text, 'Nút Tăng không đổi số');
    // iPad anchors the share sheet to the send button.
    expect(params.sharePositionOrigin, isNotNull);
    const name = 'bug_counter.increment_20261112_000000';
    expect(params.fileNameOverrides, ['$name.png', '$name.zip']);
    final png = await params.files![0].readAsBytes();

    final zip = ZipDecoder().decodeBytes(await params.files![1].readAsBytes());
    String text(String name) => utf8.decode(zip.findFile(name)!.readBytes()!);
    // The same image as the one shared, with the outlines drawn on it, see
    // 'the shared image has the highlight and the rectangles, like the form'.
    expect(zip.findFile('screenshot.png')!.readBytes(), png);
    expect(png.sublist(0, 8), _onePixelPng.sublist(0, 8), reason: 'a PNG');
    expect(text('description.txt'), 'Nút Tăng không đổi số');
    final json = jsonDecode(text('inspector.json')) as Map<String, Object?>;
    expect(json['inspector'], containsPair('id', 'counter.increment'));
    expect(json['screenshot'], containsPair('annotations', isEmpty));
    expect(json, isNot(contains('description')));

    // A finished share closes the report.
    expect(find.byType(BugReportPage), findsNothing);
    expect(find.text('Open report'), findsOneWidget);
  });

  testWidgets(
      'the shared image has the highlight and the rectangles, like the form',
      skip: _needsQaBuild, (tester) async {
    final screenshot =
        (await tester.runAsync(() => _whiteScreenshot(400, 300)))!;
    final shared = <ShareParams>[];
    await _openReport(
      tester,
      (params) async {
        shared.add(params);
        return const ShareResult('done', ShareResultStatus.success);
      },
      screenshot: screenshot,
    );

    // Draw a rectangle in the editor.
    await tester.tap(find.byType(BugScreenshotEditor));
    await tester.pumpAndSettle();
    final editor = tester.getRect(find.byType(BugScreenshotEditor));
    await tester.dragFrom(
      editor.topLeft + const Offset(20, 20),
      const Offset(120, 80),
    );
    await tester.pump();
    await tester.tap(find.text(_en.annotateDone));
    await tester.pumpAndSettle();

    await _tapSend(tester);
    expect(shared, hasLength(1));

    final files = shared.single.files!;
    final png = await files[0].readAsBytes();
    final zip = ZipDecoder().decodeBytes(await files[1].readAsBytes());
    // The zip holds the same image.
    expect(zip.findFile('screenshot.png')!.readBytes(), png);
    final json = jsonDecode(
      utf8.decode(zip.findFile('inspector.json')!.readBytes()!),
    ) as Map<String, Object?>;
    final annotations = (json['screenshot']! as Map)['annotations']! as List;
    expect(annotations, hasLength(1));
    final rect = annotations.single as Map;

    final pixels = (await tester.runAsync(() => _decode(png)))!;
    // The selected widget, 100,100 200x50, outlined with dashes.
    expect(pixels.at(102, 100), BugInspector.defaultBorderColor);
    expect(pixels.at(108, 100), const Color(0xFFFFFFFF));
    // The tester's rectangle.
    final left = (rect['left']! as num).floor();
    final middle =
        ((rect['top']! as num) + (rect['height']! as num) / 2).floor();
    expect(pixels.at(left, middle), BugScreenshotEditor.defaultColor);
    expect(pixels.at(left + 10, middle), const Color(0xFFFFFFFF));
  });

  testWidgets('dismissing the share sheet keeps the report', (tester) async {
    var shares = 0;
    await _openReport(tester, (params) async {
      shares++;
      return const ShareResult('', ShareResultStatus.dismissed);
    });

    await _tapSend(tester);
    expect(shares, 1);
    expect(find.byType(BugReportPage), findsOneWidget);

    // The tester can share again.
    await _tapSend(tester);
    expect(shares, 2);
  });

  testWidgets('a failed share shows an error and keeps the report',
      (tester) async {
    await _openReport(tester, (params) async {
      throw StateError('no share sheet');
    });

    await _tapSend(tester);

    expect(find.byType(CupertinoAlertDialog), findsOneWidget);
    expect(find.text(_en.shareFailed), findsOneWidget);
    expect(find.text('Bad state: no share sheet'), findsOneWidget);
    expect(find.byType(BugReportPage), findsOneWidget);

    await tester.tap(find.text(_en.ok));
    await tester.pumpAndSettle();
    expect(find.byType(CupertinoAlertDialog), findsNothing);
    expect(find.byType(BugReportPage), findsOneWidget);
  });

  testWidgets('cancelling a written report asks before discarding it',
      (tester) async {
    await _openReport(tester, _neverShare);
    await tester.enterText(find.byType(CupertinoTextField), 'Sai nhãn');
    await tester.pump();

    await tester.tap(find.text(_en.cancel));
    await tester.pumpAndSettle();
    expect(find.text(_en.discardTitle), findsOneWidget);

    // Keep editing: the report and the description stay.
    await tester.tap(find.text(_en.keepEditing));
    await tester.pumpAndSettle();
    expect(find.text(_en.discardTitle), findsNothing);
    expect(find.text('Sai nhãn'), findsOneWidget);

    // The system back asks too.
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text(_en.discardTitle), findsOneWidget);

    await tester.tap(find.text(_en.discardConfirm));
    await tester.pumpAndSettle();
    expect(find.byType(BugReportPage), findsNothing);
    expect(find.text('Open report'), findsOneWidget);
  });

  testWidgets('the copy button copies the report JSON', (tester) async {
    final copied = <String>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          copied.add((call.arguments as Map)['text'] as String);
        }
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, null),
    );
    await _openReport(tester, _neverShare);
    await tester.enterText(find.byType(CupertinoTextField), 'Sai nhãn');

    // The button is in the header of the payload, below the screenshot.
    await tester.scrollUntilVisible(
      find.text(_en.copyJson),
      200,
      scrollable: find
          .descendant(
            of: find.byType(ListView),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text(_en.copyJson));
    await tester.pump();

    expect(copied, hasLength(1));
    final json = jsonDecode(copied.single) as Map<String, Object?>;
    expect(json['description'], 'Sai nhãn');
    expect(json['inspector'], containsPair('id', 'counter.increment'));
    // The button shows the copy for a moment.
    expect(find.text(_en.copied), findsOneWidget);
    await tester.pump(const Duration(seconds: 2));
    expect(find.text(_en.copyJson), findsOneWidget);
  });

  testWidgets('QA flow: the editor clears every rectangle after asking',
      skip: _needsQaBuild, (tester) async {
    await _openReport(tester, _neverShare);
    await tester.tap(find.byType(BugScreenshotEditor));
    await tester.pumpAndSettle();

    // Nothing to clear yet.
    CupertinoButton clearButton() => tester.widget<CupertinoButton>(
          find.ancestor(
            of: find.text(_en.annotateClearAll),
            matching: find.byType(CupertinoButton),
          ),
        );
    expect(clearButton().onPressed, isNull);

    final editor = tester.getRect(find.byType(BugScreenshotEditor));
    await tester.dragFrom(
      editor.topLeft + const Offset(20, 20),
      const Offset(120, 80),
    );
    await tester.pump();
    expect(clearButton().onPressed, isNotNull);

    await tester.tap(find.text(_en.annotateClearAll));
    await tester.pumpAndSettle();
    await tester.tap(find.text(_en.annotateClearAllConfirm));
    await tester.pumpAndSettle();
    expect(find.byKey(BugScreenshotEditor.deleteButtonKey), findsNothing);
    expect(clearButton().onPressed, isNull);

    await tester.tap(find.text(_en.annotateDone));
    await tester.pumpAndSettle();
    expect(find.text(_en.annotateHint), findsOneWidget);
    // Nothing left to lose: cancel closes at once.
    await tester.tap(find.text(_en.cancel));
    await tester.pumpAndSettle();
    expect(find.byType(BugReportPage), findsNothing);
  });

  testWidgets('the texts and the share subject come from the strings',
      (tester) async {
    final shared = <ShareParams>[];
    await _openReport(
      tester,
      (params) async {
        shared.add(params);
        return const ShareResult('done', ShareResultStatus.success);
      },
      strings: BugReportStrings.vi.copyWith(title: 'Báo lỗi QA'),
    );

    expect(find.text('Báo lỗi QA'), findsOneWidget);
    expect(find.text(BugReportStrings.vi.cancel), findsOneWidget);
    await tester.tap(find.text(BugReportStrings.vi.send));
    await _settleSend(tester);

    expect(shared.single.subject,
        'Báo lỗi: bug_counter.increment_20261112_000000');
  });

  testWidgets('without strings the report follows the locale', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('vi'),
        supportedLocales: const [Locale('vi')],
        localizationsDelegates: const [
          _EnglishFor<MaterialLocalizations>(DefaultMaterialLocalizations.load),
          _EnglishFor<CupertinoLocalizations>(
            DefaultCupertinoLocalizations.load,
          ),
          DefaultWidgetsLocalizations.delegate,
        ],
        home: BugReportPage(selection: _selection()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text(BugReportStrings.vi.title), findsOneWidget);
    expect(find.text(BugReportStrings.vi.send), findsOneWidget);
  });
}

/// The English texts of [T] for any locale, so the app can use Vietnamese
/// without flutter_localizations.
class _EnglishFor<T> extends LocalizationsDelegate<T> {
  const _EnglishFor(this._load);

  final Future<T> Function(Locale locale) _load;

  @override
  bool isSupported(Locale locale) => true;

  @override
  Future<T> load(Locale locale) => _load(locale);

  @override
  bool shouldReload(_EnglishFor<T> old) => false;
}

/// A share that never runs, for the tests that do not send.
Future<ShareResult> _neverShare(ShareParams params) =>
    throw StateError('not shared');

/// Pumps a page that opens the report with [share] in place of the share
/// sheet, then opens it.
Future<void> _openReport(
  WidgetTester tester,
  BugReportShare share, {
  BugScreenshot? screenshot,
  BugReportStrings? strings,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: TextButton(
              onPressed: () => BugReportPage.open(
                context,
                selection: _selection(),
                screenshot: screenshot ?? _screenshot(),
                strings: strings,
                share: share,
              ),
              child: const Text('Open report'),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('Open report'));
  await tester.pumpAndSettle();
}

/// Taps the send button of the navigation bar and waits until the report is
/// shared.
Future<void> _tapSend(WidgetTester tester) async {
  await tester.tap(find.text(_en.send));
  await _settleSend(tester);
}

/// Waits until a tapped send button has shared the report.
Future<void> _settleSend(WidgetTester tester) async {
  await tester.pump();
  // The button is a spinner while the outlines are drawn on the image, which
  // runs in the engine, outside the fake clock of the test.
  final spinner = find.byType(CupertinoActivityIndicator);
  for (var i = 0; i < 100 && spinner.evaluate().isNotEmpty; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 10)),
    );
    await tester.pump();
  }
  await tester.pumpAndSettle();
}

BugWidgetSelection _selection() => BugWidgetSelection(
      id: 'counter.increment',
      widgetType: 'FilledButton',
      bounds: const Rect.fromLTWH(100, 100, 200, 50),
      capturedAtUtc: DateTime.utc(2026, 11, 12),
    );

BugScreenshot _screenshot() => BugScreenshot(
      pngBytes: _onePixelPng,
      width: 800,
      height: 600,
      pixelRatio: 1,
      contentBounds: const Rect.fromLTWH(0, 0, 800, 600),
      capturedAtUtc: DateTime.utc(2026, 11, 12),
    );

/// A white screenshot of [width] x [height] image pixels, at a pixel ratio of
/// 1 from the top left of the screen.
Future<BugScreenshot> _whiteScreenshot(int width, int height) async {
  final recorder = ui.PictureRecorder();
  Canvas(recorder).drawRect(
    Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble()),
    Paint()..color = const Color(0xFFFFFFFF),
  );
  final picture = recorder.endRecording();
  final image = await picture.toImage(width, height);
  picture.dispose();
  final data = await image.toByteData(format: ui.ImageByteFormat.png);
  image.dispose();
  return BugScreenshot(
    pngBytes: data!.buffer.asUint8List(),
    width: width,
    height: height,
    pixelRatio: 1,
    contentBounds: Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble()),
    capturedAtUtc: DateTime.utc(2026, 11, 12),
  );
}

Future<_Pixels> _decode(Uint8List png) async {
  final codec = await ui.instantiateImageCodec(png);
  final image = (await codec.getNextFrame()).image;
  codec.dispose();
  final data = await image.toByteData();
  final pixels = _Pixels(image.width, image.height, data!);
  image.dispose();
  return pixels;
}

/// The RGBA pixels of a decoded image.
class _Pixels {
  _Pixels(this.width, this.height, this._data);

  final int width;
  final int height;
  final ByteData _data;

  Color at(int x, int y) {
    final rgba = _data.getUint32((y * width + x) * 4);
    return Color(((rgba & 0xFF) << 24) | (rgba >> 8));
  }
}
