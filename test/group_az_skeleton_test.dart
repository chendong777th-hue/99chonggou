import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:tencent_cloud_chat_demo/src/models/me_group_record.dart';
import 'package:tencent_cloud_chat_demo/src/services/group_local/group_local_perf_flags.dart';
import 'package:tencent_cloud_chat_demo/src/services/group_local/group_local_store.dart';
import 'package:tencent_cloud_chat_demo/src/services/group_local/my_group_az_skeleton.dart';
import 'package:tencent_cloud_chat_uikit/ui/views/TIMUIKitSearch/conversation_search_utils.dart';

MeGroupRecord _rec(
  String id, {
  String name = 'g',
  int memberCount = 1,
  int updatedAt = 1,
  int myRole = 200,
}) {
  return MeGroupRecord(
    groupId: id,
    groupType: 'Public',
    groupName: name,
    displayAlias: '',
    avatarUrl: '',
    notice: '',
    memberCount: memberCount,
    myRole: myRole,
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

  group('GroupLocalPerfFlags AZ', () {
    test('AZ optimize flags locked as planned', () {
      expect(GroupLocalPerfFlags.myGroupListAzOptimizeEnabled, isTrue);
      expect(GroupLocalPerfFlags.myGroupListMemoryReuseEnabled, isTrue);
      expect(GroupLocalPerfFlags.myGroupListBackfillChunkSize, 200);
      expect(GroupLocalPerfFlags.myGroupListSearchLimit, 200);
    });
  });

  group('MyGroupAzSkeleton.computeIndexTag', () {
    test('matches memberSuspensionIndexTag for latin / chinese / symbol', () {
      const samples = <String>[
        'Apple',
        'banana',
        '中文群',
        '123数字',
        '#话题',
        '测试群聊A',
        '',
      ];
      for (final name in samples) {
        final show = MyGroupAzSkeleton.showNameOf(
          groupName: name,
          groupId: 'gid_fallback',
        );
        expect(
          MyGroupAzSkeleton.computeIndexTag(groupName: name, groupId: 'gid_fallback'),
          memberSuspensionIndexTag(show),
          reason: 'name=$name',
        );
      }
      expect(
        MyGroupAzSkeleton.computeIndexTag(groupName: '', groupId: 'Zebra'),
        memberSuspensionIndexTag('Zebra'),
      );
    });
  });

  group('GroupLocalStore AZ skeleton', () {
    const owner = 'group_az_skeleton_owner';

    setUp(() async {
      await GroupLocalStore.instance.clearForOwner(owner);
    });

    tearDown(() async {
      await GroupLocalStore.instance.clearForOwner(owner);
    });

    test('upsert persists index_tag and readAzSkeleton keeps AZ order', () async {
      final records = [
        _rec('@TGS#Z1', name: 'Zebra'),
        _rec('@TGS#A1', name: 'Apple'),
        _rec('@TGS#H1', name: '中文群'),
        _rec('@TGS#N1', name: '123数字'),
      ];
      await GroupLocalStore.instance.replaceAll(
        ownerUserId: owner,
        records: records,
      );

      final skeletons = await GroupLocalStore.instance.readAzSkeleton(
        ownerUserId: owner,
      );
      expect(skeletons.length, 4);

      final expected = records
          .map(
            (r) => (
              id: r.groupId,
              tag: MyGroupAzSkeleton.computeIndexTag(
                groupName: r.groupName,
                groupId: r.groupId,
              ),
              name: r.groupName,
            ),
          )
          .toList()
        ..sort((a, b) {
          final t = a.tag.compareTo(b.tag);
          if (t != 0) return t;
          final n = a.name.compareTo(b.name);
          if (n != 0) return n;
          return a.id.compareTo(b.id);
        });
      expect(
        skeletons.map((e) => e.groupId).toList(),
        expected.map((e) => e.id).toList(),
      );
      for (final s in skeletons) {
        expect(
          s.indexTag,
          MyGroupAzSkeleton.computeIndexTag(
            groupName: s.groupName,
            groupId: s.groupId,
          ),
        );
      }

      final count = await GroupLocalStore.instance.countGroups(ownerUserId: owner);
      expect(count, 4);
    });

    test('search respects limit and keyword', () async {
      await GroupLocalStore.instance.replaceAll(
        ownerUserId: owner,
        records: [
          for (var i = 0; i < 10; i++)
            _rec('@TGS#S$i', name: i.isEven ? 'SearchHit$i' : 'Other$i'),
        ],
      );
      final hit = await GroupLocalStore.instance.readAzSkeleton(
        ownerUserId: owner,
        keyword: 'SearchHit',
        limit: 3,
      );
      expect(hit.length, lessThanOrEqualTo(3));
      expect(hit.every((e) => e.groupName.contains('SearchHit')), isTrue);
    });

    test('ensureIndexTagsBackfilled fills empty SQL tags', () async {
      await GroupLocalStore.instance.replaceAll(
        ownerUserId: owner,
        records: [
          _rec('@TGS#BF1', name: 'BackfillOne'),
          _rec('@TGS#BF2', name: 'BackfillTwo'),
        ],
      );

      await GroupLocalStore.instance.debugClearIndexTagsForOwner(owner);
      await GroupLocalStore.instance.ensureIndexTagsBackfilled(
        ownerUserId: owner,
      );

      final rows = await GroupLocalStore.instance.debugReadIndexTagRows(owner);
      expect(rows.length, 2);
      for (final row in rows) {
        final groupId = row['group_id']!.toString();
        final groupName = row['group_name']!.toString();
        final tag = row['index_tag']!.toString();
        expect(tag, isNotEmpty);
        expect(
          tag,
          MyGroupAzSkeleton.computeIndexTag(
            groupName: groupName,
            groupId: groupId,
          ),
        );
      }
    });
  });
}
