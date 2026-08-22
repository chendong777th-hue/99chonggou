import 'package:flutter_test/flutter_test.dart';
import 'package:tencent_cloud_chat_demo/src/services/group_join_application_service.dart';
import 'package:tencent_cloud_chat_demo/src/utils/group_join_application_approval.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_group_application.dart';

V2TimGroupApplication _pendingInvite({
  required String groupId,
  required String fromUser,
  required String toUser,
  int id = 1,
}) {
  return V2TimGroupApplication(
    groupID: groupId,
    fromUser: fromUser,
    toUser: toUser,
    addTime: 100,
    type: 2,
    handleStatus: 0,
    handleResult: 0,
    authentication: '${GroupJoinApplicationService.applicationAuthPrefix}$id',
  );
}

void main() {
  group('groupJoinApplicationCanApproveForCurrentUser', () {
    test('allows non-participant admin to approve pending invite', () {
      final application = _pendingInvite(
        groupId: 'g1',
        fromUser: 'member',
        toUser: 'friend',
      );

      expect(
        groupJoinApplicationCanApproveForCurrentUser(
          application: application,
          adminGroupIds: {'g1'},
          currentUserId: 'admin',
        ),
        isTrue,
      );
    });

    test('denies inviter even when cached as admin', () {
      final application = _pendingInvite(
        groupId: 'g1',
        fromUser: 'member',
        toUser: 'friend',
      );

      expect(
        groupJoinApplicationCanApproveForCurrentUser(
          application: application,
          adminGroupIds: {'g1'},
          currentUserId: 'member',
        ),
        isFalse,
      );
    });

    test('denies invitee even when cached as admin', () {
      final application = _pendingInvite(
        groupId: 'g1',
        fromUser: 'member',
        toUser: 'friend',
      );

      expect(
        groupJoinApplicationCanApproveForCurrentUser(
          application: application,
          adminGroupIds: {'g1'},
          currentUserId: 'friend',
        ),
        isFalse,
      );
    });

    test('denies inviter without admin role', () {
      final application = _pendingInvite(
        groupId: 'g1',
        fromUser: 'member',
        toUser: 'friend',
      );

      expect(
        groupJoinApplicationCanApproveForCurrentUser(
          application: application,
          adminGroupIds: const {},
          currentUserId: 'member',
        ),
        isFalse,
      );
    });
  });

  group('groupJoinApplicationMemberAddedTargets', () {
    test('invite approval uses inviter as operator and invitee as member', () {
      final application = _pendingInvite(
        groupId: 'g1',
        fromUser: 'member',
        toUser: 'friend',
      );

      final targets = groupJoinApplicationMemberAddedTargets(application);

      expect(targets.operatorUserId, 'member');
      expect(targets.memberUserIds, ['friend']);
    });

    test('join request approval uses applicant as member', () {
      final application = V2TimGroupApplication(
        groupID: 'g1',
        fromUser: 'applicant',
        addTime: 100,
        type: 0,
        handleStatus: 0,
        handleResult: 0,
        authentication: '${GroupJoinApplicationService.applicationAuthPrefix}2',
      );

      final targets = groupJoinApplicationMemberAddedTargets(application);

      expect(targets.operatorUserId, 'applicant');
      expect(targets.memberUserIds, ['applicant']);
    });
  });

  group('groupJoinApplicationIsWaitingAsParticipant', () {
    test('marks inviter pending invite as waiting', () {
      final application = _pendingInvite(
        groupId: 'g1',
        fromUser: 'member',
        toUser: 'friend',
      );

      expect(
        groupJoinApplicationIsWaitingAsParticipant(
          application: application,
          adminGroupIds: const {},
          currentUserId: 'member',
        ),
        isTrue,
      );
    });

    test('marks invitee pending invite as waiting', () {
      final application = _pendingInvite(
        groupId: 'g1',
        fromUser: 'member',
        toUser: 'friend',
      );

      expect(
        groupJoinApplicationIsWaitingAsParticipant(
          application: application,
          adminGroupIds: const {},
          currentUserId: 'friend',
        ),
        isTrue,
      );
    });

    test('does not mark admin approver as waiting participant', () {
      final application = _pendingInvite(
        groupId: 'g1',
        fromUser: 'member',
        toUser: 'friend',
      );

      expect(
        groupJoinApplicationIsWaitingAsParticipant(
          application: application,
          adminGroupIds: {'g1'},
          currentUserId: 'admin',
        ),
        isFalse,
      );
    });
  });
}
