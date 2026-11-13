import 'package:flutter/material.dart';
import 'package:flutter_qa_inspector/flutter_qa_inspector.dart';

import 'app.dart';
import 'jsonplaceholder_api.dart';

void main() {
  // Records the BLoC/Cubit state timeline. Call it before any BLoC/Cubit is
  // created: it keeps the observer the app already uses. Without
  // --dart-define=FLUTTER_QA_INSPECTOR=true it does nothing.
  // It also creates the recorder of the API calls that the Dio interceptors
  // of demo_api.dart and jsonplaceholder_api.dart write into.
  FlutterQaInspector.install(networkRecorder: exampleNetworkRecorder());

  // `true` only in builds made with --dart-define=FLUTTER_QA_INSPECTOR=true.
  // It is a constant, so a production build leaves the inspector out.
  runApp(const ExampleApp(qaEnabled: BugInspector.enabledFromEnvironment));
}
