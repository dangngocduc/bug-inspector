import 'package:flutter/cupertino.dart';
import 'package:flutter_qa_inspector/flutter_qa_inspector.dart';

/// Full-screen editor where the tester marks the screenshot with rectangles.
///
/// A page of the `BugReportPage` navigator: the report form opens it above
/// itself, and closing it goes back to the form. Edits go straight to
/// [controller], so closing the page keeps them. The page is always dark,
/// like the photo editors of iOS, so the screenshot stands out.
class ScreenshotAnnotationPage extends StatelessWidget {
  const ScreenshotAnnotationPage({
    super.key,
    required this.screenshot,
    required this.controller,
    this.highlight,
  });

  final BugScreenshot screenshot;
  final BugScreenshotAnnotationController controller;

  /// The selected widget, outlined but not editable.
  final Rect? highlight;

  static const _theme = CupertinoThemeData(brightness: Brightness.dark);

  /// Opens the editor in [context]'s navigator. From the report form, that is
  /// the report's own navigator, so the editor stays inside the report.
  static Future<void> open(
    BuildContext context, {
    required BugScreenshot screenshot,
    required BugScreenshotAnnotationController controller,
    Rect? highlight,
  }) {
    return Navigator.of(context).push<void>(
      CupertinoPageRoute<void>(
        // Slides up from the bottom, with no back swipe from the left edge,
        // which would steal drawing there.
        fullscreenDialog: true,
        builder: (_) => ScreenshotAnnotationPage(
          screenshot: screenshot,
          controller: controller,
          highlight: highlight,
        ),
      ),
    );
  }

  /// Removes every rectangle, after asking.
  Future<void> _confirmClear(BuildContext context) async {
    final clear = await showCupertinoModalPopup<bool>(
      context: context,
      // The popup is built in the overlay of the navigator, which does not
      // see the dark theme of this page.
      builder: (context) => CupertinoTheme(
        data: _theme,
        child: CupertinoActionSheet(
          title: const Text('Xóa tất cả các khung?'),
          actions: [
            CupertinoActionSheetAction(
              isDestructiveAction: true,
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Xóa tất cả'),
            ),
          ],
          cancelButton: CupertinoActionSheetAction(
            isDefaultAction: true,
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Hủy'),
          ),
        ),
      ),
    );
    if (clear == true) controller.clear();
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoTheme(
      data: _theme,
      child: Builder(
        builder: (context) => DefaultTextStyle(
          style: CupertinoTheme.of(context).textTheme.textStyle,
          child: CupertinoPageScaffold(
            backgroundColor: CupertinoColors.black,
            navigationBar: CupertinoNavigationBar(
              automaticallyImplyLeading: false,
              leading: ListenableBuilder(
                listenable: controller,
                builder: (context, _) => CupertinoButton(
                  padding: EdgeInsets.zero,
                  onPressed: controller.annotations.isEmpty
                      ? null
                      : () => _confirmClear(context),
                  child: const Text('Xóa hết'),
                ),
              ),
              middle: const Text('Đánh dấu trên ảnh'),
              trailing: CupertinoButton(
                padding: EdgeInsets.zero,
                onPressed: () => Navigator.of(context).pop(),
                child: const Text(
                  'Xong',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            ),
            // The navigation bar is translucent: the safe area keeps the
            // editor below it.
            child: SafeArea(
              child: Column(
                children: [
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Center(
                        child: BugScreenshotEditor(
                          screenshot: screenshot,
                          controller: controller,
                          highlight: highlight,
                          deleteButtonLabel: 'Xóa khung',
                          resetZoomButtonLabel: 'Về kích thước vừa màn hình',
                        ),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 0, 24, 12),
                    child: Text(
                      'Kéo trên ảnh để vẽ khung. Chạm vào khung để chọn, kéo '
                      'để di chuyển, kéo các góc để đổi kích thước, bấm ✕ để '
                      'xóa. Dùng hai ngón tay để phóng to.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 13,
                        color:
                            CupertinoColors.secondaryLabel.resolveFrom(context),
                      ),
                    ),
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
