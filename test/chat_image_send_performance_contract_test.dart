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
    expect(
      source.contains('final maxWorkers = PlatformUtils().isIOS ? 1 : 2'),
      isTrue,
    );
    expect(
      source.contains('pending.length < maxWorkers'),
      isTrue,
    );
    expect(source.contains('final size = await originFile.length();'), isTrue);
    expect(source.contains('final size = originFile.lengthSync();'), isFalse);
  });

  test('media completion adopts one stable row without a second bottom pin', () {
    final panel = File(
      'third_party/tencent_cloud_chat_uikit/lib/ui/views/TIMUIKitChat/'
      'TIMUIKitTextField/tim_uikit_more_panel.dart',
    ).readAsStringSync();
    final model = File(
      'third_party/tencent_cloud_chat_uikit/lib/business_logic/'
      'separate_models/tui_chat_separate_view_model.dart',
    ).readAsStringSync();

    final sendStart = panel.indexOf(
      'Future<void> _sendPendingGalleryImagesConcurrently',
    );
    final sendEnd = panel.indexOf(
      'void _dispatchPreparedGalleryMedia',
      sendStart,
    );
    final sendBody = panel.substring(sendStart, sendEnd);
    expect(sendBody.contains('existingOptimisticId: item.optimisticId'), isTrue);
    expect(sendBody.contains('requestPinToBottom'), isFalse);

    final adoptStart = model.indexOf(
      'void _adoptOptimisticOutgoingImageMessage',
    );
    final adoptEnd = model.indexOf(
      'String _prependOptimisticVideoMessage',
      adoptStart,
    );
    final adoptBody = model.substring(adoptStart, adoptEnd);
    expect(adoptBody.contains('_swapOutgoingMessage'), isTrue);
    expect(adoptBody.contains('_prependOutgoingMessage'), isFalse);
    expect(adoptBody.contains('requestPinToBottom'), isFalse);
  });
}
