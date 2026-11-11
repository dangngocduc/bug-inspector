import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_qa_inspector/flutter_qa_inspector.dart';
import 'package:flutter_test/flutter_test.dart';

class _CounterCubit extends Cubit<int> {
  _CounterCubit() : super(0);

  void increment() => emit(state + 1);

  void fail() => addError(StateError('failed'));
}

sealed class _CounterEvent {}

class _Incremented extends _CounterEvent {}

class _CounterBloc extends Bloc<_CounterEvent, int> {
  _CounterBloc() : super(0) {
    on<_Incremented>((event, emit) => emit(state + 1));
  }
}

class _CountingObserver extends BlocObserver {
  int changes = 0;

  @override
  void onChange(BlocBase<dynamic> bloc, Change<dynamic> change) {
    super.onChange(bloc, change);
    changes++;
  }
}

BugStateRecord _record(DateTime timestampUtc, [String type = 'A']) {
  return BugStateRecord(
    timestampUtc: timestampUtc,
    kind: BugStateRecordKind.change,
    blocType: type,
    instanceId: '1',
  );
}

void main() {
  group('BugStateRecorder', () {
    test('keeps at most maxRecords and drops the oldest', () {
      final recorder = BugStateRecorder(maxRecords: 3);
      for (var i = 0; i < 5; i++) {
        recorder.add(_record(DateTime.utc(2026, 1, 1, 0, 0, i), 'T$i'));
      }
      expect(recorder.length, 3);
      expect(
        recorder.records.map((record) => record.blocType),
        <String>['T2', 'T3', 'T4'],
      );
    });

    test('defaults to 300 records', () {
      final recorder = BugStateRecorder();
      for (var i = 0; i < 310; i++) {
        recorder.add(_record(DateTime.utc(2026)));
      }
      expect(recorder.maxRecords, 300);
      expect(recorder.length, 300);
    });

    test('recordsSince returns the records inside the window', () {
      final now = DateTime.utc(2026, 1, 1, 12);
      final recorder = BugStateRecorder(clock: () => now);
      recorder
        ..add(_record(now.subtract(const Duration(seconds: 31)), 'old'))
        ..add(_record(now.subtract(const Duration(seconds: 30)), 'edge'))
        ..add(_record(now.subtract(const Duration(seconds: 1)), 'recent'))
        ..add(_record(now.add(const Duration(seconds: 1)), 'future'));

      expect(
        recorder
            .recordsSince(const Duration(seconds: 30))
            .map((record) => record.blocType),
        <String>['edge', 'recent'],
      );
      expect(
        recorder
            .recordsSince(
              const Duration(seconds: 5),
              nowUtc: now.add(const Duration(seconds: 2)),
            )
            .map((record) => record.blocType),
        <String>['recent', 'future'],
      );
    });

    test('instanceIdOf is stable per instance and unique', () {
      final a = Object();
      final b = Object();
      expect(
          BugStateRecorder.instanceIdOf(a), BugStateRecorder.instanceIdOf(a));
      expect(
        BugStateRecorder.instanceIdOf(a),
        isNot(BugStateRecorder.instanceIdOf(b)),
      );
    });
  });

  group('BugInspectorBlocObserver', () {
    late BlocObserver previousObserver;

    setUp(() => previousObserver = Bloc.observer);
    tearDown(() => Bloc.observer = previousObserver);

    test('records cubit activity', () async {
      final recorder = BugStateRecorder();
      Bloc.observer = BugInspectorBlocObserver(recorder: recorder);

      final cubit = _CounterCubit()
        ..increment()
        ..fail();
      await cubit.close();

      final id = BugStateRecorder.instanceIdOf(cubit);
      expect(
        recorder.records.map((record) => record.kind),
        <BugStateRecordKind>[
          BugStateRecordKind.created,
          BugStateRecordKind.change,
          BugStateRecordKind.error,
          BugStateRecordKind.closed,
        ],
      );
      expect(
          recorder.records.every((record) => record.instanceId == id), isTrue);
      expect(recorder.records.every((r) => r.timestampUtc.isUtc), isTrue);

      final change = recorder.records[1];
      expect(change.blocType, '_CounterCubit');
      expect(change.fromStateType, 'int');
      expect(change.toStateType, 'int');
      expect(recorder.records[2].errorType, 'StateError');
      expect(recorder.records.first.stateType, 'int');
    });

    test('records bloc events and transitions without duplicate changes',
        () async {
      final recorder = BugStateRecorder();
      Bloc.observer = BugInspectorBlocObserver(recorder: recorder);

      final bloc = _CounterBloc()..add(_Incremented());
      await Future<void>.delayed(Duration.zero);
      await bloc.close();

      expect(
        recorder.records.map((record) => record.kind),
        <BugStateRecordKind>[
          BugStateRecordKind.created,
          BugStateRecordKind.event,
          BugStateRecordKind.transition,
          BugStateRecordKind.closed,
        ],
      );
      final transition = recorder.records[2];
      expect(transition.eventType, '_Incremented');
      expect(transition.fromStateType, 'int');
      expect(transition.toStateType, 'int');
      expect(recorder.records[1].eventType, '_Incremented');
    });

    test('ignores InspectModeCubit and honours the filter', () async {
      final recorder = BugStateRecorder();
      Bloc.observer = BugInspectorBlocObserver(
        recorder: recorder,
        filter: (bloc) => bloc is! _CounterBloc,
      );

      final mode = InspectModeCubit()..enable();
      final bloc = _CounterBloc()..add(_Incremented());
      final cubit = _CounterCubit()..increment();
      await Future<void>.delayed(Duration.zero);
      await Future.wait(<Future<void>>[
        mode.close(),
        bloc.close(),
        cubit.close(),
      ]);

      expect(
        recorder.records.map((record) => record.blocType).toSet(),
        <String>{'_CounterCubit'},
      );
    });

    test('keeps the app observer through MultiBlocObserver', () async {
      final recorder = BugStateRecorder();
      final appObserver = _CountingObserver();
      Bloc.observer = MultiBlocObserver(
        observers: <BlocObserver>[
          appObserver,
          BugInspectorBlocObserver(recorder: recorder),
        ],
      );

      final cubit = _CounterCubit()
        ..increment()
        ..increment();
      await cubit.close();

      expect(appObserver.changes, 2);
      expect(
        recorder.records
            .where((record) => record.kind == BugStateRecordKind.change),
        hasLength(2),
      );
    });
  });

  group('InspectModeCubit', () {
    test('enable, disable and toggle', () async {
      final cubit = InspectModeCubit();
      expect(cubit.state, InspectMode.disabled);
      cubit.enable();
      expect(cubit.isSelecting, isTrue);
      cubit.disable();
      expect(cubit.state, InspectMode.disabled);
      cubit.toggle();
      expect(cubit.state, InspectMode.selecting);
      cubit.toggle();
      expect(cubit.state, InspectMode.disabled);
      await cubit.close();
      // Calls after close are ignored instead of throwing.
      expect(cubit.enable, returnsNormally);
    });
  });
}
