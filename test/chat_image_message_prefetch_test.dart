import 'package:flutter_test/flutter_test.dart';
import 'package:tencent_cloud_chat_demo/utils/chat_image_message_prefetch.dart';
import 'package:tencent_cloud_chat_uikit/data_services/message/message_service_implement.dart';
import 'package:tencent_cloud_chat_uikit/ui/utils/chat_media_gallery_utils.dart';

void main() {
  test('thumbnail persistence work stays within thermal limits', () {
    expect(ChatImageMessagePrefetch.debugMaxThumbnailDownloadConcurrent, 2);
    expect(ChatImageMessagePrefetch.debugMaxThumbnailDownloadQueue, 24);
    expect(ChatImageMessagePrefetch.debugMaxThumbnailDownloadsPerMinute, 12);
    expect(MessageServiceImpl.thumbnailDownloadMaxConcurrent, 2);
    expect(MessageServiceImpl.thumbnailDownloadMaxQueue, 24);
    expect(MessageServiceImpl.thumbnailDownloadMaxStartsPerMinute, 12);
  });

  test('bubble prefetch uses the same cache key as chat image bubbles', () {
    const msgID = 'msg-1';
    const url = 'https://example.com/thumb.jpg';

    expect(
      chatBubbleImageCacheKey(msgID, url: url),
      chatMediaBubbleImageCacheKey(msgID, urlFallback: url),
    );
  });

  test('warm decode hint can be read and forgotten without native media state',
      () {
    const key = 'msg-1:bubble:https://example.com/thumb.jpg';
    forgetChatBubbleImageWarmDecodeHint(key);

    registerChatBubbleImageWarmDecodeHint(
      key,
      decodeByWidth: false,
      targetPx: 720,
    );
    final hint = chatBubbleImageWarmDecodeHint(key);
    expect(hint, isNotNull);
    expect(hint!.decodeByWidth, isFalse);
    expect(hint.targetPx, 720);

    forgetChatBubbleImageWarmDecodeHint(key);
    expect(chatBubbleImageWarmDecodeHint(key), isNull);
  });
}
