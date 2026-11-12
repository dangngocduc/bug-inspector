import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_qa_inspector/flutter_qa_inspector.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/test_host.dart';
import 'support/build_mode.dart';

void main() => qaBuildOnly(() {
      testWidgets('the launcher floats above the app and enables the mode',
          (tester) async {
        final home = Scaffold(
          appBar: AppBar(title: const Text('App')),
          body: Center(child: BugInspectable(id: 'a', child: box(50, 50))),
        );
        await pumpHost(tester, home: home, showLauncher: false);
        final layoutWithout = tester.getRect(find.byType(Scaffold));
        final titleWithout = tester.getRect(find.text('App'));

        await pumpHost(tester, home: home);
        expect(launcher, findsOneWidget);
        // Not part of the app content: not below its Navigator, no layout change.
        expect(
          find.descendant(of: find.byType(Navigator), matching: launcher),
          findsNothing,
        );
        expect(tester.getRect(find.byType(Scaffold)), layoutWithout);
        expect(tester.getRect(find.text('App')), titleWithout);

        await tester.tap(launcher);
        await pumpModeChange(tester);

        expect(modeOf(tester).state, InspectMode.selecting);
        expect(launcher, findsNothing);
        expect(find.text(BugInspector.defaultSelectionHint), findsOneWidget);
        expect(exitButton, findsOneWidget);
      });

      testWidgets('the app keeps its taps, drags and focus', (tester) async {
        final controller = ScrollController();
        final focusNode = FocusNode();
        addTearDown(controller.dispose);
        addTearDown(focusNode.dispose);
        var appTaps = 0;
        await pumpHost(
          tester,
          home: Scaffold(
            body: Column(
              children: <Widget>[
                TextField(focusNode: focusNode),
                TextButton(
                  onPressed: () => appTaps++,
                  child: const Text('App button'),
                ),
                Expanded(
                  child: ListView(
                    controller: controller,
                    children: <Widget>[
                      for (var i = 0; i < 50; i++)
                        SizedBox(height: 40, child: Text('$i')),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );

        await tester.tap(find.text('App button'));
        expect(appTaps, 1);

        // Dragging the launcher moves it and does not scroll the list below it.
        final start = tester.getRect(launcher);
        await tester.drag(launcher, const Offset(-200, 0));
        await tester.pump();
        expect(tester.getRect(launcher).left, lessThan(start.left - 150));
        expect(controller.offset, 0);
        expect(modeOf(tester).state, InspectMode.disabled);

        // Using the control does not move the focus away from the app, even with
        // a mouse, where a tap outside a text field usually unfocuses it.
        focusNode.requestFocus();
        await tester.pump();
        await tester.tap(launcher, kind: PointerDeviceKind.mouse);
        await pumpModeChange(tester);
        expect(modeOf(tester).state, InspectMode.selecting);
        expect(focusNode.hasFocus, isTrue);

        await tester.tap(exitButton, kind: PointerDeviceKind.mouse);
        await pumpModeChange(tester);
        expect(focusNode.hasFocus, isTrue);
      });

      testWidgets('showLauncher: false still shows the toolbar while selecting',
          (tester) async {
        await pumpHost(tester,
            home: const SizedBox.expand(), showLauncher: false);
        expect(launcher, findsNothing);

        await enable(tester);
        expect(exitButton, findsOneWidget);

        await tester.tap(exitButton);
        await pumpModeChange(tester);
        expect(modeOf(tester).state, InspectMode.disabled);
        expect(launcher, findsNothing);
      });

      testWidgets('the position is shared by the launcher and the toolbar',
          (tester) async {
        await pumpHost(tester, home: const SizedBox.expand());

        // Drag far beyond the top left corner: the control stays on screen.
        await tester.drag(launcher, const Offset(-2000, -2000));
        await tester.pump();
        expect(tester.getRect(launcher).topLeft, const Offset(16, 16));

        await tester.tap(launcher);
        await pumpModeChange(tester);
        final toolbar = tester.getRect(
          find.ancestor(of: exitButton, matching: find.byType(Material)).last,
        );
        expect(toolbar.topLeft, const Offset(16, 16));

        // Dragging the toolbar does not select anything below it.
        await tester.drag(exitButton, const Offset(300, 200));
        await tester.pump();
        expect(modeOf(tester).state, InspectMode.selecting);
        expect(
          tester
              .getRect(
                find
                    .ancestor(of: exitButton, matching: find.byType(Material))
                    .last,
              )
              .topLeft,
          const Offset(316, 216),
        );

        await tester.tap(exitButton);
        await pumpModeChange(tester);
        expect(tester.getRect(launcher).left, greaterThan(16));
      });

      testWidgets('screen readers can use every control', (tester) async {
        final handle = tester.ensureSemantics();
        final selections = await pumpHost(
          tester,
          home: const Scaffold(
            body: BugInspectablePage(
              id: 'home',
              label: 'Home',
              child: SizedBox.expand(),
            ),
          ),
        );

        Future<void> activate(String label) async {
          // Its own button node, not merged into the one that covers the app.
          final node = tester.getSemantics(find.bySemanticsLabel(label));
          final data = node.getSemanticsData();
          // flagsCollection, its replacement, needs Flutter 3.32; the package
          // supports 3.19.
          // ignore: deprecated_member_use
          expect(data.hasFlag(SemanticsFlag.isButton), isTrue);
          expect(data.hasAction(SemanticsAction.tap), isTrue);
          expect(node.rect.width, lessThan(300));
          tester.semantics.tap(find.semantics.byLabel(label));
          await pumpModeChange(tester);
        }

        // Dragging the control is not offered as scrolling, here or on the app.
        expect(
            find.semantics.byAction(SemanticsAction.scrollLeft), findsNothing);

        await activate('Open bug inspector');
        expect(modeOf(tester).state, InspectMode.selecting);
        expect(
            find.semantics.byAction(SemanticsAction.scrollLeft), findsNothing);

        await activate('Exit inspect mode');
        expect(modeOf(tester).state, InspectMode.disabled);

        await activate('Open bug inspector');
        await activate('${BugInspector.defaultPageButtonLabel}: Home');
        expect(selections.single.kind, BugSelectionKind.page);
        expect(selections.single.id, 'home');
        expect(modeOf(tester).state, InspectMode.disabled);
        handle.dispose();
      });

      testWidgets('screenshots leave the control out', (tester) async {
        late BuildContext context;
        await pumpHost(
          tester,
          home: Builder(
            builder: (c) {
              context = c;
              return const ColoredBox(color: Color(0xFF00FF00));
            },
          ),
        );
        final screenshot = await tester.runAsync(
          () => BugInspector.captureScreenshot(
            context,
            pixelRatio: 1,
            waitForNextFrame: false,
          ),
        );
        final image = await tester.runAsync(
          () => decodeImageFromList(screenshot!.pngBytes),
        );
        final pixels = await tester.runAsync(() => image!.toByteData());
        final center = tester.getCenter(launcher);
        final offset =
            (center.dy.round() * image!.width + center.dx.round()) * 4;

        // RGBA of the app background where the launcher is drawn on screen.
        expect(
          pixels!.buffer.asUint8List(offset, 4),
          <int>[0x00, 0xFF, 0x00, 0xFF],
        );
        image.dispose();
      });
    });
