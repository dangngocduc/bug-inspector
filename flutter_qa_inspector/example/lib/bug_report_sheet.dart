import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_qa_inspector/flutter_qa_inspector.dart';

import 'screenshot_annotation_page.dart';

/// A demo bug report form. A real app would send [report] to its tracker.
class BugReportSheet extends StatefulWidget {
  const BugReportSheet({super.key, required this.selection, this.screenshot});

  final BugWidgetSelection selection;
  final BugScreenshot? screenshot;

  @override
  State<BugReportSheet> createState() => _BugReportSheetState();
}

class _BugReportSheetState extends State<BugReportSheet> {
  final _description = TextEditingController();

  /// The rectangles the tester drew on the screenshot.
  final _annotations = BugScreenshotAnnotationController();

  @override
  void dispose() {
    _description.dispose();
    _annotations.dispose();
    super.dispose();
  }

  Map<String, Object?> get report => {
        'description': _description.text,
        'inspector': widget.selection.toJson(),
        if (widget.screenshot != null)
          'screenshot': {
            ...widget.screenshot!.toJson(),
            'annotations': _annotations.toJson(),
          },
      };

  /// The selected widget, outlined on the screenshot. A whole screen is not
  /// outlined: it is the whole image.
  Rect? get _highlight => widget.selection.kind == BugSelectionKind.widget
      ? widget.selection.bounds
      : null;

  void _annotate() {
    final screenshot = widget.screenshot;
    if (screenshot == null) return;
    ScreenshotAnnotationPage.open(
      context,
      screenshot: screenshot,
      controller: _annotations,
      highlight: _highlight,
    );
  }

  Future<void> _send() async {
    final screenshot = widget.screenshot;
    // A real app uploads this image, with the tester's rectangles drawn on
    // it, together with [report].
    final png = screenshot == null
        ? null
        : await screenshot.toAnnotatedPng(_annotations.annotations);
    debugPrint('Bug report: ${jsonEncode(report)}, '
        'screenshot: ${png?.length ?? 0} bytes');
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final selection = widget.selection;
    final screenshot = widget.screenshot;
    final payload =
        const JsonEncoder.withIndent('  ').convert(selection.toJson());
    final theme = Theme.of(context);

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * 0.85,
          ),
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            children: [
              Text('Báo lỗi', style: theme.textTheme.titleLarge),
              const SizedBox(height: 4),
              Text(
                '${selection.kind == BugSelectionKind.page ? 'Màn hình' : 'Widget'}: '
                '${selection.id} · ${selection.widgetType}',
                style: theme.textTheme.bodyMedium,
              ),
              const SizedBox(height: 16),
              if (screenshot != null) ...[
                _ScreenshotPreview(
                  screenshot: screenshot,
                  annotations: _annotations,
                  highlight: _highlight,
                  onTap: _annotate,
                ),
                const SizedBox(height: 8),
                ListenableBuilder(
                  listenable: _annotations,
                  builder: (context, _) {
                    final count = _annotations.annotations.length;
                    return Text(
                      count == 0
                          ? 'Chạm vào ảnh để đánh dấu vùng lỗi'
                          : 'Đã đánh dấu $count vùng · Chạm vào ảnh để sửa',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    );
                  },
                ),
                const SizedBox(height: 16),
              ],
              TextField(
                controller: _description,
                minLines: 2,
                maxLines: 5,
                decoration: const InputDecoration(
                  labelText: 'Mô tả lỗi',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              Text('Payload', style: theme.textTheme.titleSmall),
              const SizedBox(height: 8),
              DecoratedBox(
                decoration: BoxDecoration(
                  color: theme.colorScheme.onSurface.withAlpha(15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: SelectableText(
                    payload,
                    style:
                        const TextStyle(fontFamily: 'monospace', fontSize: 12),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => Clipboard.setData(
                        ClipboardData(text: jsonEncode(report)),
                      ),
                      icon: const Icon(Icons.copy),
                      label: const Text('Sao chép JSON'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      onPressed: _send,
                      child: const Text('Gửi'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
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
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: BugScreenshotEditor(
            screenshot: screenshot,
            controller: annotations,
            highlight: highlight,
            readOnly: true,
          ),
        ),
      ),
    );
  }
}
