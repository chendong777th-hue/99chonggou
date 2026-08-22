import 'package:tencent_cloud_chat_demo/utils/chat_id_format.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_conversation.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_conversation.dart';

/// 会话 ID 是否为腾讯云 IM 单聊形态（`c2c_` / 脏孪生 `group_c2c_`）。
bool looksLikeC2cConversationId(String? raw) {
  final id = raw?.trim().toLowerCase() ?? '';
  if (id.isEmpty) {
    return false;
  }
  return id.startsWith('c2c_') || id.startsWith('group_c2c_');
}

/// 禁止写入群成员库 / 当作 TIM groupID 使用的 ID（含把 `c2c_…` 当群）。
bool isForbiddenGroupStorageId(String? raw) {
  final id = raw?.trim() ?? '';
  if (id.isEmpty) {
    return true;
  }
  if (looksLikeC2cConversationId(id)) {
    return true;
  }
  final normalized = ChatIdFormat.normalizeGroupId(id);
  if (normalized.isEmpty) {
    return true;
  }
  return looksLikeC2cConversationId(normalized);
}

/// 群列表已对齐后，未加入的群会话不应出现在消息列表。
bool shouldHideNonMemberGroupConversation({
  required String conversationId,
  String? groupId,
  required bool groupListSyncedOnce,
  required bool Function(String groupId) isJoinedGroup,
}) {
  if (!groupListSyncedOnce) {
    return false;
  }
  final resolvedGroupId = resolveGroupIdFromConversation(
    conversationId: conversationId,
    groupId: groupId,
  );
  if (resolvedGroupId.isEmpty) {
    return false;
  }
  return !isJoinedGroup(resolvedGroupId);
}

/// 从会话解析群 ID。`c2c_` 前缀硬否决；`group_` 前缀优先于误填字段。
String resolveGroupIdFromConversation({
  required String conversationId,
  String? groupId,
}) {
  final id = conversationId.trim();
  if (looksLikeC2cConversationId(id)) {
    return '';
  }
  if (id.toLowerCase().startsWith('group_')) {
    final fromPrefix = ChatIdFormat.normalizeGroupId(id.substring(6));
    if (fromPrefix.isEmpty || isForbiddenGroupStorageId(fromPrefix)) {
      return '';
    }
    return fromPrefix;
  }
  final explicit = ChatIdFormat.normalizeGroupId(groupId);
  if (explicit.isEmpty || isForbiddenGroupStorageId(explicit)) {
    return '';
  }
  return explicit;
}

/// 是否群会话：`conversationID` 前缀硬覆盖 type / 误填 groupID（对齐官方与 HistoryPeer）。
bool isGroupConversation(V2TimConversation conversation) {
  final id = conversation.conversationID.trim();
  final lower = id.toLowerCase();
  if (lower.startsWith('c2c_') || looksLikeC2cConversationId(id)) {
    return false;
  }
  if (lower.startsWith('group_')) {
    return true;
  }
  final rawGroupId = conversation.groupID?.trim() ?? '';
  if (rawGroupId.isNotEmpty && !isForbiddenGroupStorageId(rawGroupId)) {
    return true;
  }
  return conversation.type == 2;
}

bool shouldShowConversationForMembership({
  required V2TimConversation conversation,
  required bool groupListSyncedOnce,
  required bool Function(String groupId) isJoinedGroup,
  bool Function(String groupId)? hasActiveConversationEvidence,
}) {
  if (!isGroupConversation(conversation)) {
    return true;
  }
  final hidden = shouldHideNonMemberGroupConversation(
    conversationId: conversation.conversationID,
    groupId: conversation.groupID,
    groupListSyncedOnce: groupListSyncedOnce,
    isJoinedGroup: isJoinedGroup,
  );
  if (!hidden) {
    return true;
  }
  final groupId = resolveGroupIdFromConversation(
    conversationId: conversation.conversationID,
    groupId: conversation.groupID,
  );
  return groupId.isNotEmpty &&
      (hasActiveConversationEvidence?.call(groupId) ?? false);
}

class CollapsedGroupConversations {
  const CollapsedGroupConversations({
    required this.conversations,
    required this.obsoleteConversationIds,
  });

  final List<V2TimConversation> conversations;
  final List<String> obsoleteConversationIds;
}

/// 同一群的短码 / 完整 ID 只留 preferred 一行，其余进 obsolete。
CollapsedGroupConversations collapseEquivalentGroupConversations(
  List<V2TimConversation> input,
) {
  final byToken = <String, V2TimConversation>{};
  final obsolete = <String>[];
  final passthrough = <V2TimConversation>[];
  for (final conv in input) {
    if (!isGroupConversation(conv)) {
      passthrough.add(conv);
      continue;
    }
    final id = conv.conversationID.trim();
    final token = ChatIdFormat.groupEquivalenceToken(id) ??
        ChatIdFormat.groupEquivalenceToken(conv.groupID);
    if (token == null || token.isEmpty) {
      passthrough.add(conv);
      continue;
    }
    final existing = byToken[token];
    if (existing == null) {
      byToken[token] = conv;
      continue;
    }
    final preferredId = ChatIdFormat.preferredGroupConversationId(
      existing.conversationID,
      id,
    );
    if (preferredId == id) {
      final dropped = existing.conversationID.trim();
      if (dropped.isNotEmpty) {
        obsolete.add(dropped);
      }
      byToken[token] = conv;
    } else {
      if (id.isNotEmpty) {
        obsolete.add(id);
      }
    }
  }
  return CollapsedGroupConversations(
    conversations: <V2TimConversation>[...passthrough, ...byToken.values],
    obsoleteConversationIds: obsolete,
  );
}
