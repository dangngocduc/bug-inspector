part of '../flutter_qa_inspector.dart';

/// Returns the texts of the inspector and of the bug report, see
/// [FlutterQaInspector.wrap].
typedef BugReportStringsBuilder = BugReportStrings Function(
  BuildContext context,
);

/// The turnkey setup: the state timeline, the inspector and the ready-made
/// [BugReportPage], in two calls.
///
/// ```dart
/// void main() {
///   // Before any BLoC/Cubit is created.
///   FlutterQaInspector.install();
///   runApp(const App());
/// }
///
/// MaterialApp(
///   builder: FlutterQaInspector.builder,
///   // or, inside a builder that wraps other widgets too:
///   // builder: (context, child) => FlutterQaInspector.wrap(child: child!),
/// );
/// ```
///
/// Then mark screens with [BugInspectablePage] (or [BugInspectablePage.route]
/// in `onGenerateRoute`) and widgets with [BugInspectable].
///
/// Without `--dart-define=FLUTTER_QA_INSPECTOR=true`, [install] does nothing
/// and [wrap] returns its child, so the app runs as if the package were not
/// there.
///
/// For another report flow, use [BugInspector] with your own
/// [BugInspector.onWidgetSelected] instead of [wrap].
abstract final class FlutterQaInspector {
  static BugStateRecorder? _recorder;
  static BlocObserver? _previousObserver;

  /// The recorder [install] feeds, or `null` before [install] and in builds
  /// without the define.
  static BugStateRecorder? get recorder => _recorder;

  /// Records the BLoC/Cubit state timeline: sets [Bloc.observer] to a
  /// [MultiBlocObserver] of the current observer and a
  /// [BugInspectorBlocObserver] that writes to [recorder].
  ///
  /// Call it once, before any BLoC/Cubit is created. Later calls do nothing.
  /// Pass [stateRecorder] to choose the recorder, for example with another
  /// [BugStateRecorder.maxRecords].
  static void install({BugStateRecorder? stateRecorder}) {
    // A constant: without the define, the compiler drops the rest.
    if (!BugInspector.enabledFromEnvironment || _recorder != null) return;
    final recorder = stateRecorder ?? BugStateRecorder();
    _recorder = recorder;
    _previousObserver = Bloc.observer;
    Bloc.observer = MultiBlocObserver(
      observers: [
        Bloc.observer,
        BugInspectorBlocObserver(recorder: recorder),
      ],
    );
  }

  /// Undoes [install]: restores the previous [Bloc.observer] and forgets the
  /// recorder.
  @visibleForTesting
  static void debugReset() {
    final previous = _previousObserver;
    if (_recorder != null && previous != null) Bloc.observer = previous;
    _recorder = null;
    _previousObserver = null;
  }

  /// A `MaterialApp.builder`: [wrap] with the defaults.
  static Widget builder(BuildContext context, Widget? child) =>
      wrap(child: child ?? const SizedBox.shrink());

  /// Hosts the inspector for [child], the child of `MaterialApp.builder` that
  /// holds the app's Navigator or Router, and opens a [BugReportPage] for
  /// every selection.
  ///
  /// * [enabled]: see [BugInspector.enabled], for example to hide the
  ///   inspector behind a QA menu switch.
  /// * [stateRecorder]: the state timeline; [recorder] when `null`.
  /// * [strings]: the texts of the inspector and of the report;
  ///   [BugReportStrings.of] when `null`. Map them from the app's own
  ///   localization here.
  /// * [captureScreenshot]: whether the report has a screenshot.
  /// * [share]: sends the report; `SharePlus.instance.share` when `null`.
  static Widget wrap({
    required Widget child,
    bool enabled = true,
    BugStateRecorder? stateRecorder,
    BugReportStringsBuilder? strings,
    bool captureScreenshot = true,
    BugReportShare? share,
  }) {
    if (!BugInspector.enabledFromEnvironment) return child;
    return _BugReportHost(
      enabled: enabled,
      stateRecorder: stateRecorder,
      strings: strings,
      captureScreenshot: captureScreenshot,
      share: share,
      child: child,
    );
  }
}

class _BugReportHost extends StatelessWidget {
  const _BugReportHost({
    required this.enabled,
    required this.stateRecorder,
    required this.strings,
    required this.captureScreenshot,
    required this.share,
    required this.child,
  });

  final bool enabled;
  final BugStateRecorder? stateRecorder;
  final BugReportStringsBuilder? strings;
  final bool captureScreenshot;
  final BugReportShare? share;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final texts = strings?.call(context) ?? BugReportStrings.of(context);
    return BugInspector(
      enabled: enabled,
      stateRecorder: stateRecorder ?? FlutterQaInspector.recorder,
      selectionHint: texts.selectionHint,
      pageButtonLabel: texts.pageButtonLabel,
      onWidgetSelected: (widgetContext, selection) async {
        // The inspector has already left the selecting mode: the screenshot
        // waits for a frame without borders.
        final screenshot = captureScreenshot
            ? await BugInspector.captureScreenshot(widgetContext)
            : null;
        if (!widgetContext.mounted) return;
        // The launcher stays hidden until the report closes.
        await BugReportPage.open(
          widgetContext,
          selection: selection,
          screenshot: screenshot,
          strings: texts,
          share: share,
        );
      },
      child: child,
    );
  }
}
