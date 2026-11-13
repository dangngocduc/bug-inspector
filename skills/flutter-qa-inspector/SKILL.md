---
name: flutter-qa-inspector
description: Tích hợp flutter_qa_inspector và thêm inspect cho widget/page Flutter; đọc, mô tả và phân tích bug report ZIP do flow của thư viện xuất ra, gồm screenshot.png, description.txt và inspector.json (kể cả các API call Dio đã record). Dùng khi user hỏi thư viện support gì, cách tích hợp/snapshot state/timeline/network Dio/annotation, hoặc gửi ZIP báo lỗi để hiểu vị trí UI và dữ liệu liên quan. Không dùng cho ZIP hoặc crash report không liên quan.
---

# Flutter QA Inspector

Giúp agent dùng public API của `flutter_qa_inspector` để tester chọn widget/màn hình, đồng thời hiểu bug khi nhận report ZIP chứa ảnh, mô tả và dữ liệu inspector. Khi user hỏi cách làm, cung cấp hướng dẫn/snippet; khi user yêu cầu triển khai hoặc sửa bug, thực hiện trong phạm vi đó.

## Chọn tài liệu theo nhu cầu

| Nhu cầu | Đọc |
| --- | --- |
| Nhận file ZIP để mô tả, phân tích hoặc sửa bug | [references/bug-reports.md](references/bug-reports.md) trước; dùng [scripts/read_bug_report.py](scripts/read_bug_report.py) để đọc đúng bundle |
| Thư viện support gì, dữ liệu trả về và giới hạn | [references/capabilities.md](references/capabilities.md) |
| Cài dependency, tích hợp nhanh (`FlutterQaInspector`, form báo lỗi có sẵn), host tùy chỉnh, observer, record API call bằng Dio interceptor, QA/production build | [references/integration.md](references/integration.md) |
| Thêm inspect widget/page, gắn BLoC/Cubit hoặc params của widget (`widgetState`) | [references/widget-page.md](references/widget-page.md) |
| Chụp ảnh, preview, editor đánh dấu và xuất PNG | [references/screenshots.md](references/screenshots.md) |

Chỉ đọc reference liên quan. Với input ZIP, bắt đầu từ report, không yêu cầu user tích hợp lại inspector. Với việc thêm marker, tái sử dụng host/recorder hiện có nếu app đã tích hợp.

## Hiểu bug từ ZIP

Đọc đủ `description.txt`, `inspector.json` và xem `screenshot.png` nếu có. Liên kết triệu chứng nhìn thấy, nội dung tester báo, marker/source/route, snapshot, timeline và các API call trong `inspector.network` để mô tả bug. Chỉ đọc JSON hoặc chỉ nhìn ảnh là chưa đủ khi bundle có cả hai.

Snapshot phản ánh **lúc tester chọn vùng lỗi**, không bảo đảm chính xác thời điểm bug phát sinh; ảnh có thể được chụp ở frame sau. Phân biệt bằng chứng, dữ liệu thiếu và giả thuyết; không khẳng định root cause từ marker hoặc tên state. Nếu user chỉ cần giải thích report thì không tự sửa code. Nếu user yêu cầu sửa, dùng source metadata/ID để tìm và kiểm chứng trong checkout hiện tại trước khi sửa.

## Nguồn đối chiếu

Trong repo này, package nằm ở `flutter_qa_inspector/` tính từ root project, còn skill nằm ở `skills/flutter-qa-inspector/`:

- [pubspec.yaml](../../flutter_qa_inspector/pubspec.yaml): version, SDK và dependencies thực tế.
- [Public entrypoint](../../flutter_qa_inspector/lib/flutter_qa_inspector.dart): import duy nhất cho consumer, các API được khai báo trong những file `part` của nó.
- [README](../../flutter_qa_inspector/README.md) và [app example](../../flutter_qa_inspector/example/lib/app.dart): hướng dẫn và luồng tích hợp đang có.
- [Form báo lỗi và ZIP](../../flutter_qa_inspector/lib/src/report/): `BugReportPage`, `BugReportBundle`, `BugReportStrings`.

Nếu skill được chuyển sang host repo khác, tìm dependency đang được host resolve qua `pubspec.yaml`, lockfile hoặc `.dart_tool/package_config.json`; không giữ nguyên đường dẫn local của repo này. Đối chiếu constructor và phần source liên quan khi version khác hoặc tài liệu mâu thuẫn. Không coi bản thiết kế implementation là bằng chứng một API đã tồn tại.

## Các ràng buộc tích hợp

- Consumer import `package:flutter_qa_inspector/flutter_qa_inspector.dart`; dùng public wrappers thay vì copy implementation hoặc import `src/`.
- Công tắc compile-time là `--dart-define=FLUTTER_QA_INSPECTOR=true`. `enabled: true` không bật được inspector nếu thiếu define. Không dùng tên flag cũ `QA_INSPECTOR`.
- Mặc định tích hợp bằng `FlutterQaInspector.install()` (trước khi tạo BLoC/Cubit) và `FlutterQaInspector.wrap(child:)`/`.builder` trong `MaterialApp.builder`: có sẵn timeline, launcher, chụp ảnh, form báo lỗi, ZIP và share sheet. Không copy form/bundle vào host; host còn bản copy cũ thì xóa (trùng tên gây `ambiguous_import`).
- Giữ nguyên Navigator/Router, theme, providers, state và callbacks của app. Ghép `wrap` (hoặc `BugInspector`) vào builder đang có và truyền tiếp `child`; không thay app bằng demo trong reference.
- Thêm `BugInspectable` cho vùng widget, `BugInspectablePage` cho toàn màn hình; navigator dùng `onGenerateRoute` có tên route thì dùng `BugInspectablePage.route(settings:, child:)`. Wrapper không tự tìm source file, BLoC phụ thuộc hay params của widget.
- Dùng `BugBlocScope<S>.lazy` dưới provider và trên marker widget cần snapshot. Tái sử dụng instance của app; không tạo Cubit/Bloc riêng chỉ để inspect. Page selection còn đọc được các scope bên trong page.
- Selection mô tả `child` trực tiếp của marker: `widgetType` là runtime type, `widgetState` là params của `child` đó. Params cần `with BugInspectableWidget` trên class widget làm `child` (không phải trên `State`); `child` không có mixin cho `widgetState: {}`. Từ `0.9.0` không còn `BugInspectableState`/`widgetStates`. Cả `bugSnapshot()` và `snapshotBuilder` phải đồng bộ, không thay đổi state, chỉ trả JSON-compatible values và bỏ secrets/dữ liệu cá nhân.
- Khi cần timeline với host tùy chỉnh, cài observer trước khi tạo BLoC/Cubit, giữ observer đang có và truyền cùng một `BugStateRecorder` cho observer lẫn host (`FlutterQaInspector.install` đã làm việc này cho `wrap`). Timeline chỉ chứa tên kiểu và thời điểm, không phải lịch sử đầy đủ giá trị state.
- Chuỗi hiển thị đi qua `strings:` (`BugReportStrings`, có sẵn `en`/`vi` theo locale); host có l10n thì map vào đó. Gửi report đi nơi khác (upload, ticket) qua `share:`. Chỉ dùng `BugInspector` + `onWidgetSelected(widgetContext, selection)` khi host cần form riêng; package không có dịch vụ upload hay tích hợp issue tracker.
- API call chỉ hỗ trợ app dùng Dio: thêm `BugInspectorDioInterceptor()` vào từng `Dio` của app, sau các interceptor sửa request, trong nhánh `BugInspector.enabledFromEnvironment`. Không có `recorder:` thì ghi vào `FlutterQaInspector.networkRecorder` do `install` tạo; host tùy chỉnh truyền cùng một `BugNetworkRecorder` cho interceptor và `BugInspector.networkRecorder`. Header/field bí mật mặc định được redact; dữ liệu cá nhân khác cần thêm vào `redactedFields` hoặc loại endpoint bằng `filter`. Không hỗ trợ `http`/`HttpClient` khác.
- Không cần thêm nút Inspect vào UI: host có launcher nổi. Menu QA riêng dùng `maybeModeCubitOf(context)?.enable()` từ context dưới host; tránh `context.read<InspectModeCubit>()` vì production không có Cubit đó.

## Kiểm tra và bàn giao

Với thay đổi tích hợp, chạy analyzer và các kiểm tra hiện có phù hợp trong host app. Nếu kiểm tra hành vi theo build mode, chạy riêng có và không có define; test nhóm QA có thể bị skip khi thiếu define.

Khi có thể kiểm tra runtime: thực hiện action bình thường, bật inspector rồi chọn marker; xác nhận action không chạy thêm do tap chọn, `kind`/`id` và snapshot đúng instance, **Select screen** trỏ đúng page/tab hiện tại. Bản không có define không có launcher; luồng app vẫn hoạt động. Nếu có screenshot, chụp trước khi mở form và kiểm tra PNG cùng metadata riêng.

Với tích hợp, nêu vị trí host/marker, cách bật QA build và dữ liệu snapshot đã chọn. Với ZIP, nêu bug quan sát được, vị trí và state liên quan, evidence hỗ trợ, điều còn thiếu và hướng điều tra tiếp theo theo [bug-reports.md](references/bug-reports.md). Phân biệt analyzer/test với runtime evidence; không khẳng định đã tái hiện bug khi chỉ đọc report/source.
