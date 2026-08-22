import 'package:tencent_cloud_chat_demo/src/api/me_friend_api.dart';
import 'package:tencent_cloud_chat_demo/src/models/user_profile_record.dart';
import 'package:tencent_cloud_chat_demo/utils/chat_id_format.dart';

/// 好友展示名字段合并：入站空值不覆盖本地已有备注/公开昵称。
class FriendDisplayFieldsMerge {
  FriendDisplayFieldsMerge._();

  /// 将 [incoming] 与 [previous]/[profile] 合并为可入库记录。
  ///
  /// 优先级：入站非空 > previous 非空 > profile 非空。
  static MeFriendRecord merge({
    required MeFriendRecord incoming,
    MeFriendRecord? previous,
    UserProfileRecord? profile,
  }) {
    final id = ChatIdFormat.rawUserUid(incoming.friendUserId);
    final remark = _firstNonEmpty([
      incoming.remark,
      previous?.remark,
      profile?.friendRemark,
    ]);
    final nickname = _firstNonEmpty([
      incoming.friendNickname,
      previous?.friendNickname,
      profile?.nickname,
    ]);
    final avatar = _firstNonEmpty([
      incoming.friendAvatarUrl,
      previous?.friendAvatarUrl,
      profile?.avatarUrl,
    ]);
    return incoming.copyWith(
      friendUserId: id.isNotEmpty ? id : incoming.friendUserId,
      remark: remark,
      friendNickname: nickname,
      friendAvatarUrl: avatar,
    );
  }

  /// 全量 sync 时：对每个入站项用旧表补空备注/昵称。
  static List<MeFriendRecord> mergeListPreservingLocalNames({
    required List<MeFriendRecord> incoming,
    required List<MeFriendRecord> previous,
    Map<String, UserProfileRecord>? profilesByUserId,
  }) {
    final prevById = <String, MeFriendRecord>{};
    for (final item in previous) {
      final id = ChatIdFormat.rawUserUid(item.friendUserId);
      if (id.isNotEmpty) {
        prevById[id] = item;
      }
    }
    return incoming
        .map((item) {
          final id = ChatIdFormat.rawUserUid(item.friendUserId);
          return merge(
            incoming: item,
            previous: prevById[id],
            profile: id.isEmpty ? null : profilesByUserId?[id],
          );
        })
        .toList(growable: false);
  }

  static String _firstNonEmpty(List<String?> values) {
    for (final value in values) {
      final text = value?.trim() ?? '';
      if (text.isNotEmpty) {
        return text;
      }
    }
    return '';
  }
}
