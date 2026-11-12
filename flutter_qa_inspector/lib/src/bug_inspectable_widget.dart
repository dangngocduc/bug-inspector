part of '../flutter_qa_inspector.dart';

/// Adds the parameters of a widget to the selection of the [BugInspectable]
/// or [BugInspectablePage] whose `child` it is.
///
/// Dart cannot read the fields of a widget by itself, and the diagnostics of
/// a widget are empty outside debug builds, so the widget lists the
/// parameters that help diagnose a bug in [bugSnapshot]:
///
/// ```dart
/// class ProductCard extends StatelessWidget with BugInspectableWidget {
///   const ProductCard({
///     super.key,
///     required this.productId,
///     required this.inStock,
///     this.onAddToCart,
///   });
///
///   final String productId;
///   final bool inStock;
///   final VoidCallback? onAddToCart;
///
///   @override
///   Map<String, Object?> bugSnapshot() => {
///         'productId': productId,
///         'inStock': inStock,
///         'canAddToCart': onAddToCart != null,
///       };
///
///   // build as usual.
/// }
/// ```
///
/// ```dart
/// BugInspectable(
///   id: 'catalog.product',
///   child: ProductCard(productId: product.id, inStock: product.inStock),
/// )
/// ```
///
/// When a [BugInspectable] or a [BugInspectablePage] is selected, the
/// inspector calls [bugSnapshot] on its `child` and stores the result in
/// [BugWidgetSelection.widgetState], next to [BugWidgetSelection.widgetType],
/// the runtime type of the same `child`. Only that `child` is read: put the
/// marker right around the widget with this mixin. A widget with the mixin
/// deeper inside the `child`, or above the marker, is not read, and a `child`
/// without the mixin gives an empty [BugWidgetSelection.widgetState].
///
/// The mixin works on a [StatelessWidget] and on a [StatefulWidget]. It reads
/// the parameters of the widget, the values its parent passed in, not the
/// fields of its [State].
///
/// The mixin overrides nothing, so the widget builds exactly as without it.
/// [bugSnapshot] is only called when a tester selects a widget, which never
/// happens without `--dart-define=FLUTTER_QA_INSPECTOR=true`.
mixin BugInspectableWidget on Widget {
  /// Converts the parameters of this widget into the JSON object stored in
  /// [BugWidgetSelection.widgetState].
  ///
  /// Return only parameters that help diagnose a bug, such as an id, a flag
  /// or a count. Report a callback as whether it is set, for example
  /// `'canAddToCart': onAddToCart != null`. The values may be strings, finite
  /// numbers, booleans, `null`, lists and maps with string keys. Convert
  /// enums with `.name` and dates with `.toIso8601String()`. Leave out
  /// passwords, tokens and personal data.
  ///
  /// It is called synchronously while the tester selects a widget. It must
  /// not change any state. When it throws or returns a value that is not JSON
  /// compatible, [BugWidgetSelection.widgetState] is empty and
  /// [BugWidgetSelection.widgetStateCaptureErrorType] is set.
  @protected
  Map<String, Object?> bugSnapshot();
}

/// Reads [BugWidgetSelection.widgetState] from [child], the `child` of a
/// [BugInspectable] or a [BugInspectablePage]. Never throws.
({Map<String, Object?> state, String? captureErrorType}) _captureWidgetState(
  Widget child,
) {
  if (child is! BugInspectableWidget) {
    return (state: const <String, Object?>{}, captureErrorType: null);
  }
  try {
    final state = _copyJsonValue(child.bugSnapshot()) as Map<String, Object?>;
    return (state: state, captureErrorType: null);
  } catch (error) {
    assert(() {
      debugPrint(
        'flutter_qa_inspector: could not capture the parameters of '
        '${child.runtimeType}: $error',
      );
      return true;
    }());
    return (
      state: const <String, Object?>{},
      captureErrorType: error.runtimeType.toString(),
    );
  }
}
