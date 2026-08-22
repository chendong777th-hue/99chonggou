import 'package:flutter_test/flutter_test.dart';
import 'package:tencent_cloud_chat_demo/src/services/group_local/group_local_perf_flags.dart';
import 'package:tencent_cloud_chat_demo/src/services/group_local/group_membership_sync_service.dart';

void main() {
  group('shouldSkipNetworkSyncFullDecision', () {
    test('skips when process already synced once', () {
      final skip = GroupMembershipSyncService.shouldSkipNetworkSyncFullDecision(
        refresh: false,
        reason: 'native_post_home_after_quiet',
        localCount: 3001,
        groupListSyncedOnce: true,
        metaAtMs: 0,
        metaCount: 0,
        nowMs: 1,
      );
      expect(skip, isTrue);
    });

    test('skips when meta fresh and count matches', () {
      const now = 1000000;
      final skip = GroupMembershipSyncService.shouldSkipNetworkSyncFullDecision(
        refresh: false,
        reason: 'tcp_auth_ok',
        localCount: 3001,
        groupListSyncedOnce: false,
        metaAtMs: now - 60000,
        metaCount: 3001,
        nowMs: now,
      );
      expect(skip, isTrue);
    });

    test('does not skip refresh:true', () {
      final skip = GroupMembershipSyncService.shouldSkipNetworkSyncFullDecision(
        refresh: true,
        reason: 'native_post_home',
        localCount: 3001,
        groupListSyncedOnce: true,
        metaAtMs: 1,
        metaCount: 3001,
        nowMs: 2,
      );
      expect(skip, isFalse);
    });

    test('does not skip idle_reconcile reason', () {
      final skip = GroupMembershipSyncService.shouldSkipNetworkSyncFullDecision(
        refresh: false,
        reason: 'idle_reconcile',
        localCount: 3001,
        groupListSyncedOnce: true,
        metaAtMs: 1,
        metaCount: 3001,
        nowMs: 2,
      );
      expect(skip, isFalse);
    });

    test('does not skip when meta count mismatches', () {
      const now = 1000000;
      final skip = GroupMembershipSyncService.shouldSkipNetworkSyncFullDecision(
        refresh: false,
        reason: 'native_post_home',
        localCount: 3001,
        groupListSyncedOnce: false,
        metaAtMs: now - 60000,
        metaCount: 2990,
        nowMs: now,
      );
      expect(skip, isFalse);
    });

    test('does not skip when meta older than max age', () {
      const now = 1000000000;
      final skip = GroupMembershipSyncService.shouldSkipNetworkSyncFullDecision(
        refresh: false,
        reason: 'native_post_home',
        localCount: 3001,
        groupListSyncedOnce: false,
        metaAtMs: now - GroupLocalPerfFlags.fullSyncMaxAge.inMilliseconds - 1,
        metaCount: 3001,
        nowMs: now,
      );
      expect(skip, isFalse);
    });

    test('does not skip below localCompleteMinCount', () {
      final skip = GroupMembershipSyncService.shouldSkipNetworkSyncFullDecision(
        refresh: false,
        reason: 'native_post_home',
        localCount: GroupLocalPerfFlags.localCompleteMinCount - 1,
        groupListSyncedOnce: true,
        metaAtMs: 1,
        metaCount: 50,
        nowMs: 2,
      );
      expect(skip, isFalse);
    });
  });
}
