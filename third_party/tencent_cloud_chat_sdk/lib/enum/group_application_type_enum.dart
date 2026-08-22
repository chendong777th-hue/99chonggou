///入群申请类型
///
///{@category Enums}
///
// ignore_for_file: constant_identifier_names

enum GroupApplicationTypeEnum {
  ///需要群主或管理员审批的申请加群请求
  V2TIM_GROUP_APPLICATION_GET_TYPE_JOIN,

  ///需要被邀请者同意的被邀请入群请求
  V2TIM_GROUP_APPLICATION_GET_TYPE_INVITE,

  ///需要群主或管理员审批的被邀请入群请求
  V2TIM_GROUP_APPLICATION_NEED_ADMIN_APPROVE,
}
