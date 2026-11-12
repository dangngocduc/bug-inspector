# Thêm inspect cho widget hoặc page

Các snippet Dart dưới đây dùng import `package:flutter/material.dart`, `package:flutter_bloc/flutter_bloc.dart` và `package:flutter_qa_inspector/flutter_qa_inspector.dart` theo nhu cầu. Giả định subtree đã nằm dưới `BugInspector` được bật; nếu chưa có, đọc [integration.md](integration.md).

## Một widget

Bọc đúng vùng muốn tester chọn và giữ child/callback cũ. Metadata dưới đây là ví dụ; đổi `sourceFile` theo đường dẫn thật từ root host repo, chỉ thêm `sourceLine` nếu đã biết dòng chính xác.

```dart
Widget inspectCheckout(VoidCallback onCheckout) => BugInspectable(
      id: 'cart.checkout',
      label: 'Thanh toán',
      sourceFile: 'lib/cart/cart_page.dart',
      child: FilledButton(
        onPressed: onCheckout,
        child: const Text('Thanh toán'),
      ),
    );
```

ID ổn định giúp tìm lại vùng trong code; không dùng timestamp/random ID. Với list, ID có thể đặt theo điểm render chung rồi phân biệt item bằng `label`/`widgetState`, hoặc ghép domain ID ổn định phù hợp. Không phụ thuộc index khi list có thể đổi thứ tự. `label` hiển thị cho tester nên dùng localization hiện có trong app thật.

Khi lồng nhiều marker, trong cùng mức ưu tiên hit test inspector chọn bounds nhỏ nhất, bằng nhau thì chọn node sâu hơn. Marker bị offstage/không paint bị loại, phần đã clip không nhận chọn; widget bị che chỉ là fallback khi không còn ứng viên chạm tới được. Không bọc nhiều lớp cùng một control nếu không có mục đích phân biệt vùng.

## BLoC/Cubit của widget

Thứ tự thông thường: `BlocProvider<T> → BugBlocScope<S>.lazy → BugInspectable`. `S` là kiểu state, không phải kiểu Cubit/Bloc. Không cần thêm scope nếu chỉ muốn metadata/bounds.

Ví dụ dùng `CounterCubit extends Cubit<int>` đã có trong app, tương tự [CounterCubit của example](../../../flutter_qa_inspector/example/lib/counter_page.dart):

```dart
Widget withCounterInspection(Widget content) => BugBlocScope<int>.lazy(
      id: 'counter_cubit',
      // Context do scope cung cấp, nằm dưới BlocProvider<CounterCubit>.
      readBloc: (context) => context.read<CounterCubit>(),
      snapshotBuilder: (value) => {'value': value},
      child: content,
    );

Widget inspectedCounterButton() => BlocBuilder<CounterCubit, int>(
      builder: (context, value) => BugInspectable(
        id: 'counter.increment',
        sourceFile: 'lib/counter/counter_page.dart',
        child: FilledButton(
          onPressed: context.read<CounterCubit>().increment,
          child: Text('Tăng ($value)'),
        ),
      ),
    );
```

Đặt `withCounterInspection(inspectedCounterButton())` dưới provider hiện có. Không tạo provider/Cubit mới chỉ để lấy snapshot; không lấy context bên ngoài provider trong closure `readBloc`. Một widget cần nhiều instance thì lồng nhiều scope. Inspector loại trùng theo instance; hai Cubit cùng class vẫn có thể xuất hiện riêng.

Đối với widget selection, scope đặt **bên trong child của marker** không được thu vào `blocs`; hãy đặt scope trên marker. BLoC được tìm qua scope đã khai báo, không tự suy ra từ `BlocBuilder`/`context.read` của child. Serializer lấy field hữu ích như status, số item, filter, error code; enum đổi `.name`, DateTime đổi ISO, Set thành list, không trả model/controller trực tiếp.

## Cả page

Bọc root page/Scaffold hoặc bọc page ở route builder; chọn một vị trí phù hợp với kiến trúc hiện có. Đặt ở route builder thường cho `widgetType` là class page thay vì chỉ `Scaffold`, và `widgetState` là params của page khi class page dùng `BugInspectableWidget`.

```dart
MaterialPageRoute<void> inspectedCatalogRoute(Widget page) =>
    MaterialPageRoute<void>(
      settings: const RouteSettings(name: '/catalog'),
      builder: (_) => BugInspectablePage(
        id: 'catalog',
        label: 'Danh mục',
        sourceFile: 'lib/catalog/catalog_page.dart',
        child: page,
      ),
    );
```

Khi app dựng route bằng `onGenerateRoute` có `RouteSettings.name`, dùng `BugInspectablePage.route` một lần ở navigator thay vì gắn marker vào từng page. `id` và `label` là `settings.name`; route không tên có id `BugInspectablePage.unnamedRouteId` (`unnamed_route`). `sourceFile` là file định nghĩa route (navigator), không phải file page.

```dart
Route<void> onGenerateRoute(RouteSettings settings) => MaterialPageRoute<void>(
      settings: settings,
      builder: (_) => BugInspectablePage.route(
        settings: settings,
        sourceFile: 'lib/app_navigator.dart',
        child: pageFor(settings),
      ),
    );
```

`pageFor` là hàm chọn page sẵn có của host. Dùng constructor thường khi cần `id`/`label` ổn định khác tên route, hoặc route name chứa tham số động (ví dụ `/order/123`) làm id thay đổi theo dữ liệu.

Với `go_router`, trả `BugInspectablePage(id: ..., child: page)` từ builder/page content đang có; giữ path, params, redirect và provider ownership. Không thêm dependency router mới chỉ để inspect. `routeName` lấy từ `RouteSettings.name` thực tế; `id` của marker không tự đặt route name.

Tester bật launcher rồi chọn **Select screen**. `selection.kind == BugSelectionKind.page`; marker page không làm mọi widget con tự chọn riêng được. Muốn chọn cả page lẫn từng control thì thêm `BugInspectable` cho những control đó.

Page selection thu các `BugBlocScope` descendant theo tree rồi ancestors gần trước, loại trùng instance. Vì vậy marker ở route builder có thể bao ngoài các provider/scope mà page tự dựng; không cần di chuyển các provider đó. Các scope trong subtree đã dựng có thể được đọc lazy khi chọn page, không chỉ scope của một control.

Page/tab hiện tại là marker đang paint trên cùng; tab ẩn của `IndexedStack`/route offstage bị bỏ qua, page lồng bên trong shell thắng marker shell. Nút page xuất hiện sau frame paint marker. Nếu chỉ có marker shell, **Select screen** sẽ chọn shell, không tự suy ra page con.

## Params của widget được chọn (`widgetState`)

Selection mô tả `child` trực tiếp của `BugInspectable`/`BugInspectablePage`: `widgetType` là runtime type của `child`, `widgetState` là params của chính `child` đó. Dart không có reflection và Diagnostics (`debugFillProperties`) rỗng ngoài debug build, nên class widget làm `child` khai báo params bằng mixin `BugInspectableWidget`. Mixin đặt trên class widget (`StatelessWidget` hoặc `StatefulWidget`), không đặt trên `State`; giữ nguyên constructor, build và state management hiện có.

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

  @override
  Map<String, Object?> bugSnapshot() => {
        'productId': productId,
        'inStock': inStock,
        'canAddToCart': onAddToCart != null,
      };

  @override
  Widget build(BuildContext context) => ListTile(
        title: Text(productId),
        onTap: inStock ? onAddToCart : null,
      );
}

Widget inspectProduct(String id, bool inStock, VoidCallback onAdd) =>
    BugInspectable(
      id: 'catalog.product',
      sourceFile: 'lib/catalog/product_card.dart',
      child: ProductCard(productId: id, inStock: inStock, onAddToCart: onAdd),
    );
```

Kết quả: `widgetType: ProductCard`, `widgetState: {productId: ..., inStock: ..., canAddToCart: true}`.

- Chỉ đọc `child` trực tiếp: đặt marker sát quanh widget có mixin. `BugInspectable(child: Padding(child: ProductCard(...)))` cho `widgetType: Padding`, `widgetState: {}`; widget có mixin sâu hơn trong `child` hoặc phía trên marker không được đọc. Với `Expanded`/`Flexible`, marker vẫn nằm trong `child` của chúng và bọc trực tiếp widget có mixin.
- `child` không có mixin, kể cả widget Flutter (`Text`, `FilledButton`, `TextField`), cho `widgetState: {}`. Muốn có params thì tách phần UI thành widget riêng có mixin thay vì sửa widget framework.
- Với `StatefulWidget`, `bugSnapshot()` chỉ thấy field của widget (giá trị parent truyền vào), không thấy field của `State`. Dữ liệu chỉ nằm trong `State` (ví dụ text của controller) không vào report; nếu cần, truyền nó xuống thành param của widget dưới marker hoặc đưa vào BLoC/Cubit có `BugBlocScope`. Không tạo state/controller mới chỉ để inspect.
- Page: `BugInspectablePage(child: ProductPage(productId: ...))` hoặc `BugInspectablePage.route(child: pageFor(settings))` cho params của page widget khi class page dùng mixin; page `const CatalogPage()` không có params thì `{}`.
- Callback: báo có hay không (`onAddToCart != null`), không trả function. List item: đưa domain id vào params để phân biệt instance.

`bugSnapshot()` chạy đồng bộ lúc chọn: không gọi `setState`, `emit`, I/O hay trả `Future`. Giá trị trong map theo quy tắc JSON như `snapshotBuilder` (enum `.name`, DateTime ISO, Set thành list). Không đưa password/token/dữ liệu cá nhân vào params. Exception hoặc JSON không hợp lệ cho `widgetState: {}` kèm `widgetStateCaptureErrorType`, không làm lỗi toàn selection.

## Giữ layout và kiểm tra kết quả

`Expanded`, `Flexible`, `Positioned` phải giữ vị trí ParentDataWidget; đặt marker **trong child** của chúng:

```dart
Widget expandedInspection(Widget content) => Expanded(
      child: BugInspectable(
        id: 'catalog.results',
        child: content,
      ),
    );
```

Dùng pattern này trong `Row`/`Column` phù hợp. Không bọc sliver trực tiếp bằng marker box; bọc widget trong item builder hoặc bên trong `SliverToBoxAdapter`.

Kiểm tra sau khi chọn: `kind`, `id`, `widgetType`, `widgetState`, source/route nếu đã khai báo; snapshot đúng instance/field và không có `captureErrorType`/`widgetStateCaptureErrorType`. Nếu `blocs` rỗng, xem lại vị trí scope; nếu `unknown`, xem provider và context; nếu `widgetState` rỗng, xem `widgetType` có đúng class có mixin không (marker phải bọc trực tiếp widget đó). `stateHistory` rỗng cần kiểm tra recorder/observer/cửa sổ thời gian, không giải quyết bằng tạo thêm Cubit.
