import 'package:tencent_cloud_chat_demo/src/services/group_local/group_local_store.dart';
import 'package:tencent_cloud_chat_demo/src/services/group_local/group_member_local_store.dart';
import 'package:tencent_cloud_chat_demo/src/services/user_profile_local/user_profile_local_service.dart';
import 'package:tencent_cloud_chat_demo/utils/chat_id_format.dart';
import 'package:tencent_cloud_chat_demo/utils/friend_display_name.dart';
import 'package:tencent_cloud_chat_sdk/tencent_im_sdk_plugin.dart';
import 'package:tencent_cloud_chat_uikit/business_logic/services/display_name_store.dart';
import 'package:tencent_cloud_chat_uikit/tencent_cloud_chat_uikit.dart';

/// 转账详情双方展示名：备注/群名片/昵称优先，绝不把裸 userId 当昵称展示。
class TransferPartyNameResolver {
  TransferPartyNameResolver._();

  static bool isRawUserId(String? text, {String? userId}) {
    final value = text?.trim() ?? '';
    if (value.isEmpty) {
      return true;
    }
    final id = ChatIdFormat.rawUserUid(userId);
    if (id.isNotEmpty && value == id) {
      return true;
    }
    // 后端偶发把 userId 填进 name 字段；若 hint 本身可被规范成 uid 且等于自身，视为裸 ID。
    final asUid = ChatIdFormat.rawUserUid(value);
    return asUid.isNotEmpty && asUid == value && !_looksLikeHumanNick(value);
  }

  static bool _looksLikeHumanNick(String value) {
    // 含中文、空格、emoji/符号时更像昵称；纯短小写数字字母更像内部 uid。
    if (RegExp(r'[\u4e00-\u9fff]').hasMatch(value)) {
      return true;
    }
    if (RegExp(r'\s').hasMatch(value)) {
      return true;
    }
    if (value.length <= 2) {
      return true;
    }
    return !RegExp(r'^[a-z0-9_]{6,32}$').hasMatch(value);
  }

  static String groupNameOf(String? groupId) {
    final gid = groupId?.trim() ?? '';
    if (gid.isEmpty) {
      return '';
    }
    try {
      final fromStore = DisplayNameStore.instance.group(gid)?.trim() ?? '';
      if (fromStore.isNotEmpty) {
        return fromStore;
      }
    } catch (_) {}
    try {
      final fromLocal =
          GroupLocalStore.instance.readCached(groupId: gid)?.groupName.trim() ??
              '';
      if (fromLocal.isNotEmpty) {
        return fromLocal;
      }
    } catch (_) {}
    return '';
  }

  static bool isGroupDisplayName(String? text, {String? groupId}) {
    final value = text?.trim() ?? '';
    if (value.isEmpty) {
      return false;
    }
    final groupName = groupNameOf(groupId);
    return groupName.isNotEmpty && value == groupName;
  }

  /// 后端 / 旧卡片偶发把「京444444群转账转我」整段塞进收款人昵称。
  static String sanitizeDisplayName(
    String? text, {
    String? userId,
    String? groupId,
  }) {
    var value = text?.trim() ?? '';
    if (value.isEmpty) {
      return '';
    }
    for (final marker in const ['群转账', '群轉帳']) {
      final idx = value.indexOf(marker);
      if (idx >= 0) {
        value = value.substring(0, idx).trim();
        break;
      }
    }
    const transferToHans = '转账给';
    const transferToHant = '轉帳給';
    if (value.startsWith(transferToHans)) {
      value = value.substring(transferToHans.length).trim();
    } else if (value.startsWith(transferToHant)) {
      value = value.substring(transferToHant.length).trim();
    }
    if (value.isEmpty ||
        isRawUserId(value, userId: userId) ||
        isGroupDisplayName(value, groupId: groupId)) {
      return '';
    }
    return value;
  }

  /// 专属红包 / 群转账：只用用户昵称，不用好友备注、群名片、会话展示名。
  static String nicknameOf({
    required String userId,
    String? nickHint,
  }) {
    final id = ChatIdFormat.rawUserUid(userId);
    if (id.isEmpty) {
      return sanitizeDisplayName(nickHint);
    }
    try {
      final localNick =
          UserProfileLocalService.instance.readCached(id)?.nickname.trim() ??
              '';
      final cleanedLocal = sanitizeDisplayName(localNick, userId: id);
      if (cleanedLocal.isNotEmpty) {
        return cleanedLocal;
      }
    } catch (_) {}
    return sanitizeDisplayName(nickHint, userId: id);
  }

  static Future<String> resolveNickname({
    required String userId,
    String nickHint = '',
  }) async {
    final id = ChatIdFormat.rawUserUid(userId);
    if (id.isEmpty) {
      return sanitizeDisplayName(nickHint);
    }
    try {
      final localNick =
          UserProfileLocalService.instance.readCached(id)?.nickname.trim() ??
              '';
      final cleanedLocal = sanitizeDisplayName(localNick, userId: id);
      if (cleanedLocal.isNotEmpty) {
        return cleanedLocal;
      }
    } catch (_) {}
    try {
      final res = await TencentImSDKPlugin.v2TIMManager.getUsersInfo(
        userIDList: <String>[id],
      );
      final nick = res.data?.isNotEmpty == true
          ? (res.data!.first.nickName?.trim() ?? '')
          : '';
      final cleaned = sanitizeDisplayName(nick, userId: id);
      if (cleaned.isNotEmpty) {
        return cleaned;
      }
    } catch (_) {}
    return sanitizeDisplayName(nickHint, userId: id);
  }

  static String pickPreferredName({
    required List<Object?> candidates,
    String userId = '',
    String? groupId,
  }) {
    final id = ChatIdFormat.rawUserUid(userId);
    for (final candidate in candidates) {
      final text = sanitizeDisplayName(
        candidate?.toString(),
        userId: id,
        groupId: groupId,
      );
      if (text.isEmpty) {
        continue;
      }
      return text;
    }
    return '';
  }

  static Future<String> resolve({
    String nameHint = '',
    String userId = '',
    String? groupId,
  }) async {
    final hint = nameHint.trim();
    final id = ChatIdFormat.rawUserUid(
      userId.trim().isNotEmpty
          ? userId
          : (isRawUserId(hint) ? hint : ''),
    );

    if (id.isNotEmpty) {
      final fromFriend = FriendDisplayName.resolveC2C(userId: id).trim();
      if (fromFriend.isNotEmpty &&
          !isRawUserId(fromFriend, userId: id) &&
          !isGroupDisplayName(fromFriend, groupId: groupId)) {
        return fromFriend;
      }

      final gid = groupId?.trim() ?? '';
      if (gid.isNotEmpty) {
        try {
          final owner = TIMUIKitCore.getInstance().loginInfo.userID.trim();
          final member = await GroupMemberLocalStore.instance.readRecord(
            groupId: gid,
            userId: id,
            ownerUserId: owner.isEmpty ? null : owner,
          );
          final memberName = member?.displayName.trim() ?? '';
          if (memberName.isNotEmpty &&
              !isRawUserId(memberName, userId: id) &&
              !isGroupDisplayName(memberName, groupId: groupId)) {
            return memberName;
          }
        } catch (_) {}
      }

      try {
        final res = await TencentImSDKPlugin.v2TIMManager.getUsersInfo(
          userIDList: <String>[id],
        );
        final nick = res.data?.isNotEmpty == true
            ? (res.data!.first.nickName?.trim() ?? '')
            : '';
        if (nick.isNotEmpty &&
            !isRawUserId(nick, userId: id) &&
            !isGroupDisplayName(nick, groupId: groupId)) {
          return nick;
        }
      } catch (_) {}
    }

    if (hint.isNotEmpty && !isGroupDisplayName(hint, groupId: groupId)) {
      final cleaned = sanitizeDisplayName(
        hint,
        userId: id,
        groupId: groupId,
      );
      if (cleaned.isNotEmpty) {
        return cleaned;
      }
    }
    return id;
  }

  static Future<(String sender, String receiver)> resolvePair({
    required String senderName,
    required String receiverName,
    String senderUserId = '',
    String receiverUserId = '',
    String? groupId,
  }) async {
    final results = await Future.wait<String>([
      resolve(
        nameHint: senderName,
        userId: senderUserId,
        groupId: groupId,
      ),
      resolve(
        nameHint: receiverName,
        userId: receiverUserId,
        groupId: groupId,
      ),
    ]);
    return (results[0], results[1]);
  }
}
