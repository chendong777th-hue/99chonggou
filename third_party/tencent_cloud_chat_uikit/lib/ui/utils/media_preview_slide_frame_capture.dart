import 'dart:async';
import 'dart:ui' as ui;

import 'package:fc_native_video_thumbnail/fc_native_video_thumbnail.dart';
import 'package:fc_native_video_thumbnail/fc_native_video_thumbnail_platform_interface.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:video_player/video_player.dart';

class MediaPreviewSlideFrameRequest {
  const MediaPreviewSlideFrameRequest({
    required this.frameCaptureKey,
    this.controller,
    this.localVideoPath,
    this.remoteVideoUrl,
    this.position = Duration.zero,
    this.targetSize,
    required this.pixelRatio,
  });

  final GlobalKey frameCaptureKey;
  final VideoPlayerController? controller;
  final String? localVideoPath;
  final String? remoteVideoUrl;
  final Duration position;
  final Size? targetSize;
  final double pixelRatio;
}

class MediaPreviewSlideFrameCapture {
  MediaPreviewSlideFrameCapture._();

  static final FcNativeVideoThumbnail _thumbnailPlugin = FcNativeVideoThumbnail();

  static Future<ui.Image?> capture(MediaPreviewSlideFrameRequest request) async {
    final fromRepaint = await _captureFromRepaintBoundary(
      request.frameCaptureKey,
      request.pixelRatio,
    );
    if (fromRepaint != null) {
      return fromRepaint;
    }
    return _captureFromNativeThumbnail(request);
  }

  static Future<ui.Image?> _captureFromRepaintBoundary(
    GlobalKey key,
    double pixelRatio,
  ) async {
    final boundary = key.currentContext?.findRenderObject();
    if (boundary is! RenderRepaintBoundary) {
      return null;
    }
    try {
      if (boundary.debugNeedsPaint) {
        await WidgetsBinding.instance.endOfFrame;
      }
    } catch (_) {
      await WidgetsBinding.instance.endOfFrame;
    }
    try {
      return boundary.toImage(pixelRatio: pixelRatio);
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Slide frame RepaintBoundary capture failed: $e');
      }
      return null;
    }
  }

  static Future<ui.Image?> _captureFromNativeThumbnail(
    MediaPreviewSlideFrameRequest request,
  ) async {
    final localPath = request.localVideoPath?.trim();
    final remoteUrl = request.remoteVideoUrl?.trim();

    final String? srcFile;
    final bool srcFileUri;
    if (localPath != null && localPath.isNotEmpty) {
      srcFile = localPath;
      srcFileUri = false;
    } else if (remoteUrl != null && remoteUrl.isNotEmpty) {
      srcFile = remoteUrl;
      srcFileUri = true;
    } else {
      return null;
    }

    final size = request.targetSize;
    final dpr = request.pixelRatio;
    var width = 720;
    var height = 1280;
    if (size != null && size.width > 0 && size.height > 0) {
      width = (size.width * dpr).round().clamp(1, 4096);
      height = (size.height * dpr).round().clamp(1, 4096);
    }

    try {
      final position = request.position;
      final FcVideoThumbnailTime? at = position > Duration.zero
          ? FcVideoThumbnailTime(
              position.inMicroseconds,
              FcVideoThumbnailTimeUnit.microseconds,
            )
          : null;

      final bytes = await _thumbnailPlugin.saveThumbnailToBytes(
        srcFile: srcFile,
        srcFileUri: srcFileUri,
        width: width,
        height: height,
        quality: 90,
        at: at,
      );
      if (bytes == null || bytes.isEmpty) {
        return null;
      }
      return _decodeImage(bytes);
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Native slide frame capture failed: $e');
      }
      return null;
    }
  }

  static Future<ui.Image?> _decodeImage(Uint8List bytes) {
    final completer = Completer<ui.Image?>();
    ui.decodeImageFromList(bytes, (image) {
      if (!completer.isCompleted) {
        completer.complete(image);
      }
    });
    return completer.future;
  }
}
