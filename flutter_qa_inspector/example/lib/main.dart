import 'package:bloc/bloc.dart';
import 'package:flutter/material.dart';
import 'package:flutter_qa_inspector/flutter_qa_inspector.dart';

import 'app.dart';

/// Build QA builds with `--dart-define=QA_INSPECTOR=true`.
const qaInspectorEnabled = bool.fromEnvironment('QA_INSPECTOR');

void main() {
  // Install the observer before any BLoC/Cubit is created, and keep the
  // observer the app already uses.
  final recorder = qaInspectorEnabled ? BugStateRecorder() : null;
  if (recorder != null) {
    Bloc.observer = MultiBlocObserver(
      observers: [
        Bloc.observer,
        BugInspectorBlocObserver(recorder: recorder),
      ],
    );
  }

  runApp(ExampleApp(qaEnabled: qaInspectorEnabled, recorder: recorder));
}
