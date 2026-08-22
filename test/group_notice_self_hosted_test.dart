import 'package:flutter_test/flutter_test.dart';
import 'package:tencent_cloud_chat_demo/src/api/group_join_api.dart';
import 'package:tencent_cloud_chat_demo/src/api/group_notice_api.dart';
import 'package:tencent_cloud_chat_demo/src/utils/group_join_application_dedupe.dart';
import 'package:tencent_cloud_chat_demo/src/services/group_join_application_service.dart';
import 'package:tencent_cloud_chat_demo/src/utils/group_join_application_mapper.dart';
import 'package:tencent_cloud_chat_demo/src/utils/group_notice_applications_merge.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_group_application.dart';
import 'package:tencent_cloud_chat_uikit/business_logic/view_models/tui_chat_global_model.dart';

void main() {
  group('GroupJoinApplicationRecord', () {
    test('parses my join application payload with group display fields', () {
      final record = GroupJoinApplicationRecord.fromJson(<String, dynamic>{
        'applicationId': 123,
        'groupId': '@TGS#ABC',
        'groupName': '产品讨论群',
        'groupAvatarUrl': 'https://cdn.example.com/thumb.jpg',
        'applicationType': 'join',
        'fromUserId': '10001',
        'status': 'approved',
        'createdAt': 1718452800000,
        'handledAt': 1718456400000,
        'handlerUserId': 'admin-1',
        'handledByNickName': '管理员甲',
        'fromUserNickName': '张三',
      });

      expect(record.id, 123);
      expect(record.groupName, '产品讨论群');
      expect(record.groupAvatarUrl, 'https://cdn.example.com/thumb.jpg');
      expect(record.handledAtMs, 1718456400000);
      expect(record.handledByUserId, 'admin-1');
      expect(record.handledByNickName, '管理员甲');
      expect(record.toJson()['handledByUserId'], 'admin-1');
      expect(record.toJson()['handlerUserId'], 'admin-1');
      expect(record.isInvite, isFalse);
    });

    test('maps REST record to UIKit application with join_app auth prefix', () {
      final application = GroupJoinApplicationMapper.toUIKitApplication(
        const GroupJoinApplicationRecord(
          id: 42,
          groupId: '@TGS#ABC',
          applicationType: 'invite',
          fromUserId: '10001',
          toUserId: '10002',
          status: 'pending',
          createdAtMs: 1718452800000,
        ),
      );

      expect(
        application.authentication,
        '${GroupJoinApplicationService.applicationAuthPrefix}42',
      );
      expect(application.type, 2);
      expect(application.handleStatus, 0);
    });
  });

  group('dedupeGroupNoticeApplications', () {
    test('dedupes by join_app auth and sorts newest first', () {
      final older = V2TimGroupApplication(
        groupID: 'g1',
        fromUser: 'u1',
        addTime: 100,
        type: 0,
        handleStatus: 0,
        handleResult: 0,
        authentication: '${GroupJoinApplicationService.applicationAuthPrefix}1',
      );
      final newer = V2TimGroupApplication(
        groupID: 'g1',
        fromUser: 'u1',
        addTime: 200,
        type: 0,
        handleStatus: 0,
        handleResult: 0,
        authentication: '${GroupJoinApplicationService.applicationAuthPrefix}1',
      );
      final other = V2TimGroupApplication(
        groupID: 'g2',
        fromUser: 'u2',
        addTime: 150,
        type: 0,
        handleStatus: 0,
        handleResult: 0,
        authentication: '${GroupJoinApplicationService.applicationAuthPrefix}2',
      );

      final result = dedupeGroupNoticeApplications([older, newer, other]);

      expect(result.length, 2);
      expect(result.first.authentication, endsWith('1'));
      expect(result.first.addTime, 200);
      expect(result.last.authentication, endsWith('2'));
    });
  });

  group('GroupNoticeRecord', () {
    test('parses REST system notice payload', () {
      final record = GroupNoticeRecord.fromJson(<String, dynamic>{
        'noticeId': 'grant|g1|a|b|1718452800000',
        'groupId': '@TGS#ABC',
        'groupName': '测试群',
        'groupAvatarUrl': 'https://cdn.example.com/a.jpg',
        'type': 'grant_administrator',
        'operatorUserId': '10001',
        'operatorNickName': '李四',
        'targetUserId': '10002',
        'targetNickName': '张三',
        'createdAt': 1718452800000,
      });

      final notice = record.toUIKitNotice();
      expect(notice.id, 'grant|g1|a|b|1718452800000');
      expect(notice.type, GroupSystemNoticeType.grantAdministrator);
      expect(notice.operatorName, '李四');
      expect(notice.targetName, '张三');
      expect(notice.timestamp, 1718452800000);
    });

    test('parses TCP group_system_notice detail', () {
      final record = GroupNoticeRecord.fromDetail(<String, dynamic>{
        'noticeId': 'owner|g1||10002|1718456400000',
        'type': 'transfer_owner',
        'operatorUserId': '10001',
        'operatorNickName': '旧群主',
        'targetUserId': '10002',
        'targetNickName': '新群主',
        'groupId': '@TGS#ABC',
        'groupName': '测试群',
        'createdAt': 1718456400000,
      });

      expect(record, isNotNull);
      expect(record!.toUIKitNotice().type, GroupSystemNoticeType.transferOwner);
    });

    test('maps revoke administrator type', () {
      final record = GroupNoticeRecord.fromJson(<String, dynamic>{
        'noticeId': 'revoke|g1|a|b|1',
        'groupId': 'g1',
        'type': 'revoke_administrator',
        'createdAt': 1000,
      });

      expect(
        record.toUIKitNotice().type,
        GroupSystemNoticeType.revokeAdministrator,
      );
    });
  });

  group('dedupeGroupJoinApplicationRecords', () {
    test('collapses duplicate invite records for same invitee', () {
      final records = dedupeGroupJoinApplicationRecords([
        GroupJoinApplicationRecord(
          id: 456,
          groupId: 'g1',
          applicationType: 'invite',
          fromUserId: 'admin01',
          toUserId: 'user_b',
          status: 'approved',
          createdAtMs: 2000,
          fromUserNickName: '管理员',
        ),
        GroupJoinApplicationRecord(
          id: 123,
          groupId: 'g1',
          applicationType: 'invite',
          fromUserId: 'user_a',
          toUserId: 'user_b',
          status: 'approved',
          createdAtMs: 1000,
          fromUserNickName: '算账号',
        ),
      ]);

      expect(records.length, 1);
      expect(records.first.id, 123);
      expect(records.first.fromUserNickName, '算账号');
    });
  });
}
