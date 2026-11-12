# flutter_qa_inspector

Tester chọn một widget hoặc cả màn hình trên bản QA, package trả về thông tin widget/màn hình, state BLoC/Cubit và state của widget (`State` của `StatefulWidget`) tại thời điểm chọn, cùng timeline state gần nhất để đính kèm vào bug report.

- Dart `>=3.3.0 <4.0.0`, Flutter `>=3.19.0`, `flutter_bloc: ^9.1.1`.
- Ví dụ dùng `MultiBlocObserver` cần `bloc` từ 9.2.0 trở lên.
- Chỉ chạy khi build với `--dart-define=FLUTTER_QA_INSPECTOR=true`. Thiếu define hoặc `=false` thì package không làm gì và gần như không có mặt trong binary, xem [Bản production](#bản-production).

## Luồng báo bug

1. Tester tái hiện lỗi rồi bấm nút bug nổi trên cùng app (hoặc app gọi `BugInspector.maybeModeCubitOf(context)?.enable()` từ menu QA của mình).
2. Mọi `BugInspectable` có viền hồng, mọi `BugInspectablePage` có viền xanh. App ngừng nhận pointer (tap, cuộn, hover).
3. Nút bug nổi mở ra thành thanh công cụ nổi. Tester chạm vào một vùng có viền để chọn widget, hoặc bấm **Select screen** trên thanh công cụ để chọn cả màn hình hiện tại. Inspector đo bounds, đọc state BLoC/Cubit và state của widget, rồi lấy timeline. Chạm ra ngoài các widget thì giữ nguyên chế độ chọn.
4. Inspector tắt chế độ chọn (mặc định) rồi gọi `onWidgetSelected(widgetContext, selection)`. Nút ✕ trên thanh công cụ cho phép hủy.

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
void main() {
  BugStateRecorder? recorder;
  // Hằng số: bản build không có define sẽ bỏ hẳn nhánh này.
  if (BugInspector.enabledFromEnvironment) {
    // Cài observer trước khi tạo BLoC/Cubit và giữ observer sẵn có của app.
    recorder = BugStateRecorder();
    Bloc.observer = MultiBlocObserver(
      observers: [Bloc.observer, BugInspectorBlocObserver(recorder: recorder)],
    );
  }

  runApp(
    MaterialApp(
      // Không cần if: thiếu define thì BugInspector chỉ trả về child.
      builder: (context, child) => BugInspector(
        stateRecorder: recorder,
        onWidgetSelected: (widgetContext, selection) {
          // Mở form báo lỗi với selection.toJson().
        },
        // Giữ child của builder để Navigator/Router tiếp tục hoạt động.
        child: child ?? const SizedBox.shrink(),
      ),
      home: const HomePage(),
    ),
  );
}
```

Đánh dấu widget và gắn state:

```dart
BugBlocScope<CartState>.lazy(
  id: 'cart_cubit',
  // Chỉ chạy khi tester chọn widget, không chạy lúc build.
  readBloc: (context) => context.read<CartCubit>(),
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

Lấy state của widget: Dart không tự đọc được field của `State`, nên `State` khai báo các field cần đưa vào bug report qua mixin `BugInspectableState`:

```dart
class _CheckoutPageState extends State<CheckoutPage>
    with BugInspectableState {
  final _promoCode = TextEditingController();
  var _step = 0;
  var _acceptedTerms = false;

  // Chỉ chạy khi tester chọn widget hoặc màn hình.
  @override
  Object? bugSnapshot() => {
        'step': _step,
        'acceptedTerms': _acceptedTerms,
        'promoCode': _promoCode.text,
      };

  // initState, dispose, build như bình thường.
}
```

Khi chọn một `BugInspectable` hoặc `BugInspectablePage`, `selection.widgetStates` chứa snapshot của mọi `State` có mixin này:

- Bên trong widget/màn hình được chọn, theo thứ tự trong tree. Đây thường là state của chính widget đó, ví dụ `BugInspectable(child: QuantityStepper())` hoặc `BugInspectablePage(child: CheckoutPage())` với widget con là `StatefulWidget`.
- Rồi các `State` phía trên, gần trước. Đây thường là `State` có `build` tạo ra widget được chọn, ví dụ một `BugInspectable` nằm trong `_CheckoutPageState.build`.

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

App không cần thêm nút Inspect vào UI: `BugInspector` tự vẽ một nút bug nổi (xem [Widget nổi](#widget-nổi)). Nếu app đã có menu QA riêng, đặt `showLauncher: false` và gọi:

```dart
BugInspector.maybeModeCubitOf(context)?.enable();
```

`maybeModeCubitOf` trả về `null` trên bản production, tiện để ẩn mục menu. Đừng dùng `context.read<InspectModeCubit>()`: trên bản production không có Cubit nên lệnh này ném lỗi.

Chạy bản QA:

```sh
flutter run --dart-define=FLUTTER_QA_INSPECTOR=true
flutter build ipa --dart-define=FLUTTER_QA_INSPECTOR=true   # bản QA/TestFlight
```

## Bản production

Define `FLUTTER_QA_INSPECTOR` là công tắc chính của package, đọc qua hằng số `BugInspector.enabledFromEnvironment`. Thiếu define hoặc `--dart-define=FLUTTER_QA_INSPECTOR=false` thì package không ảnh hưởng tới app, kể cả khi code tích hợp vẫn nằm nguyên trong app:

| Thành phần | Khi không có define |
| --- | --- |
| `BugInspector` | Chỉ trả về `child`, bất kể `enabled`. Không có nút nổi, không có lớp nào bọc app, không tạo `InspectModeCubit`. |
| `BugInspectable`, `BugInspectablePage` | Chỉ trả về `child`. Không đăng ký, không có render object hay `GlobalKey`. |
| `BugBlocScope.lazy` | Chỉ trả về `child`, không bao giờ gọi `readBloc`. |
| `BugInspectableState` | Mixin không override method nào của `State`, nên `State` chạy như khi không có mixin. `bugSnapshot` không bao giờ được gọi. |
| `BugInspectorBlocObserver` | Không ghi gì, kể cả khi app vẫn cài nó vào `Bloc.observer`. |
| `maybeModeCubitOf`, `captureScreenshot` | Trả về `null`. |
| `BugScreenshotEditor` | Dựng một hộp rỗng. |
| `BugScreenshot.toAnnotatedPng` | Trả về `pngBytes` nguyên vẹn. |

Vì là hằng số, compiler bỏ phần code của inspector khỏi bản build. Đo trên bản release Android arm64 của example: code của package trong `libapp.so` là 0,9 KB khi không có define (chỉ còn 4 widget trả về `child` và thông tin kiểu của mixin `BugInspectableState`) và 46 KB khi có define. Các chuỗi của inspector như `Open bug inspector` cũng không có trong binary, và `bugSnapshot` của app bị bỏ khỏi binary vì không có gì gọi tới.

Cái còn lại trên bản production: mỗi `BugInspectable`, `BugInspectablePage`, `BugBlocScope` và `BugInspector` thêm một element không có render object, nên layout, paint, hit test và semantics giữ nguyên. `test/production_build_test.dart` kiểm tra điều này: một app tích hợp đầy đủ có cùng render tree và semantics tree với app không dùng package.

Những gì package không chặn được, vì là code của app:

- Biểu thức truyền vào `BugBlocScope(bloc: ...)` vẫn chạy mỗi lần build. Ví dụ `context.read<T>()` sẽ tạo provider lazy sớm hơn. Dùng `BugBlocScope.lazy`.
- Code QA của app như `BugStateRecorder()`, `MultiBlocObserver`, form báo lỗi hay `InspectModeCubit` tự tạo. Đặt chúng trong `if (BugInspector.enabledFromEnvironment)` để compiler bỏ đi.
- `context.read<InspectModeCubit>()` ném lỗi trên bản production. Dùng `BugInspector.maybeModeCubitOf(context)`.

Checklist trước khi phát hành:

1. Lệnh build production và CI không truyền `--dart-define=FLUTTER_QA_INSPECTOR=true`.
2. Observer và recorder chỉ được tạo trong nhánh `if (BugInspector.enabledFromEnvironment)`.
3. Dùng `BugBlocScope.lazy` thay cho `BugBlocScope(bloc: context.read<T>())`.

Trên bản QA, `enabled: false` tắt inspector giống như khi không có define, ví dụ cho một flavor. Quyết định giá trị này trước `runApp`: đổi nó lúc app đang chạy sẽ dựng lại nội dung app, mất route stack và state màn hình. Để ẩn công cụ lúc đang chạy, dùng `showLauncher` và `InspectModeCubit`.

## API

| Thành phần | Trách nhiệm |
| --- | --- |
| `InspectModeCubit` | `InspectMode.disabled` / `InspectMode.selecting` qua `enable()`, `disable()`, `toggle()`. Gọi sau `close()` không ném lỗi. |
| `BugInspector` | Cung cấp Cubit, giữ registry riêng cho subtree, vẽ widget nổi và lớp chọn, gọi callback khi chọn. `BugInspector.enabledFromEnvironment` là công tắc chính. |
| `BugInspectable` | Đăng ký widget theo `id`, vẽ viền khi đang chọn. Có `label`, `sourceFile`, `sourceLine`, `borderColor`, `borderWidth`. Không có define hoặc ngoài host thì chỉ trả về `child`. |
| `BugInspectablePage` | Đánh dấu cả màn hình. Cùng tham số như `BugInspectable`, viền riêng và được chọn bằng nút **Select screen**. |
| `BugBlocScope<S>`, `BugBlocScope<S>.lazy` | Gắn instance BLoC/Cubit và `snapshotBuilder` vào subtree. Bản `.lazy` chỉ đọc instance qua `readBloc` khi tester chọn widget. |
| `BugInspectableState` | Mixin cho `State`. `bugSnapshot()` trả về các field của `State` dưới dạng JSON, chỉ được gọi khi tester chọn widget. |
| `BugStateRecorder` | Queue trong bộ nhớ, mặc định 300 bản ghi, bỏ bản ghi cũ nhất khi đầy. |
| `BugInspectorBlocObserver` | Ghi `created`, `closed`, `error` (BLoC và Cubit), `event`, `transition` (BLoC), `change` (Cubit). Bỏ qua `InspectModeCubit`; có `filter` tùy chọn. Lỗi khi ghi (ví dụ `filter` ném lỗi) bị bỏ qua, không lan sang `emit`/`add` của app. |
| `BugWidgetSelection`, `BugBlocSnapshot`, `BugWidgetStateSnapshot`, `BugStateRecord` | Dữ liệu trả về, có `toJson()`. `BugWidgetSelection.kind` là `widget` hoặc `page`. |
| `BugInspector.captureScreenshot` / `BugScreenshot` | Chụp PNG nội dung app (không gồm widget nổi và các lớp của inspector) và đổi bounds sang tọa độ ảnh. |
| `BugScreenshotEditor` | Hiện ảnh chụp và cho tester vẽ, chọn, kéo, đổi kích thước và xóa các khung chữ nhật. `readOnly: true` chỉ hiện ảnh và các khung. |
| `BugScreenshotAnnotationController`, `BugScreenshotAnnotation` | Giữ danh sách khung (tọa độ pixel của ảnh) và khung đang chọn. `toJson()` cho payload. |
| `BugScreenshot.toAnnotatedPng` | Vẽ các khung lên ảnh và trả về PNG mới để đính kèm. |
| `BugInspector.launcherKey`, `exitButtonKey`, `pageButtonKey` | Key của các nút trên widget nổi, dùng cho widget test và integration test. |

Tham số chính của `BugInspector`:

| Tham số | Mặc định | Ghi chú |
| --- | --- | --- |
| `enabled` | `true` | Chỉ có tác dụng khi có define. `false` tắt inspector trên bản QA. Không đổi lúc app đang chạy. |
| `modeCubit` | `null` | `null`: host tự tạo và `close()` Cubit. Truyền vào: app sở hữu và tự `close()`. |
| `stateRecorder` | `null` | Dùng chung instance với `BugInspectorBlocObserver`. |
| `historyWindow` | 30 giây | Cửa sổ thời gian của `stateHistory`. |
| `disableModeOnSelection` | `true` | Nếu `false`, tự tắt mode trước khi mở form trong Navigator bên dưới overlay. |
| `selectionTrigger` | `tapUp` | `tapUp` chỉ chọn khi Flutter đã xác nhận tap (kéo không chọn). `tapDown` chọn ngay khi chạm xuống. |
| `showLauncher` | `true` | Hiện nút bug nổi khi mode đang tắt. Đặt `false` nếu app bật mode từ menu QA riêng. Thanh công cụ nổi luôn hiện khi đang chọn. |
| `floatingAlignment` | giữa cạnh cuối | Vị trí ban đầu của widget nổi, trong safe area. |
| `selectionHint` | `Tap a highlighted widget` | Dòng hướng dẫn trên thanh công cụ. |
| `borderColor`, `borderWidth` | `#FF2D78`, 2 | Giá trị mặc định cho mọi `BugInspectable` bên dưới. |
| `showPageButton`, `pageButtonLabel` | hiện, `Select screen` | Nút chọn màn hình trên thanh công cụ. Chỉ hiện khi có `BugInspectablePage` trên màn hình. |
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

## Widget nổi

Khi có `BugInspector`, một widget nổi nằm trên cùng app, phía trên cả Navigator, dialog và bottom sheet của app:

- Khi mode tắt: nút bug tròn. Bấm để bật inspect mode.
- Khi đang chọn: thanh công cụ gồm dòng hướng dẫn, nút ✕ để thoát và nút **Select screen** (khi có màn hình được đánh dấu).

Widget nổi không ảnh hưởng tới app:

- Không nằm trong cây widget của app (không thuộc Navigator hay Overlay của app) nên không đổi layout, theme hay route của app.
- Chỉ phần diện tích của chính nó nhận tap; tap và thao tác kéo ở chỗ khác vẫn tới app như bình thường.
- Không nhận focus bàn phím và được nhóm với các ô nhập của app, nên bấm vào nó không làm mất focus hay đóng bàn phím.
- `captureScreenshot` không chụp nó.
- Nằm trong safe area và phía trên bàn phím.

Tester kéo được widget nổi tới bất kỳ đâu để không che widget cần chọn. Widget luôn nằm trong màn hình, bám đúng theo ngón tay, và giữ vị trí mới cho cả nút bug lẫn thanh công cụ ở các lần bật sau.

## Chọn cả màn hình

- Màn hình hiện tại là `BugInspectablePage` đang được vẽ và nằm trên cùng: route mới push thắng route bên dưới (route offstage bị bỏ qua), tab ẩn của `IndexedStack` bị bỏ qua, màn hình lồng bên trong (tab trong shell) thắng màn hình chứa nó. Dialog hoặc bottom sheet không phải màn hình nên màn hình bên dưới vẫn là màn hình hiện tại.
- Nút **Select screen** trên thanh công cụ hiện tên (`label`, hoặc `id`) của màn hình sẽ được chọn. Nút xuất hiện một frame sau khi viền đã vẽ, và ẩn khi không có màn hình nào.
- `blocs` của màn hình gồm các `BugBlocScope` bên trong màn hình (theo thứ tự trong tree), rồi các scope phía trên (gần trước), loại trùng theo instance. Vì vậy có thể đặt `BugInspectablePage` ở route builder, bên ngoài các scope mà page widget tự tạo.
- `bounds` là bounds của màn hình, `widgetType` là kiểu của `child` (ví dụ `CatalogPage`), `routeName` là `RouteSettings.name` của route nếu có.

## State và timeline

- `BugBlocScope` phải nằm dưới nơi cung cấp instance và trên `BugInspectable`. Với `BugBlocScope.lazy`, `readBloc` nhận context của chính scope, nên `context.read<T>()` hoạt động khi scope nằm dưới provider. Hàm này chỉ chạy khi tester chọn widget; nếu provider lazy chưa được tạo thì lúc đó mới tạo. Nếu không đọc được instance, snapshot có `type: unknown` và `captureErrorType`.
- `BugBlocScope(bloc: ...)` nhận instance ngay lúc build. Biểu thức truyền vào chạy cả trên bản production.
- Khi chọn, inspector đi ngược ancestor từ gần đến xa, loại trùng theo identity. Hai instance khác nhau của cùng class đều được giữ.
- `snapshotBuilder` phải trả về giá trị JSON: chuỗi, số hữu hạn, bool, null, list, map có key là chuỗi (kiểm tra cả giá trị lồng nhau). Nếu builder ném lỗi hoặc trả giá trị không hợp lệ, snapshot đó có `state: {}` và `captureErrorType`; các scope khác vẫn được thu thập.
- `blocs` chỉ phản ánh các scope khai báo phía trên widget. Đối chiếu thêm với `BlocBuilder`/`context.read<T>()` để biết widget thực sự dùng instance nào.
- `widgetStates` gồm các `State` có `BugInspectableState` bên trong widget/màn hình được chọn (theo thứ tự trong tree), rồi các `State` phía trên (gần trước). `State` không có mixin, kể cả `State` nội bộ của `TextField` hay `Checkbox`, bị bỏ qua. Mỗi phần tử có `type` (kiểu của `State`, ví dụ `_CheckoutPageState`), `widgetType` (ví dụ `CheckoutPage`) và `state`.
- `bugSnapshot` theo cùng quy tắc JSON như `snapshotBuilder`, được gọi đồng bộ lúc chọn và không được gọi `setState`. Nếu nó ném lỗi hoặc trả giá trị không hợp lệ, phần tử đó có `state: {}` và `captureErrorType`; các `State` khác vẫn được thu thập. Đừng đưa mật khẩu, token hay dữ liệu cá nhân vào snapshot. Khi nhiều instance của cùng một `State` có thể cùng xuất hiện (ví dụ item trong list), thêm một field để phân biệt, như id của item.
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
  "widgetStates": [
    {
      "type": "_CounterPageState", "widgetType": "CounterPage",
      "state": { "step": 1 }
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

`kind` là `page` khi chọn cả màn hình. `route.name` xuất hiện khi route có `RouteSettings.name` (route `home` là `/`). `label` và `source.line` chỉ xuất hiện khi được truyền. `blocs`, `widgetStates` và `stateHistory` có thể rỗng.

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

## Đánh dấu trên ảnh chụp

Tester vẽ khung chữ nhật lên ảnh chụp để chỉ thêm các chỗ khác, ví dụ một nhãn sai hay một icon bị thiếu. App giữ một `BugScreenshotAnnotationController` trong form báo lỗi:

```dart
final annotations = BugScreenshotAnnotationController(); // dispose() cùng form

// Trong form: ảnh xem trước, chạm vào để mở trang vẽ.
GestureDetector(
  onTap: openEditor,
  child: BugScreenshotEditor(
    screenshot: screenshot,
    controller: annotations,
    highlight: selection.bounds, // viền nét đứt, không sửa được
    readOnly: true,
  ),
),
const Text('Chạm vào ảnh để đánh dấu vùng lỗi'),

// Trang vẽ toàn màn hình, dùng chung controller.
BugScreenshotEditor(screenshot: screenshot, controller: annotations)

// Khi gửi:
final png = await screenshot.toAnnotatedPng(annotations.annotations);
final json = {...screenshot.toJson(), 'annotations': annotations.toJson()};
```

Thao tác trong `BugScreenshotEditor`:

- Kéo trên vùng trống của ảnh để vẽ khung mới. Chạm mà không kéo thì không vẽ, và bỏ chọn khung đang chọn.
- Chạm vào khung để chọn. Nếu nhiều khung chồng nhau, khung nhỏ nhất được chọn. Kéo khung để di chuyển.
- Kéo một trong 4 tay nắm ở góc khung đang chọn để đổi kích thước; góc đối diện đứng yên. Kéo qua góc đối diện thì khung lật lại.
- Nút ✕ cạnh khung đang chọn (`BugScreenshotEditor.deleteButtonKey`) xóa khung đó. App cũng có thể gọi `removeSelected()`, `removeAt()` hoặc `clear()` trên controller.
- Khung luôn nằm trong ảnh và nhỏ nhất `minRectSize` (16) logical pixel trên màn hình.

Editor giữ tỉ lệ ảnh và chiếm kích thước lớn nhất mà constraints cho phép. Nó nhận mọi thao tác chạm bắt đầu trên ảnh ngay khi chạm xuống, nên kéo trên ảnh không cuộn list chứa nó: đặt editor tương tác trong một trang riêng và dùng `readOnly: true` cho ảnh xem trước trong form có cuộn. Tọa độ khung là pixel của ảnh (`coordinateUnit: image_pixels`), cùng hệ với `BugScreenshot.toImageRect`. `toAnnotatedPng` vẽ mỗi khung với nét `strokeWidth * pixelRatio` pixel ảnh, nên ảnh xuất ra giống editor khi hiện ảnh bằng kích thước thật của app. Không có khung nào thì `toAnnotatedPng` trả về `pngBytes` mà không encode lại.

## Lưu ý

- Với `Expanded`, `Flexible`, `Positioned`, đặt `BugInspectable` bên trong `child` của chúng. Trong sliver list, đặt trong item builder hoặc `SliverToBoxAdapter`.
- `widgetType` lấy từ `runtimeType`; bản build có `--obfuscate` sẽ cho tên đã rút gọn.
- `widgetContext` dùng ngay trong callback để tìm Navigator. Sau `await`, kiểm tra `widgetContext.mounted`.
- Dùng ID ổn định (`home.quick_add_water`) và đường dẫn tương đối từ repo cho `sourceFile`.

## Phát triển

```sh
flutter pub get
flutter analyze
flutter test                                          # hành vi bản production
flutter test --dart-define=FLUTTER_QA_INSPECTOR=true  # hành vi bản QA

cd example
flutter run --dart-define=FLUTTER_QA_INSPECTOR=true
```

Mỗi lệnh `flutter test` chỉ chạy nhóm test của chế độ đó và bỏ qua (skip) nhóm còn lại, nên CI cần chạy cả hai.
