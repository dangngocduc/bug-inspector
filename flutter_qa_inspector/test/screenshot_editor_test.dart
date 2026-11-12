import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_qa_inspector/flutter_qa_inspector.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/build_mode.dart';

/// A valid 1x1 transparent PNG. The editor sizes itself from
/// [BugScreenshot.width] and [BugScreenshot.height], not from the bytes.
final Uint8List _onePixelPng = Uint8List.fromList(<int>[
  0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D, //
  0x49, 0x48, 0x44, 0x52, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
  0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4, 0x89, 0x00, 0x00, 0x00,
  0x0A, 0x49, 0x44, 0x41, 0x54, 0x78, 0x9C, 0x63, 0x00, 0x01, 0x00, 0x00,
  0x05, 0x00, 0x01, 0x0D, 0x0A, 0x2D, 0xB4, 0x00, 0x00, 0x00, 0x00, 0x49,
  0x45, 0x4E, 0x44, 0xAE, 0x42, 0x60, 0x82,
]);

/// 200 x 100 image pixels, shown at 400 x 200 by [_pumpEditor]: one image
/// pixel is two logical pixels on screen.
BugScreenshot _screenshot({Uint8List? pngBytes}) => BugScreenshot(
      pngBytes: pngBytes ?? _onePixelPng,
      width: 200,
      height: 100,
      pixelRatio: 2,
      contentBounds: const Rect.fromLTWH(0, 0, 100, 50),
      capturedAtUtc: DateTime.utc(2026, 11, 12),
    );

BugScreenshotAnnotation _annotation(double l, double t, double r, double b) =>
    BugScreenshotAnnotation(Rect.fromLTRB(l, t, r, b));

Future<BugScreenshotAnnotationController> _pumpEditor(
  WidgetTester tester, {
  List<BugScreenshotAnnotation> annotations = const [],
  int? selected,
  bool readOnly = false,
  Rect? highlight,
}) async {
  final controller = BugScreenshotAnnotationController(annotations)
    ..select(selected);
  addTearDown(controller.dispose);
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Center(
          child: SizedBox(
            width: 400,
            height: 200,
            child: BugScreenshotEditor(
              screenshot: _screenshot(),
              controller: controller,
              readOnly: readOnly,
              highlight: highlight,
            ),
          ),
        ),
      ),
    ),
  );
  return controller;
}

/// A point on the editor, in logical pixels from its top left corner.
Offset _at(WidgetTester tester, double x, double y) =>
    tester.getTopLeft(find.byType(BugScreenshotEditor)) + Offset(x, y);

Future<void> _drag(WidgetTester tester, Offset from, Offset to) async {
  final gesture = await tester.startGesture(from);
  await gesture.moveTo(Offset.lerp(from, to, 0.5)!);
  await gesture.moveTo(to);
  await gesture.up();
  await tester.pump();
}

final Finder _deleteButton = find.byKey(BugScreenshotEditor.deleteButtonKey);

void main() {
  group('BugScreenshotAnnotation', () {
    test('describes its rectangle in image pixels', () {
      expect(_annotation(10, 20, 40, 60).toJson(), <String, Object?>{
        'left': 10.0,
        'top': 20.0,
        'width': 30.0,
        'height': 40.0,
        'coordinateUnit': 'image_pixels',
      });
      expect(_annotation(1, 2, 3, 4), _annotation(1, 2, 3, 4));
      expect(_annotation(1, 2, 3, 4), isNot(_annotation(1, 2, 3, 5)));
    });
  });

  group('BugScreenshotAnnotationController', () {
    test('adds, selects and removes, keeping the selection on its item', () {
      final controller = BugScreenshotAnnotationController();
      addTearDown(controller.dispose);
      var notifications = 0;
      controller.addListener(() => notifications++);

      controller.add(_annotation(0, 0, 10, 10));
      controller.add(_annotation(20, 20, 30, 30));
      controller.add(_annotation(40, 40, 50, 50), select: false);
      expect(controller.annotations, hasLength(3));
      expect(controller.selectedIndex, 1);
      expect(controller.selected, _annotation(20, 20, 30, 30));

      // Removing an item before the selected one keeps the same selection.
      controller.removeAt(0);
      expect(controller.selectedIndex, 0);
      expect(controller.selected, _annotation(20, 20, 30, 30));

      expect(controller.removeSelected(), isTrue);
      expect(controller.selectedIndex, isNull);
      expect(controller.annotations, <Object>[_annotation(40, 40, 50, 50)]);
      expect(controller.removeSelected(), isFalse);

      controller.select(0);
      controller.replaceAt(0, _annotation(1, 1, 9, 9));
      expect(controller.selected, _annotation(1, 1, 9, 9));
      expect(notifications, 7);

      // No change, no notification.
      controller
        ..replaceAt(0, _annotation(1, 1, 9, 9))
        ..select(0);
      expect(notifications, 7);

      expect(controller.toJson(), <Object?>[_annotation(1, 1, 9, 9).toJson()]);
      expect(() => controller.select(1), throwsRangeError);
      expect(
        () => controller.annotations.add(_annotation(0, 0, 1, 1)),
        throwsUnsupportedError,
      );

      controller.clear();
      expect(controller.annotations, isEmpty);
      expect(controller.selectedIndex, isNull);

      controller
        ..add(_annotation(0, 0, 1, 1))
        ..annotations = <BugScreenshotAnnotation>[_annotation(2, 2, 3, 3)];
      expect(controller.annotations, <Object>[_annotation(2, 2, 3, 3)]);
      expect(controller.selectedIndex, isNull);
    });
  });

  qaBuildOnly(() {
    group('BugScreenshotEditor', () {
      testWidgets('keeps the aspect ratio of the image', (tester) async {
        final controller = BugScreenshotAnnotationController();
        addTearDown(controller.dispose);
        await tester.pumpWidget(
          MaterialApp(
            home: Center(
              child: SizedBox(
                width: 400,
                height: 400,
                child: Center(
                  child: BugScreenshotEditor(
                    screenshot: _screenshot(),
                    controller: controller,
                  ),
                ),
              ),
            ),
          ),
        );
        expect(
          tester.getSize(find.byType(BugScreenshotEditor)),
          const Size(400, 200),
        );
      });

      testWidgets('a drag on the image draws a selected rectangle',
          (tester) async {
        final controller = await _pumpEditor(tester);

        await _drag(tester, _at(tester, 20, 20), _at(tester, 120, 80));

        expect(controller.annotations, <Object>[_annotation(10, 10, 60, 40)]);
        expect(controller.selectedIndex, 0);
        expect(_deleteButton, findsOneWidget);
        expect(
          find.byType(BugScreenshotEditor),
          paints
            // The selected rectangle is filled, then stroked.
            ..rect(
              rect: const Rect.fromLTRB(20, 20, 120, 80),
              color: BugScreenshotEditor.defaultColor.withAlpha(0x33),
            )
            ..rect(
              rect: const Rect.fromLTRB(20, 20, 120, 80),
              color: BugScreenshotEditor.defaultColor,
              style: PaintingStyle.stroke,
              strokeWidth: BugScreenshotEditor.defaultStrokeWidth,
            )
            ..circle(x: 20, y: 20),
        );
      });

      testWidgets('a drag in any direction draws, staying inside the image',
          (tester) async {
        final controller = await _pumpEditor(tester);

        await _drag(tester, _at(tester, 120, 80), _at(tester, -50, 500));

        expect(controller.annotations, <Object>[_annotation(0, 40, 60, 100)]);
      });

      testWidgets('a short drag draws the smallest rectangle', (tester) async {
        final controller = await _pumpEditor(tester);

        await _drag(tester, _at(tester, 20, 20), _at(tester, 30, 20));

        // minRectSize logical pixels are 8 image pixels.
        expect(controller.annotations, <Object>[_annotation(10, 10, 18, 18)]);
      });

      testWidgets('a tap draws nothing and unselects', (tester) async {
        final controller = await _pumpEditor(
          tester,
          annotations: [_annotation(10, 10, 50, 30)],
          selected: 0,
        );

        await tester.tapAt(_at(tester, 300, 150));
        await tester.pump();

        expect(controller.annotations, <Object>[_annotation(10, 10, 50, 30)]);
        expect(controller.selectedIndex, isNull);
        expect(_deleteButton, findsNothing);
      });

      testWidgets('a tap selects the smallest rectangle under the finger',
          (tester) async {
        final controller = await _pumpEditor(
          tester,
          annotations: [
            _annotation(50, 30, 70, 50),
            _annotation(0, 0, 200, 100),
          ],
        );

        await tester.tapAt(_at(tester, 120, 80));
        await tester.pump();
        expect(controller.selectedIndex, 0);

        await tester.tapAt(_at(tester, 20, 20));
        await tester.pump();
        expect(controller.selectedIndex, 1);
      });

      testWidgets('dragging a rectangle moves it inside the image',
          (tester) async {
        final controller = await _pumpEditor(
          tester,
          annotations: [_annotation(10, 10, 50, 30)],
        );

        // Not selected yet: the same drag selects and moves it.
        await _drag(tester, _at(tester, 60, 40), _at(tester, 100, 60));
        expect(controller.selectedIndex, 0);
        expect(controller.annotations, <Object>[_annotation(30, 20, 70, 40)]);

        await _drag(tester, _at(tester, 100, 60), _at(tester, 2000, 2000));
        expect(
            controller.annotations, <Object>[_annotation(160, 80, 200, 100)]);
      });

      testWidgets('dragging a corner resizes from the opposite corner',
          (tester) async {
        final controller = await _pumpEditor(
          tester,
          annotations: [_annotation(10, 10, 50, 30)],
          selected: 0,
        );

        await _drag(tester, _at(tester, 100, 60), _at(tester, 140, 80));
        expect(controller.annotations, <Object>[_annotation(10, 10, 70, 40)]);

        // Past the opposite corner, the rectangle flips.
        await _drag(tester, _at(tester, 20, 20), _at(tester, 220, 120));
        expect(controller.annotations, <Object>[_annotation(70, 40, 110, 60)]);

        // Onto the opposite corner, it keeps the smallest size.
        await _drag(tester, _at(tester, 220, 120), _at(tester, 140, 80));
        expect(controller.annotations, <Object>[_annotation(70, 40, 78, 48)]);
      });

      testWidgets('the corner handles only work on the selected rectangle',
          (tester) async {
        final controller = await _pumpEditor(
          tester,
          annotations: [_annotation(10, 10, 50, 30)],
        );

        // Where the bottom right handle would be, outside the rectangle:
        // without a selection there is no handle, so it draws.
        await _drag(tester, _at(tester, 115, 75), _at(tester, 155, 95));

        expect(controller.annotations, hasLength(2));
        expect(controller.annotations.first, _annotation(10, 10, 50, 30));
      });

      testWidgets('the delete button removes the selected rectangle',
          (tester) async {
        final controller = await _pumpEditor(
          tester,
          annotations: [
            _annotation(10, 10, 50, 30),
            _annotation(100, 50, 150, 90),
          ],
          selected: 1,
        );

        await tester.tap(_deleteButton);
        await tester.pump();

        expect(controller.annotations, <Object>[_annotation(10, 10, 50, 30)]);
        expect(controller.selectedIndex, isNull);
        expect(_deleteButton, findsNothing);
      });

      testWidgets('the delete button is a button for screen readers',
          (tester) async {
        final semantics = tester.ensureSemantics();
        await _pumpEditor(
          tester,
          annotations: [_annotation(10, 10, 50, 30)],
          selected: 0,
        );

        expect(
          tester.getSemantics(_deleteButton),
          isSemantics(
            label: BugScreenshotEditor.defaultDeleteButtonLabel,
            isButton: true,
            hasTapAction: true,
          ),
        );
        expect(
          tester.getSemantics(find.byType(BugScreenshotEditor)),
          isSemantics(
            label: BugScreenshotEditor.defaultSemanticLabel,
            isImage: true,
          ),
        );
        semantics.dispose();
      });

      testWidgets('readOnly shows the rectangles and takes no gesture',
          (tester) async {
        final controller = await _pumpEditor(
          tester,
          annotations: [_annotation(10, 10, 50, 30)],
          selected: 0,
          readOnly: true,
        );

        expect(_deleteButton, findsNothing);
        expect(
          find.byType(BugScreenshotEditor),
          paints
            ..rect(
              rect: const Rect.fromLTRB(20, 20, 100, 60),
              style: PaintingStyle.stroke,
            ),
        );
        expect(find.byType(BugScreenshotEditor), isNot(paints..circle()));

        await _drag(tester, _at(tester, 60, 40), _at(tester, 160, 140));
        await _drag(tester, _at(tester, 200, 100), _at(tester, 300, 150));
        await tester.tapAt(_at(tester, 300, 150));
        await tester.pump();

        expect(controller.annotations, <Object>[_annotation(10, 10, 50, 30)]);
        expect(controller.selectedIndex, 0);
      });

      testWidgets('outlines the highlight with a dashed line', (tester) async {
        await _pumpEditor(
          tester,
          // Global logical pixels: x2 to image pixels, x2 again on screen.
          highlight: const Rect.fromLTWH(5, 5, 20, 10),
        );

        expect(
          find.byType(BugScreenshotEditor),
          paints
            ..line(
              p1: const Offset(20, 20),
              p2: const Offset(26, 20),
              color: BugInspector.defaultBorderColor,
            ),
        );

        // Not something the tester can move.
        await tester.tapAt(_at(tester, 40, 30));
        await tester.pump();
        expect(_deleteButton, findsNothing);
      });

      testWidgets('drawing inside a list does not scroll it', (tester) async {
        final scroll = ScrollController();
        addTearDown(scroll.dispose);
        final controller = BugScreenshotAnnotationController();
        addTearDown(controller.dispose);
        await tester.pumpWidget(
          MaterialApp(
            home: ListView(
              controller: scroll,
              children: <Widget>[
                Center(
                  child: SizedBox(
                    width: 400,
                    height: 200,
                    child: BugScreenshotEditor(
                      screenshot: _screenshot(),
                      controller: controller,
                    ),
                  ),
                ),
                const SizedBox(key: ValueKey<String>('spacer'), height: 2000),
              ],
            ),
          ),
        );

        await _drag(tester, _at(tester, 20, 180), _at(tester, 120, 20));
        expect(scroll.offset, 0);
        expect(controller.annotations, <Object>[_annotation(10, 10, 60, 90)]);

        // Outside the editor, the list still scrolls.
        await tester.dragFrom(const Offset(400, 400), const Offset(0, -300));
        await tester.pump();
        expect(scroll.offset, greaterThan(0));
      });
    });

    group('toAnnotatedPng', () {
      testWidgets('draws the rectangles into the image', (tester) async {
        const red = Color(0xFFFF0000);
        final pixels = await tester.runAsync(() async {
          final screenshot = await _whiteScreenshot(40, 40);
          final png = await screenshot.toAnnotatedPng(
            <BugScreenshotAnnotation>[_annotation(10, 10, 30, 30)],
            color: red,
            strokeWidth: 2,
          );
          return _decode(png);
        });

        expect(pixels!.width, 40);
        expect(pixels.height, 40);
        expect(pixels.at(10, 20), red);
        expect(pixels.at(29, 20), red);
        expect(pixels.at(20, 10), red);
        expect(pixels.at(20, 20), const Color(0xFFFFFFFF));
        expect(pixels.at(0, 0), const Color(0xFFFFFFFF));
        expect(pixels.at(13, 20), const Color(0xFFFFFFFF));
      });

      testWidgets('scales the stroke with the pixel ratio', (tester) async {
        const red = Color(0xFFFF0000);
        final pixels = await tester.runAsync(() async {
          final screenshot = await _whiteScreenshot(40, 40, pixelRatio: 4);
          final png = await screenshot.toAnnotatedPng(
            <BugScreenshotAnnotation>[_annotation(10, 10, 30, 30)],
            color: red,
            strokeWidth: 2,
          );
          return _decode(png);
        });

        // 2 logical pixels are 8 image pixels, centered on the edge.
        expect(pixels!.at(6, 20), red);
        expect(pixels.at(13, 20), red);
        expect(pixels.at(15, 20), const Color(0xFFFFFFFF));
      });

      test('without annotations returns the original bytes', () async {
        final screenshot = _screenshot();
        expect(
          await screenshot.toAnnotatedPng(const <BugScreenshotAnnotation>[]),
          same(screenshot.pngBytes),
        );
      });
    });
  });

  productionBuildOnly(() {
    testWidgets('the editor builds nothing and the image is left as is',
        (tester) async {
      final controller = BugScreenshotAnnotationController(
        <BugScreenshotAnnotation>[_annotation(10, 10, 50, 30)],
      );
      addTearDown(controller.dispose);
      final screenshot = _screenshot();
      await tester.pumpWidget(
        Center(
          child: BugScreenshotEditor(
            screenshot: screenshot,
            controller: controller,
          ),
        ),
      );

      expect(tester.getSize(find.byType(BugScreenshotEditor)), Size.zero);
      expect(find.byType(Image), findsNothing);
      expect(
        await screenshot.toAnnotatedPng(controller.annotations),
        same(screenshot.pngBytes),
      );
    });
  });
}

/// A white screenshot of [width] x [height] image pixels.
Future<BugScreenshot> _whiteScreenshot(
  int width,
  int height, {
  double pixelRatio = 1,
}) async {
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
    pixelRatio: pixelRatio,
    contentBounds: Rect.fromLTWH(
      0,
      0,
      width / pixelRatio,
      height / pixelRatio,
    ),
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
