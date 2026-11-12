# flutter_qa_inspector

Tester chọn một widget hoặc cả màn hình trên bản QA, package trả về thông tin widget/màn hình, state BLoC/Cubit và state của widget (`State` của `StatefulWidget`) tại thời điểm chọn, cùng timeline state gần nhất để đính kèm vào bug report. Package có sẵn form báo lỗi (`BugReportPage`): vẽ khung lên ảnh chụp, nhập mô tả, rồi chia sẻ ảnh + ZIP qua share sheet.

- Dart `>=3.4.0 <4.0.0`, Flutter `>=3.29.0`.
- Dependencies: `flutter_bloc: ^9.1.1`, `bloc: ^9.2.0` (`MultiBlocObserver`), `archive: ^4.0.0` (ZIP), `share_plus: >=12.0.0 <14.0.0` (share sheet).
- Inspector chỉ bật khi build với `--dart-define=FLUTTER_QA_INSPECTOR=true`. Thiếu define hoặc `=false` thì tích hợp qua facade giữ nguyên app content, xem [Bản production](#bản-production).

## Luồng báo bug

1. Tester tái hiện lỗi rồi bấm nút bug nổi trên cùng app (hoặc app gọi `BugInspector.maybeModeCubitOf(context)?.enable()` từ menu QA của mình).
2. Mọi `BugInspectable` có viền hồng, mọi `BugInspectablePage` có viền xanh. App ngừng nhận pointer (tap, cuộn, hover).
3. Nút bug nổi mở ra thành thanh công cụ nổi. Tester chạm vào một vùng có viền để chọn widget, hoặc bấm **Select screen** trên thanh công cụ để chọn cả màn hình hiện tại. Inspector đo bounds, đọc state BLoC/Cubit và state của widget, rồi lấy timeline. Chạm ra ngoài các widget thì giữ nguyên chế độ chọn.
4. Inspector tắt chế độ chọn (mặc định) rồi gọi `onWidgetSelected(widgetContext, selection)`. Nút ✕ trên thanh công cụ cho phép hủy.
5. Với tích hợp nhanh, callback này chụp màn hình và mở `BugReportPage`. Tester vẽ khung, nhập mô tả rồi bấm **Send** để chia sẻ ảnh và file ZIP.

## Cài đặt

```yaml
dependencies:
  flutter_qa_inspector:
    git:
      url: https://github.com/dangngocduc/bug-inspector
      path: flutter_qa_inspector
```

App không cần tự khai báo `archive` hay `share_plus` nếu không dùng trực tiếp các package đó. `share_plus` là plugin, nên native code của nó vẫn có trong mọi bản build, kể cả production. Khi chỉ mở form qua `FlutterQaInspector`, nhánh mở form bị compiler bỏ khi không có define.

Đối chiếu native toolchain với version `share_plus` được resolve trong lockfile:

- `12.0.0`: iOS 12+, macOS 10.14+; Android cần Java 17, Kotlin 2.2.0, AGP 8.12.1+ và Gradle 8.13+.
- `13.3.1`: Dart 3.10+, Flutter 3.38.1+, iOS 13+, macOS 10.15+; yêu cầu Android như trên. Range dependency cho phép resolver chọn bản phù hợp SDK, nhưng deployment target native vẫn cần kiểm tra riêng.
- iOS: thêm `NSPhotoLibraryAddUsageDescription` vào `ios/Runner/Info.plist` nếu dùng share sheet mặc định để tester có thể chọn **Save Image**. Package không thể tự thêm khóa này vào host. Form đã truyền vị trí nút gửi cho popover trên iPad.
- Linux không hỗ trợ chia sẻ file qua `share_plus`; dùng `share:` riêng để gửi ZIP. Trên web, share file phụ thuộc browser và có thể chuyển sang download.

Yêu cầu theo từng version: [share_plus 12.0.0](https://pub.dev/packages/share_plus/versions/12.0.0), [share_plus 13.3.1](https://pub.dev/packages/share_plus/versions/13.3.1).

## Tích hợp nhanh

Ba chỗ, không cần thêm file nào trong app:

```dart
import 'package:flutter_qa_inspector/flutter_qa_inspector.dart';

void main() {
  // Trước khi tạo BLoC/Cubit nào. Giữ observer sẵn có của app.
  FlutterQaInspector.install();
  runApp(const App());
}

MaterialApp(
  // Hoặc, khi builder còn bọc widget khác:
  // builder: (context, child) => FlutterQaInspector.wrap(child: child!),
  builder: FlutterQaInspector.builder,
  onGenerateRoute: (settings) => MaterialPageRoute<void>(
    settings: settings,
    // Mỗi route là một màn hình chọn được, id = tên route.
    builder: (_) => BugInspectablePage.route(
      settings: settings,
      sourceFile: 'lib/app_navigator.dart',
      child: pageFor(settings),
    ),
  ),
);
```

Sau đó đánh dấu widget bằng `BugInspectable`, gắn state bằng `BugBlocScope` và params của widget bằng `BugInspectableWidget` như phần dưới.

- `FlutterQaInspector.install({stateRecorder})`: cài `MultiBlocObserver(Bloc.observer cũ + BugInspectorBlocObserver)` một lần; `FlutterQaInspector.recorder` là recorder đó. Thiếu define thì không làm gì.
- `FlutterQaInspector.wrap(child:, enabled:, stateRecorder:, strings:, captureScreenshot:, share:)`: dựng `BugInspector` (recorder mặc định là `FlutterQaInspector.recorder`), mỗi lần chọn thì chụp màn hình rồi mở `BugReportPage` trên root navigator. Thiếu define thì trả nguyên `child`.
- `BugInspectablePage.route(settings:, child:, sourceFile:)`: `id` và `label` là `settings.name`, route không tên có id `unnamed_route` (`BugInspectablePage.unnamedRouteId`).

### Chuỗi hiển thị

`BugReportStrings` gồm chuỗi của thanh công cụ (`selectionHint`, `pageButtonLabel`), form và trang vẽ. Package có `BugReportStrings.en` và `.vi`; mặc định `BugReportStrings.of(context)` chọn `vi` khi `Localizations` là tiếng Việt, còn lại là `en`. App có l10n riêng truyền vào:

```dart
FlutterQaInspector.wrap(
  child: child!,
  strings: (context) => BugReportStrings.en.copyWith(
    title: S.of(context).bugReportTitle,
  ),
)
```

### Gửi report đi nơi khác

Mặc định **Send** gọi `SharePlus.instance.share`. Truyền `share:` để upload hoặc tạo ticket: hàm nhận `ShareParams` (`files` gồm PNG và ZIP, `text` là mô tả) và trả `ShareResult`. `ShareResultStatus.dismissed` giữ form mở để gửi lại, trạng thái khác đóng form, lỗi ném ra hiện dialog. `ShareParams`, `ShareResult`, `ShareResultStatus`, `XFile` được export lại nên app không cần import `share_plus`.

### Form báo lỗi và file ZIP

`BugReportPage` (style Cupertino, theme riêng, theo sáng/tối của máy) mở full-screen trên root navigator, có `Navigator` riêng nên Navigator của app chỉ thấy một route (`BugReportPage.routeName`, `/qa-bug-report`). Back đóng trang vẽ trước rồi mới tới form; form có mô tả hoặc khung thì hỏi trước khi bỏ. Gửi tạo `BugReportBundle`:

| File | Nội dung |
| --- | --- |
| `screenshot.png` | Ảnh đã vẽ viền widget được chọn (không viền khi chọn màn hình) và các khung của tester. Chỉ có khi có ảnh chụp. |
| `description.txt` | Mô tả tester nhập, giữ nguyên. |
| `inspector.json` | `{"inspector": selection.toJson(), "screenshot": {...screenshot.toJson(), "annotations": [...]}}`; `screenshot` chỉ có khi có ảnh. |

Tên file là `BugReportBundle.nameFor(selection.id, selection.capturedAtUtc)`, ví dụ `bug_counter.increment_20261112_093005`, share kèm `<name>.png` và `<name>.zip`. Nút **Copy JSON** chép `{"description": ..., ...inspector.json}`. Có thể mở form từ callback của riêng app bằng `BugReportPage.open(widgetContext, selection:, screenshot:, strings:, share:)`.

## Tích hợp tùy chỉnh

Khi app cần form hoặc luồng gửi riêng, dùng trực tiếp `BugInspector` và tự xử lý `onWidgetSelected`:

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
        // Trả về Future của route báo lỗi: nút bug nổi ẩn cho đến khi
        // Future hoàn tất, nên không che form.
        onWidgetSelected: (widgetContext, selection) {
          // Mở form báo lỗi với selection.toJson().
          return Navigator.of(widgetContext).push(/* route báo lỗi */);
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

Lấy params của widget được chọn: selection mô tả `child` của marker. `widgetType` là runtime type của `child`, `widgetState` là params của chính `child` đó. Dart không có reflection để tự đọc field, còn Diagnostics (`debugFillProperties`) chỉ có dữ liệu ở debug build, nên class widget của `child` khai báo params cần đưa vào bug report qua mixin `BugInspectableWidget`:

```dart
class ProductCard extends StatelessWidget with BugInspectableWidget {
  const ProductCard({
    super.key,
    required this.productId,
    required this.inStock,
    this.onAddToCart,
  });

  final String productId;
  final bool inStock;
  final VoidCallback? onAddToCart;

  // Chỉ chạy khi tester chọn widget hoặc màn hình.
  @override
  Map<String, Object?> bugSnapshot() => {
        'productId': productId,
        'inStock': inStock,
        'canAddToCart': onAddToCart != null, // callback -> có hay không
      };

  // build như bình thường.
}

BugInspectable(
  id: 'catalog.product',
  child: ProductCard(productId: product.id, inStock: product.inStock),
)
// selection.widgetType == 'ProductCard'
// selection.widgetState == {'productId': 'p1', 'inStock': true, 'canAddToCart': false}
```

- Chỉ đọc đúng `child` của `BugInspectable`/`BugInspectablePage`: đặt marker sát quanh widget có mixin. Widget có mixin nằm sâu hơn bên trong `child` (ví dụ `BugInspectable(child: Padding(child: ProductCard(...)))`) hoặc phía trên marker không được đọc; khi đó `widgetType` là `Padding` và `widgetState` là `{}`.
- `child` không dùng mixin, kể cả widget của Flutter như `Text` hay `FilledButton`, cho `widgetState: {}`.
- Mixin dùng được cho `StatelessWidget` và `StatefulWidget`, nhưng đọc params của widget (giá trị parent truyền vào), không đọc field của `State`. Giá trị là params tại lúc chọn, sau lần build gần nhất.

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
| `FlutterQaInspector` | `install` không đổi `Bloc.observer`, `recorder` là `null`; `wrap`/`builder` trả về chính `child`. |
| `BugInspector` | Chỉ trả về `child`, bất kể `enabled`. Không có nút nổi, không có lớp nào bọc app, không tạo `InspectModeCubit`. |
| `BugInspectable`, `BugInspectablePage`, `BugInspectablePage.route` | Chỉ trả về `child`. Không đăng ký, không có render object hay `GlobalKey`. |
| `BugBlocScope.lazy` | Chỉ trả về `child`, không bao giờ gọi `readBloc`. |
| `BugInspectableWidget` | Mixin không override method nào của widget, nên widget build như khi không có mixin. `bugSnapshot` không bao giờ được gọi. |
| `BugInspectorBlocObserver` | Không ghi gì, kể cả khi app vẫn cài nó vào `Bloc.observer`. |
| `maybeModeCubitOf`, `captureScreenshot` | Trả về `null`. |
| `BugScreenshotEditor` | Dựng một hộp rỗng. |
| `BugScreenshot.toAnnotatedPng` | Trả về `pngBytes` nguyên vẹn. |

Vì là hằng số, compiler có thể bỏ nhánh inspector và form không được gọi. Các số đo Android arm64 trước `0.8.0` (0,9 KB khi thiếu define, 46 KB khi có define trong `libapp.so` của example) là baseline cũ, chưa đo lại sau khi đưa report và plugin vào package; không dùng chúng làm kích thước binary của bản hiện tại.

Cái còn lại trên bản production: mỗi `BugInspectable`, `BugInspectablePage`, `BugBlocScope` và `BugInspector` thêm một element không có render object, nên layout, paint, hit test và semantics giữ nguyên. `test/production_build_test.dart` kiểm tra điều này: một app tích hợp đầy đủ có cùng render tree và semantics tree với app không dùng package.

Các phần không được compile-time gate tự động:

- Biểu thức truyền vào `BugBlocScope(bloc: ...)` vẫn chạy mỗi lần build. Ví dụ `context.read<T>()` sẽ tạo provider lazy sớm hơn. Dùng `BugBlocScope.lazy`.
- Code QA của app như `BugStateRecorder()`, `MultiBlocObserver`, form báo lỗi riêng hay `InspectModeCubit` tự tạo. Đặt chúng trong `if (BugInspector.enabledFromEnvironment)` để compiler bỏ đi. `FlutterQaInspector` đã tự làm việc này.
- Native code của plugin `share_plus` (dependency của package).
- `BugReportPage` và `BugReportBundle` nếu app chủ động gọi trực tiếp: chúng vẫn dựng form/đóng gói report khi thiếu define. Đặt lối mở riêng trong nhánh `BugInspector.enabledFromEnvironment`; facade đã có gate này.
- `context.read<InspectModeCubit>()` ném lỗi trên bản production. Dùng `BugInspector.maybeModeCubitOf(context)`.

Checklist trước khi phát hành:

1. Lệnh build production và CI không truyền `--dart-define=FLUTTER_QA_INSPECTOR=true`.
2. Observer và recorder chỉ được tạo qua `FlutterQaInspector.install()` hoặc trong nhánh `if (BugInspector.enabledFromEnvironment)`.
3. Dùng `BugBlocScope.lazy` thay cho `BugBlocScope(bloc: context.read<T>())`.

Trên bản QA, `enabled: false` tắt inspector giống như khi không có define, ví dụ cho một flavor. Quyết định giá trị này trước `runApp`: đổi nó lúc app đang chạy sẽ dựng lại nội dung app, mất route stack và state màn hình. Để ẩn công cụ lúc đang chạy, dùng `showLauncher` và `InspectModeCubit`.

## API

| Thành phần | Trách nhiệm |
| --- | --- |
| `FlutterQaInspector` | Tích hợp nhanh: `install()`, `wrap()`, `builder`, `recorder`. |
| `BugReportPage` | Form báo lỗi có sẵn: target, ảnh chụp + trang vẽ, mô tả, JSON, gửi qua `share`. `open()` push lên root navigator. |
| `BugReportBundle`, `BugReportShare` | ZIP `screenshot.png` + `description.txt` + `inspector.json`, `nameFor`, `toZip()`, `toShareParams()`. |
| `BugReportStrings` | Chuỗi của thanh công cụ, form và trang vẽ: `en`, `vi`, `of(context)`, `copyWith`. |
| `InspectModeCubit` | `InspectMode.disabled` / `InspectMode.selecting` qua `enable()`, `disable()`, `toggle()`. Gọi sau `close()` không ném lỗi. |
| `BugInspector` | Cung cấp Cubit, giữ registry riêng cho subtree, vẽ widget nổi và lớp chọn, gọi callback khi chọn. `BugInspector.enabledFromEnvironment` là công tắc chính. |
| `BugInspectable` | Đăng ký widget theo `id`, vẽ viền khi đang chọn. Có `label`, `sourceFile`, `sourceLine`, `borderColor`, `borderWidth`. Không có define hoặc ngoài host thì chỉ trả về `child`. |
| `BugInspectablePage` | Đánh dấu cả màn hình. Cùng tham số như `BugInspectable`, viền riêng và được chọn bằng nút **Select screen**. `BugInspectablePage.route(settings:)` lấy `id`/`label` từ tên route. |
| `BugBlocScope<S>`, `BugBlocScope<S>.lazy` | Gắn instance BLoC/Cubit và `snapshotBuilder` vào subtree. Bản `.lazy` chỉ đọc instance qua `readBloc` khi tester chọn widget. |
| `BugInspectableWidget` | Mixin cho class widget làm `child` của marker. `bugSnapshot()` trả về params của widget dưới dạng JSON object, lưu vào `selection.widgetState`, chỉ được gọi khi tester chọn widget. |
| `BugStateRecorder` | Queue trong bộ nhớ, mặc định 300 bản ghi, bỏ bản ghi cũ nhất khi đầy. |
| `BugInspectorBlocObserver` | Ghi `created`, `closed`, `error` (BLoC và Cubit), `event`, `transition` (BLoC), `change` (Cubit). Bỏ qua `InspectModeCubit`; có `filter` tùy chọn. Lỗi khi ghi (ví dụ `filter` ném lỗi) bị bỏ qua, không lan sang `emit`/`add` của app. |
| `BugWidgetSelection`, `BugBlocSnapshot`, `BugStateRecord` | Dữ liệu trả về, có `toJson()`. `BugWidgetSelection.kind` là `widget` hoặc `page`; `widgetType` và `widgetState` mô tả `child` của marker. |
| `BugInspector.captureScreenshot` / `BugScreenshot` | Chụp PNG nội dung app (không gồm widget nổi và các lớp của inspector) và đổi bounds sang tọa độ ảnh. |
| `BugScreenshotEditor` | Hiện ảnh chụp và cho tester vẽ, chọn, kéo, đổi kích thước và xóa các khung chữ nhật, và phóng to ảnh bằng hai ngón tay. `readOnly: true` chỉ hiện ảnh và các khung. |
| `BugScreenshotAnnotationController`, `BugScreenshotAnnotation` | Giữ danh sách khung (tọa độ pixel của ảnh) và khung đang chọn. `toJson()` cho payload. |
| `BugScreenshot.toAnnotatedPng` | Vẽ lên ảnh những gì editor hiện (status bar giả, viền `highlight` và các khung) và trả về PNG mới để đính kèm. |
| `BugStatusBar`, `BugStatusBarStyle` | Status bar giả phủ vùng safe area phía trên của ảnh: kiểu Pixel 8 (`android`) hoặc Dynamic Island (`iOS`). |
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
| `showLauncher` | `true` | Hiện nút bug nổi khi mode đang tắt. Đặt `false` nếu app bật mode từ menu QA riêng. Thanh công cụ nổi luôn hiện khi đang chọn. Nút cũng ẩn trong lúc `Future` mà `onWidgetSelected` trả về chưa hoàn tất (form báo lỗi đang mở). |
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
- `bounds` là bounds của màn hình, `widgetType` là kiểu của `child` (ví dụ `CatalogPage`), `widgetState` là params của `child` khi class đó dùng `BugInspectableWidget` (ví dụ `ProductPage(productId: ...)` ở route builder), `routeName` là `RouteSettings.name` của route nếu có.

## State và timeline

- `BugBlocScope` phải nằm dưới nơi cung cấp instance và trên `BugInspectable`. Với `BugBlocScope.lazy`, `readBloc` nhận context của chính scope, nên `context.read<T>()` hoạt động khi scope nằm dưới provider. Hàm này chỉ chạy khi tester chọn widget; nếu provider lazy chưa được tạo thì lúc đó mới tạo. Nếu không đọc được instance, snapshot có `type: unknown` và `captureErrorType`.
- `BugBlocScope(bloc: ...)` nhận instance ngay lúc build. Biểu thức truyền vào chạy cả trên bản production.
- Khi chọn, inspector đi ngược ancestor từ gần đến xa, loại trùng theo identity. Hai instance khác nhau của cùng class đều được giữ.
- `snapshotBuilder` phải trả về giá trị JSON: chuỗi, số hữu hạn, bool, null, list, map có key là chuỗi (kiểm tra cả giá trị lồng nhau). Nếu builder ném lỗi hoặc trả giá trị không hợp lệ, snapshot đó có `state: {}` và `captureErrorType`; các scope khác vẫn được thu thập.
- `blocs` chỉ phản ánh các scope khai báo phía trên widget. Đối chiếu thêm với `BlocBuilder`/`context.read<T>()` để biết widget thực sự dùng instance nào.
- `widgetState` là params của `child` của marker, từ `BugInspectableWidget.bugSnapshot`; `{}` khi `child` không dùng mixin. Không có danh sách `State` của subtree hay ancestors (`widgetStates` đã bỏ từ `0.9.0`).
- `bugSnapshot` theo cùng quy tắc JSON như `snapshotBuilder` (giá trị trong map), được gọi đồng bộ lúc chọn và không được thay đổi state. Nếu nó ném lỗi hoặc trả giá trị không hợp lệ, `widgetState` là `{}` và `widgetStateCaptureErrorType` là kiểu lỗi; `blocs` và `stateHistory` vẫn được thu thập. Đừng đưa mật khẩu, token hay dữ liệu cá nhân vào snapshot. Với item trong list, đưa id của item vào params để phân biệt.
- Timeline chỉ lưu tên kiểu, không lưu giá trị state. Giá trị tại thời điểm chọn nằm trong `blocs[].state`. Dùng `instanceId` để đối chiếu snapshot với timeline trong cùng phiên chạy.
- Snapshot và cutoff của timeline dùng chung một timestamp (`capturedAtUtc`).

## Payload

```json
{
  "kind": "widget",
  "id": "counter.increment",
  "widgetType": "CounterButton",
  "widgetState": { "step": 1, "enabled": true },
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

`kind` là `page` khi chọn cả màn hình. `route.name` xuất hiện khi route có `RouteSettings.name` (route `home` là `/`). `label` và `source.line` chỉ xuất hiện khi được truyền. `widgetState` luôn có mặt và là `{}` khi `child` không dùng `BugInspectableWidget`; `widgetStateCaptureErrorType` chỉ xuất hiện khi `bugSnapshot` lỗi. `blocs` và `stateHistory` có thể rỗng.

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

Status bar của hệ thống không nằm trong app nên ảnh chụp chỉ có nền app ở vùng đó. Khi nội dung nằm dưới safe area phía trên trên Android hoặc iOS, `captureScreenshot` thêm `BugScreenshot.statusBar`: một status bar giả cao đúng bằng phần safe area đó, kiểu Pixel 8 trên Android (giờ, camera đục lỗ, Wi-Fi, sóng, pin) và kiểu Dynamic Island trên iOS. Đồng hồ là giờ chụp (24 giờ nếu máy dùng 24 giờ), sóng, Wi-Fi và pin luôn đầy, icon màu đen hoặc trắng tùy nền app ở vùng đó. Status bar không nằm trong `pngBytes`: `BugScreenshotEditor` (cả `readOnly`) và `toAnnotatedPng` vẽ nó dưới viền `highlight` và các khung. `captureScreenshot(context, statusBar: false)` bỏ status bar.

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
// Truyền cùng highlight với editor để ảnh xuất ra giống ảnh tester thấy.
final png = await screenshot.toAnnotatedPng(
  annotations.annotations,
  highlight: selection.bounds,
);
final json = {...screenshot.toJson(), 'annotations': annotations.toJson()};
```

Thao tác trong `BugScreenshotEditor`:

- Kéo trên vùng trống của ảnh để vẽ khung mới. Chạm mà không kéo thì không vẽ, và bỏ chọn khung đang chọn.
- Chạm vào khung để chọn. Nếu nhiều khung chồng nhau, khung nhỏ nhất được chọn. Kéo khung để di chuyển.
- Kéo một trong 4 tay nắm ở góc khung đang chọn để đổi kích thước; góc đối diện đứng yên. Kéo qua góc đối diện thì khung lật lại.
- Nút ✕ cạnh khung đang chọn (`BugScreenshotEditor.deleteButtonKey`) xóa khung đó. App cũng có thể gọi `removeSelected()`, `removeAt()` hoặc `clear()` trên controller.
- Khung luôn nằm trong ảnh và nhỏ nhất `minRectSize` (16) logical pixel trên màn hình.
- Dùng hai ngón tay để phóng to ảnh (tối đa `maxZoom`, mặc định 5 lần) và di chuyển ảnh đã phóng to, để vẽ và chỉnh khung chính xác hơn. Ngón thứ hai chạm xuống thì hủy thao tác ngón đầu đang làm (vẽ, kéo hay đổi kích thước), và các ngón chỉ thu phóng cho tới khi nhấc hết tay. Thả tay ở gần mức vừa khung thì ảnh về lại mức đó. Khi đang phóng to, nút ở góc dưới bên phải (`BugScreenshotEditor.resetZoomButtonKey`) hiện mức zoom, chạm vào để về lại cả ảnh. `maxZoom: 1` tắt zoom. Nét khung, tay nắm và vùng chạm giữ nguyên kích thước trên màn hình ở mọi mức zoom.

Editor giữ tỉ lệ ảnh và chiếm kích thước lớn nhất mà constraints cho phép. Nó nhận mọi thao tác chạm bắt đầu trên ảnh ngay khi chạm xuống, nên kéo trên ảnh không cuộn list chứa nó: đặt editor tương tác trong một trang riêng và dùng `readOnly: true` cho ảnh xem trước trong form có cuộn. Tọa độ khung là pixel của ảnh (`coordinateUnit: image_pixels`), cùng hệ với `BugScreenshot.toImageRect`. `toAnnotatedPng` vẽ viền nét đứt của `highlight` (nếu truyền) ở dưới, rồi vẽ mỗi khung với nét `strokeWidth * pixelRatio` pixel ảnh, nên ảnh xuất ra giống editor khi hiện ảnh bằng kích thước thật của app. Không có khung nào, không có `highlight` và không có `statusBar` thì `toAnnotatedPng` trả về `pngBytes` mà không encode lại.

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
