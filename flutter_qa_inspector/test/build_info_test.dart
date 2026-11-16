import 'package:flutter/material.dart';
import 'package:flutter_qa_inspector/flutter_qa_inspector.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';

import 'support/build_mode.dart';
import 'support/test_host.dart';

void mockVersion(String version, String buildNumber) {
  PackageInfo.setMockInitialValues(
    appName: 'Example',
    packageName: 'com.example.app',
    version: version,
    buildNumber: buildNumber,
    buildSignature: '',
  );
}

Finder richText(String text) => find.text(text, findRichText: true);

Future<void> pumpSelecting(
  WidgetTester tester, {
  bool showBuildInfo = true,
  String branch = '',
  BugReportStrings? strings,
}) async {
  await pumpHost(
    tester,
    home: Scaffold(body: BugInspectable(id: 'a', child: box(50, 50))),
    showBuildInfo: showBuildInfo,
    branch: branch,
    strings: strings,
  );
  // The version is read from the platform after the first frame.
  await tester.pump();
  await enable(tester);
}

void main() => qaBuildOnly(() {
      test('the branch comes from FLUTTER_QA_INSPECTOR_BRANCH', () {
        expect(
          BugInspector.branchFromEnvironment,
          const String.fromEnvironment('FLUTTER_QA_INSPECTOR_BRANCH'),
        );
      });

      testWidgets('the toolbar ends with the app version and the branch',
          (tester) async {
        mockVersion('1.2.0', '42');
        await pumpHost(
          tester,
          home: Scaffold(body: BugInspectable(id: 'a', child: box(50, 50))),
          branch: '  feature/login  ',
        );
        await tester.pump();
        // Only part of the toolbar, not of the launcher.
        expect(buildInfo, findsNothing);

        await enable(tester);
        expect(buildInfo, findsOneWidget);
        expect(richText('Version  1.2.0 (42)'), findsOneWidget);
        expect(richText('Branch  feature/login'), findsOneWidget);
        expect(
          tester.getRect(buildInfo).top,
          greaterThan(tester.getRect(exitButton).bottom),
        );

        await disable(tester);
        expect(buildInfo, findsNothing);
      });

      testWidgets('an empty branch only hides the branch', (tester) async {
        mockVersion('2.0.0', '2.0.0');
        await pumpSelecting(tester);
        expect(buildInfo, findsOneWidget);
        // A build number equal to the version is not repeated.
        expect(richText('Version  2.0.0'), findsOneWidget);
        expect(find.textContaining('Branch', findRichText: true), findsNothing);
      });

      testWidgets('the branch shows without a version', (tester) async {
        mockVersion('', '');
        await pumpSelecting(tester, branch: 'develop');
        expect(buildInfo, findsOneWidget);
        expect(richText('Branch  develop'), findsOneWidget);
        expect(
          find.textContaining('Version', findRichText: true),
          findsNothing,
        );
      });

      testWidgets('nothing shows without a version and a branch',
          (tester) async {
        mockVersion('', '');
        await pumpSelecting(tester, branch: '   ');
        expect(exitButton, findsOneWidget);
        expect(buildInfo, findsNothing);
      });

      testWidgets('showBuildInfo: false hides it', (tester) async {
        mockVersion('1.2.0', '42');
        await pumpSelecting(tester, showBuildInfo: false, branch: 'main');
        expect(exitButton, findsOneWidget);
        expect(buildInfo, findsNothing);
      });

      testWidgets('the labels come from the strings', (tester) async {
        mockVersion('1.2.0', '42');
        await pumpSelecting(
          tester,
          branch: 'main',
          strings: BugReportStrings.vi,
        );
        expect(richText('Phiên bản  1.2.0 (42)'), findsOneWidget);
        expect(richText('Branch  main'), findsOneWidget);

        expect(
          BugReportStrings.en
              .copyWith(buildVersionLabel: 'Build', buildBranchLabel: 'Git')
              .buildBranchLabel,
          'Git',
        );
      });
    });
