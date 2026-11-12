import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui';

import 'package:archive/archive.dart';
import 'package:share_plus/share_plus.dart';

/// Opens the platform share sheet. The app uses [SharePlus.share]; tests pass
/// a fake that records the [ShareParams].
typedef BugReportShare = Future<ShareResult> Function(ShareParams params);

/// The files of one bug report, and a zip that holds them all:
///
/// - [screenshotFileName]: the screenshot with the tester's rectangles.
/// - [descriptionFileName]: what the tester wrote.
/// - [inspectorFileName]: the inspector JSON.
class BugReportBundle {
  BugReportBundle({
    required this.name,
    required this.description,
    required this.inspectorJson,
    this.screenshotPng,
  });

  /// The name of the shared files, without an extension.
  final String name;

  /// The tester's description of the bug.
  final String description;

  /// The selection and the screenshot details, see `BugWidgetSelection.toJson`.
  final Map<String, Object?> inspectorJson;

  /// The encoded PNG, or `null` when the report has no screenshot.
  final Uint8List? screenshotPng;

  static const screenshotFileName = 'screenshot.png';
  static const descriptionFileName = 'description.txt';
  static const inspectorFileName = 'inspector.json';

  /// A file name made of the selection id and the capture time, for example
  /// `bug_counter.increment_20261112_093005`.
  static String nameFor(String selectionId, DateTime capturedAt) {
    final id = selectionId.replaceAll(RegExp(r'[^A-Za-z0-9._-]+'), '_');
    final t = capturedAt.toUtc();
    String two(int value) => value.toString().padLeft(2, '0');
    return 'bug_${id}_${t.year}${two(t.month)}${two(t.day)}_'
        '${two(t.hour)}${two(t.minute)}${two(t.second)}';
  }

  String get zipFileName => '$name.zip';
  String get pngFileName => '$name.png';

  /// Encodes the zip with the screenshot, the description and the JSON.
  Uint8List toZip() {
    final png = screenshotPng;
    final archive = Archive()
      ..addFile(ArchiveFile.string(descriptionFileName, description))
      ..addFile(
        ArchiveFile.string(
          inspectorFileName,
          const JsonEncoder.withIndent('  ').convert(inspectorJson),
        ),
      );
    // A PNG is already compressed: store it as it is.
    if (png != null) {
      archive.addFile(
        ArchiveFile.noCompress(screenshotFileName, png.length, png),
      );
    }
    return ZipEncoder().encodeBytes(archive);
  }

  /// Shares the screenshot, the zip and the description.
  ///
  /// iPad shows the share sheet as a popover next to [sharePositionOrigin],
  /// in global logical pixels; other devices ignore it.
  ShareParams toShareParams({Rect? sharePositionOrigin}) {
    final png = screenshotPng;
    final text = description.trim();
    return ShareParams(
      // share_plus rejects an empty text.
      text: text.isEmpty ? null : text,
      subject: 'Báo lỗi: $name',
      files: [
        if (png != null) XFile.fromData(png, mimeType: 'image/png'),
        XFile.fromData(toZip(), mimeType: 'application/zip'),
      ],
      // Outside the web, XFile.fromData drops its name: these name the
      // temporary files share_plus writes.
      fileNameOverrides: [
        if (png != null) pngFileName,
        zipFileName,
      ],
      sharePositionOrigin: sharePositionOrigin,
    );
  }
}
