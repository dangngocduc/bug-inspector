part of '../flutter_qa_inspector.dart';

/// Marks [child] as a widget the tester can select while the nearest
/// [BugInspector] is in [InspectMode.selecting].
///
/// While selecting, a border is painted on top of [child]. The border does not
/// change the size, padding or hit testing of [child].
///
/// Without `--dart-define=FLUTTER_QA_INSPECTOR=true`, or outside an enabled
/// [BugInspector], this widget only returns [child] and registers nothing.
///
/// Use a stable [id] such as `home.quick_add_water` and a [sourceFile]
/// relative to the repository root.
///
/// For `Expanded`, `Flexible` and `Positioned`, put the [BugInspectable] inside
/// their `child`. In a sliver list, put it inside `SliverToBoxAdapter` or the
/// item builder.
///
/// To make a whole screen selectable, use [BugInspectablePage].
class BugInspectable extends StatelessWidget implements _InspectableNodeWidget {
  /// Creates an inspectable wrapper around [child].
  const BugInspectable({
    super.key,
    required this.id,
    required this.child,
    this.label,
    this.sourceFile,
    this.sourceLine,
    this.borderColor,
    this.borderWidth,
  }) : assert(borderWidth == null || borderWidth >= 0);

  /// A stable identifier stored in [BugWidgetSelection.id].
  @override
  final String id;

  /// An optional human readable name stored in [BugWidgetSelection.label].
  @override
  final String? label;

  /// The file that builds [child], relative to the repository root.
  @override
  final String? sourceFile;

  /// The line in [sourceFile] that builds [child].
  @override
  final int? sourceLine;

  /// The border color. Defaults to [BugInspector.borderColor].
  @override
  final Color? borderColor;

  /// The border width in logical pixels. Defaults to
  /// [BugInspector.borderWidth].
  @override
  final double? borderWidth;

  /// The inspected widget.
  @override
  final Widget child;

  @override
  Widget build(BuildContext context) {
    // A constant: without the define, the compiler drops the node.
    if (!BugInspector.enabledFromEnvironment) return child;
    return _InspectableNodeHost(node: this, kind: BugSelectionKind.widget);
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    _debugFillNodeProperties(this, properties);
  }
}

/// What [BugInspectable] and [BugInspectablePage] have in common.
abstract interface class _InspectableNodeWidget {
  String get id;
  String? get label;
  String? get sourceFile;
  int? get sourceLine;
  Color? get borderColor;
  double? get borderWidth;
  Widget get child;
}

void _debugFillNodeProperties(
  _InspectableNodeWidget node,
  DiagnosticPropertiesBuilder properties,
) {
  properties
    ..add(StringProperty('id', node.id))
    ..add(StringProperty('label', node.label, defaultValue: null))
    ..add(StringProperty('sourceFile', node.sourceFile, defaultValue: null))
    ..add(IntProperty('sourceLine', node.sourceLine, defaultValue: null));
}

/// The running part of a [BugInspectable] or [BugInspectablePage], only
/// built when the inspector is compiled in.
class _InspectableNodeHost extends StatefulWidget {
  const _InspectableNodeHost({required this.node, required this.kind});

  final _InspectableNodeWidget node;
  final BugSelectionKind kind;

  @override
  State<_InspectableNodeHost> createState() => _InspectableNode();
}

/// Registers the node with the nearest [BugInspector], paints its border and
/// captures its selection.
class _InspectableNode extends State<_InspectableNodeHost> {
  BugSelectionKind get _kind => widget.kind;

  _InspectableNodeWidget get _node => widget.node;

  bool get _isPage => _kind == BugSelectionKind.page;

  final GlobalKey _boxKey = GlobalKey(debugLabel: 'BugInspectable');
  _BugInspectorRegistry? _registry;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final registry = _BugInspectorScope.maybeOf(context)?.registry;
    if (!identical(registry, _registry)) {
      _registry?.unregister(this);
      _registry = registry;
      registry?.register(this);
    }
  }

  @override
  void dispose() {
    _registry?.unregister(this);
    _registry = null;
    super.dispose();
  }

  /// The laid out and attached render object of this node, if any.
  _RenderBugInspectable? get _renderBox {
    final renderObject = _boxKey.currentContext?.findRenderObject();
    if (renderObject is! _RenderBugInspectable ||
        !renderObject.attached ||
        !renderObject.hasSize) {
      return null;
    }
    return renderObject;
  }

  /// The number of ancestors of this element.
  int _depth() {
    var depth = 0;
    context.visitAncestorElements((_) {
      depth++;
      return true;
    });
    return depth;
  }

  /// The name shown on the page button: the label, or the id.
  String get _displayName => _node.label ?? _node.id;

  /// The context of the [BugInspectable] or [BugInspectablePage] itself, the
  /// parent of this node.
  BuildContext get _markerContext {
    BuildContext marker = context;
    context.visitAncestorElements((parent) {
      marker = parent;
      return false;
    });
    return marker;
  }

  BugWidgetSelection _createSelection({
    required Rect bounds,
    required DateTime capturedAtUtc,
    required List<BugStateRecord> stateHistory,
  }) {
    final node = _node;
    final context = _markerContext;
    return BugWidgetSelection(
      kind: _kind,
      id: node.id,
      widgetType: node.child.runtimeType.toString(),
      label: node.label,
      sourceFile: node.sourceFile,
      sourceLine: node.sourceLine,
      routeName: ModalRoute.of(context)?.settings.name,
      bounds: bounds,
      capturedAtUtc: capturedAtUtc,
      blocs: _captureBlocSnapshots(context, includeDescendants: _isPage),
      widgetStates: _captureWidgetStates(context),
      stateHistory: stateHistory,
    );
  }

  @override
  Widget build(BuildContext context) {
    final scope = _BugInspectorScope.maybeOf(context);
    final node = _node;
    if (scope == null) return node.child;

    return BlocSelector<InspectModeCubit, InspectMode, bool>(
      bloc: scope.modeCubit,
      selector: (mode) => mode == InspectMode.selecting,
      builder: (context, selecting) => _BugInspectableBox(
        key: _boxKey,
        showBorder: selecting,
        borderColor: node.borderColor ??
            (_isPage ? scope.pageBorderColor : scope.borderColor),
        borderWidth: node.borderWidth ??
            (_isPage ? scope.pageBorderWidth : scope.borderWidth),
        child: node.child,
      ),
    );
  }
}

/// Paints the inspect border in the foreground of its child.
class _BugInspectableBox extends SingleChildRenderObjectWidget {
  const _BugInspectableBox({
    super.key,
    required this.showBorder,
    required this.borderColor,
    required this.borderWidth,
    super.child,
  });

  final bool showBorder;
  final Color borderColor;
  final double borderWidth;

  @override
  _RenderBugInspectable createRenderObject(BuildContext context) {
    return _RenderBugInspectable(
      showBorder: showBorder,
      borderColor: borderColor,
      borderWidth: borderWidth,
    );
  }

  @override
  void updateRenderObject(
    BuildContext context,
    _RenderBugInspectable renderObject,
  ) {
    renderObject
      ..showBorder = showBorder
      ..borderColor = borderColor
      ..borderWidth = borderWidth;
  }
}

/// A proxy box that paints a border over its child.
///
/// Unlike a foreground `DecoratedBox`, it never reports a hit by itself, so
/// wrapping a widget does not change which widget receives a tap.
///
/// It also tracks whether it has been painted since the border was shown and
/// reports when a hit test reaches it during a selection probe. The inspector
/// uses both to skip widgets that are offstage, hidden or covered.
class _RenderBugInspectable extends RenderProxyBox {
  _RenderBugInspectable({
    required bool showBorder,
    required Color borderColor,
    required double borderWidth,
  })  : _showBorder = showBorder,
        _borderColor = borderColor,
        _borderWidth = borderWidth;

  bool get showBorder => _showBorder;
  bool _showBorder;
  set showBorder(bool value) {
    if (value == _showBorder) return;
    _showBorder = value;
    _paintedWithBorder = false;
    markNeedsPaint();
  }

  Color get borderColor => _borderColor;
  Color _borderColor;
  set borderColor(Color value) {
    if (value == _borderColor) return;
    _borderColor = value;
    if (_showBorder) markNeedsPaint();
  }

  double get borderWidth => _borderWidth;
  double _borderWidth;
  set borderWidth(double value) {
    if (value == _borderWidth) return;
    _borderWidth = value;
    if (_showBorder) markNeedsPaint();
  }

  bool _paintedWithBorder = false;

  /// Whether the border is shown and this box was painted since then, which
  /// means it is part of what is currently on screen.
  bool get paintedWithBorder => _showBorder && _paintedWithBorder;

  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    // A re-attached subtree may end up somewhere that is not painted.
    _paintedWithBorder = false;
    if (_showBorder) markNeedsPaint();
  }

  @override
  bool hitTest(BoxHitTestResult result, {required Offset position}) {
    final probe = _activeHitProbe;
    if (probe != null && size.contains(position)) probe.add(this);
    return super.hitTest(result, position: position);
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    super.paint(context, offset);
    if (!_showBorder) return;
    _paintedWithBorder = true;

    final strokeWidth = math.min(_borderWidth, size.shortestSide);
    if (strokeWidth <= 0) return;
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..color = _borderColor;
    context.canvas.drawRect((offset & size).deflate(strokeWidth / 2), paint);
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties
      ..add(FlagProperty('showBorder', value: _showBorder, ifTrue: 'border'))
      ..add(ColorProperty('borderColor', _borderColor))
      ..add(DoubleProperty('borderWidth', _borderWidth));
  }
}
