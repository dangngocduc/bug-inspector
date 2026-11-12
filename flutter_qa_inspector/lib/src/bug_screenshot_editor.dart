part of '../flutter_qa_inspector.dart';

/// A rectangle the tester drew on a [BugScreenshot], for example to point at
/// a wrong label or a missing icon.
@immutable
class BugScreenshotAnnotation {
  /// Creates an annotation covering [rect], in pixels of the screenshot image.
  const BugScreenshotAnnotation(this.rect);

  /// Where the rectangle is, in pixels of the screenshot image (the same
  /// space as [BugScreenshot.toImageRect]).
  final Rect rect;

  /// Converts the annotation into a JSON compatible map.
  Map<String, Object?> toJson() => <String, Object?>{
        'left': rect.left,
        'top': rect.top,
        'width': rect.width,
        'height': rect.height,
        'coordinateUnit': 'image_pixels',
      };

  @override
  bool operator ==(Object other) =>
      other is BugScreenshotAnnotation && other.rect == rect;

  @override
  int get hashCode => rect.hashCode;

  @override
  String toString() => 'BugScreenshotAnnotation($rect)';
}

/// Holds the rectangles drawn on a screenshot and which one is selected.
///
/// Give the same controller to a [BugScreenshotEditor] and read
/// [annotations] when the report is sent. The owner calls [dispose].
class BugScreenshotAnnotationController extends ChangeNotifier {
  /// Creates a controller that starts with [annotations] and no selection.
  BugScreenshotAnnotationController([
    Iterable<BugScreenshotAnnotation> annotations =
        const <BugScreenshotAnnotation>[],
  ]) : _annotations = List<BugScreenshotAnnotation>.of(annotations);

  List<BugScreenshotAnnotation> _annotations;
  int? _selectedIndex;

  /// The annotations, in drawing order: the last one is drawn on top.
  List<BugScreenshotAnnotation> get annotations =>
      List<BugScreenshotAnnotation>.unmodifiable(_annotations);

  /// Replaces every annotation and clears the selection.
  set annotations(List<BugScreenshotAnnotation> value) {
    _annotations = List<BugScreenshotAnnotation>.of(value);
    _selectedIndex = null;
    notifyListeners();
  }

  /// The index of the selected annotation in [annotations], if any.
  int? get selectedIndex => _selectedIndex;

  /// The selected annotation, if any.
  BugScreenshotAnnotation? get selected {
    final index = _selectedIndex;
    return index == null ? null : _annotations[index];
  }

  /// Adds [annotation] on top of the others and, when [select] is `true`,
  /// selects it.
  void add(BugScreenshotAnnotation annotation, {bool select = true}) {
    _annotations.add(annotation);
    if (select) _selectedIndex = _annotations.length - 1;
    notifyListeners();
  }

  /// Replaces the annotation at [index], keeping the selection.
  void replaceAt(int index, BugScreenshotAnnotation annotation) {
    RangeError.checkValidIndex(index, _annotations);
    if (_annotations[index] == annotation) return;
    _annotations[index] = annotation;
    notifyListeners();
  }

  /// Removes the annotation at [index].
  void removeAt(int index) {
    RangeError.checkValidIndex(index, _annotations);
    _annotations.removeAt(index);
    final selected = _selectedIndex;
    if (selected == index) {
      _selectedIndex = null;
    } else if (selected != null && selected > index) {
      _selectedIndex = selected - 1;
    }
    notifyListeners();
  }

  /// Removes the selected annotation. Returns `false` when none is selected.
  bool removeSelected() {
    final index = _selectedIndex;
    if (index == null) return false;
    removeAt(index);
    return true;
  }

  /// Removes every annotation.
  void clear() {
    if (_annotations.isEmpty) return;
    _annotations.clear();
    _selectedIndex = null;
    notifyListeners();
  }

  /// Selects the annotation at [index], or nothing when [index] is `null`.
  void select(int? index) {
    if (index != null) RangeError.checkValidIndex(index, _annotations);
    if (_selectedIndex == index) return;
    _selectedIndex = index;
    notifyListeners();
  }

  /// Converts the annotations into a JSON compatible list.
  List<Object?> toJson() => <Object?>[
        for (final annotation in _annotations) annotation.toJson(),
      ];
}

/// Shows a [BugScreenshot] and lets the tester mark parts of it with
/// rectangles.
///
/// * Drag on the image, outside any rectangle, to draw a new one.
/// * Tap a rectangle to select it, drag it to move it, and drag one of its
///   corner handles to resize it. Tap outside the rectangles to unselect.
/// * The round button next to the selected rectangle deletes it.
///
/// Rectangles stay inside the image. The editor keeps the aspect ratio of the
/// image and takes the largest size its constraints allow, so give it a
/// bounded width or height. A touch that starts on the editor is never a
/// scroll of an enclosing list: put it in a full-screen route rather than in a
/// scrolling form, and use [readOnly] for a preview inside the form.
///
/// Without `--dart-define=FLUTTER_QA_INSPECTOR=true`
/// ([BugInspector.enabledFromEnvironment]) it builds an empty box.
class BugScreenshotEditor extends StatefulWidget {
  /// Creates an editor for [screenshot] whose rectangles are kept in
  /// [controller].
  const BugScreenshotEditor({
    super.key,
    required this.screenshot,
    required this.controller,
    this.highlight,
    this.readOnly = false,
    this.color = defaultColor,
    this.strokeWidth = defaultStrokeWidth,
    this.highlightColor = BugInspector.defaultBorderColor,
    this.semanticLabel = defaultSemanticLabel,
    this.deleteButtonLabel = defaultDeleteButtonLabel,
  });

  /// The default color of the rectangles.
  static const Color defaultColor = Color(0xFFFF6D00);

  /// The default stroke width of the rectangles, in logical pixels.
  static const double defaultStrokeWidth = 3;

  /// The default [semanticLabel].
  static const String defaultSemanticLabel = 'Bug screenshot';

  /// The default [deleteButtonLabel].
  static const String defaultDeleteButtonLabel = 'Delete rectangle';

  /// The key of the button that deletes the selected rectangle, for widget
  /// tests and integration tests.
  static const Key deleteButtonKey =
      ValueKey<String>('bug_screenshot_editor.delete');

  /// The smallest width and height of a rectangle drawn or resized by the
  /// tester, in logical pixels on screen.
  static const double minRectSize = 16;

  /// The screenshot to show.
  final BugScreenshot screenshot;

  /// The rectangles and the selection.
  final BugScreenshotAnnotationController controller;

  /// An area to outline with a dashed line that the tester cannot edit, in
  /// global logical pixels, for example [BugWidgetSelection.bounds].
  final Rect? highlight;

  /// Whether the editor only shows the rectangles, without selection,
  /// handles or gestures.
  final bool readOnly;

  /// The color of the rectangles.
  final Color color;

  /// The stroke width of the rectangles, in logical pixels on screen.
  ///
  /// Pass the same value to [BugScreenshot.toAnnotatedPng] to get the same
  /// look in the exported image.
  final double strokeWidth;

  /// The color of the [highlight] outline.
  final Color highlightColor;

  /// What a screen reader says for the image.
  final String semanticLabel;

  /// What a screen reader says for the delete button.
  final String deleteButtonLabel;

  @override
  State<BugScreenshotEditor> createState() => _BugScreenshotEditorState();
}

enum _EditorDragMode { draw, move, resize }

class _BugScreenshotEditorState extends State<BugScreenshotEditor> {
  /// The finger can start this far from a corner and still grab its handle.
  static const double _handleTouchRadius = 24;

  /// A drag on the image must move this far before a rectangle appears, so
  /// a tap does not draw one.
  static const double _drawSlop = 8;

  /// A tap this close to a rectangle still selects it.
  static const double _rectTouchTolerance = 8;

  static const double _deleteButtonSize = 32;
  static const double _deleteButtonGap = 8;

  /// The size the image is shown at, in logical pixels.
  Size _displaySize = Size.zero;

  _EditorDragMode? _mode;
  Offset _dragStart = Offset.zero;

  /// The annotation being edited, as last written to the controller. A
  /// different value at [_index] means it changed under the drag.
  BugScreenshotAnnotation? _editing;
  int? _index;
  int? _selectionBefore;

  /// Image-space rectangle before a move or resize.
  Rect _original = Rect.zero;

  /// Image-space corner that stays in place while drawing or resizing.
  Offset _fixedCorner = Offset.zero;

  /// Image-space position of the corner being dragged when the drag started.
  Offset _movingCorner = Offset.zero;

  BugScreenshot get _screenshot => widget.screenshot;

  Size get _imageSize =>
      Size(_screenshot.width.toDouble(), _screenshot.height.toDouble());

  /// Logical pixels on screen per image pixel.
  double get _scale =>
      _screenshot.width == 0 ? 1 : _displaySize.width / _screenshot.width;

  @override
  void didUpdateWidget(BugScreenshotEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.readOnly ||
        oldWidget.controller != widget.controller ||
        oldWidget.screenshot != widget.screenshot) {
      _resetDrag();
    }
  }

  Rect _toDisplay(Rect imageRect) {
    final scale = _scale;
    return Rect.fromLTRB(
      imageRect.left * scale,
      imageRect.top * scale,
      imageRect.right * scale,
      imageRect.bottom * scale,
    );
  }

  Offset _toImage(Offset displayPoint) {
    final scale = _scale;
    return Offset(displayPoint.dx / scale, displayPoint.dy / scale);
  }

  /// The handle of the selected rectangle at [point], as the index of the
  /// corner in [_cornersOf].
  int? _cornerAt(Rect displayRect, Offset point) {
    final inside = displayRect.contains(point);
    // Inside a small rectangle, leave its middle for moving it.
    final radius = inside
        ? math.min(_handleTouchRadius, displayRect.shortestSide / 3)
        : _handleTouchRadius;
    int? nearest;
    var nearestDistance = double.infinity;
    final corners = _cornersOf(displayRect);
    for (var i = 0; i < corners.length; i++) {
      final distance = (corners[i] - point).distance;
      if (distance <= radius && distance < nearestDistance) {
        nearest = i;
        nearestDistance = distance;
      }
    }
    return nearest;
  }

  /// The rectangle at [point]: the smallest one, then the one on top.
  int? _annotationAt(Offset point) {
    final annotations = widget.controller.annotations;
    int? found;
    var foundArea = double.infinity;
    for (var i = annotations.length - 1; i >= 0; i--) {
      final rect = _toDisplay(annotations[i].rect);
      if (!rect.inflate(_rectTouchTolerance).contains(point)) continue;
      final area = rect.width * rect.height;
      if (area < foundArea) {
        found = i;
        foundArea = area;
      }
    }
    return found;
  }

  void _onDragStart(Offset point) {
    if (widget.readOnly || _displaySize.isEmpty) return;
    final controller = widget.controller;
    _selectionBefore = controller.selectedIndex;
    _dragStart = point;

    final selected = controller.selectedIndex;
    if (selected != null) {
      final annotation = controller.annotations[selected];
      final corners = _cornersOf(annotation.rect);
      final corner = _cornerAt(_toDisplay(annotation.rect), point);
      if (corner != null) {
        _mode = _EditorDragMode.resize;
        _index = selected;
        _editing = annotation;
        _original = annotation.rect;
        _movingCorner = corners[corner];
        _fixedCorner = corners[(corner + 2) % 4];
        return;
      }
    }

    final hit = _annotationAt(point);
    if (hit != null) {
      controller.select(hit);
      final annotation = controller.annotations[hit];
      _mode = _EditorDragMode.move;
      _index = hit;
      _editing = annotation;
      _original = annotation.rect;
      return;
    }

    _mode = _EditorDragMode.draw;
    _index = null;
    _editing = null;
    _fixedCorner = _clampToImage(_toImage(point));
  }

  void _onDragUpdate(Offset point) {
    final mode = _mode;
    if (mode == null) return;
    final controller = widget.controller;
    final index = _index;
    if (index != null &&
        (index >= controller.annotations.length ||
            !identical(controller.annotations[index], _editing))) {
      // Deleted or replaced by someone else during the drag.
      _resetDrag();
      return;
    }

    final delta = point - _dragStart;
    final imageDelta = Offset(delta.dx / _scale, delta.dy / _scale);
    final Rect rect;
    switch (mode) {
      case _EditorDragMode.draw:
        if (index == null && delta.distance < _drawSlop) return;
        rect = _rectBetween(_fixedCorner, _toImage(point), _toImage(point));
      case _EditorDragMode.resize:
        final moving = _movingCorner + imageDelta;
        rect = _rectBetween(_fixedCorner, moving, _movingCorner);
      case _EditorDragMode.move:
        rect = _shiftInsideImage(_original, imageDelta);
    }

    final annotation = BugScreenshotAnnotation(rect);
    if (index == null) {
      controller.add(annotation);
      _index = controller.annotations.length - 1;
    } else {
      controller.replaceAt(index, annotation);
    }
    _editing = controller.annotations[_index!];
  }

  void _onDragEnd() {
    if (_mode == _EditorDragMode.draw && _index == null) {
      // A tap outside the rectangles.
      widget.controller.select(null);
    }
    _resetDrag();
  }

  void _onDragCancel() {
    final controller = widget.controller;
    final index = _index;
    final stillOurs = index != null &&
        index < controller.annotations.length &&
        identical(controller.annotations[index], _editing);
    if (stillOurs) {
      if (_mode == _EditorDragMode.draw) {
        controller.removeAt(index);
      } else {
        controller.replaceAt(index, BugScreenshotAnnotation(_original));
      }
    }
    final selectionBefore = _selectionBefore;
    if (stillOurs &&
        (selectionBefore == null ||
            selectionBefore < controller.annotations.length)) {
      controller.select(selectionBefore);
    }
    _resetDrag();
  }

  void _resetDrag() {
    _mode = null;
    _index = null;
    _editing = null;
    _selectionBefore = null;
  }

  Offset _clampToImage(Offset point) {
    final size = _imageSize;
    return Offset(
      _clamp(point.dx, 0, size.width),
      _clamp(point.dy, 0, size.height),
    );
  }

  /// The rectangle between [fixed] and [moving], inside the image and at
  /// least [BugScreenshotEditor.minRectSize] on screen. When [moving] is too
  /// close to [fixed] on an axis, it goes to the side of [preferred].
  Rect _rectBetween(Offset fixed, Offset moving, Offset preferred) {
    final minSize = BugScreenshotEditor.minRectSize / _scale;
    final size = _imageSize;
    double axis(double fixed, double moving, double preferred, double max) {
      var offset = moving - fixed;
      if (offset.abs() < minSize) {
        final side =
            offset != 0 ? offset.sign : (preferred - fixed < 0 ? -1.0 : 1.0);
        offset = side * minSize;
      }
      var value = _clamp(fixed + offset, 0, max);
      // No room on that side, at the edge of the image: use the other one.
      if ((value - fixed).abs() < minSize) {
        value = _clamp(fixed - offset, 0, max);
      }
      return value;
    }

    return Rect.fromPoints(
      fixed,
      Offset(
        axis(fixed.dx, moving.dx, preferred.dx, size.width),
        axis(fixed.dy, moving.dy, preferred.dy, size.height),
      ),
    );
  }

  Rect _shiftInsideImage(Rect rect, Offset delta) {
    final size = _imageSize;
    return rect.shift(Offset(
      _clamp(delta.dx, -rect.left, size.width - rect.right),
      _clamp(delta.dy, -rect.top, size.height - rect.bottom),
    ));
  }

  /// Where the delete button of [selected] goes, in display pixels: above the
  /// rectangle, else below it, else inside it at the top.
  Offset _deleteButtonOrigin(Rect selected) {
    const size = _deleteButtonSize;
    const gap = _deleteButtonGap;
    var top = selected.top - gap - size;
    if (top < 0) top = selected.bottom + gap;
    if (top + size > _displaySize.height) top = selected.top + gap;
    final left = _clamp(
      selected.center.dx - size / 2,
      0,
      _displaySize.width - size,
    );
    return Offset(left, _clamp(top, 0, _displaySize.height - size));
  }

  @override
  Widget build(BuildContext context) {
    if (!BugInspector.enabledFromEnvironment) return const SizedBox.shrink();
    final screenshot = widget.screenshot;
    final image = Image.memory(
      screenshot.pngBytes,
      fit: BoxFit.fill,
      gaplessPlayback: true,
      excludeFromSemantics: true,
    );
    final highlight = widget.highlight;
    final imageHighlight =
        highlight == null ? null : screenshot.toImageRect(highlight);

    return Semantics(
      container: true,
      image: true,
      label: widget.semanticLabel,
      child: AspectRatio(
        aspectRatio:
            screenshot.height == 0 ? 1 : screenshot.width / screenshot.height,
        child: LayoutBuilder(
          builder: (context, constraints) {
            _displaySize = constraints.biggest;
            return ListenableBuilder(
              listenable: widget.controller,
              child: image,
              builder: (context, image) {
                final controller = widget.controller;
                final selected = widget.readOnly ? null : controller.selected;
                Widget canvas = CustomPaint(
                  foregroundPainter: _AnnotationPainter(
                    annotations: controller.annotations,
                    selectedIndex:
                        widget.readOnly ? null : controller.selectedIndex,
                    scale: _scale,
                    color: widget.color,
                    strokeWidth: widget.strokeWidth,
                    highlight: imageHighlight,
                    highlightColor: widget.highlightColor,
                  ),
                  child: image,
                );
                if (!widget.readOnly) {
                  canvas = RawGestureDetector(
                    behavior: HitTestBehavior.opaque,
                    excludeFromSemantics: true,
                    gestures: <Type, GestureRecognizerFactory>{
                      _AnnotationDragRecognizer:
                          GestureRecognizerFactoryWithHandlers<
                              _AnnotationDragRecognizer>(
                        () => _AnnotationDragRecognizer(debugOwner: this),
                        (recognizer) => recognizer
                          ..onStart = _onDragStart
                          ..onUpdate = _onDragUpdate
                          ..onEnd = _onDragEnd
                          ..onCancel = _onDragCancel,
                      ),
                    },
                    child: canvas,
                  );
                }
                return Stack(
                  fit: StackFit.expand,
                  children: <Widget>[
                    canvas,
                    if (selected != null)
                      _deleteButton(_toDisplay(selected.rect)),
                  ],
                );
              },
            );
          },
        ),
      ),
    );
  }

  Widget _deleteButton(Rect selected) {
    final origin = _deleteButtonOrigin(selected);
    void delete() => widget.controller.removeSelected();
    return Positioned(
      left: origin.dx,
      top: origin.dy,
      width: _deleteButtonSize,
      height: _deleteButtonSize,
      child: Semantics(
        container: true,
        button: true,
        label: widget.deleteButtonLabel,
        excludeSemantics: true,
        onTap: delete,
        child: Material(
          color: widget.color,
          shape: const CircleBorder(
            side: BorderSide(color: Color(0xFFFFFFFF), width: 2),
          ),
          elevation: 2,
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            key: BugScreenshotEditor.deleteButtonKey,
            onTap: delete,
            child: const Icon(
              Icons.close,
              size: 18,
              color: Color(0xFFFFFFFF),
            ),
          ),
        ),
      ),
    );
  }
}

/// The corners of [rect], clockwise from the top left, so the opposite of
/// corner `i` is corner `(i + 2) % 4`.
List<Offset> _cornersOf(Rect rect) => <Offset>[
      rect.topLeft,
      rect.topRight,
      rect.bottomRight,
      rect.bottomLeft,
    ];

/// Like [num.clamp], but returns [max] instead of throwing when
/// `min > max`.
double _clamp(double value, double min, double max) =>
    math.min(math.max(value, min), max);

/// Takes every pointer that goes down on the editor right away, so a drag
/// starts without delay and is never taken by an enclosing scroll view.
class _AnnotationDragRecognizer extends OneSequenceGestureRecognizer {
  _AnnotationDragRecognizer({super.debugOwner});

  ValueChanged<Offset>? onStart;
  ValueChanged<Offset>? onUpdate;
  VoidCallback? onEnd;
  VoidCallback? onCancel;

  /// The pointer being followed. Other fingers are ignored meanwhile.
  int? _pointer;

  @override
  void addAllowedPointer(PointerDownEvent event) {
    if (_pointer != null) return;
    super.addAllowedPointer(event);
    _pointer = event.pointer;
    resolve(GestureDisposition.accepted);
    invokeCallback<void>('onStart', () => onStart?.call(event.localPosition));
  }

  @override
  void handleEvent(PointerEvent event) {
    if (event.pointer != _pointer) return;
    if (event is PointerMoveEvent) {
      invokeCallback<void>(
        'onUpdate',
        () => onUpdate?.call(event.localPosition),
      );
    } else if (event is PointerUpEvent) {
      _stop();
      invokeCallback<void>('onEnd', () => onEnd?.call());
    } else if (event is PointerCancelEvent) {
      _stop();
      invokeCallback<void>('onCancel', () => onCancel?.call());
    }
  }

  @override
  void rejectGesture(int pointer) {
    if (pointer != _pointer) return;
    _stop();
    invokeCallback<void>('onCancel', () => onCancel?.call());
  }

  void _stop() {
    final pointer = _pointer;
    _pointer = null;
    if (pointer != null) stopTrackingPointer(pointer);
  }

  @override
  void didStopTrackingLastPointer(int pointer) {}

  @override
  String get debugDescription => 'screenshot annotation drag';
}

class _AnnotationPainter extends CustomPainter {
  _AnnotationPainter({
    required this.annotations,
    required this.selectedIndex,
    required this.scale,
    required this.color,
    required this.strokeWidth,
    required this.highlight,
    required this.highlightColor,
  });

  static const double _handleRadius = 6;
  static const double _dashLength = 6;
  static const double _dashGap = 4;

  final List<BugScreenshotAnnotation> annotations;
  final int? selectedIndex;
  final double scale;
  final Color color;
  final double strokeWidth;
  final Rect? highlight;
  final Color highlightColor;

  Rect _toDisplay(Rect rect) => Rect.fromLTRB(
        rect.left * scale,
        rect.top * scale,
        rect.right * scale,
        rect.bottom * scale,
      );

  @override
  void paint(Canvas canvas, Size size) {
    final highlight = this.highlight;
    if (highlight != null) {
      _paintDashedRect(
        canvas,
        _toDisplay(highlight),
        Paint()
          ..color = highlightColor
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2,
      );
    }

    final stroke = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;
    for (var i = 0; i < annotations.length; i++) {
      final rect = _toDisplay(annotations[i].rect);
      if (i == selectedIndex) {
        canvas.drawRect(rect, Paint()..color = color.withAlpha(0x33));
      }
      canvas.drawRect(rect, stroke);
    }

    final selected = selectedIndex;
    if (selected == null || selected >= annotations.length) return;
    final fill = Paint()..color = const Color(0xFFFFFFFF);
    final outline = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    for (final corner in _cornersOf(_toDisplay(annotations[selected].rect))) {
      canvas
        ..drawCircle(corner, _handleRadius, fill)
        ..drawCircle(corner, _handleRadius, outline);
    }
  }

  void _paintDashedRect(Canvas canvas, Rect rect, Paint paint) {
    final corners = _cornersOf(rect);
    for (var i = 0; i < corners.length; i++) {
      final from = corners[i];
      final to = corners[(i + 1) % corners.length];
      final length = (to - from).distance;
      if (length == 0) continue;
      final direction = (to - from) / length;
      for (var start = 0.0; start < length; start += _dashLength + _dashGap) {
        final end = math.min(start + _dashLength, length);
        canvas.drawLine(
            from + direction * start, from + direction * end, paint);
      }
    }
  }

  @override
  bool shouldRepaint(_AnnotationPainter oldDelegate) =>
      !listEquals(oldDelegate.annotations, annotations) ||
      oldDelegate.selectedIndex != selectedIndex ||
      oldDelegate.scale != scale ||
      oldDelegate.color != color ||
      oldDelegate.strokeWidth != strokeWidth ||
      oldDelegate.highlight != highlight ||
      oldDelegate.highlightColor != highlightColor;
}
