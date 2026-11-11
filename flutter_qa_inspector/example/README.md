# flutter_qa_inspector_example

Ví dụ tích hợp `flutter_qa_inspector`:

- `lib/main.dart`: cài `BugInspectorBlocObserver` qua `MultiBlocObserver` khi build với `QA_INSPECTOR=true`.
- `lib/app.dart`: đặt `BugInspector` trong `MaterialApp.builder`, chụp ảnh và mở form báo lỗi.
- `lib/counter_page.dart`: Cubit đếm số lần nhấn, như ví dụ trong tài liệu.
- `lib/catalog_page.dart`: Bloc có event, `ListView` và bộ lọc.
- `lib/bug_report_sheet.dart`: form demo hiển thị ảnh, vùng đã chọn và payload JSON.

```sh
flutter pub get
flutter run --dart-define=QA_INSPECTOR=true
```

Nhấn **Tăng** hai lần, nhấn **Inspect**, rồi chạm vào nút **Tăng** đang có viền. Form hiển thị `id: counter.increment` và snapshot `value: 2`; giá trị đếm giữ nguyên.
