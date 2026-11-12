part of '../../flutter_qa_inspector.dart';

/// The full screen page where the tester draws rectangles on the screenshot.
///
/// It opens in the navigator of [BugReportPage], above the form. Edits go
/// straight to [controller], so closing the page keeps the rectangles. The
/// page is always dark, so the screenshot stands out.
class _ScreenshotAnnotationPage extends StatelessWidget {
  const _ScreenshotAnnotationPage({
    required this.screenshot,
    required this.controller,
    required this.strings,
    this.highlight,
  });

  final BugScreenshot screenshot;
  final BugScreenshotAnnotationController controller;
  final BugReportStrings strings;

  /// The selected widget, outlined but not editable.
  final Rect? highlight;

  static const String routeName = '${BugReportPage.routeName}/annotate';

  static const _theme = CupertinoThemeData(brightness: Brightness.dark);

  static Future<void> open(
    BuildContext context, {
    required BugScreenshot screenshot,
    required BugScreenshotAnnotationController controller,
    required BugReportStrings strings,
    Rect? highlight,
  }) {
    return Navigator.of(context).push<void>(
      CupertinoPageRoute<void>(
        // Slides up from the bottom, with no back swipe from the left edge,
        // which would take the strokes of the tester.
        fullscreenDialog: true,
        settings: const RouteSettings(name: routeName),
        builder: (_) => _ScreenshotAnnotationPage(
          screenshot: screenshot,
          controller: controller,
          strings: strings,
          highlight: highlight,
        ),
      ),
    );
  }

  Future<void> _confirmClear(BuildContext context) async {
    final clear = await showCupertinoModalPopup<bool>(
      context: context,
      // The popup is built in the overlay of the navigator, which does not
      // see the dark theme of the page.
      builder: (context) => CupertinoTheme(
        data: _theme,
        child: CupertinoActionSheet(
          title: Text(strings.annotateClearAllTitle),
          actions: [
            CupertinoActionSheetAction(
              isDestructiveAction: true,
              onPressed: () => Navigator.of(context).pop(true),
              child: Text(strings.annotateClearAllConfirm),
            ),
          ],
          cancelButton: CupertinoActionSheetAction(
            isDefaultAction: true,
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(strings.cancel),
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
                  child: Text(strings.annotateClearAll),
                ),
              ),
              middle: Text(strings.annotateTitle),
              trailing: CupertinoButton(
                padding: EdgeInsets.zero,
                onPressed: () => Navigator.of(context).pop(),
                child: Text(
                  strings.annotateDone,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            ),
            // The navigation bar is translucent: the SafeArea keeps the
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
                          deleteButtonLabel: strings.annotateDeleteBox,
                          resetZoomButtonLabel: strings.annotateResetZoom,
                        ),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
                    child: Text(
                      strings.annotateInstructions,
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
