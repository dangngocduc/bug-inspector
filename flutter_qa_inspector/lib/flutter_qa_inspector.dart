/// Lets testers pick a widget on a QA build and attach the widget info,
/// BLoC/Cubit and widget state snapshots and a recent state timeline to a bug
/// report.
///
/// The quickest setup is [FlutterQaInspector]: `FlutterQaInspector.install()`
/// before the app starts and `FlutterQaInspector.builder` as
/// `MaterialApp.builder`. A selection then opens the ready-made
/// [BugReportPage], which shares the screenshot, the description and the
/// inspector JSON as a ZIP ([BugReportBundle]).
///
/// For a custom flow, wrap the app content with [BugInspector] (usually in
/// `MaterialApp.builder`),
/// mark widgets with [BugInspectable], expose BLoC/Cubit state with
/// [BugBlocScope], expose the fields of a [State] with [BugInspectableState],
/// and record state history with [BugInspectorBlocObserver]. Testers can mark
/// parts of the [BugScreenshot] with rectangles in a [BugScreenshotEditor].
///
/// The inspector requires `--dart-define=FLUTTER_QA_INSPECTOR=true`
/// ([BugInspector.enabledFromEnvironment]) and [BugInspector.enabled]. The
/// facade checks this flag. Direct calls to [BugReportPage] or
/// [BugReportBundle] are independent of it; gate a custom report entry point
/// with the same flag when it should only be available in QA builds.
library;

import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:archive/archive.dart' show Archive, ArchiveFile, ZipEncoder;
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:share_plus/share_plus.dart'
    show SharePlus, ShareParams, ShareResult, ShareResultStatus, XFile;

// The types of a custom [BugReportShare], so the app does not need its own
// share_plus dependency to write one.
export 'package:share_plus/share_plus.dart'
    show ShareParams, ShareResult, ShareResultStatus, XFile;

part 'src/bug_bloc_scope.dart';
part 'src/bug_inspectable.dart';
part 'src/bug_inspectable_page.dart';
part 'src/bug_inspectable_state.dart';
part 'src/bug_inspector.dart';
part 'src/bug_screenshot.dart';
part 'src/bug_screenshot_editor.dart';
part 'src/bug_state_recorder.dart';
part 'src/bug_status_bar.dart';
part 'src/flutter_qa_inspector_setup.dart';
part 'src/inspect_mode_cubit.dart';
part 'src/models.dart';
part 'src/report/bug_report_bundle.dart';
part 'src/report/bug_report_page.dart';
part 'src/report/bug_report_strings.dart';
part 'src/report/screenshot_annotation_page.dart';
part 'src/selection_resolver.dart';
