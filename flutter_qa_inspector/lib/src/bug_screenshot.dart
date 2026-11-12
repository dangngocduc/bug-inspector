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

  /// Encodes this image with [annotations] drawn on it as a PNG.
  ///
  /// Each rectangle is stroked with [color], [strokeWidth] logical pixels wide
  /// (`strokeWidth * pixelRatio` image pixels), like in a
  /// [BugScreenshotEditor] shown at the size of the app. Returns [pngBytes]
  /// when there are no annotations, and without
  /// `--dart-define=FLUTTER_QA_INSPECTOR=true`.
  Future<Uint8List> toAnnotatedPng(
    Iterable<BugScreenshotAnnotation> annotations, {
    Color color = BugScreenshotEditor.defaultColor,
    double strokeWidth = BugScreenshotEditor.defaultStrokeWidth,
  }) async {
    if (!BugInspector.enabledFromEnvironment) return pngBytes;
    final rects = <Rect>[for (final annotation in annotations) annotation.rect];
    if (rects.isEmpty) return pngBytes;

    final codec = await ui.instantiateImageCodec(pngBytes);
    ui.Image? source;
    ui.Image? annotated;
    try {
      source = (await codec.getNextFrame()).image;
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder)..drawImage(source, Offset.zero, Paint());
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
      };
}

Future<BugScreenshot?> _captureScreenshot(
  BuildContext context, {
  required double? pixelRatio,
  required bool waitForNextFrame,
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
  if (!boundary.attached) return null;

  final contentBounds = MatrixUtils.transformRect(
    boundary.getTransformTo(null),
    Offset.zero & boundary.size,
  );
  final capturedAtUtc = DateTime.now().toUtc();
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
    );
  } finally {
    image.dispose();
  }
}
