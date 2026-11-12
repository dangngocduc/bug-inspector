import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_qa_inspector/flutter_qa_inspector.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/app_parity.dart';
import 'support/build_mode.dart';
import 'support/test_host.dart';

/// A stepper that keeps its value in its own state.
class _Stepper extends StatefulWidget {
  const _Stepper({required this.name, this.onSnapshot});

  final String name;
  final VoidCallback? onSnapshot;

  @override
  State<_Stepper> createState() => _StepperState();
}

class _StepperState extends State<_Stepper> with BugInspectableState {
  var _value = 0;

  @override
  Object? bugSnapshot() {
    widget.onSnapshot?.call();
    return <String, Object?>{'name': widget.name, 'value': _value};
  }

  @override
  Widget build(BuildContext context) => TextButton(
        onPressed: () => setState(() => _value++),
        child: Text('${widget.name}: $_value'),
      );
}

/// A form whose build creates the inspectables.
class _Form extends StatefulWidget {
  const _Form({this.onSnapshot});

  final VoidCallback? onSnapshot;

  @override
  State<_Form> createState() => _FormState();
}

class _FormState extends State<_Form> with BugInspectableState {
  var _agreed = false;
  final _note = TextEditingController();

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  @override
  Object? bugSnapshot() {
    widget.onSnapshot?.call();
    return <String, Object?>{'agreed': _agreed, 'note': _note.text};
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        body: Column(
          children: <Widget>[
            BugInspectable(
              id: 'agree',
              child: Checkbox(
                value: _agreed,
                onChanged: (value) => setState(() => _agreed = value!),
              ),
            ),
            BugInspectable(
              id: 'note',
              child: SizedBox(
                width: 200,
                child: TextField(controller: _note),
              ),
            ),
            BugInspectable(
              id: 'stepper',
              child: _Stepper(name: 'quantity', onSnapshot: widget.onSnapshot),
            ),
          ],
        ),
      );
}

/// A state above the page, such as an app shell.
class _Shell extends StatefulWidget {
  const _Shell({required this.child});

  final Widget child;

  @override
  State<_Shell> createState() => _ShellState();
}

class _ShellState extends State<_Shell> with BugInspectableState {
  @override
  Object? bugSnapshot() => <String, Object?>{'tab': 'home'};

  @override
  Widget build(BuildContext context) => widget.child;
}

class _Broken extends StatefulWidget {
  const _Broken();

  @override
  State<_Broken> createState() => _BrokenState();
}

class _BrokenState extends State<_Broken> with BugInspectableState {
  @override
  Object? bugSnapshot() => throw StateError('boom');

  @override
  Widget build(BuildContext context) => box(40, 40);
}

class _NotJson extends StatefulWidget {
  const _NotJson();

  @override
  State<_NotJson> createState() => _NotJsonState();
}

class _NotJsonState extends State<_NotJson> with BugInspectableState {
  @override
  Object? bugSnapshot() => <String, Object?>{'at': DateTime.utc(2026)};

  @override
  Widget build(BuildContext context) => box(40, 40);
}

List<String> _typesOf(BugWidgetSelection selection) => <String>[
      for (final snapshot in selection.widgetStates) snapshot.type,
    ];

void main() => qaBuildOnly(() {
      late int reads;
      late List<BugWidgetSelection> selections;

      Future<void> pumpForm(WidgetTester tester) async {
        reads = 0;
        selections = await pumpHost(
          tester,
          home: _Shell(
            child: BugInspectablePage(
              id: 'form',
              child: _Form(onSnapshot: () => reads++),
            ),
          ),
        );
      }

      /// Checks the box, types a note and steps the quantity twice.
      Future<void> fillForm(WidgetTester tester) async {
        await tester.tap(find.byType(Checkbox));
        await tester.enterText(find.byType(TextField), 'hello');
        await tester.tap(find.text('quantity: 0'));
        await tester.pump();
        await tester.tap(find.text('quantity: 1'));
        await tester.pump();
      }

      testWidgets(
          'a widget gets its own state, then the states above it, with their '
          'current values', (tester) async {
        await pumpForm(tester);
        await fillForm(tester);
        await enable(tester);
        await tapCenterOf(tester, inspectable('stepper'));

        final selection = selections.single;
        expect(selection.widgetType, '_Stepper');
        expect(
          selection.toJson()['widgetStates'],
          <Object?>[
            <String, Object?>{
              'type': '_StepperState',
              'widgetType': '_Stepper',
              'state': <String, Object?>{'name': 'quantity', 'value': 2},
            },
            <String, Object?>{
              'type': '_FormState',
              'widgetType': '_Form',
              'state': <String, Object?>{'agreed': true, 'note': 'hello'},
            },
            <String, Object?>{
              'type': '_ShellState',
              'widgetType': '_Shell',
              'state': <String, Object?>{'tab': 'home'},
            },
          ],
        );
        expect(() => jsonEncode(selection.toJson()), returnsNormally);
      });

      testWidgets(
          'a widget built by a state gets that state, not the states of its '
          'siblings', (tester) async {
        await pumpForm(tester);
        await fillForm(tester);
        await enable(tester);
        await tapCenterOf(tester, inspectable('agree'));

        // The checkbox and the text field have states of their own, without
        // the mixin: they are left out.
        expect(_typesOf(selections.single), <String>[
          '_FormState',
          '_ShellState',
        ]);
        expect(
          selections.single.widgetStates.first.state,
          <String, Object?>{'agreed': true, 'note': 'hello'},
        );
      });

      testWidgets(
          'a page gets the states inside it in tree order, then those above '
          'it', (tester) async {
        await pumpForm(tester);
        await enable(tester);
        await tester.tap(pageButton);
        await tester.pump();

        final selection = selections.single;
        expect(selection.kind, BugSelectionKind.page);
        expect(_typesOf(selection), <String>[
          '_FormState',
          '_StepperState',
          '_ShellState',
        ]);
      });

      testWidgets('a state is read only when a widget is selected',
          (tester) async {
        await pumpForm(tester);
        await fillForm(tester);
        expect(reads, 0);

        await enable(tester);
        await disable(tester);
        await enable(tester);
        expect(reads, 0);

        await tapCenterOf(tester, inspectable('stepper'));
        // Once for the stepper, once for the form.
        expect(reads, 2);
      });

      testWidgets('reports a state it cannot capture and keeps the others',
          (tester) async {
        final selections = await pumpHost(
          tester,
          home: Center(
            child: BugInspectable(
              id: 'mixed',
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  const _Broken(),
                  const _NotJson(),
                  Material(child: _Stepper(name: 'ok')),
                ],
              ),
            ),
          ),
        );
        await enable(tester);
        await tapCenterOf(tester, inspectable('mixed'));

        final states = selections.single.widgetStates;
        expect(_typesOf(selections.single), <String>[
          '_BrokenState',
          '_NotJsonState',
          '_StepperState',
        ]);
        expect(states[0].captureErrorType, 'StateError');
        expect(states[0].state, <String, Object?>{});
        expect(states[1].captureErrorType, 'BugSnapshotFormatException');
        expect(states[1].state, <String, Object?>{});
        expect(states[2].hasCaptureError, isFalse);
        expect(states[2].state, <String, Object?>{'name': 'ok', 'value': 0});
      });

      testWidgets('the parity screen exposes the state of its text field',
          (tester) async {
        // The production test checks that this state is never read.
        final screen = ParityScreen();
        final selections = await pumpHost(
          tester,
          home: screen.build(withPackage: true),
        );
        await tester.enterText(find.byType(TextField), 'abc');
        await enable(tester);
        expect(screen.stateReads, 0);

        await tapCenterOf(tester, inspectable('field'));
        expect(screen.stateReads, 1);
        expect(
          selections.single.widgetStates.single.state,
          <String, Object?>{'text': 'abc'},
        );
      });
    });
