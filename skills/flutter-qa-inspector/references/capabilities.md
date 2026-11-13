# Khả năng và giới hạn

Đối chiếu với package `flutter_qa_inspector` version `0.10.0` trong repo này. Khi dùng version khác, kiểm tra lại public API thay vì suy ra từ bảng này.

## Chọn API

| Nhu cầu | API | Hành vi cần biết |
| --- | --- | --- |
| Tích hợp nhanh có form báo lỗi | `FlutterQaInspector.install`, `FlutterQaInspector.wrap` / `.builder`, `FlutterQaInspector.recorder`, `FlutterQaInspector.networkRecorder` | `install` cài observer timeline và tạo network recorder một lần; `wrap` dựng host (gắn cả hai recorder) và mở `BugReportPage` cho mỗi selection. Thiếu define: `install` không làm gì, `wrap` trả `child`. Xem [integration.md](integration.md). |
| Form báo lỗi có sẵn | `BugReportPage`, `BugReportPage.open` | Cupertino, theme riêng, `Navigator` riêng trên root navigator (`/qa-bug-report`): target, preview + trang vẽ full-screen, mô tả, nhóm **Network** (mới nhất trước, chạm để xem chi tiết call: Request = host + method/path với query param tô màu, Request headers từng dòng có nút copy value (header redact không copy), Request body, rồi Response = status/duration/thời gian, error, response headers, response body; body JSON object/list nguyên vẹn hiện ngay dạng cây collapsible (lazy) với Expand all/Collapse all ở header, ban đầu mở theo từng cấp trong giới hạn 100 dòng; body bị cắt và body khác hiện text), JSON + Copy JSON, Send. Preview Payload bỏ `network`; ZIP và Copy JSON vẫn có. Hỏi trước khi bỏ form có thay đổi; share bị dismiss thì giữ form. |
| Đóng gói/gửi report | `BugReportBundle`, `BugReportShare` | ZIP `screenshot.png`, `description.txt`, `inspector.json`; `nameFor`, `toZip()`, `toShareParams()`. `share:` tùy chỉnh để upload/tạo ticket thay share sheet. |
| Chuỗi hiển thị | `BugReportStrings` (`en`, `vi`, `of`, `copyWith`), `BugReportStringsBuilder` | Chuỗi cho toolbar, form, editor. `of` chọn `vi` theo locale, mặc định `en`. |
| Bật công cụ cho toàn app (tùy chỉnh) | `BugInspector` | Registry theo subtree, launcher nổi kéo được, toolbar chọn và callback. Thường đặt trong `MaterialApp.builder` hoặc `MaterialApp.router.builder`. |
| Điều khiển từ menu QA | `InspectModeCubit`, `BugInspector.maybeModeCubitOf` | `enable()`, `disable()`, `toggle()`; accessor trả `null` ngoài host đang bật hoặc khi thiếu define. |
| Chọn một vùng UI | `BugInspectable` | Marker có `id` bắt buộc; `label`, `sourceFile`, `sourceLine` và border tùy chọn. Selection mô tả `child`: `widgetType` là runtime type của `child`, `widgetState` là params của `child`. |
| Chọn toàn màn hình | `BugInspectablePage`, `BugInspectablePage.route` | `.route(settings:)` lấy `id`/`label` từ tên route (`unnamed_route` khi không tên). Dùng **Select screen**. Page/tab được vẽ trên cùng thắng; page lồng trong shell thắng page bao ngoài. Dialog/bottom sheet không tự trở thành page. |
| Đọc BLoC/Cubit hiện tại | `BugBlocScope<S>.lazy` | Khai báo instance và serializer, chỉ đọc khi chọn. Bản `BugBlocScope(bloc: ...)` cũng có, nhưng biểu thức đối số vẫn chạy lúc build. |
| Đọc params của widget được chọn | `BugInspectableWidget` | Mixin trên class widget (`StatelessWidget`/`StatefulWidget`) làm `child` trực tiếp của marker, override `Map<String, Object?> bugSnapshot()`. Chỉ thu params khai báo tường minh, hoạt động mọi build mode. Không đọc field của `State`, widget sâu hơn trong `child` hay phía trên marker. `BugInspectableState` đã bỏ từ `0.9.0`. |
| Timeline gần thời điểm chọn | `BugStateRecorder`, `BugInspectorBlocObserver` | Queue RAM mặc định 300 records; host lấy 30 giây gần nhất theo `historyWindow`. Observer có `filter` và bỏ qua `InspectModeCubit`. |
| API call (request/response) của app dùng Dio | `BugInspectorDioInterceptor`, `BugNetworkRecorder`, `BugNetworkRecord`, `BugNetworkBody` | Interceptor ghi mọi call vào recorder (mặc định `FlutterQaInspector.networkRecorder`), có `filter`. Recorder giữ 100 call mới nhất (`maxRecords`) cho lịch sử API, nhưng mỗi selection/report chỉ lấy tối đa 10 call mới nhất (`maxReportRecords`, `0` = report không có call), cắt body text/JSON sau 16384 ký tự (`maxBodyLength`), redact `redactedHeaders`/`redactedFields`. Host gắn qua `BugInspector.networkRecorder`; `networkHistoryWindow` mặc định `null` = mọi call đang giữ. Recorder là `Listenable`. Chỉ Dio. |
| Xem lịch sử API call không cần chọn widget | Nút **Inspect network** trên toolbar chọn (`BugInspector.networkButtonKey`), `BugNetworkHistoryPage`, `BugNetworkHistoryPage.open` | Nút hiện dưới **Select screen** khi host có `networkRecorder`, subtitle đếm số call và số call lỗi/status `>= 400`, cập nhật live. Bấm thì tắt mode và push `BugNetworkHistoryPage` (`/qa-network-history`) lên root navigator, launcher ẩn tới khi đóng. Trang liệt kê mọi call (mới nhất trước, live), chi tiết call + JSON tree, **Clear** xóa recorder (report sau không còn các call đó). Text qua `BugInspector.strings` (facade truyền `strings:` của nó). |
| Payload | `BugWidgetSelection`, `BugBlocSnapshot`, `BugStateRecord`, `BugNetworkRecord` | Có `toJson()`; lỗi capture một snapshot (BLoC hoặc `widgetState`) không làm mất những phần khác. |
| Chụp nội dung app | `BugInspector.captureScreenshot`, `BugScreenshot` | PNG không gồm launcher/overlay riêng của inspector. Có thể trả `null`; không tự đính kèm vào selection. |
| Bổ sung status bar cho ảnh | `BugStatusBar`, `BugStatusBarStyle` | `captureScreenshot(statusBar: true)` mặc định thêm metadata status bar giả khi chụp dưới top safe area trên Android/iOS. Editor và export vẽ nó; pin/sóng/Wi-Fi là mô phỏng, không phải telemetry. |
| Đánh dấu vùng trên ảnh | `BugScreenshotEditor`, `BugScreenshotAnnotationController`, `BugScreenshotAnnotation` | Vẽ, chọn, kéo, resize, xóa rectangle; pinch zoom/pan, reset zoom; `readOnly` cho preview. Controller do app sở hữu và dispose. |
| Xuất ảnh đã đánh dấu | `BugScreenshot.toAnnotatedPng` | Render highlight và rectangles vào PNG; truyền style giống editor khi có custom style. |
| Hiểu report ZIP được export | `BugReportPage` / `BugReportBundle` | Agent đọc ảnh, mô tả và inspector payload theo [bug-reports.md](bug-reports.md). Host có form riêng có thể xuất format khác. |
| Automation bằng widget key | `BugInspector.launcherKey`, `exitButtonKey`, `pageButtonKey`, `networkButtonKey`; `BugNetworkHistoryPage.closeButtonKey`, `clearButtonKey` | Editor có thêm `deleteButtonKey`, `resetZoomButtonKey`. |

Khi inspect mode bật, app bên dưới ngừng nhận pointer; tap chọn không gọi action của widget. Border được vẽ foreground mà không đổi kích thước/padding. Tap ngoài marker giữ mode, trừ khi host bật `selectPageOnEmptyTap`.

Danh sách API trong `BugNetworkHistoryPage` và nhóm **Network** của `BugReportPage` dùng chung cách hiển thị: host + duration, bên dưới là thời điểm nhận response theo giờ local thiết bị (`Response: HH:mm:ss.SSS`, từ `endedAtUtc`). Lỗi không có response dùng nhãn `networkError` (**Error**/**Lỗi**) và thời điểm ghi nhận lỗi; pending chưa hiện thời gian kết thúc. Nhãn response dùng `BugReportStrings.networkResponse`. Thứ tự vẫn theo lúc request bắt đầu, mới nhất trước; timestamp xuất JSON/ZIP giữ UTC.

## Dữ liệu selection

`selection.toJson()` cung cấp:

- `kind`: `widget` hoặc `page`; `id`, `widgetType`, `widgetState`, `capturedAtUtc`.
- `widgetType` và `widgetState` cùng mô tả `child` trực tiếp của `BugInspectable`/`BugInspectablePage`: type và params từ `BugInspectableWidget.bugSnapshot()`. `widgetState` luôn có mặt, là `{}` khi class của `child` không dùng mixin (kể cả widget Flutter như `Text`, `FilledButton`) hoặc khi capture lỗi; khi lỗi có thêm `widgetStateCaptureErrorType`. Không dùng Diagnostics/`debugFillProperties` (rỗng ngoài debug build).
- `label`, `source.file`, `source.line`, `route.name`: chỉ xuất hiện khi có dữ liệu. Route lấy từ `RouteSettings.name`; source metadata do app truyền, không được tự suy ra từ runtime.
- `bounds`: global logical pixels, gồm `left`, `top`, `width`, `height`, `coordinateUnit: logical_pixels`. Đây là bounding box ngoài, không phải vùng đã trừ clip.
- `blocs`: khi chọn widget, lấy scope ancestors gần trước; khi chọn page, lấy descendant scopes theo tree rồi ancestors. Loại trùng theo identity instance, không theo class.
- `stateHistory`: records trong cửa sổ thời gian của recorder, cũ trước. Đây là lịch sử các instance observer ghi nhận, không tự lọc theo `selection.blocs`; đối chiếu bằng `instanceId` hoặc cấu hình observer `filter`.
- `network`: luôn có (có thể rỗng), tối đa `maxReportRecords` (mặc định 10) API call **mới nhất** của **toàn app** mà recorder đang giữ lúc chọn, theo thứ tự bắt đầu, cũ trước. Mỗi call có `id`, `status` (`pending`/`completed`/`failed`), `method`, `url`, `startedAtUtc`, `endedAtUtc`/`durationMs` (khi đã xong), `request.headers`/`request.body`, `response` (khi có response, kể cả status lỗi) và `error` (`type` là tên `DioExceptionType`, `message`, `causeType`). Body có `kind` (`json`, `text`, `bytes`, `formData`, `stream`, `other`), `value`, `size`, `truncated`. Xem cách đọc ở [bug-reports.md](bug-reports.md).

BLoC snapshot có `captureErrorType` và `state: {}` khi serializer ném lỗi hoặc trả dữ liệu không hợp lệ; lỗi đọc lazy provider còn cho `type`/`instanceId: unknown`. Với `bugSnapshot()` của widget, lỗi cho `widgetState: {}` kèm `widgetStateCaptureErrorType`. JSON hợp lệ gồm null, bool, string, số hữu hạn, list và map string-key; enum dùng `.name`, DateTime dùng `.toIso8601String()`, Set đổi thành list.

Interceptor luôn chuyển tiếp request/response/error nguyên vẹn, lỗi khi ghi bị bỏ qua; chỉ thêm `BugInspectorDioInterceptor.extraKey` vào `RequestOptions.extra`. Redact mặc định: header `Authorization`, `Proxy-Authorization`, `Cookie`, `Set-Cookie`, `X-Api-Key`, `X-Auth-Token`, `X-Access-Token`, `X-Refresh-Token`; field JSON/form/query như `password`, `secret`, `token`, `accessToken`, `refreshToken`, `idToken`, `apiKey`, `otp`, `pin`, `cvv`, `cardNumber` (so khớp bỏ qua hoa thường, `_`, `-`); xóa user info của URL. Giá trị thành `REDACTED`. Body text thuần không được redact; dữ liệu cá nhân khác giữ nguyên trừ khi host thêm field hoặc `filter`.

Observer ghi `created`, `closed`, `error` cho BLoC/Cubit; `event`, `transition` cho BLoC; `change` cho Cubit. Records lưu type names, không lưu state/event values, message hay stack trace đầy đủ. `instanceId` chỉ có ý nghĩa trong cùng phiên chạy.

## Giới hạn

- Chỉ những subtree được đánh dấu mới chọn được; không có chế độ tự biến toàn bộ widget tree thành inspectable.
- Không có reflection đọc params của widget hay field của `State`, tự nhận biết các BLoC widget dùng hoặc timeline giá trị đầy đủ. Cần khai báo scope/mixin và serializer. Local state chỉ nằm trong `State` (ví dụ text của controller) không có trong report trừ khi được truyền thành param của widget dưới marker hoặc nằm trong BLoC/Cubit có scope.
- Network chỉ hỗ trợ Dio (`dio ^5.2.0`), qua interceptor host tự thêm vào từng client; không bắt `http`, `HttpClient`, WebSocket hay request native. Interceptor thêm trước interceptor này mà trả lời trong `onRequest` (cache) làm call không được ghi; kết thúc call trong `onError` (retry resolve lỗi) làm record kẹt `pending`. Retry bằng `dio.fetch` thành record riêng. Queue 100 call, RAM-only; app gọi nhiều API có thể đã đẩy call cũ ra trước lúc chọn.
- Registry, history, network và annotations không tự persist ra disk. Package có form và share sheet, nhưng không có dịch vụ upload hay tích hợp issue tracker; host nối qua `share:` hoặc flow riêng.
- Form không có field tùy biến (severity, assignee, app version, device). Host cần thêm dữ liệu thì dùng `BugInspector` + form riêng, hoặc gắn qua `share:` khi upload.
- `share_plus` là dependency plugin của package nên có native code trong cả bản production của host.
- Trang vẽ (`ScreenshotAnnotationPage`) là private; dùng `BugScreenshotEditor` nếu host dựng editor riêng.
- Runtime type names có thể bị rút gọn khi `--obfuscate`; dùng stable marker ID để truy nguồn.
- `onWidgetSelected` nhận callback trả `FutureOr<void>`. Return/await future của report route để launcher ẩn cho tới khi report đóng; callback không return future thì launcher vẫn hiện.
- Khi thiếu compile-time define, wrappers trả `child`, accessor/capture trả `null` (gồm `FlutterQaInspector.networkRecorder`), observer và Dio interceptor không ghi (interceptor chỉ chuyển tiếp), editor hiện hộp rỗng. `BugReportPage`/`BugReportBundle` được gọi trực tiếp vẫn hoạt động; gate lối mở riêng nếu chỉ dùng cho QA. Vẫn có widget elements của wrappers; không mô tả là hoàn toàn không có overhead hoặc dùng số đo trước `0.8.0` cho binary hiện tại.

## Nguồn chi tiết

- [Host và compile-time gate](../../../flutter_qa_inspector/lib/src/bug_inspector.dart).
- [Selection models và JSON validation](../../../flutter_qa_inspector/lib/src/models.dart).
- [Scope collection](../../../flutter_qa_inspector/lib/src/bug_bloc_scope.dart) và [widget params (`BugInspectableWidget`)](../../../flutter_qa_inspector/lib/src/bug_inspectable_widget.dart).
- [Recorder và observer](../../../flutter_qa_inspector/lib/src/bug_state_recorder.dart).
- [Network recorder và Dio interceptor](../../../flutter_qa_inspector/lib/src/bug_network_recorder.dart), [trang chi tiết call](../../../flutter_qa_inspector/lib/src/report/network_record_page.dart).
- [Screenshot](../../../flutter_qa_inspector/lib/src/bug_screenshot.dart) và [editor/controller](../../../flutter_qa_inspector/lib/src/bug_screenshot_editor.dart).
- [Status bar mô phỏng](../../../flutter_qa_inspector/lib/src/bug_status_bar.dart).
- [Tích hợp nhanh](../../../flutter_qa_inspector/lib/src/flutter_qa_inspector_setup.dart), [form báo lỗi](../../../flutter_qa_inspector/lib/src/report/bug_report_page.dart), [ZIP](../../../flutter_qa_inspector/lib/src/report/bug_report_bundle.dart), [chuỗi](../../../flutter_qa_inspector/lib/src/report/bug_report_strings.dart), [page marker](../../../flutter_qa_inspector/lib/src/bug_inspectable_page.dart).
