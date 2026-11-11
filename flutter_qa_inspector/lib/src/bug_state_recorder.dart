part of '../flutter_qa_inspector.dart';

/// Keeps a bounded, in-memory timeline of BLoC/Cubit activity.
///
/// Feed it with [BugInspectorBlocObserver] and pass the same instance to
/// [BugInspector.stateRecorder] so selections include the recent history.
class BugStateRecorder {
  /// Creates a recorder that keeps at most [maxRecords] records.
  ///
  /// [clock] returns the current time and defaults to [DateTime.now]. It is
  /// mainly useful in tests.
  BugStateRecorder(
      {this.maxRecords = defaultMaxRecords, DateTime Function()? clock})
      : assert(maxRecords > 0, 'maxRecords must be greater than zero'),
        _clock = clock ?? DateTime.now;

  /// The default value of [maxRecords].
  static const int defaultMaxRecords = 300;

  /// The maximum number of records kept. The oldest record is dropped when a
  /// new one is added to a full recorder.
  final int maxRecords;

  final DateTime Function() _clock;
  final ListQueue<BugStateRecord> _records = ListQueue<BugStateRecord>();

  /// The number of records currently kept.
  int get length => _records.length;

  /// All records currently kept, oldest first.
  List<BugStateRecord> get records =>
      List<BugStateRecord>.unmodifiable(_records);

  /// The current time of this recorder's clock, in UTC.
  DateTime nowUtc() => _clock().toUtc();

  /// Adds [record], dropping the oldest records when the recorder is full.
  void add(BugStateRecord record) {
    _records.addLast(record);
    while (_records.length > maxRecords) {
      _records.removeFirst();
    }
  }

  /// Returns the records taken within [window] before [nowUtc], oldest first.
  ///
  /// [nowUtc] defaults to the recorder's clock. Records taken after [nowUtc]
  /// are excluded.
  List<BugStateRecord> recordsSince(Duration window, {DateTime? nowUtc}) {
    final now = (nowUtc ?? this.nowUtc()).toUtc();
    final cutoff = now.subtract(window);
    return List<BugStateRecord>.unmodifiable(
      _records.where(
        (record) =>
            !record.timestampUtc.isBefore(cutoff) &&
            !record.timestampUtc.isAfter(now),
      ),
    );
  }

  /// Removes every record.
  void clear() => _records.clear();

  static final Expando<String> _instanceIds = Expando<String>('bugInstanceId');
  static int _nextInstanceId = 0;

  /// Returns an identifier for [bloc] that is stable for the lifetime of the
  /// instance and unique within the current run.
  ///
  /// [BugBlocSnapshot.instanceId] and [BugStateRecord.instanceId] use it, so a
  /// snapshot can be matched with the records of the same instance.
  static String instanceIdOf(Object bloc) {
    return _instanceIds[bloc] ??=
        (++_nextInstanceId).toRadixString(16).padLeft(6, '0');
  }
}

/// Decides whether [BugInspectorBlocObserver] records the activity of [bloc].
typedef BugStateRecordFilter = bool Function(BlocBase<dynamic> bloc);

/// A [BlocObserver] that writes BLoC/Cubit activity into a [BugStateRecorder].
///
/// Install it before any BLoC/Cubit is created and keep the app's existing
/// observer with `MultiBlocObserver` (bloc 9.2.0 or later):
///
/// ```dart
/// Bloc.observer = MultiBlocObserver(
///   observers: [Bloc.observer, BugInspectorBlocObserver(recorder: recorder)],
/// );
/// ```
///
/// The [InspectModeCubit] of the inspector itself is never recorded.
class BugInspectorBlocObserver extends BlocObserver {
  /// Creates an observer that writes into [recorder].
  ///
  /// When [filter] is given, only the instances it accepts are recorded.
  const BugInspectorBlocObserver({required this.recorder, this.filter});

  /// Where the records are written.
  final BugStateRecorder recorder;

  /// Optional filter applied to every instance.
  final BugStateRecordFilter? filter;

  bool _accepts(BlocBase<dynamic> bloc) {
    if (bloc is InspectModeCubit) return false;
    return filter?.call(bloc) ?? true;
  }

  void _record(
    BlocBase<dynamic> bloc,
    BugStateRecordKind kind, {
    String? stateType,
    String? fromStateType,
    String? toStateType,
    String? eventType,
    String? errorType,
  }) {
    if (!_accepts(bloc)) return;
    recorder.add(
      BugStateRecord(
        timestampUtc: recorder.nowUtc(),
        kind: kind,
        blocType: bloc.runtimeType.toString(),
        instanceId: BugStateRecorder.instanceIdOf(bloc),
        stateType: stateType,
        fromStateType: fromStateType,
        toStateType: toStateType,
        eventType: eventType,
        errorType: errorType,
      ),
    );
  }

  static String _typeOf(Object? value) => value.runtimeType.toString();

  @override
  void onCreate(BlocBase<dynamic> bloc) {
    super.onCreate(bloc);
    _record(
      bloc,
      BugStateRecordKind.created,
      stateType: _typeOf(bloc.state),
    );
  }

  @override
  void onEvent(Bloc<dynamic, dynamic> bloc, Object? event) {
    super.onEvent(bloc, event);
    _record(bloc, BugStateRecordKind.event, eventType: _typeOf(event));
  }

  @override
  void onTransition(
    Bloc<dynamic, dynamic> bloc,
    Transition<dynamic, dynamic> transition,
  ) {
    super.onTransition(bloc, transition);
    _record(
      bloc,
      BugStateRecordKind.transition,
      eventType: _typeOf(transition.event),
      fromStateType: _typeOf(transition.currentState),
      toStateType: _typeOf(transition.nextState),
    );
  }

  @override
  void onChange(BlocBase<dynamic> bloc, Change<dynamic> change) {
    super.onChange(bloc, change);
    // A Bloc reports every change through onTransition as well.
    if (bloc is Bloc<dynamic, dynamic>) return;
    _record(
      bloc,
      BugStateRecordKind.change,
      fromStateType: _typeOf(change.currentState),
      toStateType: _typeOf(change.nextState),
    );
  }

  @override
  void onError(BlocBase<dynamic> bloc, Object error, StackTrace stackTrace) {
    super.onError(bloc, error, stackTrace);
    _record(bloc, BugStateRecordKind.error, errorType: _typeOf(error));
  }

  @override
  void onClose(BlocBase<dynamic> bloc) {
    super.onClose(bloc);
    _record(
      bloc,
      BugStateRecordKind.closed,
      stateType: _typeOf(bloc.state),
    );
  }
}
