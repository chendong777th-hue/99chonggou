import 'dart:convert';

import 'package:tencent_cloud_chat_sdk/enum/group_tips_elem_type.dart';
import 'package:tencent_cloud_chat_sdk/enum/message_elem_type.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_elem.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_user_full_info.dart';
import 'package:tencent_cloud_chat_sdk/native_im/adapter/tim_c_enum.dart';
import 'package:tencent_cloud_chat_sdk/utils/utils.dart';
import 'v2_tim_group_change_info.dart';
import 'v2_tim_group_member_change_info.dart';
import 'v2_tim_group_member_info.dart';

/// V2TimGroupTipsElem
///
/// {@category Models}
///
class V2TimGroupTipsElem extends V2TIMElem {
  late String groupID;
  /// [GroupTipsElemType]
  late int type;
  /// 操作者成员信息
  late V2TimGroupMemberInfo opMember;
  /// 被操作者成员列表
  List<V2TimGroupMemberInfo?>? memberList = List.empty(growable: true);
  /// 群资料变更信息列表
  List<V2TimGroupChangeInfo?>? groupChangeInfoList = List.empty(growable: true);
  /// 群成员变更信息列表
  List<V2TimGroupMemberChangeInfo?>? memberChangeInfoList =
      List.empty(growable: true);
  /// 当前群成员数
  late int? memberCount;

  // imsdk 底层的 tipsType
  int? _sdkTipsType;
  // 加群类型, @ref TIMGroupTipType 为 kTIMGroupTip_Invite 时有效
  int? _joinType;
  // 操作者用户信息
  V2TimUserFullInfo? _opUser;
  // 被操作者用户列表
  List<V2TimUserFullInfo>? _userInfoList = List.empty(growable: true);

  V2TimGroupTipsElem({
    required this.groupID,
    required this.type,
    required this.opMember,
    this.memberList,
    this.groupChangeInfoList,
    this.memberChangeInfoList,
    this.memberCount,
  }): super(elemType: MessageElemType.V2TIM_ELEM_TYPE_GROUP_TIPS);

  V2TimGroupTipsElem.fromJson(Map json) {
    elemType = MessageElemType.V2TIM_ELEM_TYPE_GROUP_TIPS;
    json = Utils.formatJson(json);
    groupID = json['group_tips_elem_group_id'] ?? '';
    _sdkTipsType = json['group_tips_elem_tip_type'] ?? 0;
    type = GroupTipsElemType.GROUP_TIPS_TYPE_INVALID;
    _joinType = null;
    if (_sdkTipsType == CGroupTipsType.GROUP_TIPS_TYPE_JOIN) {
      _joinType = json['group_tips_elem_join_type'];
      if (_joinType == GroupTipsElemType.V2TIM_GROUP_TIPS_TYPE_INVITE) {
        type = GroupTipsElemType.V2TIM_GROUP_TIPS_TYPE_INVITE;
      } else {
        type = GroupTipsElemType.V2TIM_GROUP_TIPS_TYPE_JOIN;
      }
    } else if (_sdkTipsType == CGroupTipsType.GROUP_TIPS_TYPE_QUIT) {
      type = GroupTipsElemType.V2TIM_GROUP_TIPS_TYPE_QUIT;
    } else if (_sdkTipsType == CGroupTipsType.GROUP_TIPS_TYPE_KICK) {
      type = GroupTipsElemType.V2TIM_GROUP_TIPS_TYPE_KICKED;
    } else if (_sdkTipsType == CGroupTipsType.GROUP_TIPS_TYPE_GRANT_ADMINISTRATOR)  {
      type = GroupTipsElemType.V2TIM_GROUP_TIPS_TYPE_SET_ADMIN;
    } else if (_sdkTipsType == CGroupTipsType.GROUP_TIPS_TYPE_REVOKE_ADMINISTRATOR)   {
      type = GroupTipsElemType.V2TIM_GROUP_TIPS_TYPE_CANCEL_ADMIN;
    } else if (_sdkTipsType == CGroupTipsType.GROUP_TIPS_TYPE_GROUP_INFO_CHANGE) {
      type = GroupTipsElemType.V2TIM_GROUP_TIPS_TYPE_GROUP_INFO_CHANGE;
    } else if (_sdkTipsType == CGroupTipsType.GROUP_TIPS_TYPE_GROUP_MEMBER_INFO_CHANGE) {
      type = GroupTipsElemType.V2TIM_GROUP_TIPS_TYPE_MEMBER_INFO_CHANGE;
    } else if (_sdkTipsType == CGroupTipsType.GROUP_TIPS_TYPE_TOPIC_INFO_CHANGE) {
      type = GroupTipsElemType.V2TIM_GROUP_TIPS_TYPE_TOPIC_INFO_CHANGE;
    } else if (_sdkTipsType == CGroupTipsType.GROUP_TIPS_TYPE_PINNED_MESSAGE_ADDED) {
      type = GroupTipsElemType.V2TIM_GROUP_TIPS_TYPE_PINNED_MESSAGE_ADDED;
    } else if (_sdkTipsType == CGroupTipsType.GROUP_TIPS_TYPE_PINNED_MESSAGE_DELETED) {
      type = GroupTipsElemType.V2TIM_GROUP_TIPS_TYPE_PINNED_MESSAGE_DELETED;
    }

    opMember = V2TimGroupMemberInfo.fromJson(json['group_tips_elem_op_group_memberinfo'] ?? {});
    _opUser = V2TimUserFullInfo();
    if (json['group_tips_elem_changed_group_memberinfo_array'] != null) {
      memberList = List.empty(growable: true);
      json['group_tips_elem_changed_group_memberinfo_array'].forEach((v) {
        memberList!.add(V2TimGroupMemberInfo.fromJson(v));
      });
    }
    if (json['group_tips_elem_changed_user_info_array'] != null) {
      _userInfoList = List.empty(growable: true);
      json['group_tips_elem_changed_user_info_array'].forEach((v) {
        _userInfoList!.add(V2TimUserFullInfo.fromJson(v));
      });
    }
    if (json['group_tips_elem_group_change_info_array'] != null) {
      groupChangeInfoList = List.empty(growable: true);
      json['group_tips_elem_group_change_info_array'].forEach((v) {
        groupChangeInfoList!.add(V2TimGroupChangeInfo.fromJson(v));
      });
    }
    if (json['group_tips_elem_member_change_info_array'] != null) {
      memberChangeInfoList = List.empty(growable: true);
      json['group_tips_elem_member_change_info_array'].forEach((v) {
        memberChangeInfoList!.add(V2TimGroupMemberChangeInfo.fromJson(v));
      });
    }
    memberCount = json['group_tips_elem_member_num'];
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['elem_type'] = CElemType.ElemGroupTips;
    data['group_tips_elem_group_id'] = groupID;
    data['group_tips_elem_tip_type'] = _sdkTipsType;
    data['group_tips_elem_join_type'] = _joinType;
    data['group_tips_elem_op_group_memberinfo'] = opMember.toJson();
    if (memberList != null) {
      data['group_tips_elem_changed_group_memberinfo_array'] = memberList?.map((v) => v?.toJson()).toList();
    }
    if (groupChangeInfoList != null) {
      data['group_tips_elem_group_change_info_array'] =
          groupChangeInfoList?.map((v) => v?.toJson()).toList();
    }
    if (memberChangeInfoList != null) {
      data['group_tips_elem_member_change_info_array'] =
          memberChangeInfoList?.map((v) => v?.toJson()).toList();
    }
    data['group_tips_elem_member_num'] = memberCount;
    return data;
  }

  String toLogString() {
    String res =
        "groupID:$groupID|type:$type|opMember:${opMember.toLogString()}|memberCount:$memberCount|memberList:${json.encode(memberList?.map((e) => e?.toLogString()).toList())}|groupChangeInfoList:${json.encode(groupChangeInfoList?.map((e) => e?.toLogString()).toList())}|memberChangeInfoList:${json.encode(memberChangeInfoList?.map((e) => e?.toLogString()).toList())}";
    return res;
  }
}
// {
//   "groupID":"",
//   "type":0,
//   "opMember":{},
//   "memberList":[{}],
//   "groupChangeInfoList":[{}],
//   "memberChangeInfoList":[{}],
//   "memberCount":0
// }
