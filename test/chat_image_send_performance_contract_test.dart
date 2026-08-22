import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('chat image compression uses balanced mobile send settings', () {
    final source = File(
      'third_party/tencent_cloud_chat_uikit/lib/ui/utils/'
      'chat_media_send_utils.dart',
    ).readAsStringSync();

    expect(source.contains('kChatImageMaxLongEdge = 3072'), isTrue);
    expect(source.contains('kChatImageJpegQuality = 94'), isTrue);
    expect(
      source.contains('kChatImageSkipCompressBelowBytes = 1200 * 1024'),
      isTrue,
    );
    expect(source.contains('resolveChatImageSendTargetSize'), isTrue);
    expect(source.contains('minWidth: targetWidth'), isTrue);
    expect(source.contains('minHeight: targetHeight'), isTrue);
  });

  test('gallery image sends use bounded concurrency and async file length', () {
    final source = File(
      'third_party/tencent_cloud_chat_uikit/lib/ui/views/TIMUIKitChat/'
      'TIMUIKitTextField/tim_uikit_more_panel.dart',
    ).readAsStringSync();

    expect(
      source.contains('_sendPendingGalleryImagesConcurrently'),
      isTrue,
    );
    expect(source.contains('final workerCount = pending.length < 2'), isTrue);
    expect(source.contains('final size = await originFile.length();'), isTrue);
    expect(source.contains('final size = originFile.lengthSync();'), isFalse);
  });
}
