import 'package:tencent_cloud_chat_demo/src/i18n/app_i18n.dart';
import 'package:tencent_cloud_chat_demo/src/models/me_group_record.dart';
import 'package:tencent_cloud_chat_demo/utils/chat_id_format.dart';
import 'package:tencent_cloud_chat_demo/utils/group_privacy_guard.dart';

/// 群成员入群时间 / 邀请人展示与可见性。
class GroupMemberJoinMeta {
  GroupMemberJoinMeta._();

  static const joinChannelInvite = 'invite';
  static const joinChannelGroupId = 'group_id';

  /// 隐私关：全员可见；隐私开：仅群主/管理员。
  static Future<bool> canView({required String groupId}) async {
    final gid = groupId.trim();
    if (gid.isEmpty) {
      return false;
    }
    final privacyOn =
        await GroupPrivacyCache.privacyProtectionEnabled(gid);
    if (!privacyOn) {
      return true;
    }
    return GroupPrivacyGuard.isCurrentUserGroupManager(gid);
  }

  static String? formatJoinedAt(int joinedAtMs, {AppI18n? i18n}) {
    if (joinedAtMs <= 0) {
      return null;
    }
    final dt = DateTime.fromMillisecondsSinceEpoch(joinedAtMs).toLocal();
    final y = dt.year.toString().padLeft(4, '0');
    final m = dt.month.toString().padLeft(2, '0');
    final d = dt.day.toString().padLeft(2, '0');
    final hh = dt.hour.toString().padLeft(2, '0');
    final mm = dt.minute.toString().padLeft(2, '0');
    return '$y-$m-$d $hh:$mm';
  }

  /// 来源文案；null 表示不展示来源行。
  static String? formatJoinSource(GroupMemberRecord record, {AppI18n? i18n}) {
    final channel = record.joinChannel.trim().toLowerCase();
    final lang = i18n ?? AppI18n.current;
    if (channel == joinChannelGroupId) {
      return lang.t(
        zhHans: '通过群ID加入',
        zhHant: '透過群ID加入',
        en: 'Joined via group ID',
        ja: 'グループIDで参加',
        ko: '그룹 ID로 가입',
      );
    }
    if (channel == joinChannelInvite) {
      final name = inviterDisplayName(record);
      if (name == null || name.isEmpty) {
        return lang.t(
          zhHans: '邀请加入',
          zhHant: '邀請加入',
          en: 'Invited',
          ja: '招待で参加',
          ko: '초대로 가입',
        );
      }
      return lang.t(
        zhHans: '由 $name 邀请',
        zhHant: '由 $name 邀請',
        en: 'Invited by $name',
        ja: '$name が招待',
        ko: '$name 님이 초대',
      );
    }
    return null;
  }

  static String? inviterDisplayName(GroupMemberRecord record) {
    final nick = record.invitedByNickname.trim();
    if (nick.isNotEmpty) {
      return nick;
    }
    final id = ChatIdFormat.rawUserUid(record.invitedByUserId);
    return id.isEmpty ? null : id;
  }

  static bool inviterTappable(GroupMemberRecord record) {
    if (record.joinChannel.trim().toLowerCase() != joinChannelInvite) {
      return false;
    }
    return ChatIdFormat.rawUserUid(record.invitedByUserId).isNotEmpty;
  }

  static bool hasAnyDisplayRow(GroupMemberRecord record) {
    return formatJoinedAt(record.joinedAt) != null ||
        formatJoinSource(record) != null;
  }
}
