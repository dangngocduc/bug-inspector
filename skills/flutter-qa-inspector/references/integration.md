# Tích hợp vào host app

## Dependency và build flag

Package trong repo có `publish_to: none`; không giả định đã có version trên pub.dev. Dùng path đúng từ `pubspec.yaml` của host, hoặc Git source/ref thực tế mà project cung cấp. Ví dụ host nằm cạnh thư mục package:

```yaml
dependencies:
  flutter_qa_inspector:
    path: ../flutter_qa_inspector
    # hoặc git: { url: <repo>, path: flutter_qa_inspector, ref: <tag/sha> }
```

Contract `0.9.0` (dependencies không đổi từ `0.8.0`): Dart `>=3.4.0 <4.0.0`, Flutter `>=3.29.0`. Package tự kéo `flutter_bloc ^9.1.1`, `bloc ^9.2.0` (`MultiBlocObserver`), `archive ^4.0.0` (ZIP) và `share_plus >=12.0.0 <14.0.0` (share sheet); host không cần khai báo thêm chỉ để tích hợp. Nếu host đã pin/override `share_plus` hoặc `archive`, kiểm tra version nằm trong range trên; không nâng dependency khác của host chỉ để khớp đoạn YAML. Host đã có `archive` chỉ để dùng cho bản copy form report cũ thì có thể bỏ.

`share_plus` là plugin: native code của nó có trong mọi build của host, kể cả production. Khi host chỉ mở form qua facade, nhánh inspector/form không được gọi khi thiếu define. Báo rõ điểm này nếu host nhạy cảm với kích thước binary hoặc danh sách plugin.

Đối chiếu version trong lockfile với native toolchain trước khi build:

- `share_plus 12.0.0`: iOS 12+, macOS 10.14+; Android cần Java 17, Kotlin 2.2.0, AGP 8.12.1+, Gradle 8.13+.
- `share_plus 13.3.1`: Dart 3.10+, Flutter 3.38.1+, iOS 13+, macOS 10.15+; yêu cầu Android như trên. Pub kiểm tra SDK khi resolve, không tự nâng deployment target native của host.
- Với share sheet mặc định trên iOS, thêm `NSPhotoLibraryAddUsageDescription` vào `ios/Runner/Info.plist` cho action **Save Image**. Package không tự ghi được Info.plist của host. Form đã đặt `sharePositionOrigin` cho popover trên iPad.
- Linux không share file qua plugin; dùng `share:` riêng nếu cần gửi ZIP. Web tùy browser có thể share file hoặc download.

Nguồn yêu cầu theo version: [12.0.0](https://pub.dev/packages/share_plus/versions/12.0.0), [13.3.1](https://pub.dev/packages/share_plus/versions/13.3.1). Với version khác trong range, đọc README/native config đúng bản resolve thay vì áp dụng mức tối thiểu của bản khác.

```sh
flutter pub get
flutter run --dart-define=FLUTTER_QA_INSPECTOR=true
flutter build ipa --dart-define=FLUTTER_QA_INSPECTOR=true
```

Lệnh IPA là ví dụ artifact QA khi project có target iOS. Dùng đúng flavor, entrypoint và Flutter/FVM runner sẵn có của host. Define là compile-time: sau khi đổi cần chạy/build lại, hot reload không đổi nó. Với VS Code, thêm define vào `toolArgs` của configuration QA, không đưa vào configuration production.

## Tích hợp nhanh (mặc định)

Dùng cách này khi host chỉ cần form báo lỗi có sẵn: chụp ảnh, vẽ khung, mô tả, chia sẻ PNG + ZIP. Không tạo file wrapper/form riêng trong host.

```dart
import 'package:flutter/material.dart';
import 'package:flutter_qa_inspector/flutter_qa_inspector.dart';

void main() {
  // Một lần, trước bootstrap tạo BLoC/Cubit. Giữ Bloc.observer đang có.
  FlutterQaInspector.install();
  runApp(const App());
}

class App extends StatelessWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
        // Builder đã bọc widget khác: (context, child) =>
        //     Existing(child: FlutterQaInspector.wrap(child: child!)).
        builder: FlutterQaInspector.builder,
        home: const BugInspectablePage(
          id: 'home',
          sourceFile: 'lib/main.dart',
          child: Scaffold(body: Center(child: Text('QA example'))),
        ),
      );
}
```

- `FlutterQaInspector.install({stateRecorder})`: thiếu define thì không làm gì. Có define thì đặt `Bloc.observer = MultiBlocObserver([observer cũ, BugInspectorBlocObserver])` một lần; gọi lại không cài thêm. `FlutterQaInspector.recorder` là recorder đó. Gọi sau khi BLoC/Cubit đã tạo thì timeline thiếu các record trước đó.
- `FlutterQaInspector.wrap(child:, enabled:, stateRecorder:, strings:, captureScreenshot:, share:)`: thiếu define thì trả nguyên `child`. Có define thì dựng `BugInspector` với recorder của `install` (hoặc `stateRecorder`), mỗi selection chụp ảnh rồi `BugReportPage.open` trên root navigator; launcher ẩn tới khi form đóng. `FlutterQaInspector.builder` là `wrap` với mặc định.
- `strings`: `BugReportStringsBuilder` trả `BugReportStrings` cho cả thanh công cụ (`selectionHint`, `pageButtonLabel`), form và trang vẽ. Mặc định `BugReportStrings.of(context)`: `vi` khi locale tiếng Việt, còn lại `en`. Host có l10n riêng thì map từ hệ đó, ví dụ `strings: (context) => BugReportStrings.en.copyWith(title: S.of(context).bugReportTitle)`; không thêm chuỗi viết cứng vào widget của host.
- `share`: `BugReportShare` (`Future<ShareResult> Function(ShareParams)`), mặc định `SharePlus.instance.share`. Dùng để upload/tạo ticket từ `params.files` (PNG, ZIP) và `params.text`; trả `ShareResultStatus.dismissed` để giữ form, trạng thái khác để đóng; lỗi ném ra hiện dialog. Package export lại `ShareParams`, `ShareResult`, `ShareResultStatus`, `XFile`.
- Route: `BugInspectablePage.route(settings:, child:, sourceFile:)` trong `onGenerateRoute` biến mỗi route có tên thành page chọn được, xem [widget-page.md](widget-page.md).
- `BugReportPage.routeName` là `/qa-bug-report`. Nếu host log/analytics route hoặc có route guard theo tên, loại trừ route này.

Host đã có bản copy `BugReportPage`, `BugReportBundle`, `ScreenshotAnnotationPage` từ example cũ (ví dụ trong `lib/utils/debug/`) sẽ lỗi `ambiguous_import` khi nâng lên `0.8.0`: xóa các file đó, thay wrapper bằng `install`/`wrap`, đổi marker route tự viết sang `BugInspectablePage.route`, và chỉ giữ map `strings` nếu host muốn dùng l10n riêng.

## Host tùy chỉnh và timeline

Dùng `BugInspector` trực tiếp khi host cần form/luồng gửi riêng mà `share:` không đáp ứng. Ví dụ standalone dưới đây minh họa public API. Khi ghép vào app thật, giữ bootstrap, theme, localization, routes và providers đang có; chỉ thêm observer/host vào đúng điểm. `debugPrint` ở đây chỉ để xem payload demo, app thật nối callback với flow báo lỗi của mình, hoặc gọi `BugReportPage.open(widgetContext, selection:, screenshot:, strings:, share:)` để dùng lại form có sẵn.

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

Recorder không bắt buộc cho snapshot: `stateRecorder: null` cho `stateHistory` rỗng nhưng `BugBlocScope` và `BugInspectableWidget` vẫn capture lúc chọn. Khi cần history, dùng cùng instance recorder ở host và observer; không tạo recorder trong `build`.

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

Build production không truyền `FLUTTER_QA_INSPECTOR=true` (hoặc truyền `false`). `FlutterQaInspector.install`/`wrap` đã tự kiểm tra hằng compile-time. Với host tùy chỉnh, giữ recorder/observer và các phần QA do app tạo trong nhánh `BugInspector.enabledFromEnvironment` nếu muốn compiler bỏ chúng. Wrapper không chặn được việc evaluate đối số của app: `BugBlocScope(bloc: context.read<T>())` vẫn chạy `read` ở production, nên ưu tiên `.lazy`.

`BugReportPage`/`BugReportBundle` dùng trực tiếp vẫn dựng form/đóng gói ZIP khi thiếu define; gate lối mở riêng bằng `BugInspector.enabledFromEnvironment`. Không dùng số đo binary trước `0.8.0` làm bằng chứng kích thước hiện tại sau khi thêm dependency plugin.

Với source package trong repo, chạy các kiểm tra sau từ thư mục `flutter_qa_inspector/` khi cần verify thay đổi code package, không phải từ root chứa `skills/`:

```sh
flutter analyze
flutter test
flutter test --dart-define=FLUTTER_QA_INSPECTOR=true
```

Hai lệnh test chạy các nhóm build mode khác nhau và skip nhóm còn lại. Với tích hợp chỉ ở host app, ưu tiên checks của host và các test ảnh hưởng trực tiếp.

Nguồn: [main example](../../../flutter_qa_inspector/example/lib/main.dart), [app builder](../../../flutter_qa_inspector/example/lib/app.dart), [FlutterQaInspector](../../../flutter_qa_inspector/lib/src/flutter_qa_inspector_setup.dart), [BugReportPage](../../../flutter_qa_inspector/lib/src/report/bug_report_page.dart), [BugReportStrings](../../../flutter_qa_inspector/lib/src/report/bug_report_strings.dart), [host API](../../../flutter_qa_inspector/lib/src/bug_inspector.dart).
