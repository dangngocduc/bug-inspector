part of '../flutter_qa_inspector.dart';

/// Called when the tester selects a [BugInspectable] or a
/// [BugInspectablePage].
///
/// [widgetContext] is the context of the selected widget or page. Use it right away to
/// find the widget's `Navigator`, for example to open a bug report form. After
/// an `await`, check `widgetContext.mounted` before using it again.
typedef BugWidgetSelectedCallback = void Function(
  BuildContext widgetContext,
  BugWidgetSelection selection,
);

/// Builds the button that leaves [InspectMode.selecting]. Call [exit] to
/// leave the mode.
typedef BugExitButtonBuilder = Widget Function(
  BuildContext context,
  VoidCallback exit,
);

/// Which part of a tap selects a widget.
enum BugSelectionTrigger {
  /// Select when the pointer goes down. Faster, but a drag that starts on a
  /// widget also selects it.
  tapDown,

  /// Select when Flutter has recognized a tap, after the pointer goes up.
  tapUp,
}

/// Hosts the bug inspector for [child].
///
/// Put it in `MaterialApp.builder` (or `MaterialApp.router` with a `builder`)
/// and pass the builder's child through, so the Navigator or Router keeps
/// working:
///
/// ```dart
/// MaterialApp(
///   builder: (context, child) => BugInspector(
///     stateRecorder: recorder,
///     onWidgetSelected: (widgetContext, selection) {
///       // Open the bug report form with selection.toJson().
///     },
///     child: child ?? const SizedBox.shrink(),
///   ),
/// )
/// ```
///
/// The host provides an [InspectModeCubit] to its subtree. When the mode is
/// [InspectMode.selecting], every [BugInspectable] below the host gets a
/// border, the app content stops receiving pointer input (taps, scrolls and
/// hovers), and the next tap inside a border calls [onWidgetSelected]. A tap
/// outside every widget border keeps the mode, unless
/// [selectPageOnEmptyTap] is set.
///
/// Every [BugInspectablePage] gets a page border, and a floating button
/// selects the current page. The tester can drag the button out of the way.
class BugInspector extends StatefulWidget {
  /// Creates an inspector host.
  const BugInspector({
    super.key,
    required this.child,
    required this.onWidgetSelected,
    this.modeCubit,
    this.stateRecorder,
    this.historyWindow = defaultHistoryWindow,
    this.disableModeOnSelection = true,
    this.selectionTrigger = BugSelectionTrigger.tapUp,
    this.showExitButton = true,
    this.exitButtonLabel = defaultExitButtonLabel,
    this.exitButtonAlignment = Alignment.topCenter,
    this.exitButtonBuilder,
    this.borderColor = defaultBorderColor,
    this.borderWidth = defaultBorderWidth,
    this.showPageButton = true,
    this.pageButtonLabel = defaultPageButtonLabel,
    this.pageButtonAlignment = AlignmentDirectional.bottomEnd,
    this.selectPageOnEmptyTap = false,
    this.pageBorderColor = defaultPageBorderColor,
    this.pageBorderWidth = defaultPageBorderWidth,
  })  : assert(borderWidth >= 0),
        assert(pageBorderWidth >= 0);

  /// The default value of [historyWindow].
  static const Duration defaultHistoryWindow = Duration(seconds: 30);

  /// The default value of [borderColor].
  static const Color defaultBorderColor = Color(0xFFFF2D78);

  /// The default value of [borderWidth].
  static const double defaultBorderWidth = 2;

  /// The default value of [exitButtonLabel].
  static const String defaultExitButtonLabel = 'Tap a highlighted widget';

  /// The default value of [pageButtonLabel].
  static const String defaultPageButtonLabel = 'Select screen';

  /// The default value of [pageBorderColor].
  static const Color defaultPageBorderColor = Color(0xFF2979FF);

  /// The default value of [pageBorderWidth].
  static const double defaultPageBorderWidth = 4;

  /// The app content, usually the child of `MaterialApp.builder`.
  final Widget child;

  /// Called after the tester selected a widget.
  final BugWidgetSelectedCallback onWidgetSelected;

  /// The cubit that controls the mode.
  ///
  /// When `null`, the host creates and closes its own cubit. When given, the
  /// caller owns it, can call [InspectModeCubit.enable] from outside the host
  /// and must close it. Use the same instance for the host, the borders and
  /// the QA menu.
  final InspectModeCubit? modeCubit;

  /// The recorder that keeps the state timeline. Pass the same instance to
  /// [BugInspectorBlocObserver]. When `null`, selections have an empty
  /// [BugWidgetSelection.stateHistory].
  final BugStateRecorder? stateRecorder;

  /// How far back [BugWidgetSelection.stateHistory] goes.
  final Duration historyWindow;

  /// Whether to switch to [InspectMode.disabled] right after a widget is
  /// selected, before [onWidgetSelected] is called.
  ///
  /// When `false`, disable the mode before opening a form in the Navigator
  /// below the host, otherwise the inspector keeps intercepting taps.
  final bool disableModeOnSelection;

  /// Which part of a tap selects a widget.
  final BugSelectionTrigger selectionTrigger;

  /// Whether to show a button that leaves the mode while selecting.
  final bool showExitButton;

  /// The text of the default exit button.
  final String exitButtonLabel;

  /// Where the exit button is placed, inside the safe area.
  final AlignmentGeometry exitButtonAlignment;

  /// Replaces the default exit button.
  final BugExitButtonBuilder? exitButtonBuilder;

  /// The default border color of the [BugInspectable]s below this host.
  final Color borderColor;

  /// The default border width of the [BugInspectable]s below this host.
  final double borderWidth;

  /// Whether to show the floating button that selects the current
  /// [BugInspectablePage] while selecting.
  ///
  /// The button only appears when a page is on screen. Its subtitle names the
  /// page it will select.
  final bool showPageButton;

  /// The title of the page button.
  final String pageButtonLabel;

  /// Where the page button starts, inside the safe area. The tester can drag
  /// it elsewhere, and the host remembers the new position.
  final AlignmentGeometry pageButtonAlignment;

  /// Whether a tap outside every [BugInspectable] selects the
  /// [BugInspectablePage] under the tap.
  ///
  /// Off by default, so a tap that misses a widget keeps the mode instead of
  /// reporting the whole page.
  final bool selectPageOnEmptyTap;

  /// The default border color of the [BugInspectablePage]s below this host.
  final Color pageBorderColor;

  /// The default border width of the [BugInspectablePage]s below this host.
  final double pageBorderWidth;

  /// Returns the [InspectModeCubit] of the nearest host, or `null` when
  /// [context] is not below a [BugInspector].
  ///
  /// Useful to show a QA menu entry only when the inspector is present.
  static InspectModeCubit? maybeModeCubitOf(BuildContext context) {
    return _BugInspectorScope.maybeOf(context)?.modeCubit;
  }

  /// Captures the app content of the nearest host as a PNG.
  ///
  /// The capture covers the [child] of the host, without the inspector's own
  /// overlay. [pixelRatio] defaults to the device pixel ratio. When
  /// [waitForNextFrame] is `true`, the capture waits for the next frame so that
  /// a mode change made just before, such as the borders being removed after a
  /// selection, is visible in the image.
  ///
  /// Capture before opening a form on top of the content. Returns `null` when
  /// [context] is not below a [BugInspector] or the content cannot be
  /// captured.
  static Future<BugScreenshot?> captureScreenshot(
    BuildContext context, {
    double? pixelRatio,
    bool waitForNextFrame = true,
  }) {
    return _captureScreenshot(
      context,
      pixelRatio: pixelRatio,
      waitForNextFrame: waitForNextFrame,
    );
  }

  @override
  State<BugInspector> createState() => _BugInspectorState();
}

class _BugInspectorState extends State<BugInspector> {
  final _BugInspectorRegistry _registry = _BugInspectorRegistry();
  InspectModeCubit? _ownedModeCubit;

  /// Where the tester dragged the page button, kept across mode changes.
  Alignment? _pageButtonAlignment;

  InspectModeCubit get _modeCubit => widget.modeCubit ?? _ownedModeCubit!;

  @override
  void initState() {
    super.initState();
    if (widget.modeCubit == null) _ownedModeCubit = InspectModeCubit();
  }

  @override
  void didUpdateWidget(BugInspector oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.modeCubit != null) {
      _closeOwnedModeCubit();
    } else {
      _ownedModeCubit ??= InspectModeCubit();
    }
  }

  @override
  void dispose() {
    _closeOwnedModeCubit();
    super.dispose();
  }

  void _closeOwnedModeCubit() {
    final cubit = _ownedModeCubit;
    _ownedModeCubit = null;
    if (cubit != null) unawaited(cubit.close());
  }

  void _handleTapDown(TapDownDetails details) =>
      _select(details.globalPosition);

  void _handleTapUp(TapUpDetails details) => _select(details.globalPosition);

  RenderBox? get _content {
    final content = _registry.contentKey.currentContext?.findRenderObject();
    if (content is! RenderBox || !content.attached || !content.hasSize) {
      return null;
    }
    return content;
  }

  void _select(Offset globalPosition) {
    if (!_modeCubit.isSelecting) return;
    final content = _content;
    if (content == null) return;

    final nodes = _registry.nodes;
    final candidate = _resolveSelection(
          nodes: nodes,
          content: content,
          globalPosition: globalPosition,
        ) ??
        (widget.selectPageOnEmptyTap
            ? _resolveCurrentPage(
                nodes: nodes,
                content: content,
                globalPosition: globalPosition,
              )
            : null);
    // A tap outside every inspectable keeps the mode.
    if (candidate != null) _capture(candidate);
  }

  _InspectableCandidate? _currentPage() {
    final content = _content;
    if (content == null) return null;
    return _resolveCurrentPage(nodes: _registry.nodes, content: content);
  }

  void _selectCurrentPage() {
    if (!_modeCubit.isSelecting) return;
    final page = _currentPage();
    if (page != null) _capture(page);
  }

  void _capture(_InspectableCandidate candidate) {
    // Capture everything before the mode changes or a route is opened.
    final recorder = widget.stateRecorder;
    final capturedAtUtc = recorder?.nowUtc() ?? DateTime.now().toUtc();
    final stateHistory = recorder == null
        ? const <BugStateRecord>[]
        : recorder.recordsSince(widget.historyWindow, nowUtc: capturedAtUtc);
    final node = candidate.node;
    final selection = node._createSelection(
      bounds: candidate.geometry.bounds,
      capturedAtUtc: capturedAtUtc,
      stateHistory: stateHistory,
    );
    final widgetContext = node.context;

    if (widget.disableModeOnSelection) _modeCubit.disable();
    widget.onWidgetSelected(widgetContext, selection);
  }

  @override
  Widget build(BuildContext context) {
    final modeCubit = _modeCubit;
    return _BugInspectorScope(
      registry: _registry,
      modeCubit: modeCubit,
      borderColor: widget.borderColor,
      borderWidth: widget.borderWidth,
      pageBorderColor: widget.pageBorderColor,
      pageBorderWidth: widget.pageBorderWidth,
      child: BlocProvider<InspectModeCubit>.value(
        value: modeCubit,
        child: BlocBuilder<InspectModeCubit, InspectMode>(
          bloc: modeCubit,
          builder: (context, mode) =>
              _buildLayers(context, selecting: mode == InspectMode.selecting),
        ),
      ),
    );
  }

  Widget _buildLayers(BuildContext context, {required bool selecting}) {
    final textDirection = Directionality.maybeOf(context);
    final trigger = widget.selectionTrigger;
    return Stack(
      fit: StackFit.passthrough,
      textDirection: textDirection ?? TextDirection.ltr,
      children: <Widget>[
        // Always present so that toggling the mode keeps the app state.
        AbsorbPointer(
          absorbing: selecting,
          child: RepaintBoundary(
            key: _registry.contentKey,
            child: widget.child,
          ),
        ),
        if (selecting)
          Positioned.fill(
            key: const ValueKey<String>('bug_inspector.selection_layer'),
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              excludeFromSemantics: true,
              onTapDown: trigger == BugSelectionTrigger.tapDown
                  ? _handleTapDown
                  : null,
              onTapUp:
                  trigger == BugSelectionTrigger.tapUp ? _handleTapUp : null,
            ),
          ),
        if (selecting && widget.showPageButton)
          Positioned.fill(
            key: const ValueKey<String>('bug_inspector.page_button_layer'),
            child: _PageButtonLayer(
              alignment: _pageButtonAlignment ??
                  widget.pageButtonAlignment
                      .resolve(textDirection ?? TextDirection.ltr),
              onAlignmentChanged: (alignment) =>
                  _pageButtonAlignment = alignment,
              label: widget.pageButtonLabel,
              color: widget.pageBorderColor,
              currentPageName: () => _currentPage()?.node._displayName,
              onPressed: _selectCurrentPage,
              textDirection: textDirection,
            ),
          ),
        if (selecting && widget.showExitButton)
          Positioned.fill(
            key: const ValueKey<String>('bug_inspector.exit_layer'),
            child: _ExitButtonLayer(
              alignment: widget.exitButtonAlignment,
              textDirection: textDirection,
              child: Builder(
                builder: (context) =>
                    widget.exitButtonBuilder
                        ?.call(context, _modeCubit.disable) ??
                    _DefaultExitButton(
                      label: widget.exitButtonLabel,
                      onPressed: _modeCubit.disable,
                    ),
              ),
            ),
          ),
      ],
    );
  }
}

/// The inspectables and pages below one [BugInspector].
class _BugInspectorRegistry {
  final Set<_InspectableNode> _nodes = <_InspectableNode>{};

  /// The key of the repaint boundary around the app content.
  final GlobalKey contentKey = GlobalKey(debugLabel: 'BugInspector content');

  /// A snapshot of the registered nodes in registration order.
  List<_InspectableNode> get nodes => List<_InspectableNode>.of(_nodes);

  void register(_InspectableNode node) => _nodes.add(node);

  void unregister(_InspectableNode node) => _nodes.remove(node);
}

class _BugInspectorScope extends InheritedWidget {
  const _BugInspectorScope({
    required this.registry,
    required this.modeCubit,
    required this.borderColor,
    required this.borderWidth,
    required this.pageBorderColor,
    required this.pageBorderWidth,
    required super.child,
  });

  final _BugInspectorRegistry registry;
  final InspectModeCubit modeCubit;
  final Color borderColor;
  final double borderWidth;
  final Color pageBorderColor;
  final double pageBorderWidth;

  static _BugInspectorScope? maybeOf(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<_BugInspectorScope>();
  }

  @override
  bool updateShouldNotify(_BugInspectorScope oldWidget) {
    return !identical(registry, oldWidget.registry) ||
        !identical(modeCubit, oldWidget.modeCubit) ||
        borderColor != oldWidget.borderColor ||
        borderWidth != oldWidget.borderWidth ||
        pageBorderColor != oldWidget.pageBorderColor ||
        pageBorderWidth != oldWidget.pageBorderWidth;
  }
}

/// Places the exit button inside the safe area. Only the button itself takes
/// part in hit testing, the rest of the layer lets taps through.
class _ExitButtonLayer extends StatelessWidget {
  const _ExitButtonLayer({
    required this.alignment,
    required this.textDirection,
    required this.child,
  });

  final AlignmentGeometry alignment;
  final TextDirection? textDirection;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final safeArea = MediaQuery.maybePaddingOf(context) ?? EdgeInsets.zero;
    Widget layer = Padding(
      padding: safeArea + const EdgeInsets.all(12),
      child: Align(alignment: alignment, child: child),
    );
    if (textDirection == null) {
      layer = Directionality(textDirection: TextDirection.ltr, child: layer);
    }
    return layer;
  }
}

class _DefaultExitButton extends StatelessWidget {
  const _DefaultExitButton({required this.label, required this.onPressed});

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    const foreground = Color(0xFFFFFFFF);
    return Semantics(
      button: true,
      label: 'Exit inspect mode',
      hint: label,
      excludeSemantics: true,
      child: Material(
        color: const Color(0xE6202124),
        shape: const StadiumBorder(),
        elevation: 6,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          key: const ValueKey<String>('bug_inspector.exit_button'),
          onTap: onPressed,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 16, 8),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                const Icon(Icons.close, size: 18, color: foreground),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: foreground,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Places the page button inside the safe area and lets the tester drag it.
///
/// The current page is only known once the borders have been painted, so the
/// button appears after the first frame of the selecting mode, and only when
/// a page is on screen.
class _PageButtonLayer extends StatefulWidget {
  const _PageButtonLayer({
    required this.alignment,
    required this.onAlignmentChanged,
    required this.label,
    required this.color,
    required this.currentPageName,
    required this.onPressed,
    required this.textDirection,
  });

  final Alignment alignment;
  final ValueChanged<Alignment> onAlignmentChanged;
  final String label;
  final Color color;
  final String? Function() currentPageName;
  final VoidCallback onPressed;
  final TextDirection? textDirection;

  @override
  State<_PageButtonLayer> createState() => _PageButtonLayerState();
}

class _PageButtonLayerState extends State<_PageButtonLayer> {
  final GlobalKey _buttonKey = GlobalKey(debugLabel: 'BugInspector page');
  late Alignment _alignment = widget.alignment;
  String? _pageName;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(() => _pageName = widget.currentPageName());
    });
  }

  void _drag(Offset delta, Size area) {
    final buttonSize = _buttonKey.currentContext?.size ?? Size.zero;
    final freeWidth = area.width - buttonSize.width;
    final freeHeight = area.height - buttonSize.height;
    final x = freeWidth > 0 ? _alignment.x + delta.dx * 2 / freeWidth : 0.0;
    final y = freeHeight > 0 ? _alignment.y + delta.dy * 2 / freeHeight : 0.0;
    setState(() {
      _alignment = Alignment(x.clamp(-1.0, 1.0), y.clamp(-1.0, 1.0));
    });
    widget.onAlignmentChanged(_alignment);
  }

  @override
  Widget build(BuildContext context) {
    final pageName = _pageName;
    if (pageName == null) return const SizedBox.shrink();

    final safeArea = MediaQuery.maybePaddingOf(context) ?? EdgeInsets.zero;
    Widget layer = Padding(
      padding: safeArea + const EdgeInsets.all(16),
      child: LayoutBuilder(
        builder: (context, constraints) => Align(
          alignment: _alignment,
          child: GestureDetector(
            onPanUpdate: (details) => _drag(details.delta, constraints.biggest),
            child: KeyedSubtree(
              key: _buttonKey,
              child: _DefaultPageButton(
                label: widget.label,
                color: widget.color,
                pageName: pageName,
                onPressed: widget.onPressed,
              ),
            ),
          ),
        ),
      ),
    );
    if (widget.textDirection == null) {
      layer = Directionality(textDirection: TextDirection.ltr, child: layer);
    }
    return layer;
  }
}

class _DefaultPageButton extends StatelessWidget {
  const _DefaultPageButton({
    required this.label,
    required this.color,
    required this.pageName,
    required this.onPressed,
  });

  final String label;
  final Color color;
  final String pageName;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    const foreground = Color(0xFFFFFFFF);
    return Semantics(
      button: true,
      label: '$label: $pageName',
      excludeSemantics: true,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 260),
        child: Material(
          color: color,
          shape: const StadiumBorder(),
          elevation: 6,
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            key: const ValueKey<String>('bug_inspector.page_button'),
            onTap: onPressed,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 8, 18, 8),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  const Icon(Icons.crop_free, size: 20, color: foreground),
                  const SizedBox(width: 10),
                  Flexible(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: foreground,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          pageName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Color(0xCCFFFFFF),
                            fontSize: 12,
                          ),
                        ),
                      ],
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
