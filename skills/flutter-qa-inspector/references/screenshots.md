# Screenshot và annotation

Đọc khi user cần ảnh đính kèm hoặc flow đánh dấu vùng lỗi; chỉ thêm marker thì không cần xây report/editor UI.

## Chụp trước khi mở form

Public imports cho các snippet: `dart:typed_data`, `package:flutter/material.dart`, `package:flutter_qa_inspector/flutter_qa_inspector.dart`.

Host mặc định tắt selection mode trước callback. Dùng context marker để chụp; hàm chờ frame tiếp theo nên ảnh không còn border và không chứa launcher/overlay riêng của inspector.

```dart
Future<void> captureThenOpenReport(
  BuildContext widgetContext,
  BugWidgetSelection selection,
  Future<void> Function(
    BuildContext context,
    BugWidgetSelection selection,
    BugScreenshot? screenshot,
  ) openReport,
) async {
  final screenshot = await BugInspector.captureScreenshot(widgetContext);
  if (!widgetContext.mounted) return;
  await openReport(widgetContext, selection, screenshot);
}
```

Nối helper vào `onWidgetSelected` với flow mở form của host và return/await future mà helper trả về. `openReport` phải chờ tới khi report route đóng; host ẩn launcher tới khi future callback hoàn tất. Nếu dùng `disableModeOnSelection: false`, gọi `BugInspector.maybeModeCubitOf(widgetContext)?.disable()` trước capture. Không mở report rồi mới chụp, vì report nằm trong nội dung app cũng sẽ lọt vào ảnh.

`captureScreenshot` có `pixelRatio`, `waitForNextFrame` và `statusBar` tùy chọn; xử lý trường hợp trả `null`. `BugScreenshot.capturedAtUtc` riêng với selection vì ảnh chụp frame sau. `pngBytes` là PNG nội dung app; `screenshot.toJson()` chỉ là metadata, không chứa bytes.

System status bar thật không nằm trong ảnh app. Mặc định `statusBar: true` tạo `BugScreenshot.statusBar` khi chụp dưới top safe area trên Android/iOS: kiểu Pixel 8 hoặc Dynamic Island, đồng hồ giờ chụp, pin/sóng/Wi-Fi luôn đầy. Editor và `toAnnotatedPng` vẽ bar giả này, còn raw `pngBytes` chưa có nó. Dùng `statusBar: false` khi muốn bỏ; không coi các icon mô phỏng hoặc style bar là bằng chứng trạng thái mạng/pin hay model thiết bị thực tế.

## Preview và editor

Form sở hữu một `BugScreenshotAnnotationController`, tạo một lần trong lifecycle form và dispose khi form đóng. Dùng cùng controller cho preview và trang editor; không tạo lại trong `build`. Truyền screenshot/selection đã chụp vào form, không đọc lại BLoC sau khi điều hướng để thay payload ban đầu.

```dart
Widget reportPreview({
  required BugScreenshot screenshot,
  required BugWidgetSelection selection,
  required BugScreenshotAnnotationController annotations,
  required VoidCallback onEdit,
}) =>
    GestureDetector(
      onTap: onEdit,
      child: BugScreenshotEditor(
        screenshot: screenshot,
        controller: annotations,
        highlight: selection.bounds,
        readOnly: true,
      ),
    );

Widget reportEditor({
  required BugScreenshot screenshot,
  required BugWidgetSelection selection,
  required BugScreenshotAnnotationController annotations,
}) =>
    BugScreenshotEditor(
      screenshot: screenshot,
      controller: annotations,
      highlight: selection.bounds,
    );
```

Đặt editor tương tác trong page riêng với constraints hữu hạn, ví dụ body của `Scaffold`; editor nhận gesture ngay khi chạm nên kéo trên nó không cuộn form cha. Trong form có scroll, dùng preview `readOnly: true` và mở trang editor từ `onEdit`. Giữ quy tắc back/nested navigator của host.

Editor hỗ trợ draw/move/resize/delete rectangles; pinch zoom/pan với `maxZoom` mặc định 5, `maxZoom: 1` tắt zoom. Ngón thứ hai hủy thao tác rectangle đang làm để chuyển sang zoom. `highlight` là viền nét đứt không chỉnh sửa; controller quản lý annotations và rectangle đang chọn.

## Tọa độ và xuất attachment

| Dữ liệu | Hệ tọa độ |
| --- | --- |
| `selection.bounds`, đối số `highlight` của editor/export | Global logical pixels của app |
| `BugScreenshotAnnotation.rect`, `annotations.toJson()` | Pixel của ảnh (`image_pixels`) |
| `screenshot.toImageRect(selection.bounds)` | Chuyển global logical pixels sang image pixels |

Không convert `selection.bounds` trước khi truyền vào `highlight`; editor/export tự convert. Nếu tạo rectangle bằng code từ bounds, dùng `toImageRect` trước khi đưa vào `BugScreenshotAnnotation`.

```dart
Future<Uint8List> exportReportPng({
  required BugScreenshot screenshot,
  required BugWidgetSelection selection,
  required BugScreenshotAnnotationController annotations,
}) =>
    screenshot.toAnnotatedPng(
      annotations.annotations,
      highlight: selection.bounds,
    );

Map<String, Object?> reportPayload({
  required BugWidgetSelection selection,
  required BugScreenshot screenshot,
  required BugScreenshotAnnotationController annotations,
}) =>
    {
      'inspector': selection.toJson(),
      'screenshot': {
        ...screenshot.toJson(),
        'annotations': annotations.toJson(),
      },
    };
```

Truyền cùng `highlight`, `color`, `strokeWidth`, `highlightColor` ở editor và `toAnnotatedPng` nếu đã custom; nếu không ảnh export có thể khác preview. Không có annotations, highlight và status bar thì export trả PNG gốc. Build thiếu define cũng trả PNG gốc.

Nếu user cần ZIP/share, tham khảo [BugReportBundle của example](../../../flutter_qa_inspector/example/lib/bug_report_bundle.dart) và [BugReportPage](../../../flutter_qa_inspector/example/lib/bug_report_page.dart); đây là app code dùng `archive`/`share_plus`, không phải public API package. Chỉ thêm dependencies/cấu hình platform khi thực sự triển khai flow đó, không bắt chúng thành điều kiện để inspect widget/page.
