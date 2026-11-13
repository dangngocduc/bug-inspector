# flutter_qa_inspector

A Flutter inspector for QA builds. Testers can select a widget or a whole screen and attach its metadata, explicit widget parameters, BLoC/Cubit state snapshots, a recent activity timeline, the API calls of a Dio client (request and response), and an annotated screenshot to a bug report.

The package includes `BugReportPage`: draw rectangles on a screenshot, describe the issue, then share the image and a ZIP through the platform share sheet. It does not automatically read fields from a widget's `State` or discover its BLoC dependencies; expose the data you need through the markers and scopes below.

This README describes version `0.10.0` and the current public API.

## Requirements and installation

- Dart `>=3.4.0 <4.0.0`, Flutter `>=3.29.0`.
- Dependencies: `flutter_bloc: ^9.1.1`, `bloc: ^9.2.0` (`MultiBlocObserver`), `dio: ^5.2.0` (`BugInspectorDioInterceptor`, pure Dart), `cupertino_icons: ^1.0.8` (the icon font of the report pages), `archive: ^4.0.0` (ZIP), and `share_plus: >=12.0.0 <14.0.0` (share sheet).
- The inspector requires `--dart-define=FLUTTER_QA_INSPECTOR=true`. Without the define, or with `false`, the facade returns the app content unchanged; see [Production builds](#production-builds). `enabled: true` cannot override the compile-time flag.

This package declares `publish_to: none`. Add it from Git:

```yaml
dependencies:
  flutter_qa_inspector:
    git:
      url: https://github.com/dangngocduc/bug-inspector
      path: flutter_qa_inspector
```

For a local checkout, use `path: ../flutter_qa_inspector` instead, adjusted relative to the host app's `pubspec.yaml`. Import the public entrypoint:

```dart
import 'package:flutter_qa_inspector/flutter_qa_inspector.dart';
```

You do not need to declare `archive`, `share_plus`, or `cupertino_icons` separately unless your app imports them directly; the `CupertinoIcons` font is bundled through this package. An app that uses Dio already declares `dio`; keep its constraint inside `^5.2.0`. Because `share_plus` is a plugin, its native code is included in production builds too. The facade gates the Dart inspector/report flow, not native plugin registration.

Check the `share_plus` version resolved in your lockfile against the host's native toolchain:

| Version | Requirements |
| --- | --- |
| `12.0.0` | iOS 12+, macOS 10.14+; Android: Java 17, Kotlin 2.2.0, AGP 8.12.1+, Gradle 8.13+. |
| `13.3.1` | Dart 3.10+, Flutter 3.38.1+, iOS 13+, macOS 10.15+; the same Android requirements as above. |

Dependency resolution checks SDK constraints but does not update native deployment targets. For other versions in the allowed range, check that version's requirements. See the upstream documentation for [share_plus 12.0.0](https://pub.dev/packages/share_plus/versions/12.0.0) and [13.3.1](https://pub.dev/packages/share_plus/versions/13.3.1).

- On iOS, add `NSPhotoLibraryAddUsageDescription` to `ios/Runner/Info.plist` when using the default share sheet so testers can choose **Save Image**. The package cannot add this key to the host app. The report already supplies the send button's position for the iPad share popover.
- Linux does not support file sharing through `share_plus`; provide a custom `share:` callback to send the ZIP. On the web, file sharing depends on the browser and may fall back to a download.

## Bug reporting workflow

1. Reproduce the issue, then tap the floating bug button. An existing QA menu can also call `BugInspector.maybeModeCubitOf(context)?.enable()`.
2. `BugInspectable` widgets receive pink borders and `BugInspectablePage` screens receive blue borders. The app content stops receiving pointer input, including taps, scrolling, and hover events.
3. Tap a highlighted widget, or use **Select screen** on the floating toolbar to select the current screen. The inspector measures bounds, captures declared widget parameters and BLoC/Cubit snapshots, and reads the recent timeline and the recorded API calls. A tap outside all widget markers keeps selection mode active by default. When API calls are recorded, the toolbar also has **Inspect network** below **Select screen**, with the number of calls and failed calls; it leaves selection mode and opens the API call history (see [API calls (Dio)](#api-calls-dio)).
4. The inspector disables selection mode by default, then calls `onWidgetSelected(widgetContext, selection)`. Use the toolbar's close button to cancel selection instead.
5. With the quick setup, the callback captures the app and opens `BugReportPage`. Annotate the image, enter a description, and tap **Send** to share the PNG and ZIP.

The snapshot records the moment of selection. The screenshot may be captured in a later frame; neither is a recording of the entire reproduction flow.

## Quick setup

Install the observer before creating any BLoC/Cubit, add the host to the app builder, and mark the screens or widgets testers should be able to select. This minimal app uses the built-in report flow:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_qa_inspector/flutter_qa_inspector.dart';

void main() {
  // Keeps the app's existing Bloc.observer.
  FlutterQaInspector.install();
  runApp(const App());
}

class App extends StatelessWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
        builder: FlutterQaInspector.builder,
        home: const BugInspectablePage(
          id: 'home',
          sourceFile: 'lib/main.dart',
          child: Scaffold(
            body: Center(
              child: BugInspectable(
                id: 'home.message',
                child: Text('QA example'),
              ),
            ),
          ),
        ),
      );
}
```

To record API calls, add the interceptor to each Dio client of the app, after the interceptors that change the request (see [API calls (Dio)](#api-calls-dio)):

```dart
if (BugInspector.enabledFromEnvironment) {
  dio.interceptors.add(const BugInspectorDioInterceptor());
}
```

For an existing app, preserve its bootstrap, Navigator/Router, theme, localization, providers, and callbacks. Compose the inspector into the existing builder and pass its `child` through. For example, inside that builder:

```dart
return FlutterQaInspector.wrap(
  child: child ?? const SizedBox.shrink(),
);
```

`MaterialApp.router` supports the same builder pattern; keep your existing `routerConfig`.

- `FlutterQaInspector.install({stateRecorder, networkRecorder})` installs a `MultiBlocObserver` combining the existing observer with `BugInspectorBlocObserver`, and creates the `BugNetworkRecorder` of the API calls. Later calls do nothing. `FlutterQaInspector.recorder` and `FlutterQaInspector.networkRecorder` expose the installed recorders. Without the define, installation does nothing and both are `null`.
- `FlutterQaInspector.wrap(child:, enabled:, stateRecorder:, networkRecorder:, strings:, captureScreenshot:, share:)` hosts the inspector, captures a screenshot, and opens the report on the root navigator for each selection. It uses the installed recorders unless you supply them. Without the define, it returns `child` directly.
- `FlutterQaInspector.builder` is `wrap` with default options. Set `captureScreenshot: false` on `wrap` for reports without an image.

Run the app or build a QA artifact with the same flag:

```sh
flutter pub get
flutter run --dart-define=FLUTTER_QA_INSPECTOR=true
flutter build ipa --dart-define=FLUTTER_QA_INSPECTOR=true
```

The IPA command applies to an app with an iOS target. Keep your existing flavor, entrypoint, and Flutter/FVM runner. Changing the compile-time define requires running or building the app again; hot reload does not change it. Use this define in QA CI builds, and omit it from production builds.

### Display strings

`BugReportStrings` covers the toolbar, report form, and annotation editor. `BugReportStrings.of(context)` selects `.vi` for a Vietnamese locale and `.en` otherwise. Map your app's localization into `strings:`; for example, inside an existing builder where `S` is your localization class:

```dart
return FlutterQaInspector.wrap(
  child: child ?? const SizedBox.shrink(),
  strings: (context) => BugReportStrings.en.copyWith(
    title: S.of(context).bugReportTitle,
  ),
);
```

### Custom delivery

By default, **Send** calls `SharePlus.instance.share`. Supply `share:` to upload the report or create a ticket. The callback receives `ShareParams` with the PNG (when available), ZIP, and the trimmed description as `text`, and returns a `ShareResult`.

`ShareResultStatus.dismissed` keeps the form open for another attempt; other statuses close it. Throwing an error displays a dialog. The package re-exports `ShareParams`, `ShareResult`, `ShareResultStatus`, and `XFile`, so the callback can use them through the public entrypoint. The package does not provide an upload service or issue tracker integration.

### Report form and ZIP

`BugReportPage` is a full-screen Cupertino report with its own theme, following the device's light/dark mode. It opens on the root navigator and has an internal navigator for the editor, so the app sees one report route: `BugReportPage.routeName`, `/qa-bug-report`.

Back closes the editor before the form. Leaving a form with a description or annotations asks for confirmation. Sending creates a `BugReportBundle`:

| ZIP entry | Contents |
| --- | --- |
| `screenshot.png` | Optional. The screenshot with the selected widget's highlight and the tester's rectangles. Whole-screen selections do not receive a highlight around the page. |
| `description.txt` | The tester's description, preserved as entered. May be empty. |
| `inspector.json` | `{"inspector": selection.toJson(), "screenshot": {...screenshot.toJson(), "annotations": [...]}}`. The `screenshot` object is present only when an image is available; it contains metadata, not PNG bytes. |

`BugReportBundle.nameFor(selection.id, selection.capturedAtUtc)` generates a name such as `bug_counter.increment_20261112_093005`, using a sanitized ID and the UTC selection time. The share sheet receives `<name>.png` when available and `<name>.zip`. **Copy JSON** copies `{"description": ..., ...inspector.json}`; this additional description field is not written to `inspector.json` in the ZIP.

A custom callback can reuse the form with `BugReportPage.open(widgetContext, selection:, screenshot:, strings:, share:)`. Capture the screenshot before opening the form. The form lists the recorded API calls in a **Network** section, newest first; tapping a call opens its page. **Request**: the scheme and host, then the method and path with each query parameter name and value in its own color (redacted values greyed out). **Request headers**: one row per header, name and value, with a button that copies the value (a redacted value has none). **Request body**, when there is one. Then **Response**: status code and message, duration, and start time; the error, when there is one; the response headers, in the same format; and the response body. A whole JSON object or list body (request or response) shows right in the call page as a collapsible tree: tap an object or list to open or close it, or use **Expand all** / **Collapse all** in the section header (the root stays open); keys, strings, numbers, booleans, and `null` have their own colors, and each object or list shows its item count. The tree first opens one level at a time while it stays within 100 rows: a small body shows whole, a long list shows its items closed. Rows are built as they scroll in. A body cut by `maxBodyLength`, and any other body, is selectable text. The **Payload** preview leaves `network` out because it has its own section; `inspector.json` and **Copy JSON** include it.

The bundle does not automatically include app version, build number, Git SHA, or device details; add those in a custom flow if needed.

## Mark widgets and capture state

The following snippets assume an enabled host and existing app models, providers, and actions. Add `package:flutter/material.dart` and `package:flutter_bloc/flutter_bloc.dart` imports where used.

### BLoC/Cubit snapshots

Place a scope below the instance's provider and above the widget marker. Reuse the app's instance:

```dart
BugBlocScope<CartState>.lazy(
  id: 'cart_cubit',
  // Runs when selected, not during build.
  readBloc: (context) => context.read<CartCubit>(),
  snapshotBuilder: (state) => {
    'status': state.status.name,
    'itemCount': state.items.length,
    'updatedAt': state.updatedAt?.toIso8601String(),
  },
  child: BugInspectable(
    id: 'cart.checkout',
    sourceFile: 'lib/cart/cart_page.dart',
    child: FilledButton(
      onPressed: checkout,
      child: const Text('Checkout'),
    ),
  ),
)
```

Use the state type for `BugBlocScope<S>`, not the Cubit/Bloc type. The lazy reader receives the scope's context. It can instantiate a previously unused lazy provider at selection time. `BugBlocScope(bloc: ...)` is also available, but its argument expression runs during build, including production builds.

Widget selection collects ancestor scopes, nearest first, and deduplicates them by instance identity. Two different instances of the same class are kept. A scope inside the marker's child is not included for a widget selection. Declared scopes do not prove which instances the child actually consumes; check its `BlocBuilder`, `BlocSelector`, or `context.read<T>()` when diagnosing an issue.

`snapshotBuilder` and the widget's `bugSnapshot()` must be synchronous, must not change state, and must return JSON-compatible data: strings, finite numbers, booleans, `null`, lists, and maps with string keys. Convert enums with `.name`, dates with `.toIso8601String()`, and sets to lists. Check nested values too, and omit passwords, tokens, and personal data.

If reading a scope or serializing its state fails, its snapshot has `state: {}` and `captureErrorType`; other scopes are still captured. A failed lazy read also sets `type` and `instanceId` to `unknown`.

### Parameters of the selected widget

`widgetType` and `widgetState` describe the marker's direct `child`. To expose its parameters, add `BugInspectableWidget` to that widget class:

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

Widget inspectedProduct() => const BugInspectable(
      id: 'catalog.product',
      child: ProductCard(productId: 'p1', inStock: true),
    );
// widgetType: ProductCard
// widgetState: {productId: p1, inStock: true, canAddToCart: false}
```

- Put the marker directly around the widget with the mixin. `BugInspectable(child: Padding(child: ProductCard(...)))` describes `Padding` and produces `widgetState: {}`. Widgets deeper inside the child or above the marker are not read.
- A child without the mixin, including Flutter widgets such as `Text` or `FilledButton`, produces `widgetState: {}`.
- The mixin works on `StatelessWidget` and `StatefulWidget`. It reads widget parameters from the latest build, not fields of `State`, controllers, or the whole subtree. Local state must be passed as parameters to the marked child or exposed through a BLoC/Cubit scope to appear in the report.
- `bugSnapshot()` runs synchronously at selection time and follows the same JSON rules as `snapshotBuilder`. Failure produces `widgetState: {}` and `widgetStateCaptureErrorType`, while BLoC snapshots and history are still collected.
- From `0.9.0`, `BugInspectableState` and the `widgetStates` list have been removed. Use `BugInspectableWidget` and the `widgetState` object; the new object has different semantics from the old `State` snapshots.

## Mark and select screens

Wrap a page in its route builder or mark the page's root widget:

```dart
Route<void> catalogRoute() => MaterialPageRoute<void>(
      settings: const RouteSettings(name: '/catalog'),
      builder: (_) => const BugInspectablePage(
        id: 'catalog',
        label: 'Catalog',
        sourceFile: 'lib/catalog/catalog_page.dart',
        child: CatalogPage(),
      ),
    );
```

For named routes created by `onGenerateRoute`, use `BugInspectablePage.route` once at the navigation boundary. In this fragment, `pageFor(settings)` is the host app's existing page factory:

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

The route factory uses `settings.name` for both `id` and `label`. Unnamed routes use `BugInspectablePage.unnamedRouteId` (`unnamed_route`). Use the regular constructor when you need a different stable ID. With `go_router`, return `BugInspectablePage(id: 'catalog', child: CatalogPage())` from the existing route builder; preserve its routing and providers.

- The current screen is the topmost painted page marker. Offstage routes and hidden `IndexedStack` tabs are excluded. A nested page, such as a tab inside a shell, takes precedence over its containing page. Dialogs and bottom sheets do not automatically become pages.
- **Select screen** shows the target's `label` or `id`. It appears one frame after the marker is painted and is hidden when no page is available.
- Page snapshots collect descendant scopes in tree order, then ancestor scopes nearest first, deduplicated by instance. A marker at the route boundary can therefore capture scopes created inside the page.
- `bounds` describes the page, `widgetType` describes its direct child, and `widgetState` contains that child's declared parameters. `routeName` comes from the containing route's `RouteSettings.name`, independently of the marker ID.

A page marker does not make every child individually selectable. Add `BugInspectable` to each control that needs its own selection.

## Custom inspector host

Use `BugInspector` directly when you need your own form or reporting flow. Its required arguments are `child` and `onWidgetSelected`. Install the observer before creating app instances and pass the same recorder to the host:

```dart
BugStateRecorder? installQaTimeline() {
  if (!BugInspector.enabledFromEnvironment) return null;
  final recorder = BugStateRecorder();
  Bloc.observer = MultiBlocObserver(
    observers: [Bloc.observer, BugInspectorBlocObserver(recorder: recorder)],
  );
  return recorder;
}

Widget withQaInspector({
  required Widget child,
  required BugStateRecorder? recorder,
  required BugWidgetSelectedCallback openReport,
}) =>
    BugInspector(
      stateRecorder: recorder,
      onWidgetSelected: openReport,
      child: child,
    );
```

This fragment uses `Bloc` and `MultiBlocObserver` from `package:bloc/bloc.dart`. If your app imports that package directly, declare `bloc: ^9.2.0` in its dependencies. Call `installQaTimeline()` once during startup, then call `withQaInspector` from the app builder with its original child and your callback. Do not create the recorder in `build`.

The callback receives the selected marker's context. Use it immediately to find the relevant navigator; after `await`, check `widgetContext.mounted`. Return or await the report route's future so the launcher stays hidden until the report closes. A callback that returns immediately can leave the launcher over the report.

A recorder is optional: without it, state snapshots still work and `stateHistory` is empty.

### Existing QA menu

The default host includes a draggable launcher. With a custom `BugInspector`, set `showLauncher: false` if your app has its own entry point, and call this from a context below the host:

```dart
BugInspector.maybeModeCubitOf(context)?.enable();
```

The accessor returns `null` without an enabled host, including production builds. Use it to hide the QA menu entry when unavailable. `context.read<InspectModeCubit>()` throws in production because that Cubit is not provided there.

### Host options

| Option | Default | Behavior |
| --- | --- | --- |
| `enabled` | `true` | Still requires the compile-time flag. Keep this value stable for the app's lifetime. |
| `modeCubit` | `null` | The host creates and closes its own Cubit. When supplied, the caller owns and closes it. |
| `stateRecorder` | `null` | Use the same instance as the observer. |
| `historyWindow` | 30 seconds | Time window included in `stateHistory`. |
| `networkRecorder` | `null` | Use the same instance as the `BugInspectorDioInterceptor`. Without it, `network` is empty. |
| `networkHistoryWindow` | `null` | Calls that ended within this window, plus running calls, are included in `network`. `null` includes every kept call. Either way, `network` has at most the newest `BugNetworkRecorder.maxReportRecords` calls. |
| `strings` | `null` | Texts of the **Inspect network** button and the API call history; `BugReportStrings.of(context)` when `null`. The facade passes its `strings:`. |
| `disableModeOnSelection` | `true` | If `false`, disable mode before capturing or opening a form below the overlay. |
| `selectionTrigger` | `BugSelectionTrigger.tapUp` | Selects after a confirmed tap. `tapDown` selects immediately, even before a drag. |
| `showLauncher` | `true` | Shows the bug button while mode is disabled. The selection toolbar always appears while selecting. The launcher hides while the callback's future is pending. |
| `floatingAlignment` | `AlignmentDirectional.centerEnd` | Initial position inside the safe area. |
| `selectionHint` | `Tap a highlighted widget` | Toolbar hint. |
| `borderColor`, `borderWidth` | `#FF2D78`, 2 | Defaults for widget markers. |
| `showPageButton`, `pageButtonLabel` | `true`, `Select screen` | Page button, visible only when a marked screen is available. |
| `selectPageOnEmptyTap` | `false` | When enabled, a tap outside all widget markers selects the page under the tap. |
| `pageBorderColor`, `pageBorderWidth` | `#2979FF`, 4 | Defaults for page markers. |

Changing `enabled` at runtime rebuilds app content and loses its route stack and screen state. Decide it before `runApp`; use `InspectModeCubit` and `showLauncher` for runtime control. `InspectModeCubit` supports `enable()`, `disable()`, and `toggle()`; calls after `close()` are ignored.

## Selection rules and floating controls

At tap time, the inspector measures each attached, laid-out marker's `RenderBox` and converts its bounds to global logical pixels:

1. Exclude widgets not painted in the current frame, such as offstage routes, hidden `IndexedStack` children, `Offstage`, and zero-opacity content.
2. Exclude clipped portions. The tap must fall within the remaining visible area.
3. Prefer candidates reached by the hit test. A widget covered by a dialog, bottom sheet, or another widget is a fallback when no reachable candidate exists. Widgets under the app's `IgnorePointer` or `AbsorbPointer` remain eligible as reachable candidates.
4. Within the same priority, choose the smallest bounds; equal areas prefer the deeper widget. A remaining tie prefers the later registration.

The returned `bounds` is the outer bounding rectangle in global logical pixels, without subtracting clips. Borders use a dedicated foreground render object that preserves the child's size, padding, and hit testing.

The floating control sits above the app's Navigator, dialogs, and bottom sheets, outside the app's own overlay. It does not change app layout or theme. While mode is disabled, only the control's area receives its input; input elsewhere reaches the app. It does not take keyboard focus, remains inside the safe area and above the keyboard, and is excluded from screenshots.

Testers can drag it anywhere within the screen. The host remembers the position for both the bug button and the expanded toolbar across mode changes.

## State timeline and payload

`BugInspectorBlocObserver` records activity as soon as it is installed, including before selection mode is enabled:

| Source | Record kinds |
| --- | --- |
| BLoC and Cubit | `created`, `closed`, `error` |
| BLoC | `event`, `transition` |
| Cubit | `change` |

The recorder keeps up to 300 records in memory by default, dropping the oldest when full. The host includes the last 30 seconds by default. Adjust `BugStateRecorder(maxRecords:)` and `historyWindow` as needed. Increasing the time window cannot recover records already dropped.

Records contain UTC timestamps, instance IDs, and type names, not state/event values, full error messages, or stack traces. Current values are in `blocs[].state`. Match snapshots and history with `instanceId`, which is unique within the current run. History is not automatically filtered to the selected widget's scopes; use the IDs or an observer `filter`. The inspector's own `InspectModeCubit` is ignored, and recording errors do not propagate to the app's `emit` or `add`.

Selection capture and the history cutoff share `capturedAtUtc`. Example `selection.toJson()`:

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
  ],
  "network": []
}
```

`kind` is `page` for a screen selection. `route.name` appears when the route has a name (`home` uses `/`). `label`, `source.file`, and `source.line` appear only when supplied. `widgetState` is always present; `widgetStateCaptureErrorType` appears only on capture failure. `blocs`, `stateHistory`, and `network` may be empty. Source metadata is supplied by the app, not discovered automatically.

## API calls (Dio)

Only apps that use [Dio](https://pub.dev/packages/dio) are supported. `BugInspectorDioInterceptor` writes every call of a Dio client into a `BugNetworkRecorder`, and each selection copies the newest of the recorder's calls into `network` (10 by default, see `maxReportRecords` below):

```dart
final dio = Dio(BaseOptions(baseUrl: 'https://api.example.com'));
if (BugInspector.enabledFromEnvironment) {
  // Last: it sees the request as it is sent, with the headers added by the
  // other interceptors (their secret values are redacted).
  dio.interceptors.add(const BugInspectorDioInterceptor());
}
```

- Without `recorder:`, the interceptor writes into `FlutterQaInspector.networkRecorder`, read at every request, so the Dio client may be created before or after `install`. Calls made while no recorder exists are not recorded. A custom host passes the same `BugNetworkRecorder` to the interceptor (`recorder:`) and to `BugInspector.networkRecorder`.
- `filter: (options) => ...` leaves calls out, for example health checks or endpoints whose bodies hold personal data.
- The interceptor always passes the request, response, and error on unchanged; recording errors are dropped. It only adds `BugInspectorDioInterceptor.extraKey` to `RequestOptions.extra`.
- A bug report includes at most the 10 newest calls (`BugNetworkRecorder(maxReportRecords:)`; `0` leaves the calls out of reports). The form's **Network** section lists those same calls. The recorder still keeps more for the API call history.
- `BugNetworkRecorder` keeps the newest 100 calls in memory (`maxRecords`) and the first 16384 characters of each text or JSON body (`maxBodyLength`); a cut body has `truncated: true` and the full `size`. Bytes and streams keep only their size or kind; `FormData` keeps its text fields and file names, never file contents.
- Redaction: values of `defaultRedactedHeaders` (`Authorization`, `Cookie`, `Set-Cookie`, `X-Api-Key`, ...) and of `defaultRedactedFields` (`password`, `token`, `accessToken`, `refreshToken`, `apiKey`, `otp`, `pin`, ...) in JSON bodies, form fields, and query parameters become `REDACTED`; URL user info is removed. Field names match ignoring case, `_`, and `-`. Extend the sets with `BugNetworkRecorder(redactedFields: {...BugNetworkRecorder.defaultRedactedFields, 'iban'})`, passed to `install(networkRecorder:)`. Other personal data and plain-text bodies are kept as they are.
- `status` is `completed` (accepted response), `failed` (a `DioException`: rejected status code, timeout, connection error, cancel; the response is kept when there was one), or `pending`. A call is `pending` when it was still running at selection time, or when an interceptor added before this one ended it in `onError` (for example a retry interceptor that resolves the error). A call that an earlier interceptor answers in `onRequest` (for example from a cache) never reaches this interceptor and is not recorded. A retry with `dio.fetch` goes through the interceptor again and gets its own record.

One `network` entry:

```json
{
  "id": "000003",
  "status": "failed",
  "method": "POST",
  "url": "https://api.example.com/orders?lang=vi",
  "startedAtUtc": "2026-11-13T10:00:01.000Z",
  "endedAtUtc": "2026-11-13T10:00:01.240Z",
  "durationMs": 240,
  "request": {
    "headers": { "Authorization": "REDACTED", "content-type": "application/json" },
    "body": { "kind": "json", "value": { "productId": 7, "quantity": 2 }, "size": 28 }
  },
  "response": {
    "statusCode": 500,
    "headers": { "content-type": "application/json" },
    "body": { "kind": "json", "value": { "code": "internal" }, "size": 19 }
  },
  "error": { "type": "badResponse", "message": "..." }
}
```

`body.kind` is `json`, `text`, `bytes`, `formData`, `stream`, or `other` (only `valueType`). `response` is absent without a response, `error` without an error, `endedAtUtc` and `durationMs` while pending. Calls are the newest ones of the whole app, at most `maxReportRecords`, oldest first, not only those of the selected widget. Timestamps come from the device clock, like `capturedAtUtc`.

### API call history

While selecting, the toolbar shows **Inspect network** (`BugInspector.networkButtonKey`) below **Select screen** whenever the host has a `networkRecorder` (with the facade: after `install`). Its subtitle counts the kept calls and those that failed or returned a status code of 400 or more, and follows new calls. Tapping it leaves selection mode and pushes `BugNetworkHistoryPage` on the app's root navigator as `/qa-network-history`; the bug button hides until it closes.

`BugNetworkHistoryPage` lists every kept call, newest first, updated as calls start and end (`BugNetworkRecorder` is a `Listenable`). A tap opens the call details and the JSON tree, as in the report. **Clear** empties the recorder, so later reports no longer include those calls. To open it from an existing QA menu:

```dart
final recorder = FlutterQaInspector.networkRecorder;
if (recorder != null) {
  BugNetworkHistoryPage.open(context, recorder: recorder);
}
```

Each row in the API history and the report's **Network** section shows the host and duration, then the time the response was recorded, in the device's local time (`HH:mm:ss.SSS`, for example `Response: 17:00:01.240`). This uses `endedAtUtc`, the device clock when the call reaches the interceptor. An error without a response uses the localized **Error** label and the time the error was recorded; pending calls have no end time yet. Rows stay ordered by request start, newest first. Exported timestamps remain in UTC.

Like `BugReportPage`, a direct call does not check the compile-time define. Texts: `networkButtonLabel`, `networkButtonSubtitle`, `networkHistoryTitle`, `networkHistoryEmpty`, `networkClear`, `close` in `BugReportStrings`.

## Screenshots and annotations

Capture before opening a report so the form itself is not in the image. A callback that reuses the built-in report can do this:

```dart
Future<void> captureAndOpenReport(
  BuildContext widgetContext,
  BugWidgetSelection selection,
) async {
  final screenshot = await BugInspector.captureScreenshot(widgetContext);
  if (!widgetContext.mounted) return;
  await BugReportPage.open(
    widgetContext,
    selection: selection,
    screenshot: screenshot,
  );
}
```

`captureScreenshot` captures the host's child without its own launcher or overlay. By default it waits for the next frame so selection borders have disappeared. With `disableModeOnSelection: false`, disable mode first. Capture may return `null`; the report can still be sent without an image. Optional arguments are `pixelRatio`, `waitForNextFrame`, and `statusBar`.

`BugScreenshot.capturedAtUtc` is separate from the selection timestamp. `pngBytes` contains the raw app PNG, while `toJson()` describes the screenshot without its bytes. Use `toImageRect(selection.bounds)` to convert global logical pixels to image pixels.

### Simulated status bar

The real system status bar is not part of the app capture. On Android and iOS, when the content extends under the top safe area, the default capture adds `BugScreenshot.statusBar` metadata: a Pixel 8 style on Android or a Dynamic Island style on iOS, matching the safe-area height.

The clock uses capture time and the device's 12/24-hour preference; signal, Wi-Fi, and battery indicators are always full. Icons are black or white according to the app background. These are simulated graphics, not evidence of the actual device model, connectivity, or battery level.

The status bar is not in raw `pngBytes`. `BugScreenshotEditor` (including read-only previews) and `toAnnotatedPng` render it beneath the highlight and annotations. Use `captureScreenshot(context, statusBar: false)` to omit it.

### Custom preview, editor, and export

The built-in form handles annotation ownership and export. For your own form, create one `BugScreenshotAnnotationController` for its lifetime and dispose it when the form closes. Use the same controller for preview and editor. Given the captured `screenshot`, `selection`, and controller:

```dart
Widget reportPreview({
  required BugScreenshot screenshot,
  required BugWidgetSelection selection,
  required BugScreenshotAnnotationController annotations,
  required VoidCallback openEditor,
}) =>
    GestureDetector(
      onTap: openEditor,
      child: BugScreenshotEditor(
        screenshot: screenshot,
        controller: annotations,
        highlight: selection.bounds,
        readOnly: true,
      ),
    );

Widget reportEditor({
  required BugScreenshot screenshot,
  required BugWidgetSelection selection,
  required BugScreenshotAnnotationController annotations,
}) =>
    BugScreenshotEditor(
      screenshot: screenshot,
      controller: annotations,
      highlight: selection.bounds,
    );
```

For PNG export, pass the same highlight and styles as the editor:

```dart
final png = await screenshot.toAnnotatedPng(
  annotations.annotations,
  highlight: selection.bounds,
);
final metadata = {...screenshot.toJson(), 'annotations': annotations.toJson()};
```

Editor interactions:

- Drag on an empty part of the image to draw a rectangle. A tap without a drag clears selection without drawing.
- Tap a rectangle to select it; overlapping rectangles prefer the smallest. Drag a selected rectangle to move it.
- Drag one of its four corner handles to resize it. The opposite corner stays fixed; crossing it flips the rectangle.
- Tap the selected rectangle's close button (`BugScreenshotEditor.deleteButtonKey`) to delete it. The controller also exposes `removeSelected()`, `removeAt()`, and `clear()`.
- Rectangles stay within the image, with a minimum width and height of `BugScreenshotEditor.minRectSize` (16 logical screen pixels).
- Pinch with two fingers to zoom and pan, up to `maxZoom` (default 5). A second finger cancels the current draw/move/resize gesture; all fingers then control zoom until released. Releasing near fit-to-view resets the image. The zoom button (`resetZoomButtonKey`) also resets it. `maxZoom: 1` disables zoom. Strokes, handles, and touch targets retain their screen size at every zoom level.

The editor preserves image aspect ratio and uses the largest size allowed by its constraints. It claims gestures starting on the image immediately, so dragging does not scroll a parent list. Put the interactive editor on a separate page with bounded constraints; use `readOnly: true` for previews in a scrolling form.

`highlight` uses global logical pixels; do not pre-convert it. Annotation rectangles use image pixels (`coordinateUnit: image_pixels`), the same coordinates returned by `toImageRect`. Export renders the dashed highlight below the rectangles, with annotation strokes `strokeWidth * pixelRatio` image pixels wide. If you customize `color`, `strokeWidth`, or `highlightColor`, pass the same values to the editor and export. With no annotations, highlight, or simulated status bar, export returns the original PNG without re-encoding.

## Production builds

`BugInspector.enabledFromEnvironment` is a compile-time constant. Omitting the define or setting `--dart-define=FLUTTER_QA_INSPECTOR=false` gives these behaviors:

| Component | Without the define |
| --- | --- |
| `FlutterQaInspector` | `install` leaves `Bloc.observer` unchanged; `recorder` and `networkRecorder` are `null`; `wrap`/`builder` return the original child. |
| `BugInspector` | Returns `child`, regardless of `enabled`; no launcher, selection layer, or `InspectModeCubit` is created. |
| `BugInspectable`, `BugInspectablePage`, `.route` | Return `child`; no registration, extra render object, or `GlobalKey`. |
| `BugBlocScope.lazy` | Returns `child` and never calls `readBloc` during the inspector flow. |
| `BugInspectableWidget` | Overrides no widget methods; the inspector never calls `bugSnapshot()`. |
| `BugInspectorBlocObserver` | Records nothing, even if manually installed. |
| `BugInspectorDioInterceptor` | Records nothing and passes every request, response, and error on unchanged; `FlutterQaInspector.networkRecorder` is `null`. |
| `maybeModeCubitOf`, `captureScreenshot` | Return `null`. |
| `BugScreenshotEditor` | Builds an empty box. |
| `BugScreenshot.toAnnotatedPng` | Returns the original `pngBytes`. |

Direct marker/host wrappers still add widget elements, but no render objects. Their layout, paint, hit testing, and semantics remain unchanged. [production_build_test.dart](test/production_build_test.dart) checks render-tree and semantics parity against an app without the package. No current binary-size measurement is provided; historical measurements before the report/plugin integration do not describe version `0.10.0`.

The compile-time gate does not prevent evaluation of arguments supplied by your app. Keep these boundaries in mind:

- Prefer `BugBlocScope.lazy` over `BugBlocScope(bloc: context.read<T>())`; the latter reads its provider during build even in production.
- Gate app-owned QA recorders, observers, Dio interceptors, Cubits, and custom report entry points with `if (BugInspector.enabledFromEnvironment)`. The facade already gates its own installation and report entry point.
- Direct calls to `BugReportPage` and `BugReportBundle` still open forms or create bundles without the define; gate your own entry points if they must be QA-only.
- The native `share_plus` plugin remains included.
- Use `maybeModeCubitOf` instead of reading an inspector Cubit that does not exist in production.

Before release, ensure production commands and CI omit `FLUTTER_QA_INSPECTOR=true`, observer setup is gated, and lazy scopes are used where provider creation must remain unchanged.

## Integration notes

- With `Expanded`, `Flexible`, or `Positioned`, put the marker inside their `child` to preserve parent data. In sliver lists, mark box children inside the item builder or `SliverToBoxAdapter`, not the sliver itself.
- `widgetType` comes from `runtimeType`; builds using `--obfuscate` may shorten it. Use stable marker IDs such as `home.quick_add_water` and repository-relative `sourceFile` paths.
- Supply `sourceLine` only when known; source metadata can drift between builds and checkouts. Match the report to the correct app revision before investigating.
- Registry entries, timeline history, API calls, and annotations are not automatically persisted to disk. The exported bundle is the report artifact.

## Development and verification

From the package directory:

```sh
flutter pub get
flutter analyze
flutter test                                         # Production behavior
flutter test --dart-define=FLUTTER_QA_INSPECTOR=true   # QA behavior

cd example
flutter run --dart-define=FLUTTER_QA_INSPECTOR=true
```

The test suites gate QA-specific and production-specific groups separately; run both commands because either command skips the other mode's groups. For example changes, also run `flutter analyze` and `flutter test` from `example/`, adding the QA define when checking QA behavior.

Runtime acceptance checks for a host integration:

| Check | Expected behavior |
| --- | --- |
| Build without the QA define | No launcher or inspector observer installation through the facade; normal app behavior. |
| Enable and cancel selection | Borders appear without layout changes; pointer input is blocked only while selecting and resumes on exit. |
| Select an interactive widget | Correct ID, bounds, and snapshots; the business action is not triggered by the selection tap. |
| Select nested, clipped, or hidden markers | Selection follows visibility, hit-test priority, area, and depth rules. |
| Select a screen or tab | **Select screen** targets the current painted page and captures the declared page scopes. |
| Serialize one invalid snapshot | Its capture error is reported; other snapshots and history remain available. |
| Capture, annotate, and send | The screenshot precedes the form, annotations align with image coordinates, and the ZIP has the documented entries. |
| Exercise Android/iOS QA builds | Selection, navigation, editor, and sharing work on the target device with the host's build configuration. |

These are acceptance criteria, not a claim of device verification. Analyzer results and widget tests do not replace runtime checks on the target platforms. See the [example app](example/lib/app.dart) for an integration using existing app state and the built-in report flow.
