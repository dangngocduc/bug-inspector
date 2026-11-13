part of '../../flutter_qa_inspector.dart';

/// The open objects and lists of the JSON tree of one body, shared by the
/// expand and collapse buttons of its header and by its rows.
class _JsonTreeController extends ChangeNotifier {
  _JsonTreeController(this.json) : _expanded = _initialPaths(json);

  /// A JSON object or list, see [canShow].
  final Object json;

  /// The paths of the open objects and lists.
  Set<String> _expanded;

  List<_JsonRow>? _rows;

  /// At most this many rows are on screen when the tree first shows, unless
  /// the root alone has more children.
  static const int initialRowLimit = 100;

  /// Whether [value] can be shown as a tree: a JSON object or list.
  static bool canShow(Object? value) =>
      value is Map<String, Object?> || value is List<Object?>;

  /// The rows on screen, the root first.
  List<_JsonRow> get rows => _rows ??= _JsonRow.flatten(json, _expanded);

  bool isExpanded(String path) => _expanded.contains(path);

  /// Opens or closes the object or list at [path].
  void toggle(String path) {
    final expanded = {..._expanded};
    if (!expanded.remove(path)) expanded.add(path);
    _set(expanded);
  }

  /// Opens every object and list.
  void expandAll() => _set(_pathsUpTo(json, null));

  /// Closes every object and list but the root.
  void collapseAll() => _set(_pathsUpTo(json, 0));

  void _set(Set<String> expanded) {
    _expanded = expanded;
    _rows = null;
    notifyListeners();
  }

  /// The root, then one more level at a time while the rows on screen stay
  /// within [initialRowLimit]: a small body shows whole, a long list shows
  /// its items closed.
  static Set<String> _initialPaths(Object json) {
    var paths = _pathsUpTo(json, 0);
    for (var depth = 1;; depth++) {
      final next = _pathsUpTo(json, depth);
      if (next.length == paths.length ||
          _JsonRow.flatten(json, next).length > initialRowLimit) {
        return paths;
      }
      paths = next;
    }
  }

  /// The paths of the objects and lists down to [depth], the root being 0.
  static Set<String> _pathsUpTo(Object json, int? depth) {
    final paths = <String>{};
    void visit(Object? value, String path, int level) {
      if (!canShow(value)) return;
      if (depth != null && level > depth) return;
      paths.add(path);
      for (final child in _JsonRow.childrenOf(value, path)) {
        visit(child.value, child.path, level + 1);
      }
    }

    visit(json, _JsonRow.rootPath, 0);
    return paths;
  }
}

/// The slivers of a JSON body section: a header with [title] and the
/// expand and collapse buttons, then the rows of the tree in a rounded box,
/// built as they scroll into view.
///
/// [section] names the body in the keys of the buttons, for example
/// `response`: `bug_report.json.response.expand_all`.
List<Widget> _jsonTreeSlivers({
  required String title,
  required String section,
  required _JsonTreeController controller,
  required BugReportStrings strings,
}) {
  return <Widget>[
    SliverToBoxAdapter(
      child: Padding(
        // The header margin of CupertinoListSection.insetGrouped.
        padding: const EdgeInsetsDirectional.fromSTEB(20, 16, 20, 6),
        child: Row(
          children: [
            Expanded(child: _ReportSectionHeader(title)),
            _JsonHeaderButton(
              key: ValueKey<String>('bug_report.json.$section.expand_all'),
              icon: CupertinoIcons.rectangle_expand_vertical,
              label: strings.jsonExpandAll,
              onPressed: controller.expandAll,
            ),
            const SizedBox(width: 12),
            _JsonHeaderButton(
              key: ValueKey<String>('bug_report.json.$section.collapse_all'),
              icon: CupertinoIcons.rectangle_compress_vertical,
              label: strings.jsonCollapseAll,
              onPressed: controller.collapseAll,
            ),
          ],
        ),
      ),
    ),
    SliverPadding(
      // The rows margin of CupertinoListSection.insetGrouped.
      padding: const EdgeInsetsDirectional.fromSTEB(20, 0, 20, 10),
      sliver: Builder(
        builder: (context) => DecoratedSliver(
          decoration: BoxDecoration(
            color: CupertinoColors.secondarySystemGroupedBackground
                .resolveFrom(context),
            borderRadius: const BorderRadius.all(Radius.circular(10)),
          ),
          sliver: SliverPadding(
            padding: const EdgeInsets.fromLTRB(6, 10, 10, 10),
            sliver: ListenableBuilder(
              listenable: controller,
              builder: (context, _) {
                final rows = controller.rows;
                return SliverList.builder(
                  itemCount: rows.length,
                  itemBuilder: (context, index) {
                    final row = rows[index];
                    return _JsonRowView(
                      row: row,
                      expanded: controller.isExpanded(row.path),
                      strings: strings,
                      onToggle: row.isContainer
                          ? () => controller.toggle(row.path)
                          : null,
                    );
                  },
                );
              },
            ),
          ),
        ),
      ),
    ),
  ];
}

/// The expand or collapse button in the header of a JSON body section.
class _JsonHeaderButton extends StatelessWidget {
  const _JsonHeaderButton({
    super.key,
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return CupertinoButton(
      sizeStyle: CupertinoButtonSize.small,
      padding: EdgeInsets.zero,
      minimumSize: Size.zero,
      onPressed: onPressed,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16),
          const SizedBox(width: 4),
          Text(label, style: const TextStyle(fontSize: 13)),
        ],
      ),
    );
  }
}

/// One visible line of the tree.
@immutable
class _JsonRow {
  const _JsonRow({
    required this.path,
    required this.value,
    required this.isLast,
    this.key,
    this.index,
  });

  /// The path of the root value.
  static const String rootPath = r'$';

  /// Identifies the value in the tree. A separator that JSON keys rarely
  /// hold keeps `a.b` and `a` > `b` apart.
  final String path;

  /// The key in its parent object, or `null`.
  final String? key;

  /// The index in its parent list, or `null`.
  final int? index;

  final Object? value;

  /// For each level from 1 to [depth]: whether the ancestor at that level,
  /// then this row itself, is the last child of its parent. It tells which
  /// guide lines go on below the row.
  final List<bool> isLast;

  int get depth => isLast.length;

  bool get isContainer => _JsonTreeController.canShow(value);

  int get count => switch (value) {
        final Map<String, Object?> map => map.length,
        final List<Object?> list => list.length,
        _ => 0,
      };

  /// The children of [value] as rows one level down, without [isLast].
  static Iterable<_JsonRow> childrenOf(Object? value, String path) sync* {
    if (value is Map<String, Object?>) {
      for (final entry in value.entries) {
        yield _JsonRow(
          path: '$path\u0001${entry.key}',
          key: entry.key,
          value: entry.value,
          isLast: const [],
        );
      }
    } else if (value is List<Object?>) {
      for (var i = 0; i < value.length; i++) {
        yield _JsonRow(
          path: '$path\u0001[$i]',
          index: i,
          value: value[i],
          isLast: const [],
        );
      }
    }
  }

  /// The rows on screen: [root], and the children of the [expanded] paths.
  static List<_JsonRow> flatten(Object root, Set<String> expanded) {
    final rows = <_JsonRow>[];
    void visit(_JsonRow row) {
      rows.add(row);
      if (!row.isContainer || !expanded.contains(row.path)) return;
      final children = childrenOf(row.value, row.path).toList();
      for (var i = 0; i < children.length; i++) {
        final child = children[i];
        visit(
          _JsonRow(
            path: child.path,
            key: child.key,
            index: child.index,
            value: child.value,
            isLast: [...row.isLast, i == children.length - 1],
          ),
        );
      }
    }

    visit(_JsonRow(path: rootPath, value: root, isLast: const []));
    return rows;
  }
}

/// The colors of the tree, for light and dark mode.
abstract final class _JsonColors {
  static const key = CupertinoDynamicColor.withBrightness(
    color: Color(0xFF7B2FBE),
    darkColor: Color(0xFFD2A8FF),
  );
  static const string = CupertinoDynamicColor.withBrightness(
    color: Color(0xFF1A7F37),
    darkColor: Color(0xFF7EE787),
  );
  static const number = CupertinoDynamicColor.withBrightness(
    color: Color(0xFF0550AE),
    darkColor: Color(0xFF79C0FF),
  );
  static const boolean = CupertinoDynamicColor.withBrightness(
    color: Color(0xFFC2410C),
    darkColor: Color(0xFFFFA657),
  );
  static const object = CupertinoColors.systemBlue;
  static const list = CupertinoColors.systemPurple;
}

const TextStyle _jsonTextStyle = TextStyle(
  fontFamily: 'Menlo',
  fontFamilyFallback: ['Courier', 'monospace'],
  fontSize: 13,
  height: 1.5,
);

/// One line of the tree, with its guide lines.
class _JsonRowView extends StatelessWidget {
  const _JsonRowView({
    required this.row,
    required this.expanded,
    required this.strings,
    required this.onToggle,
  });

  final _JsonRow row;
  final bool expanded;
  final BugReportStrings strings;

  /// Opens or closes an object or a list; `null` for a value.
  final VoidCallback? onToggle;

  /// The width of one level of the tree.
  static const double indent = 22;

  /// The minimum height of a row, and twice the center of its first line.
  static const double lineHeight = 30;

  @override
  Widget build(BuildContext context) {
    final label = CupertinoColors.label.resolveFrom(context);
    final keyColor = _JsonColors.key.resolveFrom(context);
    final value = row.value;
    final isList = value is List<Object?>;
    final keySpans = <InlineSpan>[
      if (row.key != null) ...[
        TextSpan(
          text: jsonEncode(row.key),
          style: TextStyle(color: keyColor, fontWeight: FontWeight.w600),
        ),
        TextSpan(text: ': ', style: TextStyle(color: label)),
      ],
    ];
    // Like the reference layout: `0 { } 2 items`, `{ } "profile": 3 items`,
    // `"id": 1024`, `0 : "admin"`.
    final content = <InlineSpan>[
      if (row.index != null) ...[
        WidgetSpan(
          alignment: PlaceholderAlignment.middle,
          child: _JsonPill(
            text: '${row.index}',
            color: keyColor,
            background: _JsonColors.list.resolveFrom(context).withAlpha(30),
          ),
        ),
        TextSpan(
          text: row.isContainer ? ' ' : ' : ',
          style: TextStyle(color: label),
        ),
      ],
      if (row.isContainer) ...[
        TextSpan(
          text: isList ? '[ ] ' : '{ } ',
          style: TextStyle(
            color: (isList ? _JsonColors.list : _JsonColors.object)
                .resolveFrom(context),
            fontWeight: FontWeight.w700,
          ),
        ),
        ...keySpans,
        WidgetSpan(
          alignment: PlaceholderAlignment.middle,
          child: _JsonPill(
            text: strings.jsonItemCount(row.count),
            color: CupertinoColors.secondaryLabel.resolveFrom(context),
            background: CupertinoColors.tertiarySystemFill.resolveFrom(context),
          ),
        ),
      ] else ...[
        ...keySpans,
        _valueSpan(context, value),
      ],
    ];

    final line = Padding(
      padding: EdgeInsets.only(left: row.depth * indent),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: indent,
            height: lineHeight,
            child: row.isContainer
                ? AnimatedRotation(
                    turns: expanded ? 0.25 : 0,
                    duration: const Duration(milliseconds: 150),
                    child: Icon(
                      CupertinoIcons.chevron_right,
                      size: 15,
                      color:
                          CupertinoColors.secondaryLabel.resolveFrom(context),
                    ),
                  )
                : null,
          ),
          const SizedBox(width: 4),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Text.rich(
                TextSpan(children: content),
                style: _jsonTextStyle.copyWith(color: label),
              ),
            ),
          ),
        ],
      ),
    );

    final view = CustomPaint(
      painter: _JsonGuidePainter(
        isLast: row.isLast,
        color: CupertinoColors.separator.resolveFrom(context),
        indent: indent,
        lineCenter: lineHeight / 2,
        // The chevron of an object or list starts where the guide ends.
        tick: row.isContainer ? 2 : indent,
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: lineHeight),
        child: line,
      ),
    );
    if (onToggle == null) return view;
    return Semantics(
      button: true,
      expanded: expanded,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onToggle,
        child: view,
      ),
    );
  }

  static InlineSpan _valueSpan(BuildContext context, Object? value) {
    return switch (value) {
      null => WidgetSpan(
          alignment: PlaceholderAlignment.middle,
          child: _JsonPill(
            text: 'null',
            color: CupertinoColors.label.resolveFrom(context),
            background: CupertinoColors.tertiarySystemFill.resolveFrom(context),
          ),
        ),
      final String text => TextSpan(
          text: jsonEncode(text),
          style: TextStyle(color: _JsonColors.string.resolveFrom(context)),
        ),
      final bool flag => TextSpan(
          text: '$flag',
          style: TextStyle(color: _JsonColors.boolean.resolveFrom(context)),
        ),
      final num number => TextSpan(
          text: '$number',
          style: TextStyle(color: _JsonColors.number.resolveFrom(context)),
        ),
      _ => TextSpan(text: '$value'),
    };
  }
}

/// A rounded label: an item count, a list index or `null`.
class _JsonPill extends StatelessWidget {
  const _JsonPill({
    required this.text,
    required this.color,
    required this.background,
  });

  final String text;
  final Color color;
  final Color background;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: ShapeDecoration(
        color: background,
        shape: const StadiumBorder(),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 1),
        child: Text(
          text,
          style: _jsonTextStyle.copyWith(
            fontSize: 12,
            height: 1.4,
            color: color,
            fontFamily:
                CupertinoTheme.of(context).textTheme.textStyle.fontFamily,
          ),
        ),
      ),
    );
  }
}

/// Draws the guide lines of a row: a vertical line for every ancestor that
/// has more children below, and a branch to the row itself.
class _JsonGuidePainter extends CustomPainter {
  const _JsonGuidePainter({
    required this.isLast,
    required this.color,
    required this.indent,
    required this.lineCenter,
    required this.tick,
  });

  final List<bool> isLast;
  final Color color;
  final double indent;
  final double lineCenter;
  final double tick;

  @override
  void paint(Canvas canvas, Size size) {
    if (isLast.isEmpty) return;
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1;
    final depth = isLast.length;
    for (var level = 1; level <= depth; level++) {
      // The column of the children of the row at level - 1.
      final x = (level - 1) * indent + indent / 2;
      final last = isLast[level - 1];
      if (level < depth) {
        if (!last) canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
      } else {
        canvas
          ..drawLine(
            Offset(x, 0),
            Offset(x, last ? lineCenter : size.height),
            paint,
          )
          ..drawLine(
            Offset(x, lineCenter),
            Offset(x + indent / 2 + tick, lineCenter),
            paint,
          );
      }
    }
  }

  @override
  bool shouldRepaint(_JsonGuidePainter oldDelegate) =>
      !listEquals(oldDelegate.isLast, isLast) ||
      oldDelegate.color != color ||
      oldDelegate.indent != indent ||
      oldDelegate.lineCenter != lineCenter ||
      oldDelegate.tick != tick;
}
