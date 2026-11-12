import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_qa_inspector/flutter_qa_inspector.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/build_mode.dart';
import 'support/test_host.dart';

const Color _black = Color(0xFF000000);
const Color _white = Color(0xFFFFFFFF);
const Color _red = Color(0xFFFF0000);

/// Makes the top [top] logical pixels of the test view its safe area.
void _setSafeTop(WidgetTester tester, double top) {
  tester.view.padding =
      FakeViewPadding(top: top * tester.view.devicePixelRatio);
  addTearDown(tester.view.resetPadding);
}

/// Pumps [home] in a host and captures it.
Future<BugScreenshot> _capture(
  WidgetTester tester, {
  Color color = _white,
  bool statusBar = true,
}) async {
  late BuildContext context;
  await pumpHost(
    tester,
    home: Builder(
      builder: (c) {
        context = c;
        return ColoredBox(color: color);
      },
    ),
  );
  final screenshot = await tester.runAsync(
    () => BugInspector.captureScreenshot(
      context,
      pixelRatio: 1,
      waitForNextFrame: false,
      statusBar: statusBar,
    ),
  );
  return screenshot!;
}

/// The local time of [screenshot] as a 12-hour status bar clock.
String _clockOf(BugScreenshot screenshot) {
  final local = screenshot.capturedAtUtc.toLocal();
  final hour = local.hour % 12 == 0 ? 12 : local.hour % 12;
  return '$hour:${local.minute.toString().padLeft(2, '0')}';
}

void main() => qaBuildOnly(() {
      group('BugStatusBarStyle.of', () {
        test('is Pixel 8 on Android, Dynamic Island on iOS', () {
          expect(BugStatusBarStyle.of(TargetPlatform.android),
              BugStatusBarStyle.android);
          expect(
              BugStatusBarStyle.of(TargetPlatform.iOS), BugStatusBarStyle.iOS);
          for (final platform in <TargetPlatform>[
            TargetPlatform.fuchsia,
            TargetPlatform.linux,
            TargetPlatform.macOS,
            TargetPlatform.windows,
          ]) {
            expect(BugStatusBarStyle.of(platform), isNull, reason: '$platform');
          }
        });
      });

      group('BugStatusBar', () {
        test('describes its style and height', () {
          const bar = BugStatusBar(style: BugStatusBarStyle.iOS, height: 59);
          expect(bar.toJson(), <String, Object?>{
            'style': 'iOS',
            'height': 59.0,
            'coordinateUnit': 'logical_pixels',
          });
          expect(bar.time, BugStatusBar.defaultTime);
          expect(bar.foregroundColor, BugStatusBar.defaultForegroundColor);
          expect(
            bar,
            const BugStatusBar(style: BugStatusBarStyle.iOS, height: 59),
          );
          expect(
            bar,
            isNot(const BugStatusBar(style: BugStatusBarStyle.iOS, height: 47)),
          );
          expect(
            bar,
            isNot(const BugStatusBar(
              style: BugStatusBarStyle.iOS,
              height: 59,
              foregroundColor: _white,
            )),
          );
        });
      });

      group('captureScreenshot', () {
        testWidgets('adds a Dynamic Island bar over the safe area on iOS',
            (tester) async {
          _setSafeTop(tester, 59);
          final screenshot = await _capture(tester);

          final bar = screenshot.statusBar;
          expect(bar, isNotNull);
          expect(bar!.style, BugStatusBarStyle.iOS);
          expect(bar.height, 59);
          expect(bar.time, _clockOf(screenshot));
          expect(screenshot.toJson()['statusBar'], bar.toJson());
          // The bar is drawn, not captured.
          expect(screenshot.height, 600);
        }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

        testWidgets('adds a Pixel 8 bar over the safe area on Android',
            (tester) async {
          _setSafeTop(tester, 24);
          final screenshot = await _capture(tester);

          expect(screenshot.statusBar?.style, BugStatusBarStyle.android);
          expect(screenshot.statusBar?.height, 24);
        }, variant: TargetPlatformVariant.only(TargetPlatform.android));

        testWidgets('picks black icons on a light app, white on a dark one',
            (tester) async {
          _setSafeTop(tester, 24);
          final light = await _capture(tester, color: const Color(0xFFF3F1FA));
          final dark = await _capture(tester, color: const Color(0xFF3F51B5));

          expect(light.statusBar?.foregroundColor, _black);
          expect(dark.statusBar?.foregroundColor, _white);
        });

        testWidgets('shows a 24-hour clock when the device uses one',
            (tester) async {
          tester.platformDispatcher.alwaysUse24HourFormatTestValue = true;
          addTearDown(tester.platformDispatcher.clearAlwaysUse24HourTestValue);
          // The value above does not notify the MediaQuery: the padding
          // change does.
          _setSafeTop(tester, 24);
          final screenshot = await _capture(tester);

          final local = screenshot.capturedAtUtc.toLocal();
          String two(int value) => value.toString().padLeft(2, '0');
          expect(
            screenshot.statusBar?.time,
            '${two(local.hour)}:${two(local.minute)}',
          );
        });

        testWidgets('adds no bar without a top safe area', (tester) async {
          final screenshot = await _capture(tester);
          expect(screenshot.statusBar, isNull);
          expect(screenshot.toJson().containsKey('statusBar'), isFalse);
        });

        testWidgets('adds no bar when statusBar is false', (tester) async {
          _setSafeTop(tester, 24);
          final screenshot = await _capture(tester, statusBar: false);
          expect(screenshot.statusBar, isNull);
        });

        testWidgets('adds no bar on desktop', (tester) async {
          _setSafeTop(tester, 24);
          final screenshot = await _capture(tester);
          expect(screenshot.statusBar, isNull);
        }, variant: TargetPlatformVariant.only(TargetPlatform.macOS));

        testWidgets('covers only the part of the safe area in the content',
            (tester) async {
          _setSafeTop(tester, 24);
          Future<BugScreenshot?> captureBelow(double top) async {
            late BuildContext context;
            await tester.pumpWidget(
              MaterialApp(
                builder: (_, child) => Padding(
                  padding: EdgeInsets.only(top: top),
                  child: BugInspector(
                    onWidgetSelected: (_, __) {},
                    child: child!,
                  ),
                ),
                home: Builder(
                  builder: (c) {
                    context = c;
                    return const ColoredBox(color: _white);
                  },
                ),
              ),
            );
            return tester.runAsync<BugScreenshot?>(
              () => BugInspector.captureScreenshot(
                context,
                waitForNextFrame: false,
              ),
            );
          }

          expect((await captureBelow(10))?.statusBar?.height, 14);
          expect((await captureBelow(24))?.statusBar, isNull);
        });
      });

      group('BugScreenshotEditor', () {
        Future<void> pumpEditor(
          WidgetTester tester,
          BugScreenshot screenshot, {
          List<BugScreenshotAnnotation> annotations = const [],
        }) async {
          final controller = BugScreenshotAnnotationController(annotations);
          addTearDown(controller.dispose);
          await tester.pumpWidget(
            MaterialApp(
              home: Center(
                child: SizedBox(
                  width: 400,
                  height: 200,
                  child: BugScreenshotEditor(
                    screenshot: screenshot,
                    controller: controller,
                    readOnly: true,
                  ),
                ),
              ),
            ),
          );
        }

        testWidgets('draws the Dynamic Island, the clock and the icons',
            (tester) async {
          await pumpEditor(
            tester,
            _screenshot(
              statusBar: const BugStatusBar(
                style: BugStatusBarStyle.iOS,
                height: 20,
                foregroundColor: _red,
              ),
            ),
          );

          expect(
            find.byType(BugScreenshotEditor),
            paints
              ..rrect(color: _black)
              ..paragraph()
              ..rrect(color: _red),
          );
        });

        testWidgets('draws the camera, the clock and the icons on Android',
            (tester) async {
          await pumpEditor(
            tester,
            _screenshot(
              statusBar: const BugStatusBar(
                style: BugStatusBarStyle.android,
                height: 20,
                foregroundColor: _red,
              ),
            ),
          );

          expect(
            find.byType(BugScreenshotEditor),
            paints
              ..circle(color: _black)
              ..paragraph()
              ..rrect(color: _red)
              ..path(color: _red),
          );
        });

        testWidgets('draws the bar under the rectangles', (tester) async {
          await pumpEditor(
            tester,
            _screenshot(
              statusBar: const BugStatusBar(
                style: BugStatusBarStyle.iOS,
                height: 20,
              ),
            ),
            annotations: <BugScreenshotAnnotation>[
              const BugScreenshotAnnotation(Rect.fromLTRB(10, 10, 50, 30)),
            ],
          );

          expect(
            find.byType(BugScreenshotEditor),
            paints
              ..rrect(color: _black)
              ..rect(color: BugScreenshotEditor.defaultColor),
          );
        });

        testWidgets('draws no bar without one', (tester) async {
          await pumpEditor(tester, _screenshot());
          expect(find.byType(BugScreenshotEditor), isNot(paints..paragraph()));
        });
      });

      group('toAnnotatedPng', () {
        testWidgets('draws the Dynamic Island bar into the image',
            (tester) async {
          final pixels = await tester.runAsync(() async {
            final screenshot = await _whiteScreenshot(
              400,
              80,
              statusBar: const BugStatusBar(
                style: BugStatusBarStyle.iOS,
                height: 59,
                foregroundColor: _red,
              ),
            );
            final png = await screenshot
                .toAnnotatedPng(const <BugScreenshotAnnotation>[]);
            expect(png, isNot(same(screenshot.pngBytes)));
            return _decode(png);
          });

          // The island: 125 x 37, centered in the bar.
          expect(pixels!.at(200, 29), _black);
          expect(pixels.at(140, 29), _black);
          expect(pixels.at(200, 13), _black);
          expect(pixels.at(200, 5), _white);
          // The clock, centered left of the island.
          expect(
              pixels.anyIn(const Rect.fromLTRB(33, 18, 101, 41), _red), isTrue);
          // The battery, on the right.
          expect(pixels.at(353, 29), _red);
          // Nothing below the bar.
          expect(pixels.allIn(const Rect.fromLTRB(0, 59, 400, 80), _white),
              isTrue);
        });

        testWidgets('draws the Pixel 8 bar into the image', (tester) async {
          final pixels = await tester.runAsync(() async {
            final screenshot = await _whiteScreenshot(
              400,
              80,
              statusBar: const BugStatusBar(
                style: BugStatusBarStyle.android,
                height: 52,
                foregroundColor: _red,
              ),
            );
            return _decode(await screenshot
                .toAnnotatedPng(const <BugScreenshotAnnotation>[]));
          });

          // The camera: 21 wide, centered in the bar.
          expect(pixels!.at(200, 26), _black);
          expect(pixels.at(200, 10), _white);
          // The clock, 24 from the left edge.
          expect(
              pixels.anyIn(const Rect.fromLTRB(24, 15, 90, 37), _red), isTrue);
          expect(
              pixels.anyIn(const Rect.fromLTRB(0, 0, 23, 52), _red), isFalse);
          // The battery, 24 from the right edge.
          expect(pixels.at(372, 27), _red);
          expect(pixels.anyIn(const Rect.fromLTRB(377, 0, 400, 52), _red),
              isFalse);
          expect(pixels.allIn(const Rect.fromLTRB(0, 52, 400, 80), _white),
              isTrue);
        });

        testWidgets('scales the bar with the pixel ratio', (tester) async {
          final pixels = await tester.runAsync(() async {
            final screenshot = await _whiteScreenshot(
              800,
              160,
              pixelRatio: 2,
              statusBar: const BugStatusBar(
                style: BugStatusBarStyle.iOS,
                height: 59,
              ),
            );
            return _decode(await screenshot
                .toAnnotatedPng(const <BugScreenshotAnnotation>[]));
          });

          // The island is 250 x 74 image pixels.
          expect(pixels!.at(400, 59), _black);
          expect(pixels.at(280, 59), _black);
          expect(pixels.at(270, 59), _white);
          expect(pixels.at(400, 25), _black);
          expect(pixels.at(400, 20), _white);
          expect(pixels.allIn(const Rect.fromLTRB(0, 118, 800, 160), _white),
              isTrue);
        });

        testWidgets('draws the rectangles over the bar', (tester) async {
          final pixels = await tester.runAsync(() async {
            final screenshot = await _whiteScreenshot(
              400,
              80,
              statusBar: const BugStatusBar(
                style: BugStatusBarStyle.iOS,
                height: 59,
              ),
            );
            return _decode(await screenshot.toAnnotatedPng(
              <BugScreenshotAnnotation>[
                const BugScreenshotAnnotation(Rect.fromLTRB(190, 20, 260, 70)),
              ],
              color: _red,
              strokeWidth: 2,
            ));
          });

          expect(pixels!.at(190, 29), _red);
          expect(pixels.at(195, 29), _black);
        });
      });
    });

/// A valid 1x1 transparent PNG, for an editor sized from the screenshot.
final Uint8List _onePixelPng = Uint8List.fromList(<int>[
  0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D, //
  0x49, 0x48, 0x44, 0x52, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
  0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4, 0x89, 0x00, 0x00, 0x00,
  0x0A, 0x49, 0x44, 0x41, 0x54, 0x78, 0x9C, 0x63, 0x00, 0x01, 0x00, 0x00,
  0x05, 0x00, 0x01, 0x0D, 0x0A, 0x2D, 0xB4, 0x00, 0x00, 0x00, 0x00, 0x49,
  0x45, 0x4E, 0x44, 0xAE, 0x42, 0x60, 0x82,
]);

/// 200 x 100 image pixels of a 100 x 50 app, shown at 400 x 200.
BugScreenshot _screenshot({BugStatusBar? statusBar}) => BugScreenshot(
      pngBytes: _onePixelPng,
      width: 200,
      height: 100,
      pixelRatio: 2,
      contentBounds: const Rect.fromLTWH(0, 0, 100, 50),
      capturedAtUtc: DateTime.utc(2026, 11, 12),
      statusBar: statusBar,
    );

/// A white screenshot of [width] x [height] image pixels.
Future<BugScreenshot> _whiteScreenshot(
  int width,
  int height, {
  double pixelRatio = 1,
  BugStatusBar? statusBar,
}) async {
  final recorder = ui.PictureRecorder();
  Canvas(recorder).drawRect(
    Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble()),
    Paint()..color = _white,
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
    contentBounds: Rect.fromLTWH(0, 0, width / pixelRatio, height / pixelRatio),
    capturedAtUtc: DateTime.utc(2026, 11, 12),
    statusBar: statusBar,
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

  Iterable<Color> _in(Rect rect) sync* {
    for (var y = rect.top.toInt(); y < rect.bottom.toInt(); y++) {
      for (var x = rect.left.toInt(); x < rect.right.toInt(); x++) {
        yield at(x, y);
      }
    }
  }

  bool anyIn(Rect rect, Color color) => _in(rect).contains(color);

  bool allIn(Rect rect, Color color) => _in(rect).every((c) => c == color);
}
