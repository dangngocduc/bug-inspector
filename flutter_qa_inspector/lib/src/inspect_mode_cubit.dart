part of '../flutter_qa_inspector.dart';

/// Whether the inspector is waiting for the tester to pick a widget.
enum InspectMode {
  /// The app receives pointer input as usual and no borders are drawn.
  disabled,

  /// Borders are drawn around every [BugInspectable] and the next tap inside
  /// one of them selects it. The app content does not receive pointer input.
  selecting,
}

/// Holds the current [InspectMode] of a [BugInspector].
///
/// An enabled [BugInspector] provides its instance to the subtree, so a QA
/// menu can call `BugInspector.maybeModeCubitOf(context)?.enable()`. Unlike
/// `context.read<InspectModeCubit>()`, it returns `null` instead of throwing
/// when the inspector is disabled.
class InspectModeCubit extends Cubit<InspectMode> {
  /// Creates a cubit that starts in [initialMode].
  InspectModeCubit({InspectMode initialMode = InspectMode.disabled})
      : super(initialMode);

  /// Whether the inspector is currently in [InspectMode.selecting].
  bool get isSelecting => state == InspectMode.selecting;

  /// Switches to [InspectMode.selecting].
  void enable() => _set(InspectMode.selecting);

  /// Switches to [InspectMode.disabled].
  void disable() => _set(InspectMode.disabled);

  /// Switches between [InspectMode.disabled] and [InspectMode.selecting].
  void toggle() => isSelecting ? disable() : enable();

  void _set(InspectMode mode) {
    if (isClosed) return;
    emit(mode);
  }
}
