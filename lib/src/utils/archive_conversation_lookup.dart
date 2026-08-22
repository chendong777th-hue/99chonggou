import 'package:flutter/foundation.dart';
import 'package:tencent_cloud_chat_demo/src/utils/message_conversation_id.dart';
import 'package:tencent_cloud_chat_demo/utils/chat_id_format.dart';

/// 归档会话 ID → 查找 token 展开 / O(1) 判定（滚动热路径用）。
Set<String> archiveLookupTokensForConversationId(String conversationID) {
  final id = conversationID.trim();
  if (id.isEmpty) {
    return const <String>{};
  }
  final out = <String>{id};
  void add(String? value) {
    final v = value?.trim() ?? '';
    if (v.isNotEmpty) {
      out.add(v);
    }
  }

  final comparable = MessageConversationId.normalizeComparableKey(id);
  add(comparable);

  final lower = id.toLowerCase();
  final isGroup = lower.startsWith('group_') || id.startsWith('GROUP');
  final isC2c = lower.startsWith('c2c_') || id.startsWith('C2C');

  if (isGroup || (!isC2c && ChatIdFormat.isIMGroupOrCommunityId(comparable))) {
    final peer = comparable.isNotEmpty ? comparable : id;
    final canonical = ChatIdFormat.canonicalGroupStorageId(peer);
    add(canonical);
    add('group_$canonical');
    final token = ChatIdFormat.groupEquivalenceToken(peer) ??
        ChatIdFormat.groupEquivalenceToken(canonical) ??
        ChatIdFormat.groupEquivalenceToken(id);
    add(token);
    if (token != null && token.isNotEmpty) {
      add('group_$token');
    }
    return out;
  }

  final peer = comparable.isNotEmpty
      ? ChatIdFormat.rawUserUid(comparable)
      : ChatIdFormat.rawUserUid(id);
  add(peer);
  if (peer.isNotEmpty) {
    add('c2c_$peer');
  }
  return out;
}

Set<String> buildArchiveLookupTokenSet(Set<String> archivedIDs) {
  if (archivedIDs.isEmpty) {
    return const <String>{};
  }
  final out = <String>{};
  for (final archivedId in archivedIDs) {
    out.addAll(archiveLookupTokensForConversationId(archivedId));
  }
  return out;
}

/// 同一 [archivedIDs] 实例上缓存 token Set，供角标热路径复用。
final Expando<Set<String>> _archiveLookupTokenCache = Expando<Set<String>>();

Set<String> cachedArchiveLookupTokenSet(Set<String> archivedIDs) {
  if (archivedIDs.isEmpty) {
    return const <String>{};
  }
  final cached = _archiveLookupTokenCache[archivedIDs];
  if (cached != null) {
    return cached;
  }
  final built = buildArchiveLookupTokenSet(archivedIDs);
  _archiveLookupTokenCache[archivedIDs] = built;
  return built;
}

/// 写入归档 JOIN 候选表的 ID 形态（与 [archiveLookupTokensForConversationId] 同集）。
Set<String> archiveJoinCandidatesForConversationId(String conversationID) {
  return archiveLookupTokensForConversationId(conversationID);
}

Set<String> buildArchiveJoinCandidateSet(Set<String> archivedIDs) {
  return buildArchiveLookupTokenSet(archivedIDs);
}

/// 原始归档 ID 是否已有任一候选落在本地已命中的 `conversation_id` 集合中。
bool archivedIdMatchedInStoredIds(
  String archivedId,
  Set<String> storedConversationIds,
) {
  if (storedConversationIds.isEmpty) {
    return false;
  }
  for (final token in archiveJoinCandidatesForConversationId(archivedId)) {
    if (storedConversationIds.contains(token)) {
      return true;
    }
  }
  return false;
}

bool conversationIdInArchivedLookup(
  Set<String> lookupTokens,
  String conversationID,
) {
  if (lookupTokens.isEmpty) {
    return false;
  }
  for (final token in archiveLookupTokensForConversationId(conversationID)) {
    if (lookupTokens.contains(token)) {
      return true;
    }
  }
  return false;
}
