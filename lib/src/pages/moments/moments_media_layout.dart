import 'package:flutter/material.dart';
import 'package:tencent_cloud_chat_demo/src/models/moments/moment_models.dart';

/// Shared sizing rules for a single Moments attachment.
///
/// Multiple attachments intentionally stay square so feed rows remain stable.
abstract final class MomentsMediaLayout {
  static const double fallbackImageAspectRatio = 1.08;
  static const double minPortraitAspectRatio = 3 / 4;
  static const double maxLandscapeAspectRatio = 16 / 9;

  static double singleAspectRatio(MomentAttachment item) {
    if (item.isVideo) return maxLandscapeAspectRatio;
    final width = item.width ?? 0;
    final height = item.height ?? 0;
    if (width <= 0 || height <= 0) return fallbackImageAspectRatio;
    return (width / height).clamp(
      minPortraitAspectRatio,
      maxLandscapeAspectRatio,
    );
  }

  static bool isLongImage(MomentAttachment item) {
    if (!item.isImage) return false;
    final width = item.width ?? 0;
    final height = item.height ?? 0;
    return width > 0 && height / width >= 2;
  }
}

/// Resolves missing legacy metadata from the image itself and keeps long
/// images at their real ratio instead of zooming them into a square crop.
class MomentsSingleMediaFrame extends StatefulWidget {
  const MomentsSingleMediaFrame({
    super.key,
    required this.item,
    required this.child,
    this.imageProvider,
    this.maxLongImageHeight = 420,
  });

  final MomentAttachment item;
  final Widget child;
  final ImageProvider? imageProvider;
  final double maxLongImageHeight;

  @override
  State<MomentsSingleMediaFrame> createState() =>
      _MomentsSingleMediaFrameState();
}

class _MomentsSingleMediaFrameState extends State<MomentsSingleMediaFrame> {
  double? _resolvedRatio;
  ImageStream? _stream;
  ImageStreamListener? _listener;

  double? get _metadataRatio {
    final width = widget.item.width ?? 0;
    final height = widget.item.height ?? 0;
    return width > 0 && height > 0 ? width / height : null;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _resolveRatio();
  }

  @override
  void didUpdateWidget(covariant MomentsSingleMediaFrame oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.imageProvider != widget.imageProvider ||
        oldWidget.item.width != widget.item.width ||
        oldWidget.item.height != widget.item.height) {
      _resolvedRatio = null;
      _resolveRatio();
    }
  }

  void _resolveRatio() {
    _removeListener();
    if (widget.item.isVideo || _metadataRatio != null) return;
    final provider = widget.imageProvider;
    if (provider == null) return;
    final stream = provider.resolve(createLocalImageConfiguration(context));
    final listener = ImageStreamListener((info, _) {
      final width = info.image.width;
      final height = info.image.height;
      if (!mounted || width <= 0 || height <= 0) return;
      final ratio = width / height;
      if (_resolvedRatio != ratio) setState(() => _resolvedRatio = ratio);
      _removeListener();
    });
    _stream = stream;
    _listener = listener;
    stream.addListener(listener);
  }

  void _removeListener() {
    final stream = _stream;
    final listener = _listener;
    if (stream != null && listener != null) stream.removeListener(listener);
    _stream = null;
    _listener = null;
  }

  @override
  void dispose() {
    _removeListener();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.item.isVideo) {
      return AspectRatio(
        aspectRatio: MomentsMediaLayout.maxLandscapeAspectRatio,
        child: widget.child,
      );
    }
    final rawRatio = _metadataRatio ?? _resolvedRatio;
    if (rawRatio == null || rawRatio <= 0) {
      return AspectRatio(
        aspectRatio: MomentsMediaLayout.fallbackImageAspectRatio,
        child: widget.child,
      );
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        final maxWidth = constraints.maxWidth;
        if (rawRatio < MomentsMediaLayout.minPortraitAspectRatio &&
            maxWidth.isFinite) {
          final height =
              (maxWidth / rawRatio).clamp(0.0, widget.maxLongImageHeight);
          return Align(
            alignment: Alignment.centerLeft,
            child: SizedBox(
              width: height * rawRatio,
              height: height,
              child: widget.child,
            ),
          );
        }
        return AspectRatio(
          aspectRatio: rawRatio.clamp(
            MomentsMediaLayout.minPortraitAspectRatio,
            MomentsMediaLayout.maxLandscapeAspectRatio,
          ),
          child: widget.child,
        );
      },
    );
  }
}
