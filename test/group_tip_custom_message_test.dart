import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:tencent_cloud_chat_demo/src/models/group_join_option.dart';
import 'package:tencent_cloud_chat_demo/src/utils/group_tip_custom_message.dart';
import 'package:tencent_cloud_chat_sdk/enum/message_elem_type.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_custom_elem.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_custom_elem.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_message.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_message.dart';

void main() {
  test('buildGroupTipPayload includes businessID and preview', () {
    final payload = buildGroupTipPayload(
      action: 'member_set_admin',
      opUserId: 'u1',
      opUserName: '张三',
      clientMsgId: 'cid-1',
      memberUserIds: const ['u2'],
      memberNames: const ['李四'],
    );
    expect(payload['businessID'], kGroupTipBusinessID);
    expect(payload['action'], 'member_set_admin');
    expect(payload['previewAbstract'], '张三将李四设置为管理员');
    expect(payload['clientMsgId'], 'cid-1');
  });

  test('groupTipDisplayText for leave and notice', () {
    expect(
      groupTipDisplayText({
        'action': 'member_left',
        'opUserName': '王五',
        'memberNames': ['王五'],
      }),
      '王五退出群聊',
    );
    expect(
      groupTipDisplayText({
        'action': 'group_notice_changed',
        'opUserName': '赵六',
      }),
      '赵六修改了群公告',
    );
  });

  test('groupTipDisplayText for join options and privacy', () {
    expect(
      groupTipDisplayText({
        'action': 'group_apply_join_option_changed',
        'opUserName': '甲',
        'detail': {'applyJoinOption': 'free_access'},
      }),
      '甲将申请加群方式修改为自动审批',
    );
    expect(
      groupTipDisplayText({
        'action': 'group_invite_join_option_changed',
        'opUserName': '甲',
        'detail': {'inviteJoinOption': 'disabled'},
      }),
      '甲将邀请好友方式修改为禁止',
    );
    expect(
      groupTipDisplayText({
        'action': 'group_qr_join_disabled',
        'opUserName': '乙',
      }),
      '乙关闭了二维码加群',
    );
    expect(
      groupTipDisplayText({
        'action': 'group_alias_join_enabled',
        'opUserName': '乙',
      }),
      '乙开启了群别名加群',
    );
    expect(
      groupTipDisplayText({
        'action': 'group_privacy_enabled',
        'opUserName': '丙',
      }),
      '丙开启了群成员隐私保护',
    );
  });

  test('groupJoinOptionsTipDiffs only emits changed fields', () {
    const before = GroupJoinOptions(
      applyJoinOption: GroupJoinOption.needPermission,
      inviteJoinOption: GroupJoinOption.freeAccess,
      allowJoinByQrCode: true,
      allowJoinByAlias: true,
    );
    final after = before.copyWith(
      applyJoinOption: GroupJoinOption.disabled,
      allowJoinByQrCode: false,
    );
    final specs = groupJoinOptionsTipDiffs(before, after);
    expect(specs.map((e) => e.action).toList(), [
      'group_apply_join_option_changed',
      'group_qr_join_disabled',
    ]);
    expect(specs.first.detail['applyJoinOption'], 'disabled');
  });

  test('parseGroupTipPayload accepts valid custom', () {
    final message = V2TimMessage.fromJson(<String, dynamic>{
      'message_server_time': 1700000000,
      'message_msg_id': 'm1',
      'message_is_from_self': false,
      'message_status': 2,
      'message_custom_str': '',
      'message_risk_type_identified': 0,
      'message_sender_group_member_info': <String, dynamic>{},
      'message_group_at_user_array': <String>[],
    });
    message.elemType = MessageElemType.V2TIM_ELEM_TYPE_CUSTOM;
    message.customElem = V2TimCustomElem(
      data: jsonEncode(
        buildGroupTipPayload(
          action: 'group_name_changed',
          opUserId: 'u1',
          opUserName: '甲',
          clientMsgId: 'c2',
        ),
      ),
    );
    expect(isGroupTipCustomMessage(message), isTrue);
    expect(groupTipActionOf(message), 'group_name_changed');
  });

  test('parseGroupTipPayload accepts privacy action', () {
    final message = V2TimMessage.fromJson(<String, dynamic>{
      'message_server_time': 1700000000,
      'message_msg_id': 'm2',
      'message_is_from_self': false,
      'message_status': 2,
      'message_custom_str': '',
      'message_risk_type_identified': 0,
      'message_sender_group_member_info': <String, dynamic>{},
      'message_group_at_user_array': <String>[],
    });
    message.elemType = MessageElemType.V2TIM_ELEM_TYPE_CUSTOM;
    message.customElem = V2TimCustomElem(
      data: jsonEncode(
        buildGroupTipPayload(
          action: 'group_privacy_disabled',
          opUserId: 'u1',
          opUserName: '甲',
          clientMsgId: 'c3',
          detail: const {'privacyProtectionEnabled': false},
        ),
      ),
    );
    expect(isGroupTipCustomMessage(message), isTrue);
    expect(groupTipActionOf(message), 'group_privacy_disabled');
    expect(
      groupTipDisplayText(parseGroupTipPayload(message.customElem)!),
      '甲关闭了群成员隐私保护',
    );
  });

  test('isGroupDisplayTipAction and extractGroupTipDisplayFields', () {
    expect(isGroupDisplayTipAction('group_name_changed'), isTrue);
    expect(isGroupDisplayTipAction('group_avatar_changed'), isTrue);
    expect(isGroupDisplayTipAction('member_added'), isFalse);

    final nameFields = extractGroupTipDisplayFields({
      'action': 'group_name_changed',
      'detail': {'groupName': '新群名'},
    });
    expect(nameFields.groupName, '新群名');
    expect(nameFields.avatarUrl, '');

    final avatarFields = extractGroupTipDisplayFields({
      'action': 'group_avatar_changed',
      'detail': {'groupFaceUrl': 'https://example.com/g.png'},
    });
    expect(avatarFields.groupName, '');
    expect(avatarFields.avatarUrl, 'https://example.com/g.png');
  });
}
