part of '../../flutter_qa_inspector.dart';

/// Opens the platform share sheet with [params].
///
/// [BugReportPage] uses `SharePlus.instance.share` by default. Pass another
/// function to send the report somewhere else, for example to upload
/// `params.files` to a bug tracker and return a [ShareResult] with
/// [ShareResultStatus.success]. Tests pass a fake that records the params.
typedef BugReportShare = Future<ShareResult> Function(ShareParams params);

/// The files of one bug report, and a ZIP that holds them all:
///
/// - [screenshotFileName]: the screenshot with the tester's rectangles.
/// - [descriptionFileName]: what the tester wrote.
/// - [inspectorFileName]: the inspector JSON.
class BugReportBundle {
  /// Creates the files of a bug report.
  BugReportBundle({
    required this.name,
    required this.description,
    required this.inspectorJson,
    this.screenshotPng,
  });

  /// The name of the shared files, without an extension, see [nameFor].
  final String name;

  /// The tester's description of the bug.
  final String description;

  /// The content of [inspectorFileName]: `inspector`, the
  /// [BugWidgetSelection.toJson] of the selection, and `screenshot`, the
  /// [BugScreenshot.toJson] of the screenshot with its `annotations`.
  final Map<String, Object?> inspectorJson;

  /// The encoded PNG, or `null` when the report has no screenshot.
  final Uint8List? screenshotPng;

  /// The name of the screenshot in the ZIP.
  static const String screenshotFileName = 'screenshot.png';

  /// The name of the description in the ZIP.
  static const String descriptionFileName = 'description.txt';

  /// The name of the inspector JSON in the ZIP.
  static const String inspectorFileName = 'inspector.json';

  /// A file name made of the selection id and the UTC capture time, for
  /// example `bug_counter.increment_20261112_093005`.
  static String nameFor(String selectionId, DateTime capturedAt) {
    final id = selectionId.replaceAll(RegExp(r'[^A-Za-z0-9._-]+'), '_');
    final t = capturedAt.toUtc();
    String two(int value) => value.toString().padLeft(2, '0');
    return 'bug_${id}_${t.year}${two(t.month)}${two(t.day)}_'
        '${two(t.hour)}${two(t.minute)}${two(t.second)}';
  }

  /// The name of the shared ZIP.
  String get zipFileName => '$name.zip';

  /// The name of the shared screenshot.
  String get pngFileName => '$name.png';

  /// Encodes the ZIP with the screenshot, the description and the JSON.
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

  /// Shares the screenshot, the ZIP and the description.
  ///
  /// [subject] defaults to the English [BugReportStrings.shareSubject]. iPad
  /// shows the share sheet as a popover next to [sharePositionOrigin], in
  /// global logical pixels; other devices ignore it.
  ShareParams toShareParams({Rect? sharePositionOrigin, String? subject}) {
    final png = screenshotPng;
    final text = description.trim();
    return ShareParams(
      // share_plus rejects an empty text.
      text: text.isEmpty ? null : text,
      subject: subject ?? BugReportStrings.en.shareSubject(name),
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
