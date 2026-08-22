import 'package:flutter_test/flutter_test.dart';
import 'package:tencent_cloud_chat_demo/src/services/conversation_local/conversation_perf_flags.dart';
import 'package:tencent_cloud_chat_demo/src/services/group_local/group_membership_sync_service.dart';

void main() {
  group('GroupMembershipSyncService revision coalesce', () {
    late GroupMembershipSyncService service;
    var bumps = 0;
    late void Function() onBump;

    setUp(() {
      service = GroupMembershipSyncService.instance;
      bumps = 0;
      onBump = () => bumps++;
      service.joinedGroupsRevision.addListener(onBump);
    });

    tearDown(() {
      service.joinedGroupsRevision.removeListener(onBump);
      service.flushJoinedGroupsRevisionCoalesceForTest();
    });

    test('multiple bumps within coalesce window become one notify', () async {
      final before = service.joinedGroupsRevision.value;
      service.bumpJoinedGroupsRevisionForTest();
      service.bumpJoinedGroupsRevisionForTest();
      service.bumpJoinedGroupsRevisionForTest();
      expect(service.joinedGroupsRevision.value, before);
      expect(bumps, 0);

      await Future<void>.delayed(
        ConversationPerfFlags.joinedGroupsRevisionCoalesce +
            const Duration(milliseconds: 40),
      );
      expect(service.joinedGroupsRevision.value, before + 1);
      expect(bumps, 1);
    });
  });
}
