import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_qa_inspector/flutter_qa_inspector.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/test_host.dart';

class _CounterCubit extends Cubit<int> {
  _CounterCubit([super.initialState = 0]);

  void increment() => emit(state + 1);
}

class _CounterPage extends StatelessWidget {
  const _CounterPage();

  @override
  Widget build(BuildContext context) {
    return BugBlocScope<int>(
      id: 'counter_cubit',
      bloc: context.read<_CounterCubit>(),
      snapshotBuilder: (value) => <String, Object?>{'value': value},
      child: Scaffold(
        body: Center(
          child: BlocBuilder<_CounterCubit, int>(
            builder: (context, value) => BugInspectable(
              id: 'counter.increment',
              label: 'Increment',
              sourceFile: 'lib/main.dart',
              sourceLine: 42,
              child: FilledButton(
                onPressed: context.read<_CounterCubit>().increment,
                child: Text('Tăng ($value)'),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

void main() {
  testWidgets('outside a host it only returns its child', (tester) async {
    await tester.pumpWidget(
      const Directionality(
        textDirection: TextDirection.ltr,
        child: BugInspectable(id: 'alone', child: Text('child')),
      ),
    );
    expect(tester.renderObject(find.byType(BugInspectable)),
        isA<RenderParagraph>());
  });

  group('mode', () {
    testWidgets('disabled: the app receives taps and no border is painted',
        (tester) async {
      final cubit = _CounterCubit();
      addTearDown(cubit.close);
      final selections = await pumpHost(
        tester,
        home: BlocProvider<_CounterCubit>.value(
          value: cubit,
          child: const _CounterPage(),
        ),
      );

      expect(find.byType(BugInspectable), isNot(paintsBorder));
      await tester.tap(find.byType(FilledButton));
      await tester.pump();
      expect(cubit.state, 1);
      expect(selections, isEmpty);
    });

    testWidgets('enable() paints borders, keeps the layout and blocks input',
        (tester) async {
      final cubit = _CounterCubit();
      addTearDown(cubit.close);
      await pumpHost(
        tester,
        home: BlocProvider<_CounterCubit>.value(
          value: cubit,
          child: const _CounterPage(),
        ),
        disableModeOnSelection: false,
      );
      final rectBefore = tester.getRect(find.byType(FilledButton));

      await enable(tester);

      expect(find.byType(BugInspectable), paintsBorder);
      expect(tester.getRect(find.byType(FilledButton)), rectBefore);
      await tapCenterOf(tester, find.byType(FilledButton));
      expect(cubit.state, 0,
          reason: 'the selection tap must not reach the app');
    });

    testWidgets('scrolling is blocked while selecting', (tester) async {
      final controller = ScrollController();
      addTearDown(controller.dispose);
      final selections = await pumpHost(
        tester,
        home: Scaffold(
          body: BugInspectable(
            id: 'list',
            child: ListView(
              controller: controller,
              children: <Widget>[
                for (var i = 0; i < 50; i++)
                  SizedBox(height: 50, child: Text('item $i')),
              ],
            ),
          ),
        ),
      );
      final center = tester.getCenter(find.byType(ListView));

      await enable(tester);
      await tester.dragFrom(center, const Offset(0, -300));
      await tester.pump();
      expect(controller.offset, 0);
      expect(selections, isEmpty, reason: 'a drag is not a tap');

      await disable(tester);
      await tester.dragFrom(center, const Offset(0, -300));
      await tester.pump();
      expect(controller.offset, greaterThan(0));
    });

    testWidgets('the exit button disables the mode', (tester) async {
      final cubit = _CounterCubit();
      addTearDown(cubit.close);
      await pumpHost(
        tester,
        home: BlocProvider<_CounterCubit>.value(
          value: cubit,
          child: const _CounterPage(),
        ),
      );
      await enable(tester);
      expect(find.text(BugInspector.defaultExitButtonLabel), findsOneWidget);

      await tester
          .tap(find.byKey(const ValueKey<String>('bug_inspector.exit_button')));
      await tester.pump();

      expect(modeOf(tester).state, InspectMode.disabled);
      expect(find.text(BugInspector.defaultExitButtonLabel), findsNothing);
      expect(find.byType(BugInspectable), isNot(paintsBorder));
      await tester.tap(find.byType(FilledButton));
      expect(cubit.state, 1);
    });

    testWidgets('disable() removes the borders', (tester) async {
      await pumpHost(
        tester,
        home: Center(child: BugInspectable(id: 'a', child: box(50, 50))),
      );
      await enable(tester);
      expect(find.byType(BugInspectable), paintsBorder);
      await disable(tester);
      expect(find.byType(BugInspectable), isNot(paintsBorder));
    });

    testWidgets('custom and hidden exit buttons', (tester) async {
      await pumpHost(
        tester,
        home: const SizedBox.expand(),
        exitButtonBuilder: (context, exit) =>
            TextButton(onPressed: exit, child: const Text('Done')),
      );
      await enable(tester);
      await tester.tap(find.text('Done'));
      await tester.pump();
      expect(modeOf(tester).state, InspectMode.disabled);

      await pumpHost(
        tester,
        home: const SizedBox.expand(),
        showExitButton: false,
      );
      await enable(tester);
      expect(find.text(BugInspector.defaultExitButtonLabel), findsNothing);
    });

    testWidgets('wrapping does not change hit testing of the app',
        (tester) async {
      var lowerTaps = 0;
      await pumpHost(
        tester,
        home: Stack(
          children: <Widget>[
            Positioned.fill(
              child: GestureDetector(onTap: () => lowerTaps++),
            ),
            // An empty box is not hit testable, so the tap reaches the
            // detector below, with or without the inspectable.
            Center(child: BugInspectable(id: 'empty', child: box(100, 100))),
          ],
        ),
      );
      await tester.tapAt(tester.getCenter(inspectable('empty')));
      expect(lowerTaps, 1);
    });
  });

  group('selection', () {
    testWidgets('captures id, source, bounds, time and state', (tester) async {
      final cubit = _CounterCubit(2);
      addTearDown(cubit.close);
      BuildContext? selectedContext;
      final selections = await pumpHost(
        tester,
        home: BlocProvider<_CounterCubit>.value(
          value: cubit,
          child: const _CounterPage(),
        ),
        onWidgetSelected: (widgetContext, _) => selectedContext = widgetContext,
      );
      await enable(tester);
      final before = DateTime.now().toUtc();

      await tapCenterOf(tester, find.byType(FilledButton));

      expect(selections, hasLength(1));
      final selection = selections.single;
      expect(selection.id, 'counter.increment');
      expect(selection.label, 'Increment');
      expect(selection.widgetType, 'FilledButton');
      expect(selection.sourceFile, 'lib/main.dart');
      expect(selection.sourceLine, 42);
      expect(selection.bounds, tester.getRect(find.byType(FilledButton)));
      expect(selection.capturedAtUtc.isUtc, isTrue);
      expect(
        selection.capturedAtUtc
            .isBefore(before.subtract(const Duration(seconds: 1))),
        isFalse,
      );
      expect(selection.blocs, hasLength(1));
      final snapshot = selection.blocs.single;
      expect(snapshot.id, 'counter_cubit');
      expect(snapshot.type, '_CounterCubit');
      expect(snapshot.stateType, 'int');
      expect(snapshot.state, <String, Object?>{'value': 2});
      expect(snapshot.instanceId, BugStateRecorder.instanceIdOf(cubit));
      expect(selection.stateHistory, isEmpty);

      expect(cubit.state, 2,
          reason: 'the selection tap must not press the button');
      expect(modeOf(tester).state, InspectMode.disabled);
      expect(find.byType(BugInspectable), isNot(paintsBorder));
      expect(selectedContext, isNotNull);
      expect(
        selectedContext!.findAncestorWidgetOfExactType<BugInspectable>(),
        isNull,
        reason: 'the callback gets the context of the BugInspectable itself',
      );
      expect(
          (selectedContext!.widget as BugInspectable).id, 'counter.increment');
    });

    testWidgets('a tap outside every inspectable keeps the mode',
        (tester) async {
      final selections = await pumpHost(
        tester,
        home: Center(child: BugInspectable(id: 'a', child: box(50, 50))),
      );
      await enable(tester);
      await tester.tapAt(const Offset(5, 590));
      await tester.pump();
      expect(selections, isEmpty);
      expect(modeOf(tester).state, InspectMode.selecting);
    });

    testWidgets('the smallest area wins, the deepest wins on equal area',
        (tester) async {
      final selections = await pumpHost(
        tester,
        home: Center(
          child: BugInspectable(
            id: 'outer',
            child: SizedBox(
              width: 300,
              height: 300,
              child: Align(
                alignment: Alignment.topLeft,
                child: BugInspectable(
                  id: 'shell',
                  child: BugInspectable(id: 'core', child: box(100, 100)),
                ),
              ),
            ),
          ),
        ),
        disableModeOnSelection: false,
      );
      await enable(tester);

      await tapCenterOf(tester, inspectable('core'));
      await tester.tapAt(
          tester.getBottomRight(inspectable('outer')) - const Offset(10, 10));
      await tester.pump();

      expect(selections.map((selection) => selection.id),
          <String>['core', 'outer']);
    });

    testWidgets('callback context can open a route', (tester) async {
      await pumpHost(
        tester,
        home: Center(child: BugInspectable(id: 'a', child: box(50, 50))),
        onWidgetSelected: (widgetContext, selection) {
          unawaited(
            showDialog<void>(
              context: widgetContext,
              builder: (_) =>
                  AlertDialog(content: Text('report ${selection.id}')),
            ),
          );
        },
      );
      await enable(tester);
      await tapCenterOf(tester, inspectable('a'));
      await tester.pumpAndSettle();
      expect(find.text('report a'), findsOneWidget);
    });

    testWidgets('disableModeOnSelection: false keeps selecting',
        (tester) async {
      final selections = await pumpHost(
        tester,
        home: Center(child: BugInspectable(id: 'a', child: box(50, 50))),
        disableModeOnSelection: false,
      );
      await enable(tester);
      await tapCenterOf(tester, inspectable('a'));
      await tapCenterOf(tester, inspectable('a'));
      expect(selections, hasLength(2));
      expect(modeOf(tester).state, InspectMode.selecting);
    });

    testWidgets('tapDown selects on pointer down, tapUp ignores drags',
        (tester) async {
      var selections = await pumpHost(
        tester,
        home: Center(child: BugInspectable(id: 'a', child: box(200, 200))),
        selectionTrigger: BugSelectionTrigger.tapDown,
      );
      await enable(tester);
      final gesture =
          await tester.startGesture(tester.getCenter(inspectable('a')));
      await tester.pump();
      expect(selections, hasLength(1));
      await gesture.up();

      selections = await pumpHost(
        tester,
        home: Center(child: BugInspectable(id: 'a', child: box(200, 200))),
      );
      await enable(tester);
      await tester.dragFrom(
          tester.getCenter(inspectable('a')), const Offset(0, 80));
      await tester.pump();
      expect(selections, isEmpty);
    });
  });

  group('visibility', () {
    testWidgets('widgets of an offstage route are skipped', (tester) async {
      final selections = await pumpHost(
        tester,
        home: Scaffold(
          body: Center(
            child: BugInspectable(id: 'page1.center', child: box(40, 40)),
          ),
        ),
      );
      unawaited(
        tester.state<NavigatorState>(find.byType(Navigator)).push(
              MaterialPageRoute<void>(
                builder: (_) => Scaffold(
                  body: Align(
                    alignment: Alignment.topLeft,
                    child: BugInspectable(
                      id: 'page2.corner',
                      child: box(40, 40),
                    ),
                  ),
                ),
              ),
            ),
      );
      await tester.pumpAndSettle();
      await enable(tester);

      // page1.center is still mounted but its route is offstage.
      await tester.tapAt(const Offset(400, 300));
      await tester.pump();
      expect(selections, isEmpty);

      await tapCenterOf(tester, inspectable('page2.corner'));
      expect(selections.single.id, 'page2.corner');
    });

    testWidgets('widgets hidden by an IndexedStack are skipped',
        (tester) async {
      final selections = await pumpHost(
        tester,
        home: IndexedStack(
          children: <Widget>[
            Align(
              alignment: Alignment.topLeft,
              child: BugInspectable(id: 'tab0.corner', child: box(40, 40)),
            ),
            Center(
              child: BugInspectable(id: 'tab1.center', child: box(40, 40)),
            ),
          ],
        ),
      );
      await enable(tester);

      await tester.tapAt(const Offset(400, 300));
      await tester.pump();
      expect(selections, isEmpty);

      await tapCenterOf(tester, inspectable('tab0.corner'));
      expect(selections.single.id, 'tab0.corner');
    });

    testWidgets('the clipped part of a scrolled item is skipped',
        (tester) async {
      final controller = ScrollController();
      addTearDown(controller.dispose);
      final selections = await pumpHost(
        tester,
        home: Column(
          children: <Widget>[
            const SizedBox(height: 56, width: double.infinity),
            Expanded(
              child: ListView(
                controller: controller,
                children: <Widget>[
                  for (var i = 0; i < 30; i++)
                    BugInspectable(
                      id: 'item$i',
                      child: const SizedBox(height: 40),
                    ),
                ],
              ),
            ),
          ],
        ),
      );
      controller.jumpTo(30);
      await tester.pump();
      await enable(tester);

      // item0 spans y 26..66, but only 56..66 is visible below the header.
      // x = 100 keeps the taps away from the exit button.
      expect(tester.getRect(inspectable('item0')).top, 26);
      await tester.tapAt(const Offset(100, 40));
      await tester.pump();
      expect(selections, isEmpty);

      await tester.tapAt(const Offset(100, 60));
      await tester.pump();
      expect(selections.single.id, 'item0');
    });

    testWidgets('a dialog on top wins over a smaller widget below it',
        (tester) async {
      final selections = await pumpHost(
        tester,
        home: Scaffold(
          body: Center(
              child: BugInspectable(id: 'page.small', child: box(40, 40))),
        ),
      );
      unawaited(
        showDialog<void>(
          context: tester.element(find.byType(Scaffold)),
          builder: (_) => Center(
            child: BugInspectable(
              id: 'dialog.panel',
              child: Material(child: box(300, 200)),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await enable(tester);

      await tester.tapAt(const Offset(400, 300));
      await tester.pump();

      expect(selections.single.id, 'dialog.panel');
    });

    testWidgets('widgets below IgnorePointer stay selectable', (tester) async {
      final selections = await pumpHost(
        tester,
        home: Center(
          child: BugInspectable(
            id: 'form',
            child: Material(
              child: SizedBox(
                width: 300,
                height: 300,
                child: Center(
                  child: IgnorePointer(
                    child:
                        BugInspectable(id: 'form.field', child: box(100, 50)),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await enable(tester);
      await tapCenterOf(tester, inspectable('form.field'));
      expect(selections.single.id, 'form.field');
    });
  });

  group('state', () {
    testWidgets('collects scopes nearest first, once per instance',
        (tester) async {
      final shared = _CounterCubit(1);
      final sameClass = _CounterCubit(7);
      final failing = _CounterCubit(3);
      addTearDown(shared.close);
      addTearDown(sameClass.close);
      addTearDown(failing.close);

      Object? snapshotOf(int value) => <String, Object?>{'value': value};

      final selections = await pumpHost(
        tester,
        home: BugBlocScope<int>(
          id: 'shared.outer',
          bloc: shared,
          snapshotBuilder: snapshotOf,
          child: BugBlocScope<int>(
            id: 'failing',
            bloc: failing,
            snapshotBuilder: (_) => throw StateError('cannot serialize'),
            child: BugBlocScope<int>(
              id: 'same_class',
              bloc: sameClass,
              snapshotBuilder: snapshotOf,
              child: BugBlocScope<int>(
                id: 'shared.inner',
                bloc: shared,
                snapshotBuilder: snapshotOf,
                child:
                    Center(child: BugInspectable(id: 'a', child: box(50, 50))),
              ),
            ),
          ),
        ),
      );
      shared.increment();
      await enable(tester);
      await tapCenterOf(tester, inspectable('a'));

      final blocs = selections.single.blocs;
      expect(blocs.map((bloc) => bloc.id),
          <String>['shared.inner', 'same_class', 'failing']);
      expect(blocs[0].state, <String, Object?>{'value': 2});
      expect(blocs[1].state, <String, Object?>{'value': 7});
      expect(blocs[0].instanceId, isNot(blocs[1].instanceId));
      expect(blocs[0].type, blocs[1].type);
      expect(blocs[2].captureErrorType, 'StateError');
      expect(blocs[2].state, <String, Object?>{});
    });

    testWidgets('includes the history within the window', (tester) async {
      var now = DateTime.utc(2026, 11, 11, 7, 40);
      final recorder = BugStateRecorder(clock: () => now);
      final previousObserver = Bloc.observer;
      Bloc.observer = BugInspectorBlocObserver(recorder: recorder);
      addTearDown(() => Bloc.observer = previousObserver);

      final cubit = _CounterCubit(); // `created` at 07:40:00
      addTearDown(cubit.close);
      final selections = await pumpHost(
        tester,
        recorder: recorder,
        home: BlocProvider<_CounterCubit>.value(
          value: cubit,
          child: const _CounterPage(),
        ),
      );

      now = now.add(const Duration(seconds: 20));
      await tester.tap(find.byType(FilledButton)); // `change` at 07:40:20
      await tester.pump();
      now = now.add(const Duration(seconds: 15)); // select at 07:40:35

      await enable(tester);
      await tapCenterOf(tester, find.byType(FilledButton));

      final selection = selections.single;
      expect(selection.capturedAtUtc, DateTime.utc(2026, 11, 11, 7, 40, 35));
      expect(selection.stateHistory, hasLength(1));
      final record = selection.stateHistory.single;
      expect(record.kind, BugStateRecordKind.change);
      expect(record.blocType, '_CounterCubit');
      expect(record.instanceId, selection.blocs.single.instanceId);
      expect(recorder.records.first.kind, BugStateRecordKind.created);
      expect(
        recorder.records
            .where((record) => record.blocType == 'InspectModeCubit'),
        isEmpty,
      );
    });
  });

  group('mode cubit ownership', () {
    testWidgets('an owned cubit is closed with the host', (tester) async {
      await pumpHost(tester, home: const SizedBox.expand());
      final owned = modeOf(tester);
      expect(
        BugInspector.maybeModeCubitOf(tester.element(find.byType(Navigator))),
        same(owned),
      );

      await tester.pumpWidget(const SizedBox());
      expect(owned.isClosed, isTrue);
    });

    testWidgets('an external cubit drives the host and stays open',
        (tester) async {
      final external = InspectModeCubit();
      addTearDown(external.close);
      await pumpHost(
        tester,
        modeCubit: external,
        home: Center(child: BugInspectable(id: 'a', child: box(50, 50))),
      );
      expect(modeOf(tester), same(external));

      external.enable();
      await pumpModeChange(tester);
      expect(find.byType(BugInspectable), paintsBorder);

      await tester.pumpWidget(const SizedBox());
      expect(external.isClosed, isFalse);
    });

    testWidgets('maybeModeCubitOf is null outside a host', (tester) async {
      late BuildContext context;
      await tester.pumpWidget(Builder(builder: (c) {
        context = c;
        return const SizedBox();
      }));
      expect(BugInspector.maybeModeCubitOf(context), isNull);
    });
  });

  testWidgets('captureScreenshot captures the content as PNG', (tester) async {
    late BuildContext context;
    await pumpHost(
      tester,
      home: Builder(
        builder: (c) {
          context = c;
          return const ColoredBox(color: Color(0xFF2196F3));
        },
      ),
    );

    final screenshot = await tester.runAsync(
      () => BugInspector.captureScreenshot(
        context,
        pixelRatio: 2,
        waitForNextFrame: false,
      ),
    );

    expect(screenshot, isNotNull);
    expect(screenshot!.width, 1600);
    expect(screenshot.height, 1200);
    expect(screenshot.contentBounds, const Rect.fromLTWH(0, 0, 800, 600));
    expect(screenshot.pngBytes.sublist(0, 4), <int>[0x89, 0x50, 0x4E, 0x47]);
    expect(
      screenshot.toImageRect(const Rect.fromLTWH(10, 20, 30, 40)),
      const Rect.fromLTWH(20, 40, 60, 80),
    );
  });
}
