import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_qa_inspector/flutter_qa_inspector.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/test_host.dart';
import 'support/build_mode.dart';

class _ValueCubit extends Cubit<int> {
  _ValueCubit(super.initialState);
}

Object? _snapshotOf(int value) => <String, Object?>{'value': value};

Widget _page(String id, {Widget? body, String? label}) {
  return BugInspectablePage(
    id: id,
    label: label,
    child: Scaffold(body: body ?? const SizedBox.expand()),
  );
}

void main() => qaBuildOnly(() {
      testWidgets('outside a host it only returns its child', (tester) async {
        await tester.pumpWidget(
          const Directionality(
            textDirection: TextDirection.ltr,
            child: BugInspectablePage(id: 'alone', child: Text('child')),
          ),
        );
        expect(
          tester.renderObject(find.byType(BugInspectablePage)),
          isA<RenderParagraph>(),
        );
      });

      testWidgets(
          'selecting paints the page border without changing the layout',
          (tester) async {
        await pumpHost(
          tester,
          home: _page('home', body: const Center(child: Text('content'))),
        );
        final rectBefore = tester.getRect(find.text('content'));
        expect(find.byType(BugInspectablePage), isNot(paintsPageBorder));

        await enable(tester);
        expect(find.byType(BugInspectablePage), paintsPageBorder);
        expect(tester.getRect(find.text('content')), rectBefore);

        await disable(tester);
        expect(find.byType(BugInspectablePage), isNot(paintsPageBorder));
      });

      testWidgets('the page button selects the page with its state',
          (tester) async {
        final outside = _ValueCubit(1);
        final inside = _ValueCubit(2);
        final nested = _ValueCubit(3);
        addTearDown(outside.close);
        addTearDown(inside.close);
        addTearDown(nested.close);

        final selections = await pumpHost(
          tester,
          home: BugBlocScope<int>(
            id: 'outside',
            bloc: outside,
            snapshotBuilder: _snapshotOf,
            child: BugInspectablePage(
              id: 'counter',
              label: 'Counter screen',
              sourceFile: 'lib/counter_page.dart',
              child: Scaffold(
                body: BugBlocScope<int>(
                  id: 'inside',
                  bloc: inside,
                  snapshotBuilder: _snapshotOf,
                  child: Column(
                    children: <Widget>[
                      BugBlocScope<int>(
                        id: 'nested',
                        bloc: nested,
                        snapshotBuilder: _snapshotOf,
                        child: BugInspectable(id: 'widget', child: box(50, 50)),
                      ),
                      // Same instance as 'inside', captured once.
                      BugBlocScope<int>(
                        id: 'inside.again',
                        bloc: inside,
                        snapshotBuilder: _snapshotOf,
                        child: box(50, 50),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
        await enable(tester);

        expect(find.text(BugInspector.defaultPageButtonLabel), findsOneWidget);
        expect(find.text('Counter screen'), findsOneWidget);
        await tester.tap(pageButton);
        await tester.pump();

        final selection = selections.single;
        expect(selection.kind, BugSelectionKind.page);
        expect(selection.id, 'counter');
        expect(selection.label, 'Counter screen');
        expect(selection.widgetType, 'Scaffold');
        expect(selection.sourceFile, 'lib/counter_page.dart');
        expect(selection.routeName, '/');
        expect(selection.bounds, const Rect.fromLTWH(0, 0, 800, 600));
        expect(
          selection.blocs.map((bloc) => bloc.id),
          <String>['inside', 'nested', 'outside'],
        );
        expect(
          selection.blocs.map((bloc) => bloc.state),
          <Object?>[
            <String, Object?>{'value': 2},
            <String, Object?>{'value': 3},
            <String, Object?>{'value': 1},
          ],
        );
        expect(selection.toJson()['kind'], 'page');
        expect(selection.toJson()['route'], <String, Object?>{'name': '/'});
        expect(modeOf(tester).state, InspectMode.disabled);
        expect(pageButton, findsNothing);
      });

      testWidgets('the button is hidden without a page or when turned off',
          (tester) async {
        await pumpHost(
          tester,
          home: Center(child: BugInspectable(id: 'a', child: box(50, 50))),
        );
        await enable(tester);
        expect(pageButton, findsNothing);

        await disable(tester);
        await pumpHost(tester, home: _page('home'), showPageButton: false);
        await enable(tester);
        expect(pageButton, findsNothing);
        expect(find.byType(BugInspectablePage), paintsPageBorder);
      });

      testWidgets('the page of the top route is current, also below a dialog',
          (tester) async {
        final selections = await pumpHost(tester, home: _page('page1'));
        unawaited(
          tester.state<NavigatorState>(find.byType(Navigator)).push(
                MaterialPageRoute<void>(
                  settings: const RouteSettings(name: '/details'),
                  builder: (_) => _page('page2'),
                ),
              ),
        );
        await tester.pumpAndSettle();
        unawaited(
          showDialog<void>(
            context: tester.element(find.byType(Scaffold).last),
            builder: (_) => const AlertDialog(content: Text('dialog')),
          ),
        );
        await tester.pumpAndSettle();
        await enable(tester);

        expect(find.text('page2'), findsOneWidget);
        await tester.tap(pageButton);
        await tester.pump();

        expect(selections.single.id, 'page2');
        expect(selections.single.routeName, '/details');
      });

      testWidgets('a nested page wins over its parent', (tester) async {
        final selections = await pumpHost(
          tester,
          home: BugInspectablePage(
            id: 'shell',
            child: Scaffold(
              body: IndexedStack(
                index: 1,
                children: <Widget>[_page('tab0'), _page('tab1')],
              ),
              bottomNavigationBar: const SizedBox(height: 56),
            ),
          ),
        );
        await enable(tester);

        // tab0 is hidden by the IndexedStack.
        expect(find.text('tab1'), findsOneWidget);
        await tester.tap(pageButton);
        await tester.pump();
        expect(selections.single.id, 'tab1');
      });

      testWidgets('the page painted on top wins, not the last registered',
          (tester) async {
        late StateSetter setState;
        var showBottom = false;
        final selections = await pumpHost(
          tester,
          home: StatefulBuilder(
            builder: (context, setter) {
              setState = setter;
              return Stack(
                children: <Widget>[
                  // Inserted later, so registered after 'top', but painted below.
                  if (showBottom)
                    KeyedSubtree(
                      key: const ValueKey<String>('bottom'),
                      child: _page('bottom'),
                    ),
                  KeyedSubtree(
                    key: const ValueKey<String>('top'),
                    child: _page('top'),
                  ),
                ],
              );
            },
          ),
        );
        setState(() => showBottom = true);
        await tester.pump();
        await enable(tester);

        await tester.tap(pageButton);
        await tester.pump();
        expect(selections.single.id, 'top');
      });

      testWidgets('a tap that misses every widget keeps the mode by default',
          (tester) async {
        final home = _page(
          'home',
          body: Center(child: BugInspectable(id: 'widget', child: box(50, 50))),
        );
        var selections = await pumpHost(tester, home: home);
        await enable(tester);

        await tester.tapAt(const Offset(100, 300));
        await tester.pump();
        expect(selections, isEmpty);
        expect(modeOf(tester).state, InspectMode.selecting);

        await disable(tester);
        selections = await pumpHost(
          tester,
          home: home,
          selectPageOnEmptyTap: true,
          disableModeOnSelection: false,
        );
        await enable(tester);

        await tester.tapAt(const Offset(100, 300));
        await tester.pump();
        await tapCenterOf(tester, inspectable('widget'));

        expect(
          selections
              .map((selection) => '${selection.kind.name}:${selection.id}'),
          <String>['page:home', 'widget:widget'],
        );
      });

      testWidgets('the button can be dragged without selecting',
          (tester) async {
        final selections = await pumpHost(tester, home: _page('home'));
        await enable(tester);
        final start = tester.getRect(pageButton);

        await tester.drag(pageButton, const Offset(-300, -200));
        await tester.pump();

        final moved = tester.getRect(pageButton);
        expect(moved.left, lessThan(start.left - 200));
        expect(moved.top, lessThan(start.top - 100));
        expect(selections, isEmpty);
        expect(modeOf(tester).state, InspectMode.selecting);

        // The position is kept for the next time the mode is enabled.
        await disable(tester);
        await enable(tester);
        expect(tester.getRect(pageButton).topLeft, moved.topLeft);

        await tester.tap(pageButton);
        await tester.pump();
        expect(selections.single.id, 'home');
      });

      testWidgets('a widget selection carries its route name', (tester) async {
        final selections =
            await pumpHost(tester, home: const SizedBox.expand());
        unawaited(
          tester.state<NavigatorState>(find.byType(Navigator)).push(
                MaterialPageRoute<void>(
                  settings: const RouteSettings(name: '/details'),
                  builder: (_) => Center(
                    child: BugInspectable(id: 'widget', child: box(50, 50)),
                  ),
                ),
              ),
        );
        await tester.pumpAndSettle();
        await enable(tester);

        await tapCenterOf(tester, inspectable('widget'));

        expect(selections.single.kind, BugSelectionKind.widget);
        expect(selections.single.routeName, '/details');
      });
    });
