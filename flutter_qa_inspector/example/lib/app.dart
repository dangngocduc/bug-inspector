import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_qa_inspector/flutter_qa_inspector.dart';

import 'bug_report_page.dart';
import 'counter_page.dart';

class ExampleApp extends StatelessWidget {
  const ExampleApp({
    super.key,
    required this.qaEnabled,
    this.recorder,
    this.captureScreenshots = true,
  });

  /// Whether the bug inspector is part of this build.
  final bool qaEnabled;

  /// The recorder fed by `BugInspectorBlocObserver`, see `main.dart`.
  final BugStateRecorder? recorder;

  /// Whether a screenshot is attached to the bug report.
  final bool captureScreenshots;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'QA Inspector Example',
      theme: ThemeData(colorSchemeSeed: Colors.indigo),
      // When qaEnabled is false, BugInspector returns the builder's child
      // unchanged, and every BugInspectable, BugInspectablePage and
      // BugBlocScope below it only returns its child.
      builder: (context, child) => BugInspector(
        enabled: qaEnabled,
        stateRecorder: recorder,
        onWidgetSelected: _openBugReport,
        // Keep the builder's child, it holds the Navigator.
        child: child ?? const SizedBox.shrink(),
      ),
      home: BlocProvider<CounterCubit>(
        create: (_) => CounterCubit(),
        // Marks the whole screen, so the tester can report the page itself.
        child: const BugInspectablePage(
          id: 'counter',
          label: 'Counter',
          sourceFile: 'example/lib/counter_page.dart',
          child: CounterPage(),
        ),
      ),
    );
  }

  Future<void> _openBugReport(
    BuildContext widgetContext,
    BugWidgetSelection selection,
  ) async {
    // The inspector has already left the selecting mode. The screenshot waits
    // for the frame without borders and is taken before the report opens.
    final screenshot = captureScreenshots
        ? await BugInspector.captureScreenshot(widgetContext)
        : null;
    if (!widgetContext.mounted) return;

    await BugReportPage.open(
      widgetContext,
      selection: selection,
      screenshot: screenshot,
    );
  }
}
