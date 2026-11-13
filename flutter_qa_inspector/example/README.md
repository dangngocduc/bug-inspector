# flutter_qa_inspector_example

Ví dụ tích hợp `flutter_qa_inspector`:

- `lib/main.dart`: gọi `FlutterQaInspector.install()` trước khi tạo BLoC/Cubit; package giữ observer đang có và ghi timeline khi build với `FLUTTER_QA_INSPECTOR=true`.
- `lib/app.dart`: gọi `FlutterQaInspector.wrap` trong `MaterialApp.builder`, giữ child chứa Navigator. Package tự chụp ảnh và mở form báo lỗi; launcher ẩn trong lúc form mở. Không cần file setup hoặc report riêng; app không cần option thì dùng thẳng `FlutterQaInspector.builder`.
- `lib/counter_page.dart`, `lib/catalog_page.dart`: dùng `BugBlocScope.lazy`, nên Cubit/Bloc chỉ được đọc khi tester chọn widget.
- `lib/counter_page.dart`: Cubit đếm số lần nhấn, như ví dụ trong tài liệu.
- `lib/main.dart`: `FlutterQaInspector.install(networkRecorder: exampleNetworkRecorder())`, recorder giữ body tới 256 KB (mặc định 16 KB) và redact thêm field `email`.
- `lib/jsonplaceholder_api.dart`, `lib/comments_page.dart`: gọi API thật của [jsonplaceholder](https://jsonplaceholder.typicode.com) qua Dio có `BugInspectorDioInterceptor`: `GET /comments` (500 comment, khoảng 130 KB) và `GET /comments/{id}` khi chạm một comment. Nút ⚠ trên app bar mở `/comments/999999` để có call lỗi 404 (màn hình có nút **Thử lại**). Cần Internet; Android đã khai báo quyền `INTERNET` trong manifest chính để bản release cũng gọi được.
- `lib/demo_api.dart`: `Dio` của example với `BugInspectorDioInterceptor` (chỉ thêm khi build QA) và một adapter local trả về danh sách sản phẩm, nên example chạy offline. App thật giữ adapter của mình, chỉ thêm interceptor. Header `Authorization` giả lập hiện là `REDACTED` trong report.
- `lib/catalog_page.dart`: Bloc tải danh sách qua Dio (`GET /products?page=1`), có event, `ListView` và bộ lọc. Mỗi item là `_CatalogItemTile` dùng `BugInspectableWidget`, nên report của item có `widgetType: _CatalogItemTile` và `widgetState` với `item`, `favorite` (params mà list truyền vào). Query của ô tìm kiếm nằm trong `State` của màn hình nên không có trong report.
- Form, trang vẽ và ZIP nằm trong [package](../lib/src/report/), được dùng qua `package:flutter_qa_inspector/flutter_qa_inspector.dart`. Example không giữ bản copy hoặc khai báo riêng `archive`/`share_plus`.
- `BugReportPage`: form Cupertino full-screen trên root navigator (`/qa-bug-report`), với theme và Navigator riêng. Back đóng editor trước rồi mới tới form; form có mô tả hoặc khung hỏi trước khi bỏ.
- `BugReportStrings`: có sẵn `en`/`vi`, chọn theo locale của app. Example hiện dùng locale mặc định tiếng Anh cho report (**Bug report**, **Cancel**, **Send**, **Done**); có thể truyền `strings: (_) => BugReportStrings.vi` cho `wrap` để dùng tiếng Việt.

```sh
flutter pub get
flutter run --dart-define=FLUTTER_QA_INSPECTOR=true   # bản QA
flutter run --release                                   # như production: không có inspector
```

Nhấn **Tăng** hai lần, nhấn nút bug nổi ở cạnh phải, rồi chạm vào nút **Tăng** đang có viền. Form hiển thị `id: counter.increment` và snapshot `value: 2`; giá trị đếm giữ nguyên.

Mở **Danh mục**, bấm tim của **Sản phẩm 2**, bật inspector rồi chọn **Sản phẩm 2**. Payload có `widgetType: _CatalogItemTile` và `widgetState: {item: Sản phẩm 2, favorite: true}`. Bấm **Select screen** thì `widgetType` là `CatalogPage` và `widgetState` là `{}` vì `CatalogPage` không dùng mixin.

Sau khi mở **Danh mục**, report của mọi selection có nhóm **Network** với call `GET /products?page=1` (`200`). Chạm vào call để xem URL, thời gian, headers, request/response body; response JSON hiện ngay dạng cây (Expand all / Collapse all ở header của section, chạm object/list để mở/đóng); `inspector.json` có danh sách này ở `inspector.network`.

Từ màn đầu bấm **Comments (API thật)**, chạm một comment rồi bật inspector và **Select screen**: nhóm **Network** có `GET /comments/{id}` và `GET /comments` (`200`), body JSON hiện dạng cây ngay trong trang call (`/comments` dài nên mở sẵn chỉ root, các comment đang đóng), `email` hiện `REDACTED`. Mở comment 404 để thấy call `failed` màu đỏ với lỗi `badResponse`. Không cần chọn widget: bật inspector rồi bấm **Inspect network** (dưới **Select screen**) để mở lịch sử mọi API call, cập nhật trực tiếp, có nút **Clear**.

Mỗi dòng API trong lịch sử và nhóm **Network** hiển thị host, duration và thời điểm nhận response theo giờ local của thiết bị, dạng `Response: HH:mm:ss.SSS`. Lỗi không có response hiện thời điểm ghi nhận lỗi với nhãn **Error** (**Lỗi** khi dùng `BugReportStrings.vi`); pending chưa có thời gian kết thúc. Danh sách vẫn xếp theo thời điểm bắt đầu request, mới nhất trước; timestamp trong JSON/ZIP vẫn là UTC.

Sau khi chọn widget, trang **Bug report** mở toàn màn hình. Chạm vào ảnh trong form để mở trang **Mark up screenshot**. Kéo trên ảnh để vẽ khung, chạm vào khung để chọn, kéo để di chuyển, kéo các góc để đổi kích thước, bấm ✕ để xóa, dùng hai ngón tay để phóng to và di chuyển ảnh, rồi bấm **Done** (hoặc back) để quay lại form. **Clear all** hỏi trước khi xóa mọi khung. Dòng dưới ảnh hiện số vùng đã đánh dấu, và JSON sao chép bằng **Copy JSON** ở nhóm Payload có `screenshot.annotations`.

Bấm **Send** trên thanh điều hướng để chia sẻ báo lỗi qua share sheet của hệ điều hành (`share_plus`). Package nén ba file vào `bug_<id>_<yyyyMMdd_HHmmss>.zip` (thời gian UTC lúc chọn widget):

| File trong zip | Nội dung |
| --- | --- |
| `screenshot.png` | Ảnh giống ảnh trên form: viền nét đứt quanh widget đã chọn và các khung tester đánh dấu. Không có nếu báo lỗi không kèm ảnh. |
| `description.txt` | Mô tả lỗi tester nhập. |
| `inspector.json` | `inspector` (`selection.toJson()`, gồm `network`) và `screenshot` (kích thước, `annotations`). |

Share sheet nhận ảnh PNG, file zip và mô tả lỗi (dạng text, bỏ qua nếu để trống). Chia sẻ xong thì trang báo lỗi đóng; đóng share sheet mà không chọn ứng dụng thì form giữ nguyên để gửi lại; chia sẻ lỗi thì hiện hộp thoại báo lỗi và giữ form. Trên iPad, share sheet hiện cạnh nút **Send**. `ios/Runner/Info.plist` có `NSPhotoLibraryAddUsageDescription` để tester dùng **Save Image**. Khi tích hợp app khác, kiểm tra thêm [yêu cầu native của dependency](../README.md#cài-đặt).
