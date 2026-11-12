# flutter_qa_inspector_example

Ví dụ tích hợp `flutter_qa_inspector`:

- `lib/main.dart`: cài `BugInspectorBlocObserver` qua `MultiBlocObserver` khi build với `FLUTTER_QA_INSPECTOR=true`.
- `lib/app.dart`: đặt `BugInspector` trong `MaterialApp.builder`, chụp ảnh và mở form báo lỗi. App không có nút Inspect riêng; tester dùng nút bug nổi của inspector. `onWidgetSelected` trả về Future của trang báo lỗi, nên nút bug nổi ẩn trong lúc trang mở.
- `lib/counter_page.dart`, `lib/catalog_page.dart`: dùng `BugBlocScope.lazy`, nên Cubit/Bloc chỉ được đọc khi tester chọn widget.
- `lib/counter_page.dart`: Cubit đếm số lần nhấn, như ví dụ trong tài liệu.
- `lib/catalog_page.dart`: Bloc có event, `ListView` và bộ lọc. Ô tìm kiếm giữ query trong `State` của màn hình; `BugInspectableState` đưa query đó vào `widgetStates`.
- `lib/bug_report_page.dart`: trang báo lỗi toàn màn hình kiểu modal iOS, mở trên root navigator bằng `CupertinoPageRoute(fullscreenDialog: true)`. Toàn bộ report dùng widget Cupertino (`CupertinoPageScaffold`, `CupertinoNavigationBar`, `CupertinoListSection.insetGrouped`, `CupertinoTextField`, action sheet, alert) với `CupertinoThemeData` riêng, theo chế độ sáng/tối của máy. Trang có `Navigator` riêng: trang đầu là form với **Hủy** / **Gửi** trên thanh điều hướng, các nhóm Đối tượng, Ảnh chụp màn hình, Mô tả và Payload; chạm vào ảnh để mở trang đánh dấu trong navigator đó. Nút back và cử chỉ back đóng trang đánh dấu trước, rồi mới đóng cả trang báo lỗi. Khi đã nhập mô tả hoặc vẽ khung, **Hủy** và back hỏi lại trước khi bỏ báo lỗi.
- `lib/screenshot_annotation_page.dart`: trang toàn màn hình nền tối trong navigator của trang báo lỗi, để vẽ khung chữ nhật lên ảnh chụp bằng `BugScreenshotEditor`. **Xóa hết** (có hỏi lại) xóa mọi khung, **Xong** quay lại form.
- `lib/bug_report_bundle.dart`: đóng gói báo lỗi thành file zip (dùng `archive`) và tạo `ShareParams` cho `share_plus`.

```sh
flutter pub get
flutter run --dart-define=FLUTTER_QA_INSPECTOR=true   # bản QA
flutter run --release                                   # như production: không có inspector
```

Nhấn **Tăng** hai lần, nhấn nút bug nổi ở cạnh phải, rồi chạm vào nút **Tăng** đang có viền. Form hiển thị `id: counter.increment` và snapshot `value: 2`; giá trị đếm giữ nguyên.

Mở **Danh mục**, gõ `2` vào ô tìm kiếm, bật inspector rồi chọn ô tìm kiếm hoặc bấm **Select screen**. Payload có `widgetStates` với `_CatalogViewState` và `query: 2`.

Sau khi chọn widget, trang **Báo lỗi** mở toàn màn hình. Chạm vào ảnh trong form để mở trang **Đánh dấu trên ảnh**. Kéo trên ảnh để vẽ khung, chạm vào khung để chọn, kéo để di chuyển, kéo các góc để đổi kích thước, bấm ✕ để xóa, dùng hai ngón tay để phóng to và di chuyển ảnh, rồi bấm **Xong** (hoặc back) để quay lại form. Dòng dưới ảnh hiện số vùng đã đánh dấu, và JSON sao chép bằng **Sao chép JSON** ở nhóm Payload có `screenshot.annotations`.

Bấm **Gửi** trên thanh điều hướng để chia sẻ báo lỗi qua share sheet của hệ điều hành (`share_plus`). App nén ba file vào `bug_<id>_<yyyyMMdd_HHmmss>.zip` (thời gian UTC lúc chọn widget):

| File trong zip | Nội dung |
| --- | --- |
| `screenshot.png` | Ảnh giống ảnh trên form: viền nét đứt quanh widget đã chọn và các khung tester đánh dấu. Không có nếu báo lỗi không kèm ảnh. |
| `description.txt` | Mô tả lỗi tester nhập. |
| `inspector.json` | `inspector` (`selection.toJson()`) và `screenshot` (kích thước, `annotations`). |

Share sheet nhận ảnh PNG, file zip và mô tả lỗi (dạng text, bỏ qua nếu để trống). Chia sẻ xong thì trang báo lỗi đóng; đóng share sheet mà không chọn ứng dụng thì form giữ nguyên để gửi lại; chia sẻ lỗi thì hiện hộp thoại báo lỗi và giữ form. Trên iPad, share sheet hiện cạnh nút **Gửi**. `ios/Runner/Info.plist` có `NSPhotoLibraryAddUsageDescription` vì iOS dừng app nếu tester chọn **Lưu hình ảnh** mà thiếu khóa này.
