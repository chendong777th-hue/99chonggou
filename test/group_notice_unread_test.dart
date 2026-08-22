import 'package:flutter_test/flutter_test.dart';
import 'package:tencent_cloud_chat_demo/src/services/group_join_application_service.dart';
import 'package:tencent_cloud_chat_demo/src/services/group_notice_unread_service.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_group_application.dart';
import 'package:tencent_cloud_chat_uikit/business_logic/view_models/tui_chat_global_model.dart';

void main() {
  group('computeGroupNoticeUnreadCount', () {
    test('counts items newer than read watermark', () {
      final count = computeGroupNoticeUnreadCount(
        readWatermarkMs: 1000,
        applications: [
          V2TimGroupApplication(
            groupID: 'g1',
            addTime: 2,
            type: 0,
            handleStatus: 0,
            handleResult: 0,
            authentication:
                '${GroupJoinApplicationService.applicationAuthPrefix}1',
          ),
        ],
        notices: const [],
      );

      expect(count, 1);
    });

    test('counts system notices with millisecond timestamps', () {
      final count = computeGroupNoticeUnreadCount(
        readWatermarkMs: 1000,
        applications: const [],
        notices: [
          GroupSystemNoticeItem(
            id: 'n1',
            groupID: 'g1',
            groupName: 'g1',
            groupFaceUrl: '',
            type: GroupSystemNoticeType.grantAdministrator,
            operatorUserID: 'a',
            operatorName: 'a',
            targetUserID: 'b',
            targetName: 'b',
            timestamp: 2000,
          ),
        ],
      );

      expect(count, 1);
    });

    test('normalizes second-based timestamps', () {
      final count = computeGroupNoticeUnreadCount(
        readWatermarkMs: 1500,
        applications: [
          V2TimGroupApplication(
            groupID: 'g1',
            addTime: 2,
            type: 0,
            handleStatus: 0,
            handleResult: 0,
            authentication:
                '${GroupJoinApplicationService.applicationAuthPrefix}1',
          ),
        ],
        notices: const [],
      );

      expect(count, 1);
    });
  });
}
