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
