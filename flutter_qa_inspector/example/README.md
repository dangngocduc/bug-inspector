# flutter_qa_inspector_example

Ví dụ tích hợp `flutter_qa_inspector`:

- `lib/main.dart`: gọi `FlutterQaInspector.install()` trước khi tạo BLoC/Cubit; package giữ observer đang có và ghi timeline khi build với `FLUTTER_QA_INSPECTOR=true`.
- `lib/app.dart`: gọi `FlutterQaInspector.wrap` trong `MaterialApp.builder`, giữ child chứa Navigator. Package tự chụp ảnh và mở form báo lỗi; launcher ẩn trong lúc form mở. Không cần file setup hoặc report riêng; app không cần option thì dùng thẳng `FlutterQaInspector.builder`.
- `lib/counter_page.dart`, `lib/catalog_page.dart`: dùng `BugBlocScope.lazy`, nên Cubit/Bloc chỉ được đọc khi tester chọn widget.
- `lib/counter_page.dart`: Cubit đếm số lần nhấn, như ví dụ trong tài liệu.
- `lib/catalog_page.dart`: Bloc có event, `ListView` và bộ lọc. Ô tìm kiếm giữ query trong `State` của màn hình; `BugInspectableState` đưa query đó vào `widgetStates`.
- Form, trang vẽ và ZIP nằm trong [package](../lib/src/report/), được dùng qua `package:flutter_qa_inspector/flutter_qa_inspector.dart`. Example không giữ bản copy hoặc khai báo riêng `archive`/`share_plus`.
- `BugReportPage`: form Cupertino full-screen trên root navigator (`/qa-bug-report`), với theme và Navigator riêng. Back đóng editor trước rồi mới tới form; form có mô tả hoặc khung hỏi trước khi bỏ.
- `BugReportStrings`: có sẵn `en`/`vi`, chọn theo locale của app. Example hiện dùng locale mặc định tiếng Anh cho report (**Bug report**, **Cancel**, **Send**, **Done**); có thể truyền `strings: (_) => BugReportStrings.vi` cho `wrap` để dùng tiếng Việt.

```sh
flutter pub get
flutter run --dart-define=FLUTTER_QA_INSPECTOR=true   # bản QA
flutter run --release                                   # như production: không có inspector
```

Nhấn **Tăng** hai lần, nhấn nút bug nổi ở cạnh phải, rồi chạm vào nút **Tăng** đang có viền. Form hiển thị `id: counter.increment` và snapshot `value: 2`; giá trị đếm giữ nguyên.

Mở **Danh mục**, gõ `2` vào ô tìm kiếm, bật inspector rồi chọn ô tìm kiếm hoặc bấm **Select screen**. Payload có `widgetStates` với `_CatalogViewState` và `query: 2`.

Sau khi chọn widget, trang **Bug report** mở toàn màn hình. Chạm vào ảnh trong form để mở trang **Mark up screenshot**. Kéo trên ảnh để vẽ khung, chạm vào khung để chọn, kéo để di chuyển, kéo các góc để đổi kích thước, bấm ✕ để xóa, dùng hai ngón tay để phóng to và di chuyển ảnh, rồi bấm **Done** (hoặc back) để quay lại form. **Clear all** hỏi trước khi xóa mọi khung. Dòng dưới ảnh hiện số vùng đã đánh dấu, và JSON sao chép bằng **Copy JSON** ở nhóm Payload có `screenshot.annotations`.

Bấm **Send** trên thanh điều hướng để chia sẻ báo lỗi qua share sheet của hệ điều hành (`share_plus`). Package nén ba file vào `bug_<id>_<yyyyMMdd_HHmmss>.zip` (thời gian UTC lúc chọn widget):

| File trong zip | Nội dung |
| --- | --- |
| `screenshot.png` | Ảnh giống ảnh trên form: viền nét đứt quanh widget đã chọn và các khung tester đánh dấu. Không có nếu báo lỗi không kèm ảnh. |
| `description.txt` | Mô tả lỗi tester nhập. |
| `inspector.json` | `inspector` (`selection.toJson()`) và `screenshot` (kích thước, `annotations`). |

Share sheet nhận ảnh PNG, file zip và mô tả lỗi (dạng text, bỏ qua nếu để trống). Chia sẻ xong thì trang báo lỗi đóng; đóng share sheet mà không chọn ứng dụng thì form giữ nguyên để gửi lại; chia sẻ lỗi thì hiện hộp thoại báo lỗi và giữ form. Trên iPad, share sheet hiện cạnh nút **Send**. `ios/Runner/Info.plist` có `NSPhotoLibraryAddUsageDescription` để tester dùng **Save Image**. Khi tích hợp app khác, kiểm tra thêm [yêu cầu native của dependency](../README.md#cài-đặt).
