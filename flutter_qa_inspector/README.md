# flutter_qa_inspector

Tester chọn một widget hoặc cả màn hình trên bản QA, package trả về thông tin widget/màn hình, state BLoC/Cubit tại thời điểm chọn và timeline state gần nhất để đính kèm vào bug report.

- Dart `>=3.3.0 <4.0.0`, Flutter `>=3.19.0`, `flutter_bloc: ^9.1.1`.
- Ví dụ dùng `MultiBlocObserver` cần `bloc` từ 9.2.0 trở lên.

## Luồng báo bug

1. Tester tái hiện lỗi, mở menu QA và gọi `context.read<InspectModeCubit>().enable()`.
2. Mọi `BugInspectable` có viền hồng, mọi `BugInspectablePage` có viền xanh. App ngừng nhận pointer (tap, cuộn, hover).
3. Tester chạm vào một vùng có viền để chọn widget, hoặc bấm nút nổi **Select screen** để chọn cả màn hình hiện tại. Inspector đo bounds, đọc state BLoC/Cubit và lấy timeline. Chạm ra ngoài các widget thì giữ nguyên chế độ chọn.
4. Inspector tắt chế độ chọn (mặc định) rồi gọi `onWidgetSelected(widgetContext, selection)`. Nút thoát cho phép hủy.

## Cài đặt

```yaml
dependencies:
  bloc: ^9.2.0
  flutter_bloc: ^9.1.1
  flutter_qa_inspector:
    path: ../flutter_qa_inspector
```

## Tích hợp

```dart
const qaInspectorEnabled = bool.fromEnvironment('QA_INSPECTOR');

void main() {
  // Cài observer trước khi tạo BLoC/Cubit và giữ observer sẵn có của app.
  final recorder = qaInspectorEnabled ? BugStateRecorder() : null;
  if (recorder != null) {
    Bloc.observer = MultiBlocObserver(
      observers: [Bloc.observer, BugInspectorBlocObserver(recorder: recorder)],
    );
  }

  runApp(
    MaterialApp(
      builder: (context, child) {
        // Giữ child của builder để Navigator/Router tiếp tục hoạt động.
        final appContent = child ?? const SizedBox.shrink();
        if (!qaInspectorEnabled) return appContent;

        return BugInspector(
          stateRecorder: recorder,
          onWidgetSelected: (widgetContext, selection) {
            // Mở form báo lỗi với selection.toJson().
          },
          child: appContent,
        );
      },
      home: const HomePage(),
    ),
  );
}
```

Đánh dấu widget và gắn state:

```dart
BugBlocScope<CartState>(
  id: 'cart_cubit',
  bloc: context.read<CartCubit>(),
  snapshotBuilder: (state) => {
    'status': state.status.name,          // enum -> .name
    'itemCount': state.items.length,
    'updatedAt': state.updatedAt?.toIso8601String(), // DateTime -> ISO
  },
  child: BugInspectable(
    id: 'cart.checkout',
    sourceFile: 'lib/cart/cart_page.dart',
    sourceLine: 42,
    child: FilledButton(onPressed: checkout, child: const Text('Thanh toán')),
  ),
)
```

Đánh dấu màn hình, trong page widget hoặc ngay trong route builder:

```dart
MaterialPageRoute<void>(
  settings: const RouteSettings(name: '/catalog'),
  builder: (_) => const BugInspectablePage(
    id: 'catalog',
    label: 'Danh mục',
    sourceFile: 'lib/catalog/catalog_page.dart',
    child: CatalogPage(),
  ),
)
```

Với go_router: `builder: (context, state) => BugInspectablePage(id: 'catalog', child: CatalogPage())`.

Nút vào chế độ inspect:

```dart
TextButton(
  onPressed: () => context.read<InspectModeCubit>().enable(),
  child: const Text('Inspect'),
)
```

`BugInspector.maybeModeCubitOf(context)` trả về `null` khi không có host, tiện để ẩn nút trên bản không bật QA.

Chạy bản QA:

```sh
flutter run --dart-define=QA_INSPECTOR=true
```

## API

| Thành phần | Trách nhiệm |
| --- | --- |
| `InspectModeCubit` | `InspectMode.disabled` / `InspectMode.selecting` qua `enable()`, `disable()`, `toggle()`. Gọi sau `close()` không ném lỗi. |
| `BugInspector` | Cung cấp Cubit, giữ registry riêng cho subtree, hiển thị overlay, nút thoát, gọi callback khi chọn. |
| `BugInspectable` | Đăng ký widget theo `id`, vẽ viền khi đang chọn. Có `label`, `sourceFile`, `sourceLine`, `borderColor`, `borderWidth`. Ngoài host chỉ trả về `child`. |
| `BugInspectablePage` | Đánh dấu cả màn hình. Cùng tham số như `BugInspectable`, viền riêng và được chọn bằng nút **Select screen**. |
| `BugBlocScope<S>` | Gắn instance BLoC/Cubit và `snapshotBuilder` vào subtree. |
| `BugStateRecorder` | Queue trong bộ nhớ, mặc định 300 bản ghi, bỏ bản ghi cũ nhất khi đầy. |
| `BugInspectorBlocObserver` | Ghi `created`, `closed`, `error` (BLoC và Cubit), `event`, `transition` (BLoC), `change` (Cubit). Bỏ qua `InspectModeCubit`; có `filter` tùy chọn. |
| `BugWidgetSelection`, `BugBlocSnapshot`, `BugStateRecord` | Dữ liệu trả về, có `toJson()`. `BugWidgetSelection.kind` là `widget` hoặc `page`. |
| `BugInspector.captureScreenshot` / `BugScreenshot` | Chụp PNG nội dung app (không gồm overlay của inspector) và đổi bounds sang tọa độ ảnh. |

Tham số chính của `BugInspector`:

| Tham số | Mặc định | Ghi chú |
| --- | --- | --- |
| `modeCubit` | `null` | `null`: host tự tạo và `close()` Cubit. Truyền vào: app sở hữu và tự `close()`. |
| `stateRecorder` | `null` | Dùng chung instance với `BugInspectorBlocObserver`. |
| `historyWindow` | 30 giây | Cửa sổ thời gian của `stateHistory`. |
| `disableModeOnSelection` | `true` | Nếu `false`, tự tắt mode trước khi mở form trong Navigator bên dưới overlay. |
| `selectionTrigger` | `tapUp` | `tapUp` chỉ chọn khi Flutter đã xác nhận tap (kéo không chọn). `tapDown` chọn ngay khi chạm xuống. |
| `showExitButton`, `exitButtonLabel`, `exitButtonAlignment`, `exitButtonBuilder` | hiện, giữa phía trên | Tùy biến nút thoát. |
| `borderColor`, `borderWidth` | `#FF2D78`, 2 | Giá trị mặc định cho mọi `BugInspectable` bên dưới. |
| `showPageButton`, `pageButtonLabel`, `pageButtonAlignment` | hiện, `Select screen`, góc dưới cuối | Nút chọn màn hình. Chỉ hiện khi có `BugInspectablePage` trên màn hình. Tester kéo được nút, vị trí mới được giữ cho lần bật sau. |
| `selectPageOnEmptyTap` | `false` | Nếu `true`, chạm ra ngoài mọi widget sẽ chọn màn hình chứa điểm chạm. |
| `pageBorderColor`, `pageBorderWidth` | `#2979FF`, 4 | Giá trị mặc định cho mọi `BugInspectablePage` bên dưới. |

## Quy tắc chọn widget

Tại thời điểm chạm, inspector đo `RenderBox` đã layout và còn attached của mỗi `BugInspectable`, đổi `Offset.zero & size` sang tọa độ global qua `getTransformTo(null)` rồi lọc ứng viên:

1. Bỏ widget không được vẽ trong frame hiện tại: route offstage, con ẩn của `IndexedStack`, `Offstage`, `Opacity` 0.
2. Bỏ phần bị clip bởi ancestor (ví dụ item list đã cuộn ra dưới header). Ứng viên phải chứa điểm chạm trong phần còn nhìn thấy.
3. Ưu tiên widget mà hit test tại điểm chạm chạm tới được. Widget bị dialog, bottom sheet hoặc widget khác che chỉ được chọn khi không còn ứng viên nào khác. Widget nằm dưới `IgnorePointer`/`AbsorbPointer` của app vẫn được tính là chạm tới được.
4. Trong cùng mức ưu tiên, chọn diện tích bounds nhỏ nhất. Bằng diện tích thì ưu tiên widget sâu hơn trong tree.

Các bước 1–3 khắc phục giới hạn của v0.1.0 (widget bị che, bị clip hoặc thuộc route offstage vẫn lọt vào tập ứng viên).

Viền được vẽ bằng một render object riêng ở foreground. Nó giữ nguyên kích thước, padding và hành vi hit test của `child`. `DecoratedBox` foreground, như mô tả của v0.1.0, tự báo hit trên toàn bộ diện tích nên có thể đổi widget nhận tap trên bản QA.

`bounds` là hình chữ nhật bao ngoài theo logical pixel, không tính clip.

## Chọn cả màn hình

- Màn hình hiện tại là `BugInspectablePage` đang được vẽ và nằm trên cùng: route mới push thắng route bên dưới (route offstage bị bỏ qua), tab ẩn của `IndexedStack` bị bỏ qua, màn hình lồng bên trong (tab trong shell) thắng màn hình chứa nó. Dialog hoặc bottom sheet không phải màn hình nên màn hình bên dưới vẫn là màn hình hiện tại.
- Nút **Select screen** hiện tên (`label`, hoặc `id`) của màn hình sẽ được chọn. Nút xuất hiện một frame sau khi viền đã vẽ, và ẩn khi không có màn hình nào.
- `blocs` của màn hình gồm các `BugBlocScope` bên trong màn hình (theo thứ tự trong tree), rồi các scope phía trên (gần trước), loại trùng theo instance. Vì vậy có thể đặt `BugInspectablePage` ở route builder, bên ngoài các scope mà page widget tự tạo.
- `bounds` là bounds của màn hình, `widgetType` là kiểu của `child` (ví dụ `CatalogPage`), `routeName` là `RouteSettings.name` của route nếu có.

## State và timeline

- `BugBlocScope` phải nằm dưới nơi cung cấp instance và trên `BugInspectable`. Lấy instance bằng `context.read<T>()` trong `Builder` hoặc widget con của provider; lệnh này có thể khởi tạo provider lazy.
- Khi chọn, inspector đi ngược ancestor từ gần đến xa, loại trùng theo identity. Hai instance khác nhau của cùng class đều được giữ.
- `snapshotBuilder` phải trả về giá trị JSON: chuỗi, số hữu hạn, bool, null, list, map có key là chuỗi (kiểm tra cả giá trị lồng nhau). Nếu builder ném lỗi hoặc trả giá trị không hợp lệ, snapshot đó có `state: {}` và `captureErrorType`; các scope khác vẫn được thu thập.
- `blocs` chỉ phản ánh các scope khai báo phía trên widget. Đối chiếu thêm với `BlocBuilder`/`context.read<T>()` để biết widget thực sự dùng instance nào.
- Timeline chỉ lưu tên kiểu, không lưu giá trị state. Giá trị tại thời điểm chọn nằm trong `blocs[].state`. Dùng `instanceId` để đối chiếu snapshot với timeline trong cùng phiên chạy.
- Snapshot và cutoff của timeline dùng chung một timestamp (`capturedAtUtc`).

## Payload

```json
{
  "kind": "widget",
  "id": "counter.increment",
  "widgetType": "FilledButton",
  "source": { "file": "lib/main.dart" },
  "bounds": {
    "left": 142.0, "top": 388.0, "width": 108.0, "height": 48.0,
    "coordinateUnit": "logical_pixels"
  },
  "capturedAtUtc": "2026-11-11T07:40:03.123Z",
  "blocs": [
    {
      "id": "counter_cubit", "type": "CounterCubit", "instanceId": "00002a",
      "stateType": "int", "state": { "value": 2 }
    }
  ],
  "stateHistory": [
    {
      "timestampUtc": "2026-11-11T07:40:01.712Z", "kind": "change",
      "blocType": "CounterCubit", "instanceId": "00002a",
      "fromStateType": "int", "toStateType": "int"
    }
  ]
}
```

`kind` là `page` khi chọn cả màn hình. `route.name` xuất hiện khi route có `RouteSettings.name` (route `home` là `/`). `label` và `source.line` chỉ xuất hiện khi được truyền. `blocs` và `stateHistory` có thể rỗng.

## Ảnh chụp màn hình

```dart
onWidgetSelected: (widgetContext, selection) async {
  // Chờ frame không còn viền rồi chụp, trước khi mở form.
  final screenshot = await BugInspector.captureScreenshot(widgetContext);
  if (!widgetContext.mounted) return;
  // screenshot?.pngBytes, screenshot?.toImageRect(selection.bounds)
},
```

`captureScreenshot` chụp `child` của host, không gồm overlay của inspector. Với `disableModeOnSelection: false`, tắt mode trước khi chụp để ảnh không có viền. `BugScreenshot.capturedAtUtc` được ghi riêng vì ảnh được chụp ở frame sau snapshot.

## Lưu ý

- Với `Expanded`, `Flexible`, `Positioned`, đặt `BugInspectable` bên trong `child` của chúng. Trong sliver list, đặt trong item builder hoặc `SliverToBoxAdapter`.
- `widgetType` lấy từ `runtimeType`; bản build có `--obfuscate` sẽ cho tên đã rút gọn.
- `widgetContext` dùng ngay trong callback để tìm Navigator. Sau `await`, kiểm tra `widgetContext.mounted`.
- Dùng ID ổn định (`home.quick_add_water`) và đường dẫn tương đối từ repo cho `sourceFile`.

## Phát triển

```sh
flutter pub get
flutter analyze
flutter test

cd example
flutter run --dart-define=QA_INSPECTOR=true
```
