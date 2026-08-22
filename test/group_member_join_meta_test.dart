import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:tencent_cloud_chat_demo/src/models/me_group_record.dart';
import 'package:tencent_cloud_chat_demo/src/services/group_local/group_member_local_store.dart';
import 'package:tencent_cloud_chat_demo/utils/group_member_join_meta.dart';
import 'package:tencent_cloud_chat_demo/utils/group_privacy_guard.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  tearDown(() async {
    await GroupMemberLocalStore.instance.clearForOwner('owner-join-meta');
  });

  group('GroupMemberRecord.fromJson invite fields', () {
    test('parses camelCase invite / group_id / joinedAt ms', () {
      final record = GroupMemberRecord.fromJson(<String, dynamic>{
        'userId': 'u1',
        'nickname': 'N1',
        'avatarUrl': '',
        'friendRemark': '',
        'nameCard': '',
        'role': 200,
        'joinedAt': 1700000000000,
        'isSelf': false,
        'invitedByUserId': 'inviter1',
        'invitedByNickname': '邀请人',
        'joinChannel': 'invite',
      });
      expect(record.joinedAt, 1700000000000);
      expect(record.invitedByUserId, 'inviter1');
      expect(record.invitedByNickname, '邀请人');
      expect(record.joinChannel, 'invite');
    });

    test('parses snake_case and normalizes joinChannel', () {
      final viaId = GroupMemberRecord.fromJson(<String, dynamic>{
        'user_id': 'u2',
        'joined_at': 1700000000, // seconds → ms
        'invited_by_user_id': null,
        'invited_by_nickname': null,
        'join_channel': 'group_id',
      });
      expect(viaId.joinedAt, 1700000000000);
      expect(viaId.invitedByUserId, '');
      expect(viaId.joinChannel, 'group_id');

      final unknown = GroupMemberRecord.fromJson(<String, dynamic>{
        'userId': 'u3',
        'joinChannel': 'weird',
      });
      expect(unknown.joinChannel, '');
    });
  });

  group('GroupMemberJoinMeta display helpers', () {
    test('formatJoinedAt hides non-positive', () {
      expect(GroupMemberJoinMeta.formatJoinedAt(0), isNull);
      expect(GroupMemberJoinMeta.formatJoinedAt(-1), isNull);
      final text = GroupMemberJoinMeta.formatJoinedAt(1700000000000);
      expect(text, isNotNull);
      expect(text!.contains('-'), isTrue);
    });

    test('formatJoinSource invite / group_id / null', () {
      final invite = GroupMemberRecord(
        userId: 'u',
        nickname: '',
        avatarUrl: '',
        friendRemark: '',
        nameCard: '',
        role: 200,
        joinedAt: 1,
        isSelf: false,
        invitedByUserId: 'boss',
        invitedByNickname: '老板',
        joinChannel: 'invite',
      );
      expect(
        GroupMemberJoinMeta.formatJoinSource(invite),
        contains('老板'),
      );

      final viaId = invite.copyWith(
        joinChannel: 'group_id',
        invitedByUserId: '',
        invitedByNickname: '',
      );
      final viaIdText = GroupMemberJoinMeta.formatJoinSource(viaId);
      expect(viaIdText, isNotNull);
      expect(
        viaIdText!.contains('群ID') || viaIdText.toLowerCase().contains('group id'),
        isTrue,
      );

      final hist = invite.copyWith(joinChannel: '');
      expect(GroupMemberJoinMeta.formatJoinSource(hist), isNull);
    });

    test('inviterTappable requires invite channel + userId', () {
      final withId = GroupMemberRecord(
        userId: 'u',
        nickname: '',
        avatarUrl: '',
        friendRemark: '',
        nameCard: '',
        role: 200,
        joinedAt: 1,
        isSelf: false,
        invitedByUserId: 'inv',
        invitedByNickname: '名',
        joinChannel: 'invite',
      );
      expect(GroupMemberJoinMeta.inviterTappable(withId), isTrue);

      final noId = withId.copyWith(invitedByUserId: '');
      expect(GroupMemberJoinMeta.inviterTappable(noId), isFalse);

      final viaId = withId.copyWith(joinChannel: 'group_id');
      expect(GroupMemberJoinMeta.inviterTappable(viaId), isFalse);
    });
  });

  group('GroupMemberJoinMeta.canView', () {
    test('empty groupId → false', () async {
      expect(await GroupMemberJoinMeta.canView(groupId: ''), isFalse);
      expect(await GroupMemberJoinMeta.canView(groupId: '   '), isFalse);
    });

    test('privacy off → any member can view', () async {
      GroupPrivacyCache.set('g-privacy-off', false);
      expect(
        await GroupMemberJoinMeta.canView(groupId: 'g-privacy-off'),
        isTrue,
      );
    });
  });

  group('GroupMemberLocalStore invite columns', () {
    test('upsert/read preserves invite fields', () async {
      const owner = 'owner-join-meta';
      const groupId = 'g-join-meta';
      final record = GroupMemberRecord(
        userId: 'member1',
        nickname: 'M',
        avatarUrl: '',
        friendRemark: '',
        nameCard: '',
        role: 200,
        joinedAt: 1700000000000,
        isSelf: false,
        invitedByUserId: 'inviter9',
        invitedByNickname: 'Inv9',
        joinChannel: 'invite',
      );
      await GroupMemberLocalStore.instance.upsertMany(
        ownerUserId: owner,
        groupId: groupId,
        records: <GroupMemberRecord>[record],
      );
      final loaded = await GroupMemberLocalStore.instance.readRecord(
        groupId: groupId,
        userId: 'member1',
        ownerUserId: owner,
      );
      expect(loaded, isNotNull);
      expect(loaded!.invitedByUserId, 'inviter9');
      expect(loaded.invitedByNickname, 'Inv9');
      expect(loaded.joinChannel, 'invite');
      expect(loaded.joinedAt, 1700000000000);
    });
  });
}
