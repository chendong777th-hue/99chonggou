import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('video tap refuses fullscreen while context menu is open', () {
    final video = File(
      'third_party/tencent_cloud_chat_uikit/lib/ui/views/TIMUIKitChat/'
      'TIMUIKitMessageItem/tim_uikit_chat_video_elem.dart',
    ).readAsStringSync();
    final image = File(
      'third_party/tencent_cloud_chat_uikit/lib/ui/views/TIMUIKitChat/'
      'TIMUIKitMessageItem/tim_uikit_chat_image_elem.dart',
    ).readAsStringSync();

    expect(image.contains('isMessageContextMenuOverlayOpen'), isTrue);
    expect(video.contains('isMessageContextMenuOverlayOpen'), isTrue);

    final guardIdx = video.indexOf('isMessageContextMenuOverlayOpen');
    final openIdx = video.indexOf('_openMobileMediaPreview(heroTag)');
    expect(guardIdx, greaterThanOrEqualTo(0));
    expect(openIdx, greaterThan(guardIdx));
    expect(
      video.contains('菜单打开期间禁止进全屏'),
      isTrue,
    );
  });
}
