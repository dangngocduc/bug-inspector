import 'package:bloc/bloc.dart';
import 'package:flutter/material.dart';
import 'package:flutter_qa_inspector/flutter_qa_inspector.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/build_mode.dart';
import 'support/test_host.dart';

class _CounterCubit extends Cubit<int> {
  _CounterCubit() : super(0);

  void increment() => emit(state + 1);
}

class _HostObserver extends BlocObserver {
  final changes = <Change<int>>[];

  @override
  void onChange(BlocBase<dynamic> bloc, Change<dynamic> change) {
    if (bloc is _CounterCubit) {
      changes.add(Change(
        currentState: change.currentState as int,
        nextState: change.nextState as int,
      ));
    }
    super.onChange(bloc, change);
  }
}

/// An app with the turnkey setup and one marked screen with one marked
/// button, opened by a named route.
Widget _app({
  bool enabled = true,
  BugReportStringsBuilder? strings,
  String? routeName = '/home',
}) {
  return MaterialApp(
    builder: (context, child) => FlutterQaInspector.wrap(
      enabled: enabled,
      strings: strings,
      captureScreenshot: false,
      child: child!,
    ),
    initialRoute: routeName,
    onGenerateRoute: (settings) => MaterialPageRoute<void>(
      settings: RouteSettings(name: routeName),
      builder: (_) => BugInspectablePage.route(
        settings: RouteSettings(name: routeName),
        sourceFile: 'lib/app_navigator.dart',
        child: Scaffold(
          body: Center(
            child: BugInspectable(
              id: 'home.button',
              child: ElevatedButton(
                onPressed: () {},
                child: const Text('Tap'),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

void main() {
  test('BugReportStrings.of follows the language of the locale', () {
    // Exercised through a widget below; here the constants themselves.
    expect(
        BugReportStrings.en.selectionHint, BugInspector.defaultSelectionHint);
    expect(BugReportStrings.en.pageButtonLabel,
        BugInspector.defaultPageButtonLabel);
    expect(BugReportStrings.vi.title, 'Báo lỗi');
    expect(BugReportStrings.en.copyWith(title: 'X').title, 'X');
    expect(BugReportStrings.en.copyWith(title: 'X').send, 'Send');
  });

  testWidgets('BugReportStrings.of picks vi or en', (tester) async {
    late BugReportStrings vi;
    late BugReportStrings fr;
    late BugReportStrings none;
    await tester.pumpWidget(
      Column(
        children: [
          Localizations(
            locale: const Locale('vi', 'VN'),
            delegates: const [DefaultWidgetsLocalizations.delegate],
            child: Builder(builder: (context) {
              vi = BugReportStrings.of(context);
              return const SizedBox();
            }),
          ),
          Localizations(
            locale: const Locale('fr'),
            delegates: const [DefaultWidgetsLocalizations.delegate],
            child: Builder(builder: (context) {
              fr = BugReportStrings.of(context);
              return const SizedBox();
            }),
          ),
          Builder(builder: (context) {
            none = BugReportStrings.of(context);
            return const SizedBox();
          }),
        ],
      ),
    );

    expect(vi, same(BugReportStrings.vi));
    expect(fr, same(BugReportStrings.en));
    expect(none, same(BugReportStrings.en));
  });

  productionBuildOnly(() {
    test('install leaves Bloc.observer alone', () {
      final previous = Bloc.observer;
      FlutterQaInspector.install();
      addTearDown(FlutterQaInspector.debugReset);

      expect(Bloc.observer, same(previous));
      expect(FlutterQaInspector.recorder, isNull);
      expect(FlutterQaInspector.networkRecorder, isNull);
    });

    test('wrap and builder return the child itself', () {
      const child = SizedBox();
      expect(FlutterQaInspector.wrap(child: child), same(child));
      expect(
        FlutterQaInspector.builder(_FakeContext(), child),
        same(child),
      );
    });

    testWidgets('a route marker only builds its page', (tester) async {
      await tester.pumpWidget(_app());

      expect(find.byKey(BugInspector.launcherKey), findsNothing);
      final marker = find.byType(BugInspectablePage);
      Element? built;
      tester.element(marker).visitChildElements((child) => built = child);
      expect(
          built?.widget, same(tester.widget<BugInspectablePage>(marker).child));
    });
  });

  qaBuildOnly(() {
    test('install records the state timeline once, keeping the observer',
        () async {
      final previous = Bloc.observer;
      final hostObserver = _HostObserver();
      Bloc.observer = hostObserver;
      addTearDown(() {
        FlutterQaInspector.debugReset();
        Bloc.observer = previous;
      });
      FlutterQaInspector.install();
      final recorder = FlutterQaInspector.recorder;
      final observer = Bloc.observer;

      expect(recorder, isNotNull);
      final networkRecorder = FlutterQaInspector.networkRecorder;
      expect(networkRecorder, isNotNull);
      expect(observer, isA<MultiBlocObserver>());
      expect(observer, isNot(same(hostObserver)));

      // A second call keeps the first setup.
      FlutterQaInspector.install();
      expect(FlutterQaInspector.recorder, same(recorder));
      expect(FlutterQaInspector.networkRecorder, same(networkRecorder));
      expect(Bloc.observer, same(observer));

      final cubit = _CounterCubit()..increment();
      await cubit.close();
      expect(hostObserver.changes, hasLength(1));
      expect(hostObserver.changes.single.currentState, 0);
      expect(hostObserver.changes.single.nextState, 1);
      expect(
        recorder!.records.map((record) => record.kind),
        [
          BugStateRecordKind.created,
          BugStateRecordKind.change,
          BugStateRecordKind.closed,
        ],
      );

      FlutterQaInspector.debugReset();
      expect(Bloc.observer, same(hostObserver));
      expect(FlutterQaInspector.recorder, isNull);
      expect(FlutterQaInspector.networkRecorder, isNull);
    });

    test('install takes the given recorders', () {
      final recorder = BugStateRecorder(maxRecords: 5);
      final networkRecorder = BugNetworkRecorder(maxRecords: 5);
      FlutterQaInspector.install(
        stateRecorder: recorder,
        networkRecorder: networkRecorder,
      );
      addTearDown(FlutterQaInspector.debugReset);

      expect(FlutterQaInspector.recorder, same(recorder));
      expect(FlutterQaInspector.networkRecorder, same(networkRecorder));
    });

    testWidgets('a selected widget opens the report', (tester) async {
      await tester.pumpWidget(_app());

      await tester.tap(find.byKey(BugInspector.launcherKey));
      await pumpModeChange(tester);
      expect(find.text(BugReportStrings.en.selectionHint), findsOneWidget);
      await tester.tapAt(tester.getCenter(find.text('Tap')));
      await tester.pumpAndSettle();

      expect(find.byType(BugReportPage), findsOneWidget);
      expect(find.text(BugReportStrings.en.title), findsOneWidget);
      expect(find.textContaining('"id": "home.button"'), findsOneWidget);
      // The launcher hides until the report closes.
      expect(find.byKey(BugInspector.launcherKey), findsNothing);

      await tester.tap(find.text(BugReportStrings.en.cancel));
      await tester.pumpAndSettle();
      expect(find.byType(BugReportPage), findsNothing);
      expect(find.byKey(BugInspector.launcherKey), findsOneWidget);
    });

    testWidgets('the route marker selects the screen by its route name',
        (tester) async {
      await tester.pumpWidget(_app(routeName: '/teacher/home'));

      await tester.tap(find.byKey(BugInspector.launcherKey));
      await pumpModeChange(tester);
      await tester.tap(find.text(BugReportStrings.en.pageButtonLabel));
      await tester.pumpAndSettle();

      expect(find.textContaining('"kind": "page"'), findsOneWidget);
      expect(find.textContaining('"id": "/teacher/home"'), findsOneWidget);
      expect(
        find.textContaining('"file": "lib/app_navigator.dart"'),
        findsOneWidget,
      );
    });

    testWidgets('a route without a name gets the unnamed id', (tester) async {
      await tester.pumpWidget(_app(routeName: null));

      final page = tester.widget<BugInspectablePage>(
        find.byType(BugInspectablePage),
      );
      expect(page.id, BugInspectablePage.unnamedRouteId);
      expect(page.label, BugInspectablePage.unnamedRouteId);
    });

    testWidgets('the strings builder sets the texts of the inspector',
        (tester) async {
      await tester.pumpWidget(
        _app(strings: (_) => BugReportStrings.vi.copyWith(title: 'QA')),
      );

      await tester.tap(find.byKey(BugInspector.launcherKey));
      await pumpModeChange(tester);
      expect(find.text(BugReportStrings.vi.selectionHint), findsOneWidget);
      expect(find.text(BugReportStrings.vi.pageButtonLabel), findsOneWidget);

      await tester.tap(find.text(BugReportStrings.vi.pageButtonLabel));
      await tester.pumpAndSettle();
      expect(find.text('QA'), findsOneWidget);
      expect(find.text(BugReportStrings.vi.send), findsOneWidget);
    });

    testWidgets('enabled false hides the inspector', (tester) async {
      await tester.pumpWidget(_app(enabled: false));

      expect(find.byKey(BugInspector.launcherKey), findsNothing);
      final context = tester.element(find.text('Tap'));
      expect(BugInspector.maybeModeCubitOf(context), isNull);
    });
  });
}

/// A context that is never used: [FlutterQaInspector.builder] does not read
/// it in a production build.
class _FakeContext extends Fake implements BuildContext {}
