# flutter_qa_inspector_example

Ví dụ tích hợp `flutter_qa_inspector`:

- `lib/main.dart`: cài `BugInspectorBlocObserver` qua `MultiBlocObserver` khi build với `FLUTTER_QA_INSPECTOR=true`.
- `lib/app.dart`: đặt `BugInspector` trong `MaterialApp.builder`, chụp ảnh và mở form báo lỗi. App không có nút Inspect riêng; tester dùng nút bug nổi của inspector.
- `lib/counter_page.dart`, `lib/catalog_page.dart`: dùng `BugBlocScope.lazy`, nên Cubit/Bloc chỉ được đọc khi tester chọn widget.
- `lib/counter_page.dart`: Cubit đếm số lần nhấn, như ví dụ trong tài liệu.
- `lib/catalog_page.dart`: Bloc có event, `ListView` và bộ lọc. Ô tìm kiếm giữ query trong `State` của màn hình; `BugInspectableState` đưa query đó vào `widgetStates`.
- `lib/bug_report_sheet.dart`: form demo hiển thị ảnh, vùng đã chọn và payload JSON.

```sh
flutter pub get
flutter run --dart-define=FLUTTER_QA_INSPECTOR=true   # bản QA
flutter run --release                                   # như production: không có inspector
```

Nhấn **Tăng** hai lần, nhấn nút bug nổi ở cạnh phải, rồi chạm vào nút **Tăng** đang có viền. Form hiển thị `id: counter.increment` và snapshot `value: 2`; giá trị đếm giữ nguyên.

Mở **Danh mục**, gõ `2` vào ô tìm kiếm, bật inspector rồi chọn ô tìm kiếm hoặc bấm **Select screen**. Payload có `widgetStates` với `_CatalogViewState` và `query: 2`.
