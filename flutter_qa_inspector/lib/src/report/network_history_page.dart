part of '../../flutter_qa_inspector.dart';

/// The API calls kept by a [BugNetworkRecorder], newest first, updated as the
/// app makes them, presented full screen above the app like [BugReportPage].
///
/// A tap on a call shows its URL, status, timing, headers, bodies and error,
/// and a JSON body opens as a tree. **Clear** removes every kept call from the
/// recorder, so the next bug reports no longer have them.
///
/// The **Inspect network** button of the selection toolbar of [BugInspector]
/// opens it when the host has a [BugInspector.networkRecorder]. To open it from an app's
/// own QA menu:
///
/// ```dart
/// final recorder = FlutterQaInspector.networkRecorder;
/// if (recorder != null) {
///   BugNetworkHistoryPage.open(context, recorder: recorder);
/// }
/// ```
///
/// Like [BugReportPage], it does not check
/// `--dart-define=FLUTTER_QA_INSPECTOR=true`: gate a custom entry point with
/// [BugInspector.enabledFromEnvironment].
class BugNetworkHistoryPage extends StatefulWidget {
  /// Creates the history of the calls of [recorder].
  const BugNetworkHistoryPage({
    super.key,
    required this.recorder,
    this.strings,
  });

  /// The name of the route that [open] pushes.
  static const String routeName = '/qa-network-history';

  /// The key of the button that closes the page.
  static const Key closeButtonKey =
      ValueKey<String>('bug_network_history.close');

  /// The key of the button that removes every call.
  static const Key clearButtonKey =
      ValueKey<String>('bug_network_history.clear');

  /// The calls to list.
  final BugNetworkRecorder recorder;

  /// The texts of the page. [BugReportStrings.of] when `null`.
  final BugReportStrings? strings;

  /// Opens the page on the root navigator, so it covers the whole app. The
  /// future completes when the page closes.
  static Future<void> open(
    BuildContext context, {
    required BugNetworkRecorder recorder,
    BugReportStrings? strings,
  }) {
    return Navigator.of(context, rootNavigator: true)
        .push<void>(_route(recorder: recorder, strings: strings));
  }

  /// The route of [open]: full screen, slides up, named [routeName].
  static Route<void> _route({
    required BugNetworkRecorder recorder,
    BugReportStrings? strings,
  }) {
    return CupertinoPageRoute<void>(
      fullscreenDialog: true,
      settings: const RouteSettings(name: routeName),
      builder: (_) =>
          BugNetworkHistoryPage(recorder: recorder, strings: strings),
    );
  }

  @override
  State<BugNetworkHistoryPage> createState() => _BugNetworkHistoryPageState();
}

class _BugNetworkHistoryPageState extends State<BugNetworkHistoryPage> {
  final _navigatorKey = GlobalKey<NavigatorState>();

  /// [context] is above the page's navigator: this pops the whole page.
  void _close() => Navigator.of(context).pop();

  @override
  Widget build(BuildContext context) {
    final strings = widget.strings ?? BugReportStrings.of(context);
    return CupertinoTheme(
      data: BugReportPage.theme,
      child: Builder(
        builder: (context) => DefaultTextStyle(
          style: CupertinoTheme.of(context).textTheme.textStyle,
          // A back gesture closes a call or a JSON tree first.
          child: NavigatorPopHandler<void>(
            onPopWithResult: (_) => _navigatorKey.currentState?.maybePop(),
            child: Navigator(
              key: _navigatorKey,
              onGenerateRoute: (settings) => CupertinoPageRoute<void>(
                settings: settings,
                builder: (_) => _NetworkHistoryList(
                  recorder: widget.recorder,
                  strings: strings,
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

/// The first page of the navigator of [BugNetworkHistoryPage].
class _NetworkHistoryList extends StatefulWidget {
  const _NetworkHistoryList({
    required this.recorder,
    required this.strings,
    required this.onClose,
  });

  final BugNetworkRecorder recorder;
  final BugReportStrings strings;
  final VoidCallback onClose;

  @override
  State<_NetworkHistoryList> createState() => _NetworkHistoryListState();
}

class _NetworkHistoryListState extends State<_NetworkHistoryList> {
  @override
  void initState() {
    super.initState();
    widget.recorder.addListener(_changed);
  }

  @override
  void didUpdateWidget(_NetworkHistoryList oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.recorder, widget.recorder)) {
      oldWidget.recorder.removeListener(_changed);
      widget.recorder.addListener(_changed);
    }
  }

  @override
  void dispose() {
    widget.recorder.removeListener(_changed);
    super.dispose();
  }

  void _changed() {
    if (!mounted) return;
    // A call can start while the app builds: rebuild after that frame.
    if (SchedulerBinding.instance.schedulerPhase ==
        SchedulerPhase.persistentCallbacks) {
      SchedulerBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() {});
      });
    } else {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final strings = widget.strings;
    final records = widget.recorder.records;
    return CupertinoPageScaffold(
      backgroundColor: CupertinoColors.systemGroupedBackground,
      navigationBar: CupertinoNavigationBar(
        leading: CupertinoButton(
          key: BugNetworkHistoryPage.closeButtonKey,
          padding: EdgeInsets.zero,
          onPressed: widget.onClose,
          child: Text(strings.close),
        ),
        middle: Text(strings.networkHistoryTitle),
        trailing: CupertinoButton(
          key: BugNetworkHistoryPage.clearButtonKey,
          padding: EdgeInsets.zero,
          onPressed: records.isEmpty ? null : widget.recorder.clear,
          child: Text(strings.networkClear),
        ),
      ),
      child: records.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      CupertinoIcons.arrow_up_arrow_down,
                      size: 40,
                      color: CupertinoColors.tertiaryLabel.resolveFrom(context),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      strings.networkHistoryEmpty,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color:
                            CupertinoColors.secondaryLabel.resolveFrom(context),
                      ),
                    ),
                  ],
                ),
              ),
            )
          : ListView(
              children: [
                CupertinoListSection.insetGrouped(
                  header: _ReportSectionHeader(strings.sectionNetwork),
                  footer: _ReportSectionFooter(
                    strings.networkCount(records.length),
                  ),
                  children: _networkTiles(
                    context,
                    records,
                    strings,
                    backTitle: strings.networkHistoryTitle,
                  ),
                ),
              ],
            ),
    );
  }
}
