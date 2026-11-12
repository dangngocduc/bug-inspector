part of '../flutter_qa_inspector.dart';

/// Called when the tester selects a [BugInspectable] or a
/// [BugInspectablePage].
///
/// [widgetContext] is the context of the selected widget or page. Use it right
/// away to find the widget's `Navigator`, for example to open a bug report
/// form. After an `await`, check `widgetContext.mounted` before using it
/// again.
///
/// Return a [Future] that completes when the report is closed, for example
/// the one of `Navigator.push` for the report route: the floating bug button
/// hides until it completes, so it never covers the report. A callback that
/// returns nothing leaves the button on screen.
typedef BugWidgetSelectedCallback = FutureOr<void> Function(
  BuildContext widgetContext,
  BugWidgetSelection selection,
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
/// The inspector only runs in builds made with
/// `--dart-define=FLUTTER_QA_INSPECTOR=true`, see [enabledFromEnvironment].
/// In any other build, this widget and every other widget of the package only
/// return their child, so the app runs as if the package were not there.
///
/// The host draws a floating control on top of the app. It is not part of the
/// app content: it does not change the layout, it only takes the taps that
/// land on it, it never takes keyboard focus, and
/// [BugInspector.captureScreenshot] leaves it out. The tester can drag it
/// anywhere, and the host remembers where it was left.
///
/// * While the mode is [InspectMode.disabled], the control is a small bug
///   button that enables the mode (see [showLauncher]).
/// * While the mode is [InspectMode.selecting], it expands into a toolbar
///   with a hint, a button that leaves the mode and, when a
///   [BugInspectablePage] is on screen, a "Select screen" button.
///
/// The host also provides an [InspectModeCubit] to its subtree, so a QA menu
/// of the app can call `BugInspector.maybeModeCubitOf(context)?.enable()` too.
///
/// While selecting, every [BugInspectable] below the host gets a border, every
/// [BugInspectablePage] gets a page border, the app content stops receiving
/// pointer input (taps, scrolls and hovers), and the next tap inside a widget
/// border calls [onWidgetSelected]. A tap outside every widget border keeps
/// the mode, unless [selectPageOnEmptyTap] is set.
class BugInspector extends StatelessWidget {
  /// Creates an inspector host.
  const BugInspector({
    super.key,
    this.enabled = true,
    required this.child,
    required this.onWidgetSelected,
    this.modeCubit,
    this.stateRecorder,
    this.historyWindow = defaultHistoryWindow,
    this.disableModeOnSelection = true,
    this.selectionTrigger = BugSelectionTrigger.tapUp,
    this.showLauncher = true,
    this.floatingAlignment = AlignmentDirectional.centerEnd,
    this.selectionHint = defaultSelectionHint,
    this.showPageButton = true,
    this.pageButtonLabel = defaultPageButtonLabel,
    this.selectPageOnEmptyTap = false,
    this.borderColor = defaultBorderColor,
    this.borderWidth = defaultBorderWidth,
    this.pageBorderColor = defaultPageBorderColor,
    this.pageBorderWidth = defaultPageBorderWidth,
  })  : assert(borderWidth >= 0),
        assert(pageBorderWidth >= 0);

  /// Whether the app was built with `--dart-define=FLUTTER_QA_INSPECTOR=true`.
  ///
  /// The master switch of the package, `false` unless the define is `true`.
  /// When `false`:
  ///
  /// * [BugInspector], [BugInspectable], [BugInspectablePage] and
  ///   [BugBlocScope] only return their child. No floating control, no layer
  ///   around the app, no [InspectModeCubit], no registration, no extra render
  ///   object.
  /// * [BugBlocScope.lazy] never reads its bloc.
  /// * [BugInspectorBlocObserver] records nothing.
  /// * [maybeModeCubitOf] and [captureScreenshot] return `null`.
  ///
  /// It is a constant, so the compiler leaves the inspector code out of such
  /// a build. Use it for the app's own QA code too, for example
  /// `if (BugInspector.enabledFromEnvironment) { ... }` around the
  /// installation of [BugInspectorBlocObserver].
  static const bool enabledFromEnvironment =
      bool.fromEnvironment('FLUTTER_QA_INSPECTOR');

  /// The default value of [historyWindow].
  static const Duration defaultHistoryWindow = Duration(seconds: 30);

  /// The default value of [borderColor].
  static const Color defaultBorderColor = Color(0xFFFF2D78);

  /// The default value of [borderWidth].
  static const double defaultBorderWidth = 2;

  /// The default value of [selectionHint].
  static const String defaultSelectionHint = 'Tap a highlighted widget';

  /// The default value of [pageButtonLabel].
  static const String defaultPageButtonLabel = 'Select screen';

  /// The default value of [pageBorderColor].
  static const Color defaultPageBorderColor = Color(0xFF2979FF);

  /// The default value of [pageBorderWidth].
  static const double defaultPageBorderWidth = 4;

  /// The key of the floating button that enables the mode.
  static const Key launcherKey = ValueKey<String>('bug_inspector.launcher');

  /// The key of the toolbar button that leaves the mode.
  static const Key exitButtonKey = ValueKey<String>('bug_inspector.exit');

  /// The key of the toolbar button that selects the current page.
  static const Key pageButtonKey =
      ValueKey<String>('bug_inspector.page_button');

  /// Whether the inspector runs in a build where [enabledFromEnvironment] is
  /// `true`. Without the define, the inspector never runs, whatever this
  /// value.
  ///
  /// Set it to `false` to turn the inspector off in some QA builds, for
  /// example from a flavor. The host then returns [child] unchanged and the
  /// widgets below it only return their child, as without the define.
  ///
  /// Decide it before `runApp` and keep it for the whole run. Changing it
  /// while the app runs rebuilds the app content, so the route stack and the
  /// state of the screens are lost. To hide the tool at runtime, use
  /// [showLauncher] and [InspectModeCubit] instead.
  final bool enabled;

  /// The app content, usually the child of `MaterialApp.builder`.
  final Widget child;

  /// Called after the tester selected a widget or a page.
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

  /// Whether to switch to [InspectMode.disabled] right after a selection,
  /// before [onWidgetSelected] is called.
  ///
  /// When `false`, disable the mode before opening a form in the Navigator
  /// below the host, otherwise the inspector keeps intercepting taps.
  final bool disableModeOnSelection;

  /// Which part of a tap selects a widget.
  final BugSelectionTrigger selectionTrigger;

  /// Whether the floating bug button stays on screen while the mode is
  /// disabled, so testers can enable the mode without any entry in the app
  /// UI.
  ///
  /// Set it to `false` when the app enables the mode from its own QA menu.
  /// While selecting, the floating toolbar is always shown, because the app
  /// content does not receive taps and the toolbar is the way out.
  ///
  /// The button also hides while the [Future] returned by [onWidgetSelected]
  /// runs, that is while the bug report is open.
  final bool showLauncher;

  /// Where the floating control starts, inside the safe area. The tester can
  /// drag it elsewhere.
  final AlignmentGeometry floatingAlignment;

  /// The hint shown in the floating toolbar while selecting.
  final String selectionHint;

  /// Whether the floating toolbar offers a button that selects the current
  /// [BugInspectablePage].
  ///
  /// The button only appears when a page is on screen, and names the page it
  /// will select.
  final bool showPageButton;

  /// The title of the page button.
  final String pageButtonLabel;

  /// Whether a tap outside every [BugInspectable] selects the
  /// [BugInspectablePage] under the tap.
  ///
  /// Off by default, so a tap that misses a widget keeps the mode instead of
  /// reporting the whole page.
  final bool selectPageOnEmptyTap;

  /// The default border color of the [BugInspectable]s below this host.
  final Color borderColor;

  /// The default border width of the [BugInspectable]s below this host.
  final double borderWidth;

  /// The default border color of the [BugInspectablePage]s below this host.
  final Color pageBorderColor;

  /// The default border width of the [BugInspectablePage]s below this host.
  final double pageBorderWidth;

  /// Returns the [InspectModeCubit] of the nearest host, or `null` when
  /// [context] is not below an enabled [BugInspector].
  ///
  /// Useful to show a QA menu entry only when the inspector is present.
  static InspectModeCubit? maybeModeCubitOf(BuildContext context) {
    if (!enabledFromEnvironment) return null;
    return _BugInspectorScope.maybeOf(context)?.modeCubit;
  }

  /// Captures the app content of the nearest host as a PNG.
  ///
  /// The capture covers the [child] of the host, without the inspector's own
  /// floating control and overlays. [pixelRatio] defaults to the device pixel
  /// ratio. When [waitForNextFrame] is `true`, the capture waits for the next
  /// frame so that a mode change made just before, such as the borders being
  /// removed after a selection, is visible in the image.
  ///
  /// The system status bar is not part of the app, so the image only shows
  /// the app background under it. When [statusBar] is `true` and the content
  /// is under the top safe area on Android or iOS, the screenshot gets a
  /// [BugScreenshot.statusBar] that fills that area: a Pixel 8 bar on
  /// Android, a Dynamic Island bar on iOS, with the capture time and black
  /// or white icons, whichever shows on the app background.
  ///
  /// Capture before opening a form on top of the content. Returns `null` when
  /// [context] is not below an enabled [BugInspector] or the content cannot be
  /// captured.
  static Future<BugScreenshot?> captureScreenshot(
    BuildContext context, {
    double? pixelRatio,
    bool waitForNextFrame = true,
    bool statusBar = true,
  }) {
    if (!enabledFromEnvironment) return Future<BugScreenshot?>.value();
    return _captureScreenshot(
      context,
      pixelRatio: pixelRatio,
      waitForNextFrame: waitForNextFrame,
      statusBar: statusBar,
    );
  }

  @override
  Widget build(BuildContext context) {
    // A constant check first: without the define, the compiler drops the
    // host and everything only it uses.
    if (!enabledFromEnvironment || !enabled) return child;
    return _BugInspectorHost(inspector: this);
  }
}

/// The running inspector of an enabled [BugInspector].
class _BugInspectorHost extends StatefulWidget {
  const _BugInspectorHost({required this.inspector});

  final BugInspector inspector;

  @override
  State<_BugInspectorHost> createState() => _BugInspectorState();
}

class _BugInspectorState extends State<_BugInspectorHost> {
  final _BugInspectorRegistry _registry = _BugInspectorRegistry();
  InspectModeCubit? _ownedModeCubit;

  /// Where the tester dragged the floating control, kept across mode changes.
  Alignment? _floatingAlignment;

  /// How many futures returned by [BugInspector.onWidgetSelected] are still
  /// running. The launcher hides while one runs: a bug report is open.
  int _openReports = 0;

  BugInspector get _inspector => widget.inspector;

  InspectModeCubit get _modeCubit => _inspector.modeCubit ?? _ownedModeCubit!;

  @override
  void initState() {
    super.initState();
    _syncOwnedModeCubit();
  }

  @override
  void didUpdateWidget(_BugInspectorHost oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncOwnedModeCubit();
  }

  /// Owns a cubit only when none is given.
  void _syncOwnedModeCubit() {
    if (_inspector.modeCubit == null) {
      _ownedModeCubit ??= InspectModeCubit();
    } else {
      _closeOwnedModeCubit();
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
        (_inspector.selectPageOnEmptyTap
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
    final recorder = _inspector.stateRecorder;
    final capturedAtUtc = recorder?.nowUtc() ?? DateTime.now().toUtc();
    final stateHistory = recorder == null
        ? const <BugStateRecord>[]
        : recorder.recordsSince(_inspector.historyWindow,
            nowUtc: capturedAtUtc);
    final node = candidate.node;
    final selection = node._createSelection(
      bounds: candidate.geometry.bounds,
      capturedAtUtc: capturedAtUtc,
      stateHistory: stateHistory,
    );
    final widgetContext = node._markerContext;

    if (_inspector.disableModeOnSelection) _modeCubit.disable();
    final report = _inspector.onWidgetSelected(widgetContext, selection);
    if (report is Future<void>) _hideLauncherUntil(report);
  }

  /// Hides the launcher until [report] completes. An error of [report] is
  /// reported to [FlutterError.onError], as it would be without the host.
  void _hideLauncherUntil(Future<void> report) {
    setState(() => _openReports++);
    report.then<void>(
      (_) {},
      onError: (Object error, StackTrace stack) {
        FlutterError.reportError(
          FlutterErrorDetails(
            exception: error,
            stack: stack,
            library: 'flutter_qa_inspector',
            context: ErrorDescription('while running onWidgetSelected'),
          ),
        );
      },
    ).whenComplete(() {
      if (mounted) setState(() => _openReports--);
    });
  }

  @override
  Widget build(BuildContext context) {
    final modeCubit = _modeCubit;
    return _BugInspectorScope(
      registry: _registry,
      modeCubit: modeCubit,
      borderColor: _inspector.borderColor,
      borderWidth: _inspector.borderWidth,
      pageBorderColor: _inspector.pageBorderColor,
      pageBorderWidth: _inspector.pageBorderWidth,
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
    final trigger = _inspector.selectionTrigger;
    return Stack(
      fit: StackFit.passthrough,
      textDirection: textDirection ?? TextDirection.ltr,
      children: <Widget>[
        // Always present so that toggling the mode keeps the app state.
        AbsorbPointer(
          absorbing: selecting,
          child: RepaintBoundary(
            key: _registry.contentKey,
            child: _inspector.child,
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
        // Above everything else, including the selection layer.
        Positioned.fill(
          key: const ValueKey<String>('bug_inspector.floating_layer'),
          child: _FloatingControl(
            selecting: selecting,
            showLauncher: _inspector.showLauncher && _openReports == 0,
            alignment: _floatingAlignment ??
                _inspector.floatingAlignment
                    .resolve(textDirection ?? TextDirection.ltr),
            onAlignmentChanged: (alignment) => _floatingAlignment = alignment,
            selectionHint: _inspector.selectionHint,
            pageButtonLabel:
                _inspector.showPageButton ? _inspector.pageButtonLabel : null,
            pageColor: _inspector.pageBorderColor,
            currentPageName: () => _currentPage()?.node._displayName,
            onEnable: _modeCubit.enable,
            onExit: _modeCubit.disable,
            onSelectPage: _selectCurrentPage,
            textDirection: textDirection,
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

const Color _controlBackground = Color(0xE6202124);
const Color _controlForeground = Color(0xFFFFFFFF);
const Color _controlSecondary = Color(0xB3FFFFFF);

/// The draggable control that floats above the app content: a bug button
/// while the mode is disabled, a toolbar while selecting.
///
/// Only the control itself takes part in hit testing. It is excluded from
/// focus traversal and grouped with the app's text fields, so using it never
/// takes the focus away from the app or closes the keyboard.
class _FloatingControl extends StatefulWidget {
  const _FloatingControl({
    required this.selecting,
    required this.showLauncher,
    required this.alignment,
    required this.onAlignmentChanged,
    required this.selectionHint,
    required this.pageButtonLabel,
    required this.pageColor,
    required this.currentPageName,
    required this.onEnable,
    required this.onExit,
    required this.onSelectPage,
    required this.textDirection,
  });

  final bool selecting;
  final bool showLauncher;
  final Alignment alignment;
  final ValueChanged<Alignment> onAlignmentChanged;
  final String selectionHint;

  /// `null` hides the page button.
  final String? pageButtonLabel;
  final Color pageColor;
  final String? Function() currentPageName;
  final VoidCallback onEnable;
  final VoidCallback onExit;
  final VoidCallback onSelectPage;
  final TextDirection? textDirection;

  @override
  State<_FloatingControl> createState() => _FloatingControlState();
}

class _FloatingControlState extends State<_FloatingControl> {
  final GlobalKey _controlKey = GlobalKey(debugLabel: 'BugInspector control');
  late Alignment _alignment = widget.alignment;

  /// The page the page button selects. Only known once the page borders have
  /// been painted, so it is resolved after the first selecting frame.
  String? _pageName;

  @override
  void initState() {
    super.initState();
    if (widget.selecting) _resolvePageAfterFrame();
  }

  @override
  void didUpdateWidget(_FloatingControl oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.selecting && !oldWidget.selecting) {
      _resolvePageAfterFrame();
    } else if (!widget.selecting) {
      _pageName = null;
    }
  }

  void _resolvePageAfterFrame() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !widget.selecting) return;
      setState(() => _pageName = widget.currentPageName());
    });
  }

  void _drag(Offset delta, Size area) {
    final controlSize = _controlKey.currentContext?.size ?? Size.zero;
    final freeWidth = area.width - controlSize.width;
    final freeHeight = area.height - controlSize.height;
    final x = freeWidth > 0 ? _alignment.x + delta.dx * 2 / freeWidth : 0.0;
    final y = freeHeight > 0 ? _alignment.y + delta.dy * 2 / freeHeight : 0.0;
    setState(() {
      _alignment = Alignment(x.clamp(-1.0, 1.0), y.clamp(-1.0, 1.0));
    });
    widget.onAlignmentChanged(_alignment);
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.selecting && !widget.showLauncher) {
      return const SizedBox.shrink();
    }

    final Widget control = widget.selecting
        ? _SelectionToolbar(
            hint: widget.selectionHint,
            pageButtonLabel: widget.pageButtonLabel,
            pageName: _pageName,
            pageColor: widget.pageColor,
            onExit: widget.onExit,
            onSelectPage: widget.onSelectPage,
          )
        : _LauncherButton(onPressed: widget.onEnable);

    // Keep the control inside the safe area and above the keyboard.
    final insets = (MediaQuery.maybePaddingOf(context) ?? EdgeInsets.zero) +
        (MediaQuery.maybeViewInsetsOf(context) ?? EdgeInsets.zero);
    Widget layer = ExcludeFocus(
      child: Padding(
        padding: insets + const EdgeInsets.all(16),
        child: LayoutBuilder(
          builder: (context, constraints) => Align(
            alignment: _alignment,
            child: GestureDetector(
              // Follow the finger from the first contact, including the
              // distance moved before the drag was recognized.
              dragStartBehavior: DragStartBehavior.down,
              // Dragging only moves the control: it is not something a screen
              // reader should offer as a scroll action.
              excludeFromSemantics: true,
              onPanUpdate: (details) =>
                  _drag(details.delta, constraints.biggest),
              child: KeyedSubtree(
                key: _controlKey,
                // A tap on the control is not a tap outside the app's text
                // fields, so it does not close the keyboard.
                child: TextFieldTapRegion(child: control),
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

/// The round bug button shown while the mode is disabled.
class _LauncherButton extends StatelessWidget {
  const _LauncherButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    // A container, so the button gets its own node instead of being merged
    // into the semantics node that covers the whole app.
    return Semantics(
      container: true,
      button: true,
      label: 'Open bug inspector',
      excludeSemantics: true,
      onTap: onPressed,
      child: Material(
        color: _controlBackground,
        shape: const CircleBorder(),
        elevation: 4,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          key: BugInspector.launcherKey,
          onTap: onPressed,
          child: const SizedBox(
            width: 48,
            height: 48,
            child: Icon(Icons.bug_report, size: 24, color: _controlForeground),
          ),
        ),
      ),
    );
  }
}

/// The toolbar shown while selecting.
class _SelectionToolbar extends StatelessWidget {
  const _SelectionToolbar({
    required this.hint,
    required this.pageButtonLabel,
    required this.pageName,
    required this.pageColor,
    required this.onExit,
    required this.onSelectPage,
  });

  final String hint;
  final String? pageButtonLabel;
  final String? pageName;
  final Color pageColor;
  final VoidCallback onExit;
  final VoidCallback onSelectPage;

  @override
  Widget build(BuildContext context) {
    final pageButtonLabel = this.pageButtonLabel;
    final pageName = this.pageName;
    return Semantics(
      container: true,
      explicitChildNodes: true,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 260),
        child: Material(
          color: _controlBackground,
          borderRadius: BorderRadius.circular(16),
          elevation: 6,
          clipBehavior: Clip.antiAlias,
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    const Icon(
                      Icons.drag_indicator,
                      size: 18,
                      color: _controlSecondary,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        hint,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: _controlForeground,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    Semantics(
                      container: true,
                      button: true,
                      label: 'Exit inspect mode',
                      excludeSemantics: true,
                      onTap: onExit,
                      child: InkResponse(
                        key: BugInspector.exitButtonKey,
                        onTap: onExit,
                        radius: 20,
                        child: const Padding(
                          padding: EdgeInsets.all(8),
                          child: Icon(
                            Icons.close,
                            size: 20,
                            color: _controlForeground,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                if (pageButtonLabel != null && pageName != null) ...<Widget>[
                  const SizedBox(height: 8),
                  Semantics(
                    container: true,
                    button: true,
                    label: '$pageButtonLabel: $pageName',
                    excludeSemantics: true,
                    onTap: onSelectPage,
                    child: Material(
                      color: pageColor,
                      borderRadius: BorderRadius.circular(12),
                      clipBehavior: Clip.antiAlias,
                      child: InkWell(
                        key: BugInspector.pageButtonKey,
                        onTap: onSelectPage,
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
                          child: Row(
                            children: <Widget>[
                              const Icon(
                                Icons.crop_free,
                                size: 20,
                                color: _controlForeground,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: <Widget>[
                                    Text(
                                      pageButtonLabel,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        color: _controlForeground,
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    Text(
                                      pageName,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        color: _controlSecondary,
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
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
