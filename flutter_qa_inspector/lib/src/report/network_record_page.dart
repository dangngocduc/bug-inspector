part of '../../flutter_qa_inspector.dart';

/// The rows of the network section of [BugReportPage] and of
/// [BugNetworkHistoryPage]: one per call, newest first. A tap opens the
/// details of the call in the navigator of [context], with [backTitle] on
/// its back button.
List<Widget> _networkTiles(
  BuildContext context,
  List<BugNetworkRecord> network,
  BugReportStrings strings, {
  required String backTitle,
}) {
  return <Widget>[
    for (final record in network.reversed)
      CupertinoListTile(
        key: ValueKey<String>('bug_report.network.${record.id}'),
        title: Text(
          '${record.method} ${_networkPath(record.url)}',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(
          <String>[
            _networkHost(record.url),
            if (record.duration != null)
              '${record.duration!.inMilliseconds} ms',
          ].where((part) => part.isNotEmpty).join(' · '),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        additionalInfo: Text(
          _networkStatusLabel(record, strings),
          style: TextStyle(color: _networkStatusColor(record, context)),
        ),
        trailing: const CupertinoListTileChevron(),
        onTap: () => _NetworkRecordPage.open(
          context,
          record: record,
          strings: strings,
          backTitle: backTitle,
        ),
      ),
  ];
}

/// The path and the query of [url], or [url] when it cannot be parsed.
String _networkPath(String url) {
  final uri = Uri.tryParse(url);
  if (uri == null || !uri.hasAuthority) return url;
  final path = uri.path.isEmpty ? '/' : uri.path;
  return uri.hasQuery ? '$path?${uri.query}' : path;
}

String _networkHost(String url) {
  final uri = Uri.tryParse(url);
  if (uri == null || !uri.hasAuthority) return '';
  return uri.hasPort ? '${uri.host}:${uri.port}' : uri.host;
}

/// The status code, the error type of a call without a response, or
/// [BugReportStrings.networkPending].
String _networkStatusLabel(BugNetworkRecord record, BugReportStrings strings) {
  final code = record.statusCode;
  if (code != null) return '$code';
  return switch (record.status) {
    BugNetworkRecordStatus.pending => strings.networkPending,
    _ => record.errorType ?? record.status.name,
  };
}

Color _networkStatusColor(BugNetworkRecord record, BuildContext context) {
  final code = record.statusCode;
  final color = record.status == BugNetworkRecordStatus.failed ||
          (code != null && code >= 400)
      ? CupertinoColors.systemRed
      : record.status == BugNetworkRecordStatus.pending
          ? CupertinoColors.systemOrange
          : CupertinoColors.systemGreen;
  return color.resolveFrom(context);
}

/// The details of one API call: URL, status, timing, error, headers and
/// bodies. A whole JSON object or list body shows as a collapsible tree,
/// other bodies and the headers as selectable text.
class _NetworkRecordPage extends StatefulWidget {
  const _NetworkRecordPage({
    required this.record,
    required this.strings,
    required this.backTitle,
  });

  final BugNetworkRecord record;
  final BugReportStrings strings;

  /// The title of the page below, on the back button.
  final String backTitle;

  /// Opens the page in the navigator of [context], the report's navigator.
  static Future<void> open(
    BuildContext context, {
    required BugNetworkRecord record,
    required BugReportStrings strings,
    required String backTitle,
  }) {
    return Navigator.of(context).push<void>(
      CupertinoPageRoute<void>(
        builder: (_) => _NetworkRecordPage(
          record: record,
          strings: strings,
          backTitle: backTitle,
        ),
      ),
    );
  }

  @override
  State<_NetworkRecordPage> createState() => _NetworkRecordPageState();
}

class _NetworkRecordPageState extends State<_NetworkRecordPage> {
  /// The trees of the bodies that are whole JSON objects or lists.
  late final _JsonTreeController? _requestTree =
      _treeOf(widget.record.requestBody);
  late final _JsonTreeController? _responseTree =
      _treeOf(widget.record.responseBody);

  /// A tree for [body], or `null` when it is not a whole JSON object or list:
  /// a body cut by [BugNetworkRecorder.maxBodyLength] is only text.
  static _JsonTreeController? _treeOf(BugNetworkBody? body) {
    final json = body?.value;
    if (body == null ||
        body.kind != BugNetworkBodyKind.json ||
        body.truncated ||
        json == null ||
        !_JsonTreeController.canShow(json)) {
      return null;
    }
    return _JsonTreeController(json);
  }

  @override
  void dispose() {
    _requestTree?.dispose();
    _responseTree?.dispose();
    super.dispose();
  }

  static const JsonEncoder _json = JsonEncoder.withIndent('  ');

  static String _bodyText(BugNetworkBody body) {
    final value = body.value;
    return switch (body.kind) {
      BugNetworkBodyKind.json ||
      BugNetworkBodyKind.text when value is String =>
        value,
      BugNetworkBodyKind.json ||
      BugNetworkBodyKind.formData =>
        _json.convert(value),
      BugNetworkBodyKind.text => '',
      BugNetworkBodyKind.bytes => '<${body.size ?? '?'} bytes>',
      BugNetworkBodyKind.stream => '<stream>',
      BugNetworkBodyKind.other => '<${body.valueType ?? 'unknown'}>',
    };
  }

  String? _truncatedNote(BugNetworkBody body) {
    if (!body.truncated) return null;
    final value = body.value;
    final shown = value is String ? value.length : 0;
    return widget.strings.networkTruncated(shown, body.size ?? shown);
  }

  /// The slivers of a body: a tree, or a text section.
  List<Widget> _bodySlivers(
    BugNetworkBody? body,
    _JsonTreeController? tree, {
    required String title,
    required String section,
  }) {
    if (body == null) return const <Widget>[];
    if (tree != null) {
      return _jsonTreeSlivers(
        title: title,
        section: section,
        controller: tree,
        strings: widget.strings,
      );
    }
    return <Widget>[
      SliverToBoxAdapter(
        child: _NetworkSection(
          title: title,
          text: _bodyText(body),
          footer: _truncatedNote(body),
        ),
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final record = widget.record;
    final strings = widget.strings;
    final title = '${record.method} ${_networkStatusLabel(record, strings)}';

    return CupertinoPageScaffold(
      backgroundColor: CupertinoColors.systemGroupedBackground,
      navigationBar: CupertinoNavigationBar(
        previousPageTitle: widget.backTitle,
        middle: Text(title),
        trailing: _CopyTextButton(
          text: () => jsonEncode(record.toJson()),
          strings: strings,
        ),
      ),
      // Slivers, so a long JSON tree builds its rows as they scroll in.
      child: CustomScrollView(
        slivers: [
          SliverSafeArea(
            sliver: SliverMainAxisGroup(
              slivers: [
                // The request: path, headers, body.
                SliverToBoxAdapter(
                  child: _NetworkSection(
                    title: strings.networkRequest,
                    child: _RequestPathView(record: record),
                  ),
                ),
                if (record.requestHeaders.isNotEmpty)
                  SliverToBoxAdapter(
                    child: _NetworkSection(
                      title: strings.networkRequestHeaders,
                      child: _HeadersView(
                        headers: record.requestHeaders,
                        strings: strings,
                      ),
                    ),
                  ),
                ..._bodySlivers(
                  record.requestBody,
                  _requestTree,
                  title: strings.networkRequestBody,
                  section: 'request',
                ),
                // The response: status and timing, error, headers, body.
                SliverToBoxAdapter(
                  child: _NetworkSection(
                    title: strings.networkResponse,
                    child: _ResponseStatusView(
                      record: record,
                      strings: strings,
                    ),
                  ),
                ),
                if (record.errorType != null)
                  SliverToBoxAdapter(
                    child: _NetworkSection(
                      title: strings.networkError,
                      text: <String>[
                        record.errorType!,
                        if (record.errorCauseType != null)
                          record.errorCauseType!,
                        if (record.errorMessage != null) record.errorMessage!,
                      ].join('\n'),
                    ),
                  ),
                if (record.responseHeaders.isNotEmpty)
                  SliverToBoxAdapter(
                    child: _NetworkSection(
                      title: strings.networkResponseHeaders,
                      child: _HeadersView(
                        headers: record.responseHeaders,
                        strings: strings,
                      ),
                    ),
                  ),
                ..._bodySlivers(
                  record.responseBody,
                  _responseTree,
                  title: strings.networkResponseBody,
                  section: 'response',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// The monospace text of the call page.
TextStyle _networkTextStyle(BuildContext context) => TextStyle(
      fontFamily: 'Menlo',
      fontFamilyFallback: const ['Courier', 'monospace'],
      fontSize: 12,
      height: 1.4,
      color: CupertinoColors.label.resolveFrom(context),
    );

/// The method and the path of a call, with the names and values of its
/// query parameters in their own colors, below the scheme and host.
class _RequestPathView extends StatelessWidget {
  const _RequestPathView({required this.record});

  final BugNetworkRecord record;

  /// The text of a query part, decoded when it can be.
  static String _decoded(String part) {
    try {
      return Uri.decodeQueryComponent(part);
    } on ArgumentError {
      return part;
    }
  }

  /// A query value: greyed out when redacted, like a header value.
  static TextSpan _valueSpan(BuildContext context, String value) => TextSpan(
        text: value,
        style: value == BugNetworkRecorder.redactedValue
            ? TextStyle(
                color: CupertinoColors.secondaryLabel.resolveFrom(context),
                fontStyle: FontStyle.italic,
              )
            : TextStyle(color: _JsonColors.string.resolveFrom(context)),
      );

  @override
  Widget build(BuildContext context) {
    final uri = Uri.tryParse(record.url);
    final style = _networkTextStyle(context);
    final secondary = CupertinoColors.secondaryLabel.resolveFrom(context);
    final hasAuthority = uri != null && uri.hasAuthority;
    final origin = hasAuthority
        ? '${uri.scheme}://${uri.host}${uri.hasPort ? ':${uri.port}' : ''}'
        : null;
    final path = !hasAuthority
        ? record.url
        : uri.path.isEmpty
            ? '/'
            : uri.path;
    final query = hasAuthority && uri.hasQuery ? uri.query : '';
    final parts = query.isEmpty ? const <String>[] : query.split('&');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (origin != null) ...[
          Text(origin, style: style.copyWith(color: secondary, fontSize: 11)),
          const SizedBox(height: 4),
        ],
        SelectableText.rich(
          TextSpan(
            style: style.copyWith(fontSize: 13),
            children: [
              TextSpan(
                text: '${record.method} ',
                style: TextStyle(
                  color: _JsonColors.object.resolveFrom(context),
                  fontWeight: FontWeight.w700,
                ),
              ),
              TextSpan(text: path),
              for (var i = 0; i < parts.length; i++) ...[
                TextSpan(
                  text: i == 0 ? '?' : '&',
                  style: TextStyle(color: secondary),
                ),
                TextSpan(
                  text: _decoded(parts[i].split('=').first),
                  style: TextStyle(
                    color: _JsonColors.key.resolveFrom(context),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (parts[i].contains('=')) ...[
                  TextSpan(text: '=', style: TextStyle(color: secondary)),
                  _valueSpan(
                    context,
                    _decoded(parts[i].substring(parts[i].indexOf('=') + 1)),
                  ),
                ],
              ],
            ],
          ),
        ),
      ],
    );
  }
}

/// The headers of a call, one per row: the name, the value and a button
/// that copies the value. A redacted value is greyed out and not copied.
class _HeadersView extends StatelessWidget {
  const _HeadersView({required this.headers, required this.strings});

  final Map<String, String> headers;
  final BugReportStrings strings;

  @override
  Widget build(BuildContext context) {
    final style = _networkTextStyle(context);
    final entries = headers.entries.toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < entries.length; i++) ...[
          if (i > 0)
            Container(
              height: 0.5,
              margin: const EdgeInsets.symmetric(vertical: 6),
              color: CupertinoColors.separator.resolveFrom(context),
            ),
          _HeaderRow(
            name: entries[i].key,
            value: entries[i].value,
            style: style,
            strings: strings,
          ),
        ],
      ],
    );
  }
}

class _HeaderRow extends StatefulWidget {
  const _HeaderRow({
    required this.name,
    required this.value,
    required this.style,
    required this.strings,
  });

  final String name;
  final String value;
  final TextStyle style;
  final BugReportStrings strings;

  @override
  State<_HeaderRow> createState() => _HeaderRowState();
}

class _HeaderRowState extends State<_HeaderRow> {
  bool _copied = false;
  Timer? _timer;

  bool get _redacted => widget.value == BugNetworkRecorder.redactedValue;

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _copy() async {
    await Clipboard.setData(ClipboardData(text: widget.value));
    if (!mounted) return;
    unawaited(HapticFeedback.lightImpact());
    setState(() => _copied = true);
    _timer?.cancel();
    _timer = Timer(const Duration(seconds: 2), () {
      if (mounted) setState(() => _copied = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    final style = widget.style;
    final secondary = CupertinoColors.secondaryLabel.resolveFrom(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.name,
                style: style.copyWith(
                  color: _JsonColors.key.resolveFrom(context),
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 2),
              SelectableText(
                widget.value,
                style: _redacted
                    ? style.copyWith(
                        color: secondary,
                        fontStyle: FontStyle.italic,
                      )
                    : style,
              ),
            ],
          ),
        ),
        if (!_redacted)
          Semantics(
            button: true,
            label: '${widget.strings.copyValue}: ${widget.name}',
            excludeSemantics: true,
            child: CupertinoButton(
              key: ValueKey<String>('bug_report.header.copy.${widget.name}'),
              padding: const EdgeInsets.only(left: 8),
              minimumSize: const Size(32, 32),
              onPressed: _copy,
              child: Icon(
                _copied
                    ? CupertinoIcons.checkmark_alt
                    : CupertinoIcons.doc_on_doc,
                size: 18,
                color: _copied
                    ? CupertinoColors.systemGreen.resolveFrom(context)
                    : null,
              ),
            ),
          ),
      ],
    );
  }
}

/// The status code and message, the duration and the start time of a call.
class _ResponseStatusView extends StatelessWidget {
  const _ResponseStatusView({required this.record, required this.strings});

  final BugNetworkRecord record;
  final BugReportStrings strings;

  @override
  Widget build(BuildContext context) {
    final style = _networkTextStyle(context);
    final duration = record.duration;
    final secondary = CupertinoColors.secondaryLabel.resolveFrom(context);
    final status = <String>[
      _networkStatusLabel(record, strings),
      if (record.statusCode != null &&
          (record.statusMessage?.isNotEmpty ?? false))
        record.statusMessage!,
    ].join(' ');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                status,
                style: style.copyWith(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: _networkStatusColor(record, context),
                ),
              ),
            ),
            if (duration != null)
              Text(
                '${duration.inMilliseconds} ms',
                style: style.copyWith(color: secondary),
              ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          '${record.startedAtUtc.toUtc().toIso8601String()} UTC',
          style: style.copyWith(color: secondary, fontSize: 11),
        ),
      ],
    );
  }
}

/// A section of [_NetworkRecordPage]: [child], or a selectable monospace
/// [text].
class _NetworkSection extends StatelessWidget {
  const _NetworkSection({
    required this.title,
    this.text = '',
    this.child,
    this.footer,
  });

  final String title;
  final String text;
  final Widget? child;
  final String? footer;

  @override
  Widget build(BuildContext context) {
    final footer = this.footer;
    return CupertinoListSection.insetGrouped(
      header: _ReportSectionHeader(title),
      footer: footer == null ? null : _ReportSectionFooter(footer),
      children: [
        // CupertinoListSection gives its rows a loose width: fill it, so a
        // short text does not shrink the section.
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          child:
              child ?? SelectableText(text, style: _networkTextStyle(context)),
        ),
      ],
    );
  }
}

/// Copies [text], then says so for a moment.
class _CopyTextButton extends StatefulWidget {
  const _CopyTextButton({required this.text, required this.strings});

  /// The copied text, built on tap.
  final String Function() text;
  final BugReportStrings strings;

  @override
  State<_CopyTextButton> createState() => _CopyTextButtonState();
}

class _CopyTextButtonState extends State<_CopyTextButton> {
  bool _copied = false;
  Timer? _timer;

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _copy() async {
    await Clipboard.setData(ClipboardData(text: widget.text()));
    if (!mounted) return;
    unawaited(HapticFeedback.lightImpact());
    setState(() => _copied = true);
    _timer?.cancel();
    _timer = Timer(const Duration(seconds: 2), () {
      if (mounted) setState(() => _copied = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoButton(
      padding: EdgeInsets.zero,
      onPressed: _copy,
      child: Text(_copied ? widget.strings.copied : widget.strings.copyJson),
    );
  }
}
