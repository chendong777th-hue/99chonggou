import 'package:tencent_cloud_chat_sdk/enum/message_elem_type.dart';
import 'package:tencent_cloud_chat_sdk/utils/utils.dart';
import 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_elem.dart';
import 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_group_member_info.dart';
import 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_user_full_info.dart';

/// Web-compatible group system notification element.
class V2TimGroupReportElem extends V2TIMElem {
  static const int kTIMGroupReport_None = 0;
  static const int kTIMGroupReport_AddRequest = 1;
  static const int kTIMGroupReport_AddAccept = 2;
  static const int kTIMGroupReport_AddRefuse = 3;
  static const int kTIMGroupReport_BeKicked = 4;
  static const int kTIMGroupReport_Delete = 5;
  static const int kTIMGroupReport_Create = 6;
  static const int kTIMGroupReport_Invite = 7;
  static const int kTIMGroupReport_Quit = 8;
  static const int kTIMGroupReport_GrantAdmin = 9;
  static const int kTIMGroupReport_CancelAdmin = 10;
  static const int kTIMGroupReport_GroupRecycle = 11;
  static const int kTIMGroupReport_InviteReqToInvitee = 12;
  static const int kTIMGroupReport_InviteAccept = 13;
  static const int kTIMGroupReport_InviteRefuse = 14;
  static const int kTIMGroupReport_ReadReport = 15;
  static const int kTIMGroupReport_UserDefine = 16;
  static const int kTIMGroupReport_ShutUpMember = 17;
  static const int kTIMGroupReport_TopicCreate = 18;
  static const int kTIMGroupReport_TopicDelete = 19;
  static const int kTIMGroupReport_GroupMessageRead = 20;
  static const int kTIMGroupReport_GroupMessageRecvOption = 21;
  static const int kTIMGroupReport_BannedFromGroup = 22;
  static const int kTIMGroupReport_UnbannedFromGroup = 23;
  static const int kTIMGroupReport_InviteReqToAdmin = 24;

  late int type;
  late String groupID;
  String? opUserID;
  V2TimUserFullInfo? opUserInfo;
  V2TimGroupMemberInfo? opMemberInfo;
  String? reason;
  String? customData;
  String? platform;
  int? shutUpTime;
  int? messageReceiveOpt;

  V2TimGroupReportElem({
    required this.groupID,
    required this.type,
    this.opUserID,
    this.opUserInfo,
    this.opMemberInfo,
    this.reason,
    this.customData,
    this.platform,
    this.shutUpTime,
    this.messageReceiveOpt,
  }) : super(elemType: MessageElemType.V2TIM_ELEM_TYPE_GROUP_REPORT);

  V2TimGroupReportElem.fromJson(Map json) {
    elemType = MessageElemType.V2TIM_ELEM_TYPE_GROUP_REPORT;
    json = Utils.formatJson(json);
    groupID = (json['groupID'] ??
            json['group_report_elem_group_id'] ??
            '')
        .toString();
    type = json['type'] ??
        json['group_report_elem_report_type'] ??
        kTIMGroupReport_None;
    opUserID = json['opUserID'] ?? json['group_report_elem_op_user'];
    final userInfo = json['opUserInfo'] ?? json['group_report_elem_op_user_info'];
    if (userInfo is Map) {
      opUserInfo = V2TimUserFullInfo.fromJson(Map<String, dynamic>.from(userInfo));
    }
    final memberInfo =
        json['opMemberInfo'] ?? json['group_report_elem_op_group_memberinfo'];
    if (memberInfo is Map) {
      opMemberInfo =
          V2TimGroupMemberInfo.fromJson(Map<String, dynamic>.from(memberInfo));
    }
    reason = json['reason'] ?? json['group_report_elem_msg'];
    customData = json['customData'] ?? json['group_report_elem_user_data'];
    platform = json['platform'] ?? json['group_report_elem_platform'];
    shutUpTime = json['shutUpTime'] ?? json['group_report_elem_shut_up_time'];
    messageReceiveOpt = json['messageReceiveOpt'] ??
        json['group_report_elem_group_message_receive_option'];
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'elem_type': MessageElemType.V2TIM_ELEM_TYPE_GROUP_REPORT,
      'groupID': groupID,
      'type': type,
      'opUserID': opUserID,
      'opUserInfo': opUserInfo?.toJson(),
      'opMemberInfo': opMemberInfo?.toJson(),
      'reason': reason,
      'customData': customData,
      'platform': platform,
      'shutUpTime': shutUpTime,
      'messageReceiveOpt': messageReceiveOpt,
    };
  }

  String toLogString() {
    return 'groupID:$groupID|type:$type|opUserID:$opUserID|reason:$reason';
  }
}
