# Khả năng và giới hạn

Đối chiếu với package `flutter_qa_inspector` version `0.7.0` trong repo này. Khi dùng version khác, kiểm tra lại public API thay vì suy ra từ bảng này.

## Chọn API

| Nhu cầu | API | Hành vi cần biết |
| --- | --- | --- |
| Bật công cụ cho toàn app | `BugInspector` | Registry theo subtree, launcher nổi kéo được, toolbar chọn và callback. Thường đặt trong `MaterialApp.builder` hoặc `MaterialApp.router.builder`. |
| Điều khiển từ menu QA | `InspectModeCubit`, `BugInspector.maybeModeCubitOf` | `enable()`, `disable()`, `toggle()`; accessor trả `null` ngoài host đang bật hoặc khi thiếu define. |
| Chọn một vùng UI | `BugInspectable` | Marker có `id` bắt buộc; `label`, `sourceFile`, `sourceLine` và border tùy chọn. `widgetType` là runtime type của `child`. |
| Chọn toàn màn hình | `BugInspectablePage` | Dùng **Select screen**. Page/tab được vẽ trên cùng thắng; page lồng trong shell thắng page bao ngoài. Dialog/bottom sheet không tự trở thành page. |
| Đọc BLoC/Cubit hiện tại | `BugBlocScope<S>.lazy` | Khai báo instance và serializer, chỉ đọc khi chọn. Bản `BugBlocScope(bloc: ...)` cũng có, nhưng biểu thức đối số vẫn chạy lúc build. |
| Đọc local widget state | `BugInspectableState<T>` | Mixin trên `State<T>`, override `bugSnapshot()`. Chỉ thu những field được khai báo tường minh. |
| Timeline gần thời điểm chọn | `BugStateRecorder`, `BugInspectorBlocObserver` | Queue RAM mặc định 300 records; host lấy 30 giây gần nhất theo `historyWindow`. Observer có `filter` và bỏ qua `InspectModeCubit`. |
| Payload | `BugWidgetSelection`, `BugBlocSnapshot`, `BugWidgetStateSnapshot`, `BugStateRecord` | Có `toJson()`; lỗi capture một snapshot không làm mất những snapshot khác. |
| Chụp nội dung app | `BugInspector.captureScreenshot`, `BugScreenshot` | PNG không gồm launcher/overlay riêng của inspector. Có thể trả `null`; không tự đính kèm vào selection. |
| Bổ sung status bar cho ảnh | `BugStatusBar`, `BugStatusBarStyle` | `captureScreenshot(statusBar: true)` mặc định thêm metadata status bar giả khi chụp dưới top safe area trên Android/iOS. Editor và export vẽ nó; pin/sóng/Wi-Fi là mô phỏng, không phải telemetry. |
| Đánh dấu vùng trên ảnh | `BugScreenshotEditor`, `BugScreenshotAnnotationController`, `BugScreenshotAnnotation` | Vẽ, chọn, kéo, resize, xóa rectangle; pinch zoom/pan, reset zoom; `readOnly` cho preview. Controller do app sở hữu và dispose. |
| Xuất ảnh đã đánh dấu | `BugScreenshot.toAnnotatedPng` | Render highlight và rectangles vào PNG; truyền style giống editor khi có custom style. |
| Hiểu report ZIP được export | Flow `BugReportPage` / `BugReportBundle` của example | Agent đọc ảnh, mô tả và inspector payload theo [bug-reports.md](bug-reports.md); đây là format report của app tích hợp, không phải API export ZIP trong core package. |
| Automation bằng widget key | `BugInspector.launcherKey`, `exitButtonKey`, `pageButtonKey` | Editor có thêm `deleteButtonKey`, `resetZoomButtonKey`. |

Khi inspect mode bật, app bên dưới ngừng nhận pointer; tap chọn không gọi action của widget. Border được vẽ foreground mà không đổi kích thước/padding. Tap ngoài marker giữ mode, trừ khi host bật `selectPageOnEmptyTap`.

## Dữ liệu selection

`selection.toJson()` cung cấp:

- `kind`: `widget` hoặc `page`; `id`, `widgetType`, `capturedAtUtc`.
- `label`, `source.file`, `source.line`, `route.name`: chỉ xuất hiện khi có dữ liệu. Route lấy từ `RouteSettings.name`; source metadata do app truyền, không được tự suy ra từ runtime.
- `bounds`: global logical pixels, gồm `left`, `top`, `width`, `height`, `coordinateUnit: logical_pixels`. Đây là bounding box ngoài, không phải vùng đã trừ clip.
- `blocs`: khi chọn widget, lấy scope ancestors gần trước; khi chọn page, lấy descendant scopes theo tree rồi ancestors. Loại trùng theo identity instance, không theo class.
- `widgetStates`: mọi `State` có mixin trong subtree được chọn theo thứ tự tree, rồi ancestors gần trước. Không đọc field của state không có mixin.
- `stateHistory`: records trong cửa sổ thời gian của recorder, cũ trước. Đây là lịch sử các instance observer ghi nhận, không tự lọc theo `selection.blocs`; đối chiếu bằng `instanceId` hoặc cấu hình observer `filter`.

Snapshot có `captureErrorType` và `state: {}` khi serializer ném lỗi hoặc trả dữ liệu không hợp lệ; lỗi đọc lazy provider còn cho `type`/`instanceId: unknown`. JSON hợp lệ gồm null, bool, string, số hữu hạn, list và map string-key; enum dùng `.name`, DateTime dùng `.toIso8601String()`, Set đổi thành list.

Observer ghi `created`, `closed`, `error` cho BLoC/Cubit; `event`, `transition` cho BLoC; `change` cho Cubit. Records lưu type names, không lưu state/event values, message hay stack trace đầy đủ. `instanceId` chỉ có ý nghĩa trong cùng phiên chạy.

## Giới hạn và phạm vi của example

- Chỉ những subtree được đánh dấu mới chọn được; không có chế độ tự biến toàn bộ widget tree thành inspectable.
- Không có reflection đọc mọi field của `State`, tự nhận biết các BLoC widget dùng, network recorder hoặc timeline giá trị đầy đủ. Cần khai báo scope/mixin và serializer.
- Registry, history và annotations không tự persist ra disk hay gửi backend. Package không cung cấp bug-report form, dịch vụ upload hoặc tạo issue.
- `BugReportPage`, `ScreenshotAnnotationPage` và `BugReportBundle` thuộc app example. ZIP/share dùng dependencies `archive`, `share_plus` của example, không được export bởi `flutter_qa_inspector`. Chỉ tham khảo/tích hợp phần này khi user cần flow gửi báo lỗi.
- Runtime type names có thể bị rút gọn khi `--obfuscate`; dùng stable marker ID để truy nguồn.
- `onWidgetSelected` nhận callback trả `FutureOr<void>`. Return/await future của report route để launcher ẩn cho tới khi report đóng; callback không return future thì launcher vẫn hiện.
- Khi thiếu compile-time define, wrappers trả `child`, accessor/capture trả `null`, observer không ghi, editor hiện hộp rỗng. Vẫn có widget elements của wrappers; không mô tả là hoàn toàn không có overhead hoặc tự chứng nhận số đo binary của host app.

## Nguồn chi tiết

- [Host và compile-time gate](../../../flutter_qa_inspector/lib/src/bug_inspector.dart).
- [Selection models và JSON validation](../../../flutter_qa_inspector/lib/src/models.dart).
- [Scope collection](../../../flutter_qa_inspector/lib/src/bug_bloc_scope.dart) và [local State collection](../../../flutter_qa_inspector/lib/src/bug_inspectable_state.dart).
- [Recorder và observer](../../../flutter_qa_inspector/lib/src/bug_state_recorder.dart).
- [Screenshot](../../../flutter_qa_inspector/lib/src/bug_screenshot.dart) và [editor/controller](../../../flutter_qa_inspector/lib/src/bug_screenshot_editor.dart).
- [Status bar mô phỏng](../../../flutter_qa_inspector/lib/src/bug_status_bar.dart).
