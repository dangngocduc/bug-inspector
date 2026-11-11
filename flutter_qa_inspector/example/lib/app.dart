import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_qa_inspector/flutter_qa_inspector.dart';

import 'bug_report_sheet.dart';
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
      builder: (context, child) {
        // Keep the builder's child, it holds the Navigator.
        final appContent = child ?? const SizedBox.shrink();
        if (!qaEnabled) return appContent;

        return BugInspector(
          stateRecorder: recorder,
          onWidgetSelected: _openBugReport,
          child: appContent,
        );
      },
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
    // for the frame without borders and is taken before the sheet opens.
    final screenshot = captureScreenshots
        ? await BugInspector.captureScreenshot(widgetContext)
        : null;
    if (!widgetContext.mounted) return;

    await showModalBottomSheet<void>(
      context: widgetContext,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => BugReportSheet(
        selection: selection,
        screenshot: screenshot,
      ),
    );
  }
}
