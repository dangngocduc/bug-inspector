/// Lets testers pick a widget on a QA build and attach the widget info,
/// BLoC/Cubit and widget state snapshots and a recent state timeline to a bug
/// report.
///
/// Wrap the app content with [BugInspector] (usually in `MaterialApp.builder`),
/// mark widgets with [BugInspectable], expose BLoC/Cubit state with
/// [BugBlocScope], expose the fields of a [State] with [BugInspectableState],
/// and record state history with [BugInspectorBlocObserver]. Testers can mark
/// parts of the [BugScreenshot] with rectangles in a [BugScreenshotEditor].
///
/// Nothing runs unless [BugInspector.enabled] is `true`, for example in builds
/// made with `--dart-define=FLUTTER_QA_INSPECTOR=true`
/// ([BugInspector.enabledFromEnvironment]).
library;

import 'dart:async';
import 'dart:collection';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

part 'src/bug_bloc_scope.dart';
part 'src/bug_inspectable.dart';
part 'src/bug_inspectable_page.dart';
part 'src/bug_inspectable_state.dart';
part 'src/bug_inspector.dart';
part 'src/bug_screenshot.dart';
part 'src/bug_screenshot_editor.dart';
part 'src/bug_state_recorder.dart';
part 'src/inspect_mode_cubit.dart';
part 'src/models.dart';
part 'src/selection_resolver.dart';
