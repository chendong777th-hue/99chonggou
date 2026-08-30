// ignore_for_file: avoid_print, unnecessary_getters_setters, unused_element
import 'dart:async';
import 'dart:convert';
import 'dart:collection';
import 'dart:io';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:tencent_cloud_chat_demo/src/services/im/contracts/contracts.dart';
import 'package:tencent_cloud_chat_demo/src/services/im/outgoing_send_coordinator.dart';
import 'package:tencent_cloud_chat_uikit/ui/views/TIMUIKitSearch/conversation_search_utils.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tencent_cloud_chat_uikit/business_logic/view_models/gap_detector.dart';
import 'package:tencent_cloud_chat_uikit/business_logic/view_models/inbound_reorder_buffer.dart';
import 'package:tencent_cloud_chat_sdk/enum/V2TimAdvancedMsgListener.dart';
import 'package:tencent_cloud_chat_sdk/enum/history_msg_get_type_enum.dart';
import 'package:tencent_cloud_chat_sdk/enum/message_elem_type.dart';
import 'package:tencent_cloud_chat_sdk/enum/message_priority_enum.dart';
import 'package:tencent_cloud_chat_sdk/enum/message_status.dart';
import 'package:tencent_cloud_chat_sdk/enum/offlinePushInfo.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_conversation.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_conversation.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_custom_elem.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_custom_elem.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_group_application.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_group_application.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_group_member_full_info.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_group_member_full_info.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_image.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_image.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_message.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_message.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_message_download_progress.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_message_download_progress.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_message_receipt.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_message_receipt.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_msg_create_info_result.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_msg_create_info_result.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_value_callback.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_value_callback.dart';
import 'package:tencent_cloud_chat_uikit/base_widgets/tim_ui_kit_class.dart';
import 'package:tencent_cloud_chat_uikit/business_logic/life_cycle/chat_life_cycle.dart';
import 'package:tencent_cloud_chat_uikit/business_logic/separate_models/tui_chat_model_tools.dart';
import 'package:tencent_cloud_chat_uikit/business_logic/services/group_member_store.dart';
import 'package:tencent_cloud_chat_uikit/business_logic/view_models/chat_message_window.dart';
import 'package:tencent_cloud_chat_uikit/business_logic/view_models/chat_message_window_policy.dart';
import 'package:tencent_cloud_chat_uikit/business_logic/view_models/chat_ui_state_store.dart';
import 'package:tencent_cloud_chat_uikit/business_logic/view_models/message_commit_coordinator.dart';
import 'package:tencent_cloud_chat_uikit/business_logic/view_models/message_cloud_catch_up.dart';
import 'package:tencent_cloud_chat_uikit/business_logic/view_models/message_reconciliation_coordinator.dart';
import 'package:tencent_cloud_chat_uikit/business_logic/view_models/message_reconciliation_identity.dart';
import 'package:tencent_cloud_chat_uikit/business_logic/view_models/message_reconciliation_writer.dart';
import 'package:tencent_cloud_chat_uikit/business_logic/view_models/message_history_coverage.dart';
import 'package:tencent_cloud_chat_uikit/business_logic/view_models/open_hydrate_result.dart';
import 'package:tencent_cloud_chat_uikit/business_logic/view_models/message_history_batch.dart';
import 'package:tencent_cloud_chat_uikit/business_logic/view_models/message_delta.dart';
import 'package:tencent_cloud_chat_uikit/data_services/group/group_services.dart';
import 'package:tencent_cloud_chat_uikit/data_services/message/message_services.dart';
import 'package:tencent_cloud_chat_uikit/data_services/message/conversation_peer_read_coordinator.dart';
import 'package:tencent_cloud_chat_uikit/data_services/profile/user_profile_local_bridge.dart';
import 'package:tencent_cloud_chat_uikit/data_services/services_locatar.dart';
import 'package:tencent_cloud_chat_uikit/tencent_cloud_chat_uikit.dart';
import 'package:tencent_cloud_chat_uikit/ui/constants/history_message_constant.dart';
import 'package:tencent_cloud_chat_uikit/ui/utils/error_message_converter.dart';
import 'package:tencent_cloud_chat_uikit/ui/utils/chat_history_trace.dart';
import 'package:tencent_cloud_chat_uikit/ui/utils/chat_main_thread_perf.dart';
import 'package:tencent_cloud_chat_uikit/ui/utils/outgoing_visible_probe.dart';
import 'package:tencent_cloud_chat_uikit/ui/utils/history_pagination_anchor.dart';
import 'package:tencent_cloud_chat_uikit/ui/utils/chat_jitter_diag.dart';
import 'package:tencent_cloud_chat_uikit/ui/utils/regexp_probe.dart';
import 'package:tencent_cloud_chat_uikit/ui/utils/chat_media_send_utils.dart';
import 'package:tencent_cloud_chat_uikit/ui/utils/chat_media_gallery_expand.dart';
import 'package:tencent_cloud_chat_uikit/ui/utils/chat_message_height_cache.dart';
import 'package:tencent_cloud_chat_uikit/ui/utils/message_inbound_batch_coalescer.dart';
import 'package:tencent_cloud_chat_uikit/ui/utils/message_inbound_chunk_reveal.dart';
import 'package:tencent_cloud_chat_uikit/ui/widgets/chat_send_fly_overlay.dart';
import 'package:tencent_cloud_chat_uikit/ui/utils/logger.dart';
import 'package:tencent_cloud_chat_uikit/ui/utils/message.dart';

enum ConvType { none, c2c, group }

enum HistoryMessagePosition {
  bottom,
  inTwoScreen,
  awayTwoScreen,
  notShowLatest
}

/// 搜索跳转进会话时的加载/定位状态（供消息列表 UI 与 _loadData 共用）。
enum SearchJumpStatus {
  idle,
  loading,
  success,
  failed,
}

enum GroupSystemNoticeType {
  grantAdministrator,
  revokeAdministrator,
  transferOwner,
}

class GroupSystemNoticeItem {
  final String id;
  final String groupID;
  final String groupName;
  final String groupFaceUrl;
  final GroupSystemNoticeType type;
  final String operatorUserID;
  final String operatorName;
  final String targetUserID;
  final String targetName;
  final int timestamp;

  GroupSystemNoticeItem({
    required this.id,
    required this.groupID,
    required this.groupName,
    required this.groupFaceUrl,
    required this.type,
    required this.operatorUserID,
    required this.operatorName,
    required this.targetUserID,
    required this.targetName,
    required this.timestamp,
  });
}

class CurrentConversation {
  final String conversationID;
  final ConvType conversationType;

  CurrentConversation(this.conversationID, this.conversationType);
}

class AppContactPresenceBridge {
  final Listenable? presenceListenable;
  final MemberPresenceLabelBuilder? presenceLabelBuilder;
  final MemberPresenceLoadingChecker? presenceLoadingChecker;
  final MemberPresenceOnlineResolver? presenceOnlineResolver;
  final void Function(List<String> userIds)? onContactListLoaded;

  const AppContactPresenceBridge({
    this.presenceListenable,
    this.presenceLabelBuilder,
    this.presenceLoadingChecker,
    this.presenceOnlineResolver,
    this.onContactListLoaded,
  });
}

class _InboundUnreadState {
  int unreadCount = 0;
  int receivedCount = 0;
  int lockedEntryUnreadCount = 0;

  /// Frozen at open: first unread group seq for tip jump (survives mark-read).
  int lockedFirstUnreadSeq = 0;
  final List<V2TimMessage> bufferedMessages = <V2TimMessage>[];
  final Set<String> bufferedMessageKeys = <String>{};

  bool get isEmpty =>
      unreadCount == 0 &&
      receivedCount == 0 &&
      lockedEntryUnreadCount == 0 &&
      lockedFirstUnreadSeq == 0 &&
      bufferedMessages.isEmpty &&
      bufferedMessageKeys.isEmpty;

  void clear() {
    unreadCount = 0;
    receivedCount = 0;
    lockedEntryUnreadCount = 0;
    lockedFirstUnreadSeq = 0;
    bufferedMessages.clear();
    bufferedMessageKeys.clear();
  }
}

enum _HistoryConversationKind { c2c, group }

/// Viewport coordinates captured when a message context menu opens.
///
/// The scroll extent is not a sufficient anchor for a reverse chat list: the
/// unread center, time dividers, spacers, or a later row measurement can all
/// change the extent without preserving the selected row's screen position.
class MessageContextMenuViewportAnchor {
  const MessageContextMenuViewportAnchor({
    required this.identity,
    required this.seq,
    required this.viewportTop,
  });

  /// Message `msgID`, or the local id while an optimistic row has no server id.
  final String? identity;

  /// Sequence is a fallback for SDK rows whose identity changes during sync.
  final String? seq;

  /// Top edge of the selected row relative to the chat scroll viewport.
  final double viewportTop;
}

enum RowLocalMessageReplacementResult {
  replaced,
  stale,
  notFound,
  ambiguous,
  reordered,
  semanticChange,
}

/// Immutable synchronous snapshot produced by [TUIChatGlobalModel.setMessageList].
///
/// Callers that need post-commit state must consume this value instead of
/// sampling the mutable global maps again.
class MessageCommitResult {
  const MessageCommitResult({
    required this.conversationID,
    required this.token,
    required this.generation,
    required this.listRevision,
    required this.projectionRevision,
    required this.rawCount,
    required this.firstIdentity,
    required this.lastIdentity,
    required this.memoryWindowMissingNewer,
    required this.memoryWindowMissingOlder,
    required this.memoryWindowSuppressed,
    required this.unreadBufferedCount,
    required this.unreadProjectionHeld,
    required this.structureChanged,
    required this.contentChanged,
    this.writerRevision,
    this.writerGeneration,
    this.writerClearEpoch,
    this.writerOwnerUserID,
    this.writerAccountGeneration,
    this.writerDomainGeneration,
  });

  final String conversationID;
  final int token;
  final int generation;
  final int listRevision;
  final int projectionRevision;
  final int rawCount;
  final String? firstIdentity;
  final String? lastIdentity;
  final bool memoryWindowMissingNewer;
  final bool memoryWindowMissingOlder;
  final bool memoryWindowSuppressed;
  final int unreadBufferedCount;
  final bool unreadProjectionHeld;
  final bool structureChanged;
  final bool contentChanged;

  /// Revision and scope of the authoritative Message Writer commit that
  /// produced this UI snapshot. Null means this was a legacy direct snapshot.
  final int? writerRevision;
  final int? writerGeneration;
  final int? writerClearEpoch;
  final String? writerOwnerUserID;
  final int? writerAccountGeneration;
  final int? writerDomainGeneration;

  int? get commitRevision => writerRevision;

  /// Unified revision view for Writer-backed and legacy UI commits.
  int get revision => writerRevision ?? listRevision;
}

/// Diagnostic metadata for the last authoritative history commit.
///
/// This deliberately contains no message payload, credentials, or media URL.
class MessageHistoryCommitMetadata {
  const MessageHistoryCommitMetadata({
    required this.conversationKey,
    required this.source,
    required this.batchKind,
    required this.generation,
    required this.revision,
    required this.resultCount,
    required this.proofKind,
    required this.clearEpoch,
  });

  final String conversationKey;
  final MessageReconciliationSource source;
  final MessageHistoryBatchKind batchKind;
  final int generation;
  final int revision;
  final int resultCount;
  final MessageHistoryProofKind proofKind;
  bool get cloudProof => proofKind != MessageHistoryProofKind.none;
  bool get cloudTransportConfirmed => cloudProof;
  bool get serverContinuityProven =>
      proofKind == MessageHistoryProofKind.serverContinuity;
  final int clearEpoch;

  Map<String, Object?> toMetadataJson() => <String, Object?>{
        'conversationKey': conversationKey,
        'source': source.name,
        'batchKind': batchKind.name,
        'generation': generation,
        'revision': revision,
        'resultCount': resultCount,
        'proofKind': proofKind.name,
        'cloudProof': cloudProof,
        'cloudTransportConfirmed': cloudTransportConfirmed,
        'serverContinuityProven': serverContinuityProven,
        'clearEpoch': clearEpoch,
      };
}

class TUIChatGlobalModel extends ChangeNotifier implements TIMUIKitClass {
  static void Function(TUIChatGlobalModel model)? registerAppExtensions;

  static void ensureAppExtensionsRegistered() {
    setupServiceLocator();
    registerAppExtensions?.call(serviceLocator<TUIChatGlobalModel>());
  }

  final MessageService _messageService = serviceLocator<MessageService>();
  final GroupServices _groupServices = serviceLocator<GroupServices>();
  final ChatUiStateStore _chatUiStateStore = serviceLocator<ChatUiStateStore>();
  final Map<String, List<V2TimMessage>?> _messageListMap = {};
  final Map<String, MessageHistoryCommitMetadata>
      _lastHistoryCommitMetadataByConv =
      <String, MessageHistoryCommitMetadata>{};
  final MessageCommitCoordinator _messageCommitCoordinator =
      MessageCommitCoordinator();
  late final MessageReconciliationWriter<V2TimMessage>
      _messageReconciliationWriter = MessageReconciliationWriter<V2TimMessage>(
    comparator: (left, right) => compareMessagesChronological(
      right.value,
      left.value,
    ),
  );
  int _nextRealtimeReconciliationEvent = 0;

  /// App-owned connectivity bridge. UIKit does not import the host app's
  /// network services; when no provider is installed, reconciliation stays in
  /// the conservative `unknown` state and never claims cloud completeness.
  MessageReconciliationNetworkState Function()?
      appMessageReconciliationNetworkStateProvider;

  /// Host-app persistence for coverage metadata. UIKit owns the state shape,
  /// while the app owns the SQLite lifecycle and account scoping.
  MessageHistoryCoverageRepository? appMessageHistoryCoverageRepository;

  Future<MessageHistoryCoverage?> loadMessageHistoryCoverage(
    String conversationID,
  ) {
    final repository = appMessageHistoryCoverageRepository;
    return repository?.load(conversationID) ??
        Future<MessageHistoryCoverage?>.value();
  }

  Future<void> persistMessageHistoryCoverage(
    MessageHistoryCoverage coverage,
  ) async {
    await appMessageHistoryCoverageRepository?.save(coverage);
  }

  Future<void> clearMessageHistoryCoverage(
    String conversationID, {
    required bool isGroup,
    required int clearEpoch,
  }) async {
    await appMessageHistoryCoverageRepository?.clearConversation(
      conversationID,
      isGroup: isGroup,
      clearEpoch: clearEpoch,
    );
  }

  MessageReconciliationNetworkState get messageReconciliationNetworkState {
    try {
      return appMessageReconciliationNetworkStateProvider?.call() ??
          MessageReconciliationNetworkState.unknown;
    } catch (_) {
      return MessageReconciliationNetworkState.unknown;
    }
  }

  MessageReconciliationRecord<V2TimMessage> _reconciliationRecord(
    V2TimMessage message,
  ) {
    return MessageReconciliationRecord<V2TimMessage>(
      value: message,
      msgID: message.msgID,
      localID: message.id,
      outgoingStableID: readOutgoingStableId(message) ??
          (message.isSelf == true &&
                  ((message.msgID?.trim() ?? '').isEmpty ||
                      message.msgID?.trim() == message.id?.trim())
              ? message.id
              : null),
      seq: message.seq,
    );
  }

  MessageReconciliationRecord<V2TimMessage> messageDeltaRecord(
    V2TimMessage message,
  ) =>
      _reconciliationRecord(message);

  Iterable<MessageReconciliationRecord<V2TimMessage>> _reconciliationRecords(
      Iterable<V2TimMessage> messages) {
    return messages.map(_reconciliationRecord);
  }

  int messageDeltaGenerationFor(String conversationID) {
    final storageKey = _resolveMessageListStorageKey(conversationID);
    final key = storageKey.isEmpty ? conversationID.trim() : storageKey;
    if (key.isEmpty) return 0;
    return _messageReconciliationWriter.coordinator
        .stateFor(key)
        .requestGeneration;
  }

  int messageDeltaClearEpochFor(String conversationID) {
    final storageKey = _resolveMessageListStorageKey(conversationID);
    final key = storageKey.isEmpty ? conversationID.trim() : storageKey;
    return _messageHistoryCoverageByConv[key]?.clearEpoch ?? 0;
  }

  /// Supplies the account and SDK-session scope captured by app ingress.
  ///
  /// The UIKit model does not infer the logged-in account. The host app must
  /// call this at login/session ownership time so late events can be rejected
  /// by the single Writer.
  void configureMessageWriterScope({
    required String ownerUserID,
    required int accountGeneration,
    required int domainGeneration,
  }) {
    _messageReconciliationWriter.configureScope(
      MessageReconciliationWriterScope(
        ownerUserID: ownerUserID,
        accountGeneration: accountGeneration,
        domainGeneration: domainGeneration,
      ),
    );
  }

  void releaseMessageDeltaTombstones(
    String conversationID,
    Iterable<String> msgIDs,
  ) {
    final storageKey = _resolveMessageListStorageKey(conversationID);
    final key = storageKey.isEmpty ? conversationID.trim() : storageKey;
    if (key.isEmpty) return;
    _messageReconciliationWriter.releaseTombstones(key, msgIDs);
  }

  void restoreMessageDeltaAfterDeleteFailure(
    String conversationID,
    Iterable<V2TimMessage> messages,
  ) {
    final restored = messages.toList(growable: false);
    if (restored.isEmpty) return;
    final ids = restored
        .map((message) => message.msgID?.trim() ?? '')
        .where((id) => id.isNotEmpty)
        .toList(growable: false);
    releaseMessageDeltaTombstones(conversationID, ids);
    commitMessageDelta(
      MessageDelta<V2TimMessage>(
        conversationKey: conversationID,
        eventID:
            'delete_rollback:${ids.join(',')}:${DateTime.now().microsecondsSinceEpoch}',
        kind: MessageDeltaKind.optimisticAdoption,
        source: MessageDeltaSource.userAction,
        generation: messageDeltaGenerationFor(conversationID),
        clearEpoch: messageDeltaClearEpochFor(conversationID),
        upserts: _reconciliationRecords(restored),
      ),
    );
  }

  /// Authoritative boundary for realtime, optimistic, edit, revoke and delete.
  /// `setMessageList` remains the final UI projection writer, but no caller in
  /// these mutation paths decides merge/removal semantics independently.
  MessageCommitResult? commitMessageDelta(
    MessageDelta<V2TimMessage> delta, {
    bool applyMemoryWindow = true,
    bool memoryWindowPreferLatest = false,
  }) {
    final storageKey = _resolveMessageListStorageKey(delta.conversationKey);
    final key = storageKey.isEmpty ? delta.conversationKey.trim() : storageKey;
    if (key.isEmpty || delta.isSynthetic) return null;
    if (!_messageReconciliationWriter.hasActiveRequest(key)) {
      final current = _mergedAliasMessageList(key);
      _messageReconciliationWriter.seedAuthoritative(
        conversationID: key,
        records: _reconciliationRecords(current),
        trackSeqGaps: _isGroupConversation(key, messages: current),
        clearEpoch: delta.clearEpoch,
      );
    }
    final normalized = MessageDelta<V2TimMessage>(
      conversationKey: key,
      eventID: delta.eventID,
      kind: delta.kind,
      source: delta.source,
      generation: delta.generation,
      clearEpoch: delta.clearEpoch,
      ownerUserID: delta.ownerUserID,
      accountGeneration: delta.accountGeneration,
      domainGeneration: delta.domainGeneration,
      replace: delta.replace,
      upserts: delta.upserts,
      explicitDeletes: delta.explicitDeletes,
      tombstones: delta.tombstones,
    );
    final commit = _messageReconciliationWriter.applyDelta(normalized);
    if (commit == null) return null;
    return setMessageList(
      key,
      commit.records.map((record) => record.value).toList(growable: false),
      needResetNewMessageCount: false,
      replace: true,
      isDeleteMsg: delta.kind == MessageDeltaKind.delete,
      applyMemoryWindow: applyMemoryWindow,
      memoryWindowPreferLatest: memoryWindowPreferLatest,
      writerCommit: commit,
      historyCommitSource:
          'message_delta:${delta.kind.name}:r${commit.revision}',
    );
  }

  /// Starts one history transaction against the current authoritative window.
  /// Realtime callbacks are queued by the same writer until this generation
  /// either commits or fails, so an old history response cannot overwrite them.
  MessageReconciliationRequest beginHistoryReconciliation({
    required String conversationID,
    required MessageReconciliationSource requestedSource,
    required MessageReconciliationNetworkState networkState,
  }) {
    final storageKey = _resolveMessageListStorageKey(conversationID);
    final authoritative = _mergedAliasMessageList(storageKey);
    _messageReconciliationWriter.seedAuthoritative(
      conversationID: storageKey,
      records: _reconciliationRecords(authoritative),
      trackSeqGaps: _isGroupConversation(
        storageKey,
        messages: authoritative,
      ),
      clearEpoch: messageDeltaClearEpochFor(storageKey),
    );
    return _messageReconciliationWriter.beginInitialHistory(
      conversationID: storageKey,
      requestedSource: requestedSource,
      networkState: networkState,
      clearEpoch: messageDeltaClearEpochFor(storageKey),
    );
  }

  bool hasActiveHistoryReconciliation(String conversationID) {
    final storageKey = _resolveMessageListStorageKey(conversationID);
    final key = storageKey.isEmpty ? conversationID.trim() : storageKey;
    return key.isNotEmpty && _messageReconciliationWriter.hasActiveRequest(key);
  }

  MessageReconciliationState messageReconciliationStateFor(
    String conversationID,
  ) {
    final storageKey = _resolveMessageListStorageKey(conversationID);
    return _messageReconciliationWriter.coordinator.stateFor(
      storageKey.isEmpty ? conversationID : storageKey,
    );
  }

  MessageHistoryCommitMetadata? messageHistoryCommitMetadataFor(
    String conversationID,
  ) {
    final storageKey = _resolveMessageListStorageKey(conversationID);
    return _lastHistoryCommitMetadataByConv[
        storageKey.isEmpty ? conversationID.trim() : storageKey];
  }

  MessageCommitResult? completeHistoryReconciliation({
    required MessageReconciliationRequest request,
    required Iterable<V2TimMessage> history,
    required MessageReconciliationSource actualSource,
    required MessageReconciliationNetworkState networkState,
    bool applyMemoryWindow = true,
    bool memoryWindowPreferLatest = false,
    String historyCommitSource = 'reconciliation',
    bool cloudHasMoreNewer = false,
    MessageHistoryBatchKind batchKind = MessageHistoryBatchKind.olderPage,
    bool? historyIsFinished,
    int? clearEpoch,
    MessageHistoryCursor? requestedCursor,
    MessageHistoryBounds? returnedBounds,
    MessageHistoryProofKind? proofKind,
    bool? cloudResponseProven,
    Iterable<String> explicitDeletes = const <String>[],
    Iterable<String> tombstones = const <String>[],
  }) {
    // Include direct row-local/self-send commits made while the request was in
    // flight. Inbound callbacks are already held in pendingRealtime.
    final historyList = history.toList(growable: false);
    final effectiveClearEpoch =
        clearEpoch ?? messageDeltaClearEpochFor(request.conversationKey);
    final current = _mergedAliasMessageList(request.conversationKey);
    final authoritativeBase =
        batchKind == MessageHistoryBatchKind.latestWindow &&
                actualSource == MessageReconciliationSource.cloud
            ? _authoritativeBaseForCloudLatestWindow(
                conversationID: request.conversationKey,
                current: current,
                cloudWindow: historyList,
              )
            : current;
    final resolvedProofKind = proofKind ??
        (cloudResponseProven != null
            ? (cloudResponseProven
                ? MessageHistoryProofKind.transportObserved
                : MessageHistoryProofKind.none)
            : actualSource == MessageReconciliationSource.cloud &&
                    networkState == MessageReconciliationNetworkState.online
                ? MessageHistoryProofKind.transportObserved
                : MessageHistoryProofKind.none);
    final commit = _messageReconciliationWriter.completeHistory(
      request: request,
      history: _reconciliationRecords(historyList),
      authoritativeBase: _reconciliationRecords(authoritativeBase),
      actualSource: actualSource,
      networkState: networkState,
      clearEpoch: effectiveClearEpoch,
      cloudHasMoreNewer: cloudHasMoreNewer,
      batchKind: batchKind,
      proofKind: resolvedProofKind,
      historyIsFinished: historyIsFinished,
      explicitDeletes: explicitDeletes,
      tombstones: tombstones,
    );
    if (commit == null) {
      return null;
    }
    final result = setMessageList(
      commit.conversationKey,
      commit.records.map((record) => record.value).toList(growable: false),
      needResetNewMessageCount: false,
      replace: true,
      applyMemoryWindow: applyMemoryWindow,
      memoryWindowPreferLatest: memoryWindowPreferLatest,
      skipEquivalentHistoryWindow: true,
      writerCommit: commit,
      historyCommitSource: '$historyCommitSource:r${commit.revision}',
    );
    final resolvedMetadataKey =
        _resolveMessageListStorageKey(commit.conversationKey);
    final metadataKey = resolvedMetadataKey.isEmpty
        ? commit.conversationKey.trim()
        : resolvedMetadataKey;
    _lastHistoryCommitMetadataByConv[metadataKey] =
        MessageHistoryCommitMetadata(
      conversationKey: metadataKey,
      source: actualSource,
      batchKind: batchKind,
      generation: request.generation,
      revision: commit.revision,
      resultCount: result.rawCount,
      proofKind: resolvedProofKind,
      clearEpoch: effectiveClearEpoch,
    );
    _recordMessageHistoryCoverageAfterCommit(
      request: request,
      batchKind: batchKind,
      actualSource: actualSource,
      networkState: networkState,
      history: historyList,
      historyIsFinished: historyIsFinished,
      cloudHasMoreNewer: cloudHasMoreNewer,
      clearEpoch: effectiveClearEpoch,
      requestedCursor: requestedCursor,
      returnedBounds: returnedBounds,
      proofKind: resolvedProofKind,
    );
    unawaited(
      ImOutgoingSendCoordinator.instance
          .adoptProviderHistory(historyList)
          .catchError((Object error) {
        debugPrint(
          'OUTBOX_HISTORY_ADOPTION_FAILURE '
          'errorType=${error.runtimeType}',
        );
        return 0;
      }),
    );
    return result;
  }

  /// Commits a typed history envelope after validating its request generation
  /// and clear epoch. Transport provenance and continuity proof remain
  /// separate; an online response is not promoted to complete history.
  MessageCommitResult? completeHistoryBatch({
    required MessageReconciliationRequest request,
    required MessageHistoryBatch<V2TimMessage> batch,
    required MessageReconciliationNetworkState networkState,
    required int clearEpoch,
    bool applyMemoryWindow = true,
    bool memoryWindowPreferLatest = false,
    String historyCommitSource = 'reconciliation_batch',
  }) {
    final batchKey = batch.conversationKey.trim();
    final requestKey = request.conversationKey.trim();
    final sameConversation =
        isSameConversationIdForHistory(batchKey, requestKey);
    final stale = batch.isStale(
      generation: request.generation,
      clearEpoch: clearEpoch,
    );
    if (!sameConversation || stale) {
      ChatHistoryTrace.log(
        'history_batch_rejected',
        conversationID: requestKey,
        extras: <String, Object?>{
          'reason': !sameConversation ? 'conversation_mismatch' : 'stale',
          'batchKind': batch.batchKind.name,
          'requestGeneration': request.generation,
          'batchGeneration': batch.generation,
          'clearEpoch': clearEpoch,
          'batchClearEpoch': batch.clearEpoch,
        },
      );
      return null;
    }
    if (batchKey != requestKey) {
      ChatHistoryTrace.log(
        'history_batch_alias_accepted',
        conversationID: requestKey,
        extras: <String, Object?>{
          'batchKind': batch.batchKind.name,
          'requestGeneration': request.generation,
        },
      );
    }
    return completeHistoryReconciliation(
      request: request,
      history: batch.messages,
      actualSource: batch.actualSource,
      networkState: networkState,
      applyMemoryWindow: applyMemoryWindow,
      memoryWindowPreferLatest: memoryWindowPreferLatest,
      historyCommitSource: historyCommitSource,
      cloudHasMoreNewer: batch.cloudHasMoreNewer,
      batchKind: batch.batchKind,
      historyIsFinished: batch.isFinished,
      clearEpoch: clearEpoch,
      requestedCursor: batch.requestedCursor,
      returnedBounds: batch.returnedBounds,
      proofKind: batch.proofKind,
      explicitDeletes: batch.explicitDeletes,
      tombstones: batch.tombstones,
    );
  }

  List<V2TimMessage> _authoritativeBaseForCloudLatestWindow({
    required String conversationID,
    required List<V2TimMessage> current,
    required List<V2TimMessage> cloudWindow,
  }) {
    // A latest-window response proves only the bounded window it returned.
    // Absence from that page is not a delete/revoke proof, especially when the
    // SDK cloud request can fall back to local data. Keep every existing row;
    // explicit tombstones/revoke callbacks are the only removal authority.
    return current;
  }

  bool _groupWindowsOverlapOrTouch(
    List<V2TimMessage> first,
    List<V2TimMessage> second,
  ) {
    int? firstMin;
    int? firstMax;
    int? secondMin;
    int? secondMax;
    for (final message in first) {
      final seq = int.tryParse(message.seq?.trim() ?? '');
      if (seq == null || seq <= 0) continue;
      firstMin = firstMin == null || seq < firstMin ? seq : firstMin;
      firstMax = firstMax == null || seq > firstMax ? seq : firstMax;
    }
    for (final message in second) {
      final seq = int.tryParse(message.seq?.trim() ?? '');
      if (seq == null || seq <= 0) continue;
      secondMin = secondMin == null || seq < secondMin ? seq : secondMin;
      secondMax = secondMax == null || seq > secondMax ? seq : secondMax;
    }
    if (firstMin == null ||
        firstMax == null ||
        secondMin == null ||
        secondMax == null) {
      return false;
    }
    return firstMin <= secondMax + 1 && secondMin <= firstMax + 1;
  }

  void _recordMessageHistoryCoverageAfterCommit({
    required MessageReconciliationRequest request,
    required MessageHistoryBatchKind batchKind,
    required MessageReconciliationSource actualSource,
    required MessageReconciliationNetworkState networkState,
    required List<V2TimMessage> history,
    required bool? historyIsFinished,
    required bool cloudHasMoreNewer,
    required int clearEpoch,
    MessageHistoryCursor? requestedCursor,
    MessageHistoryBounds? returnedBounds,
    required MessageHistoryProofKind proofKind,
  }) {
    final storageKey = _resolveMessageListStorageKey(request.conversationKey);
    final key = storageKey.isEmpty ? request.conversationKey : storageKey;
    final coverageSessionGeneration = _messageHistoryCoverageSessionGeneration;
    final reconciliationState =
        _messageReconciliationWriter.coordinator.stateFor(key);
    final missingSeqRanges = List<MessageSeqRange>.unmodifiable(
      reconciliationState.missingSeqRanges,
    );
    final historySnapshot = List<V2TimMessage>.unmodifiable(history);

    void applyLoadedCoverage() {
      if (coverageSessionGeneration !=
          _messageHistoryCoverageSessionGeneration) {
        return;
      }
      final current = _messageHistoryCoverageByConv[key];
      if (current == null || current.clearEpoch != clearEpoch) return;
      final previousGeneration =
          _messageHistoryCoverageRequestGenerationByConv[key] ?? 0;
      if (request.generation <= previousGeneration) return;
      _messageHistoryCoverageRequestGenerationByConv[key] = request.generation;
      _applyMessageHistoryCoverageCommit(
        current: current,
        request: request,
        batchKind: batchKind,
        actualSource: actualSource,
        networkState: networkState,
        history: historySnapshot,
        historyIsFinished: historyIsFinished,
        cloudHasMoreNewer: cloudHasMoreNewer,
        missingSeqRanges: missingSeqRanges,
        requestedCursor: requestedCursor,
        returnedBounds: returnedBounds,
        proofKind: proofKind,
      );
    }

    if (_messageHistoryCoverageLoadedConvs.contains(key) &&
        !_messageHistoryCoverageUpdateTailByConv.containsKey(key)) {
      applyLoadedCoverage();
      return;
    }

    unawaited(
      _enqueueMessageHistoryCoverageUpdate(key, () async {
        await ensureMessageHistoryCoverageLoaded(key, clearEpoch: clearEpoch);
        applyLoadedCoverage();
      }),
    );
  }

  Future<void> _enqueueMessageHistoryCoverageUpdate(
    String conversationID,
    Future<void> Function() update,
  ) {
    final previous = _messageHistoryCoverageUpdateTailByConv[conversationID];
    late final Future<void> task;
    task = () async {
      if (previous != null) {
        try {
          await previous;
        } catch (_) {}
      }
      await update();
    }()
        .whenComplete(() {
      if (identical(
        _messageHistoryCoverageUpdateTailByConv[conversationID],
        task,
      )) {
        _messageHistoryCoverageUpdateTailByConv.remove(conversationID);
      }
    });
    _messageHistoryCoverageUpdateTailByConv[conversationID] = task;
    return task;
  }

  void _applyMessageHistoryCoverageCommit({
    required MessageHistoryCoverage current,
    required MessageReconciliationRequest request,
    required MessageHistoryBatchKind batchKind,
    required MessageReconciliationSource actualSource,
    required MessageReconciliationNetworkState networkState,
    required List<V2TimMessage> history,
    required bool? historyIsFinished,
    required bool cloudHasMoreNewer,
    required List<MessageSeqRange> missingSeqRanges,
    MessageHistoryCursor? requestedCursor,
    MessageHistoryBounds? returnedBounds,
    required MessageHistoryProofKind proofKind,
  }) {
    final now = DateTime.now().millisecondsSinceEpoch;
    final isGroup = current.isGroup ||
        _isGroupConversation(request.conversationKey, messages: history);
    final oldest = _oldestServerHistoryMessage(history);
    final newest = _newestServerHistoryMessage(history);
    final cloudTransportConfirmed =
        actualSource == MessageReconciliationSource.cloud &&
            proofKind != MessageHistoryProofKind.none;
    final serverContinuityProven =
        proofKind == MessageHistoryProofKind.serverContinuity;
    final holes = _coverageHolesForCommit(
      current: current,
      isGroup: isGroup,
      batchKind: batchKind,
      generation: request.generation,
      history: history,
      missingSeqRanges: missingSeqRanges,
      cloudProven: cloudTransportConfirmed,
      nowMs: now,
    );
    final nextNewerHasMore =
        batchKind == MessageHistoryBatchKind.latestWindow ||
                batchKind == MessageHistoryBatchKind.newerCatchUp
            ? cloudHasMoreNewer
            : current.newerHasMore;
    // An online transport response only proves that this bounded request
    // reached the server. It does not prove the conversation is continuous;
    // only an explicit server-continuity token may produce `verified`.
    final status = batchKind == MessageHistoryBatchKind.localSnapshot
        ? MessageHistoryCoverageStatus.provisional
        : !cloudTransportConfirmed
            ? MessageHistoryCoverageStatus.offlineLocalOnly
            : holes.isNotEmpty ||
                    nextNewerHasMore ||
                    historyIsFinished != true ||
                    !serverContinuityProven
                ? MessageHistoryCoverageStatus.partial
                : MessageHistoryCoverageStatus.verified;
    var next = current.copyWith(
      isGroup: isGroup,
      coverageRevision: current.coverageRevision + 1,
      status: status,
      holes: holes,
      newerHasMore: nextNewerHasMore,
      updatedAtMs: now,
      lastRequestGeneration: request.generation,
      lastRequestedSource: request.requestedSource.name,
      lastActualSource: actualSource.name,
      lastBatchKind: batchKind.name,
      lastCursorDirection: requestedCursor?.direction.name,
      lastCursorMsgID: requestedCursor?.lastMsgID,
      lastCursorSeq: requestedCursor?.lastMsgSeq,
      clearLastCursor: requestedCursor == null,
      lastReturnedOldestMsgID: returnedBounds?.oldestMsgID,
      lastReturnedNewestMsgID: returnedBounds?.newestMsgID,
      lastReturnedOldestSeq: returnedBounds?.oldestSeq,
      lastReturnedNewestSeq: returnedBounds?.newestSeq,
      clearLastReturnedBounds: returnedBounds == null,
      lastProofKind: proofKind,
      lastCloudResponseProven: cloudTransportConfirmed,
    );
    final direction = _coverageDirectionForBatch(batchKind);
    final boundedRange = _coverageRangeForCommit(
      direction: direction,
      isGroup: isGroup,
      returnedBounds: returnedBounds,
      history: history,
      proofKind: proofKind,
      closed: serverContinuityProven &&
          historyIsFinished == true &&
          !cloudHasMoreNewer &&
          holes.isEmpty,
      generation: request.generation,
      nowMs: now,
    );
    final page = MessageHistoryPageRecord(
      key:
          'p:${request.generation}:${direction.name}:${requestedCursor?.lastMsgID ?? ''}:${requestedCursor?.lastMsgSeq ?? ''}',
      direction: direction,
      cursorMsgID: requestedCursor?.lastMsgID,
      cursorSeq: requestedCursor?.lastMsgSeq,
      returnedOldestMsgID: returnedBounds?.oldestMsgID,
      returnedNewestMsgID: returnedBounds?.newestMsgID,
      returnedOldestSeq: returnedBounds?.oldestSeq,
      returnedNewestSeq: returnedBounds?.newestSeq,
      isFinished: historyIsFinished == true,
      hasMore: cloudHasMoreNewer || historyIsFinished != true,
      proofKind: proofKind,
      generation: request.generation,
      updatedAtMs: now,
    );
    final continuationPending = !serverContinuityProven ||
        cloudHasMoreNewer ||
        historyIsFinished != true ||
        holes.isNotEmpty;
    // Persist the cursor that can actually continue this page chain. A
    // requested cursor is the previous anchor; resuming must use the returned
    // boundary (oldest for older pages, newest for newer/latest windows).
    final continuationDirection = continuationPending
        ? cloudHasMoreNewer
            ? MessageHistoryCoverageDirection.newer
            : historyIsFinished == false
                ? MessageHistoryCoverageDirection.older
                : direction
        : null;
    final continuationCursorMsgID =
        continuationDirection == MessageHistoryCoverageDirection.older
            ? (returnedBounds?.oldestMsgID ?? oldest?.msgID)
            : (returnedBounds?.newestMsgID ?? newest?.msgID);
    final continuationCursorSeq =
        continuationDirection == MessageHistoryCoverageDirection.older
            ? (returnedBounds?.oldestSeq ?? _messageNumericSeq(oldest))
            : (returnedBounds?.newestSeq ?? _messageNumericSeq(newest));
    next = next.copyWith(
      ranges: _appendCoverageRange(current.ranges, boundedRange),
      pages: _appendCoveragePage(current.pages, page),
      continuationPending: continuationPending,
      continuationDirection: continuationDirection,
      clearContinuationDirection: !continuationPending,
      continuationCursorMsgID:
          continuationPending ? continuationCursorMsgID : null,
      continuationCursorSeq: continuationPending ? continuationCursorSeq : null,
      clearContinuationCursor: !continuationPending,
    );
    if (batchKind == MessageHistoryBatchKind.localSnapshot) {
      next = next.copyWith(
        localOldestMsgID: oldest?.msgID,
        localNewestMsgID: newest?.msgID,
      );
    } else if (cloudTransportConfirmed) {
      final updatesOldest = batchKind == MessageHistoryBatchKind.latestWindow ||
          batchKind == MessageHistoryBatchKind.olderPage;
      final updatesNewest = batchKind == MessageHistoryBatchKind.latestWindow ||
          batchKind == MessageHistoryBatchKind.newerCatchUp;
      next = next.copyWith(
        verifiedOldestMsgID:
            updatesOldest ? oldest?.msgID : current.verifiedOldestMsgID,
        verifiedNewestMsgID:
            updatesNewest ? newest?.msgID : current.verifiedNewestMsgID,
        verifiedOldestSeq: updatesOldest
            ? _messageNumericSeq(oldest)
            : current.verifiedOldestSeq,
        verifiedNewestSeq: updatesNewest
            ? _messageNumericSeq(newest)
            : current.verifiedNewestSeq,
        olderExhausted: batchKind == MessageHistoryBatchKind.olderPage ||
                batchKind == MessageHistoryBatchKind.latestWindow
            ? historyIsFinished == true
            : current.olderExhausted,
        cloudVerifiedAtMs: now,
      );
    }
    _storeMessageHistoryCoverage(next);
  }

  MessageHistoryCoverageDirection _coverageDirectionForBatch(
    MessageHistoryBatchKind batchKind,
  ) {
    switch (batchKind) {
      case MessageHistoryBatchKind.olderPage:
      case MessageHistoryBatchKind.gapFill:
        return MessageHistoryCoverageDirection.older;
      case MessageHistoryBatchKind.newerCatchUp:
        return MessageHistoryCoverageDirection.newer;
      case MessageHistoryBatchKind.localSnapshot:
      case MessageHistoryBatchKind.latestWindow:
        return MessageHistoryCoverageDirection.latest;
    }
  }

  MessageHistoryCoverageRange? _coverageRangeForCommit({
    required MessageHistoryCoverageDirection direction,
    required bool isGroup,
    required MessageHistoryBounds? returnedBounds,
    required List<V2TimMessage> history,
    required MessageHistoryProofKind proofKind,
    required bool closed,
    required int generation,
    required int nowMs,
  }) {
    final oldest = returnedBounds?.oldestMsgID ??
        _oldestServerHistoryMessage(history)?.msgID;
    final newest = returnedBounds?.newestMsgID ??
        _newestServerHistoryMessage(history)?.msgID;
    final oldestSeq = returnedBounds?.oldestSeq ??
        _messageNumericSeq(_oldestServerHistoryMessage(history));
    final newestSeq = returnedBounds?.newestSeq ??
        _messageNumericSeq(_newestServerHistoryMessage(history));
    if (isGroup && oldestSeq != null && newestSeq != null) {
      return MessageHistoryCoverageRange(
        key: 'seq:${direction.name}:$oldestSeq-$newestSeq',
        direction: direction,
        oldestMsgID: oldest,
        newestMsgID: newest,
        startSeq: oldestSeq,
        endSeq: newestSeq,
        proofKind: proofKind,
        closed: closed,
        generation: generation,
        updatedAtMs: nowMs,
      );
    }
    if (oldest == null && newest == null) return null;
    return MessageHistoryCoverageRange(
      key: 'page:${direction.name}:${oldest ?? ''}:$newest',
      direction: direction,
      oldestMsgID: oldest,
      newestMsgID: newest,
      proofKind: proofKind,
      closed: closed,
      generation: generation,
      updatedAtMs: nowMs,
    );
  }

  List<MessageHistoryCoverageRange> _appendCoverageRange(
    List<MessageHistoryCoverageRange> existing,
    MessageHistoryCoverageRange? incoming,
  ) {
    if (incoming == null) return existing;
    final next = <MessageHistoryCoverageRange>[
      ...existing.where((range) => range.key != incoming.key),
      incoming,
    ];
    next.sort((a, b) => a.updatedAtMs.compareTo(b.updatedAtMs));
    return List<MessageHistoryCoverageRange>.unmodifiable(
      next.length <= 64 ? next : next.sublist(next.length - 64),
    );
  }

  List<MessageHistoryPageRecord> _appendCoveragePage(
    List<MessageHistoryPageRecord> existing,
    MessageHistoryPageRecord incoming,
  ) {
    final next = <MessageHistoryPageRecord>[
      ...existing.where((page) => page.key != incoming.key),
      incoming,
    ];
    next.sort((a, b) => a.updatedAtMs.compareTo(b.updatedAtMs));
    return List<MessageHistoryPageRecord>.unmodifiable(
      next.length <= 64 ? next : next.sublist(next.length - 64),
    );
  }

  List<MessageHistoryHole> _coverageHolesForCommit({
    required MessageHistoryCoverage current,
    required bool isGroup,
    required MessageHistoryBatchKind batchKind,
    required int generation,
    required List<V2TimMessage> history,
    required List<MessageSeqRange> missingSeqRanges,
    required bool cloudProven,
    required int nowMs,
  }) {
    if (isGroup) {
      if (batchKind == MessageHistoryBatchKind.gapFill &&
          missingSeqRanges.isEmpty) {
        // The merged authoritative window is now Seq-contiguous. Retain
        // unrelated hole kinds, but retire the group Seq holes that this
        // gap-fill request was responsible for repairing.
        return current.holes
            .where((hole) => hole.kind != MessageHistoryHoleKind.groupSeq)
            .toList(growable: false);
      }
      if (missingSeqRanges.isEmpty &&
          batchKind != MessageHistoryBatchKind.gapFill) {
        // A bounded newer/older page can be disjoint from a previously
        // recorded hole. Do not erase that durable gap merely because this
        // writer generation did not carry both Seq anchors.
        return current.holes
            .where((hole) => hole.kind == MessageHistoryHoleKind.groupSeq)
            .toList(growable: false);
      }
      final status = batchKind == MessageHistoryBatchKind.gapFill
          ? cloudProven
              ? MessageHistoryHoleStatus.retryable
              : MessageHistoryHoleStatus.cloudUnavailable
          : MessageHistoryHoleStatus.open;
      return missingSeqRanges
          .map(
            (range) => MessageHistoryHole(
              key: 'seq:${range.start}-${range.end}',
              kind: MessageHistoryHoleKind.groupSeq,
              status: status,
              startSeq: range.start,
              endSeq: range.end,
              generation: generation,
              updatedAtMs: nowMs,
            ),
          )
          .toList(growable: false);
    }
    final nonBoundaryHoles = current.holes
        .where((hole) => hole.kind != MessageHistoryHoleKind.c2cBoundary)
        .toList(growable: true);
    if (batchKind == MessageHistoryBatchKind.localSnapshot) {
      return nonBoundaryHoles;
    }
    final historyIDs = <String>{
      for (final message in history)
        if ((message.msgID?.trim() ?? '').isNotEmpty) message.msgID!.trim(),
    };
    final overlaps = historyIDs.contains(current.localOldestMsgID) ||
        historyIDs.contains(current.localNewestMsgID);
    if (overlaps) {
      return nonBoundaryHoles;
    }
    final existingBoundaryStatus = !cloudProven
        ? MessageHistoryHoleStatus.cloudUnavailable
        : batchKind == MessageHistoryBatchKind.latestWindow
            ? MessageHistoryHoleStatus.open
            : MessageHistoryHoleStatus.retryable;
    final existingBoundaryHoles = current.holes
        .where((hole) => hole.kind == MessageHistoryHoleKind.c2cBoundary)
        .where(
          (hole) => !historyIDs.contains(hole.olderMsgID),
        )
        .map(
          (hole) => MessageHistoryHole(
            key: hole.key,
            kind: hole.kind,
            status: existingBoundaryStatus,
            startSeq: hole.startSeq,
            endSeq: hole.endSeq,
            olderMsgID: hole.olderMsgID,
            newerMsgID: hole.newerMsgID,
            generation: generation,
            updatedAtMs: nowMs,
          ),
        )
        .toList(growable: false);
    if (batchKind != MessageHistoryBatchKind.latestWindow ||
        current.status != MessageHistoryCoverageStatus.provisional ||
        history.isEmpty ||
        current.localNewestMsgID == null) {
      return <MessageHistoryHole>[
        ...nonBoundaryHoles,
        ...existingBoundaryHoles,
      ];
    }
    final oldest = _oldestServerHistoryMessage(history);
    return <MessageHistoryHole>[
      ...nonBoundaryHoles,
      MessageHistoryHole(
        key: 'c2c:${current.localNewestMsgID}:${oldest?.msgID ?? ''}',
        kind: MessageHistoryHoleKind.c2cBoundary,
        status: cloudProven
            ? MessageHistoryHoleStatus.open
            : MessageHistoryHoleStatus.cloudUnavailable,
        olderMsgID: current.localNewestMsgID,
        newerMsgID: oldest?.msgID,
        generation: generation,
        updatedAtMs: nowMs,
      ),
    ];
  }

  V2TimMessage? _oldestServerHistoryMessage(List<V2TimMessage> messages) {
    V2TimMessage? result;
    for (final message in messages) {
      if ((message.msgID?.trim() ?? '').isEmpty) continue;
      if (result == null || compareMessagesChronological(message, result) < 0) {
        result = message;
      }
    }
    return result;
  }

  V2TimMessage? _newestServerHistoryMessage(List<V2TimMessage> messages) {
    V2TimMessage? result;
    for (final message in messages) {
      if ((message.msgID?.trim() ?? '').isEmpty) continue;
      if (result == null || compareMessagesChronological(message, result) > 0) {
        result = message;
      }
    }
    return result;
  }

  int? _messageNumericSeq(V2TimMessage? message) {
    final seq = int.tryParse(message?.seq?.trim() ?? '');
    return seq == null || seq <= 0 ? null : seq;
  }

  MessageCommitResult? failHistoryReconciliation({
    required MessageReconciliationRequest request,
    required String reason,
  }) {
    final commit = _messageReconciliationWriter.failHistory(
      request: request,
      reason: reason,
      networkState: messageReconciliationNetworkState,
    );
    if (commit == null) {
      return null;
    }
    return setMessageList(
      commit.conversationKey,
      commit.records.map((record) => record.value).toList(growable: false),
      needResetNewMessageCount: false,
      replace: true,
      applyMemoryWindow: false,
      writerCommit: commit,
      historyCommitSource: 'reconciliation_fail:r${commit.revision}',
    );
  }

  final Map<String, int> _messageCommitGenerationByConv = {};
  final Map<String, int> _messageCommitTokenByConv = {};
  int _nextMessageCommitToken = 0;

  /// 内存窗口裁掉了较新端：下翻/回底需能再 loadLatest。
  final Map<String, bool> _memoryWindowMissingNewerByConv = {};
  final Map<String, Map<String, String>> _rowLocalAliasByConversation = {};
  final Map<String, bool> _memoryWindowMissingOlderByConv = {};
  final Map<String, int> _memoryWindowBoundaryTimestampByConv = {};
  final Map<String, String> _memoryWindowBoundarySeqByConv = {};

  /// 搜索/引用定位拉历史期间抑制窗口，避免目标被 trim 掉。
  final Set<String> _memoryWindowSuppressedConvs = {};
  String? _memoryWindowAnchorMsgID;
  String? _memoryWindowAnchorSeq;
  String? _memoryWindowAnchorConvID;
  final Map<String, SearchJumpStatus> _searchJumpStatusMap = {};
  final Map<String, List<V2TimMessage>> _localMergerMessageCache = {};
  final Set<String> _initialHistoryLoadedConvs = {};
  final Map<String, bool> _mayHaveOlderHistoryByConv = {};
  final Map<String, MessageHistoryCoverage> _messageHistoryCoverageByConv =
      <String, MessageHistoryCoverage>{};
  final Set<String> _messageHistoryCoverageLoadedConvs = <String>{};
  final Map<String, Future<MessageHistoryCoverage?>>
      _messageHistoryCoverageLoadInFlight =
      <String, Future<MessageHistoryCoverage?>>{};
  final Map<String, Future<void>> _messageHistoryCoverageUpdateTailByConv =
      <String, Future<void>>{};
  final Map<String, int> _messageHistoryCoverageRequestGenerationByConv =
      <String, int>{};
  int _messageHistoryCoverageSessionGeneration = 0;

  bool _isMessageLifecycleCurrent(int generation) {
    return generation == _messageHistoryCoverageSessionGeneration;
  }

  final Map<String, Future<void>> _openHydrateInFlightByConv = {};
  final Map<String, OpenHydrateResult> _openHydrateResultByConv =
      <String, OpenHydrateResult>{};
  final Map<String, V2TimMessageReceipt> _messageReadReceiptMap = {};
  final Map<String, int> _c2cPeerReadTimestampMap = {};
  final Map<String, int> _messageListProgressMap = {};
  final Map<String, String> _fileListLocationMap = {};
  final Map<String, Size> _fileMessageSizeMap = {};
  final Set<String> _cancelledOutgoingMediaIds = <String>{};
  final Map<String, dynamic> _preloadImageMap = {};
  final Map<String, HistoryMessagePosition> _historyMessagePositionMap = {};
  final List<CurrentConversation> _currentConversationList = [];
  final List<VoidCallback> _roamingSyncListeners = <VoidCallback>[];

  Map<String, dynamic> get preloadImageMap => _preloadImageMap;

  ChatLifeCycle? _lifeCycle;
  bool _isDownloading = false;
  final List<Map<String, String>> _waitingDownloadList =
      List.empty(growable: true); // example {"savePath":"","url":"",msgId:""}
  int _totalUnreadCount = 0;
  String localKeyPrefix = "TUIKit_conversation_stored_";
  String localMsgIDListKey = "TUIKit_conversation_list";

  late V2TimAdvancedMsgListener advancedMsgListener;
  final Map<String, _InboundUnreadState> _inboundUnreadStateByConversation =
      <String, _InboundUnreadState>{};
  final Map<String, int> _unreadTongueRemainingByConversation = {};
  final Map<String, bool> _unreadTongueBelowByConversation = {};
  final Map<String, int> _dismissedEntryUnreadTongueCountByConversation = {};
  int _unreadTongueMetricsVersion = 0;

  // use for generate a new sliver list to show received message list
  final Set<String> _deferredUntilUserBottomConversations = <String>{};

  TIMUIKitChatConfig chatConfig = const TIMUIKitChatConfig();
  List<V2TimGroupApplication>? _groupApplicationList;
  DateTime? _lastGroupApplicationRefreshAt;
  Future<void>? _groupApplicationRefreshTask;
  Timer? _pendingGroupApplicationRefreshTimer;
  static const Duration _groupApplicationRefreshInterval =
      Duration(seconds: 20);
  List<GroupSystemNoticeItem> _groupSystemNoticeList = [];
  String Function(V2TimMessage message)? _abstractMessageBuilder;
  Widget Function(
    BuildContext context,
    TextEditingController controller,
    ValueChanged<String> onChanged,
  )? _appSearchBarBuilder;
  Widget Function(BuildContext context)? _appForwardSelectFriendPage;
  Widget Function(BuildContext context)? _appForwardSelectGroupPage;
  NavigatorState? Function()? _appRootNavigator;
  AppContactPresenceBridge Function(BuildContext context)?
      _appContactPresenceBridgeBuilder;
  final Map<String, int> _c2cMessageEditStatusMap =
      Map.from({}); // 0 normal 1 sending
  final Map<String, bool> _c2cMessageFromUserActiveMap = Map.from({});
  final Map<String, Timer> _c2cMessageActiveTimer = Map.from({});
  bool _showC2cMessageEditStatus = true;
  final Map<String, Timer> _c2cMessageStatusShowTimer = Map.from({});
  Map<String, List> loadingMessage = {};
  final Set<String> _messageEnterAnimationKeys = <String>{};
  final Map<String, int> _enterAnimationThrottleMarkMsByConv = <String, int>{};
  final Map<String, String> _enterAnimationThrottlePendingKeyByConv =
      <String, String>{};
  ChatSendFlyOverlayRequest? _sendFlyOverlayRequest;
  final Map<String, ScrollController> _activeChatScrollControllerMap = {};
  final Map<String, double> _mediaPreviewScrollOffsetMap = {};
  final Map<String, String> _mediaPreviewAnchorMsgIDMap = {};
  static const int _mediaPreviewRestoreLockMilliseconds = 300;
  static const int _mediaPreviewRestoreTailLockMilliseconds = 80;
  bool _isMediaPreviewOverlayOpen = false;
  int _walletOverlayDepth = 0;
  bool _isRestoringScrollAfterMediaPreview = false;
  int _mediaPreviewRestoreVersion = 0;
  int _mediaPreviewRestoreLockUntil = 0;
  int _outgoingPinScrollSuppressUntilMs = 0;
  bool _isChatListUserScrolling = false;
  int _lastChatListUserScrollEndAtMs = 0;
  int _chatOpenImageDecodeDeferUntilMs = 0;

  /// ScrollEnd 后短窗口：跳过入场动画，避免松手瞬间与灌消息叠峰。
  static const int postScrollSkipEnterAnimationMs = 300;

  /// 进页首屏：短暂压低气泡解码上限，削多图同屏尖刺。
  static const Duration chatOpenImageDecodeDeferTtl =
      Duration(milliseconds: 700);

  /// 松手后防抖 flush 时，缓冲条数达此阈值则走分片揭示，避免一次灌爆。
  static const int postScrollFlushChunkThreshold = 8;

  /// Open chat page SSOT for scroll UI (wired from [ChatPageUiNotifiers]).
  ValueNotifier<HistoryMessagePosition>? _openPageHistoryPosition;
  ValueNotifier<bool>? _openPageUserScrolling;
  String? _openPageConvId;
  final Map<String, int> _messageListRevisionByConv = {};
  final Map<String, int> _messageProjectionRevisionByConv = {};
  final Map<String, Set<String>> _inboundHiddenKeysByConv = {};
  final Set<String> _authoritativeDeferredIncomingKeys = <String>{};
  final Set<String> _inboundFastForwardMessageKeys = <String>{};
  final Map<String, int> _outgoingLocalSeqByConv = {};
  final Map<String, List<V2TimMessage>> _messageListDisplayCache = {};
  final Map<String, Timer> _activeReadReportDebounceMap = {};
  final Map<String, int> _lastActiveReadReportAtMs = {};
  static const int _activeReadReportDebounceMs = 1200;
  static const int _activeReadReportMinIntervalMs = 3000;
  bool _notifyPending = false;
  bool _notifyScheduled = false;
  static const int _inboundBatchMaxSize = 50;
  static const Duration _inboundBatchMaxDelay = Duration(milliseconds: 50);
  static const int _bulkMessageSyncThreshold = 2;

  /// 1s 内到达条数达到该阈值 → 洪峰：关入场动画 / 关分片揭示 / 整批提交。
  static const int _inboundFloodWindowMs = 1000;
  static const int _inboundFloodCountThreshold = 8;

  /// 单次 coalesce flush 达到该条数也视为洪峰（群刷屏一批）。
  static const int _inboundFloodBatchSizeThreshold = 6;
  final List<int> _inboundFloodArrivalMs = <int>[];
  late final MessageInboundBatchCoalescer _inboundBatchCoalescer;
  late final MessageInboundChunkedReveal _inboundChunkReveal;
  final Map<String, InboundReorderBuffer> _reorderBuffersByConv =
      <String, InboundReorderBuffer>{};
  final Set<String> _gapCatchUpInFlight = <String>{};
  final Map<String, int> _groupGapAutoAttemptAtMs = <String, int>{};
  static const int _groupGapAutoCooldownMs = 5000;
  final BoundedMessageCloudCatchUp _boundedCloudCatchUp =
      BoundedMessageCloudCatchUp();
  final Map<String, int> _cloudContinuationRoundsByConv = <String, int>{};
  final Map<String, Timer> _cloudContinuationTimersByConv = <String, Timer>{};

  /// C2C has no conversation-wide seq cursor. Keep the last stalled anchor so
  /// an automatic continuation cannot replay the same CLOUD_NEWER request.
  final Map<String, String> _cloudCatchUpStalledAnchorByConv =
      <String, String>{};
  static const String _cloudCatchUpStalledBatchKind = 'cloud_catch_up_stalled';
  static const String _cloudCatchUpUnblockedBatchKind =
      'cloud_catch_up_unblocked';
  static const int _maxAutomaticCloudContinuationRounds = 2;
  static const Duration _cloudContinuationDelay = Duration(milliseconds: 600);
  final Map<String, int> _bulkMessageSyncDepthByConv = <String, int>{};
  final Map<String, bool> _pendingPinAfterBulkByConv = <String, bool>{};
  int _inboundScrollFollowSeq = 0;
  int _inboundPresentationSupersedeSeq = 0;
  bool _inboundScrollFollowSessionEnding = false;
  List<V2TimMessage> _lastInboundScrollFollowChunk = const [];
  bool _chatAppForeground = true;
  final Map<String, bool> _wasAtBottomBeforeBackgroundByConv = <String, bool>{};
  final Map<String, bool> _wasAtBottomBeforeKeyboardViewportChangeByConv =
      <String, bool>{};
  final Map<String, Timer> _keyboardViewportSettleTimersByConv =
      <String, Timer>{};
  static const Duration _keyboardViewportSettleDelay =
      Duration(milliseconds: 220);
  int _suppressInboundAnimationUntilMs = 0;
  final Set<String> _inactiveInboundDirtyConvs = <String>{};
  Timer? _inactiveInboundNotifyTimer;
  static const Duration _inactiveInboundNotifyDelayIdle =
      Duration(milliseconds: 80);
  static const Duration _inactiveInboundNotifyDelayFlood =
      Duration(milliseconds: 250);

  bool get isChatListUserScrolling =>
      _openPageUserScrolling?.value ?? _isChatListUserScrolling;

  /// 键盘动画会短暂改变列表 viewport，导致原本贴底的会话被误判为
  /// "正在看历史"。保留动画开始前的贴底快照，直至几何稳定。
  void beginKeyboardViewportTransition(String conversationID) {
    final convId = _safeConversationId(conversationID);
    if (convId.isEmpty || !_isSameConversationID(convId, currentSelectedConv)) {
      return;
    }
    final key = _inboundStateKey(convId);
    _wasAtBottomBeforeKeyboardViewportChangeByConv.putIfAbsent(
      key,
      () => _isActiveChatNearBottom(convId),
    );
    _keyboardViewportSettleTimersByConv.remove(key)?.cancel();
    _keyboardViewportSettleTimersByConv[key] = Timer(
      _keyboardViewportSettleDelay,
      () => _finishKeyboardViewportTransition(convId),
    );
  }

  bool _wasAtBottomBeforeKeyboardViewportChange(String conversationID) {
    return _wasAtBottomBeforeKeyboardViewportChangeByConv[
            _inboundStateKey(conversationID)] ==
        true;
  }

  void _finishKeyboardViewportTransition(String conversationID) {
    final key = _inboundStateKey(conversationID);
    _keyboardViewportSettleTimersByConv.remove(key);
    final wasAtBottom =
        _wasAtBottomBeforeKeyboardViewportChangeByConv.remove(key) == true;
    if (!wasAtBottom ||
        !_isSameConversationID(conversationID, currentSelectedConv)) {
      return;
    }
    // 键盘稳定后，贴底会话不应继续保留因 transient viewport 导致的
    // inbound buffer / hidden projection；直接提交即可，不必等退出重进。
    flushDeferredIncomingMessages(
      conversationID,
      notify: false,
      userInitiated: true,
    );
    _storeHistoryMessagePosition(conversationID, HistoryMessagePosition.bottom);
    requestPinToBottom(conversationID);
    _markNeedsNotify();
  }

  void _clearKeyboardViewportTransition(String conversationID) {
    final key = _inboundStateKey(conversationID);
    _keyboardViewportSettleTimersByConv.remove(key)?.cancel();
    _wasAtBottomBeforeKeyboardViewportChangeByConv.remove(key);
  }

  /// 进页揭开后短窗口：列表气泡走 scroll-tier 解码预算。
  void beginChatOpenImageDecodeDefer({
    Duration ttl = chatOpenImageDecodeDeferTtl,
  }) {
    final until = DateTime.now().millisecondsSinceEpoch + ttl.inMilliseconds;
    if (until > _chatOpenImageDecodeDeferUntilMs) {
      _chatOpenImageDecodeDeferUntilMs = until;
    }
  }

  bool get isChatOpenImageDecodeDeferActive {
    if (_chatOpenImageDecodeDeferUntilMs <= 0) {
      return false;
    }
    final now = DateTime.now().millisecondsSinceEpoch;
    if (now >= _chatOpenImageDecodeDeferUntilMs) {
      _chatOpenImageDecodeDeferUntilMs = 0;
      return false;
    }
    return true;
  }

  /// 用户正在滑，或刚松手后的短窗口（用于跳过进场动画等）。
  bool get shouldSkipHeavyChatListPresentation {
    if (isChatOpenImageDecodeDeferActive) {
      return true;
    }
    if (isChatListUserScrolling) {
      return true;
    }
    if (_lastChatListUserScrollEndAtMs <= 0) {
      return _shouldDeferHeavyBubbleDecodeForAndroidHistory();
    }
    final elapsed =
        DateTime.now().millisecondsSinceEpoch - _lastChatListUserScrollEndAtMs;
    if (elapsed >= 0 && elapsed < postScrollSkipEnterAnimationMs) {
      return true;
    }
    return _shouldDeferHeavyBubbleDecodeForAndroidHistory();
  }

  bool _shouldDeferHeavyBubbleDecodeForAndroidHistory() {
    if (kIsWeb || !Platform.isAndroid) {
      return false;
    }
    final convId = currentSelectedConv.trim();
    if (convId.isEmpty) {
      return false;
    }
    if (isReadingHistory(convId)) {
      return true;
    }
    // 不在底部时推迟离屏图片解码，避免浏览历史/未读时主线程尖刺。
    return !_isActiveChatNearBottom(convId);
  }

  int deferredIncomingBufferedCount(String conversationID) {
    return _inboundUnreadStateFor(
      conversationID,
      create: false,
    ).bufferedMessages.length;
  }

  /// 后台期间缓冲、尚未合并进可见列表的新消息（含 deferred 闸门）。
  bool hasDeferredIncomingForResume(String? conversationID) {
    final convId = _safeConversationId(conversationID ?? currentSelectedConv);
    if (convId.isEmpty) {
      return false;
    }
    for (final key in _historyFlagKeys(convId)) {
      final normalized = _inboundStateKey(key);
      if (_deferredUntilUserBottomConversations.contains(normalized)) {
        return true;
      }
      if (deferredIncomingBufferedCount(key) > 0) {
        return true;
      }
    }
    return false;
  }

  /// 回前台：贴底会话合并后台缓冲；读历史则保留 buffer，交给历史补拉。
  void reconcileActiveChatAfterForegroundResume({int attempt = 0}) {
    final convId = currentSelectedConv.trim();
    if (convId.isEmpty || !_chatAppForeground) {
      return;
    }
    if (!hasDeferredIncomingForResume(convId)) {
      return;
    }
    final normalizedConvId = _inboundStateKey(convId);
    final wasAtBottomBeforeBackground =
        _wasAtBottomBeforeBackgroundByConv[normalizedConvId];
    final nearBottom = _isActiveChatNearBottom(convId);
    final awayOneScreen = _isActiveChatAwayOneScreen(convId);
    final controller = _activeChatScrollControllerMap[convId];
    final scrollReady = controller != null &&
        controller.hasClients &&
        controller.positions.isNotEmpty;
    if (wasAtBottomBeforeBackground == null && !scrollReady && attempt < 3) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        reconcileActiveChatAfterForegroundResume(attempt: attempt + 1);
      });
      return;
    }
    final shouldKeepBuffered = wasAtBottomBeforeBackground == false ||
        (wasAtBottomBeforeBackground == null && !nearBottom && awayOneScreen);
    if (shouldKeepBuffered) {
      ChatJitterDiag.logInboundFlow(
        action: 'resume_reconcile_keep_buffer',
        conv: convId,
        extras: <String, Object?>{
          'buffered': deferredIncomingBufferedCount(convId),
          'attempt': attempt,
          'wasAtBottomBeforeBackground': wasAtBottomBeforeBackground,
        },
      );
      return;
    }
    _mergeDeferredIncomingAfterBackgroundResume(convId);
    _wasAtBottomBeforeBackgroundByConv.remove(normalizedConvId);
  }

  void _mergeDeferredIncomingAfterBackgroundResume(String conversationID) {
    final convId = _safeConversationId(conversationID);
    if (convId.isEmpty) {
      return;
    }
    for (final key in _historyFlagKeys(convId)) {
      _deferredUntilUserBottomConversations.remove(_inboundStateKey(key));
    }
    _storeHistoryMessagePosition(convId, HistoryMessagePosition.bottom);
    flushDeferredIncomingMessages(
      convId,
      notify: false,
      userInitiated: true,
    );
    unlockEntryUnreadForTongue(
      conversationID: convId,
      notify: false,
    );
    clearReceivedUnreadState(
      conversationID: convId,
      notify: false,
    );
    ChatJitterDiag.logInboundFlow(
      action: 'resume_reconcile_merged',
      conv: convId,
      extras: <String, Object?>{
        'listLen':
            _messageListMap[_resolveMessageListStorageKey(convId)]?.length,
      },
    );
    _markNeedsNotify();
  }

  void _pruneInboundFloodWindow([int? nowMs]) {
    final now = nowMs ?? DateTime.now().millisecondsSinceEpoch;
    _inboundFloodArrivalMs.removeWhere((t) => now - t > _inboundFloodWindowMs);
  }

  void _noteInboundFloodArrivals(int count) {
    if (count <= 0) {
      return;
    }
    final now = DateTime.now().millisecondsSinceEpoch;
    for (var i = 0; i < count; i++) {
      _inboundFloodArrivalMs.add(now);
    }
    if (_inboundFloodArrivalMs.length > 96) {
      _inboundFloodArrivalMs.removeRange(
        0,
        _inboundFloodArrivalMs.length - 96,
      );
    }
    _pruneInboundFloodWindow(now);
  }

  /// 消息洪峰：短时高频入站，动画与分片揭示应让路给吞吐。
  bool get isInboundFloodActive {
    _pruneInboundFloodWindow();
    return _inboundFloodArrivalMs.length >= _inboundFloodCountThreshold;
  }

  /// Bind the open history list's page UI notifiers as SSOT for scroll flags.
  void attachOpenChatPageUi({
    required String conversationId,
    required ValueNotifier<HistoryMessagePosition> historyPosition,
    required ValueNotifier<bool> userScrolling,
  }) {
    final convId = _safeConversationId(conversationId);
    _openPageConvId = convId;
    _openPageHistoryPosition = historyPosition;
    _openPageUserScrolling = userScrolling;
    final seeded =
        _historyMessagePositionMap[convId] ?? HistoryMessagePosition.bottom;
    if (historyPosition.value != seeded) {
      historyPosition.value = seeded;
    }
    userScrolling.value = false;
    _isChatListUserScrolling = false;
  }

  void detachOpenChatPageUi({
    required ValueNotifier<HistoryMessagePosition> historyPosition,
    required ValueNotifier<bool> userScrolling,
  }) {
    if (!identical(_openPageHistoryPosition, historyPosition)) {
      return;
    }
    final convId = _openPageConvId;
    if (convId != null && convId.isNotEmpty) {
      _historyMessagePositionMap[convId] = historyPosition.value;
    }
    _openPageHistoryPosition = null;
    _openPageUserScrolling = null;
    _openPageConvId = null;
    _isChatListUserScrolling = false;
  }

  void _storeHistoryMessagePosition(
    String conversationID,
    HistoryMessagePosition position,
  ) {
    final convId = _safeConversationId(conversationID);
    if (convId.isEmpty) {
      return;
    }
    _historyMessagePositionMap[convId] = position;
    final page = _openPageHistoryPosition;
    final pageConv = _openPageConvId;
    if (page != null &&
        pageConv != null &&
        _isSameConversationID(convId, pageConv) &&
        page.value != position) {
      page.value = position;
    }
    if (position == HistoryMessagePosition.bottom) {
      final state = _messageReconciliationWriter.coordinator.stateFor(convId);
      if (state.cloudHasMoreNewer) {
        _scheduleCloudContinuation(convId);
      }
    }
  }

  bool get shouldAnimateInboundPresentation =>
      _chatAppForeground &&
      DateTime.now().millisecondsSinceEpoch >=
          _suppressInboundAnimationUntilMs &&
      !isInboundFloodActive;

  void setChatAppLifecycleState(AppLifecycleState state) {
    final wasForeground = _chatAppForeground;
    final foreground = state == AppLifecycleState.resumed;
    final convId = currentSelectedConv.trim();
    if (wasForeground && !foreground && convId.isNotEmpty) {
      _syncHistoryPositionFromActiveScroll(convId);
      final normalizedConvId = _inboundStateKey(convId);
      final logicalPosition = getMessageListPosition(convId);
      _wasAtBottomBeforeBackgroundByConv[normalizedConvId] =
          _isActiveChatNearBottom(convId) ||
              logicalPosition == HistoryMessagePosition.bottom;
    }
    _chatAppForeground = foreground;
    if (foreground && !wasForeground) {
      // Resume recovery may merge a large server-side backlog over several
      // asynchronous callbacks. Treat that window as synchronization, not as
      // a sequence of newly arriving foreground messages.
      _suppressInboundAnimationUntilMs =
          DateTime.now().millisecondsSinceEpoch + 5000;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        reconcileActiveChatAfterForegroundResume();
        if (convId.isNotEmpty) {
          unawaited(
            reconcileConversationCloud(
              convId,
              reason: 'app_foreground',
            ),
          );
        }
      });
    }

    if (convId.isNotEmpty && !foreground) {
      // Rows not yet presented stay deferred. Do not reveal the queue while
      // transitioning to background, otherwise it will be replayed on resume.
      _inboundChunkReveal.cancelToBuffer(convId);
    }
    _messageEnterAnimationKeys.clear();
    // paused/hidden 阶段不重建仍在树上的长消息列表；resumed 会统一通知。
    if (foreground) {
      _markNeedsNotify();
    }
  }

  bool isBulkMessageSyncActive([String? conversationID]) {
    if (conversationID != null) {
      final convId = _safeConversationId(conversationID);
      return (_bulkMessageSyncDepthByConv[convId] ?? 0) > 0;
    }
    return _bulkMessageSyncDepthByConv.values.any((depth) => depth > 0);
  }

  void _beginBulkMessageSync(String conversationID) {
    final convId = _safeConversationId(conversationID);
    if (convId.isEmpty) {
      return;
    }
    _bulkMessageSyncDepthByConv[convId] =
        (_bulkMessageSyncDepthByConv[convId] ?? 0) + 1;
    ChatJitterDiag.log(
      'bulk_message_sync_begin',
      conv: convId,
      extras: <String, Object?>{
        'depth': _bulkMessageSyncDepthByConv[convId],
      },
    );
  }

  void _endBulkMessageSync(String conversationID) {
    final convId = _safeConversationId(conversationID);
    if (convId.isEmpty) {
      return;
    }
    final next = (_bulkMessageSyncDepthByConv[convId] ?? 0) - 1;
    if (next <= 0) {
      _bulkMessageSyncDepthByConv.remove(convId);
    } else {
      _bulkMessageSyncDepthByConv[convId] = next;
    }
    ChatJitterDiag.log(
      'bulk_message_sync_end',
      conv: convId,
      extras: <String, Object?>{
        'depth': _bulkMessageSyncDepthByConv[convId] ?? 0,
      },
    );
    _flushDeferredPinToBottom(convId);
  }

  void _flushDeferredPinToBottom(String conversationID) {
    final convId = _safeConversationId(conversationID);
    if (convId.isEmpty) {
      return;
    }
    if (!isBulkMessageSyncActive(convId) &&
        !isChunkedRevealActive(convId) &&
        (_pendingPinAfterBulkByConv.remove(convId) ?? false)) {
      requestPinToBottom(convId, force: true);
    }
  }

  bool isChunkedRevealActive([String? conversationID]) {
    if (conversationID != null) {
      return _inboundChunkReveal.isActiveFor(conversationID);
    }
    return _inboundChunkReveal.pendingCountFor(currentSelectedConv) > 0 ||
        _inboundChunkReveal.isActiveFor(currentSelectedConv);
  }

  /// Cancels presentation-only inbound work before an authoritative history
  /// replacement reveals the complete projection.
  void cancelInboundProjectionRevealForAuthoritativeReplace(
    String conversationID,
  ) {
    final storageKey = _resolveMessageListStorageKey(conversationID);
    _inboundChunkReveal.cancelForAuthoritativeReplace(conversationID);
    if (storageKey.isNotEmpty && storageKey != conversationID.trim()) {
      _inboundChunkReveal.cancelForAuthoritativeReplace(storageKey);
    }
  }

  /// Acknowledges that the message list finished laying out and animating the
  /// currently revealed projection group. The next group is not exposed until
  /// this acknowledgement, so burst traffic can never stack row controllers.
  void completeInboundProjectionReveal(String conversationID) {
    _inboundChunkReveal.completeCurrentReveal(conversationID);
  }

  bool isInboundProjectionRevealWaiting(String conversationID) =>
      _inboundChunkReveal.isWaitingForTransaction(conversationID);

  int pendingInboundProjectionCount(String conversationID) =>
      _inboundChunkReveal.pendingCountFor(conversationID);

  bool consumeInboundFastForwardFlag(V2TimMessage message) {
    return _inboundFastForwardMessageKeys.remove(messageDedupKey(message));
  }

  void cancelInboundProjectionRevealToBuffer(String conversationID) {
    _inboundChunkReveal.cancelToBuffer(conversationID);
  }

  @Deprecated('Use isChunkedRevealActive')
  bool isPacedRevealActive([String? conversationID]) =>
      isChunkedRevealActive(conversationID);

  int get inboundScrollFollowSeq => _inboundScrollFollowSeq;

  /// Bumped when paced reveal cancels an in-flight push so only the newest
  /// message keeps its animation. Message list should abort without acking.
  int get inboundPresentationSupersedeSeq => _inboundPresentationSupersedeSeq;

  bool get inboundScrollFollowSessionEnding =>
      _inboundScrollFollowSessionEnding;

  List<V2TimMessage> get lastInboundScrollFollowChunk =>
      _lastInboundScrollFollowChunk;

  int messageListRevisionFor(String conversationID) =>
      _messageListRevisionByConv[conversationID] ?? 0;

  int messageProjectionRevisionFor(String conversationID) =>
      _messageProjectionRevisionByConv[_inboundStateKey(conversationID)] ?? 0;

  /// Privacy-safe counts for diagnosing authority -> projection -> render
  /// discontinuities. Message content is intentionally excluded.
  Map<String, Object?> historyProjectionDiagnostics(String conversationID) {
    final convKey = _inboundStateKey(conversationID);
    final authoritative = _collectAuthoritativeMessages(conversationID);
    final hidden = _inboundHiddenKeysByConv[convKey] ?? const <String>{};
    final unreadState = _inboundUnreadStateFor(convKey, create: false);
    final display = _messageListDisplayCache[conversationID];
    return <String, Object?>{
      'authorityCount': authoritative.length,
      'hiddenCount': hidden.length,
      'projectedCount': authoritative
          .where((message) => !hidden.contains(messageDedupKey(message)))
          .length,
      'displayCount':
          display?.where((message) => message.elemType != 11).length,
      'displayDividerCount':
          display?.where((message) => message.elemType == 11).length,
      'displayCacheHit': display != null,
      'bufferedCount': unreadState.bufferedMessages.length,
      'tongueUnread': unreadState.unreadCount,
      'lockedEntryUnread': unreadState.lockedEntryUnreadCount,
      'pendingReveal': pendingInboundProjectionCount(convKey),
      'revealWaiting': isInboundProjectionRevealWaiting(convKey),
      'listRevision': messageListRevisionFor(conversationID),
      'projectionRevision': messageProjectionRevisionFor(convKey),
      'position': getMessageListPosition(conversationID).name,
      'deferredUntilBottom':
          _deferredUntilUserBottomConversations.contains(convKey),
    };
  }

  String _authoritativeDeferredKey(
    String conversationID,
    V2TimMessage message,
  ) {
    final normalized = _normalizeConversationID(conversationID);
    final convKey = normalized.isEmpty ? conversationID : normalized;
    return '$convKey|${messageDedupKey(message)}';
  }

  void _revealDeferredProjectionAcrossAliases(
    String conversationID,
    Iterable<V2TimMessage> messages,
  ) {
    final snapshot = List<V2TimMessage>.from(messages);
    if (snapshot.isEmpty) {
      return;
    }
    _revealInboundProjectionChunk(conversationID, snapshot);
    final pendingKeys = snapshot.map(messageDedupKey).toSet();
    for (final alias in List<String>.from(_inboundHiddenKeysByConv.keys)) {
      if (alias == conversationID) {
        continue;
      }
      final hidden = _inboundHiddenKeysByConv[alias];
      if (hidden == null || !hidden.any(pendingKeys.contains)) {
        continue;
      }
      _revealInboundProjectionChunk(alias, snapshot);
    }
  }

  void _hideInboundProjection(
    String conversationID,
    Iterable<V2TimMessage> messages,
  ) {
    final convKey = _inboundStateKey(conversationID);
    final hidden = _inboundHiddenKeysByConv.putIfAbsent(
      convKey,
      () => <String>{},
    );
    for (final message in messages) {
      hidden.add(messageDedupKey(message));
    }
  }

  bool _revealInboundProjectionChunk(
    String conversationID,
    Iterable<V2TimMessage> messages,
  ) {
    final convKey = _inboundStateKey(conversationID);
    final hidden = _inboundHiddenKeysByConv[convKey];
    if (hidden == null || hidden.isEmpty) {
      return false;
    }
    var changed = false;
    for (final message in messages) {
      changed = hidden.remove(messageDedupKey(message)) || changed;
    }
    if (hidden.isEmpty) {
      _inboundHiddenKeysByConv.remove(convKey);
    }
    if (changed) {
      _bumpMessageProjectionRevisionFor(convKey);
    }
    return changed;
  }

  bool _revealAllInboundProjection(String conversationID) {
    final convKey = _inboundStateKey(conversationID);
    final hidden = _inboundHiddenKeysByConv.remove(convKey);
    _authoritativeDeferredIncomingKeys.removeWhere(
      (key) => key.startsWith('$convKey|'),
    );
    if (hidden == null || hidden.isEmpty) {
      return false;
    }
    _bumpMessageProjectionRevisionFor(convKey);
    return true;
  }

  bool _revealAllDeferredProjectionAcrossAliases(String conversationID) {
    var changed = false;
    final aliases = List<String>.from(_inboundHiddenKeysByConv.keys);
    for (final alias in aliases) {
      if (_isSameConversationID(alias, conversationID)) {
        changed = _revealAllInboundProjection(alias) || changed;
      }
    }
    // Also clears authoritative deferred keys when no projection alias remains.
    changed = _revealAllInboundProjection(conversationID) || changed;
    return changed;
  }

  void _bumpMessageProjectionRevisionFor(String conversationID) {
    final convKey = _inboundStateKey(conversationID);
    _messageProjectionRevisionByConv[convKey] =
        (_messageProjectionRevisionByConv[convKey] ?? 0) + 1;
    _messageListDisplayCache.removeWhere(
      (key, _) => _isSameConversationID(key, convKey),
    );
  }

  void _bumpMessageListRevisionFor(String conversationID,
      {String reason = ''}) {
    final next = (_messageListRevisionByConv[conversationID] ?? 0) + 1;
    _messageListRevisionByConv[conversationID] = next;
    // 与投影 revision 一致：按等价会话 ID 清展示缓存，避免群 ID 别名打空洞。
    _messageListDisplayCache.removeWhere(
      (key, _) => _isSameConversationID(key, conversationID),
    );
    // 仅「绕过 setMessageList 的原地改表」清签名，迫使下次 setMessageList 再比对。
    // setMessageList 自己 bump 时绝不能清：否则刚写入的签名立刻失效，
    // 进页 hydrate / loadLatest 原样回写会每次都 signatureChanged→再 bump→整表抖。
    final fromSetMessageList = reason == 'setMessageList_signature' ||
        reason == 'setMessageList_delete';
    if (!fromSetMessageList) {
      _messageListContentSignatureByConv.remove(conversationID);
    }
    ChatJitterDiag.log(
      'message_list_revision_bump',
      conv: conversationID,
      extras: <String, Object?>{
        'rev': next,
        'reason': reason.isEmpty ? 'unspecified' : reason,
        'stack': ChatJitterDiag.compactStack(),
      },
    );
  }

  void _scheduleNotifyListeners() {
    if (_notifyScheduled) {
      return;
    }
    _notifyScheduled = true;
    // 洪峰时并到下一帧，避免同帧多次 microtask → 整表 setState 连打。
    void flush() {
      _notifyScheduled = false;
      if (!_notifyPending) {
        return;
      }
      // 相册是不透明路由。覆盖期间继续通知会让底层长消息列表在不可见时
      // 反复 rebuild，并与 PhotoKit 缩略图解码争抢 raster/主线程。
      // 保留 pending，关闭相册后由 endMediaPickerOverlay 一次性刷新。
      if (isMediaPickerOverlayOpen) {
        return;
      }
      _notifyPending = false;
      notifyListeners();
    }

    if (isInboundFloodActive) {
      WidgetsBinding.instance.addPostFrameCallback((_) => flush());
    } else {
      scheduleMicrotask(flush);
    }
  }

  void _markNeedsNotify() {
    _notifyPending = true;
    if (isMediaPickerOverlayOpen) {
      return;
    }
    _scheduleNotifyListeners();
  }

  void _scheduleInactiveInboundPresentationCommit(String convID) {
    final storageKey = _resolveMessageListStorageKey(convID);
    if (storageKey.isEmpty) {
      return;
    }
    _inactiveInboundDirtyConvs.add(storageKey);
    _inactiveInboundNotifyTimer?.cancel();
    final delay = isInboundFloodActive
        ? _inactiveInboundNotifyDelayFlood
        : _inactiveInboundNotifyDelayIdle;
    _inactiveInboundNotifyTimer = Timer(delay, () {
      _inactiveInboundNotifyTimer = null;
      _flushInactiveInboundPresentationCommits();
    });
  }

  void _flushInactiveInboundPresentationCommits() {
    _inactiveInboundNotifyTimer?.cancel();
    _inactiveInboundNotifyTimer = null;
    if (_inactiveInboundDirtyConvs.isEmpty) {
      return;
    }
    final convs = List<String>.from(_inactiveInboundDirtyConvs);
    _inactiveInboundDirtyConvs.clear();
    for (final convId in convs) {
      _bumpMessageListRevisionFor(
        convId,
        reason: 'inbound_batch_inactive_coalesced',
      );
    }
    final activeConvId = currentSelectedConv.trim();
    final touchesActiveConversation = activeConvId.isNotEmpty &&
        convs.any((convId) => _isSameConversationID(convId, activeConvId));
    // 当前聊天打开时，其他会话的消息只更新各自 revision；不要广播全局
    // notify 掀翻正在显示的长消息列表。切入该会话时会直接读取最新 map。
    if (activeConvId.isEmpty || touchesActiveConversation) {
      _markNeedsNotify();
    }
  }

  void flushInactiveInboundPresentationForConversation(String conversationID) {
    final storageKey = _resolveMessageListStorageKey(conversationID);
    if (storageKey.isEmpty) {
      return;
    }
    if (!_inactiveInboundDirtyConvs.remove(storageKey)) {
      return;
    }
    if (_inactiveInboundDirtyConvs.isEmpty) {
      _inactiveInboundNotifyTimer?.cancel();
      _inactiveInboundNotifyTimer = null;
    }
    _bumpMessageListRevisionFor(
      storageKey,
      reason: 'inbound_batch_inactive_open',
    );
    _markNeedsNotify();
  }

  /// 回前台合并缓冲后再跑 history refresh，避免与 deferred merge 抢写列表。
  Future<void> prepareForegroundChatRecovery() async {
    reconcileActiveChatAfterForegroundResume();
    for (var i = 0; i < 3; i++) {
      await WidgetsBinding.instance.endOfFrame;
    }
  }

  bool isOutgoingMediaCancelled(String? id) {
    if (id == null || id.isEmpty) {
      return false;
    }
    return _cancelledOutgoingMediaIds.contains(id);
  }

  void markOutgoingMediaCancelled(String? id) {
    if (id != null && id.isNotEmpty) {
      _cancelledOutgoingMediaIds.add(id);
    }
  }

  void clearOutgoingMediaCancelled(String? id) {
    if (id != null && id.isNotEmpty) {
      _cancelledOutgoingMediaIds.remove(id);
    }
  }

  int _normalizedOutgoingStatus(V2TimMessage item, int? fallback) {
    final status =
        item.status ?? fallback ?? MessageStatus.V2TIM_MSG_STATUS_SEND_SUCC;
    if (status == MessageStatus.V2TIM_MSG_STATUS_SENDING &&
        (item.msgID?.isNotEmpty ?? false)) {
      return MessageStatus.V2TIM_MSG_STATUS_SEND_SUCC;
    }
    return status;
  }

  V2TimMessage? _messageInConversation(
    String conversationID, {
    String? clientId,
    String? msgID,
  }) {
    final list = rawMessageList(conversationID);
    if (list == null || list.isEmpty) {
      return null;
    }
    for (final item in list) {
      if (clientId != null &&
          clientId.isNotEmpty &&
          item.id != null &&
          item.id == clientId) {
        return item;
      }
      if (msgID != null &&
          msgID.isNotEmpty &&
          item.msgID != null &&
          item.msgID == msgID) {
        return item;
      }
    }
    return null;
  }

  int _receiptTimestamp(int value) {
    if (value > 1000000000000) {
      return value ~/ 1000;
    }
    return value;
  }

  V2TimMessage? messageInConversationByKey(
    String conversationID,
    String messageKey,
  ) {
    final key = messageKey.trim();
    if (key.isEmpty) {
      return null;
    }
    final storageKey = _resolveMessageListStorageKey(conversationID);
    final list = _messageListMap[storageKey];
    if (list == null || list.isEmpty) {
      return null;
    }
    final resolvedKey = _rowLocalAliasByConversation[storageKey]?[key] ?? key;
    for (final item in list) {
      if (item.msgID == resolvedKey || item.id == resolvedKey) {
        return item;
      }
      final seq = item.seq?.trim();
      if (seq != null && seq.isNotEmpty && 'seq_$seq' == resolvedKey) {
        return item;
      }
      if (ChatUiStateStore.messageKeyOf(item) == resolvedKey) {
        return item;
      }
    }
    return null;
  }

  bool _messageMatchesRowIdentity(
    V2TimMessage message,
    Set<String> identities,
  ) {
    if (identities.isEmpty) {
      return false;
    }
    final values = <String>{
      ChatUiStateStore.messageKeyOf(message).trim(),
      message.id?.trim() ?? '',
      message.msgID?.trim() ?? '',
      readOutgoingStableId(message)?.trim() ?? '',
      if (message.elemType == MessageElemType.V2TIM_ELEM_TYPE_IMAGE)
        message.imageElem?.path?.trim() ?? '',
    }..remove('');
    return values.any(identities.contains);
  }

  void _rememberRowLocalAliases(
    String storageKey,
    Iterable<String?> aliases,
    String targetKey,
  ) {
    final target = targetKey.trim();
    if (target.isEmpty) {
      return;
    }
    final map = _rowLocalAliasByConversation.putIfAbsent(
      storageKey,
      () => <String, String>{},
    );
    final normalizedAliases = aliases
        .map((value) => value?.trim() ?? '')
        .where((value) => value.isNotEmpty)
        .toSet();
    final chainedSources = map.entries
        .where((entry) => normalizedAliases.contains(entry.value))
        .map((entry) => entry.key)
        .toList(growable: false);
    for (final source in chainedSources) {
      map[source] = target;
    }
    for (final value in normalizedAliases) {
      if (value.isNotEmpty && value != target) {
        map[value] = target;
      }
    }
    while (map.length > 512) {
      map.remove(map.keys.first);
    }
  }

  /// Resolves exactly one row through the outgoing stable identity chain.
  /// Missing/ambiguous identities, semantic changes and reordering are never
  /// guessed: callers must keep their full-list fallback for those results.
  RowLocalMessageReplacementResult replaceMessageRowByStableIdentity({
    required String conversationID,
    required String stableIdentity,
    required V2TimMessage replacement,
    Iterable<String?> aliases = const <String?>[],
  }) {
    final primary = stableIdentity.trim();
    if (primary.isEmpty) {
      return RowLocalMessageReplacementResult.notFound;
    }
    final storageKey = _resolveMessageListStorageKey(conversationID);
    final current = _messageListMap[storageKey];
    if (current == null || current.isEmpty) {
      return RowLocalMessageReplacementResult.notFound;
    }
    final identities = <String>{primary};
    for (final alias in aliases) {
      final value = alias?.trim() ?? '';
      if (value.isNotEmpty) {
        identities.add(value);
      }
    }
    final matches = <int>[];
    for (var index = 0; index < current.length; index++) {
      if (_messageMatchesRowIdentity(current[index], identities)) {
        matches.add(index);
      }
    }
    if (matches.isEmpty) {
      return RowLocalMessageReplacementResult.notFound;
    }
    if (matches.length != 1) {
      return RowLocalMessageReplacementResult.ambiguous;
    }
    final index = matches.single;
    final expected = current[index];
    if (expected.elemType != replacement.elemType ||
        expected.isSelf != replacement.isSelf) {
      return RowLocalMessageReplacementResult.semanticChange;
    }
    final next = List<V2TimMessage>.from(current)..[index] = replacement;
    if (!isNewestFirstStorageOrderValid(next)) {
      return RowLocalMessageReplacementResult.reordered;
    }
    final resolvedStableIdentity = readOutgoingStableId(expected) ??
        readOutgoingStableId(replacement) ??
        expected.id ??
        expected.msgID ??
        primary;
    final commit = commitMessageDelta(
      MessageDelta<V2TimMessage>(
        conversationKey: storageKey,
        eventID:
            'row_replace:$resolvedStableIdentity:${replacement.msgID ?? ''}',
        kind: MessageDeltaKind.edit,
        source: MessageDeltaSource.sendPipeline,
        generation: messageDeltaGenerationFor(storageKey),
        clearEpoch: messageDeltaClearEpochFor(storageKey),
        upserts: <MessageReconciliationRecord<V2TimMessage>>[
          MessageReconciliationRecord<V2TimMessage>(
            value: replacement,
            msgID: replacement.msgID,
            localID: replacement.id,
            outgoingStableID: resolvedStableIdentity,
            seq: replacement.seq,
          ),
        ],
      ),
    );
    if (commit == null) {
      return RowLocalMessageReplacementResult.stale;
    }
    final replacementKey = ChatUiStateStore.messageKeyOf(replacement);
    final allAliases = <String?>{
      ChatUiStateStore.messageKeyOf(expected),
      expected.id,
      expected.msgID,
      readOutgoingStableId(expected),
      replacement.id,
      replacement.msgID,
      readOutgoingStableId(replacement),
      ...aliases,
    };
    _rememberRowLocalAliases(storageKey, allAliases, replacementKey);
    for (final alias in allAliases) {
      final value = alias?.trim() ?? '';
      if (value.isNotEmpty && value != replacementKey) {
        _chatUiStateStore.bindMessageAlias(storageKey, value, replacementKey);
      }
    }
    _markMessageRowChanged(storageKey, replacement);
    return RowLocalMessageReplacementResult.replaced;
  }

  /// Replaces one authoritative row without invalidating the whole message
  /// window. The caller must already have proved that membership and ordering
  /// are unchanged; otherwise use [setMessageList].
  RowLocalMessageReplacementResult replaceMessageRowLocal({
    required String conversationID,
    required int index,
    required V2TimMessage expected,
    required V2TimMessage replacement,
    Iterable<String?> aliases = const <String?>[],
  }) {
    final storageKey = _resolveMessageListStorageKey(conversationID);
    final current = _messageListMap[storageKey];
    if (current == null ||
        index < 0 ||
        index >= current.length ||
        !identical(current[index], expected)) {
      return RowLocalMessageReplacementResult.stale;
    }
    final next = List<V2TimMessage>.from(current);
    next[index] = replacement;
    if (!isNewestFirstStorageOrderValid(next)) {
      return RowLocalMessageReplacementResult.reordered;
    }
    final stableIdentity = readOutgoingStableId(expected) ??
        readOutgoingStableId(replacement) ??
        expected.id ??
        expected.msgID ??
        replacement.id ??
        replacement.msgID;
    if (stableIdentity == null || stableIdentity.trim().isEmpty) {
      return RowLocalMessageReplacementResult.notFound;
    }
    final commit = commitMessageDelta(
      MessageDelta<V2TimMessage>(
        conversationKey: storageKey,
        eventID: 'row_local_replace:$stableIdentity:${replacement.msgID ?? ''}',
        kind: MessageDeltaKind.edit,
        source: MessageDeltaSource.sendPipeline,
        generation: messageDeltaGenerationFor(storageKey),
        clearEpoch: messageDeltaClearEpochFor(storageKey),
        upserts: <MessageReconciliationRecord<V2TimMessage>>[
          MessageReconciliationRecord<V2TimMessage>(
            value: replacement,
            msgID: replacement.msgID,
            localID: replacement.id,
            outgoingStableID: stableIdentity,
            seq: replacement.seq,
          ),
        ],
      ),
    );
    if (commit == null) {
      return RowLocalMessageReplacementResult.stale;
    }
    final replacementKey = ChatUiStateStore.messageKeyOf(replacement);
    final keys = <String?>{
      ChatUiStateStore.messageKeyOf(expected),
      expected.id,
      expected.msgID,
      replacement.id,
      replacement.msgID,
      ...aliases,
    };
    _rememberRowLocalAliases(storageKey, keys, replacementKey);
    for (final alias in keys) {
      final value = alias?.trim() ?? '';
      if (value.isNotEmpty && value != replacementKey) {
        _chatUiStateStore.bindMessageAlias(storageKey, value, replacementKey);
      }
    }
    _markMessageRowChanged(storageKey, replacement);
    return RowLocalMessageReplacementResult.replaced;
  }

  void _markMessageRowChanged(
    String conversationID,
    V2TimMessage message, {
    String? extraKey,
    MessageMutationType mutationType = MessageMutationType.contentOrMedia,
  }) {
    final keys = <String>{
      ChatUiStateStore.messageKeyOf(message),
    };
    final msgID = message.msgID?.trim();
    if (msgID != null && msgID.isNotEmpty) {
      keys.add(msgID);
    }
    final id = message.id?.trim();
    if (id != null && id.isNotEmpty) {
      keys.add(id);
    }
    final seq = message.seq?.trim();
    if (seq != null && seq.isNotEmpty) {
      keys.add('seq_$seq');
    }
    final key = extraKey?.trim();
    if (key != null && key.isNotEmpty) {
      keys.add(key);
    }
    _messageCommitCoordinator.stage(
      MessageMutation(
        conversationID: conversationID,
        type: mutationType,
        generation: _messageCommitGenerationByConv[conversationID] ?? 0,
        source: 'row_local',
        stableIdentity: _commitSnapshotIdentity(message),
      ),
      requiresListRevision: false,
    );
    _chatUiStateStore.markMessagesChanged(conversationID, keys);
  }

  void _markMessageRowChangedByIds(
    String conversationID, {
    String? msgID,
    String? clientId,
  }) {
    final keys = <String>{};
    final mid = msgID?.trim();
    if (mid != null && mid.isNotEmpty) {
      keys.add(mid);
    }
    final cid = clientId?.trim();
    if (cid != null && cid.isNotEmpty) {
      keys.add(cid);
    }
    final message = _messageInConversation(
      conversationID,
      clientId: cid,
      msgID: mid,
    );
    if (message != null) {
      keys.add(ChatUiStateStore.messageKeyOf(message));
      final messageId = message.id?.trim();
      if (messageId != null && messageId.isNotEmpty) {
        keys.add(messageId);
      }
      final messageMsgID = message.msgID?.trim();
      if (messageMsgID != null && messageMsgID.isNotEmpty) {
        keys.add(messageMsgID);
      }
    }
    if (keys.isNotEmpty) {
      _messageCommitCoordinator.stage(
        MessageMutation(
          conversationID: conversationID,
          type: MessageMutationType.statusOrProgress,
          generation: _messageCommitGenerationByConv[conversationID] ?? 0,
          source: 'status_progress',
          stableIdentity: mid?.isNotEmpty == true ? mid : cid,
        ),
        requiresListRevision: false,
      );
      _chatUiStateStore.markMessagesChanged(conversationID, keys);
    }
  }

  void _markMessageRowsChangedByMsgID(String msgID) {
    final key = msgID.trim();
    if (key.isEmpty) {
      return;
    }
    for (final entry in _messageListMap.entries.toList()) {
      final list = entry.value;
      if (list == null || list.isEmpty) {
        continue;
      }
      for (final message in list) {
        if (message.msgID == key || message.id == key) {
          _markMessageRowChanged(entry.key, message, extraKey: key);
        }
      }
    }
  }

  void markMessageRowsChangedByMsgIDs(Iterable<String?> msgIDs) {
    final keys = msgIDs
        .whereType<String>()
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toSet();
    if (keys.isEmpty) {
      return;
    }
    for (final key in keys) {
      _markMessageRowsChangedByMsgID(key);
    }
  }

  int messageStatusInConversation(
    String conversationID, {
    String? clientId,
    String? msgID,
    int? fallback,
    int? elemType,
  }) {
    final list = rawMessageList(conversationID);
    if (list == null || list.isEmpty) {
      return fallback ?? MessageStatus.V2TIM_MSG_STATUS_SEND_SUCC;
    }
    for (final item in list) {
      if (clientId != null &&
          clientId.isNotEmpty &&
          item.id != null &&
          item.id == clientId) {
        return _normalizedOutgoingStatus(item, fallback);
      }
      if (msgID != null &&
          msgID.isNotEmpty &&
          item.msgID != null &&
          item.msgID == msgID) {
        return _normalizedOutgoingStatus(item, fallback);
      }
    }
    if (fallback == MessageStatus.V2TIM_MSG_STATUS_SENDING) {
      final hasSelfSending = list.any(
        (item) =>
            item.isSelf == true &&
            item.status == MessageStatus.V2TIM_MSG_STATUS_SENDING &&
            !(item.msgID?.isNotEmpty ?? false) &&
            (elemType == null || item.elemType == elemType),
      );
      if (!hasSelfSending) {
        return MessageStatus.V2TIM_MSG_STATUS_SEND_SUCC;
      }
      return MessageStatus.V2TIM_MSG_STATUS_SENDING;
    }
    return fallback ?? MessageStatus.V2TIM_MSG_STATUS_SEND_SUCC;
  }

  bool applyOutgoingSendResult(
    V2TimValueCallback<V2TimMessage> sendMsgRes,
    String convID,
    String clientId,
    ConvType convType,
    GroupReceiptAllowType? groupType,
    ValueChanged<String>? setInputField,
  ) {
    final dataMsgID = sendMsgRes.data?.msgID;
    if (isOutgoingMediaCancelled(clientId) ||
        isOutgoingMediaCancelled(dataMsgID)) {
      return false;
    }
    try {
      updateMessage(
        sendMsgRes,
        convID,
        clientId,
        convType,
        groupType,
        setInputField,
      );
      return true;
    } catch (e) {
      outputLogger.i('updateMessage error: $e');
      return false;
    }
  }

  void setChatListUserScrolling(bool scrolling) {
    final wasScrolling = isChatListUserScrolling;
    final page = _openPageUserScrolling;
    if (page != null) {
      if (page.value != scrolling) {
        page.value = scrolling;
      }
    } else {
      _isChatListUserScrolling = scrolling;
    }
    if (scrolling) {
      final convId = _safeConversationId(currentSelectedConv);
      if (convId.isNotEmpty && _inboundChunkReveal.isActiveFor(convId)) {
        _inboundChunkReveal.cancelToBuffer(convId);
      }
      ChatJitterDiag.logInboundFlow(
        action: 'user_scroll_start',
        conv: convId,
        throttleKey: 'user_scroll_start',
        minIntervalMs: 200,
      );
    } else if (wasScrolling) {
      _lastChatListUserScrollEndAtMs = DateTime.now().millisecondsSinceEpoch;
      ChatJitterDiag.logInboundFlow(
        action: 'user_scroll_end',
        conv: _safeConversationId(currentSelectedConv),
        throttleKey: 'user_scroll_end',
        minIntervalMs: 200,
        extras: <String, Object?>{
          'buffered': deferredIncomingBufferedCount(currentSelectedConv),
        },
      );
    }
  }

  TUIChatGlobalModel() {
    _inboundBatchCoalescer = MessageInboundBatchCoalescer(
      maxBatchSize: _inboundBatchMaxSize,
      maxDelay: _inboundBatchMaxDelay,
      onFlush: _flushInboundMessageBatch,
    );
    _inboundChunkReveal = MessageInboundChunkedReveal(
      interval: Duration(milliseconds: chatConfig.inboundChunkRevealIntervalMs),
      maxChunkSize: chatConfig.inboundChunkRevealMaxChunk,
      alignToFrame: true,
      burstBoostChunk: 0,
      // Under sustained traffic, commit stale presentation work immediately
      // and keep only the newest bubble for the visible push animation.
      maxAnimatedBacklog: 1,
      // Paced reveal is presentation-only. Keeping it outside bulk-sync allows
      // each released row to run its extent animation while chunk-active guards
      // still suppress competing list-push and pin paths.
      onSessionBegin: (_) {},
      onSessionEnd: (convId) {
        _inboundScrollFollowSessionEnding = true;
        _lastInboundScrollFollowChunk = const [];
        _inboundScrollFollowSeq++;
        _flushDeferredPinToBottom(convId);
        _markNeedsNotify();
      },
      onRevealChunk: (convId, chunk) {
        _lastInboundScrollFollowChunk = chunk;
        _inboundScrollFollowSessionEnding = false;
        _revealInboundProjectionChunk(convId, chunk);
        if (chunk.length == 1) {
          final message = chunk.first;
          if (message.isSelf != true &&
              _inboundChunkReveal.pendingCountFor(convId) == 0) {
            _markIncomingMessageEnterAnimation(message);
          }
        }
        _inboundScrollFollowSeq++;
        _markNeedsNotify();
      },
      onDrainRemaining: _drainChunkRevealToBuffer,
      onSupersede: (convId) {
        _inboundPresentationSupersedeSeq++;
        _markNeedsNotify();
      },
      onFastForward: (convId, messages) {
        for (final message in messages) {
          _inboundFastForwardMessageKeys.add(messageDedupKey(message));
        }
        _revealInboundProjectionChunk(convId, messages);
        _markNeedsNotify();
      },
    );
    advancedMsgListener = V2TimAdvancedMsgListener(
      onRecvC2CReadReceipt: (List<V2TimMessageReceipt> receiptList) {
        _onReceiveC2CReadReceipt(receiptList);
      },
      onRecvMessageRevoked: (String msgID) {
        onMessageRevoked(msgID);
      },
      onRecvNewMessage: (V2TimMessage newMsg) {
        _onReceiveNewMsg(newMsg);
      },
      onSendMessageProgress: (V2TimMessage messagae, int progress) {
        _onSendMessageProgress(messagae, progress);
      },
      onRecvMessageReadReceipts: (List<V2TimMessageReceipt> receiptList) {
        _onReceiveMessageReadReceipts(receiptList);
      },
      onRecvMessageModified: (V2TimMessage newMsg) {
        onMessageModified(newMsg);
      },
      onMessageDownloadProgressCallback:
          (V2TimMessageDownloadProgress messageProgress) {
        onMessageDownloadProgressCallback(messageProgress);
      },
    );
  }

  bool get isDownloading => _isDownloading;

  bool get hasWaiting => _waitingDownloadList.isNotEmpty;

  Map<String, String> get currentDownLoad => _waitingDownloadList.first;

  int getWaitingListLength() {
    return _waitingDownloadList.length;
  }

  void addWaitingList(String msgID) {
    outputLogger.i("add to waiting list success");
    bool contains = false;
    for (Map<String, String> element in _waitingDownloadList) {
      String msgIDItem = element["msgID"] ?? "";
      if (msgIDItem.isNotEmpty) {
        if (msgID == msgIDItem) {
          contains = true;
          break;
        }
      }
    }
    if (!contains) {
      _waitingDownloadList.add(Map.from({
        "msgID": msgID,
      }));
      // setMessageProgress(msgID, 1); // 有一点进度条，表示等待中
    }
  }

  downloadFile() async {
    if (_isDownloading || _waitingDownloadList.isEmpty) {
      return;
    }

    final nextDownload = _waitingDownloadList.first;
    final msgID = nextDownload["msgID"] ?? "";
    if (msgID.isEmpty || _messageListProgressMap[msgID] == 100) {
      return;
    }

    _isDownloading = true;
    await _messageService.downloadMessage(
      msgID: msgID,
      messageType: 6,
      imageType: 0,
      isSnapshot: false,
    );

    outputLogger.i("start another download");
  }

  int getReceived(msgID) {
    return messageListProgressMap[msgID] ?? 0;
  }

  bool isWaiting(String msgID) {
    return _waitingDownloadList.where((element) {
      String msgIDItem = element["msgID"] ?? "";
      if (msgIDItem.isNotEmpty) {
        if (msgID == msgIDItem) {
          return true;
        }
      }
      return false;
    }).isNotEmpty;
  }

  Map<String, int> get messageListProgressMap {
    return _messageListProgressMap;
  }

  Map<String, List<V2TimMessage>?> get messageListMap {
    return _messageListMap;
  }

  String _normalizeMergerCacheKey(String? key) {
    return key?.trim() ?? '';
  }

  void cacheLocalMergerMessageList({
    required Iterable<String?> keys,
    required List<V2TimMessage> messages,
  }) {
    if (messages.isEmpty) {
      return;
    }
    final normalizedKeys = keys
        .map(_normalizeMergerCacheKey)
        .where((item) => item.isNotEmpty)
        .toSet();
    if (normalizedKeys.isEmpty) {
      return;
    }
    final cached = messages.map(_cloneMessage).toList(growable: false);
    for (final key in normalizedKeys) {
      _localMergerMessageCache[key] = cached;
    }
  }

  void bindLocalMergerMessageKeys({
    required String? sourceKey,
    required Iterable<String?> keys,
  }) {
    final source = _normalizeMergerCacheKey(sourceKey);
    if (source.isEmpty) {
      return;
    }
    final cached = _localMergerMessageCache[source];
    if (cached == null || cached.isEmpty) {
      return;
    }
    cacheLocalMergerMessageList(keys: keys, messages: cached);
  }

  List<V2TimMessage>? getLocalMergerMessageList(String? key) {
    final normalized = _normalizeMergerCacheKey(key);
    if (normalized.isEmpty) {
      return null;
    }
    final cached = _localMergerMessageCache[normalized];
    if (cached == null || cached.isEmpty) {
      return null;
    }
    return cached.map(_cloneMessage).toList(growable: false);
  }

  int get totalUnReadCount {
    return _totalUnreadCount;
  }

  set totalUnReadCount(int newValue) {
    _totalUnreadCount = newValue;
    notifyListeners();
  }

  String _inboundStateKey(String? conversationID) {
    final safe = _safeConversationId(conversationID).trim();
    final normalized = _normalizeConversationID(safe);
    return normalized.isEmpty ? safe : normalized;
  }

  _InboundUnreadState _inboundUnreadStateFor(
    String? conversationID, {
    bool create = true,
  }) {
    final key = _inboundStateKey(conversationID);
    if (!create) {
      return _inboundUnreadStateByConversation[key] ?? _InboundUnreadState();
    }
    return _inboundUnreadStateByConversation.putIfAbsent(
      key,
      _InboundUnreadState.new,
    );
  }

  int unreadCountForTongueFor(String conversationID) =>
      _inboundUnreadStateFor(conversationID, create: false).unreadCount;

  int lockedEntryUnreadCountFor(String conversationID) =>
      _inboundUnreadStateFor(
        conversationID,
        create: false,
      ).lockedEntryUnreadCount;

  int lockedFirstUnreadSeqFor(String conversationID) => _inboundUnreadStateFor(
        conversationID,
        create: false,
      ).lockedFirstUnreadSeq;

  int get receivedNewMessageCount =>
      _inboundUnreadStateFor(currentSelectedConv, create: false).receivedCount;

  set receivedNewMessageCount(int value) {
    _inboundUnreadStateFor(currentSelectedConv).receivedCount = value;
  }

  int get unreadCountForTongue => unreadCountForTongueFor(currentSelectedConv);

  int get lockedEntryUnreadCount =>
      lockedEntryUnreadCountFor(currentSelectedConv);

  int get lockedFirstUnreadSeq => lockedFirstUnreadSeqFor(currentSelectedConv);

  bool get hasLockedEntryUnread => lockedEntryUnreadCount > 0;

  bool hasLockedEntryUnreadFor(String conversationID) {
    return lockedEntryUnreadCountFor(conversationID) > 0;
  }

  set unreadCountForTongue(int value) {
    setUnreadCountForTongue(value);
  }

  void lockEntryUnreadForTongue({
    required String conversationID,
    required int unreadCount,
    int? firstUnreadSeq,
    bool notify = true,
  }) {
    final convId = _normalizeConversationID(conversationID);
    if (convId.isEmpty || unreadCount <= 0) {
      return;
    }
    final state = _inboundUnreadStateFor(convId);
    state.lockedEntryUnreadCount = unreadCount;
    state.unreadCount = unreadCount;
    final frozenSeq = firstUnreadSeq ?? 0;
    if (frozenSeq > 0) {
      state.lockedFirstUnreadSeq = frozenSeq;
    }
    _dismissedEntryUnreadTongueCountByConversation.remove(convId);
    if (conversationID != convId) {
      _dismissedEntryUnreadTongueCountByConversation.remove(conversationID);
    }
    setUnreadTongueMetrics(
      conversationID: convId,
      remaining: unreadCount,
      below: false,
      notify: notify,
    );
  }

  void unlockEntryUnreadForTongue({
    String? conversationID,
    bool notify = true,
  }) {
    final convId = _inboundStateKey(conversationID);
    if (_deferredUntilUserBottomConversations.contains(convId)) {
      return;
    }
    final state = _inboundUnreadStateFor(convId, create: false);
    // A caller may reach the bottom in the same event-loop turn that the
    // coalescer routes an inbound message to the away buffer. Never let an
    // unread cleanup operation discard a message that has not been merged.
    if (state.bufferedMessages.isNotEmpty) {
      return;
    }
    if (state.lockedEntryUnreadCount <= 0 && state.unreadCount <= 0) {
      return;
    }
    state.clear();
    _inboundUnreadStateByConversation.remove(convId);
    if (notify) {
      notifyListeners();
    }
  }

  void setUnreadCountForTongue(
    int value, {
    String? conversationID,
    bool notify = true,
  }) {
    final state = _inboundUnreadStateFor(conversationID);
    if (value == 0 && state.lockedEntryUnreadCount > 0) {
      return;
    }
    state.unreadCount = value;
    if (notify) {
      notifyListeners();
    }
  }

  int get unreadTongueMetricsVersion => _unreadTongueMetricsVersion;

  int getUnreadTongueRemaining(String conversationID) {
    final normalized = _normalizeConversationID(conversationID);
    final direct = _unreadTongueRemainingByConversation[conversationID];
    if (direct != null) {
      return direct;
    }
    if (normalized.isNotEmpty) {
      final normalizedRemaining =
          _unreadTongueRemainingByConversation[normalized];
      if (normalizedRemaining != null) {
        return normalizedRemaining;
      }
    }
    return unreadCountForTongueFor(conversationID);
  }

  bool getUnreadTongueBelow(String conversationID) {
    final normalized = _normalizeConversationID(conversationID);
    if (_unreadTongueBelowByConversation.containsKey(conversationID)) {
      return _unreadTongueBelowByConversation[conversationID] ?? true;
    }
    if (normalized.isNotEmpty &&
        _unreadTongueBelowByConversation.containsKey(normalized)) {
      return _unreadTongueBelowByConversation[normalized] ?? true;
    }
    return true;
  }

  void setUnreadTongueMetrics({
    required String conversationID,
    required int remaining,
    required bool below,
    bool notify = true,
  }) {
    final convId = _normalizeConversationID(conversationID);
    if (convId.isEmpty) {
      return;
    }
    final safeRemaining = remaining < 0 ? 0 : remaining;
    if (_unreadTongueRemainingByConversation[convId] == safeRemaining &&
        _unreadTongueBelowByConversation[convId] == below) {
      return;
    }
    _unreadTongueRemainingByConversation[convId] = safeRemaining;
    _unreadTongueBelowByConversation[convId] = below;
    _unreadTongueMetricsVersion++;
    if (notify) {
      notifyListeners();
    }
  }

  void clearUnreadTongueMetrics(String conversationID, {bool notify = false}) {
    if (conversationID.isEmpty) {
      return;
    }
    final convId = _inboundStateKey(conversationID);
    final removedRemaining =
        _unreadTongueRemainingByConversation.remove(convId) != null;
    final removedBelow =
        _unreadTongueBelowByConversation.remove(convId) != null;
    final changed = removedRemaining || removedBelow;
    if (changed) {
      _unreadTongueMetricsVersion++;
      if (notify) {
        notifyListeners();
      }
    }
  }

  int getDismissedEntryUnreadTongueCount(String conversationID) {
    return _dismissedEntryUnreadTongueCountByConversation[
            _inboundStateKey(conversationID)] ??
        0;
  }

  void markEntryUnreadTongueDismissed({
    required String conversationID,
    required int unreadCount,
    bool notify = false,
  }) {
    final convId = _inboundStateKey(conversationID);
    if (convId.isEmpty) {
      return;
    }
    final safeCount = unreadCount < 0 ? 0 : unreadCount;
    final previous =
        _dismissedEntryUnreadTongueCountByConversation[convId] ?? 0;
    if (safeCount <= previous) {
      return;
    }
    _dismissedEntryUnreadTongueCountByConversation[convId] = safeCount;
    if (notify) {
      notifyListeners();
    }
  }

  void clearEntryUnreadTongueDismissed(String conversationID,
      {bool notify = false}) {
    final convId = _inboundStateKey(conversationID);
    if (convId.isEmpty) {
      return;
    }
    final changed =
        _dismissedEntryUnreadTongueCountByConversation.remove(convId) != null;
    if (changed && notify) {
      notifyListeners();
    }
  }

  void clearReceivedUnreadState({
    String? conversationID,
    bool notify = false,
  }) {
    final convId = _inboundStateKey(conversationID);
    if (_deferredUntilUserBottomConversations.contains(convId)) {
      return;
    }
    final state = _inboundUnreadStateFor(convId, create: false);
    if (state.bufferedMessages.isNotEmpty) {
      return;
    }
    if (state.lockedEntryUnreadCount > 0) {
      return;
    }
    state.clear();
    _inboundUnreadStateByConversation.remove(convId);
    _dismissedEntryUnreadTongueCountByConversation.remove(convId);
    if (notify) {
      notifyListeners();
    }
  }

  bool _shouldDeferIncomingToVisibleList(
    String convID, {
    required HistoryMessagePosition position,
    required bool isActuallyNearBottom,
  }) {
    if (!_isSameConversationID(convID, currentSelectedConv)) {
      return false;
    }
    // 长按菜单打开时：即便贴底也先缓冲，避免背景列表被新消息顶走。
    if (isMessageContextMenuOverlayOpen) {
      return true;
    }
    // 键盘几何动画中，沿用动画前的贴底状态；不能把活跃会话误路由到
    // bufferedMessages，否则仅在退出页面的 flush 中才会恢复可见。
    if (_wasAtBottomBeforeKeyboardViewportChange(convID)) {
      return false;
    }
    // 已离开底部超过约一屏（「回到底部」应出现）：新消息只缓冲，不再上推。
    if (_isActiveChatAwayOneScreen(convID)) {
      return true;
    }
    if (isActuallyNearBottom) {
      return false;
    }
    if (position == HistoryMessagePosition.bottom &&
        unreadCountForTongue == 0) {
      return false;
    }
    return true;
  }

  void _bufferIncomingWhileReadingAway(
    String convID,
    V2TimMessage mountedMessage, {
    required String route,
    required HistoryMessagePosition position,
    required bool isActuallyNearBottom,
  }) {
    if (!_chatAppForeground) {
      final normalizedConvId = _inboundStateKey(convID);
      _deferredUntilUserBottomConversations.add(normalizedConvId);
      _storeHistoryMessagePosition(
        normalizedConvId,
        HistoryMessagePosition.notShowLatest,
      );
    }
    final state = _inboundUnreadStateFor(convID);
    final messageKey = messageDedupKey(mountedMessage);
    if (!state.bufferedMessageKeys.add(messageKey)) {
      return;
    }
    state.unreadCount++;
    state.receivedCount++;
    state.bufferedMessages.add(mountedMessage);
    ChatJitterDiag.logReadingHistoryIncoming(
      action: 'route_buffer',
      conv: convID,
      extras: <String, Object?>{
        'route': route,
        'position': position.name,
        'nearBottom': isActuallyNearBottom,
        'tongueUnread': state.unreadCount,
        'bufferedLen': state.bufferedMessages.length,
        'msgId': mountedMessage.msgID,
      },
    );
    _markNeedsNotify();
  }

  /// 将看历史期间缓冲的新消息合并进可见列表（回到底部 / 点未读条时调用）。
  bool flushDeferredIncomingMessages(
    String convID, {
    bool notify = true,
    bool userInitiated = false,
  }) {
    final normalizedConvId = _inboundStateKey(convID);
    if (_deferredUntilUserBottomConversations.contains(normalizedConvId) &&
        !userInitiated) {
      return false;
    }
    if (userInitiated) {
      if (_inboundChunkReveal.isActiveFor(convID)) {
        _inboundChunkReveal.cancelToBuffer(convID);
      } else if (_inboundChunkReveal.isActiveFor(normalizedConvId)) {
        _inboundChunkReveal.cancelToBuffer(normalizedConvId);
      }
      _deferredUntilUserBottomConversations.remove(normalizedConvId);
    }
    final projectionRevealed = userInitiated
        ? _revealAllDeferredProjectionAcrossAliases(convID)
        : false;
    final state = _inboundUnreadStateFor(normalizedConvId, create: false);
    if (state.bufferedMessages.isEmpty) {
      if (projectionRevealed && notify) {
        _markNeedsNotify();
      }
      return projectionRevealed;
    }
    final pending = List<V2TimMessage>.from(state.bufferedMessages);
    state.bufferedMessages.clear();
    state.bufferedMessageKeys.clear();
    final alreadyAuthoritative = <V2TimMessage>[];
    final needsUpsert = <V2TimMessage>[];
    for (final message in pending) {
      final key = _authoritativeDeferredKey(convID, message);
      if (_authoritativeDeferredIncomingKeys.remove(key)) {
        alreadyAuthoritative.add(message);
      } else {
        needsUpsert.add(message);
      }
    }
    _revealDeferredProjectionAcrossAliases(convID, alreadyAuthoritative);
    final storageKey = _resolveMessageListStorageKey(convID);

    // 松手后大缓冲：走分片揭示，避免一次 revision + 整表 layout。
    if (!userInitiated &&
        pending.length >= postScrollFlushChunkThreshold &&
        chatConfig.inboundChunkRevealEnabled &&
        !isChatListUserScrolling &&
        needsUpsert.isNotEmpty) {
      ChatJitterDiag.logInboundFlow(
        action: 'flush_deferred_paced',
        conv: storageKey,
        extras: <String, Object?>{
          'count': pending.length,
          'upsert': needsUpsert.length,
          'authoritative': alreadyAuthoritative.length,
        },
      );
      _stageInboundChunkReveal(storageKey, needsUpsert);
      if (notify) {
        _markNeedsNotify();
      }
      return true;
    }

    final result = _upsertIncomingMessageBatch(storageKey, needsUpsert);
    if (result.inserted) {
      _bumpMessageListRevisionFor(
        storageKey,
        reason: 'flush_deferred_batch',
      );
    }
    ChatJitterDiag.logReadingHistoryIncoming(
      action: 'flush_deferred',
      conv: storageKey,
      extras: <String, Object?>{
        'count': pending.length,
        'listLen': _messageListMap[storageKey]?.length,
      },
    );
    ChatJitterDiag.logInboundFlow(
      action: 'flush_deferred',
      conv: storageKey,
      throttleKey: 'flush_deferred',
      minIntervalMs: 100,
      extras: <String, Object?>{
        'count': pending.length,
        'listLen': _messageListMap[storageKey]?.length,
      },
    );
    if (notify) {
      _markNeedsNotify();
    }
    return true;
  }

  /// Flushes messages that are either waiting in the SDK batch coalescer or
  /// buffered while the user was away from the latest message. This is the
  /// final inbound drain used by an explicit return-to-bottom transaction.
  ///
  /// The coalescer is deliberately drained first: otherwise a message already
  /// delivered by the SDK can arrive in the 50ms coalescing gap after the UI's
  /// first deferred flush and be mistaken for a post-transaction message.
  bool flushPendingIncomingMessagesForUserBottom(String conversationID) {
    final storageKey = _resolveMessageListStorageKey(conversationID);
    final keys = <String>{
      conversationID.trim(),
      storageKey,
      _inboundStateKey(conversationID),
      _inboundStateKey(storageKey),
    }..removeWhere((key) => key.isEmpty);
    var hadCoalescedMessages = false;
    for (final key in keys) {
      hadCoalescedMessages = _inboundBatchCoalescer.pendingCountFor(key) > 0 ||
          hadCoalescedMessages;
      _inboundBatchCoalescer.flushConversation(key);
    }
    final beforeDeferred = deferredIncomingBufferedCount(conversationID);
    final flushedDeferred = flushDeferredIncomingMessages(
      storageKey.isEmpty ? conversationID : storageKey,
      notify: true,
      userInitiated: true,
    );
    return hadCoalescedMessages || beforeDeferred > 0 || flushedDeferred;
  }

  List<V2TimGroupApplication> get groupApplicationList =>
      _groupApplicationList ?? [];
  List<GroupSystemNoticeItem> get groupSystemNoticeList =>
      _groupSystemNoticeList;

  String Function(V2TimMessage message)? get abstractMessageBuilder =>
      _abstractMessageBuilder;

  Widget Function(
    BuildContext context,
    TextEditingController controller,
    ValueChanged<String> onChanged,
  )? get appSearchBarBuilder => _appSearchBarBuilder;

  Widget Function(BuildContext context)? get appForwardSelectFriendPage =>
      _appForwardSelectFriendPage;

  Widget Function(BuildContext context)? get appForwardSelectGroupPage =>
      _appForwardSelectGroupPage;

  NavigatorState? Function()? get appRootNavigator => _appRootNavigator;

  AppContactPresenceBridge Function(BuildContext context)?
      get appContactPresenceBridgeBuilder => _appContactPresenceBridgeBuilder;

  Map<String, V2TimMessageReceipt> get messageReadReceiptMap =>
      _messageReadReceiptMap;

  String get currentSelectedConv => _currentConversationList.isNotEmpty
      ? _currentConversationList[_currentConversationList.length - 1]
          .conversationID
      : "";

  ConvType? get currentSelectedConvType => _currentConversationList.isNotEmpty
      ? _currentConversationList[_currentConversationList.length - 1]
          .conversationType
      : null;

  String _normalizeConversationID(String? value) {
    return normalizeConversationIdForHistory(value);
  }

  /// 历史桶写入主键：C2C 固定 `c2c_<uid>`，群去掉 `group_` 前缀并保留短码大小写。
  static String canonicalHistoryStorageKey(String? conversationID) {
    final trimmed = conversationID?.trim() ?? '';
    if (trimmed.isEmpty) {
      return '';
    }
    final normalized = normalizeConversationIdForHistory(trimmed);
    if (normalized.isEmpty) {
      return trimmed;
    }
    if (_historyIdKind(trimmed) == _HistoryConversationKind.group) {
      return normalized;
    }
    return 'c2c_${normalized.toLowerCase()}';
  }

  List<String> _historyAliasKeys(String conversationID) {
    final trimmed = conversationID.trim();
    final canonical = canonicalHistoryStorageKey(trimmed);
    final keys = <String>{
      if (trimmed.isNotEmpty) trimmed,
      if (canonical.isNotEmpty) canonical,
    };
    keys.addAll(
      _messageListMap.keys.where(
        (mapKey) => isSameConversationIdForHistory(mapKey, trimmed),
      ),
    );
    return keys.toList(growable: false);
  }

  List<V2TimMessage> _mergedAliasMessageList(String conversationID) {
    final merged = <V2TimMessage>[];
    for (final key in _historyAliasKeys(conversationID)) {
      final list = _messageListMap[key];
      if (list == null || list.isEmpty) {
        continue;
      }
      merged.addAll(list);
    }
    if (merged.isEmpty) {
      return const <V2TimMessage>[];
    }
    return sortMessagesNewestFirst(dedupeMessages(merged));
  }

  /// 别名合并后的内存窗（`c2c_` / 裸 id 等同会话），供分页 baseline 与提交守卫使用。
  List<V2TimMessage> mergedAliasMessageList(String conversationID) {
    return _mergedAliasMessageList(conversationID);
  }

  /// 用户正在读历史（一屏外 / 非最新），此期间禁止 latest 向 replace 抢写列表。
  bool isReadingHistory(String conversationID) {
    final position = getMessageListPosition(conversationID);
    return position == HistoryMessagePosition.awayTwoScreen ||
        position == HistoryMessagePosition.notShowLatest;
  }

  void _collapseHistoryAliasesToCanonical(
    String conversationID, {
    required String canonical,
  }) {
    if (canonical.isEmpty) {
      return;
    }
    for (final key in _historyAliasKeys(conversationID)) {
      if (key == canonical) {
        continue;
      }
      _messageListMap.remove(key);
      _messageListContentSignatureByConv.remove(key);
      final position = _historyMessagePositionMap.remove(key);
      if (position != null &&
          !_historyMessagePositionMap.containsKey(canonical)) {
        _storeHistoryMessagePosition(canonical, position);
      }
    }
  }

  /// 去掉 `c2c_` / `group_` 等前缀，供历史桶 / 进页匹配共用。
  static String normalizeConversationIdForHistory(String? value) {
    var id = value?.trim() ?? '';
    if (id.isEmpty) {
      return '';
    }
    final lower = id.toLowerCase();
    if (lower.startsWith('c2c_')) {
      id = id.substring(4);
    } else if (lower.startsWith('group_')) {
      id = id.substring(6);
    } else if (id.startsWith('C2C')) {
      id = id.substring(3);
    } else if (id.startsWith('GROUP')) {
      id = id.substring(5);
    }
    return id;
  }

  bool _isSameConversationID(String? left, String? right) {
    return isSameConversationIdForHistory(left, right);
  }

  bool _isGroupConversation(
    String conversationID, {
    Iterable<V2TimMessage> messages = const <V2TimMessage>[],
  }) {
    final selectedType = currentSelectedConvType;
    if (selectedType != null &&
        _isSameConversationID(conversationID, currentSelectedConv)) {
      return selectedType == ConvType.group;
    }
    if (messages.any(
      (message) => TencentUtils.checkString(message.groupID) != null,
    )) {
      return true;
    }
    return _historyIdKind(conversationID) == _HistoryConversationKind.group;
  }

  /// 包内外统一的会话 ID 等价判断（前缀、社群短码）。
  ///
  /// 聊天页空拉兜底、hydrate 别名探测等禁止再写字面 `==` / 手拼 `group_`。
  /// `c2c_` 与群短码即使忽略大小写相同，也不得判为同一会话。
  static bool isSameConversationIdForHistory(String? left, String? right) {
    final a = normalizeConversationIdForHistory(left);
    final b = normalizeConversationIdForHistory(right);
    if (a.isEmpty || b.isEmpty) {
      return false;
    }
    final aKind = _historyIdKind(left);
    final bKind = _historyIdKind(right);
    if (aKind != bKind) {
      final groupBody = aKind == _HistoryConversationKind.group ? a : b;
      if (groupBody.contains('TGS#') || groupBody.startsWith('@')) {
        return _communityIdsEquivalent(a, b);
      }
      return false;
    }
    if (a == b) {
      return true;
    }
    if (aKind == _HistoryConversationKind.group) {
      return _communityIdsEquivalent(a, b);
    }
    return a.toLowerCase() == b.toLowerCase();
  }

  /// 与 app [ChatIdFormat.isCommunityShortToken] 对齐：字母数字下划线且含大写。
  static final RegExp _communityShortAlnumReg = RegExp(r'^[A-Za-z0-9_]+$');
  static final RegExp _hasUpperCaseReg = RegExp(r'[A-Z]');

  static bool _looksLikeCommunityShortToken(String token) {
    final t = token.trim();
    if (t.isEmpty || t.toUpperCase().contains('TGS#')) {
      return false;
    }
    if (!_communityShortAlnumReg.hasMatch(t)) {
      return false;
    }
    return _hasUpperCaseReg.hasMatch(t);
  }

  static bool _rawHasC2cPrefix(String trimmed) {
    final lower = trimmed.toLowerCase();
    return lower.startsWith('c2c_') || trimmed.startsWith('C2C');
  }

  static bool _rawHasGroupPrefix(String trimmed) {
    final lower = trimmed.toLowerCase();
    return lower.startsWith('group_') || trimmed.startsWith('GROUP');
  }

  static _HistoryConversationKind _historyIdKind(String? conversationID) {
    final trimmed = conversationID?.trim() ?? '';
    if (trimmed.isEmpty) {
      return _HistoryConversationKind.c2c;
    }
    if (_rawHasC2cPrefix(trimmed)) {
      return _HistoryConversationKind.c2c;
    }
    if (_rawHasGroupPrefix(trimmed)) {
      return _HistoryConversationKind.group;
    }
    final body = normalizeConversationIdForHistory(trimmed);
    if (body.contains('TGS#') ||
        body.startsWith('@') ||
        _looksLikeCommunityShortToken(body)) {
      return _HistoryConversationKind.group;
    }
    return _HistoryConversationKind.c2c;
  }

  static bool _communityIdsEquivalent(String left, String right) {
    String shortOf(String raw) {
      var id = raw.trim();
      if (id.isEmpty) {
        return '';
      }
      final upper = id.toUpperCase();
      // 默认分配社群：`@TGS#_@TGS#{short}`
      const fullPrefix = '@TGS#_@TGS#';
      if (upper.startsWith(fullPrefix)) {
        return id.substring(fullPrefix.length);
      }
      // 控制台自定义社群：`@TGS#_mc…` → `mc…`（勿把 `_mc…` 当 token）
      if (upper.startsWith('@TGS#_')) {
        return id.substring('@TGS#_'.length);
      }
      final hash = id.indexOf('#');
      if (hash >= 0 && hash + 1 < id.length && upper.contains('TGS#')) {
        var token = id.substring(hash + 1);
        if (token.startsWith('_')) {
          token = token.substring(1);
        }
        return token;
      }
      if (id.startsWith('@')) {
        return id.substring(1);
      }
      return id;
    }

    final a = shortOf(left);
    final b = shortOf(right);
    return a.isNotEmpty && b.isNotEmpty && a == b;
  }

  String? _messageConversationID(V2TimMessage message) {
    final groupID = TencentUtils.checkString(message.groupID);
    if (groupID != null) {
      final normalized = _normalizeConversationID(groupID);
      return normalized.isNotEmpty ? normalized : groupID;
    }
    final userID = TencentUtils.checkString(message.userID);
    if (userID != null) {
      final normalized = _normalizeConversationID(userID);
      return normalized.isNotEmpty ? normalized : userID;
    }
    final sender = TencentUtils.checkString(message.sender);
    if (sender == null) {
      return null;
    }
    final normalized = _normalizeConversationID(sender);
    return normalized.isNotEmpty ? normalized : sender;
  }

  setCurrentConversation(CurrentConversation value, {bool notify = true}) {
    flushInactiveInboundPresentationForConversation(value.conversationID);
    _currentConversationList.add(value);
    if (notify) {
      notifyListeners();
    }
  }

  clearCurrentConversation({bool notify = false}) {
    if (_currentConversationList.isNotEmpty) {
      final leaving = _currentConversationList.last.conversationID;
      _inboundBatchCoalescer.flushConversation(leaving);
      _inboundChunkReveal.flushConversation(leaving);
      _revealAllInboundProjection(leaving);
      // Buffered messages are not yet authoritative. Commit them before the
      // active conversation is removed so switching routes cannot lose rows.
      flushDeferredIncomingMessages(
        leaving,
        notify: false,
        userInitiated: true,
      );
      final leavingStorageKey = _resolveMessageListStorageKey(leaving);
      final reorderBuffer = _reorderBuffersByConv.remove(leavingStorageKey) ??
          _reorderBuffersByConv.remove(leaving);
      reorderBuffer?.dispose();
      _cancelCloudContinuation(leaving);
      _groupGapAutoAttemptAtMs.removeWhere(
        (key, _) => key.startsWith('$leavingStorageKey:'),
      );
      final stateKey = _inboundStateKey(leaving);
      _inboundUnreadStateByConversation.remove(stateKey);
      _deferredUntilUserBottomConversations.remove(stateKey);
      _wasAtBottomBeforeBackgroundByConv.remove(stateKey);
      _clearKeyboardViewportTransition(leaving);
    }
    if (_currentConversationList.isNotEmpty) {
      _currentConversationList.removeLast();
    }
    if (notify) {
      notifyListeners();
    }
  }

  /// History warm / open-gate keys: bare id + matching `group_` / `c2c_` shape.
  ///
  /// For group/community ids, always stamp both bare and `group_` so
  /// `@TGS#_@TGS#…` warm flags hit `group_@TGS#_@TGS#…` open reads.
  /// Do **not** invent both `group_` and `c2c_` for ambiguous bare ids.
  Set<String> _historyFlagKeys(String conversationID) {
    final trimmed = conversationID.trim();
    if (trimmed.isEmpty) {
      return const <String>{};
    }
    final normalized = _normalizeConversationID(trimmed);
    final keys = <String>{trimmed};
    if (normalized.isNotEmpty) {
      keys.add(normalized);
      final lower = trimmed.toLowerCase();
      if (lower.startsWith('group_')) {
        keys.add('group_$normalized');
      } else if (lower.startsWith('c2c_')) {
        keys.add('c2c_$normalized');
      } else if (_looksLikeGroupHistoryId(normalized)) {
        keys.add('group_$normalized');
      }
    }
    for (final mapKey in _messageListMap.keys) {
      if (_isSameConversationID(mapKey, trimmed)) {
        keys.add(mapKey);
      }
    }
    return keys;
  }

  bool _looksLikeGroupHistoryId(String id) {
    final value = id.trim();
    if (value.isEmpty) {
      return false;
    }
    final upper = value.toUpperCase();
    if (upper.contains('TGS#')) {
      return true;
    }
    // Community short token (has uppercase); keep in sync with app ChatIdFormat.
    final token = value.startsWith('@') ? value.substring(1) : value;
    if (token.isEmpty || token.toUpperCase().contains('TGS#')) {
      return false;
    }
    if (!_communityShortAlnumReg.hasMatch(token)) {
      return false;
    }
    return _hasUpperCaseReg.hasMatch(token);
  }

  void _clearHistoryFlagsForConversation(String conversationID) {
    final trimmed = conversationID.trim();
    if (trimmed.isEmpty) {
      return;
    }
    _initialHistoryLoadedConvs.removeWhere(
      (key) => _isSameConversationID(key, trimmed),
    );
    _mayHaveOlderHistoryByConv
        .removeWhere((key, _) => _isSameConversationID(key, trimmed));
  }

  Future<MessageHistoryCoverage> ensureMessageHistoryCoverageLoaded(
    String conversationID, {
    int clearEpoch = 0,
  }) async {
    final storageKey = _resolveMessageListStorageKey(conversationID);
    final key = storageKey.isEmpty ? conversationID.trim() : storageKey;
    if (key.isEmpty) {
      return MessageHistoryCoverage.empty('', isGroup: false);
    }
    final cached = _messageHistoryCoverageByConv[key];
    if (_messageHistoryCoverageLoadedConvs.contains(key) && cached != null) {
      if (clearEpoch <= cached.clearEpoch) return cached;
      final cleared = MessageHistoryCoverage.empty(
        key,
        isGroup: cached.isGroup,
        clearEpoch: clearEpoch,
      );
      _storeMessageHistoryCoverage(cleared);
      return cleared;
    }
    final existingTask = _messageHistoryCoverageLoadInFlight[key];
    if (existingTask != null) {
      final loaded = await existingTask;
      return loaded ??
          MessageHistoryCoverage.empty(
            key,
            isGroup: _looksLikeGroupConversationKey(key),
            clearEpoch: clearEpoch,
          );
    }
    late final Future<MessageHistoryCoverage?> task;
    final coverageSessionGeneration = _messageHistoryCoverageSessionGeneration;
    task = loadMessageHistoryCoverage(key).then((loaded) {
      final isGroup = loaded?.isGroup ?? _looksLikeGroupConversationKey(key);
      final normalized = loaded == null || loaded.clearEpoch < clearEpoch
          ? MessageHistoryCoverage.empty(
              key,
              isGroup: isGroup,
              clearEpoch: clearEpoch,
            )
          : loaded.copyWith(conversationKey: key);
      if (coverageSessionGeneration !=
          _messageHistoryCoverageSessionGeneration) {
        return normalized;
      }
      _messageHistoryCoverageByConv[key] = normalized;
      _messageHistoryCoverageLoadedConvs.add(key);
      return normalized;
    }).whenComplete(() {
      if (identical(_messageHistoryCoverageLoadInFlight[key], task)) {
        _messageHistoryCoverageLoadInFlight.remove(key);
      }
    });
    _messageHistoryCoverageLoadInFlight[key] = task;
    return await task ??
        MessageHistoryCoverage.empty(
          key,
          isGroup: _looksLikeGroupConversationKey(key),
          clearEpoch: clearEpoch,
        );
  }

  MessageHistoryCoverage? messageHistoryCoverageFor(String conversationID) {
    final storageKey = _resolveMessageListStorageKey(conversationID);
    final key = storageKey.isEmpty ? conversationID.trim() : storageKey;
    return _messageHistoryCoverageByConv[key];
  }

  @visibleForTesting
  Future<void> waitForMessageHistoryCoverageUpdates(String conversationID) {
    final storageKey = _resolveMessageListStorageKey(conversationID);
    final key = storageKey.isEmpty ? conversationID.trim() : storageKey;
    return _messageHistoryCoverageUpdateTailByConv[key] ?? Future<void>.value();
  }

  Future<void> invalidateMessageHistoryCoverage(
    String conversationID, {
    required bool isGroup,
    required int clearEpoch,
  }) async {
    final storageKey = _resolveMessageListStorageKey(conversationID);
    final key = storageKey.isEmpty ? conversationID.trim() : storageKey;
    if (key.isEmpty) return;
    final coverage = MessageHistoryCoverage.empty(
      key,
      isGroup: isGroup,
      clearEpoch: clearEpoch,
    ).copyWith(updatedAtMs: DateTime.now().millisecondsSinceEpoch);
    _messageHistoryCoverageByConv[key] = coverage;
    _messageHistoryCoverageLoadedConvs.add(key);
    _messageHistoryCoverageRequestGenerationByConv.remove(key);
    _messageReconciliationWriter.reset(key);
    _boundedCloudCatchUp.invalidate(key);
    await clearMessageHistoryCoverage(
      key,
      isGroup: isGroup,
      clearEpoch: clearEpoch,
    );
  }

  void _storeMessageHistoryCoverage(MessageHistoryCoverage coverage) {
    final key = _resolveMessageListStorageKey(coverage.conversationKey);
    final storageKey = key.isEmpty ? coverage.conversationKey.trim() : key;
    if (storageKey.isEmpty) return;
    final normalized = coverage.copyWith(conversationKey: storageKey);
    _messageHistoryCoverageByConv[storageKey] = normalized;
    _messageHistoryCoverageLoadedConvs.add(storageKey);
    unawaited(persistMessageHistoryCoverage(normalized));
  }

  bool _looksLikeGroupConversationKey(String conversationID) {
    final key = conversationID.trim();
    if (key.isEmpty) return false;
    final lower = key.toLowerCase();
    return (lower.startsWith('group_') && !lower.startsWith('group_c2c_')) ||
        key.toUpperCase().contains('TGS#');
  }

  bool hasInitialHistoryLoaded(String conversationID) {
    final trimmed = conversationID.trim();
    if (trimmed.isEmpty) {
      return false;
    }
    if (_initialHistoryLoadedConvs.contains(trimmed)) {
      return true;
    }
    final normalized = _normalizeConversationID(trimmed);
    if (normalized.isNotEmpty &&
        _initialHistoryLoadedConvs.contains(normalized)) {
      return true;
    }
    for (final key in _initialHistoryLoadedConvs) {
      if (_isSameConversationID(key, trimmed)) {
        return true;
      }
    }
    return false;
  }

  void _markInitialHistoryVisible(String conversationID) {
    for (final key in _historyFlagKeys(conversationID)) {
      _initialHistoryLoadedConvs.add(key);
    }
    _activateReorderBuffer(conversationID);
  }

  /// Local SDK history is allowed to release the first-frame gate, but it is
  /// not proof that cloud history is complete and must not start a second
  /// bootstrap catch-up request.
  void markLocalInitialHistoryVisible(String conversationID) {
    _markInitialHistoryVisible(conversationID);
  }

  /// A proven initial cloud window is visible. Reconnect/foreground events own
  /// later catch-up; the bootstrap itself already performed the cloud request.
  void markCloudInitialHistoryVerified(String conversationID) {
    _markInitialHistoryVisible(conversationID);
  }

  void markInitialHistoryLoaded(String conversationID) {
    _markInitialHistoryVisible(conversationID);
    unawaited(
      reconcileConversationCloud(
        conversationID,
        reason: 'chat_open',
      ),
    );
    if (OutgoingVisibleProbe.matches(conversationID)) {
      OutgoingVisibleProbe.log(
        'mark_initial_history_loaded',
        conversationID: conversationID,
        extras: <String, Object?>{
          'count': rawMessageCount(conversationID),
          ...OutgoingVisibleProbe.trackedInList(rawMessageList(conversationID)),
        },
      );
    }
  }

  /// Activates the InboundReorderBuffer for group conversations after
  /// initial history is loaded. C2C seq has no global continuity, so
  /// the buffer is only used for group chats.
  void _activateReorderBuffer(String conversationID) {
    final trimmed = conversationID.trim();
    if (trimmed.isEmpty) return;
    final storageKey = _resolveMessageListStorageKey(trimmed);
    final list = _messageListMap[storageKey] ?? _messageListMap[trimmed];
    if (list == null || list.isEmpty) return;
    if (!_isGroupConversation(storageKey, messages: list)) return;
    int newestSeq = 0;
    for (final msg in list) {
      final seq = int.tryParse(msg.seq?.trim() ?? '') ?? 0;
      if (seq > newestSeq) newestSeq = seq;
    }
    if (newestSeq <= 0) return;
    final buffer = _reorderBuffersByConv.putIfAbsent(
      storageKey,
      () => InboundReorderBuffer(
        onFlush: (messages) {
          _applyInboundMessageBatch(storageKey, messages);
        },
        onGapTimeout: (anchorSeq, convID) {
          _triggerGroupGapCatchUp(convID, anchorSeq);
        },
      ),
    );
    buffer.activate(storageKey, newestSeq);
  }

  /// Triggers a CLOUD_NEWER pull when a group seq gap times out.
  Future<void> _triggerGroupGapCatchUp(
      String conversationID, int expectedSeq) async {
    final trimmed = conversationID.trim();
    if (trimmed.isEmpty) {
      return;
    }
    await reconcileConversationCloud(
      trimmed,
      reason: 'seq_gap_$expectedSeq',
    );
  }

  V2TimMessage? _cloudCatchUpNewestAnchor(
    List<V2TimMessage> messages,
  ) {
    for (final message in messages) {
      if (HistoryPaginationAnchor.canUseForSdkPagination(message)) {
        return message;
      }
    }
    return null;
  }

  String _cloudCatchUpAnchorKey(V2TimMessage? anchor) {
    if (anchor == null) {
      return '';
    }
    final msgID = anchor.msgID?.trim() ?? '';
    if (msgID.isEmpty) {
      return '';
    }
    // Include the visible content signature in the in-memory key. A server
    // edit to the same message therefore invalidates the stalled decision.
    return '$msgID|${_messageListContentSignature(<V2TimMessage>[anchor])}';
  }

  Future<bool> _shouldHoldStalledCloudContinuation(
    String conversationID,
  ) async {
    final current = _mergedAliasMessageList(conversationID);
    final anchor = _cloudCatchUpNewestAnchor(current);
    final anchorID = anchor?.msgID?.trim() ?? '';
    if (anchorID.isEmpty) {
      return false;
    }
    final inMemory = _cloudCatchUpStalledAnchorByConv[conversationID];
    if (inMemory != null) {
      // A changed anchor or content is a fresh observation. Do not fall back
      // to the durable ID-only record, otherwise an edited tip would remain
      // blocked until another lifecycle event.
      if (inMemory == _cloudCatchUpAnchorKey(anchor)) {
        return true;
      }
      _cloudCatchUpStalledAnchorByConv.remove(conversationID);
      return false;
    }
    var coverage = messageHistoryCoverageFor(conversationID);
    coverage ??= await ensureMessageHistoryCoverageLoaded(conversationID);
    if (!coverage.cloudContinuationStalled ||
        coverage.continuationCursorMsgID != anchorID) {
      return false;
    }
    _cloudCatchUpStalledAnchorByConv[conversationID] =
        _cloudCatchUpAnchorKey(anchor);
    return true;
  }

  Future<void> _markCloudCatchUpUnblocked(String conversationID) async {
    _cloudCatchUpStalledAnchorByConv.remove(conversationID);
    await _enqueueMessageHistoryCoverageUpdate(conversationID, () async {
      var coverage = messageHistoryCoverageFor(conversationID);
      coverage ??= await ensureMessageHistoryCoverageLoaded(conversationID);
      if (coverage.lastBatchKind != _cloudCatchUpStalledBatchKind) {
        return;
      }
      _storeMessageHistoryCoverage(
        coverage.copyWith(
          coverageRevision: coverage.coverageRevision + 1,
          lastBatchKind: _cloudCatchUpUnblockedBatchKind,
          updatedAtMs: DateTime.now().millisecondsSinceEpoch,
        ),
      );
    });
  }

  Future<void> _recordCloudCatchUpStalled(
    String conversationID,
    List<V2TimMessage> current,
  ) async {
    final anchor = _cloudCatchUpNewestAnchor(current);
    final anchorID = anchor?.msgID?.trim() ?? '';
    if (anchorID.isEmpty) {
      return;
    }
    final anchorKey = _cloudCatchUpAnchorKey(anchor);
    _cloudCatchUpStalledAnchorByConv[conversationID] = anchorKey;
    await _enqueueMessageHistoryCoverageUpdate(conversationID, () async {
      var coverage = messageHistoryCoverageFor(conversationID);
      coverage ??= await ensureMessageHistoryCoverageLoaded(conversationID);
      final now = DateTime.now().millisecondsSinceEpoch;
      _storeMessageHistoryCoverage(
        coverage.copyWith(
          coverageRevision: coverage.coverageRevision + 1,
          status: MessageHistoryCoverageStatus.partial,
          newerHasMore: true,
          continuationPending: true,
          continuationDirection: MessageHistoryCoverageDirection.newer,
          continuationCursorMsgID: anchorID,
          clearContinuationCursor: false,
          lastBatchKind: _cloudCatchUpStalledBatchKind,
          lastCursorDirection: MessageHistoryCoverageDirection.newer.name,
          lastCursorMsgID: anchorID,
          clearLastCursor: false,
          updatedAtMs: now,
        ),
      );
    });
  }

  /// Runs one bounded cloud reconciliation for open/reconnect/foreground and
  /// gap-repair triggers. All fetched rows are committed through the same
  /// reconciliation writer as initial history and realtime callbacks.
  Future<MessageCloudCatchUpResult> reconcileConversationCloud(
    String conversationID, {
    required String reason,
  }) async {
    final storageKey = _resolveMessageListStorageKey(conversationID);
    if (storageKey.isEmpty) {
      return const MessageCloudCatchUpResult(
        disposition: MessageCloudCatchUpDisposition.offline,
        attempts: 0,
        timedOut: false,
      );
    }
    if (_shouldDeferCloudCatchUpWhileReadingHistory(storageKey)) {
      ChatHistoryTrace.log(
        'cloud_catch_up_deferred_reading_history',
        conversationID: storageKey,
        extras: <String, Object?>{
          'reason': reason,
          'position': getMessageListPosition(storageKey).name,
          'memorySuppressed': isMemoryWindowSuppressed(storageKey),
          'missingNewer': memoryWindowMissingNewer(storageKey),
        },
      );
      return const MessageCloudCatchUpResult(
        disposition: MessageCloudCatchUpDisposition.settled,
        attempts: 0,
        timedOut: false,
      );
    }
    if (reason == 'cloud_continuation') {
      if (await _shouldHoldStalledCloudContinuation(storageKey)) {
        ChatHistoryTrace.log(
          'cloud_catch_up_stalled_hold',
          conversationID: storageKey,
          extras: <String, Object?>{'reason': reason},
        );
        return const MessageCloudCatchUpResult(
          disposition: MessageCloudCatchUpDisposition.stalled,
          attempts: 0,
          timedOut: false,
        );
      }
    } else {
      // A fresh lifecycle/open/bottom trigger is the explicit escape hatch
      // from a stalled same-anchor continuation.
      await _markCloudCatchUpUnblocked(storageKey);
    }
    if (reason != 'cloud_continuation') {
      _cancelCloudContinuation(storageKey, clearBudget: false);
      _cloudContinuationRoundsByConv[storageKey] = 0;
    }
    final result = await _boundedCloudCatchUp.run(
      conversationID: storageKey,
      operation: (attempt) => _runCloudCatchUpAttempt(
        storageKey,
        reason: reason,
        attempt: attempt,
      ),
    );
    await _markUnresolvedGroupCoverageAfterCatchUp(storageKey, result);
    if (result.disposition == MessageCloudCatchUpDisposition.stalled) {
      await _recordCloudCatchUpStalled(
        storageKey,
        _mergedAliasMessageList(storageKey),
      );
    }
    if (result.settled) {
      ChatHistoryTrace.log(
        'cloud_catch_up_settled',
        conversationID: storageKey,
        extras: <String, Object?>{
          'reason': reason,
          'attempts': result.attempts,
        },
      );
    }
    if (result.completed || result.settled) {
      _cancelCloudContinuation(storageKey);
    } else if (result.needsContinuation) {
      _scheduleCloudContinuation(storageKey);
    }
    return result;
  }

  Future<void> _markUnresolvedGroupCoverageAfterCatchUp(
    String conversationID,
    MessageCloudCatchUpResult result,
  ) async {
    if (result.completed || result.settled || result.needsContinuation) return;
    final storageKey = _resolveMessageListStorageKey(conversationID);
    if (storageKey.isEmpty) return;
    await _enqueueMessageHistoryCoverageUpdate(storageKey, () async {
      final current = await ensureMessageHistoryCoverageLoaded(storageKey);
      final unresolved = current.holes
          .where((hole) =>
              hole.kind == MessageHistoryHoleKind.groupSeq &&
              hole.status != MessageHistoryHoleStatus.resolved)
          .toList(growable: false);
      if (!current.isGroup || unresolved.isEmpty) return;
      final nextHoleStatus =
          result.disposition == MessageCloudCatchUpDisposition.offline
              ? MessageHistoryHoleStatus.cloudUnavailable
              : MessageHistoryHoleStatus.retryable;
      if (unresolved.every((hole) => hole.status == nextHoleStatus)) return;
      final now = DateTime.now().millisecondsSinceEpoch;
      final holes = current.holes.map((hole) {
        if (hole.kind != MessageHistoryHoleKind.groupSeq ||
            hole.status == MessageHistoryHoleStatus.resolved) {
          return hole;
        }
        return MessageHistoryHole(
          key: hole.key,
          kind: hole.kind,
          status: nextHoleStatus,
          startSeq: hole.startSeq,
          endSeq: hole.endSeq,
          olderMsgID: hole.olderMsgID,
          newerMsgID: hole.newerMsgID,
          generation: hole.generation,
          updatedAtMs: now,
        );
      }).toList(growable: false);
      _storeMessageHistoryCoverage(
        current.copyWith(
          coverageRevision: current.coverageRevision + 1,
          status: result.disposition == MessageCloudCatchUpDisposition.offline
              ? MessageHistoryCoverageStatus.offlineLocalOnly
              : MessageHistoryCoverageStatus.partial,
          holes: holes,
          updatedAtMs: now,
        ),
      );
    });
  }

  void _scheduleCloudContinuation(String conversationID) {
    final storageKey = _resolveMessageListStorageKey(conversationID);
    final current = storageKey.isEmpty
        ? const <V2TimMessage>[]
        : _mergedAliasMessageList(storageKey);
    if (storageKey.isEmpty ||
        _isGroupConversation(storageKey, messages: current) ||
        _cloudContinuationTimersByConv.containsKey(storageKey)) {
      return;
    }
    final rounds = _cloudContinuationRoundsByConv[storageKey] ?? 0;
    if (rounds >= _maxAutomaticCloudContinuationRounds ||
        !_chatAppForeground ||
        !_isSameConversationID(currentSelectedConv, storageKey) ||
        isChatListUserScrolling) {
      return;
    }
    final position = getMessageListPosition(storageKey);
    if (!_isActiveChatNearBottom(storageKey) &&
        position != HistoryMessagePosition.bottom) {
      return;
    }
    _cloudContinuationTimersByConv[storageKey] = Timer(
      _cloudContinuationDelay,
      () {
        _cloudContinuationTimersByConv.remove(storageKey);
        if (!_chatAppForeground ||
            !_isSameConversationID(currentSelectedConv, storageKey) ||
            isChatListUserScrolling ||
            _messageReconciliationWriter.hasActiveRequest(storageKey)) {
          return;
        }
        final currentRounds = _cloudContinuationRoundsByConv[storageKey] ?? 0;
        if (currentRounds >= _maxAutomaticCloudContinuationRounds) {
          return;
        }
        _cloudContinuationRoundsByConv[storageKey] = currentRounds + 1;
        unawaited(reconcileConversationCloud(
          storageKey,
          reason: 'cloud_continuation',
        ));
      },
    );
  }

  void _cancelCloudContinuation(
    String conversationID, {
    bool clearBudget = true,
  }) {
    final storageKey = _resolveMessageListStorageKey(conversationID);
    _cloudContinuationTimersByConv.remove(storageKey)?.cancel();
    if (clearBudget) {
      _cloudContinuationRoundsByConv.remove(storageKey);
    }
  }

  Future<MessageCloudCatchUpDisposition> _runCloudCatchUpAttempt(
    String storageKey, {
    required String reason,
    required MessageCloudCatchUpAttempt attempt,
  }) async {
    if (_shouldDeferCloudCatchUpWhileReadingHistory(storageKey)) {
      return MessageCloudCatchUpDisposition.settled;
    }
    final networkBefore = messageReconciliationNetworkState;
    if (networkBefore != MessageReconciliationNetworkState.online) {
      return MessageCloudCatchUpDisposition.offline;
    }
    if (_messageReconciliationWriter.hasActiveRequest(storageKey)) {
      return MessageCloudCatchUpDisposition.retry;
    }
    final current = _mergedAliasMessageList(storageKey);
    if (current.isEmpty) {
      return MessageCloudCatchUpDisposition.complete;
    }
    final isGroup = _isGroupConversation(storageKey, messages: current);
    final clearEpoch = messageDeltaClearEpochFor(storageKey);
    _messageReconciliationWriter.seedAuthoritative(
      conversationID: storageKey,
      records: _reconciliationRecords(current),
      trackSeqGaps: isGroup,
      clearEpoch: clearEpoch,
    );
    final request = _messageReconciliationWriter.beginCloudCatchUp(
      conversationID: storageKey,
      networkState: networkBefore,
      clearEpoch: clearEpoch,
    );
    attempt.onInvalidated(() {
      failHistoryReconciliation(
        request: request,
        reason: 'cloud_catch_up_timeout',
      );
    });
    final sdkConversationID = normalizeConversationIdForHistory(storageKey);
    final groupID = isGroup ? sdkConversationID : null;
    final userID = isGroup ? null : sdkConversationID;
    final missingSeqs = isGroup
        ? _boundedMissingGroupSeqs(current, maxCount: 100)
        : const <int>[];
    V2TimMessage? newestAnchor;
    var newestSeq = 0;
    for (final message in current) {
      if (!HistoryPaginationAnchor.canUseForSdkPagination(message)) {
        continue;
      }
      newestAnchor ??= message;
      final seq = int.tryParse(message.seq?.trim() ?? '') ?? 0;
      if (seq > newestSeq) {
        newestSeq = seq;
      }
    }
    if ((isGroup && missingSeqs.isEmpty && newestSeq <= 0) ||
        (!isGroup && newestAnchor == null)) {
      failHistoryReconciliation(
        request: request,
        reason: 'cloud_catch_up_missing_anchor',
      );
      return MessageCloudCatchUpDisposition.complete;
    }

    try {
      final response = await _messageService.getHistoryMessageListWithComplete(
        count: missingSeqs.isNotEmpty ? missingSeqs.length : 50,
        getType: HistoryMsgGetTypeEnum.V2TIM_GET_CLOUD_NEWER_MSG,
        userID: userID,
        groupID: groupID,
        // Group reconciliation uses a Seq cursor only. Passing lastMsg too
        // would make the SDK silently ignore lastMsgSeq.
        lastMsgSeq: isGroup && missingSeqs.isEmpty ? newestSeq : 0,
        lastMsg: isGroup ? null : newestAnchor,
        messageSeqList: missingSeqs.isEmpty ? null : missingSeqs,
      );
      if (!attempt.isCurrent) {
        failHistoryReconciliation(
          request: request,
          reason: 'cloud_catch_up_stale_attempt',
        );
        return MessageCloudCatchUpDisposition.retry;
      }
      if (_shouldDeferCloudCatchUpWhileReadingHistory(storageKey)) {
        failHistoryReconciliation(
          request: request,
          reason: 'cloud_catch_up_deferred_reading_history',
        );
        return MessageCloudCatchUpDisposition.settled;
      }
      if (response == null) {
        failHistoryReconciliation(
          request: request,
          reason: 'cloud_catch_up_null_response',
        );
        return MessageCloudCatchUpDisposition.retry;
      }
      if (!isGroup &&
          !response.isFinished &&
          !_c2cCatchUpHasNewMessage(current, response.messageList)) {
        // C2C has no conversation-wide Seq. If the SDK returns the same page
        // under the same lastMsg anchor, another immediate continuation would
        // repeat the request forever. Keep reconciliation incomplete and wait
        // for a later foreground/reconnect/bottom-edge trigger.
        failHistoryReconciliation(
          request: request,
          reason: 'cloud_catch_up_no_progress',
        );
        return MessageCloudCatchUpDisposition.stalled;
      }
      final networkAfter = messageReconciliationNetworkState;
      final provenance = MessageReconciliationProvenance.resolve(
        requestedSource: MessageReconciliationSource.cloud,
        beforeRequest: networkBefore,
        afterResponse: networkAfter,
      );
      final returnedOldest = _oldestServerHistoryMessage(response.messageList);
      final returnedNewest = _newestServerHistoryMessage(response.messageList);
      final catchUpCursor = MessageHistoryCursor(
        direction: missingSeqs.isEmpty
            ? MessageHistoryCursorDirection.newer
            : MessageHistoryCursorDirection.older,
        lastMsgID: missingSeqs.isEmpty && !isGroup ? newestAnchor?.msgID : null,
        lastMsgSeq: missingSeqs.isNotEmpty
            ? missingSeqs.first
            : (isGroup && newestSeq > 0 ? newestSeq : null),
      );
      final commit = completeHistoryReconciliation(
        request: request,
        history: response.messageList,
        actualSource: provenance.actualSource,
        networkState: provenance.networkState,
        historyCommitSource: 'cloud_catch_up:$reason:a${attempt.number}',
        cloudHasMoreNewer: missingSeqs.isEmpty && !response.isFinished,
        batchKind: missingSeqs.isEmpty
            ? MessageHistoryBatchKind.newerCatchUp
            : MessageHistoryBatchKind.gapFill,
        historyIsFinished: response.isFinished,
        clearEpoch: messageHistoryCoverageFor(storageKey)?.clearEpoch ?? 0,
        requestedCursor: catchUpCursor,
        returnedBounds: MessageHistoryBounds(
          oldestMsgID: returnedOldest?.msgID,
          newestMsgID: returnedNewest?.msgID,
          oldestSeq: _messageNumericSeq(returnedOldest),
          newestSeq: _messageNumericSeq(returnedNewest),
        ),
        cloudResponseProven: provenance.cloudResponseProven,
      );
      if (commit == null) {
        return MessageCloudCatchUpDisposition.retry;
      }
      if (!provenance.cloudResponseProven) {
        return MessageCloudCatchUpDisposition.offline;
      }
      final state = _messageReconciliationWriter.coordinator.stateFor(
        storageKey,
      );
      final needsAnotherPage = missingSeqs.isEmpty && !response.isFinished;
      if (state.missingSeqRanges.isNotEmpty || needsAnotherPage) {
        return needsAnotherPage
            ? MessageCloudCatchUpDisposition.continuation
            : MessageCloudCatchUpDisposition.retry;
      }
      // A successful finished transport response ends this bounded pass, but
      // does not upgrade durable coverage to verified. A later open/reconnect
      // can validate again without three identical immediate retries.
      if (provenance.proofKind != MessageHistoryProofKind.serverContinuity) {
        return MessageCloudCatchUpDisposition.settled;
      }
      return MessageCloudCatchUpDisposition.complete;
    } catch (_) {
      if (attempt.isCurrent) {
        failHistoryReconciliation(
          request: request,
          reason: 'cloud_catch_up_exception',
        );
      }
      return MessageCloudCatchUpDisposition.retry;
    }
  }

  bool _c2cCatchUpHasNewMessage(
    List<V2TimMessage> current,
    List<V2TimMessage> fetched,
  ) {
    final known = <String, String>{};
    for (final message in current) {
      final id = (message.msgID?.trim().isNotEmpty ?? false)
          ? message.msgID!.trim()
          : (message.id?.trim() ?? '');
      if (id.isNotEmpty) {
        known[id] = _messageListContentSignature(<V2TimMessage>[message]);
      }
    }
    for (final message in fetched) {
      final id = (message.msgID?.trim().isNotEmpty ?? false)
          ? message.msgID!.trim()
          : (message.id?.trim() ?? '');
      if (id.isEmpty || !known.containsKey(id)) return true;
      if (known[id] != _messageListContentSignature(<V2TimMessage>[message])) {
        return true;
      }
    }
    return false;
  }

  List<int> _boundedMissingGroupSeqs(
    List<V2TimMessage> newestFirst, {
    required int maxCount,
  }) {
    final gaps = GapDetector.detectGaps(
      newestFirst: newestFirst,
      isGroup: true,
      fullScan: true,
    );
    if (gaps.isEmpty) {
      return const <int>[];
    }
    final seqs = <int>[];
    for (final gap in gaps) {
      final lower = gap.lowerSeq;
      final upper = gap.upperSeq;
      if (lower == null || upper == null) {
        continue;
      }
      for (var seq = lower + 1; seq < upper && seqs.length < maxCount; seq++) {
        seqs.add(seq);
      }
      if (seqs.length >= maxCount) {
        break;
      }
    }
    return List<int>.unmodifiable(seqs);
  }

  void _requestDetectedGroupGapCatchUp(String conversationID, GapInfo gap) {
    final storageKey = _resolveMessageListStorageKey(conversationID);
    final lower = gap.lowerSeq ?? 0;
    final upper = gap.upperSeq ?? 0;
    if (storageKey.isEmpty || lower <= 0 || upper <= lower + 1) {
      return;
    }
    if (_shouldDeferCloudCatchUpWhileReadingHistory(storageKey)) {
      ChatHistoryTrace.log(
        'seq_gap_catch_up_deferred_reading_history',
        conversationID: storageKey,
        extras: <String, Object?>{
          'lowerSeq': lower,
          'upperSeq': upper,
          'position': getMessageListPosition(storageKey).name,
          'memorySuppressed': isMemoryWindowSuppressed(storageKey),
        },
      );
      return;
    }
    final rangeKey = '$storageKey:$lower-$upper';
    final now = DateTime.now().millisecondsSinceEpoch;
    final previous = _groupGapAutoAttemptAtMs[rangeKey] ?? 0;
    if (now - previous < _groupGapAutoCooldownMs) {
      return;
    }
    _groupGapAutoAttemptAtMs[rangeKey] = now;
    unawaited(reconcileConversationCloud(
      storageKey,
      reason: 'seq_gap_${lower}_$upper',
    ));
  }

  bool _shouldDeferCloudCatchUpWhileReadingHistory(String conversationID) {
    return isMemoryWindowSuppressed(conversationID) ||
        isReadingHistory(conversationID);
  }

  void _clearResolvedGroupGapAttempts(
    String conversationID,
    List<GapInfo> gaps,
  ) {
    final storageKey = _resolveMessageListStorageKey(conversationID);
    final active = <String>{
      for (final gap in gaps)
        '$storageKey:${gap.lowerSeq ?? 0}-${gap.upperSeq ?? 0}',
    };
    _groupGapAutoAttemptAtMs.removeWhere(
      (key, _) => key.startsWith('$storageKey:') && !active.contains(key),
    );
  }

  /// 保留当前消息窗口，只撤销“首屏已验证”资格。
  ///
  /// LOCAL-only 预热刷新了旧暖窗时使用；不清消息、分页提示、搜索或位置状态。
  void clearInitialHistoryLoaded(String conversationID) {
    final trimmed = conversationID.trim();
    if (trimmed.isEmpty) {
      return;
    }
    _initialHistoryLoadedConvs.removeWhere(
      (key) => _isSameConversationID(key, trimmed),
    );
  }

  void markInitialHistoryMayHaveOlder(
    String conversationID, {
    required bool mayHaveOlder,
  }) {
    final keys = _historyFlagKeys(conversationID);
    if (keys.isEmpty) {
      return;
    }
    if (mayHaveOlder) {
      for (final key in keys) {
        _mayHaveOlderHistoryByConv[key] = true;
      }
    } else {
      for (final key in keys) {
        _mayHaveOlderHistoryByConv.remove(key);
      }
    }
  }

  bool mayHaveOlderHistory(String conversationID) {
    final trimmed = conversationID.trim();
    if (trimmed.isEmpty) {
      return false;
    }
    if (_mayHaveOlderHistoryByConv[trimmed] == true) {
      return true;
    }
    final normalized = _normalizeConversationID(trimmed);
    if (normalized.isNotEmpty &&
        _mayHaveOlderHistoryByConv[normalized] == true) {
      return true;
    }
    for (final entry in _mayHaveOlderHistoryByConv.entries) {
      if (entry.value && _isSameConversationID(entry.key, trimmed)) {
        return true;
      }
    }
    return false;
  }

  /// Raw in-memory window for warm/open short-circuit (alias-aware).
  ///
  /// 若本 key 上是空 list、但等价别名仍有消息，优先返回非空别名窗——
  /// 否则 tip-strip / hydrate_keep_empty 写过的空占位会永远挡住真实暖窗（灰屏）。
  List<V2TimMessage>? rawMessageList(String conversationID) {
    final trimmed = conversationID.trim();
    if (trimmed.isEmpty) {
      return null;
    }
    List<V2TimMessage>? emptyPlaceholder;
    final direct = _messageListMap[trimmed];
    if (direct != null) {
      if (direct.isNotEmpty) {
        return direct;
      }
      emptyPlaceholder = direct;
    }
    final normalized = _normalizeConversationID(trimmed);
    if (normalized.isNotEmpty) {
      final byNorm = _messageListMap[normalized];
      if (byNorm != null && byNorm.isNotEmpty) {
        return byNorm;
      }
      emptyPlaceholder ??= byNorm;
    }
    for (final entry in _messageListMap.entries) {
      if (!_isSameConversationID(entry.key, trimmed)) {
        continue;
      }
      final aliasList = entry.value;
      if (aliasList == null) {
        continue;
      }
      if (aliasList.isNotEmpty) {
        return aliasList;
      }
      emptyPlaceholder ??= aliasList;
    }
    return emptyPlaceholder;
  }

  /// 是否仍有进页 hydrate / 冷开并行 peek 在飞（别名感知）。
  bool hasOpenHydrateInFlight(String conversationID) {
    return _findOpenHydrateInFlight(conversationID) != null;
  }

  /// Last terminal result for the app-owned first-window bootstrap. This is
  /// separate from the in-flight map so a caller arriving just after
  /// completion can consume the same result without issuing LOCAL/CLOUD again.
  OpenHydrateResult? openHydrateResultFor(String conversationID) {
    final trimmed = conversationID.trim();
    if (trimmed.isEmpty) return null;
    final direct = _openHydrateResultByConv[trimmed];
    if (direct != null) return direct;
    final normalized = _normalizeConversationID(trimmed);
    if (normalized.isNotEmpty) {
      final byNorm = _openHydrateResultByConv[normalized];
      if (byNorm != null) return byNorm;
    }
    for (final entry in _openHydrateResultByConv.entries) {
      if (_isSameConversationID(entry.key, trimmed)) return entry.value;
    }
    return null;
  }

  OpenHydrateResult? takeOpenHydrateResult(String conversationID) {
    final result = openHydrateResultFor(conversationID);
    if (result != null) {
      clearOpenHydrateResult(conversationID);
    }
    return result;
  }

  void publishOpenHydrateResult(
    String conversationID,
    OpenHydrateResult result,
  ) {
    final key = conversationID.trim();
    if (key.isEmpty) return;
    for (final alias in _historyFlagKeys(key)) {
      _openHydrateResultByConv[alias] = result;
    }
  }

  void clearOpenHydrateResult(String conversationID) {
    final key = conversationID.trim();
    if (key.isEmpty) return;
    _openHydrateResultByConv.removeWhere(
      (alias, _) => _isSameConversationID(alias, key),
    );
  }

  Future<void>? _findOpenHydrateInFlight(String conversationID) {
    final trimmed = conversationID.trim();
    if (trimmed.isEmpty) {
      return null;
    }
    final direct = _openHydrateInFlightByConv[trimmed];
    if (direct != null) {
      return direct;
    }
    final normalized = _normalizeConversationID(trimmed);
    if (normalized.isNotEmpty) {
      final byNorm = _openHydrateInFlightByConv[normalized];
      if (byNorm != null) {
        return byNorm;
      }
    }
    for (final entry in _openHydrateInFlightByConv.entries) {
      if (_isSameConversationID(entry.key, trimmed)) {
        return entry.value;
      }
    }
    return null;
  }

  /// 聊天页 initState 启动的首屏灌入任务；hydrate 可短暂等待以避免 0→N 闪屏。
  void registerOpenHydrateInFlight(
    String conversationID,
    Future<dynamic> future,
  ) {
    final key = conversationID.trim();
    if (key.isEmpty) {
      return;
    }
    final existing = _findOpenHydrateInFlight(key);
    final normalizedFuture = future.then<void>((_) {});
    final tracked = existing == null
        ? normalizedFuture
        : Future.wait<void>(<Future<void>>[existing, normalizedFuture]);
    // 主 key + 等价别名都挂上，避免 c2c_/group_/裸 id 互相等不到。
    for (final alias in _historyFlagKeys(key)) {
      _openHydrateInFlightByConv[alias] = tracked;
    }
    unawaited(
      tracked.whenComplete(() {
        for (final alias in _historyFlagKeys(key)) {
          if (identical(_openHydrateInFlightByConv[alias], tracked)) {
            _openHydrateInFlightByConv.remove(alias);
          }
        }
      }),
    );
  }

  Future<void> awaitOpenHydrateInFlight(
    String conversationID, {
    Duration timeout = const Duration(milliseconds: 450),
  }) async {
    final inFlight = _findOpenHydrateInFlight(conversationID);
    if (inFlight == null) {
      return;
    }
    try {
      await inFlight.timeout(timeout);
    } on TimeoutException {
      // hydrate 自行兜底。
    }
  }

  int rawMessageCount(String conversationID) {
    return rawMessageList(conversationID)?.length ?? 0;
  }

  bool memoryWindowMissingNewer(String conversationID) {
    for (final entry in _memoryWindowMissingNewerByConv.entries) {
      if (entry.value && _isSameConversationID(entry.key, conversationID)) {
        return true;
      }
    }
    return false;
  }

  /// True when the in-memory window was trimmed and must be reconciled with
  /// SDK history before it can be considered a complete open window.
  /// This is deliberately separate from the SDK's own "has more" flags.
  bool memoryWindowNeedsReconciliation(String conversationID) {
    return memoryWindowMissingNewer(conversationID) ||
        _memoryWindowMissingOlderByConv.entries.any(
          (entry) =>
              entry.value && _isSameConversationID(entry.key, conversationID),
        );
  }

  bool memoryWindowReconciliationCovered(
    String conversationID,
    List<V2TimMessage>? messages,
  ) {
    if (!memoryWindowNeedsReconciliation(conversationID) ||
        messages == null ||
        messages.isEmpty) return false;
    final boundary = _memoryWindowBoundaryTimestampByConv.entries
        .where((e) => _isSameConversationID(e.key, conversationID))
        .map((e) => e.value)
        .fold<int>(0, (a, b) => a > b ? a : b);
    final newer = memoryWindowMissingNewer(conversationID);
    final older = _memoryWindowMissingOlderByConv.entries
        .any((e) => e.value && _isSameConversationID(e.key, conversationID));
    if (boundary <= 0) return messages.isNotEmpty;
    final timestamps =
        messages.map((m) => m.timestamp ?? 0).where((v) => v > 0);
    if (timestamps.isNotEmpty) {
      final minTs = timestamps.reduce((a, b) => a < b ? a : b);
      final maxTs = timestamps.reduce((a, b) => a > b ? a : b);
      if (newer && maxTs > boundary) return true;
      if (older && minTs < boundary) return true;
    }
    final seqs = messages
        .map((m) => int.tryParse(m.seq?.trim() ?? '') ?? 0)
        .where((v) => v > 0);
    final boundarySeq = int.tryParse(_memoryWindowBoundarySeqByConv.entries
            .firstWhere((e) => _isSameConversationID(e.key, conversationID),
                orElse: () => const MapEntry('', ''))
            .value) ??
        0;
    if (boundarySeq > 0 && seqs.isNotEmpty) {
      final minSeq = seqs.reduce((a, b) => a < b ? a : b);
      final maxSeq = seqs.reduce((a, b) => a > b ? a : b);
      return (newer && maxSeq > boundarySeq) || (older && minSeq < boundarySeq);
    }
    return false;
  }

  void markMemoryWindowMissingNewer(String conversationID) {
    final key = conversationID.trim();
    if (key.isEmpty) {
      return;
    }
    _memoryWindowMissingNewerByConv[key] = true;
  }

  void markMemoryWindowMissingOlder(String conversationID) {
    final key = conversationID.trim();
    if (key.isNotEmpty) _memoryWindowMissingOlderByConv[key] = true;
  }

  void clearMemoryWindowMissingNewer(String conversationID) {
    final keys = _memoryWindowMissingNewerByConv.keys
        .where((k) => _isSameConversationID(k, conversationID))
        .toList(growable: false);
    for (final key in keys) {
      _memoryWindowMissingNewerByConv.remove(key);
    }
  }

  void clearMemoryWindowReconciliation(String conversationID) {
    clearMemoryWindowMissingNewer(conversationID);
    final keys = _memoryWindowMissingOlderByConv.keys
        .where((k) => _isSameConversationID(k, conversationID))
        .toList(growable: false);
    for (final key in keys) {
      _memoryWindowMissingOlderByConv.remove(key);
      _memoryWindowBoundaryTimestampByConv.remove(key);
      _memoryWindowBoundarySeqByConv.remove(key);
    }
  }

  void setMemoryWindowSuppressed(String conversationID, bool suppressed) {
    final key = conversationID.trim();
    if (key.isEmpty) {
      return;
    }
    final wasSuppressed = isMemoryWindowSuppressed(conversationID);
    if (suppressed) {
      _memoryWindowSuppressedConvs.add(key);
    } else {
      _memoryWindowSuppressedConvs.removeWhere(
        (k) => _isSameConversationID(k, conversationID),
      );
    }
    if (wasSuppressed != suppressed) {
      ChatJitterDiag.log(
        'memory_window',
        conv: conversationID,
        extras: <String, Object?>{
          'action': suppressed ? 'suppress_on' : 'suppress_off',
          'rawCount': rawMessageCount(conversationID),
          'position': getMessageListPosition(conversationID).name,
        },
      );
    }
  }

  bool isMemoryWindowSuppressed(String conversationID) {
    return _memoryWindowSuppressedConvs.any(
      (k) => _isSameConversationID(k, conversationID),
    );
  }

  /// IM `onSyncServerFinish`：90 天漫游入库后通知打开中的聊天页重拉连续窗。
  void addRoamingSyncListener(VoidCallback listener) {
    if (_roamingSyncListeners.contains(listener)) {
      return;
    }
    _roamingSyncListeners.add(listener);
  }

  void removeRoamingSyncListener(VoidCallback listener) {
    _roamingSyncListeners.remove(listener);
  }

  void notifyRoamingSyncFinished() {
    final listeners = List<VoidCallback>.of(_roamingSyncListeners);
    for (final listener in listeners) {
      listener();
    }
  }

  /// 上翻分页前挂上视口锚，供 [setMessageList] 做双向窗口裁剪。
  void setMemoryWindowAnchor(
    String conversationID, {
    String? msgID,
    String? seq,
  }) {
    _memoryWindowAnchorConvID = conversationID.trim();
    _memoryWindowAnchorMsgID = msgID?.trim();
    _memoryWindowAnchorSeq = seq?.trim();
  }

  void clearMemoryWindowAnchor([String? conversationID]) {
    if (conversationID != null &&
        conversationID.trim().isNotEmpty &&
        _memoryWindowAnchorConvID != null &&
        !_isSameConversationID(_memoryWindowAnchorConvID!, conversationID)) {
      return;
    }
    _memoryWindowAnchorConvID = null;
    _memoryWindowAnchorMsgID = null;
    _memoryWindowAnchorSeq = null;
  }

  /// 对当前内存列表再跑一遍窗口闸门（搜索抑制解除后收束超长窗）。
  void applyMessageMemoryWindowNow(
    String conversationID, {
    String? memoryWindowAnchorMsgID,
    String? memoryWindowAnchorSeq,
    bool memoryWindowPreferLatest = false,
    bool forceWhileReadingHistory = false,
  }) {
    final list = rawMessageList(conversationID);
    if (list == null || list.isEmpty) {
      return;
    }
    if (list.length <= ChatMessageWindowPolicy.softMax) {
      return;
    }
    setMessageList(
      conversationID,
      List<V2TimMessage>.of(list),
      needResetNewMessageCount: false,
      replace: true,
      memoryWindowPreferLatest: memoryWindowPreferLatest,
      memoryWindowAnchorMsgID: memoryWindowAnchorMsgID,
      memoryWindowAnchorSeq: memoryWindowAnchorSeq,
      forceMemoryWindowTrimWhileReading: forceWhileReadingHistory,
    );
  }

  bool isMessageInMemoryWindow(
    String conversationID, {
    String? msgID,
    String? seq,
  }) {
    final list = rawMessageList(conversationID);
    if (list == null || list.isEmpty) {
      return false;
    }
    final id = msgID?.trim() ?? '';
    final s = seq?.trim() ?? '';
    for (final message in list) {
      if (id.isNotEmpty) {
        final mid = message.msgID?.trim() ?? '';
        final lid = message.id?.trim() ?? '';
        if (mid == id || lid == id) {
          return true;
        }
      }
      if (s.isNotEmpty && (message.seq?.trim() ?? '') == s) {
        return true;
      }
    }
    return false;
  }

  void removeMessageList(String conversationID) {
    final normalized = _normalizeConversationID(conversationID);
    if (OutgoingVisibleProbe.matches(conversationID) ||
        OutgoingVisibleProbe.matches(normalized) ||
        OutgoingVisibleProbe.matches(OutgoingVisibleProbe.lastConvID)) {
      OutgoingVisibleProbe.log(
        'remove_message_list',
        conversationID: conversationID,
        extras: <String, Object?>{
          'normalized': normalized,
          ...OutgoingVisibleProbe.trackedInList(rawMessageList(conversationID)),
        },
      );
    }
    final keys = <String>{
      if (conversationID.trim().isNotEmpty) conversationID.trim(),
      if (normalized.isNotEmpty) normalized,
    };
    keys.addAll(
      _messageListMap.keys
          .where(
            (mapKey) => keys.any((key) => _isSameConversationID(mapKey, key)),
          )
          .toList(growable: false),
    );
    // Drop every loaded/mayHaveOlder alias first — leftover flags after a wipe
    // make open path think the window is warm while map is empty (灰屏).
    _clearHistoryFlagsForConversation(conversationID);
    clearMemoryWindowMissingNewer(conversationID);
    clearMemoryWindowAnchor(conversationID);
    setMemoryWindowSuppressed(conversationID, false);
    for (final key in keys) {
      _messageListMap.remove(key);
      _rowLocalAliasByConversation.remove(key);
      _messageListContentSignatureByConv.remove(key);
      _historyMessagePositionMap.remove(key);
      _searchJumpStatusMap.remove(key);
      _messageListDisplayCache.removeWhere(
        (cacheKey, _) => _isSameConversationID(cacheKey, key),
      );
    }
    if (keys.isNotEmpty) {
      _markNeedsNotify();
    }
  }

  /// 清空聊天记录后的内存态：空列表 + 已加载完成。
  /// 必须保留 initialLoaded，否则消息列表会一直显示 bootstrapping 转圈。
  void clearLocalHistoryAsEmptyLoaded(String conversationID) {
    final normalized = _normalizeConversationID(conversationID);
    final keys = <String>{
      if (conversationID.trim().isNotEmpty) conversationID.trim(),
      if (normalized.isNotEmpty) normalized,
    };
    // hydrate / 预载会把同一份列表写在等价别名 key（如 group_ 前缀）下；
    // 只清字面 key 会留下旧窗口，再进页时被别名读回（清空后仍闪旧记录）。
    keys.addAll(
      _messageListMap.keys
          .where(
            (mapKey) => keys.any((key) => _isSameConversationID(mapKey, key)),
          )
          .toList(growable: false),
    );
    for (final key in keys) {
      // Clearing the visible window is also a formal replacement. Reset any
      // in-flight writer transaction first, then publish the empty snapshot
      // through the compatibility admission so stale history cannot restore
      // rows after the clear.
      _messageReconciliationWriter.reset(key);
      setMessageList(
        key,
        const <V2TimMessage>[],
        needResetNewMessageCount: false,
        isDeleteMsg: true,
        replace: true,
        applyMemoryWindow: false,
        historyCommitSource: 'clear_local_history',
      );
      _messageListContentSignatureByConv.remove(key);
      _initialHistoryLoadedConvs.add(key);
      _mayHaveOlderHistoryByConv.remove(key);
      _storeHistoryMessagePosition(key, HistoryMessagePosition.bottom);
      _searchJumpStatusMap.remove(key);
      // 展示层缓存必须同步失效：否则清空后再进页，getMessageList 仍会
      // 命中旧缓存，把已清空的消息整窗闪现一帧再塌掉（进页「抖两次」）。
      _messageListDisplayCache.removeWhere(
        (cacheKey, _) => _isSameConversationID(cacheKey, key),
      );
    }
    if (keys.isNotEmpty) {
      _markNeedsNotify();
    }
  }

  SearchJumpStatus getSearchJumpStatus(String conversationID) {
    return _searchJumpStatusMap[conversationID] ?? SearchJumpStatus.idle;
  }

  void setSearchJumpStatus(
    String conversationID,
    SearchJumpStatus status, {
    bool notify = false,
  }) {
    if (status == SearchJumpStatus.idle) {
      _searchJumpStatusMap.remove(conversationID);
    } else {
      _searchJumpStatusMap[conversationID] = status;
    }
    if (notify) {
      notifyListeners();
    }
  }

  void clearSearchJumpStatus(String conversationID, {bool notify = false}) {
    setSearchJumpStatus(conversationID, SearchJumpStatus.idle, notify: notify);
  }

  V2TimMessageReceipt? getMessageReadReceipt(String msgID) {
    return messageReadReceiptMap[msgID];
  }

  String _normalizeC2CKey(String value) {
    var key = value.trim();
    if (key.isEmpty) {
      return key;
    }
    if (key.toLowerCase().startsWith('c2c_')) {
      return key.substring(4);
    }
    if (key.toUpperCase().startsWith('C2C')) {
      return key.substring(3);
    }
    return key;
  }

  bool _isC2CConversationForPeer(String conversationID, String peerID) {
    final conv = _normalizeC2CKey(conversationID).toLowerCase();
    final peer = _normalizeC2CKey(peerID).toLowerCase();
    if (conv.isEmpty || peer.isEmpty) {
      return false;
    }
    return conv == peer;
  }

  int _c2cPeerReadTimestampFor(String conversationID) {
    final convKey = _normalizeC2CKey(conversationID).toLowerCase();
    if (convKey.isEmpty) {
      return 0;
    }
    var timestamp = 0;
    _c2cPeerReadTimestampMap.forEach((peerID, readAt) {
      if (_normalizeC2CKey(peerID).toLowerCase() == convKey &&
          readAt > timestamp) {
        timestamp = readAt;
      }
    });
    return timestamp;
  }

  bool isOutgoingC2CMessagePeerRead({
    required String conversationID,
    required V2TimMessage message,
  }) {
    if (message.isSelf != true) {
      return false;
    }
    final current = _messageInConversation(
      conversationID,
      clientId: message.id,
      msgID: message.msgID,
    );
    if (current?.isPeerRead == true || message.isPeerRead == true) {
      return true;
    }

    final msgID = current?.msgID ?? message.msgID;
    if (msgID != null && msgID.isNotEmpty) {
      final receipt = _messageReadReceiptMap[msgID];
      if (receipt?.isPeerRead == true) {
        return true;
      }
    }

    final readAt = _c2cPeerReadTimestampFor(conversationID);
    if (readAt <= 0) {
      return false;
    }
    final sentAt = current?.timestamp ?? message.timestamp ?? 0;
    return sentAt > 0 && sentAt <= readAt;
  }

  setShowC2cEditStatus(bool show) {
    _showC2cMessageEditStatus = show;
  }

  /// set edit status from chats
  setC2cMessageEditStatus(String userID, int status) {
    _c2cMessageEditStatusMap[userID] = status;
    if (status == 1) {
      if (_c2cMessageStatusShowTimer[userID] != null) {
        if (_c2cMessageStatusShowTimer[userID]!.isActive) {
          _c2cMessageStatusShowTimer[userID]!.cancel();
          _c2cMessageEditStatusMap[userID] = 0;
        }
      }
      _c2cMessageStatusShowTimer[userID] =
          Timer.periodic(const Duration(seconds: 5), (timer) {
        _c2cMessageEditStatusMap[userID] = 0;
        Timer? t = _c2cMessageStatusShowTimer[userID];
        if (t != null && t.isActive) {
          // 取消当前的定时器
          t.cancel();
        }
      });
    }
    notifyListeners();
  }

  int getC2cMessageEditStatus(String userID) {
    return _c2cMessageEditStatusMap[userID] ?? 0;
  }

  set abstractMessageBuilder(String Function(V2TimMessage message)? value) {
    _abstractMessageBuilder = value;
  }

  set appSearchBarBuilder(
    Widget Function(
      BuildContext context,
      TextEditingController controller,
      ValueChanged<String> onChanged,
    )? value,
  ) {
    _appSearchBarBuilder = value;
  }

  set appForwardSelectFriendPage(Widget Function(BuildContext context)? value) {
    _appForwardSelectFriendPage = value;
  }

  set appForwardSelectGroupPage(Widget Function(BuildContext context)? value) {
    _appForwardSelectGroupPage = value;
  }

  set appRootNavigator(NavigatorState? Function()? value) {
    _appRootNavigator = value;
  }

  set appContactPresenceBridgeBuilder(
    AppContactPresenceBridge Function(BuildContext context)? value,
  ) {
    _appContactPresenceBridgeBuilder = value;
  }

  set lifeCycle(ChatLifeCycle? value) {
    _lifeCycle = value;
    // messageShouldMount 变更后必须失效展示缓存，否则会继续用带「零高度行」的旧列表。
    _messageListDisplayCache.clear();
  }

  set groupApplicationList(List<V2TimGroupApplication> value) {
    _groupApplicationList = value;
  }

  void addGroupSystemNotice(GroupSystemNoticeItem notice) {
    _groupSystemNoticeList.removeWhere((item) => item.id == notice.id);
    _groupSystemNoticeList = [notice, ..._groupSystemNoticeList]
      ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
    notifyListeners();
  }

  setChatConfig(TIMUIKitChatConfig config) {
    chatConfig = config;
    _inboundChunkReveal.configure(
      interval: Duration(milliseconds: config.inboundChunkRevealIntervalMs),
      maxChunkSize: config.inboundChunkRevealMaxChunk,
      alignToFrame: true,
      burstBoostChunk: 0,
    );
  }

  initMessageMapFromLocalDatabase(
      List<V2TimConversation?> conversations) async {
    int index = 0;
    for (V2TimConversation? conversationItem in conversations) {
      if (conversationItem == null || conversationItem.type == null) {
        return;
      }
      final conversationID =
          TencentUtils.checkString(conversationItem.userID) ??
              TencentUtils.checkString(conversationItem.groupID) ??
              conversationItem.conversationID;
      if (messageListMap[conversationID] == null ||
          messageListMap[conversationID]!.isEmpty) {
        index++;
        Future.delayed(Duration(milliseconds: 500 * index), () {
          preloadMessageForConversation(
              conversationID: conversationID,
              conversationType: ConvType.values[conversationItem.type!]);
        });
      }
    }
  }

  preloadMessageForConversation({
    required ConvType conversationType,
    required String conversationID,
  }) async {
    final response = await _messageService.getHistoryMessageList(
        count: 10,
        getType: HistoryMsgGetTypeEnum.V2TIM_GET_LOCAL_OLDER_MSG,
        userID: conversationType == ConvType.c2c ? conversationID : null,
        groupID: conversationType == ConvType.group ? conversationID : null);
    final storageKey = _resolveMessageListStorageKey(conversationID);
    if (storageKey.isEmpty || _mergedAliasMessageList(storageKey).isNotEmpty) {
      return;
    }
    final commit = setMessageList(
      storageKey,
      response,
      needResetNewMessageCount: false,
      replace: true,
      applyMemoryWindow: false,
      historyCommitSource: 'preload_local_history',
    );
    if (commit.rawCount > 0) {
      // 会话列表预载时先种行高，进聊天页不再全靠 56 估。
      ChatMessageHeightCache.instance.seedEstimatesForMessages(response);
    }
  }

  clearMessageMapFromLocal() async {
    final prefs = await SharedPreferences.getInstance();
    final List<String>? localMsgIDList = prefs.getStringList(localMsgIDListKey);

    if (localMsgIDList != null) {
      for (String convID in localMsgIDList) {
        prefs.remove("$localKeyPrefix$convID");
      }
    }

    prefs.remove(localMsgIDListKey);
  }

  Future<void> updateMessageFromController(
      {required String msgID,
      required String conversationID,
      required ConvType conversationType}) async {
    final lifecycleGeneration = _messageHistoryCoverageSessionGeneration;
    final TUIChatModelTools tools = serviceLocator<TUIChatModelTools>();
    V2TimMessage? newMessage = await tools.getExistingMessageByID(
        msgID: msgID,
        conversationID: conversationID,
        conversationType: conversationType);
    if (newMessage != null && _isMessageLifecycleCurrent(lifecycleGeneration)) {
      // Keep the scope captured by the controller request. The selected
      // conversation may have changed while the SDK lookup was in flight.
      onMessageModified(newMessage, conversationID);
    }
  }

  clearData() {
    // Flush all buffered inbound messages before clearing state so SDK
    // push messages that haven't been committed to messageListMap are
    // not lost. SDK internal SQLite persists them, but flushing ensures
    // consistency for any in-flight presentation.
    _inboundBatchCoalescer.flushAll();
    _inboundChunkReveal.flushAll();
    for (final buffer in _reorderBuffersByConv.values) {
      buffer.dispose();
    }
    _reorderBuffersByConv.clear();
    _gapCatchUpInFlight.clear();
    _groupGapAutoAttemptAtMs.clear();
    for (final timer in _cloudContinuationTimersByConv.values) {
      timer.cancel();
    }
    _cloudContinuationTimersByConv.clear();
    _cloudContinuationRoundsByConv.clear();
    _cloudCatchUpStalledAnchorByConv.clear();
    _messageReconciliationWriter.resetAll();
    _boundedCloudCatchUp.invalidateAll();
    _messageHistoryCoverageSessionGeneration += 1;
    _messageHistoryCoverageByConv.clear();
    _messageHistoryCoverageLoadedConvs.clear();
    _messageHistoryCoverageLoadInFlight.clear();
    _messageHistoryCoverageUpdateTailByConv.clear();
    _messageHistoryCoverageRequestGenerationByConv.clear();
    _openHydrateResultByConv.clear();
    for (final timer in _activeReadReportDebounceMap.values) {
      timer.cancel();
    }
    _activeReadReportDebounceMap.clear();
    _lastActiveReadReportAtMs.clear();
    unawaited(appMessageHistoryCoverageRepository?.clearSession());
    _messageListMap.clear();
    _lastHistoryCommitMetadataByConv.clear();
    _rowLocalAliasByConversation.clear();
    _initialHistoryLoadedConvs.clear();
    _mayHaveOlderHistoryByConv.clear();
    _currentConversationList.clear();
    _totalUnreadCount = 0;
    _pendingGroupApplicationRefreshTimer?.cancel();
    _groupApplicationRefreshTask = null;
    _lastGroupApplicationRefreshAt = null;
    _groupApplicationList?.clear();
    _groupSystemNoticeList.clear();
    _totalUnreadCount = 0;
    _inboundUnreadStateByConversation.clear();
    _deferredUntilUserBottomConversations.clear();
    _messageReadReceiptMap.clear();
    _messageListProgressMap.clear();
    _localMergerMessageCache.clear();
    _messageProjectionRevisionByConv.clear();
    _messageListRevisionByConv.clear();
    _inboundHiddenKeysByConv.clear();
    _authoritativeDeferredIncomingKeys.clear();
    _inboundFastForwardMessageKeys.clear();
    _messageListDisplayCache.clear();
    _bulkMessageSyncDepthByConv.clear();
    _pendingPinAfterBulkByConv.clear();
    _userScrollToBottomConvId = null;
    _userScrollToBottomTransactionActive = false;
    _userScrollToBottomUntilMs = 0;
    _lastInboundScrollFollowChunk = const <V2TimMessage>[];
    _inboundScrollFollowSessionEnding = false;
    notifyListeners();
  }

  clearReceivedNewMessageCount() {
    _inboundUnreadStateFor(currentSelectedConv).receivedCount = 0;
  }

  _preLoadImage(List<V2TimMessage> msgList) {
    List<V2TimMessage> needPreViewList =
        msgList.sublist(0, max(0, min(5, msgList.length - 1)));
    for (var msgItem in needPreViewList) {
      V2TimImage? getImageFromList(V2TimImageTypesEnum imgType) {
        V2TimImage? img = MessageUtils.getImageFromImgList(
            msgItem.imageElem?.imageList,
            HistoryMessageDartConstant.imgPriorMap[imgType] ??
                HistoryMessageDartConstant.oriImgPrior);
        return img;
      }

      V2TimImage? originalImg = getImageFromList(V2TimImageTypesEnum.small);
      if (originalImg?.localUrl != null && originalImg!.localUrl != "") {
        try {
          ImageConfiguration configuration = const ImageConfiguration();
          final image = FileImage(File((originalImg.localUrl!)));

          image.resolve(configuration).addListener(
              ImageStreamListener((ImageInfo image, bool synchronousCall) {
            final tempImg = image.image;
            _preloadImageMap[msgItem.seq! +
                msgItem.timestamp.toString() +
                (msgItem.msgID ?? "")] = tempImg;
            outputLogger.i("cacheImage ${msgItem.msgID}");
          }));
        } catch (e) {
          outputLogger.i("cacheImage error ${msgItem.msgID}");
        }
      }
    }
  }

  int getMessageProgress(String? msgID) {
    return _messageListProgressMap[msgID] ?? 0;
  }

  Size? getFileMessageSize(String? msgID) {
    if (msgID == null || msgID.isEmpty) {
      return null;
    }
    return _fileMessageSizeMap[msgID];
  }

  String getFileMessageLocation(String? msgID) {
    return _fileListLocationMap[msgID] ?? '';
  }

  setMessageProgress(String msgID, int progress) {
    _messageListProgressMap[msgID] = progress;
    if (progress > 0 && progress < 100) {
      _isDownloading = true;
    } else {
      _isDownloading = false;
      _waitingDownloadList.removeWhere((element) {
        String msgIDItem = element["msgID"] ?? "";
        if (msgIDItem.isNotEmpty) {
          if (msgID == msgIDItem) {
            outputLogger.i("remove download");
            return true;
          }
        }
        return false;
      });
    }
    _markNeedsNotify();
  }

  /// 上传进度高频更新只由 [ChatUiStateStore] 驱动对应气泡遮罩刷新，禁止
  /// notify 全局消息模型导致整张聊天列表参与 rebuild。
  void _setUploadProgressSilently(String msgID, int progress) {
    if (msgID.isEmpty) {
      return;
    }
    _messageListProgressMap[msgID] = progress.clamp(0, 100);
  }

  void _clearUploadProgressSilently(String? msgID) {
    final id = msgID?.trim() ?? '';
    if (id.isNotEmpty) {
      _messageListProgressMap.remove(id);
    }
  }

  void clearMessageProgress(String? msgID) {
    if (msgID == null || msgID.isEmpty) {
      return;
    }
    _messageListProgressMap.remove(msgID);
    _fileListLocationMap.remove(msgID);
    _fileMessageSizeMap.remove(msgID);
    notifyListeners();
  }

  void clearUploadProgress(String? msgID) {
    if (msgID == null || msgID.isEmpty) {
      return;
    }
    _messageListProgressMap.remove(msgID);
    _markNeedsNotify();
  }

  /// Metadata writes used while adopting an already-mounted outgoing row.
  /// The adoption publishes one row revision after all fields are coherent.
  void setUploadProgressRowLocal(String msgID, int progress) {
    _setUploadProgressSilently(msgID, progress);
  }

  void clearUploadProgressRowLocal(String? msgID) {
    _clearUploadProgressSilently(msgID);
  }

  void setFileMessageLocationRowLocal(
    String msgID,
    String location, {
    Size? imageSize,
  }) {
    _fileListLocationMap[msgID] = location;
    if (imageSize != null && imageSize.width > 0 && imageSize.height > 0) {
      _fileMessageSizeMap[msgID] = imageSize;
    }
  }

  setFileMessageLocation(String msgID, String location, {Size? imageSize}) {
    _fileListLocationMap[msgID] = location;
    if (imageSize != null && imageSize.width > 0 && imageSize.height > 0) {
      _fileMessageSizeMap[msgID] = imageSize;
    }
    notifyListeners();
  }

  _editStatusCheck(V2TimMessage msg) {
    bool isStatusMessage = false;
    if (msg.customElem != null &&
        TencentUtils.checkString(msg.groupID) == null) {
      V2TimCustomElem customElem = msg.customElem!;
      String sender = msg.sender ?? "";
      if (customElem.data!.isNotEmpty) {
        try {
          Map<String, dynamic>? data = json.decode(customElem.data ?? "");
          if (data != null) {
            var businessID = data["businessID"];
            int? userAction = data["userAction"];
            String? actionParam = data["actionParam"];
            if (businessID.toString() == "user_typing_status") {
              int? typingStatus = data["typingStatus"];
              if (sender != "") {
                if (typingStatus != null) {
                  setC2cMessageEditStatus(sender, typingStatus);
                } else {
                  // 兼容旧版本逻辑
                  if (userAction != null) {
                    if (userAction == 14) {
                      if (actionParam != null) {
                        setC2cMessageEditStatus(sender,
                            actionParam == "EIMAMSG_InputStatus_Ing" ? 1 : 0);
                      }
                    }
                  }
                }
              }
              return true;
            }
          }
        } catch (err) {
          // err;
        }
      }
    }
    return isStatusMessage;
  }

  _checkFromUserisActive(V2TimMessage msg) async {
    // check message is c2c message and message cloudcustomdata field is not null
    if (msg.groupID == null && msg.cloudCustomData != null) {
      try {
        Map<String, dynamic> data = json.decode(msg.cloudCustomData ?? "");
        Map<String, dynamic>? messageFeature = data["messageFeature"];
        if (messageFeature != null) {
          int needTyping = messageFeature["needTyping"];
          if (needTyping == 1) {
            _c2cMessageFromUserActiveMap[msg.sender ?? ""] = true;

            if (_c2cMessageActiveTimer[msg.sender ?? ""] != null) {
              Timer? t = _c2cMessageActiveTimer[msg.sender ?? ""];
              if (t != null && t.isActive) {
                //取消原来的定时器
                t.cancel();
              }
            }
            _c2cMessageActiveTimer[msg.sender ?? ""] =
                Timer.periodic(const Duration(seconds: 30), (timer) {
              _c2cMessageFromUserActiveMap[msg.sender ?? ""] = false;
              Timer? t = _c2cMessageActiveTimer[msg.sender ?? ""];
              if (t != null && t.isActive) {
                // 取消当前的定时器
                t.cancel();
              }
            });
          }
        }
      } catch (err) {
        // err
      }
    }
  }

  sendEditStatusMessage(bool isEditing, String toUser) async {
    if (!_showC2cMessageEditStatus) {
      return;
    }
    if (!(_c2cMessageFromUserActiveMap[toUser] ?? false)) {
      return;
    }
    V2TimMsgCreateInfoResult? res = await _messageService.createCustomMessage(
        data: json.encode({
      "businessID": "user_typing_status",
      "typingStatus": isEditing == true ? 1 : 0,
      "userAction": 14,
      "version": 0,
      "actionParam": isEditing == true
          ? "EIMAMSG_InputStatus_Ing"
          : "EIMAMSG_InputStatus_End"
    }));
    if (res != null) {
      _sendMessage(
        id: res.id!,
        convID: toUser,
        convType: ConvType.c2c,
        onlineUserOnly: true,
        isEditStatusMessage: true,
      );
    }
  }

  void refreshGroupApplicationList({bool force = false}) {
    if (_groupApplicationRefreshTask != null) {
      if (force) {
        _pendingGroupApplicationRefreshTimer?.cancel();
        _pendingGroupApplicationRefreshTimer = Timer(
          const Duration(milliseconds: 300),
          () => refreshGroupApplicationList(force: true),
        );
      }
      return;
    }

    final now = DateTime.now();
    final last = _lastGroupApplicationRefreshAt;
    if (!force && last != null) {
      final elapsed = now.difference(last);
      if (elapsed < _groupApplicationRefreshInterval) {
        _pendingGroupApplicationRefreshTimer?.cancel();
        _pendingGroupApplicationRefreshTimer = Timer(
          _groupApplicationRefreshInterval - elapsed,
          () => refreshGroupApplicationList(force: true),
        );
        return;
      }
    }

    _lastGroupApplicationRefreshAt = now;
    final task = _loadGroupApplicationList();
    _groupApplicationRefreshTask = task.whenComplete(() {
      if (identical(_groupApplicationRefreshTask, task)) {
        _groupApplicationRefreshTask = null;
      }
    });
  }

  Future<void> _loadGroupApplicationList() async {
    final res = await _groupServices.getGroupApplicationList();
    final nextList = res.data?.groupApplicationList
            ?.whereType<V2TimGroupApplication>()
            .toList() ??
        [];
    if (_isSameGroupApplicationList(
        _groupApplicationList ?? const [], nextList)) {
      return;
    }
    _groupApplicationList = nextList;
    notifyListeners();
  }

  bool _isSameGroupApplicationList(
    List<V2TimGroupApplication> oldList,
    List<V2TimGroupApplication> nextList,
  ) {
    if (oldList.length != nextList.length) return false;
    for (var i = 0; i < oldList.length; i++) {
      final oldItem = oldList[i];
      final nextItem = nextList[i];
      if (oldItem.groupID != nextItem.groupID ||
          oldItem.fromUser != nextItem.fromUser ||
          oldItem.toUser != nextItem.toUser ||
          oldItem.addTime != nextItem.addTime ||
          oldItem.type != nextItem.type ||
          oldItem.handleStatus != nextItem.handleStatus ||
          oldItem.handleResult != nextItem.handleResult) {
        return false;
      }
    }
    return true;
  }

  cancelAllTimer() {
    _c2cMessageActiveTimer.forEach((key, value) {
      if (value.isActive) {
        value.cancel();
      }
    });
    _c2cMessageStatusShowTimer.forEach((key, value) {
      if (value.isActive) {
        value.cancel();
      }
    });
  }

  static const String _outgoingLocalSeqKey = '__outgoingLocalSeq';
  static const String _outgoingLocalSentAtKey = '__outgoingLocalSentAt';

  static int? _outgoingRandomValue(V2TimMessage message) {
    final random = message.random;
    if (random == null || random == 0) {
      return null;
    }
    return random;
  }

  static int? _readOutgoingLocalSeq(V2TimMessage message) {
    return _readOutgoingLocalInt(message, _outgoingLocalSeqKey);
  }

  static int? _readOutgoingLocalSentAt(V2TimMessage message) {
    return _readOutgoingLocalInt(message, _outgoingLocalSentAtKey);
  }

  static int? _readOutgoingLocalInt(V2TimMessage message, String key) {
    final raw = message.localCustomData?.trim();
    if (raw == null || raw.isEmpty) {
      return null;
    }
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) {
        return null;
      }
      final value = decoded[key];
      if (value is int) {
        return value;
      }
      if (value is num) {
        return value.toInt();
      }
    } catch (_) {}
    return null;
  }

  static void _writeOutgoingLocalSeq(V2TimMessage message, int seq) {
    final data = <String, dynamic>{};
    final raw = message.localCustomData?.trim();
    if (raw != null && raw.isNotEmpty) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is Map) {
          data.addAll(Map<String, dynamic>.from(decoded));
        }
      } catch (_) {}
    }
    data[_outgoingLocalSeqKey] = seq;
    data[_outgoingLocalSentAtKey] ??=
        DateTime.now().millisecondsSinceEpoch ~/ 1000;
    message.localCustomData = jsonEncode(data);
  }

  static void _preserveOutgoingLocalOrderData(
    V2TimMessage previous,
    V2TimMessage merged,
  ) {
    final previousRaw = previous.localCustomData?.trim();
    if (previousRaw == null || previousRaw.isEmpty) {
      return;
    }
    final data = <String, dynamic>{};
    final mergedRaw = merged.localCustomData?.trim();
    if (mergedRaw != null && mergedRaw.isNotEmpty) {
      try {
        final decoded = jsonDecode(mergedRaw);
        if (decoded is Map) {
          data.addAll(Map<String, dynamic>.from(decoded));
        }
      } catch (_) {}
    }
    try {
      final previousDecoded = jsonDecode(previousRaw);
      if (previousDecoded is Map) {
        for (final key in const [
          _outgoingLocalSeqKey,
          _outgoingLocalSentAtKey,
          kChatOutgoingStableIdKey,
          kChatMediaBatchIdKey,
          kChatMediaBatchIndexKey,
        ]) {
          if (previousDecoded.containsKey(key)) {
            data[key] = previousDecoded[key];
          }
        }
      }
    } catch (_) {}
    if (data.isNotEmpty) {
      merged.localCustomData = jsonEncode(data);
    }
  }

  void assignOutgoingLocalSeq(String conversationID, V2TimMessage message) {
    final convID = _safeConversationId(conversationID);
    if (convID.isEmpty) {
      return;
    }
    final next = (_outgoingLocalSeqByConv[convID] ?? 0) + 1;
    _outgoingLocalSeqByConv[convID] = next;
    _writeOutgoingLocalSeq(message, next);
    _logOutgoingSendOrder(
      event: 'tap',
      convID: convID,
      message: message,
      clientId: message.id,
      mergePath: 'assign_local_seq',
    );
  }

  void _logOutgoingSendOrder({
    required String event,
    required String convID,
    required V2TimMessage message,
    String? clientId,
    String? mergePath,
    int? existingIndex,
    bool? reordered,
    String? warn,
  }) {
    if (!ChatJitterDiag.enabled) {
      return;
    }
    final list = _messageListMap[convID] ?? const <V2TimMessage>[];
    final msgID = message.msgID?.trim() ?? '';
    final idValue = clientId?.trim().isNotEmpty == true
        ? clientId!.trim()
        : (message.id?.trim() ?? '');
    var finalIndex = -1;
    for (var i = 0; i < list.length; i++) {
      final item = list[i];
      if (msgID.isNotEmpty && item.msgID == msgID) {
        finalIndex = i;
        break;
      }
      if (idValue.isNotEmpty && item.id == idValue) {
        finalIndex = i;
        break;
      }
    }
    final localSeq = _readOutgoingLocalSeq(message);
    final existing = existingIndex ?? -1;
    final reorderFlag = reordered == true;
    final warnSuffix = warn == null || warn.isEmpty ? '' : ' warn=$warn';
    debugPrint(
      '[IM_SEND_ORDER] event=$event conv=$convID clientId=$idValue msgID=$msgID '
      'tapOrder=$localSeq localSeq=$localSeq serverSeq=${message.seq ?? ''} '
      'timestamp=${message.timestamp ?? ''} finalIndex=$finalIndex listLen=${list.length} '
      'existingIndex=$existing path=${mergePath ?? ''} reordered=$reorderFlag '
      'isSelf=${message.isSelf} random=${message.random}$warnSuffix',
    );
    outputLogger.i(
      '[IM_SEND_ORDER] event=$event conv=$convID clientId=$idValue msgID=$msgID '
      'localSeq=$localSeq serverSeq=${message.seq ?? ''} ts=${message.timestamp ?? ''} '
      'path=${mergePath ?? ''} reordered=$reorderFlag warn=${warn ?? ''}',
    );
  }

  static String? _outgoingCorrelationKey(V2TimMessage message) {
    if (message.isSelf != true) {
      return null;
    }
    // Stable id bridges optimistic clientId → SDK create id across swaps.
    // Prefer it over random/id so dedupe collapses 一图两气泡 pairs.
    final stableId = readOutgoingStableId(message)?.trim();
    if (stableId != null && stableId.isNotEmpty) {
      return 'stable:$stableId:t${message.elemType}';
    }
    final random = _outgoingRandomValue(message);
    if (random != null) {
      // 带上 elemType，避免不同消息偶发同 random 时文字/图片被并成一条。
      return 'rand:$random:t${message.elemType}';
    }
    final id = message.id?.trim();
    if (id != null && id.isNotEmpty) {
      return 'id:$id:t${message.elemType}';
    }
    return null;
  }

  static bool _isClientPlaceholderMessage(V2TimMessage message) {
    if (message.isSelf != true) {
      return false;
    }
    if (message.status != MessageStatus.V2TIM_MSG_STATUS_SENDING) {
      return false;
    }
    final id = message.id;
    return id != null && id.isNotEmpty;
  }

  static bool _isResolvedOutgoingMessage(V2TimMessage message) {
    if (message.isSelf != true) {
      return false;
    }
    // C2C 镜像 dup（对方内容却标 isSelf）不是真实 outgoing ack。
    if (_isC2cConversationMessage(message) &&
        _c2cDirectionConsistencyScore(message) < 3) {
      return false;
    }
    final msgID = message.msgID?.trim();
    if (msgID == null || msgID.isEmpty) {
      return false;
    }
    final id = message.id?.trim();
    if (id != null && id.isNotEmpty && id == msgID) {
      return false;
    }
    return message.status != MessageStatus.V2TIM_MSG_STATUS_SENDING;
  }

  static bool _outgoingMessagesCorrelate(
    V2TimMessage a,
    V2TimMessage b,
  ) {
    if (a.isSelf != true || b.isSelf != true) {
      return false;
    }
    // 同 random/id 也必须同类型：否则文字占位与图片回执可能被误并。
    if (a.elemType != b.elemType) {
      return false;
    }
    final keyA = _outgoingCorrelationKey(a);
    final keyB = _outgoingCorrelationKey(b);
    if (keyA != null && keyB != null && keyA == keyB) {
      return true;
    }
    final seqA = _readOutgoingLocalSeq(a);
    final seqB = _readOutgoingLocalSeq(b);
    if (seqA != null && seqB != null && seqA == seqB) {
      return true;
    }
    // Optimistic image keeps a local path; adopt copies it onto the SDK
    // message. Path equality is a safe bridge when one side is still a
    // placeholder and random/id have not converged yet.
    if (a.elemType == MessageElemType.V2TIM_ELEM_TYPE_IMAGE &&
        (_isClientPlaceholderMessage(a) || _isClientPlaceholderMessage(b))) {
      final pathA = a.imageElem?.path?.trim() ?? '';
      final pathB = b.imageElem?.path?.trim() ?? '';
      if (pathA.isNotEmpty && pathA == pathB) {
        return true;
      }
    }
    if (_outgoingRandomValue(a) != null || _outgoingRandomValue(b) != null) {
      return false;
    }
    final placeholder = _isClientPlaceholderMessage(a) ||
        _isClientPlaceholderMessage(b) ||
        _isResolvedOutgoingMessage(a) ||
        _isResolvedOutgoingMessage(b);
    if (!placeholder) {
      return false;
    }
    // Never correlate by timestamp alone: same-second sends share timestamp
    // and would merge acks into the wrong placeholder.
    return false;
  }

  /// 存储序列为 newest-first：任一相邻对 chronologically 逆序则需重排。
  @visibleForTesting
  static bool isNewestFirstStorageOrderValid(List<V2TimMessage> list) {
    if (list.length < 2) {
      return true;
    }
    for (var i = 0; i < list.length - 1; i++) {
      if (compareMessagesChronological(list[i], list[i + 1]) < 0) {
        return false;
      }
    }
    return true;
  }

  /// 秒级 epoch；字段误存毫秒时归一化（Web/归档混源常见）。
  @visibleForTesting
  static int normalizeMessageEpochSeconds(int? raw) {
    if (raw == null || raw <= 0) {
      return 0;
    }
    if (raw >= 1000000000000) {
      return raw ~/ 1000;
    }
    return raw;
  }

  static int messageEpochSecondsForDisplay(V2TimMessage message) {
    return normalizeMessageEpochSeconds(_messageSortTimestamp(message));
  }

  static int _findOutgoingPlaceholderIndex(
    List<V2TimMessage> list,
    V2TimMessage incoming,
  ) {
    final candidates = <int>[];
    for (var i = 0; i < list.length; i++) {
      final element = list[i];
      if (!_isClientPlaceholderMessage(element)) {
        continue;
      }
      if (element.elemType != incoming.elemType) {
        continue;
      }
      candidates.add(i);
    }
    if (candidates.isEmpty) {
      return -1;
    }
    final incomingStable = readOutgoingStableId(incoming)?.trim();
    if (incomingStable != null && incomingStable.isNotEmpty) {
      for (final i in candidates) {
        if (readOutgoingStableId(list[i]) == incomingStable) {
          return i;
        }
      }
    }
    if (candidates.length == 1) {
      return candidates.first;
    }
    final incomingRandom = _outgoingRandomValue(incoming);
    if (incomingRandom != null) {
      for (final i in candidates) {
        if (list[i].random == incomingRandom) {
          return i;
        }
      }
    }
    final incomingId = incoming.id?.trim();
    if (incomingId != null && incomingId.isNotEmpty) {
      for (final i in candidates) {
        if (list[i].id == incomingId) {
          return i;
        }
      }
    }
    final incomingMsgID = incoming.msgID?.trim();
    if (incomingMsgID != null && incomingMsgID.isNotEmpty) {
      for (final i in candidates) {
        if (list[i].msgID?.trim() == incomingMsgID) {
          return i;
        }
      }
    }
    final incomingLocalSeq = _readOutgoingLocalSeq(incoming);
    if (incomingLocalSeq != null) {
      for (final i in candidates) {
        if (_readOutgoingLocalSeq(list[i]) == incomingLocalSeq) {
          return i;
        }
      }
    }
    if (incoming.elemType == MessageElemType.V2TIM_ELEM_TYPE_IMAGE) {
      final path = incoming.imageElem?.path?.trim() ?? '';
      if (path.isNotEmpty) {
        final pathMatches = <int>[];
        for (final i in candidates) {
          if (list[i].imageElem?.path?.trim() == path) {
            pathMatches.add(i);
          }
        }
        if (pathMatches.length == 1) {
          return pathMatches.first;
        }
      }
    }
    if (incoming.elemType == MessageElemType.V2TIM_ELEM_TYPE_SOUND) {
      final newDuration = incoming.soundElem?.duration;
      for (final i in candidates) {
        if (list[i].soundElem?.duration == newDuration) {
          return i;
        }
      }
    }
    // Ambiguous when multiple placeholders share type without random/id/msgID.
    // Orphan-insert + chronological sort is safer than guessing FIFO.
    return -1;
  }

  /// Binds SDK-assigned [msgID] to a sending placeholder before send completes.
  void bindOutgoingSyncMsgId(
    String conversationID,
    String clientId,
    String msgID,
  ) {
    final id = clientId.trim();
    final serverMsgID = msgID.trim();
    if (id.isEmpty || serverMsgID.isEmpty) {
      return;
    }
    final storageKey = _resolveMessageListStorageKey(conversationID);
    if (storageKey.isEmpty) {
      return;
    }

    final current = _mergedAliasMessageList(storageKey);
    final index = current.indexWhere(
      (item) =>
          item.isSelf == true &&
          item.id == id &&
          (item.msgID == null || item.msgID!.isEmpty || item.msgID == id),
    );
    if (index < 0) {
      return;
    }

    final previous = current[index];
    final updated = _cloneMessage(previous);
    updated.msgID = serverMsgID;
    final stableIdentity = readOutgoingStableId(previous) ?? id;
    final commit = commitMessageDelta(
      MessageDelta<V2TimMessage>(
        conversationKey: storageKey,
        eventID: 'send_bind:$id:$serverMsgID',
        kind: MessageDeltaKind.optimisticAdoption,
        source: MessageDeltaSource.sendPipeline,
        generation: messageDeltaGenerationFor(storageKey),
        clearEpoch: messageDeltaClearEpochFor(storageKey),
        upserts: <MessageReconciliationRecord<V2TimMessage>>[
          MessageReconciliationRecord<V2TimMessage>(
            value: updated,
            msgID: updated.msgID,
            localID: updated.id,
            outgoingStableID: stableIdentity,
            seq: updated.seq,
          ),
        ],
      ),
    );
    if (commit == null) {
      // Rejected/stale/active-history binds must not mutate the formal list.
      return;
    }
    _chatUiStateStore.bindMessageAlias(
      storageKey,
      id,
      ChatUiStateStore.messageKeyOf(updated),
    );
    ChatMessageHeightCache.instance.rememberAlias(id, serverMsgID);
    _markMessageRowChanged(storageKey, updated, extraKey: id);
    _markNeedsNotify();
  }

  @visibleForTesting
  static int findOutgoingPlaceholderIndexForTesting(
    List<V2TimMessage> list,
    V2TimMessage incoming,
  ) {
    return _findOutgoingPlaceholderIndex(list, incoming);
  }

  @visibleForTesting
  static void preserveOutgoingLocalOrderDataForTesting(
    V2TimMessage previous,
    V2TimMessage merged,
  ) {
    _preserveOutgoingLocalOrderData(previous, merged);
  }

  @visibleForTesting
  static int? readOutgoingLocalSeqForTesting(V2TimMessage message) {
    return _readOutgoingLocalSeq(message);
  }

  int findReplaceableOutgoingIndex(
    String convID,
    V2TimMessage message, {
    String? priorTempId,
    List<V2TimMessage>? listOverride,
  }) {
    final list = listOverride ?? _messageListMap[convID] ?? [];
    if (priorTempId != null && priorTempId.isNotEmpty) {
      final byTemp = list.indexWhere(
        (item) => item.id == priorTempId || item.msgID == priorTempId,
      );
      if (byTemp != -1) {
        return byTemp;
      }
    }
    final id = message.id;
    if (id != null && id.isNotEmpty) {
      final byId = list.indexWhere((item) => item.id == id);
      if (byId != -1) {
        return byId;
      }
    }
    final msgID = message.msgID;
    if (msgID != null && msgID.isNotEmpty) {
      final byMsgID = list.indexWhere((item) => item.msgID == msgID);
      if (byMsgID != -1) {
        return byMsgID;
      }
    }
    return _findOutgoingPlaceholderIndex(list, message);
  }

  void _preserveSoundLocalPath(V2TimMessage? previous, V2TimMessage resolved) {
    if (previous == null ||
        previous.elemType != MessageElemType.V2TIM_ELEM_TYPE_SOUND ||
        resolved.elemType != MessageElemType.V2TIM_ELEM_TYPE_SOUND) {
      return;
    }
    final prevSound = previous.soundElem;
    final nextSound = resolved.soundElem;
    if (prevSound == null || nextSound == null) {
      return;
    }
    final localPath = prevSound.path ?? prevSound.localUrl;
    if (localPath == null || localPath.isEmpty) {
      return;
    }
    nextSound.path = localPath;
    nextSound.localUrl = prevSound.localUrl ?? localPath;
  }

  void _preserveImageLocalPath(V2TimMessage? previous, V2TimMessage resolved) {
    if (previous == null ||
        previous.elemType != MessageElemType.V2TIM_ELEM_TYPE_IMAGE ||
        resolved.elemType != MessageElemType.V2TIM_ELEM_TYPE_IMAGE) {
      return;
    }
    final prevPath = previous.imageElem?.path;
    if (prevPath == null || prevPath.isEmpty) {
      return;
    }
    resolved.imageElem ??= previous.imageElem;
    resolved.imageElem!.path = prevPath;
  }

  void _preserveImageDisplaySize(V2TimMessage resolved, String clientId) {
    if (resolved.elemType != MessageElemType.V2TIM_ELEM_TYPE_IMAGE) {
      return;
    }
    Size? size = _fileMessageSizeMap[clientId];
    final msgID = resolved.msgID?.trim();
    if ((size == null || size.width <= 0 || size.height <= 0) &&
        msgID != null &&
        msgID.isNotEmpty) {
      size = _fileMessageSizeMap[msgID];
    }
    if (size == null || size.width <= 0 || size.height <= 0) {
      return;
    }
    final imageList = resolved.imageElem?.imageList;
    if (imageList == null || imageList.isEmpty) {
      return;
    }
    final width = size.width.round();
    final height = size.height.round();
    for (final image in imageList) {
      if (image == null) {
        continue;
      }
      image.width = width;
      image.height = height;
    }
  }

  void _migrateFileMessageMetadata(String clientId, String? msgID) {
    if (clientId.isEmpty || msgID == null || msgID.isEmpty) {
      return;
    }
    final location = _fileListLocationMap[clientId];
    if (location != null && location.isNotEmpty) {
      _fileListLocationMap.putIfAbsent(msgID, () => location);
    }
    final size = _fileMessageSizeMap[clientId];
    if (size != null) {
      _fileMessageSizeMap.putIfAbsent(msgID, () => size);
    }
  }

  void _registerSoundLocalPath(V2TimMessage message) {
    if (message.elemType != MessageElemType.V2TIM_ELEM_TYPE_SOUND) {
      return;
    }
    final localPath = message.soundElem?.path ?? message.soundElem?.localUrl;
    if (localPath == null || localPath.isEmpty) {
      return;
    }
    final msgID = message.msgID;
    if (msgID != null && msgID.isNotEmpty) {
      setFileMessageLocation(msgID, localPath);
    }
    final clientId = message.id;
    if (clientId != null && clientId.isNotEmpty) {
      setFileMessageLocation(clientId, localPath);
    }
  }

  bool _messageCorrelatesWithStored(
    V2TimMessage stored,
    V2TimMessage incoming,
  ) {
    if (messagesCorrelateForDedup(stored, incoming)) {
      return true;
    }
    if (incoming.isSelf == true &&
        _outgoingMessagesCorrelate(stored, incoming)) {
      return true;
    }
    return false;
  }

  V2TimMessage _mergeMessageAtIndex(
    String convID,
    List<V2TimMessage> list,
    int index,
    V2TimMessage newMsg, {
    bool replacingPlaceholder = false,
    bool forceSuccess = false,
  }) {
    final previous = list[index];
    final merged = _cloneMessage(newMsg);
    final isSelf =
        _isC2cConversationMessage(previous) && _isC2cConversationMessage(newMsg)
            ? _resolveMergedIsSelf(previous, newMsg)
            : (previous.isSelf == true || newMsg.isSelf == true);
    merged.isSelf = isSelf;

    if (isSelf) {
      final clientId = previous.id;
      if (clientId != null && clientId.isNotEmpty) {
        merged.id = clientId;
      }
      _preserveOutgoingLocalOrderData(previous, merged);
      if (previous.elemType == MessageElemType.V2TIM_ELEM_TYPE_SOUND &&
          merged.elemType == MessageElemType.V2TIM_ELEM_TYPE_SOUND) {
        _preserveSoundLocalPath(previous, merged);
      }
      if (previous.elemType == MessageElemType.V2TIM_ELEM_TYPE_IMAGE &&
          merged.elemType == MessageElemType.V2TIM_ELEM_TYPE_IMAGE) {
        _preserveImageLocalPath(previous, merged);
        final clientId = previous.id?.trim() ?? '';
        if (clientId.isNotEmpty) {
          _preserveImageDisplaySize(merged, clientId);
          _migrateFileMessageMetadata(clientId, merged.msgID);
          final layoutSize = readPersistedImageLayoutSize(previous) ??
              _fileMessageSizeMap[clientId] ??
              ((merged.msgID?.isNotEmpty ?? false)
                  ? _fileMessageSizeMap[merged.msgID!]
                  : null);
          if (layoutSize != null) {
            applyImageLayoutToMessage(merged, layoutSize);
          }
        }
      }
      if (forceSuccess ||
          merged.status == MessageStatus.V2TIM_MSG_STATUS_SEND_SUCC) {
        merged.status = MessageStatus.V2TIM_MSG_STATUS_SEND_SUCC;
        ErrorMessageConverter.clearSendFailCode(merged);
      } else if (merged.status == MessageStatus.V2TIM_MSG_STATUS_SEND_FAIL) {
        merged.status = MessageStatus.V2TIM_MSG_STATUS_SEND_FAIL;
      } else if (previous.status == MessageStatus.V2TIM_MSG_STATUS_SEND_SUCC) {
        merged.status = MessageStatus.V2TIM_MSG_STATUS_SEND_SUCC;
      } else {
        merged.status = MessageStatus.V2TIM_MSG_STATUS_SENDING;
      }
    } else if (merged.status == MessageStatus.V2TIM_MSG_STATUS_SENDING) {
      merged.status = MessageStatus.V2TIM_MSG_STATUS_SEND_SUCC;
    }
    if (isSelf) {
      _logOutgoingSendOrder(
        event: 'merge_self',
        convID: convID,
        message: merged,
        clientId: merged.id,
        mergePath: replacingPlaceholder ? 'placeholder_merge' : 'inplace_merge',
        existingIndex: index,
      );
    }
    return merged;
  }

  void _applyMergedMessagePresentationSideEffects(
    String conversationID,
    V2TimMessage? previous,
    V2TimMessage message,
  ) {
    _registerSoundLocalPath(message);
    if (previous == null) {
      return;
    }
    final previousKey = ChatUiStateStore.messageKeyOf(previous);
    _chatUiStateStore.bindMessageAlias(
      conversationID,
      previousKey,
      ChatUiStateStore.messageKeyOf(message),
    );
    _markMessageRowChanged(
      conversationID,
      message,
      extraKey: previousKey,
    );
  }

  bool _upsertIncomingMessage(
    String convID,
    V2TimMessage newMsg, {
    bool forceSuccess = false,
  }) {
    final storageKey = _resolveMessageListStorageKey(convID);
    if (storageKey.isEmpty) {
      return false;
    }
    final serverID = newMsg.msgID?.trim() ?? '';
    if (serverID.isNotEmpty &&
        _messageReconciliationWriter
            .tombstonesFor(storageKey)
            .contains(serverID)) {
      // A late self receipt must not reinsert a server-deleted/revoked row.
      return false;
    }
    // The writer owns the authoritative list. This local copy is only used to
    // preserve the mature outgoing merge rules before the delta is admitted.
    final list = List<V2TimMessage>.from(
      _mergedAliasMessageList(storageKey),
    );
    var index = list.indexWhere(
      (element) => _messageCorrelatesWithStored(element, newMsg),
    );
    var replacingPlaceholder = false;
    if (index == -1 && newMsg.isSelf == true) {
      index = _findOutgoingPlaceholderIndex(list, newMsg);
      replacingPlaceholder = index != -1;
    }
    final previous = index == -1 ? null : list[index];
    final value = index == -1
        ? _cloneMessage(newMsg)
        : _mergeMessageAtIndex(
            storageKey,
            list,
            index,
            newMsg,
            replacingPlaceholder: replacingPlaceholder,
            forceSuccess: forceSuccess || newMsg.isSelf != true,
          );
    final stableIdentity = readOutgoingStableId(value) ??
        readOutgoingStableId(previous) ??
        (value.isSelf == true ? value.id : null);
    final commit = commitMessageDelta(
      MessageDelta<V2TimMessage>(
        conversationKey: storageKey,
        eventID: 'realtime:${++_nextRealtimeReconciliationEvent}:'
            '${messageDedupKey(value)}',
        kind: MessageDeltaKind.realtimeUpsert,
        source: MessageDeltaSource.sdkRealtime,
        generation: messageDeltaGenerationFor(storageKey),
        clearEpoch: messageDeltaClearEpochFor(storageKey),
        upserts: <MessageReconciliationRecord<V2TimMessage>>[
          MessageReconciliationRecord<V2TimMessage>(
            value: value,
            msgID: value.msgID,
            localID: value.id,
            outgoingStableID: stableIdentity,
            seq: value.seq,
          ),
        ],
      ),
      applyMemoryWindow: true,
    );
    if (commit == null) {
      // A history transaction, stale generation, or tombstone owns this
      // event. Never fall back to a direct list write.
      return false;
    }
    _applyMergedMessagePresentationSideEffects(storageKey, previous, value);
    _collapseHistoryAliasesToCanonical(
      storageKey,
      canonical: storageKey,
    );
    return previous != null;
  }

  static bool _sameMessageIdentityList(
    List<V2TimMessage> a,
    List<V2TimMessage> b,
  ) {
    if (identical(a, b) || a.length != b.length) {
      return identical(a, b);
    }
    for (var i = 0; i < a.length; i++) {
      if (!messagesCorrelateForDedup(a[i], b[i])) {
        return false;
      }
    }
    return true;
  }

  /// Applies a burst without sorting the full conversation once per message.
  ///
  /// The common path (all messages are new) performs one final sort. If a
  /// duplicate appears inside the burst, pending inserts are flushed first so
  /// the existing single-message merge semantics remain unchanged.
  ({
    bool inserted,
    V2TimMessage? lastInserted,
    List<V2TimMessage> insertedMessages,
  }) _upsertIncomingMessageBatch(
    String convID,
    List<V2TimMessage> messages,
  ) {
    if (messages.isEmpty) {
      return (
        inserted: false,
        lastInserted: null,
        insertedMessages: const <V2TimMessage>[],
      );
    }

    // Normal inbound rows use the same authoritative writer as history. Keep
    // the mature self-send correlation path below because it also migrates
    // local media metadata and placeholder status; server inbound rows have
    // no such local-only side effects.
    if (messages.every((message) => message.isSelf != true)) {
      final before = _mergedAliasMessageList(convID);
      final eventID = 'realtime:${++_nextRealtimeReconciliationEvent}:'
          '${messages.map(messageDedupKey).join(',')}';
      final commit = commitMessageDelta(
        MessageDelta<V2TimMessage>(
          conversationKey: convID,
          eventID: eventID,
          kind: MessageDeltaKind.realtimeUpsert,
          source: MessageDeltaSource.sdkRealtime,
          generation: messageDeltaGenerationFor(convID),
          clearEpoch: messageDeltaClearEpochFor(convID),
          upserts: _reconciliationRecords(messages),
        ),
      );
      if (commit == null) {
        return (
          inserted: false,
          lastInserted: null,
          insertedMessages: const <V2TimMessage>[],
        );
      }
      final after = commit.rawCount > 0
          ? (rawMessageList(convID) ?? const <V2TimMessage>[])
          : const <V2TimMessage>[];
      final insertedMessages = messages
          .where(
            (message) => !before.any(
              (existing) => _messageCorrelatesWithStored(existing, message),
            ),
          )
          .toList(growable: false);
      return (
        inserted: insertedMessages.isNotEmpty || after.length > before.length,
        lastInserted: insertedMessages.isEmpty ? null : insertedMessages.last,
        insertedMessages: insertedMessages,
      );
    }

    if (_messageReconciliationWriter.hasActiveRequest(convID)) {
      // History and realtime are one transaction. Do not mutate the raw map
      // while an older history snapshot is in flight; its completion publishes
      // the fetched rows plus this queued batch under one list revision.
      final eventID = 'realtime:${++_nextRealtimeReconciliationEvent}:'
          '${messages.map(messageDedupKey).join(',')}';
      _messageReconciliationWriter.enqueueRealtime(
        conversationID: convID,
        eventID: eventID,
        records: _reconciliationRecords(messages),
      );
      return (
        inserted: false,
        lastInserted: null,
        insertedMessages: const <V2TimMessage>[],
      );
    }

    final storageKey = _resolveMessageListStorageKey(convID);
    if (storageKey.isEmpty) {
      return (
        inserted: false,
        lastInserted: null,
        insertedMessages: const <V2TimMessage>[],
      );
    }
    final before = _mergedAliasMessageList(storageKey);
    final known = List<V2TimMessage>.of(before);
    final records = <MessageReconciliationRecord<V2TimMessage>>[];
    final previousRecords = <V2TimMessage?>[];
    final insertedMessages = <V2TimMessage>[];

    for (final message in messages) {
      var index = known.indexWhere(
        (item) => _messageCorrelatesWithStored(item, message),
      );
      var replacingPlaceholder = false;
      if (index == -1 && message.isSelf == true) {
        index = _findOutgoingPlaceholderIndex(known, message);
        replacingPlaceholder = index != -1;
      }
      final previous = index == -1 ? null : known[index];
      final value = index == -1
          ? _cloneMessage(message)
          : _mergeMessageAtIndex(
              storageKey,
              known,
              index,
              message,
              replacingPlaceholder: replacingPlaceholder,
              forceSuccess: message.isSelf == true || previous != null,
            );
      final stableIdentity = readOutgoingStableId(value) ??
          readOutgoingStableId(previous) ??
          (value.isSelf == true ? value.id : null);
      records.add(
        MessageReconciliationRecord<V2TimMessage>(
          value: value,
          msgID: value.msgID,
          localID: value.id,
          outgoingStableID: stableIdentity,
          seq: value.seq,
        ),
      );
      previousRecords.add(previous);
      if (previous == null) {
        insertedMessages.add(value);
        known.add(value);
      } else {
        known[index] = value;
      }
    }

    final commit = commitMessageDelta(
      MessageDelta<V2TimMessage>(
        conversationKey: storageKey,
        eventID: 'realtime:batch:${++_nextRealtimeReconciliationEvent}:'
            '${messages.map(messageDedupKey).join(',')}',
        kind: MessageDeltaKind.realtimeUpsert,
        source: MessageDeltaSource.sdkRealtime,
        generation: messageDeltaGenerationFor(storageKey),
        clearEpoch: messageDeltaClearEpochFor(storageKey),
        upserts: records,
      ),
    );
    if (commit != null) {
      for (var index = 0; index < records.length; index++) {
        final value = records[index].value;
        _applyMergedMessagePresentationSideEffects(
          storageKey,
          previousRecords[index],
          value,
        );
      }
    } else {
      insertedMessages.clear();
    }
    final inserted = insertedMessages.isNotEmpty;
    final lastInserted = inserted ? insertedMessages.last : null;
    if (ChatJitterDiag.enabled) {
      final groupCount =
          messages.where((message) => _isGroupLikeMessage(message)).length;
      final c2cCount = messages
          .where((message) => _isC2cConversationMessage(message))
          .length;
      ChatJitterDiag.log(
        'inbound_batch_dedup',
        conv: convID,
        extras: <String, Object?>{
          'count': messages.length,
          'upserted': insertedMessages.length,
          'duplicates': messages.length - insertedMessages.length,
          'source': groupCount > 0 && c2cCount == 0
              ? 'group'
              : c2cCount > 0 && groupCount == 0
                  ? 'c2c'
                  : 'mixed',
          'seqPresent': messages.any((message) => _messageSortSeq(message) > 0),
        },
      );
    }
    return (
      inserted: inserted,
      lastInserted: lastInserted,
      insertedMessages: insertedMessages,
    );
  }

  void _stageInboundChunkReveal(
    String conversationID,
    List<V2TimMessage> messages,
  ) {
    final result = _upsertIncomingMessageBatch(conversationID, messages);
    if (!result.inserted) {
      _markNeedsNotify();
      return;
    }

    // Install the projection barrier before invalidating the display cache.
    // The canonical list is complete immediately, but only reveal ticks may
    // make these rows visible.
    _hideInboundProjection(conversationID, result.insertedMessages);
    _bumpMessageListRevisionFor(
      conversationID,
      reason: 'inbound_authority_batch',
    );
    _storeHistoryMessagePosition(
      conversationID,
      HistoryMessagePosition.bottom,
    );
    if (lockedEntryUnreadCountFor(conversationID) == 0) {
      flushDeferredIncomingMessages(conversationID, notify: false);
      clearReceivedUnreadState(
        conversationID: conversationID,
        notify: false,
      );
    }
    _inboundChunkReveal.enqueueAll(
      conversationID,
      result.insertedMessages,
    );
  }

  void _flushInboundMessageBatch(
    String conversationID,
    List<V2TimMessage> messages,
  ) {
    if (messages.isEmpty) {
      return;
    }
    final convId = _resolveMessageListStorageKey(
      _safeConversationId(conversationID),
    );
    if (convId.isEmpty) {
      return;
    }
    _noteInboundFloodArrivals(messages.length);
    final flood = isInboundFloodActive ||
        messages.length >= _inboundFloodBatchSizeThreshold;
    if (flood && _inboundChunkReveal.isActiveFor(convId)) {
      // 洪峰中取消未完成的分片揭示，改走整批插入，避免动画积压拖垮主线程。
      _inboundChunkReveal.cancelToBuffer(convId);
    }
    if (!flood && _shouldChunkRevealInbound(convId, messages)) {
      ChatJitterDiag.log(
        'inbound_chunk_reveal_enqueue',
        conv: convId,
        extras: <String, Object?>{
          'count': messages.length,
          'intervalMs': chatConfig.inboundChunkRevealIntervalMs,
          'maxChunk': chatConfig.inboundChunkRevealMaxChunk,
        },
      );
      _stageInboundChunkReveal(convId, messages);
      return;
    }
    final isBulk = flood || messages.length >= _bulkMessageSyncThreshold;
    if (isBulk) {
      _beginBulkMessageSync(convId);
    }
    try {
      _applyInboundMessageBatch(convId, messages);
    } finally {
      if (isBulk) {
        _endBulkMessageSync(convId);
      }
    }
  }

  bool _shouldChunkRevealInbound(
    String convID,
    List<V2TimMessage> messages,
  ) {
    if (!chatConfig.inboundChunkRevealEnabled ||
        messages.isEmpty ||
        !shouldAnimateInboundPresentation ||
        isInboundFloodActive ||
        messages.length >= _inboundFloodBatchSizeThreshold) {
      return false;
    }
    if (!_isSameConversationID(convID, currentSelectedConv)) {
      return false;
    }
    // While the user explicitly returns to the bottom, incoming rows must join
    // the authoritative list immediately. Starting another reveal transaction
    // would keep moving the scroll target and can make the button never settle.
    if (isUserScrollToBottomInProgress(convID)) {
      return false;
    }
    if (isChatListUserScrolling) {
      return false;
    }
    _syncHistoryPositionFromActiveScroll(convID);
    var position = getMessageListPosition(convID);
    final isActuallyNearBottom = _isActiveChatNearBottom(convID);
    if (_shouldDeferIncomingToVisibleList(
      convID,
      position: position,
      isActuallyNearBottom: isActuallyNearBottom,
    )) {
      return false;
    }
    if (!isActuallyNearBottom &&
        !(position == HistoryMessagePosition.bottom &&
            unreadCountForTongue == 0)) {
      return false;
    }
    return true;
  }

  void _drainChunkRevealToBuffer(
    String convID,
    List<V2TimMessage> messages,
  ) {
    if (messages.isEmpty) {
      return;
    }
    _syncHistoryPositionFromActiveScroll(convID);
    final position = getMessageListPosition(convID);
    final isActuallyNearBottom = _isActiveChatNearBottom(convID);
    for (final message in messages) {
      if (message.isSelf == true) {
        _revealInboundProjectionChunk(convID, <V2TimMessage>[message]);
        continue;
      }
      _authoritativeDeferredIncomingKeys.add(
        _authoritativeDeferredKey(convID, message),
      );
      _bufferIncomingWhileReadingAway(
        convID,
        message,
        route: 'chunk_reveal_cancelled',
        position: position,
        isActuallyNearBottom: isActuallyNearBottom,
      );
    }
    ChatJitterDiag.log(
      'inbound_chunk_reveal_drain_buffer',
      conv: convID,
      extras: <String, Object?>{
        'count': messages.length,
        'tongueUnread': unreadCountForTongue,
      },
    );
    _markNeedsNotify();
  }

  void _applyInboundMessageBatch(
    String convID,
    List<V2TimMessage> messages,
  ) {
    if (messages.isEmpty) {
      return;
    }
    final isActiveConversation =
        _isSameConversationID(convID, currentSelectedConv);
    var listDirty = false;
    V2TimMessage? enterAnimationCandidate;

    if (!isActiveConversation) {
      final result = _upsertIncomingMessageBatch(convID, messages);
      if (result.inserted) {
        _scheduleInactiveInboundPresentationCommit(convID);
      }
      return;
    }

    _syncHistoryPositionFromActiveScroll(convID);
    var position = getMessageListPosition(convID);
    final wasAtBottomBeforeKeyboardViewportChange =
        _wasAtBottomBeforeKeyboardViewportChange(convID);
    final isActuallyNearBottom = _isActiveChatNearBottom(convID) ||
        wasAtBottomBeforeKeyboardViewportChange;
    if (wasAtBottomBeforeKeyboardViewportChange) {
      _storeHistoryMessagePosition(convID, HistoryMessagePosition.bottom);
      position = HistoryMessagePosition.bottom;
    }
    final isReturningToBottom = isUserScrollToBottomInProgress(convID);
    var clearedUnreadState = false;
    final messagesToUpsert = <V2TimMessage>[];

    for (final message in messages) {
      if (message.isSelf == true) {
        _syncSelfSentMessage(convID, message, forceSuccess: true);
        listDirty = true;
        continue;
      }

      if (!_chatAppForeground) {
        _bufferIncomingWhileReadingAway(
          convID,
          message,
          route: 'app_background',
          position: HistoryMessagePosition.notShowLatest,
          isActuallyNearBottom: false,
        );
        continue;
      }

      if (!isReturningToBottom &&
          _shouldDeferIncomingToVisibleList(
            convID,
            position: position,
            isActuallyNearBottom: isActuallyNearBottom,
          )) {
        _bufferIncomingWhileReadingAway(
          convID,
          message,
          route: position == HistoryMessagePosition.notShowLatest
              ? 'notShowLatest'
              : 'awayFromBottom',
          position: position,
          isActuallyNearBottom: isActuallyNearBottom,
        );
        continue;
      }

      if (isReturningToBottom ||
          isActuallyNearBottom ||
          (position == HistoryMessagePosition.bottom &&
              unreadCountForTongue == 0)) {
        if (isActuallyNearBottom) {
          _storeHistoryMessagePosition(convID, HistoryMessagePosition.bottom);
        }
        if (!isReturningToBottom &&
            !clearedUnreadState &&
            lockedEntryUnreadCountFor(convID) == 0) {
          flushDeferredIncomingMessages(convID, notify: false);
          clearReceivedUnreadState(
            conversationID: convID,
            notify: false,
          );
          clearedUnreadState = true;
        }
        messagesToUpsert.add(message);
      } else {
        _bufferIncomingWhileReadingAway(
          convID,
          message,
          route: 'awayFromBottom',
          position: position,
          isActuallyNearBottom: isActuallyNearBottom,
        );
      }
    }

    final upsertResult = _upsertIncomingMessageBatch(convID, messagesToUpsert);
    if (upsertResult.inserted) {
      listDirty = true;
      enterAnimationCandidate = upsertResult.lastInserted;
    }

    if (listDirty) {
      _bumpMessageListRevisionFor(
        convID,
        reason: 'inbound_batch_active',
      );
    }

    if (enterAnimationCandidate != null) {
      _markIncomingMessageEnterAnimation(enterAnimationCandidate);
    }

    final isBulk = messages.length >= _bulkMessageSyncThreshold;
    if (listDirty &&
        isActuallyNearBottom &&
        !_shouldDeferIncomingToVisibleList(
          convID,
          position: position,
          isActuallyNearBottom: isActuallyNearBottom,
        )) {
      final scrollFollowActive = chatConfig.inboundScrollFollowEnabled &&
          isChunkedRevealActive(convID);
      if (isBulk ||
          isBulkMessageSyncActive(convID) ||
          isChunkedRevealActive(convID)) {
        if (!scrollFollowActive) {
          _pendingPinAfterBulkByConv[convID] = true;
        }
      } else {
        requestPinToBottom(convID);
      }
    }

    ChatJitterDiag.logInboundFlow(
      action: 'batch_applied',
      conv: convID,
      extras: <String, Object?>{
        'count': messages.length,
        'upserted': messagesToUpsert.length,
        'listDirty': listDirty,
        'bulk': isBulk,
        'nearBottom': isActuallyNearBottom,
        'bottomLocked': isInboundPresentationBottomLocked(convID),
        'returningToBottom': isReturningToBottom,
        'logicalPosition': position.name,
        'tongueUnread': unreadCountForTongue,
        'buffered': _inboundUnreadStateFor(convID, create: false)
            .bufferedMessages
            .length,
        'queue': pendingInboundProjectionCount(convID),
      },
    );
    _markNeedsNotify();
  }

  bool _syncSelfSentMessage(
    String convID,
    V2TimMessage newMsg, {
    bool forceSuccess = false,
  }) {
    if (newMsg.isSelf != true) {
      return false;
    }
    if (forceSuccess &&
        (isOutgoingMediaCancelled(newMsg.id) ||
            isOutgoingMediaCancelled(newMsg.msgID))) {
      return false;
    }
    // _upsertIncomingMessage constructs and submits the authoritative delta.
    // Its null/rejected result is terminal for this callback; there is no
    // direct-list fallback after a Writer decision.
    return _upsertIncomingMessage(
      convID,
      newMsg,
      forceSuccess: forceSuccess,
    );
  }

  void _syncGroupMemberFromMessage(V2TimMessage message) {
    final groupID = TencentUtils.checkString(message.groupID);
    final userID = TencentUtils.checkString(message.sender) ??
        TencentUtils.checkString(message.userID);
    if (groupID == null || userID == null) {
      return;
    }

    final nameCard = TencentUtils.checkString(message.nameCard);
    final nickName = TencentUtils.checkString(message.nickName);
    final friendRemark = TencentUtils.checkString(message.friendRemark);
    final faceUrl = TencentUtils.checkString(message.faceUrl);
    if (nameCard == null &&
        nickName == null &&
        friendRemark == null &&
        faceUrl == null) {
      return;
    }

    final current = GroupMemberStore.instance.memberOf(groupID, userID);
    if (current == null) {
      GroupMemberStore.instance.putMember(
        groupID,
        V2TimGroupMemberFullInfo(
          userID: userID,
          nameCard: nameCard,
          nickName: nickName,
          friendRemark: friendRemark,
          faceUrl: faceUrl,
        ),
      );
      return;
    }

    var changed = false;
    if (nameCard != null && current.nameCard != nameCard) {
      current.nameCard = nameCard;
      changed = true;
    }
    if (nickName != null && current.nickName != nickName) {
      current.nickName = nickName;
      changed = true;
    }
    if (friendRemark != null && current.friendRemark != friendRemark) {
      current.friendRemark = friendRemark;
      changed = true;
    }
    if (faceUrl != null && current.faceUrl != faceUrl) {
      current.faceUrl = faceUrl;
      changed = true;
    }
    if (changed) {
      GroupMemberStore.instance.putMember(groupID, current);
    }
  }

  _onReceiveNewMsg(V2TimMessage msgComing) async {
    final lifecycleGeneration = _messageHistoryCoverageSessionGeneration;
    final initialConvID = _messageConversationID(msgComing);
    if (initialConvID == null || initialConvID.isEmpty) {
      return;
    }

    V2TimMessage? mountedMessage = msgComing;
    if (_lifeCycle?.newMessageWillMount != null) {
      try {
        mountedMessage = await _lifeCycle!.newMessageWillMount(msgComing);
      } catch (e) {
        outputLogger.i('newMessageWillMount error: $e');
        mountedMessage = msgComing;
      }
    }
    if (!_isMessageLifecycleCurrent(lifecycleGeneration)) {
      ChatJitterDiag.log(
        'message_inbound_drop_stale_lifecycle',
        conv: initialConvID,
        extras: <String, Object?>{
          'generation': lifecycleGeneration,
          'currentGeneration': _messageHistoryCoverageSessionGeneration,
        },
      );
      return;
    }
    if (mountedMessage == null) {
      return;
    }
    mountedMessage = _normalizeInboundC2cDirection(mountedMessage);

    final rawConvID = _messageConversationID(mountedMessage) ?? initialConvID;
    final convID = _resolveMessageListStorageKey(rawConvID);
    _syncGroupMemberFromMessage(mountedMessage);
    final senderId = TencentUtils.checkString(mountedMessage.sender) ??
        TencentUtils.checkString(mountedMessage.userID);
    if (mountedMessage.isSelf != true && senderId != null) {
      unawaited(
        UserProfileLocalBridge.upsertPublicProfileFromSnapshot(
          userId: senderId,
          nickName: mountedMessage.nickName,
          faceUrl: mountedMessage.faceUrl,
        ),
      );
    }

    // Typing/status custom messages should update typing state only. They must not
    // enter the visible message list, but they also must not stop normal message
    // events in other conversations.
    final bool isEditMessage = _editStatusCheck(mountedMessage);
    if (isEditMessage) {
      return;
    }

    _checkFromUserisActive(mountedMessage);
    final convType = TencentUtils.checkString(mountedMessage.groupID) != null
        ? ConvType.group
        : ConvType.c2c;
    final isActiveConversation =
        _isSameConversationID(convID, currentSelectedConv);

    if (isActiveConversation &&
        chatConfig.isAutoReportRead &&
        lockedEntryUnreadCountFor(convID) == 0) {
      _scheduleActiveReadReport(
        convID: convID,
        convType: convType,
      );
    }

    // Self-sent sync on the active chat must stay immediate for send UX.
    if (isActiveConversation && mountedMessage.isSelf == true) {
      _syncSelfSentMessage(convID, mountedMessage, forceSuccess: true);
      _markNeedsNotify();
      return;
    }

    // Group seq gap detection: if the reorder buffer is active for this
    // conversation, route through it so out-of-order messages are buffered
    // and missing messages trigger a cloud catch-up. C2C seq has no global
    // continuity so the buffer is never active for C2C.
    final buffer = _reorderBuffersByConv[convID];
    if (buffer != null && buffer.isActivated && convType == ConvType.group) {
      final result = buffer.accept(mountedMessage);
      if (result == null) {
        // Buffered: out-of-order or gap detected, will be flushed later.
        return;
      }
      if (result.isEmpty) {
        // Duplicate (seq <= expected), silently dropped.
        return;
      }
      // Contiguous: upsert immediately (may include drained buffer messages).
      for (final msg in result) {
        _inboundBatchCoalescer.enqueue(convID, msg);
      }
      return;
    }

    _inboundBatchCoalescer.enqueue(convID, mountedMessage);
  }

  String _revokedCloudCustomData(String? raw, bool isAdmin) {
    final data = <String, dynamic>{};
    final source = raw?.trim();
    if (source != null && source.isNotEmpty) {
      try {
        final decoded = jsonDecode(source);
        if (decoded is Map) {
          data.addAll(Map<String, dynamic>.from(decoded));
        }
      } catch (_) {
        // Keep the original message render stable even when old custom data is invalid.
      }
    }
    data['isRevoke'] = true;
    data['revokeByAdmin'] = isAdmin;
    return jsonEncode(data);
  }

  void _addRevokeLookupKey(List<String> keys, String? key) {
    final value = key?.trim();
    if (value == null || value.isEmpty || keys.contains(value)) {
      return;
    }
    keys.add(value);

    if (value.startsWith('c2c_')) {
      final pure = value.substring(4);
      if (pure.isNotEmpty && !keys.contains(pure)) {
        keys.add(pure);
      }
    } else if (value.startsWith('C2C')) {
      final pure = value.substring(3);
      if (pure.isNotEmpty && !keys.contains(pure)) {
        keys.add(pure);
      }
    } else if (!value.startsWith('group_') && !value.startsWith('GROUP')) {
      final c2cKey = 'c2c_$value';
      if (!keys.contains(c2cKey)) {
        keys.add(c2cKey);
      }
    }

    if (value.startsWith('group_')) {
      final pure = value.substring(6);
      if (pure.isNotEmpty && !keys.contains(pure)) {
        keys.add(pure);
      }
    } else if (value.startsWith('GROUP')) {
      final pure = value.substring(5);
      if (pure.isNotEmpty && !keys.contains(pure)) {
        keys.add(pure);
      }
    }
  }

  void _clearRevokedInboundPresentation(
    String conversationID,
    String msgID, {
    V2TimMessage? revokedMessage,
  }) {
    final target = msgID.trim();
    if (target.isEmpty) {
      return;
    }
    final stateKey = _inboundStateKey(conversationID);
    final state = _inboundUnreadStateFor(stateKey, create: false);
    final dedupKeys = <String>{
      'msg:$target',
      if (revokedMessage != null) messageDedupKey(revokedMessage),
    };
    state.bufferedMessages.removeWhere(
      (message) =>
          message.msgID == target ||
          dedupKeys.contains(messageDedupKey(message)),
    );
    bool matchesTarget(String value) {
      return dedupKeys.contains(value) ||
          value == target ||
          value.endsWith(':$target');
    }

    state.bufferedMessageKeys.removeWhere(matchesTarget);
    _inboundFastForwardMessageKeys.removeWhere(matchesTarget);
    final deferredPrefix = '$stateKey|';
    _authoritativeDeferredIncomingKeys.removeWhere(
      (value) =>
          value.startsWith(deferredPrefix) &&
          matchesTarget(value.substring(deferredPrefix.length)),
    );
    if (revokedMessage != null) {
      _revealDeferredProjectionAcrossAliases(
        conversationID,
        <V2TimMessage>[revokedMessage],
      );
      _chatUiStateStore.markMessageChanged(
        conversationID,
        ChatUiStateStore.messageKeyOf(revokedMessage),
      );
    }
  }

  bool markMessageRevokedNow(
    String msgID, {
    String? convID,
    bool isAdmin = false,
  }) {
    final targetMsgID = msgID.trim();
    if (targetMsgID.isEmpty) {
      return false;
    }

    final keys = <String>[];
    _addRevokeLookupKey(keys, convID);
    _addRevokeLookupKey(keys, currentSelectedConv);
    for (final key in _messageListMap.keys) {
      _addRevokeLookupKey(keys, key);
    }

    var didUpdate = false;
    final visitedStorageKeys = <String>{};
    for (final key in keys) {
      final storageKey = _resolveMessageListStorageKey(key);
      if (storageKey.isEmpty || !visitedStorageKeys.add(storageKey)) {
        continue;
      }
      final activeMessageList = _messageListMap[storageKey];
      if (activeMessageList == null || activeMessageList.isEmpty) {
        // Keep the revoke authority even when the row is outside the current
        // memory window. A later older-page response must not resurrect it.
        final commit = commitMessageDelta(
          MessageDelta<V2TimMessage>(
            conversationKey: storageKey,
            eventID: 'revoke_tombstone:$targetMsgID:$storageKey',
            kind: MessageDeltaKind.revoke,
            source: MessageDeltaSource.sdkRealtime,
            generation: messageDeltaGenerationFor(storageKey),
            clearEpoch: messageDeltaClearEpochFor(storageKey),
            tombstones: <String>{targetMsgID},
          ),
        );
        if (commit != null) {
          _clearRevokedInboundPresentation(storageKey, targetMsgID);
          didUpdate = true;
        }
        continue;
      }

      final target = activeMessageList.cast<V2TimMessage?>().firstWhere(
            (item) => item?.msgID == targetMsgID,
            orElse: () => null,
          );
      if (target != null) {
        final revoked = _cloneMessage(target);
        revoked.status = MessageStatus.V2TIM_MSG_STATUS_LOCAL_REVOKED;
        revoked.cloudCustomData =
            _revokedCloudCustomData(revoked.cloudCustomData, isAdmin);
        revoked.id ??= revoked.msgID;
        final commit = commitMessageDelta(
          MessageDelta<V2TimMessage>(
            conversationKey: storageKey,
            eventID:
                'revoke:$targetMsgID:$storageKey:${DateTime.now().microsecondsSinceEpoch}',
            kind: MessageDeltaKind.revoke,
            source: MessageDeltaSource.sdkRealtime,
            generation: messageDeltaGenerationFor(storageKey),
            clearEpoch: messageDeltaClearEpochFor(storageKey),
            upserts: [messageDeltaRecord(revoked)],
            tombstones: <String>{targetMsgID},
          ),
        );
        if (commit != null) {
          _clearRevokedInboundPresentation(
            storageKey,
            targetMsgID,
            revokedMessage: revoked,
          );
          didUpdate = true;
          continue;
        }
      }

      // A row may be outside this memory window or may already have been
      // projected away. The tombstone is still authoritative and is the only
      // accepted fallback; never mutate the formal list directly here.
      final commit = commitMessageDelta(
        MessageDelta<V2TimMessage>(
          conversationKey: storageKey,
          eventID:
              'revoke_tombstone:$targetMsgID:$storageKey:${DateTime.now().microsecondsSinceEpoch}',
          kind: MessageDeltaKind.revoke,
          source: MessageDeltaSource.sdkRealtime,
          generation: messageDeltaGenerationFor(storageKey),
          clearEpoch: messageDeltaClearEpochFor(storageKey),
          tombstones: <String>{targetMsgID},
        ),
      );
      if (commit != null) {
        _clearRevokedInboundPresentation(storageKey, targetMsgID);
        didUpdate = true;
      }
    }

    // The recalled row may already be outside the in-memory chat window while
    // still present in the short gallery cache. Invalidate by server identity
    // even when no visible row was updated, and across alias conversation keys.
    ChatMediaGalleryExpandCache.removeMessage(targetMsgID);

    if (didUpdate) {
      // Revoke is a user-visible command. Refresh immediately like WeChat instead
      // of waiting for the next route switch/history reload.
      _notifyPending = false;
      notifyListeners();
    }
    return didUpdate;
  }

  onMessageRevoked(String msgID, [String? convID]) {
    markMessageRevokedNow(msgID, convID: convID);
  }

  void markMessageChangedByMessage(
    String conversationID,
    V2TimMessage message,
  ) {
    final messageKey = ChatUiStateStore.messageKeyOf(message);
    if (messageKey.isEmpty) {
      return;
    }
    _chatUiStateStore.markMessageChanged(conversationID, messageKey);
    _markNeedsNotify();
  }

  /// Commits media metadata that arrived after a history row was mounted.
  ///
  /// URL resolution usually mutates the SDK message object in place. A cloud
  /// reconciliation can instead have cloned that row, so update the
  /// authoritative row when identity matches and then use the existing
  /// row-level revision channel. This keeps late media enrichment from
  /// rebuilding or resorting the whole message window.
  void mergeMessageMediaMetadata(
    V2TimMessage resolved, {
    String? conversationID,
  }) {
    final msgID = resolved.msgID?.trim() ?? '';
    final clientID = resolved.id?.trim() ?? '';
    if (msgID.isEmpty && clientID.isEmpty) {
      return;
    }

    final explicitConversation = conversationID?.trim() ?? '';
    String inferredConversation = explicitConversation;
    if (inferredConversation.isEmpty) {
      inferredConversation = resolved.userID?.trim() ?? '';
    }
    if (inferredConversation.isEmpty) {
      inferredConversation = resolved.groupID?.trim() ?? '';
    }
    if (inferredConversation.isEmpty) {
      try {
        inferredConversation = resolved.messageConvID?.toString().trim() ?? '';
      } catch (_) {}
    }

    // Explicit context is authoritative. Without it, userID/groupID is only
    // a preference because self-sent C2C rows may carry the login user ID.
    final allEntries = _messageListMap.entries.toList(growable: true);
    final entries = explicitConversation.isNotEmpty
        ? allEntries
            .where(
              (entry) => _isSameConversationID(entry.key, explicitConversation),
            )
            .toList(growable: true)
        : allEntries.toList(growable: true);
    if (explicitConversation.isEmpty && inferredConversation.isNotEmpty) {
      entries.sort((left, right) {
        final leftMatches =
            _isSameConversationID(left.key, inferredConversation);
        final rightMatches =
            _isSameConversationID(right.key, inferredConversation);
        if (leftMatches == rightMatches) {
          return 0;
        }
        return leftMatches ? -1 : 1;
      });
    }
    final visitedStorageKeys = <String>{};
    var changed = false;
    for (final entry in entries) {
      final storageKey = _resolveMessageListStorageKey(entry.key);
      if (!visitedStorageKeys.add(storageKey)) {
        continue;
      }
      final current = _messageListMap[storageKey];
      if (current == null || current.isEmpty) {
        continue;
      }
      final index = current.indexWhere(
        (candidate) =>
            (msgID.isNotEmpty && candidate.msgID == msgID) ||
            (clientID.isNotEmpty && candidate.id == clientID),
      );
      if (index < 0) {
        continue;
      }
      final existing = current[index];
      if (identical(existing, resolved)) {
        _messageListDisplayCache.removeWhere(
          (key, _) => _isSameConversationID(key, storageKey),
        );
        _markMessageRowChanged(
          storageKey,
          existing,
          extraKey: msgID.isNotEmpty ? msgID : clientID,
        );
        changed = true;
        continue;
      }

      final replacement = _cloneMessage(existing);
      if (resolved.imageElem != null) {
        replacement.imageElem = resolved.imageElem;
      }
      if (resolved.videoElem != null) {
        replacement.videoElem = resolved.videoElem;
      }
      if (replacement.elemType == MessageElemType.V2TIM_ELEM_TYPE_NONE &&
          resolved.elemType != MessageElemType.V2TIM_ELEM_TYPE_NONE) {
        replacement.elemType = resolved.elemType;
      }
      final result = replaceMessageRowLocal(
        conversationID: storageKey,
        index: index,
        expected: existing,
        replacement: replacement,
        aliases: <String?>[msgID, clientID],
      );
      if (result == RowLocalMessageReplacementResult.replaced) {
        _messageListDisplayCache.removeWhere(
          (key, _) => _isSameConversationID(key, storageKey),
        );
        changed = true;
      }
    }

    // A metadata response may finish before the matching history window is
    // committed. The row-level invalidation is harmless and lets a later
    // alias-aware lookup rebuild the row as soon as it exists.
    if (!changed && msgID.isNotEmpty) {
      markMessageRowsChangedByMsgIDs(<String?>[msgID]);
    }
  }

  onMessageModified(V2TimMessage modifiedMessage, [String? convID]) async {
    final lifecycleGeneration = _messageHistoryCoverageSessionGeneration;
    final String? exactId = TencentUtils.checkString(modifiedMessage.userID) ??
        TencentUtils.checkString(modifiedMessage.groupID);
    final rawConvID = convID ?? exactId;
    if (rawConvID == null || rawConvID.isEmpty) {
      return;
    }
    final resolvedConvID = _resolveMessageListStorageKey(rawConvID);
    if (resolvedConvID.isEmpty) {
      return;
    }
    if (modifiedMessage.isSelf == true) {
      final applied = _syncSelfSentMessage(
        resolvedConvID,
        modifiedMessage,
        forceSuccess:
            modifiedMessage.status == MessageStatus.V2TIM_MSG_STATUS_SEND_SUCC,
      );
      if (applied) {
        _chatUiStateStore.markMessageChangedByMessage(
          resolvedConvID,
          modifiedMessage,
        );
        _markNeedsNotify();
      }
      return;
    }
    final V2TimMessage newMsg =
        await _lifeCycle?.modifiedMessageWillMount(modifiedMessage) ??
            modifiedMessage;
    if (!_isMessageLifecycleCurrent(lifecycleGeneration)) {
      ChatJitterDiag.log(
        'message_modified_drop_stale_lifecycle',
        conv: resolvedConvID,
        extras: <String, Object?>{
          'generation': lifecycleGeneration,
          'currentGeneration': _messageHistoryCoverageSessionGeneration,
        },
      );
      return;
    }
    if (newMsg.isSelf != true) {
      final msgID = newMsg.msgID?.trim() ?? '';
      final clientId = newMsg.id?.trim() ?? '';
      final editCommit = commitMessageDelta(
        MessageDelta<V2TimMessage>(
          conversationKey: resolvedConvID,
          eventID: 'edit:${msgID.isNotEmpty ? msgID : clientId}:'
              '${DateTime.now().microsecondsSinceEpoch}',
          kind: MessageDeltaKind.edit,
          source: MessageDeltaSource.sdkRealtime,
          generation: messageDeltaGenerationFor(resolvedConvID),
          clearEpoch: messageDeltaClearEpochFor(resolvedConvID),
          upserts: [messageDeltaRecord(newMsg)],
        ),
      );
      // The row may be outside the current memory window. The delta still
      // needs to be remembered as an authoritative overlay so an older page
      // cannot resurrect stale content. While history is in flight the delta
      // is queued and must not be applied through the legacy direct writer.
      if (editCommit != null ||
          _messageReconciliationWriter.hasActiveRequest(resolvedConvID)) {
        return;
      }
      // A null commit means the writer rejected a stale/duplicate/tombstoned
      // edit. Never fall back to a direct list mutation in that case, or a
      // deleted row could be reintroduced outside the authoritative state.
      return;
    }
    if (newMsg.isSelf == true) {
      // A lifecycle hook may turn an inbound model into a self message. It
      // still follows the same send/adoption Writer boundary as the normal
      // self branch above.
      final applied = _syncSelfSentMessage(
        resolvedConvID,
        newMsg,
        forceSuccess: newMsg.status == MessageStatus.V2TIM_MSG_STATUS_SEND_SUCC,
      );
      if (applied) {
        _chatUiStateStore.markMessageChangedByMessage(
          resolvedConvID,
          newMsg,
        );
        _markNeedsNotify();
      }
    }
  }

  _onReceiveC2CReadReceipt(List<V2TimMessageReceipt> receiptList) {
    var changed = false;
    final peerReadConvIds = <String, int>{};
    for (var receipt in receiptList) {
      final peerID = receipt.userID.trim();
      if (peerID.isEmpty) {
        continue;
      }
      final readAt = _receiptTimestamp(receipt.timestamp);
      final peerKey = _normalizeC2CKey(peerID).toLowerCase();
      if (readAt > (_c2cPeerReadTimestampMap[peerKey] ?? 0)) {
        _c2cPeerReadTimestampMap[peerKey] = readAt;
        changed = true;
      }

      final normalizedPeer = _normalizeC2CKey(peerID);
      if (normalizedPeer.isNotEmpty) {
        peerReadConvIds['c2c_$normalizedPeer'] = readAt;
      }

      final visitedConversationKeys = <String>{};
      for (final entry in _messageListMap.entries.toList()) {
        if (!_isC2CConversationForPeer(entry.key, peerID)) {
          continue;
        }
        final storageKey = _resolveMessageListStorageKey(entry.key);
        if (storageKey.isEmpty || !visitedConversationKeys.add(storageKey)) {
          continue;
        }
        peerReadConvIds[storageKey] = readAt;
        final list = _mergedAliasMessageList(storageKey);
        if (list.isEmpty) continue;
        var convChanged = false;
        final changedKeys = <String>{};
        final updated = list.map((element) {
          final isSelf = element.isSelf ?? true;
          final timestamp = element.timestamp ?? 0;
          final shouldMarkRead = isSelf &&
              element.isPeerRead != true &&
              (readAt <= 0 || timestamp <= 0 || timestamp <= readAt);
          if (shouldMarkRead) {
            final msgID = element.msgID;
            if (msgID != null && msgID.isNotEmpty) {
              changedKeys.add(msgID);
            }
            changedKeys.add(ChatUiStateStore.messageKeyOf(element));
            convChanged = true;
            final next = _cloneMessage(element);
            next.isPeerRead = true;
            return next;
          }
          return element;
        }).toList();
        if (convChanged) {
          final commit = commitMessageDelta(
            MessageDelta<V2TimMessage>(
              conversationKey: storageKey,
              eventID: 'read_receipt:c2c:$peerID:$readAt',
              kind: MessageDeltaKind.readReceipt,
              source: MessageDeltaSource.sdkRealtime,
              generation: messageDeltaGenerationFor(storageKey),
              clearEpoch: messageDeltaClearEpochFor(storageKey),
              upserts: _reconciliationRecords(updated),
            ),
          );
          if (commit != null) {
            for (final element in updated) {
              if (element.isSelf == true && element.isPeerRead == true) {
                final msgID = element.msgID?.trim() ?? '';
                if (msgID.isNotEmpty) {
                  _messageReadReceiptMap[msgID] = V2TimMessageReceipt(
                    userID: peerID,
                    timestamp: readAt,
                    msgID: msgID,
                    isPeerRead: true,
                  );
                }
              }
            }
            _chatUiStateStore.markMessagesChanged(storageKey, changedKeys);
            changed = true;
          }
        }
      }
    }
    for (final entry in peerReadConvIds.entries) {
      ConversationPeerReadCoordinator.scheduleNotify(
        conversationID: entry.key,
        peerReadAtSec: entry.value,
      );
    }
    if (changed) {
      _markNeedsNotify();
    }
  }

  _onReceiveMessageReadReceipts(List<V2TimMessageReceipt> receiptList) {
    try {
      var changed = false;
      for (var receipt in receiptList) {
        final msgID = receipt.msgID;
        if (msgID != null && msgID.isNotEmpty) {
          // Some SDK versions report a fully-read receipt as
          // unreadCount=0/readCount>0 while leaving isPeerRead=false.
          // Normalize that combination so the chat message model and the
          // conversation-list projection use the same read decision.
          final fullyRead = receipt.isPeerRead == true ||
              (receipt.unreadCount != null &&
                  receipt.unreadCount == 0 &&
                  (receipt.readCount ?? 0) > 0);
          final next = V2TimMessageReceipt(
            userID: receipt.userID,
            timestamp: _receiptTimestamp(receipt.timestamp),
            msgID: msgID,
            isPeerRead: fullyRead,
            readCount: receipt.readCount,
            unreadCount: receipt.unreadCount,
            groupID: receipt.groupID,
          );
          final previous = _messageReadReceiptMap[msgID];
          if (previous?.isPeerRead != next.isPeerRead ||
              previous?.timestamp != next.timestamp ||
              previous?.readCount != next.readCount ||
              previous?.unreadCount != next.unreadCount) {
            _messageReadReceiptMap[msgID] = next;
            changed = true;
          }
          if (_isReceiptFullyRead(next)) {
            final convId = _conversationIdForReadReceipt(next);
            if (convId != null && convId.isNotEmpty) {
              ConversationPeerReadCoordinator.scheduleNotify(
                conversationID: convId,
                msgID: msgID,
                peerReadAtSec: next.timestamp,
              );
            }
          }
        }
      }
      if (changed) {
        for (final receipt in receiptList) {
          final msgID = receipt.msgID;
          if (msgID != null && msgID.isNotEmpty) {
            _markMessageRowsChangedByMsgID(msgID);
          }
        }
        _markNeedsNotify();
      }
    } catch (e) {}
  }

  bool _isReceiptFullyRead(V2TimMessageReceipt receipt) {
    if (receipt.isPeerRead == true) {
      return true;
    }
    final unread = receipt.unreadCount;
    final read = receipt.readCount ?? 0;
    return unread != null && unread == 0 && read > 0;
  }

  String? _conversationIdForReadReceipt(V2TimMessageReceipt receipt) {
    final group = receipt.groupID?.trim() ?? '';
    if (group.isNotEmpty) {
      return group.startsWith('group_') ? group : 'group_$group';
    }
    final msgID = receipt.msgID?.trim() ?? '';
    if (msgID.isNotEmpty) {
      for (final entry in _messageListMap.entries) {
        final list = entry.value;
        if (list == null || list.isEmpty) {
          continue;
        }
        for (final message in list) {
          if (message.msgID == msgID) {
            return entry.key;
          }
        }
      }
    }
    final peer = _normalizeC2CKey(receipt.userID);
    if (peer.isNotEmpty) {
      return 'c2c_$peer';
    }
    return null;
  }

  _onSendMessageProgress(V2TimMessage message, int progress) {
    final rawConvID = _messageConversationID(message) ??
        TencentUtils.checkString(message.userID) ??
        message.groupID;
    if (rawConvID == null || rawConvID.isEmpty) {
      return;
    }
    final convID = _resolveMessageListStorageKey(rawConvID);
    if (convID.isEmpty) {
      return;
    }
    final msgID = message.msgID;
    final id = message.id;
    if (isOutgoingMediaCancelled(id) || isOutgoingMediaCancelled(msgID)) {
      return;
    }
    final progressClamped = progress.clamp(0, 100);
    if (progressClamped > 0 && progressClamped < 100) {
      if (msgID != null && msgID.isNotEmpty) {
        _setUploadProgressSilently(msgID, progressClamped);
      }
      if (id != null && id.isNotEmpty) {
        _setUploadProgressSilently(id, progressClamped);
      }
      _markMessageRowChangedByIds(convID, msgID: msgID, clientId: id);
    } else if (progressClamped >= 100) {
      if (msgID != null && msgID.isNotEmpty) {
        _clearUploadProgressSilently(msgID);
      }
      if (id != null && id.isNotEmpty) {
        _clearUploadProgressSilently(id);
      }
      _markMessageRowChangedByIds(convID, msgID: msgID, clientId: id);
    }
    if (progressClamped >= 100 ||
        message.status == MessageStatus.V2TIM_MSG_STATUS_SEND_SUCC) {
      final committed = _syncSelfSentMessage(
        convID,
        message,
        forceSuccess: true,
      );
      if (committed) {
        _markNeedsNotify();
      }
      // A rejected or queued Writer commit is terminal for this callback. In
      // particular, do not turn a stale progress event into a formal-list
      // write after account/history state has moved on.
      return;
    }
  }

  Future<void> onMessageDownloadProgressCallback(
      V2TimMessageDownloadProgress messageProgress) async {
    final currentProgress = getMessageProgress(messageProgress.msgID);
    if (kDebugMode) {
      print(
          "onMessageDownloadProgressCallback, ${messageProgress.type} - ${messageProgress.isFinish} - ${messageProgress.currentSize} - $currentProgress - ");
    }

    if (messageProgress.isError || messageProgress.errorCode != 0) {
      V2TimMessage? message =
          await _findAndRetrieveMessage(messageProgress.msgID);
      _handleDownloadError(messageProgress, message);
      return;
    }

    if (messageProgress.isFinish && currentProgress < 100) {
      V2TimMessage? message =
          await _findAndRetrieveMessage(messageProgress.msgID);
      _handleFinishedDownload(messageProgress, message);
      return;
    }

    _updateProgressIfNeeded(messageProgress, currentProgress);
  }

  Future<V2TimMessage?> _findAndRetrieveMessage(String messageId) async {
    final messages =
        await _messageService.findMessages(messageIDList: [messageId]);
    return messages?.first;
  }

  void _handleFinishedDownload(
      V2TimMessageDownloadProgress messageProgress, V2TimMessage? message) {
    if (message != null) {
      bool isImageType =
          message.elemType == MessageElemType.V2TIM_ELEM_TYPE_IMAGE;
      bool isVideoType =
          message.elemType == MessageElemType.V2TIM_ELEM_TYPE_VIDEO;
      const originalImageType = 0;
      if (!isImageType && !isVideoType) {
        _updateMessageLocationAndDownloadFile(messageProgress);
      } else if ((isImageType && messageProgress.type == originalImageType) ||
          (isVideoType && !messageProgress.isSnapshot)) {
        Future.delayed(const Duration(seconds: 1),
            () => _updateMessageAndDownloadFile(message, messageProgress));
      } else {
        return;
      }
    } else {
      _updateMessageLocationAndDownloadFile(messageProgress);
    }
  }

  void _handleDownloadError(
      V2TimMessageDownloadProgress messageProgress, V2TimMessage? message) {
    setMessageProgress(messageProgress.msgID, 0);
    _markMessageRowsChangedByMsgID(messageProgress.msgID);
    _markNeedsNotify();
    downloadFile();
  }

  void _updateMessageAndDownloadFile(
      V2TimMessage message, V2TimMessageDownloadProgress messageProgress) {
    updateAsyncMessage(
        message,
        TencentUtils.checkString(message.userID) ??
            TencentUtils.checkString(message.groupID) ??
            "");

    _updateMessageLocationAndDownloadFile(messageProgress);
  }

  void _updateMessageLocationAndDownloadFile(
      V2TimMessageDownloadProgress messageProgress) {
    setFileMessageLocation(messageProgress.msgID, messageProgress.path);
    setMessageProgress(messageProgress.msgID, 100);
    _markMessageRowsChangedByMsgID(messageProgress.msgID);
    _markNeedsNotify();
    downloadFile();
  }

  void _updateProgressIfNeeded(
      V2TimMessageDownloadProgress messageProgress, int currentProgress) {
    try {
      if (messageProgress.totalSize != -1 && !messageProgress.isFinish) {
        int progress = min(
            99,
            (messageProgress.currentSize / messageProgress.totalSize * 100)
                .floor());
        if (progress > 1 && progress > currentProgress) {
          setMessageProgress(messageProgress.msgID, progress);
          _markMessageRowsChangedByMsgID(messageProgress.msgID);
          _markNeedsNotify();
        }
      }
    } catch (e) {
      outputLogger.i("calculate error: ${messageProgress.toJson()}");
    }
  }

  /// Ordinary chat callbacks are owned by the app-level
  /// [TencentAdvancedMessageAdapter]. Keep the old API source-compatible but
  /// prevent a view model from registering a second SDK listener.
  @Deprecated('The app MessageCore owns the only ordinary chat listener.')
  void addAdvancedMsgListener() {}

  @Deprecated('The app MessageCore owns the only ordinary chat listener.')
  void removeAdvanceMsgListener() {}

  /// Application-layer compatibility bridge for the single IM ingress.
  ///
  /// The SDK listener is owned by the app MessageCore. These methods preserve
  /// the existing UIKit projection behavior without registering another SDK
  /// listener inside the view model.
  Future<void> applyAppRealtimeMessage(V2TimMessage message) async {
    await _onReceiveNewMsg(message);
  }

  Future<void> applyAppMessageModified(
    V2TimMessage message, {
    String? conversationID,
  }) async {
    await onMessageModified(message, conversationID);
  }

  void applyAppMessageRevoked(String msgID, [String? conversationID]) {
    onMessageRevoked(msgID, conversationID);
  }

  void applyAppC2CReadReceipts(List<V2TimMessageReceipt> receipts) {
    _onReceiveC2CReadReceipt(receipts);
  }

  void applyAppMessageReadReceipts(List<V2TimMessageReceipt> receipts) {
    _onReceiveMessageReadReceipts(receipts);
  }

  void applyAppSendMessageProgress(V2TimMessage message, int progress) {
    _onSendMessageProgress(message, progress);
  }

  Future<void> applyAppMessageDownloadProgress(
    V2TimMessageDownloadProgress progress,
  ) {
    return onMessageDownloadProgressCallback(progress);
  }

  markMessageAsRead({
    required String convID,
    required ConvType convType,
  }) async {
    ChatJitterDiag.log(
      'active_read_report_start',
      conv: convID,
      extras: <String, Object?>{'convType': convType.name},
    );
    dynamic result;
    if (convType == ConvType.c2c) {
      result = await _messageService.markC2CMessageAsRead(userID: convID);
    } else if (kIsWeb) {
      ChatJitterDiag.log(
        'active_read_report_skip',
        conv: convID,
        extras: const <String, Object?>{'reason': 'web_group'},
      );
      return null;
    } else {
      result = await _messageService.markGroupMessageAsRead(groupID: convID);
    }
    ChatJitterDiag.log(
      'active_read_report_done',
      conv: convID,
      extras: <String, Object?>{
        'convType': convType.name,
        'sdkCode': result?.code,
        'sdkDesc': result?.desc,
      },
    );
    return result;
  }

  void _scheduleActiveReadReport({
    required String convID,
    required ConvType convType,
  }) {
    final lifecycleGeneration = _messageHistoryCoverageSessionGeneration;
    final normalizedConvID = _normalizeConversationID(convID);
    if (normalizedConvID.isEmpty) {
      return;
    }

    if (convType == ConvType.c2c) {
      final now = DateTime.now().millisecondsSinceEpoch;
      final last = _lastActiveReadReportAtMs[normalizedConvID] ?? 0;
      final elapsed = now - last;
      final delayMs = elapsed >= _activeReadReportMinIntervalMs
          ? _activeReadReportDebounceMs
          : _activeReadReportMinIntervalMs - elapsed;
      _activeReadReportDebounceMap[normalizedConvID]?.cancel();
      _activeReadReportDebounceMap[normalizedConvID] = Timer(
        Duration(milliseconds: delayMs),
        () async {
          _activeReadReportDebounceMap.remove(normalizedConvID);
          if (!_isMessageLifecycleCurrent(lifecycleGeneration) ||
              !_isSameConversationID(normalizedConvID, currentSelectedConv)) {
            ChatJitterDiag.log(
              'active_read_report_skip',
              conv: normalizedConvID,
              extras: const <String, Object?>{
                'reason': 'lifecycle_or_conversation_changed',
              },
            );
            return;
          }
          if (_isSameConversationID(normalizedConvID, currentSelectedConv)) {
            await markMessageAsRead(
              convID: normalizedConvID,
              convType: convType,
            );
            if (_isMessageLifecycleCurrent(lifecycleGeneration) &&
                _isSameConversationID(normalizedConvID, currentSelectedConv)) {
              _lastActiveReadReportAtMs[normalizedConvID] =
                  DateTime.now().millisecondsSinceEpoch;
            }
          }
        },
      );
      ChatJitterDiag.log(
        'active_read_report_scheduled',
        conv: normalizedConvID,
        extras: <String, Object?>{
          'convType': 'c2c',
          'delayMs': delayMs,
          'elapsedMs': elapsed,
        },
      );
      return;
    }

    if (kIsWeb) {
      return;
    }

    final now = DateTime.now().millisecondsSinceEpoch;
    final last = _lastActiveReadReportAtMs[normalizedConvID] ?? 0;
    final elapsed = now - last;
    final delayMs = elapsed >= _activeReadReportMinIntervalMs
        ? _activeReadReportDebounceMs
        : _activeReadReportMinIntervalMs - elapsed;

    _activeReadReportDebounceMap[normalizedConvID]?.cancel();
    _activeReadReportDebounceMap[normalizedConvID] = Timer(
      Duration(milliseconds: delayMs),
      () async {
        _activeReadReportDebounceMap.remove(normalizedConvID);
        if (!_isMessageLifecycleCurrent(lifecycleGeneration) ||
            !_isSameConversationID(normalizedConvID, currentSelectedConv)) {
          ChatJitterDiag.log(
            'active_read_report_skip',
            conv: normalizedConvID,
            extras: const <String, Object?>{
              'reason': 'lifecycle_or_conversation_changed',
            },
          );
          return;
        }
        await markMessageAsRead(convID: normalizedConvID, convType: convType);
        if (_isMessageLifecycleCurrent(lifecycleGeneration) &&
            _isSameConversationID(normalizedConvID, currentSelectedConv)) {
          _lastActiveReadReportAtMs[normalizedConvID] =
              DateTime.now().millisecondsSinceEpoch;
        }
      },
    );
    ChatJitterDiag.log(
      'active_read_report_scheduled',
      conv: normalizedConvID,
      extras: <String, Object?>{
        'convType': 'group',
        'delayMs': delayMs,
        'elapsedMs': elapsed,
      },
    );
  }

  Future<GroupReceiptAllowType?> _loadGroupReceiptType(String groupID) async {
    final groupInfoList =
        await _groupServices.getGroupsInfo(groupIDList: [groupID]);
    if (groupInfoList == null || groupInfoList.isEmpty) {
      return null;
    }
    final groupInfo = groupInfoList.first.groupInfo;
    const groupTypeMap = {
      "Meeting": GroupReceiptAllowType.meeting,
      "Public": GroupReceiptAllowType.public,
      "Work": GroupReceiptAllowType.work,
      "Community": GroupReceiptAllowType.community,
    };
    return groupTypeMap[groupInfo?.groupType];
  }

  bool _isReadReceiptAllowedGroup(GroupReceiptAllowType? groupType) {
    return groupType == GroupReceiptAllowType.work ||
        groupType == GroupReceiptAllowType.public ||
        groupType == GroupReceiptAllowType.meeting;
  }

  static bool _looksLikeCommunityGroupId(String? input) {
    var id = input?.trim() ?? '';
    if (id.isEmpty) {
      return false;
    }
    if (id.length > 6 && id.toLowerCase().startsWith('group_')) {
      id = id.substring(6);
    }
    final upper = id.toUpperCase();
    return upper.startsWith('@TGS#_') || upper.startsWith('TGS#_');
  }

  Future<V2TimValueCallback<V2TimMessage>?>? sendMessageFromController({
    required V2TimMessage? messageInfo,
    required ConvType convType,
    required String convID,
    ValueChanged<String>? setInputField,
    OfflinePushInfo? offlinePushInfo,
    MessagePriorityEnum priority = MessagePriorityEnum.V2TIM_PRIORITY_NORMAL,
    bool? onlineUserOnly,
    bool? isExcludedFromUnreadCount,
    bool? needReadReceipt,
    String? cloudCustomData,
    String? localCustomData,
    bool recoverPreparedOutbox = false,
    ValueChanged<ImCoordinatedSendResult>? onCoordinatedResult,
  }) {
    final TUIChatModelTools tools = serviceLocator<TUIChatModelTools>();
    if (messageInfo != null) {
      final messageInfoWithSender = messageInfo.sender == null
          ? tools.setUserInfoForMessage(messageInfo, messageInfo.id!)
          : messageInfo;
      messageInfoWithSender.status = MessageStatus.V2TIM_MSG_STATUS_SENDING;
      markMessageEnterAnimation(messageInfoWithSender);
      prepareForOutgoingMessage(convID);
      assignOutgoingLocalSeq(convID, messageInfoWithSender);
      commitMessageDelta(
        MessageDelta<V2TimMessage>(
          conversationKey: convID,
          eventID: 'optimistic:controller:${messageInfoWithSender.id ?? ''}',
          kind: MessageDeltaKind.optimisticInsert,
          source: MessageDeltaSource.sendPipeline,
          generation: messageDeltaGenerationFor(convID),
          clearEpoch: messageDeltaClearEpochFor(convID),
          upserts: [messageDeltaRecord(messageInfoWithSender)],
        ),
      );
      requestPinToBottom(convID, force: true);
      if (loadingMessage[convID] != null &&
          loadingMessage[convID]!.isNotEmpty) {
        loadingMessage[convID]!.add(messageInfoWithSender);
      } else {
        loadingMessage[convID] = <V2TimMessage>[messageInfoWithSender];
      }
      return _sendMessage(
        priority: priority,
        onlineUserOnly: onlineUserOnly,
        isExcludedFromUnreadCount: isExcludedFromUnreadCount,
        needReadReceipt: needReadReceipt,
        cloudCustomData: cloudCustomData,
        localCustomData: localCustomData,
        isExcludedFromContentModeration:
            messageInfo.isExcludedFromContentModeration ?? false,
        recoverPreparedOutbox: recoverPreparedOutbox,
        messageInfo: messageInfoWithSender,
        convID: convID,
        setInputField: setInputField,
        id: messageInfo.id as String,
        convType: ConvType.values[convType.index],
        offlinePushInfo: offlinePushInfo ??
            tools.buildMessagePushInfo(
                messageInfo, convID, ConvType.values[convType.index]),
        onCoordinatedResult: onCoordinatedResult,
      );
    }
    return null;
  }

  Future<V2TimValueCallback<V2TimMessage>?> sendReplyMessageFromController({
    required String text,
    required V2TimMessage messageBeenReplied,
    required String convID,
    required ConvType convType,
    ValueChanged<String>? setInputField,
    OfflinePushInfo? offlinePushInfo,
    MessagePriorityEnum priority = MessagePriorityEnum.V2TIM_PRIORITY_NORMAL,
    bool? onlineUserOnly,
    bool? isExcludedFromUnreadCount,
    bool? needReadReceipt,
    String? localCustomData,
  }) async {
    if (text.isEmpty) {
      return null;
    }
    final TUIChatModelTools tools = serviceLocator<TUIChatModelTools>();
    V2TimMsgCreateInfoResult? textMessageInfo =
        await _messageService.createTextMessage(text: text);

    textMessageInfo = await _messageService.createTextAtMessage(
        text: text +
            "\n@${TencentUtils.checkString(messageBeenReplied.nickName) ?? TencentUtils.checkString(messageBeenReplied.sender) ?? TencentUtils.checkString(messageBeenReplied.userID)}",
        atUserList: [
          TencentUtils.checkString(messageBeenReplied.sender) ??
              TencentUtils.checkString(messageBeenReplied.userID) ??
              ""
        ]);

    final V2TimMessage? messageInfo = textMessageInfo!.messageInfo;

    if (messageInfo != null) {
      final messageInfoWithSender = messageInfo.sender == null
          ? tools.setUserInfoForMessage(
              messageInfo, messageInfo.id ?? textMessageInfo.id ?? "")
          : messageInfo;
      messageInfoWithSender.status = MessageStatus.V2TIM_MSG_STATUS_SENDING;
      final hasNickName = messageBeenReplied.nickName != null &&
          messageBeenReplied.nickName != "";
      final cloudCustomData = {
        "messageReply": {
          "messageID": messageBeenReplied.msgID,
          "messageAbstract": tools.getMessageAbstract(
              messageBeenReplied, abstractMessageBuilder),
          "messageSender": hasNickName
              ? messageBeenReplied.nickName
              : messageBeenReplied.sender,
          "messageType": messageBeenReplied.elemType,
          "version": 1
        }
      };
      messageInfoWithSender.cloudCustomData = json.encode(cloudCustomData);

      markMessageEnterAnimation(messageInfoWithSender);
      prepareForOutgoingMessage(convID);
      assignOutgoingLocalSeq(convID, messageInfoWithSender);
      commitMessageDelta(
        MessageDelta<V2TimMessage>(
          conversationKey: convID,
          eventID: 'optimistic:reply:${messageInfoWithSender.id ?? ''}',
          kind: MessageDeltaKind.optimisticInsert,
          source: MessageDeltaSource.sendPipeline,
          generation: messageDeltaGenerationFor(convID),
          clearEpoch: messageDeltaClearEpochFor(convID),
          upserts: [messageDeltaRecord(messageInfoWithSender)],
        ),
      );
      requestPinToBottom(convID, force: true);
      if (loadingMessage[convID] != null &&
          loadingMessage[convID]!.isNotEmpty) {
        loadingMessage[convID]!.add(messageInfoWithSender);
      } else {
        loadingMessage[convID] = <V2TimMessage>[messageInfoWithSender];
      }

      return _sendMessage(
        cloudCustomData: json.encode(cloudCustomData),
        id: textMessageInfo.id as String,
        offlinePushInfo: offlinePushInfo ??
            tools.buildMessagePushInfo(
                messageInfo, convID, ConvType.values[convType.index]),
        priority: priority,
        onlineUserOnly: onlineUserOnly,
        isExcludedFromUnreadCount: isExcludedFromUnreadCount,
        needReadReceipt: needReadReceipt,
        localCustomData: localCustomData,
        messageInfo: messageInfoWithSender,
        convID: convID,
        setInputField: setInputField,
        convType: ConvType.values[convType.index],
      );
    }
    return null;
  }

  Future<bool> setLocalCustomData(
      String msgID, String localCustomData, String conversationID) async {
    final res = await _messageService.setLocalCustomData(
        msgID: msgID, localCustomData: localCustomData);
    if (res.code != 0) return false;
    _commitLocalMessageMetadata(
      conversationID: conversationID,
      messageID: msgID,
      localCustomData: localCustomData,
      eventID: 'local_custom_data:$conversationID:$msgID',
    );
    return true;
  }

  Future<bool> setLocalCustomInt(
      String msgID, int localCustomInt, String conversationID) async {
    final targetId = msgID.trim();
    if (targetId.isEmpty || conversationID.trim().isEmpty) {
      return false;
    }

    final storageKey = _resolveMessageListStorageKey(conversationID);
    final current = storageKey.isEmpty
        ? const <V2TimMessage>[]
        : _mergedAliasMessageList(storageKey);
    final touched = current.any(
      (item) => item.msgID?.trim() == targetId || item.id?.trim() == targetId,
    );
    if (touched) {
      _commitLocalMessageMetadata(
        conversationID: storageKey,
        messageID: targetId,
        localCustomInt: localCustomInt,
        eventID: 'local_custom_int:$storageKey:$targetId',
      );
    }

    final res = await _messageService.setLocalCustomInt(
        msgID: targetId, localCustomInt: localCustomInt);
    if (res.code != 0) return touched;

    if (!touched && storageKey.isNotEmpty) {
      _commitLocalMessageMetadata(
        conversationID: storageKey,
        messageID: targetId,
        localCustomInt: localCustomInt,
        eventID: 'local_custom_int_sdk:$storageKey:$targetId',
      );
    }
    return true;
  }

  bool _commitLocalMessageMetadata({
    required String conversationID,
    required String messageID,
    String? localCustomData,
    int? localCustomInt,
    required String eventID,
  }) {
    final storageKey = _resolveMessageListStorageKey(conversationID);
    final targetID = messageID.trim();
    if (storageKey.isEmpty || targetID.isEmpty) return false;
    final current = _mergedAliasMessageList(storageKey);
    for (final item in current) {
      if (item.msgID?.trim() != targetID && item.id?.trim() != targetID) {
        continue;
      }
      final next = _cloneMessage(item);
      if (localCustomData != null) next.localCustomData = localCustomData;
      if (localCustomInt != null) next.localCustomInt = localCustomInt;
      if (next.localCustomData == item.localCustomData &&
          next.localCustomInt == item.localCustomInt) {
        return true;
      }
      final commit = commitMessageDelta(
        MessageDelta<V2TimMessage>(
          conversationKey: storageKey,
          eventID: eventID,
          kind: MessageDeltaKind.localMetadata,
          source: MessageDeltaSource.userAction,
          generation: messageDeltaGenerationFor(storageKey),
          clearEpoch: messageDeltaClearEpochFor(storageKey),
          upserts: <MessageReconciliationRecord<V2TimMessage>>[
            _reconciliationRecord(next),
          ],
        ),
      );
      if (commit == null) return false;
      _chatUiStateStore.markMessagesChanged(
        storageKey,
        <String>{
          ChatUiStateStore.messageKeyOf(item),
          ChatUiStateStore.messageKeyOf(next),
          targetID,
        },
      );
      _markMessageRowChanged(storageKey, next, extraKey: targetID);
      if (_isSameConversationID(storageKey, currentSelectedConv)) {
        _markNeedsNotify();
      }
      return true;
    }
    return false;
  }

  Future<V2TimValueCallback<V2TimMessage>> _sendMessage({
    required String id,
    required String convID,
    required ConvType convType,
    OfflinePushInfo? offlinePushInfo,
    bool? onlineUserOnly = false,
    bool? isEditStatusMessage = false,
    GroupReceiptAllowType? groupType,
    ValueChanged<String>? setInputField,
    MessagePriorityEnum priority = MessagePriorityEnum.V2TIM_PRIORITY_NORMAL,
    bool? isExcludedFromUnreadCount,
    bool? needReadReceipt,
    String? cloudCustomData,
    String? localCustomData,
    V2TimMessage? messageInfo,
    bool isExcludedFromContentModeration = false,
    bool recoverPreparedOutbox = false,
    ValueChanged<ImCoordinatedSendResult>? onCoordinatedResult,
  }) async {
    String receiver = convType == ConvType.c2c ? convID : '';
    String groupID = convType == ConvType.group ? convID : '';
    // 历史桶 key 常带 `c2c_` / `group_` 前缀；IM sendMessage 必须用裸 userID / groupID。
    if (receiver.toLowerCase().startsWith('c2c_') && receiver.length > 4) {
      receiver = receiver.substring(4);
    }
    if (groupID.toLowerCase().startsWith('group_') && groupID.length > 6) {
      groupID = groupID.substring(6);
    }
    final receiptGroupType = groupType ??
        (convType == ConvType.group
            ? await _loadGroupReceiptType(groupID)
            : null);
    final useReadReceipt =
        (needReadReceipt ?? chatConfig.isShowReadingStatus) &&
            (convType != ConvType.group ||
                _isReadReceiptAllowedGroup(receiptGroupType)) &&
            !_looksLikeCommunityGroupId(groupID);
    final coordinatedSend = await ImOutgoingSendCoordinator.instance.send(
      messageService: _messageService,
      sdkLocalId: id,
      conversationId: convID,
      conversationType: convType == ConvType.group
          ? ImConversationType.group
          : ImConversationType.c2c,
      receiver: receiver,
      groupID: groupID,
      fallbackMessage: messageInfo,
      needReadReceipt: useReadReceipt,
      priority: priority,
      localCustomData: localCustomData,
      isExcludedFromUnreadCount: isExcludedFromUnreadCount ?? false,
      offlinePushInfo: offlinePushInfo,
      isExcludedFromContentModeration: isExcludedFromContentModeration,
      onlineUserOnly: onlineUserOnly ?? false,
      businessCloudCustomData: cloudCustomData ??
          json.encode({
            "messageFeature": {
              "needTyping": 1,
              "version": 1,
            }
          }),
      persistOutbox: isEditStatusMessage != true,
      recoverPreparedOutbox: recoverPreparedOutbox,
      onSyncMsgID: (syncMsgID) {
        bindOutgoingSyncMsgId(convID, id, syncMsgID);
      },
    );
    onCoordinatedResult?.call(coordinatedSend);
    final sendMsgRes = coordinatedSend.sdkResult;
    // IM-08: when the SDK Future resolves OutcomeUnknown, the dispatch path
    // cannot prove the provider accepted or rejected the operation. The
    // Outbox main + recovery copy already record OutcomeUnknown; the
    // single Writer must keep the optimistic bubble in SENDING and wait
    // for history/realtime to claim it. Auto-committing a success/failed
    // projection here would resurrect an in-flight message or flash a
    // red retry icon on a still-pending send.
    var projectionCommitted = true;
    if (isEditStatusMessage == false && !coordinatedSend.outcomeUnknown) {
      projectionCommitted = applyOutgoingSendResult(
          sendMsgRes, convID, id, convType, receiptGroupType, setInputField);
    } else if (coordinatedSend.outcomeUnknown) {
      projectionCommitted = false;
    }
    if (projectionCommitted && coordinatedSend.canCompleteProjection) {
      await ImOutgoingSendCoordinator.instance.completeSuccessfulProjection(
        coordinatedSend,
      );
    }
    if (_lifeCycle?.messageDidSend != null) {
      _lifeCycle!.messageDidSend(sendMsgRes);
    }

    return sendMsgRes;
  }

  String? _messageEnterAnimationKey(V2TimMessage message) {
    final id = message.id;
    if (id != null && id.toString().isNotEmpty) {
      return id.toString();
    }
    final msgID = message.msgID;
    if (msgID != null && msgID.isNotEmpty) {
      return msgID;
    }
    return null;
  }

  void markMessageEnterAnimation(V2TimMessage message) {
    final skip = chatConfig.skipMessageEnterAnimationForMessage;
    if (skip != null && skip(message)) {
      return;
    }
    final convId = _messageConversationID(message);
    if (convId != null && isBulkMessageSyncActive(convId)) {
      return;
    }
    final key = _messageEnterAnimationKey(message);
    if (key == null) {
      return;
    }
    final throttleMs = chatConfig.messageEnterAnimationThrottleMs;
    if (convId != null && throttleMs > 0) {
      final now = DateTime.now().millisecondsSinceEpoch;
      final lastMark = _enterAnimationThrottleMarkMsByConv[convId] ?? 0;
      if (now - lastMark < throttleMs) {
        final superseded = _enterAnimationThrottlePendingKeyByConv[convId];
        if (superseded != null) {
          _messageEnterAnimationKeys.remove(superseded);
        }
      }
      _enterAnimationThrottleMarkMsByConv[convId] = now;
      _enterAnimationThrottlePendingKeyByConv[convId] = key;
    }
    _messageEnterAnimationKeys.add(key);
    _maybeScheduleSendFlyOverlay(message, key);
  }

  ChatSendFlyOverlayRequest? get sendFlyOverlayRequest =>
      _sendFlyOverlayRequest;

  bool isSendFlyOverlayPendingForMessage(V2TimMessage message) {
    final req = _sendFlyOverlayRequest;
    if (req == null) {
      return false;
    }
    final key = _messageEnterAnimationKey(message);
    return key != null && key == req.messageKey;
  }

  bool shouldHideBubbleForSendFly(V2TimMessage message) {
    if (!chatConfig.sendFlyOverlayEnabled) {
      return false;
    }
    return isSendFlyOverlayPendingForMessage(message);
  }

  void reportSendFlyTargetRect(V2TimMessage message, Rect rect) {
    final req = _sendFlyOverlayRequest;
    if (req == null) {
      return;
    }
    final key = _messageEnterAnimationKey(message);
    if (key == null || key != req.messageKey) {
      return;
    }
    final existing = req.targetRect;
    if (existing != null &&
        (existing.top - rect.top).abs() < 0.5 &&
        (existing.height - rect.height).abs() < 0.5) {
      return;
    }
    _sendFlyOverlayRequest = req.copyWith(targetRect: rect);
    notifyListeners();
  }

  void completeSendFlyOverlay() {
    if (_sendFlyOverlayRequest == null) {
      return;
    }
    _sendFlyOverlayRequest = null;
    notifyListeners();
  }

  void _maybeScheduleSendFlyOverlay(V2TimMessage message, String key) {
    if (!chatConfig.sendFlyOverlayEnabled) {
      return;
    }
    if (message.isSelf != true) {
      return;
    }
    if (message.elemType != MessageElemType.V2TIM_ELEM_TYPE_TEXT) {
      return;
    }
    final text = message.textElem?.text?.trim() ?? '';
    if (text.isEmpty) {
      return;
    }
    final convId = _messageConversationID(message);
    if (convId == null || convId.isEmpty) {
      return;
    }
    _sendFlyOverlayRequest = ChatSendFlyOverlayRequest(
      messageKey: key,
      text: text,
      conversationId: convId,
    );
    notifyListeners();
  }

  void _markIncomingMessageEnterAnimation(V2TimMessage message) {
    if (message.isSelf == true) {
      return;
    }
    if (!shouldAnimateInboundPresentation) {
      return;
    }
    // WeChat list-push mode animates the viewport itself: a complete row starts
    // below the list's clipping edge and the scroll offset moves back to the
    // bottom. A per-bubble translate would double the movement and make the
    // row appear to expand or rebound.
    if (chatConfig.messageEnterAnimationStyle ==
            MessageEnterAnimationStyle.wechat &&
        chatConfig.messageEnterAnimationListPushEnabled) {
      return;
    }
    final convId = _messageConversationID(message);
    if (convId != null && isBulkMessageSyncActive(convId)) {
      return;
    }
    if (convId != null && !_isActiveChatNearBottom(convId)) {
      return;
    }
    markMessageEnterAnimation(message);
  }

  /// 消息是否仍在播放入场动画（仿微信 notifyItemInserted 后 ItemAnimator 未结束）。
  bool isMessageEnterAnimationPending(V2TimMessage message) {
    final key = _messageEnterAnimationKey(message);
    if (key == null) {
      return false;
    }
    return _messageEnterAnimationKeys.contains(key);
  }

  void finishMessageEnterAnimation(V2TimMessage message) {
    final key = _messageEnterAnimationKey(message);
    if (key != null) {
      _messageEnterAnimationKeys.remove(key);
    }
  }

  @Deprecated('Use isMessageEnterAnimationPending')
  bool shouldPlayMessageEnterAnimation(V2TimMessage message) {
    return isMessageEnterAnimationPending(message);
  }

  @Deprecated('Use markMessageEnterAnimation')
  void markOutgoingMessageEnterAnimation(V2TimMessage message) {
    markMessageEnterAnimation(message);
  }

  @Deprecated('Use isMessageEnterAnimationPending')
  bool shouldPlayOutgoingEnterAnimation(V2TimMessage message) {
    return isMessageEnterAnimationPending(message);
  }

  /// 覆盖 msgID/seq/状态的内容签名。打开会话后本地校验、头像回填等
  /// 路径会把同样的列表原样写回；签名一致时跳过 revision bump，
  /// 避免 Selector 因 revision 变化整表重建（进入页面时头像/列表抖动）。
  ///
  /// 故意不含 faceUrl：头像回填只改展示字段，不应触发消息列表 revision。
  static bool _listHasCorrelatingDup(List<V2TimMessage> messages) {
    if (messages.length < 2) {
      return false;
    }
    final scanCount = messages.length < 32 ? messages.length : 32;
    for (var i = 0; i < scanCount; i++) {
      for (var j = i + 1; j < scanCount; j++) {
        if (messagesCorrelateForDedup(messages[i], messages[j])) {
          return true;
        }
      }
    }
    return false;
  }

  static String _messageListContentSignature(List<V2TimMessage> messageList) {
    final buffer = StringBuffer()
      ..write(messageList.length)
      ..write(';');
    for (final message in messageList) {
      buffer
        ..write(message.msgID ?? message.id ?? '')
        ..write(':')
        ..write(message.seq ?? '')
        ..write(':')
        ..write(message.status ?? '')
        ..write(':')
        ..write(message.progress ?? '')
        ..write(':')
        ..write(message.localCustomInt ?? '')
        ..write(':')
        ..write(message.elemType)
        ..write(':')
        ..write(_messageMediaAvailabilitySignature(message))
        ..write(';');
    }
    return buffer.toString();
  }

  static String _messageMediaAvailabilitySignature(V2TimMessage message) {
    final imageSignature = (message.imageElem?.imageList ?? const [])
        .whereType<V2TimImage>()
        .map((item) => '${item.type}:${item.url ?? ''}:${item.localUrl ?? ''}')
        .join(',');
    final video = message.videoElem;
    final sound = message.soundElem;
    final file = message.fileElem;
    return <String>[
      imageSignature,
      video?.videoUrl ?? '',
      video?.snapshotUrl ?? '',
      video?.localVideoUrl ?? '',
      video?.localSnapshotUrl ?? '',
      sound?.url ?? '',
      sound?.localUrl ?? '',
      file?.url ?? '',
      file?.localUrl ?? '',
    ].join('|');
  }

  @visibleForTesting
  static String messageListCommitSignatureForTesting(
    List<V2TimMessage> messages,
  ) =>
      _messageListContentSignature(messages);

  final Map<String, String> _messageListContentSignatureByConv = {};
  final Map<String, String> _historyWindowCommitSignatureByConv = {};

  /// 读历史（一屏外 / 非最新）期间冻结内存窗口裁剪，避免 prepend 后列表长度震荡。
  bool _shouldFreezeMemoryWindowTrimWhileReadingHistory(String conversationID) {
    final isActive = currentSelectedConv.trim().isNotEmpty &&
        _isSameConversationID(conversationID, currentSelectedConv);
    if (!isActive) {
      return false;
    }
    final position = getMessageListPosition(conversationID);
    return position == HistoryMessagePosition.awayTwoScreen ||
        position == HistoryMessagePosition.notShowLatest;
  }

  /// 内存窗口闸门：只裁 `_messageListMap`，绝不删 DB/SDK 存储。
  List<V2TimMessage> _applyMessageMemoryWindow(
    String conversationID,
    List<V2TimMessage> sorted, {
    String? anchorMsgID,
    String? anchorSeq,
    bool forcePreferLatest = false,
    bool forceWhileReadingHistory = false,
  }) {
    if (!ChatMessageWindowPolicy.enabled) {
      return sorted;
    }
    if (isMemoryWindowSuppressed(conversationID) && !forceWhileReadingHistory) {
      ChatJitterDiag.log(
        'memory_window',
        conv: conversationID,
        extras: <String, Object?>{
          'action': 'skip_suppressed',
          'len': sorted.length,
          'position': getMessageListPosition(conversationID).name,
        },
      );
      return sorted;
    }
    if (!forceWhileReadingHistory &&
        _shouldFreezeMemoryWindowTrimWhileReadingHistory(conversationID)) {
      ChatJitterDiag.log(
        'memory_window',
        conv: conversationID,
        extras: <String, Object?>{
          'action': 'skip_frozen_reading_history',
          'len': sorted.length,
          'position': getMessageListPosition(conversationID).name,
        },
      );
      return sorted;
    }
    if (sorted.length <= ChatMessageWindowPolicy.softMax) {
      return sorted;
    }

    final isActive = currentSelectedConv.trim().isNotEmpty &&
        _isSameConversationID(conversationID, currentSelectedConv);
    final position = getMessageListPosition(conversationID);
    final preferLatest = forcePreferLatest ||
        !isActive ||
        position == HistoryMessagePosition.bottom ||
        position == HistoryMessagePosition.inTwoScreen;

    String? resolvedMsgID = anchorMsgID?.trim();
    String? resolvedSeq = anchorSeq?.trim();
    if ((resolvedMsgID == null || resolvedMsgID.isEmpty) &&
        (resolvedSeq == null || resolvedSeq.isEmpty) &&
        _memoryWindowAnchorConvID != null &&
        _isSameConversationID(_memoryWindowAnchorConvID!, conversationID)) {
      resolvedMsgID = _memoryWindowAnchorMsgID;
      resolvedSeq = _memoryWindowAnchorSeq;
    }

    final result = ChatMessageWindow.trimToWindow(
      list: sorted,
      preferLatest: preferLatest,
      anchorMsgID: resolvedMsgID,
      anchorSeq: resolvedSeq,
    );
    if (!result.didTrim) {
      return sorted;
    }
    if (result.trimmedAwayLatest) {
      markMemoryWindowMissingNewer(conversationID);
    }
    if (result.trimmedAwayOldestInMemory) {
      markMemoryWindowMissingOlder(conversationID);
    }
    final retainedBoundary = result.list.isEmpty
        ? 0
        : (preferLatest
            ? (result.list.last.timestamp ?? 0)
            : (result.list.first.timestamp ?? 0));
    if (retainedBoundary > 0) {
      _memoryWindowBoundaryTimestampByConv[conversationID.trim()] =
          retainedBoundary;
    }
    final retainedSeq = result.list.isEmpty
        ? ''
        : (preferLatest
            ? (result.list.last.seq ?? '')
            : (result.list.first.seq ?? ''));
    if (retainedSeq.trim().isNotEmpty) {
      _memoryWindowBoundarySeqByConv[conversationID.trim()] =
          retainedSeq.trim();
    }
    // 注意：preferLatest 只表示「保留当前内存里的最新端」，不等于全局最新。
    // missingNewer 只能在真正 loadLatest 到底 / reloadNewest 成功后清除。
    ChatHistoryTrace.log(
      'memory_window_trim',
      conversationID: conversationID,
      extras: <String, Object?>{
        'before': sorted.length,
        'after': result.list.length,
        'removedNewer': result.removedNewerCount,
        'removedOlder': result.removedOlderCount,
        'trimmedAwayLatest': result.trimmedAwayLatest,
        'trimmedAwayOldest': result.trimmedAwayOldestInMemory,
        'preferLatest': preferLatest,
        'forcePreferLatest': forcePreferLatest,
        'position': position.name,
        'isActive': isActive,
        'anchorMsgID': resolvedMsgID,
        'anchorSeq': resolvedSeq,
      },
    );
    ChatJitterDiag.log(
      'memory_window',
      conv: conversationID,
      extras: <String, Object?>{
        'action': 'trim',
        'before': sorted.length,
        'after': result.list.length,
        'removedNewer': result.removedNewerCount,
        'removedOlder': result.removedOlderCount,
        'preferLatest': preferLatest,
        'position': position.name,
        'anchorMsgID': resolvedMsgID,
      },
    );
    return result.list;
  }

  String _commitSnapshotIdentity(V2TimMessage message) {
    final key = messageDedupKey(message).trim();
    if (key.isNotEmpty) return key;
    final msgID = message.msgID?.trim() ?? '';
    if (msgID.isNotEmpty) return 'msg:$msgID';
    final id = message.id?.trim() ?? '';
    if (id.isNotEmpty) return 'id:$id';
    return 'wire:${message.timestamp ?? 0}:${message.random ?? 0}';
  }

  bool _messageCommitStructureChanged(
    List<V2TimMessage> previous,
    List<V2TimMessage> next,
  ) {
    if (previous.length != next.length) return true;
    for (var index = 0; index < previous.length; index++) {
      if (_commitSnapshotIdentity(previous[index]) !=
          _commitSnapshotIdentity(next[index])) {
        return true;
      }
    }
    return false;
  }

  bool _memoryWindowMissingOlder(String conversationID) =>
      _memoryWindowMissingOlderByConv.entries.any(
        (entry) =>
            entry.value && _isSameConversationID(entry.key, conversationID),
      );

  /// Public accessor: true when the memory window was trimmed on the older
  /// side and the user can scroll up to load more (haveMoreData must be true).
  bool memoryWindowMissingOlder(String conversationID) =>
      _memoryWindowMissingOlder(conversationID);

  /// C2C lastMessage verification: when onConversationChanged arrives with
  /// a lastMessage that is not in the active C2C chat's visible list,
  /// the onRecvNewMessage push was lost. Trigger a CLOUD_NEWER catch-up.
  void verifyC2CLastMessage(List<V2TimConversation> conversations) {
    final activeConv = currentSelectedConv;
    if (activeConv.isEmpty) return;
    for (final conv in conversations) {
      final convIdRaw = (conv.conversationID ?? '').trim();
      if (!convIdRaw.toLowerCase().startsWith('c2c')) continue;
      final convID = _resolveMessageListStorageKey(conv.conversationID ?? '');
      if (!_isSameConversationID(convID, activeConv)) continue;
      final lastMsg = conv.lastMessage;
      if (lastMsg == null) continue;
      final lastMsgID = (lastMsg.msgID ?? lastMsg.id ?? '').trim();
      if (lastMsgID.isEmpty) continue;
      final list = _messageListMap[convID] ??
          _messageListMap[_resolveMessageListStorageKey(convID)];
      if (list == null || list.isEmpty) continue;
      bool found = false;
      for (final msg in list) {
        final msgID = (msg.msgID ?? msg.id ?? '').trim();
        if (msgID.isNotEmpty && msgID == lastMsgID) {
          found = true;
          break;
        }
      }
      if (!found && !_gapCatchUpInFlight.contains(convID)) {
        _gapCatchUpInFlight.add(convID);
        unawaited(_c2cLastMessageCatchUp(convID, activeConv));
      }
    }
  }

  Future<void> _c2cLastMessageCatchUp(String convID, String rawConvID) async {
    await reconcileConversationCloud(
      rawConvID.isEmpty ? convID : rawConvID,
      reason: 'c2c_preview_ahead',
    );
    _gapCatchUpInFlight.remove(convID);
  }

  /// Clears the missing-older flag so haveMoreData reflects only the SDK
  /// pagination state.
  void clearMemoryWindowMissingOlder(String conversationID) {
    final keys = _memoryWindowMissingOlderByConv.keys
        .where((k) => _isSameConversationID(k, conversationID))
        .toList(growable: false);
    for (final key in keys) {
      _memoryWindowMissingOlderByConv.remove(key);
    }
  }

  MessageCommitResult _messageCommitSnapshot({
    required String conversationID,
    required String storageKey,
    required List<V2TimMessage> list,
    required bool structureChanged,
    required bool contentChanged,
    required bool recordCommit,
    MessageReconciliationWriterCommit<V2TimMessage>? writerCommit,
  }) {
    if (recordCommit) {
      _messageCommitGenerationByConv[storageKey] =
          (_messageCommitGenerationByConv[storageKey] ?? 0) + 1;
      _messageCommitTokenByConv[storageKey] = ++_nextMessageCommitToken;
    }
    final projectionKey = _inboundStateKey(conversationID);
    final unreadState = _inboundUnreadStateFor(projectionKey, create: false);
    return MessageCommitResult(
      conversationID: storageKey,
      token: _messageCommitTokenByConv[storageKey] ?? 0,
      generation: _messageCommitGenerationByConv[storageKey] ?? 0,
      listRevision: messageListRevisionFor(storageKey),
      projectionRevision: messageProjectionRevisionFor(conversationID),
      rawCount: list.length,
      firstIdentity: list.isEmpty ? null : _commitSnapshotIdentity(list.first),
      lastIdentity: list.isEmpty ? null : _commitSnapshotIdentity(list.last),
      memoryWindowMissingNewer: memoryWindowMissingNewer(conversationID),
      memoryWindowMissingOlder: _memoryWindowMissingOlder(conversationID),
      memoryWindowSuppressed: isMemoryWindowSuppressed(conversationID),
      unreadBufferedCount: unreadState.bufferedMessageKeys.length,
      unreadProjectionHeld:
          _deferredUntilUserBottomConversations.contains(projectionKey),
      structureChanged: structureChanged,
      contentChanged: contentChanged,
      writerRevision: writerCommit?.revision,
      writerGeneration: writerCommit?.generation,
      writerClearEpoch: writerCommit?.clearEpoch,
      writerOwnerUserID: writerCommit?.ownerUserID,
      writerAccountGeneration: writerCommit?.accountGeneration,
      writerDomainGeneration: writerCommit?.domainGeneration,
    );
  }

  bool isMessageCommitCurrent(MessageCommitResult result) {
    final key = canonicalHistoryStorageKey(result.conversationID);
    final storageKey = key.isNotEmpty ? key : result.conversationID.trim();
    return (_messageCommitTokenByConv[storageKey] ?? 0) == result.token &&
        (_messageCommitGenerationByConv[storageKey] ?? 0) == result.generation;
  }

  MessageMutationType _messageMutationTypeForCommit({
    required bool replace,
    required bool isDeleteMsg,
    required bool structureChanged,
  }) {
    if (replace) return MessageMutationType.historyWindow;
    if (isDeleteMsg) return MessageMutationType.removeOrRevoke;
    if (structureChanged) return MessageMutationType.reorder;
    return MessageMutationType.contentOrMedia;
  }

  MessageCommitResult setMessageList(
      String conversationID, List<V2TimMessage> messageList,
      {bool needResetNewMessageCount = true,
      bool isDeleteMsg = false,

      /// true：整表替换，不与旧内存拼接（会话预览首屏 / 已合并全量列表写入用）。
      bool replace = false,

      /// false：跳过内存窗口裁剪（搜索定位拉史等）。
      bool applyMemoryWindow = true,

      /// true：强制保留最新端窗口（loadLatest / 回底补窗）。
      bool memoryWindowPreferLatest = false,

      /// true：显式分页收尾时允许按锚点收束读历史窗口。
      bool forceMemoryWindowTrimWhileReading = false,

      /// 覆盖全局挂起的窗口锚点。
      String? memoryWindowAnchorMsgID,
      String? memoryWindowAnchorSeq,
      bool skipEquivalentHistoryWindow = false,
      String historyCommitSource = 'unspecified',
      MessageReconciliationWriterCommit<V2TimMessage>? writerCommit}) {
    final canonical = canonicalHistoryStorageKey(conversationID);
    final storageKey = canonical.isNotEmpty ? canonical : conversationID.trim();
    final previous = _mergedAliasMessageList(conversationID);
    if (writerCommit == null &&
        _messageReconciliationWriter.hasActiveRequest(storageKey)) {
      // A history transaction owns the next formal publication. Legacy
      // callers may still invoke setMessageList, but they cannot publish a
      // competing snapshot while that transaction is active.
      return _messageCommitSnapshot(
        conversationID: conversationID,
        storageKey: storageKey,
        list: previous,
        structureChanged: false,
        contentChanged: false,
        recordCommit: false,
      );
    }
    if (writerCommit == null) {
      // Legacy callers remain source-compatible, but their snapshot must be
      // admitted by the same identity/revision boundary as every other
      // formal mutation. Seed from the current projection first because the
      // Writer may be seeing this conversation for the first time.
      final clearEpoch = messageDeltaClearEpochFor(storageKey);
      _messageReconciliationWriter.seedAuthoritative(
        conversationID: storageKey,
        records: _reconciliationRecords(previous),
        trackSeqGaps: _isGroupConversation(storageKey, messages: previous),
        clearEpoch: clearEpoch,
      );
      final compatibilityCommit =
          _messageReconciliationWriter.applyCompatibilitySnapshot(
        conversationID: storageKey,
        eventID:
            'compatibility:set_message_list:$storageKey:${++_nextRealtimeReconciliationEvent}',
        records: _reconciliationRecords(messageList),
        generation: messageDeltaGenerationFor(storageKey),
        clearEpoch: clearEpoch,
        replace: replace || isDeleteMsg,
      );
      if (compatibilityCommit == null) {
        return _messageCommitSnapshot(
          conversationID: conversationID,
          storageKey: storageKey,
          list: previous,
          structureChanged: false,
          contentChanged: false,
          recordCommit: false,
        );
      }
      writerCommit = compatibilityCommit;
      messageList = compatibilityCommit.records
          .map((record) => record.value)
          .toList(growable: false);
      // The Writer has already produced a complete authoritative snapshot;
      // this method now only applies the existing memory-window/UI projection.
      replace = true;
    }
    if (replace) {
      // Do this before the equivalent-window fast path as well. A replace can
      // carry no content delta while still superseding a pending presentation
      // transaction that has hidden rows in the projection.
      cancelInboundProjectionRevealForAuthoritativeReplace(conversationID);
    }
    if (skipEquivalentHistoryWindow &&
        writerCommit != null &&
        replace &&
        !isDeleteMsg &&
        previous.length == messageList.length) {
      final previousSignature = _messageListContentSignature(previous);
      final incomingSignature = _messageListContentSignature(messageList);
      final commitSignature = '$historyCommitSource|$incomingSignature';
      if (previousSignature == incomingSignature &&
          _historyWindowCommitSignatureByConv[storageKey] == commitSignature) {
        if (replace &&
            _revealAllDeferredProjectionAcrossAliases(conversationID)) {
          _markNeedsNotify();
        }
        return _messageCommitSnapshot(
          conversationID: conversationID,
          storageKey: storageKey,
          list: previous,
          structureChanged: false,
          contentChanged: false,
          recordCommit: false,
          writerCommit: writerCommit,
        );
      }
      _historyWindowCommitSignatureByConv[storageKey] = commitSignature;
    }
    var incomingForMerge = messageList;
    if (!isDeleteMsg && previous.isNotEmpty) {
      final extras = collectUncorrelatedInFlightOutgoing(
        previous: previous,
        incoming: messageList,
      );
      if (OutgoingVisibleProbe.matches(conversationID) ||
          OutgoingVisibleProbe.matches(storageKey)) {
        OutgoingVisibleProbe.log(
          replace ? 'set_list_replace_retain' : 'set_list_merge_retain',
          conversationID: storageKey,
          extras: <String, Object?>{
            'prevCount': previous.length,
            'incomingCount': messageList.length,
            'retainCount': extras.length,
            'retainIds':
                extras.map((m) => '${m.id ?? ''}/${m.msgID ?? ''}').join(','),
            'prevHasTracked':
                OutgoingVisibleProbe.trackedInList(previous).toString(),
            'incomingHasTracked':
                OutgoingVisibleProbe.trackedInList(messageList).toString(),
          },
        );
      }
      if (extras.isNotEmpty) {
        incomingForMerge = <V2TimMessage>[...messageList, ...extras];
      }
    }
    if (replace &&
        !isDeleteMsg &&
        applyMemoryWindow &&
        HistoryPaginationAnchor.shouldRejectC2cPeekRestamp(
          existingCount: previous.length,
          incomingCount: incomingForMerge.length,
        )) {
      if (OutgoingVisibleProbe.matches(conversationID) ||
          OutgoingVisibleProbe.matches(storageKey)) {
        OutgoingVisibleProbe.log(
          'c2c_reject_peek_restamp',
          conversationID: storageKey,
          extras: <String, Object?>{
            'prevCount': previous.length,
            'incomingCount': incomingForMerge.length,
          },
        );
      }
      incomingForMerge = mergeC2cOfficialOlderPage(
        existing: previous,
        fetched: incomingForMerge,
      );
    } else if (replace &&
        previous.isEmpty &&
        (OutgoingVisibleProbe.matches(conversationID) ||
            OutgoingVisibleProbe.matches(storageKey))) {
      OutgoingVisibleProbe.log(
        'set_list_replace_empty_prev',
        conversationID: storageKey,
        extras: <String, Object?>{
          'incomingCount': messageList.length,
          'incomingHasTracked':
              OutgoingVisibleProbe.trackedInList(messageList).toString(),
        },
      );
    }
    // 始终 dedupe：分页写入常已含 previous，再拼接会产生重复 key，表现为顶部无法加载。
    final mergedInput = replace || isDeleteMsg || previous.isEmpty
        ? incomingForMerge
        : <V2TimMessage>[...incomingForMerge, ...previous];
    final sorted = ChatMainThreadPerf.measure(
      ChatMainThreadPerf.setMessageListMs,
      () {
        var result = sortMessagesNewestFirst(dedupeMessages(mergedInput));
        // 正常列表首遍已经稳定；仅检测到相关性重复时再做收紧，避免每次分页/
        // 恢复都无条件重复一次全表 dedupe + sort。
        if (_listHasCorrelatingDup(result)) {
          final tightened = sortMessagesNewestFirst(dedupeMessages(result));
          if (tightened.length < result.length) {
            result = tightened;
          }
        }
        if (applyMemoryWindow && !isDeleteMsg) {
          // Only group Seq provides protocol-level continuity. A detected
          // range is repaired through the bounded reconciliation writer;
          // synchronization state never enters the message list as a marker.
          final isGroup = _isGroupConversation(
            storageKey,
            messages: result,
          );
          final gaps = isGroup
              ? GapDetector.detectGaps(
                  newestFirst: result,
                  isGroup: true,
                  fullScan: true,
                )
              : const <GapInfo>[];
          if (isGroup) {
            _clearResolvedGroupGapAttempts(storageKey, gaps);
          }
          if (gaps.isNotEmpty) {
            _requestDetectedGroupGapCatchUp(storageKey, gaps.first);
          }
          result = _applyMessageMemoryWindow(
            conversationID,
            result,
            anchorMsgID: memoryWindowAnchorMsgID,
            anchorSeq: memoryWindowAnchorSeq,
            forcePreferLatest: memoryWindowPreferLatest,
            forceWhileReadingHistory: forceMemoryWindowTrimWhileReading,
          );
        }
        if (!isDeleteMsg && previous.isNotEmpty) {
          result = restoreUncorrelatedInFlightOutgoing(
            previous: previous,
            incoming: result,
          );
        }
        return result;
      },
      count: mergedInput.length,
      source: replace ? 'replace' : 'merge',
      conversationType:
          ChatMainThreadPerf.conversationTypeForId(conversationID),
    );
    if (skipEquivalentHistoryWindow) {
      _historyWindowCommitSignatureByConv[storageKey] =
          '$historyCommitSource|${_messageListContentSignature(sorted)}';
    }

    if (replace ||
        isDeleteMsg ||
        previous.isEmpty ||
        sorted.length != previous.length) {
      final prevNewest = previous.isEmpty ? 0 : (previous.first.timestamp ?? 0);
      final nextNewest = sorted.isEmpty ? 0 : (sorted.first.timestamp ?? 0);
      ChatHistoryTrace.log(
        replace ? 'set_list_replace' : 'set_list_merge',
        conversationID: conversationID,
        extras: <String, Object?>{
          'isDeleteMsg': isDeleteMsg,
          'prevCount': previous.length,
          'nextCount': sorted.length,
          'inputCount': messageList.length,
          'applyMemoryWindow': applyMemoryWindow,
          'memoryWindowPreferLatest': memoryWindowPreferLatest,
          'memorySuppressed': isMemoryWindowSuppressed(conversationID),
          'position': getMessageListPosition(conversationID).name,
          'prevNewestTs': prevNewest,
          'nextNewestTs': nextNewest,
          'windowWentOlder':
              prevNewest > 0 && nextNewest > 0 && nextNewest < prevNewest,
          ...ChatHistoryTrace.windowSummary(previous, prefix: 'prev'),
          ...ChatHistoryTrace.windowSummary(sorted, prefix: 'next'),
        },
      );
      if (OutgoingVisibleProbe.matches(conversationID) ||
          OutgoingVisibleProbe.matches(storageKey)) {
        OutgoingVisibleProbe.log(
          'set_list_committed',
          conversationID: storageKey,
          extras: <String, Object?>{
            'replace': replace,
            'isDeleteMsg': isDeleteMsg,
            'prevCount': previous.length,
            'nextCount': sorted.length,
            'inputCount': messageList.length,
            'prevTracked':
                OutgoingVisibleProbe.trackedInList(previous).toString(),
            'nextTracked':
                OutgoingVisibleProbe.trackedInList(sorted).toString(),
          },
        );
      }
      if (replace && sorted.length < previous.length) {
        ChatJitterDiag.log(
          'history_list_shrink',
          conv: conversationID,
          extras: <String, Object?>{
            'prevCount': previous.length,
            'nextCount': sorted.length,
            'inputCount': messageList.length,
            'lost': previous.length - sorted.length,
            'applyMemoryWindow': applyMemoryWindow,
            'memorySuppressed': isMemoryWindowSuppressed(conversationID),
            'position': getMessageListPosition(conversationID).name,
          },
        );
      }
    }
    final normalizedConvId = _inboundStateKey(conversationID);
    final unreadState = _inboundUnreadStateFor(normalizedConvId, create: false);
    final holdUntilUserBottom =
        _deferredUntilUserBottomConversations.contains(normalizedConvId);
    var projectionChanged = false;
    if (replace) {
      // 会话预览同源首屏 / 分页全量写回：必须露出完整窗口。
      // 否则上一轮 inbound hide（群聊未读缓充）会把窗口内消息滤掉，出现空洞。
      projectionChanged =
          _revealAllDeferredProjectionAcrossAliases(conversationID);
      final authoritativePrefix = '$normalizedConvId|';
      _authoritativeDeferredIncomingKeys.removeWhere(
        (key) => key.startsWith(authoritativePrefix),
      );
    } else if (holdUntilUserBottom &&
        unreadState.bufferedMessageKeys.isNotEmpty) {
      final authoritativeDeferred = sorted
          .where(
            (message) => unreadState.bufferedMessageKeys.contains(
              messageDedupKey(message),
            ),
          )
          .toList(growable: false);
      if (authoritativeDeferred.isNotEmpty) {
        projectionChanged = true;
        _hideInboundProjection(conversationID, authoritativeDeferred);
        for (final message in authoritativeDeferred) {
          _authoritativeDeferredIncomingKeys.add(
            _authoritativeDeferredKey(conversationID, message),
          );
        }
      }
    }
    // 先算内容签名：进页 hydrate / peek 原样回写时必须跳过 bump+notify，
    // 否则短会话一次打开会固定多轮 list_rebuild（日志里 spacer 晚到也叠在这上面）。
    var signature = _messageListContentSignature(sorted);
    var signatureChanged =
        _messageListContentSignatureByConv[storageKey] != signature;
    final structureChanged = _messageCommitStructureChanged(previous, sorted);
    if (!signatureChanged && !isDeleteMsg) {
      if (_listHasCorrelatingDup(sorted)) {
        signatureChanged = true;
      } else {
        ChatMainThreadPerf.increment('message_list_noop_commit');
        // 列表语义未变：仍补种行高供短历史估 spacer，但不掀翻 UI。
        if (OutgoingVisibleProbe.matches(conversationID) ||
            OutgoingVisibleProbe.matches(storageKey)) {
          OutgoingVisibleProbe.log(
            'set_list_signature_unchanged',
            conversationID: storageKey,
            extras: <String, Object?>{
              'replace': replace,
              'count': sorted.length,
              ...OutgoingVisibleProbe.trackedInList(sorted),
            },
          );
        }
        ChatMessageHeightCache.instance.seedEstimatesForMessages(sorted);
        _messageListContentSignatureByConv[storageKey] = signature;
        _messageListMap[storageKey] = sorted;
        _collapseHistoryAliasesToCanonical(
          conversationID,
          canonical: storageKey,
        );
        if (needResetNewMessageCount && !holdUntilUserBottom) {
          unreadState.receivedCount = 0;
        }
        // 签名未变但投影显隐变了：仍需通知，否则缓充消息会一直藏着。
        if (projectionChanged) {
          _markNeedsNotify();
        }
        return _messageCommitSnapshot(
          conversationID: conversationID,
          storageKey: storageKey,
          list: sorted,
          structureChanged: structureChanged,
          contentChanged: false,
          recordCommit: true,
          writerCommit: writerCommit,
        );
      }
    }

    _messageListMap[storageKey] = sorted;
    _collapseHistoryAliasesToCanonical(
      conversationID,
      canonical: storageKey,
    );
    // 首屏 / 增量写入时补种缺省行高，避免冷进页 short-history 全靠常量估算。
    ChatMessageHeightCache.instance.seedEstimatesForMessages(sorted);
    _messageListContentSignatureByConv[storageKey] = signature;
    final commitStage = _messageCommitCoordinator.stage(
      MessageMutation(
        conversationID: storageKey,
        type: _messageMutationTypeForCommit(
          replace: replace,
          isDeleteMsg: isDeleteMsg,
          structureChanged: structureChanged,
        ),
        generation: (_messageCommitGenerationByConv[storageKey] ?? 0) + 1,
        source: historyCommitSource,
        expectedFirstIdentity:
            sorted.isEmpty ? null : _commitSnapshotIdentity(sorted.first),
        expectedLastIdentity:
            sorted.isEmpty ? null : _commitSnapshotIdentity(sorted.last),
      ),
    );
    ChatMainThreadPerf.increment('message_list_structural_commit');
    if (commitStage.shouldAdvanceListRevision) {
      _bumpMessageListRevisionFor(
        storageKey,
        reason:
            isDeleteMsg ? 'setMessageList_delete' : 'setMessageList_signature',
      );
    }
    // bump 对 setMessageList_* 不再清签名；此处再写一次以防旧调用路径。
    _messageListContentSignatureByConv[storageKey] = signature;
    if (needResetNewMessageCount && !holdUntilUserBottom) {
      unreadState.receivedCount = 0;
    }

    if (isDeleteMsg) {
      final retainedKeys = sorted.map(messageDedupKey).toSet();
      final removedKeys = previous
          .map(messageDedupKey)
          .where((key) => !retainedKeys.contains(key))
          .toSet();
      if (removedKeys.isNotEmpty) {
        final projectionKey = _inboundStateKey(conversationID);
        final hidden = _inboundHiddenKeysByConv[projectionKey];
        hidden?.removeWhere(removedKeys.contains);
        if (hidden != null && hidden.isEmpty) {
          _inboundHiddenKeysByConv.remove(projectionKey);
        }
        final authoritativePrefix = '$projectionKey|';
        _authoritativeDeferredIncomingKeys.removeWhere(
          (key) =>
              key.startsWith(authoritativePrefix) &&
              removedKeys.contains(key.substring(authoritativePrefix.length)),
        );
        final state = _inboundUnreadStateFor(conversationID, create: false);
        state.bufferedMessages.removeWhere(
          (message) => removedKeys.contains(messageDedupKey(message)),
        );
        state.bufferedMessageKeys.removeWhere(removedKeys.contains);
        _inboundFastForwardMessageKeys.removeWhere(removedKeys.contains);
        _bumpMessageProjectionRevisionFor(projectionKey);
      }
      HistoryMessagePosition position = getMessageListPosition(conversationID);
      if (position == HistoryMessagePosition.awayTwoScreen) {
        _storeHistoryMessagePosition(
          conversationID,
          HistoryMessagePosition.notShowLatest,
        );
      }
    }

    _markNeedsNotify();
    return _messageCommitSnapshot(
      conversationID: conversationID,
      storageKey: storageKey,
      list: sorted,
      structureChanged: structureChanged,
      contentChanged: true,
      recordCommit: true,
      writerCommit: writerCommit,
    );
  }

  V2TimMessage _cloneMessage(V2TimMessage message) {
    try {
      return V2TimMessage.fromJson(
        Map<String, dynamic>.from(message.toJson()),
      );
    } catch (_) {
      return message;
    }
  }

  int _findMessageIndexForUpdate(
    List<V2TimMessage> messageList,
    String id,
    V2TimMessage sentMessage,
  ) {
    return findReplaceableOutgoingIndex(
      '',
      sentMessage,
      priorTempId: id,
      listOverride: messageList,
    );
  }

  bool _isRowLocalOutgoingMediaReceipt(
    V2TimMessage? previous,
    V2TimMessage replacement,
  ) {
    if (previous == null ||
        previous.isSelf != true ||
        replacement.isSelf != true ||
        previous.elemType != replacement.elemType) {
      return false;
    }
    return const <int>{
      MessageElemType.V2TIM_ELEM_TYPE_IMAGE,
      MessageElemType.V2TIM_ELEM_TYPE_VIDEO,
      MessageElemType.V2TIM_ELEM_TYPE_FILE,
      MessageElemType.V2TIM_ELEM_TYPE_SOUND,
    }.contains(replacement.elemType);
  }

  updateMessage(
      V2TimValueCallback<V2TimMessage> sendMsgRes,
      String convID,
      String id,
      ConvType convType,
      GroupReceiptAllowType? groupType,
      ValueChanged<String>? setInputField) {
    final storageConvID = _resolveMessageListStorageKey(convID);
    List<V2TimMessage> currentHistoryMsgList =
        _messageListMap[storageConvID] ?? _collectAuthoritativeMessages(convID);
    final V2TimMessage sendMsgResData = sendMsgRes.data as V2TimMessage;
    final resolvedMessage = _cloneMessage(sendMsgResData);

    // Always set the correct status based on send result
    if (sendMsgRes.code == 0) {
      resolvedMessage.status = MessageStatus.V2TIM_MSG_STATUS_SEND_SUCC;
      _setUploadProgressSilently(id, 100);
      final resolvedMsgID = resolvedMessage.msgID?.trim();
      if (resolvedMsgID != null && resolvedMsgID.isNotEmpty) {
        _setUploadProgressSilently(resolvedMsgID, 100);
      }
    } else {
      resolvedMessage.status = MessageStatus.V2TIM_MSG_STATUS_SEND_FAIL;
    }
    if (resolvedMessage.id == null || resolvedMessage.id!.isEmpty) {
      resolvedMessage.id = id;
    }
    final targetIndex =
        _findMessageIndexForUpdate(currentHistoryMsgList, id, resolvedMessage);
    final originalRowCount = currentHistoryMsgList.length;
    if (sendMsgRes.code != 0 &&
        resolvedMessage.status == MessageStatus.V2TIM_MSG_STATUS_SEND_FAIL) {
      ErrorMessageConverter.attachSendFailCode(
          resolvedMessage, sendMsgRes.code);
      final msgID = resolvedMessage.msgID;
      if (msgID != null &&
          msgID.isNotEmpty &&
          resolvedMessage.localCustomData != null) {
        _messageService.setLocalCustomData(
            msgID: msgID, localCustomData: resolvedMessage.localCustomData!);
      }
    }
    V2TimMessage? previousForMerge;
    if (targetIndex != -1) {
      currentHistoryMsgList = [...currentHistoryMsgList];
      previousForMerge = currentHistoryMsgList[targetIndex];
      _preserveSoundLocalPath(previousForMerge, resolvedMessage);
      _preserveImageLocalPath(previousForMerge, resolvedMessage);
      _preserveImageDisplaySize(resolvedMessage, id);
      _preserveOutgoingLocalOrderData(previousForMerge, resolvedMessage);
      currentHistoryMsgList[targetIndex] = resolvedMessage;
    } else {
      currentHistoryMsgList = [resolvedMessage, ...currentHistoryMsgList];
    }
    final resolvedId = resolvedMessage.id ?? id;
    final resolvedMsgID = resolvedMessage.msgID;
    if (sendMsgRes.code == 0) {
      final hadFailCode =
          ErrorMessageConverter.getSendFailCode(resolvedMessage) != null;
      ErrorMessageConverter.clearSendFailCode(resolvedMessage);
      if (hadFailCode && resolvedMsgID != null && resolvedMsgID.isNotEmpty) {
        _messageService.setLocalCustomData(
          msgID: resolvedMsgID,
          localCustomData: resolvedMessage.localCustomData ?? '',
        );
      }
      _clearUploadProgressSilently(resolvedId);
      if (resolvedMsgID != null && resolvedMsgID.isNotEmpty) {
        _clearUploadProgressSilently(resolvedMsgID);
      }
      _migrateFileMessageMetadata(id, resolvedMsgID);
      if (resolvedMessage.elemType == MessageElemType.V2TIM_ELEM_TYPE_IMAGE) {
        final layoutSize = _fileMessageSizeMap[id] ??
            ((resolvedMsgID?.isNotEmpty ?? false)
                ? _fileMessageSizeMap[resolvedMsgID!]
                : null);
        if (layoutSize != null &&
            layoutSize.width > 0 &&
            layoutSize.height > 0) {
          applyImageLayoutToMessage(resolvedMessage, layoutSize);
          if (resolvedMsgID != null && resolvedMsgID.isNotEmpty) {
            _messageService.setLocalCustomData(
              msgID: resolvedMsgID,
              localCustomData: resolvedMessage.localCustomData ?? '',
            );
          }
        }
      }
    }
    if (resolvedId.isNotEmpty || (resolvedMsgID?.isNotEmpty ?? false)) {
      currentHistoryMsgList = currentHistoryMsgList.where((element) {
        if (identical(element, resolvedMessage)) {
          return true;
        }
        final sameId = resolvedId.isNotEmpty && element.id == resolvedId;
        final sameMsgID = resolvedMsgID != null &&
            resolvedMsgID.isNotEmpty &&
            element.msgID == resolvedMsgID;
        if (!sameId && !sameMsgID) {
          return true;
        }
        return false;
      }).toList();
    }
    final collapsedDuplicate = currentHistoryMsgList.length < originalRowCount;
    if (loadingMessage[storageConvID] != null &&
        loadingMessage[storageConvID]!.isNotEmpty) {
      loadingMessage[storageConvID]!.removeWhere((element) => element.id == id);
    }
    if (chatConfig.isShowReadingStatus &&
        groupType != GroupReceiptAllowType.community &&
        sendMsgRes.data?.msgID != null) {
      _messageReadReceiptMap[sendMsgRes.data!.msgID!] =
          V2TimMessageReceipt(timestamp: 0, userID: "", readCount: 0);
    }
    _registerSoundLocalPath(resolvedMessage);
    final stableIdentity =
        readOutgoingStableId(previousForMerge)?.trim().isNotEmpty == true
            ? readOutgoingStableId(previousForMerge)!.trim()
            : readOutgoingStableId(resolvedMessage)?.trim().isNotEmpty == true
                ? readOutgoingStableId(resolvedMessage)!.trim()
                : id.trim();
    final adoptionRecord = MessageReconciliationRecord<V2TimMessage>(
      value: resolvedMessage,
      msgID: resolvedMessage.msgID,
      localID: resolvedMessage.id,
      outgoingStableID: stableIdentity,
      seq: resolvedMessage.seq,
    );
    final authoritativeSendCommit = commitMessageDelta(
      MessageDelta<V2TimMessage>(
        conversationKey: storageConvID,
        eventID: 'send_adoption:$stableIdentity:${resolvedMessage.msgID ?? ''}',
        kind: MessageDeltaKind.optimisticAdoption,
        source: MessageDeltaSource.sendPipeline,
        generation: messageDeltaGenerationFor(storageConvID),
        clearEpoch: messageDeltaClearEpochFor(storageConvID),
        upserts: [adoptionRecord],
      ),
    );
    if (authoritativeSendCommit == null) {
      // A queued, stale, or rejected receipt cannot use the old row-local or
      // full-list fallback. History completion or a later valid receipt owns
      // the next formal publication.
      // `send_done_row_local_fallback` is intentionally retired as a formal
      // list path; keep the diagnostic term for compatibility with probes.
      return;
    }
    _chatUiStateStore.bindMessageAlias(
      storageConvID,
      id,
      ChatUiStateStore.messageKeyOf(resolvedMessage),
    );
    // temp id 上已测到的行高迁到正式 msgID，避免 send_done 后失缓存再估高抖动。
    ChatMessageHeightCache.instance.rememberAlias(
      id,
      resolvedMessage.msgID,
    );
    final knownHeight =
        ChatMessageHeightCache.instance.heightFor(resolvedMessage);
    if (knownHeight != null && knownHeight > 0) {
      ChatMessageHeightCache.instance.remember(resolvedMessage, knownHeight);
    }
    _markMessageRowChanged(storageConvID, resolvedMessage, extraKey: id);
    final insertedRow = targetIndex == -1;
    final reordered = !isNewestFirstStorageOrderValid(currentHistoryMsgList);
    final isRowLocalMediaReceipt = targetIndex != -1 &&
        !collapsedDuplicate &&
        stableIdentity.isNotEmpty &&
        _isRowLocalOutgoingMediaReceipt(previousForMerge, resolvedMessage);
    final structuralChange = insertedRow || collapsedDuplicate || reordered;
    if (structuralChange) {
      _bumpMessageListRevisionFor(
        storageConvID,
        reason: insertedRow
            ? 'send_done_insert_sort'
            : collapsedDuplicate
                ? 'send_done_duplicate_collapse'
                : 'send_done_reorder',
      );
    }
    _logOutgoingSendOrder(
      event: 'send_done',
      convID: storageConvID,
      message: resolvedMessage,
      clientId: id,
      mergePath: isRowLocalMediaReceipt
          ? 'row_local_stable_identity'
          : targetIndex != -1
              ? 'update_replace'
              : 'update_insert',
      existingIndex: targetIndex,
      reordered: reordered,
    );
    // 同位回执只由 ChatUiStateStore 通知该行；不发全局 notify，
    // 也不请求贴底，避免用户正在上滑时被拉回底部。
    if (!structuralChange) {
      return;
    }
    // 发送后 350ms suppress 窗口内推迟整表 notify，让 list-push 先播完。
    if (targetIndex != -1 && shouldSuppressOutgoingPinScroll()) {
      Future<void>.delayed(const Duration(milliseconds: 380), () {
        _markNeedsNotify();
      });
    } else {
      _markNeedsNotify();
    }
  }

  bool markOutgoingSendFailedByIdentity({
    required String conversationID,
    String? clientId,
    String? msgID,
    String? localCustomData,
    int? sendFailCode,
    String reason = 'send_failed',
  }) {
    final storageConvID = _resolveMessageListStorageKey(conversationID);
    final cid = clientId?.trim() ?? '';
    final mid = msgID?.trim() ?? '';
    if (storageConvID.isEmpty || (cid.isEmpty && mid.isEmpty)) {
      return false;
    }
    final list = _mergedAliasMessageList(storageConvID);
    if (list.isEmpty) {
      return false;
    }
    final index = list.indexWhere((item) {
      final stable = readOutgoingStableId(item)?.trim() ?? '';
      if (cid.isNotEmpty && (item.id == cid || stable == cid)) {
        return true;
      }
      if (mid.isNotEmpty && (item.msgID == mid || stable == mid)) {
        return true;
      }
      return false;
    });
    if (index < 0) {
      return false;
    }
    final previous = list[index];
    final failed = _cloneMessage(previous);
    failed.status = MessageStatus.V2TIM_MSG_STATUS_SEND_FAIL;
    if (localCustomData != null) {
      failed.localCustomData = localCustomData;
    }
    if (sendFailCode != null) {
      ErrorMessageConverter.attachSendFailCode(failed, sendFailCode);
    }
    final stableIdentity = readOutgoingStableId(previous) ??
        readOutgoingStableId(failed) ??
        (cid.isNotEmpty ? cid : mid);
    final safeReason = reason.trim().isEmpty
        ? 'send_failed'
        : reason.trim().replaceAll(':', '_');
    final commit = commitMessageDelta(
      MessageDelta<V2TimMessage>(
        conversationKey: storageConvID,
        eventID: 'send_fail:$storageConvID:$safeReason:$stableIdentity:$mid',
        kind: MessageDeltaKind.optimisticAdoption,
        source: MessageDeltaSource.sendPipeline,
        generation: messageDeltaGenerationFor(storageConvID),
        clearEpoch: messageDeltaClearEpochFor(storageConvID),
        upserts: <MessageReconciliationRecord<V2TimMessage>>[
          MessageReconciliationRecord<V2TimMessage>(
            value: failed,
            msgID: failed.msgID,
            localID: failed.id,
            outgoingStableID: stableIdentity,
            seq: failed.seq,
          ),
        ],
      ),
    );
    if (commit == null) {
      return false;
    }
    final failedKey = ChatUiStateStore.messageKeyOf(failed);
    for (final alias in <String>{cid, mid, stableIdentity}..remove('')) {
      if (alias != failedKey) {
        _chatUiStateStore.bindMessageAlias(storageConvID, alias, failedKey);
      }
    }
    _markMessageRowChanged(
      storageConvID,
      failed,
      extraKey: cid.isNotEmpty ? cid : mid,
      mutationType: MessageMutationType.statusOrProgress,
    );
    if (_isSameConversationID(storageConvID, currentSelectedConv)) {
      _markNeedsNotify();
    }
    return true;
  }

  /// Marks an optimistic outgoing message as SEND_FAIL when the commit guard
  /// rejected the send (e.g. conversation switched during async media prep).
  /// Finds the message by temporary client [id], updates its status, and
  /// stamps [localCustomData] with guard_dropped so the UI can show a retry.
  void markOutgoingGuardDropped({
    required String conversationID,
    required String clientId,
    String? localCustomData,
  }) {
    markOutgoingSendFailedByIdentity(
      conversationID: conversationID,
      clientId: clientId,
      localCustomData: localCustomData,
      reason: 'guard_dropped',
    );
  }

  void updateAsyncMessage(
    V2TimMessage message,
    String convID,
  ) {
    if (message.id == null || message.id!.isEmpty) {
      message.id =
          message.msgID ?? DateTime.now().millisecondsSinceEpoch.toString();
    }

    final storageKey = _resolveMessageListStorageKey(convID);
    if (storageKey.isEmpty) {
      return;
    }
    final msgID = message.msgID?.trim() ?? '';
    if (msgID.isEmpty) {
      return;
    }
    final current = _mergedAliasMessageList(storageKey);
    final index = current.indexWhere((item) => item.msgID == msgID);
    if (index < 0) {
      return;
    }
    final previous = current[index];
    final resolved = _cloneMessage(message);
    final stableIdentity = readOutgoingStableId(previous) ??
        readOutgoingStableId(resolved) ??
        previous.id ??
        resolved.id ??
        msgID;
    final commit = commitMessageDelta(
      MessageDelta<V2TimMessage>(
        conversationKey: storageKey,
        eventID: 'async_message_edit:$storageKey:$msgID',
        kind: MessageDeltaKind.edit,
        source: MessageDeltaSource.sdkRealtime,
        generation: messageDeltaGenerationFor(storageKey),
        clearEpoch: messageDeltaClearEpochFor(storageKey),
        upserts: <MessageReconciliationRecord<V2TimMessage>>[
          MessageReconciliationRecord<V2TimMessage>(
            value: resolved,
            msgID: resolved.msgID,
            localID: resolved.id,
            outgoingStableID: stableIdentity,
            seq: resolved.seq,
          ),
        ],
      ),
    );
    if (commit == null) {
      return;
    }
    _chatUiStateStore.markMessagesChanged(
      storageKey,
      <String>{
        ChatUiStateStore.messageKeyOf(previous),
        ChatUiStateStore.messageKeyOf(resolved),
        msgID,
      },
    );
    _markMessageRowChanged(storageKey, resolved, extraKey: msgID);
    if (_isSameConversationID(storageKey, currentSelectedConv)) {
      _markNeedsNotify();
    }
  }

  /// 群 dedup 用：与 [_normalizeConversationID] 同规则，但不依赖实例。
  static String _normalizeGroupIdForDedup(String? value) {
    final raw = value?.trim() ?? '';
    if (raw.isEmpty) {
      return '';
    }
    var normalized = raw;
    if (normalized.startsWith('GROUP')) {
      normalized = normalized.substring(5);
    }
    if (normalized.startsWith('group_')) {
      normalized = normalized.substring(6);
    }
    return normalized.trim();
  }

  static String _groupShortTokenForDedup(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) {
      return '';
    }
    final upper = trimmed.toUpperCase();
    // 默认分配：`@TGS#_@TGS#short` → 取内层；自定义：`@TGS#_mc…` → 原样
    if (upper.startsWith('@TGS#_@TGS#')) {
      return trimmed.substring('@TGS#_'.length); // `@TGS#short`
    }
    if (upper.startsWith('@TGS#_')) {
      return trimmed;
    }
    return trimmed;
  }

  static bool _groupIdsEquivalentForDedup(String? left, String? right) {
    final a = _normalizeGroupIdForDedup(left);
    final b = _normalizeGroupIdForDedup(right);
    if (a.isEmpty && b.isEmpty) {
      return true;
    }
    if (a.isEmpty || b.isEmpty) {
      return false;
    }
    if (a == b) {
      return true;
    }
    final shortA = _groupShortTokenForDedup(a);
    final shortB = _groupShortTokenForDedup(b);
    if (shortA.isNotEmpty && shortA == shortB) {
      return true;
    }
    return false;
  }

  /// 群消息：含 groupID、归档 msgKey，或带 archiveHistory 的群归档行（C2C 归档不算）。
  static bool _isGroupLikeMessage(V2TimMessage message) {
    final userID = message.userID?.trim() ?? '';
    if (userID.isNotEmpty) {
      return false;
    }
    final groupID = message.groupID?.trim() ?? '';
    if (groupID.isNotEmpty) {
      return true;
    }
    final msgID = message.msgID?.trim() ?? '';
    if (msgID.contains('@TGS#') && msgID.contains(':')) {
      return true;
    }
    if (HistoryPaginationAnchor.isArchiveHistoryMessage(message)) {
      return true;
    }
    return false;
  }

  /// 从 groupID 或归档 msgKey（@TGS#xxx:seq）解析 canonical 群 token。
  static String _normalizedGroupIdForMessage(V2TimMessage message) {
    final fromGroup = _normalizeGroupIdForDedup(message.groupID);
    if (fromGroup.isNotEmpty) {
      return _groupShortTokenForDedup(fromGroup);
    }
    final msgID = message.msgID?.trim() ?? '';
    if (msgID.isEmpty) {
      return '';
    }
    if (_isLikelyTencentSdkMsgId(msgID)) {
      return '';
    }
    final colon = msgID.lastIndexOf(':');
    if (colon > 0) {
      final prefix = msgID.substring(0, colon);
      final normalized = _normalizeGroupIdForDedup(prefix);
      if (normalized.isNotEmpty) {
        return _groupShortTokenForDedup(normalized);
      }
    }
    return _groupShortTokenForDedup(_normalizeGroupIdForDedup(msgID));
  }

  static int _messageSortSeq(V2TimMessage message) {
    final fromField = int.tryParse(message.seq?.toString() ?? '') ?? 0;
    if (fromField > 0) {
      return fromField;
    }
    final msgID = message.msgID?.trim() ?? '';
    if (msgID.isEmpty) {
      return 0;
    }
    final colon = msgID.lastIndexOf(':');
    if (colon <= 0 || colon + 1 >= msgID.length) {
      return 0;
    }
    final suffix = msgID.substring(colon + 1);
    if (!_isAllAsciiDigits(suffix)) {
      return 0;
    }
    return int.tryParse(suffix) ?? 0;
  }

  /// Whether [message] carries a group-global monotonic [seq] that can be
  /// trusted for chronological ordering.
  ///
  /// Only GROUP messages have a conversation-wide monotonic seq. In C2C (1-to-1)
  /// chats each side numbers its own messages independently, so seq is NOT
  /// comparable across senders and must never drive ordering — timestamps are
  /// the source of truth there.
  static bool _hasGroupSeqOrdering(V2TimMessage message) {
    if (_messageSortSeq(message) <= 0) {
      return false;
    }
    return _isGroupLikeMessage(message);
  }

  /// A self message that is still being sent (no server [seq] yet) and carries
  /// a local outgoing sequence. Such a row is the most recently tapped message
  /// and must sort as the newest on a timestamp tie.
  static bool _isLiveOutgoingPlaceholder(V2TimMessage message) {
    return _messageSortSeq(message) <= 0 &&
        message.isSelf == true &&
        _readOutgoingLocalSeq(message) != null &&
        message.status == MessageStatus.V2TIM_MSG_STATUS_SENDING;
  }

  /// Messages without a server [seq] (local group tips, sending placeholders).
  static bool _usesTimelineLocalOrdering(V2TimMessage message) {
    if (_messageSortSeq(message) > 0) {
      return false;
    }
    final raw = message.localCustomData?.trim() ?? '';
    if (raw.isNotEmpty) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is Map) {
          if (decoded['localGroupTips'] == true) {
            return true;
          }
          if (decoded.containsKey('timelineRank')) {
            return true;
          }
        }
      } catch (_) {}
    }
    return message.isSelf == true &&
        _readOutgoingLocalSeq(message) != null &&
        message.status == MessageStatus.V2TIM_MSG_STATUS_SENDING;
  }

  static int _messageTimelineSortRank(V2TimMessage message) {
    final raw = message.localCustomData?.trim() ?? '';
    if (raw.isEmpty) {
      return 50;
    }
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map) {
        final rank = decoded['timelineRank'];
        if (rank is num) {
          return rank.toInt();
        }
      }
    } catch (_) {}
    return 50;
  }

  static int _messageSortTimestamp(V2TimMessage message) {
    final timestamp = normalizeMessageEpochSeconds(message.timestamp);
    if (timestamp > 0) {
      return timestamp;
    }
    final localSentAt =
        normalizeMessageEpochSeconds(_readOutgoingLocalSentAt(message));
    if (localSentAt > 0) {
      return localSentAt;
    }
    return 0;
  }

  static int compareMessagesChronological(V2TimMessage a, V2TimMessage b) {
    final sa = _messageSortSeq(a);
    final sb = _messageSortSeq(b);
    final aLocalTimeline = _usesTimelineLocalOrdering(a);
    final bLocalTimeline = _usesTimelineLocalOrdering(b);

    // In GROUP chats the server seq is the source of truth: msgID/server
    // timestamps can be non-monotonic while seq stays ordered (see logs). In
    // C2C chats seq is per-sender and NOT chronological, so it must not be used
    // here — fall through to timestamp ordering instead.
    final batchA = readChatMediaBatchId(a);
    final batchB = readChatMediaBatchId(b);
    final batchIndexA = readChatMediaBatchIndex(a);
    final batchIndexB = readChatMediaBatchIndex(b);
    if (batchA != null &&
        batchA == batchB &&
        batchIndexA != null &&
        batchIndexB != null &&
        batchIndexA != batchIndexB) {
      return batchIndexA.compareTo(batchIndexB);
    }

    final aGroupSeq = !aLocalTimeline && _hasGroupSeqOrdering(a);
    final bGroupSeq = !bLocalTimeline && _hasGroupSeqOrdering(b);
    if (aGroupSeq && bGroupSeq) {
      if (sa != sb) {
        return sa.compareTo(sb);
      }
    }

    final ta = _messageSortTimestamp(a);
    final tb = _messageSortTimestamp(b);
    if (ta != tb) {
      return ta.compareTo(tb);
    }
    // Equal timestamps (same-second send): a live SENDING placeholder was just
    // created locally and is therefore newer than any already-resolved message
    // it ties with. Sends are serialized, so any resolved row in the list was
    // dispatched before this placeholder was tapped. Without this, the
    // placeholder (seq=0) loses the seq tie-break below and briefly renders
    // *above* (older than) the previous message, then snaps back once its own
    // server seq arrives — the visible "reorder then recover" flicker.
    final aSendingPlaceholder = _isLiveOutgoingPlaceholder(a);
    final bSendingPlaceholder = _isLiveOutgoingPlaceholder(b);
    if (aSendingPlaceholder != bSendingPlaceholder) {
      return aSendingPlaceholder ? 1 : -1;
    }
    // C2C 同秒（真实 timestamp）：我方先发、对方后回，升序里 self 在前。
    if (ta == tb &&
        ta > 0 &&
        _isC2cLikeMessage(a) &&
        _isC2cLikeMessage(b) &&
        a.isSelf != b.isSelf) {
      if (a.isSelf == true) {
        return -1;
      }
      if (b.isSelf == true) {
        return 1;
      }
    }
    final rankA = _messageTimelineSortRank(a);
    final rankB = _messageTimelineSortRank(b);
    if (rankA != rankB) {
      return rankA.compareTo(rankB);
    }
    if (aGroupSeq && bGroupSeq && sa != sb) {
      return sa.compareTo(sb);
    }
    final la = _readOutgoingLocalSeq(a);
    final lb = _readOutgoingLocalSeq(b);
    if (la != null && lb != null && la != lb) {
      return la.compareTo(lb);
    }
    if (la != null && lb == null) {
      return 1;
    }
    if (la == null && lb != null) {
      return -1;
    }
    final ma = a.msgID ?? a.id ?? '';
    final mb = b.msgID ?? b.id ?? '';
    return ma.compareTo(mb);
  }

  static List<V2TimMessage> sortMessagesChronologicallyAsc(
    List<V2TimMessage> messages,
  ) {
    return List<V2TimMessage>.from(messages)
      ..sort(compareMessagesChronological);
  }

  /// 缓存 _isLikelyTencentSdkMsgId 结果——控制台日志显示历史拉取后
  /// 该函数被调用 160 万次。纯函数 + msgID 不变，适合 LRU 缓存。
  static final LinkedHashMap<String, bool> _likelySdkMsgIdCache =
      LinkedHashMap<String, bool>();
  static const int _likelySdkMsgIdCacheCap = 8192;

  /// 腾讯 SDK / 端上自消息 msgID（数字 TIM id 或 `userId-ts-random`；非归档 `@TGS#:seq`）。
  static bool _isLikelyTencentSdkMsgId(String? msgID) {
    final id = msgID?.trim() ?? '';
    if (id.isEmpty) {
      return false;
    }
    final cached = _likelySdkMsgIdCache[id];
    if (cached != null) {
      RegExpProbe.recordCacheHit('msgId.isLikelySdk');
      _likelySdkMsgIdCache.remove(id);
      _likelySdkMsgIdCache[id] = cached;
      return cached;
    }
    RegExpProbe.recordCacheMiss('msgId.isLikelySdk');
    final result = RegExpProbe.measure('msgId.isLikelySdk', () {
      // These two checks intentionally mirror the old anchored regexes, but
      // avoid invoking the RegExp interpreter for the high-volume identity
      // comparator. The prefix check accepts malformed-but-prefixed SDK IDs
      // exactly as `^\d{6,}-` did.
      if (_hasDigitDashPrefix(id)) {
        return true;
      }
      // 自消息常见：`q14gkm5swv-1785731054-174908238`
      return _matchesUserIdDashShape(id) && !_isArchiveUnderscoreMsgId(id);
    });
    _likelySdkMsgIdCache[id] = result;
    while (_likelySdkMsgIdCache.length > _likelySdkMsgIdCacheCap) {
      _likelySdkMsgIdCache.remove(_likelySdkMsgIdCache.keys.first);
    }
    return result;
  }

  static bool _hasDigitDashPrefix(String id) {
    var index = 0;
    while (index < id.length) {
      final code = id.codeUnitAt(index);
      if (code < 0x30 || code > 0x39) {
        break;
      }
      index++;
    }
    return index >= 6 && index < id.length && id.codeUnitAt(index) == 0x2d;
  }

  /// Fast structural equivalent of `^[A-Za-z0-9_-]+-\d+-\d+$`.
  static bool _matchesUserIdDashShape(String id) {
    final last = id.lastIndexOf('-');
    if (last <= 0 || last == id.length - 1) {
      return false;
    }
    final middle = id.lastIndexOf('-', last - 1);
    if (middle <= 0 || middle == last - 1) {
      return false;
    }
    return _isUserIdWireHead(id.substring(0, middle)) &&
        _isAllAsciiDigits(id.substring(middle + 1, last)) &&
        _isAllAsciiDigits(id.substring(last + 1));
  }

  /// `seq_random_ts` 归档 msgID：`^(\d+)_(\d+)_(\d+)$`（结构匹配，对齐旧 hasMatch）。
  static bool _isArchiveUnderscoreMsgId(String msgID) {
    final last = msgID.lastIndexOf('_');
    if (last <= 0) {
      return false;
    }
    final mid = msgID.lastIndexOf('_', last - 1);
    if (mid <= 0) {
      return false;
    }
    // 恰好两段 `_`，三段均非空数字（含 0），与 RegExp hasMatch 一致。
    if (msgID.indexOf('_') != mid) {
      return false;
    }
    final head = msgID.substring(0, mid);
    final midPart = msgID.substring(mid + 1, last);
    final tail = msgID.substring(last + 1);
    return _isAllAsciiDigits(head) &&
        _isAllAsciiDigits(midPart) &&
        _isAllAsciiDigits(tail);
  }

  static bool _isAllAsciiDigits(String s) {
    if (s.isEmpty) {
      return false;
    }
    for (var i = 0; i < s.length; i++) {
      final c = s.codeUnitAt(i);
      if (c < 0x30 || c > 0x39) {
        return false;
      }
    }
    return true;
  }

  static bool _isUserIdWireHead(String s) {
    if (s.isEmpty) {
      return false;
    }
    for (var i = 0; i < s.length; i++) {
      final c = s.codeUnitAt(i);
      final isDigit = c >= 0x30 && c <= 0x39;
      final isUpper = c >= 0x41 && c <= 0x5a;
      final isLower = c >= 0x61 && c <= 0x7a;
      final isSep = c == 0x5f /* _ */ || c == 0x2d /* - */;
      if (!isDigit && !isUpper && !isLower && !isSep) {
        return false;
      }
    }
    return true;
  }

  /// `^(\d{6,})-(\d+)-(\d+)$` → (ts, random)
  static ({int ts, int random})? _tryParseTimDigitDashWire(String msgID) {
    final last = msgID.lastIndexOf('-');
    if (last <= 0) {
      return null;
    }
    final mid = msgID.lastIndexOf('-', last - 1);
    if (mid <= 0) {
      return null;
    }
    final head = msgID.substring(0, mid);
    final midPart = msgID.substring(mid + 1, last);
    final tail = msgID.substring(last + 1);
    if (head.length < 6 ||
        !_isAllAsciiDigits(head) ||
        !_isAllAsciiDigits(midPart) ||
        !_isAllAsciiDigits(tail)) {
      return null;
    }
    final ts = int.tryParse(midPart) ?? 0;
    final random = int.tryParse(tail) ?? 0;
    if (ts <= 0 || random <= 0) {
      return null;
    }
    return (ts: ts, random: random);
  }

  /// `^([A-Za-z0-9_-]+)-(\d+)-(\d+)$` → (ts, random)
  static ({int ts, int random})? _tryParseUserIdDashWire(String msgID) {
    final last = msgID.lastIndexOf('-');
    if (last <= 0) {
      return null;
    }
    final mid = msgID.lastIndexOf('-', last - 1);
    if (mid <= 0) {
      return null;
    }
    final head = msgID.substring(0, mid);
    final midPart = msgID.substring(mid + 1, last);
    final tail = msgID.substring(last + 1);
    if (!_isUserIdWireHead(head) ||
        !_isAllAsciiDigits(midPart) ||
        !_isAllAsciiDigits(tail)) {
      return null;
    }
    final ts = int.tryParse(midPart) ?? 0;
    final random = int.tryParse(tail) ?? 0;
    if (ts <= 0 || random <= 0) {
      return null;
    }
    return (ts: ts, random: random);
  }

  /// `^(\d+)_(\d+)_(\d+)$` → (random, ts) 与旧 RegExp group2/group3 一致。
  static ({int random, int ts})? _tryParseArchiveUnderscoreWire(String msgID) {
    final last = msgID.lastIndexOf('_');
    if (last <= 0) {
      return null;
    }
    final mid = msgID.lastIndexOf('_', last - 1);
    if (mid <= 0) {
      return null;
    }
    final head = msgID.substring(0, mid);
    final midPart = msgID.substring(mid + 1, last);
    final tail = msgID.substring(last + 1);
    if (!_isAllAsciiDigits(head) ||
        !_isAllAsciiDigits(midPart) ||
        !_isAllAsciiDigits(tail)) {
      return null;
    }
    final random = int.tryParse(midPart) ?? 0;
    final ts = int.tryParse(tail) ?? 0;
    if (random <= 0 || ts <= 0) {
      return null;
    }
    return (random: random, ts: ts);
  }

  /// C2C 跨源稳定身份：sender + timestampSec + random。
  static ({String sender, int timestampSec, int random})? _c2cWireIdentity(
    V2TimMessage message,
  ) {
    if (!_isC2cConversationMessage(message) && !_isC2cLikeMessage(message)) {
      return null;
    }
    final sender = _normalizedC2cAccountId(
      (message.sender?.trim().isNotEmpty ?? false)
          ? message.sender
          : message.userID,
    );
    var ts = message.timestamp ?? 0;
    if (ts > 1000000000000) {
      ts = ts ~/ 1000;
    }
    var random = message.random ?? 0;
    final msgID = message.msgID?.trim() ?? '';
    // 字段已齐时 msgID 解析是纯空转（旧逻辑只在 <=0 时回填）——跳过 Probe/解析。
    if (msgID.isNotEmpty && (ts <= 0 || random <= 0)) {
      RegExpProbe.measure('msgId.c2cWireIdentity', () {
        final sdk =
            _tryParseTimDigitDashWire(msgID) ?? _tryParseUserIdDashWire(msgID);
        if (sdk != null && !_isArchiveUnderscoreMsgId(msgID)) {
          if (ts <= 0 && sdk.ts > 0) {
            ts = sdk.ts;
          }
          if (random <= 0 && sdk.random > 0) {
            random = sdk.random;
          }
        } else {
          final archive = _tryParseArchiveUnderscoreWire(msgID);
          if (archive != null) {
            if (random <= 0 && archive.random > 0) {
              random = archive.random;
            }
            if (ts <= 0 && archive.ts > 0) {
              ts = archive.ts;
            }
          }
        }
      });
    }
    if (sender.isEmpty || ts <= 0 || random <= 0) {
      return null;
    }
    return (sender: sender, timestampSec: ts, random: random);
  }

  @visibleForTesting
  static ({String sender, int timestampSec, int random})?
      parseC2cWireIdentityForTesting(V2TimMessage message) {
    return _c2cWireIdentity(message);
  }

  /// 历史合并后用于幂等判断的身份签名（wire 优先，否则 messageDedupKey）。
  static String historyIdentitySignature(List<V2TimMessage> messages) {
    final keys = <String>[];
    for (final message in messages) {
      final wire = _c2cWireIdentity(message);
      if (wire != null) {
        keys.add('c2cwi:${wire.sender}:${wire.timestampSec}:${wire.random}');
        continue;
      }
      if (_hasGroupSeqOrdering(message)) {
        final seq = _messageSortSeq(message);
        if (seq > 0) {
          keys.add(
            'gseq:${_normalizedGroupIdForMessage(message)}:$seq',
          );
          continue;
        }
      }
      keys.add(messageDedupKey(message));
    }
    keys.sort();
    return keys.join('|');
  }

  @visibleForTesting
  static String historyIdentitySignatureForTesting(
    List<V2TimMessage> messages,
  ) {
    return historyIdentitySignature(messages);
  }

  /// 胜出行吸收对侧本地媒体路径，并在方向分更高时采纳 isSelf。
  static V2TimMessage _finalizePreferredDedupMessage(
    V2TimMessage preferred,
    V2TimMessage other,
  ) {
    _absorbMediaLocalPaths(preferred, other);
    // 归档↔SDK 不同 msgID：把已测行高粘到保留行，避免短历史 spacer 再估高。
    ChatMessageHeightCache.instance.rememberAliasesBetween(preferred, other);
    if (_isC2cConversationMessage(preferred) &&
        _isC2cConversationMessage(other)) {
      final preferredScore = _c2cDirectionConsistencyScore(preferred);
      final otherScore = _c2cDirectionConsistencyScore(other);
      if (otherScore > preferredScore) {
        preferred.isSelf = other.isSelf;
      }
    }
    return preferred;
  }

  static void _absorbMediaLocalPaths(V2TimMessage winner, V2TimMessage donor) {
    if (winner.elemType == MessageElemType.V2TIM_ELEM_TYPE_IMAGE &&
        donor.elemType == MessageElemType.V2TIM_ELEM_TYPE_IMAGE) {
      final donorPath = donor.imageElem?.path?.trim() ?? '';
      final winnerPath = winner.imageElem?.path?.trim() ?? '';
      if (donorPath.isNotEmpty && winnerPath.isEmpty) {
        winner.imageElem ??= donor.imageElem;
        winner.imageElem?.path = donorPath;
      }
    }
    if (winner.elemType == MessageElemType.V2TIM_ELEM_TYPE_SOUND &&
        donor.elemType == MessageElemType.V2TIM_ELEM_TYPE_SOUND) {
      final donorPath =
          donor.soundElem?.path ?? donor.soundElem?.localUrl ?? '';
      if (donorPath.isNotEmpty) {
        winner.soundElem ??= donor.soundElem;
        winner.soundElem?.path = donor.soundElem?.path ?? donorPath;
        winner.soundElem?.localUrl =
            donor.soundElem?.localUrl ?? winner.soundElem?.localUrl;
      }
    }
    if (winner.elemType == MessageElemType.V2TIM_ELEM_TYPE_VIDEO &&
        donor.elemType == MessageElemType.V2TIM_ELEM_TYPE_VIDEO) {
      final donorPath = donor.videoElem?.localVideoUrl?.trim() ??
          donor.videoElem?.videoPath?.trim() ??
          '';
      final winnerPath = winner.videoElem?.localVideoUrl?.trim() ??
          winner.videoElem?.videoPath?.trim() ??
          '';
      if (donorPath.isNotEmpty && winnerPath.isEmpty) {
        winner.videoElem ??= donor.videoElem;
        if ((winner.videoElem?.localVideoUrl?.trim().isEmpty ?? true) &&
            (donor.videoElem?.localVideoUrl?.trim().isNotEmpty ?? false)) {
          winner.videoElem?.localVideoUrl = donor.videoElem?.localVideoUrl;
        }
        if ((winner.videoElem?.videoPath?.trim().isEmpty ?? true) &&
            (donor.videoElem?.videoPath?.trim().isNotEmpty ?? false)) {
          winner.videoElem?.videoPath = donor.videoElem?.videoPath;
        }
      }
    }
    if (winner.elemType == MessageElemType.V2TIM_ELEM_TYPE_FILE &&
        donor.elemType == MessageElemType.V2TIM_ELEM_TYPE_FILE) {
      final donorPath = donor.fileElem?.localUrl?.trim() ??
          donor.fileElem?.path?.trim() ??
          '';
      final winnerPath = winner.fileElem?.localUrl?.trim() ??
          winner.fileElem?.path?.trim() ??
          '';
      if (donorPath.isNotEmpty && winnerPath.isEmpty) {
        winner.fileElem ??= donor.fileElem;
        winner.fileElem?.localUrl =
            donor.fileElem?.localUrl ?? winner.fileElem?.localUrl;
        winner.fileElem?.path = donor.fileElem?.path ?? winner.fileElem?.path;
      }
    }
  }

  static void _applyDedupPreference(
    List<V2TimMessage> result,
    int index,
    V2TimMessage candidate, {
    String? candidateDedupKey,
    Map<String, int>? dedupKeyToResultIndex,
  }) {
    final existing = result[index];
    if (_preferMessageForDedup(candidate, existing)) {
      result[index] = _finalizePreferredDedupMessage(candidate, existing);
      if (candidateDedupKey != null && dedupKeyToResultIndex != null) {
        dedupKeyToResultIndex[candidateDedupKey] = index;
      }
    } else {
      result[index] = _finalizePreferredDedupMessage(existing, candidate);
    }
  }

  /// 同一 dedupKey 冲突时保留哪条（incoming 为 true 则替换 existing）。
  static bool _preferMessageForDedup(
    V2TimMessage incoming,
    V2TimMessage existing,
  ) {
    final incomingArchive =
        HistoryPaginationAnchor.isArchiveHistoryMessage(incoming);
    final existingArchive =
        HistoryPaginationAnchor.isArchiveHistoryMessage(existing);

    // 后端归档历史 SoT：先于「resolved outgoing」判断，避免 SDK isSelf 压过归档。
    if (incomingArchive != existingArchive) {
      final incomingSeq = _messageSortSeq(incoming);
      final existingSeq = _messageSortSeq(existing);
      final sameGroupSeq = !_isC2cConversationMessage(incoming) &&
          !_isC2cConversationMessage(existing) &&
          incomingSeq > 0 &&
          incomingSeq == existingSeq;
      final c2cPair = _isC2cConversationMessage(incoming) &&
          _isC2cConversationMessage(existing);
      if (sameGroupSeq ||
          c2cPair ||
          messagesCorrelateForDedup(incoming, existing)) {
        return incomingArchive;
      }
    }

    final existingResolved = _isResolvedOutgoingMessage(existing);
    final incomingResolved = _isResolvedOutgoingMessage(incoming);
    if (incomingResolved && !existingResolved) {
      return true;
    }
    if (!incomingResolved && existingResolved) {
      return false;
    }

    // 群历史（含 Web SDK 缺 groupID）：同 seq 时后端归档优先。
    final incomingSeqEarly = _messageSortSeq(incoming);
    final existingSeqEarly = _messageSortSeq(existing);
    if (!_isC2cConversationMessage(incoming) &&
        !_isC2cConversationMessage(existing) &&
        incomingSeqEarly > 0 &&
        incomingSeqEarly == existingSeqEarly) {
      if (incomingArchive && !existingArchive) {
        return true;
      }
      if (!incomingArchive && existingArchive) {
        return false;
      }
    }

    // 群消息：后端归档历史优先于 SDK 漫游副本。
    if (_isGroupLikeMessage(incoming) &&
        _isGroupLikeMessage(existing) &&
        _messageSortSeq(incoming) > 0 &&
        _messageSortSeq(incoming) == _messageSortSeq(existing)) {
      if (incomingArchive && !existingArchive) {
        return true;
      }
      if (!incomingArchive && existingArchive) {
        return false;
      }
    }

    // C2C：后端归档历史为 SoT；SDK 仅覆盖 client echo。
    if (_isC2cConversationMessage(incoming) &&
        _isC2cConversationMessage(existing)) {
      final incomingSdk = _isLikelyTencentSdkMsgId(incoming.msgID);
      final existingSdk = _isLikelyTencentSdkMsgId(existing.msgID);
      if (incomingArchive && existingSdk) {
        return true;
      }
      if (incomingSdk && existingArchive) {
        return false;
      }
      if (incomingArchive && !existingArchive) {
        return true;
      }
      if (!incomingArchive && existingArchive) {
        return false;
      }
      if (incomingSdk && _isC2cClientEchoMessage(existing)) {
        return true;
      }
      if (_isC2cClientEchoMessage(incoming) && existingSdk) {
        return false;
      }
      final incomingScore = _c2cDirectionConsistencyScore(incoming);
      final existingScore = _c2cDirectionConsistencyScore(existing);
      if (incomingScore != existingScore) {
        return incomingScore > existingScore;
      }
    }

    return false;
  }

  static bool _isC2cConversationMessage(V2TimMessage message) {
    return _isC2cLikeMessage(message) &&
        (message.userID?.trim().isNotEmpty ?? false);
  }

  /// 无 C2C userID 即非单聊；群消息也有 sender，不能凭 sender 判 C2C。
  static bool _isC2cLikeMessage(V2TimMessage message) {
    if (_isGroupLikeMessage(message)) {
      return false;
    }
    return message.userID?.trim().isNotEmpty ?? false;
  }

  static bool _isC2cClientEchoMessage(V2TimMessage message) {
    if (_isLikelyTencentSdkMsgId(message.msgID)) {
      return false;
    }
    final id = message.id?.trim() ?? '';
    return id.isNotEmpty;
  }

  /// 同秒同内容：TIM SDK 副本 vs 会话预览/client id echo（userID 可能不一致）。
  static bool _c2cPreviewEchoCorrelate(V2TimMessage a, V2TimMessage b) {
    if (!_isC2cLikeMessage(a) || !_isC2cLikeMessage(b)) {
      return false;
    }
    final tsA = a.timestamp ?? 0;
    final tsB = b.timestamp ?? 0;
    if (tsA <= 0 || tsA != tsB) {
      return false;
    }
    final fpA = _messageContentFingerprint(a);
    final fpB = _messageContentFingerprint(b);
    if (fpA == null || fpB == null || fpA != fpB) {
      return false;
    }
    final aSdk = _isLikelyTencentSdkMsgId(a.msgID);
    final bSdk = _isLikelyTencentSdkMsgId(b.msgID);
    if (aSdk && bSdk) {
      final aMsgID = a.msgID!.trim();
      final bMsgID = b.msgID!.trim();
      return aMsgID == bMsgID;
    }
    if (aSdk || bSdk) {
      return true;
    }
    if (a.isSelf != b.isSelf) {
      return true;
    }
    return _isC2cClientEchoMessage(a) || _isC2cClientEchoMessage(b);
  }

  /// C2C 账号归一化（去 c2c_ 前缀、@ 后缀），与 app 侧 ChatIdFormat 语义对齐。
  static String _normalizedC2cAccountId(String? raw) {
    var id = raw?.trim() ?? '';
    if (id.isEmpty) {
      return '';
    }
    if (id.startsWith('c2c_')) {
      id = id.substring(4);
    }
    final at = id.indexOf('@');
    if (at > 0) {
      id = id.substring(0, at);
    }
    return id.toLowerCase();
  }

  /// sender 与 peer/userID 方向一致时得分更高（3=一致，1=镜像 dup）。
  static int _c2cDirectionConsistencyScore(V2TimMessage message) {
    if (!_isC2cConversationMessage(message)) {
      return 0;
    }
    final peer = _normalizedC2cAccountId(message.userID);
    final sender = _normalizedC2cAccountId(message.sender);
    if (peer.isEmpty || sender.isEmpty) {
      return 0;
    }
    final fromPeer = peer == sender;
    final isSelf = message.isSelf == true;
    if (fromPeer && !isSelf) {
      return 3;
    }
    if (!fromPeer && isSelf) {
      return 3;
    }
    return 1;
  }

  /// C2C 镜像 dup：sender 为 peer 却被标成 isSelf（Web 漫游常见）。
  static bool _isC2cMirrorMislabeledSelf(V2TimMessage message) {
    return message.isSelf == true &&
        _isC2cConversationMessage(message) &&
        _c2cDirectionConsistencyScore(message) < 3;
  }

  V2TimMessage _normalizeInboundC2cDirection(V2TimMessage message) {
    if (!_isC2cMirrorMislabeledSelf(message)) {
      return message;
    }
    final fixed = _cloneMessage(message);
    fixed.isSelf = false;
    return fixed;
  }

  static bool _resolveMergedIsSelf(V2TimMessage a, V2TimMessage b) {
    final scoreA = _c2cDirectionConsistencyScore(a);
    final scoreB = _c2cDirectionConsistencyScore(b);
    if (scoreA > scoreB) {
      return a.isSelf == true;
    }
    if (scoreB > scoreA) {
      return b.isSelf == true;
    }
    final peer = _normalizedC2cAccountId(a.userID ?? b.userID);
    if (peer.isNotEmpty) {
      final senderA = _normalizedC2cAccountId(a.sender);
      final senderB = _normalizedC2cAccountId(b.sender);
      if (senderA == peer && senderB == peer) {
        // 双方 sender 均为 peer：真实方向是 incoming（左收）。
        return false;
      }
      if (senderA == peer && senderB != peer) {
        return a.isSelf == true;
      }
      if (senderB == peer && senderA != peer) {
        return b.isSelf == true;
      }
    }
    return a.isSelf == true && b.isSelf == true;
  }

  static String? _messageContentFingerprint(V2TimMessage message) {
    final text = message.textElem?.text?.trim();
    if (text != null && text.isNotEmpty) {
      return text;
    }
    return null;
  }

  /// C2C 跨源去重键：优先 wire identity（ts+random）；无 random 时降级文本指纹。
  static String? _c2cCrossSourceDedupKey(V2TimMessage message) {
    if (!_isC2cConversationMessage(message)) {
      return null;
    }
    final wire = _c2cWireIdentity(message);
    if (wire != null) {
      return 'c2cwi:${wire.sender}:${wire.timestampSec}:${wire.random}';
    }
    final userID = _normalizedC2cAccountId(message.userID);
    final ts = message.timestamp ?? 0;
    if (userID.isEmpty || ts <= 0) {
      return null;
    }
    final fingerprint = _messageContentFingerprint(message);
    if (fingerprint == null || fingerprint.isEmpty) {
      return null;
    }
    return 'c2cx:$userID:$ts:${message.elemType}:$fingerprint';
  }

  static bool _c2cCrossSourceCorrelate(V2TimMessage a, V2TimMessage b) {
    final keyA = _c2cCrossSourceDedupKey(a);
    final keyB = _c2cCrossSourceDedupKey(b);
    if (keyA == null || keyB == null || keyA != keyB) {
      return false;
    }
    // wire identity 已对齐：任意来源组合均视为同一条。
    if (keyA.startsWith('c2cwi:')) {
      return true;
    }
    final aArchive = HistoryPaginationAnchor.isArchiveHistoryMessage(a);
    final bArchive = HistoryPaginationAnchor.isArchiveHistoryMessage(b);
    final aSdk = _isLikelyTencentSdkMsgId(a.msgID);
    final bSdk = _isLikelyTencentSdkMsgId(b.msgID);
    if ((aArchive && bSdk) || (bArchive && aSdk)) {
      return true;
    }
    // 同会话同内容 isSelf 镜像（左收右发）：归档/TIM 或双 SDK echo。
    if (a.isSelf != b.isSelf) {
      return true;
    }
    return false;
  }

  /// 群聊 archive↔SDK 跨源：同 seq 视为同一条（Web SDK 常缺 groupID/@TGS#）。
  static String? _groupCrossSourceDedupKey(V2TimMessage message) {
    if (!_isGroupLikeMessage(message) &&
        !HistoryPaginationAnchor.isArchiveHistoryMessage(message)) {
      return null;
    }
    final seq = _messageSortSeq(message);
    if (seq <= 0) {
      return null;
    }
    if (_isLikelyTencentSdkMsgId(message.msgID) &&
        !_isGroupLikeMessage(message)) {
      // Web SDK 群消息偶发缺 groupID：用 seq-only 键与归档侧配对。
      return 'gseqx:*:$seq';
    }
    final token = _normalizedGroupIdForMessage(message);
    return 'gseqx:${token.isEmpty ? '*' : token}:$seq';
  }

  static bool _groupCrossSourceCorrelate(V2TimMessage a, V2TimMessage b) {
    if (_isC2cConversationMessage(a) || _isC2cConversationMessage(b)) {
      return false;
    }
    final seqA = _messageSortSeq(a);
    final seqB = _messageSortSeq(b);
    if (seqA <= 0 || seqB <= 0 || seqA != seqB) {
      return false;
    }
    final aArchive = HistoryPaginationAnchor.isArchiveHistoryMessage(a);
    final bArchive = HistoryPaginationAnchor.isArchiveHistoryMessage(b);
    final aSdk = _isLikelyTencentSdkMsgId(a.msgID);
    final bSdk = _isLikelyTencentSdkMsgId(b.msgID);
    if ((aArchive && bSdk) || (bArchive && aSdk)) {
      return true;
    }
    return false;
  }

  static String messageDedupKey(V2TimMessage message) {
    // Seq proves group ordering and gap continuity, not exact identity. Keep
    // different server msgIDs distinct; archive↔SDK copies are correlated by
    // the explicit cross-source rule above.
    if (_hasGroupSeqOrdering(message)) {
      final groupToken = _normalizedGroupIdForMessage(message);
      final seq = _messageSortSeq(message);
      final msgID = message.msgID?.trim() ?? '';
      if (msgID.isNotEmpty) {
        return 'gmsg:$groupToken:$seq:$msgID';
      }
      return 'gseq:$groupToken:$seq';
    }
    final msgID = message.msgID?.trim();
    if (msgID != null && msgID.isNotEmpty) {
      return 'msg:$msgID';
    }
    final id = message.id?.trim();
    if (id != null && id.isNotEmpty) {
      return 'id:$id';
    }
    return [
      message.sender ?? message.userID ?? '',
      message.timestamp ?? '',
      message.seq ?? '',
      message.elemType,
      message.random,
    ].join('|');
  }

  static List<V2TimMessage> dedupeMessages(List<V2TimMessage> messages) {
    if (messages.isEmpty) {
      return const <V2TimMessage>[];
    }
    final dedupKeyToResultIndex = <String, int>{};
    final correlationToResultIndex = <String, int>{};
    final crossSourceToResultIndex = <String, int>{};
    final groupCrossSourceToResultIndex = <String, int>{};
    final result = <V2TimMessage>[];
    for (final message in messages) {
      final key = messageDedupKey(message);
      final corr = _outgoingCorrelationKey(message);
      if (corr != null) {
        final existingIdx = correlationToResultIndex[corr];
        if (existingIdx != null &&
            !_areDistinctSdkIdentities(result[existingIdx], message) &&
            !_areDistinctGroupServerIdentities(
              result[existingIdx],
              message,
            ) &&
            !_areDistinctGroupSequences(result[existingIdx], message)) {
          _applyDedupPreference(
            result,
            existingIdx,
            message,
            candidateDedupKey: key,
            dedupKeyToResultIndex: dedupKeyToResultIndex,
          );
          continue;
        }
      }
      final groupCrossKey = _groupCrossSourceDedupKey(message);
      var groupCrossMatched = false;
      if (groupCrossKey != null) {
        final existingIdx = groupCrossSourceToResultIndex[groupCrossKey];
        if (existingIdx != null) {
          final existing = result[existingIdx];
          if (_groupCrossSourceCorrelate(message, existing)) {
            _applyDedupPreference(
              result,
              existingIdx,
              message,
              candidateDedupKey: key,
              dedupKeyToResultIndex: dedupKeyToResultIndex,
            );
            groupCrossMatched = true;
          }
        }
        if (!groupCrossMatched && groupCrossKey.contains(':*:')) {
          final seqSuffix =
              groupCrossKey.substring(groupCrossKey.lastIndexOf(':'));
          for (var i = 0; i < result.length; i++) {
            final existingKey = _groupCrossSourceDedupKey(result[i]);
            if (existingKey == null || !existingKey.endsWith(seqSuffix)) {
              continue;
            }
            if (_groupCrossSourceCorrelate(message, result[i])) {
              _applyDedupPreference(
                result,
                i,
                message,
                candidateDedupKey: key,
                dedupKeyToResultIndex: dedupKeyToResultIndex,
              );
              groupCrossSourceToResultIndex[groupCrossKey] = i;
              if (existingKey != groupCrossKey) {
                groupCrossSourceToResultIndex[existingKey] = i;
              }
              groupCrossMatched = true;
              break;
            }
          }
        }
        if (groupCrossMatched) {
          continue;
        }
      }
      final crossKey = _c2cCrossSourceDedupKey(message);
      if (crossKey != null) {
        final existingIdx = crossSourceToResultIndex[crossKey];
        if (existingIdx != null) {
          final existing = result[existingIdx];
          if (!_areDistinctSdkIdentities(existing, message) &&
              _c2cCrossSourceCorrelate(message, existing)) {
            _applyDedupPreference(
              result,
              existingIdx,
              message,
              candidateDedupKey: key,
              dedupKeyToResultIndex: dedupKeyToResultIndex,
            );
            continue;
          }
        }
      }
      var correlateIdx = -1;
      for (var i = 0; i < result.length; i++) {
        if (messagesCorrelateForDedup(message, result[i])) {
          correlateIdx = i;
          break;
        }
      }
      if (correlateIdx >= 0) {
        _applyDedupPreference(
          result,
          correlateIdx,
          message,
          candidateDedupKey: key,
          dedupKeyToResultIndex: dedupKeyToResultIndex,
        );
        if (corr != null) {
          correlationToResultIndex[corr] = correlateIdx;
        }
        if (crossKey != null) {
          crossSourceToResultIndex[crossKey] = correlateIdx;
        }
        if (groupCrossKey != null) {
          groupCrossSourceToResultIndex[groupCrossKey] = correlateIdx;
        }
        continue;
      }
      final existingIdx = dedupKeyToResultIndex[key];
      if (existingIdx != null) {
        _applyDedupPreference(
          result,
          existingIdx,
          message,
          candidateDedupKey: key,
          dedupKeyToResultIndex: dedupKeyToResultIndex,
        );
        if (corr != null) {
          correlationToResultIndex[corr] = existingIdx;
        }
        continue;
      }
      final resultIndex = result.length;
      result.add(message);
      dedupKeyToResultIndex[key] = resultIndex;
      if (corr != null) {
        correlationToResultIndex[corr] = resultIndex;
      }
      if (crossKey != null) {
        crossSourceToResultIndex[crossKey] = resultIndex;
      }
      if (groupCrossKey != null) {
        groupCrossSourceToResultIndex[groupCrossKey] = resultIndex;
      }
    }
    return result;
  }

  @visibleForTesting
  static List<V2TimMessage> dedupeMessagesForTesting(
    List<V2TimMessage> messages,
  ) {
    return dedupeMessages(messages);
  }

  static bool _groupPreviewStubCorrelate(V2TimMessage a, V2TimMessage b) {
    if (_isC2cConversationMessage(a) || _isC2cConversationMessage(b)) {
      return false;
    }
    // preview stub 常缺 textElem（指纹为 null）。若不校验 elemType，
    // 同秒「已发出文字」会与「图片 stub/SDK 头」误并，本地气泡从文字变成图片。
    if (a.elemType != b.elemType) {
      return false;
    }
    final tsA = a.timestamp ?? 0;
    final tsB = b.timestamp ?? 0;
    if (tsA <= 0 || tsA != tsB) {
      return false;
    }
    final seqA = _messageSortSeq(a);
    final seqB = _messageSortSeq(b);
    if (seqA > 0 && seqB > 0 && seqA != seqB) {
      return false;
    }
    final randA = _outgoingRandomValue(a);
    final randB = _outgoingRandomValue(b);
    if (randA != null && randB != null && randA != randB) {
      return false;
    }
    if (_isClientPlaceholderMessage(a) && _isClientPlaceholderMessage(b)) {
      final idA = a.id?.trim() ?? '';
      final idB = b.id?.trim() ?? '';
      if (idA.isNotEmpty && idB.isNotEmpty && idA != idB) {
        return false;
      }
    }
    final aSdk = _isLikelyTencentSdkMsgId(a.msgID);
    final bSdk = _isLikelyTencentSdkMsgId(b.msgID);
    final aStub = seqA <= 0 || !aSdk;
    final bStub = seqB <= 0 || !bSdk;
    if (!aStub && !bStub) {
      return false;
    }
    final senderA = a.sender?.trim() ?? '';
    final senderB = b.sender?.trim() ?? '';
    if (senderA.isNotEmpty && senderB.isNotEmpty && senderA != senderB) {
      return false;
    }
    final fpA = _messageContentFingerprint(a);
    final fpB = _messageContentFingerprint(b);
    if (aStub && bStub) {
      // 双 stub 必须内容指纹一致，避免同秒不同消息误并。
      if (fpA == null || fpB == null || fpA != fpB) {
        return false;
      }
      return true;
    }
    // SDK 头 + 会话 preview stub：允许 preview 缺 textElem。
    if (fpA != null && fpB != null && fpA != fpB) {
      return false;
    }
    return true;
  }

  static bool _sameSelfNonC2cEchoCorrelate(V2TimMessage a, V2TimMessage b) {
    if (a.isSelf != true || b.isSelf != true) {
      return false;
    }
    if (_isC2cConversationMessage(a) || _isC2cConversationMessage(b)) {
      return false;
    }
    if (a.elemType != b.elemType) {
      return false;
    }
    final tsA = a.timestamp ?? 0;
    final tsB = b.timestamp ?? 0;
    if (tsA <= 0 || tsA != tsB) {
      return false;
    }
    final seqA = _messageSortSeq(a);
    final seqB = _messageSortSeq(b);
    // 连发相同文案会共享同一秒 timestamp；seq 不同就是不同消息，不能当 echo 合并。
    if (seqA > 0 && seqB > 0 && seqA != seqB) {
      return false;
    }
    final randA = _outgoingRandomValue(a);
    final randB = _outgoingRandomValue(b);
    if (randA != null && randB != null && randA != randB) {
      return false;
    }
    if (_isClientPlaceholderMessage(a) && _isClientPlaceholderMessage(b)) {
      final idA = a.id?.trim() ?? '';
      final idB = b.id?.trim() ?? '';
      if (idA.isNotEmpty && idB.isNotEmpty && idA != idB) {
        return false;
      }
    }
    final fpA = _messageContentFingerprint(a);
    final fpB = _messageContentFingerprint(b);
    if (fpA == null || fpB == null || fpA != fpB) {
      return false;
    }
    final senderA = a.sender?.trim() ?? '';
    final senderB = b.sender?.trim() ?? '';
    if (senderA.isNotEmpty && senderB.isNotEmpty && senderA != senderB) {
      return false;
    }
    return true;
  }

  /// C2C 两条都已是腾讯 SDK msgID 且不相同：就是两条云端消息，禁止再按
  /// random / 文案 / 同秒指纹并掉（连发 `1`/`2`/`3` 会误并整页）。
  /// 群聊不走这条：同 seq 的 SDK/归档副本 msgID 本来就不同。
  static bool _areDistinctSdkIdentities(V2TimMessage a, V2TimMessage b) {
    if (!_isC2cLikeMessage(a) || !_isC2cLikeMessage(b)) {
      return false;
    }
    final aId = a.msgID?.trim() ?? '';
    final bId = b.msgID?.trim() ?? '';
    if (!_isLikelyTencentSdkMsgId(aId) || !_isLikelyTencentSdkMsgId(bId)) {
      return false;
    }
    return aId != bId;
  }

  /// 群聊的正数 seq 是服务端会话内的唯一顺序标识。只要两条消息属于同一群且
  /// seq 不同，就一定是两条不同消息，不能再按同秒、相同发送者或相同内容合并。
  static bool _areDistinctGroupSequences(V2TimMessage a, V2TimMessage b) {
    if (!_isGroupLikeMessage(a) || !_isGroupLikeMessage(b)) {
      return false;
    }
    final seqA = _messageSortSeq(a);
    final seqB = _messageSortSeq(b);
    if (seqA <= 0 || seqB <= 0 || seqA == seqB) {
      return false;
    }
    final groupA = _normalizedGroupIdForMessage(a);
    final groupB = _normalizedGroupIdForMessage(b);
    return groupA.isNotEmpty &&
        groupB.isNotEmpty &&
        _groupIdsEquivalentForDedup(groupA, groupB);
  }

  static bool _groupSeqScopesCompatible(V2TimMessage a, V2TimMessage b) {
    final groupA = _normalizedGroupIdForMessage(a);
    final groupB = _normalizedGroupIdForMessage(b);
    if (groupA.isEmpty || groupB.isEmpty) {
      return true;
    }
    return _groupIdsEquivalentForDedup(groupA, groupB);
  }

  /// Same Seq is a protocol conflict when both group rows carry different
  /// server identities. Preserve both so diagnostics and later authority can
  /// resolve it. The one allowed exception is a proven archive↔SDK copy.
  static bool _areDistinctGroupServerIdentities(
    V2TimMessage a,
    V2TimMessage b,
  ) {
    if (_isC2cConversationMessage(a) || _isC2cConversationMessage(b)) {
      return false;
    }
    final seqA = _messageSortSeq(a);
    final seqB = _messageSortSeq(b);
    if (seqA <= 0 || seqA != seqB) return false;
    final msgIDA = a.msgID?.trim() ?? '';
    final msgIDB = b.msgID?.trim() ?? '';
    if (msgIDA.isEmpty || msgIDB.isEmpty || msgIDA == msgIDB) return false;
    final aArchive = HistoryPaginationAnchor.isArchiveHistoryMessage(a);
    final bArchive = HistoryPaginationAnchor.isArchiveHistoryMessage(b);
    final aSdk = _isLikelyTencentSdkMsgId(msgIDA);
    final bSdk = _isLikelyTencentSdkMsgId(msgIDB);
    if ((aArchive && bSdk) || (bArchive && aSdk)) {
      return false;
    }
    if (!_groupSeqScopesCompatible(a, b)) {
      return true;
    }
    if (a.elemType == b.elemType && aSdk && bSdk) {
      return false;
    }
    final fpA = _messageContentFingerprint(a);
    final fpB = _messageContentFingerprint(b);
    if (a.elemType == b.elemType && fpA != null && fpA == fpB) {
      return false;
    }
    return true;
  }

  static bool messagesCorrelateForDedup(V2TimMessage a, V2TimMessage b) {
    if (_areDistinctSdkIdentities(a, b) ||
        _areDistinctGroupSequences(a, b) ||
        _areDistinctGroupServerIdentities(a, b)) {
      return false;
    }
    final seqA = _messageSortSeq(a);
    final seqB = _messageSortSeq(b);
    if (seqA > 0 &&
        seqA == seqB &&
        !_isC2cConversationMessage(a) &&
        !_isC2cConversationMessage(b) &&
        _groupSeqScopesCompatible(a, b)) {
      if (a.elemType == b.elemType &&
          (_isGroupLikeMessage(a) ||
              _isGroupLikeMessage(b) ||
              (a.isSelf == true && b.isSelf == true))) {
        return true;
      }
    }
    if (_hasGroupSeqOrdering(a) &&
        _hasGroupSeqOrdering(b) &&
        a.elemType == b.elemType &&
        _groupIdsEquivalentForDedup(
          _normalizedGroupIdForMessage(a),
          _normalizedGroupIdForMessage(b),
        ) &&
        seqA == seqB) {
      return true;
    }
    final aMsgID = a.msgID?.trim() ?? '';
    final bMsgID = b.msgID?.trim() ?? '';
    if (aMsgID.isNotEmpty && bMsgID.isNotEmpty && aMsgID == bMsgID) {
      return true;
    }
    final aId = a.id?.trim() ?? '';
    final bId = b.id?.trim() ?? '';
    if (aId.isNotEmpty && bId.isNotEmpty && aId == bId) {
      return true;
    }
    if (aMsgID.isNotEmpty && bId.isNotEmpty && aMsgID == bId) {
      return true;
    }
    if (aId.isNotEmpty && bMsgID.isNotEmpty && aId == bMsgID) {
      return true;
    }
    if (_c2cCrossSourceCorrelate(a, b)) {
      return true;
    }
    if (_groupCrossSourceCorrelate(a, b)) {
      return true;
    }
    if (_c2cPreviewEchoCorrelate(a, b)) {
      return true;
    }
    if (_sameSelfNonC2cEchoCorrelate(a, b)) {
      return true;
    }
    if (_groupPreviewStubCorrelate(a, b)) {
      return true;
    }
    return _outgoingMessagesCorrelate(a, b);
  }

  /// Merge fetched history with any messages upserted while loading.
  ///
  /// 注意：会保留 [existing] 里的全部历史。首屏若要以会话预览窗口为准，
  /// 请用 [mergePeekWindowWithLiveMemory] + [setMessageList] `replace: true`。
  static List<V2TimMessage> mergeHistoricalWithInMemory({
    List<V2TimMessage>? existing,
    required List<V2TimMessage> fetched,
  }) {
    if (existing == null || existing.isEmpty) {
      return sortMessagesNewestFirst(dedupeMessages(fetched));
    }
    return sortMessagesNewestFirst(
      dedupeMessages(<V2TimMessage>[...existing, ...fetched]),
    );
  }

  /// C2C 官方旧页：只按 msgID 并集。连发相同数字文案不能走 outgoing/指纹去重，
  /// 否则 20 条云端页只会留下 2 条（`----` / `11111`）。
  static List<V2TimMessage> mergeC2cOfficialOlderPage({
    List<V2TimMessage>? existing,
    required List<V2TimMessage> fetched,
  }) {
    final current = existing ?? const <V2TimMessage>[];
    final seenMsgID = <String>{};
    final keyed = <V2TimMessage>[];
    final placeholders = <V2TimMessage>[];
    void ingest(V2TimMessage message) {
      final msgID = message.msgID?.trim() ?? '';
      if (msgID.isNotEmpty) {
        if (seenMsgID.add(msgID)) {
          keyed.add(message);
        }
        return;
      }
      placeholders.add(message);
    }

    for (final message in current) {
      ingest(message);
    }
    for (final message in fetched) {
      ingest(message);
    }
    if (placeholders.isEmpty) {
      return sortMessagesNewestFirst(keyed);
    }
    return sortMessagesNewestFirst(
      dedupeMessages(<V2TimMessage>[...keyed, ...placeholders]),
    );
  }

  /// 进聊合窗时须保留的本地群灰字（勿被 peek 窗口冲掉）。
  /// 成员变动 tip（member_added/removed/left）已换轨 IM GroupTips，不再保留。
  static bool _isPreservedLocalGroupTip(V2TimMessage message) {
    final raw = message.localCustomData?.trim() ?? '';
    if (raw.isNotEmpty) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is Map && decoded['localGroupTips'] == true) {
          final action =
              decoded['action']?.toString().trim().toLowerCase() ?? '';
          if (action == 'member_added' ||
              action == 'member_removed' ||
              action == 'member_left') {
            return false;
          }
          return true;
        }
      } catch (_) {}
    }
    final msgID = message.msgID?.trim() ?? '';
    if (msgID.startsWith('local_gt_') ||
        msgID.startsWith('ce_') ||
        msgID.startsWith('local_')) {
      return true;
    }
    final id = message.id?.trim() ?? '';
    return id.startsWith('local_gt_') ||
        id.startsWith('ce_') ||
        id.startsWith('local_');
  }

  /// 整表 replace 或分页 merge 时，保留尚未出现在新窗里的在途/刚回执自己消息。
  /// 已对上 id / msgID / stableId / dedup 的占位符不回插（避免 018 双气泡）。
  @visibleForTesting
  static List<V2TimMessage> collectUncorrelatedInFlightOutgoing({
    required List<V2TimMessage> previous,
    required List<V2TimMessage> incoming,
  }) {
    if (previous.isEmpty) {
      return const <V2TimMessage>[];
    }
    V2TimMessage? newestIncoming;
    for (final message in incoming) {
      if (newestIncoming == null ||
          compareMessagesChronological(message, newestIncoming) > 0) {
        newestIncoming = message;
      }
    }

    bool coveredByIncoming(V2TimMessage candidate) {
      final candidateId = candidate.id?.trim() ?? '';
      final candidateMsgID = candidate.msgID?.trim() ?? '';
      final candidateStable = readOutgoingStableId(candidate)?.trim() ?? '';
      for (final row in incoming) {
        if (messagesCorrelateForDedup(candidate, row)) {
          return true;
        }
        final rowId = row.id?.trim() ?? '';
        if (candidateId.isNotEmpty && candidateId == rowId) {
          return true;
        }
        final rowMsgID = row.msgID?.trim() ?? '';
        if (candidateMsgID.isNotEmpty && candidateMsgID == rowMsgID) {
          return true;
        }
        final rowStable = readOutgoingStableId(row)?.trim() ?? '';
        if (candidateStable.isNotEmpty && candidateStable == rowStable) {
          return true;
        }
      }
      return false;
    }

    final extras = <V2TimMessage>[];
    for (final message in previous) {
      if (message.isSelf != true || coveredByIncoming(message)) {
        continue;
      }
      if (_shouldKeepUncorrelatedOutgoing(message, newestIncoming)) {
        extras.add(message);
      }
    }
    return extras;
  }

  /// 未被新窗关联的自己消息：在途必留；已成功则留下「比窗新」或本会话刚发出的行。
  ///
  /// 发图 upload 回执时间戳常晚于紧跟着发出的文字。只按 chronological > newest
  /// 会把这条 SEND_SUCC 文字当旧历史丢掉，对端却已收到。
  static bool _shouldKeepUncorrelatedOutgoing(
    V2TimMessage message,
    V2TimMessage? newestIncoming,
  ) {
    if (message.status == MessageStatus.V2TIM_MSG_STATUS_SENDING ||
        _isLiveOutgoingPlaceholder(message)) {
      return true;
    }
    if (message.status != MessageStatus.V2TIM_MSG_STATUS_SEND_SUCC) {
      return false;
    }
    if (newestIncoming != null &&
        compareMessagesChronological(message, newestIncoming) > 0) {
      return true;
    }
    if (_readOutgoingLocalSeq(message) == null) {
      return false;
    }
    if (newestIncoming == null) {
      return true;
    }
    if (compareMessagesChronological(message, newestIncoming) >= 0) {
      return true;
    }
    const maxLagSec = 120;
    final newestTs = newestIncoming.timestamp ?? 0;
    final messageTs = message.timestamp ?? 0;
    if (newestTs > 0 && messageTs > 0 && newestTs - messageTs <= maxLagSec) {
      return true;
    }
    final sentAt = _readOutgoingLocalSentAt(message);
    if (sentAt == null) {
      return false;
    }
    final nowSec = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    return nowSec >= sentAt && nowSec - sentAt <= maxLagSec;
  }

  /// 把 [collectUncorrelatedInFlightOutgoing] 的 extras 插回 newest 端并去重。
  /// 用于分页 merge、内存窗 trim 之后，避免已回执自己消息被旧页/120 窗裁掉。
  @visibleForTesting
  static List<V2TimMessage> restoreUncorrelatedInFlightOutgoing({
    required List<V2TimMessage> previous,
    required List<V2TimMessage> incoming,
  }) {
    final extras = collectUncorrelatedInFlightOutgoing(
      previous: previous,
      incoming: incoming,
    );
    if (extras.isEmpty) {
      return incoming;
    }
    return sortMessagesNewestFirst(
      dedupeMessages(<V2TimMessage>[...extras, ...incoming]),
    );
  }

  /// 以 peek 窗补齐实时/在途消息；不得驱逐后端归档历史（含窗外独有补洞）。
  /// 历史冲突以后端归档为 SoT，由最终 [dedupeMessages] prefer 收敛。
  static List<V2TimMessage> mergePeekWindowWithLiveMemory({
    List<V2TimMessage>? existing,
    required List<V2TimMessage> fetched,
  }) {
    final window = dedupeMessages(fetched);
    if (existing == null || existing.isEmpty) {
      return sortMessagesNewestFirst(window);
    }
    if (window.isEmpty) {
      return sortMessagesNewestFirst(dedupeMessages(existing));
    }

    V2TimMessage? newestInWindow;
    for (final message in window) {
      if (newestInWindow == null ||
          compareMessagesChronological(message, newestInWindow) > 0) {
        newestInWindow = message;
      }
    }

    final live = <V2TimMessage>[];
    var retainedArchiveCount = 0;
    for (final message in existing) {
      // 后端归档（含校对补洞）：一律保留，禁止 SDK peek 窗整表冲掉后再靠校对灌回。
      if (HistoryPaginationAnchor.isArchiveHistoryMessage(message)) {
        live.add(message);
        retainedArchiveCount++;
        continue;
      }
      final coveredByWindow = window.any(
        (windowMessage) => messagesCorrelateForDedup(message, windowMessage),
      );
      if (coveredByWindow) {
        continue;
      }
      if (_isPreservedLocalGroupTip(message)) {
        live.add(message);
        continue;
      }
      final sending = message.isSelf == true &&
          (message.status == MessageStatus.V2TIM_MSG_STATUS_SENDING ||
              _isLiveOutgoingPlaceholder(message));
      if (sending) {
        live.add(message);
        continue;
      }
      if (newestInWindow != null &&
          compareMessagesChronological(message, newestInWindow) > 0) {
        live.add(message);
      }
    }

    final merged = restoreUncorrelatedInFlightOutgoing(
      previous: existing,
      incoming: sortMessagesNewestFirst(
        dedupeMessages(<V2TimMessage>[...window, ...live]),
      ),
    );
    if (OutgoingVisibleProbe.matches(OutgoingVisibleProbe.lastConvID) ||
        existing.any(OutgoingVisibleProbe.matchesMessage) ||
        fetched.any(OutgoingVisibleProbe.matchesMessage)) {
      final droppedSelf = existing.where((message) {
        if (message.isSelf != true) {
          return false;
        }
        return !merged.any(
          (kept) =>
              ((message.id?.trim() ?? '').isNotEmpty &&
                  kept.id?.trim() == message.id?.trim()) ||
              ((message.msgID?.trim() ?? '').isNotEmpty &&
                  kept.msgID?.trim() == message.msgID?.trim()),
        );
      }).toList(growable: false);
      OutgoingVisibleProbe.log(
        'peek_merge_live',
        extras: <String, Object?>{
          'existingCount': existing.length,
          'fetchedCount': fetched.length,
          'liveKept': live.length,
          'mergedCount': merged.length,
          'droppedSelfCount': droppedSelf.length,
          'droppedSelf':
              droppedSelf.map(OutgoingVisibleProbe.brief).join(' || '),
          'existingTracked':
              OutgoingVisibleProbe.trackedInList(existing).toString(),
          'fetchedTracked':
              OutgoingVisibleProbe.trackedInList(fetched).toString(),
          'mergedTracked':
              OutgoingVisibleProbe.trackedInList(merged).toString(),
        },
      );
    }
    if (retainedArchiveCount > 0) {
      ChatHistoryTrace.log(
        'peek_merge_retained_archive',
        extras: <String, Object?>{
          'retainedArchiveCount': retainedArchiveCount,
          'windowCount': window.length,
          'mergedCount': merged.length,
        },
      );
    }
    return merged;
  }

  static List<V2TimMessage> sortMessagesNewestFirst(
    List<V2TimMessage> messages,
  ) {
    return List<V2TimMessage>.from(messages)
      ..sort((a, b) => compareMessagesChronological(b, a));
  }

  static List<V2TimMessage> _mergePendingIncomingForDedup({
    required List<V2TimMessage> pending,
    required List<V2TimMessage> existing,
  }) {
    return sortMessagesNewestFirst(
      dedupeMessages(<V2TimMessage>[...pending, ...existing]),
    );
  }

  @visibleForTesting
  static List<V2TimMessage> appendDistinctIncomingBatchForTesting({
    required List<V2TimMessage> existing,
    required List<V2TimMessage> incoming,
  }) {
    return _mergePendingIncomingForDedup(
      pending: incoming,
      existing: existing,
    );
  }

  @visibleForTesting
  static List<V2TimMessage> filterHiddenProjectionForTesting({
    required Iterable<V2TimMessage> authoritativeMessages,
    required Set<String> hiddenKeys,
  }) {
    return authoritativeMessages
        .where((message) => !hiddenKeys.contains(messageDedupKey(message)))
        .toList(growable: false);
  }

  List<V2TimMessage>? getMessageList(String conversationID) {
    final cached = _messageListDisplayCache[conversationID];
    if (cached != null) {
      return cached;
    }
    final convKey = _inboundStateKey(conversationID);
    final hidden = _inboundHiddenKeysByConv[convKey];
    // 合并 c2c_/裸 id 等别名桶，避免入站写到另一 key 时对话页读不到。
    final authoritative =
        _collectAuthoritativeMessages(conversationID).reversed.toList();
    final visible = hidden == null
        ? authoritative
        : filterHiddenProjectionForTesting(
            authoritativeMessages: authoritative,
            hiddenKeys: hidden,
          );
    final list = visible
        .where((element) => _lifeCycle?.messageShouldMount(element) ?? true)
        .toList();
    final mountedList = _lifeCycle?.messageListShouldMount(list) ?? list;
    final finalList = List<V2TimMessage>.from(mountedList)
      ..sort(compareMessagesChronological);
    final interval = chatConfig.timeDividerConfig?.timeInterval ?? 300;
    final result = attachTimeDividersForTesting(
      finalList,
      intervalSeconds: interval,
    ).reversed.toList();
    _messageListDisplayCache[conversationID] = result;
    ChatHistoryTrace.log(
      'visible_projection_built',
      conversationID: conversationID,
      extras: <String, Object?>{
        'authorityCount': authoritative.length,
        'hiddenCount': hidden?.length ?? 0,
        'projectedCount': visible.length,
        'mountedCount': finalList.length,
        'displayCount':
            result.where((message) => message.elemType != 11).length,
        'dividerCount':
            result.where((message) => message.elemType == 11).length,
        'listRevision': messageListRevisionFor(conversationID),
        'projectionRevision': messageProjectionRevisionFor(conversationID),
      },
    );
    return result;
  }

  /// 无可见行高的消息不参与时间分割线锚点（否则会留下孤儿分割线）。
  @visibleForTesting
  static bool messageAnchorsTimeDivider(V2TimMessage message) {
    if (message.elemType == 11 || message.elemType == 101) {
      return false;
    }
    // 与列表 item 一致：空群 tip 渲染为 SizedBox.shrink。
    if (message.elemType == MessageElemType.V2TIM_ELEM_TYPE_GROUP_TIPS &&
        message.groupTipsElem == null) {
      return false;
    }
    return true;
  }

  /// 按时间升序插入分割线，并去掉「后面没有真实消息」的孤儿分割线。
  @visibleForTesting
  static List<V2TimMessage> attachTimeDividersForTesting(
    List<V2TimMessage> chronologicalAsc, {
    int intervalSeconds = 300,
  }) {
    final listWithTimestamp = <V2TimMessage>[];
    for (final item in chronologicalAsc) {
      if (!messageAnchorsTimeDivider(item)) {
        continue;
      }
      final lastAnchor = _lastTimeDividerAnchor(listWithTimestamp);
      final crossesCalendarDay = lastAnchor?.timestamp != null &&
          item.timestamp != null &&
          _isDifferentCalendarDay(lastAnchor!.timestamp!, item.timestamp!);
      final shouldInsertDivider = listWithTimestamp.isEmpty ||
          crossesCalendarDay ||
          (lastAnchor?.timestamp != null &&
              item.timestamp != null &&
              item.timestamp! - lastAnchor!.timestamp! > intervalSeconds);
      if (shouldInsertDivider) {
        listWithTimestamp.add(_buildTimeDividerMessage(item.timestamp));
      }
      listWithTimestamp.add(item);
    }
    return stripOrphanTimeDividersForTesting(listWithTimestamp);
  }

  static bool _isDifferentCalendarDay(int firstTimestamp, int secondTimestamp) {
    final first = DateTime.fromMillisecondsSinceEpoch(firstTimestamp * 1000);
    final second = DateTime.fromMillisecondsSinceEpoch(secondTimestamp * 1000);
    return first.year != second.year ||
        first.month != second.month ||
        first.day != second.day;
  }

  static V2TimMessage _buildTimeDividerMessage(int? timestamp) {
    final ts = timestamp ?? 0;
    final message = V2TimMessage.fromJson(<String, dynamic>{
      'message_server_time': ts,
      'message_msg_id': 'time-divider-$ts',
      'message_is_from_self': false,
      'message_custom_str': '',
      'message_risk_type_identified': 0,
      'message_sender_group_member_info': <String, dynamic>{},
      'message_group_at_user_array': <String>[],
      'elem_type': 11,
    });
    message.elemType = 11;
    message.timestamp = ts;
    message.msgID = 'time-divider-$ts';
    message.isSelf = false;
    message.userID = '';
    return message;
  }

  static V2TimMessage? _lastTimeDividerAnchor(List<V2TimMessage> list) {
    for (var i = list.length - 1; i >= 0; i--) {
      if (messageAnchorsTimeDivider(list[i])) {
        return list[i];
      }
    }
    return null;
  }

  /// 时间升序列表：去掉连续分割线，以及末尾无真实消息的分割线。
  @visibleForTesting
  static List<V2TimMessage> stripOrphanTimeDividersForTesting(
    List<V2TimMessage> chronologicalAsc,
  ) {
    final out = <V2TimMessage>[];
    for (var i = 0; i < chronologicalAsc.length; i++) {
      final item = chronologicalAsc[i];
      if (item.elemType == 11) {
        final next =
            i + 1 < chronologicalAsc.length ? chronologicalAsc[i + 1] : null;
        if (next == null || next.elemType == 11 || next.elemType == 101) {
          continue;
        }
        if (out.isNotEmpty && out.last.elemType == 11) {
          continue;
        }
        out.add(item);
        continue;
      }
      out.add(item);
    }
    return out;
  }

  bool get isMediaPreviewOverlayOpen => _isMediaPreviewOverlayOpen;

  /// 全屏媒体预览打开中 / 关闭后滚动恢复中：聊天列表应禁用手势滚动。
  bool get shouldLockChatScrollForMediaPreview =>
      _isMediaPreviewOverlayOpen || isRestoringScrollAfterMediaPreview;

  bool get isWalletOverlayOpen => _walletOverlayDepth > 0;

  int _mediaPickerOverlayDepth = 0;

  /// 长按消息菜单 / tooltip 打开期间禁止列表上推，新消息先缓冲。
  int _messageContextMenuOverlayDepth = 0;
  int _messageContextMenuTransactionGeneration = 0;
  final Set<String> _contextMenuViewportRestoreConversations = <String>{};
  final Map<String, MessageContextMenuViewportAnchor>
      _contextMenuViewportAnchors =
      <String, MessageContextMenuViewportAnchor>{};
  final Map<String, Timer> _contextMenuViewportRestoreTimers =
      <String, Timer>{};
  int _pinToBottomRequestSeq = 0;
  String? _pinToBottomRequestConvId;
  bool _pinToBottomForce = false;
  // A return-to-bottom action is asynchronous (history reload, layout and
  // animation). Keep the routing gate alive until the caller explicitly ends
  // the transaction; the timestamp remains only as a stale-call fallback.
  bool _userScrollToBottomTransactionActive = false;
  String? _userScrollToBottomConvId;
  int _userScrollToBottomUntilMs = 0;

  /// list-push / viewport insert 期间会短暂离开 minScrollExtent；此锁防止
  /// 「回到底部」胶囊被误判点亮后又熄灭。
  String? _inboundViewportPushConvId;
  int _inboundViewportPushUntilMs = 0;

  bool get isMediaPickerOverlayOpen => _mediaPickerOverlayDepth > 0;

  bool get isMessageContextMenuOverlayOpen =>
      _messageContextMenuOverlayDepth > 0;

  int get messageContextMenuTransactionGeneration =>
      _messageContextMenuTransactionGeneration;

  bool isContextMenuViewportRestoreActive(String? conversationID) {
    final convId = _safeConversationId(conversationID);
    return convId.isNotEmpty &&
        _contextMenuViewportRestoreConversations.contains(convId);
  }

  MessageContextMenuViewportAnchor? contextMenuViewportAnchorFor(
    String? conversationID,
  ) {
    final convId = _safeConversationId(conversationID);
    if (convId.isEmpty ||
        !_contextMenuViewportRestoreConversations.contains(convId)) {
      return null;
    }
    return _contextMenuViewportAnchors[convId];
  }

  /// Called by the list after it has restored the selected row, or when the
  /// row is no longer mounted. This also releases the physics gate.
  void completeContextMenuViewportRestore(String? conversationID) {
    final convId = _safeConversationId(conversationID);
    if (convId.isEmpty) {
      return;
    }
    _contextMenuViewportRestoreConversations.remove(convId);
    _contextMenuViewportAnchors.remove(convId);
    _contextMenuViewportRestoreTimers.remove(convId)?.cancel();
    _markNeedsNotify();
  }

  int get pinToBottomRequestSeq => _pinToBottomRequestSeq;

  String? get pinToBottomRequestConvId => _pinToBottomRequestConvId;

  bool get pinToBottomForce => _pinToBottomForce;

  void beginUserScrollToBottom(
    String conversationID, {
    int lockMilliseconds = 700,
  }) {
    final convId = _inboundStateKey(conversationID);
    if (convId.isEmpty) {
      return;
    }
    _userScrollToBottomTransactionActive = true;
    final nextUntil = DateTime.now().millisecondsSinceEpoch + lockMilliseconds;
    if (_userScrollToBottomConvId == convId &&
        _userScrollToBottomUntilMs >= nextUntil) {
      return;
    }
    _userScrollToBottomConvId = convId;
    _userScrollToBottomUntilMs = nextUntil;
  }

  bool isUserScrollToBottomInProgress(String? conversationID) {
    final convId = _inboundStateKey(conversationID);
    if (convId.isEmpty || _userScrollToBottomConvId != convId) {
      return false;
    }
    return _userScrollToBottomTransactionActive ||
        DateTime.now().millisecondsSinceEpoch < _userScrollToBottomUntilMs;
  }

  void beginInboundViewportPush(
    String conversationID, {
    int lockMilliseconds = 1200,
  }) {
    final convId = _inboundStateKey(conversationID);
    if (convId.isEmpty) {
      return;
    }
    final nextUntil = DateTime.now().millisecondsSinceEpoch + lockMilliseconds;
    if (_inboundViewportPushConvId == convId &&
        _inboundViewportPushUntilMs >= nextUntil) {
      return;
    }
    _inboundViewportPushConvId = convId;
    _inboundViewportPushUntilMs = nextUntil;
  }

  void endInboundViewportPush(
    String conversationID, {
    int settleMilliseconds = 320,
  }) {
    final convId = _inboundStateKey(conversationID);
    if (convId.isEmpty || _inboundViewportPushConvId != convId) {
      return;
    }
    _inboundViewportPushUntilMs =
        DateTime.now().millisecondsSinceEpoch + settleMilliseconds;
  }

  bool isInboundViewportPushActive(String? conversationID) {
    final convId = _inboundStateKey(conversationID);
    if (convId.isEmpty || _inboundViewportPushConvId != convId) {
      return false;
    }
    return DateTime.now().millisecondsSinceEpoch < _inboundViewportPushUntilMs;
  }

  void endUserScrollToBottom(String conversationID) {
    final convId = _inboundStateKey(conversationID);
    if (_userScrollToBottomConvId != convId) {
      return;
    }
    _userScrollToBottomConvId = null;
    _userScrollToBottomTransactionActive = false;
    _userScrollToBottomUntilMs = 0;
  }

  void requestPinToBottom(String conversationID, {bool force = false}) {
    final convId = _safeConversationId(conversationID);
    if (convId.isEmpty) {
      return;
    }
    debugPrint(
        '[MessageContextTrace] scroll_mutation type=pin_schedule conv=$convId force=$force menuOpen=$isMessageContextMenuOverlayOpen');
    ChatHistoryTrace.log(
      'pin_to_bottom_requested',
      conversationID: convId,
      extras: <String, Object?>{
        'force': force,
        'position': getMessageListPosition(convId).name,
        'readingHistory': isReadingHistory(convId),
        'memorySuppressed': isMemoryWindowSuppressed(convId),
        'bulkSync': isBulkMessageSyncActive(convId),
        'chunkedReveal': isChunkedRevealActive(convId),
      },
    );
    if (isBulkMessageSyncActive(convId) || isChunkedRevealActive(convId)) {
      _pendingPinAfterBulkByConv[convId] =
          force || (_pendingPinAfterBulkByConv[convId] ?? false);
      return;
    }
    _pinToBottomRequestConvId = convId;
    _pinToBottomForce = force;
    _pinToBottomRequestSeq++;
    _markNeedsNotify();
  }

  void beginMediaPickerOverlay() {
    _mediaPickerOverlayDepth++;
  }

  void endMediaPickerOverlay() {
    final wasOpen = _mediaPickerOverlayDepth > 0;
    if (_mediaPickerOverlayDepth > 0) {
      _mediaPickerOverlayDepth--;
    }
    if (wasOpen && _mediaPickerOverlayDepth == 0) {
      // 系统/自定义相册覆盖聊天页期间，底层列表不可能仍由用户拖动。
      // 某些平台关闭 picker 时不会补发此前被打断的 ScrollEnd，若保留
      // scrolling=true，随后发送图片的 force-pin 会被当成手势冲突而取消。
      setChatListUserScrolling(false);
      _markNeedsNotify();
    }
  }

  void beginMessageContextMenuOverlay({
    String? conversationID,
    String? anchorMessageID,
    String? anchorSeq,
    double? anchorViewportTop,
  }) {
    if (_messageContextMenuOverlayDepth == 0) {
      _messageContextMenuTransactionGeneration++;
    }
    final convId = _safeConversationId(conversationID ?? currentSelectedConv);
    if (_messageContextMenuOverlayDepth == 0 && convId.isNotEmpty) {
      _contextMenuViewportRestoreConversations.remove(convId);
      _contextMenuViewportAnchors.remove(convId);
      _contextMenuViewportRestoreTimers.remove(convId)?.cancel();
      _syncHistoryPositionFromActiveScroll(convId);
      final identity = anchorMessageID?.trim();
      final seq = anchorSeq?.trim();
      if (((identity?.isNotEmpty ?? false) || (seq?.isNotEmpty ?? false)) &&
          anchorViewportTop != null &&
          anchorViewportTop.isFinite) {
        _contextMenuViewportAnchors[convId] = MessageContextMenuViewportAnchor(
          identity: identity,
          seq: seq?.isNotEmpty == true ? seq : null,
          viewportTop: anchorViewportTop,
        );
      }
      debugPrint('[MessageContextTrace] global_open conv=$convId '
          'identity=$identity seq=$seq anchorTop=$anchorViewportTop '
          'depth=$_messageContextMenuOverlayDepth');
    }
    _messageContextMenuOverlayDepth++;
    _markNeedsNotify();
  }

  final List<VoidCallback> _contextMenuOverlayDismissers = <VoidCallback>[];

  void registerContextMenuOverlayDismisser(VoidCallback dismiss) {
    // There is only one context menu in the app. Keeping callbacks from every
    // mounted message row caused dismissAllContextMenuOverlays to broadcast
    // closeTooltip to the entire list, triggering hundreds of stale cleanup
    // calls and unnecessary rebuilds. Replace the previous owner atomically.
    _contextMenuOverlayDismissers
      ..clear()
      ..add(dismiss);
  }

  void unregisterContextMenuOverlayDismisser(VoidCallback dismiss) {
    _contextMenuOverlayDismissers.remove(dismiss);
  }

  /// 路由离栈 / 聊天 dispose 时强制移除 root 长按菜单 Overlay，并重置 depth。
  void dismissAllContextMenuOverlays() {
    final pending = List<VoidCallback>.from(_contextMenuOverlayDismissers);
    for (final dismiss in pending) {
      try {
        dismiss();
      } catch (_) {}
    }
    _contextMenuOverlayDismissers.clear();
    // A dismisser normally calls endMessageContextMenuOverlay first, which
    // reduces depth to zero and starts viewport restoration. Route teardown
    // must clear that newly-created restore transaction as well, so cleanup
    // cannot be conditional on depth still being positive here.
    _messageContextMenuOverlayDepth = 0;
    _contextMenuViewportRestoreConversations.clear();
    _contextMenuViewportAnchors.clear();
    for (final timer in _contextMenuViewportRestoreTimers.values) {
      timer.cancel();
    }
    _contextMenuViewportRestoreTimers.clear();
    // A long press can win while a scroll gesture is being cancelled. Flutter
    // does not guarantee a later ScrollEndNotification for that cancelled
    // gesture, so never carry the scrolling latch past overlay teardown.
    setChatListUserScrolling(false);
    _markNeedsNotify();
  }

  void endMessageContextMenuOverlay({String? conversationID}) {
    final wasOpen = _messageContextMenuOverlayDepth > 0;
    if (_messageContextMenuOverlayDepth > 0) {
      _messageContextMenuOverlayDepth--;
    }
    if (!wasOpen || _messageContextMenuOverlayDepth > 0) {
      return;
    }
    // The overlay absorbed/cancelled the pointer sequence. Clear a stale
    // scrolling latch before rebuilding physics, otherwise automatic scroll
    // coordination may continue treating the list as gesture-owned.
    setChatListUserScrolling(false);
    _messageContextMenuTransactionGeneration++;
    final convId = _safeConversationId(
      conversationID ?? currentSelectedConv,
    );
    debugPrint('[MessageContextTrace] global_close conv=$convId '
        'depth=$_messageContextMenuOverlayDepth '
        'buffered=${deferredIncomingBufferedCount(convId)}');
    if (convId.isNotEmpty) {
      _contextMenuViewportRestoreConversations.add(convId);
      final before = deferredIncomingBufferedCount(convId);
      // Closing a context menu must not also be a "return to latest" action.
      // Flushing here combines a newest-edge insert with the overlay removal;
      // on a reverse, virtualized list that can evict the selected row before
      // its viewport anchor is measured. Keep these rows in the unread queue
      // until the user explicitly returns to bottom or taps the unread tongue.
      debugPrint('[MessageContextTrace] close_defer conv=$convId '
          'buffered=$before');
      _markNeedsNotify();
      debugPrint('[MessageContextTrace] close_restore_scheduled conv=$convId');
      _contextMenuViewportRestoreTimers[convId]?.cancel();
      // Watchdog only. Normal completion is reported by the list after the
      // identity anchor is geometrically stable for consecutive frames.
      _contextMenuViewportRestoreTimers[convId] = Timer(
        const Duration(seconds: 5),
        () => completeContextMenuViewportRestore(convId),
      );
    } else {
      _markNeedsNotify();
    }
  }

  void beginWalletOverlay({
    String? conversationID,
    String? anchorMessageID,
  }) {
    _walletOverlayDepth++;
    saveScrollBeforeRouteOverlay(
      conversationID,
      anchorMessageID: anchorMessageID,
      lockMilliseconds: 1200,
    );
  }

  void endWalletOverlay({String? conversationID}) {
    if (_walletOverlayDepth > 0) {
      _walletOverlayDepth--;
    }
    restoreScrollAfterRouteOverlay(
      conversationID,
      lockMilliseconds: 900,
    );
  }

  ScrollPosition? _singleScrollPositionOrNull(ScrollController controller) {
    if (!controller.hasClients || controller.positions.length != 1) {
      return null;
    }
    return controller.position;
  }

  void saveScrollBeforeRouteOverlay(
    String? conversationID, {
    String? anchorMessageID,
    int lockMilliseconds = 800,
  }) {
    final convId = _safeConversationId(conversationID);
    if (convId.isEmpty) {
      return;
    }
    final controller = _activeChatScrollControllerMap[convId];
    final position =
        controller == null ? null : _singleScrollPositionOrNull(controller);
    if (position != null && position.hasPixels) {
      _mediaPreviewScrollOffsetMap[convId] = position.pixels;
    }
    final anchor = anchorMessageID?.trim() ?? '';
    if (anchor.isNotEmpty) {
      _mediaPreviewAnchorMsgIDMap[convId] = anchor;
    }
    _syncHistoryPositionFromActiveScroll(convId);
  }

  void restoreScrollAfterRouteOverlay(
    String? conversationID, {
    int lockMilliseconds = 800,
  }) {
    final convId = _safeConversationId(conversationID);
    if (convId.isEmpty) {
      _isRestoringScrollAfterMediaPreview = false;
      return;
    }
    _isRestoringScrollAfterMediaPreview = true;
    _mediaPreviewRestoreVersion++;
    _mediaPreviewRestoreLockUntil =
        DateTime.now().millisecondsSinceEpoch + lockMilliseconds;
    _syncHistoryPositionFromActiveScroll(convId);
    notifyListeners();
  }

  bool get isRestoringScrollAfterMediaPreview {
    final now = DateTime.now().millisecondsSinceEpoch;
    return _isRestoringScrollAfterMediaPreview ||
        now < _mediaPreviewRestoreLockUntil;
  }

  int get mediaPreviewRestoreVersion => _mediaPreviewRestoreVersion;

  void bindActiveChatScrollController({
    required String conversationID,
    required ScrollController scrollController,
  }) {
    if (conversationID.isEmpty) {
      return;
    }
    _activeChatScrollControllerMap[conversationID] = scrollController;
  }

  void clearActiveChatScrollController({String? conversationID}) {
    if (conversationID != null && conversationID.isNotEmpty) {
      _activeChatScrollControllerMap.remove(conversationID);
      return;
    }
    _activeChatScrollControllerMap.clear();
  }

  bool hasPendingScrollRestore(String? conversationID) {
    final convId = _safeConversationId(conversationID);
    if (convId.isEmpty) {
      return false;
    }
    // 仅「正在恢复滚动」时阻塞列表；预览期间保存的 offset 不应改变列表位姿。
    return _isRestoringScrollAfterMediaPreview ||
        DateTime.now().millisecondsSinceEpoch < _mediaPreviewRestoreLockUntil;
  }

  bool isInboundPresentationBottomLocked(String convId) {
    if (isChatListUserScrolling ||
        !_isSameConversationID(convId, currentSelectedConv)) {
      return false;
    }
    // list-push 会故意 jump 离底再 animate 回来；这段物理偏移不是用户上滑看历史。
    // 不限 chunked reveal：单条连续收消息同样会误闪「回到底部」。
    if (isInboundViewportPushActive(convId)) {
      return true;
    }
    if (!isChunkedRevealActive(convId)) {
      return false;
    }
    // A viewport insert deliberately moves pixels away from minScrollExtent
    // while a tall row slides in. That visual offset is not user history
    // navigation, so keep the pre-transaction logical position authoritative.
    return getMessageListPosition(convId) == HistoryMessagePosition.bottom;
  }

  /// During a reverse-list prepend Flutter can briefly expose the minimum
  /// pixels while the new sliver tree is laid out. This is geometry, not a
  /// user return-to-latest gesture. Expose the predicate so the tongue and
  /// other position observers share the same gate as the active list.
  bool isPaginationRestoreTransientNearBottom(
    String convId,
    ScrollPosition position,
  ) {
    final logicalPosition = getMessageListPosition(convId);
    final physicalDistance = position.pixels - position.minScrollExtent;
    return isMemoryWindowSuppressed(convId) &&
        !isChatListUserScrolling &&
        !isUserScrollToBottomInProgress(convId) &&
        (logicalPosition == HistoryMessagePosition.awayTwoScreen ||
            logicalPosition == HistoryMessagePosition.notShowLatest) &&
        physicalDistance <= 80.0;
  }

  // Kept as a private alias for existing diagnostics/tests; all production
  // callers use the public predicate above so the gate is shared cross-widget.
  bool _isPaginationRestoreTransientNearBottom(
    String convId,
    ScrollPosition position,
  ) =>
      isPaginationRestoreTransientNearBottom(convId, position);

  void _syncHistoryPositionFromActiveScroll(String convId) {
    if (isInboundPresentationBottomLocked(convId)) {
      _storeHistoryMessagePosition(convId, HistoryMessagePosition.bottom);
      final controller = _activeChatScrollControllerMap[convId];
      final position =
          controller == null ? null : _singleScrollPositionOrNull(controller);
      if (position != null &&
          position.hasPixels &&
          position.hasContentDimensions &&
          position.pixels > position.minScrollExtent + 80) {
        ChatJitterDiag.logInboundFlow(
          action: 'physical_away_ignored',
          conv: convId,
          extras: <String, Object?>{
            'pixels': position.pixels.toStringAsFixed(1),
            'minExtent': position.minScrollExtent.toStringAsFixed(1),
            'distance':
                (position.pixels - position.minScrollExtent).toStringAsFixed(1),
            'maxExtent': position.maxScrollExtent.toStringAsFixed(1),
            'logicalPosition': HistoryMessagePosition.bottom.name,
            'queue': pendingInboundProjectionCount(convId),
            'waiting': isInboundProjectionRevealWaiting(convId),
          },
          throttleKey: 'physical_away_ignored',
          minIntervalMs: 200,
        );
      }
      return;
    }
    final controller = _activeChatScrollControllerMap[convId];
    final position =
        controller == null ? null : _singleScrollPositionOrNull(controller);
    if (position != null &&
        position.hasPixels &&
        position.hasContentDimensions) {
      // A reverse history prepend can transiently report pixels==0 while the
      // new sliver tree is being laid out. During the protected memory-window
      // transaction that value is not a real return-to-bottom gesture. If we
      // promote it to bottom here, realtime messages are committed into the
      // visible list and their pin/rebuild path races the pagination anchor
      // (the observed awayTwoScreen -> bottom -> old offset oscillation).
      final logicalPosition = getMessageListPosition(convId);
      final physicalDistance = position.pixels - position.minScrollExtent;
      if (isPaginationRestoreTransientNearBottom(convId, position)) {
        ChatHistoryTrace.log(
          'logical_position_sync_ignored_pagination_restore',
          conversationID: convId,
          extras: <String, Object?>{
            'logicalPosition': logicalPosition.name,
            'pixels': position.pixels.toStringAsFixed(1),
            'minExtent': position.minScrollExtent.toStringAsFixed(1),
            'maxExtent': position.maxScrollExtent.toStringAsFixed(1),
            'distance': physicalDistance.toStringAsFixed(1),
            'userScrolling': isChatListUserScrolling,
            'userScrollToBottom': isUserScrollToBottomInProgress(convId),
            'memorySuppressed': true,
          },
        );
        return;
      }
      const nearThreshold = 80.0;
      final viewport = position.viewportDimension;
      final distance = position.pixels - position.minScrollExtent;
      final previous = getMessageListPosition(convId);
      final HistoryMessagePosition next;
      if (viewport > 0 && distance > viewport) {
        next = HistoryMessagePosition.awayTwoScreen;
      } else if (distance > nearThreshold) {
        next = HistoryMessagePosition.inTwoScreen;
      } else {
        next = HistoryMessagePosition.bottom;
      }
      _storeHistoryMessagePosition(convId, next);
      if (previous != next) {
        ChatJitterDiag.logInboundFlow(
          action: 'logical_position_sync',
          conv: convId,
          extras: <String, Object?>{
            'before': previous.name,
            'after': next.name,
            'pixels': position.pixels.toStringAsFixed(1),
            'minExtent': position.minScrollExtent.toStringAsFixed(1),
            'distance': distance.toStringAsFixed(1),
            'viewport': viewport.toStringAsFixed(1),
            'userScrolling': isChatListUserScrolling,
            'chunkActive': isChunkedRevealActive(convId),
          },
        );
      }
    }
  }

  bool _isActiveChatNearBottom(String convId, {double threshold = 80.0}) {
    if (isInboundPresentationBottomLocked(convId)) {
      return true;
    }
    final controller = _activeChatScrollControllerMap[convId];
    if (controller == null) {
      return false;
    }
    final position = _singleScrollPositionOrNull(controller);
    if (position == null) {
      return false;
    }
    if (!position.hasPixels || !position.hasContentDimensions) {
      return false;
    }
    if (isPaginationRestoreTransientNearBottom(convId, position)) {
      return false;
    }
    return position.pixels <= position.minScrollExtent + threshold;
  }

  /// Shared physical near-bottom decision for message routing and list-push.
  /// Logical `bottom` alone is not sufficient because it can lag behind a
  /// short user scroll or an in-flight geometry change.
  bool isActiveChatNearBottom(String conversationID) =>
      _isActiveChatNearBottom(_safeConversationId(conversationID));

  /// 物理滚动已离开底部超过约一屏（与「回到底部」出现阈值对齐）。
  bool _isActiveChatAwayOneScreen(String convId) {
    if (isInboundPresentationBottomLocked(convId)) {
      return false;
    }
    final controller = _activeChatScrollControllerMap[convId];
    if (controller == null) {
      return false;
    }
    final position = _singleScrollPositionOrNull(controller);
    if (position == null ||
        !position.hasPixels ||
        !position.hasContentDimensions) {
      return false;
    }
    final viewport = position.viewportDimension;
    if (viewport <= 0) {
      return false;
    }
    final distance = position.pixels - position.minScrollExtent;
    return distance > viewport;
  }

  void saveScrollBeforeMediaPreview(
    String? conversationID, {
    String? anchorMessageID,
  }) {
    final wasOpen = _isMediaPreviewOverlayOpen;
    _isMediaPreviewOverlayOpen = true;
    saveScrollBeforeRouteOverlay(
      conversationID,
      anchorMessageID: anchorMessageID,
      lockMilliseconds: _mediaPreviewRestoreLockMilliseconds,
    );
    if (!wasOpen) {
      _markNeedsNotify();
    }
  }

  void restoreScrollAfterMediaPreview(String? conversationID) {
    final convId = _safeConversationId(conversationID);
    if (convId.isEmpty) {
      if (_isMediaPreviewOverlayOpen) {
        _isMediaPreviewOverlayOpen = false;
        _markNeedsNotify();
      }
      return;
    }
    if (!_needsActiveScrollRestoreAfterPreview(convId)) {
      _clearMediaPreviewScrollRestoreState(convId);
      if (_isMediaPreviewOverlayOpen) {
        _isMediaPreviewOverlayOpen = false;
        _markNeedsNotify();
      }
      return;
    }
    restoreScrollAfterRouteOverlay(
      conversationID,
      lockMilliseconds: _mediaPreviewRestoreLockMilliseconds,
    );
    // Keep overlay lock until [finishScrollAfterMediaPreview]: clearing early
    // lets residual slide-dismiss pointers scroll the chat list under the pop.
    //
    // 兜底：列表若未调度到 finish（dispose / 未挂 listener），超时强制解锁，
    // 避免永久 NeverScrollable。
    final restoreVersion = _mediaPreviewRestoreVersion;
    Future<void>.delayed(const Duration(milliseconds: 1600), () {
      if (_mediaPreviewRestoreVersion != restoreVersion) {
        return;
      }
      if (!shouldLockChatScrollForMediaPreview) {
        return;
      }
      finishScrollAfterMediaPreview(convId);
    });
  }

  /// 预览路由已完全 pop 且滚动恢复结束后调用（与 [restoreScrollAfterMediaPreview] 解耦兜底）。
  void endMediaPreviewOverlay() {
    if (!_isMediaPreviewOverlayOpen) {
      return;
    }
    _isMediaPreviewOverlayOpen = false;
    _markNeedsNotify();
  }

  /// 预览关闭后是否需要主动改滚动位置。
  ///
  /// 只认打开时保存的像素 offset：列表在 `opaque:false` 预览下本来就还在，
  /// 仅有锚点消息 id 时不得强制 restore——否则会走
  /// `scrollToIndex(middle)` 把入口气泡拽到屏幕正中。
  bool _needsActiveScrollRestoreAfterPreview(String convId) {
    final offset = _mediaPreviewScrollOffsetMap[convId];
    if (offset == null) {
      return false;
    }
    final controller = _activeChatScrollControllerMap[convId];
    final position =
        controller == null ? null : _singleScrollPositionOrNull(controller);
    if (position == null ||
        !position.hasPixels ||
        !position.hasContentDimensions) {
      // offset 已存、当前读不到 position：仍要进 restore，等列表就绪后 jump。
      return true;
    }
    final target = offset.clamp(
      position.minScrollExtent,
      position.maxScrollExtent,
    );
    return (position.pixels - target).abs() > 0.5;
  }

  void _clearMediaPreviewScrollRestoreState(String convId) {
    final wasRestoring = _isRestoringScrollAfterMediaPreview ||
        DateTime.now().millisecondsSinceEpoch < _mediaPreviewRestoreLockUntil;
    _isRestoringScrollAfterMediaPreview = false;
    _mediaPreviewRestoreLockUntil = 0;
    _mediaPreviewScrollOffsetMap.remove(convId);
    _mediaPreviewAnchorMsgIDMap.remove(convId);
    if (wasRestoring) {
      _markNeedsNotify();
    }
  }

  /// 画廊预览关闭前更新锚点，避免左右滑到别的图后仍滚回入口消息。
  void updateMediaPreviewCloseAnchor(
    String? conversationID,
    String? anchorMessageID,
  ) {
    final convId = _safeConversationId(conversationID);
    if (convId.isEmpty) {
      return;
    }
    final anchor = anchorMessageID?.trim() ?? '';
    if (anchor.isNotEmpty) {
      _mediaPreviewAnchorMsgIDMap[convId] = anchor;
    }
  }

  String? getScrollRestoreAnchorMsgID(String? conversationID) {
    final convId = _safeConversationId(conversationID);
    if (convId.isEmpty) {
      return null;
    }
    return _mediaPreviewAnchorMsgIDMap[convId];
  }

  double? getScrollRestoreOffset(String? conversationID) {
    final convId = _safeConversationId(conversationID);
    if (convId.isEmpty) {
      return null;
    }
    return _mediaPreviewScrollOffsetMap[convId];
  }

  void finishScrollAfterMediaPreview(String? conversationID) {
    final convId = _safeConversationId(conversationID);
    if (convId.isNotEmpty) {
      final controller = _activeChatScrollControllerMap[convId];
      final position =
          controller == null ? null : _singleScrollPositionOrNull(controller);
      if (position != null &&
          position.hasPixels &&
          position.hasContentDimensions) {
        const threshold = 80.0;
        if (position.pixels > position.minScrollExtent + threshold) {
          _storeHistoryMessagePosition(
            convId,
            HistoryMessagePosition.inTwoScreen,
          );
        } else {
          _storeHistoryMessagePosition(convId, HistoryMessagePosition.bottom);
        }
      }
      _mediaPreviewRestoreLockUntil = DateTime.now().millisecondsSinceEpoch +
          _mediaPreviewRestoreTailLockMilliseconds;
    }
    final wasOpen = _isMediaPreviewOverlayOpen;
    _isMediaPreviewOverlayOpen = false;
    Future<void>.delayed(
        const Duration(milliseconds: _mediaPreviewRestoreTailLockMilliseconds),
        () {
      final now = DateTime.now().millisecondsSinceEpoch;
      if (now < _mediaPreviewRestoreLockUntil) {
        return;
      }
      if (convId.isNotEmpty) {
        _clearMediaPreviewScrollRestoreState(convId);
      } else {
        _isRestoringScrollAfterMediaPreview = false;
        _mediaPreviewRestoreLockUntil = 0;
      }
    });
    if (wasOpen) {
      _markNeedsNotify();
    }
  }

  String _safeConversationId(String? conversationID) {
    if (conversationID != null && conversationID.isNotEmpty) {
      return conversationID;
    }
    return currentSelectedConv;
  }

  /// 入站/展示共用的 messageListMap 存储键。
  ///
  /// Web/C2C 常见分裂：历史灌在 `c2c_userId`，`onRecvNewMessage` 算出的是裸
  /// `userId`。若各写各的桶，会话预览（conversation listener）会更新，但聊天
  /// 页 `getMessageList(c2c_…)` 仍读旧桶 → 预览有字、对话页不刷新。
  String _resolveMessageListStorageKey(String conversationID) {
    final trimmed = conversationID.trim();
    if (trimmed.isEmpty) {
      return trimmed;
    }

    final selected = currentSelectedConv.trim();
    if (selected.isNotEmpty &&
        _isSameConversationID(trimmed, selected) &&
        _messageListMap.containsKey(selected)) {
      return selected;
    }

    String? emptyAlias;
    for (final entry in _messageListMap.entries) {
      if (!_isSameConversationID(entry.key, trimmed)) {
        continue;
      }
      final list = entry.value;
      if (list != null && list.isNotEmpty) {
        return entry.key;
      }
      emptyAlias ??= entry.key;
    }
    if (emptyAlias != null) {
      return emptyAlias;
    }

    if (selected.isNotEmpty && _isSameConversationID(trimmed, selected)) {
      return selected;
    }
    return trimmed;
  }

  /// 合并等价会话 ID 下所有非空桶（防御双写残留）。
  List<V2TimMessage> _collectAuthoritativeMessages(String conversationID) {
    final trimmed = conversationID.trim();
    if (trimmed.isEmpty) {
      return const <V2TimMessage>[];
    }
    final buckets = <List<V2TimMessage>>[];
    for (final entry in _messageListMap.entries) {
      if (!_isSameConversationID(entry.key, trimmed)) {
        continue;
      }
      final list = entry.value;
      if (list != null && list.isNotEmpty) {
        buckets.add(list);
      }
    }
    if (buckets.isEmpty) {
      return const <V2TimMessage>[];
    }
    if (buckets.length == 1) {
      return buckets.first;
    }
    return sortMessagesNewestFirst(
      dedupeMessages(
        <V2TimMessage>[
          for (final bucket in buckets) ...bucket,
        ],
      ),
    );
  }

  HistoryMessagePosition getMessageListPosition(String? conversationID) {
    final convId = _safeConversationId(conversationID);
    if (hasPendingScrollRestore(convId)) {
      // During scroll restore lock, return notShowLatest temporarily
      // WITHOUT persisting it. The previous stored position is preserved
      // and will be read again once the lock clears.
      return HistoryMessagePosition.notShowLatest;
    }
    final page = _openPageHistoryPosition;
    final pageConv = _openPageConvId;
    if (page != null &&
        pageConv != null &&
        _isSameConversationID(convId, pageConv)) {
      return page.value;
    }
    final HistoryMessagePosition? position = _historyMessagePositionMap[convId];
    if (position == null) {
      _storeHistoryMessagePosition(convId, HistoryMessagePosition.bottom);
      return HistoryMessagePosition.bottom;
    }
    return position;
  }

  void prepareForOutgoingMessage(String conversationID) {
    final convId = _safeConversationId(conversationID);
    if (convId.isEmpty) {
      return;
    }
    _mediaPreviewScrollOffsetMap.remove(convId);
    _mediaPreviewAnchorMsgIDMap.remove(convId);
    _isRestoringScrollAfterMediaPreview = false;
    _mediaPreviewRestoreLockUntil = 0;
    _storeHistoryMessagePosition(convId, HistoryMessagePosition.bottom);
    flushDeferredIncomingMessages(
      convId,
      notify: false,
      userInitiated: true,
    );
    unlockEntryUnreadForTongue(
      conversationID: convId,
      notify: false,
    );
    clearReceivedUnreadState(
      conversationID: convId,
      notify: false,
    );
    _outgoingPinScrollSuppressUntilMs =
        DateTime.now().millisecondsSinceEpoch + 350;
  }

  bool shouldSuppressOutgoingPinScroll() {
    return DateTime.now().millisecondsSinceEpoch <
        _outgoingPinScrollSuppressUntilMs;
  }

  void setMessageListPosition(
      String conversationID, HistoryMessagePosition position,
      {bool notify = true}) {
    final convId = _safeConversationId(conversationID);
    final previous = getMessageListPosition(convId);
    HistoryMessagePosition next = position;
    final controller = _activeChatScrollControllerMap[convId];
    final activeScrollPosition =
        controller == null ? null : _singleScrollPositionOrNull(controller);
    if (position == HistoryMessagePosition.bottom &&
        activeScrollPosition != null &&
        activeScrollPosition.hasPixels &&
        activeScrollPosition.hasContentDimensions &&
        isPaginationRestoreTransientNearBottom(
          convId,
          activeScrollPosition,
        )) {
      // A tongue/overlay/background callback can observe the transient zero
      // pixels before the pagination anchor is restored. Keep the prior
      // logical position authoritative; accepting bottom here starts the
      // realtime pin/rebuild path and recreates the 0 -> oldOffset oscillation.
      next = previous;
      ChatHistoryTrace.log(
        'message_list_position_bottom_blocked_pagination_restore',
        conversationID: convId,
        extras: <String, Object?>{
          'previous': previous.name,
          'pixels': activeScrollPosition.pixels.toStringAsFixed(1),
          'minExtent': activeScrollPosition.minScrollExtent.toStringAsFixed(1),
          'maxExtent': activeScrollPosition.maxScrollExtent.toStringAsFixed(1),
          'memorySuppressed': true,
        },
      );
    }
    if (position == HistoryMessagePosition.bottom &&
        _deferredUntilUserBottomConversations.contains(
          _inboundStateKey(convId),
        )) {
      next = HistoryMessagePosition.notShowLatest;
    } else if (position == HistoryMessagePosition.bottom &&
        hasPendingScrollRestore(convId)) {
      next = HistoryMessagePosition.notShowLatest;
    }
    _storeHistoryMessagePosition(convId, next);
    if (previous != next) {
      ChatHistoryTrace.log(
        'message_list_position_changed',
        conversationID: convId,
        extras: <String, Object?>{
          'previous': previous.name,
          'requested': position.name,
          'next': next.name,
          'notify': notify,
          'pendingScrollRestore': hasPendingScrollRestore(convId),
          'readingHistory': isReadingHistory(convId),
          'memorySuppressed': isMemoryWindowSuppressed(convId),
        },
      );
    }
    // Scroll-position churn must not fan out to every Global listener when
    // the logical value is unchanged (page-local UI is SSOT while attached).
    if (notify && previous != next) {
      notifyListeners();
    }
  }
}
