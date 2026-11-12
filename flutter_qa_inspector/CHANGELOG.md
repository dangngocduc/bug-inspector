## 0.6.0

- `BugScreenshotEditor` lets the tester mark a `BugScreenshot` with
  rectangles: drag on the image to draw one, tap one to select it, drag it to
  move it, drag a corner handle to resize it, and tap the button next to it
  to delete it. Rectangles stay inside the image. `readOnly` shows them
  without gestures, and `highlight` outlines the selected widget with a dashed
  line. A touch that starts on the editor is never a scroll of an enclosing
  list.
- `BugScreenshotAnnotationController` holds the rectangles
  (`BugScreenshotAnnotation`, in image pixels) and the selection, with
  `toJson()` for the report.
- `BugScreenshot.toAnnotatedPng` encodes the screenshot with the rectangles
  drawn on it.
- Without the define, the editor builds an empty box and `toAnnotatedPng`
  returns `pngBytes`.

## 0.5.0

- `BugInspectableState`, a mixin for `State`: `bugSnapshot()` returns the
  fields of the state as a JSON value. When a widget or a page is selected,
  `BugWidgetSelection.widgetStates` holds a `BugWidgetStateSnapshot` of every
  state with the mixin inside the selection, in tree order, then of those
  above it, nearest first. A snapshot that throws or is not JSON has an empty
  `state` and `captureErrorType`.
- The mixin overrides nothing. Without the define, `bugSnapshot` is never
  called and is left out of the build.

## 0.4.0

- The inspector only runs in builds made with
  `--dart-define=FLUTTER_QA_INSPECTOR=true`
  (`BugInspector.enabledFromEnvironment`). Without it, `BugInspector`,
  `BugInspectable`, `BugInspectablePage` and `BugBlocScope` only return their
  child, `BugInspectorBlocObserver` records nothing, and
  `maybeModeCubitOf`/`captureScreenshot` return `null`. The check is a
  constant, so the inspector code is left out of such builds: 0.7 KB of
  package code in the example's release build, against 42.5 KB with the
  define.
- `BugInspector.enabled` (default `true`) turns the inspector off in a QA
  build. A disabled host creates no `InspectModeCubit`.
- `BugBlocScope.lazy` reads its bloc with `readBloc` only when a widget is
  selected, so a lazy provider is not created by the scope. `capture` takes
  the context of the scope. `BugBlocScope.bloc` is `null` for lazy scopes.
- `BugInspectorBlocObserver` drops its own errors, for example from `filter`,
  instead of throwing inside the app's `emit` or `add`.
- `BugInspector`, `BugInspectable` and `BugInspectablePage` are now
  `StatelessWidget`s.
- The tests run in two modes: `flutter test` checks the production
  behavior, and `flutter test --dart-define=FLUTTER_QA_INSPECTOR=true` checks
  the inspector.

## 0.3.0

- A floating, draggable control on top of the app replaces the exit pill and
  the separate page button. While the mode is disabled it is a bug button
  that enables the mode, so the app needs no Inspect entry in its own UI.
  While selecting it is a toolbar with a hint, an exit button and the
  "Select screen" button.
- The control is not part of the app content: no layout change, only its own
  area takes taps, it never takes focus or closes the keyboard, and
  `captureScreenshot` leaves it out. It stays inside the safe area and above
  the keyboard, follows the finger and keeps its position across mode
  changes.
- Screen readers see each control as its own button with a tap action, and
  dragging is not offered as a scroll action.
- New `BugInspector.showLauncher`, `floatingAlignment`, `selectionHint`, and
  public `launcherKey`, `exitButtonKey`, `pageButtonKey`.
- Removed `showExitButton`, `exitButtonLabel`, `exitButtonAlignment`,
  `exitButtonBuilder`, `BugExitButtonBuilder` and `pageButtonAlignment`.

## 0.2.0

- `BugInspectablePage` marks a whole screen. While selecting, pages get their
  own border and a draggable "Select screen" button selects the current page:
  the topmost page on screen, nested pages winning over their parents.
- Page selections include the `BugBlocScope`s inside the page as well as
  those above it.
- `BugWidgetSelection.kind` (`widget` or `page`) and `routeName`, exported as
  `kind` and `route.name`.
- `BugInspector.showPageButton`, `pageButtonLabel`, `pageButtonAlignment`,
  `selectPageOnEmptyTap`, `pageBorderColor` and `pageBorderWidth`.

## 0.1.0

- `BugInspector`, `BugInspectable`, `BugBlocScope`, `InspectModeCubit`.
- `BugStateRecorder` and `BugInspectorBlocObserver` for the BLoC/Cubit timeline.
- `BugWidgetSelection`, `BugBlocSnapshot`, `BugStateRecord` with `toJson()`.
- `BugInspector.captureScreenshot` and `BugScreenshot`.
- Selection skips widgets that are not painted, clipped away or covered by
  another reachable widget, then picks the smallest bounds and, on equal area,
  the deepest widget.
- `createSelection` reads the history window only when a recorder is set and
  uses one timestamp for the snapshot and the timeline cutoff.
