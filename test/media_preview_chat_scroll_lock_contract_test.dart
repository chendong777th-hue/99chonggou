import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('media preview scrim absorbs hits instead of ignoring them', () {
    final shell = File(
      'third_party/tencent_cloud_chat_uikit/lib/ui/widgets/'
      'media_preview_slide_shell.dart',
    ).readAsStringSync();

    final scrim = shell.indexOf('Widget _buildScrimBackdrop');
    expect(scrim, greaterThanOrEqualTo(0));
    final scrimBody = shell.substring(scrim);
    expect(scrimBody.contains('return IgnorePointer'), isFalse);
    expect(scrimBody.contains('return ColoredBox('), isTrue);
  });

  test('chat history locks scroll while media preview overlay is open', () {
    final list = File(
      'third_party/tencent_cloud_chat_uikit/lib/ui/views/TIMUIKitChat/'
      'TIMUIKItMessageList/tim_uikit_chat_history_message_list.dart',
    ).readAsStringSync();
    final global = File(
      'third_party/tencent_cloud_chat_uikit/lib/business_logic/view_models/'
      'tui_chat_global_model.dart',
    ).readAsStringSync();

    expect(global.contains('shouldLockChatScrollForMediaPreview'), isTrue);
    expect(
      list.contains('globalModel.shouldLockChatScrollForMediaPreview'),
      isTrue,
    );
    expect(
      list.contains('scrollLockedForOverlay'),
      isTrue,
    );
    expect(
      global.contains(
        'Keep overlay lock until [finishScrollAfterMediaPreview]',
      ),
      isTrue,
    );
  });

  test('pushMediaPreview restores chat scroll without bubble mounted gate', () {
    final presenter = File(
      'third_party/tencent_cloud_chat_uikit/lib/ui/utils/'
      'media_preview_presenter.dart',
    ).readAsStringSync();
    final imageElem = File(
      'third_party/tencent_cloud_chat_uikit/lib/ui/views/TIMUIKitChat/'
      'TIMUIKitMessageItem/tim_uikit_chat_image_elem.dart',
    ).readAsStringSync();
    final videoElem = File(
      'third_party/tencent_cloud_chat_uikit/lib/ui/views/TIMUIKitChat/'
      'TIMUIKitMessageItem/tim_uikit_chat_video_elem.dart',
    ).readAsStringSync();
    final global = File(
      'third_party/tencent_cloud_chat_uikit/lib/business_logic/view_models/'
      'tui_chat_global_model.dart',
    ).readAsStringSync();

    expect(presenter.contains('restoreChatScrollConversationID'), isTrue);
    expect(
      presenter.contains('restoreScrollAfterMediaPreview(restoreConvId)'),
      isTrue,
    );

    final imageRestoreFn = imageElem.indexOf('void restoreAfterPreview()');
    expect(imageRestoreFn, greaterThanOrEqualTo(0));
    final imageRestoreBody = imageElem.substring(
      imageRestoreFn,
      imageRestoreFn + 350,
    );
    expect(imageRestoreBody.contains('if (!mounted)'), isFalse);
    expect(
      imageElem.contains('restoreChatScrollConversationID: convId'),
      isTrue,
    );

    expect(
      videoElem.contains('restoreChatScrollConversationID: convId'),
      isTrue,
    );
    expect(videoElem.contains('if (!didPushPreview)'), isTrue);
    expect(global.contains('超时强制解锁'), isTrue);
  });
}
