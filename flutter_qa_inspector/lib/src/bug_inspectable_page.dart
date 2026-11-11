part of '../flutter_qa_inspector.dart';

/// Marks [child] as a whole screen the tester can select while the nearest
/// [BugInspector] is in [InspectMode.selecting].
///
/// While selecting, the page gets its own border (see
/// [BugInspector.pageBorderColor]) and the host shows a floating
/// "Select screen" button. The button selects the current page: the topmost
/// [BugInspectablePage] that is on screen. A page shown below a dialog or a
/// bottom sheet still counts as current, and a page nested in another one,
/// such as a tab inside a shell, wins over its parent.
///
/// The selection has [BugWidgetSelection.kind] set to
/// [BugSelectionKind.page]. Its [BugWidgetSelection.blocs] include the
/// [BugBlocScope]s inside the page as well as those above it.
///
/// Wrap the content of each screen, for example in the page widget or in the
/// route builder:
///
/// ```dart
/// MaterialPageRoute<void>(
///   builder: (_) => const BugInspectablePage(
///     id: 'catalog',
///     sourceFile: 'lib/catalog/catalog_page.dart',
///     child: CatalogPage(),
///   ),
/// )
/// ```
///
/// Outside a [BugInspector] this widget simply returns [child].
class BugInspectablePage extends StatefulWidget
    implements _InspectableNodeWidget {
  /// Creates a page marker around [child].
  const BugInspectablePage({
    super.key,
    required this.id,
    required this.child,
    this.label,
    this.sourceFile,
    this.sourceLine,
    this.borderColor,
    this.borderWidth,
  }) : assert(borderWidth == null || borderWidth >= 0);

  /// A stable identifier stored in [BugWidgetSelection.id], for example
  /// `checkout`.
  @override
  final String id;

  /// An optional human readable name, shown on the page button and stored in
  /// [BugWidgetSelection.label].
  @override
  final String? label;

  /// The file that builds the page, relative to the repository root.
  @override
  final String? sourceFile;

  /// The line in [sourceFile] that builds the page.
  @override
  final int? sourceLine;

  /// The border color. Defaults to [BugInspector.pageBorderColor].
  @override
  final Color? borderColor;

  /// The border width in logical pixels. Defaults to
  /// [BugInspector.pageBorderWidth].
  @override
  final double? borderWidth;

  /// The page content.
  @override
  final Widget child;

  @override
  State<BugInspectablePage> createState() => _BugInspectablePageState();

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    _debugFillNodeProperties(this, properties);
  }
}

class _BugInspectablePageState extends State<BugInspectablePage>
    with _InspectableNodeState<BugInspectablePage> {
  @override
  BugSelectionKind get _kind => BugSelectionKind.page;

  @override
  _InspectableNodeWidget get _node => widget;
}
