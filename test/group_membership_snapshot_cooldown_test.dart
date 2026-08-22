import 'package:flutter_test/flutter_test.dart';
import 'package:tencent_cloud_chat_demo/src/services/group_local/group_membership_sync_service.dart';

void main() {
  group('shouldSkipMembershipSnapshotForCooldownDecision', () {
    test('skips member_added family inside cooldown', () {
      expect(
        GroupMembershipSyncService.shouldSkipMembershipSnapshotForCooldownDecision(
          nowMs: 1000,
          cooldownUntilMs: 5000,
          reason: 'tcp_member_added',
        ),
        isTrue,
      );
      expect(
        GroupMembershipSyncService.shouldSkipMembershipSnapshotForCooldownDecision(
          nowMs: 1000,
          cooldownUntilMs: 5000,
          reason: 'local_member_added',
        ),
        isTrue,
      );
      expect(
        GroupMembershipSyncService.shouldSkipMembershipSnapshotForCooldownDecision(
          nowMs: 1000,
          cooldownUntilMs: 5000,
          reason: 'invite_members',
        ),
        isTrue,
      );
    });

    test('does not skip after cooldown expires', () {
      expect(
        GroupMembershipSyncService.shouldSkipMembershipSnapshotForCooldownDecision(
          nowMs: 6000,
          cooldownUntilMs: 5000,
          reason: 'tcp_member_added',
        ),
        isFalse,
      );
    });

    test('does not skip unrelated reasons inside cooldown', () {
      expect(
        GroupMembershipSyncService.shouldSkipMembershipSnapshotForCooldownDecision(
          nowMs: 1000,
          cooldownUntilMs: 5000,
          reason: 'tcp_member_removed',
        ),
        isFalse,
      );
      expect(
        GroupMembershipSyncService.shouldSkipMembershipSnapshotForCooldownDecision(
          nowMs: 1000,
          cooldownUntilMs: 5000,
          reason: 'manual',
        ),
        isFalse,
      );
    });
  });
}
