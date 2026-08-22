///入群申请类型
///
///{@category Enums}
///
// ignore_for_file: constant_identifier_names

class GroupApplicationType {
  ///需要群主或管理员审批的申请加群请求
  static const int V2TIM_GROUP_APPLICATION_GET_TYPE_JOIN = 0;

  ///需要被邀请者同意的被邀请入群请求
  static const int V2TIM_GROUP_APPLICATION_GET_TYPE_INVITE = 1;

  ///需要群主或管理员审批的被邀请入群请求
  static const int V2TIM_GROUP_APPLICATION_NEED_ADMIN_APPROVE = 2;
}
