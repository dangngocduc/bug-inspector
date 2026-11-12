part of '../flutter_qa_inspector.dart';

/// A PNG capture of the app content, made by [BugInspector.captureScreenshot].
@immutable
class BugScreenshot {
  /// Creates a screenshot.
  const BugScreenshot({
    required this.pngBytes,
    required this.width,
    required this.height,
    required this.pixelRatio,
    required this.contentBounds,
    required this.capturedAtUtc,
    this.statusBar,
  });

  /// The encoded PNG image.
  final Uint8List pngBytes;

  /// The image width in physical pixels.
  final int width;

  /// The image height in physical pixels.
  final int height;

  /// The number of image pixels per logical pixel.
  final double pixelRatio;

  /// Where the captured content is on screen, in global logical pixels.
  final Rect contentBounds;

  /// When the image was captured, in UTC.
  ///
  /// It can differ from [BugWidgetSelection.capturedAtUtc] because the image
  /// is taken in a later frame.
  final DateTime capturedAtUtc;

  /// The fake status bar drawn over the top of the image, if any.
  ///
  /// It is not in [pngBytes]: the [BugScreenshotEditor] and
  /// [toAnnotatedPng] draw it, under the highlight and the rectangles.
  /// [BugInspector.captureScreenshot] adds it when the content is under the
  /// top safe area on Android or iOS.
  final BugStatusBar? statusBar;

  /// Converts [globalRect], for example [BugWidgetSelection.bounds], from
  /// global logical pixels into pixels of this image.
  Rect toImageRect(Rect globalRect) {
    return Rect.fromLTWH(
      (globalRect.left - contentBounds.left) * pixelRatio,
      (globalRect.top - contentBounds.top) * pixelRatio,
      globalRect.width * pixelRatio,
      globalRect.height * pixelRatio,
    );
  }

  /// Encodes this image as a PNG with what a [BugScreenshotEditor] draws on
  /// it: the [statusBar], the [highlight] outline and the [annotations].
  ///
  /// The [statusBar] is drawn at [pixelRatio] image pixels per logical pixel.
  /// Pass the `highlight` given to the editor, in global logical pixels, for
  /// example [BugWidgetSelection.bounds]. It is outlined with dashes of
  /// [highlightColor], under the rectangles. Each rectangle is stroked with
  /// [color], [strokeWidth] logical pixels wide (`strokeWidth * pixelRatio`
  /// image pixels), like in an editor shown at the size of the app.
  ///
  /// Returns [pngBytes] when there is nothing to draw, and without
  /// `--dart-define=FLUTTER_QA_INSPECTOR=true`.
  Future<Uint8List> toAnnotatedPng(
    Iterable<BugScreenshotAnnotation> annotations, {
    Rect? highlight,
    Color color = BugScreenshotEditor.defaultColor,
    double strokeWidth = BugScreenshotEditor.defaultStrokeWidth,
    Color highlightColor = BugInspector.defaultBorderColor,
  }) async {
    if (!BugInspector.enabledFromEnvironment) return pngBytes;
    final rects = <Rect>[for (final annotation in annotations) annotation.rect];
    final statusBar = this.statusBar;
    if (rects.isEmpty && highlight == null && statusBar == null) {
      return pngBytes;
    }

    final codec = await ui.instantiateImageCodec(pngBytes);
    ui.Image? source;
    ui.Image? annotated;
    try {
      source = (await codec.getNextFrame()).image;
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder)..drawImage(source, Offset.zero, Paint());
      if (statusBar != null && pixelRatio > 0) {
        canvas
          ..save()
          ..scale(pixelRatio);
        statusBar._paint(canvas, source.width / pixelRatio);
        canvas.restore();
      }
      if (highlight != null) {
        _AnnotationPainter._paintDashedRect(
          canvas,
          toImageRect(highlight),
          Paint()
            ..color = highlightColor
            ..style = PaintingStyle.stroke
            ..strokeWidth =
                _AnnotationPainter._highlightStrokeWidth * pixelRatio,
          unit: pixelRatio,
        );
      }
      final stroke = Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth * pixelRatio;
      for (final rect in rects) {
        canvas.drawRect(rect, stroke);
      }
      final picture = recorder.endRecording();
      try {
        annotated = await picture.toImage(source.width, source.height);
      } finally {
        picture.dispose();
      }
      final data = await annotated.toByteData(format: ui.ImageByteFormat.png);
      if (data == null) {
        throw StateError('The annotated screenshot could not be encoded.');
      }
      return data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
    } finally {
      source?.dispose();
      annotated?.dispose();
      codec.dispose();
    }
  }

  /// Describes the image without its bytes.
  Map<String, Object?> toJson() => <String, Object?>{
        'width': width,
        'height': height,
        'pixelRatio': pixelRatio,
        'contentBounds': <String, Object?>{
          'left': contentBounds.left,
          'top': contentBounds.top,
          'width': contentBounds.width,
          'height': contentBounds.height,
          'coordinateUnit': 'logical_pixels',
        },
        'capturedAtUtc': capturedAtUtc.toUtc().toIso8601String(),
        if (statusBar != null) 'statusBar': statusBar!.toJson(),
      };
}

Future<BugScreenshot?> _captureScreenshot(
  BuildContext context, {
  required double? pixelRatio,
  required bool waitForNextFrame,
  required bool statusBar,
}) async {
  final scope = context.getInheritedWidgetOfExactType<_BugInspectorScope>();
  if (scope == null) return null;
  final contentKey = scope.registry.contentKey;
  final ratio =
      pixelRatio ?? MediaQuery.maybeDevicePixelRatioOf(context) ?? 1.0;

  if (waitForNextFrame) await WidgetsBinding.instance.endOfFrame;

  final boundary = contentKey.currentContext?.findRenderObject();
  if (boundary is! RenderRepaintBoundary ||
      !boundary.attached ||
      !boundary.hasSize) {
    return null;
  }
  var needsPaint = false;
  assert(() {
    needsPaint = boundary.debugNeedsPaint;
    return true;
  }());
  if (needsPaint) await WidgetsBinding.instance.endOfFrame;
  final boundaryContext = contentKey.currentContext;
  if (!boundary.attached ||
      boundaryContext == null ||
      !boundaryContext.mounted) {
    return null;
  }

  final contentBounds = MatrixUtils.transformRect(
    boundary.getTransformTo(null),
    Offset.zero & boundary.size,
  );
  final capturedAtUtc = DateTime.now().toUtc();
  final statusBarStyle =
      statusBar ? BugStatusBarStyle.of(defaultTargetPlatform) : null;
  final statusBarHeight = statusBarStyle == null
      ? 0.0
      : _statusBarHeight(boundaryContext, contentBounds);
  final use24HourClock =
      MediaQuery.maybeAlwaysUse24HourFormatOf(boundaryContext) ?? false;
  final image = await boundary.toImage(pixelRatio: ratio);
  try {
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    if (data == null) return null;
    return BugScreenshot(
      pngBytes: data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
      width: image.width,
      height: image.height,
      pixelRatio: ratio,
      contentBounds: contentBounds,
      capturedAtUtc: capturedAtUtc,
      statusBar: statusBarStyle == null || statusBarHeight <= 0
          ? null
          : BugStatusBar(
              style: statusBarStyle,
              height: statusBarHeight,
              time: _statusBarClock(
                capturedAtUtc.toLocal(),
                use24Hour: use24HourClock,
              ),
              foregroundColor: await _statusBarForeground(
                image,
                (statusBarHeight * ratio).ceil(),
              ),
            ),
    );
  } finally {
    image.dispose();
  }
}
