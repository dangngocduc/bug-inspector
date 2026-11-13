part of '../../flutter_qa_inspector.dart';

/// A ready-made bug report form, presented full screen above the app like an
/// iOS modal.
///
/// The form shows the selected widget or screen, the screenshot, a
/// description field, the API calls of [BugWidgetSelection.network] and the
/// inspector JSON. Tapping the screenshot opens a full screen
/// [BugScreenshotEditor] where the tester draws rectangles, tapping a call
/// opens its request and response.
/// Sending zips the screenshot (with the selected widget outlined and the
/// rectangles drawn on it), the description and the inspector JSON, then
/// shares the screenshot, the ZIP and the description, see [BugReportBundle].
///
/// The page has its own [Navigator]: the form is its first page and the
/// editor opens above it, so the app's navigator only sees one route for the
/// whole report. The back button and the back gesture close the editor first,
/// then the report. Leaving a form that has a description or rectangles asks
/// first. A dismissed share sheet keeps the report open, a failed share shows
/// the error.
///
/// The report is styled with Cupertino widgets and its own [theme], so it
/// looks the same whatever the theme of the app, and follows the light or
/// dark mode of the device.
///
/// `FlutterQaInspector.wrap` opens it for every selection. To open it from
/// your own [BugInspector.onWidgetSelected]:
///
/// ```dart
/// onWidgetSelected: (widgetContext, selection) async {
///   final screenshot = await BugInspector.captureScreenshot(widgetContext);
///   if (!widgetContext.mounted) return;
///   await BugReportPage.open(
///     widgetContext,
///     selection: selection,
///     screenshot: screenshot,
///   );
/// },
/// ```
class BugReportPage extends StatefulWidget {
  /// Creates a bug report form for [selection].
  const BugReportPage({
    super.key,
    required this.selection,
    this.screenshot,
    this.strings,
    this.share,
  });

  /// The name of the route that [open] pushes.
  static const String routeName = '/qa-bug-report';

  /// The theme of the report: not based on the theme of the app, system
  /// colors, and the brightness of the device.
  static const CupertinoThemeData theme = CupertinoThemeData();

  /// The selected widget or screen.
  final BugWidgetSelection selection;

  /// The screenshot taken before the report opened, or `null` for a report
  /// without an image.
  final BugScreenshot? screenshot;

  /// The texts of the report. [BugReportStrings.of] when `null`.
  final BugReportStrings? strings;

  /// Sends the report. `SharePlus.instance.share` when `null`.
  final BugReportShare? share;

  /// Opens the report on the root navigator, so it covers the whole app even
  /// when the selected widget is inside a nested navigator. The future
  /// completes when the report closes.
  static Future<void> open(
    BuildContext context, {
    required BugWidgetSelection selection,
    BugScreenshot? screenshot,
    BugReportStrings? strings,
    BugReportShare? share,
  }) {
    return Navigator.of(context, rootNavigator: true).push<void>(
      CupertinoPageRoute<void>(
        // Slides up from the bottom, with no back swipe from the left edge:
        // the report closes with its cancel button, the back button or the
        // back gesture.
        fullscreenDialog: true,
        settings: const RouteSettings(name: routeName),
        builder: (_) => BugReportPage(
          selection: selection,
          screenshot: screenshot,
          strings: strings,
          share: share,
        ),
      ),
    );
  }

  @override
  State<BugReportPage> createState() => _BugReportPageState();
}

class _BugReportPageState extends State<BugReportPage> {
  final _navigatorKey = GlobalKey<NavigatorState>();

  /// Closes the report with every page of its navigator. [context] is above
  /// the report's navigator, so this pops the route that holds the report.
  void _close() => Navigator.of(context).pop();

  @override
  Widget build(BuildContext context) {
    final strings = widget.strings ?? BugReportStrings.of(context);
    return CupertinoTheme(
      data: BugReportPage.theme,
      child: Builder(
        // A MaterialApp gives the text without a Material ancestor an error
        // style. The pages of the report have no Material, so they use the
        // Cupertino text style.
        builder: (context) => DefaultTextStyle(
          style: CupertinoTheme.of(context).textTheme.textStyle,
          // While the report's navigator has a page above the form, or the
          // form asks before closing, a back gesture goes to that navigator
          // instead of closing the whole report.
          child: NavigatorPopHandler<void>(
            onPopWithResult: (_) => _navigatorKey.currentState?.maybePop(),
            child: Navigator(
              key: _navigatorKey,
              onGenerateRoute: (settings) => CupertinoPageRoute<void>(
                settings: settings,
                builder: (_) => _BugReportForm(
                  selection: widget.selection,
                  screenshot: widget.screenshot,
                  strings: strings,
                  share: widget.share ?? SharePlus.instance.share,
                  onClose: _close,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The first page of the report's navigator.
class _BugReportForm extends StatefulWidget {
  const _BugReportForm({
    required this.selection,
    required this.screenshot,
    required this.strings,
    required this.share,
    required this.onClose,
  });

  final BugWidgetSelection selection;
  final BugScreenshot? screenshot;
  final BugReportStrings strings;
  final BugReportShare share;

  /// Closes the whole report.
  final VoidCallback onClose;

  @override
  State<_BugReportForm> createState() => _BugReportFormState();
}

class _BugReportFormState extends State<_BugReportForm> {
  final _description = TextEditingController();

  /// The rectangles the tester drew on the screenshot.
  final _annotations = BugScreenshotAnnotationController();

  /// Whether the report is being zipped or the share sheet is open.
  final _sending = ValueNotifier<bool>(false);

  /// Whether the copy button shows that the JSON was copied.
  final _copied = ValueNotifier<bool>(false);
  Timer? _copiedTimer;

  /// The selection does not change: its JSON is encoded once. The API calls
  /// have their own section, and are left out of this preview only: the
  /// report and the copied JSON have them.
  late final String _payload = const JsonEncoder.withIndent('  ')
      .convert(widget.selection.toJson()..remove('network'));

  BugReportStrings get _strings => widget.strings;

  @override
  void dispose() {
    _copiedTimer?.cancel();
    _description.dispose();
    _annotations.dispose();
    _sending.dispose();
    _copied.dispose();
    super.dispose();
  }

  /// Whether closing the form would lose what the tester wrote or drew.
  bool get _hasChanges =>
      _description.text.trim().isNotEmpty ||
      _annotations.annotations.isNotEmpty;

  /// The content of [BugReportBundle.inspectorFileName].
  Map<String, Object?> get _inspectorJson => {
        'inspector': widget.selection.toJson(),
        if (widget.screenshot != null)
          'screenshot': {
            ...widget.screenshot!.toJson(),
            'annotations': _annotations.toJson(),
          },
      };

  /// What the copy button copies.
  Map<String, Object?> get _report => {
        'description': _description.text,
        ..._inspectorJson,
      };

  /// The selected widget, outlined on the screenshot. A whole screen is not
  /// outlined: it is the whole image.
  Rect? get _highlight => widget.selection.kind == BugSelectionKind.widget
      ? widget.selection.bounds
      : null;

  /// Closes the report, after asking when the tester would lose their
  /// description or rectangles.
  Future<void> _cancel() async {
    if (_sending.value) return;
    if (!_hasChanges) {
      widget.onClose();
      return;
    }
    final discard = await showCupertinoModalPopup<bool>(
      context: context,
      // The popup is built in the overlay of the app's navigator, which does
      // not see the theme of the report.
      builder: (context) => CupertinoTheme(
        data: BugReportPage.theme,
        child: CupertinoActionSheet(
          title: Text(_strings.discardTitle),
          message: Text(_strings.discardMessage),
          actions: [
            CupertinoActionSheetAction(
              isDestructiveAction: true,
              onPressed: () => Navigator.of(context).pop(true),
              child: Text(_strings.discardConfirm),
            ),
          ],
          cancelButton: CupertinoActionSheetAction(
            isDefaultAction: true,
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(_strings.keepEditing),
          ),
        ),
      ),
    );
    if (discard == true && mounted) widget.onClose();
  }

  /// Opens the editor in the report's navigator, above this form.
  void _annotate() {
    final screenshot = widget.screenshot;
    if (screenshot == null) return;
    FocusScope.of(context).unfocus();
    _ScreenshotAnnotationPage.open(
      context,
      screenshot: screenshot,
      controller: _annotations,
      strings: _strings,
      highlight: _highlight,
    );
  }

  Future<void> _copyJson() async {
    await Clipboard.setData(ClipboardData(text: jsonEncode(_report)));
    if (!mounted) return;
    unawaited(HapticFeedback.lightImpact());
    _copied.value = true;
    _copiedTimer?.cancel();
    _copiedTimer = Timer(const Duration(seconds: 2), () {
      if (mounted) _copied.value = false;
    });
  }

  /// Zips the report and opens the share sheet next to [origin], the send
  /// button in global logical pixels.
  Future<void> _send(Rect? origin) async {
    if (_sending.value) return;
    FocusScope.of(context).unfocus();
    _sending.value = true;
    try {
      final screenshot = widget.screenshot;
      final png = screenshot == null
          ? null
          : await screenshot.toAnnotatedPng(
              _annotations.annotations,
              highlight: _highlight,
            );
      final bundle = BugReportBundle(
        name: BugReportBundle.nameFor(
          widget.selection.id,
          widget.selection.capturedAtUtc,
        ),
        description: _description.text,
        inspectorJson: _inspectorJson,
        screenshotPng: png,
      );
      final result = await widget.share(
        bundle.toShareParams(
          sharePositionOrigin: origin,
          subject: _strings.shareSubject(bundle.name),
        ),
      );
      // A share sheet closed without sharing keeps the report, to send again.
      if (mounted && result.status != ShareResultStatus.dismissed) {
        widget.onClose();
      }
    } catch (error) {
      if (!mounted) return;
      unawaited(
        showCupertinoDialog<void>(
          context: context,
          builder: (context) => CupertinoTheme(
            data: BugReportPage.theme,
            child: CupertinoAlertDialog(
              title: Text(_strings.shareFailed),
              content: Text('$error'),
              actions: [
                CupertinoDialogAction(
                  isDefaultAction: true,
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(_strings.ok),
                ),
              ],
            ),
          ),
        ),
      );
    } finally {
      if (mounted) _sending.value = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final strings = _strings;
    final selection = widget.selection;
    final screenshot = widget.screenshot;
    final isPage = selection.kind == BugSelectionKind.page;

    final scaffold = CupertinoPageScaffold(
      backgroundColor: CupertinoColors.systemGroupedBackground,
      navigationBar: CupertinoNavigationBar(
        leading: ValueListenableBuilder<bool>(
          valueListenable: _sending,
          builder: (context, sending, _) => CupertinoButton(
            padding: EdgeInsets.zero,
            onPressed: sending ? null : _cancel,
            child: Text(strings.cancel),
          ),
        ),
        middle: Text(strings.title),
        trailing: ValueListenableBuilder<bool>(
          valueListenable: _sending,
          builder: (context, sending, _) => sending
              ? const CupertinoActivityIndicator()
              // The context of this builder is the button: iPad anchors the
              // share sheet to it.
              : Builder(
                  builder: (buttonContext) => CupertinoButton(
                    padding: EdgeInsets.zero,
                    onPressed: () => _send(_globalRect(buttonContext)),
                    child: Text(
                      strings.send,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
        ),
      ),
      child: ListView(
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        children: [
          CupertinoListSection.insetGrouped(
            header: _ReportSectionHeader(strings.sectionTarget),
            children: [
              CupertinoListTile(
                leading: Icon(
                  isPage
                      ? CupertinoIcons.device_phone_portrait
                      : CupertinoIcons.square_on_square,
                ),
                title: Text(selection.label ?? selection.id),
                subtitle: Text(
                  selection.label == null
                      ? selection.widgetType
                      : '${selection.id} · ${selection.widgetType}',
                ),
                additionalInfo: Text(
                  isPage ? strings.kindScreen : strings.kindWidget,
                ),
              ),
            ],
          ),
          if (screenshot != null)
            CupertinoListSection.insetGrouped(
              header: _ReportSectionHeader(strings.sectionScreenshot),
              footer: ListenableBuilder(
                listenable: _annotations,
                builder: (context, _) {
                  final count = _annotations.annotations.length;
                  return _ReportSectionFooter(
                    count == 0
                        ? strings.annotateHint
                        : strings.annotatedCount(count),
                  );
                },
              ),
              children: [
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: _ReportScreenshotPreview(
                    screenshot: screenshot,
                    annotations: _annotations,
                    highlight: _highlight,
                    strings: strings,
                    onTap: _annotate,
                  ),
                ),
              ],
            ),
          CupertinoListSection.insetGrouped(
            header: _ReportSectionHeader(strings.sectionDescription),
            children: [
              CupertinoTextField.borderless(
                controller: _description,
                placeholder: strings.descriptionPlaceholder,
                minLines: 3,
                maxLines: 8,
                textCapitalization: TextCapitalization.sentences,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                onTapOutside: (_) => FocusScope.of(context).unfocus(),
              ),
            ],
          ),
          if (selection.network.isNotEmpty)
            CupertinoListSection.insetGrouped(
              header: _ReportSectionHeader(strings.sectionNetwork),
              footer: _ReportSectionFooter(
                strings.networkCount(selection.network.length),
              ),
              children: _networkTiles(
                context,
                selection.network,
                strings,
                backTitle: strings.title,
              ),
            ),
          CupertinoListSection.insetGrouped(
            header: Row(
              children: [
                Expanded(
                  child: _ReportSectionHeader(strings.sectionPayload),
                ),
                CupertinoButton(
                  sizeStyle: CupertinoButtonSize.small,
                  padding: EdgeInsets.zero,
                  minimumSize: Size.zero,
                  onPressed: _copyJson,
                  child: ValueListenableBuilder<bool>(
                    valueListenable: _copied,
                    builder: (context, copied, _) => Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          copied
                              ? CupertinoIcons.checkmark_alt
                              : CupertinoIcons.doc_on_doc,
                          size: 16,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          copied ? strings.copied : strings.copyJson,
                          style: const TextStyle(fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                // The only Material widget of the report: Cupertino has no
                // selectable text.
                child: SelectableText(
                  _payload,
                  style: TextStyle(
                    fontFamily: 'Menlo',
                    fontFamilyFallback: const ['Courier', 'monospace'],
                    fontSize: 12,
                    height: 1.4,
                    color: CupertinoColors.label.resolveFrom(context),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );

    // The back button and the back gesture on the form act as the cancel
    // button: they ask before the description or the rectangles are lost.
    return ListenableBuilder(
      listenable: Listenable.merge([_description, _annotations, _sending]),
      child: scaffold,
      builder: (context, child) => PopScope<void>(
        canPop: !_sending.value && !_hasChanges,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop) _cancel();
        },
        child: child!,
      ),
    );
  }
}

class _ReportSectionHeader extends StatelessWidget {
  const _ReportSectionHeader(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text.toUpperCase(),
      style: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w400,
        letterSpacing: -0.08,
        color: CupertinoColors.secondaryLabel.resolveFrom(context),
      ),
    );
  }
}

class _ReportSectionFooter extends StatelessWidget {
  const _ReportSectionFooter(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(
        fontSize: 13,
        letterSpacing: -0.08,
        color: CupertinoColors.secondaryLabel.resolveFrom(context),
      ),
    );
  }
}

/// Where the widget of [context] is on screen, in global logical pixels.
Rect? _globalRect(BuildContext context) {
  final box = context.findRenderObject();
  if (box is! RenderBox || !box.hasSize) return null;
  return box.localToGlobal(Offset.zero) & box.size;
}

/// The screenshot with the selected widget and the tester's rectangles. A tap
/// opens the editor.
class _ReportScreenshotPreview extends StatelessWidget {
  const _ReportScreenshotPreview({
    required this.screenshot,
    required this.annotations,
    required this.highlight,
    required this.strings,
    required this.onTap,
  });

  final BugScreenshot screenshot;
  final BugScreenshotAnnotationController annotations;
  final Rect? highlight;
  final BugReportStrings strings;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxHeight: 280),
        child: Semantics(
          container: true,
          button: true,
          label: strings.annotateTitle,
          excludeSemantics: true,
          onTap: onTap,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onTap,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Stack(
                children: [
                  BugScreenshotEditor(
                    screenshot: screenshot,
                    controller: annotations,
                    highlight: highlight,
                    readOnly: true,
                  ),
                  Positioned(
                    right: 8,
                    bottom: 8,
                    child: _MarkupBadge(label: strings.markup),
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

class _MarkupBadge extends StatelessWidget {
  const _MarkupBadge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const ShapeDecoration(
        color: Color(0xB3000000),
        shape: StadiumBorder(),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 4, 10, 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              CupertinoIcons.pencil_outline,
              size: 14,
              color: CupertinoColors.white,
            ),
            const SizedBox(width: 4),
            Text(
              label,
              style: const TextStyle(
                color: CupertinoColors.white,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
