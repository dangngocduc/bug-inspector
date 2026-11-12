import 'dart:async';
import 'dart:convert';

import 'package:flutter/cupertino.dart';
// The only Material widget of the report: Cupertino has no selectable text.
import 'package:flutter/material.dart' show SelectableText;
import 'package:flutter/services.dart';
import 'package:flutter_qa_inspector/flutter_qa_inspector.dart';
import 'package:share_plus/share_plus.dart';

import 'bug_report_bundle.dart';
import 'screenshot_annotation_page.dart';

/// A demo bug report, presented full screen above the app like an iOS modal.
///
/// The page has its own [Navigator]. The report form is its first page, and
/// [ScreenshotAnnotationPage] opens above the form in that navigator, so the
/// app's navigator only sees one route for the whole report. The back button
/// and the back gesture close the pages of the report's navigator first, then
/// the report itself. Leaving a form that has a description or rectangles
/// asks first.
///
/// The report is styled with Cupertino widgets and its own
/// [CupertinoThemeData], so it looks like an iOS sheet whatever the theme of
/// the app, and follows the light or dark mode of the device.
class BugReportPage extends StatefulWidget {
  const BugReportPage({
    super.key,
    required this.selection,
    this.screenshot,
    this.share,
  });

  /// The name of the route that [open] pushes.
  static const String routeName = '/bug-report';

  /// The theme of the report: not based on the Material theme of the app,
  /// system colors, and the brightness of the device.
  static const CupertinoThemeData theme = CupertinoThemeData();

  final BugWidgetSelection selection;
  final BugScreenshot? screenshot;

  /// Opens the share sheet when the tester sends the report.
  /// [SharePlus.share] when `null`.
  final BugReportShare? share;

  /// Opens the report on the root navigator, so it covers the whole app even
  /// when the selected widget is inside a nested navigator.
  static Future<void> open(
    BuildContext context, {
    required BugWidgetSelection selection,
    BugScreenshot? screenshot,
    BugReportShare? share,
  }) {
    return Navigator.of(context, rootNavigator: true).push<void>(
      CupertinoPageRoute<void>(
        // Slides up from the bottom, with no back swipe from the left edge:
        // the report closes with its cancel button, the back button or the
        // back gesture.
        fullscreenDialog: true,
        settings: const RouteSettings(name: routeName),
        builder: (_) => BugReportPage(
          selection: selection,
          screenshot: screenshot,
          share: share,
        ),
      ),
    );
  }

  @override
  State<BugReportPage> createState() => _BugReportPageState();
}

class _BugReportPageState extends State<BugReportPage> {
  final _navigatorKey = GlobalKey<NavigatorState>();

  /// Closes the report with every page of its navigator. [context] is above
  /// the report's navigator, so this pops the route that holds the report.
  void _close() => Navigator.of(context).pop();

  @override
  Widget build(BuildContext context) {
    return CupertinoTheme(
      data: BugReportPage.theme,
      child: Builder(
        // A MaterialApp gives the text without a Material ancestor an error
        // style. The pages of the report have no Material, so they use the
        // Cupertino text style.
        builder: (context) => DefaultTextStyle(
          style: CupertinoTheme.of(context).textTheme.textStyle,
          // While the report's navigator has a page above the form, or the
          // form asks before closing, a back gesture goes to that navigator
          // instead of closing the whole report.
          child: NavigatorPopHandler<void>(
            onPopWithResult: (_) => _navigatorKey.currentState?.maybePop(),
            child: Navigator(
              key: _navigatorKey,
              onGenerateRoute: (settings) => CupertinoPageRoute<void>(
                settings: settings,
                builder: (_) => _BugReportForm(
                  selection: widget.selection,
                  screenshot: widget.screenshot,
                  share: widget.share ?? SharePlus.instance.share,
                  onClose: _close,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The first page of the report's navigator. Sending the report zips the
/// screenshot, the description and the inspector JSON, then shares the
/// screenshot, the zip and the description, see [BugReportBundle].
class _BugReportForm extends StatefulWidget {
  const _BugReportForm({
    required this.selection,
    required this.screenshot,
    required this.share,
    required this.onClose,
  });

  final BugWidgetSelection selection;
  final BugScreenshot? screenshot;
  final BugReportShare share;

  /// Closes the whole report.
  final VoidCallback onClose;

  @override
  State<_BugReportForm> createState() => _BugReportFormState();
}

class _BugReportFormState extends State<_BugReportForm> {
  final _description = TextEditingController();

  /// The rectangles the tester drew on the screenshot.
  final _annotations = BugScreenshotAnnotationController();

  /// Whether the report is being zipped or the share sheet is open.
  var _sending = false;

  /// Whether the copy button shows that the JSON was copied.
  var _copied = false;
  Timer? _copiedTimer;

  @override
  void dispose() {
    _copiedTimer?.cancel();
    _description.dispose();
    _annotations.dispose();
    super.dispose();
  }

  /// Whether closing the form would lose what the tester wrote or drew.
  bool get _hasChanges =>
      _description.text.trim().isNotEmpty ||
      _annotations.annotations.isNotEmpty;

  /// The content of [BugReportBundle.inspectorFileName].
  Map<String, Object?> get _inspectorJson => {
        'inspector': widget.selection.toJson(),
        if (widget.screenshot != null)
          'screenshot': {
            ...widget.screenshot!.toJson(),
            'annotations': _annotations.toJson(),
          },
      };

  Map<String, Object?> get report => {
        'description': _description.text,
        ..._inspectorJson,
      };

  /// The selected widget, outlined on the screenshot. A whole screen is not
  /// outlined: it is the whole image.
  Rect? get _highlight => widget.selection.kind == BugSelectionKind.widget
      ? widget.selection.bounds
      : null;

  /// Closes the report, after asking when the tester would lose their
  /// description or rectangles.
  Future<void> _cancel() async {
    if (_sending) return;
    if (!_hasChanges) {
      widget.onClose();
      return;
    }
    final discard = await showCupertinoModalPopup<bool>(
      context: context,
      // The popup is built in the overlay of the app's navigator, which does
      // not see the theme of the report.
      builder: (context) => CupertinoTheme(
        data: BugReportPage.theme,
        child: CupertinoActionSheet(
          title: const Text('Bỏ báo lỗi này?'),
          message: const Text('Mô tả và các vùng đã đánh dấu sẽ bị xóa.'),
          actions: [
            CupertinoActionSheetAction(
              isDestructiveAction: true,
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Bỏ báo lỗi'),
            ),
          ],
          cancelButton: CupertinoActionSheetAction(
            isDefaultAction: true,
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Tiếp tục chỉnh sửa'),
          ),
        ),
      ),
    );
    if (discard == true && mounted) widget.onClose();
  }

  /// Opens the editor in the report's navigator, above this form.
  void _annotate() {
    final screenshot = widget.screenshot;
    if (screenshot == null) return;
    FocusScope.of(context).unfocus();
    ScreenshotAnnotationPage.open(
      context,
      screenshot: screenshot,
      controller: _annotations,
      highlight: _highlight,
    );
  }

  Future<void> _copyJson() async {
    await Clipboard.setData(ClipboardData(text: jsonEncode(report)));
    if (!mounted) return;
    HapticFeedback.lightImpact();
    setState(() => _copied = true);
    _copiedTimer?.cancel();
    _copiedTimer = Timer(const Duration(seconds: 2), () {
      if (mounted) setState(() => _copied = false);
    });
  }

  /// Zips the report and opens the share sheet next to [origin], the send
  /// button in global logical pixels.
  Future<void> _send(Rect? origin) async {
    if (_sending) return;
    FocusScope.of(context).unfocus();
    setState(() => _sending = true);
    try {
      final screenshot = widget.screenshot;
      // The image the tester sees: the selected widget outlined and their
      // rectangles drawn on it.
      final png = screenshot == null
          ? null
          : await screenshot.toAnnotatedPng(
              _annotations.annotations,
              highlight: _highlight,
            );
      final bundle = BugReportBundle(
        name: BugReportBundle.nameFor(
          widget.selection.id,
          widget.selection.capturedAtUtc,
        ),
        description: _description.text,
        inspectorJson: _inspectorJson,
        screenshotPng: png,
      );
      final result = await widget.share(
        bundle.toShareParams(sharePositionOrigin: origin),
      );
      // Dismissing the share sheet keeps the report, to share it again.
      if (mounted && result.status != ShareResultStatus.dismissed) {
        widget.onClose();
      }
    } catch (error) {
      if (!mounted) return;
      unawaited(
        showCupertinoDialog<void>(
          context: context,
          builder: (context) => CupertinoTheme(
            data: BugReportPage.theme,
            child: CupertinoAlertDialog(
              title: const Text('Không chia sẻ được báo lỗi'),
              content: Text('$error'),
              actions: [
                CupertinoDialogAction(
                  isDefaultAction: true,
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('OK'),
                ),
              ],
            ),
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final selection = widget.selection;
    final screenshot = widget.screenshot;
    final payload =
        const JsonEncoder.withIndent('  ').convert(selection.toJson());
    final isPage = selection.kind == BugSelectionKind.page;

    final scaffold = CupertinoPageScaffold(
      backgroundColor: CupertinoColors.systemGroupedBackground,
      navigationBar: CupertinoNavigationBar(
        // The form is the first page of the report's navigator, so there is
        // nothing to go back to there: this button closes the whole report.
        leading: CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: _sending ? null : _cancel,
          child: const Text('Hủy'),
        ),
        middle: const Text('Báo lỗi'),
        trailing: _sending
            ? const CupertinoActivityIndicator()
            // The builder's context is the button: iPad anchors the share
            // sheet to it.
            : Builder(
                builder: (buttonContext) => CupertinoButton(
                  padding: EdgeInsets.zero,
                  onPressed: () => _send(_globalRect(buttonContext)),
                  child: const Text(
                    'Gửi',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ),
      ),
      // The list scrolls under the translucent navigation bar: it gets the
      // height of the bar and the safe areas as padding.
      child: ListView(
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        children: [
          CupertinoListSection.insetGrouped(
            header: const _SectionHeader('Đối tượng'),
            children: [
              CupertinoListTile(
                leading: Icon(
                  isPage
                      ? CupertinoIcons.device_phone_portrait
                      : CupertinoIcons.square_on_square,
                ),
                title: Text(selection.label ?? selection.id),
                subtitle: Text(
                  selection.label == null
                      ? selection.widgetType
                      : '${selection.id} · ${selection.widgetType}',
                ),
                additionalInfo: Text(isPage ? 'Màn hình' : 'Widget'),
              ),
            ],
          ),
          if (screenshot != null)
            CupertinoListSection.insetGrouped(
              header: const _SectionHeader('Ảnh chụp màn hình'),
              footer: ListenableBuilder(
                listenable: _annotations,
                builder: (context, _) {
                  final count = _annotations.annotations.length;
                  return _SectionFooter(
                    count == 0
                        ? 'Chạm vào ảnh để đánh dấu vùng lỗi'
                        : 'Đã đánh dấu $count vùng · Chạm vào ảnh để sửa',
                  );
                },
              ),
              children: [
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: _ScreenshotPreview(
                    screenshot: screenshot,
                    annotations: _annotations,
                    highlight: _highlight,
                    onTap: _annotate,
                  ),
                ),
              ],
            ),
          CupertinoListSection.insetGrouped(
            header: const _SectionHeader('Mô tả'),
            children: [
              CupertinoTextField.borderless(
                controller: _description,
                placeholder: 'Lỗi gì xảy ra, và các bước để tái hiện',
                minLines: 3,
                maxLines: 8,
                textCapitalization: TextCapitalization.sentences,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                onTapOutside: (_) => FocusScope.of(context).unfocus(),
              ),
            ],
          ),
          CupertinoListSection.insetGrouped(
            header: Row(
              children: [
                const Expanded(child: _SectionHeader('Payload')),
                CupertinoButton(
                  sizeStyle: CupertinoButtonSize.small,
                  padding: EdgeInsets.zero,
                  minimumSize: Size.zero,
                  onPressed: _copyJson,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _copied
                            ? CupertinoIcons.checkmark_alt
                            : CupertinoIcons.doc_on_doc,
                        size: 16,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        _copied ? 'Đã sao chép' : 'Sao chép JSON',
                        style: const TextStyle(fontSize: 13),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: SelectableText(
                  payload,
                  style: TextStyle(
                    fontFamily: 'Menlo',
                    fontFamilyFallback: const ['Courier', 'monospace'],
                    fontSize: 12,
                    height: 1.4,
                    color: CupertinoColors.label.resolveFrom(context),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );

    // On the form, the back button and the back gesture are the cancel
    // button: they ask before losing the description or the rectangles.
    return ListenableBuilder(
      listenable: Listenable.merge([_description, _annotations]),
      child: scaffold,
      builder: (context, child) => PopScope<void>(
        canPop: !_sending && !_hasChanges,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop) _cancel();
        },
        child: child!,
      ),
    );
  }
}

/// The title above a group of the form, in the small grey capitals of the
/// grouped lists of iOS.
class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text.toUpperCase(),
      style: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w400,
        letterSpacing: -0.08,
        color: CupertinoColors.secondaryLabel.resolveFrom(context),
      ),
    );
  }
}

/// The hint below a group of the form.
class _SectionFooter extends StatelessWidget {
  const _SectionFooter(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(
        fontSize: 13,
        letterSpacing: -0.08,
        color: CupertinoColors.secondaryLabel.resolveFrom(context),
      ),
    );
  }
}

/// Where the widget of [context] is on screen, in global logical pixels.
Rect? _globalRect(BuildContext context) {
  final box = context.findRenderObject();
  if (box is! RenderBox || !box.hasSize) return null;
  return box.localToGlobal(Offset.zero) & box.size;
}

/// Shows the screenshot with the selected widget and the tester's
/// rectangles. Tapping the image opens the editor.
class _ScreenshotPreview extends StatelessWidget {
  const _ScreenshotPreview({
    required this.screenshot,
    required this.annotations,
    required this.highlight,
    required this.onTap,
  });

  final BugScreenshot screenshot;
  final BugScreenshotAnnotationController annotations;
  final Rect? highlight;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxHeight: 280),
        child: Semantics(
          container: true,
          button: true,
          label: 'Đánh dấu trên ảnh',
          // The badge only repeats the label.
          excludeSemantics: true,
          onTap: onTap,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onTap,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Stack(
                children: [
                  BugScreenshotEditor(
                    screenshot: screenshot,
                    controller: annotations,
                    highlight: highlight,
                    readOnly: true,
                  ),
                  // Shows that the image opens the editor, like the markup
                  // button of iOS.
                  const Positioned(
                    right: 8,
                    bottom: 8,
                    child: _MarkupBadge(),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _MarkupBadge extends StatelessWidget {
  const _MarkupBadge();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const ShapeDecoration(
        color: Color(0xB3000000),
        shape: StadiumBorder(),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 4, 10, 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              CupertinoIcons.pencil_outline,
              size: 14,
              color: CupertinoColors.white,
            ),
            SizedBox(width: 4),
            Text(
              'Đánh dấu',
              style: TextStyle(
                color: CupertinoColors.white,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
