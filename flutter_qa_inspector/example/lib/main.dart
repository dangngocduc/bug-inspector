import 'package:bloc/bloc.dart';
import 'package:flutter/material.dart';
import 'package:flutter_qa_inspector/flutter_qa_inspector.dart';

import 'app.dart';

void main() {
  // `true` only in builds made with --dart-define=FLUTTER_QA_INSPECTOR=true.
  // It is a constant, so a production build leaves this branch out.
  const qaEnabled = BugInspector.enabledFromEnvironment;

  BugStateRecorder? recorder;
  if (qaEnabled) {
    // Install the observer before any BLoC/Cubit is created, and keep the
    // observer the app already uses.
    recorder = BugStateRecorder();
    Bloc.observer = MultiBlocObserver(
      observers: [
        Bloc.observer,
        BugInspectorBlocObserver(recorder: recorder),
      ],
    );
  }

  runApp(ExampleApp(qaEnabled: qaEnabled, recorder: recorder));
}
