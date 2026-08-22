import 'package:flutter_test/flutter_test.dart';
import 'package:tencent_cloud_chat_demo/src/models/me_group_record.dart';
import 'package:tencent_cloud_chat_demo/utils/group_notice_open_gate.dart';
import 'package:tencent_cloud_chat_sdk/enum/group_member_role.dart';

MeGroupRecord _record({required int myRole}) {
  return MeGroupRecord(
    groupId: 'g1',
    groupType: 'Work',
    groupName: 'n',
    displayAlias: '',
    avatarUrl: '',
    notice: '',
    memberCount: 1,
    myRole: myRole,
    myNameCard: '',
    joinedAt: 0,
    updatedAt: 0,
  );
}

void main() {
  test('allow when myRole is member or above', () {
    expect(
      interpretMeGroupDetailForOpen(
        record: _record(
          myRole: GroupMemberRoleType.V2TIM_GROUP_MEMBER_ROLE_MEMBER,
        ),
      ),
      GroupNoticeOpenGate.allow,
    );
    expect(
      interpretMeGroupDetailForOpen(
        record: _record(
          myRole: GroupMemberRoleType.V2TIM_GROUP_MEMBER_ROLE_OWNER,
        ),
      ),
      GroupNoticeOpenGate.allow,
    );
  });

  test('deny when myRole below member', () {
    expect(
      interpretMeGroupDetailForOpen(record: _record(myRole: 0)),
      GroupNoticeOpenGate.denyNotInGroup,
    );
    expect(
      interpretMeGroupDetailForOpen(record: _record(myRole: 100)),
      GroupNoticeOpenGate.denyNotInGroup,
    );
  });

  test('deny when record is null without error code', () {
    expect(
      interpretMeGroupDetailForOpen(record: null),
      GroupNoticeOpenGate.denyNotInGroup,
    );
  });

  test('deny for membership and group-missing error codes', () {
    for (final code in [
      'NOT_GROUP_MEMBER',
      'GROUP_NOT_FOUND',
      'GROUP_DISMISSED',
      'group_not_found',
    ]) {
      expect(
        interpretMeGroupDetailForOpen(errorCode: code),
        GroupNoticeOpenGate.denyNotInGroup,
        reason: code,
      );
    }
  });

  test('unavailable for other error codes', () {
    expect(
      interpretMeGroupDetailForOpen(errorCode: 'TIMEOUT'),
      GroupNoticeOpenGate.unavailable,
    );
    expect(
      interpretMeGroupDetailForOpen(errorCode: 'REQUEST_FAILED'),
      GroupNoticeOpenGate.unavailable,
    );
  });
}
