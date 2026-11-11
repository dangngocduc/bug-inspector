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
/// widgets. Reading the instance with `context.read<T>()` may create a lazy
/// provider.
///
/// ```dart
/// BugBlocScope<CartState>(
///   id: 'cart_cubit',
///   bloc: context.read<CartCubit>(),
///   snapshotBuilder: (state) => {
///     'status': state.status.name,
///     'itemCount': state.items.length,
///   },
///   child: const CartView(),
/// )
/// ```
class BugBlocScope<S> extends StatelessWidget {
  /// Creates a scope for [bloc].
  const BugBlocScope({
    super.key,
    required this.id,
    required this.bloc,
    required this.snapshotBuilder,
    required this.child,
  });

  /// A stable identifier stored in [BugBlocSnapshot.id].
  final String id;

  /// The BLoC or Cubit instance whose state is captured.
  final StateStreamable<S> bloc;

  /// Converts the current state into a JSON value.
  final BugSnapshotBuilder<S> snapshotBuilder;

  /// The widget below this scope.
  final Widget child;

  /// Reads the current state of [bloc] and builds its snapshot.
  ///
  /// Never throws. When [snapshotBuilder] throws or returns a value that is
  /// not JSON compatible, the snapshot has an empty `state` and
  /// [BugBlocSnapshot.captureErrorType] is set.
  BugBlocSnapshot capture() {
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
      assert(() {
        debugPrint(
          'flutter_qa_inspector: could not capture BugBlocScope "$id" '
          '($type): $error',
        );
        return true;
      }());
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

  @override
  Widget build(BuildContext context) => child;

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties
      ..add(StringProperty('id', id))
      ..add(DiagnosticsProperty<Object>('bloc', bloc));
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
    if (widget is BugBlocScope<Object?> && seen.add(widget.bloc)) {
      snapshots.add(widget.capture());
    }
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
