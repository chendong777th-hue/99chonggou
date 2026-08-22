import 'package:flutter_test/flutter_test.dart';
import 'package:tencent_cloud_chat_demo/utils/chat_image_message_prefetch.dart';
import 'package:tencent_cloud_chat_uikit/ui/utils/chat_media_gallery_utils.dart';

void main() {
  test('bubble prefetch uses the same cache key as chat image bubbles', () {
    const msgID = 'msg-1';
    const url = 'https://example.com/thumb.jpg';

    expect(
      chatBubbleImageCacheKey(msgID, url: url),
      chatMediaBubbleImageCacheKey(msgID, urlFallback: url),
    );
  });
}
