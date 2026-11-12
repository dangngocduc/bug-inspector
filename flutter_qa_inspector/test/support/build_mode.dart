import 'package:flutter_qa_inspector/flutter_qa_inspector.dart';
import 'package:flutter_test/flutter_test.dart';

const String _qaDefine = '--dart-define=FLUTTER_QA_INSPECTOR=true';

/// Declares the tests of [body] when the inspector is compiled in:
/// `flutter test --dart-define=FLUTTER_QA_INSPECTOR=true`.
///
/// Otherwise declares a single skipped test that says how to run them.
void qaBuildOnly(void Function() body) {
  if (BugInspector.enabledFromEnvironment) {
    body();
  } else {
    test('QA build tests', () {}, skip: 'Run with $_qaDefine');
  }
}

/// Declares the tests of [body] when the inspector is not compiled in, as in
/// a production build: `flutter test` without the define.
void productionBuildOnly(void Function() body) {
  if (BugInspector.enabledFromEnvironment) {
    test('production build tests', () {}, skip: 'Run without $_qaDefine');
  } else {
    body();
  }
}
