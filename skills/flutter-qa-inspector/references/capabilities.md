# Khả năng và giới hạn

Đối chiếu với package `flutter_qa_inspector` version `0.9.0` trong repo này. Khi dùng version khác, kiểm tra lại public API thay vì suy ra từ bảng này.

## Chọn API

| Nhu cầu | API | Hành vi cần biết |
| --- | --- | --- |
| Tích hợp nhanh có form báo lỗi | `FlutterQaInspector.install`, `FlutterQaInspector.wrap` / `.builder`, `FlutterQaInspector.recorder` | `install` cài observer timeline một lần; `wrap` dựng host và mở `BugReportPage` cho mỗi selection. Thiếu define: `install` không làm gì, `wrap` trả `child`. Xem [integration.md](integration.md). |
| Form báo lỗi có sẵn | `BugReportPage`, `BugReportPage.open` | Cupertino, theme riêng, `Navigator` riêng trên root navigator (`/qa-bug-report`): target, preview + trang vẽ full-screen, mô tả, JSON + Copy JSON, Send. Hỏi trước khi bỏ form có thay đổi; share bị dismiss thì giữ form. |
| Đóng gói/gửi report | `BugReportBundle`, `BugReportShare` | ZIP `screenshot.png`, `description.txt`, `inspector.json`; `nameFor`, `toZip()`, `toShareParams()`. `share:` tùy chỉnh để upload/tạo ticket thay share sheet. |
| Chuỗi hiển thị | `BugReportStrings` (`en`, `vi`, `of`, `copyWith`), `BugReportStringsBuilder` | Chuỗi cho toolbar, form, editor. `of` chọn `vi` theo locale, mặc định `en`. |
| Bật công cụ cho toàn app (tùy chỉnh) | `BugInspector` | Registry theo subtree, launcher nổi kéo được, toolbar chọn và callback. Thường đặt trong `MaterialApp.builder` hoặc `MaterialApp.router.builder`. |
| Điều khiển từ menu QA | `InspectModeCubit`, `BugInspector.maybeModeCubitOf` | `enable()`, `disable()`, `toggle()`; accessor trả `null` ngoài host đang bật hoặc khi thiếu define. |
| Chọn một vùng UI | `BugInspectable` | Marker có `id` bắt buộc; `label`, `sourceFile`, `sourceLine` và border tùy chọn. Selection mô tả `child`: `widgetType` là runtime type của `child`, `widgetState` là params của `child`. |
| Chọn toàn màn hình | `BugInspectablePage`, `BugInspectablePage.route` | `.route(settings:)` lấy `id`/`label` từ tên route (`unnamed_route` khi không tên). Dùng **Select screen**. Page/tab được vẽ trên cùng thắng; page lồng trong shell thắng page bao ngoài. Dialog/bottom sheet không tự trở thành page. |
| Đọc BLoC/Cubit hiện tại | `BugBlocScope<S>.lazy` | Khai báo instance và serializer, chỉ đọc khi chọn. Bản `BugBlocScope(bloc: ...)` cũng có, nhưng biểu thức đối số vẫn chạy lúc build. |
| Đọc params của widget được chọn | `BugInspectableWidget` | Mixin trên class widget (`StatelessWidget`/`StatefulWidget`) làm `child` trực tiếp của marker, override `Map<String, Object?> bugSnapshot()`. Chỉ thu params khai báo tường minh, hoạt động mọi build mode. Không đọc field của `State`, widget sâu hơn trong `child` hay phía trên marker. `BugInspectableState` đã bỏ từ `0.9.0`. |
| Timeline gần thời điểm chọn | `BugStateRecorder`, `BugInspectorBlocObserver` | Queue RAM mặc định 300 records; host lấy 30 giây gần nhất theo `historyWindow`. Observer có `filter` và bỏ qua `InspectModeCubit`. |
| Payload | `BugWidgetSelection`, `BugBlocSnapshot`, `BugStateRecord` | Có `toJson()`; lỗi capture một snapshot (BLoC hoặc `widgetState`) không làm mất những phần khác. |
| Chụp nội dung app | `BugInspector.captureScreenshot`, `BugScreenshot` | PNG không gồm launcher/overlay riêng của inspector. Có thể trả `null`; không tự đính kèm vào selection. |
| Bổ sung status bar cho ảnh | `BugStatusBar`, `BugStatusBarStyle` | `captureScreenshot(statusBar: true)` mặc định thêm metadata status bar giả khi chụp dưới top safe area trên Android/iOS. Editor và export vẽ nó; pin/sóng/Wi-Fi là mô phỏng, không phải telemetry. |
| Đánh dấu vùng trên ảnh | `BugScreenshotEditor`, `BugScreenshotAnnotationController`, `BugScreenshotAnnotation` | Vẽ, chọn, kéo, resize, xóa rectangle; pinch zoom/pan, reset zoom; `readOnly` cho preview. Controller do app sở hữu và dispose. |
| Xuất ảnh đã đánh dấu | `BugScreenshot.toAnnotatedPng` | Render highlight và rectangles vào PNG; truyền style giống editor khi có custom style. |
| Hiểu report ZIP được export | `BugReportPage` / `BugReportBundle` | Agent đọc ảnh, mô tả và inspector payload theo [bug-reports.md](bug-reports.md). Host có form riêng có thể xuất format khác. |
| Automation bằng widget key | `BugInspector.launcherKey`, `exitButtonKey`, `pageButtonKey` | Editor có thêm `deleteButtonKey`, `resetZoomButtonKey`. |

Khi inspect mode bật, app bên dưới ngừng nhận pointer; tap chọn không gọi action của widget. Border được vẽ foreground mà không đổi kích thước/padding. Tap ngoài marker giữ mode, trừ khi host bật `selectPageOnEmptyTap`.

## Dữ liệu selection

`selection.toJson()` cung cấp:

- `kind`: `widget` hoặc `page`; `id`, `widgetType`, `widgetState`, `capturedAtUtc`.
- `widgetType` và `widgetState` cùng mô tả `child` trực tiếp của `BugInspectable`/`BugInspectablePage`: type và params từ `BugInspectableWidget.bugSnapshot()`. `widgetState` luôn có mặt, là `{}` khi class của `child` không dùng mixin (kể cả widget Flutter như `Text`, `FilledButton`) hoặc khi capture lỗi; khi lỗi có thêm `widgetStateCaptureErrorType`. Không dùng Diagnostics/`debugFillProperties` (rỗng ngoài debug build).
- `label`, `source.file`, `source.line`, `route.name`: chỉ xuất hiện khi có dữ liệu. Route lấy từ `RouteSettings.name`; source metadata do app truyền, không được tự suy ra từ runtime.
- `bounds`: global logical pixels, gồm `left`, `top`, `width`, `height`, `coordinateUnit: logical_pixels`. Đây là bounding box ngoài, không phải vùng đã trừ clip.
- `blocs`: khi chọn widget, lấy scope ancestors gần trước; khi chọn page, lấy descendant scopes theo tree rồi ancestors. Loại trùng theo identity instance, không theo class.
- `stateHistory`: records trong cửa sổ thời gian của recorder, cũ trước. Đây là lịch sử các instance observer ghi nhận, không tự lọc theo `selection.blocs`; đối chiếu bằng `instanceId` hoặc cấu hình observer `filter`.

BLoC snapshot có `captureErrorType` và `state: {}` khi serializer ném lỗi hoặc trả dữ liệu không hợp lệ; lỗi đọc lazy provider còn cho `type`/`instanceId: unknown`. Với `bugSnapshot()` của widget, lỗi cho `widgetState: {}` kèm `widgetStateCaptureErrorType`. JSON hợp lệ gồm null, bool, string, số hữu hạn, list và map string-key; enum dùng `.name`, DateTime dùng `.toIso8601String()`, Set đổi thành list.

Observer ghi `created`, `closed`, `error` cho BLoC/Cubit; `event`, `transition` cho BLoC; `change` cho Cubit. Records lưu type names, không lưu state/event values, message hay stack trace đầy đủ. `instanceId` chỉ có ý nghĩa trong cùng phiên chạy.

## Giới hạn

- Chỉ những subtree được đánh dấu mới chọn được; không có chế độ tự biến toàn bộ widget tree thành inspectable.
- Không có reflection đọc params của widget hay field của `State`, tự nhận biết các BLoC widget dùng, network recorder hoặc timeline giá trị đầy đủ. Cần khai báo scope/mixin và serializer. Local state chỉ nằm trong `State` (ví dụ text của controller) không có trong report trừ khi được truyền thành param của widget dưới marker hoặc nằm trong BLoC/Cubit có scope.
- Registry, history và annotations không tự persist ra disk. Package có form và share sheet, nhưng không có dịch vụ upload hay tích hợp issue tracker; host nối qua `share:` hoặc flow riêng.
- Form không có field tùy biến (severity, assignee, app version, device). Host cần thêm dữ liệu thì dùng `BugInspector` + form riêng, hoặc gắn qua `share:` khi upload.
- `share_plus` là dependency plugin của package nên có native code trong cả bản production của host.
- Trang vẽ (`ScreenshotAnnotationPage`) là private; dùng `BugScreenshotEditor` nếu host dựng editor riêng.
- Runtime type names có thể bị rút gọn khi `--obfuscate`; dùng stable marker ID để truy nguồn.
- `onWidgetSelected` nhận callback trả `FutureOr<void>`. Return/await future của report route để launcher ẩn cho tới khi report đóng; callback không return future thì launcher vẫn hiện.
- Khi thiếu compile-time define, wrappers trả `child`, accessor/capture trả `null`, observer không ghi, editor hiện hộp rỗng. `BugReportPage`/`BugReportBundle` được gọi trực tiếp vẫn hoạt động; gate lối mở riêng nếu chỉ dùng cho QA. Vẫn có widget elements của wrappers; không mô tả là hoàn toàn không có overhead hoặc dùng số đo trước `0.8.0` cho binary hiện tại.

## Nguồn chi tiết

- [Host và compile-time gate](../../../flutter_qa_inspector/lib/src/bug_inspector.dart).
- [Selection models và JSON validation](../../../flutter_qa_inspector/lib/src/models.dart).
- [Scope collection](../../../flutter_qa_inspector/lib/src/bug_bloc_scope.dart) và [widget params (`BugInspectableWidget`)](../../../flutter_qa_inspector/lib/src/bug_inspectable_widget.dart).
- [Recorder và observer](../../../flutter_qa_inspector/lib/src/bug_state_recorder.dart).
- [Screenshot](../../../flutter_qa_inspector/lib/src/bug_screenshot.dart) và [editor/controller](../../../flutter_qa_inspector/lib/src/bug_screenshot_editor.dart).
- [Status bar mô phỏng](../../../flutter_qa_inspector/lib/src/bug_status_bar.dart).
- [Tích hợp nhanh](../../../flutter_qa_inspector/lib/src/flutter_qa_inspector_setup.dart), [form báo lỗi](../../../flutter_qa_inspector/lib/src/report/bug_report_page.dart), [ZIP](../../../flutter_qa_inspector/lib/src/report/bug_report_bundle.dart), [chuỗi](../../../flutter_qa_inspector/lib/src/report/bug_report_strings.dart), [page marker](../../../flutter_qa_inspector/lib/src/bug_inspectable_page.dart).
