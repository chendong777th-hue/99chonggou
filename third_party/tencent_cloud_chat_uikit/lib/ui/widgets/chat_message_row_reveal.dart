import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

/// Layout-only wrapper for a complete sliver message row.
///
/// Multiple rows can share [progress], so a burst uses one controller and one
/// layout transaction. The child is laid out at its real height while this
/// wrapper exposes only the animated fraction to the surrounding SliverList.
///
/// Progress is applied in [performLayout] (not via a rebuild/`SizeTransition`),
/// so callers can `controller.value = 1` + `flushLayout()` in the same frame
/// and immediately measure/jump before the next paint — which keeps send and
/// receive on the same viewport-scroll push path without a bottom flash.
class ChatMessageRowReveal extends SingleChildRenderObjectWidget {
  const ChatMessageRowReveal({
    super.key,
    required this.progress,
    this.onFullHeightChanged,
    required Widget child,
  }) : super(child: child);

  final Animation<double> progress;

  /// Reports the child's full layout height even while the exposed row is zero.
  final ValueChanged<double>? onFullHeightChanged;

  @override
  RenderObject createRenderObject(BuildContext context) {
    return RenderChatMessageRowReveal(
      progress: progress,
      onFullHeightChanged: onFullHeightChanged,
    );
  }

  @override
  void updateRenderObject(
    BuildContext context,
    RenderChatMessageRowReveal renderObject,
  ) {
    renderObject.progress = progress;
    renderObject.onFullHeightChanged = onFullHeightChanged;
  }
}

class RenderChatMessageRowReveal extends RenderBox
    with RenderObjectWithChildMixin<RenderBox> {
  RenderChatMessageRowReveal({
    required Animation<double> progress,
    ValueChanged<double>? onFullHeightChanged,
  })  : _progress = progress,
        _onFullHeightChanged = onFullHeightChanged;

  Animation<double> _progress;
  ValueChanged<double>? _onFullHeightChanged;
  double? _lastReportedFullHeight;

  Animation<double> get progress => _progress;

  set progress(Animation<double> value) {
    if (identical(_progress, value)) {
      return;
    }
    if (attached) {
      _progress.removeListener(_handleProgress);
    }
    _progress = value;
    if (attached) {
      _progress.addListener(_handleProgress);
    }
    markNeedsLayout();
  }

  set onFullHeightChanged(ValueChanged<double>? value) {
    if (identical(_onFullHeightChanged, value)) {
      return;
    }
    _onFullHeightChanged = value;
    final fullHeight = _lastReportedFullHeight;
    if (fullHeight != null && fullHeight > 0) {
      value?.call(fullHeight);
    }
  }

  void _handleProgress() {
    markNeedsLayout();
  }

  @override
  void attach(PipelineOwner owner) {
    _progress.addListener(_handleProgress);
    super.attach(owner);
  }

  @override
  void detach() {
    _progress.removeListener(_handleProgress);
    super.detach();
  }

  @override
  void performLayout() {
    final child = this.child;
    if (child == null) {
      size = constraints.smallest;
      return;
    }
    child.layout(constraints, parentUsesSize: true);
    final factor = _progress.value.clamp(0.0, 1.0);
    final width = child.size.width;
    final fullHeight = child.size.height;
    if (fullHeight > 0 &&
        (_lastReportedFullHeight == null ||
            (fullHeight - _lastReportedFullHeight!).abs() > 0.5)) {
      _lastReportedFullHeight = fullHeight;
      _onFullHeightChanged?.call(fullHeight);
    }
    final height = fullHeight * factor;
    size = constraints.constrain(Size(width, height));
    // Align to the bottom of the clip (axisAlignment ≈ 1), matching SizeTransition.
    final childParentData = child.parentData! as BoxParentData;
    childParentData.offset = Offset(0, height - fullHeight);
  }

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) {
    final child = this.child;
    if (child == null) {
      return false;
    }
    final childParentData = child.parentData! as BoxParentData;
    return result.addWithPaintOffset(
      offset: childParentData.offset,
      position: position,
      hitTest: (BoxHitTestResult result, Offset transformed) {
        return child.hitTest(result, position: transformed);
      },
    );
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    final child = this.child;
    if (child == null || size.height <= 0) {
      return;
    }
    final childParentData = child.parentData! as BoxParentData;
    context.pushClipRect(
      needsCompositing,
      offset,
      Offset.zero & size,
      (PaintingContext context, Offset offset) {
        context.paintChild(child, offset + childParentData.offset);
      },
    );
  }

  @override
  double? computeDistanceToActualBaseline(TextBaseline baseline) {
    final child = this.child;
    if (child == null) {
      return super.computeDistanceToActualBaseline(baseline);
    }
    final childBaseline = child.getDistanceToActualBaseline(baseline);
    if (childBaseline == null) {
      return null;
    }
    final childParentData = child.parentData! as BoxParentData;
    return childBaseline + childParentData.offset.dy;
  }
}
