import 'package:tencent_cloud_chat_sdk/enum/message_elem_type.dart';
import 'package:tencent_cloud_chat_sdk/enum/receive_message_opt_enum.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_elem.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_group_member_info.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_user_full_info.dart';
import 'package:tencent_cloud_chat_sdk/native_im/adapter/tim_c_enum.dart';
import 'package:tencent_cloud_chat_sdk/utils/utils.dart';
import 'package:tencent_cloud_chat_sdk/enum/utils.dart';

/// V2TimGroupReportElem
///
/// {@category Models}
///
class V2TimGroupReportElem extends V2TIMElem {
  // 群系统通知类型
  // 未知类型
  static const int kTIMGroupReport_None = 0;
  // 申请加群(只有管理员会接收到)
  static const int kTIMGroupReport_AddRequest = 1;
  // 申请加群被同意(只有申请人自己接收到)
  static const int kTIMGroupReport_AddAccept = 2;
  // 申请加群被拒绝(只有申请人自己接收到)
  static const int kTIMGroupReport_AddRefuse = 3;
  // 被管理员踢出群(只有被踢者接收到)
  static const int kTIMGroupReport_BeKicked = 4;
  // 群被解散(全员接收)
  static const int kTIMGroupReport_Delete = 5;
  // 创建群(创建者接收, 不展示)
  static const int kTIMGroupReport_Create = 6;
  // 无需被邀请者同意，拉入群中（例如工作群）
  static const int kTIMGroupReport_Invite = 7;
  // 主动退群(主动退出者接收, 不展示)
  static const int kTIMGroupReport_Quit = 8;
  // 设置管理员(被设置者接收)
  static const int kTIMGroupReport_GrantAdmin = 9;
  // 取消管理员(被取消者接收)
  static const int kTIMGroupReport_CancelAdmin = 10;
  // 群已被回收(全员接收, 不展示)
  static const int kTIMGroupReport_GroupRecycle = 11;
  // 需要被邀请者审批的邀请入群请求
  static const int kTIMGroupReport_InviteReqToInvitee = 12;
  // 邀请加群被同意(只有发出邀请者会接收到)
  static const int kTIMGroupReport_InviteAccept = 13;
  // 邀请加群被拒绝(只有发出邀请者会接收到)
  static const int kTIMGroupReport_InviteRefuse = 14;
  // 已读上报多终端同步通知(只有上报人自己收到)
  static const int kTIMGroupReport_ReadReport = 15;
  // 用户自定义通知(默认全员接收)
  static const int kTIMGroupReport_UserDefine = 16;
  // 禁言某些用户(被禁言的用户收到)
  static const int kTIMGroupReport_ShutUpMember = 17;
  // 话题创建
  static const int kTIMGroupReport_TopicCreate = 18;
  // 话题被删除
  static const int kTIMGroupReport_TopicDelete = 19;
  // 群消息已读回执通知
  static const int kTIMGroupReport_GroupMessageRead = 20;
  // 消息接收选项变更通知
  static const int kTIMGroupReport_GroupMessageRecvOption = 21;
  // 被封禁通知
  static const int kTIMGroupReport_BannedFromGroup = 22;
  // 被解封通知
  static const int kTIMGroupReport_UnbannedFromGroup = 23;
  // 需要群主或管理员审批的邀请入群请求
  static const int kTIMGroupReport_InviteReqToAdmin = 24;


  late int type;
  late String groupID;
  // 操作者个人资料信息
  String? opUserID;
  V2TimUserFullInfo? opUserInfo;
  // 操作者群内信息
  V2TimGroupMemberInfo? opMemberInfo;
  // 操作理由
  String? reason;
  // 操作者填写的自定义信息
  String? customData;
  // 操作方平台信息
  String? platform;
  // 被操作者的禁言时间(禁言某些用户时，被禁言的用户会收到该信息)
  int? shutUpTime;
  // 消息接收选项, 用户修改群消息接收选项时会收到该信息
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
  }): super(elemType: MessageElemType.V2TIM_ELEM_TYPE_GROUP_REPORT);

  V2TimGroupReportElem.fromJson(Map json) {
    elemType = MessageElemType.V2TIM_ELEM_TYPE_GROUP_REPORT;
    json = Utils.formatJson(json);
    groupID = json['group_report_elem_group_id'] ?? '';
    type = json['group_report_elem_report_type'] ?? kTIMGroupReport_None;
    opUserID = json['group_report_elem_op_user'];
    if (json['group_report_elem_op_user_info'] != null) {
      opUserInfo = V2TimUserFullInfo.fromJson(json['group_report_elem_op_user_info']);
    }
    if (json['group_report_elem_op_group_memberinfo'] != null) {
      opMemberInfo = V2TimGroupMemberInfo.fromJson(json['group_report_elem_op_group_memberinfo']);
    }
    reason = json['group_report_elem_msg'];
    customData = json['group_report_elem_user_data'];
    platform = json['group_report_elem_platform'];
    shutUpTime = json['group_report_elem_shut_up_time'];
    messageReceiveOpt = EnumUtils.cReceiveMessageOpt2DartOpt(json['group_report_elem_group_message_receive_option'] ?? 0).index;
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['elem_type'] = CElemType.ElemGroupReport;
    data['group_report_elem_group_id'] = groupID;
    data['group_report_elem_report_type'] = type;
    data['group_report_elem_op_user'] = opUserID;
    if (opUserInfo != null) {
      data['group_report_elem_op_user_info'] = opUserInfo?.toJson();
    }

    if (opMemberInfo != null) {
      data['group_report_elem_op_group_memberinfo'] = opMemberInfo?.toJson();
    }
    data['group_report_elem_msg'] = reason;
    data['group_report_elem_user_data'] = customData;
    data['group_report_elem_platform'] = platform;
    data['group_report_elem_shut_up_time'] = shutUpTime;
    data['group_report_elem_group_message_receive_option'] = messageReceiveOpt != null ? EnumUtils.dartReceiveMessageOpt2CReceiveMessageOpt(ReceiveMsgOptEnum.values[messageReceiveOpt!]) : null;
    return data;
  }

  String toLogString() {
    String res =
        "groupID:$groupID|type:$type|opUserID:$opUserID|opUserInfo:${opUserInfo?.toLogString()}|opMemberInfo:${opMemberInfo?.toLogString()}|reason:$reason|customData:$customData|platform:$platform|shutUpTime:$shutUpTime|messageReceiveOpt:$messageReceiveOpt";
    return res;
  }
}
