import 'package:flutter_test/flutter_test.dart';
import 'package:tencent_cloud_chat_demo/src/services/group_notice_unread_service.dart';
import 'package:tencent_cloud_chat_uikit/business_logic/view_models/tui_chat_global_model.dart'
    show GroupSystemNoticeItem, GroupSystemNoticeType;

void main() {
  test('latestGroupNoticeTimestampMs takes max over unordered notices', () {
    final notices = <GroupSystemNoticeItem>[
      GroupSystemNoticeItem(
        id: 'n1',
        groupID: 'g1',
        groupName: 'Group',
        groupFaceUrl: '',
        type: GroupSystemNoticeType.grantAdministrator,
        operatorUserID: 'u1',
        operatorName: 'User',
        targetUserID: 'u2',
        targetName: 'Target',
        timestamp: 300,
      ),
      GroupSystemNoticeItem(
        id: 'n2',
        groupID: 'g2',
        groupName: 'Group',
        groupFaceUrl: '',
        type: GroupSystemNoticeType.grantAdministrator,
        operatorUserID: 'u1',
        operatorName: 'User',
        targetUserID: 'u2',
        targetName: 'Target',
        timestamp: 900,
      ),
      GroupSystemNoticeItem(
        id: 'n3',
        groupID: 'g3',
        groupName: 'Group',
        groupFaceUrl: '',
        type: GroupSystemNoticeType.grantAdministrator,
        operatorUserID: 'u1',
        operatorName: 'User',
        targetUserID: 'u2',
        targetName: 'Target',
        timestamp: 100,
      ),
    ];

    // 秒级时间戳会规范成毫秒（×1000）
    expect(latestGroupNoticeTimestampMs(const [], notices), 900000);
  });
}
