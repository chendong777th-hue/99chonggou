import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:tencent_cloud_chat_demo/src/models/me_group_record.dart';
import 'package:tencent_cloud_chat_demo/src/services/group_local/group_local_perf_flags.dart';
import 'package:tencent_cloud_chat_demo/src/services/group_local/group_local_store.dart';
import 'package:tencent_cloud_chat_demo/src/services/group_local/group_membership_sync_service.dart';

MeGroupRecord _rec(
  String id, {
  String name = 'g',
  int memberCount = 1,
  int updatedAt = 1,
}) {
  return MeGroupRecord(
    groupId: id,
    groupType: 'Public',
    groupName: name,
    displayAlias: '',
    avatarUrl: '',
    notice: '',
    memberCount: memberCount,
    myRole: 200,
    myNameCard: '',
    joinedAt: 1,
    updatedAt: updatedAt,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('GroupLocalPerfFlags', () {
    test('locked constants match plan', () {
      expect(GroupLocalPerfFlags.syncFullWriteChunkSize, 80);
      expect(GroupLocalPerfFlags.syncFullWriteChunkYield.inMilliseconds, 40);
      expect(GroupLocalPerfFlags.coldStartWriteChunkSize, 250);
      expect(GroupLocalPerfFlags.coldStartWriteChunkYield.inMilliseconds, 8);
      expect(GroupLocalPerfFlags.coldStartUpsertRatio, 0.85);
      expect(GroupLocalPerfFlags.tcpAuthSyncFullDelay.inSeconds, 2);
      expect(GroupLocalPerfFlags.tcpAuthSyncFullDelayEnabled, isTrue);
    });
  });

  group('isColdStartReplaceAll', () {
    test('empty existing is cold start', () {
      expect(
        GroupLocalStore.isColdStartReplaceAll(
          existingCount: 0,
          upsertCount: 100,
          normalizedCount: 100,
        ),
        isTrue,
      );
    });

    test('high upsert ratio is cold start', () {
      expect(
        GroupLocalStore.isColdStartReplaceAll(
          existingCount: 100,
          upsertCount: 90,
          normalizedCount: 100,
        ),
        isTrue,
      );
    });

    test('mostly unchanged is not cold start', () {
      expect(
        GroupLocalStore.isColdStartReplaceAll(
          existingCount: 100,
          upsertCount: 2,
          normalizedCount: 100,
        ),
        isFalse,
      );
    });
  });

  group('dedupeGroupRecords', () {
    test('drops empty ids and keeps last duplicate exact id', () {
      final out = GroupLocalStore.dedupeGroupRecords([
        _rec(''),
        _rec('@TGS#AAA', name: 'first'),
        _rec('@TGS#AAA', name: 'second'),
      ]);
      expect(out.length, 1);
      expect(out.single.groupId, '@TGS#AAA');
      expect(out.single.groupName, 'second');
    });

    test('merges equivalent group ids keeping last', () {
      final out = GroupLocalStore.dedupeGroupRecords([
        _rec('@TGS#ABCDEF', name: 'a'),
        _rec('group_@TGS#ABCDEF', name: 'b'),
      ]);
      expect(out.length, 1);
      expect(out.single.groupName, 'b');
    });
  });

  group('groupIdsToDelete', () {
    test('returns existing ids missing from normalized set', () {
      final toDelete = GroupLocalStore.groupIdsToDelete(
        existing: [
          _rec('@TGS#KEEP'),
          _rec('@TGS#GONE'),
        ],
        normalized: [
          _rec('@TGS#KEEP'),
          _rec('@TGS#NEW'),
        ],
      );
      expect(toDelete, ['@TGS#GONE']);
    });

    test('deletes old alias when equivalent id form differs', () {
      final toDelete = GroupLocalStore.groupIdsToDelete(
        existing: [_rec('@TGS#ABCDEF')],
        normalized: [_rec('group_@TGS#ABCDEF')],
      );
      expect(toDelete, ['@TGS#ABCDEF']);
    });

    test('keeps exact same stored id', () {
      final toDelete = GroupLocalStore.groupIdsToDelete(
        existing: [_rec('@TGS#ABCDEF')],
        normalized: [_rec('@TGS#ABCDEF')],
      );
      expect(toDelete, isEmpty);
    });
  });

  group('groupRecordsToUpsert', () {
    test('skips an unchanged record', () {
      final out = GroupLocalStore.groupRecordsToUpsert(
        existing: [_rec('@TGS#SAME')],
        normalized: [_rec('@TGS#SAME')],
      );
      expect(out, isEmpty);
    });

    test('missing incoming updatedAt does not force a rewrite', () {
      final out = GroupLocalStore.groupRecordsToUpsert(
        existing: [_rec('@TGS#SAME', updatedAt: 123)],
        normalized: [_rec('@TGS#SAME', updatedAt: 0)],
      );
      expect(out, isEmpty);
    });

    test('writes a changed business field', () {
      final changed = _rec('@TGS#CHANGED', name: 'new', updatedAt: 0);
      final out = GroupLocalStore.groupRecordsToUpsert(
        existing: [_rec('@TGS#CHANGED', name: 'old', updatedAt: 123)],
        normalized: [changed],
      );
      expect(out, [changed]);
    });

    test('writes an equivalent id when the stored form changes', () {
      final incoming = _rec('group_@TGS#ALIAS');
      final out = GroupLocalStore.groupRecordsToUpsert(
        existing: [_rec('@TGS#ALIAS')],
        normalized: [incoming],
      );
      expect(out, [incoming]);
    });
  });

  group('removedGroupIdsByEquivalence', () {
    test('keeps equivalent group id aliases', () {
      final removed = GroupMembershipSyncService.removedGroupIdsByEquivalence(
        existingIds: const ['group_@TGS#KEEP'],
        joinedIds: const ['@TGS#KEEP'],
      );
      expect(removed, isEmpty);
    });

    test('returns only groups absent from the backend snapshot', () {
      final removed = GroupMembershipSyncService.removedGroupIdsByEquivalence(
        existingIds: const ['@TGS#KEEP', '@TGS#GONE'],
        joinedIds: const ['group_@TGS#KEEP'],
      );
      expect(removed, ['@TGS#GONE']);
    });
  });

  group('destructive group conversation purge gate', () {
    test('snapshot membership difference is never destructive', () {
      expect(
        GroupMembershipSyncService.shouldDestructivelyPurgeGroupConversation(
          explicitMembershipEvent: false,
        ),
        isFalse,
      );
    });

    test('explicit self removal or dismissal may purge', () {
      expect(
        GroupMembershipSyncService.shouldDestructivelyPurgeGroupConversation(
          explicitMembershipEvent: true,
        ),
        isTrue,
      );
    });
  });

  group('snapshot missing quarantine', () {
    test('retains groups during the first two missing snapshots', () {
      for (final misses in <int>[1, 2]) {
        expect(
          GroupMembershipSyncService.shouldRetainGroupFromSnapshotSafety(
            explicitlyRemoved: false,
            consecutiveMissingSnapshots: misses,
          ),
          isTrue,
        );
      }
    });

    test('third independent missing snapshot may remove local membership', () {
      expect(
        GroupMembershipSyncService.shouldRetainGroupFromSnapshotSafety(
          explicitlyRemoved: false,
          consecutiveMissingSnapshots: 3,
        ),
        isFalse,
      );
    });

    test('explicit removal bypasses snapshot quarantine', () {
      expect(
        GroupMembershipSyncService.shouldRetainGroupFromSnapshotSafety(
          explicitlyRemoved: true,
          consecutiveMissingSnapshots: 0,
        ),
        isFalse,
      );
    });
  });

  test('snapshot merge preserves a locally joined group missing from one page',
      () {
    final existing = <MeGroupRecord>[
      _rec('@TGS#KEEP_LOCAL', name: 'local'),
    ];
    final incoming = <MeGroupRecord>[
      _rec('@TGS#NEW_REMOTE', name: 'remote'),
    ];
    final safe = GroupLocalStore.dedupeGroupRecords(
      <MeGroupRecord>[...existing, ...incoming],
    );
    expect(
      safe.map((record) => record.groupId),
      containsAll(<String>['@TGS#KEEP_LOCAL', '@TGS#NEW_REMOTE']),
    );
  });

  group('replaceAll SQLite diff', () {
    const owner = 'group_replace_diff_owner';

    setUp(() => GroupLocalStore.instance.clearForOwner(owner));
    tearDown(() => GroupLocalStore.instance.clearForOwner(owner));

    test('unchanged record with missing timestamp keeps stored timestamp',
        () async {
      await GroupLocalStore.instance.replaceAll(
        ownerUserId: owner,
        records: [_rec('@TGS#SQL_SAME', updatedAt: 123)],
      );
      await GroupLocalStore.instance.replaceAll(
        ownerUserId: owner,
        records: [_rec('@TGS#SQL_SAME', updatedAt: 0)],
      );

      final stored = await GroupLocalStore.instance.read(
        groupId: 'group_@TGS#SQL_SAME',
        ownerUserId: owner,
      );
      expect(stored?.updatedAt, 123);
    });

    test('changed record with missing timestamp is persisted', () async {
      await GroupLocalStore.instance.replaceAll(
        ownerUserId: owner,
        records: [_rec('@TGS#SQL_CHANGED', name: 'old', updatedAt: 123)],
      );
      await GroupLocalStore.instance.replaceAll(
        ownerUserId: owner,
        records: [_rec('@TGS#SQL_CHANGED', name: 'new', updatedAt: 0)],
      );

      final stored = await GroupLocalStore.instance.read(
        groupId: '@TGS#SQL_CHANGED',
        ownerUserId: owner,
      );
      expect(stored?.groupName, 'new');
      expect(stored?.updatedAt, greaterThan(123));
    });

    test('existingSnapshot skips second readAll and keeps diff behavior',
        () async {
      await GroupLocalStore.instance.replaceAll(
        ownerUserId: owner,
        records: [_rec('@TGS#SNAP', name: 'old', updatedAt: 10)],
      );
      final snapshot = await GroupLocalStore.instance.readAll(
        ownerUserId: owner,
        caller: 'test',
      );
      await GroupLocalStore.instance.replaceAll(
        ownerUserId: owner,
        records: [_rec('@TGS#SNAP', name: 'old', updatedAt: 10)],
        existingSnapshot: snapshot,
      );
      final stored = await GroupLocalStore.instance.read(
        groupId: '@TGS#SNAP',
        ownerUserId: owner,
      );
      expect(stored?.groupName, 'old');
      expect(stored?.updatedAt, 10);
    });

    test('upsert rejects c2c_ as groupId', () async {
      await GroupLocalStore.instance.upsert(
        ownerUserId: owner,
        record: _rec('c2c_rqwm8onw3j'),
      );
      final stored = await GroupLocalStore.instance.read(
        groupId: 'c2c_rqwm8onw3j',
        ownerUserId: owner,
      );
      expect(stored, isNull);
      expect(
        await GroupLocalStore.instance.countGroups(ownerUserId: owner),
        0,
      );
    });

    test('replaceAll filters forbidden c2c_ records', () async {
      await GroupLocalStore.instance.replaceAll(
        ownerUserId: owner,
        records: [
          _rec('m2KEEPGROUP01'),
          _rec('c2c_should_drop'),
        ],
      );
      final all = await GroupLocalStore.instance.readAll(ownerUserId: owner);
      expect(all.map((e) => e.groupId), ['m2KEEPGROUP01']);
    });
  });
}
