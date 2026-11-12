import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_qa_inspector/flutter_qa_inspector.dart';
import 'package:flutter_test/flutter_test.dart';

/// A cubit owned by the app under test.
class CounterCubit extends Cubit<int> {
  CounterCubit() : super(0);

  void increment() => emit(state + 1);
}

/// Records the BLoC/Cubit instances created while it is installed.
class CreatedObserver extends BlocObserver {
  final List<BlocBase<dynamic>> created = <BlocBase<dynamic>>[];

  @override
  void onCreate(BlocBase<dynamic> bloc) {
    super.onCreate(bloc);
    created.add(bloc);
  }
}

/// Installs [observer] as [Bloc.observer] for the rest of the test.
void useObserver(BlocObserver observer) {
  final previous = Bloc.observer;
  Bloc.observer = observer;
  addTearDown(() => Bloc.observer = previous);
}

/// A screen with a button, a text field and a list, built either with every
/// widget of the package around it or with none of them.
class ParityScreen {
  ParityScreen() : counter = CounterCubit() {
    addTearDown(counter.close);
  }

  final CounterCubit counter;

  /// How many times the button was tapped.
  int taps = 0;

  /// How many times the lazy scope read its bloc.
  int lazyReads = 0;

  /// How many times the state of the text field was captured.
  int stateReads = 0;

  Widget build({required bool withPackage}) {
    Widget mark(String id, Widget child) =>
        withPackage ? BugInspectable(id: id, child: child) : child;

    final Widget body = Column(
      children: <Widget>[
        mark(
          'button',
          TextButton(onPressed: () => taps++, child: const Text('Tap')),
        ),
        mark('field', withPackage ? _InspectedDraft(this) : const _Draft()),
        Expanded(
          child: ListView(
            children: <Widget>[
              for (var i = 0; i < 20; i++)
                mark('item.$i', SizedBox(height: 40, child: Text('$i'))),
            ],
          ),
        ),
      ],
    );
    final Widget scaffold = Scaffold(
      appBar: AppBar(title: const Text('Title')),
      body: withPackage
          ? BugBlocScope<int>(
              id: 'eager',
              bloc: counter,
              snapshotBuilder: (value) => <String, Object?>{'v': value},
              child: BugBlocScope<int>.lazy(
                id: 'lazy',
                readBloc: (context) {
                  lazyReads++;
                  return context.read<CounterCubit>();
                },
                snapshotBuilder: (value) => <String, Object?>{'v': value},
                child: body,
              ),
            )
          : body,
    );
    return BlocProvider<CounterCubit>.value(
      value: counter,
      child: withPackage
          ? BugInspectablePage(id: 'page', child: scaffold)
          : scaffold,
    );
  }

  /// Taps the button, types in the field and scrolls the list.
  Future<void> use(WidgetTester tester) async {
    await tester.tap(find.text('Tap'));
    await tester.enterText(find.byType(TextField), 'abc');
    await tester.drag(find.text('3'), const Offset(0, -200));
    await tester.pump();
  }

  /// Whether [use] reached the app.
  void expectUsed() {
    expect(taps, 1);
    expect(find.text('abc'), findsOneWidget);
    expect(find.text('0'), findsNothing);
  }
}

/// A text field whose text is kept in a [State].
class _Draft extends StatefulWidget {
  const _Draft();

  @override
  State<_Draft> createState() => _DraftState();
}

class _DraftState extends State<_Draft> {
  final TextEditingController text = TextEditingController();

  @override
  void dispose() {
    text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => TextField(controller: text);
}

/// The same text field, with its state exposed through [BugInspectableState].
class _InspectedDraft extends _Draft {
  const _InspectedDraft(this.screen);

  final ParityScreen screen;

  @override
  State<_Draft> createState() => _InspectedDraftState();
}

class _InspectedDraftState extends _DraftState with BugInspectableState {
  @override
  Object? bugSnapshot() {
    (widget as _InspectedDraft).screen.stateReads++;
    return <String, Object?>{'text': text.text};
  }
}

/// The runtime types of the render objects of the app, in tree order.
List<Type> renderTypesOf(WidgetTester tester) {
  final types = <Type>[];
  void visit(RenderObject renderObject) {
    types.add(renderObject.runtimeType);
    renderObject.visitChildren(visit);
  }

  visit(tester.renderObject(find.byType(MaterialApp)));
  return types;
}

/// The semantics tree of the screen without the node ids, which differ
/// between pumps.
String semanticsOf(WidgetTester tester) {
  final root = tester.getSemantics(find.byType(Scaffold));
  return root.toStringDeep().replaceAll(RegExp(r'#\d+'), '#');
}

/// Pumps the screen without the package and returns its render types and
/// semantics, to compare with the same screen built with the package.
Future<(List<Type>, String)> pumpWithoutPackage(
  WidgetTester tester,
  ParityScreen screen,
) async {
  await tester.pumpWidget(MaterialApp(home: screen.build(withPackage: false)));
  return (renderTypesOf(tester), semanticsOf(tester));
}
