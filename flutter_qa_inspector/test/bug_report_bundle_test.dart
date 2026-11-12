import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_qa_inspector/flutter_qa_inspector.dart';
import 'package:flutter_test/flutter_test.dart';

final _png = Uint8List.fromList(<int>[0x89, 0x50, 0x4E, 0x47, 1, 2, 3]);

Map<String, ArchiveFile> _entries(Uint8List zip) => {
      for (final file in ZipDecoder().decodeBytes(zip)) file.name: file,
    };

void main() {
  test('nameFor uses the selection id and the UTC capture time', () {
    expect(
      BugReportBundle.nameFor(
        'counter.increment',
        DateTime.utc(2026, 11, 12, 9, 30, 5),
      ),
      'bug_counter.increment_20261112_093005',
    );
    // Characters that are not safe in a file name are replaced.
    expect(
      BugReportBundle.nameFor('cart / checkout:1', DateTime.utc(2026, 1, 2)),
      'bug_cart_checkout_1_20260102_000000',
    );
  });

  test('the zip holds the screenshot, the description and the JSON', () {
    final bundle = BugReportBundle(
      name: 'bug_x',
      description: 'Nút Tăng không đổi số',
      inspectorJson: {
        'inspector': {'id': 'counter.increment'},
      },
      screenshotPng: _png,
    );

    final entries = _entries(bundle.toZip());

    expect(
        entries.keys,
        unorderedEquals(<String>[
          BugReportBundle.screenshotFileName,
          BugReportBundle.descriptionFileName,
          BugReportBundle.inspectorFileName,
        ]));
    expect(entries['screenshot.png']!.readBytes(), _png);
    expect(
      utf8.decode(entries['description.txt']!.readBytes()!),
      'Nút Tăng không đổi số',
    );
    expect(
      jsonDecode(utf8.decode(entries['inspector.json']!.readBytes()!)),
      {
        'inspector': {'id': 'counter.increment'},
      },
    );
  });

  test('without a screenshot the zip has no image', () {
    final bundle = BugReportBundle(
      name: 'bug_x',
      description: '',
      inspectorJson: const {},
    );

    expect(
      _entries(bundle.toZip()).keys,
      unorderedEquals(<String>['description.txt', 'inspector.json']),
    );
  });

  test('shares the image, the zip and the description', () async {
    final bundle = BugReportBundle(
      name: 'bug_x',
      description: '  Lỗi hiển thị \n',
      inspectorJson: const {'inspector': <String, Object?>{}},
      screenshotPng: _png,
    );
    const origin = Rect.fromLTWH(10, 20, 100, 40);

    final params = bundle.toShareParams(sharePositionOrigin: origin);

    expect(params.text, 'Lỗi hiển thị');
    expect(params.subject, 'Bug report: bug_x');
    expect(params.sharePositionOrigin, origin);
    expect(params.fileNameOverrides, ['bug_x.png', 'bug_x.zip']);
    expect(params.files!.map((file) => file.mimeType), [
      'image/png',
      'application/zip',
    ]);
    expect(await params.files![0].readAsBytes(), _png);
    expect(
      _entries(await params.files![1].readAsBytes()).keys,
      hasLength(3),
    );
  });

  test('a blank description shares only the files', () {
    final params = BugReportBundle(
      name: 'bug_x',
      description: '  ',
      inspectorJson: const {},
    ).toShareParams();

    expect(params.text, isNull);
    expect(params.fileNameOverrides, ['bug_x.zip']);
  });

  test('the subject can be localized', () {
    final params = BugReportBundle(
      name: 'bug_x',
      description: '',
      inspectorJson: const {},
    ).toShareParams(subject: BugReportStrings.vi.shareSubject('bug_x'));

    expect(params.subject, 'Báo lỗi: bug_x');
  });
}
