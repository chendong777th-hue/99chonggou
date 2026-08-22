import 'dart:ui' as ui;

import 'package:flutter/material.dart';

class MediaPreviewVideoSlideLayer extends StatelessWidget {
  const MediaPreviewVideoSlideLayer({
    super.key,
    required this.player,
    required this.slideDragActive,
    required this.hidePlayerForSlide,
    this.slideDragFrame,
    this.displayedVideoSize,
    this.slideFallbackVisual,
    this.heroOverlay,
  });

  final Widget player;
  final bool slideDragActive;
  final bool hidePlayerForSlide;
  final ui.Image? slideDragFrame;
  final Size? displayedVideoSize;
  final Widget? slideFallbackVisual;
  final Widget? heroOverlay;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      alignment: Alignment.center,
      children: [
        const ColoredBox(color: Colors.black),
        Offstage(
          offstage: hidePlayerForSlide,
          child: Stack(
            fit: StackFit.expand,
            alignment: Alignment.center,
            children: [
              Positioned.fill(child: player),
              if (heroOverlay != null) IgnorePointer(child: heroOverlay!),
            ],
          ),
        ),
        if (slideDragActive) IgnorePointer(child: _buildDragFrameVisual()),
      ],
    );
  }

  Widget _buildDragFrameVisual() {
    final frame = slideDragFrame;
    if (frame != null) {
      final image = RawImage(
        image: frame,
        fit: BoxFit.contain,
        filterQuality: FilterQuality.low,
      );
      final size = displayedVideoSize;
      if (size == null) {
        return Center(child: image);
      }
      return Center(
        child: SizedBox(
          width: size.width,
          height: size.height,
          child: image,
        ),
      );
    }
    final fallback = slideFallbackVisual;
    if (fallback != null) {
      return Center(child: fallback);
    }
    return const SizedBox.shrink();
  }
}
