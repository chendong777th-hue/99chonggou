import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('chat page owns one generation gate for open switch and dispose', () {
    final source = File('lib/src/chat.dart').readAsStringSync();

    expect(source, contains('int _chatOpenGeneration = 0;'));
    expect(source, contains('_beginChatOpenGeneration();'));
    expect(source, contains('_chatOpenGeneration++;'));
    expect(source, contains('_isChatOpenGenerationCurrent('));
    expect(source, contains('MessageConversationId.sameConversation('));
    expect(source, contains('MobileAsyncCommitGuard'));
    expect(source, contains("'call-history-refresh'"));
    expect(source, contains('_mobileCommitGuard.canCommit(commitToken)'));
    expect(source, contains('_mobileCommitGuard.advancePage();'));
  });

  test('separate view model gates delayed work and invalidates dispose', () {
    final source = File(
      'third_party/tencent_cloud_chat_uikit/lib/business_logic/'
      'separate_models/tui_chat_separate_view_model.dart',
    ).readAsStringSync();

    expect(source, contains('int _chatOpenGeneration = 0;'));
    expect(source, contains('final initGeneration = ++_chatOpenGeneration;'));
    expect(source, contains('_isChatGenerationCurrent('));
    expect(source, contains('final generation = _chatOpenGeneration;'));
    expect(source, contains('void dispose()'));
    expect(source, contains('runPostOpenProfileEnrichment()'));
    expect(source, contains('_openProfileEnrichmentInFlight'));
    final initStart = source.indexOf('void initForEachConversation(');
    final enrichmentStart = source.indexOf(
      'Future<void> runPostOpenProfileEnrichment()',
      initStart,
    );
    final initBody = source.substring(initStart, enrichmentStart);
    expect(initBody, isNot(contains('loadGroupInfo(groupID ?? convID)')));
    expect(initBody, isNot(contains('_friendshipServices.getFriendsInfo')));
  });

  test('custom parse cache key contains conversation identity and version', () {
    final source = File(
      'lib/utils/custom_message/custom_message_parse_cache.dart',
    ).readAsStringSync();

    expect(source, contains("return 'group:\$groupID';"));
    expect(source, contains("return 'c2c:\$userID';"));
    expect(source, contains("'\$conversation|\$identity|\$version|"));
    expect(source, contains('_payloadHash(payload)'));
  });

  test('chat page guards network enrichment writes against conversation switch',
      () {
    // Plan 095: 网络/轮询任务的 await 后必须校验当前会话/代次，
    // 防止切会话后旧群/旧 C2C 的异步结果写入新会话 UI 状态。
    final source = File('lib/src/chat.dart').readAsStringSync();

    // _loadPeerFaceUrl / _loadPeerLocalProfile：await 后校验 generation + peerId。
    final loadPeerFaceUrl = source.substring(
      source.indexOf('Future<void> _loadPeerFaceUrl()'),
      source.indexOf('Future<void> _loadPeerLocalProfile()'),
    );
    expect(
      loadPeerFaceUrl,
      contains('_isChatOpenGenerationCurrent(generation, convId)'),
    );
    final loadPeerLocalProfile = source.substring(
      source.indexOf('Future<void> _loadPeerLocalProfile()'),
      source.indexOf('void _onPeerProfileRefresh()'),
    );
    expect(
      loadPeerLocalProfile,
      contains('_isChatOpenGenerationCurrent(generation, convId)'),
    );

    // 群头像刷新：await 后仍校验 generation + groupId。
    final refreshAvatars = source.substring(
      source.indexOf(
        'Future<void> _refreshGroupAvatarsFromProfileBusAsync',
      ),
      source.indexOf('void _refreshPeerMessageAvatars'),
    );
    expect(
      refreshAvatars,
      contains('_isChatOpenGenerationCurrent(generation, convId)'),
    );
    expect(refreshAvatars, contains('widget.selectedConversation.groupID'));

    // 群 live 轮询：await 后校验 generation + groupId。
    final loadGroupLive = source.substring(
      source.indexOf('Future<void> _loadGroupLiveCurrent()'),
      source.indexOf('void _onGroupLiveStateChanged()'),
    );
    expect(
      loadGroupLive,
      contains('_isChatOpenGenerationCurrent(generation, convId)'),
    );
    expect(
      loadGroupLive,
      contains(
          'ChatIdFormat.normalizeGroupId(widget.selectedConversation.groupID)'),
    );

    // 三公横幅：await 后校验 generation。
    final loadSangongBanner = source.substring(
      source.indexOf('Future<void> _loadSangongBannerSettings()'),
      source.indexOf('void _applySangongRealtimeState'),
    );
    expect(
      loadSangongBanner,
      contains('_isChatOpenGenerationCurrent(generation, convId)'),
    );

    // 切会话分支必须清空旧群三公/游戏状态。
    final didUpdateWidget = source.substring(
      source.indexOf('void didUpdateWidget(Chat oldWidget)'),
      source.indexOf('_itemClick('),
    );
    expect(didUpdateWidget, contains('_groupSide.clearSangongAccess();'));
    expect(didUpdateWidget, contains('_groupSide.disableGroupGame();'));
  });

  test('tongue bottom transactions are scoped to the widget conversation', () {
    final source = File(
      'third_party/tencent_cloud_chat_uikit/lib/ui/views/TIMUIKitChat/'
      'TIMUIKItMessageList/TIMUIKitTongue/'
      'tim_uikit_chat_history_message_list_tongue_container.dart',
    ).readAsStringSync();
    final bottomStart = source.indexOf(
      'Future<void> _scrollToLatestAndDismissUnreadCapsule()',
    );
    final unreadStart = source.indexOf(
      'Future<void> _jumpToFirstUnreadMessage(',
      bottomStart,
    );
    final bottomBody = source.substring(bottomStart, unreadStart);
    expect(bottomBody, contains('final model = widget.model;'));
    expect(bottomBody, contains('final conversationGeneration ='));
    expect(bottomBody, contains('final transactionToken ='));
    expect(bottomBody, contains('_isCurrentConversationGeneration('));
    expect(bottomBody, contains('model.reloadNewestMessageWindow('));
    expect(bottomBody, contains('model.markMessageAsRead(force: true);'));
    expect(bottomBody, contains('changePositionStateForConversation('));
    expect(
        bottomBody,
        contains(
          'if (transactionToken == _bottomScrollTransactionToken)',
        ));

    final didUpdateStart = source.indexOf('void didUpdateWidget(');
    final positionStateStart = source.indexOf(
      'void changePositionState(',
      didUpdateStart,
    );
    final didUpdateBody = source.substring(didUpdateStart, positionStateStart);
    expect(didUpdateBody, contains('_conversationWidgetGeneration++;'));
    expect(didUpdateBody, contains('_bottomScrollTransactionToken++;'));
    expect(didUpdateBody, contains('globalModel.endUserScrollToBottom('));
    expect(didUpdateBody, contains('_cancelScrollActivity('));
  });

  test('global message callbacks reject work from a cleared lifecycle', () {
    final source = File(
      'third_party/tencent_cloud_chat_uikit/lib/business_logic/view_models/'
      'tui_chat_global_model.dart',
    ).readAsStringSync();
    expect(source, contains('bool _isMessageLifecycleCurrent(int generation)'));

    final updateStart =
        source.indexOf('Future<void> updateMessageFromController(');
    final clearStart = source.indexOf('clearData()', updateStart);
    final updateBody = source.substring(updateStart, clearStart);
    expect(updateBody, contains('final lifecycleGeneration ='));
    expect(updateBody,
        contains('_isMessageLifecycleCurrent(lifecycleGeneration)'));
    expect(
        updateBody, contains('onMessageModified(newMessage, conversationID);'));
    expect(updateBody,
        isNot(contains('onMessageModified(newMessage, currentSelectedConv);')));

    final receiveStart =
        source.indexOf('_onReceiveNewMsg(V2TimMessage msgComing)');
    final receiveEnd =
        source.indexOf('String _revokedCloudCustomData', receiveStart);
    final receiveBody = source.substring(receiveStart, receiveEnd);
    expect(receiveBody, contains('final lifecycleGeneration ='));
    expect(receiveBody,
        contains('_isMessageLifecycleCurrent(lifecycleGeneration)'));

    final modifiedStart =
        source.indexOf('onMessageModified(V2TimMessage modifiedMessage');
    final modifiedEnd =
        source.indexOf('void addAdvancedMsgListener()', modifiedStart);
    final modifiedBody = source.substring(modifiedStart, modifiedEnd);
    expect(modifiedBody, contains('final lifecycleGeneration ='));
    expect(modifiedBody,
        contains('_isMessageLifecycleCurrent(lifecycleGeneration)'));

    final clearEnd =
        source.indexOf('clearReceivedNewMessageCount()', clearStart);
    final clearBody = source.substring(clearStart, clearEnd);
    expect(
        clearBody, contains('_messageHistoryCoverageSessionGeneration += 1;'));
    expect(clearBody, contains('_activeReadReportDebounceMap.clear();'));
    expect(clearBody, contains('_lastActiveReadReportAtMs.clear();'));
  });
}
