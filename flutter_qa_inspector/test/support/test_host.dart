import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_qa_inspector/flutter_qa_inspector.dart';
import 'package:flutter_test/flutter_test.dart';

/// Pumps a [MaterialApp] whose builder wraps the navigator in a
/// [BugInspector] and returns the selections it reports.
Future<List<BugWidgetSelection>> pumpHost(
  WidgetTester tester, {
  required Widget home,
  bool enabled = true,
  InspectModeCubit? modeCubit,
  BugStateRecorder? recorder,
  Duration historyWindow = BugInspector.defaultHistoryWindow,
  bool disableModeOnSelection = true,
  BugSelectionTrigger selectionTrigger = BugSelectionTrigger.tapUp,
  bool showLauncher = true,
  bool showPageButton = true,
  bool selectPageOnEmptyTap = false,
  BugWidgetSelectedCallback? onWidgetSelected,
}) async {
  final selections = <BugWidgetSelection>[];
  await tester.pumpWidget(
    MaterialApp(
      builder: (context, child) => BugInspector(
        enabled: enabled,
        modeCubit: modeCubit,
        stateRecorder: recorder,
        historyWindow: historyWindow,
        disableModeOnSelection: disableModeOnSelection,
        selectionTrigger: selectionTrigger,
        showLauncher: showLauncher,
        showPageButton: showPageButton,
        selectPageOnEmptyTap: selectPageOnEmptyTap,
        onWidgetSelected: (widgetContext, selection) {
          selections.add(selection);
          onWidgetSelected?.call(widgetContext, selection);
        },
        child: child ?? const SizedBox.shrink(),
      ),
      home: home,
    ),
  );
  return selections;
}

InspectModeCubit modeOf(WidgetTester tester) =>
    tester.element(find.byType(Navigator)).read<InspectModeCubit>();

/// Pumps until a mode change is fully on screen.
///
/// The cubit delivers the new state through a stream, so the rebuild is
/// scheduled one microtask later. The page button then appears one frame
/// after the borders were painted.
Future<void> pumpModeChange(WidgetTester tester) async {
  await tester.pump();
  await tester.pump();
  await tester.pump();
}

Future<void> enable(WidgetTester tester) async {
  modeOf(tester).enable();
  await pumpModeChange(tester);
}

Future<void> disable(WidgetTester tester) async {
  modeOf(tester).disable();
  await pumpModeChange(tester);
}

Future<void> tapCenterOf(WidgetTester tester, Finder finder) async {
  await tester.tapAt(tester.getCenter(finder));
  await tester.pump();
}

/// Finds the [BugInspectable] or [BugInspectablePage] with [id].
Finder inspectable(String id) => find.byWidgetPredicate(
      (widget) =>
          (widget is BugInspectable && widget.id == id) ||
          (widget is BugInspectablePage && widget.id == id),
    );

Widget box(double width, double height) =>
    SizedBox(width: width, height: height);

PaintPattern get paintsBorder => paints
  ..rect(
    color: BugInspector.defaultBorderColor,
    style: PaintingStyle.stroke,
    strokeWidth: BugInspector.defaultBorderWidth,
  );

PaintPattern get paintsPageBorder => paints
  ..rect(
    color: BugInspector.defaultPageBorderColor,
    style: PaintingStyle.stroke,
    strokeWidth: BugInspector.defaultPageBorderWidth,
  );

final Finder launcher = find.byKey(BugInspector.launcherKey);

final Finder exitButton = find.byKey(BugInspector.exitButtonKey);

final Finder pageButton = find.byKey(BugInspector.pageButtonKey);
