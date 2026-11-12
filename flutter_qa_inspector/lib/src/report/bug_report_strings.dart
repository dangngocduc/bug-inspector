part of '../../flutter_qa_inspector.dart';

/// The texts of the floating inspector control, of [BugReportPage] and of its
/// screenshot editor.
///
/// The package ships [en] and [vi]. [of] picks one from the locale of the
/// context, so most apps pass nothing. An app with its own localization can
/// build a [BugReportStrings] from it, for example in
/// `FlutterQaInspector.wrap(strings: (context) => ...)`, or change a few
/// texts with [copyWith].
@immutable
class BugReportStrings {
  /// Creates a set of texts. Every text is required, see [en] for the
  /// English ones.
  const BugReportStrings({
    required this.selectionHint,
    required this.pageButtonLabel,
    required this.title,
    required this.cancel,
    required this.send,
    required this.sectionTarget,
    required this.kindScreen,
    required this.kindWidget,
    required this.sectionScreenshot,
    required this.annotateHint,
    required this.annotatedCount,
    required this.sectionDescription,
    required this.descriptionPlaceholder,
    required this.sectionPayload,
    required this.copyJson,
    required this.copied,
    required this.discardTitle,
    required this.discardMessage,
    required this.discardConfirm,
    required this.keepEditing,
    required this.shareFailed,
    required this.ok,
    required this.shareSubject,
    required this.markup,
    required this.annotateTitle,
    required this.annotateClearAll,
    required this.annotateClearAllTitle,
    required this.annotateClearAllConfirm,
    required this.annotateDone,
    required this.annotateDeleteBox,
    required this.annotateResetZoom,
    required this.annotateInstructions,
  });

  /// The English texts, used for every locale but Vietnamese.
  static const BugReportStrings en = BugReportStrings(
    selectionHint: BugInspector.defaultSelectionHint,
    pageButtonLabel: BugInspector.defaultPageButtonLabel,
    title: 'Bug report',
    cancel: 'Cancel',
    send: 'Send',
    sectionTarget: 'Target',
    kindScreen: 'Screen',
    kindWidget: 'Widget',
    sectionScreenshot: 'Screenshot',
    annotateHint: 'Tap the image to mark the problem area',
    annotatedCount: _enAnnotatedCount,
    sectionDescription: 'Description',
    descriptionPlaceholder: 'What went wrong, and the steps to reproduce',
    sectionPayload: 'Payload',
    copyJson: 'Copy JSON',
    copied: 'Copied',
    discardTitle: 'Discard this bug report?',
    discardMessage: 'The description and marked areas will be removed.',
    discardConfirm: 'Discard report',
    keepEditing: 'Keep editing',
    shareFailed: "Couldn't share the bug report",
    ok: 'OK',
    shareSubject: _enShareSubject,
    markup: 'Mark up',
    annotateTitle: 'Mark up screenshot',
    annotateClearAll: 'Clear all',
    annotateClearAllTitle: 'Remove all boxes?',
    annotateClearAllConfirm: 'Remove all',
    annotateDone: 'Done',
    annotateDeleteBox: 'Delete box',
    annotateResetZoom: 'Fit to screen',
    annotateInstructions: 'Drag on the image to draw a box. Tap a box to '
        'select it, drag to move it, drag its corners to resize, tap ✕ to '
        'delete. Use two fingers to zoom.',
  );

  /// The Vietnamese texts.
  static const BugReportStrings vi = BugReportStrings(
    selectionHint: 'Chạm vào vùng được đánh dấu',
    pageButtonLabel: 'Chọn màn hình',
    title: 'Báo lỗi',
    cancel: 'Hủy',
    send: 'Gửi',
    sectionTarget: 'Đối tượng',
    kindScreen: 'Màn hình',
    kindWidget: 'Widget',
    sectionScreenshot: 'Ảnh chụp màn hình',
    annotateHint: 'Chạm vào ảnh để đánh dấu vùng lỗi',
    annotatedCount: _viAnnotatedCount,
    sectionDescription: 'Mô tả',
    descriptionPlaceholder: 'Lỗi gì xảy ra, và các bước để tái hiện',
    sectionPayload: 'Payload',
    copyJson: 'Sao chép JSON',
    copied: 'Đã sao chép',
    discardTitle: 'Bỏ báo lỗi này?',
    discardMessage: 'Mô tả và các vùng đã đánh dấu sẽ bị xóa.',
    discardConfirm: 'Bỏ báo lỗi',
    keepEditing: 'Tiếp tục chỉnh sửa',
    shareFailed: 'Không chia sẻ được báo lỗi',
    ok: 'OK',
    shareSubject: _viShareSubject,
    markup: 'Đánh dấu',
    annotateTitle: 'Đánh dấu trên ảnh',
    annotateClearAll: 'Xóa hết',
    annotateClearAllTitle: 'Xóa tất cả các khung?',
    annotateClearAllConfirm: 'Xóa tất cả',
    annotateDone: 'Xong',
    annotateDeleteBox: 'Xóa khung',
    annotateResetZoom: 'Về kích thước vừa màn hình',
    annotateInstructions: 'Kéo trên ảnh để vẽ khung. Chạm vào khung để chọn, '
        'kéo để di chuyển, kéo các góc để đổi kích thước, bấm ✕ để xóa. Dùng '
        'hai ngón tay để phóng to.',
  );

  /// [vi] when the language of the nearest [Localizations] is Vietnamese,
  /// [en] otherwise, including when there is no [Localizations].
  static BugReportStrings of(BuildContext context) {
    final locale = Localizations.maybeLocaleOf(context);
    return locale?.languageCode == 'vi' ? vi : en;
  }

  static String _enAnnotatedCount(int count) =>
      '$count area(s) marked · Tap the image to edit';
  static String _viAnnotatedCount(int count) =>
      'Đã đánh dấu $count vùng · Chạm vào ảnh để sửa';
  static String _enShareSubject(String name) => 'Bug report: $name';
  static String _viShareSubject(String name) => 'Báo lỗi: $name';

  /// The hint of the floating toolbar, see [BugInspector.selectionHint].
  final String selectionHint;

  /// The "Select screen" button, see [BugInspector.pageButtonLabel].
  final String pageButtonLabel;

  /// The title of the report form.
  final String title;

  /// The button that closes the report without sending it.
  final String cancel;

  /// The button that sends the report.
  final String send;

  /// The header of the selected widget or screen.
  final String sectionTarget;

  /// Shown next to a selected screen.
  final String kindScreen;

  /// Shown next to a selected widget.
  final String kindWidget;

  /// The header of the screenshot.
  final String sectionScreenshot;

  /// Below the screenshot, before the tester drew a rectangle.
  final String annotateHint;

  /// Below the screenshot, once the tester drew `count` rectangles.
  final String Function(int count) annotatedCount;

  /// The header of the description field.
  final String sectionDescription;

  /// The placeholder of the description field.
  final String descriptionPlaceholder;

  /// The header of the inspector JSON.
  final String sectionPayload;

  /// The button that copies the report JSON.
  final String copyJson;

  /// The copy button, for a moment after a copy.
  final String copied;

  /// The title of the sheet shown before a written report is discarded.
  final String discardTitle;

  /// The message of the sheet shown before a written report is discarded.
  final String discardMessage;

  /// The button that discards a written report.
  final String discardConfirm;

  /// The button that keeps a written report open.
  final String keepEditing;

  /// The title of the dialog shown when sharing fails.
  final String shareFailed;

  /// The button that closes the share error dialog.
  final String ok;

  /// The subject of the shared report, from its file name `name`.
  final String Function(String name) shareSubject;

  /// The badge on the screenshot preview.
  final String markup;

  /// The title of the screenshot editor page.
  final String annotateTitle;

  /// The button that removes every rectangle.
  final String annotateClearAll;

  /// The title of the sheet shown before every rectangle is removed.
  final String annotateClearAllTitle;

  /// The button that confirms removing every rectangle.
  final String annotateClearAllConfirm;

  /// The button that closes the screenshot editor.
  final String annotateDone;

  /// See [BugScreenshotEditor.deleteButtonLabel].
  final String annotateDeleteBox;

  /// See [BugScreenshotEditor.resetZoomButtonLabel].
  final String annotateResetZoom;

  /// The help text below the screenshot editor.
  final String annotateInstructions;

  /// A copy with the given texts replaced.
  BugReportStrings copyWith({
    String? selectionHint,
    String? pageButtonLabel,
    String? title,
    String? cancel,
    String? send,
    String? sectionTarget,
    String? kindScreen,
    String? kindWidget,
    String? sectionScreenshot,
    String? annotateHint,
    String Function(int count)? annotatedCount,
    String? sectionDescription,
    String? descriptionPlaceholder,
    String? sectionPayload,
    String? copyJson,
    String? copied,
    String? discardTitle,
    String? discardMessage,
    String? discardConfirm,
    String? keepEditing,
    String? shareFailed,
    String? ok,
    String Function(String name)? shareSubject,
    String? markup,
    String? annotateTitle,
    String? annotateClearAll,
    String? annotateClearAllTitle,
    String? annotateClearAllConfirm,
    String? annotateDone,
    String? annotateDeleteBox,
    String? annotateResetZoom,
    String? annotateInstructions,
  }) {
    return BugReportStrings(
      selectionHint: selectionHint ?? this.selectionHint,
      pageButtonLabel: pageButtonLabel ?? this.pageButtonLabel,
      title: title ?? this.title,
      cancel: cancel ?? this.cancel,
      send: send ?? this.send,
      sectionTarget: sectionTarget ?? this.sectionTarget,
      kindScreen: kindScreen ?? this.kindScreen,
      kindWidget: kindWidget ?? this.kindWidget,
      sectionScreenshot: sectionScreenshot ?? this.sectionScreenshot,
      annotateHint: annotateHint ?? this.annotateHint,
      annotatedCount: annotatedCount ?? this.annotatedCount,
      sectionDescription: sectionDescription ?? this.sectionDescription,
      descriptionPlaceholder:
          descriptionPlaceholder ?? this.descriptionPlaceholder,
      sectionPayload: sectionPayload ?? this.sectionPayload,
      copyJson: copyJson ?? this.copyJson,
      copied: copied ?? this.copied,
      discardTitle: discardTitle ?? this.discardTitle,
      discardMessage: discardMessage ?? this.discardMessage,
      discardConfirm: discardConfirm ?? this.discardConfirm,
      keepEditing: keepEditing ?? this.keepEditing,
      shareFailed: shareFailed ?? this.shareFailed,
      ok: ok ?? this.ok,
      shareSubject: shareSubject ?? this.shareSubject,
      markup: markup ?? this.markup,
      annotateTitle: annotateTitle ?? this.annotateTitle,
      annotateClearAll: annotateClearAll ?? this.annotateClearAll,
      annotateClearAllTitle:
          annotateClearAllTitle ?? this.annotateClearAllTitle,
      annotateClearAllConfirm:
          annotateClearAllConfirm ?? this.annotateClearAllConfirm,
      annotateDone: annotateDone ?? this.annotateDone,
      annotateDeleteBox: annotateDeleteBox ?? this.annotateDeleteBox,
      annotateResetZoom: annotateResetZoom ?? this.annotateResetZoom,
      annotateInstructions: annotateInstructions ?? this.annotateInstructions,
    );
  }
}
