import 'package:flutter/material.dart';
import 'package:flutter_qa_inspector/flutter_qa_inspector.dart';

import 'app.dart';

void main() {
  // Records the BLoC/Cubit state timeline. Call it before any BLoC/Cubit is
  // created: it keeps the observer the app already uses. Without
  // --dart-define=FLUTTER_QA_INSPECTOR=true it does nothing.
  FlutterQaInspector.install();

  // `true` only in builds made with --dart-define=FLUTTER_QA_INSPECTOR=true.
  // It is a constant, so a production build leaves the inspector out.
  runApp(const ExampleApp(qaEnabled: BugInspector.enabledFromEnvironment));
}
