part of '../flutter_qa_inspector.dart';

/// The look of a [BugStatusBar].
enum BugStatusBarStyle {
  /// A Pixel 8 status bar: the clock on the left, the punch-hole camera in
  /// the middle, then Wi-Fi, mobile signal and battery on the right.
  android,

  /// An iPhone status bar with a Dynamic Island: the clock left of the
  /// island, then mobile signal, Wi-Fi and battery right of it.
  iOS;

  /// The style drawn for screenshots taken on [platform], or `null` when
  /// [platform] has no status bar to draw.
  static BugStatusBarStyle? of(TargetPlatform platform) => switch (platform) {
        TargetPlatform.android => BugStatusBarStyle.android,
        TargetPlatform.iOS => BugStatusBarStyle.iOS,
        _ => null,
      };
}

/// A fake system status bar drawn over the top of a [BugScreenshot], in the
/// [BugScreenshotEditor] and in [BugScreenshot.toAnnotatedPng].
///
/// The system draws its status bar above the app, so a capture of the app
/// only shows the app background there. [BugInspector.captureScreenshot]
/// adds a bar that fills the top safe area, so the image looks like the
/// screen the tester saw. Only its height matches the device: the clock shows
/// [time], and signal, Wi-Fi and battery are always full.
@immutable
class BugStatusBar {
  /// Creates a status bar [height] logical pixels high.
  const BugStatusBar({
    required this.style,
    required this.height,
    this.time = defaultTime,
    this.foregroundColor = defaultForegroundColor,
  }) : assert(height >= 0, 'height must not be negative');

  /// The default [time].
  static const String defaultTime = '9:41';

  /// The default [foregroundColor], for a light app background.
  static const Color defaultForegroundColor = Color(0xFF000000);

  /// The look of the bar.
  final BugStatusBarStyle style;

  /// How high the bar is, in logical pixels from the top of the image: the
  /// part of the top safe area that the capture covers.
  final double height;

  /// The clock, for example `9:41`.
  final String time;

  /// The color of the clock and the icons. The Dynamic Island and the camera
  /// are always black.
  final Color foregroundColor;

  /// Describes the bar.
  Map<String, Object?> toJson() => <String, Object?>{
        'style': style.name,
        'height': height,
        'coordinateUnit': 'logical_pixels',
      };

  @override
  bool operator ==(Object other) =>
      other is BugStatusBar &&
      other.style == style &&
      other.height == height &&
      other.time == time &&
      other.foregroundColor == foregroundColor;

  @override
  int get hashCode => Object.hash(style, height, time, foregroundColor);

  @override
  String toString() => 'BugStatusBar(${style.name}, height: $height)';

  static const Color _black = Color(0xFF000000);
  static const Color _white = Color(0xFFFFFFFF);

  /// Draws the bar at the top left of [canvas], in logical pixels of the app,
  /// across [width].
  void _paint(Canvas canvas, double width) {
    if (height <= 0 || width <= 0) return;
    canvas
      ..save()
      ..clipRect(Rect.fromLTWH(0, 0, width, height));
    switch (style) {
      case BugStatusBarStyle.android:
        _paintAndroid(canvas, width);
      case BugStatusBarStyle.iOS:
        _paintIOS(canvas, width);
    }
    canvas.restore();
  }

  /// Pixel 8 on Android 14. The clock and the icons keep their size in any
  /// bar at least 24 logical pixels high, and the camera grows with the bar.
  void _paintAndroid(Canvas canvas, double width) {
    final s = _clamp(height / 24, 0.7, 1);
    final cy = height / 2;
    final padding = 24 * s;
    final paint = Paint()..color = foregroundColor;

    canvas.drawCircle(
      Offset(width / 2, cy),
      math.min(21, height * 0.7) / 2,
      Paint()..color = _black,
    );

    _paintClock(
      canvas,
      left: padding,
      centerY: cy,
      fontSize: 14 * s,
      fontWeight: FontWeight.w500,
      letterSpacing: 0.1 * s,
    );

    // From the right: battery, mobile signal, Wi-Fi.
    var right = width - padding;

    // A full battery, standing up: the cap is on top.
    final batteryBody = Rect.fromLTRB(
      right - 7.5 * s,
      cy - 6 * s,
      right,
      cy + 7 * s,
    );
    canvas
      ..drawRRect(
        RRect.fromRectAndRadius(batteryBody, Radius.circular(1.5 * s)),
        paint,
      )
      ..drawRRect(
        RRect.fromRectAndCorners(
          Rect.fromLTRB(
            batteryBody.center.dx - 1.75 * s,
            batteryBody.top - 1.5 * s,
            batteryBody.center.dx + 1.75 * s,
            batteryBody.top + 0.5 * s,
          ),
          topLeft: Radius.circular(0.5 * s),
          topRight: Radius.circular(0.5 * s),
        ),
        paint,
      );
    right = batteryBody.left - 5 * s;

    // Full mobile signal: a triangle up to the right.
    final signalSize = 13 * s;
    final signalBottom = cy + signalSize / 2;
    canvas.drawPath(
      Path()
        ..moveTo(right - signalSize, signalBottom)
        ..lineTo(right, signalBottom)
        ..lineTo(right, signalBottom - signalSize)
        ..close(),
      paint,
    );
    right -= signalSize + 5 * s;

    // Full Wi-Fi: a fan pointing down, as the Material icon.
    final k = 16 * s / 23.2;
    final wifiTop = cy - 18 * k / 2;
    final wifiLeft = right - 23.2 * k;
    Offset at(double x, double y) =>
        Offset(wifiLeft + (x - 0.4) * k, wifiTop + (y - 3) * k);
    final apex = at(12, 21);
    final topRight = at(23.6, 7);
    final topLeft = at(0.4, 7);
    final c1 = at(23.15, 6.66);
    final c2 = at(18.67, 3);
    final top = at(12, 3);
    final c3 = at(5.32, 3);
    final c4 = at(0.85, 6.66);
    canvas.drawPath(
      Path()
        ..moveTo(apex.dx, apex.dy)
        ..lineTo(topRight.dx, topRight.dy)
        ..cubicTo(c1.dx, c1.dy, c2.dx, c2.dy, top.dx, top.dy)
        ..cubicTo(c3.dx, c3.dy, c4.dx, c4.dy, topLeft.dx, topLeft.dy)
        ..close(),
      paint,
    );
  }

  /// An iPhone 15 Pro, whose bar is 59 points high. A lower bar gets a
  /// smaller island, and the clock and the icons shrink in a bar lower than
  /// 44 points.
  void _paintIOS(Canvas canvas, double width) {
    final s = _clamp(height / 44, 0.7, 1);
    final islandScale = math.min(1.0, height / 59);
    final cy = height / 2;

    final island = Rect.fromCenter(
      center: Offset(width / 2, cy),
      width: 125 * islandScale,
      height: 37 * islandScale,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(island, Radius.circular(island.height / 2)),
      Paint()..color = _black,
    );

    // The clock and the icons are centered on each side of the island, and
    // stay near the edges of a wide screen.
    final sideCenter = math.min(island.left / 2, 67 * s);
    _paintClock(
      canvas,
      centerX: sideCenter,
      centerY: cy,
      fontSize: 17 * s,
      fontWeight: FontWeight.w600,
      letterSpacing: -0.4 * s,
    );

    const signalWidth = 17.0;
    const wifiWidth = 15.4;
    const batteryWidth = 27.4;
    const gap = 5.5;
    const iconsWidth = signalWidth + gap + wifiWidth + gap + batteryWidth;
    var left = width - sideCenter - iconsWidth * s / 2;
    final paint = Paint()..color = foregroundColor;

    // Full mobile signal: four bars.
    final iconBottom = cy + 5.5 * s;
    const barHeights = <double>[4, 6.3, 8.7, 11];
    for (var i = 0; i < barHeights.length; i++) {
      final barLeft = left + i * 4.7 * s;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTRB(
            barLeft,
            iconBottom - barHeights[i] * s,
            barLeft + 3 * s,
            iconBottom,
          ),
          Radius.circular(1 * s),
        ),
        paint,
      );
    }
    left += (signalWidth + gap) * s;

    // Full Wi-Fi: a dot and two bands around the bottom point.
    final apex = Offset(left + wifiWidth * s / 2, iconBottom);
    const half = math.pi / 4;
    canvas.drawArc(
      Rect.fromCircle(center: apex, radius: 3.4 * s),
      -math.pi / 2 - half,
      2 * half,
      true,
      paint,
    );
    final band = Paint()
      ..color = foregroundColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.6 * s
      ..strokeCap = StrokeCap.round;
    for (final radius in const <double>[5.9, 9.5]) {
      // The round caps go past the arc by half the stroke width.
      final sweep = half - 1.3 / radius;
      canvas.drawArc(
        Rect.fromCircle(center: apex, radius: radius * s),
        -math.pi / 2 - sweep,
        2 * sweep,
        false,
        band,
      );
    }
    left += (wifiWidth + gap) * s;

    // A full battery, lying down: the cap is on the right.
    final body = Rect.fromLTWH(left, cy - 6 * s, 25 * s, 12 * s);
    canvas
      ..drawRRect(
        RRect.fromRectAndRadius(
            body.deflate(0.5 * s), Radius.circular(3.8 * s)),
        Paint()
          ..color = foregroundColor.withAlpha(0x59)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1 * s,
      )
      ..drawRRect(
        RRect.fromRectAndRadius(body.deflate(2 * s), Radius.circular(2.5 * s)),
        paint,
      )
      ..drawRRect(
        RRect.fromRectAndCorners(
          Rect.fromLTWH(body.right + 1 * s, cy - 2 * s, 1.4 * s, 4 * s),
          topRight: Radius.circular(1 * s),
          bottomRight: Radius.circular(1 * s),
        ),
        Paint()..color = foregroundColor.withAlpha(0x66),
      );
  }

  /// Draws [time] with its digits centered on [centerY], starting at [left]
  /// or centered on [centerX].
  void _paintClock(
    Canvas canvas, {
    double? left,
    double? centerX,
    required double centerY,
    required double fontSize,
    required FontWeight fontWeight,
    required double letterSpacing,
  }) {
    final clock = TextPainter(
      text: TextSpan(
        text: time,
        style: TextStyle(
          color: foregroundColor,
          fontSize: fontSize,
          fontWeight: fontWeight,
          letterSpacing: letterSpacing,
          fontFeatures: const <ui.FontFeature>[ui.FontFeature.tabularFigures()],
        ),
      ),
      textDirection: TextDirection.ltr,
      maxLines: 1,
    )..layout();
    try {
      final baseline =
          clock.computeDistanceToActualBaseline(TextBaseline.alphabetic);
      // Digits are about 0.72 em high, sitting on the baseline.
      final top = centerY + 0.36 * fontSize - baseline;
      clock.paint(
        canvas,
        Offset(left ?? centerX! - clock.width / 2, top),
      );
    } finally {
      clock.dispose();
    }
  }
}

/// Paints [statusBar] over an image of the app [contentWidth] logical pixels
/// wide, scaled to the size of the image on screen.
class _StatusBarPainter extends CustomPainter {
  _StatusBarPainter(this.statusBar, {required this.contentWidth});

  final BugStatusBar statusBar;
  final double contentWidth;

  @override
  void paint(Canvas canvas, Size size) {
    if (contentWidth <= 0 || size.isEmpty) return;
    canvas
      ..save()
      ..scale(size.width / contentWidth);
    statusBar._paint(canvas, contentWidth);
    canvas.restore();
  }

  @override
  bool shouldRepaint(_StatusBarPainter oldDelegate) =>
      oldDelegate.statusBar != statusBar ||
      oldDelegate.contentWidth != contentWidth;
}

/// How much of the top safe area of the view of [context] is inside
/// [contentBounds], in logical pixels from its top.
double _statusBarHeight(BuildContext context, Rect contentBounds) {
  final view = View.maybeOf(context);
  if (view == null || view.devicePixelRatio <= 0) return 0;
  final safeTop = view.padding.top / view.devicePixelRatio;
  return _clamp(safeTop - contentBounds.top, 0, contentBounds.height);
}

/// [time] as the status bar shows it: `9:41`, or `09:41` with [use24Hour].
String _statusBarClock(DateTime time, {required bool use24Hour}) {
  final minute = time.minute.toString().padLeft(2, '0');
  if (use24Hour) return '${time.hour.toString().padLeft(2, '0')}:$minute';
  final hour = time.hour % 12 == 0 ? 12 : time.hour % 12;
  return '$hour:$minute';
}

/// Black over a light top of [image], white over a dark one, as an [AppBar]
/// picks the status bar icons. [height] is in image pixels.
Future<Color> _statusBarForeground(ui.Image image, int height) async {
  if (image.width == 0 || image.height == 0) {
    return BugStatusBar.defaultForegroundColor;
  }
  final rows = height.clamp(1, image.height);
  final recorder = ui.PictureRecorder();
  Canvas(recorder).drawImage(image, Offset.zero, Paint());
  final picture = recorder.endRecording();
  ui.Image? strip;
  try {
    strip = await picture.toImage(image.width, rows);
    // Premultiplied: transparent pixels count as black.
    final data = await strip.toByteData();
    if (data == null || data.lengthInBytes == 0) {
      return BugStatusBar.defaultForegroundColor;
    }
    final bytes =
        data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
    var red = 0;
    var green = 0;
    var blue = 0;
    for (var i = 0; i + 3 < bytes.length; i += 4) {
      red += bytes[i];
      green += bytes[i + 1];
      blue += bytes[i + 2];
    }
    final count = bytes.length ~/ 4;
    final average = Color.fromARGB(
      0xFF,
      red ~/ count,
      green ~/ count,
      blue ~/ count,
    );
    return ThemeData.estimateBrightnessForColor(average) == Brightness.light
        ? BugStatusBar._black
        : BugStatusBar._white;
  } finally {
    picture.dispose();
    strip?.dispose();
  }
}
