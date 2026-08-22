import 'package:flutter_test/flutter_test.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_friend_info.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_user_full_info.dart';
import 'package:tencent_cloud_chat_uikit/data_services/profile/user_profile_local_bridge.dart';

void main() {
  group('UserProfileLocalBridge.mergeImPublicProfile', () {
    test('fills signature without overwriting hosted nick/avatar/remark', () {
      final hosted = V2TimFriendInfo(
        userID: 'u1',
        friendRemark: '备注',
        userProfile: V2TimUserFullInfo(
          userID: 'u1',
          nickName: '本地昵称',
          faceUrl: 'https://local/a.png',
        ),
      );
      final merged = UserProfileLocalBridge.mergeImPublicProfile(
        userId: 'u1',
        info: hosted,
        im: V2TimUserFullInfo(
          userID: 'u1',
          nickName: 'IM昵称',
          faceUrl: 'https://im/a.png',
          selfSignature: '今日宜摸鱼',
          gender: 1,
          birthday: 19900101,
        ),
      );

      expect(merged.friendRemark, '备注');
      expect(merged.userProfile?.nickName, '本地昵称');
      expect(merged.userProfile?.faceUrl, 'https://local/a.png');
      expect(merged.userProfile?.selfSignature, '今日宜摸鱼');
      expect(merged.userProfile?.gender, 1);
      expect(merged.userProfile?.birthday, 19900101);
    });

    test('empty IM signature keeps existing', () {
      final hosted = V2TimFriendInfo(
        userID: 'u1',
        userProfile: V2TimUserFullInfo(
          userID: 'u1',
          selfSignature: '已有签名',
        ),
      );
      final merged = UserProfileLocalBridge.mergeImPublicProfile(
        userId: 'u1',
        info: hosted,
        im: V2TimUserFullInfo(
          userID: 'u1',
          selfSignature: '   ',
        ),
      );
      expect(merged.userProfile?.selfSignature, '已有签名');
    });

    test('null IM leaves hosted profile unchanged', () {
      final hosted = V2TimFriendInfo(
        userID: 'u1',
        userProfile: V2TimUserFullInfo(
          userID: 'u1',
          nickName: '小明',
        ),
      );
      final merged = UserProfileLocalBridge.mergeImPublicProfile(
        userId: 'u1',
        info: hosted,
        im: null,
      );
      expect(merged.userProfile?.nickName, '小明');
      expect(merged.userProfile?.selfSignature, isNull);
    });
  });
}
