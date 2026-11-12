## 0.8.0

- The bug report flow moves from the example into the package, so an app
  only adds the dependency and calls it:
  - `FlutterQaInspector.install()` records the BLoC/Cubit timeline: a
    `MultiBlocObserver` of the current `Bloc.observer` and a
    `BugInspectorBlocObserver`, once. `FlutterQaInspector.recorder` is its
    recorder.
  - `FlutterQaInspector.wrap(child:)` (or `FlutterQaInspector.builder` as
    `MaterialApp.builder`) hosts the inspector and, for every selection,
    captures a screenshot and opens `BugReportPage`. Options: `enabled`,
    `stateRecorder`, `strings`, `captureScreenshot`, `share`.
  - Without the define, `install` does nothing and `wrap` returns its child.
- `BugReportPage`: the Cupertino report form of the example, with the
  full screen screenshot editor. `BugReportPage.open` pushes it on the root
  navigator, as the `/qa-bug-report` route (the example used
  `/bug-report`).
- `BugReportBundle` and `BugReportShare`: the ZIP with `screenshot.png`,
  `description.txt` and `inspector.json`, unchanged from the example.
  `toShareParams` takes a `subject`, English by default (the example used a
  Vietnamese subject).
- `BugReportStrings`: the texts of the floating toolbar, the form and the
  editor, with `en` and `vi`. `BugReportStrings.of(context)` picks `vi` for a
  Vietnamese locale and `en` otherwise.
- `BugInspectablePage.route(settings:)` marks the page of a route with the
  route name as `id` and `label` (`unnamed_route` without a name).
- The package exports `ShareParams`, `ShareResult`, `ShareResultStatus` and
  `XFile` from `share_plus`, for a custom `share`.
- New dependencies: `archive: ^4.0.0`, `bloc: ^9.2.0`,
  `share_plus: >=12.0.0 <14.0.0`. Dart `>=3.4.0` and Flutter `>=3.29.0` are
  now required. `share_plus` is a plugin: its native code is part of every
  build of the app, production included.
- Migration: apps that copied `bug_report_page.dart`,
  `bug_report_bundle.dart` and `screenshot_annotation_page.dart` from the
  example must delete them, since the names now clash with the package
  (`ambiguous_import`). Replace the hand-written setup with
  `FlutterQaInspector.install` and `FlutterQaInspector.wrap`, and drop the
  app's own `archive` dependency if nothing else uses it.

## 0.7.0

- `BugScreenshotEditor` zooms with two fingers, up to `maxZoom` (default 5,
  `1` turns zooming off), and two fingers pan the zoomed image, so the tester
  can draw and adjust small rectangles precisely. A second finger undoes what
  the first one was drawing, moving or resizing, and the fingers only zoom
  until they are all lifted. A pinch that ends close to the fit goes back to
  it. While zoomed in, a button in the bottom right corner
  (`BugScreenshotEditor.resetZoomButtonKey`, `resetZoomButtonLabel`) shows
  the zoom and resets it. Strokes, handles and touch areas keep their size on
  screen at any zoom, and the delete button hides while its rectangle is out
  of view. `readOnly` editors do not zoom.
- `BugScreenshot.toAnnotatedPng` takes the editor's `highlight` (and
  `highlightColor`) and outlines it with the same dashes, under the
  rectangles, so the exported image looks like the editor. With a
  `highlight`, it encodes a new image even without rectangles.
- `onWidgetSelected` may return a `Future` (`BugWidgetSelectedCallback`
  returns `FutureOr<void>`). The floating bug button hides until it
  completes, so return the future of the report route to keep the button off
  the report. An error of the future goes to `FlutterError.onError`.
  Callbacks that return nothing keep the button, as before.
- Screenshots get a fake status bar over the top safe area, since the
  system's own is not part of the capture: a Pixel 8 bar on Android (clock,
  punch-hole camera, Wi-Fi, signal, battery) and a Dynamic Island bar on iOS.
  It matches the height of the safe area, shows the capture time (24-hour
  when the device uses it) and picks black or white icons from the app
  background. `BugInspector.captureScreenshot` adds it as
  `BugScreenshot.statusBar` (`BugStatusBar`, `BugStatusBarStyle`);
  `statusBar: false` leaves it out. The editor and `toAnnotatedPng` draw it
  under the highlight and the rectangles, so `toAnnotatedPng` encodes a new
  image even with nothing else to draw. `BugScreenshot.toJson` describes it.

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
