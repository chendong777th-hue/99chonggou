import 'package:flutter_test/flutter_test.dart';
import 'package:tencent_cloud_chat_demo/src/api/me_friend_api.dart';
import 'package:tencent_cloud_chat_demo/src/models/user_profile_record.dart';
import 'package:tencent_cloud_chat_demo/src/utils/friend_display_fields_merge.dart';

MeFriendRecord _friend({
  required String id,
  String remark = '',
  String nickname = '',
  String avatar = '',
}) {
  return MeFriendRecord(
    friendUserId: id,
    remark: remark,
    friendNickname: nickname,
    friendAvatarUrl: avatar,
    addedAt: 1,
    peerDeletedMe: false,
    canMessage: true,
  );
}

void main() {
  group('FriendDisplayFieldsMerge', () {
    test('restores remark and nickname from profile on re-add shell', () {
      final merged = FriendDisplayFieldsMerge.merge(
        incoming: _friend(id: 'u1'),
        previous: null,
        profile: UserProfileRecord(
          userId: 'u1',
          nickname: '公开昵称',
          friendRemark: '旧备注',
        ),
      );
      expect(merged.remark, '旧备注');
      expect(merged.friendNickname, '公开昵称');
    });

    test('incoming non-empty wins over profile', () {
      final merged = FriendDisplayFieldsMerge.merge(
        incoming: _friend(id: 'u1', remark: '新备注', nickname: '新昵称'),
        profile: UserProfileRecord(
          userId: 'u1',
          nickname: '旧昵称',
          friendRemark: '旧备注',
        ),
      );
      expect(merged.remark, '新备注');
      expect(merged.friendNickname, '新昵称');
    });

    test('sync empty nickname does not wipe local nickname', () {
      final merged = FriendDisplayFieldsMerge.mergeListPreservingLocalNames(
        incoming: [_friend(id: 'u1', remark: '', nickname: '')],
        previous: [_friend(id: 'u1', remark: '备', nickname: '昵')],
      );
      expect(merged.single.remark, '备');
      expect(merged.single.friendNickname, '昵');
    });
  });
}
