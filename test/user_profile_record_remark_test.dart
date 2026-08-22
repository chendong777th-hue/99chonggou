import 'package:flutter_test/flutter_test.dart';
import 'package:tencent_cloud_chat_demo/src/models/user_profile_record.dart';
import 'package:tencent_cloud_chat_demo/utils/friend_remark_policy.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_friend_info.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_user_full_info.dart';

void main() {
  group('UserProfileRecord remark', () {
    test('copyWith empty remark actually clears', () {
      final record = UserProfileRecord(
        userId: 'u1',
        friendRemark: '棒棒糖',
      );
      final cleared = record.copyWith(friendRemark: '');
      expect(cleared.friendRemark, '');
    });

    test('SDK merge keeps locally cleared remark', () {
      final local = UserProfileRecord(
        userId: 'u1',
        nickname: '小明',
        friendRemark: '',
      );
      final merged = local.mergeSdkRemotePreferLocal(
        V2TimFriendInfo(
          userID: 'u1',
          friendRemark: '棒棒糖',
          userProfile: V2TimUserFullInfo(
            userID: 'u1',
            nickName: '小明',
          ),
        ),
      );
      expect(merged.friendRemark, '');
      expect(merged.nickname, '小明');
    });

    test('SDK merge replaces local nick and avatar when remote non-empty', () {
      final local = UserProfileRecord(
        userId: 'u1',
        nickname: '旧昵称',
        avatarUrl: 'https://old.example/a.png',
        friendRemark: '备注',
      );
      final merged = local.mergeSdkRemotePreferLocal(
        V2TimFriendInfo(
          userID: 'u1',
          friendRemark: 'IM脏备注',
          userProfile: V2TimUserFullInfo(
            userID: 'u1',
            nickName: '新昵称',
            faceUrl: 'https://new.example/b.png',
          ),
        ),
      );
      expect(merged.nickname, '新昵称');
      expect(merged.avatarUrl, 'https://new.example/b.png');
      expect(merged.friendRemark, '备注');
    });

    test('SDK merge keeps local nick/avatar when remote empty', () {
      final local = UserProfileRecord(
        userId: 'u1',
        nickname: '本地昵称',
        avatarUrl: 'https://local.example/a.png',
      );
      final merged = local.mergeSdkRemoteUserInfoPreferLocal(
        V2TimUserFullInfo(userID: 'u1', nickName: '', faceUrl: ''),
      );
      expect(merged.nickname, '本地昵称');
      expect(merged.avatarUrl, 'https://local.example/a.png');
    });
  });

  group('FriendRemarkPolicy', () {
    test('max length is 30', () {
      expect(FriendRemarkPolicy.maxLength, 30);
      expect(FriendRemarkPolicy.isLengthValid('测' * 30), isTrue);
      expect(FriendRemarkPolicy.isLengthValid('测' * 31), isFalse);
      expect(FriendRemarkPolicy.isLengthValid('a' * 30), isTrue);
      expect(FriendRemarkPolicy.isLengthValid('a' * 31), isFalse);
    });

    test('strips line breaks before validating length', () {
      expect(FriendRemarkPolicy.stripLineBreaks('你好\n世界'), '你好世界');
      expect(FriendRemarkPolicy.stripLineBreaks('a\r\nb'), 'ab');
      expect(FriendRemarkPolicy.isLengthValid('测\n试'), isTrue);
    });
  });
}
