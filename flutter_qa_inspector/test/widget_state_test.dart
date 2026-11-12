import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_qa_inspector/flutter_qa_inspector.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/app_parity.dart';
import 'support/build_mode.dart';
import 'support/test_host.dart';

/// A stepper whose value lives in its own state. Only its parameters are
/// exposed.
class _Stepper extends StatefulWidget with BugInspectableWidget {
  const _Stepper({required this.name, this.step = 1, this.onSnapshot});

  final String name;
  final int step;
  final ValueChanged<String>? onSnapshot;

  @override
  Map<String, Object?> bugSnapshot() {
    onSnapshot?.call('_Stepper');
    return <String, Object?>{'name': name, 'step': step};
  }

  @override
  State<_Stepper> createState() => _StepperState();
}

class _StepperState extends State<_Stepper> {
  var _value = 0;

  @override
  Widget build(BuildContext context) => TextButton(
        onPressed: () => setState(() => _value += widget.step),
        child: Text('${widget.name}: $_value'),
      );
}

/// A checkbox whose value is passed in by its parent.
class _Agreement extends StatelessWidget with BugInspectableWidget {
  const _Agreement({required this.agreed, this.onChanged});

  final bool agreed;
  final ValueChanged<bool>? onChanged;

  @override
  Map<String, Object?> bugSnapshot() => <String, Object?>{
        'agreed': agreed,
        'canChange': onChanged != null,
      };

  @override
  Widget build(BuildContext context) => Checkbox(
        value: agreed,
        onChanged: onChanged == null ? null : (value) => onChanged!(value!),
      );
}

/// A form whose build creates the inspectables.
class _Form extends StatefulWidget with BugInspectableWidget {
  const _Form({required this.title, this.onSnapshot});

  final String title;
  final ValueChanged<String>? onSnapshot;

  @override
  Map<String, Object?> bugSnapshot() {
    onSnapshot?.call('_Form');
    return <String, Object?>{'title': title};
  }

  @override
  State<_Form> createState() => _FormState();
}

class _FormState extends State<_Form> {
  var _agreed = false;
  final _note = TextEditingController();

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        body: Column(
          children: <Widget>[
            BugInspectable(
              id: 'agree',
              child: _Agreement(
                agreed: _agreed,
                onChanged: (value) => setState(() => _agreed = value),
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
              child: _Stepper(
                name: 'quantity',
                step: 2,
                onSnapshot: widget.onSnapshot,
              ),
            ),
          ],
        ),
      );
}

/// A widget above the page, such as an app shell.
class _Shell extends StatelessWidget with BugInspectableWidget {
  const _Shell({required this.child, this.onSnapshot});

  final Widget child;
  final ValueChanged<String>? onSnapshot;

  @override
  Map<String, Object?> bugSnapshot() {
    onSnapshot?.call('_Shell');
    return <String, Object?>{'tab': 'home'};
  }

  @override
  Widget build(BuildContext context) => child;
}

class _Broken extends StatelessWidget with BugInspectableWidget {
  const _Broken();

  @override
  Map<String, Object?> bugSnapshot() => throw StateError('boom');

  @override
  Widget build(BuildContext context) => box(40, 40);
}

class _NotJson extends StatelessWidget with BugInspectableWidget {
  const _NotJson();

  @override
  Map<String, Object?> bugSnapshot() =>
      <String, Object?>{'at': DateTime.utc(2026)};

  @override
  Widget build(BuildContext context) => box(40, 40);
}

/// Returns [values] as they are, to check that they are copied.
class _Values extends StatelessWidget with BugInspectableWidget {
  const _Values(this.values);

  final Map<String, Object?> values;

  @override
  Map<String, Object?> bugSnapshot() => values;

  @override
  Widget build(BuildContext context) => box(40, 40);
}

void main() => qaBuildOnly(() {
      late List<String> reads;
      late List<BugWidgetSelection> selections;

      Future<void> pumpForm(WidgetTester tester) async {
        reads = <String>[];
        selections = await pumpHost(
          tester,
          home: _Shell(
            onSnapshot: reads.add,
            child: BugInspectablePage(
              id: 'form',
              child: _Form(title: 'Checkout', onSnapshot: reads.add),
            ),
          ),
        );
      }

      testWidgets(
          'a widget gets the parameters of its child, next to the type of '
          'the child', (tester) async {
        await pumpForm(tester);
        // Changes the state of the stepper, not its parameters.
        await tester.tap(find.text('quantity: 0'));
        await tester.pump();
        await enable(tester);
        await tapCenterOf(tester, inspectable('stepper'));

        final json = selections.single.toJson();
        expect(json['widgetType'], '_Stepper');
        expect(
          json['widgetState'],
          <String, Object?>{'name': 'quantity', 'step': 2},
        );
        expect(json.containsKey('widgetStateCaptureErrorType'), isFalse);
        expect(json.containsKey('widgetStates'), isFalse);
        expect(() => jsonEncode(json), returnsNormally);
      });

      testWidgets('the parameters are those of the child when it is selected',
          (tester) async {
        await pumpForm(tester);
        await tester.tap(find.byType(Checkbox));
        await tester.pump();
        await enable(tester);
        await tapCenterOf(tester, inspectable('agree'));

        final selection = selections.single;
        expect(selection.widgetType, '_Agreement');
        expect(
          selection.widgetState,
          <String, Object?>{'agreed': true, 'canChange': true},
        );
      });

      testWidgets(
          'a child without the mixin gives an empty widget state, and the '
          'widgets above the marker are not read', (tester) async {
        await pumpForm(tester);
        await enable(tester);
        await tapCenterOf(tester, inspectable('note'));

        final selection = selections.single;
        expect(selection.widgetType, 'SizedBox');
        expect(selection.widgetState, isEmpty);
        expect(selection.widgetStateCaptureErrorType, isNull);
        expect(selection.toJson()['widgetState'], <String, Object?>{});
        // The form and the shell, above the marker, use the mixin too.
        expect(reads, isEmpty);
      });

      testWidgets('a widget with the mixin inside the child is not read',
          (tester) async {
        final reads = <String>[];
        final selections = await pumpHost(
          tester,
          home: Center(
            child: BugInspectable(
              id: 'wrapped',
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Material(
                  child: _Stepper(name: 'inner', onSnapshot: reads.add),
                ),
              ),
            ),
          ),
        );
        await enable(tester);
        await tapCenterOf(tester, inspectable('wrapped'));

        expect(selections.single.widgetType, 'Padding');
        expect(selections.single.widgetState, isEmpty);
        expect(reads, isEmpty);
      });

      testWidgets('a page gets the parameters of its child', (tester) async {
        await pumpForm(tester);
        await enable(tester);
        await tester.tap(pageButton);
        await tester.pump();

        final selection = selections.single;
        expect(selection.kind, BugSelectionKind.page);
        expect(selection.widgetType, '_Form');
        expect(selection.widgetState, <String, Object?>{'title': 'Checkout'});
        // Neither the stepper inside the page nor the shell above it.
        expect(reads, <String>['_Form']);
      });

      testWidgets('the parameters are read only when a widget is selected',
          (tester) async {
        await pumpForm(tester);
        await tester.tap(find.text('quantity: 0'));
        await tester.pump();
        expect(reads, isEmpty);

        await enable(tester);
        await disable(tester);
        await enable(tester);
        expect(reads, isEmpty);

        await tapCenterOf(tester, inspectable('stepper'));
        expect(reads, <String>['_Stepper']);
      });

      testWidgets(
          'reports parameters it cannot capture and keeps the selection',
          (tester) async {
        final selections = await pumpHost(
          tester,
          home: const Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                BugInspectable(id: 'broken', child: _Broken()),
                BugInspectable(id: 'not_json', child: _NotJson()),
              ],
            ),
          ),
        );
        await enable(tester);
        await tapCenterOf(tester, inspectable('broken'));
        await enable(tester);
        await tapCenterOf(tester, inspectable('not_json'));

        expect(
          selections.map((selection) => selection.id),
          <String>['broken', 'not_json'],
        );
        final [broken, notJson] = selections;
        expect(broken.widgetType, '_Broken');
        expect(broken.widgetState, isEmpty);
        expect(broken.widgetStateCaptureErrorType, 'StateError');
        expect(
          broken.toJson()['widgetStateCaptureErrorType'],
          'StateError',
        );
        expect(notJson.widgetState, isEmpty);
        expect(
          notJson.widgetStateCaptureErrorType,
          'BugSnapshotFormatException',
        );
        expect(() => jsonEncode(notJson.toJson()), returnsNormally);
      });

      testWidgets('copies the parameters', (tester) async {
        final values = <String, Object?>{
          'tags': <Object?>['a'],
        };
        final selections = await pumpHost(
          tester,
          home: Center(
            child: BugInspectable(id: 'values', child: _Values(values)),
          ),
        );
        await enable(tester);
        await tapCenterOf(tester, inspectable('values'));

        (values['tags']! as List<Object?>).add('b');
        values['count'] = 1;
        final state = selections.single.widgetState;
        expect(state, <String, Object?>{
          'tags': <Object?>['a'],
        });
        expect(() => state['count'] = 1, throwsUnsupportedError);
      });

      testWidgets('the parity screen exposes the parameters of its text field',
          (tester) async {
        // The production test checks that they are never read.
        final screen = ParityScreen();
        final selections = await pumpHost(
          tester,
          home: screen.build(withPackage: true),
        );
        await tester.enterText(find.byType(TextField), 'abc');
        await enable(tester);
        expect(screen.widgetStateReads, 0);

        await tapCenterOf(tester, inspectable('field'));
        expect(screen.widgetStateReads, 1);
        // The text is in the state of the field, not in its parameters.
        expect(selections.single.widgetType, '_InspectedDraft');
        expect(
          selections.single.widgetState,
          <String, Object?>{'maxLines': 1},
        );
      });
    });
