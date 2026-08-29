import 'package:tencent_cloud_chat_sdk/models/v2_tim_conversation.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_conversation.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_group_info.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_group_info.dart';
import 'package:tencent_cloud_chat_demo/src/models/me_group_record.dart';
import 'package:tencent_cloud_chat_demo/src/services/group_local/group_local_store.dart';
import 'package:tencent_cloud_chat_demo/utils/chat_id_format.dart';
import 'package:tencent_cloud_chat_demo/utils/user_avatar.dart';

/// 群会话展示名/头像：优先群资料库，再 REST [groupList]，再回退 IM 会话字段。
class GroupDisplayResolver {
  GroupDisplayResolver._();

  /// Expando cache for O(1) group lookup by groupID, avoiding linear
  /// scans through groupList on every conversation row build.
  static final Expando<_GroupIndexSnapshot> _groupIndexCache =
      Expando<_GroupIndexSnapshot>();

  static V2TimGroupInfo? findGroup(
    Iterable<V2TimGroupInfo>? groupList,
    String? groupId,
  ) {
    final id = groupId?.trim() ?? '';
    if (id.isEmpty || groupList == null) {
      return null;
    }
    // Build/reuse an index keyed by groupID for O(1) lookup.
    final list = groupList is List<V2TimGroupInfo>
        ? groupList
        : groupList.toList(growable: false);
    var snapshot = _groupIndexCache[list];
    if (snapshot == null || !snapshot.matches(list)) {
      final byId = <String, V2TimGroupInfo>{};
      for (final item in list) {
        final itemId = item.groupID.trim();
        if (itemId.isNotEmpty) {
          byId[itemId] = item;
        }
      }
      snapshot = _GroupIndexSnapshot(
        length: list.length,
        first: list.isEmpty ? null : list.first,
        last: list.isEmpty ? null : list.last,
        byId: byId,
      );
      _groupIndexCache[list] = snapshot;
    }
    // Fast path: exact ID match.
    final exact = snapshot.byId[id];
    if (exact != null) return exact;
    // Fallback: equivalent ID match (community IDs etc).
    for (final entry in snapshot.byId.entries) {
      if (ChatIdFormat.groupIdsEquivalent(entry.key, id)) {
        return entry.value;
      }
    }
    return null;
  }

  /// 会话 showName 是否像群 ID / 展示别名（而非群名称）。
  static bool looksLikeGroupIdLabel(String? value, {String? groupId}) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) {
      return false;
    }
    if (ChatIdFormat.isIMGroupOrCommunityId(text)) {
      return true;
    }
    final gid = groupId?.trim() ?? '';
    if (gid.isNotEmpty && ChatIdFormat.groupIdsEquivalent(text, gid)) {
      return true;
    }
    final alias = ChatIdFormat.displayGroupAlias(text);
    if (alias.isNotEmpty && alias == text) {
      // `@m2…` / `@TGS#_…` 这类别名不应充当群昵称。
      if (text.startsWith('@') &&
          (text.toUpperCase().contains('TGS#') ||
              ChatIdFormat.isCommunityShortToken(text.substring(1)))) {
        return true;
      }
    }
    return false;
  }

  static String resolveShowName({
    required V2TimConversation conversation,
    Iterable<V2TimGroupInfo>? groupList,
    String? localGroupName,
  }) {
    final groupId = conversation.groupID?.trim() ?? '';
    if (groupId.isEmpty) {
      final bare = conversation.showName?.trim() ?? '';
      return looksLikeGroupIdLabel(bare) ? '' : bare;
    }

    void consider(String? raw, List<String> sink) {
      final text = raw?.trim() ?? '';
      if (text.isEmpty) {
        return;
      }
      if (looksLikeGroupIdLabel(text, groupId: groupId)) {
        return;
      }
      if (!sink.contains(text)) {
        sink.add(text);
      }
    }

    final candidates = <String>[];
    final cachedRecord = _safeCachedGroupRecord(groupId);
    // 群资料库一旦存在，就是群展示字段的提交快照。SDK 群列表和会话
    // showName 只能在没有本地记录时作为冷启动兜底，不能覆盖本地快照。
    consider(cachedRecord?.groupName ?? localGroupName, candidates);
    if (cachedRecord != null) {
      if (candidates.isNotEmpty) {
        return candidates.first;
      }
      final alias = ChatIdFormat.displayGroupAlias(
        groupId,
      );
      return alias;
    }
    final fromRest = findGroup(groupList, groupId);
    consider(fromRest?.groupName, candidates);
    consider(conversation.showName, candidates);
    if (candidates.isNotEmpty) {
      return candidates.first;
    }
    // 无真实群名时最多回退短展示别名（@m2…），绝不展示 @TGS#_@TGS# 完整 IM ID。
    final alias = ChatIdFormat.displayGroupAlias(
      conversation.showName,
      groupIdFallback: groupId,
    );
    if (alias.isNotEmpty) {
      return alias;
    }
    return '';
  }

  static String resolveFaceUrl({
    required V2TimConversation conversation,
    Iterable<V2TimGroupInfo>? groupList,
  }) {
    final groupId = conversation.groupID?.trim() ?? '';
    final localUrl = _safeCachedAvatarUrl(groupId) ?? '';
    if (localUrl.isNotEmpty &&
        !UserAvatarHelper.isDefaultPlaceholder(localUrl)) {
      return localUrl;
    }
    final fromRest = findGroup(groupList, groupId);
    final restUrl = fromRest?.faceUrl?.trim() ?? '';
    if (restUrl.isNotEmpty && !UserAvatarHelper.isDefaultPlaceholder(restUrl)) {
      return restUrl;
    }
    final fromConversation = conversation.faceUrl?.trim() ?? '';
    if (fromConversation.isNotEmpty &&
        !UserAvatarHelper.isDefaultPlaceholder(fromConversation)) {
      return fromConversation;
    }
    return fromConversation;
  }

  static int? resolveMemberCount({
    required String? groupId,
    Iterable<V2TimGroupInfo>? groupList,
  }) {
    final cachedRecord = _safeCachedGroupRecord(groupId?.trim() ?? '');
    if (cachedRecord != null) {
      return cachedRecord.memberCount;
    }
    final fromRest = findGroup(groupList, groupId);
    return fromRest?.memberCount;
  }

  static String resolveNotice({
    required String? groupId,
    Iterable<V2TimGroupInfo>? groupList,
  }) {
    final fromRest = findGroup(groupList, groupId);
    return fromRest?.notification?.trim() ?? '';
  }

  static MeGroupRecord? _safeCachedGroupRecord(String groupId) {
    try {
      return GroupLocalStore.instance.readCached(groupId: groupId);
    } catch (_) {
      return null;
    }
  }

  static String? _safeCachedAvatarUrl(String groupId) {
    try {
      return GroupLocalStore.instance
          .readCached(groupId: groupId)
          ?.avatarUrl
          .trim();
    } catch (_) {
      return null;
    }
  }
}

class _GroupIndexSnapshot {
  const _GroupIndexSnapshot({
    required this.length,
    required this.first,
    required this.last,
    required this.byId,
  });

  final int length;
  final V2TimGroupInfo? first;
  final V2TimGroupInfo? last;
  final Map<String, V2TimGroupInfo> byId;

  bool matches(List<V2TimGroupInfo> list) {
    return list.length == length &&
        (list.isEmpty || identical(list.first, first)) &&
        (list.isEmpty || identical(list.last, last));
  }
}
