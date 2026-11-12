part of '../flutter_qa_inspector.dart';

/// Builds the JSON value stored in [BugBlocSnapshot.state] from [state].
///
/// Return only fields that help diagnose a bug, such as `status`, `itemCount`,
/// `isSubmitting` or `errorCode`. The value may contain strings, finite
/// numbers, booleans, `null`, lists and maps with string keys. Convert enums
/// with `.name` and dates with `.toIso8601String()`.
typedef BugSnapshotBuilder<S> = Object? Function(S state);

/// Exposes a BLoC/Cubit instance to the [BugInspectable]s below it.
///
/// When a widget is selected, the inspector walks up from the widget, reads
/// `bloc.state` of every [BugBlocScope] it meets and turns it into a
/// [BugBlocSnapshot] with [snapshotBuilder].
///
/// Place it below the provider of the instance and above the inspected
/// widgets. Prefer [BugBlocScope.lazy], which reads the instance only when a
/// widget is selected:
///
/// ```dart
/// BugBlocScope<CartState>.lazy(
///   id: 'cart_cubit',
///   readBloc: (context) => context.read<CartCubit>(),
///   snapshotBuilder: (state) => {
///     'status': state.status.name,
///     'itemCount': state.items.length,
///   },
///   child: const CartView(),
/// )
/// ```
///
/// The scope always only returns [child]. Without
/// `--dart-define=FLUTTER_QA_INSPECTOR=true`, or outside an enabled
/// [BugInspector], nothing selects a widget, so [BugBlocScope.lazy] never
/// calls [readBloc].
class BugBlocScope<S> extends StatelessWidget {
  /// Creates a scope for [bloc].
  ///
  /// The expression passed as [bloc] runs on every build, also when the
  /// inspector is disabled. `context.read<T>()` there creates a lazy
  /// provider right away. Use [BugBlocScope.lazy] to avoid that.
  const BugBlocScope({
    super.key,
    required this.id,
    required StateStreamable<S> this.bloc,
    required this.snapshotBuilder,
    required this.child,
  }) : readBloc = null;

  /// Creates a scope that calls [readBloc] only when a widget below it is
  /// selected, with the context of this scope.
  ///
  /// The app builds and runs exactly as without the scope: nothing is read
  /// while the inspector is disabled or not selecting. A lazy provider that
  /// was not created yet is created by the selection.
  const BugBlocScope.lazy({
    super.key,
    required this.id,
    required StateStreamable<S> Function(BuildContext context) this.readBloc,
    required this.snapshotBuilder,
    required this.child,
  }) : bloc = null;

  /// A stable identifier stored in [BugBlocSnapshot.id].
  final String id;

  /// The BLoC or Cubit instance whose state is captured, or `null` for
  /// [BugBlocScope.lazy].
  final StateStreamable<S>? bloc;

  /// Reads the instance when a widget is selected, for [BugBlocScope.lazy].
  final StateStreamable<S> Function(BuildContext context)? readBloc;

  /// Converts the current state into a JSON value.
  final BugSnapshotBuilder<S> snapshotBuilder;

  /// The widget below this scope.
  final Widget child;

  /// Reads the current state of the instance and builds its snapshot.
  ///
  /// [context] is the context of this scope. [BugBlocScope.lazy] needs it to
  /// read the instance.
  ///
  /// Never throws. When the instance cannot be read, [snapshotBuilder] throws
  /// or it returns a value that is not JSON compatible, the snapshot has an
  /// empty `state` and [BugBlocSnapshot.captureErrorType] is set. When the
  /// instance cannot be read, its `type` and `instanceId` are `unknown`.
  BugBlocSnapshot capture([BuildContext? context]) =>
      _captureIn(context, HashSet<Object>.identity())!;

  /// Captures the instance unless [seen] already contains it.
  BugBlocSnapshot? _captureIn(BuildContext? context, Set<Object> seen) {
    final StateStreamable<S> bloc;
    try {
      final given = this.bloc;
      if (given != null) {
        bloc = given;
      } else if (context != null) {
        bloc = readBloc!(context);
      } else {
        throw StateError('BugBlocScope.lazy needs the context of the scope.');
      }
    } catch (error) {
      _debugReport(error, 'read the instance of');
      return BugBlocSnapshot(
        id: id,
        type: 'unknown',
        instanceId: 'unknown',
        state: const <String, Object?>{},
        captureErrorType: error.runtimeType.toString(),
      );
    }
    if (!seen.add(bloc)) return null;

    final type = bloc.runtimeType.toString();
    final instanceId = BugStateRecorder.instanceIdOf(bloc);
    String? stateType;
    try {
      final state = bloc.state;
      stateType = state.runtimeType.toString();
      return BugBlocSnapshot(
        id: id,
        type: type,
        instanceId: instanceId,
        stateType: stateType,
        state: _copyJsonValue(snapshotBuilder(state)),
      );
    } catch (error) {
      _debugReport(error, 'capture');
      return BugBlocSnapshot(
        id: id,
        type: type,
        instanceId: instanceId,
        stateType: stateType,
        state: const <String, Object?>{},
        captureErrorType: error.runtimeType.toString(),
      );
    }
  }

  void _debugReport(Object error, String action) {
    assert(() {
      debugPrint(
        'flutter_qa_inspector: could not $action BugBlocScope "$id": $error',
      );
      return true;
    }());
  }

  @override
  Widget build(BuildContext context) => child;

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties
      ..add(StringProperty('id', id))
      ..add(DiagnosticsProperty<Object>('bloc', bloc, defaultValue: null))
      ..add(FlagProperty('lazy', value: readBloc != null, ifTrue: 'lazy'));
  }
}

/// Captures the [BugBlocScope]s around [context].
///
/// With [includeDescendants], the scopes inside the subtree of [context] come
/// first, in tree order. The scopes above [context] follow, nearest first.
///
/// An instance exposed by several scopes is captured once, by the first scope
/// met. Two different instances of the same class are both captured.
List<BugBlocSnapshot> _captureBlocSnapshots(
  BuildContext context, {
  bool includeDescendants = false,
}) {
  final snapshots = <BugBlocSnapshot>[];
  final seen = HashSet<Object>.identity();
  void capture(Element element) {
    final widget = element.widget;
    if (widget is! BugBlocScope<Object?>) return;
    final snapshot = widget._captureIn(element, seen);
    if (snapshot != null) snapshots.add(snapshot);
  }

  if (includeDescendants) {
    void visitDescendant(Element element) {
      capture(element);
      element.visitChildElements(visitDescendant);
    }

    context.visitChildElements(visitDescendant);
  }
  context.visitAncestorElements((element) {
    capture(element);
    return true;
  });
  return List<BugBlocSnapshot>.unmodifiable(snapshots);
}
