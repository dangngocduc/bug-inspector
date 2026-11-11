# Triển khai `flutter_qa_inspector` trên Flutter

Tài liệu dựa trên mã nguồn `flutter_qa_inspector` v0.1.0. Package giúp tester chọn widget trên QA build và đính kèm thông tin widget, state BLoC/Cubit và timeline vào bug report.

## 1. Luồng báo bug

1. Tester tái hiện lỗi, sau đó mở menu QA và gọi `context.read<InspectModeCubit>().enable()`.
2. Inspector vẽ viền quanh các `BugInspectable`. Overlay tiếp nhận thao tác chạm và chặn thao tác pointer của app, kể cả cuộn màn hình.
3. Tester chạm vào bên trong vùng có viền. Inspector xác định widget, lấy bounds, đọc state BLoC/Cubit tại thời điểm chọn và lấy lịch sử gần nhất. Chạm ngoài các vùng giữ nguyên chế độ chọn.
4. Inspector tắt chế độ chọn theo mặc định rồi gọi `onWidgetSelected(widgetContext, selection)`. App dùng callback để mở form và đính kèm dữ liệu báo bug. Tester có thể bấm nút thoát để hủy bước chọn.

## 2. Cấu trúc package và API

Package hiện khai báo Dart `>=3.3.0 <4.0.0`, Flutter `>=3.19.0` và `flutter_bloc: ^9.1.1` trong `pubspec.yaml`. Nếu tạo package từ đầu, dùng `flutter create --template=package flutter_qa_inspector`, rồi khai báo dependency và các thành phần dưới đây.

| File | Thành phần | Trách nhiệm |
| --- | --- | --- |
| `lib/flutter_qa_inspector.dart` | Entry point | Khai báo các file `part`. App import `package:flutter_qa_inspector/flutter_qa_inspector.dart`. |
| `lib/src/inspect_mode_cubit.dart` | `InspectModeCubit` | Quản lý `InspectMode.disabled` và `InspectMode.selecting` qua `enable()`, `disable()`, `toggle()`. |
| `lib/src/bug_inspector.dart` | `BugInspector` | Cung cấp Cubit, giữ registry riêng cho subtree, hiển thị overlay và gọi callback khi chọn widget. |
| `lib/src/bug_inspectable.dart` | `BugInspectable` | Đăng ký widget qua `id`, tính bounds và vẽ viền theo state của Cubit. Hỗ trợ `label`, `sourceFile`, `sourceLine`, `borderColor` và `borderWidth`. |
| `lib/src/bug_bloc_scope.dart` | `BugBlocScope<State>` | Gắn instance BLoC/Cubit và hàm `snapshotBuilder` vào subtree để đọc state. |
| `lib/src/bug_state_recorder.dart` | `BugStateRecorder`, `BugInspectorBlocObserver` | Thu thập lịch sử BLoC/Cubit trong bộ nhớ và giới hạn số bản ghi. |
| `lib/src/models.dart` | `BugWidgetSelection`, `BugBlocSnapshot`, `BugStateRecord` | Cung cấp dữ liệu cho callback và chuyển thành map qua `toJson()`. |

`BugInspector` cần `child` và `onWidgetSelected`. Mặc định, nó sở hữu vòng đời của `InspectModeCubit`, hiển thị nút thoát và tắt mode ngay sau khi capture. Khi truyền `modeCubit`, app có thể gọi `modeCubit.enable()` từ ngoài host và chịu trách nhiệm gọi `close()` khi hết vòng đời. Dùng cùng một instance Cubit cho overlay, viền và nút QA. Nếu đặt `disableModeOnSelection: false`, tắt mode trước khi mở form trong Navigator bên dưới overlay.

## 3. Các bước triển khai package

### 3.1. Bật chế độ chọn và tìm widget

1. Đặt `BugInspector` ở `MaterialApp.builder` hoặc `MaterialApp.router` với `builder`, giữ lại `child` của builder để Navigator hoặc Router tiếp tục hoạt động.
2. Mỗi `BugInspectable` đăng ký với registry của host gần nhất trong `didChangeDependencies()` và hủy đăng ký khi chuyển host hoặc `dispose()`. Dùng `BlocSelector` để bật viền của `DecoratedBox` ở foreground mà vẫn giữ nguyên kích thước và padding. Ngoài host, wrapper trả về `child`. Với `Expanded` và `Positioned`, đặt wrapper bên trong `child` của chúng.
3. Khi `selecting`, đặt `AbsorbPointer` quanh app content và một `GestureDetector` phủ lên trên. Đặt nút thoát trên cùng. Khi `disabled`, lớp nhận thao tác biến mất và app nhận tap như bình thường.
4. Đo tại thời điểm chạm. Dùng `GlobalKey` của `DecoratedBox` để lấy `RenderBox` đã layout và còn attached. Chuyển `Offset.zero & renderBox.size` sang tọa độ global qua `MatrixUtils.transformRect(renderBox.getTransformTo(null), localRect)`, rồi so với `details.globalPosition`. Trong các bounds chứa điểm chạm, chọn diện tích nhỏ nhất. Khi cùng diện tích, ưu tiên widget ở sâu hơn trong tree.
5. Tạo `BugWidgetSelection` từ node được chọn trước khi đổi mode hoặc mở route mới. Dùng `widgetContext` từ callback để tìm Navigator của widget và sử dụng ngay trong callback. Sau một thao tác async, kiểm tra `widgetContext.mounted` trước khi dùng lại context.

Bounds là hình chữ nhật bao ngoài, theo logical pixel. Widget bị che, bị clip hoặc thuộc route đang offstage vẫn có thể lọt vào tập ứng viên của v0.1.0. Bản hiện có dùng `onTapDown`, callback này có thể chạy trước khi Flutter xác nhận tap. Dùng `onTapUp` nếu luồng QA cần xác nhận thao tác chạm trước khi capture.

### 3.2. Lấy state BLoC/Cubit của widget đã chọn

1. Đặt `BugBlocScope<State>` dưới nơi cung cấp instance và trên `BugInspectable`. Lấy instance bằng `context.read<T>()` trong `Builder` hoặc widget con của provider. Lệnh đọc này có thể khởi tạo provider lazy. Với instance được truyền qua `bloc:`, gắn chính instance đó vào scope của khu vực cần inspect.
2. Từ context của `BugInspectable`, gọi `visitAncestorElements` và lấy các `BugBlocScope` trên đường lên tree. Duyệt từ gần đến xa và dùng identity để loại trùng instance. Nếu cùng class có hai instance khác nhau, snapshot giữ cả hai khi cả hai có scope trên đường ancestor.
3. Đọc `bloc.state` đồng bộ rồi gọi `snapshotBuilder`. Chỉ chọn trường phục vụ chẩn đoán, ví dụ `status`, `itemCount`, `isSubmitting` hoặc `errorCode`. Trả về giá trị JSON gồm chuỗi, số hữu hạn, bool, null, list hoặc map có key kiểu chuỗi. Chuyển enum qua `.name` và ngày giờ qua `.toIso8601String()`. Kiểm tra cả giá trị lồng nhau trước khi export.
4. Nếu một `snapshotBuilder` ném lỗi, snapshot của scope đó có `state: {}` và `captureErrorType`. Inspector vẫn thu thập các scope khác.

Danh sách `blocs` phản ánh các scope đã khai báo ở phía trên widget. Khi điều tra bug, đối chiếu thêm với `BlocBuilder`, `BlocSelector` hoặc `context.read<T>()` để biết widget thực sự dùng instance nào.

### 3.3. Ghi lịch sử state

Cài `BugInspectorBlocObserver` trước khi tạo BLoC/Cubit, truyền cùng một `BugStateRecorder` vào observer và host. Giữ observer hiện có của app khi ghép qua `MultiBlocObserver`.

| Nguồn | Bản ghi |
| --- | --- |
| BLoC và Cubit | `created`, `closed`, `error` |
| BLoC | `event` và `transition` từ `onEvent` và `onTransition` |
| Cubit | `change` từ `onChange` |

Recorder lưu timestamp UTC, `instanceId` và tên kiểu tương ứng. Khi QA observer được cài, timeline ghi hoạt động toàn app kể cả trước lúc bật mode. Queue mặc định giữ tối đa 300 bản ghi và bỏ bản ghi cũ nhất khi đầy. Host mặc định lấy 30 giây gần nhất. Dùng `instanceId` để đối chiếu một snapshot với các bản ghi trong cùng phiên chạy. Với Cubit dùng `int` hoặc một class state cố định, tên kiểu có thể giống nhau qua nhiều lần thay đổi. Giá trị tại thời điểm chọn nằm trong `blocs[].state`.

### 3.4. Rà soát mã v0.1.0 trước khi build

Trong `createSelection()`, mã hiện có truy cập `registry.historyWindow` qua một biến nullable. Kiểm tra null trên `registry` trước khi đọc `historyWindow` và dùng chung timestamp cho snapshot và cutoff của timeline.

```dart
final capturedAtUtc = DateTime.now().toUtc();
final registry = _registry;
final stateHistory = registry == null
    ? const <BugStateRecord>[]
    : (registry.stateRecorder?.recordsSince(
          registry.historyWindow,
          nowUtc: capturedAtUtc,
        ) ??
        const <BugStateRecord>[]);
```

Truyền hai biến trên vào `BugWidgetSelection(capturedAtUtc: capturedAtUtc, stateHistory: stateHistory, ...)`. Nếu giữ ví dụ dùng `MultiBlocObserver`, kiểm tra `bloc` resolve từ 9.2.0 trở lên. Dependency `flutter_bloc` có thể cho phép lockfile cũ giữ `bloc` 9.0.x hoặc 9.1.x.

## 4. Tích hợp vào app Flutter

Thêm dependency vào `pubspec.yaml` của app. Điều chỉnh đường dẫn theo repo. Khai báo `bloc` để bảo đảm phiên bản có `MultiBlocObserver` cho ví dụ.

```yaml
dependencies:
  flutter:
    sdk: flutter
  bloc: ^9.2.0
  flutter_bloc: ^9.1.1
  flutter_qa_inspector:
    path: ../flutter_qa_inspector
```

Ví dụ dưới đây dùng một Cubit đếm số lần nhấn. Nút **Inspect** chỉ xuất hiện khi app được build với `QA_INSPECTOR=true`. Trong app có sẵn `MaterialApp.builder`, ghép `BugInspector` với các wrapper đang dùng và giữ `child` của builder.

```dart
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_qa_inspector/flutter_qa_inspector.dart';

const qaInspectorEnabled = bool.fromEnvironment('QA_INSPECTOR');

void main() {
  final recorder = qaInspectorEnabled ? BugStateRecorder() : null;
  if (recorder != null) {
    Bloc.observer = MultiBlocObserver(
      observers: [
        Bloc.observer,
        BugInspectorBlocObserver(recorder: recorder),
      ],
    );
  }

  runApp(
    MaterialApp(
      builder: (context, child) {
        final appContent = child ?? const SizedBox.shrink();
        if (!qaInspectorEnabled) return appContent;

        return BugInspector(
          stateRecorder: recorder,
          child: appContent,
          onWidgetSelected: (widgetContext, selection) {
            final report = const JsonEncoder.withIndent('  ')
                .convert(selection.toJson());
            showModalBottomSheet<void>(
              context: widgetContext,
              builder: (_) => SafeArea(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: SelectableText(report),
                ),
              ),
            );
          },
        );
      },
      home: BlocProvider<CounterCubit>(
        create: (_) => CounterCubit(),
        child: const CounterPage(),
      ),
    ),
  );
}

class CounterCubit extends Cubit<int> {
  CounterCubit() : super(0);

  void increment() => emit(state + 1);
}

class CounterPage extends StatelessWidget {
  const CounterPage({super.key});

  @override
  Widget build(BuildContext context) {
    final content = Scaffold(
      appBar: AppBar(
        title: const Text('Counter'),
        actions: [
          if (qaInspectorEnabled)
            TextButton(
              onPressed: () => context.read<InspectModeCubit>().enable(),
              child: const Text('Inspect'),
            ),
        ],
      ),
      body: Center(
        child: BlocBuilder<CounterCubit, int>(
          builder: (context, value) => BugInspectable(
            id: 'counter.increment',
            sourceFile: 'lib/main.dart',
            child: FilledButton(
              onPressed: context.read<CounterCubit>().increment,
              child: Text('Tăng ($value)'),
            ),
          ),
        ),
      ),
    );

    if (!qaInspectorEnabled) return content;

    return BugBlocScope<int>(
      id: 'counter_cubit',
      bloc: context.read<CounterCubit>(),
      snapshotBuilder: (value) => {'value': value},
      child: content,
    );
  }
}
```

Chạy tại thư mục app đã có cấu hình Android hoặc iOS.

```sh
flutter pub get
flutter analyze
flutter run --dart-define=QA_INSPECTOR=true
```

Nhấn **Tăng** hai lần, nhấn **Inspect**, rồi chạm vào nút **Tăng** đang có viền. Form hiển thị `id: counter.increment` và snapshot `value: 2`. Thao tác chọn widget giữ nguyên giá trị đếm. Dùng cùng cờ `--dart-define` trong lệnh build QA của CI.

## 5. Payload và ảnh đính kèm

Ví dụ rút gọn của `selection.toJson()`. `source.line` xuất hiện khi truyền `sourceLine`. `blocs` và `stateHistory` có thể là mảng rỗng.

```json
{
  "id": "counter.increment",
  "widgetType": "FilledButton",
  "source": {
    "file": "lib/main.dart"
  },
  "bounds": {
    "left": 142.0,
    "top": 388.0,
    "width": 108.0,
    "height": 48.0,
    "coordinateUnit": "logical_pixels"
  },
  "capturedAtUtc": "2026-11-11T07:40:03.123Z",
  "blocs": [
    {
      "id": "counter_cubit",
      "type": "CounterCubit",
      "instanceId": "2a3b4c",
      "stateType": "int",
      "state": {
        "value": 2
      }
    }
  ],
  "stateHistory": [
    {
      "timestampUtc": "2026-11-11T07:40:01.712Z",
      "kind": "change",
      "blocType": "CounterCubit",
      "instanceId": "2a3b4c",
      "fromStateType": "int",
      "toStateType": "int"
    }
  ]
}
```

App có thể thêm mô tả bug, route, app version, build number, Git SHA và ảnh vào report chứa payload này. Dùng ID ổn định như `home.quick_add_water` và đường dẫn tương đối từ repo. Khi cần tra code theo bản build, CI có thể tạo bảng ánh xạ `(gitSha, widgetId) → file, line`. v0.1.0 nhận `sourceFile` và `sourceLine` trực tiếp từ app.

Nếu app cần tự chụp ảnh, đặt `RepaintBoundary` có `GlobalKey` quanh nội dung app bên dưới overlay. Tại callback, chụp boundary đã paint qua `RenderRepaintBoundary.toImage(pixelRatio: ...)` và encode PNG trước khi mở form. Để có ảnh sạch, chờ frame sau khi viền inspect đã tắt. Khi vẽ lại vùng lỗi trên PNG, đổi bounds global sang hệ tọa độ của boundary rồi nhân theo `pixelRatio` đã chọn. Ghi thời điểm chụp ảnh riêng nếu ảnh và snapshot ở hai frame khác nhau.

## 6. Tiêu chí nghiệm thu

| Ca kiểm tra | Kết quả mong đợi |
| --- | --- |
| Build không bật cờ QA | App mở bình thường, menu inspect ẩn và observer QA không được đăng ký. |
| Gọi `enable()` | Viền xuất hiện, bố cục giữ nguyên, nút và vùng cuộn của app ngừng nhận pointer. |
| Gọi `disable()` hoặc bấm nút thoát | Viền biến mất và app nhận thao tác lại. |
| Chạm vùng trống và chạm widget lồng nhau | Vùng trống giữ mode. Vùng chồng nhau theo quy tắc diện tích nhỏ nhất và ưu tiên độ sâu khi bằng nhau. |
| Chọn widget có nút bấm | Callback nhận đúng `id`, bounds và thời điểm capture. Nút nghiệp vụ giữ nguyên state trong lần chạm để chọn. |
| Widget có nhiều scope | Snapshot lấy đúng state hiện tại và loại trùng theo instance. Một scope serialize lỗi vẫn trả được các snapshot còn lại. |
| BLoC và Cubit thay đổi trước khi bật inspect | Timeline có loại record tương ứng. Dữ liệu nằm trong giới hạn số lượng và cửa sổ thời gian. Observer của app tiếp tục nhận callback. |
| QA build Android và iOS | Luồng bật mode, chọn widget và mở form chạy được trên thiết bị QA với cấu hình build của dự án. |

Sau khi thêm test với `flutter_test`, chạy `flutter test` và `flutter analyze` tại package root. Các ca trên là tiêu chí kiểm thử. Flutter SDK chưa có trong môi trường xuất tài liệu nên analyzer và app chưa được chạy tại đây.

## Tham chiếu

- [Flutter — MaterialApp.builder](https://api.flutter.dev/flutter/material/MaterialApp/builder.html)
- [Flutter — RenderObject.getTransformTo](https://api.flutter.dev/flutter/rendering/RenderObject/getTransformTo.html)
- [Flutter — GestureDetector.onTapDown](https://api.flutter.dev/flutter/widgets/GestureDetector/onTapDown.html)
- [Flutter — RenderRepaintBoundary.toImage](https://api.flutter.dev/flutter/rendering/RenderRepaintBoundary/toImage.html)
- [BLoC — Changelog và phiên bản thêm MultiBlocObserver](https://pub.dev/packages/bloc/changelog)
- [Dart — Truy cập biến nullable](https://dart.dev/tools/diagnostics/unchecked_use_of_nullable_value)
