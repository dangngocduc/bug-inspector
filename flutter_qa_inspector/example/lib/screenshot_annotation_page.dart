import 'package:flutter/material.dart';
import 'package:flutter_qa_inspector/flutter_qa_inspector.dart';

/// Full-screen editor where the tester marks the screenshot with rectangles.
///
/// Edits go straight to [controller], so closing the page keeps them.
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

  /// Opens the editor above [context]'s navigator.
  static Future<void> open(
    BuildContext context, {
    required BugScreenshot screenshot,
    required BugScreenshotAnnotationController controller,
    Rect? highlight,
  }) {
    return Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        // No back swipe from the left edge, which would steal drawing there.
        fullscreenDialog: true,
        builder: (_) => ScreenshotAnnotationPage(
          screenshot: screenshot,
          controller: controller,
          highlight: highlight,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: const Color(0xFF1C1B1F),
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text('Đánh dấu trên ảnh'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Xong'),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
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
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Text(
                'Kéo trên ảnh để vẽ khung. Chạm vào khung để chọn, kéo để di '
                'chuyển, kéo các góc để đổi kích thước, bấm ✕ để xóa.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: Colors.white70,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
