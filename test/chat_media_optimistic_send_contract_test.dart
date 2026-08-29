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

  test('media send commits are gated by conversation generation', () {
    final model = File(
      'third_party/tencent_cloud_chat_uikit/lib/business_logic/'
      'separate_models/tui_chat_separate_view_model.dart',
    ).readAsStringSync();
    expect(model.contains('MobileAsyncCommitGuard _mediaCommitGuard'), isTrue);
    expect(model.contains("'media-send'"), isTrue);
    expect(model.contains('_mediaCommitGuard.canCommit(mediaToken)'), isTrue);
    expect(model.contains('_mediaCommitGuard.advanceConversation()'), isTrue);
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
      '// 先按选择顺序一次性显示轻量占位',
    );
    final customPlaceholder = panel.indexOf(
      'model.beginOptimisticImagePlaceholders',
      customMarker,
    );
    final customResolve = panel.indexOf(
      'await _resolveGalleryImageAsset(',
      customMarker,
    );
    final customStage = panel.indexOf(
      'stageImageForChatSend(resolved.filePath)',
      customMarker,
    );
    expect(customMarker, greaterThanOrEqualTo(0));
    expect(customPlaceholder, inInclusiveRange(customMarker, customStage));
    expect(customResolve, greaterThan(customPlaceholder));
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
    expect(model.contains('hydrateOptimisticImagePlaceholder'), isTrue);
    expect(panel.contains('sourcePending: true'), isTrue);
    expect(panel.contains('requestInitialPin: false'), isTrue);
    expect(model.contains('if (requestInitialPin)'), isTrue);
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

  test('multi-select video inserts bubbles before file preparation', () {
    final panel = File(
      'third_party/tencent_cloud_chat_uikit/lib/ui/views/TIMUIKitChat/'
      'TIMUIKitTextField/tim_uikit_more_panel.dart',
    ).readAsStringSync();
    final customStart = panel.indexOf(
      'Future<void> _dispatchCustomPickedGalleryMedia({',
    );
    final customEnd = panel.indexOf(
      'Future<void> _dispatchSystemPickedMedia({',
      customStart,
    );
    final custom = panel.substring(customStart, customEnd);
    expect(custom.contains('beginOptimisticVideoPlaceholder'), isTrue);
    expect(custom.contains('existingOptimisticId: videoOptimisticIds'), isTrue);
    expect(
      custom.indexOf('beginOptimisticVideoPlaceholder'),
      lessThan(custom.indexOf('_prepareAndDispatchGalleryVideo')),
    );

    final systemStart = panel.indexOf(
      'Future<void> _dispatchSystemPickedMedia({',
    );
    final systemEnd = panel.indexOf(
      'Future<void> _prepareAndDispatchSystemGalleryVideo({',
      systemStart,
    );
    final system = panel.substring(systemStart, systemEnd);
    expect(system.contains('beginOptimisticVideoPlaceholder'), isTrue);
    expect(panel.contains('stageVideoForChatSend'), isTrue);
    expect(
      system.indexOf('beginOptimisticVideoPlaceholder'),
      lessThan(system.indexOf('_prepareAndDispatchSystemGalleryVideo')),
    );
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

    final soundSend = model.indexOf(
        'Future<V2TimValueCallback<V2TimMessage>?> sendSoundMessage({');
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

    final soundStart = model.indexOf(
      'Future<V2TimValueCallback<V2TimMessage>?> sendSoundMessage({',
    );
    final soundEnd = model.indexOf(
      'Future<V2TimValueCallback<V2TimMessage>?> sendReplyMessage({',
      soundStart,
    );
    final optimisticSoundBody = model.substring(soundStart, soundEnd);
    expect(
      optimisticSoundBody.indexOf('_prependOptimisticSoundMessage('),
      lessThan(
        optimisticSoundBody.indexOf(
          'await _messageService.createSoundMessage(',
        ),
      ),
    );
    expect(optimisticSoundBody.contains('_swapOutgoingMessage('), isTrue);
    expect(optimisticSoundBody.contains('_notifyCreateMessageFailed'), isTrue);
  });

  test('record start reuses the permission result and shows preparing feedback', () {
    final soundRecord = File(
      'third_party/tencent_cloud_chat_uikit/lib/ui/utils/sound_record.dart',
    ).readAsStringSync();
    final input = File(
      'third_party/tencent_cloud_chat_uikit/lib/ui/views/TIMUIKitChat/'
      'TIMUIKitTextField/tim_uikit_send_sound_message.dart',
    ).readAsStringSync();

    expect(soundRecord.contains('permissionAlreadyChecked'), isTrue);
    expect(
      input.contains('permissionAlreadyChecked: true'),
      isTrue,
    );
    expect(
      input.contains('unawaited(_beginRecording());\n    // Native start'),
      isTrue,
    );
    expect(input.contains('user should see an immediate preparing state'), isTrue);
  });

  test('reply send clears composer eagerly and creates one SDK message', () {
    final model = File(
      'third_party/tencent_cloud_chat_uikit/lib/business_logic/'
      'separate_models/tui_chat_separate_view_model.dart',
    ).readAsStringSync();

    final replyStart = model.indexOf(
      'Future<V2TimValueCallback<V2TimMessage>?> sendReplyMessage({',
    );
    expect(replyStart, greaterThanOrEqualTo(0));
    final replyEnd = model.indexOf(
      'void _notifyCreateMessageFailed(',
      replyStart,
    );
    expect(replyEnd, greaterThan(replyStart));
    final replyBody = model.substring(replyStart, replyEnd);

    final placeholder = replyBody.indexOf(
      'final optimisticId = _prependOptimisticTextPlaceholder(',
    );
    final clearComposer = replyBody.indexOf('repliedMessage = null;');
    final firstAwait = replyBody.indexOf('await _messageService.');
    expect(placeholder, greaterThanOrEqualTo(0));
    expect(clearComposer, greaterThan(placeholder));
    expect(firstAwait, greaterThan(clearComposer));

    expect(replyBody.contains('normalizedAtUserIDs.isEmpty'), isTrue);
    expect(
      RegExp(r'await _messageService\.createTextMessage')
          .allMatches(replyBody)
          .length,
      1,
    );
    expect(
      RegExp(r'await _messageService\.createTextAtMessage')
          .allMatches(replyBody)
          .length,
      1,
    );
    expect(
      replyBody.contains(
        'if (_composerUi.repliedMessage == null) {\n'
        '        repliedMessage = replyTarget;',
      ),
      isTrue,
    );
    expect(replyBody.contains('if (sendResult.code == 0)'), isFalse);
  });

  test('custom gallery has one optimistic production pipeline', () {
    final panel = File(
      'third_party/tencent_cloud_chat_uikit/lib/ui/views/TIMUIKitChat/'
      'TIMUIKitTextField/tim_uikit_more_panel.dart',
    ).readAsStringSync();
    final model = File(
      'third_party/tencent_cloud_chat_uikit/lib/business_logic/'
      'separate_models/tui_chat_separate_view_model.dart',
    ).readAsStringSync();

    final entryStart = panel.indexOf(
      'Future<void> _dispatchCustomPickedGalleryMedia({',
    );
    final entryEnd = panel.indexOf(
      'Future<void> _dispatchSystemPickedMedia({',
      entryStart,
    );
    expect(entryStart, greaterThanOrEqualTo(0));
    expect(entryEnd, greaterThan(entryStart));
    final entry = panel.substring(entryStart, entryEnd);

    expect(panel.contains('_dispatchCustomGalleryTasks'), isFalse);
    expect(panel.contains('_GalleryMediaSendTask'), isFalse);
    expect(model.contains('sendGalleryImageTask'), isFalse);
    expect(
      'beginOptimisticImagePlaceholders'.allMatches(entry).length,
      1,
    );
    expect('sendImageMessage('.allMatches(entry).length, 0);
    expect(entry.contains('_sendPendingGalleryImagesConcurrently'), isTrue);
    expect(entry.contains('sourcePending: true'), isTrue);
    expect(entry.contains('hydrateOptimisticImagePlaceholder'), isTrue);
    expect(entry.contains('cancelOptimisticMediaPlaceholder'), isTrue);
    expect(entry.contains('_prepareAndDispatchGalleryVideo'), isTrue);

    // The same bounded worker handles 1/4/9-image selections. iOS remains
    // serial and selection order is fixed by the pre-inserted stable IDs.
    expect(panel.contains('PlatformUtils().isIOS ? 1 : 2'), isTrue);
    expect(panel.contains('final index = nextIndex++;'), isTrue);
    expect(panel.contains('existingOptimisticId: item.optimisticId'), isTrue);
    expect(model.contains('...optimisticMessages.reversed'), isTrue);
  });

  test('gallery resolve keeps HEIC iCloud retry and terminal cleanup', () {
    final picker = File(
      'third_party/tencent_cloud_chat_uikit/lib/ui/utils/image_edit/'
      'editable_asset_picker.dart',
    ).readAsStringSync();
    final panel = File(
      'third_party/tencent_cloud_chat_uikit/lib/ui/views/TIMUIKitChat/'
      'TIMUIKitTextField/tim_uikit_more_panel.dart',
    ).readAsStringSync();

    expect(picker.contains('asset.file'), isTrue);
    expect(picker.contains('asset.originFile'), isTrue);
    expect(picker.contains('cloudTimeout'), isTrue);
    expect(picker.contains('retries = 2'), isTrue);
    expect(panel.contains('resolve_categorized_failure'), isTrue);
    expect(panel.contains('stage_failed'), isTrue);
    expect(panel.contains('resolve_cancelled_conversation_changed'), isTrue);
  });
}
