import 'package:flutter_test/flutter_test.dart';
import 'package:tencent_cloud_chat_demo/src/api/me_group_api.dart';
import 'package:tencent_cloud_chat_demo/src/services/group_local/group_member_role_pending.dart';

void main() {
  group('GroupMemberRoleBatchResponse.fromPayload', () {
    test('parses accepted results', () {
      final response = GroupMemberRoleBatchResponse.fromPayload(
        <String, dynamic>{
          'groupId': '@TGS#g1',
          'role': 300,
          'results': <Map<String, dynamic>>[
            <String, dynamic>{
              'userId': 'u1',
              'status': 'accepted',
              'code': null,
            },
            <String, dynamic>{
              'userId': 'u2',
              'status': 'accepted',
            },
          ],
        },
        groupId: '@TGS#g1',
        role: 300,
        requested: const <String>['u1', 'u2'],
      );
      expect(response.hasAccepted, isTrue);
      expect(response.acceptedUserIds, <String>['u1', 'u2']);
      expect(response.topLevelCode, isNull);
    });

    test('maps top-level error code', () {
      final response = GroupMemberRoleBatchResponse.fromPayload(
        <String, dynamic>{'code': 'NOT_GROUP_OWNER'},
        groupId: '@TGS#g1',
        role: 300,
        requested: const <String>['u1'],
      );
      expect(response.hasAccepted, isFalse);
      expect(response.topLevelCode, 'NOT_GROUP_OWNER');
      expect(response.results.single.code, 'NOT_GROUP_OWNER');
    });

    test('treats empty results with ok body as accepted', () {
      final response = GroupMemberRoleBatchResponse.fromPayload(
        <String, dynamic>{
          'groupId': '@TGS#g1',
          'role': 200,
        },
        groupId: '@TGS#g1',
        role: 200,
        requested: const <String>['u9'],
      );
      expect(response.acceptedUserIds, <String>['u9']);
    });
  });

  group('GroupMemberRolePending', () {
    late GroupMemberRolePending pending;

    setUp(() {
      pending = GroupMemberRolePending.instance;
      pending.clearAll();
      pending.onReconcileDue = null;
    });

    tearDown(() {
      pending.clearAll();
      pending.onReconcileDue = null;
    });

    test('same-role TCP sets tip suppress', () {
      pending.register(
        groupId: 'g1',
        userId: 'u1',
        expectedRole: 300,
        previousRole: 200,
        operatorUserId: 'owner',
      );
      expect(
        pending.acknowledgeTcp(groupId: 'g1', userId: 'u1', role: 300),
        isTrue,
      );
      expect(
        pending.consumeTipSuppress(groupId: 'g1', userId: 'u1', role: 300),
        isTrue,
      );
      expect(
        pending.consumeTipSuppress(groupId: 'g1', userId: 'u1', role: 300),
        isFalse,
      );
    });

    test('divergent TCP does not suppress tip', () {
      pending.register(
        groupId: 'g1',
        userId: 'u1',
        expectedRole: 300,
        previousRole: 200,
        operatorUserId: 'owner',
      );
      expect(
        pending.acknowledgeTcp(groupId: 'g1', userId: 'u1', role: 200),
        isFalse,
      );
      expect(
        pending.consumeTipSuppress(groupId: 'g1', userId: 'u1', role: 200),
        isFalse,
      );
    });

    test('takeExpiredForGroup removes timed-out entries', () {
      pending.register(
        groupId: 'g1',
        userId: 'u1',
        expectedRole: 300,
        previousRole: 200,
        operatorUserId: 'owner',
        createdAtMs: DateTime.now()
            .subtract(const Duration(seconds: 20))
            .millisecondsSinceEpoch,
      );
      final expired = pending.takeExpiredForGroup('g1');
      expect(expired, hasLength(1));
      expect(expired.single.userId, 'u1');
      expect(pending.hasPendingForGroup('g1'), isFalse);
    });
  });
}
