part of '../flutter_qa_inspector.dart';

/// What a [BugWidgetSelection] points at.
enum BugSelectionKind {
  /// A [BugInspectable], selected by tapping inside its border.
  widget,

  /// A [BugInspectablePage], selected with the page button.
  page,
}

/// Everything the inspector captured about the widget or page the tester
/// selected.
///
/// It is created at the moment of the selection, before the inspect mode
/// changes or any route is opened. Use [toJson] to attach it to a bug report.
@immutable
class BugWidgetSelection {
  /// Creates a selection.
  const BugWidgetSelection({
    required this.id,
    required this.widgetType,
    required this.bounds,
    required this.capturedAtUtc,
    this.kind = BugSelectionKind.widget,
    this.widgetState = const <String, Object?>{},
    this.widgetStateCaptureErrorType,
    this.label,
    this.sourceFile,
    this.sourceLine,
    this.routeName,
    this.blocs = const <BugBlocSnapshot>[],
    this.stateHistory = const <BugStateRecord>[],
    this.network = const <BugNetworkRecord>[],
  });

  /// Whether a single widget or a whole page was selected.
  final BugSelectionKind kind;

  /// The stable [BugInspectable.id] or [BugInspectablePage.id], for example
  /// `home.quick_add_water`.
  final String id;

  /// The runtime type of [BugInspectable.child] or [BugInspectablePage.child],
  /// for example `FilledButton`.
  final String widgetType;

  /// The parameters of the same `child` as [widgetType], as returned by
  /// [BugInspectableWidget.bugSnapshot], for example
  /// `{'productId': 'p1', 'inStock': true}`.
  ///
  /// Empty when the class of the `child` does not use [BugInspectableWidget],
  /// or when the capture failed (see [widgetStateCaptureErrorType]).
  final Map<String, Object?> widgetState;

  /// The runtime type of the error thrown while building [widgetState], or
  /// `null` when the capture succeeded or the `child` does not use
  /// [BugInspectableWidget].
  final String? widgetStateCaptureErrorType;

  /// The optional human readable label.
  final String? label;

  /// The source file given to the inspectable, relative to the repository
  /// root.
  final String? sourceFile;

  /// The source line given to the inspectable.
  final int? sourceLine;

  /// The `RouteSettings.name` of the route that contains the selection, when
  /// the route has one.
  final String? routeName;

  /// The bounding box of the widget or page in global logical pixels.
  ///
  /// It is the outer box, it does not account for clipping, rounded corners
  /// or transforms other than their bounding box.
  final Rect bounds;

  /// When the selection was captured, in UTC.
  final DateTime capturedAtUtc;

  /// Snapshots of the BLoC/Cubit instances exposed by [BugBlocScope]s.
  ///
  /// For a widget: the scopes above it, nearest first. For a page: the scopes
  /// inside the page in tree order, then the scopes above it, nearest first.
  /// An instance appears once.
  final List<BugBlocSnapshot> blocs;

  /// State history within [BugInspector.historyWindow] before [capturedAtUtc],
  /// oldest first.
  final List<BugStateRecord> stateHistory;

  /// The API calls kept by [BugInspector.networkRecorder] at [capturedAtUtc],
  /// within [BugInspector.networkHistoryWindow], in the order they started,
  /// oldest first. A call still running is [BugNetworkRecordStatus.pending].
  ///
  /// Like [stateHistory], it holds the calls of the whole app, not only those
  /// of the selected widget.
  final List<BugNetworkRecord> network;

  /// Converts the selection into a JSON compatible map.
  Map<String, Object?> toJson() {
    final source = <String, Object?>{
      if (sourceFile != null) 'file': sourceFile,
      if (sourceLine != null) 'line': sourceLine,
    };
    return <String, Object?>{
      'kind': kind.name,
      'id': id,
      'widgetType': widgetType,
      'widgetState': widgetState,
      if (widgetStateCaptureErrorType != null)
        'widgetStateCaptureErrorType': widgetStateCaptureErrorType,
      if (label != null) 'label': label,
      if (routeName != null) 'route': <String, Object?>{'name': routeName},
      if (source.isNotEmpty) 'source': source,
      'bounds': <String, Object?>{
        'left': bounds.left,
        'top': bounds.top,
        'width': bounds.width,
        'height': bounds.height,
        'coordinateUnit': 'logical_pixels',
      },
      'capturedAtUtc': capturedAtUtc.toUtc().toIso8601String(),
      'blocs': <Object?>[for (final bloc in blocs) bloc.toJson()],
      'stateHistory': <Object?>[
        for (final record in stateHistory) record.toJson(),
      ],
      'network': <Object?>[for (final record in network) record.toJson()],
    };
  }

  @override
  String toString() => 'BugWidgetSelection(${kind.name}: $id, '
      'widgetType: $widgetType, widgetState: $widgetState, '
      'bounds: $bounds, blocs: ${blocs.length}, '
      'stateHistory: ${stateHistory.length}, network: ${network.length})';
}

/// The state of one BLoC/Cubit instance at the moment of the selection.
@immutable
class BugBlocSnapshot {
  /// Creates a snapshot.
  const BugBlocSnapshot({
    required this.id,
    required this.type,
    required this.instanceId,
    required this.state,
    this.stateType,
    this.captureErrorType,
  });

  /// The [BugBlocScope.id], for example `counter_cubit`.
  final String id;

  /// The runtime type of the BLoC/Cubit, for example `CounterCubit`.
  final String type;

  /// Identifies the instance within the current run. Matches
  /// [BugStateRecord.instanceId] of the records produced by the same instance.
  final String instanceId;

  /// The runtime type of the state that was read.
  final String? stateType;

  /// The JSON value returned by [BugBlocScope.snapshotBuilder], or an empty map
  /// when the capture failed.
  final Object? state;

  /// The runtime type of the error thrown while building the snapshot, or
  /// `null` when the capture succeeded.
  final String? captureErrorType;

  /// Whether the snapshot could not be built.
  bool get hasCaptureError => captureErrorType != null;

  /// Converts the snapshot into a JSON compatible map.
  Map<String, Object?> toJson() => <String, Object?>{
        'id': id,
        'type': type,
        'instanceId': instanceId,
        if (stateType != null) 'stateType': stateType,
        'state': state,
        if (captureErrorType != null) 'captureErrorType': captureErrorType,
      };

  @override
  String toString() => 'BugBlocSnapshot(id: $id, type: $type, '
      'instanceId: $instanceId, state: $state'
      '${captureErrorType == null ? '' : ', error: $captureErrorType'})';
}

/// The kind of a [BugStateRecord].
enum BugStateRecordKind {
  /// A BLoC or Cubit was created.
  created,

  /// A BLoC or Cubit was closed.
  closed,

  /// A BLoC or Cubit reported an error.
  error,

  /// A BLoC received an event.
  event,

  /// A BLoC emitted a state in response to an event.
  transition,

  /// A Cubit emitted a state.
  change,
}

/// One entry of the state timeline kept by [BugStateRecorder].
///
/// Only type names are stored, never state values. The state value at the
/// moment of the selection lives in [BugBlocSnapshot.state].
@immutable
class BugStateRecord {
  /// Creates a record.
  const BugStateRecord({
    required this.timestampUtc,
    required this.kind,
    required this.blocType,
    required this.instanceId,
    this.stateType,
    this.fromStateType,
    this.toStateType,
    this.eventType,
    this.errorType,
  });

  /// When the record was taken, in UTC.
  final DateTime timestampUtc;

  /// What happened.
  final BugStateRecordKind kind;

  /// The runtime type of the BLoC/Cubit.
  final String blocType;

  /// Identifies the instance within the current run. Matches
  /// [BugBlocSnapshot.instanceId].
  final String instanceId;

  /// The state type for [BugStateRecordKind.created] and
  /// [BugStateRecordKind.closed].
  final String? stateType;

  /// The previous state type for [BugStateRecordKind.change] and
  /// [BugStateRecordKind.transition].
  final String? fromStateType;

  /// The next state type for [BugStateRecordKind.change] and
  /// [BugStateRecordKind.transition].
  final String? toStateType;

  /// The event type for [BugStateRecordKind.event] and
  /// [BugStateRecordKind.transition].
  final String? eventType;

  /// The error type for [BugStateRecordKind.error].
  final String? errorType;

  /// Converts the record into a JSON compatible map.
  Map<String, Object?> toJson() => <String, Object?>{
        'timestampUtc': timestampUtc.toUtc().toIso8601String(),
        'kind': kind.name,
        'blocType': blocType,
        'instanceId': instanceId,
        if (stateType != null) 'stateType': stateType,
        if (eventType != null) 'eventType': eventType,
        if (fromStateType != null) 'fromStateType': fromStateType,
        if (toStateType != null) 'toStateType': toStateType,
        if (errorType != null) 'errorType': errorType,
      };

  @override
  String toString() => 'BugStateRecord(${toJson()})';
}

/// Thrown when a [BugBlocScope.snapshotBuilder] or a
/// [BugInspectableWidget.bugSnapshot] returns a value that is not JSON
/// compatible.
class BugSnapshotFormatException implements Exception {
  /// Creates the exception for the value found at [path].
  const BugSnapshotFormatException(this.path, this.message);

  /// Where the offending value is, for example `$.items[2].createdAt`.
  final String path;

  /// What is wrong with the value.
  final String message;

  @override
  String toString() => 'BugSnapshotFormatException: $message at $path';
}

/// Returns a deep, unmodifiable copy of [value] after checking that it only
/// contains strings, finite numbers, booleans, `null`, lists and maps with
/// string keys.
///
/// Throws a [BugSnapshotFormatException] otherwise.
Object? _copyJsonValue(Object? value, [String path = r'$']) {
  if (value == null || value is bool || value is String || value is int) {
    return value;
  }
  if (value is double) {
    if (!value.isFinite) {
      throw BugSnapshotFormatException(path, 'Non-finite number $value');
    }
    return value;
  }
  if (value is List<Object?>) {
    return List<Object?>.unmodifiable(<Object?>[
      for (var i = 0; i < value.length; i++)
        _copyJsonValue(value[i], '$path[$i]'),
    ]);
  }
  if (value is Map<Object?, Object?>) {
    final copy = <String, Object?>{};
    for (final entry in value.entries) {
      final key = entry.key;
      if (key is! String) {
        throw BugSnapshotFormatException(
          path,
          'Map key of type ${key.runtimeType} is not a String',
        );
      }
      copy[key] = _copyJsonValue(entry.value, '$path.$key');
    }
    return Map<String, Object?>.unmodifiable(copy);
  }
  throw BugSnapshotFormatException(
    path,
    'Unsupported value of type ${value.runtimeType}. Convert enums with '
    '`.name` and dates with `.toIso8601String()`',
  );
}
