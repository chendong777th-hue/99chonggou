import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final globalModel = File(
    'third_party/tencent_cloud_chat_uikit/lib/business_logic/view_models/'
    'tui_chat_global_model.dart',
  ).readAsStringSync();
  final historyLoader = File(
    'third_party/tencent_cloud_chat_uikit/lib/business_logic/separate_models/'
    'tui_chat_history_pagination_load.dart',
  ).readAsStringSync();

  test('production model owns one history and realtime reconciliation writer',
      () {
    expect(globalModel, contains('MessageReconciliationWriter<V2TimMessage>'));
    expect(globalModel, contains('beginHistoryReconciliation('));
    expect(globalModel, contains('completeHistoryReconciliation('));
    expect(globalModel, contains('failHistoryReconciliation('));
    expect(
      globalModel,
      contains('_messageReconciliationWriter.hasActiveRequest(convID)'),
    );
    expect(globalModel, contains('enqueueRealtime('));
  });

  test('history loader commits or releases every reconciliation generation',
      () {
    expect(historyLoader, contains('beginHistoryReconciliation('));
    expect(historyLoader, contains('completeHistoryReconciliation('));
    expect(historyLoader, contains('reconciliationCommitted = true;'));
    expect(historyLoader, contains('if (pendingReconciliation != null &&'));
    expect(historyLoader, contains('failHistoryReconciliation('));
  });

  test('reconnect and seq-gap catch-up use bounded writer transaction', () {
    final controller = File(
      'third_party/tencent_cloud_chat_uikit/lib/business_logic/view_models/'
      'message_cloud_catch_up.dart',
    ).readAsStringSync();
    expect(globalModel, contains('BoundedMessageCloudCatchUp'));
    expect(globalModel, contains('beginCloudCatchUp('));
    expect(globalModel, contains('completeHistoryReconciliation('));
    expect(globalModel, contains('messageSeqList:'));
    expect(globalModel, contains('lastMsg: isGroup ? null : newestAnchor'));
    expect(controller, contains('this.maxAttempts = 3'));
    expect(
        controller, contains('this.maxDuration = const Duration(seconds: 10)'));
    expect(controller, contains('attempt.invalidate();'));
    expect(controller, contains('MessageCloudCatchUpDisposition.continuation'));
    expect(controller, contains('MessageCloudCatchUpDisposition.settled'));
    expect(globalModel, contains('MessageCloudCatchUpDisposition.settled'));
    expect(globalModel, contains('cloudHasMoreNewer:'));
    expect(globalModel, contains("reason: 'cloud_continuation'"));
    expect(globalModel, contains('_cloudCatchUpStalledAnchorByConv'));
    expect(globalModel, contains('_shouldHoldStalledCloudContinuation'));
    expect(globalModel, contains('_markCloudCatchUpUnblocked'));
    expect(globalModel, contains('cloudContinuationStalled'));
    expect(globalModel, contains("reason: 'cloud_catch_up_no_progress'"));
    expect(globalModel, contains('trackSeqGaps: isGroup'));
    expect(globalModel, contains('_isGroupConversation('));
    expect(
      globalModel,
      isNot(contains("storageKey.toUpperCase().contains('GROUP')")),
    );
    expect(globalModel, isNot(contains('Future<void> _fillGap(')));
    expect(globalModel, isNot(contains('GapDetector.createGapMarker')));
  });

  test('authoritative replacement cancels pending inbound presentation first',
      () {
    final reveal = File(
      'third_party/tencent_cloud_chat_uikit/lib/ui/utils/'
      'message_inbound_chunk_reveal.dart',
    ).readAsStringSync();
    final setListStart =
        globalModel.indexOf('MessageCommitResult setMessageList(');
    final equivalentFastPath = globalModel.indexOf(
      'if (skipEquivalentHistoryWindow &&',
      setListStart,
    );
    final cancel = globalModel.indexOf(
      'cancelInboundProjectionRevealForAuthoritativeReplace(conversationID);',
      setListStart,
    );
    expect(setListStart, greaterThanOrEqualTo(0));
    expect(equivalentFastPath, greaterThan(setListStart));
    expect(cancel, greaterThan(setListStart));
    expect(cancel, lessThan(equivalentFastPath));
    expect(
      globalModel.indexOf(
        '_revealAllDeferredProjectionAcrossAliases(conversationID)',
        equivalentFastPath,
      ),
      greaterThan(equivalentFastPath),
    );
    expect(reveal, contains('cancelForAuthoritativeReplace'));
    expect(reveal, contains("action: 'queue_cancel_authoritative_replace'"));
  });

  test('list push and pin follow use the shared physical near-bottom gate', () {
    final messageList = File(
      'third_party/tencent_cloud_chat_uikit/lib/ui/views/TIMUIKitChat/'
      'TIMUIKItMessageList/tim_uikit_chat_history_message_list.dart',
    ).readAsStringSync();
    expect(messageList, contains('globalModel.isActiveChatNearBottom(convId)'));
    expect(messageList, contains('bool _shouldPinScrollToBottom('));
    expect(messageList, contains('bool _shouldRunRowReveal('));
  });
}
