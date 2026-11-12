# Tích hợp vào host app

## Dependency và build flag

Package trong repo có `publish_to: none`; không giả định đã có version trên pub.dev. Dùng path đúng từ `pubspec.yaml` của host, hoặc Git source/ref thực tế mà project cung cấp. Ví dụ host nằm cạnh thư mục package:

```yaml
dependencies:
  flutter:
    sdk: flutter
  flutter_bloc: ^9.1.1
  bloc: ^9.2.0
  flutter_qa_inspector:
    path: ../flutter_qa_inspector
```

Contract hiện tại: Dart `>=3.3.0 <4.0.0`, Flutter `>=3.19.0`; `bloc ^9.2.0` ở ví dụ trên để dùng `MultiBlocObserver`. Kiểm tra SDK và lockfile của host khi resolve, không nâng các dependency khác chỉ để khớp đoạn YAML. Nếu không cần timeline thì không cần thêm `bloc` chỉ để import `MultiBlocObserver`.

Nếu host dùng `bloc` cũ chưa có `MultiBlocObserver`, giữ cơ chế composition observer hiện có hoặc ghép delegate vào observer của app với đầy đủ các hooks cần ghi. Không thay mất observer hiện tại; không dùng API `MultiBlocObserver` khi version chưa hỗ trợ.

```sh
flutter pub get
flutter run --dart-define=FLUTTER_QA_INSPECTOR=true
flutter build ipa --dart-define=FLUTTER_QA_INSPECTOR=true
```

Lệnh IPA là ví dụ artifact QA khi project có target iOS. Dùng đúng flavor, entrypoint và Flutter/FVM runner sẵn có của host. Define là compile-time: sau khi đổi cần chạy/build lại, hot reload không đổi nó. Với VS Code, thêm define vào `toolArgs` của configuration QA, không đưa vào configuration production.

## Host và timeline

Ví dụ standalone dưới đây minh họa public API. Khi ghép vào app thật, giữ bootstrap, theme, localization, routes và providers đang có; chỉ thêm observer/host vào đúng điểm. `debugPrint` ở đây chỉ để xem payload demo, app thật nối callback với flow báo lỗi của mình.

```dart
import 'dart:convert';

import 'package:bloc/bloc.dart';
import 'package:flutter/material.dart';
import 'package:flutter_qa_inspector/flutter_qa_inspector.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  BugStateRecorder? recorder;
  if (BugInspector.enabledFromEnvironment) {
    // Cài một lần, trước bootstrap tạo BLoC/Cubit của app.
    recorder = BugStateRecorder();
    Bloc.observer = MultiBlocObserver(
      observers: [
        Bloc.observer,
        BugInspectorBlocObserver(recorder: recorder),
      ],
    );
  }

  runApp(
    MaterialApp(
      builder: (context, child) => BugInspector(
        stateRecorder: recorder,
        onWidgetSelected: (widgetContext, selection) {
          // Thay log demo bằng flow báo lỗi hiện có của host.
          debugPrint(jsonEncode(selection.toJson()));
        },
        // child giữ Navigator/Router của MaterialApp.
        child: child ?? const SizedBox.shrink(),
      ),
      home: const BugInspectablePage(
        id: 'home',
        sourceFile: 'lib/main.dart',
        child: Scaffold(body: Center(child: Text('QA example'))),
      ),
    ),
  );
}
```

`MaterialApp.router` cũng đặt host trong `builder` và giữ nguyên `routerConfig` đang có. Nếu builder cũ đã bọc child, ghép inspector quanh nội dung đó, giữ các ancestor/context mà app cần. Không thay `child` bằng page cố định; không tạo host riêng cho mỗi marker.

Recorder không bắt buộc cho snapshot: `stateRecorder: null` cho `stateHistory` rỗng nhưng `BugBlocScope` và `BugInspectableState` vẫn capture lúc chọn. Khi cần history, dùng cùng instance recorder ở host và observer; không tạo recorder trong `build`.

## Menu QA, ownership và options

- Mặc định host có launcher nổi. Chỉ đặt `showLauncher: false` khi app đã có lối bật inspector khác; từ context dưới host gọi `BugInspector.maybeModeCubitOf(context)?.enable()`. Có thể dùng accessor nullable để ẩn menu khi inspector không có.
- Không truyền `modeCubit`: host tự tạo/close. Nếu truyền một `InspectModeCubit` có sẵn, app sở hữu và close nó; dùng cùng instance cho host và menu.
- `enabled` mặc định `true` nhưng vẫn phụ thuộc compile-time define. Nếu dùng `enabled: false` theo flavor, quyết định trước `runApp` và giữ ổn định; đổi lúc app đang chạy dựng lại app content, mất route stack/state. Điều khiển mode/launcher cho thay đổi runtime.
- `disableModeOnSelection` mặc định `true`: mode tắt trước callback. Nếu đặt `false`, tắt mode bằng accessor trước khi mở form hoặc chụp ảnh, nếu không overlay còn chặn tap và ảnh còn border.
- `selectionTrigger` mặc định `BugSelectionTrigger.tapUp`; `tapDown` chọn ngay khi đặt ngón tay, kể cả trước khi kéo.
- `historyWindow` mặc định 30 giây; `BugStateRecorder(maxRecords: ...)` kiểm soát giới hạn queue. Tăng cửa sổ không khôi phục các record đã bị queue loại.
- Có thể chỉnh `floatingAlignment`, `selectionHint`, `pageButtonLabel`, `showPageButton`, `selectPageOnEmptyTap` và border qua host. Đưa các chuỗi tùy chỉnh theo hệ localization của app.

Callback nhận context của marker, thuận tiện tìm Navigator chứa widget. Khi mở báo lỗi toàn app, dùng root navigator nếu phù hợp với routing của host. Sau `await`, kiểm tra `widgetContext.mounted`. Nếu cần ảnh, [chụp trước khi mở form](screenshots.md), không tự chụp form đã mở.

`BugWidgetSelectedCallback` trả `FutureOr<void>`. Khi mở report async, return future của route (hoặc `await Navigator.push` trong callback async) cho tới khi form đóng; host ẩn launcher trong thời gian future còn chạy. Nếu gọi async mà bỏ future rồi return ngay, launcher vẫn có thể che report.

## Production và kiểm tra

Build production không truyền `FLUTTER_QA_INSPECTOR=true` (hoặc truyền `false`). Giữ recorder/observer và các phần QA do app tạo trong nhánh `BugInspector.enabledFromEnvironment` nếu muốn compiler bỏ chúng. Wrapper không chặn được việc evaluate đối số của app: `BugBlocScope(bloc: context.read<T>())` vẫn chạy `read` ở production, nên ưu tiên `.lazy`.

Với source package trong repo, chạy các kiểm tra sau từ thư mục `flutter_qa_inspector/` khi cần verify thay đổi code package, không phải từ root chứa `skills/`:

```sh
flutter analyze
flutter test
flutter test --dart-define=FLUTTER_QA_INSPECTOR=true
```

Hai lệnh test chạy các nhóm build mode khác nhau và skip nhóm còn lại. Với tích hợp chỉ ở host app, ưu tiên checks của host và các test ảnh hưởng trực tiếp.

Nguồn: [main example](../../../flutter_qa_inspector/example/lib/main.dart), [app builder và callback](../../../flutter_qa_inspector/example/lib/app.dart), [host API](../../../flutter_qa_inspector/lib/src/bug_inspector.dart).
