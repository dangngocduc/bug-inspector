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

ID ổn định giúp tìm lại vùng trong code; không dùng timestamp/random ID. Với list, ID có thể đặt theo điểm render chung rồi phân biệt item bằng `label`/snapshot, hoặc ghép domain ID ổn định phù hợp. Không phụ thuộc index khi list có thể đổi thứ tự. `label` hiển thị cho tester nên dùng localization hiện có trong app thật.

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

Bọc root page/Scaffold hoặc bọc page ở route builder; chọn một vị trí phù hợp với kiến trúc hiện có. Đặt ở route builder thường cho `widgetType` là class page thay vì chỉ `Scaffold`.

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

Với `go_router`, trả `BugInspectablePage(id: ..., child: page)` từ builder/page content đang có; giữ path, params, redirect và provider ownership. Không thêm dependency router mới chỉ để inspect. `routeName` lấy từ `RouteSettings.name` thực tế; `id` của marker không tự đặt route name.

Tester bật launcher rồi chọn **Select screen**. `selection.kind == BugSelectionKind.page`; marker page không làm mọi widget con tự chọn riêng được. Muốn chọn cả page lẫn từng control thì thêm `BugInspectable` cho những control đó.

Page selection thu các `BugBlocScope` descendant theo tree rồi ancestors gần trước, loại trùng instance. Vì vậy marker ở route builder có thể bao ngoài các provider/scope mà page tự dựng; không cần di chuyển các provider đó. Các scope trong subtree đã dựng có thể được đọc lazy khi chọn page, không chỉ scope của một control.

Page/tab hiện tại là marker đang paint trên cùng; tab ẩn của `IndexedStack`/route offstage bị bỏ qua, page lồng bên trong shell thắng marker shell. Nút page xuất hiện sau frame paint marker. Nếu chỉ có marker shell, **Select screen** sẽ chọn shell, không tự suy ra page con.

## Local State của StatefulWidget

Mixin đặt trên `State` thật, không đặt trên class `StatefulWidget`. Giữ nguyên init/dispose/setState và state management hiện có; chỉ khai báo dữ liệu chẩn đoán.

```dart
class SearchPanel extends StatefulWidget {
  const SearchPanel({super.key});

  @override
  State<SearchPanel> createState() => _SearchPanelState();
}

class _SearchPanelState extends State<SearchPanel>
    with BugInspectableState<SearchPanel> {
  final _query = TextEditingController();

  @override
  Object? bugSnapshot() => {'queryLength': _query.text.length};

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => BugInspectable(
        id: 'catalog.search',
        sourceFile: 'lib/catalog/search_panel.dart',
        child: TextField(controller: _query),
      );
}
```

`widgetStates` gồm states có mixin trong subtree marker rồi ancestors. Mixin bắt được `_SearchPanelState` khi marker nằm trong `build` như trên, cũng bắt được khi một marker bên ngoài bọc `SearchPanel`. Nó không tự đọc state nội bộ của `TextField` hay state bất kỳ không có mixin. Khi nhiều instance local state cùng xuất hiện, thêm field phân biệt phù hợp.

`bugSnapshot()` chạy đồng bộ lúc chọn: không gọi `setState`, `emit`, I/O hay trả `Future`. Không đưa password/token/dữ liệu cá nhân vào snapshot; query length trong ví dụ tránh thu nội dung nhập. JSON không hợp lệ hoặc exception cho snapshot `{}` kèm `captureErrorType`, không làm lỗi toàn selection.

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

Kiểm tra sau khi chọn: `kind`, `id`, `widgetType`, source/route nếu đã khai báo; snapshot đúng instance/field và không có `captureErrorType`. Nếu `blocs` rỗng, xem lại vị trí scope; nếu `unknown`, xem provider và context; nếu `widgetStates` rỗng, xem mixin trên state thật. `stateHistory` rỗng cần kiểm tra recorder/observer/cửa sổ thời gian, không giải quyết bằng tạo thêm Cubit.
