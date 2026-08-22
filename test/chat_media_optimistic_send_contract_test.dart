import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('video supports optimistic placeholder before SDK message creation', () {
    final model = File(
      'third_party/tencent_cloud_chat_uikit/lib/business_logic/'
      'separate_models/tui_chat_separate_view_model.dart',
    ).readAsStringSync();
    final panel = File(
      'third_party/tencent_cloud_chat_uikit/lib/ui/views/TIMUIKitChat/'
      'TIMUIKitTextField/tim_uikit_more_panel.dart',
    ).readAsStringSync();

    expect(model.contains('beginOptimisticVideoPlaceholder'), isTrue);
    expect(model.contains('String? existingOptimisticId'), isTrue);
    expect(panel.contains('model.beginOptimisticVideoPlaceholder'), isTrue);
    expect(
        panel.contains('final metadata = await Future.wait<Object?>'), isTrue);
    expect(panel.contains('cancelOptimisticMediaPlaceholder'), isTrue);
    expect(panel.contains('_hasUsableConversation([String? convID]) => true'),
        isTrue);
    expect(panel.contains('}) =>\n      true;'), isTrue);
    expect(panel.contains('ActiveChatRegistry.instance.activeConversationId'),
        isFalse);
    expect(panel.contains('会话已切换，请重新选择后发送'), isFalse);
    expect(panel.contains('当前会话不可用，请返回后重试'), isFalse);
  });

  test('gallery image placeholder is inserted before staging copy', () {
    final panel = File(
      'third_party/tencent_cloud_chat_uikit/lib/ui/views/TIMUIKitChat/'
      'TIMUIKitTextField/tim_uikit_more_panel.dart',
    ).readAsStringSync();
    final model = File(
      'third_party/tencent_cloud_chat_uikit/lib/business_logic/'
      'separate_models/tui_chat_separate_view_model.dart',
    ).readAsStringSync();

    final customMarker = panel.indexOf(
      '// 所有占位一次性并入消息列表',
    );
    final customPlaceholder = panel.indexOf(
      'model.beginOptimisticImagePlaceholders',
      customMarker,
    );
    final customStage = panel.indexOf(
      'stageImageForChatSend(resolved.filePath)',
      customMarker,
    );
    expect(customMarker, greaterThanOrEqualTo(0));
    expect(customPlaceholder, inInclusiveRange(customMarker, customStage));
    expect(customStage, greaterThan(customPlaceholder));
    expect(panel.contains('waitForPickerDismissSettle'), isTrue);
    final customSettle = panel.indexOf(
      'ChatGalleryPickUtils.waitForPickerDismissSettle',
    );
    final customEndOverlay = panel.indexOf(
      'endMediaPickerOverlay',
      customSettle,
    );
    expect(customSettle, greaterThanOrEqualTo(0));
    expect(customEndOverlay, greaterThan(customSettle));
    expect(
      panel.contains('.map(_resolveGalleryImageAsset)'),
      isFalse,
    );
    expect(model.contains('bool probeSizeSynchronously = true'), isTrue);
    expect(model.contains('List<String> beginOptimisticImagePlaceholders'),
        isTrue);
    expect(model.contains('...optimisticMessages.reversed'), isTrue);
    expect(panel.contains('probeSizeSynchronously: false'), isTrue);
    expect(panel.contains('PlatformUtils().isIOS ? 1 : 2'), isTrue);
    final trace = File(
      'third_party/tencent_cloud_chat_uikit/lib/ui/utils/gallery_send_perf_trace.dart',
    ).readAsStringSync();
    expect(panel.contains('[gallery_send_perf]'), isFalse);
    expect(panel.contains('GallerySendPerfTrace'), isTrue);
    expect(panel.contains("'custom_picker_returned'"), isTrue);
    expect(panel.contains("'placeholder_batch_end'"), isTrue);
    expect(
      panel.contains("'placeholder_post_layout_pin_requested'"),
      isTrue,
    );
    expect(
      panel.contains(
        'requestPinToBottom(\n      convID,\n      force: true,',
      ),
      isTrue,
    );
    expect(panel.contains("'all_image_sends_complete'"), isTrue);
    expect(trace.contains("'slow_frame'"), isTrue);
    expect(trace.contains('buildMs='), isTrue);
    expect(trace.contains('rasterMs='), isTrue);
  });

  test('closing media picker clears interrupted chat scroll state', () {
    final globalModel = File(
      'third_party/tencent_cloud_chat_uikit/lib/business_logic/view_models/'
      'tui_chat_global_model.dart',
    ).readAsStringSync();

    final overlayEnd = globalModel.indexOf('void endMediaPickerOverlay()');
    final nextMethod = globalModel.indexOf(
        'void beginMessageContextMenuOverlay()', overlayEnd);
    final methodSource = globalModel.substring(overlayEnd, nextMethod);
    expect(methodSource.contains('setChatListUserScrolling(false)'), isTrue);
    expect(
      globalModel.contains(
        'if (isMediaPickerOverlayOpen) {\n        return;\n      }',
      ),
      isTrue,
    );
  });

  test('force pin retry outlives outgoing media settle window', () {
    final historyList = File(
      'third_party/tencent_cloud_chat_uikit/lib/ui/views/TIMUIKitChat/'
      'TIMUIKItMessageList/tim_uikit_chat_history_message_list.dart',
    ).readAsStringSync();

    expect(historyList.contains('holdMs: 1200'), isTrue);
    expect(historyList.contains('const maxAttempts = 24;'), isTrue);
    expect(
      historyList.contains('Duration(milliseconds: 64)'),
      isTrue,
    );
  });

  test('media progress animates locally without global model notification', () {
    final overlay = File(
      'third_party/tencent_cloud_chat_uikit/lib/ui/views/TIMUIKitChat/'
      'TIMUIKitMessageItem/tim_uikit_media_upload_overlay.dart',
    ).readAsStringSync();
    final video = File(
      'third_party/tencent_cloud_chat_uikit/lib/ui/views/TIMUIKitChat/'
      'TIMUIKitMessageItem/tim_uikit_chat_video_elem.dart',
    ).readAsStringSync();
    final globalModel = File(
      'third_party/tencent_cloud_chat_uikit/lib/business_logic/view_models/'
      'tui_chat_global_model.dart',
    ).readAsStringSync();

    expect(overlay.contains('TweenAnimationBuilder<double>'), isTrue);
    expect(video.contains('TimUIKitMessageUploadOverlayLayer('), isTrue);
    expect(globalModel.contains('_setUploadProgressSilently'), isTrue);
  });

  test('prepared gallery video reuses its optimistic placeholder', () {
    final panel = File(
      'third_party/tencent_cloud_chat_uikit/lib/ui/views/TIMUIKitChat/'
      'TIMUIKitTextField/tim_uikit_more_panel.dart',
    ).readAsStringSync();

    expect(
        panel.contains('existingOptimisticId: prepared.optimisticId'), isTrue);
  });

  test('outgoing updates read the canonical conversation alias', () {
    final model = File(
      'third_party/tencent_cloud_chat_uikit/lib/business_logic/'
      'separate_models/tui_chat_separate_view_model.dart',
    ).readAsStringSync();
    final globalModel = File(
      'third_party/tencent_cloud_chat_uikit/lib/business_logic/view_models/'
      'tui_chat_global_model.dart',
    ).readAsStringSync();

    expect(model.contains('globalModel.rawMessageList(targetConvID)'), isTrue);
    expect(model.contains('globalModel.rawMessageList(convID)'), isTrue);
    expect(
      globalModel.contains(
        'final storageConvID = _resolveMessageListStorageKey(convID);',
      ),
      isTrue,
    );
  });

  test('sound send keeps stable id and resolves progress conv key', () {
    final model = File(
      'third_party/tencent_cloud_chat_uikit/lib/business_logic/'
      'separate_models/tui_chat_separate_view_model.dart',
    ).readAsStringSync();
    final globalModel = File(
      'third_party/tencent_cloud_chat_uikit/lib/business_logic/view_models/'
      'tui_chat_global_model.dart',
    ).readAsStringSync();

    final soundSend = model.indexOf('Future<V2TimValueCallback<V2TimMessage>?> sendSoundMessage({');
    expect(soundSend, greaterThanOrEqualTo(0));
    final soundSendEnd = model.indexOf(
      'Future<V2TimValueCallback<V2TimMessage>?> sendReplyMessage({',
      soundSend,
    );
    final soundBody = model.substring(soundSend, soundSendEnd);
    expect(soundBody.contains('applyOutgoingStableIdToMessage'), isTrue);

    expect(
      globalModel.contains(
        'final convID = _resolveMessageListStorageKey(rawConvID);',
      ),
      isTrue,
    );
    expect(
      globalModel.contains(
        '_collectAuthoritativeMessages(storageKey)',
      ),
      isTrue,
    );
    expect(
      globalModel.contains('kChatOutgoingStableIdKey'),
      isTrue,
    );
    // Progress must not write bare userID/groupID buckets anymore.
    expect(
      globalModel.contains(
        "final convID = TencentUtils.checkString(message.userID) ?? message.groupID;",
      ),
      isFalse,
    );
  });
}
