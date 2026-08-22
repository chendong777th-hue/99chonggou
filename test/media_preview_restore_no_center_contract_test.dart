import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('media preview restore does not scrollToIndex middle', () {
    final list = File(
      'third_party/tencent_cloud_chat_uikit/lib/ui/views/TIMUIKitChat/'
      'TIMUIKItMessageList/tim_uikit_chat_history_message_list.dart',
    ).readAsStringSync();
    final global = File(
      'third_party/tencent_cloud_chat_uikit/lib/business_logic/view_models/'
      'tui_chat_global_model.dart',
    ).readAsStringSync();

    final restoreAt = list.indexOf('Future<void> _restoreRouteScroll(');
    expect(restoreAt, greaterThanOrEqualTo(0));
    final restoreBody = list.substring(restoreAt, restoreAt + 2200);

    // Offset jump remains the only active restore.
    expect(
      restoreBody.contains('jump__scheduleRouteScrollRestore'),
      isTrue,
    );
    // Former bug: anchor fallback centered the opening image bubble.
    expect(restoreBody.contains('AutoScrollPosition.middle'), isFalse);
    expect(restoreBody.contains('scroll_to_index_middle'), isFalse);
    expect(
      restoreBody.contains('getScrollRestoreAnchorMsgID'),
      isFalse,
    );

    final needsAt =
        global.indexOf('bool _needsActiveScrollRestoreAfterPreview');
    expect(needsAt, greaterThanOrEqualTo(0));
    final needsBody = global.substring(needsAt, needsAt + 900);
    // Anchor-alone must not force restore (that path used middle).
    expect(needsBody.contains('_mediaPreviewAnchorMsgIDMap'), isFalse);
    expect(needsBody.contains('_mediaPreviewScrollOffsetMap'), isTrue);
  });
}
