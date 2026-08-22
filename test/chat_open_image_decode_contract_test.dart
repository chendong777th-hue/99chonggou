import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('chat open image decode contracts (plan 017)', () {
    final imageElem = File(
      'third_party/tencent_cloud_chat_uikit/lib/ui/views/TIMUIKitChat/'
      'TIMUIKitMessageItem/tim_uikit_chat_image_elem.dart',
    ).readAsStringSync();
    final globalModel = File(
      'third_party/tencent_cloud_chat_uikit/lib/business_logic/'
      'view_models/tui_chat_global_model.dart',
    ).readAsStringSync();
    final historyList = File(
      'third_party/tencent_cloud_chat_uikit/lib/ui/views/TIMUIKitChat/'
      'TIMUIKItMessageList/tim_uikit_chat_history_message_list.dart',
    ).readAsStringSync();

    expect(imageElem.contains('ScreenshotHelper.getImageSize'), isFalse);
    expect(
      imageElem.contains('cacheWidth: decodeNativeThumb ? null'),
      isFalse,
    );
    expect(imageElem.contains('decodeNativeThumb'), isFalse);
    expect(imageElem.contains('readLocalImageSizeSync'), isTrue);
    expect(imageElem.contains('resolveChatBubbleImageDecodeTarget'), isTrue);

    expect(globalModel.contains('beginChatOpenImageDecodeDefer'), isTrue);
    expect(globalModel.contains('isChatOpenImageDecodeDeferActive'), isTrue);
    final skipIdx = globalModel.indexOf('shouldSkipHeavyChatListPresentation');
    expect(skipIdx, greaterThanOrEqualTo(0));
    final skipBody = globalModel.substring(skipIdx, skipIdx + 600);
    expect(skipBody.contains('isChatOpenImageDecodeDeferActive'), isTrue);

    expect(historyList.contains('beginChatOpenImageDecodeDefer'), isTrue);
  });
}
