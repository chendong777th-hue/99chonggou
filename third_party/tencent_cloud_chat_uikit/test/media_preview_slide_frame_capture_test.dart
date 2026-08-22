import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tencent_cloud_chat_uikit/ui/utils/media_preview_slide_frame_capture.dart';

void main() {
  test('MediaPreviewSlideFrameRequest stores capture parameters', () {
    const request = MediaPreviewSlideFrameRequest(
      frameCaptureKey: GlobalObjectKey('capture'),
      localVideoPath: '/tmp/video.mp4',
      remoteVideoUrl: 'https://example.com/video.mp4',
      position: Duration(seconds: 3),
      targetSize: Size(320, 180),
      pixelRatio: 2.0,
    );

    expect(request.localVideoPath, '/tmp/video.mp4');
    expect(request.remoteVideoUrl, 'https://example.com/video.mp4');
    expect(request.position, const Duration(seconds: 3));
    expect(request.targetSize, const Size(320, 180));
    expect(request.pixelRatio, 2.0);
  });
}
