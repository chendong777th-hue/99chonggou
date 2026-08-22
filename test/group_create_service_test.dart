import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tencent_cloud_chat_demo/src/models/me_group_record.dart';
import 'package:tencent_cloud_chat_demo/src/services/group_local/group_create_service.dart';

MeGroupRecord _group({
  required String groupId,
  required String groupName,
  String groupType = 'Public',
  int myRole = kGroupCreateOwnerRole,
  int joinedAt = 0,
  int updatedAt = 0,
  String ownerUserId = '',
}) {
  return MeGroupRecord(
    groupId: groupId,
    groupType: groupType,
    groupName: groupName,
    displayAlias: '',
    avatarUrl: '',
    notice: '',
    memberCount: 1,
    myRole: myRole,
    myNameCard: '',
    joinedAt: joinedAt,
    updatedAt: updatedAt,
    ownerUserId: ownerUserId,
  );
}

void main() {
  group('shouldAttemptGroupCreateRecovery', () {
    test('returns true for receive timeout', () {
      expect(
        shouldAttemptGroupCreateRecovery(
          DioError(
            requestOptions: RequestOptions(path: '/group'),
            type: DioErrorType.receiveTimeout,
          ),
        ),
        isTrue,
      );
    });

    test('returns true for HTTP 502', () {
      expect(
        shouldAttemptGroupCreateRecovery(
          DioError(
            requestOptions: RequestOptions(path: '/group'),
            response: Response(
              requestOptions: RequestOptions(path: '/group'),
              statusCode: 502,
            ),
            type: DioErrorType.response,
          ),
        ),
        isTrue,
      );
    });

    test('returns false for HTTP 403 CREATE_LIMIT_EXCEEDED', () {
      expect(
        shouldAttemptGroupCreateRecovery(
          DioError(
            requestOptions: RequestOptions(path: '/group'),
            response: Response(
              requestOptions: RequestOptions(path: '/group'),
              statusCode: 403,
              data: {'code': 'CREATE_LIMIT_EXCEEDED'},
            ),
            type: DioErrorType.response,
          ),
        ),
        isFalse,
      );
    });

    test('returns false for HTTP 403 GROUP_JOIN_LIMIT_EXCEEDED', () {
      expect(
        shouldAttemptGroupCreateRecovery(
          DioError(
            requestOptions: RequestOptions(path: '/group'),
            response: Response(
              requestOptions: RequestOptions(path: '/group'),
              statusCode: 403,
              data: {'code': 'GROUP_JOIN_LIMIT_EXCEEDED'},
            ),
            type: DioErrorType.response,
          ),
        ),
        isFalse,
      );
    });

    test('returns false for HTTP 403 GROUP_CREATE_LIMIT_COMMUNITY', () {
      expect(
        shouldAttemptGroupCreateRecovery(
          DioError(
            requestOptions: RequestOptions(path: '/group'),
            response: Response(
              requestOptions: RequestOptions(path: '/group'),
              statusCode: 403,
              data: {'code': 'GROUP_CREATE_LIMIT_COMMUNITY'},
            ),
            type: DioErrorType.response,
          ),
        ),
        isFalse,
      );
    });

    test('returns true for HTTP 201 with invalid response body', () {
      expect(
        shouldAttemptGroupCreateRecovery(
          DioError(
            requestOptions: RequestOptions(path: '/group'),
            response: Response(
              requestOptions: RequestOptions(path: '/group'),
              statusCode: 201,
            ),
            type: DioErrorType.response,
            error: 'INVALID_RESPONSE',
          ),
        ),
        isTrue,
      );
    });
  });

  group('findRecoverableCreatedGroup', () {
    final attemptAt = DateTime.utc(2026, 6, 19, 12, 0).millisecondsSinceEpoch;
    final recentAt = attemptAt + 5000;

    test('finds owner group with matching name and type', () {
      final match = _group(
        groupId: '@TGS#A',
        groupName: '产品讨论群',
        groupType: 'Public',
        joinedAt: recentAt,
      );
      final result = findRecoverableCreatedGroup(
        groups: [
          _group(
            groupId: '@TGS#OLD',
            groupName: '产品讨论群',
            groupType: 'Public',
            myRole: 200,
            joinedAt: recentAt,
          ),
          match,
        ],
        groupName: '产品讨论群',
        groupType: 'Public',
        attemptStartedAtMs: attemptAt,
        nowMs: recentAt + 1000,
      );
      expect(result?.groupId, '@TGS#A');
    });

    test('ignores groups created before attempt window', () {
      final result = findRecoverableCreatedGroup(
        groups: [
          _group(
            groupId: '@TGS#OLD',
            groupName: '产品讨论群',
            joinedAt: attemptAt - 120000,
          ),
        ],
        groupName: '产品讨论群',
        groupType: 'Public',
        attemptStartedAtMs: attemptAt,
        nowMs: attemptAt,
      );
      expect(result, isNull);
    });

    test('ignores groups with different type', () {
      final result = findRecoverableCreatedGroup(
        groups: [
          _group(
            groupId: '@TGS#A',
            groupName: '产品讨论群',
            groupType: 'Community',
            joinedAt: recentAt,
          ),
        ],
        groupName: '产品讨论群',
        groupType: 'Public',
        attemptStartedAtMs: attemptAt,
        nowMs: recentAt + 1000,
      );
      expect(result, isNull);
    });

    test('finds owner group when list item has no timestamps', () {
      final result = findRecoverableCreatedGroup(
        groups: [
          _group(
            groupId: '@TGS#A',
            groupName: '产品讨论群',
            groupType: 'Public',
          ),
        ],
        groupName: '产品讨论群',
        groupType: 'Public',
        attemptStartedAtMs: attemptAt,
        nowMs: attemptAt + 2000,
      );
      expect(result?.groupId, '@TGS#A');
    });

    test('picks group closest to attempt when duplicate names exist', () {
      final result = findRecoverableCreatedGroup(
        groups: [
          _group(
            groupId: '@TGS#NEWER',
            groupName: '测试',
            groupType: 'Public',
            joinedAt: attemptAt + 60000,
          ),
          _group(
            groupId: '@TGS#CORRECT',
            groupName: '测试',
            groupType: 'Public',
            joinedAt: attemptAt + 3000,
          ),
        ],
        groupName: '测试',
        groupType: 'Public',
        attemptStartedAtMs: attemptAt,
        nowMs: attemptAt + 120000,
      );
      expect(result?.groupId, '@TGS#CORRECT');
    });

    test('returns null when duplicate names tie on attempt distance', () {
      final result = findRecoverableCreatedGroup(
        groups: [
          _group(
            groupId: '@TGS#A',
            groupName: '测试',
            groupType: 'Public',
            joinedAt: attemptAt + 5000,
          ),
          _group(
            groupId: '@TGS#B',
            groupName: '测试',
            groupType: 'Public',
            joinedAt: attemptAt + 5000,
          ),
        ],
        groupName: '测试',
        groupType: 'Public',
        attemptStartedAtMs: attemptAt,
        nowMs: attemptAt + 120000,
      );
      expect(result, isNull);
    });

    test('ignores groups already present in snapshot', () {
      final result = findRecoverableCreatedGroup(
        groups: [
          _group(
            groupId: '@TGS#EXISTING',
            groupName: '测试1',
            groupType: 'Public',
            joinedAt: attemptAt + 3000,
          ),
        ],
        groupName: '测试1',
        groupType: 'Public',
        attemptStartedAtMs: attemptAt + 18000,
        nowMs: attemptAt + 20000,
        excludeGroupIds: const {'@TGS#EXISTING'},
      );
      expect(result, isNull);
    });
  });

  group('findRecoverableGroupBySnapshot', () {
    test('finds newly appeared owner group without relying on timestamps', () {
      final result = findRecoverableGroupBySnapshot(
        groups: [
          _group(groupId: '@TGS#OLD', groupName: '旧群'),
          _group(
            groupId: '@TGS#NEW',
            groupName: '新群聊',
            myRole: 0,
            ownerUserId: 'user01',
          ),
        ],
        beforeGroupIds: const {'@TGS#OLD'},
        attemptStartedAtMs: DateTime.utc(2026, 6, 19, 12).millisecondsSinceEpoch,
        preferredGroupName: '新群聊',
        currentUserId: 'user01',
      );
      expect(result?.groupId, '@TGS#NEW');
    });
  });

  group('GroupCreateService create flow generation', () {
    test('only latest generation should navigate', () {
      final service = GroupCreateService.instance;
      final first = service.beginCreateFlow();
      final second = service.beginCreateFlow();

      expect(service.isLatestCreateFlow(first), isFalse);
      expect(service.isLatestCreateFlow(second), isTrue);
    });

    test('rejects invalid generation values', () {
      final service = GroupCreateService.instance;
      service.beginCreateFlow();
      expect(service.isLatestCreateFlow(0), isFalse);
      expect(service.isLatestCreateFlow(-1), isFalse);
    });
  });
}
