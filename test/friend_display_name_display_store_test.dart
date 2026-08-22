import 'package:flutter_test/flutter_test.dart';
import 'package:tencent_cloud_chat_demo/utils/friend_display_name.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_friend_info.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_friend_info.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_user_full_info.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_user_full_info.dart';
import 'package:tencent_cloud_chat_uikit/business_logic/services/display_name_store.dart';

void main() {
  tearDown(() {
    DisplayNameStore.instance.clear(notify: false);
  });

  group('DisplayNameStore.resolveImSyncShowName', () {
    test('non-empty IM remark always wins', () {
      expect(
        DisplayNameStore.resolveImSyncShowName(
          imRemark: '新备注',
          imNickName: '昵称',
          userID: 'u1',
          existingStoreName: '旧备注',
        ),
        '新备注',
      );
    });

    test('empty IM remark keeps existing store (no nick downgrade)', () {
      expect(
        DisplayNameStore.resolveImSyncShowName(
          imRemark: '',
          imNickName: '昵称',
          userID: 'u1',
          existingStoreName: '本地备注',
        ),
        isNull,
      );
    });

    test('empty store + empty remark falls back to nick', () {
      expect(
        DisplayNameStore.resolveImSyncShowName(
          imRemark: '',
          imNickName: '昵称',
          userID: 'u1',
          existingStoreName: null,
        ),
        '昵称',
      );
    });

    test('empty remark and nick does not persist userID', () {
      expect(
        DisplayNameStore.resolveImSyncShowName(
          imRemark: '',
          imNickName: '',
          userID: 'u1',
          existingStoreName: null,
        ),
        isNull,
      );
      expect(
        DisplayNameStore.instance.applyImFriendShowName(
          userID: 'u1',
          imRemark: '',
          imNickName: '',
          notify: false,
        ),
        isFalse,
      );
      expect(DisplayNameStore.instance.c2c('u1'), isNull);
    });

    test('store equal to userID is treated as empty so nick can apply', () {
      expect(
        DisplayNameStore.resolveImSyncShowName(
          imRemark: '',
          imNickName: '张三',
          userID: 'u1',
          existingStoreName: 'u1',
        ),
        '张三',
      );
    });

    test('setC2C rejects userID as display name', () {
      DisplayNameStore.instance.setC2C('alice', 'alice', notify: false);
      expect(DisplayNameStore.instance.c2c('alice'), isNull);
      DisplayNameStore.instance.setC2C('alice', '张三', notify: false);
      expect(DisplayNameStore.instance.c2c('alice'), '张三');
      DisplayNameStore.instance.setC2C('alice', 'alice', notify: false);
      expect(DisplayNameStore.instance.c2c('alice'), isNull);
      expect(DisplayNameStore.instance.snapshotC2C().containsKey('alice'), isFalse);
    });

    test('applyImFriendShowName does not overwrite existing with nick', () {
      DisplayNameStore.instance.setC2C('u1', '本地备注', notify: false);
      final changed = DisplayNameStore.instance.applyImFriendShowName(
        userID: 'u1',
        imRemark: '',
        imNickName: '昵称',
        notify: false,
      );
      expect(changed, isFalse);
      expect(DisplayNameStore.instance.c2c('u1'), '本地备注');
    });
  });

  group('FriendDisplayName.resolveC2C', () {
    test('prefers DisplayNameStore over friendRemark', () {
      DisplayNameStore.instance.setC2C('alice', 'Store备注', notify: false);
      final friend = V2TimFriendInfo(
        userID: 'alice',
        friendRemark: '旧备注',
        userProfile: V2TimUserFullInfo(userID: 'alice', nickName: '昵称'),
      );
      expect(
        FriendDisplayName.resolveC2C(
          userId: 'alice',
          conversationShowName: '会话名',
          friendList: <V2TimFriendInfo>[friend],
        ),
        'Store备注',
      );
    });

    test('falls back to friendRemark when Store empty', () {
      final friend = V2TimFriendInfo(
        userID: 'bob',
        friendRemark: '好友备注',
        userProfile: V2TimUserFullInfo(userID: 'bob', nickName: '昵称'),
      );
      expect(
        FriendDisplayName.resolveC2C(
          userId: 'bob',
          conversationShowName: '会话名',
          friendList: <V2TimFriendInfo>[friend],
        ),
        '好友备注',
      );
    });

    test('insurance: store equals nick while friend has remark → remark', () {
      DisplayNameStore.instance.setC2C('carol', '昵称X', notify: false);
      final friend = V2TimFriendInfo(
        userID: 'carol',
        friendRemark: '备注X',
        userProfile: V2TimUserFullInfo(userID: 'carol', nickName: '昵称X'),
      );
      expect(
        FriendDisplayName.resolveC2C(
          userId: 'carol',
          conversationShowName: '会话名',
          friendList: <V2TimFriendInfo>[friend],
        ),
        '备注X',
      );
    });
  });
}
