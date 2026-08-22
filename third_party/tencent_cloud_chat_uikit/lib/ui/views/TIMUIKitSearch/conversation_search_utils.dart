import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:lpinyin/lpinyin.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_conversation.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_conversation.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_friend_info.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_friend_info.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_group_info.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_group_info.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_group_member_full_info.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_group_member_full_info.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_message_search_result_item.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_message_search_result_item.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_user_full_info.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_user_full_info.dart';
import 'package:tencent_cloud_chat_uikit/business_logic/services/display_name_store.dart';
import 'package:tencent_cloud_chat_uikit/data_services/profile/user_profile_local_bridge.dart';

({int searchTimePosition, int searchTimePeriod}) dateSearchTimeRange(
  DateTime date,
) {
  final start = DateTime(date.year, date.month, date.day);
  final end =
      start.add(const Duration(days: 1)).subtract(const Duration(seconds: 1));
  final endSec = end.millisecondsSinceEpoch ~/ 1000;
  final startSec = start.millisecondsSinceEpoch ~/ 1000;
  // SDK window is [position - period, position]. Use exact day length so the
  // lower bound lands on 00:00:00, not one second into the previous day.
  return (
    searchTimePosition: endSec,
    searchTimePeriod: endSec - startSec,
  );
}

({int startTs, int endTs}) dateSearchTimestampRange(DateTime date) {
  final start = DateTime(date.year, date.month, date.day);
  final end =
      start.add(const Duration(days: 1)).subtract(const Duration(seconds: 1));
  return (
    startTs: start.millisecondsSinceEpoch ~/ 1000,
    endTs: end.millisecondsSinceEpoch ~/ 1000,
  );
}

({int startTs, int endTs}) timestampRangeFromSearchParams({
  required int searchTimePosition,
  required int searchTimePeriod,
}) {
  if (searchTimePosition <= 0 || searchTimePeriod <= 0) {
    return (startTs: 0, endTs: 0);
  }
  return (
    startTs: searchTimePosition - searchTimePeriod,
    endTs: searchTimePosition,
  );
}

final RegExp _searchCommunityShortAlnumReg = RegExp(r'^[A-Za-z0-9_]+$');
final RegExp _searchHasUpperCaseReg = RegExp(r'[A-Z]');

/// 与 app [ChatIdFormat.isCommunityShortToken] 对齐：字母数字下划线且含大写。
bool searchLooksLikeCommunityShortToken(String token) {
  final t = token.trim();
  if (t.isEmpty || t.toUpperCase().contains('TGS#')) {
    return false;
  }
  if (!_searchCommunityShortAlnumReg.hasMatch(t)) {
    return false;
  }
  return _searchHasUpperCaseReg.hasMatch(t);
}

String searchStripConversationPrefix(String? conversationId) {
  var id = conversationId?.trim() ?? '';
  if (id.isEmpty) {
    return '';
  }
  final lower = id.toLowerCase();
  if (lower.startsWith('group_')) {
    return id.substring(6);
  }
  if (lower.startsWith('c2c_')) {
    return id.substring(4);
  }
  return id;
}

/// 群 ID 等价 token：`group_@TGS#_@TGS#m2…` / `@TGS#_@TGS#m2…` / `m2…` → `m2…`。
String? searchGroupEquivalenceToken(String? input) {
  var id = searchStripConversationPrefix(input);
  if (id.isEmpty) {
    return null;
  }
  final upper = id.toUpperCase();
  const fullPrefix = '@TGS#_@TGS#';
  if (upper.startsWith(fullPrefix)) {
    var short = id.substring(fullPrefix.length);
    if (short.startsWith('@')) {
      short = short.substring(1);
    }
    return short.isEmpty ? null : short;
  }
  if (upper.startsWith('@TGS#_')) {
    final short = id.substring('@TGS#_'.length);
    return short.isEmpty ? null : short;
  }
  if (upper.startsWith('TGS#_@TGS#')) {
    final short = id.substring('TGS#_@TGS#'.length);
    return short.isEmpty ? null : short;
  }
  if (upper.contains('TGS#')) {
    final hash = id.indexOf('#');
    if (hash >= 0 && hash + 1 < id.length) {
      var token = id.substring(hash + 1);
      if (token.startsWith('_')) {
        token = token.substring(1);
      }
      final tokenUpper = token.toUpperCase();
      if (tokenUpper.startsWith('@TGS#')) {
        final nestedHash = token.indexOf('#');
        if (nestedHash >= 0 && nestedHash + 1 < token.length) {
          token = token.substring(nestedHash + 1);
        }
      } else if (tokenUpper.startsWith('TGS#')) {
        final nestedHash = token.indexOf('#');
        if (nestedHash >= 0 && nestedHash + 1 < token.length) {
          token = token.substring(nestedHash + 1);
        }
      }
      if (token.startsWith('@')) {
        token = token.substring(1);
      }
      return token.isEmpty ? null : token;
    }
  }
  if (id.startsWith('@')) {
    id = id.substring(1);
  }
  return id.isEmpty ? null : id;
}

bool searchLooksLikeGroupConversationId(String? conversationId) {
  final id = conversationId?.trim() ?? '';
  if (id.isEmpty) {
    return false;
  }
  final lower = id.toLowerCase();
  if (lower.startsWith('c2c_')) {
    return false;
  }
  if (lower.startsWith('group_')) {
    return true;
  }
  final body = searchStripConversationPrefix(id);
  if (body.toUpperCase().contains('TGS#')) {
    return true;
  }
  if (body.startsWith('@') &&
      searchLooksLikeCommunityShortToken(body.substring(1))) {
    return true;
  }
  return searchLooksLikeCommunityShortToken(body);
}

bool searchLooksLikeGroupIdLabel(String? value, {String? groupId}) {
  final text = value?.trim() ?? '';
  if (text.isEmpty) {
    return false;
  }
  if (text.toUpperCase().contains('TGS#')) {
    return true;
  }
  final token = text.startsWith('@') ? text.substring(1) : text;
  if (searchLooksLikeCommunityShortToken(token)) {
    return true;
  }
  final gid = groupId?.trim() ?? '';
  if (gid.isNotEmpty && searchGroupIdsEquivalent(text, gid)) {
    return true;
  }
  return false;
}

bool isGroupConversationId(String? conversationId) {
  return searchLooksLikeGroupConversationId(conversationId);
}

String? groupIdFromConversationId(String? conversationId) {
  if (!isGroupConversationId(conversationId)) {
    return null;
  }
  final groupId = searchStripConversationPrefix(conversationId).trim();
  return groupId.isEmpty ? null : groupId;
}

/// 仅保留 [joinedGroupIds] 中的群；[joinedGroupIds] 为空时返回空列表。
List<V2TimGroupInfo> filterGroupInfosByJoinedIds(
  List<V2TimGroupInfo> groups,
  Set<String> joinedGroupIds,
) {
  if (joinedGroupIds.isEmpty) {
    return const <V2TimGroupInfo>[];
  }
  return groups
      .where(
        (group) =>
            searchJoinedGroupIdSetContains(joinedGroupIds, group.groupID),
      )
      .toList(growable: false);
}

/// 过滤群聊天记录搜索结果：conversationID 为 group_* 且不在白名单的条目剔除。
/// C2C 会话不受影响。
List<V2TimMessageSearchResultItem?> filterMessageSearchResultsByJoinedGroups(
  List<V2TimMessageSearchResultItem?>? items,
  Set<String> joinedGroupIds,
) {
  if (items == null || items.isEmpty) {
    return items ?? const <V2TimMessageSearchResultItem?>[];
  }
  return items.where((item) {
    final conversationId = item?.conversationID?.trim() ?? '';
    if (!isGroupConversationId(conversationId)) {
      return true;
    }
    final groupId = groupIdFromConversationId(conversationId);
    if (groupId == null || groupId.isEmpty) {
      return false;
    }
    return searchJoinedGroupIdSetContains(joinedGroupIds, groupId);
  }).toList(growable: false);
}

bool searchJoinedGroupIdSetContains(Set<String> joinedGroupIds, String groupId) {
  final id = groupId.trim();
  if (id.isEmpty || joinedGroupIds.isEmpty) {
    return false;
  }
  if (joinedGroupIds.contains(id)) {
    return true;
  }
  for (final joined in joinedGroupIds) {
    if (searchGroupIdsEquivalent(joined, id)) {
      return true;
    }
  }
  return false;
}

String? resolveGroupIdFromConversation(V2TimConversation conversation) {
  final groupId = conversation.groupID?.trim() ?? '';
  if (groupId.isNotEmpty) {
    return groupId;
  }
  return groupIdFromConversationId(conversation.conversationID);
}

bool isGroupConversation(V2TimConversation conversation) {
  final groupId = resolveGroupIdFromConversation(conversation);
  if (groupId != null && groupId.isNotEmpty) {
    return true;
  }
  return conversation.type != 1;
}

/// 搜索展示用：群名优先于会话旧 showName（避免搜到新名却显示旧名）。
@visibleForTesting
String preferSearchGroupShowName({
  String? groupName,
  String? conversationShowName,
  String? storeName,
  String? groupId,
}) {
  final gid = groupId?.trim() ?? '';
  bool usable(String? raw) {
    final text = raw?.trim() ?? '';
    if (text.isEmpty) {
      return false;
    }
    if (searchLooksLikeGroupIdLabel(text, groupId: gid)) {
      return false;
    }
    return true;
  }

  for (final candidate in <String?>[groupName, storeName, conversationShowName]) {
    if (usable(candidate)) {
      return candidate!.trim();
    }
  }
  return conversationShowName?.trim() ?? groupName?.trim() ?? gid;
}

/// 搜索「聊天记录」C2C 行标题：备注 > DisplayNameStore > 昵称 > 会话 showName；跳过等于 userId 的占位。
@visibleForTesting
String preferSearchC2cShowName({
  String? friendRemark,
  String? storeName,
  String? nickName,
  String? conversationShowName,
  String? userID,
}) {
  final uid = userID?.trim() ?? '';
  bool usable(String? raw) {
    final text = raw?.trim() ?? '';
    if (text.isEmpty) {
      return false;
    }
    if (uid.isNotEmpty && (text == uid || text == 'c2c_$uid')) {
      return false;
    }
    return true;
  }

  for (final candidate in <String?>[
    friendRemark,
    storeName,
    nickName,
    conversationShowName,
  ]) {
    if (usable(candidate)) {
      return candidate!.trim();
    }
  }
  return uid;
}

bool searchGroupIdsEquivalent(String? left, String? right) {
  final a = left?.trim() ?? '';
  final b = right?.trim() ?? '';
  if (a.isEmpty || b.isEmpty) {
    return false;
  }
  if (a == b) {
    return true;
  }
  final aTok = searchGroupEquivalenceToken(a);
  final bTok = searchGroupEquivalenceToken(b);
  if (aTok != null && bTok != null && aTok == bTok) {
    return true;
  }
  final aBare = searchStripConversationPrefix(a);
  final bBare = searchStripConversationPrefix(b);
  return aBare.isNotEmpty && aBare == bBare;
}

String? lookupSearchGroupStoreName(String groupId) {
  final id = groupId.trim();
  if (id.isEmpty) {
    return null;
  }
  final name = DisplayNameStore.instance
          .groupWhere(id, searchGroupIdsEquivalent)
          ?.trim() ??
      '';
  return name.isEmpty ? null : name;
}

V2TimConversation? lookupSearchGroupConversation(
  Map<String, V2TimConversation> conversationByGroupId,
  String groupId,
) {
  final id = groupId.trim();
  if (id.isEmpty) {
    return null;
  }
  final direct = conversationByGroupId[id];
  if (direct != null) {
    return direct;
  }
  for (final entry in conversationByGroupId.entries) {
    if (searchGroupIdsEquivalent(entry.key, id)) {
      return entry.value;
    }
  }
  return null;
}

/// 群成员副标题：由业务层提供最近在线文案（[imOnline] 为 IM 在线状态）。
typedef MemberPresenceLabelBuilder = String Function(
  String userId,
  bool imOnline,
);

/// 最近上线时间是否仍在拉取（未拉取完成时应显示骨架占位）。
typedef MemberPresenceLoadingChecker = bool Function(
  String userId,
  bool imOnline,
);

/// 将 IM SDK 在线状态与业务层 presence（通讯录最近活跃）合并为有效在线态。
typedef MemberPresenceOnlineResolver = bool Function(
  String userId,
  bool imSdkOnline,
);

Widget buildMemberPresenceSubtitleSkeleton({
  Color? baseColor,
  double width = 64,
  double height = 10,
  double lineHeight = 12,
}) {
  return SizedBox(
    height: lineHeight,
    child: Align(
      alignment: Alignment.centerLeft,
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: (baseColor ?? const Color(0xFF999999)).withValues(alpha: 0.22),
          borderRadius: BorderRadius.circular(4),
        ),
      ),
    ),
  );
}

String normalizeSearchKeyword(String keyword) => keyword.trim().toLowerCase();

bool keywordMatchesText(String? text, String keyword) {
  final normalized = normalizeSearchKeyword(keyword);
  if (normalized.isEmpty) {
    return false;
  }
  final haystack = (text ?? '').trim().toLowerCase();
  if (haystack.isEmpty) {
    return false;
  }
  return haystack.contains(normalized);
}

bool friendInfoMatchesSearchKeyword(V2TimFriendInfo friend, String keyword) {
  if (keywordMatchesText(friend.userID, keyword)) {
    return true;
  }
  if (keywordMatchesText(friend.friendRemark, keyword)) {
    return true;
  }
  if (keywordMatchesText(friend.userProfile?.nickName, keyword)) {
    return true;
  }
  return false;
}

bool groupInfoMatchesSearchKeyword(V2TimGroupInfo group, String keyword) {
  if (keywordMatchesText(group.groupID, keyword)) {
    return true;
  }
  if (keywordMatchesText(group.groupName, keyword)) {
    return true;
  }
  return false;
}

bool c2cConversationMatchesSearchKeyword(
  V2TimConversation conversation,
  String keyword,
) {
  if (isGroupConversation(conversation)) {
    return false;
  }
  if (keywordMatchesText(conversation.userID, keyword)) {
    return true;
  }
  if (keywordMatchesText(conversation.showName, keyword)) {
    return true;
  }
  final conversationId = conversation.conversationID?.trim() ?? '';
  if (conversationId.startsWith('c2c_')) {
    return keywordMatchesText(conversationId.substring(4), keyword);
  }
  return false;
}

bool groupConversationMatchesSearchKeyword(
  V2TimConversation conversation,
  String keyword,
) {
  if (!isGroupConversation(conversation)) {
    return false;
  }
  final groupId = resolveGroupIdFromConversation(conversation);
  if (keywordMatchesText(groupId, keyword)) {
    return true;
  }
  if (keywordMatchesText(conversation.showName, keyword)) {
    return true;
  }
  return false;
}

V2TimFriendInfo friendInfoFromC2cConversation(V2TimConversation conversation) {
  final userId = conversation.userID?.trim().isNotEmpty == true
      ? conversation.userID!.trim()
      : (conversation.conversationID.startsWith('c2c_')
          ? conversation.conversationID.substring(4).trim()
          : '');
  final showName = conversation.showName?.trim() ?? '';
  return V2TimFriendInfo(
    userID: userId,
    userProfile: V2TimUserFullInfo(
      userID: userId,
      nickName: showName.isNotEmpty ? showName : userId,
      faceUrl: conversation.faceUrl,
    ),
  );
}

V2TimGroupInfo groupInfoFromGroupConversation(V2TimConversation conversation) {
  final groupId = resolveGroupIdFromConversation(conversation) ?? '';
  final showName = conversation.showName?.trim() ?? '';
  return V2TimGroupInfo(
    groupID: groupId,
    groupType: conversation.groupType ?? '',
    groupName: showName.isNotEmpty ? showName : groupId,
    faceUrl: conversation.faceUrl,
  );
}

V2TimConversation resolveSearchC2cConversation({
  required V2TimFriendInfo? friendInfo,
  Map<String, V2TimConversation>? conversationByUserId,
}) {
  final userId = friendInfo?.userID.trim() ?? '';
  final cached = conversationByUserId?[userId];
  if (cached != null) {
    return cached;
  }
  return V2TimConversation(
    conversationID: 'c2c_$userId',
    userID: userId,
    type: 1,
    showName: memberDisplayName(
      friendRemark: friendInfo?.friendRemark,
      nickName: friendInfo?.userProfile?.nickName,
      userID: userId,
    ),
    faceUrl: friendInfo?.userProfile?.faceUrl ?? '',
  );
}

V2TimConversation resolveSearchGroupConversation({
  required V2TimGroupInfo group,
  Map<String, V2TimConversation>? conversationByGroupId,
}) {
  final groupId = group.groupID.trim();
  final groupName = (group.groupName ?? '').trim();
  final cached = conversationByGroupId == null
      ? null
      : lookupSearchGroupConversation(conversationByGroupId, groupId);
  if (cached != null) {
    final preferred = preferSearchGroupShowName(
      groupName: groupName,
      conversationShowName: cached.showName,
      groupId: groupId,
    );
    if (preferred.isNotEmpty &&
        preferred != (cached.showName?.trim() ?? '')) {
      cached.showName = preferred;
    }
    final face = (group.faceUrl ?? '').trim();
    if (face.isNotEmpty && (cached.faceUrl?.trim().isEmpty ?? true)) {
      cached.faceUrl = face;
    }
    return cached;
  }
  return V2TimConversation(
    conversationID: 'group_$groupId',
    groupID: groupId,
    type: 2,
    showName: preferSearchGroupShowName(
      groupName: groupName,
      conversationShowName: null,
      groupId: groupId,
    ),
    faceUrl: group.faceUrl ?? '',
  );
}

V2TimConversation? lookupCachedSearchConversation(
  Map<String, V2TimConversation>? conversationById,
  String conversationId,
) {
  final id = conversationId.trim();
  if (id.isEmpty || conversationById == null || conversationById.isEmpty) {
    return null;
  }
  final exact = conversationById[id];
  if (exact != null) {
    return exact;
  }
  final prefixed = conversationById['group_$id'];
  if (prefixed != null) {
    return prefixed;
  }
  if (id.toLowerCase().startsWith('group_')) {
    final bare = id.substring(6);
    final byBare = conversationById[bare];
    if (byBare != null) {
      return byBare;
    }
  }
  for (final entry in conversationById.entries) {
    if (searchGroupIdsEquivalent(entry.key, id)) {
      return entry.value;
    }
    final gid = entry.value.groupID?.trim() ?? '';
    if (gid.isNotEmpty &&
        (searchGroupIdsEquivalent(gid, id) ||
            searchGroupIdsEquivalent(gid, searchStripConversationPrefix(id)))) {
      return entry.value;
    }
  }
  return null;
}

V2TimConversation resolveSearchConversationById({
  required String conversationId,
  Map<String, V2TimConversation>? conversationById,
  String? showName,
  String? faceUrl,
}) {
  final id = conversationId.trim();
  final cached = lookupCachedSearchConversation(conversationById, id);
  if (cached != null) {
    return cached;
  }
  if (id.toLowerCase().startsWith('c2c_')) {
    final userId = id.substring(4).trim();
    return V2TimConversation(
      conversationID: id,
      userID: userId,
      type: 1,
      showName: showName?.trim().isNotEmpty == true ? showName : userId,
      faceUrl: faceUrl ?? '',
    );
  }
  if (isGroupConversationId(id)) {
    final groupId = groupIdFromConversationId(id) ?? searchStripConversationPrefix(id);
    return V2TimConversation(
      conversationID: id.toLowerCase().startsWith('group_') ? id : 'group_$groupId',
      groupID: groupId,
      type: 2,
      showName: showName?.trim().isNotEmpty == true ? showName : groupId,
      faceUrl: faceUrl ?? '',
    );
  }
  return V2TimConversation(
    conversationID: id,
    showName: showName?.trim().isNotEmpty == true ? showName : id,
    faceUrl: faceUrl ?? '',
  );
}

/// 群发送者/成员展示名：备注(含 Store) > 群名片 > 昵称 > userID。
String memberDisplayName({
  String? friendRemark,
  String? nameCard,
  String? nickName,
  String? storeName,
  String? userID,
}) {
  return resolveGroupSenderShowName(
    friendRemark: friendRemark,
    nameCard: nameCard,
    nickName: nickName,
    storeName: storeName,
    userID: userID,
  );
}

/// 群聊气泡/成员名统一解析。
/// 本地资料真源优先：本地备注 > IM备注 > 群名片 > 本地昵称 > Store > IM昵称 > userID。
@visibleForTesting
String resolveGroupSenderShowName({
  String? friendRemark,
  String? nameCard,
  String? nickName,
  String? storeName,
  String? userID,
}) {
  bool usable(String? value) {
    final text = value?.trim() ?? '';
    return text.isNotEmpty &&
        !DisplayNameStore.isRawUserIdDisplayName(userID, text);
  }

  final local = UserProfileLocalBridge.readCached(userID);
  final localRemark = local?.remark.trim() ?? '';
  if (usable(localRemark)) {
    return localRemark;
  }
  final remark = friendRemark?.trim() ?? '';
  if (usable(remark)) {
    return remark;
  }
  final card = nameCard?.trim() ?? '';
  if (usable(card)) {
    return card;
  }
  final localNick = local?.nickname.trim() ?? '';
  if (usable(localNick)) {
    return localNick;
  }
  final store = (storeName?.trim().isNotEmpty == true)
      ? storeName!.trim()
      : (DisplayNameStore.instance.c2c(userID ?? '')?.trim() ?? '');
  if (usable(store)) {
    return store;
  }
  final nick = nickName?.trim() ?? '';
  if (usable(nick)) {
    return nick;
  }
  return userID?.trim() ?? '';
}

/// 群聊气泡展示名短时缓存：同一 sender 输入指纹未变则复用解析结果。
class GroupSenderDisplayNameCache {
  final Map<String, ({String fingerprint, String name})> _entries =
      <String, ({String fingerprint, String name})>{};

  static String fingerprint({
    String? friendRemark,
    String? nameCard,
    String? nickName,
    String? storeName,
    String? localRemark,
    String? localNickname,
  }) {
    return '${localRemark?.trim() ?? ''}\u0001'
        '${friendRemark?.trim() ?? ''}\u0001'
        '${nameCard?.trim() ?? ''}\u0001'
        '${localNickname?.trim() ?? ''}\u0001'
        '${nickName?.trim() ?? ''}\u0001'
        '${storeName?.trim() ?? ''}';
  }

  String? lookup(String userID, String fingerprint) {
    final id = userID.trim();
    if (id.isEmpty) {
      return null;
    }
    final entry = _entries[id];
    if (entry == null || entry.fingerprint != fingerprint) {
      return null;
    }
    return entry.name;
  }

  void put(String userID, String fingerprint, String name) {
    final id = userID.trim();
    final resolved = name.trim();
    if (id.isEmpty || resolved.isEmpty) {
      return;
    }
    _entries[id] = (fingerprint: fingerprint, name: resolved);
  }

  void invalidate(String userID) {
    _entries.remove(userID.trim());
  }

  void clear() {
    _entries.clear();
  }

  @visibleForTesting
  int get debugEntryCount => _entries.length;
}

/// 字母索引标签：英文昵称取首字母；中文等取昵称首字拼音首字母。
String memberSuspensionIndexTag(String showName) {
  final name = showName.trim();
  if (name.isEmpty) {
    return '#';
  }

  final firstChar = name[0];
  if (RegExp(r'[A-Za-z]').hasMatch(firstChar)) {
    return firstChar.toUpperCase();
  }

  final firstWordPinyin = PinyinHelper.getFirstWordPinyin(name);
  if (firstWordPinyin.isNotEmpty) {
    final letter = firstWordPinyin[0].toUpperCase();
    if (RegExp(r'[A-Z]').hasMatch(letter)) {
      return letter;
    }
  }

  final shortPinyin = PinyinHelper.getShortPinyin(name);
  for (var i = 0; i < shortPinyin.length; i++) {
    final c = shortPinyin[i];
    if (RegExp(r'[A-Za-z]').hasMatch(c)) {
      return c.toUpperCase();
    }
  }

  return '#';
}

bool groupMemberMatchesKeyword(
  V2TimGroupMemberFullInfo? member,
  String keyword,
) {
  if (member == null) {
    return false;
  }
  final normalized = keyword.trim().toLowerCase();
  if (normalized.isEmpty) {
    return true;
  }
  final name = memberDisplayName(
    friendRemark: member.friendRemark,
    nameCard: member.nameCard,
    nickName: member.nickName,
    userID: member.userID,
  );
  final pinyin = PinyinHelper.getPinyinE(name).toLowerCase();
  final haystack = '${member.userID} $name $pinyin'.toLowerCase();
  return haystack.contains(normalized);
}

List<V2TimGroupMemberFullInfo?> filterGroupMembersByKeyword(
  Iterable<V2TimGroupMemberFullInfo?> members,
  String keyword,
) {
  final normalized = keyword.trim().toLowerCase();
  if (normalized.isEmpty) {
    return members.toList();
  }
  return members
      .where((member) => groupMemberMatchesKeyword(member, normalized))
      .toList();
}

/// 合并群成员列表：按 userID 去重，后写入覆盖先写入，顺序保留已有成员再追加新成员。
List<V2TimGroupMemberFullInfo> mergeGroupMembersPreferIncoming(
  List<V2TimGroupMemberFullInfo> existing,
  List<V2TimGroupMemberFullInfo> incoming,
) {
  if (incoming.isEmpty) {
    return List<V2TimGroupMemberFullInfo>.from(existing);
  }
  if (existing.isEmpty) {
    return List<V2TimGroupMemberFullInfo>.from(incoming);
  }
  final byId = <String, V2TimGroupMemberFullInfo>{};
  final order = <String>[];
  void put(V2TimGroupMemberFullInfo member) {
    final id = member.userID?.trim() ?? '';
    if (id.isEmpty) {
      return;
    }
    if (!byId.containsKey(id)) {
      order.add(id);
    }
    byId[id] = member;
  }

  for (final member in existing) {
    put(member);
  }
  for (final member in incoming) {
    put(member);
  }
  return [for (final id in order) byId[id]!];
}

bool friendMatchesKeyword(V2TimFriendInfo item, String keyword) {
  final normalized = keyword.trim().toLowerCase();
  if (normalized.isEmpty) {
    return true;
  }
  final name = memberDisplayName(
    friendRemark: item.friendRemark,
    nickName: item.userProfile?.nickName,
    userID: item.userID,
  );
  final pinyin = PinyinHelper.getPinyinE(name).toLowerCase();
  final haystack = '${item.userID} $name $pinyin'.toLowerCase();
  return haystack.contains(normalized);
}

List<V2TimFriendInfo> filterFriendsByKeyword(
  Iterable<V2TimFriendInfo> friends,
  String keyword,
) {
  final normalized = keyword.trim().toLowerCase();
  if (normalized.isEmpty) {
    return friends.toList();
  }
  return friends
      .where((item) => friendMatchesKeyword(item, normalized))
      .toList();
}
