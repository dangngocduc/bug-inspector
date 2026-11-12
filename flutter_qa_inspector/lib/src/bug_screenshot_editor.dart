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
/// * Pinch with two fingers to zoom in, up to [maxZoom], and move them to pan
///   the zoomed image. A second finger undoes what the first one was drawing,
///   moving or resizing, and the fingers zoom until they are all lifted. While
///   zoomed in, the button in the bottom right corner shows the zoom and
///   resets it.
///
/// The [BugScreenshot.statusBar], if any, is drawn over the top of the
/// image, like in [BugScreenshot.toAnnotatedPng].
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
    this.resetZoomButtonLabel = defaultResetZoomButtonLabel,
    this.maxZoom = defaultMaxZoom,
  }) : assert(maxZoom >= 1, 'maxZoom must be at least 1');

  /// The default color of the rectangles.
  static const Color defaultColor = Color(0xFFFF6D00);

  /// The default stroke width of the rectangles, in logical pixels.
  static const double defaultStrokeWidth = 3;

  /// The default [semanticLabel].
  static const String defaultSemanticLabel = 'Bug screenshot';

  /// The default [deleteButtonLabel].
  static const String defaultDeleteButtonLabel = 'Delete rectangle';

  /// The default [resetZoomButtonLabel].
  static const String defaultResetZoomButtonLabel = 'Reset zoom';

  /// The default [maxZoom].
  static const double defaultMaxZoom = 5;

  /// The key of the button that deletes the selected rectangle, for widget
  /// tests and integration tests.
  static const Key deleteButtonKey =
      ValueKey<String>('bug_screenshot_editor.delete');

  /// The key of the button that resets the zoom, shown while zoomed in, for
  /// widget tests and integration tests.
  static const Key resetZoomButtonKey =
      ValueKey<String>('bug_screenshot_editor.reset_zoom');

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

  /// The stroke width of the rectangles, in logical pixels on screen, at any
  /// zoom.
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

  /// What a screen reader says for the button that resets the zoom.
  final String resetZoomButtonLabel;

  /// How far two fingers can zoom in: 2 shows the image twice as large as
  /// it fits in the editor. 1 turns zooming off, and a second finger is then
  /// ignored.
  final double maxZoom;

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

  /// A pinch that ends closer to the fit than this goes back to it.
  static const double _zoomSnap = 1.05;

  /// The size of the editor, in logical pixels: where the image is shown,
  /// whole when not zoomed in.
  Size _displaySize = Size.zero;

  /// How many times larger than its fit the image is shown, from 1 to
  /// [BugScreenshotEditor.maxZoom].
  double _zoom = 1;

  /// The image pixel at the top left corner of the editor.
  Offset _viewOrigin = Offset.zero;

  /// The image pixel under the fingers when the pinch started, which stays
  /// under them.
  Offset _pinchAnchor = Offset.zero;
  double _pinchStartZoom = 1;

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

  /// Logical pixels on screen per image pixel when the whole image fits.
  double get _fitScale =>
      _screenshot.width == 0 ? 1 : _displaySize.width / _screenshot.width;

  /// Logical pixels on screen per image pixel at the current zoom.
  double get _scale => _fitScale * _zoom;

  double get _maxZoom => widget.readOnly ? 1 : widget.maxZoom;

  @override
  void didUpdateWidget(BugScreenshotEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.readOnly ||
        oldWidget.controller != widget.controller ||
        oldWidget.screenshot != widget.screenshot) {
      _resetDrag();
    }
    if (oldWidget.screenshot != widget.screenshot) {
      _zoom = 1;
      _viewOrigin = Offset.zero;
    } else if (_zoom > _maxZoom) {
      _zoom = _maxZoom;
      _viewOrigin = _clampOrigin(_viewOrigin, _zoom);
    }
  }

  Rect _toDisplay(Rect imageRect) {
    final scale = _scale;
    final origin = _viewOrigin;
    return Rect.fromLTRB(
      (imageRect.left - origin.dx) * scale,
      (imageRect.top - origin.dy) * scale,
      (imageRect.right - origin.dx) * scale,
      (imageRect.bottom - origin.dy) * scale,
    );
  }

  Offset _toImage(Offset displayPoint) {
    final scale = _scale;
    return Offset(displayPoint.dx / scale, displayPoint.dy / scale) +
        _viewOrigin;
  }

  /// [origin] moved so that the editor, at [zoom], shows only the image.
  Offset _clampOrigin(Offset origin, double zoom) {
    final size = _imageSize;
    return Offset(
      _clamp(origin.dx, 0, size.width - size.width / zoom),
      _clamp(origin.dy, 0, size.height - size.height / zoom),
    );
  }

  void _onPinchStart(Offset focal) {
    if (_displaySize.isEmpty) return;
    _pinchAnchor = _toImage(focal);
    _pinchStartZoom = _zoom;
  }

  void _onPinchUpdate(Offset focal, double scale) {
    if (_displaySize.isEmpty) return;
    final zoom = _clamp(_pinchStartZoom * scale, 1, _maxZoom);
    final zoomScale = _fitScale * zoom;
    final origin = _clampOrigin(
      _pinchAnchor - Offset(focal.dx / zoomScale, focal.dy / zoomScale),
      zoom,
    );
    if (zoom == _zoom && origin == _viewOrigin) return;
    setState(() {
      _zoom = zoom;
      _viewOrigin = origin;
    });
  }

  void _onPinchEnd() {
    if (_zoom < _zoomSnap) _resetZoom();
  }

  void _resetZoom() {
    if (_zoom == 1 && _viewOrigin == Offset.zero) return;
    setState(() {
      _zoom = 1;
      _viewOrigin = Offset.zero;
    });
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
    Widget image = Image.memory(
      screenshot.pngBytes,
      fit: BoxFit.fill,
      gaplessPlayback: true,
      excludeFromSemantics: true,
    );
    final statusBar = screenshot.statusBar;
    if (statusBar != null && screenshot.pixelRatio > 0) {
      // Part of the image: it zooms with it, under the rectangles.
      image = CustomPaint(
        foregroundPainter: _StatusBarPainter(
          statusBar,
          contentWidth: screenshot.width / screenshot.pixelRatio,
        ),
        child: image,
      );
    }
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
                final selectedRect =
                    selected == null ? null : _toDisplay(selected.rect);
                final scale = _scale;
                Widget canvas = CustomPaint(
                  foregroundPainter: _AnnotationPainter(
                    annotations: controller.annotations,
                    selectedIndex:
                        widget.readOnly ? null : controller.selectedIndex,
                    scale: scale,
                    origin: _viewOrigin,
                    color: widget.color,
                    strokeWidth: widget.strokeWidth,
                    highlight: imageHighlight,
                    highlightColor: widget.highlightColor,
                  ),
                  child: ClipRect(
                    child: Transform(
                      transform: Matrix4.diagonal3Values(_zoom, _zoom, 1)
                        ..setTranslationRaw(
                          -_viewOrigin.dx * scale,
                          -_viewOrigin.dy * scale,
                          0,
                        ),
                      child: image,
                    ),
                  ),
                );
                if (!widget.readOnly) {
                  canvas = RawGestureDetector(
                    behavior: HitTestBehavior.opaque,
                    excludeFromSemantics: true,
                    gestures: <Type, GestureRecognizerFactory>{
                      _EditorGestureRecognizer:
                          GestureRecognizerFactoryWithHandlers<
                              _EditorGestureRecognizer>(
                        () => _EditorGestureRecognizer(debugOwner: this),
                        (recognizer) => recognizer
                          ..pinchEnabled = _maxZoom > 1
                          ..onDragStart = _onDragStart
                          ..onDragUpdate = _onDragUpdate
                          ..onDragEnd = _onDragEnd
                          ..onDragCancel = _onDragCancel
                          ..onPinchStart = _onPinchStart
                          ..onPinchUpdate = _onPinchUpdate
                          ..onPinchEnd = _onPinchEnd,
                      ),
                    },
                    child: canvas,
                  );
                }
                return Stack(
                  fit: StackFit.expand,
                  children: <Widget>[
                    canvas,
                    // Not for a rectangle zoomed out of view.
                    if (selectedRect != null &&
                        selectedRect.overlaps(Offset.zero & _displaySize))
                      _deleteButton(selectedRect),
                    if (_zoom > 1) _resetZoomButton(),
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
      // Keyed, so that the buttons never swap their Material, which would
      // animate from the look of one to the other.
      key: const ValueKey<String>('delete'),
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

  Widget _resetZoomButton() {
    const white = Color(0xFFFFFFFF);
    return Positioned(
      key: const ValueKey<String>('reset_zoom'),
      right: 8,
      bottom: 8,
      child: Semantics(
        container: true,
        button: true,
        label: widget.resetZoomButtonLabel,
        excludeSemantics: true,
        onTap: _resetZoom,
        child: Material(
          color: const Color(0xB3000000),
          shape: const StadiumBorder(),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            key: BugScreenshotEditor.resetZoomButtonKey,
            onTap: _resetZoom,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(8, 6, 10, 6),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  const Icon(Icons.zoom_out_map, size: 16, color: white),
                  const SizedBox(width: 4),
                  Text(
                    '${_zoom.toStringAsFixed(1)}×',
                    style: const TextStyle(
                      color: white,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
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
///
/// One finger drags. When a second one goes down, the drag is cancelled and
/// the fingers pinch until they are all lifted: a finger left alone after a
/// pinch pans, it never starts a drag.
class _EditorGestureRecognizer extends OneSequenceGestureRecognizer {
  _EditorGestureRecognizer({super.debugOwner});

  /// Whether a second finger pinches. When `false`, it is ignored.
  bool pinchEnabled = true;

  ValueChanged<Offset>? onDragStart;
  ValueChanged<Offset>? onDragUpdate;
  VoidCallback? onDragEnd;
  VoidCallback? onDragCancel;

  /// The fingers of the pinch changed. Later updates are relative to here,
  /// the center of the fingers.
  ValueChanged<Offset>? onPinchStart;

  /// The center of the fingers and how much farther apart they are than at
  /// the last [onPinchStart]. One finger only pans, with a scale of 1.
  void Function(Offset focal, double scale)? onPinchUpdate;
  VoidCallback? onPinchEnd;

  /// Where each finger is, in local coordinates.
  final Map<int, Offset> _positions = <int, Offset>{};

  /// The finger dragging, if no other has gone down since it did.
  int? _dragPointer;
  bool _pinching = false;

  /// How far the fingers were from their center at the last [onPinchStart].
  double _startSpan = 0;

  @override
  void addAllowedPointer(PointerDownEvent event) {
    if (_positions.isNotEmpty && !pinchEnabled) return;
    super.addAllowedPointer(event);
    resolvePointer(event.pointer, GestureDisposition.accepted);
    _positions[event.pointer] = event.localPosition;
    if (_positions.length == 1) {
      _dragPointer = event.pointer;
      invokeCallback<void>(
        'onDragStart',
        () => onDragStart?.call(event.localPosition),
      );
      return;
    }
    if (_dragPointer != null) {
      _dragPointer = null;
      invokeCallback<void>('onDragCancel', () => onDragCancel?.call());
    }
    _startPinch();
  }

  @override
  void handleEvent(PointerEvent event) {
    final pointer = event.pointer;
    if (!_positions.containsKey(pointer)) return;
    if (event is PointerMoveEvent) {
      _positions[pointer] = event.localPosition;
      if (pointer == _dragPointer) {
        invokeCallback<void>(
          'onDragUpdate',
          () => onDragUpdate?.call(event.localPosition),
        );
      } else if (_pinching) {
        _updatePinch();
      }
    } else if (event is PointerUpEvent) {
      _remove(pointer, cancelled: false);
    } else if (event is PointerCancelEvent) {
      _remove(pointer, cancelled: true);
    }
  }

  @override
  void rejectGesture(int pointer) {
    if (_positions.containsKey(pointer)) _remove(pointer, cancelled: true);
  }

  void _remove(int pointer, {required bool cancelled}) {
    _positions.remove(pointer);
    stopTrackingPointer(pointer);
    if (pointer == _dragPointer) {
      _dragPointer = null;
      if (cancelled) {
        invokeCallback<void>('onDragCancel', () => onDragCancel?.call());
      } else {
        invokeCallback<void>('onDragEnd', () => onDragEnd?.call());
      }
    } else if (_pinching) {
      if (_positions.isEmpty) {
        _pinching = false;
        invokeCallback<void>('onPinchEnd', () => onPinchEnd?.call());
      } else {
        _startPinch();
      }
    }
  }

  Offset get _focal {
    var sum = Offset.zero;
    for (final position in _positions.values) {
      sum += position;
    }
    return sum / _positions.length.toDouble();
  }

  /// The mean distance of the fingers from [focal]: 0 for one finger.
  double _spanAround(Offset focal) {
    var sum = 0.0;
    for (final position in _positions.values) {
      sum += (position - focal).distance;
    }
    return sum / _positions.length;
  }

  void _startPinch() {
    _pinching = true;
    final focal = _focal;
    _startSpan = _spanAround(focal);
    invokeCallback<void>('onPinchStart', () => onPinchStart?.call(focal));
  }

  void _updatePinch() {
    final focal = _focal;
    final span = _spanAround(focal);
    final scale = _startSpan > 0 && span > 0 ? span / _startSpan : 1.0;
    invokeCallback<void>(
      'onPinchUpdate',
      () => onPinchUpdate?.call(focal, scale),
    );
  }

  @override
  void didStopTrackingLastPointer(int pointer) {}

  @override
  String get debugDescription => 'screenshot editor gesture';
}

class _AnnotationPainter extends CustomPainter {
  _AnnotationPainter({
    required this.annotations,
    required this.selectedIndex,
    required this.scale,
    required this.origin,
    required this.color,
    required this.strokeWidth,
    required this.highlight,
    required this.highlightColor,
  });

  static const double _handleRadius = 6;
  static const double _highlightStrokeWidth = 2;
  static const double _dashLength = 6;
  static const double _dashGap = 4;

  final List<BugScreenshotAnnotation> annotations;
  final int? selectedIndex;

  /// Logical pixels on screen per image pixel.
  final double scale;

  /// The image pixel at the top left corner.
  final Offset origin;
  final Color color;
  final double strokeWidth;
  final Rect? highlight;
  final Color highlightColor;

  Rect _toDisplay(Rect rect) => Rect.fromLTRB(
        (rect.left - origin.dx) * scale,
        (rect.top - origin.dy) * scale,
        (rect.right - origin.dx) * scale,
        (rect.bottom - origin.dy) * scale,
      );

  @override
  void paint(Canvas canvas, Size size) {
    final bounds = Offset.zero & size;
    canvas
      ..save()
      // Zoomed in, rectangles go past the editor. The margin keeps the
      // strokes on the edges of the image whole.
      ..clipRect(bounds.inflate(
        math.max(strokeWidth, _highlightStrokeWidth) / 2,
      ));
    final highlight = this.highlight;
    if (highlight != null) {
      _paintDashedRect(
        canvas,
        _toDisplay(highlight),
        Paint()
          ..color = highlightColor
          ..style = PaintingStyle.stroke
          ..strokeWidth = _highlightStrokeWidth,
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
    canvas.restore();

    final selected = selectedIndex;
    if (selected == null || selected >= annotations.length) return;
    final fill = Paint()..color = const Color(0xFFFFFFFF);
    final outline = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    // Corners on the edges stay, despite rounding; those out of view do not.
    final visible = bounds.inflate(1);
    for (final corner in _cornersOf(_toDisplay(annotations[selected].rect))) {
      if (!visible.contains(corner)) continue;
      canvas
        ..drawCircle(corner, _handleRadius, fill)
        ..drawCircle(corner, _handleRadius, outline);
    }
  }

  /// Strokes [rect] with dashes [unit] times as long as on screen, for
  /// example `pixelRatio` in an image. [BugScreenshot.toAnnotatedPng] draws
  /// the highlight with it too.
  static void _paintDashedRect(
    Canvas canvas,
    Rect rect,
    Paint paint, {
    double unit = 1,
  }) {
    final dash = _dashLength * unit;
    final step = (_dashLength + _dashGap) * unit;
    final corners = _cornersOf(rect);
    for (var i = 0; i < corners.length; i++) {
      final from = corners[i];
      final to = corners[(i + 1) % corners.length];
      final length = (to - from).distance;
      if (length == 0) continue;
      final direction = (to - from) / length;
      for (var start = 0.0; start < length; start += step) {
        final end = math.min(start + dash, length);
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
      oldDelegate.origin != origin ||
      oldDelegate.color != color ||
      oldDelegate.strokeWidth != strokeWidth ||
      oldDelegate.highlight != highlight ||
      oldDelegate.highlightColor != highlightColor;
}
