import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_qa_inspector/flutter_qa_inspector.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/app_parity.dart';
import 'support/build_mode.dart';
import 'support/test_host.dart';

void main() => qaBuildOnly(() {
      group('enabled: false', () {
        testWidgets('leaves the app as if the package were not used',
            (tester) async {
          final semanticsHandle = tester.ensureSemantics();
          final screen = ParityScreen();
          final (renderWithout, semanticsWithout) =
              await pumpWithoutPackage(tester, screen);

          final created = CreatedObserver();
          useObserver(created);
          await pumpHost(
            tester,
            enabled: false,
            home: screen.build(withPackage: true),
          );

          // The QA build adds an element per marker but no render object.
          expect(renderTypesOf(tester), renderWithout);
          expect(semanticsOf(tester), semanticsWithout);
          expect(launcher, findsNothing);
          expect(created.created, isEmpty);

          final context = tester.element(find.text('Tap'));
          expect(BugInspector.maybeModeCubitOf(context), isNull);
          expect(
            await BugInspector.captureScreenshot(
              context,
              waitForNextFrame: false,
            ),
            isNull,
          );

          await screen.use(tester);
          screen.expectUsed();
          expect(screen.lazyReads, 0);
          expect(screen.widgetStateReads, 0);
          semanticsHandle.dispose();
        });

        testWidgets('releases the cubit when set while running',
            (tester) async {
          await pumpHost(tester, home: const SizedBox.expand());
          final cubit = modeOf(tester);

          await pumpHost(tester, enabled: false, home: const SizedBox.expand());
          expect(cubit.isClosed, isTrue);
          expect(launcher, findsNothing);

          await pumpHost(tester, home: const SizedBox.expand());
          expect(modeOf(tester), isNot(same(cubit)));
          await tester.tap(launcher);
          await pumpModeChange(tester);
          expect(modeOf(tester).state, InspectMode.selecting);
        });
      });

      group('BugBlocScope.lazy', () {
        testWidgets('reads the bloc only when a widget is selected',
            (tester) async {
          final counter = CounterCubit();
          addTearDown(counter.close);
          var reads = 0;
          final selections = await pumpHost(
            tester,
            home: BlocProvider<CounterCubit>.value(
              value: counter,
              child: BugBlocScope<int>.lazy(
                id: 'counter',
                readBloc: (context) {
                  reads++;
                  return context.read<CounterCubit>();
                },
                snapshotBuilder: (value) => <String, Object?>{'value': value},
                child: Center(
                  child: BugInspectable(id: 'a', child: box(80, 80)),
                ),
              ),
            ),
          );
          counter.increment();
          await enable(tester);
          expect(reads, 0);

          await tapCenterOf(tester, inspectable('a'));
          expect(reads, 1);
          final snapshot = selections.single.blocs.single;
          expect(snapshot.id, 'counter');
          expect(snapshot.type, 'CounterCubit');
          expect(snapshot.instanceId, BugStateRecorder.instanceIdOf(counter));
          expect(snapshot.state, <String, Object?>{'value': 1});
        });

        testWidgets('reports a bloc it cannot read and keeps the other scopes',
            (tester) async {
          final counter = CounterCubit();
          addTearDown(counter.close);
          final selections = await pumpHost(
            tester,
            home: BugBlocScope<int>(
              id: 'outer',
              bloc: counter,
              snapshotBuilder: (value) => <String, Object?>{'value': value},
              child: BugBlocScope<int>.lazy(
                id: 'missing',
                // No provider above: context.read throws.
                readBloc: (context) => context.read<CounterCubit>(),
                snapshotBuilder: (value) => <String, Object?>{'value': value},
                child: Center(
                  child: BugInspectable(id: 'a', child: box(80, 80)),
                ),
              ),
            ),
          );
          await enable(tester);
          await tapCenterOf(tester, inspectable('a'));

          final blocs = selections.single.blocs;
          expect(
            blocs.map((snapshot) => snapshot.id),
            <String>['missing', 'outer'],
          );
          expect(blocs.first.captureErrorType, isNotNull);
          expect(blocs.first.type, 'unknown');
          expect(blocs.first.state, <String, Object?>{});
          expect(blocs.last.hasCaptureError, isFalse);
        });
      });

      test('a failing observer never breaks the emit that triggered it', () {
        final recorder = BugStateRecorder();
        useObserver(
          BugInspectorBlocObserver(
            recorder: recorder,
            filter: (_) => throw StateError('filter'),
          ),
        );
        final counter = CounterCubit();
        expect(counter.increment, returnsNormally);
        expect(counter.state, 1);
        expect(counter.close, returnsNormally);
        expect(recorder.records, isEmpty);
      });
    });
