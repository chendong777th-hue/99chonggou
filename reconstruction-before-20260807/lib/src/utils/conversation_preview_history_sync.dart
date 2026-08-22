import 'package:flutter/foundation.dart';
import 'package:tencent_cloud_chat_demo/src/services/conversation_local/conversation_local_store.dart';
import 'package:tencent_cloud_chat_demo/utils/chat_id_format.dart';
import 'package:tencent_cloud_chat_uikit/business_logic/view_models/tui_chat_global_model.dart';
import 'package:tencent_cloud_chat_uikit/data_services/message/archive_history_provider.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_conversation.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_conversation.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_message.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_message.dart';

@immutable
class ConversationMessageRef {
  const ConversationMessageRef({
    this.msgID,
    this.id,
    this.timestamp,
  });

  final String? msgID;
  final String? id;
  final int? timestamp;

  factory ConversationMessageRef.fromMessage(V2TimMessage message) {
    return ConversationMessageRef(
      msgID: message.msgID,
      id: message.id,
      timestamp: message.timestamp,
    );
  }
}

/// 会话列表预览与聊天室缓存对齐判断。
class ConversationPreviewHistorySync {
  ConversationPreviewHistorySync._();

  static const String previewAheadOnOpenReason = 'conversation_open_preview_ahead';

  /// Local-only ids (e.g. group tips) must not be used as IM history anchors.
  static bool isSyntheticLocalAnchorId(String? raw) {
    final id = raw?.trim() ?? '';
    return id.startsWith('local_gt_') ||
        id.startsWith('ce_') ||
        id.startsWith('local_');
  }

  static bool isSyntheticLocalMessage(V2TimMessage message) {
    if (isSyntheticLocalAnchorId(message.msgID)) {
      return true;
    }
    if (isSyntheticLocalAnchorId(message.id)) {
      return true;
    }
    final custom = message.localCustomData?.trim() ?? '';
    return custom.contains('"localGroupTips"');
  }

  /// 重连预热 / 进页短路：已 mark loaded、内存非空、预览 tip 未领先、非清空宽限期。
  ///
  /// 短会话在 `hasMoreOlder=false` 时也会 mark loaded，二次进页应同样走 warm skip。
  static bool isWarmWindowReadyForOpen({
    required TUIChatGlobalModel globalModel,
    required String conversationKey,
    V2TimMessage? preview,
  }) {
    final key = conversationKey.trim();
    if (key.isEmpty) {
      return false;
    }
    if (!globalModel.hasInitialHistoryLoaded(key)) {
      return false;
    }
    if (ArchiveHistoryProvider.isInHistoryClearGrace(key) ||
        ArchiveHistoryProvider.isInHistoryClearGrace(
          key.startsWith('group_') ? key.substring(6) : 'group_$key',
        )) {
      return false;
    }
    final cached = globalModel.rawMessageList(key);
    if (cached == null || cached.isEmpty) {
      return false;
    }
    return !isPreviewAheadOfCachedHistory(
      preview: preview,
      cached: cached,
    );
  }

  /// 进页 gate 二次 bootstrap 短路：内存已有可展示窗且 tip 未领先。
  ///
  /// 比 [isWarmWindowReadyForOpen] 更宽——冷开并行 peek 刚灌入、尚未 mark
  /// loaded 的短窗也可跳过，避免首帧后再打一轮 LOCAL→CLOUD。
  static bool canSkipOpenRebootstrap({
    required TUIChatGlobalModel globalModel,
    required String conversationKey,
    V2TimMessage? preview,
  }) {
    final key = conversationKey.trim();
    if (key.isEmpty) {
      return false;
    }
    if (isWarmWindowReadyForOpen(
      globalModel: globalModel,
      conversationKey: key,
      preview: preview,
    )) {
      return true;
    }
    if (ArchiveHistoryProvider.isInHistoryClearGrace(key) ||
        ArchiveHistoryProvider.isInHistoryClearGrace(
          key.startsWith('group_') ? key.substring(6) : 'group_$key',
        )) {
      return false;
    }
    final cached = globalModel.rawMessageList(key);
    if (cached == null || cached.isEmpty) {
      return false;
    }
    return !isPreviewAheadOfCachedHistory(
      preview: preview,
      cached: cached,
    );
  }

  static String? conversationMessageCacheKey(V2TimConversation conversation) {
    final userID = conversation.userID?.trim();
    if (userID != null && userID.isNotEmpty) {
      return userID;
    }
    final groupID = conversation.groupID?.trim();
    if (groupID != null && groupID.isNotEmpty) {
      // 完整社群/群 ID 为唯一暖窗 key（剥离 group_、展开短码）。
      return ChatIdFormat.canonicalGroupStorageId(groupID);
    }
    final conversationID = conversation.conversationID.trim();
    if (conversationID.isEmpty) {
      return null;
    }
    if (conversationID.toLowerCase().startsWith('group_')) {
      return ChatIdFormat.canonicalGroupStorageId(conversationID);
    }
    return conversationID;
  }

  static bool isSameRef(ConversationMessageRef a, ConversationMessageRef b) {
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
    return false;
  }

  static bool isSameMessage(V2TimMessage a, V2TimMessage b) {
    if (isSameRef(
      ConversationMessageRef.fromMessage(a),
      ConversationMessageRef.fromMessage(b),
    )) {
      return true;
    }
    return TUIChatGlobalModel.messagesCorrelateForDedup(a, b);
  }

  static bool isRefVisibleInList(
    ConversationMessageRef message,
    List<ConversationMessageRef> cached,
  ) {
    for (final item in cached) {
      if (isSameRef(message, item)) {
        return true;
      }
    }
    return false;
  }

  static bool isMessageVisibleInList(
    V2TimMessage message,
    List<V2TimMessage> cached,
  ) {
    for (final item in cached) {
      if (isSameMessage(message, item)) {
        return true;
      }
    }
    return false;
  }

  @visibleForTesting
  static bool isPreviewAheadOfCachedRefs({
    required ConversationMessageRef? preview,
    required List<ConversationMessageRef> cached,
  }) {
    if (preview == null) {
      return false;
    }
    if (cached.isEmpty) {
      return true;
    }
    if (isRefVisibleInList(preview, cached)) {
      return false;
    }
    final previewTs = preview.timestamp ?? 0;
    final headTs = cached.first.timestamp ?? 0;
    if (previewTs > headTs) {
      return true;
    }
    if (previewTs == headTs) {
      return !isSameRef(preview, cached.first);
    }
    return false;
  }

  static bool isPreviewAheadOfCachedHistory({
    required V2TimMessage? preview,
    required List<V2TimMessage> cached,
  }) {
    if (preview == null) {
      return false;
    }
    if (cached.isEmpty) {
      return true;
    }
    if (isMessageVisibleInList(preview, cached)) {
      return false;
    }
    final previewTs = preview.timestamp ?? 0;
    final headTs = cached.first.timestamp ?? 0;
    if (previewTs > headTs) {
      return true;
    }
    if (previewTs == headTs) {
      return !isSameMessage(preview, cached.first);
    }
    return false;
  }

  static Future<V2TimMessage?> resolvePreviewLastMessage(
    V2TimConversation conversation,
  ) async {
    final direct = conversation.lastMessage;
    if (direct != null) {
      return direct;
    }
    final conversationID = conversation.conversationID.trim();
    if (conversationID.isEmpty) {
      return null;
    }
    final local =
        await ConversationLocalStore.instance.conversationById(conversationID);
    return local?.lastMessage;
  }
}
