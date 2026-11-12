# Hướng dẫn cho agent

## Phạm vi và ngôn ngữ

- File này áp dụng cho toàn bộ repository. Đọc thêm `AGENTS.md` trong thư mục con nếu có trước khi sửa file tại đó.
<!-- language-response:start -->
- Luôn trả lời bằng tiếng Việt, mix English cho các term technical hoặc term viết tiếng Anh phổ biến.
<!-- language-response:end -->
- Thực hiện đúng phạm vi user yêu cầu; giữ nguyên thay đổi không liên quan trong working tree. Không tự commit, push hoặc publish khi chưa được yêu cầu.

## Cấu trúc repository

- `flutter_qa_inspector/`: Flutter package; public entrypoint là `lib/flutter_qa_inspector.dart`, implementation nằm trong `lib/src/`.
- `flutter_qa_inspector/test/`: test của package, gồm hai chế độ QA và production.
- `flutter_qa_inspector/example/`: app minh họa tích hợp, screenshot, annotation và xuất bug report ZIP.
- `skills/flutter-qa-inspector/`: skill hướng dẫn sử dụng package và phân tích bug report; gồm `SKILL.md`, `references/`, `scripts/` và `agents/`.
- `flutter_qa_inspector_implementation.md`: tài liệu thiết kế; phải đối chiếu source hiện tại trước khi coi một API hoặc hành vi là đã được triển khai.

## Quy tắc triển khai

- Đọc source, test và tài liệu liên quan trước khi sửa; ưu tiên thay đổi nhỏ, đúng nguyên nhân.
- Consumer dùng `package:flutter_qa_inspector/flutter_qa_inspector.dart`; không hướng dẫn import trực tiếp `src/`.
- Giữ tương thích public API trừ khi task yêu cầu thay đổi; ghi rõ tác động và cách chuyển đổi khi có breaking change.
- Giữ ranh giới QA/production: công tắc compile-time hiện tại là `--dart-define=FLUTTER_QA_INSPECTOR=true`. Thiếu define hoặc `false` phải giữ hành vi production đã được package cam kết.
- Giữ nguyên Navigator/Router, theme, providers, state, callbacks và lifecycle của host app khi sửa tích hợp.
- Không đưa secrets hoặc dữ liệu cá nhân vào snapshot, report, fixture hoặc tài liệu mẫu.
- Đối chiếu public API và hành vi bằng source cùng kiểm tra phù hợp; không dùng tài liệu cũ làm bằng chứng duy nhất. Đồng bộ README, example và changelog khi thay đổi ảnh hưởng đến chúng.

## Bắt buộc đánh giá ảnh hưởng đến skill

**Mọi thay đổi liên quan đến logic hoặc cách sử dụng đều phải được đánh giá xem có cần cập nhật `skills/` trước khi báo hoàn tất.** Quy tắc này áp dụng cả bug fix và thay đổi logic nội bộ, kể cả khi signature của public API không đổi.

Các trường hợp phải đánh giá gồm: thêm/sửa/xóa API; đổi default, callback, lifecycle, cách chọn widget/page, snapshot, timeline, screenshot hoặc annotation; đổi dependency, build flag, QA/production; đổi cách tích hợp; đổi schema, tên file hoặc cách đọc bug report ZIP; sửa giới hạn hoặc hướng troubleshooting.

### Quy trình trong mỗi task

1. Xác định hành vi trước/sau và người dùng hoặc agent cần biết gì để sử dụng, tích hợp hoặc phân tích kết quả đúng.
2. Đọc `skills/flutter-qa-inspector/SKILL.md`, tìm kiếm trong toàn bộ `skills/` các API, option, field, flag hoặc hành vi bị ảnh hưởng; đọc đầy đủ reference/script liên quan. Không chỉ kiểm tra `SKILL.md`.
3. Đối chiếu từng hướng dẫn, snippet, giới hạn và script liên quan với implementation sau thay đổi. Đánh giá khả năng skill khiến agent dùng sai API, hiểu sai dữ liệu hoặc đưa ra kết luận sai.
4. Nếu cần, cập nhật skill **trong cùng task**, không chỉ đề xuất để làm sau. Đây là một phần của yêu cầu thay đổi logic/cách sử dụng; không cần hỏi lại để đồng bộ skill trong phạm vi đó. Nếu user yêu cầu read-only hoặc cấm sửa skill, tôn trọng giới hạn và nêu rõ phần đồng bộ còn thiếu.
5. Nếu không cần cập nhật, ghi rõ lý do gắn với thay đổi và các file skill đã đối chiếu. Các câu như “không đổi API” hoặc “chỉ sửa nội bộ” chưa đủ nếu hành vi quan sát được, giới hạn hoặc cách dùng đã đổi.
6. Kiểm tra lại link, snippet và script sau khi cập nhật. Không được báo task hoàn tất khi vẫn còn nội dung skill đã biết là mâu thuẫn với thay đổi trong phạm vi được phép sửa.

### Chọn đúng nơi cập nhật

| Nội dung thay đổi | File skill cần đối chiếu và cập nhật khi bị ảnh hưởng |
| --- | --- |
| Phạm vi skill, trigger, workflow hoặc quy tắc tích hợp chung | `skills/flutter-qa-inspector/SKILL.md` |
| Khả năng, giới hạn, public API hoặc dữ liệu selection | `skills/flutter-qa-inspector/references/capabilities.md` |
| Dependency, host, observer/recorder, build flag, QA/production | `skills/flutter-qa-inspector/references/integration.md` |
| Marker widget/page, BLoC/Cubit, local State hoặc snapshot | `skills/flutter-qa-inspector/references/widget-page.md` |
| Capture, preview, editor, tọa độ, annotation hoặc xuất PNG | `skills/flutter-qa-inspector/references/screenshots.md` |
| Contract ZIP, schema report hoặc cách diễn giải evidence | `skills/flutter-qa-inspector/references/bug-reports.md` và `skills/flutter-qa-inspector/scripts/read_bug_report.py` |
| Tên hiển thị hoặc mô tả skill trong UI | `skills/flutter-qa-inspector/agents/openai.yaml` |

- Bảng này là điểm bắt đầu; một thay đổi có thể ảnh hưởng nhiều file hoặc nhiều skill trong `skills/`.
- Giữ `SKILL.md` ngắn gọn; đưa hướng dẫn chi tiết vào reference phù hợp. Không tạo API hoặc snippet không tồn tại trong source.
- Thay đổi chỉ liên quan chính tả, format hoặc quản trị repo có thể kết luận không cần cập nhật skill nếu không đổi ý nghĩa, hành vi hay cách sử dụng.

## Kiểm tra phù hợp với thay đổi

Với thay đổi code package, chạy từ thư mục package:

```sh
cd flutter_qa_inspector
flutter analyze
flutter test
flutter test --dart-define=FLUTTER_QA_INSPECTOR=true
```

- Hai lệnh test kiểm tra hai build mode khác nhau. Test QA có thể bị skip khi thiếu define; không coi một lần chạy là đã kiểm tra cả hai mode.
- Nếu sửa example, chạy `flutter analyze` và `flutter test` từ `flutter_qa_inspector/example/`; chạy thêm mode QA khi hành vi liên quan cần define.
- Chạy `dart format` trên các file Dart đã sửa, tránh format lan sang file không liên quan.
- Nếu sửa script đọc report, kiểm tra bằng bundle phù hợp với contract thay đổi và trường hợp lỗi liên quan; không ghi dữ liệu nhạy cảm vào output kiểm tra.
- Thay đổi chỉ có tài liệu: kiểm tra nội dung, đường dẫn/link và `git diff --check`; không cần chạy Flutter test nếu không có code/snippet thay đổi cần xác minh.
- Phân biệt rõ static check, test và runtime evidence. Báo chính xác kiểm tra đã chạy, kết quả, phần chưa kiểm tra và lý do; không khẳng định đã tái hiện bug chỉ từ source hoặc report.

## Nội dung bàn giao bắt buộc

Nêu thay đổi chính, kết quả kiểm tra và **Skill impact** theo một trong hai dạng:

- `Skill impact: UPDATED` — liệt kê file trong `skills/` đã cập nhật và nội dung cần đồng bộ với hành vi mới.
- `Skill impact: NOT_NEEDED` — nêu lý do cụ thể và file skill đã đối chiếu; với thay đổi thuần quản trị/tài liệu không liên quan cách dùng, nêu rõ phạm vi đó.

Nếu cần cập nhật skill nhưng chưa thực hiện được, phải báo rõ file/nội dung còn thiếu và trở ngại; không dùng `NOT_NEEDED` để bỏ qua việc đồng bộ.
