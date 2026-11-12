import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_qa_inspector/flutter_qa_inspector.dart';

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

  /// The state timeline. [FlutterQaInspector.recorder], set up by
  /// `FlutterQaInspector.install` in `main.dart`, when `null`.
  final BugStateRecorder? recorder;

  /// Whether a screenshot is attached to the bug report.
  final bool captureScreenshots;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'QA Inspector Example',
      theme: ThemeData(colorSchemeSeed: Colors.indigo),
      // Hosts the inspector and opens the package's BugReportPage for every
      // selection. When qaEnabled is false, the inspector returns the
      // builder's child unchanged, and every BugInspectable,
      // BugInspectablePage and BugBlocScope below it only returns its child.
      // Apps without these options can pass `FlutterQaInspector.builder`.
      builder: (context, child) => FlutterQaInspector.wrap(
        enabled: qaEnabled,
        stateRecorder: recorder,
        captureScreenshot: captureScreenshots,
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
}
