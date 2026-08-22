import 'package:flutter/material.dart';

/// 左边缘右滑返回，不与纵向 slide 手势竞争。
class MediaPreviewEdgeBackLayer extends StatefulWidget {
  const MediaPreviewEdgeBackLayer({
    super.key,
    required this.onBack,
    this.edgeWidth = 56,
    this.triggerDx = 72,
    this.triggerVx = 520,
  });

  final VoidCallback onBack;
  final double edgeWidth;
  final double triggerDx;
  final double triggerVx;

  @override
  State<MediaPreviewEdgeBackLayer> createState() =>
      _MediaPreviewEdgeBackLayerState();
}

class _MediaPreviewEdgeBackLayerState extends State<MediaPreviewEdgeBackLayer> {
  double _edgeDx = 0;

  void _onHorizontalDragStart(DragStartDetails details) {
    _edgeDx = 0;
  }

  void _onHorizontalDragUpdate(DragUpdateDetails details) {
    _edgeDx += details.delta.dx;
  }

  void _onHorizontalDragEnd(DragEndDetails details) {
    final vx = details.velocity.pixelsPerSecond.dx;
    if (_edgeDx > widget.triggerDx || vx > widget.triggerVx) {
      widget.onBack();
    }
    _edgeDx = 0;
  }

  void _onHorizontalDragCancel() {
    _edgeDx = 0;
  }

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onHorizontalDragStart: _onHorizontalDragStart,
        onHorizontalDragUpdate: _onHorizontalDragUpdate,
        onHorizontalDragEnd: _onHorizontalDragEnd,
        onHorizontalDragCancel: _onHorizontalDragCancel,
        child: SizedBox(
          width: widget.edgeWidth,
          height: double.infinity,
        ),
      ),
    );
  }
}
