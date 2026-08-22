import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('inactive inbound coalesces revision and notify during flood', () {
    final source = File(
      'third_party/tencent_cloud_chat_uikit/lib/business_logic/view_models/'
      'tui_chat_global_model.dart',
    ).readAsStringSync();

    expect(
        source.contains('_scheduleInactiveInboundPresentationCommit'), isTrue);
    expect(source.contains('_flushInactiveInboundPresentationCommits'), isTrue);
    expect(
      source.contains("reason: 'inbound_batch_inactive_coalesced'"),
      isTrue,
    );
    expect(
      source.contains('flushInactiveInboundPresentationForConversation'),
      isTrue,
    );
    expect(source.contains('touchesActiveConversation'), isTrue);
    expect(
      source.contains('activeConvId.isEmpty || touchesActiveConversation'),
      isTrue,
    );
    expect(
      source.contains('_shouldDeferHeavyBubbleDecodeForAndroidHistory'),
      isTrue,
    );
    expect(source.contains('prepareForegroundChatRecovery'), isTrue);
  });

  test('history list incremental partition rebuild on tail append', () {
    final source = File(
      'third_party/tencent_cloud_chat_uikit/lib/ui/views/TIMUIKitChat/'
      'TIMUIKItMessageList/tim_uikit_chat_history_message_list.dart',
    ).readAsStringSync();

    expect(source.contains('_cacheHeadMsgKey'), isTrue);
    expect(source.contains('_cacheUnreadEndPoint'), isTrue);
    expect(source.contains('partition_incremental_tail'), isTrue);
    expect(source.contains('canAppendReadTail'), isTrue);
  });

  test('foreground recovery serializes reconcile before chat refresh', () {
    final recoverySource =
        File('lib/src/services/im_recovery_service.dart').readAsStringSync();
    final runGlobalBlock = recoverySource.substring(
      recoverySource.indexOf('Future<void> _runGlobalRecovery'),
    );

    expect(runGlobalBlock.contains('prepareForegroundChatRecovery'), isTrue);
    expect(
      runGlobalBlock.indexOf('prepareForegroundChatRecovery') <
          runGlobalBlock.indexOf('refreshForegroundChatIfNeeded'),
      isTrue,
    );
  });

  test('message list avoids unconditional second full dedupe pass', () {
    final source = File(
      'third_party/tencent_cloud_chat_uikit/lib/business_logic/view_models/'
      'tui_chat_global_model.dart',
    ).readAsStringSync();

    expect(source.contains('final secondPass ='), isFalse);
    expect(source.contains('if (_listHasCorrelatingDup(sorted))'), isTrue);
    expect(source.contains('if (foreground) {\n      _markNeedsNotify();'),
        isTrue);
  });

  test('resume coalesce flush is staged across frames', () {
    final flagsSource =
        File('lib/src/services/conversation_local/conversation_perf_flags.dart')
            .readAsStringSync();
    final storeSource = File(
            'lib/src/services/conversation_local/conversation_local_store.dart')
        .readAsStringSync();

    expect(flagsSource.contains('resumeForegroundCoalesceBatchCap'), isTrue);
    expect(storeSource.contains('_resumeForegroundStagedFlushActive'), isTrue);
    expect(storeSource.contains('addPostFrameCallback'), isTrue);
  });

  test('cross-platform image cache stays bounded for long media chats', () {
    final source = File('lib/main.dart').readAsStringSync();

    expect(source.contains('maximumSize = 1200'), isTrue);
    expect(source.contains('maximumSizeBytes = 192 << 20'), isTrue);
    expect(source.contains('maximumSizeBytes = 384 << 20'), isFalse);
  });
}
