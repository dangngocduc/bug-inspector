// Run with `flutter test`, without --dart-define=FLUTTER_QA_INSPECTOR=true,
// as a production build is made.
import 'package:bloc/bloc.dart';
import 'package:flutter/material.dart';
import 'package:flutter_qa_inspector/flutter_qa_inspector.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/app_parity.dart';
import 'support/build_mode.dart';

void main() => productionBuildOnly(() {
      test('the inspector is compiled out', () {
        expect(BugInspector.enabledFromEnvironment, isFalse);
      });

      testWidgets(
          'a full integration leaves the app as if the package were not used',
          (tester) async {
        final semanticsHandle = tester.ensureSemantics();
        final screen = ParityScreen();
        final (renderWithout, semanticsWithout) =
            await pumpWithoutPackage(tester, screen);

        // Everything a QA build would do, left in the production code.
        final created = CreatedObserver();
        final recorder = BugStateRecorder();
        useObserver(
          MultiBlocObserver(
            observers: <BlocObserver>[
              created,
              BugInspectorBlocObserver(recorder: recorder),
            ],
          ),
        );
        var selections = 0;
        await tester.pumpWidget(
          MaterialApp(
            builder: (context, child) => BugInspector(
              stateRecorder: recorder,
              onWidgetSelected: (_, __) => selections++,
              child: child!,
            ),
            home: screen.build(withPackage: true),
          ),
        );

        // Same render objects (no border box, no layers around the app, no
        // floating control) and the same semantics: layout, painting, hit
        // testing and accessibility are untouched.
        expect(renderTypesOf(tester), renderWithout);
        expect(semanticsOf(tester), semanticsWithout);
        expect(find.byKey(BugInspector.launcherKey), findsNothing);

        // Each widget of the package builds its child directly.
        final markers = find
            .byWidgetPredicate((widget) => _childOf(widget) != null)
            .evaluate();
        expect(
          markers.map((marker) => marker.widget.runtimeType).toSet(),
          <Type>{
            BugInspector,
            BugInspectablePage,
            BugInspectable,
            BugBlocScope<int>,
          },
        );
        for (final marker in markers) {
          Element? built;
          marker.visitChildElements((child) => built = child);
          expect(built?.widget, same(_childOf(marker.widget)));
        }

        // The inspector creates and reads nothing, and the observer records
        // nothing, even for a cubit created after it was installed.
        expect(created.created, isEmpty);
        final lateCubit = CounterCubit()..increment();
        await lateCubit.close();
        expect(created.created, <Object>[lateCubit]);
        expect(recorder.records, isEmpty);
        expect(screen.lazyReads, 0);
        expect(screen.widgetStateReads, 0);

        final context = tester.element(find.text('Tap'));
        expect(BugInspector.maybeModeCubitOf(context), isNull);
        expect(
          await BugInspector.captureScreenshot(context),
          isNull,
        );

        // The app keeps its input.
        await screen.use(tester);
        screen.expectUsed();
        expect(selections, 0);
        expect(screen.lazyReads, 0);
        expect(screen.widgetStateReads, 0);
        semanticsHandle.dispose();
      });
    });

/// The child of a widget of the package, or `null` for any other widget.
Widget? _childOf(Widget widget) => switch (widget) {
      BugInspector(:final child) => child,
      BugInspectablePage(:final child) => child,
      BugInspectable(:final child) => child,
      BugBlocScope<Object?>(:final child) => child,
      _ => null,
    };
