import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:tencent_cloud_chat_demo/src/utils/group_tips_operator_patch_metadata.dart';
import 'package:tencent_cloud_chat_sdk/enum/message_elem_type.dart';
import 'package:tencent_cloud_chat_sdk/enum/group_tips_elem_type.dart';
import 'package:tencent_cloud_chat_sdk/enum/message_status.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_custom_elem.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_custom_elem.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_group_member_info.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_group_member_info.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_group_tips_elem.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_group_tips_elem.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_message.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_message.dart';
import 'package:tencent_cloud_chat_demo/utils/group_tips_message_helper.dart';
import 'package:tencent_cloud_chat_demo/src/utils/group_tip_custom_message.dart';

V2TimMessage _baseMessage({
  required int elemType,
  String? msgID,
  String? groupID,
  String? localCustomData,
}) {
  final message = V2TimMessage.fromJson(<String, dynamic>{
    'message_server_time': 1700000000,
    'message_msg_id': msgID,
    'message_is_from_self': false,
    'message_status': MessageStatus.V2TIM_MSG_STATUS_SEND_SUCC,
    'message_custom_str': localCustomData ?? '',
    'message_risk_type_identified': 0,
    'message_sender_group_member_info': <String, dynamic>{},
    'message_group_at_user_array': <String>[],
  });
  message.elemType = elemType;
  message.msgID = msgID;
  message.groupID = groupID;
  message.localCustomData = localCustomData;
  return message;
}

V2TimMessage _groupTipsMessage({
  required String opUserId,
  required String groupId,
  int type = GroupTipsElemType.V2TIM_GROUP_TIPS_TYPE_INVITE,
  String? localCustomData,
}) {
  final message = _baseMessage(
    elemType: MessageElemType.V2TIM_ELEM_TYPE_GROUP_TIPS,
    groupID: groupId,
    localCustomData: localCustomData,
  );
  message.groupTipsElem = V2TimGroupTipsElem(
    groupID: groupId,
    type: type,
    opMember: V2TimGroupMemberInfo(userID: opUserId),
  );
  return message;
}

V2TimMessage _groupCreateMessage({
  required String groupId,
  String msgID = 'gc1',
}) {
  final message = _baseMessage(
    elemType: MessageElemType.V2TIM_ELEM_TYPE_CUSTOM,
    msgID: msgID,
    groupID: groupId,
  );
  message.customElem = V2TimCustomElem(
    data: jsonEncode(<String, dynamic>{'businessID': 'group_create'}),
  );
  return message;
}

V2TimMessage _localMemberAddedTip({
  required String groupId,
  List<String> memberUserIds = const ['alice'],
}) {
  final message = _baseMessage(
    elemType: MessageElemType.V2TIM_ELEM_TYPE_GROUP_TIPS,
    msgID: 'local_gt_1',
    groupID: groupId,
    localCustomData: jsonEncode(<String, dynamic>{
      'localGroupTips': true,
      'action': 'member_added',
    }),
  );
  message.groupTipsElem = V2TimGroupTipsElem(
    groupID: groupId,
    type: GroupTipsElemType.V2TIM_GROUP_TIPS_TYPE_INVITE,
    opMember: V2TimGroupMemberInfo(userID: 'owner'),
    memberList: memberUserIds
        .map((id) => V2TimGroupMemberInfo(userID: id))
        .toList(),
  );
  return message;
}

V2TimMessage _sdkInviteTip({
  required String groupId,
  required String opUserId,
  List<String> memberUserIds = const ['alice'],
  String? localCustomData,
}) {
  final message = _groupTipsMessage(
    opUserId: opUserId,
    groupId: groupId,
    localCustomData: localCustomData,
  );
  message.groupTipsElem = V2TimGroupTipsElem(
    groupID: groupId,
    type: GroupTipsElemType.V2TIM_GROUP_TIPS_TYPE_INVITE,
    opMember: V2TimGroupMemberInfo(userID: opUserId),
    memberList: memberUserIds
        .map((id) => V2TimGroupMemberInfo(userID: id))
        .toList(),
  );
  return message;
}

V2TimMessage _localCancelAdminTip({
  required String groupId,
  List<String> memberUserIds = const ['alice'],
  String msgID = 'local_cancel_admin_1',
}) {
  final message = _baseMessage(
    elemType: MessageElemType.V2TIM_ELEM_TYPE_GROUP_TIPS,
    msgID: msgID,
    groupID: groupId,
    localCustomData: jsonEncode(<String, dynamic>{
      'localGroupTips': true,
      'action': 'member_cancel_admin',
    }),
  );
  message.groupTipsElem = V2TimGroupTipsElem(
    groupID: groupId,
    type: GroupTipsElemType.V2TIM_GROUP_TIPS_TYPE_CANCEL_ADMIN,
    opMember: V2TimGroupMemberInfo(userID: 'owner'),
    memberList: memberUserIds
        .map((id) => V2TimGroupMemberInfo(userID: id))
        .toList(),
  );
  return message;
}

V2TimMessage _sdkCancelAdminTip({
  required String groupId,
  required String opUserId,
  List<String> memberUserIds = const ['alice'],
  String msgID = 'sdk_cancel_admin_1',
}) {
  final message = _baseMessage(
    elemType: MessageElemType.V2TIM_ELEM_TYPE_GROUP_TIPS,
    msgID: msgID,
    groupID: groupId,
  );
  message.groupTipsElem = V2TimGroupTipsElem(
    groupID: groupId,
    type: GroupTipsElemType.V2TIM_GROUP_TIPS_TYPE_CANCEL_ADMIN,
    opMember: V2TimGroupMemberInfo(userID: opUserId),
    memberList: memberUserIds
        .map((id) => V2TimGroupMemberInfo(userID: id))
        .toList(),
  );
  return message;
}

V2TimMessage _sdkSetAdminTip({
  required String groupId,
  required String opUserId,
  List<String> memberUserIds = const ['alice'],
  String msgID = 'sdk_set_admin_1',
}) {
  final message = _baseMessage(
    elemType: MessageElemType.V2TIM_ELEM_TYPE_GROUP_TIPS,
    msgID: msgID,
    groupID: groupId,
  );
  message.groupTipsElem = V2TimGroupTipsElem(
    groupID: groupId,
    type: GroupTipsElemType.V2TIM_GROUP_TIPS_TYPE_SET_ADMIN,
    opMember: V2TimGroupMemberInfo(userID: opUserId),
    memberList: memberUserIds
        .map((id) => V2TimGroupMemberInfo(userID: id))
        .toList(),
  );
  return message;
}

V2TimMessage _groupTipCustom({
  required String groupId,
  required String action,
  List<String> memberUserIds = const ['alice'],
  String msgID = 'group_tip_custom_1',
}) {
  final message = _baseMessage(
    elemType: MessageElemType.V2TIM_ELEM_TYPE_CUSTOM,
    msgID: msgID,
    groupID: groupId,
  );
  message.customElem = V2TimCustomElem(
    data: jsonEncode(<String, dynamic>{
      'businessID': 'group_tip',
      'action': action,
      'opUserId': 'owner',
      'opUserName': '群主',
      'memberUserIds': memberUserIds,
      'memberNames': memberUserIds,
      'previewAbstract': action == 'member_set_admin'
          ? '群主将alice设置为管理员'
          : '群主将alice取消管理员',
    }),
  );
  return message;
}

void main() {
  test('isSelfOperated matches group tips operator', () {
    final message = _groupTipsMessage(
      opUserId: 'user_a',
      groupId: 'g1',
      type: GroupTipsElemType.V2TIM_GROUP_TIPS_TYPE_KICKED,
    );
    expect(GroupTipsMessageHelper.isSelfOperated(message, 'user_a'), isTrue);
    expect(GroupTipsMessageHelper.isSelfOperated(message, 'user_b'), isFalse);
  });

  test('isSilentGroupTipMessage covers admin role changes', () {
    final setAdmin = _groupTipsMessage(
      opUserId: 'owner',
      groupId: 'g1',
      type: GroupTipsElemType.V2TIM_GROUP_TIPS_TYPE_SET_ADMIN,
    );
    final cancelAdmin = _groupTipsMessage(
      opUserId: 'owner',
      groupId: 'g1',
      type: GroupTipsElemType.V2TIM_GROUP_TIPS_TYPE_CANCEL_ADMIN,
    );
    final invite = _groupTipsMessage(
      opUserId: 'owner',
      groupId: 'g1',
      type: GroupTipsElemType.V2TIM_GROUP_TIPS_TYPE_INVITE,
    );

    expect(GroupTipsMessageHelper.isSilentGroupTipMessage(setAdmin), isTrue);
    expect(GroupTipsMessageHelper.isSilentGroupTipMessage(cancelAdmin), isTrue);
    expect(GroupTipsMessageHelper.isSilentGroupTipMessage(invite), isFalse);
  });

  test('shouldSuppressConversationUnread covers all native group tips', () {
    final invite = _groupTipsMessage(
      opUserId: 'owner',
      groupId: 'g1',
      type: GroupTipsElemType.V2TIM_GROUP_TIPS_TYPE_INVITE,
    );
    final setAdmin = _groupTipsMessage(
      opUserId: 'owner',
      groupId: 'g1',
      type: GroupTipsElemType.V2TIM_GROUP_TIPS_TYPE_SET_ADMIN,
    );
    expect(
      GroupTipsMessageHelper.shouldSuppressConversationUnread(invite),
      isTrue,
    );
    expect(
      GroupTipsMessageHelper.shouldSuppressConversationUnread(setAdmin),
      isTrue,
    );
  });

  test('normalizeGroupTipPreviewDisplay replaces administrator prefix', () {
    expect(
      GroupTipsMessageHelper.normalizeGroupTipPreviewDisplay(
        'administrator邀请陈东66999加入群组',
      ),
      '${GroupTipsMessageHelper.normalizeGroupOperatorDisplayName('administrator')}邀请陈东66999加入群组',
    );
  });

  test('conversationId normalizes group conversation id', () {
    final message = _groupTipsMessage(opUserId: 'u1', groupId: 'g123');
    expect(
      GroupTipsMessageHelper.conversationId(message),
      'group_g123',
    );
  });

  test('filterSuppressedGroupCreateDuplicates ignores deprecated local member tip coverage', () {
    const groupId = '@TGS#g123';
    final messages = [
      _groupCreateMessage(groupId: groupId),
      _localMemberAddedTip(groupId: groupId),
    ];
    final filtered =
        GroupTipsMessageHelper.filterSuppressedGroupCreateDuplicates(messages);
    // 本地 member tip 已废弃，不能作为建群 coverage；两条都保留到后置过滤再剥本地 tip。
    expect(filtered.length, 2);
  });

  test('filterSuppressedGroupCreateDuplicates hides group_create when SDK INVITE exists', () {
    const groupId = '@TGS#g123';
    final messages = [
      _groupCreateMessage(groupId: groupId),
      _groupTipsMessage(opUserId: 'owner', groupId: groupId),
    ];
    final filtered =
        GroupTipsMessageHelper.filterSuppressedGroupCreateDuplicates(messages);
    expect(filtered.length, 1);
    expect(GroupTipsMessageHelper.isGroupTipsMessage(filtered.single), isTrue);
  });

  test('filterSuppressedGroupCreateDuplicates hides group_create when operator patch member_added exists', () {
    const groupId = '@TGS#g123';
    final patched = _groupTipsMessage(
      opUserId: 'owner',
      groupId: groupId,
      type: GroupTipsElemType.V2TIM_GROUP_TIPS_TYPE_KICKED,
      localCustomData: GroupTipsOperatorPatchMetadata.mergePatch(
        existingRaw: null,
        changeEventId: 'ce1',
        resolvedOperatorUserId: 'owner',
        previewAbstract: 'owner invited alice',
        action: 'member_added',
      ),
    );
    patched.msgID = 'patched_tip';
    final messages = [
      _groupCreateMessage(groupId: groupId),
      patched,
    ];
    final filtered =
        GroupTipsMessageHelper.filterSuppressedGroupCreateDuplicates(messages);
    expect(filtered.length, 1);
    expect(filtered.single.msgID, 'patched_tip');
  });

  test('filterSuppressedGroupCreateDuplicates keeps one group_create without coverage', () {
    const groupId = '@TGS#g123';
    final messages = [
      _groupCreateMessage(groupId: groupId, msgID: 'gc_dup'),
      _groupCreateMessage(groupId: groupId, msgID: 'gc_keep'),
    ];
    final filtered =
        GroupTipsMessageHelper.filterSuppressedGroupCreateDuplicates(messages);
    expect(filtered.length, 1);
    expect(filtered.single.msgID, 'gc_dup');
  });

  test('isGroupCreateRedundantWithHistory ignores deprecated local member tip', () {
    const groupId = '@TGS#g123';
    final preview = _groupCreateMessage(groupId: groupId);
    final history = [_localMemberAddedTip(groupId: groupId)];
    expect(
      GroupTipsMessageHelper.isGroupCreateRedundantWithHistory(preview, history),
      isFalse,
    );
  });

  test('applyPostMergeFilters drops deprecated local member tips', () {
    const groupId = '@TGS#g123';
    final messages = [
      _groupCreateMessage(groupId: groupId),
      _localMemberAddedTip(groupId: groupId),
    ];
    final filtered = GroupTipsMessageHelper.applyPostMergeFilters(messages);
    expect(filtered.length, 1);
    expect(GroupTipsMessageHelper.isGroupCreateCustomMessage(filtered.single), isTrue);
  });

  test('filterSuppressedRedundantMemberTips ignores deprecated local tip', () {
    const groupId = '@TGS#g123';
    final messages = [
      _localMemberAddedTip(groupId: groupId),
      _sdkInviteTip(groupId: groupId, opUserId: 'owner'),
    ];
    final filtered =
        GroupTipsMessageHelper.filterSuppressedRedundantMemberTips(messages);
    // 本地 tip 无 semantic key，不会被本过滤器删掉；由 applyPostMergeFilters 剥离。
    expect(filtered.length, 2);
    expect(
      filtered.where(GroupTipsMessageHelper.isLocalGroupTips).length,
      1,
    );
  });

  test('applyPostMergeFilters keeps SDK invite and drops local tip', () {
    const groupId = '@TGS#g123';
    final patched = _sdkInviteTip(
      groupId: groupId,
      opUserId: 'owner',
      localCustomData: GroupTipsOperatorPatchMetadata.mergePatch(
        existingRaw: null,
        changeEventId: 'ce1',
        resolvedOperatorUserId: 'owner',
        previewAbstract: 'owner invited alice',
        action: 'member_added',
      ),
    );
    patched.msgID = 'sdk_tip';
    final messages = [
      _localMemberAddedTip(groupId: groupId),
      patched,
    ];
    final filtered = GroupTipsMessageHelper.applyPostMergeFilters(messages);
    expect(filtered.length, 1);
    expect(filtered.single.msgID, 'sdk_tip');
  });

  test('actionForTipsType maps JOIN to member_added', () {
    expect(
      GroupTipsMessageHelper.actionForTipsType(
        GroupTipsElemType.V2TIM_GROUP_TIPS_TYPE_JOIN,
      ),
      'member_added',
    );
  });

  test('isDeprecatedLocalMemberTip detects local member actions', () {
    expect(
      GroupTipsMessageHelper.isDeprecatedLocalMemberTip(
        _localMemberAddedTip(groupId: '@TGS#g1'),
      ),
      isTrue,
    );
  });

  test('actionForTipsType maps set/cancel admin', () {
    expect(
      GroupTipsMessageHelper.actionForTipsType(
        GroupTipsElemType.V2TIM_GROUP_TIPS_TYPE_SET_ADMIN,
      ),
      'member_set_admin',
    );
    expect(
      GroupTipsMessageHelper.actionForTipsType(
        GroupTipsElemType.V2TIM_GROUP_TIPS_TYPE_CANCEL_ADMIN,
      ),
      'member_cancel_admin',
    );
  });

  test('isRolePlaceholderNick recognizes chinese admin labels', () {
    expect(GroupTipsMessageHelper.isRolePlaceholderNick('管理员'), isTrue);
    expect(GroupTipsMessageHelper.isRolePlaceholderNick('管理員'), isTrue);
    expect(GroupTipsMessageHelper.isRolePlaceholderNick('阿伦'), isFalse);
  });

  test('filterSuppressedAdministratorTips hides all IM native admin tips', () {
    const groupId = '@TGS#g123';
    final imPlaceholder =
        _sdkCancelAdminTip(groupId: groupId, opUserId: 'administrator');
    final imRealOp = _sdkSetAdminTip(
      groupId: groupId,
      opUserId: 'owner_uid',
      msgID: 'sdk_set_admin_real',
    );
    final filtered = GroupTipsMessageHelper.filterSuppressedAdministratorTips([
      imPlaceholder,
      imRealOp,
    ]);
    expect(filtered, isEmpty);
  });

  test('filterSuppressedAdministratorTips drops local admin tips too', () {
    const groupId = '@TGS#g123';
    final local = _localCancelAdminTip(groupId: groupId);
    final im = _sdkCancelAdminTip(groupId: groupId, opUserId: 'administrator');
    final filtered =
        GroupTipsMessageHelper.filterSuppressedAdministratorTips([local, im]);
    expect(filtered, isEmpty);
  });

  test('filterSuppressedAdministratorTips keeps App group_tip Custom', () {
    const groupId = '@TGS#g123';
    final custom = _groupTipCustom(
      groupId: groupId,
      action: 'member_set_admin',
      memberUserIds: const ['alice'],
    );
    final im = _sdkSetAdminTip(groupId: groupId, opUserId: '管理员');
    final filtered = GroupTipsMessageHelper.filterSuppressedAdministratorTips([
      custom,
      im,
    ]);
    expect(filtered.length, 1);
    expect(isGroupTipCustomMessage(filtered.single), isTrue);
  });

  test('applyPostMergeFilters hides IM admin and keeps Custom', () {
    const groupId = '@TGS#g123';
    final custom = _groupTipCustom(
      groupId: groupId,
      action: 'member_cancel_admin',
      memberUserIds: const ['alice'],
    );
    final local = _localCancelAdminTip(groupId: groupId);
    final im = _sdkCancelAdminTip(groupId: groupId, opUserId: '管理员');
    final filtered = GroupTipsMessageHelper.applyPostMergeFilters([
      custom,
      local,
      im,
    ]);
    expect(filtered.length, 1);
    expect(isGroupTipCustomMessage(filtered.single), isTrue);
  });

  test('isImNativeAdminRoleTip true only for SDK SET/CANCEL_ADMIN', () {
    expect(
      GroupTipsMessageHelper.isImNativeAdminRoleTip(
        _sdkSetAdminTip(groupId: 'g1', opUserId: 'owner'),
      ),
      isTrue,
    );
    expect(
      GroupTipsMessageHelper.isImNativeAdminRoleTip(
        _localCancelAdminTip(groupId: 'g1'),
      ),
      isFalse,
    );
    expect(
      GroupTipsMessageHelper.isImNativeAdminRoleTip(
        _groupTipCustom(
          groupId: 'g1',
          action: 'member_set_admin',
          memberUserIds: const ['alice'],
        ),
      ),
      isFalse,
    );
  });

  test('filterSdkTipsCoveredByGroupTipCustom hides matching SDK invite tip', () {
    const groupId = 'g_cover';
    final custom = _baseMessage(
      elemType: MessageElemType.V2TIM_ELEM_TYPE_CUSTOM,
      msgID: 'gt1',
      groupID: groupId,
    );
    custom.customElem = V2TimCustomElem(
      data: jsonEncode(<String, dynamic>{
        'businessID': 'group_tip',
        'action': 'member_added',
        'opUserId': 'op1',
        'opUserName': '甲',
        'memberUserIds': <String>['alice'],
        'memberNames': <String>['爱丽丝'],
        'previewAbstract': '甲邀请爱丽丝加入群组',
        'clientMsgId': 'c1',
      }),
    );
    final sdk = _groupTipsMessage(
      opUserId: 'op1',
      groupId: groupId,
      type: GroupTipsElemType.V2TIM_GROUP_TIPS_TYPE_INVITE,
    );
    sdk.groupTipsElem = V2TimGroupTipsElem(
      groupID: groupId,
      type: GroupTipsElemType.V2TIM_GROUP_TIPS_TYPE_INVITE,
      opMember: V2TimGroupMemberInfo(userID: 'op1'),
      memberList: <V2TimGroupMemberInfo>[
        V2TimGroupMemberInfo(userID: 'alice'),
      ],
    );
    final filtered = GroupTipsMessageHelper.filterSdkTipsCoveredByGroupTipCustom(
      [custom, sdk],
    );
    expect(filtered.length, 1);
    expect(filtered.single.msgID, 'gt1');
  });
}
