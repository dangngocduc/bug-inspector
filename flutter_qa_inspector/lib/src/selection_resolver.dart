part of '../flutter_qa_inspector.dart';

/// Collects the [_RenderBugInspectable]s reached by the hit test that is
/// currently running in [_resolveSelection], or `null` outside of it.
Set<_RenderBugInspectable>? _activeHitProbe;

/// Two areas closer than this, in square logical pixels, are considered equal.
const double _areaTolerance = 0.01;

/// Where an inspectable is on screen at the moment of the tap.
@immutable
class _InspectableGeometry {
  const _InspectableGeometry({
    required this.bounds,
    required this.visibleBounds,
    required this.pointerBlocked,
  });

  /// The bounding box in global logical pixels.
  final Rect bounds;

  /// [bounds] intersected with the paint clips of the ancestors.
  final Rect visibleBounds;

  /// Whether an `IgnorePointer` or `AbsorbPointer` of the app sits between
  /// the inspectable and the inspector content, so the hit test probe cannot
  /// reach it even when it is visible.
  final bool pointerBlocked;
}

class _InspectableCandidate {
  _InspectableCandidate({
    required this.node,
    required this.box,
    required this.geometry,
    required this.tier,
    required this.order,
  });

  final _InspectableNode node;
  final _RenderBugInspectable box;
  final _InspectableGeometry geometry;

  /// 0 when the inspectable is reachable by the hit test at the tap position,
  /// 1 when something else is likely painted on top of it.
  final int tier;

  /// Registration order, later registrations get higher values.
  final int order;

  late final double area = geometry.bounds.width * geometry.bounds.height;
  late final int depth = node._depth();

  bool beats(_InspectableCandidate other) {
    if (tier != other.tier) return tier < other.tier;
    final areaDifference = area - other.area;
    if (areaDifference.abs() > _areaTolerance) return areaDifference < 0;
    if (depth != other.depth) return depth > other.depth;
    return order > other.order;
  }
}

/// Finds the [BugInspectable] selected by a tap at [globalPosition].
///
/// Only inspectables that are painted, whose visible bounds contain the tap
/// and that are not covered by something reachable by a hit test are
/// preferred. Among them the smallest bounds win, and on equal area the
/// deepest widget in the tree wins. Pages are ignored.
_InspectableCandidate? _resolveSelection({
  required List<_InspectableNode> nodes,
  required RenderBox content,
  required Offset globalPosition,
}) {
  final reached = HashSet<_RenderBugInspectable>.identity();
  final previousProbe = _activeHitProbe;
  _activeHitProbe = reached;
  try {
    content.hitTest(
      BoxHitTestResult(),
      position: content.globalToLocal(globalPosition),
    );
  } finally {
    _activeHitProbe = previousProbe;
  }

  _InspectableCandidate? best;
  for (var order = 0; order < nodes.length; order++) {
    final node = nodes[order];
    if (node._isPage) continue;
    final box = node._renderBox;
    if (box == null || !box.paintedWithBorder) continue;

    final geometry = _measureInspectable(box, content);
    if (geometry == null || !geometry.visibleBounds.contains(globalPosition)) {
      continue;
    }

    final candidate = _InspectableCandidate(
      node: node,
      box: box,
      geometry: geometry,
      tier: reached.contains(box) || geometry.pointerBlocked ? 0 : 1,
      order: order,
    );
    if (best == null || candidate.beats(best)) best = candidate;
  }
  return best;
}

/// Finds the current [BugInspectablePage]: the topmost page that is painted
/// and not clipped away. When [globalPosition] is given, the page must also
/// contain it.
///
/// A page painted later wins, so a route pushed on top wins over the routes
/// below it, and a page nested in another page wins over its parent.
_InspectableCandidate? _resolveCurrentPage({
  required List<_InspectableNode> nodes,
  required RenderBox content,
  Offset? globalPosition,
}) {
  _InspectableCandidate? best;
  for (var order = 0; order < nodes.length; order++) {
    final node = nodes[order];
    if (!node._isPage) continue;
    final box = node._renderBox;
    if (box == null || !box.paintedWithBorder) continue;

    final geometry = _measureInspectable(box, content);
    if (geometry == null) continue;
    if (globalPosition != null &&
        !geometry.visibleBounds.contains(globalPosition)) {
      continue;
    }

    if (best == null || _paintsAbove(box, best.box)) {
      best = _InspectableCandidate(
        node: node,
        box: box,
        geometry: geometry,
        tier: 0,
        order: order,
      );
    }
  }
  return best;
}

/// Whether [a] is painted after [b].
///
/// A descendant is painted after its ancestor. Otherwise the render objects
/// are compared under their nearest common ancestor, where a later child is
/// painted after an earlier one, as in a `Stack` or the `Overlay` of a
/// `Navigator`.
bool _paintsAbove(RenderObject a, RenderObject b) {
  final pathA = _pathFromRoot(a);
  final pathB = _pathFromRoot(b);
  var index = 0;
  while (index < pathA.length &&
      index < pathB.length &&
      identical(pathA[index], pathB[index])) {
    index++;
  }
  // b is an ancestor of a, or they are the same object.
  if (index == pathB.length) return true;
  // a is an ancestor of b.
  if (index == pathA.length) return false;
  // Different render trees, keep the current choice.
  if (index == 0) return false;

  final childA = pathA[index];
  final childB = pathB[index];
  var position = 0;
  var positionA = -1;
  var positionB = -1;
  pathA[index - 1].visitChildren((child) {
    if (identical(child, childA)) positionA = position;
    if (identical(child, childB)) positionB = position;
    position++;
  });
  return positionA > positionB;
}

List<RenderObject> _pathFromRoot(RenderObject renderObject) {
  final path = <RenderObject>[];
  RenderObject? current = renderObject;
  while (current != null) {
    path.add(current);
    current = current.parent;
  }
  return path.reversed.toList();
}

/// Measures [box] in global logical pixels, or returns `null` when an
/// ancestor does not paint it or clips it away entirely.
_InspectableGeometry? _measureInspectable(RenderBox box, RenderObject content) {
  final bounds = MatrixUtils.transformRect(
    box.getTransformTo(null),
    Offset.zero & box.size,
  );

  var visibleBounds = bounds;
  var pointerBlocked = false;
  var reachedContent = false;
  RenderObject child = box;
  var parent = box.parent;
  while (parent != null) {
    if (!parent.paintsChild(child)) return null;

    final clip = parent.describeApproximatePaintClip(child);
    if (clip != null) {
      visibleBounds = visibleBounds.intersect(
        MatrixUtils.transformRect(parent.getTransformTo(null), clip),
      );
      if (visibleBounds.isEmpty) return null;
    }

    if (identical(parent, content)) {
      reachedContent = true;
    } else if (!reachedContent && _blocksPointers(parent)) {
      pointerBlocked = true;
    }

    child = parent;
    parent = parent.parent;
  }

  return _InspectableGeometry(
    bounds: bounds,
    visibleBounds: visibleBounds,
    pointerBlocked: reachedContent && pointerBlocked,
  );
}

bool _blocksPointers(RenderObject renderObject) {
  return (renderObject is RenderIgnorePointer && renderObject.ignoring) ||
      (renderObject is RenderAbsorbPointer && renderObject.absorbing) ||
      (renderObject is RenderSliverIgnorePointer && renderObject.ignoring);
}
