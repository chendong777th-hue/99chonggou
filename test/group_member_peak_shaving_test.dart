import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:tencent_cloud_chat_demo/src/models/me_group_record.dart';
import 'package:tencent_cloud_chat_demo/src/services/group_local/group_member_local_store.dart';
import 'package:tencent_cloud_chat_demo/src/services/group_local/group_membership_sync_service.dart';

GroupMemberRecord _member(
  String userId, {
  String nickname = 'nickname',
  int role = 200,
}) {
  return GroupMemberRecord(
    userId: userId,
    nickname: nickname,
    avatarUrl: 'avatar',
    friendRemark: 'remark',
    nameCard: 'card',
    role: role,
    joinedAt: 123,
    isSelf: false,
    muteUntil: 0,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  tearDown(() async {
    for (final owner in const [
      'group_member_diff_owner',
      'group_member_snapshot_owner',
      'owner',
    ]) {
      await GroupMemberLocalStore.instance.clearForOwner(owner);
    }
  });

  test('member diff writes only new or changed records', () {
    final unchanged = _member('user-a');
    final changed = _member('user-b', nickname: 'new');
    final added = _member('user-c');

    final result = GroupMemberLocalStore.groupMemberRecordsToUpsert(
      existing: [
        unchanged,
        _member('user-b', nickname: 'old'),
      ],
      normalized: [unchanged, changed, added],
    );

    expect(result, [changed, added]);
  });

  test('member upsert keeps unchanged rows and persists changed fields',
      () async {
    const owner = 'group_member_diff_owner';
    const group = '@TGS#GROUP_MEMBER_DIFF';

    await GroupMemberLocalStore.instance.upsertMany(
      ownerUserId: owner,
      groupId: group,
      records: [_member('user-a'), _member('user-b')],
    );
    await GroupMemberLocalStore.instance.upsertMany(
      ownerUserId: owner,
      groupId: group,
      records: [
        _member('user-a'),
        _member('user-b', nickname: 'changed'),
      ],
    );
    await GroupMemberLocalStore.instance.upsertMany(
      ownerUserId: owner,
      groupId: group,
      records: [
        _member('user-a'),
        _member('user-b', nickname: 'changed'),
      ],
    );

    final stored = await GroupMemberLocalStore.instance.readAll(
      ownerUserId: owner,
      groupId: group,
    );
    expect(stored, hasLength(2));
    expect(
      stored.singleWhere((record) => record.userId == 'user-a').nickname,
      'nickname',
    );
    expect(
      stored.singleWhere((record) => record.userId == 'user-b').nickname,
      'changed',
    );
  });

  test('complete member snapshot deletes missing and keeps unchanged rows',
      () async {
    const owner = 'group_member_snapshot_owner';
    const group = '@TGS#GROUP_MEMBER_SNAPSHOT';

    await GroupMemberLocalStore.instance.upsertMany(
      ownerUserId: owner,
      groupId: group,
      records: [_member('user-a'), _member('user-b')],
    );
    await GroupMemberLocalStore.instance.replaceSnapshot(
      ownerUserId: owner,
      groupId: group,
      records: [_member('user-a'), _member('user-c')],
    );
    await GroupMemberLocalStore.instance.replaceSnapshot(
      ownerUserId: owner,
      groupId: group,
      records: [_member('user-a'), _member('user-c')],
    );

    final stored = await GroupMemberLocalStore.instance.readAll(
      ownerUserId: owner,
      groupId: group,
    );
    expect(stored.map((item) => item.userId).toSet(), {'user-a', 'user-c'});
  });

  test('same owner and group refresh shares one in-flight operation', () async {
    final service = GroupMembershipSyncService.instance;
    final gate = Completer<void>();
    var calls = 0;

    Future<void> refresh() async {
      calls++;
      await gate.future;
    }

    final first = service.runGroupMemberRefreshSingleFlightForTest(
      ownerUserId: 'owner',
      groupId: '@TGS#SINGLE_FLIGHT',
      refresh: refresh,
    );
    final second = service.runGroupMemberRefreshSingleFlightForTest(
      ownerUserId: 'owner',
      groupId: '@TGS#SINGLE_FLIGHT',
      refresh: refresh,
    );

    expect(calls, 1);
    gate.complete();
    await Future.wait([first, second]);

    await service.runGroupMemberRefreshSingleFlightForTest(
      ownerUserId: 'owner',
      groupId: '@TGS#SINGLE_FLIGHT',
      refresh: () async {
        calls++;
      },
    );
    expect(calls, 2);
  });
}
