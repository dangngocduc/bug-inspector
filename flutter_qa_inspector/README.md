# flutter_qa_inspector

A Flutter inspector for QA builds. Testers can select a widget or a whole
screen and share a bug report with:

- Widget metadata and explicitly exposed widget parameters.
- BLoC/Cubit state snapshots and a recent activity timeline.
- Recorded Dio requests and responses, with configurable redaction.
- An annotated screenshot, a description, and inspector data in a ZIP.

The inspector requires `--dart-define=FLUTTER_QA_INSPECTOR=true`.
Without this flag, the default inspector integration leaves the app content
unchanged. State snapshots require explicit markers and scopes; the package
does not automatically discover widget state or BLoC dependencies.

See the [full documentation](https://github.com/dangngocduc/bug-inspector#readme)
for installation, integration, public APIs, production behavior, and native
plugin requirements. The [example app](example/) demonstrates the built-in
reporting flow.
