part of '../flutter_qa_inspector.dart';

/// Adds the fields of a [State] to the selections of the widgets and pages
/// around it.
///
/// Dart cannot read the fields of a [State] by itself, so the state lists the
/// ones that help diagnose a bug in [bugSnapshot]:
///
/// ```dart
/// class _CheckoutPageState extends State<CheckoutPage>
///     with BugInspectableState {
///   final _promoCode = TextEditingController();
///   var _step = 0;
///   var _acceptedTerms = false;
///
///   @override
///   Object? bugSnapshot() => {
///         'step': _step,
///         'acceptedTerms': _acceptedTerms,
///         'promoCode': _promoCode.text,
///       };
///
///   // initState, dispose and build as usual.
/// }
/// ```
///
/// When a [BugInspectable] or a [BugInspectablePage] is selected, the
/// inspector calls [bugSnapshot] on every state with this mixin inside the
/// selected widget or page, in tree order, then on those above it, nearest
/// first. The results are in [BugWidgetSelection.widgetStates]:
///
/// - A state inside the selection is usually the state of the selected widget
///   itself, for example when [BugInspectable.child] or
///   [BugInspectablePage.child] is a [StatefulWidget].
/// - A state above the selection is usually the state whose `build` method
///   created the selected widget.
///
/// The mixin overrides nothing, so the state runs exactly as without it.
/// [bugSnapshot] is only called when a tester selects a widget, which never
/// happens without `--dart-define=FLUTTER_QA_INSPECTOR=true`.
mixin BugInspectableState<T extends StatefulWidget> on State<T> {
  /// Converts the current fields of this state into the JSON value stored in
  /// [BugWidgetStateSnapshot.state].
  ///
  /// Return only fields that help diagnose a bug, such as the current step,
  /// a selected tab, a toggle or the text of a search field. The value may
  /// contain strings, finite numbers, booleans, `null`, lists and maps with
  /// string keys. Convert enums with `.name` and dates with
  /// `.toIso8601String()`. Leave out passwords, tokens and personal data.
  /// When several instances of this state can be on screen, for example in
  /// list items, include a field that tells them apart, such as the item id.
  ///
  /// It is called synchronously while the tester selects a widget. It must
  /// not change the state or call [setState]. When it throws or returns a
  /// value that is not JSON compatible, the snapshot has an empty `state` and
  /// [BugWidgetStateSnapshot.captureErrorType] is set.
  @protected
  Object? bugSnapshot();
}

/// Captures the states with [BugInspectableState] around [context]: those in
/// the subtree of [context] in tree order, then those above it, nearest
/// first.
List<BugWidgetStateSnapshot> _captureWidgetStates(BuildContext context) {
  final snapshots = <BugWidgetStateSnapshot>[];
  void capture(Element element) {
    if (element is! StatefulElement) return;
    final state = element.state;
    if (state is BugInspectableState) {
      snapshots.add(_captureWidgetState(state));
    }
  }

  void visitDescendant(Element element) {
    capture(element);
    element.visitChildElements(visitDescendant);
  }

  context.visitChildElements(visitDescendant);
  context.visitAncestorElements((element) {
    capture(element);
    return true;
  });
  return List<BugWidgetStateSnapshot>.unmodifiable(snapshots);
}

/// Builds the snapshot of [state]. Never throws.
BugWidgetStateSnapshot _captureWidgetState(BugInspectableState state) {
  final type = state.runtimeType.toString();
  final widgetType = state.widget.runtimeType.toString();
  try {
    return BugWidgetStateSnapshot(
      type: type,
      widgetType: widgetType,
      state: _copyJsonValue(state.bugSnapshot()),
    );
  } catch (error) {
    assert(() {
      debugPrint('flutter_qa_inspector: could not capture $type: $error');
      return true;
    }());
    return BugWidgetStateSnapshot(
      type: type,
      widgetType: widgetType,
      state: const <String, Object?>{},
      captureErrorType: error.runtimeType.toString(),
    );
  }
}
