import 'dart:async';
import 'dart:collection';

import 'package:flutter/foundation.dart';
import 'package:tencent_cloud_chat_demo/src/services/conversation_deleted_bus.dart';
import 'package:tencent_cloud_chat_uikit/ui/utils/outgoing_visible_probe.dart';
import 'package:tencent_cloud_chat_demo/src/services/conversation_local/conversation_list_notifier.dart';
import 'package:tencent_cloud_chat_demo/src/services/conversation_local/conversation_unread_guard.dart';
import 'package:tencent_cloud_chat_demo/src/services/conversation_local/conversation_list_sync_notifier.dart';
import 'package:tencent_cloud_chat_demo/src/services/conversation_local/conversation_local_store.dart';
import 'package:tencent_cloud_chat_demo/src/services/conversation_local/conversation_perf_flags.dart';
import 'package:tencent_cloud_chat_demo/src/services/conversation_local/conversation_perf_gate_log.dart';
import 'package:tencent_cloud_chat_demo/src/services/conversation_local/conversation_pin_hydrate_policy.dart';
import 'package:tencent_cloud_chat_demo/src/services/conversation_local/c2c_history_backfill.dart';
import 'package:tencent_cloud_chat_demo/src/services/conversation_local/conversation_unread_aggregate.dart';
import 'package:tencent_cloud_chat_demo/src/services/chat_history_refresh_bus.dart';
import 'package:tencent_cloud_chat_demo/src/services/conversation_pin_flicker_log.dart';
import 'package:tencent_cloud_chat_demo/src/services/conversation_pin_sync_service.dart';
import 'package:tencent_cloud_chat_demo/src/services/conversation_unread_trace.dart';
import 'package:tencent_cloud_chat_demo/src/services/friend_local/friend_local_store.dart';
import 'package:tencent_cloud_chat_demo/src/services/foreground_chat_guard.dart';
import 'package:tencent_cloud_chat_demo/src/services/active_chat_registry.dart';
import 'package:tencent_cloud_chat_demo/src/services/contact_social_cache_store.dart';
import 'package:tencent_cloud_chat_demo/src/models/me_group_record.dart';
import 'package:tencent_cloud_chat_demo/src/services/group_local/group_membership_sync_service.dart';
import 'package:tencent_cloud_chat_demo/src/services/conversation_history_warm_scheduler.dart';
import 'package:tencent_cloud_chat_demo/src/services/im_recovery_service.dart';
import 'package:tencent_cloud_chat_demo/src/services/im_snapshot_bootstrap_service.dart';
import 'package:tencent_cloud_chat_demo/src/services/resume_foreground_policy.dart';
import 'package:tencent_cloud_chat_demo/src/utils/group_conversation_visibility.dart';
import 'package:tencent_cloud_chat_demo/src/utils/message_conversation_id.dart';
import 'package:tencent_cloud_chat_demo/utils/chat_id_format.dart';
import 'package:tencent_cloud_chat_demo/utils/group_display_resolver.dart';
import 'package:tencent_cloud_chat_demo/utils/group_tips_message_helper.dart';
import 'package:tencent_cloud_chat_uikit/business_logic/services/display_name_store.dart';
import 'package:tencent_cloud_chat_demo/src/utils/revoked_message_preview.dart';
import 'package:tencent_cloud_chat_sdk/enum/conversation_type.dart';
import 'package:tencent_cloud_chat_sdk/enum/history_msg_get_type_enum.dart';
import 'package:tencent_cloud_chat_sdk/enum/message_status.dart';
import 'package:tencent_cloud_chat_sdk/enum/V2TimConversationListener.dart';
import 'package:tencent_cloud_chat_sdk/enum/V2TimAdvancedMsgListener.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_conversation.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_conversation.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_conversation_filter.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_conversation_filter.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_message.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_message.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_user_full_info.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_user_full_info.dart';
import 'package:tencent_cloud_chat_sdk/tencent_im_sdk_plugin.dart';
import 'package:tencent_cloud_chat_uikit/data_services/conversation/conversation_services.dart';
import 'package:tencent_cloud_chat_uikit/data_services/message/archive_history_provider.dart';
import 'package:tencent_cloud_chat_uikit/data_services/message/message_services.dart';
import 'package:tencent_cloud_chat_uikit/data_services/services_locatar.dart';
import 'package:tencent_cloud_chat_uikit/business_logic/view_models/tui_conversation_view_model.dart';
import 'package:tencent_cloud_chat_uikit/business_logic/view_models/tui_friendship_view_model.dart';
import 'package:tencent_cloud_chat_uikit/business_logic/view_models/tui_chat_global_model.dart';

/// SDK 会话变更统一写入 [ConversationLocalStore]，UI 通过 [ConversationListNotifier] 读库渲染。
class ConversationSyncService {
  ConversationSyncService._();

  static final ConversationSyncService instance = ConversationSyncService._();

  static const int _defaultPageSize = 40;

  bool _installed = false;
  bool _pageSyncInFlight = false;
  int _syncGeneration = 0;
  V2TimConversationListener? _listener;
  V2TimAdvancedMsgListener? _messageListener;
  DateTime? _lastSyncServerFinishAt;
  Timer? _syncServerFinishTimer;
  static const Duration _syncServerFinishDebounce = Duration(seconds: 45);
  static const Duration _syncServerFinishDelay = Duration(milliseconds: 350);

  /// 冷启动 bootstrap 可能在 SDK 离线消息入库前完成；需等 [onSyncServerFinish] 后再拉一次。
  bool _awaitingPostServerSync = false;
  Future<void>? _c2cHistoryBackfillInFlight;
  bool _c2cHistoryBackfillScheduled = false;

  /// 本登录已对「已有本地单聊壳」做过预览/置顶/免打扰富化，避免每次 syncFinish 重扫。
  bool _c2cMetadataEnrichDone = false;

  /// 本登录已做过（或尝试过）好友/置顶补壳扫描。
  bool _c2cFriendScanDone = false;
  _PendingSdkSync? _pendingSdkSync;
  bool _backgroundDrainInFlight = false;
  Timer? _idleDrainTimer;

  /// 本登录会话内 idle/background drain 已拉页数（防误开 flag 时无限 resume）。
  int _idleDrainSessionPages = 0;
  Timer? _historyWarmTimer;
  DateTime? _resumeQuietUntil;
  Future<void>? _scopeHydrationTask;
  bool _scopeHydrationDone = false;
  final Map<String, V2TimMessage> _pendingPatches = <String, V2TimMessage>{};
  int _patchesQueuedDuringSync = 0;
  Timer? _pendingPatchesForceTimer;
  DateTime? _pendingPatchesFirstQueuedAt;

  String? _lastMarkReadId;
  DateTime? _lastMarkReadAt;
  static const Duration _markReadDebounce = Duration(milliseconds: 400);

  Timer? _reloadUiCoalesceTimer;
  int _chatTransitionDepth = 0;
  static const Duration _globalReloadDebounce = Duration(milliseconds: 80);

  /// 返回列表后先让用户手势（左右滑）稳定，再合并落盘刷新，避免与 Slidable 抢主线程。
  static const Duration _postPopCoalesceWindow = Duration(milliseconds: 1400);
  static const Duration _postPopMinFlushDelay = Duration(milliseconds: 700);
  static const Duration _postPopTrailingDebounce = Duration(milliseconds: 200);
  DateTime? _postPopCoalesceUntil;
  DateTime? _postPopCoalesceWindowStart;
  bool _postPopCoalesceScheduled = false;

  /// 合并队列里是否有人要求整窗快照 reload（冷启等白名单）。
  bool _pendingCoalesceForceFull = false;
  Future<void>? _reloadUiInFlight;
  bool _reloadUiDirty = false;
  bool _reloadUiDirtyForceFull = false;

  final Map<String, V2TimConversation> _persistDedupBuffer =
      <String, V2TimConversation>{};
  final Map<String, String> _viewModelPersistFingerprints = <String, String>{};
  final Map<String, String> _persistInFlightFingerprints = <String, String>{};
  Timer? _persistDedupTimer;
  String _persistPendingReason = 'changed';
  String? _recentlyLeftConversationId;

  /// 群成员库尚未含本人时到达的群会话：先挂起，入群后再落库上屏（避免杀进程才看见）。
  final LinkedHashMap<String, V2TimConversation>
      _pendingNonMemberGroupConversations =
      LinkedHashMap<String, V2TimConversation>();
  static const int _pendingNonMemberGroupCap = 64;
  Timer? _membershipExpandReloadTimer;
  final Set<String> _pendingGroupRecoveryScheduled = <String>{};

  @visibleForTesting
  int reloadUiImplInvocationCount = 0;

  @visibleForTesting
  int persistFlushInvocationCount = 0;

  @visibleForTesting
  bool get reloadUiInFlightForTest => _reloadUiInFlight != null;

  @visibleForTesting
  bool get reloadUiDirtyForTest => _reloadUiDirty;

  @visibleForTesting
  Future<void> Function()? reloadUiImplOverride;

  @visibleForTesting
  Future<void> Function(String conversationID)? markReadStoreOverride;

  @visibleForTesting
  Future<List<V2TimConversation>> Function(List<V2TimConversation>)?
      upsertBatchOverride;

  /// 单测注入 ByFilter 拉页。
  @visibleForTesting
  static Future<
          ({
            List<V2TimConversation> conversationList,
            String nextSeq,
            bool isFinished,
            int code,
            String desc,
          })>
      Function({
    required int convType,
    required String nextSeq,
    required int count,
  })? debugGetConversationListByFilterOverride;

  bool get hasActiveChatTransition => _chatTransitionDepth > 0;

  bool get _isFeedScrollingNow =>
      ConversationListNotifier.instance.isFeedScrolling?.call() ?? false;

  bool get _isUiBusyForPersist =>
      _isFeedScrollingNow ||
      hasActiveChatTransition ||
      isInPostPopCoalesceWindow ||
      ActiveChatRegistry.instance.hasOpenChat;

  Duration get _effectivePersistDedupDelay => _isUiBusyForPersist
      ? ConversationPerfFlags.persistDedupDelayBusy
      : ConversationPerfFlags.persistDedupDelay;

  bool _isConversationListenerPersistReason(String reason) {
    final r = reason.trim();
    return r == 'changed' ||
        r == 'new' ||
        r == 'coalesced:changed' ||
        r == 'coalesced:new' ||
        r.startsWith('coalesced:changed') ||
        r.startsWith('coalesced:new');
  }

  Duration _persistDedupDelayForReason(String reason) {
    if (_isConversationListenerPersistReason(reason)) {
      return _isUiBusyForPersist
          ? ConversationPerfFlags.persistDedupDelayConversationListenerBusy
          : ConversationPerfFlags.persistDedupDelayConversationListener;
    }
    return _effectivePersistDedupDelay;
  }

  @visibleForTesting
  bool shouldMarkReadReloadImmediately() {
    return _chatTransitionDepth > 0 && !isInPostPopCoalesceWindow;
  }

  @visibleForTesting
  void resetChatTransitionStateForTesting() {
    _reloadUiCoalesceTimer?.cancel();
    _reloadUiCoalesceTimer = null;
    _chatTransitionDepth = 0;
    _postPopCoalesceUntil = null;
    _postPopCoalesceWindowStart = null;
    _postPopCoalesceScheduled = false;
    reloadUiImplInvocationCount = 0;
    reloadUiImplOverride = null;
    markReadStoreOverride = null;
    upsertBatchOverride = null;
    _reloadUiInFlight = null;
    _reloadUiDirty = false;
    _reloadUiDirtyForceFull = false;
    _pendingCoalesceForceFull = false;
    _persistDedupTimer?.cancel();
    _persistDedupTimer = null;
    _persistDedupBuffer.clear();
    _viewModelPersistFingerprints.clear();
    _persistInFlightFingerprints.clear();
    persistFlushInvocationCount = 0;
    _persistPendingReason = 'changed';
    _recentlyLeftConversationId = null;
    _pendingSdkSync = null;
    _backgroundDrainInFlight = false;
    _idleDrainTimer?.cancel();
    _idleDrainTimer = null;
    _idleDrainSessionPages = 0;
    _historyWarmTimer?.cancel();
    _historyWarmTimer = null;
    _resumeQuietExitTimer?.cancel();
    _resumeQuietExitTimer = null;
    _resumeQuietUntil = null;
    _uiApplyPendingAfterQuietOrScroll = false;
    _pendingUiApplyById.clear();
    _deferredViewModelPersistById.clear();
    _sdkSyncResumeAfterScroll = false;
    _reloadUiDeferredWhileScrolling = false;
    _scrollEndFlushTimer?.cancel();
    _scrollEndFlushTimer = null;
    _pendingPatchesForceTimer?.cancel();
    _pendingPatchesForceTimer = null;
    _pendingPatchesFirstQueuedAt = null;
    _pendingPatches.clear();
    _patchesQueuedDuringSync = 0;
    ConversationListSyncNotifier.instance.setDraining(false);
  }

  @visibleForTesting
  Future<void> notifyUiAfterLocalWriteForTest({
    List<V2TimConversation> upserted = const [],
    V2TimConversation? updated,
  }) {
    return _notifyUiAfterLocalWrite(upserted: upserted, updated: updated);
  }

  @visibleForTesting
  Future<void> applyPacedSyncPageToUiForTest(
    List<V2TimConversation> merged, {
    String reason = 'test',
  }) {
    return _applyPacedSyncPageToUi(merged, reason: reason, allowDefer: false);
  }

  @visibleForTesting
  void notePendingUiApplyForTest(
    List<V2TimConversation> conversations, {
    String via = 'test',
    String cause = 'test',
  }) {
    _notePendingUiApply(conversations, via: via, cause: cause);
  }

  @visibleForTesting
  Future<void> forceFlushPendingPatchesForTest() {
    return _forceFlushPendingPatches(reason: 'test');
  }

  @visibleForTesting
  int get pendingPreviewPatchCountForTest => _pendingPatches.length;

  @visibleForTesting
  void queuePendingPreviewPatchForTest({
    required String conversationId,
    required V2TimMessage message,
  }) {
    final id = conversationId.trim();
    if (id.isEmpty) {
      return;
    }
    _pendingPatches[id] = message;
    _patchesQueuedDuringSync++;
    _pendingPatchesFirstQueuedAt ??= DateTime.now();
  }

  @visibleForTesting
  int get pendingUiApplyCountForTest => _pendingUiApplyById.length;

  @visibleForTesting
  Future<void> flushPendingUiApplyForTest({required String reason}) {
    return _flushPendingUiApply(reason: reason);
  }

  @visibleForTesting
  static bool shouldScheduleIdleDrainResume({
    required bool idleBackgroundDrainEnabled,
    required bool haveMore,
    required int sessionDrainPages,
    required int sessionDrainPageBudget,
  }) {
    if (!idleBackgroundDrainEnabled) {
      return false;
    }
    if (!haveMore) {
      return false;
    }
    if (sessionDrainPageBudget > 0 &&
        sessionDrainPages >= sessionDrainPageBudget) {
      return false;
    }
    return true;
  }

  @visibleForTesting
  static bool shouldQueueSyncServerFinishDuringPageSync({
    required bool needsFullReset,
    required bool awaitingPostServerSync,
  }) {
    return needsFullReset || awaitingPostServerSync;
  }

  @visibleForTesting
  static bool shouldUsePostPopLightReload({
    required bool inPostPopWindow,
    required bool postPopLightReloadEnabled,
  }) {
    return postPopLightReloadEnabled && inPostPopWindow;
  }

  @visibleForTesting
  bool shouldSuppressStaleUnreadForTest(String conversationID) {
    return shouldSuppressStaleUnread(conversationID);
  }

  bool shouldSuppressStaleUnread(String conversationID) {
    if (!isInPostPopCoalesceWindow) {
      return false;
    }
    final left = _recentlyLeftConversationId?.trim() ?? '';
    if (left.isEmpty) {
      return false;
    }
    return MessageConversationId.sameConversation(conversationID, left);
  }

  bool get isInPostPopCoalesceWindow {
    final until = _postPopCoalesceUntil;
    return until != null && DateTime.now().isBefore(until);
  }

  void beginChatTransition() {
    _chatTransitionDepth++;
    _reloadUiCoalesceTimer?.cancel();
    _reloadUiCoalesceTimer = null;
    _postPopCoalesceScheduled = false;
  }

  void cancelChatTransition() {
    if (_chatTransitionDepth > 0) {
      _chatTransitionDepth--;
    }
    _reloadUiCoalesceTimer?.cancel();
    _reloadUiCoalesceTimer = null;
  }

  void schedulePostPopCoalesceWindow({String? conversationID}) {
    if (_postPopCoalesceScheduled) {
      return;
    }
    if (_chatTransitionDepth <= 0 && _postPopCoalesceUntil == null) {
      return;
    }
    _postPopCoalesceScheduled = true;
    if (_chatTransitionDepth > 0) {
      _chatTransitionDepth--;
    }
    final explicit = conversationID?.trim() ?? '';
    _recentlyLeftConversationId = explicit.isNotEmpty
        ? explicit
        : ActiveChatRegistry.instance.activeConversationId;
    ConversationUnreadTrace.log(
      'post_pop_window_start',
      conversationID: _recentlyLeftConversationId,
      extras: <String, Object?>{
        'depth': _chatTransitionDepth,
        'windowMs': _postPopCoalesceWindow.inMilliseconds,
      },
    );
    _postPopCoalesceUntil = DateTime.now().add(_postPopCoalesceWindow);
    _postPopCoalesceWindowStart = DateTime.now();
    _scheduleCoalescedReloadUi(postPop: true);
  }

  Future<void> flushPendingReloadUi() async {
    _reloadUiCoalesceTimer?.cancel();
    _reloadUiCoalesceTimer = null;
    _postPopCoalesceUntil = null;
    _postPopCoalesceWindowStart = null;
    _postPopCoalesceScheduled = false;
    final forceFull = _pendingCoalesceForceFull;
    _pendingCoalesceForceFull = false;
    // 默认 soft：保留滑动窗；仅队列里曾要求 forceFull 时整窗快照。
    await _reloadUiFromLocalImpl(forceFull: forceFull);
    _recentlyLeftConversationId = null;
  }

  ConversationService get _conversationService =>
      serviceLocator<ConversationService>();

  /// 用 `/me/groups` 的真实群名回填会话列表，避免标题显示 `@TGS#_@TGS#…`。
  Future<void> applyGroupDisplayNames(Iterable<MeGroupRecord> records) async {
    final byToken = <String, String>{};
    final avatarByToken = <String, String>{};
    for (final record in records) {
      final name = record.groupName.trim();
      final groupId = record.groupId.trim();
      if (groupId.isEmpty) {
        continue;
      }
      final token = ChatIdFormat.groupEquivalenceToken(groupId) ?? groupId;
      if (name.isNotEmpty &&
          !GroupDisplayResolver.looksLikeGroupIdLabel(name, groupId: groupId)) {
        byToken[token] = name;
        DisplayNameStore.instance.setGroup(groupId, name, notify: false);
        final canonical = ChatIdFormat.canonicalGroupStorageId(groupId);
        if (canonical.isNotEmpty) {
          DisplayNameStore.instance.setGroup(canonical, name, notify: false);
        }
      }
      final avatar = record.avatarUrl.trim();
      if (avatar.isNotEmpty) {
        avatarByToken[token] = avatar;
      }
    }
    if (byToken.isEmpty && avatarByToken.isEmpty) {
      return;
    }

    final toPersist = <V2TimConversation>[];
    for (final conversation
        in ConversationListNotifier.instance.conversations) {
      final groupId = conversation.groupID?.trim() ?? '';
      if (groupId.isEmpty) {
        continue;
      }
      final token = ChatIdFormat.groupEquivalenceToken(groupId) ?? groupId;
      final name = byToken[token];
      final avatar = avatarByToken[token];
      var touched = false;
      if (name != null && name.isNotEmpty) {
        final current = conversation.showName?.trim() ?? '';
        if (current != name) {
          ConversationListNotifier.instance.applyShowNameLocally(
            conversationID: conversation.conversationID,
            showName: name,
          );
          conversation.showName = name;
          touched = true;
        }
      }
      if (avatar != null && avatar.isNotEmpty) {
        final currentFace = conversation.faceUrl?.trim() ?? '';
        if (currentFace != avatar) {
          ConversationListNotifier.instance.applyFaceUrlLocally(
            conversationID: conversation.conversationID,
            faceUrl: avatar,
          );
          conversation.faceUrl = avatar;
          touched = true;
        }
      }
      if (touched) {
        toPersist.add(conversation);
      }
    }
    if (toPersist.isEmpty) {
      return;
    }
    await ConversationLocalStore.instance.upsertBatch(
      conversations: toPersist,
    );
  }

  /// 会话同步明细日志。默认关闭：冷启/删除风暴时 print 极密，debug/release 均会刷屏。
  static const bool _logEnabled = false;

  // ignore: avoid_print
  static void _log(String message) {
    if (!_logEnabled) return;
    print('ConversationSync: $message');
  }

  void install() {
    if (_installed) {
      return;
    }
    _installed = true;
    _listener = V2TimConversationListener(
      onConversationChanged: (list) {
        unawaited(_persistChanged(list, reason: 'changed'));
      },
      onNewConversation: (list) {
        unawaited(_persistChanged(list, reason: 'new'));
      },
      onConversationDeleted: (ids) {
        // 与用户删除/清空一致：真删本地行，不因清空水位回钉空壳。
        unawaited(_persistDeleted(ids, force: true));
      },
      onSyncServerFinish: () {
        _scheduleSyncServerFinish();
      },
    );
    unawaited(
      TencentImSDKPlugin.v2TIMManager
          .getConversationManager()
          .addConversationListener(listener: _listener!),
    );
    _messageListener = V2TimAdvancedMsgListener(
      onRecvMessageRevoked: (msgID) {
        unawaited(markConversationLastMessageRevoked(msgID: msgID));
      },
      onRecvMessageRevokedWithInfo: (msgID, operateUser, reason) {
        unawaited(
          markConversationLastMessageRevoked(
            msgID: msgID,
            isAdmin: _isAdminRevokeReason(reason),
            revoker: operateUser,
          ),
        );
      },
      onRecvNewMessage: (message) {
        _onRecvNewMessageForMembershipBridge(message);
      },
    );
    unawaited(
      TencentImSDKPlugin.v2TIMManager
          .getMessageManager()
          .addAdvancedMsgListener(listener: _messageListener!),
    );
  }

  /// 将本地会话预览中的最后一条消息标记为已撤回。
  Future<void> markConversationLastMessageRevoked({
    required String msgID,
    String? conversationID,
    bool isAdmin = false,
    V2TimUserFullInfo? revoker,
  }) async {
    final targetMsgID = msgID.trim();
    if (targetMsgID.isEmpty) {
      return;
    }
    final normalizedConversationID = conversationID?.trim() ?? '';
    V2TimConversation? conversation;
    if (normalizedConversationID.isNotEmpty) {
      conversation = await ConversationLocalStore.instance
          .conversationById(normalizedConversationID);
    }
    conversation ??= ConversationListNotifier.instance
        .findConversationByLastMessageId(targetMsgID);
    conversation ??=
        await ConversationLocalStore.instance.findByLastMsgId(targetMsgID);

    final source = conversation?.lastMessage;
    if (conversation == null ||
        source == null ||
        !lastMessageMatchesRevokeTarget(source, targetMsgID)) {
      return;
    }

    // 必须换对象：列表行 StatefulWidget 对同一 lastMessage 引用不重算摘要。
    final lastMessage = V2TimMessage.fromJson(source.toJson());
    applyRemoteRevokedStateToMessage(
      lastMessage,
      isAdmin: isAdmin,
      revoker: revoker,
    );
    conversation.lastMessage = lastMessage;

    ConversationListNotifier.instance.applyLastMessageLocally(
      conversationID: conversation.conversationID,
      message: lastMessage,
    );
    final merged = await ConversationLocalStore.instance.upsertBatch(
      conversations: [conversation],
    );
    await _notifyUiAfterLocalWrite(upserted: merged);
  }

  static bool _isAdminRevokeReason(String reason) {
    final normalized = reason.trim().toLowerCase();
    if (normalized.isEmpty) {
      return false;
    }
    return normalized.contains('admin') || normalized.contains('groupowner');
  }

  String _ownerUserId() =>
      ChatIdFormat.rawUserUid(ContactSocialCacheStore.safeLoginUserId());

  void _notifyChatRoamingSyncFinished() {
    try {
      serviceLocator<TUIChatGlobalModel>().notifyRoamingSyncFinished();
    } catch (_) {}
  }

  void _scheduleSyncServerFinish() {
    _syncServerFinishTimer?.cancel();
    _syncServerFinishTimer = Timer(_syncServerFinishDelay, () {
      _syncServerFinishTimer = null;
      _notifyChatRoamingSyncFinished();
      unawaited(_handleSyncServerFinish());
    });
  }

  Future<void> _handleSyncServerFinish() async {
    final last = _lastSyncServerFinishAt;
    final now = DateTime.now();
    if (last != null && now.difference(last) < _syncServerFinishDebounce) {
      _log('sync_server_finish skipped debounce');
      return;
    }

    final meta = await ConversationLocalStore.instance.readSyncMeta();
    final rowCount = await ConversationLocalStore.instance.countRows();
    final needsFullReset = shouldFullResetOnServerFinish(
      hasSyncedOnce: meta.hasSyncedOnce,
      rowCount: rowCount,
    );
    // Admit this callback before awaiting another SDK page. Otherwise that
    // page's own sync-finished callback can enter again and keep replaying a
    // pending sync forever.
    _lastSyncServerFinishAt = now;

    if (_pageSyncInFlight) {
      if (!shouldQueueSyncServerFinishDuringPageSync(
        needsFullReset: needsFullReset,
        awaitingPostServerSync: _awaitingPostServerSync,
      )) {
        // The active getConversationList can itself emit sync-finished. It is
        // not new server state and must not enqueue another identical page.
        _log('sync_server_finish ignored (page sync self-feedback)');
        return;
      }
      if (needsFullReset) {
        _enqueuePendingSync(
          reason: 'sync_server_finish_cold',
          reset: true,
          drainMode: ConversationSdkDrainMode.foregroundLimited,
          reloadUiEachPage: false,
        );
      } else if (_awaitingPostServerSync) {
        _enqueuePendingSync(
          reason: 'sync_server_finish_catchup',
          reset: false,
          drainMode: ConversationSdkDrainMode.foregroundLimited,
          reloadUiEachPage: false,
        );
      }
      unawaited(
        maybeBackfillC2cFromHistoryPeers(
          reason: 'sync_server_finish_while_paging',
        ),
      );
      return;
    }

    if (needsFullReset) {
      _log(
        'sync_server_finish cold foregroundLimited awaiting=$_awaitingPostServerSync',
      );
      await syncFromSdk(
        reason: 'sync_server_finish_cold',
        reset: true,
        drainMode: ConversationSdkDrainMode.foregroundLimited,
        reloadUiEachPage: false,
      );
      _awaitingPostServerSync = false;
    } else if (_awaitingPostServerSync) {
      _log('sync_server_finish_catchup reset=false');
      await syncFromSdk(
        reason: 'sync_server_finish_catchup',
        reset: false,
        drainMode: ConversationSdkDrainMode.foregroundLimited,
        reloadUiEachPage: false,
      );
      _awaitingPostServerSync = false;
    } else {
      _log('sync_server_finish incremental first page');
      await syncFromSdk(
        reason: 'sync_server_finish',
        reset: false,
        drainMode: ConversationSdkDrainMode.singlePage,
        reloadUiEachPage: false,
      );
    }
    unawaited(
      GroupMembershipSyncService.instance.pruneStaleGroupConversations(
        reason: 'sync_server_finish',
      ),
    );
    unawaited(
      ImRecoveryService.instance.refreshForegroundChatIfNeeded(
        reason: 'sync_server_finish',
      ),
    );
    scheduleHistoryWarmWhenIdle(
      reason: needsFullReset ? 'sync_server_finish_cold' : 'sync_server_finish',
    );
    unawaited(
      maybeBackfillC2cFromHistoryPeers(reason: 'sync_server_finish'),
    );
  }

  Future<void> ensureInitialSync({String reason = 'initial'}) async {
    await reloadUiFromLocal(immediate: true, forceFull: true);
    final owner = _ownerUserId();
    if (owner.isEmpty) {
      return;
    }
    await healC2cCursorIfNeeded(reason: '${reason}_heal');
    final meta = await ConversationLocalStore.instance.readSyncMeta();
    final rowCount = await ConversationLocalStore.instance.countRows();
    if (meta.hasSyncedOnce &&
        rowCount > 0 &&
        !meta.c2cHaveMore &&
        !meta.groupHaveMore) {
      ConversationListSyncNotifier.instance.setHasSyncedOnce(true);
      return;
    }
    final shouldReset = !meta.hasSyncedOnce || rowCount == 0;
    if (!shouldReset && meta.hasSyncedOnce) {
      // 残留：按类型补一页（升级后游标归零时相当于重灌首屏）。
      var latest = await ConversationLocalStore.instance.readSyncMeta();
      if (latest.c2cHaveMore) {
        await syncFromSdkByType(
          convType: ConversationType.V2TIM_C2C,
          reason: '${reason}_resume_c2c',
          count: _typedPageCount(ConversationType.V2TIM_C2C),
        );
        latest = await ConversationLocalStore.instance.readSyncMeta();
      }
      if (latest.groupHaveMore) {
        await syncFromSdkByType(
          convType: ConversationType.V2TIM_GROUP,
          reason: '${reason}_resume_group',
          count: _typedPageCount(ConversationType.V2TIM_GROUP),
        );
      }
      return;
    }
    await bootstrapTypedFirstScreen(reason: reason, reset: true);
  }

  Future<void> ensureVisibleConversations({
    required bool Function() hasVisibleConversations,
    String reason = 'scope_empty',
  }) async {
    if (_scopeHydrationDone && hasVisibleConversations()) {
      return;
    }
    final inFlight = _scopeHydrationTask;
    if (inFlight != null) {
      await inFlight;
      if (hasVisibleConversations()) {
        return;
      }
    }
    late final Future<void> task;
    task = _ensureVisibleConversationsImpl(
      hasVisibleConversations: hasVisibleConversations,
      reason: reason,
    ).whenComplete(() {
      if (identical(_scopeHydrationTask, task)) {
        _scopeHydrationTask = null;
      }
    });
    _scopeHydrationTask = task;
    await task;
  }

  Future<void> _ensureVisibleConversationsImpl({
    required bool Function() hasVisibleConversations,
    required String reason,
  }) async {
    final notifier = ConversationListNotifier.instance;
    final allowForceFull =
        notifier.conversations.isEmpty && !notifier.slidingWindowUserExpanded;
    await reloadUiFromLocal(immediate: true, forceFull: allowForceFull);
    if (hasVisibleConversations()) {
      _scopeHydrationDone = true;
      return;
    }
    await healC2cCursorIfNeeded(reason: '${reason}_heal');
    final meta = await ConversationLocalStore.instance.readSyncMeta();
    final rowCount = await ConversationLocalStore.instance.countRows();
    final hasLocalData = rowCount > 0;
    final typedHaveMore = meta.c2cHaveMore || meta.groupHaveMore;
    if (meta.hasSyncedOnce && hasLocalData && typedHaveMore) {
      await syncFromSdk(
        reason: reason,
        reset: false,
        drainMode: ConversationSdkDrainMode.singlePage,
        reloadUiEachPage: false,
      );
      await _reloadUiAfterHydrationPage();
      if (hasVisibleConversations()) {
        _scopeHydrationDone = true;
        return;
      }
    }
    // 可见为空时按页补到有可见项或远端耗尽，禁止阻塞式全量写库。
    var pageGuard = 0;
    while (!hasVisibleConversations() && pageGuard < 8) {
      final latest = await ConversationLocalStore.instance.readSyncMeta();
      final latestHaveMore = latest.c2cHaveMore || latest.groupHaveMore;
      if (!latestHaveMore && latest.hasSyncedOnce) {
        break;
      }
      pageGuard++;
      await syncFromSdk(
        reason: '${reason}_page_$pageGuard',
        reset: !latest.hasSyncedOnce && pageGuard == 1,
        drainMode: pageGuard == 1 && !latest.hasSyncedOnce
            ? ConversationSdkDrainMode.foregroundLimited
            : ConversationSdkDrainMode.singlePage,
        reloadUiEachPage: false,
      );
      await _reloadUiAfterHydrationPage();
      if (hasVisibleConversations()) {
        _scopeHydrationDone = true;
        return;
      }
      final after = await ConversationLocalStore.instance.readSyncMeta();
      if (!after.c2cHaveMore && !after.groupHaveMore) {
        break;
      }
    }
    if (!hasLocalData || !meta.hasSyncedOnce) {
      await syncFromSdk(
        reason: '${reason}_seed',
        reset: true,
        drainMode: ConversationSdkDrainMode.foregroundLimited,
      );
    }
    _scopeHydrationDone = true;
  }

  /// hydration 补页后刷新 UI：已扩展滑动窗则禁止热快照整窗覆盖。
  Future<void> _reloadUiAfterHydrationPage() async {
    final notifier = ConversationListNotifier.instance;
    final forceFull =
        notifier.conversations.isEmpty && !notifier.slidingWindowUserExpanded;
    await reloadUiFromLocal(forceFull: forceFull);
  }

  /// [forceFull]=true：整窗快照 reload（冷启/空窗 hydration 等白名单）。
  /// 默认 false：soft 保留当前滑动窗，只 patch 刚离开的会话。
  Future<void> reloadUiFromLocal({
    bool immediate = false,
    bool forceFull = false,
  }) async {
    if (forceFull &&
        !immediate &&
        !ConversationPerfFlags.conversationListSdkPrimary &&
        ConversationPerfFlags.resumeQuietBlocksHeavyUiReload &&
        isInResumeQuietWindow) {
      ConversationPerfGateLog.log(
        'resume_quiet_block',
        extras: <String, Object?>{'what': 'force_full_reload'},
      );
      _pendingCoalesceForceFull = true;
      _uiApplyPendingAfterQuietOrScroll = true;
      return;
    }
    if (forceFull) {
      _pendingCoalesceForceFull = true;
    }
    if (immediate) {
      _reloadUiCoalesceTimer?.cancel();
      _reloadUiCoalesceTimer = null;
      final full = _pendingCoalesceForceFull;
      _pendingCoalesceForceFull = false;
      await _reloadUiFromLocalImpl(forceFull: full);
      return;
    }
    if (isInPostPopCoalesceWindow) {
      _scheduleCoalescedReloadUi(postPop: true);
      return;
    }
    _scheduleCoalescedReloadUi(postPop: false);
  }

  Future<void> _notifyUiAfterLocalWrite({
    List<V2TimConversation> upserted = const [],
    List<String> deletedIds = const [],
    List<String> exactDeletedIds = const [],
    V2TimConversation? updated,
    bool fullReload = false,
    bool immediate = false,
  }) async {
    if (fullReload) {
      if (ConversationPerfFlags.conversationListSdkPrimary) {
        // Phase2：整窗刷新走 TabStore，不读自建库。
        await ConversationListNotifier.instance.reloadFromLocal();
        return;
      }
      await reloadUiFromLocal(immediate: immediate);
      return;
    }
    if (!immediate && _shouldDeferPersistUiApply()) {
      final cause = _persistUiDeferCause() ?? 'unknown';
      final batch = <V2TimConversation>[
        if (updated != null) updated,
        ...upserted,
      ];
      _notePendingUiApply(batch, via: 'notify', cause: cause);
      return;
    }
    // 兼容旧开关：仍允许「只排 soft reload」路径（当 persistUiApplyWhileFeedScrolling=true）。
    if (!immediate &&
        ConversationPerfFlags.deferUiNotifyWhileFeedScrolling &&
        _isFeedScrollingNow) {
      _scheduleCoalescedReloadUi(postPop: isInPostPopCoalesceWindow);
      return;
    }
    if (updated != null) {
      await ConversationListNotifier.instance.applyConversationsFromStore(
        upserted: [updated],
      );
      return;
    }
    final mergedDeleted = <String>{
      ...deletedIds.map((e) => e.trim()).where((e) => e.isNotEmpty),
      ...exactDeletedIds.map((e) => e.trim()).where((e) => e.isNotEmpty),
    }.toList(growable: false);
    if (upserted.isNotEmpty || mergedDeleted.isNotEmpty) {
      await ConversationListNotifier.instance.applyConversationsFromStore(
        upserted: upserted,
        deletedIds: mergedDeleted,
      );
    }
  }

  void _scheduleCoalescedReloadUi({bool postPop = false}) {
    final now = DateTime.now();
    final inPostPop = postPop || isInPostPopCoalesceWindow;
    late Duration delay;
    if (inPostPop) {
      final until = _postPopCoalesceUntil ?? now.add(_postPopCoalesceWindow);
      final windowStart = _postPopCoalesceWindowStart ?? now;
      final minFlushAt = windowStart.add(_postPopMinFlushDelay);
      var target = now.add(_postPopTrailingDebounce);
      if (target.isBefore(minFlushAt)) {
        target = minFlushAt;
      }
      if (target.isAfter(until)) {
        target = until;
      }
      delay = target.difference(now);
      if (delay.isNegative) {
        delay = Duration.zero;
      }
      _reloadUiCoalesceTimer?.cancel();
    } else {
      delay = _globalReloadDebounce;
      _reloadUiCoalesceTimer?.cancel();
    }

    _reloadUiCoalesceTimer = Timer(delay, _onCoalescedReloadTimerFired);
  }

  bool _reloadUiDeferredWhileScrolling = false;

  /// 滚动/quiet 期间挂起的 UI apply（停滑或 quiet 结束 flush）。
  bool _uiApplyPendingAfterQuietOrScroll = false;
  final Map<String, V2TimConversation> _pendingUiApplyById =
      <String, V2TimConversation>{};

  /// legacy quiet/scroll 挂起帽；sdkPrimary 下 [_notePendingUiApply] 直接 no-op。
  static const int _pendingUiApplyCap = 80;
  Timer? _resumeQuietExitTimer;

  /// 滚动中暂缓的 ViewModel 分页写库。
  final Map<String, V2TimConversation> _deferredViewModelPersistById =
      <String, V2TimConversation>{};
  static const int _deferredViewModelPersistCap = 200;

  bool get isInResumeQuietWindow {
    final until = _resumeQuietUntil;
    return until != null && DateTime.now().isBefore(until);
  }

  /// 等到 resume quiet 结束（或已不在 quiet）；供 PostHome / 群 sync 错峰。
  Future<void> waitUntilResumeQuietEnds() async {
    final until = _resumeQuietUntil;
    if (until == null) {
      return;
    }
    final left = until.difference(DateTime.now());
    if (left <= Duration.zero) {
      return;
    }
    ConversationPerfGateLog.log(
      'resume_quiet_wait',
      extras: <String, Object?>{'waitMs': left.inMilliseconds},
    );
    await Future<void>.delayed(left);
  }

  bool _shouldDeferPersistUiApply() {
    // Phase2：SDK-primary 时列表不依赖 DB 灌数，quiet/scroll 不得挂起 UI apply。
    if (ConversationPerfFlags.conversationListSdkPrimary) {
      return false;
    }
    if (_isFeedScrollingNow &&
        !ConversationPerfFlags.persistUiApplyWhileFeedScrolling) {
      return true;
    }
    if (isInResumeQuietWindow &&
        !ConversationPerfFlags.persistUiApplyInResumeQuiet) {
      return true;
    }
    // 默认 persistUiApplyWhileActiveChat=true：Chat 内仍 apply 内存/角标 delta，
    // Feed notify 由 Notifier defer；仅显式关闭时才挂起 apply。
    if (ActiveChatRegistry.instance.hasOpenChat &&
        !ConversationPerfFlags.persistUiApplyWhileActiveChat) {
      return true;
    }
    return false;
  }

  String? _persistUiDeferCause() {
    if (_isFeedScrollingNow &&
        !ConversationPerfFlags.persistUiApplyWhileFeedScrolling) {
      return 'scroll';
    }
    if (isInResumeQuietWindow &&
        !ConversationPerfFlags.persistUiApplyInResumeQuiet) {
      return 'quiet';
    }
    if (ActiveChatRegistry.instance.hasOpenChat &&
        !ConversationPerfFlags.persistUiApplyWhileActiveChat) {
      return 'active_chat';
    }
    return null;
  }

  void _notePendingUiApply(
    List<V2TimConversation> conversations, {
    required String via,
    required String cause,
  }) {
    // Phase4：sdkPrimary 列表不走 DB pending 帽；Listener/TabStore 已即时灌 UI。
    if (ConversationPerfFlags.conversationListSdkPrimary) {
      ConversationPerfGateLog.log(
        'mirror_skip_ui',
        extras: <String, Object?>{
          'via': 'pending_ui_apply',
          'cause': cause,
          'count': conversations.length,
        },
      );
      return;
    }
    _uiApplyPendingAfterQuietOrScroll = true;
    for (final c in conversations) {
      final id = c.conversationID.trim();
      if (id.isEmpty) {
        continue;
      }
      _pendingUiApplyById[id] = c;
    }
    while (_pendingUiApplyById.length > _pendingUiApplyCap) {
      _pendingUiApplyById.remove(_pendingUiApplyById.keys.first);
    }
    ConversationPerfGateLog.log(
      'ui_apply_deferred',
      extras: <String, Object?>{
        'cause': cause,
        'count': conversations.length,
        'pending': _pendingUiApplyById.length,
        'via': via,
      },
    );
    // 角标延后刷新；失败不影响写库/defer 主路径。
    if (!ConversationPerfGateLog.skipUnreadAggregateScheduleForTest) {
      ConversationUnreadAggregate.instance.scheduleRefresh(
        reason: 'ui_apply_deferred_$cause',
      );
    }
  }

  bool _sdkSyncResumeAfterScroll = false;
  Timer? _scrollEndFlushTimer;
  Future<void>? _scrollEndFlushInFlight;
  bool _scrollEndFlushDirty = false;

  /// 列表开始滚动时取消 settle 中的 scroll_end flush，避免滑到一半又灌窗。
  void onFeedScrollStarted() {
    _scrollEndFlushTimer?.cancel();
    _scrollEndFlushTimer = null;
  }

  /// quiet 结束且热窗未扩展：soft 热快照（保类型地板）。
  /// scroll_end / 已扩展：只 patch「已在 UI 窗内」的会话，禁止未读群批量灌窗。
  Future<void> _flushPendingUiApply({required String reason}) async {
    if (ConversationPerfFlags.conversationListSdkPrimary) {
      _uiApplyPendingAfterQuietOrScroll = false;
      _pendingUiApplyById.clear();
      ConversationPerfGateLog.log(
        'mirror_skip_ui',
        extras: <String, Object?>{
          'via': 'pending_ui_flush',
          'reason': reason,
        },
      );
      return;
    }
    if (!_uiApplyPendingAfterQuietOrScroll && _pendingUiApplyById.isEmpty) {
      return;
    }
    _uiApplyPendingAfterQuietOrScroll = false;
    final pending = _pendingUiApplyById.values.toList(growable: false);
    _pendingUiApplyById.clear();
    final notifier = ConversationListNotifier.instance;
    final quietSoft = reason.contains('quiet') &&
        !notifier.slidingWindowUserExpanded &&
        pending.isNotEmpty;
    if (quietSoft) {
      ConversationPerfGateLog.log(
        'ui_apply_flush',
        extras: <String, Object?>{
          'reason': reason,
          'pendingCount': pending.length,
          'mode': 'soft_hot',
        },
      );
      await _reloadUiFromLocalImpl(forceFull: false);
      return;
    }
    if (pending.isEmpty) {
      ConversationPerfGateLog.log(
        'ui_apply_flush',
        extras: <String, Object?>{
          'reason': reason,
          'pendingCount': 0,
          'mode': 'soft',
        },
      );
      await _reloadUiFromLocalImpl(forceFull: false);
      return;
    }
    final inWindow = <V2TimConversation>[];
    for (final conversation in pending) {
      final id = conversation.conversationID.trim();
      if (id.isEmpty) {
        continue;
      }
      final exists = notifier.conversations.any(
        (c) => MessageConversationId.sameConversation(c.conversationID, id),
      );
      if (exists) {
        inWindow.add(conversation);
      }
    }
    ConversationPerfGateLog.log(
      'ui_apply_flush',
      extras: <String, Object?>{
        'reason': reason,
        'pendingCount': pending.length,
        'inWindow': inWindow.length,
        'skippedOutside': pending.length - inWindow.length,
        'mode': 'in_window',
      },
    );
    if (inWindow.isNotEmpty) {
      await notifier.applyWindowPatchesIfNeeded(upserted: inWindow);
    } else if (!ConversationPerfGateLog.skipUnreadAggregateScheduleForTest) {
      ConversationUnreadAggregate.instance.scheduleRefresh(
        reason: 'flush_${reason}_outside_only',
      );
    }
    // 窗外页已在库：按窗外类型推动本地 append，解决触底不加载。
    final skippedOutside = pending.length - inWindow.length;
    if (skippedOutside > 0) {
      var needGroup = false;
      var needC2c = false;
      for (final conversation in pending) {
        final id = conversation.conversationID.trim();
        if (id.isEmpty) {
          continue;
        }
        final exists = notifier.conversations.any(
          (c) => MessageConversationId.sameConversation(c.conversationID, id),
        );
        if (exists) {
          continue;
        }
        if ((conversation.type == 2) ||
            conversation.conversationID.trim().startsWith('group_')) {
          needGroup = true;
        } else {
          needC2c = true;
        }
      }
      var groupAdded = 0;
      var c2cAdded = 0;
      if (needGroup) {
        groupAdded = (await notifier.appendOlderFromLocal(convType: 2)).added;
      }
      if (needC2c) {
        c2cAdded = (await notifier.appendOlderFromLocal(convType: 1)).added;
      }
      ConversationPerfGateLog.log(
        'ui_apply_flush_append',
        extras: <String, Object?>{
          'reason': reason,
          'skippedOutside': skippedOutside,
          'groupAdded': groupAdded,
          'c2cAdded': c2cAdded,
          'window': notifier.conversations.length,
        },
      );
    }
  }

  void _onCoalescedReloadTimerFired() {
    _reloadUiCoalesceTimer = null;
    final until = _postPopCoalesceUntil;
    if (until != null && DateTime.now().isAfter(until)) {
      _postPopCoalesceUntil = null;
      _postPopCoalesceWindowStart = null;
      _postPopCoalesceScheduled = false;
    }
    if (ConversationPerfFlags.deferUiNotifyWhileFeedScrolling &&
        _isFeedScrollingNow) {
      _reloadUiDeferredWhileScrolling = true;
      _scheduleCoalescedReloadUi(postPop: isInPostPopCoalesceWindow);
      return;
    }
    final forceFull = _pendingCoalesceForceFull;
    _pendingCoalesceForceFull = false;
    unawaited(_reloadUiFromLocalImpl(forceFull: forceFull));
  }

  /// 停滑后落地因滚动挂起的 soft reload（带 settle，防抖动连 flush）。
  void flushDeferredReloadUiAfterScroll() {
    if (!_reloadUiDeferredWhileScrolling &&
        !_uiApplyPendingAfterQuietOrScroll &&
        _pendingUiApplyById.isEmpty &&
        !_sdkSyncResumeAfterScroll &&
        _deferredViewModelPersistById.isEmpty) {
      return;
    }
    _scrollEndFlushTimer?.cancel();
    final settle = ConversationPerfFlags.uiApplyFlushSettleDelay;
    if (settle <= Duration.zero) {
      _runScrollEndFlush();
      return;
    }
    _scrollEndFlushTimer = Timer(settle, () {
      _scrollEndFlushTimer = null;
      if (_isFeedScrollingNow) {
        return;
      }
      _runScrollEndFlush();
    });
  }

  void _runScrollEndFlush() {
    if (!_reloadUiDeferredWhileScrolling &&
        !_uiApplyPendingAfterQuietOrScroll &&
        _pendingUiApplyById.isEmpty &&
        !_sdkSyncResumeAfterScroll &&
        _deferredViewModelPersistById.isEmpty) {
      return;
    }
    if (_scrollEndFlushInFlight != null) {
      _scrollEndFlushDirty = true;
      return;
    }
    final task = () async {
      try {
        do {
          _scrollEndFlushDirty = false;
          _reloadUiDeferredWhileScrolling = false;
          _reloadUiCoalesceTimer?.cancel();
          _reloadUiCoalesceTimer = null;
          final forceFull = _pendingCoalesceForceFull;
          _pendingCoalesceForceFull = false;
          final resumeSdk = _sdkSyncResumeAfterScroll;
          _sdkSyncResumeAfterScroll = false;
          await _flushDeferredViewModelPersist(reason: 'scroll_end');
          await _flushPendingUiApply(reason: 'scroll_end');
          if (forceFull) {
            await _reloadUiFromLocalImpl(forceFull: true);
          }
          if (resumeSdk) {
            unawaited(
              syncFromSdk(
                reason: 'resume_after_scroll',
                drainMode: ConversationSdkDrainMode.singlePage,
              ),
            );
          }
        } while (_scrollEndFlushDirty);
      } finally {
        _scrollEndFlushInFlight = null;
        // 收尾瞬间又脏：再开一轮。
        if (_scrollEndFlushDirty) {
          _scrollEndFlushDirty = false;
          _runScrollEndFlush();
        }
      }
    }();
    _scrollEndFlushInFlight = task;
    unawaited(task);
  }

  Future<void> _flushDeferredViewModelPersist({required String reason}) async {
    if (_deferredViewModelPersistById.isEmpty) {
      return;
    }
    final batch = _deferredViewModelPersistById.values.toList(growable: false);
    _deferredViewModelPersistById.clear();
    ConversationPerfGateLog.log(
      'view_model_persist_flush',
      extras: <String, Object?>{
        'reason': reason,
        'count': batch.length,
      },
    );
    final merged = await ConversationLocalStore.instance.upsertBatch(
      conversations: batch,
    );
    if (merged.isEmpty) {
      return;
    }
    await _applyPacedSyncPageToUi(
      merged,
      reason: 'view_model_flush_$reason',
      allowDefer: false,
    );
    // 写库后同样尝试 append，避免只 defer 不进窗。
    final notifier = ConversationListNotifier.instance;
    await notifier.appendOlderFromLocal(convType: 2);
    await notifier.appendOlderFromLocal(convType: 1);
  }

  Future<void> _reloadUiFromLocalImpl({bool forceFull = false}) async {
    if (_reloadUiInFlight != null) {
      _reloadUiDirty = true;
      _reloadUiDirtyForceFull = _reloadUiDirtyForceFull || forceFull;
      return _reloadUiInFlight!;
    }
    final task = _reloadUiFromLocalImplInner(forceFull: forceFull);
    _reloadUiInFlight = task;
    try {
      await task;
    } finally {
      _reloadUiInFlight = null;
      if (_reloadUiDirty) {
        final full = _reloadUiDirtyForceFull;
        _reloadUiDirty = false;
        _reloadUiDirtyForceFull = false;
        unawaited(_reloadUiFromLocalImpl(forceFull: full));
      }
    }
  }

  Future<void> _reloadUiFromLocalImplInner({bool forceFull = false}) async {
    if (ConversationPerfFlags.conversationListSdkPrimary) {
      ConversationPerfGateLog.log(
        'ui_source',
        extras: <String, Object?>{
          'source': 'sdk_store',
          'via': 'reload_ui_impl',
          'forceFull': forceFull,
        },
      );
      await ConversationListNotifier.instance.reloadFromLocal();
      return;
    }
    if (!forceFull) {
      await _reloadUiSoftPreserveWindow();
      return;
    }
    final notifier = ConversationListNotifier.instance;
    if (notifier.shouldBlockSnapshotWindowReloadNow) {
      _log('forceFull_blocked_preserve_window');
      await _reloadUiSoftPreserveWindow();
      return;
    }
    reloadUiImplInvocationCount++;
    if (reloadUiImplOverride != null) {
      await reloadUiImplOverride!();
      return;
    }
    await ConversationListNotifier.instance.reloadFromLocal();
    final meta = await ConversationLocalStore.instance.readSyncMeta();
    ConversationListSyncNotifier.instance.setHasSyncedOnce(meta.hasSyncedOnce);
  }

  /// 保留已扩展列表：刷新窗内全部行 + 热快照准入；不整窗覆盖裁顶。
  /// post-pop 轻量：只 patch 刚离开会话，禁止整窗 `conversationsByIds`。
  Future<void> _reloadUiSoftPreserveWindow() async {
    reloadUiImplInvocationCount++;
    if (reloadUiImplOverride != null) {
      await reloadUiImplOverride!();
      return;
    }

    final scrolling =
        ConversationListNotifier.instance.isFeedScrolling?.call() ?? false;
    if (scrolling || ConversationListNotifier.instance.isUiPageLoadInFlight) {
      // 滚动/翻页中延后 soft，避免与 append 抢主线程或错位。
      _reloadUiCoalesceTimer?.cancel();
      _reloadUiCoalesceTimer = Timer(
        const Duration(milliseconds: 250),
        _onCoalescedReloadTimerFired,
      );
      return;
    }

    final leftId = _recentlyLeftConversationId?.trim() ?? '';
    final notifier = ConversationListNotifier.instance;
    final usePostPopLight = shouldUsePostPopLightReload(
      inPostPopWindow: isInPostPopCoalesceWindow,
      postPopLightReloadEnabled:
          ConversationPerfFlags.postPopLightReloadEnabled,
    );
    if (usePostPopLight) {
      ConversationPinFlickerLog.log(
        'reload_ui_soft_post_pop_light',
        conversationID: leftId,
        extras: <String, Object?>{'windowCount': notifier.conversations.length},
      );
      if (leftId.isNotEmpty) {
        final local = await ConversationLocalStore.instance.conversationById(
          leftId,
        );
        if (local != null) {
          await notifier.applyConversationsFromStore(
            upserted: [local],
            forceAdmitIds: <String>{leftId},
          );
        } else {
          await refreshConversationItem(leftId);
        }
      }
      ConversationUnreadAggregate.instance.scheduleRefresh(
        reason: 'post_pop_light',
      );
      return;
    }

    // 无条数上限：禁止整窗 conversationsByIds；只热快照 + 刚离开会话。
    ConversationPinFlickerLog.log(
      'reload_ui_soft_hot_only',
      conversationID: leftId,
      extras: <String, Object?>{
        'windowCount': notifier.conversations.length,
        'postPop': isInPostPopCoalesceWindow,
      },
    );
    final upserted = <V2TimConversation>[
      ...await ConversationLocalStore.instance.loadUiWindow(),
    ];
    if (leftId.isNotEmpty &&
        !upserted.any(
          (c) =>
              MessageConversationId.sameConversation(c.conversationID, leftId),
        )) {
      final local = await ConversationLocalStore.instance.conversationById(
        leftId,
      );
      if (local != null) {
        upserted.add(local);
      } else {
        await refreshConversationItem(leftId);
      }
    }
    if (upserted.isNotEmpty) {
      await notifier.applyConversationsFromStore(
        upserted: upserted,
        forceAdmitIds: leftId.isEmpty ? const <String>{} : <String>{leftId},
      );
    }
    ConversationUnreadAggregate.instance.scheduleRefresh(
      reason: 'reload_ui_soft',
    );
  }

  /// paced 写库后：只把「已在窗 ∪ 热准入」推 UI；冷会话留在 DB，角标走聚合刷新。
  Future<void> _applyPacedSyncPageToUi(
    List<V2TimConversation> merged, {
    required String reason,
    bool allowDefer = true,
  }) async {
    if (merged.isEmpty) {
      return;
    }
    if (ConversationPerfFlags.conversationListSdkPrimary) {
      // Phase2：paced Sync 只 mirror，不驱动列表 UI。
      ConversationPerfGateLog.log(
        'mirror_skip_ui',
        extras: <String, Object?>{
          'via': 'paced',
          'reason': reason,
          'count': merged.length,
        },
      );
      return;
    }
    if (allowDefer && _shouldDeferPersistUiApply()) {
      final cause = _persistUiDeferCause() ?? 'unknown';
      _notePendingUiApply(merged, via: 'paced', cause: cause);
      return;
    }
    final notifier = ConversationListNotifier.instance;
    final forUi = <V2TimConversation>[];
    var anyColdOutOfWindow = false;
    for (final conversation in merged) {
      final id = conversation.conversationID.trim();
      if (id.isEmpty) {
        continue;
      }
      final inWindow = notifier.conversations.any(
        (c) => MessageConversationId.sameConversation(c.conversationID, id),
      );
      if (inWindow || notifier.shouldAdmitToUiWindow(conversation)) {
        forUi.add(conversation);
      } else {
        anyColdOutOfWindow = true;
      }
    }
    if (forUi.isNotEmpty) {
      await notifier.applyWindowPatchesIfNeeded(upserted: forUi);
    }
    if (anyColdOutOfWindow) {
      ConversationUnreadAggregate.instance.scheduleRefresh(reason: reason);
    }
  }

  Future<V2TimConversation?> applyConversationPinLocally({
    required String conversationID,
    required bool isPinned,
    V2TimConversation? snapshot,
    double? listScrollOffset,
  }) async {
    final updated =
        await ConversationLocalStore.instance.updateConversationPinnedLocally(
      conversationID: conversationID,
      isPinned: isPinned,
      snapshot: snapshot,
    );
    ConversationPinFlickerLog.log(
      'sync_pin_local_write',
      conversationID: conversationID,
      extras: <String, Object?>{
        'isPinned': isPinned,
        'updated': updated != null,
        'localPinned': updated?.isPinned,
        'listScroll': listScrollOffset?.toStringAsFixed(1) ?? 'na',
      },
    );
    if (updated != null) {
      // 先就地改底色，短停顿后重排；视口保持，不主动滚顶。
      // 若乐观阶段已对齐 pin+序，notifier 内会短路跳过二次 deferred。
      final notifier = ConversationListNotifier.instance;
      notifier.applyPinnedWithDeferredReorder(
        conversationID: conversationID,
        isPinned: isPinned,
        snapshot: updated,
        listScrollOffset: listScrollOffset,
      );
      // 写库后按需校正类型窗：center 跟视口，勿跟掉队会话；窗外才 forceReload。
      final convType =
          (updated.type == 2 || (updated.groupID?.trim().isNotEmpty == true))
              ? 2
              : 1;
      final hydrateStart = notifier.hydratedStartOffsetForType(convType);
      final hydrateLength = notifier.hydratedLengthForType(convType);
      final movedTypeIndex =
          notifier.typeIndexOfConversationId(convType, conversationID);
      final anchorId = (notifier.viewportAnchorConversationId ?? '').trim();
      final viewportAnchorTypeIndex = anchorId.isEmpty
          ? null
          : notifier.typeIndexOfConversationId(convType, anchorId);
      final hydrateMidTypeIndex =
          hydrateLength > 0 ? hydrateStart + (hydrateLength ~/ 2) : null;
      final center = resolvePinHydrateCenterIndex(
        viewportAnchorTypeIndex: viewportAnchorTypeIndex,
        hydrateMidTypeIndex: hydrateMidTypeIndex,
        fallback: 0,
      );
      final forceReload = shouldForceReloadTypeHydrateAfterPin(
        movedTypeIndex: movedTypeIndex,
        hydrateStart: hydrateStart,
        hydrateLength: hydrateLength,
      );
      ConversationPinFlickerLog.log(
        'sync_pin_hydrate_plan',
        conversationID: conversationID,
        extras: <String, Object?>{
          'convType': convType,
          'center': center,
          'forceReload': forceReload,
          'movedTypeIndex': movedTypeIndex,
          'hydrateStart': hydrateStart,
          'hydrateLength': hydrateLength,
          'viewportAnchor': anchorId.isEmpty ? null : anchorId,
        },
      );
      unawaited(
        notifier.ensureTypeIndexHydrated(
          convType: convType,
          centerIndex: center,
          forceReload: forceReload,
        ),
      );
    }
    return updated;
  }

  Future<bool> get haveMoreData async {
    final meta = await ConversationLocalStore.instance.readSyncMeta();
    return meta.c2cHaveMore || meta.groupHaveMore;
  }

  Future<bool> haveMoreDataForType(int convType) async {
    final meta = await ConversationLocalStore.instance.readSyncMeta();
    return meta.haveMoreForType(convType);
  }

  void _markAwaitingPostServerSyncIfNeeded(String reason) {
    if (reason.contains('bootstrap') || reason.contains('cold')) {
      _awaitingPostServerSync = true;
    }
  }

  void _enqueuePendingSync({
    required String reason,
    bool reset = false,
    bool force = false,
    bool loadAllPages = false,
    bool reloadUiEachPage = true,
    ConversationSdkDrainMode? drainMode,
  }) {
    final incoming = _PendingSdkSync(
      reason: reason,
      reset: reset,
      force: force,
      loadAllPages: loadAllPages,
      reloadUiEachPage: reloadUiEachPage,
      drainMode: drainMode,
    );
    final existing = _pendingSdkSync;
    _pendingSdkSync =
        existing == null ? incoming : existing.mergePreferStronger(incoming);
    _log(
      'syncFromSdk queued reason=$reason reset=$reset '
      'loadAllPages=$loadAllPages drainMode=${drainMode?.name}',
    );
  }

  /// 解析写库节奏；供单测断言 `reset` 不再隐含全量。
  @visibleForTesting
  static ConversationSdkDrainMode resolveDrainMode({
    required bool pacedSdkPersist,
    required bool reset,
    required bool force,
    required bool loadAllPages,
    ConversationSdkDrainMode? drainMode,
  }) {
    if (drainMode != null) {
      return drainMode;
    }
    if (!pacedSdkPersist) {
      // 旧行为：reset/force/loadAllPages 都视为可持续拉多页。
      if (loadAllPages || reset || force) {
        return ConversationSdkDrainMode.backgroundContinue;
      }
      return ConversationSdkDrainMode.singlePage;
    }
    if (loadAllPages) {
      return ConversationSdkDrainMode.backgroundContinue;
    }
    if (reset || force) {
      return ConversationSdkDrainMode.foregroundLimited;
    }
    return ConversationSdkDrainMode.singlePage;
  }

  /// 脏 meta：单聊游标已判死但本地 C2C 行数仍低于首屏地板 → 应重开 C2C。
  @visibleForTesting
  static bool shouldHealC2cCursor({
    required bool healEnabled,
    required bool c2cHaveMore,
    required int c2cRowCount,
    required int healFloor,
  }) {
    if (!healEnabled) {
      return false;
    }
    if (c2cHaveMore) {
      return false;
    }
    final floor = healFloor > 0 ? healFloor : 40;
    return c2cRowCount < floor;
  }

  /// 若需自愈：重开 C2C 游标并至少 ByFilter 拉一页。返回是否执行了自愈拉页。
  Future<bool> healC2cCursorIfNeeded(
      {String reason = 'c2c_cursor_heal'}) async {
    if (!ConversationPerfFlags.c2cCursorHealEnabled) {
      return false;
    }
    final owner = _ownerUserId();
    if (owner.isEmpty) {
      return false;
    }
    final meta = await ConversationLocalStore.instance.readSyncMeta();
    final c2cRows = await ConversationLocalStore.instance.countByConvType(
      convType: ConversationType.V2TIM_C2C,
      ownerUserId: owner,
    );
    if (!shouldHealC2cCursor(
      healEnabled: true,
      c2cHaveMore: meta.c2cHaveMore,
      c2cRowCount: c2cRows,
      healFloor: ConversationPerfFlags.uiSnapshotC2cLimit,
    )) {
      return false;
    }
    await ConversationLocalStore.instance.writeSyncMeta(
      meta: meta.withTypedCursor(
        convType: ConversationType.V2TIM_C2C,
        nextSeq: '0',
        haveMore: true,
        hasSyncedOnce: meta.hasSyncedOnce,
      ),
      ownerUserId: owner,
    );
    ConversationPerfGateLog.log(
      'c2c_cursor_heal',
      extras: <String, Object?>{
        'reason': reason,
        'c2cRows': c2cRows,
        'floor': ConversationPerfFlags.uiSnapshotC2cLimit,
      },
    );
    await syncFromSdkByType(
      convType: ConversationType.V2TIM_C2C,
      reason: '$reason#type=${ConversationType.V2TIM_C2C}',
      count: _typedPageCount(ConversationType.V2TIM_C2C),
      drainMode: ConversationSdkDrainMode.singlePage,
    );
    return true;
  }

  void scheduleBackgroundDrain({required String reason}) {
    scheduleIdleBackgroundDrain(reason: reason);
  }

  void scheduleIdleBackgroundDrain({required String reason, Duration? delay}) {
    if (!ConversationPerfFlags.pacedSdkPersist) {
      return;
    }
    if (!ConversationPerfFlags.idleBackgroundDrainEnabled) {
      _idleDrainTimer?.cancel();
      _idleDrainTimer = null;
      ConversationListSyncNotifier.instance.setDraining(false);
      _log('idle_drain skipped (disabled) reason=$reason');
      return;
    }
    _idleDrainTimer?.cancel();
    ConversationListSyncNotifier.instance.setDraining(true);
    final wait = delay ?? ConversationPerfFlags.idleDrainStartDelay;
    _log('idle_drain scheduled reason=$reason delayMs=${wait.inMilliseconds}');
    _idleDrainTimer = Timer(wait, () {
      _idleDrainTimer = null;
      unawaited(_runIdleBackgroundDrain(reason: reason));
    });
  }

  void scheduleHistoryWarmWhenIdle({required String reason}) {
    _historyWarmTimer?.cancel();
    final now = DateTime.now();
    final quietUntil = _resumeQuietUntil;
    var delay = ConversationPerfFlags.historyWarmAfterHomeDelay;
    if (quietUntil != null && quietUntil.isAfter(now)) {
      final quietDelay = quietUntil.difference(now);
      if (quietDelay > delay) {
        delay = quietDelay;
      }
      if (ConversationPerfFlags.resumeQuietBlocksHeavyUiReload) {
        ConversationPerfGateLog.log(
          'resume_quiet_block',
          extras: <String, Object?>{'what': 'history_warm'},
        );
      }
    }
    _historyWarmTimer = Timer(
      delay,
      () {
        _historyWarmTimer = null;
        if (_shouldPauseIdleWork()) {
          scheduleHistoryWarmWhenIdle(reason: reason);
          return;
        }
        ConversationHistoryWarmScheduler.instance.scheduleAfterConversationSync(
          reason: reason,
        );
      },
    );
  }

  void beginResumeQuietWindow({Duration? duration}) {
    final flagHold = ConversationPerfFlags.resumeQuietDuration;
    final hold = duration ??
        (flagHold > Duration.zero
            ? flagHold
            : ResumeForegroundPolicy.conversationHoldDuration);
    if (hold <= Duration.zero) {
      return;
    }
    final until = DateTime.now().add(hold);
    final current = _resumeQuietUntil;
    if (current == null || until.isAfter(current)) {
      _resumeQuietUntil = until;
    }
    ConversationPerfGateLog.log(
      'resume_quiet_enter',
      extras: <String, Object?>{
        'durationMs': hold.inMilliseconds,
      },
    );
    _resumeQuietExitTimer?.cancel();
    final exitAt = _resumeQuietUntil!;
    _resumeQuietExitTimer = Timer(exitAt.difference(DateTime.now()), () {
      _resumeQuietExitTimer = null;
      ConversationPerfGateLog.log('resume_quiet_exit');
      if (!_isFeedScrollingNow) {
        unawaited(_flushPendingUiApply(reason: 'quiet_end'));
      }
    });
  }

  @visibleForTesting
  static bool shouldFullResetOnServerFinish({
    required bool hasSyncedOnce,
    required int rowCount,
  }) {
    return !hasSyncedOnce || rowCount == 0;
  }

  /// 登录冷启是否尝试 IM Snapshot（方案 B：有库也暖；失败再降级腾讯分页）。
  /// [rowCount] 保留参数兼容旧调用，不再作为门闩。
  static bool shouldUseImSnapshotBootstrap({required int rowCount}) {
    return shouldAttemptImSnapshotOnLoginBootstrap();
  }

  /// 登录会话 bootstrap 是否尝试 Snapshot。
  /// 由 [ConversationPerfFlags.attemptImSnapshotOnLoginBootstrap] 控制；
  /// 关闭后首屏只依赖本地库 + SDK paced sync。
  static bool shouldAttemptImSnapshotOnLoginBootstrap() =>
      ConversationPerfFlags.attemptImSnapshotOnLoginBootstrap;

  @visibleForTesting
  static bool shouldPauseIdleDrain({
    required bool isScrolling,
    required bool inChatTransition,
  }) {
    return isScrolling || inChatTransition;
  }

  @visibleForTesting
  static bool shouldSkipPostHomeConversationReset({
    required bool conversationListBootstrapDone,
  }) {
    return conversationListBootstrapDone;
  }

  /// 治愈脏 meta：游标显示还有下一页，但 haveMore 被误写成 false。
  @visibleForTesting
  static bool shouldHealHaveMoreFromNextSeq({
    required bool haveMore,
    required String nextSeq,
  }) {
    if (haveMore) {
      return false;
    }
    final seq = nextSeq.trim();
    return seq.isNotEmpty && seq != '0';
  }

  /// 单页拉取后重算 haveMore（防 IM 未就绪空页把 flag 永久毒死）。
  @visibleForTesting
  static bool resolveHaveMoreAfterPage({
    required bool haveMoreBeforePage,
    required int pageLength,
    required int pagesLoadedBeforeThisPage,
    required String nextSeq,
    String requestedNextSeq = '0',
    bool? isFinished,
  }) {
    // Tencent SDK 的 isFinished 是分页是否结束的权威标记。部分版本在
    // isFinished=true 时仍会回传上一页 nextSeq，不能再据此继续翻页。
    if (isFinished == true) {
      return false;
    }
    final normalizedNextSeq = nextSeq.trim();
    if (normalizedNextSeq.isNotEmpty && normalizedNextSeq != '0') {
      return true;
    }
    if (pageLength > 0) {
      return false;
    }
    if (pagesLoadedBeforeThisPage > 0) {
      return false;
    }
    final requested = requestedNextSeq.trim();
    if (requested.isNotEmpty && requested != '0') {
      return false;
    }
    return haveMoreBeforePage;
  }

  bool _shouldPauseIdleWork() {
    final scrolling = ConversationListNotifier.instance.isFeedScrolling;
    return shouldPauseIdleDrain(
      isScrolling: scrolling != null && scrolling(),
      inChatTransition: hasActiveChatTransition,
    );
  }

  Future<void> _runIdleBackgroundDrain({required String reason}) async {
    if (!ConversationPerfFlags.pacedSdkPersist ||
        !ConversationPerfFlags.idleBackgroundDrainEnabled) {
      ConversationListSyncNotifier.instance.setDraining(false);
      return;
    }
    if (_backgroundDrainInFlight) {
      return;
    }
    if (_shouldPauseIdleWork()) {
      _log('idle_drain pause reason=$reason');
      scheduleIdleBackgroundDrain(reason: '${reason}_paused');
      return;
    }
    _backgroundDrainInFlight = true;
    ConversationListSyncNotifier.instance.setDraining(true);
    _log('idle_drain start reason=$reason');
    try {
      while (true) {
        if (_shouldPauseIdleWork()) {
          _log('idle_drain pause mid reason=$reason');
          break;
        }
        if (!shouldScheduleIdleDrainResume(
          idleBackgroundDrainEnabled:
              ConversationPerfFlags.idleBackgroundDrainEnabled,
          haveMore: true,
          sessionDrainPages: _idleDrainSessionPages,
          sessionDrainPageBudget:
              ConversationPerfFlags.idleDrainSessionPageBudget,
        )) {
          _log('idle_drain budget exhausted pages=$_idleDrainSessionPages');
          break;
        }
        final meta = await ConversationLocalStore.instance.readSyncMeta();
        if (!meta.c2cHaveMore && !meta.groupHaveMore) {
          break;
        }
        if (_pageSyncInFlight) {
          _enqueuePendingSync(
            reason: '${reason}_drain',
            drainMode: ConversationSdkDrainMode.backgroundContinue,
            reloadUiEachPage: false,
          );
          _log('idle_drain yielded to in-flight sync');
          return;
        }
        await syncFromSdk(
          reason: '${reason}_drain',
          // 外层负责预算、yield 与 resume；内层严格只拉一页，否则一次调用
          // 会绕过 idleDrainSessionPageBudget 直接排空整个账号。
          drainMode: ConversationSdkDrainMode.singlePage,
          reloadUiEachPage: false,
        );
        _idleDrainSessionPages++;
        final after = await ConversationLocalStore.instance.readSyncMeta();
        if (!after.c2cHaveMore && !after.groupHaveMore) {
          break;
        }
        break;
      }
    } finally {
      _backgroundDrainInFlight = false;
      final meta = await ConversationLocalStore.instance.readSyncMeta();
      final stillHaveMore = meta.c2cHaveMore || meta.groupHaveMore;
      final canResume = stillHaveMore &&
          _pendingSdkSync == null &&
          !_pageSyncInFlight &&
          shouldScheduleIdleDrainResume(
            idleBackgroundDrainEnabled:
                ConversationPerfFlags.idleBackgroundDrainEnabled,
            haveMore: stillHaveMore,
            sessionDrainPages: _idleDrainSessionPages,
            sessionDrainPageBudget:
                ConversationPerfFlags.idleDrainSessionPageBudget,
          );
      ConversationListSyncNotifier.instance.setDraining(canResume);
      if (canResume) {
        scheduleIdleBackgroundDrain(reason: '${reason}_resume');
      }
      _log(
        'idle_drain done haveMore=$stillHaveMore canResume=$canResume '
        'reason=$reason',
      );
    }
  }

  int _typedPageCount(int convType) {
    if (convType == ConversationType.V2TIM_GROUP) {
      final n = ConversationPerfFlags.uiSnapshotGroupLimit;
      return n > 0 ? n : _defaultPageSize;
    }
    final n = ConversationPerfFlags.uiSnapshotC2cLimit;
    return n > 0 ? n : _defaultPageSize;
  }

  /// 首次登录 / 冷启：单聊+群聊各拉一页 ByFilter，写库并热窗上屏。
  Future<void> bootstrapTypedFirstScreen({
    String reason = 'typed_bootstrap',
    bool reset = true,
  }) async {
    final owner = _ownerUserId();
    final generation = _syncGeneration;
    if (owner.isEmpty) {
      return;
    }
    _markAwaitingPostServerSyncIfNeeded(reason);
    if (_pageSyncInFlight) {
      _enqueuePendingSync(
        reason: reason,
        reset: reset,
        drainMode: ConversationSdkDrainMode.singlePage,
        reloadUiEachPage: false,
      );
      return;
    }
    _pageSyncInFlight = true;
    ConversationListSyncNotifier.instance.setSyncing(true);
    try {
      _log(
        'bootstrapTypedFirstScreen reason=$reason reset=$reset',
      );
      if (reset) {
        final prev = await ConversationLocalStore.instance.readSyncMeta();
        await ConversationLocalStore.instance.writeSyncMeta(
          meta: ConversationSyncMeta(
            nextSeq: '0',
            haveMore: true,
            hasSyncedOnce: prev.hasSyncedOnce,
            c2cNextSeq: '0',
            c2cHaveMore: true,
            groupNextSeq: '0',
            groupHaveMore: true,
          ),
          ownerUserId: owner,
        );
      }
      ConversationListNotifier.instance.beginSuppressNotify();
      try {
        await _pullOneTypedPageUnlocked(
          owner: owner,
          generation: generation,
          convType: ConversationType.V2TIM_C2C,
          count: _typedPageCount(ConversationType.V2TIM_C2C),
          reason: '$reason:c2c',
        );
        await _pullOneTypedPageUnlocked(
          owner: owner,
          generation: generation,
          convType: ConversationType.V2TIM_GROUP,
          count: _typedPageCount(ConversationType.V2TIM_GROUP),
          reason: '$reason:group',
        );
      } finally {
        ConversationListNotifier.instance.endSuppressNotify();
      }
      await reloadUiFromLocal(immediate: true, forceFull: true);
      ConversationListSyncNotifier.instance.setHasSyncedOnce(true);
    } catch (e, st) {
      _log('bootstrapTypedFirstScreen failed: $e');
      if (kIsWeb) {
        debugPrint('ConversationSync: bootstrapTyped stack: $st');
      }
    } finally {
      _pageSyncInFlight = false;
      ConversationListSyncNotifier.instance.setSyncing(false);
      await _replayPendingPatches();
      final pending = _pendingSdkSync;
      if (pending != null) {
        _pendingSdkSync = null;
        unawaited(
          syncFromSdk(
            reason: pending.reason,
            reset: pending.reset,
            force: pending.force,
            loadAllPages: pending.loadAllPages,
            reloadUiEachPage: pending.reloadUiEachPage,
            drainMode: pending.drainMode,
          ),
        );
      }
    }
  }

  /// 按会话类型 ByFilter 拉页写库（两路游标之一）。
  Future<void> syncFromSdkByType({
    required int convType,
    String reason = 'typed_page',
    bool reset = false,
    bool force = false,
    int? count,
    ConversationSdkDrainMode drainMode = ConversationSdkDrainMode.singlePage,
  }) async {
    final type = convType == ConversationType.V2TIM_GROUP
        ? ConversationType.V2TIM_GROUP
        : ConversationType.V2TIM_C2C;
    final owner = _ownerUserId();
    final generation = _syncGeneration;
    if (owner.isEmpty) {
      return;
    }
    final pageCount = count ?? _typedPageCount(type);
    final mode = (!ConversationPerfFlags.idleBackgroundDrainEnabled &&
            drainMode == ConversationSdkDrainMode.backgroundContinue)
        ? ConversationSdkDrainMode.singlePage
        : drainMode;
    if (_pageSyncInFlight) {
      _enqueuePendingSync(
        reason: '$reason#type=$type',
        reset: reset,
        force: force,
        drainMode: mode,
        reloadUiEachPage: false,
      );
      return;
    }
    _pageSyncInFlight = true;
    ConversationListSyncNotifier.instance.setSyncing(true);
    try {
      if (reset || force) {
        final prev = await ConversationLocalStore.instance.readSyncMeta();
        await ConversationLocalStore.instance.writeSyncMeta(
          meta: prev.withTypedCursor(
            convType: type,
            nextSeq: '0',
            haveMore: true,
          ),
          ownerUserId: owner,
        );
      }
      var pagesLoaded = 0;
      ConversationListNotifier.instance.beginSuppressNotify();
      try {
        while (true) {
          final pulled = await _pullOneTypedPageUnlocked(
            owner: owner,
            generation: generation,
            convType: type,
            count: pageCount,
            reason: reason,
          );
          if (pulled) {
            pagesLoaded++;
          }
          final meta = await ConversationLocalStore.instance.readSyncMeta();
          final haveMore = meta.haveMoreForType(type);
          var shouldContinue = false;
          if (!haveMore) {
            shouldContinue = false;
          } else if (mode == ConversationSdkDrainMode.singlePage) {
            shouldContinue = false;
          } else if (mode == ConversationSdkDrainMode.foregroundLimited) {
            shouldContinue =
                pagesLoaded < ConversationPerfFlags.bootstrapForegroundPages;
          } else {
            await Future<void>.delayed(
              ConversationPerfFlags.backgroundPageYield,
            );
            shouldContinue = _pendingSdkSync == null && !_shouldPauseIdleWork();
          }
          if (!shouldContinue) {
            break;
          }
        }
      } finally {
        ConversationListNotifier.instance.endSuppressNotify();
      }
    } catch (e, st) {
      _log('syncFromSdkByType failed type=$type: $e');
      if (kIsWeb) {
        debugPrint('ConversationSync: typed sync stack: $st');
      }
    } finally {
      _pageSyncInFlight = false;
      ConversationListSyncNotifier.instance.setSyncing(false);
      await _replayPendingPatches();
      final pending = _pendingSdkSync;
      if (pending != null) {
        _pendingSdkSync = null;
        unawaited(
          syncFromSdk(
            reason: pending.reason,
            reset: pending.reset,
            force: pending.force,
            loadAllPages: pending.loadAllPages,
            reloadUiEachPage: pending.reloadUiEachPage,
            drainMode: pending.drainMode,
          ),
        );
      }
    }
  }

  Future<void> _syncFromSdkTypedRedirect({
    required String reason,
    required bool reset,
    required bool force,
    required int count,
    ConversationSdkDrainMode? drainMode,
  }) async {
    final r = reason.trim();
    final wantsReset = reset || force;
    final coldBootstrap = wantsReset ||
        r.contains('bootstrap') ||
        r.contains('sync_server_finish_cold') ||
        r == 'initial' ||
        r.startsWith('initial');

    if (r.contains('#type=')) {
      final type = r.contains('type=2')
          ? ConversationType.V2TIM_GROUP
          : ConversationType.V2TIM_C2C;
      await syncFromSdkByType(
        convType: type,
        reason: r,
        reset: reset,
        force: force,
        count: count,
        drainMode: drainMode ?? ConversationSdkDrainMode.singlePage,
      );
      return;
    }

    if (coldBootstrap) {
      final meta = await ConversationLocalStore.instance.readSyncMeta();
      final rowCount = await ConversationLocalStore.instance.countRows();
      final doReset = wantsReset || !(meta.hasSyncedOnce && rowCount > 0);
      await bootstrapTypedFirstScreen(reason: reason, reset: doReset);
      return;
    }

    final mode = drainMode ?? ConversationSdkDrainMode.singlePage;
    final pages = mode == ConversationSdkDrainMode.foregroundLimited
        ? ConversationPerfFlags.bootstrapForegroundPages
        : 1;
    for (final type in <int>[
      ConversationType.V2TIM_C2C,
      ConversationType.V2TIM_GROUP,
    ]) {
      for (var i = 0; i < pages; i++) {
        final meta = await ConversationLocalStore.instance.readSyncMeta();
        if (!meta.haveMoreForType(type)) {
          break;
        }
        await syncFromSdkByType(
          convType: type,
          reason: '$reason:type=$type',
          count: count > 0 ? count : _typedPageCount(type),
          drainMode: ConversationSdkDrainMode.singlePage,
        );
      }
    }
  }

  /// 拉一页并更新该类型游标。调用方须已持有 [_pageSyncInFlight]。
  /// 返回是否写入了会话。
  Future<bool> _pullOneTypedPageUnlocked({
    required String owner,
    required int generation,
    required int convType,
    required int count,
    required String reason,
  }) async {
    if (!_isCurrentSync(owner, generation)) {
      return false;
    }
    final meta = await ConversationLocalStore.instance.readSyncMeta(
      ownerUserId: owner,
    );
    if (!meta.haveMoreForType(convType)) {
      return false;
    }
    final requestedNextSeq = meta.nextSeqForType(convType);
    final fetched = await _fetchConversationListByFilter(
      convType: convType,
      nextSeq: requestedNextSeq,
      count: count,
    );
    if (!_isCurrentSync(owner, generation)) {
      return false;
    }
    if (fetched.code != 0) {
      _log(
        'ByFilter fail type=$convType code=${fetched.code} '
        'desc=${fetched.desc} reason=$reason',
      );
      return false;
    }
    final page = fetched.conversationList;
    final nextSeq = fetched.nextSeq;
    final haveMore = resolveHaveMoreAfterPage(
      haveMoreBeforePage: meta.haveMoreForType(convType),
      pageLength: page.length,
      pagesLoadedBeforeThisPage: 0,
      nextSeq: nextSeq,
      requestedNextSeq: requestedNextSeq,
      isFinished: fetched.isFinished,
    );
    var loadedAny = false;
    if (page.isNotEmpty) {
      final persistable = _filterPersistableConversations(page);
      if (persistable.isNotEmpty) {
        loadedAny = true;
        final merged = upsertBatchOverride != null
            ? await upsertBatchOverride!(persistable)
            : await ConversationLocalStore.instance.upsertBatch(
                conversations: persistable,
                ownerUserId: owner,
              );
        if (!_isCurrentSync(owner, generation)) {
          return false;
        }
        await _purgeObsoleteGroupConversationTwins(
          reason: 'typedSync:$reason',
          upsertObsoleteIds: await _collectObsoleteGroupTwinIds(
            extraIds: persistable.map((c) => c.conversationID),
          ),
        );
        if (ConversationPerfFlags.pacedSdkPersist) {
          await _applyPacedSyncPageToUi(
            merged,
            reason: 'typed_sync_db_only',
          );
        }
      }
      unawaited(_purgeRejectedGroupConversations(page));
    }
    if (!_isCurrentSync(owner, generation)) {
      return false;
    }
    final latest = await ConversationLocalStore.instance.readSyncMeta(
      ownerUserId: owner,
    );
    await ConversationLocalStore.instance.writeSyncMeta(
      meta: latest
          .withTypedCursor(
            convType: convType,
            nextSeq: nextSeq.isEmpty ? '0' : nextSeq,
            haveMore: haveMore,
            hasSyncedOnce: loadedAny || latest.hasSyncedOnce,
          )
          .copyWith(
            // 兼容列：聚合 haveMore；混流 nextSeq 不再推进。
            haveMore: null,
          ),
      ownerUserId: owner,
    );
    if (_isCurrentSync(owner, generation) &&
        (loadedAny || latest.hasSyncedOnce)) {
      ConversationListSyncNotifier.instance.setHasSyncedOnce(true);
    }
    _log(
      'ByFilter page type=$convType loaded=$loadedAny '
      'count=${page.length} haveMore=$haveMore nextSeq=$nextSeq '
      'reason=$reason',
    );
    if (convType == ConversationType.V2TIM_C2C &&
        page.isEmpty &&
        fetched.isFinished == true &&
        !loadedAny) {
      unawaited(
        maybeBackfillC2cFromHistoryPeers(reason: 'typed_c2c_empty:$reason'),
      );
    }
    return loadedAny;
  }

  bool _isCurrentSync(String owner, int generation) {
    return generation == _syncGeneration && _ownerUserId() == owner;
  }

  @visibleForTesting
  static bool isSyncResultCurrent({
    required String startedOwner,
    required int startedGeneration,
    required String currentOwner,
    required int currentGeneration,
  }) {
    return startedOwner.isNotEmpty &&
        startedOwner == currentOwner &&
        startedGeneration == currentGeneration;
  }

  Future<
      ({
        List<V2TimConversation> conversationList,
        String nextSeq,
        bool isFinished,
        int code,
        String desc,
      })> _fetchConversationListByFilter({
    required int convType,
    required String nextSeq,
    required int count,
  }) async {
    final override = debugGetConversationListByFilterOverride;
    if (override != null) {
      return override(
        convType: convType,
        nextSeq: nextSeq,
        count: count,
      );
    }
    final seqInt = int.tryParse(nextSeq.trim()) ?? 0;
    final res = await TencentImSDKPlugin.v2TIMManager
        .getConversationManager()
        .getConversationListByFilter(
          filter: V2TimConversationFilter(conversationType: convType),
          nextSeq: seqInt,
          count: count,
        );
    final data = res.data;
    final list = <V2TimConversation>[];
    for (final item in data?.conversationList ?? const <V2TimConversation?>[]) {
      if (item != null) {
        list.add(item);
      }
    }
    return (
      conversationList: list,
      nextSeq: data?.nextSeq?.toString() ?? '0',
      isFinished: data?.isFinished == true,
      code: res.code,
      desc: res.desc,
    );
  }

  Future<void> syncFromSdk({
    String reason = 'manual',
    bool reset = false,
    bool force = false,
    int count = _defaultPageSize,
    bool loadAllPages = false,
    bool reloadUiEachPage = false,
    ConversationSdkDrainMode? drainMode,
  }) async {
    // 业务灌库只走 ByFilter typed；混流 getConversationList 已退役。
    await _syncFromSdkTypedRedirect(
      reason: reason,
      reset: reset,
      force: force,
      count: count,
      drainMode: drainMode,
    );
  }

  Future<void> syncNextPage({
    int count = _defaultPageSize,
    int? convType,
  }) async {
    final owner = _ownerUserId();
    if (owner.isEmpty || _pageSyncInFlight) {
      return;
    }
    final type = convType == ConversationType.V2TIM_GROUP
        ? ConversationType.V2TIM_GROUP
        : ConversationType.V2TIM_C2C;
    final meta = await ConversationLocalStore.instance.readSyncMeta();
    if (!meta.haveMoreForType(type)) {
      return;
    }
    await syncFromSdkByType(
      convType: type,
      reason: 'sync_next_page#type=$type',
      count: count > 0 ? count : _typedPageCount(type),
      drainMode: ConversationSdkDrainMode.singlePage,
    );
  }

  /// ByFilter 单聊空 / 同步完成后：把「有过记录」的 C2C 补进本地库。
  Future<C2cHistoryBackfillStats> maybeBackfillC2cFromHistoryPeers({
    String reason = 'manual',
  }) async {
    if (!ConversationPerfFlags.c2cHistoryBackfillEnabled) {
      return const C2cHistoryBackfillStats();
    }
    final inFlight = _c2cHistoryBackfillInFlight;
    if (inFlight != null) {
      await inFlight;
      return const C2cHistoryBackfillStats(skipped: 1);
    }
    final task = _runC2cHistoryBackfill(reason: reason);
    _c2cHistoryBackfillInFlight = task;
    try {
      return await task;
    } finally {
      if (identical(_c2cHistoryBackfillInFlight, task)) {
        _c2cHistoryBackfillInFlight = null;
      }
    }
  }

  Future<C2cHistoryBackfillStats> _runC2cHistoryBackfill({
    required String reason,
  }) async {
    final owner = _ownerUserId();
    if (owner.isEmpty) {
      return const C2cHistoryBackfillStats();
    }
    final localC2c = await ConversationLocalStore.instance.countByConvType(
      convType: 1,
      ownerUserId: owner,
    );
    final floor = ConversationPerfFlags.c2cHistoryBackfillFriendScanBelow;

    // 已有壳：本登录先富化一次元数据（不替代好友扫）。
    if (localC2c > 0 && !_c2cMetadataEnrichDone) {
      final localRows = await ConversationLocalStore.instance.loadConvTypePage(
        convType: 1,
        offset: 0,
        limit: ConversationPerfFlags.c2cHistoryBackfillMaxPeers,
        ownerUserId: owner,
      );
      final enrichCandidates = <String>[
        for (final row in localRows)
          if (row.conversationID.trim().startsWith('c2c_'))
            row.conversationID.trim(),
      ];
      if (enrichCandidates.isNotEmpty) {
        await _admitC2cBackfillCandidates(
          owner: owner,
          reason: '$reason:enrich_existing',
          candidates: enrichCandidates,
        );
      }
      _c2cMetadataEnrichDone = true;
    }

    final needFriendScan = C2cHistoryBackfill.shouldRunFriendScan(
      localC2c: localC2c,
      floor: floor,
      friendScanDone: _c2cFriendScanDone,
    );
    if (!needFriendScan) {
      ConversationPerfGateLog.log(
        'c2c_history_backfill',
        extras: <String, Object?>{
          'reason': reason,
          'skipped': _c2cFriendScanDone
              ? 'friend_scan_done'
              : 'friend_scan_not_needed',
          'c2c': localC2c,
          'floor': floor,
          'friendScan': false,
        },
      );
      return const C2cHistoryBackfillStats(skipped: 1);
    }

    final friendUserIds = await _collectFriendUserIdsForBackfill(owner);
    final pinned = ConversationPinSyncService.instance.pinnedConversationIds;
    final existingIds = <String>{};
    if (localC2c > 0) {
      final loadLimit =
          localC2c > ConversationPerfFlags.c2cHistoryBackfillMaxPeers
              ? localC2c
              : ConversationPerfFlags.c2cHistoryBackfillMaxPeers;
      final existingRows =
          await ConversationLocalStore.instance.loadConvTypePage(
        convType: 1,
        offset: 0,
        limit: loadLimit,
        ownerUserId: owner,
      );
      for (final row in existingRows) {
        final id = row.conversationID.trim();
        if (id.startsWith('c2c_')) {
          existingIds.add(id);
        }
      }
    }

    final candidates = C2cHistoryBackfill.selectCandidateConversationIds(
      friendUserIds: friendUserIds,
      pinnedConversationIds: pinned,
      existingLocalIds: existingIds,
      maxPeers: ConversationPerfFlags.c2cHistoryBackfillMaxPeers,
      includeFriends: ConversationPerfFlags.c2cHistoryBackfillIncludeFriends,
      includePinned: ConversationPerfFlags.c2cHistoryBackfillIncludePinned,
    );

    if (candidates.isEmpty) {
      ConversationPerfGateLog.log(
        'c2c_history_backfill',
        extras: <String, Object?>{
          'reason': reason,
          'candidates': 0,
          'applied': 0,
          'friends': friendUserIds.length,
          'c2c': localC2c,
          'floor': floor,
          'friendScan': true,
          'existing': existingIds.length,
        },
      );
      // 好友尚未就绪：本登录只再排一次延迟补拉（不立刻标 done，以便 retry）。
      if (!_c2cHistoryBackfillScheduled && friendUserIds.isEmpty) {
        _c2cHistoryBackfillScheduled = true;
        Future<void>.delayed(const Duration(seconds: 2), () {
          unawaited(
            maybeBackfillC2cFromHistoryPeers(reason: '$reason:friends_retry'),
          );
        });
        return const C2cHistoryBackfillStats();
      }
      _c2cFriendScanDone = true;
      return const C2cHistoryBackfillStats();
    }

    final stats = await _admitC2cBackfillCandidates(
      owner: owner,
      reason: '$reason:friend_scan',
      candidates: candidates,
    );
    _c2cFriendScanDone = true;
    ConversationPerfGateLog.log(
      'c2c_history_backfill',
      extras: <String, Object?>{
        'reason': '$reason:friend_scan_summary',
        'candidates': stats.candidates,
        'applied': stats.applied,
        'friends': friendUserIds.length,
        'c2c': localC2c,
        'floor': floor,
        'friendScan': true,
        'existing': existingIds.length,
        'sdkHit': stats.sdkHit,
        'historyHit': stats.historyHit,
      },
    );
    return stats;
  }

  Future<C2cHistoryBackfillStats> _admitC2cBackfillCandidates({
    required String owner,
    required String reason,
    required List<String> candidates,
  }) async {
    var sdkHit = 0;
    var historyHit = 0;
    var previewEnriched = 0;
    var skipped = 0;
    var droppedNoHistory = 0;
    final admit = <V2TimConversation>[];
    MessageService? messageService;
    try {
      messageService = serviceLocator<MessageService>();
    } catch (_) {
      messageService = null;
    }

    Future<List<V2TimMessage>> peekHistory(String peer) async {
      if (messageService == null || peer.isEmpty) {
        return const [];
      }
      var history = await messageService.getHistoryMessageList(
        getType: HistoryMsgGetTypeEnum.V2TIM_GET_CLOUD_OLDER_MSG,
        userID: peer,
        count: 1,
      );
      if (history.isEmpty) {
        history = await messageService.getHistoryMessageList(
          getType: HistoryMsgGetTypeEnum.V2TIM_GET_LOCAL_OLDER_MSG,
          userID: peer,
          count: 1,
        );
      }
      return history;
    }

    for (final conversationId in candidates) {
      try {
        final peer = ChatIdFormat.rawUserUid(
          conversationId.startsWith('c2c_')
              ? conversationId.substring(4)
              : conversationId,
        );
        final sdk = await _conversationService.getConversation(
          conversationID: conversationId,
        );
        V2TimConversation? row;
        if (C2cHistoryBackfill.shouldAdmitSdkConversation(sdk)) {
          sdkHit++;
          row = sdk;
          if (C2cHistoryBackfill.needsLastMessageEnrichment(row)) {
            final history = await peekHistory(peer);
            if (history.isNotEmpty) {
              row!.lastMessage = history.first;
              final ts = history.first.timestamp ?? 0;
              if (ts > 0) {
                row.orderkey = ts;
              }
              previewEnriched++;
              historyHit++;
            }
          }
        } else if (!ConversationPerfFlags.c2cHistoryBackfillRequireHistory) {
          row = C2cHistoryBackfill.buildShellFromHistory(
            conversationId: conversationId,
            lastMessage: null,
            hasHistory: false,
            requireHistory: false,
          );
          if (row != null) {
            historyHit++;
          }
        } else {
          final history = await peekHistory(peer);
          row = C2cHistoryBackfill.buildShellFromHistory(
            conversationId: conversationId,
            lastMessage: history.isEmpty ? null : history.first,
            hasHistory: history.isNotEmpty,
            requireHistory: true,
          );
          if (row != null) {
            historyHit++;
            previewEnriched++;
          }
        }
        if (row == null) {
          skipped++;
          continue;
        }
        final isPinned = ConversationPinSyncService.instance
            .isPinnedConversationId(conversationId);
        if (!C2cHistoryBackfill.shouldPersistBackfillRow(
          row: row,
          requireHistory:
              ConversationPerfFlags.c2cHistoryBackfillRequireHistory,
          isPinned: isPinned,
        )) {
          droppedNoHistory++;
          skipped++;
          continue;
        }
        C2cHistoryBackfill.applyPinnedFlag(row, isPinned: isPinned);
        admit.add(row);
      } catch (e) {
        skipped++;
        _log('c2c_history_backfill peer failed id=$conversationId err=$e');
      }
    }

    // 批量拉免打扰，避免 SDK 空壳 recvOpt=0 盖掉真实免打扰。
    if (admit.isNotEmpty) {
      final userIds = <String>[
        for (final c in admit)
          if ((c.userID?.trim().isNotEmpty ?? false)) c.userID!.trim(),
      ];
      final recvByUser = await _fetchC2cRecvOptsForBackfill(userIds);
      for (final c in admit) {
        final uid = c.userID?.trim() ?? '';
        if (uid.isEmpty) {
          continue;
        }
        C2cHistoryBackfill.applyRecvOpt(c, recvOpt: recvByUser[uid]);
      }
    }

    if (admit.isNotEmpty) {
      final merged = upsertBatchOverride != null
          ? await upsertBatchOverride!(admit)
          : await ConversationLocalStore.instance.upsertBatch(
              conversations: admit,
              ownerUserId: owner,
            );
      // 再刷一遍置顶列，保证 ORDER BY is_pinned 与 PinSync 一致。
      await ConversationLocalStore.instance.replaceAllPinnedFlags(
        pinnedConversationIds:
            ConversationPinSyncService.instance.pinnedConversationIds,
        ownerUserId: owner,
      );
      await _notifyUiAfterLocalWrite(upserted: merged);
      await ConversationListNotifier.instance.refreshTypeTotals();
      for (final c in merged) {
        final opt = c.recvOpt;
        if (opt == null) {
          continue;
        }
        ConversationListNotifier.instance.applyRecvOptLocally(
          conversationID: c.conversationID,
          recvOpt: opt,
        );
      }
    }

    final stats = C2cHistoryBackfillStats(
      candidates: candidates.length,
      sdkHit: sdkHit,
      historyHit: historyHit,
      applied: admit.length,
      skipped: skipped,
    );
    ConversationPerfGateLog.log(
      'c2c_history_backfill',
      extras: <String, Object?>{
        'reason': reason,
        'candidates': stats.candidates,
        'sdkHit': stats.sdkHit,
        'historyHit': stats.historyHit,
        'previewEnriched': previewEnriched,
        'droppedNoHistory': droppedNoHistory,
        'applied': stats.applied,
        'skipped': stats.skipped,
      },
    );
    _log(
      'c2c_history_backfill reason=$reason candidates=${stats.candidates} '
      'sdk=${stats.sdkHit} hist=${stats.historyHit} '
      'preview=$previewEnriched dropped=$droppedNoHistory '
      'applied=${stats.applied}',
    );
    return stats;
  }

  Future<Map<String, int?>> _fetchC2cRecvOptsForBackfill(
    List<String> userIds,
  ) async {
    final out = <String, int?>{};
    if (userIds.isEmpty) {
      return out;
    }
    try {
      final res = await TencentImSDKPlugin.v2TIMManager
          .getMessageManager()
          .getC2CReceiveMessageOpt(userIDList: userIds);
      if (res.code != 0) {
        _log('c2c_history_backfill recvOpt fail code=${res.code}');
        return out;
      }
      for (final info in res.data ?? const []) {
        final userId = info.userID?.trim() ?? '';
        if (userId.isEmpty) {
          continue;
        }
        out[userId] = info.c2CReceiveMessageOpt;
      }
    } catch (e) {
      _log('c2c_history_backfill recvOpt error: $e');
    }
    return out;
  }

  Future<List<String>> _collectFriendUserIdsForBackfill(String owner) async {
    final ids = <String>{};
    try {
      final records =
          await FriendLocalStore.instance.readAll(ownerUserId: owner);
      for (final r in records) {
        final id = ChatIdFormat.rawUserUid(r.friendUserId);
        if (id.isNotEmpty) {
          ids.add(id);
        }
      }
    } catch (_) {}
    try {
      final friends =
          serviceLocator<TUIFriendShipViewModel>().friendList ?? const [];
      for (final f in friends) {
        final id = ChatIdFormat.rawUserUid(f.userID);
        if (id.isNotEmpty) {
          ids.add(id);
        }
      }
    } catch (_) {}
    return ids.toList(growable: false);
  }

  /// 通过好友后立刻在会话列表露出 C2C 行（不依赖 IM 已建会话 / 已发 tip）。
  Future<void> ensureC2cConversationVisible({
    required String userId,
    String? nickname,
    String? avatarUrl,
  }) async {
    final id = ChatIdFormat.rawUserUid(userId);
    if (id.isEmpty) {
      return;
    }
    final convId = 'c2c_$id';
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    V2TimConversation? conversation;
    try {
      conversation = await _conversationService.getConversation(
        conversationID: convId,
      );
    } catch (_) {}
    conversation ??=
        await ConversationLocalStore.instance.conversationById(convId);

    final storeName = DisplayNameStore.instance.c2c(id)?.trim() ?? '';
    final showName = (nickname?.trim().isNotEmpty == true)
        ? nickname!.trim()
        : (storeName.isNotEmpty ? storeName : id);
    final face = avatarUrl?.trim() ?? '';

    if (conversation == null) {
      conversation = V2TimConversation(
        conversationID: convId,
        type: 1,
        userID: id,
        showName: showName,
        faceUrl: face.isEmpty ? null : face,
        unreadCount: 0,
        recvOpt: 0,
        orderkey: nowMs,
      );
    } else {
      if ((conversation.showName ?? '').trim().isEmpty) {
        conversation.showName = showName;
      }
      if ((conversation.faceUrl ?? '').trim().isEmpty && face.isNotEmpty) {
        conversation.faceUrl = face;
      }
      final existingActive = ConversationLocalStore.activeTimeMs(conversation);
      if (nowMs >= existingActive) {
        conversation.orderkey = nowMs;
      }
    }

    if (!_shouldPersistConversation(conversation)) {
      return;
    }

    final merged = await ConversationLocalStore.instance.upsertBatch(
      conversations: <V2TimConversation>[conversation],
    );
    final toShow =
        merged.isNotEmpty ? merged : <V2TimConversation>[conversation];
    final notifier = ConversationListNotifier.instance;
    await notifier.applyConversationsFromStore(
      upserted: toShow,
      forceAdmitIds: <String>{convId},
    );
    await notifier.refreshTypeTotals();
    final inHead = notifier.conversations.any(
      (c) => MessageConversationId.sameConversation(c.conversationID, convId),
    );
    final inHydrate = notifier.typeIndexOfConversationId(1, convId) != null;
    if (!inHead || !inHydrate) {
      await notifier.ensureTypeIndexHydrated(
        convType: 1,
        centerIndex: 0,
        forceReload: true,
      );
    }
  }

  Future<void> refreshConversationItem(String conversationID) async {
    final id = conversationID.trim();
    if (id.isEmpty) {
      return;
    }
    final conversation = await _conversationService.getConversation(
      conversationID: id,
    );
    if (conversation == null) {
      return;
    }
    if (!_shouldPersistConversation(conversation)) {
      _stashPendingNonMemberGroupConversations([conversation]);
      return;
    }
    _pendingNonMemberGroupConversations.remove(id);
    final merged = await ConversationLocalStore.instance.upsertBatch(
      conversations: [conversation],
    );
    await _notifyUiAfterLocalWrite(upserted: merged);
  }

  /// 用户已经从列表成功打开会话：立即保留 UI 行，并排队落入本地库。
  ///
  /// 群：成员快照可能因缓存/分页暂时缺项；若只做 membership 过滤放行，虚拟列表
  /// 返回时从 SQLite 重建仍会丢行。
  /// 单聊：下滑到中间打开的冷会话往往只在 `_typeHydrate`、不在 `_conversations`；
  /// 返回后 snapshot/post-pop 不 forceAdmit 就会从视口消失。
  Future<void> retainOpenedGroupConversation(
    V2TimConversation conversation,
  ) async {
    final convId = conversation.conversationID.trim();
    if (convId.isEmpty) {
      return;
    }
    GroupMembershipSyncService.instance.noteActiveGroupConversation(
      conversation,
    );
    if (!_shouldPersistConversation(conversation)) {
      const visibilityLog = false;
      if (visibilityLog) {
        debugPrint(
          '[ConversationVisibility] event=open_retain_rejected '
          'conv=$convId group=${conversation.groupID ?? ''}',
        );
      }
      return;
    }

    // 先把写请求放入 coalesce 队列，再补 UI；这样即使用户立刻返回，
    // 返回水合门禁也能等到该写入完成。
    final persist = ConversationLocalStore.instance.upsertBatch(
      conversations: <V2TimConversation>[conversation],
    );
    await ConversationListNotifier.instance.applyConversationsFromStore(
      upserted: <V2TimConversation>[conversation],
      forceAdmitIds: <String>{convId},
    );
    final merged = await persist;
    if (merged.isNotEmpty) {
      await ConversationListNotifier.instance.applyConversationsFromStore(
        upserted: merged,
        forceAdmitIds: <String>{convId},
      );
    }
    await ConversationListNotifier.instance.refreshTypeTotals();
    const visibilityLog = false;
    if (visibilityLog) {
      debugPrint(
        '[ConversationVisibility] event=open_retain_done conv=$convId '
        'persisted=${merged.isNotEmpty} '
        'notifier=${ConversationListNotifier.instance.conversations.any((item) => MessageConversationId.sameConversation(item.conversationID, convId))}',
      );
    }
  }

  /// 本人新入群后：拉 SDK 会话 + 冲刷挂起项 + 热窗 reload（对齐杀进程重开路径）。
  Future<void> onLocalGroupMembershipExpanded({String? groupId}) async {
    final id = ChatIdFormat.normalizeGroupId(groupId);
    if (id.isNotEmpty) {
      final convId = id.startsWith('group_') ? id : 'group_$id';
      await refreshConversationItem(convId);
    }
    await flushPendingGroupConversationsAfterMembershipChange();
    _scheduleMembershipExpandHotWindowReload();
  }

  /// 成员库已更新：把此前因「非成员」挂起的群会话落库并上屏。
  Future<void> flushPendingGroupConversationsAfterMembershipChange() async {
    if (_pendingNonMemberGroupConversations.isEmpty) {
      return;
    }
    final pending = _pendingNonMemberGroupConversations.values.toList(
      growable: false,
    );
    final ready = <V2TimConversation>[];
    for (final conversation in pending) {
      final convId = conversation.conversationID.trim();
      if (convId.isEmpty) {
        continue;
      }
      if (_shouldPersistConversation(conversation)) {
        ready.add(conversation);
        _pendingNonMemberGroupConversations.remove(convId);
        continue;
      }
      // 再拉一次 SDK，避免挂起快照过旧。
      try {
        final latest = await _conversationService.getConversation(
          conversationID: convId,
        );
        if (latest != null && _shouldPersistConversation(latest)) {
          ready.add(latest);
          _pendingNonMemberGroupConversations.remove(convId);
        }
      } catch (_) {}
    }
    if (ready.isEmpty) {
      return;
    }
    final merged = await ConversationLocalStore.instance.upsertBatch(
      conversations: ready,
    );
    await _notifyUiAfterLocalWrite(upserted: merged);
    _log(
      'flushPendingGroupConversations count=${ready.length} '
      'stillPending=${_pendingNonMemberGroupConversations.length}',
    );
  }

  void _stashPendingNonMemberGroupConversations(
    List<V2TimConversation> conversations,
  ) {
    for (final conversation in conversations) {
      if (!isGroupConversation(conversation)) {
        continue;
      }
      if (_shouldPersistConversation(conversation)) {
        continue;
      }
      final id = conversation.conversationID.trim();
      if (id.isEmpty) {
        continue;
      }
      _pendingNonMemberGroupConversations.remove(id);
      _pendingNonMemberGroupConversations[id] = conversation;
      while (_pendingNonMemberGroupConversations.length >
          _pendingNonMemberGroupCap) {
        _pendingNonMemberGroupConversations.remove(
          _pendingNonMemberGroupConversations.keys.first,
        );
      }
      _schedulePendingGroupMembershipRecovery(conversation);
    }
  }

  void _onRecvNewMessageForMembershipBridge(V2TimMessage message) {
    final loginUser = _ownerUserId();
    if (!GroupTipsMessageHelper.isSelfInvitedOrJoined(message, loginUser)) {
      return;
    }
    final groupId = ChatIdFormat.normalizeGroupId(
      message.groupID ?? message.groupTipsElem?.groupID,
    );
    if (groupId.isEmpty) {
      return;
    }
    final convId = groupId.startsWith('group_') ? groupId : 'group_$groupId';
    final pending = _pendingNonMemberGroupConversations[convId];
    unawaited(
      GroupMembershipSyncService.instance.admitGroupMembershipFromImHint(
        groupId: groupId,
        groupName: pending?.showName?.trim() ?? '',
        avatarUrl: pending?.faceUrl?.trim() ?? '',
      ),
    );
  }

  void _schedulePendingGroupMembershipRecovery(V2TimConversation conversation) {
    final groupId = resolveGroupIdFromConversation(
      conversationId: conversation.conversationID,
      groupId: conversation.groupID,
    );
    if (groupId.isEmpty) {
      return;
    }
    if (!_pendingGroupRecoveryScheduled.add(groupId)) {
      return;
    }
    unawaited(
      _runPendingGroupMembershipRecovery(
        groupId: groupId,
        groupName: conversation.showName?.trim() ?? '',
        avatarUrl: conversation.faceUrl?.trim() ?? '',
      ),
    );
  }

  Future<void> _runPendingGroupMembershipRecovery({
    required String groupId,
    required String groupName,
    required String avatarUrl,
  }) async {
    try {
      await GroupMembershipSyncService.instance.admitGroupMembershipFromImHint(
        groupId: groupId,
        groupName: groupName,
        avatarUrl: avatarUrl,
      );
    } finally {
      _pendingGroupRecoveryScheduled.remove(groupId);
    }
  }

  /// TCP `member_added` 未点名本人时：仅当该群已在挂起队列才触发入群恢复。
  Future<void> recoverPendingGroupMembershipIfNeeded({
    required String groupId,
  }) async {
    final id = ChatIdFormat.normalizeGroupId(groupId);
    if (id.isEmpty) {
      return;
    }
    final convId = id.startsWith('group_') ? id : 'group_$id';
    final pending = _pendingNonMemberGroupConversations[convId];
    if (pending == null) {
      return;
    }
    await GroupMembershipSyncService.instance.admitGroupMembershipFromImHint(
      groupId: id,
      groupName: pending.showName?.trim() ?? '',
      avatarUrl: pending.faceUrl?.trim() ?? '',
    );
  }

  void _scheduleMembershipExpandHotWindowReload() {
    _membershipExpandReloadTimer?.cancel();
    _membershipExpandReloadTimer = Timer(const Duration(milliseconds: 120), () {
      _membershipExpandReloadTimer = null;
      unawaited(
        reloadUiFromLocal(immediate: true, forceFull: true),
      );
    });
  }

  @visibleForTesting
  int get pendingNonMemberGroupConversationCount =>
      _pendingNonMemberGroupConversations.length;

  @visibleForTesting
  void stashPendingNonMemberGroupConversationsForTest(
    List<V2TimConversation> conversations,
  ) {
    _stashPendingNonMemberGroupConversations(conversations);
  }

  @visibleForTesting
  void clearPendingNonMemberGroupConversationsForTest() {
    _pendingNonMemberGroupConversations.clear();
    _pendingGroupRecoveryScheduled.clear();
  }

  /// IM 与后端归档清空成功后：从消息列表移出该会话（不留空壳）。
  Future<void> onConversationHistoryCleared({
    required String conversationID,
    V2TimConversation? snapshot,
  }) async {
    final id = conversationID.trim();
    if (id.isEmpty) {
      return;
    }
    ChatHistoryRefreshBus.instance.requestRefresh(
      conversationId: id,
      reason: 'conversation_clear_history',
    );
    // 产品：清空 = 列表移出。force 清水位并删本地行，避免空壳回钉。
    await _persistDeleted([id], force: true);
    try {
      await _conversationService.deleteConversation(conversationID: id);
    } catch (_) {}
  }

  /// 聊天页删除消息后修正本地会话预览：被删的正是预览所指那条时，
  /// 回退到会话剩余的最新一条；一条不剩则按清空历史处理。
  /// SDK 删除最后一条消息不会更新会话 lastMessage、也不触发
  /// onConversationChanged，必须本地补偿（与撤回的
  /// markConversationLastMessageRevoked 对应）。
  Future<void> onConversationMessagesDeleted({
    required String conversationID,
    required List<String> deletedMsgIDs,
    V2TimMessage? fallbackLastMessage,
  }) async {
    final id = conversationID.trim();
    final targets = deletedMsgIDs
        .map((msgID) => msgID.trim())
        .where((msgID) => msgID.isNotEmpty)
        .toSet();
    if (id.isEmpty || targets.isEmpty) {
      return;
    }
    // 传入的是裸 userID/groupID；先解析成 store 里存的完整会话 id。
    var storedId = id;
    final matched = await ConversationLocalStore.instance.conversationById(id);
    if (matched != null) {
      storedId = matched.conversationID;
    }
    final updated = await ConversationLocalStore.instance
        .replaceConversationLastMessageAfterDelete(
      storedId,
      deletedMsgIDs: targets,
      replacement: fallbackLastMessage,
    );
    if (updated == null) {
      return;
    }
    if (fallbackLastMessage == null) {
      ConversationListNotifier.instance.clearLastMessageLocally(storedId);
    }
    await ConversationListNotifier.instance.applyConversationsFromStore(
      upserted: [updated],
    );
  }

  /// 对方已读回执：若预览即为对应己方消息，写回 lastMessage.isPeerRead。
  Future<void> markLastMessagePeerRead({
    required String conversationID,
    String? msgID,
    int? peerReadAtSec,
  }) async {
    final id = conversationID.trim();
    if (id.isEmpty) {
      return;
    }
    final existing = await ConversationLocalStore.instance.conversationById(id);
    if (existing == null) {
      return;
    }
    final last = existing.lastMessage;
    if (last == null) {
      return;
    }
    if (last.isSelf != true) {
      return;
    }
    if (last.status != MessageStatus.V2TIM_MSG_STATUS_SEND_SUCC) {
      return;
    }
    if (last.isPeerRead == true) {
      return;
    }
    final targetMsgId = msgID?.trim() ?? '';
    final lastMsgId = last.msgID?.trim() ?? '';
    var matched = false;
    if (targetMsgId.isNotEmpty &&
        lastMsgId.isNotEmpty &&
        targetMsgId == lastMsgId) {
      matched = true;
    } else if ((peerReadAtSec ?? 0) > 0) {
      final ts = last.timestamp ?? 0;
      if (ts > 0 && ts <= peerReadAtSec!) {
        matched = true;
      }
    }
    if (!matched) {
      return;
    }
    last.isPeerRead = true;
    final merged = await ConversationLocalStore.instance.upsertBatch(
      conversations: [existing],
    );
    await _notifyUiAfterLocalWrite(upserted: merged);
  }

  /// 用当前消息乐观更新本地会话预览，避免横幅先于列表刷新。
  Future<void> patchConversationLastMessage({
    required String conversationID,
    required V2TimMessage message,
  }) async {
    final id = conversationID.trim();
    if (id.isEmpty) {
      return;
    }
    if (_pageSyncInFlight) {
      _pendingPatches[id] = message;
      _patchesQueuedDuringSync++;
      _pendingPatchesFirstQueuedAt ??= DateTime.now();
      _armPendingPatchesForceFlush();
      if (_patchesQueuedDuringSync == 1 || _patchesQueuedDuringSync % 50 == 0) {
        _log(
          'patch queued during sync count=$_patchesQueuedDuringSync last=$id',
        );
      }
      return;
    }
    await _applyPatchConversationLastMessage(
      conversationID: id,
      message: message,
    );
  }

  void _armPendingPatchesForceFlush() {
    if (_pendingPatchesForceTimer?.isActive == true) {
      return;
    }
    final maxWait = ConversationPerfFlags.pendingPreviewPatchMaxWait;
    if (maxWait <= Duration.zero) {
      return;
    }
    final firstAt = _pendingPatchesFirstQueuedAt ?? DateTime.now();
    final elapsed = DateTime.now().difference(firstAt);
    final remain = maxWait - elapsed;
    _pendingPatchesForceTimer = Timer(
      remain.isNegative ? Duration.zero : remain,
      () {
        _pendingPatchesForceTimer = null;
        unawaited(_forceFlushPendingPatches(reason: 'pending_patch_max_wait'));
      },
    );
  }

  Future<void> _forceFlushPendingPatches({required String reason}) async {
    if (_pendingPatches.isEmpty) {
      _pendingPatchesFirstQueuedAt = null;
      _patchesQueuedDuringSync = 0;
      return;
    }
    ConversationPerfGateLog.log(
      'pending_preview_patch_force_flush',
      extras: <String, Object?>{
        'reason': reason,
        'count': _pendingPatches.length,
        'syncInFlight': _pageSyncInFlight ? 1 : 0,
      },
    );
    await _replayPendingPatches();
  }

  Future<void> _replayPendingPatches() async {
    _pendingPatchesForceTimer?.cancel();
    _pendingPatchesForceTimer = null;
    _pendingPatchesFirstQueuedAt = null;
    if (_pendingPatches.isEmpty) {
      _patchesQueuedDuringSync = 0;
      return;
    }
    final patches = Map<String, V2TimMessage>.from(_pendingPatches);
    _pendingPatches.clear();
    final queued = _patchesQueuedDuringSync;
    _patchesQueuedDuringSync = 0;
    if (queued > 0) {
      _log(
        'replay pending patches unique=${patches.length} queuedLogs=$queued',
      );
    }
    final mergedAll = <V2TimConversation>[];
    for (final entry in patches.entries) {
      final merged = await _applyPatchConversationLastMessage(
        conversationID: entry.key,
        message: entry.value,
        notifyUi: false,
      );
      if (merged != null && merged.isNotEmpty) {
        mergedAll.addAll(merged);
      }
    }
    if (mergedAll.isNotEmpty) {
      await _notifyUiAfterLocalWrite(upserted: mergedAll, immediate: true);
    }
  }

  Future<List<V2TimConversation>?> _applyPatchConversationLastMessage({
    required String conversationID,
    required V2TimMessage message,
    bool notifyUi = true,
  }) async {
    final id = conversationID.trim();
    if (id.isEmpty) {
      return null;
    }
    // 禁止跨类型把单聊正文写进群预览（或反过来）。
    final messageConvId = MessageConversationId.fromMessage(message);
    if (messageConvId != null && messageConvId.isNotEmpty) {
      final targetC2c = MessageConversationId.looksLikeC2cConversationId(id);
      final targetGroup =
          MessageConversationId.looksLikeGroupConversationId(id) ||
              ChatIdFormat.isIMGroupOrCommunityId(id) ||
              id.toUpperCase().contains('TGS#');
      final msgC2c =
          MessageConversationId.looksLikeC2cConversationId(messageConvId);
      final msgGroup =
          MessageConversationId.looksLikeGroupConversationId(messageConvId);
      if ((targetGroup && msgC2c) || (targetC2c && msgGroup)) {
        _log(
          'skip lastMessage patch type mismatch target=$id '
          'messageConv=$messageConvId msgId=${message.msgID ?? ''}',
        );
        OutgoingVisibleProbe.log(
          'lastmsg_skip_type_mismatch',
          conversationID: id,
          message: message,
          extras: <String, Object?>{'messageConv': messageConvId},
        );
        return null;
      }
    }
    // 社群 ID 多形态：`group_@TGS#_mc…` / 裸 ID；逐个试 getConversation。
    final idCandidates = <String>{id};
    if (id.toLowerCase().startsWith('group_')) {
      final bare = id.substring(6);
      idCandidates.add(bare);
      final normalized = ChatIdFormat.normalizeGroupId(bare);
      if (normalized.isNotEmpty) {
        idCandidates.add(normalized);
        idCandidates.add('group_$normalized');
      }
    } else if (ChatIdFormat.isIMGroupOrCommunityId(id) ||
        id.toUpperCase().contains('TGS#')) {
      final normalized = ChatIdFormat.normalizeGroupId(id);
      if (normalized.isNotEmpty) {
        idCandidates.add(normalized);
        idCandidates.add('group_$normalized');
      }
    }
    V2TimConversation? conversation;
    for (final candidate in idCandidates) {
      conversation = await _conversationService.getConversation(
        conversationID: candidate,
      );
      if (conversation != null) {
        break;
      }
    }
    final msgId = message.msgID?.trim() ?? '';
    if (conversation == null) {
      final isGroup = id.toLowerCase().startsWith('group_') ||
          ChatIdFormat.isIMGroupOrCommunityId(id) ||
          id.toUpperCase().contains('TGS#');
      final groupId = isGroup
          ? ChatIdFormat.normalizeGroupId(
              id.toLowerCase().startsWith('group_') ? id.substring(6) : id,
            )
          : null;
      final convId = isGroup
          ? (groupId != null && groupId.isNotEmpty ? 'group_$groupId' : id)
          : (id.startsWith('c2c_') ? id : 'c2c_$id');
      conversation = V2TimConversation(
        conversationID: convId,
        type: isGroup ? 2 : 1,
        userID: isGroup ? null : id.replaceFirst('c2c_', ''),
        groupID: groupId,
        lastMessage: message,
        orderkey: message.timestamp,
      );
    }
    if (!_shouldPersistConversation(conversation)) {
      OutgoingVisibleProbe.log(
        'lastmsg_persist_reject',
        conversationID: id,
        message: message,
        extras: <String, Object?>{
          'convId': conversation.conversationID,
        },
      );
      // 入群竞态：先挂起并触发成员恢复，勿立刻 prune（否则永远等杀进程）。
      _stashPendingNonMemberGroupConversations([conversation]);
      // 仍把预览推到内存列表，避免发完消息回列表预览空白。
      ConversationListNotifier.instance.applyLastMessageLocally(
        conversationID: conversation.conversationID,
        message: message,
      );
      return null;
    }
    if (conversation.lastMessage?.msgID?.trim() == msgId && msgId.isNotEmpty) {
      if (GroupTipsMessageHelper.shouldUpgradeSameIdLastMessage(
        existing: conversation.lastMessage,
        incoming: message,
      )) {
        conversation.lastMessage = message;
      }
      _applySdkUnreadForPatch(conversation);
      OutgoingVisibleProbe.log(
        'lastmsg_patch_same_id',
        conversationID: id,
        message: message,
      );
      return _persistPatchedConversation(
        conversation,
        message: message,
        notifyUi: notifyUi,
      );
    }
    final last = conversation.lastMessage;
    final lastId = last?.msgID?.trim() ?? '';
    final incomingTs = message.timestamp ?? 0;
    final currentTs = last?.timestamp ?? 0;
    if (incomingTs > 0 &&
        currentTs > 0 &&
        incomingTs < currentTs &&
        msgId.isNotEmpty &&
        lastId.isNotEmpty &&
        msgId != lastId) {
      OutgoingVisibleProbe.log(
        'lastmsg_skip_ts_rollback',
        conversationID: id,
        message: message,
        extras: <String, Object?>{
          'incomingTs': incomingTs,
          'currentTs': currentTs,
          'lastMsgID': lastId,
        },
      );
      return null;
    }
    conversation.lastMessage = message;
    if (incomingTs > 0) {
      conversation.orderkey = incomingTs;
    }
    _applySdkUnreadForPatch(conversation);
    OutgoingVisibleProbe.log(
      'lastmsg_patch_ok',
      conversationID: id,
      message: message,
      extras: <String, Object?>{'notifyUi': notifyUi},
    );
    return _persistPatchedConversation(
      conversation,
      message: message,
      notifyUi: notifyUi,
    );
  }

  /// 发送预览 patch：并入 persist dedup，与 SDK changed 同窗合并，避免双写 SQLite。
  Future<List<V2TimConversation>?> _persistPatchedConversation(
    V2TimConversation conversation, {
    required V2TimMessage message,
    required bool notifyUi,
  }) async {
    if (!notifyUi) {
      // sync replay / 批量路径：直接落库。
      return ConversationLocalStore.instance.upsertBatch(
        conversations: [conversation],
      );
    }
    _enqueuePersistChanged(
      [conversation],
      reason: 'send_patch',
      prepare: true,
    );
    ConversationPerfGateLog.log(
      'persist_dedup_merge_send_patch',
      extras: <String, Object?>{
        'conversationID': conversation.conversationID,
        'buffer': _persistDedupBuffer.length,
        'busy': _isUiBusyForPersist,
      },
    );
    ConversationListNotifier.instance.applyLastMessageLocally(
      conversationID: conversation.conversationID,
      message: message,
      bumpUnread: ConversationUnreadGuard.shouldOptimisticBumpUnread(
        conversationId: conversation.conversationID,
        message: message,
      ),
    );
    final convId = conversation.conversationID.trim();
    final inList = ConversationListNotifier.instance.conversations.any(
      (c) => MessageConversationId.sameConversation(c.conversationID, convId),
    );
    if (!inList && convId.isNotEmpty) {
      if (ConversationUnreadGuard.shouldOptimisticBumpUnread(
        conversationId: convId,
        message: message,
      )) {
        conversation.unreadCount = (conversation.unreadCount ?? 0) + 1;
      }
      await ConversationListNotifier.instance.applyConversationsFromStore(
        upserted: <V2TimConversation>[conversation],
        forceAdmitIds: <String>{convId},
      );
    }
    return [conversation];
  }

  /// 未读以 IM SDK 为准；仅前台正在看的会话强制 0。
  void _applySdkUnreadForPatch(V2TimConversation conversation) {
    final conversationId = conversation.conversationID.trim();
    if (ForegroundChatGuard.isActiveConversation(conversationId)) {
      conversation.unreadCount = 0;
    }
  }

  Future<void> markConversationReadLocally(
    String conversationID, {
    bool forceImmediateUi = false,
  }) async {
    final id = conversationID.trim();
    if (id.isEmpty) {
      return;
    }
    if (!forceImmediateUi) {
      final existing = await ConversationLocalStore.instance.conversationById(
        id,
      );
      if (existing != null && (existing.unreadCount ?? 0) == 0) {
        return;
      }
      final lastAt = _lastMarkReadAt;
      if (_lastMarkReadId == id &&
          lastAt != null &&
          DateTime.now().difference(lastAt) < _markReadDebounce) {
        return;
      }
    }
    ConversationUnreadTrace.log(
      'mark_read_locally_start',
      conversationID: id,
      extras: <String, Object?>{'forceImmediateUi': forceImmediateUi},
    );
    final override = markReadStoreOverride;
    final immediate = forceImmediateUi || shouldMarkReadReloadImmediately();
    if (override != null) {
      await override(conversationID);
      await _notifyUiAfterLocalWrite(fullReload: true, immediate: immediate);
      _lastMarkReadId = id;
      _lastMarkReadAt = DateTime.now();
      ConversationUnreadTrace.log(
        'mark_read_locally_done',
        conversationID: id,
        extras: <String, Object?>{'via': 'override'},
      );
      return;
    }
    final updated = await ConversationLocalStore.instance
        .markConversationReadLocally(conversationID);
    if (updated == null) {
      ConversationUnreadTrace.log(
        'mark_read_locally_done',
        conversationID: id,
        extras: <String, Object?>{'via': 'noop'},
      );
      return;
    }
    await _notifyUiAfterLocalWrite(updated: updated, immediate: immediate);
    _lastMarkReadId = id;
    _lastMarkReadAt = DateTime.now();
    ConversationUnreadTrace.log(
      'mark_read_locally_done',
      conversationID: id,
      unreadAfter: updated.unreadCount ?? 0,
    );
  }

  Future<void> onViewModelPageLoaded({
    required List<V2TimConversation?> conversations,
    required bool isRefresh,
    required String nextSeq,
    required bool haveMoreData,
    required bool hasLoadedOnce,
  }) async {
    if (ImSnapshotBootstrapService.instance.shouldSuppressViewModelPersist) {
      _log(
        'view_model_page skipped (snapshot/login bootstrap gate) '
        'count=${conversations.length}',
      );
      return;
    }
    final typed = conversations.whereType<V2TimConversation>().toList();
    if (typed.isEmpty && !isRefresh) {
      return;
    }
    if (typed.isNotEmpty) {
      final persistable = _filterPersistableConversations(typed);
      if (persistable.isNotEmpty) {
        if (ConversationPerfFlags.conversationListSdkPrimary) {
          await ConversationLocalStore.instance.upsertBatch(
            conversations: persistable,
          );
          ConversationPerfGateLog.log(
            'mirror_skip_ui',
            extras: <String, Object?>{
              'via': 'view_model_page',
              'count': persistable.length,
            },
          );
        } else if (ConversationPerfFlags
                .deferViewModelPersistWhileFeedScrolling &&
            _isFeedScrollingNow) {
          for (final conversation in persistable) {
            final id = conversation.conversationID.trim();
            if (id.isEmpty) {
              continue;
            }
            _deferredViewModelPersistById[id] = conversation;
          }
          while (_deferredViewModelPersistById.length >
              _deferredViewModelPersistCap) {
            _deferredViewModelPersistById
                .remove(_deferredViewModelPersistById.keys.first);
          }
          ConversationPerfGateLog.log(
            'view_model_page_persist',
            extras: <String, Object?>{
              'count': persistable.length,
              'ui': 'defer_write',
              'pendingWrites': _deferredViewModelPersistById.length,
            },
          );
        } else if (ConversationPerfFlags.viewModelPageUiApplyDeferred) {
          final merged = await ConversationLocalStore.instance.upsertBatch(
            conversations: persistable,
          );
          final uiMode = _shouldDeferPersistUiApply() ? 'defer' : 'paced';
          ConversationPerfGateLog.log(
            'view_model_page_persist',
            extras: <String, Object?>{
              'count': persistable.length,
              'ui': uiMode,
            },
          );
          await _applyPacedSyncPageToUi(
            merged,
            reason: 'view_model_page',
          );
        } else {
          final merged = await ConversationLocalStore.instance.upsertBatch(
            conversations: persistable,
          );
          ConversationPerfGateLog.log(
            'view_model_page_persist',
            extras: <String, Object?>{
              'count': persistable.length,
              'ui': 'apply',
            },
          );
          await _notifyUiAfterLocalWrite(upserted: merged);
        }
      }
      unawaited(_purgeRejectedGroupConversations(typed));
    }
    // UIKit 混流分页不得冒充「本地 typed 已同步」：hasSyncedOnce / 游标
    // 只由 syncFromSdkByType / bootstrapTypedFirstScreen 推进。
  }

  Future<void> onViewModelConversationsChanged(
    List<V2TimConversation> conversations,
  ) async {
    if (ImSnapshotBootstrapService.instance.shouldSuppressViewModelPersist) {
      _log(
        'view_model_changed skipped (snapshot/login bootstrap gate) '
        'count=${conversations.length}',
      );
      return;
    }
    await _persistChanged(conversations, reason: 'view_model_changed');
  }

  List<V2TimConversation> _filterChangedViewModelConversations(
    List<V2TimConversation> conversations,
  ) {
    final changed = <V2TimConversation>[];
    for (final conversation in conversations) {
      final id = conversation.conversationID.trim();
      if (id.isEmpty) {
        continue;
      }
      final fingerprint = _viewModelFingerprint(conversation);
      final pendingKey = _findPersistDedupBufferKey(id);
      final pending =
          pendingKey == null ? null : _persistDedupBuffer[pendingKey];
      final previous = pending != null
          ? _viewModelFingerprint(pending)
          : (_persistInFlightFingerprints[id] ??
              _viewModelPersistFingerprints[id]);
      if (previous == fingerprint) {
        continue;
      }
      changed.add(conversation);
    }
    return changed;
  }

  static String _viewModelFingerprint(V2TimConversation conversation) {
    final last = conversation.lastMessage;
    return <Object?>[
      conversation.conversationID,
      conversation.type,
      conversation.userID,
      conversation.groupID,
      conversation.showName,
      conversation.faceUrl,
      conversation.unreadCount,
      conversation.recvOpt,
      conversation.groupType,
      conversation.customData,
      conversation.isPinned,
      conversation.orderkey,
      conversation.draftText,
      conversation.draftTimestamp,
      last?.msgID,
      last?.timestamp,
      last?.elemType,
      last?.status,
    ].join('\u001f');
  }

  void _prepareConversationForPersist(V2TimConversation conversation) {
    final id = conversation.conversationID.trim();
    final unreadBefore = conversation.unreadCount ?? 0;
    var uiUnread = unreadBefore;
    for (final item in ConversationListNotifier.instance.conversations) {
      if (MessageConversationId.sameConversation(item.conversationID, id)) {
        uiUnread = item.unreadCount ?? 0;
        break;
      }
    }
    final unreadAfter = ConversationUnreadGuard.resolveForPersist(
      conversation: conversation,
      uiUnread: uiUnread,
      suppressStaleForRecentlyLeft: shouldSuppressStaleUnread(id),
    );
    if (unreadBefore != unreadAfter) {
      ConversationUnreadTrace.log(
        'persist_prepare',
        conversationID: id,
        unreadBefore: unreadBefore,
        unreadAfter: unreadAfter,
        extras: <String, Object?>{
          'uiUnread': uiUnread,
          'postPop': isInPostPopCoalesceWindow,
          'recentlyLeft': _recentlyLeftConversationId,
          'suppressedStale':
              shouldSuppressStaleUnread(id) && unreadAfter < unreadBefore,
        },
      );
    }
  }

  Future<void> onViewModelConversationsDeleted(
    List<String> ids, {
    bool force = false,
  }) async {
    await _persistDeleted(ids, force: force);
  }

  Future<void> _persistChanged(
    List<V2TimConversation> conversations, {
    required String reason,
  }) async {
    for (final conversation in conversations) {
      _prepareConversationForPersist(conversation);
      ConversationPerfGateLog.markRealtimeConversationCallback(
        conversationId: conversation.conversationID,
        reason: reason,
      );
      final last = conversation.lastMessage;
      if (last != null) {
        unawaited(
          GroupMembershipSyncService.instance
              .applyInboundGroupDisplayFromMessage(last),
        );
        unawaited(
          GroupMembershipSyncService.instance
              .applyInboundMembershipTipFromMessage(last),
        );
      }
    }
    final changed = _filterChangedViewModelConversations(conversations);
    if (changed.isEmpty) {
      _log('$reason skipped unchanged count=${conversations.length}');
      return;
    }
    _enqueuePersistChanged(changed, reason: reason, prepare: false);
  }

  @visibleForTesting
  Future<void> persistChangedForTest(
    List<V2TimConversation> conversations, {
    String reason = 'test',
  }) async {
    enqueuePersistChangedForTest(conversations, reason: reason);
    _persistDedupTimer?.cancel();
    _persistDedupTimer = null;
    await _flushPersistDedupBuffer(reason: reason);
  }

  @visibleForTesting
  Future<void> persistDeletedForTest(
    List<String> conversationIds, {
    bool force = false,
  }) async {
    await _persistDeleted(conversationIds, force: force);
  }

  @visibleForTesting
  void enqueuePersistChangedForTest(
    List<V2TimConversation> conversations, {
    String reason = 'changed',
  }) {
    _enqueuePersistChanged(conversations, reason: reason, prepare: true);
  }

  void _enqueuePersistChanged(
    List<V2TimConversation> conversations, {
    required String reason,
    required bool prepare,
  }) {
    if (conversations.isEmpty) {
      return;
    }
    for (final conversation in conversations) {
      final id = conversation.conversationID.trim();
      if (id.isEmpty) {
        continue;
      }
      if (prepare) {
        _prepareConversationForPersist(conversation);
      }
      final existingKey = _findPersistDedupBufferKey(id);
      if (existingKey == null) {
        _persistDedupBuffer[id] = conversation;
        continue;
      }
      final existing = _persistDedupBuffer[existingKey]!;
      final preferredId = ChatIdFormat.preferredGroupConversationId(
        existing.conversationID,
        id,
      );
      final keep = preferredId == id ? conversation : existing;
      keep.conversationID = preferredId;
      final preferredGid = preferredId.startsWith('group_')
          ? preferredId.substring(6)
          : preferredId;
      if (preferredGid.isNotEmpty) {
        keep.groupID = preferredGid;
      }
      if (existingKey != preferredId) {
        _persistDedupBuffer.remove(existingKey);
      }
      _persistDedupBuffer[preferredId] = keep;
    }
    if (_persistDedupBuffer.isEmpty) {
      return;
    }
    _persistPendingReason = reason;
    _persistDedupTimer?.cancel();
    _persistDedupTimer = Timer(_persistDedupDelayForReason(reason), () {
      unawaited(_flushPersistDedupBuffer(reason: _persistPendingReason));
    });
  }

  String? _findPersistDedupBufferKey(String conversationId) {
    final id = conversationId.trim();
    if (id.isEmpty) {
      return null;
    }
    if (_persistDedupBuffer.containsKey(id)) {
      return id;
    }
    for (final entry in _persistDedupBuffer.entries) {
      if (MessageConversationId.sameConversation(entry.key, id)) {
        return entry.key;
      }
    }
    return null;
  }

  bool _shouldPersistConversation(V2TimConversation conversation) {
    return GroupMembershipSyncService.instance.shouldShowConversation(
      conversation,
    );
  }

  List<V2TimConversation> _filterPersistableConversations(
    List<V2TimConversation> conversations,
  ) {
    return conversations
        .where(_shouldPersistConversation)
        .toList(growable: false);
  }

  Future<void> _purgeRejectedGroupConversations(
    List<V2TimConversation> conversations,
  ) async {
    if (!GroupMembershipSyncService.instance.hasSyncedGroupListOnce) {
      return;
    }
    for (final conversation in conversations) {
      if (_shouldPersistConversation(conversation)) {
        continue;
      }
      final convId = conversation.conversationID.trim();
      // 正在等待入群对齐的挂起项：禁止 prune，否则会话被清掉后只能杀进程恢复。
      if (convId.isNotEmpty &&
          _pendingNonMemberGroupConversations.containsKey(convId)) {
        continue;
      }
      final groupId = resolveGroupIdFromConversation(
        conversationId: conversation.conversationID,
        groupId: conversation.groupID,
      );
      if (groupId.isEmpty) {
        continue;
      }
      await GroupMembershipSyncService.instance.pruneStaleGroupConversations(
        reason: 'reject_non_member_persist',
      );
      return;
    }
  }

  Future<List<String>> _collectObsoleteGroupTwinIds({
    Iterable<String> extraIds = const [],
  }) async {
    final existing =
        await ConversationLocalStore.instance.listGroupConversationIds();
    return ChatIdFormat.obsoleteGroupConversationTwinIds(<String>[
      ...existing,
      ...extraIds,
    ]);
  }

  /// 删除「完整社群已存在」时残留的裸短码会话（本地精确删 + IM SDK）。
  Future<void> purgeSupersededBareShortGroupConversations({
    String reason = 'manual',
    List<String> extraObsoleteIds = const [],
  }) {
    return _purgeObsoleteGroupConversationTwins(
      reason: reason,
      upsertObsoleteIds: extraObsoleteIds,
    );
  }

  /// 删除会话双子残留（本地删 + IM SDK）。
  Future<void> _purgeObsoleteGroupConversationTwins({
    required String reason,
    List<String> upsertObsoleteIds = const [],
  }) async {
    final targets = upsertObsoleteIds
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toSet();
    if (targets.isEmpty) {
      return;
    }
    final deleted = await ConversationLocalStore.instance.deleteBatch(
      conversationIds: targets.toList(growable: false),
    );
    for (final id in targets) {
      try {
        await _conversationService.deleteConversation(conversationID: id);
      } catch (e) {
        _log(
          'purgeObsoleteGroupTwins sdk delete failed id=$id error=$e '
          'reason=$reason',
        );
      }
    }
    if (deleted.isNotEmpty || targets.isNotEmpty) {
      await _notifyUiAfterLocalWrite(
        deletedIds: targets.toList(growable: false),
      );
    }
    _log(
      'purgeObsoleteGroupTwins reason=$reason count=${targets.length} '
      'ids=${targets.take(6).join(',')}',
    );
  }

  Future<void> _flushPersistDedupBuffer({required String reason}) async {
    _persistDedupTimer = null;
    if (_persistDedupBuffer.isEmpty) {
      return;
    }
    final conversations = _persistDedupBuffer.values.toList(growable: false);
    _persistDedupBuffer.clear();
    persistFlushInvocationCount++;
    final persistable = _filterPersistableConversations(conversations);
    final persistableIds = persistable
        .map((c) => c.conversationID.trim())
        .where((id) => id.isNotEmpty)
        .toSet();
    final rejected = conversations
        .where((c) => !persistableIds.contains(c.conversationID.trim()))
        .toList(growable: false);
    // 入群事件可能晚于 IM 会话：先挂起，勿直接丢掉（杀进程重开才能看见）。
    _stashPendingNonMemberGroupConversations(rejected);
    if (persistable.isEmpty) {
      _log(
        'persistChanged reason=coalesced:$reason skipped_non_member='
        '${conversations.length} pending='
        '${_pendingNonMemberGroupConversations.length}',
      );
      return;
    }
    final fingerprints = <String, String>{
      for (final conversation in persistable)
        if (conversation.conversationID.trim().isNotEmpty)
          conversation.conversationID.trim():
              _viewModelFingerprint(conversation),
    };
    _persistInFlightFingerprints.addAll(fingerprints);
    final hotListener = _isConversationListenerPersistReason(reason);
    final sdkPrimary = ConversationPerfFlags.conversationListSdkPrimary;
    // Phase2：Listener 热路径先用 SDK 对象灌 TabStore，再 mirror 写库。
    if (sdkPrimary && hotListener) {
      await ConversationListNotifier.instance.applyConversationsFromStore(
        upserted: persistable,
      );
      ConversationPerfGateLog.log(
        'ui_source',
        extras: <String, Object?>{
          'source': 'sdk_listener',
          'reason': reason,
          'count': persistable.length,
        },
      );
    }
    late final List<V2TimConversation> merged;
    try {
      merged = upsertBatchOverride != null
          ? await upsertBatchOverride!(persistable)
          : await ConversationLocalStore.instance.upsertBatch(
              conversations: persistable,
            );
      for (final entry in fingerprints.entries) {
        if (_persistInFlightFingerprints[entry.key] == entry.value) {
          _viewModelPersistFingerprints[entry.key] = entry.value;
        }
      }
    } finally {
      for (final entry in fingerprints.entries) {
        if (_persistInFlightFingerprints[entry.key] == entry.value) {
          _persistInFlightFingerprints.remove(entry.key);
        }
      }
    }
    ConversationPinFlickerLog.log(
      'persist_flush',
      extras: <String, Object?>{
        'reason': reason,
        'count': persistable.length,
        'deferring': ConversationListNotifier.instance.isDeferringPinReorder,
        'ids': persistable
            .map((e) => e.conversationID.trim())
            .where((e) => e.isNotEmpty)
            .take(6)
            .join(','),
      },
    );
    for (final conversation in merged) {
      ConversationPerfGateLog.markRealtimePersistDone(
        conversationId: conversation.conversationID,
        reason: reason,
      );
    }
    if (sdkPrimary && hotListener) {
      ConversationPerfGateLog.log(
        'mirror_skip_ui',
        extras: <String, Object?>{
          'via': 'persist_flush',
          'reason': reason,
          'count': merged.length,
        },
      );
    } else {
      // SDK 会话监听热路径：写库后立刻灌 UI，避开 scroll/quiet pending 帽丢更新。
      await _notifyUiAfterLocalWrite(
        upserted: merged,
        immediate: hotListener,
      );
    }
    _log('persistChanged reason=coalesced:$reason count=${persistable.length}');
    await _purgeObsoleteGroupConversationTwins(
      reason: 'persist_flush:$reason',
      upsertObsoleteIds: await _collectObsoleteGroupTwinIds(
        extraIds: persistable.map((c) => c.conversationID),
      ),
    );
    ConversationUnreadTrace.logConversations(
      'persist_flush_upserted',
      conversations: merged,
      extras: <String, Object?>{'reason': reason},
    );
    for (final conversation in persistable) {
      final id = conversation.conversationID.trim();
      if (id.isEmpty) {
        continue;
      }
      int? uiUnread;
      for (final item in ConversationListNotifier.instance.conversations) {
        if (MessageConversationId.sameConversation(item.conversationID, id)) {
          uiUnread = item.unreadCount ?? 0;
          break;
        }
      }
      ConversationUnreadTrace.log(
        'persist_flush_ui_state',
        conversationID: id,
        unreadAfter: uiUnread,
        extras: <String, Object?>{'reason': reason},
      );
    }
  }

  Future<void> _persistDeleted(
    List<String> conversationIds, {
    bool force = false,
  }) async {
    if (conversationIds.isEmpty) {
      return;
    }
    final preserved = <String>[];
    final deletable = <String>[];
    for (final raw in conversationIds) {
      final id = raw.trim();
      if (id.isEmpty) {
        continue;
      }
      if (!force &&
          await ConversationLocalStore.instance
              .shouldSuppressConversationDeletionAfterHistoryClearAsync(id)) {
        preserved.add(id);
        continue;
      }
      deletable.add(id);
    }
    if (preserved.isNotEmpty) {
      _log(
        'persistDeleted skipped history-cleared count=${preserved.length} ids=$preserved',
      );
      // 产品：清空/删除均不留空壳。suppress 时 no-op，禁止回钉列表。
    }
    if (deletable.isEmpty) {
      return;
    }
    if (force) {
      for (final id in deletable) {
        ConversationLocalStore.instance.clearHistoryClearedMarkers(id);
        ArchiveHistoryProvider.clearHistoryClearPending(id);
      }
    }
    final deleted = await ConversationLocalStore.instance.deleteBatch(
      conversationIds: deletable,
    );
    await _notifyUiAfterLocalWrite(deletedIds: deleted);
    _notifyActiveChatClosed(deleted);
    _log(
      'persistDeleted count=${deletable.length}${force ? ' force=true' : ''}',
    );
  }

  void _notifyActiveChatClosed(List<String> deletedIds) {
    if (deletedIds.isEmpty) {
      return;
    }
    try {
      final model = serviceLocator<TUIConversationViewModel>();
      final selectedId =
          model.selectedConversation?.conversationID.trim() ?? '';
      if (selectedId.isNotEmpty) {
        final hit = deletedIds.any(
          (id) => MessageConversationId.sameConversation(id, selectedId),
        );
        if (hit) {
          model.assignSelectedConversation(null, notify: true);
        }
      }
    } catch (_) {}
    ConversationDeletedBus.instance.notifyDeleted(deletedIds);
  }

  Future<void> clearSession() async {
    _syncGeneration++;
    _awaitingPostServerSync = false;
    _c2cHistoryBackfillInFlight = null;
    _c2cHistoryBackfillScheduled = false;
    _c2cMetadataEnrichDone = false;
    _c2cFriendScanDone = false;
    _pendingSdkSync = null;
    _scopeHydrationTask = null;
    _scopeHydrationDone = false;
    _pendingPatches.clear();
    _patchesQueuedDuringSync = 0;
    _lastMarkReadId = null;
    _lastMarkReadAt = null;
    _syncServerFinishTimer?.cancel();
    _syncServerFinishTimer = null;
    _lastSyncServerFinishAt = null;
    _reloadUiCoalesceTimer?.cancel();
    _reloadUiCoalesceTimer = null;
    _chatTransitionDepth = 0;
    _postPopCoalesceUntil = null;
    _postPopCoalesceWindowStart = null;
    _postPopCoalesceScheduled = false;
    _persistDedupTimer?.cancel();
    _persistDedupTimer = null;
    _persistDedupBuffer.clear();
    _viewModelPersistFingerprints.clear();
    _persistPendingReason = 'changed';
    _recentlyLeftConversationId = null;
    _idleDrainTimer?.cancel();
    _idleDrainTimer = null;
    _idleDrainSessionPages = 0;
    _backgroundDrainInFlight = false;
    await ConversationLocalStore.instance.clearSession();
    ConversationListNotifier.instance.clearSession();
    ConversationListSyncNotifier.instance.clearSession();
  }
}

class _PendingSdkSync {
  const _PendingSdkSync({
    required this.reason,
    required this.reset,
    required this.force,
    required this.loadAllPages,
    required this.reloadUiEachPage,
    this.drainMode,
  });

  final String reason;
  final bool reset;
  final bool force;
  final bool loadAllPages;
  final bool reloadUiEachPage;
  final ConversationSdkDrainMode? drainMode;

  _PendingSdkSync mergePreferStronger(_PendingSdkSync other) {
    final preferOther = other.reset ||
        other.force ||
        other.loadAllPages ||
        other.drainMode == ConversationSdkDrainMode.foregroundLimited ||
        other.reason.contains('sync_server_finish');
    final mergedMode = _strongerDrainMode(drainMode, other.drainMode);
    if (preferOther) {
      return _PendingSdkSync(
        reason: other.reason,
        reset: reset || other.reset,
        force: force || other.force,
        loadAllPages: loadAllPages || other.loadAllPages,
        reloadUiEachPage: reloadUiEachPage && other.reloadUiEachPage,
        drainMode: mergedMode ?? other.drainMode,
      );
    }
    return _PendingSdkSync(
      reason: reason,
      reset: reset || other.reset,
      force: force || other.force,
      loadAllPages: loadAllPages || other.loadAllPages,
      reloadUiEachPage: reloadUiEachPage && other.reloadUiEachPage,
      drainMode: mergedMode ?? drainMode,
    );
  }

  static ConversationSdkDrainMode? _strongerDrainMode(
    ConversationSdkDrainMode? a,
    ConversationSdkDrainMode? b,
  ) {
    if (a == null) {
      return b;
    }
    if (b == null) {
      return a;
    }
    int rank(ConversationSdkDrainMode m) {
      switch (m) {
        case ConversationSdkDrainMode.singlePage:
          return 1;
        case ConversationSdkDrainMode.foregroundLimited:
          return 2;
        case ConversationSdkDrainMode.backgroundContinue:
          return 3;
      }
    }

    return rank(a) >= rank(b) ? a : b;
  }
}
