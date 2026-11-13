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
  /// Creates a set of texts. Every text but those of the network section is
  /// required, see [en] for the English ones. The texts of the network
  /// section default to English.
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
    this.sectionNetwork = 'Network',
    this.networkCount = _enNetworkCount,
    this.networkPending = 'Pending',
    this.networkRequest = 'Request',
    this.networkResponse = 'Response',
    this.copyValue = 'Copy value',
    this.networkRequestHeaders = 'Request headers',
    this.networkRequestBody = 'Request body',
    this.networkResponseHeaders = 'Response headers',
    this.networkResponseBody = 'Response body',
    this.networkError = 'Error',
    this.networkTruncated = _enNetworkTruncated,
    this.jsonExpandAll = 'Expand all',
    this.jsonCollapseAll = 'Collapse all',
    this.jsonItemCount = _enJsonItemCount,
    this.networkHistoryTitle = 'API calls',
    this.networkHistoryEmpty =
        'No API calls yet. The calls of the Dio clients appear here as the app makes them.',
    this.networkClear = 'Clear',
    this.close = 'Close',
    this.networkButtonLabel = 'Inspect network',
    this.networkButtonSubtitle = _enNetworkButtonSubtitle,
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
    sectionNetwork: 'Network',
    networkCount: _enNetworkCount,
    networkPending: 'Pending',
    networkRequest: 'Request',
    networkResponse: 'Response',
    copyValue: 'Copy value',
    networkRequestHeaders: 'Request headers',
    networkRequestBody: 'Request body',
    networkResponseHeaders: 'Response headers',
    networkResponseBody: 'Response body',
    networkError: 'Error',
    networkTruncated: _enNetworkTruncated,
    jsonExpandAll: 'Expand all',
    jsonCollapseAll: 'Collapse all',
    jsonItemCount: _enJsonItemCount,
    networkHistoryTitle: 'API calls',
    networkHistoryEmpty:
        'No API calls yet. The calls of the Dio clients appear here as the app makes them.',
    networkClear: 'Clear',
    close: 'Close',
    networkButtonLabel: 'Inspect network',
    networkButtonSubtitle: _enNetworkButtonSubtitle,
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
    sectionNetwork: 'Network',
    networkCount: _viNetworkCount,
    networkPending: 'Đang chờ',
    networkRequest: 'Request',
    networkResponse: 'Response',
    copyValue: 'Sao chép giá trị',
    networkRequestHeaders: 'Request headers',
    networkRequestBody: 'Request body',
    networkResponseHeaders: 'Response headers',
    networkResponseBody: 'Response body',
    networkError: 'Lỗi',
    networkTruncated: _viNetworkTruncated,
    jsonExpandAll: 'Mở rộng tất cả',
    jsonCollapseAll: 'Thu gọn tất cả',
    jsonItemCount: _viJsonItemCount,
    networkHistoryTitle: 'Lịch sử API',
    networkHistoryEmpty:
        'Chưa có API call nào. Các call qua Dio sẽ hiện ở đây khi app gọi.',
    networkClear: 'Xóa',
    close: 'Đóng',
    networkButtonLabel: 'Xem network',
    networkButtonSubtitle: _viNetworkButtonSubtitle,
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
  static String _enNetworkCount(int count) =>
      '$count API call(s), newest first · Tap a call for the details';
  static String _viNetworkCount(int count) =>
      '$count API call, mới nhất trước · Chạm để xem chi tiết';
  static String _enNetworkTruncated(int shown, int total) =>
      'Cut: the first $shown of $total characters';
  static String _viNetworkTruncated(int shown, int total) =>
      'Đã cắt: $shown ký tự đầu trong $total ký tự';
  static String _enJsonItemCount(int count) =>
      count == 1 ? '1 item' : '$count items';
  static String _viJsonItemCount(int count) => '$count mục';
  static String _enNetworkButtonSubtitle(int count, int failed) {
    if (count == 0) return 'No API calls yet';
    final calls = count == 1 ? '1 API call' : '$count API calls';
    return failed == 0 ? calls : '$calls · $failed failed';
  }

  static String _viNetworkButtonSubtitle(int count, int failed) {
    if (count == 0) return 'Chưa có API call';
    return failed == 0 ? '$count API call' : '$count API call · $failed lỗi';
  }

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

  /// The header of the API calls recorded by [BugInspectorDioInterceptor].
  final String sectionNetwork;

  /// Below the API calls, for `count` calls.
  final String Function(int count) networkCount;

  /// The status of a call without a response or an error yet.
  final String networkPending;

  /// The header of the method, path and query of a call.
  final String networkRequest;

  /// The header of the status code and timing of a call.
  final String networkResponse;

  /// The button next to a header value that copies it.
  final String copyValue;

  /// The header of the request headers of a call.
  final String networkRequestHeaders;

  /// The header of the request body of a call.
  final String networkRequestBody;

  /// The header of the response headers of a call.
  final String networkResponseHeaders;

  /// The header of the response body of a call.
  final String networkResponseBody;

  /// The header of the error of a failed call.
  final String networkError;

  /// Below a body cut by [BugNetworkRecorder.maxBodyLength]: `shown` of `total` characters.
  final String Function(int shown, int total) networkTruncated;

  /// The button that opens every object and list of the JSON tree.
  final String jsonExpandAll;

  /// The button that closes every object and list of the JSON tree.
  final String jsonCollapseAll;

  /// Next to an object or a list of the JSON tree, for its `count` entries.
  final String Function(int count) jsonItemCount;

  /// The title of [BugNetworkHistoryPage].
  final String networkHistoryTitle;

  /// The text of [BugNetworkHistoryPage] without any call.
  final String networkHistoryEmpty;

  /// The button of [BugNetworkHistoryPage] that removes every recorded call.
  final String networkClear;

  /// The button that closes [BugNetworkHistoryPage].
  final String close;

  /// The toolbar button of [BugInspector] that opens [BugNetworkHistoryPage].
  final String networkButtonLabel;

  /// Below [networkButtonLabel]: `count` kept calls, `failed` of them failed or with a status code of 400 or more.
  final String Function(int count, int failed) networkButtonSubtitle;

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
    String? sectionNetwork,
    String Function(int count)? networkCount,
    String? networkPending,
    String? networkRequest,
    String? networkResponse,
    String? copyValue,
    String? networkRequestHeaders,
    String? networkRequestBody,
    String? networkResponseHeaders,
    String? networkResponseBody,
    String? networkError,
    String Function(int shown, int total)? networkTruncated,
    String? jsonExpandAll,
    String? jsonCollapseAll,
    String Function(int count)? jsonItemCount,
    String? networkHistoryTitle,
    String? networkHistoryEmpty,
    String? networkClear,
    String? close,
    String? networkButtonLabel,
    String Function(int count, int failed)? networkButtonSubtitle,
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
      sectionNetwork: sectionNetwork ?? this.sectionNetwork,
      networkCount: networkCount ?? this.networkCount,
      networkPending: networkPending ?? this.networkPending,
      networkRequest: networkRequest ?? this.networkRequest,
      networkResponse: networkResponse ?? this.networkResponse,
      copyValue: copyValue ?? this.copyValue,
      networkRequestHeaders:
          networkRequestHeaders ?? this.networkRequestHeaders,
      networkRequestBody: networkRequestBody ?? this.networkRequestBody,
      networkResponseHeaders:
          networkResponseHeaders ?? this.networkResponseHeaders,
      networkResponseBody: networkResponseBody ?? this.networkResponseBody,
      networkError: networkError ?? this.networkError,
      networkTruncated: networkTruncated ?? this.networkTruncated,
      jsonExpandAll: jsonExpandAll ?? this.jsonExpandAll,
      jsonCollapseAll: jsonCollapseAll ?? this.jsonCollapseAll,
      jsonItemCount: jsonItemCount ?? this.jsonItemCount,
      networkHistoryTitle: networkHistoryTitle ?? this.networkHistoryTitle,
      networkHistoryEmpty: networkHistoryEmpty ?? this.networkHistoryEmpty,
      networkClear: networkClear ?? this.networkClear,
      close: close ?? this.close,
      networkButtonLabel: networkButtonLabel ?? this.networkButtonLabel,
      networkButtonSubtitle:
          networkButtonSubtitle ?? this.networkButtonSubtitle,
    );
  }
}
