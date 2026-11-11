import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_qa_inspector/flutter_qa_inspector.dart';

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

  @override
  void dispose() {
    _description.dispose();
    super.dispose();
  }

  Map<String, Object?> get report => {
        'description': _description.text,
        'inspector': widget.selection.toJson(),
        if (widget.screenshot != null)
          'screenshot': widget.screenshot!.toJson(),
      };

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
                  highlight: selection.bounds,
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
                      onPressed: () => Navigator.of(context).pop(),
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

/// Shows the screenshot with the selected bounds outlined.
class _ScreenshotPreview extends StatelessWidget {
  const _ScreenshotPreview({required this.screenshot, required this.highlight});

  final BugScreenshot screenshot;
  final Rect highlight;

  @override
  Widget build(BuildContext context) {
    final imageRect = screenshot.toImageRect(highlight);
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxHeight: 280),
        child: AspectRatio(
          aspectRatio: screenshot.width / screenshot.height,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final scale = constraints.maxWidth / screenshot.width;
              return Stack(
                fit: StackFit.expand,
                children: [
                  Image.memory(screenshot.pngBytes, fit: BoxFit.fill),
                  Positioned.fromRect(
                    rect: Rect.fromLTWH(
                      imageRect.left * scale,
                      imageRect.top * scale,
                      imageRect.width * scale,
                      imageRect.height * scale,
                    ),
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.red, width: 2),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}
