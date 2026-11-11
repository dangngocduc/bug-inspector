import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_qa_inspector/flutter_qa_inspector.dart';
import 'package:flutter_test/flutter_test.dart';

enum _Status { idle }

class _ValueCubit<T> extends Cubit<T> {
  _ValueCubit(super.initialState);
}

void main() {
  group('BugWidgetSelection.toJson', () {
    test('matches the documented payload', () {
      final selection = BugWidgetSelection(
        id: 'counter.increment',
        widgetType: 'FilledButton',
        sourceFile: 'lib/main.dart',
        bounds: const Rect.fromLTWH(142, 388, 108, 48),
        capturedAtUtc: DateTime.utc(2026, 11, 11, 7, 40, 3, 123),
        blocs: const <BugBlocSnapshot>[
          BugBlocSnapshot(
            id: 'counter_cubit',
            type: 'CounterCubit',
            instanceId: '2a3b4c',
            stateType: 'int',
            state: <String, Object?>{'value': 2},
          ),
        ],
        stateHistory: <BugStateRecord>[
          BugStateRecord(
            timestampUtc: DateTime.utc(2026, 11, 11, 7, 40, 1, 712),
            kind: BugStateRecordKind.change,
            blocType: 'CounterCubit',
            instanceId: '2a3b4c',
            fromStateType: 'int',
            toStateType: 'int',
          ),
        ],
      );

      expect(selection.toJson(), <String, Object?>{
        'kind': 'widget',
        'id': 'counter.increment',
        'widgetType': 'FilledButton',
        'source': <String, Object?>{'file': 'lib/main.dart'},
        'bounds': <String, Object?>{
          'left': 142.0,
          'top': 388.0,
          'width': 108.0,
          'height': 48.0,
          'coordinateUnit': 'logical_pixels',
        },
        'capturedAtUtc': '2026-11-11T07:40:03.123Z',
        'blocs': <Object?>[
          <String, Object?>{
            'id': 'counter_cubit',
            'type': 'CounterCubit',
            'instanceId': '2a3b4c',
            'stateType': 'int',
            'state': <String, Object?>{'value': 2},
          },
        ],
        'stateHistory': <Object?>[
          <String, Object?>{
            'timestampUtc': '2026-11-11T07:40:01.712Z',
            'kind': 'change',
            'blocType': 'CounterCubit',
            'instanceId': '2a3b4c',
            'fromStateType': 'int',
            'toStateType': 'int',
          },
        ],
      });
      // The payload is encodable as is.
      expect(() => jsonEncode(selection.toJson()), returnsNormally);
    });

    test('adds label, route and source line, omits empty ones', () {
      final withLine = BugWidgetSelection(
        id: 'a',
        widgetType: 'Text',
        label: 'Title',
        sourceFile: 'lib/a.dart',
        sourceLine: 12,
        routeName: '/details',
        bounds: Rect.zero,
        capturedAtUtc: DateTime.utc(2026),
      ).toJson();
      expect(withLine['label'], 'Title');
      expect(withLine['kind'], 'widget');
      expect(withLine['route'], <String, Object?>{'name': '/details'});
      expect(withLine['source'], <String, Object?>{
        'file': 'lib/a.dart',
        'line': 12,
      });

      final bare = BugWidgetSelection(
        id: 'a',
        widgetType: 'Text',
        bounds: Rect.zero,
        capturedAtUtc: DateTime.utc(2026),
      ).toJson();
      expect(bare.containsKey('source'), isFalse);
      expect(bare.containsKey('route'), isFalse);
      expect(bare.containsKey('label'), isFalse);
      expect(bare['blocs'], isEmpty);
      expect(bare['stateHistory'], isEmpty);
    });
  });

  group('BugBlocScope.capture', () {
    BugBlocScope<S> scope<S>(S state, Object? Function(S) builder) {
      return BugBlocScope<S>(
        id: 'scope',
        bloc: _ValueCubit<S>(state),
        snapshotBuilder: builder,
        child: const SizedBox(),
      );
    }

    test('copies nested JSON values', () {
      final source = <String, Object?>{
        'status': 'loaded',
        'items': <Object?>[
          1,
          2.5,
          true,
          null,
          <String, Object?>{'a': 'b'},
        ],
      };
      final snapshot = scope<int>(1, (_) => source).capture();

      expect(snapshot.hasCaptureError, isFalse);
      expect(snapshot.type, '_ValueCubit<int>');
      expect(snapshot.stateType, 'int');
      expect(snapshot.state, source);
      // Later changes to the builder result do not leak into the snapshot.
      (source['items']! as List<Object?>).add('late');
      expect((snapshot.state! as Map<String, Object?>)['items'], hasLength(5));
    });

    test('rejects values that are not JSON', () {
      final invalid = <Object?>[
        _Status.idle,
        DateTime.utc(2026),
        double.nan,
        double.infinity,
        <int, Object?>{1: 'a'},
        <String, Object?>{
          'nested': <Object?>[Object()],
        },
        <int>{1},
      ];
      for (final value in invalid) {
        final snapshot = scope<int>(0, (_) => value).capture();
        expect(
          snapshot.captureErrorType,
          'BugSnapshotFormatException',
          reason: '$value',
        );
        expect(snapshot.state, <String, Object?>{});
      }
    });

    test('reports the error type when the builder throws', () {
      final snapshot = scope<int>(0, (_) => throw StateError('boom')).capture();
      expect(snapshot.captureErrorType, 'StateError');
      expect(snapshot.state, <String, Object?>{});
      expect(snapshot.stateType, 'int');
      expect(snapshot.toJson()['captureErrorType'], 'StateError');
    });

    test('accepts enum names and ISO dates', () {
      final snapshot = scope<_Status>(
        _Status.idle,
        (state) => <String, Object?>{
          'status': state.name,
          'at': DateTime.utc(2026).toIso8601String(),
        },
      ).capture();
      expect(snapshot.state, <String, Object?>{
        'status': 'idle',
        'at': '2026-01-01T00:00:00.000Z',
      });
    });
  });
}
