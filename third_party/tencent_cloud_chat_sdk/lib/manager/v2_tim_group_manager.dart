// ignore_for_file: unused_field
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:tencent_cloud_chat_sdk/enum/group_add_opt_enum.dart';
import 'package:tencent_cloud_chat_sdk/enum/group_application_type_enum.dart';
import 'package:tencent_cloud_chat_sdk/enum/group_member_filter_enum.dart';
import 'package:tencent_cloud_chat_sdk/enum/group_member_role_enum.dart';
import 'package:tencent_cloud_chat_sdk/enum/group_type.dart';
import 'package:tencent_cloud_chat_sdk/enum/utils.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_callback.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_callback.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_group_application.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_group_application.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_group_application_result.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_group_application_result.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_group_info.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_group_info.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_group_info_result.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_group_info_result.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_group_member_full_info.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_group_member_full_info.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_group_member_info_result.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_group_member_info_result.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_group_member_operation_result.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_group_member_operation_result.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_group_search_result.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_group_search_result.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_group_member_search_param.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_group_member_search_param.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_group_member_search_result.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_group_member_search_result.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_group_search_param.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_group_search_param.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_value_callback.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_value_callback.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_group_member.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_group_member.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_topic_info.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_topic_info.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_topic_info_result.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_topic_info_result.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_topic_operation_result.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_topic_operation_result.dart';
import 'package:tencent_cloud_chat_sdk/native_im/adapter/tim_group_manager.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/native_im/adapter/tim_group_manager_dummy.dart';
import 'package:tencent_cloud_chat_sdk/tencent_cloud_chat_sdk_platform_interface.dart';

class V2TIMGroupManager {
  ///创建自定义群组（高级版本：可以指定初始的群成员）
  ///
  /// 参数
  ///
  /// ```
  /// info  自定义群组信息，可以设置 groupID | groupType | groupName | notification | introduction | faceURL 字段
  /// memberList	指定初始的群成员（直播群 AVChatRoom 不支持指定初始群成员，memberList 请传 null）
  /// ```
  ///
  /// 注意
  ///
  /// ```
  /// 其他限制请参考V2TIMManager.createGroup注释
  /// isSupportTopic 仅对社群有效
  /// ```
  Future<V2TimValueCallback<String>> createGroup({
    String? groupID,
    required String groupType,
    required String groupName,
    String? notification,
    String? introduction,
    String? faceUrl,
    bool? isAllMuted,
    bool? isSupportTopic = false,
    GroupAddOptTypeEnum? addOpt,
    List<V2TimGroupMember>? memberList,
    GroupAddOptTypeEnum? approveOpt,
    bool? isEnablePermissionGroup,
    int? defaultPermissions,
  }) async {
    // add a default number.
    GroupAddOptTypeEnum addOptDefault = addOpt == null
        ? GroupAddOptTypeEnum.V2TIM_GROUP_ADD_ANY
        : (groupType == GroupType.AVChatRoom ? GroupAddOptTypeEnum.V2TIM_GROUP_ADD_ANY : addOpt);
    GroupAddOptTypeEnum approveOptDefault = approveOpt == null
        ? (groupType == GroupType.Work
          ? GroupAddOptTypeEnum.V2TIM_GROUP_ADD_ANY
          : GroupAddOptTypeEnum.V2TIM_GROUP_ADD_FORBID)
        : (groupType == GroupType.AVChatRoom ? GroupAddOptTypeEnum.V2TIM_GROUP_ADD_FORBID : approveOpt);
    if (kIsWeb) {
      return TencentCloudChatSdkPlatform.instance.createGroup(
        groupType: groupType,
        groupName: groupName,
        groupID: groupID,
        notification: notification,
        introduction: introduction,
        faceUrl: faceUrl,
        isAllMuted: isAllMuted,
        addOpt: addOptDefault.index,
        memberList: memberList,
        isSupportTopic: isSupportTopic,
        approveOpt: approveOptDefault.index,
        isEnablePermissionGroup: isEnablePermissionGroup,
        defaultPermissions: defaultPermissions,
      );
    }

    return TIMGroupManager.instance.createGroup(
      groupType: groupType,
      groupName: groupName,
      groupID: groupID,
      notification: notification,
      introduction: introduction,
      faceUrl: faceUrl,
      isAllMuted: isAllMuted,
      addOpt: addOptDefault,
      memberList: memberList,
      isSupportTopic: isSupportTopic,
      approveOpt: approveOptDefault,
      isEnablePermissionGroup: isEnablePermissionGroup,
      defaultPermissions: defaultPermissions,
    );
  }

  /// 获取当前用户已经加入的群列表
  ///
  /// 注意
  ///
  /// ```
  /// 直播群(AVChatRoom) 不支持该 API。
  /// 该接口有频限检测，SDK 限制调用频率为1 秒 10 次，超过限制后会报 ERR_SDK_COMM_API_CALL_FREQUENCY_LIMIT （7008）错误
  /// ```
  Future<V2TimValueCallback<List<V2TimGroupInfo>>> getJoinedGroupList() async {
    if (kIsWeb) {
      return TencentCloudChatSdkPlatform.instance.getJoinedGroupList();
    }
    return TIMGroupManager.instance.getJoinedGroupList();
  }

  /// 拉取群资料
  ///
  /// 参数
  ///
  /// ```
  /// groupIDList	群 ID 列表
  /// ```
  Future<V2TimValueCallback<List<V2TimGroupInfoResult>>> getGroupsInfo({
    required List<String> groupIDList,
  }) async {
    if (kIsWeb) {
      return TencentCloudChatSdkPlatform.instance.getGroupsInfo(groupIDList: groupIDList);
    }
    return TIMGroupManager.instance.getGroupsInfo(groupIDList: groupIDList);
  }

  ///修改群资料
  ///
  ///参数：
  ///[V2TimGroupInfo]  群资料参数
  Future<V2TimCallback> setGroupInfo({
    required V2TimGroupInfo info,
  }) async {
    if (kIsWeb) {
      return TencentCloudChatSdkPlatform.instance.setGroupInfo(info: info);
    }
    return TIMGroupManager.instance.setGroupInfo(info: info);
  }

  /// 初始化群属性，会清空原有的群属性列表
  ///
  /// 注意
  ///
  /// attributes 的使用限制如下：
  ///
  /// ```
  /// 1、目前只支持 AVChatRoom
  /// 2、key 最多支持16个，长度限制为32字节
  /// 3、value 长度限制为4k
  /// 4、总的 attributes（包括 key 和 value）限制为16k
  /// 5、initGroupAttributes、setGroupAttributes、deleteGroupAttributes 接口合并计算， SDK 限制为5秒10次，超过后回调8511错误码；后台限制1秒5次，超过后返回10049错误码
  /// 6、getGroupAttributes 接口 SDK 限制5秒20次
  /// ```
  Future<V2TimCallback> initGroupAttributes({
    required String groupID,
    required Map<String, String> attributes,
  }) async {
    if (kIsWeb) {
      return TencentCloudChatSdkPlatform.instance.initGroupAttributes(groupID: groupID, attributes: attributes);
    }
    return TIMGroupManager.instance.initGroupAttributes(groupID: groupID, attributes: attributes);
  }

  ///设置群属性。已有该群属性则更新其 value 值，没有该群属性则添加该属性。
  ///
  Future<V2TimCallback> setGroupAttributes({
    required String groupID,
    required Map<String, String> attributes,
  }) async {
    if (kIsWeb) {
      return TencentCloudChatSdkPlatform.instance.setGroupAttributes(groupID: groupID, attributes: attributes);
    }
    return TIMGroupManager.instance.setGroupAttributes(groupID: groupID, attributes: attributes);
  }

  ///删除指定群属性，keys 传 null 则清空所有群属性。
  ///
  Future<V2TimCallback> deleteGroupAttributes({
    required String groupID,
    required List<String> keys,
  }) async {
    if (kIsWeb) {
      return TencentCloudChatSdkPlatform.instance.deleteGroupAttributes(groupID: groupID, keys: keys);
    }
    return TIMGroupManager.instance.deleteGroupAttributes(groupID: groupID, keys: keys);
  }

  ///获取指定群属性，keys 传 null 则获取所有群属性。
  ///
  Future<V2TimValueCallback<Map<String, String>>> getGroupAttributes({
    required String groupID,
    List<String>? keys,
  }) async {
    if (kIsWeb) {
      return TencentCloudChatSdkPlatform.instance.getGroupAttributes(groupID: groupID, keys: keys);
    }
    return TIMGroupManager.instance.getGroupAttributes(groupID: groupID, keys: keys);
  }

  ///获取指定群在线人数
  ///请注意：
  ///```
  ///SDK 7.3 以前的版本仅支持直播群（ AVChatRoom）；
  ///SDK 7.3 及其以后的版本支持所有群类型。
  ///```
  Future<V2TimValueCallback<int>> getGroupOnlineMemberCount({
    required String groupID,
  }) async {
    if (kIsWeb) {
      return TencentCloudChatSdkPlatform.instance.getGroupOnlineMemberCount(groupID: groupID);
    }
    return TIMGroupManager.instance.getGroupOnlineMemberCount(groupID: groupID);
  }

  /// 获取群成员列表
  ///
  /// 参数
  ///
  /// ```
  /// filter	指定群成员类型
  /// GroupMemberFilterTypeEnum.V2TIM_GROUP_MEMBER_FILTER_ALL：所有类型
  /// GroupMemberFilterTypeEnum.V2TIM_GROUP_MEMBER_FILTER_OWNER：群主
  /// GroupMemberFilterTypeEnum.V2TIM_GROUP_MEMBER_FILTER_ADMIN：群管理员
  /// GroupMemberFilterTypeEnum.V2TIM_GROUP_MEMBER_FILTER_COMMON：普通群成员
  /// nextSeq	分页拉取标志，第一次拉取填0，回调成功如果 nextSeq 不为零，需要分页，传入再次拉取，直至为0。
  /// ```
  /// 注意
  ///
  /// ```
  /// 直播群（AVChatRoom）的特殊限制：
  /// 不支持管理员角色的拉取，群成员个数最大只支持 31 个（新进来的成员会排前面），程序重启后，请重新加入群组，否则拉取群成员会报 10007 错误码。
  /// 群成员资料信息仅支持 userID | nickName | faceURL | role 字段。
  /// role 字段不支持管理员角色，如果您的业务逻辑依赖于管理员角色，可以使用群自定义字段 groupAttributes 管理该角色。
  /// ```
  /// web 端使用时，count 和 offset 为必传参数. filter 和 nextSeq 不生效
  /// count: 需要拉取的数量。最大值：100，避免回包过大导致请求失败。若传入超过100，则只拉取前100个。
  /// offset: 偏移量，默认从0开始拉取
  ///
  Future<V2TimValueCallback<V2TimGroupMemberInfoResult>> getGroupMemberList({
    required String groupID,
    required GroupMemberFilterTypeEnum filter,
    required String nextSeq,
    int count = 15,
    int offset = 0,
  }) async {
    if (kIsWeb) {
      return TencentCloudChatSdkPlatform.instance
          .getGroupMemberList(groupID: groupID, filter: filter.index, nextSeq: nextSeq, count: count, offset: offset);
    }
    return TIMGroupManager.instance
        .getGroupMemberList(groupID: groupID, filter: filter, nextSeq: nextSeq, count: count, offset: offset);
  }

  ///获取指定的群成员资料
  ///
  Future<V2TimValueCallback<List<V2TimGroupMemberFullInfo>>> getGroupMembersInfo({
    required String groupID,
    required List<String> memberList,
  }) async {
    if (kIsWeb) {
      return TencentCloudChatSdkPlatform.instance.getGroupMembersInfo(groupID: groupID, memberList: memberList);
    }
    return TIMGroupManager.instance.getGroupMembersInfo(groupID: groupID, memberList: memberList);
  }

  ///修改指定的群成员资料
  ///
  Future<V2TimCallback> setGroupMemberInfo({
    required String groupID,
    required String userID,
    String? nameCard,
    Map<String, String>? customInfo,
  }) async {
    if (kIsWeb) {
      return TencentCloudChatSdkPlatform.instance.setGroupMemberInfo(
        groupID: groupID,
        userID: userID,
        nameCard: nameCard,
        customInfo: customInfo,
      );
    }
    return TIMGroupManager.instance.setGroupMemberInfo(
      groupID: groupID,
      userID: userID,
      nameCard: nameCard,
      customInfo: customInfo,
    );
  }

  ///禁言（只有管理员或群主能够调用）
  ///
  Future<V2TimCallback> muteGroupMember({
    required String groupID,
    required String userID,
    required int seconds,
  }) async {
    if (kIsWeb) {
      return TencentCloudChatSdkPlatform.instance.muteGroupMember(
        groupID: groupID,
        userID: userID,
        seconds: seconds,
      );
    }
    return TIMGroupManager.instance.muteGroupMember(
      groupID: groupID,
      userID: userID,
      seconds: seconds,
    );
  }

  /// 禁言全体群成员，只有管理员或群主能够调用
  ///
  /// 参数
  ///
  /// ```
  /// groupID 群组 ID
  /// isMute  true 表示禁言，false 表示解除禁言
  /// ```
  ///
  /// 注意
  ///
  /// ```
  /// 禁言全体群成员没有时间限制，设置 isMute 为 false 则解除禁言。
  /// 禁言或解除禁言后，会触发 V2TimGroupListener 中的 onAllGroupMembersMuted 回调。
  /// 群主和管理员可以禁言普通成员。普通成员不能操作禁言/解除禁言。
  /// ```
  Future<V2TimCallback> muteAllGroupMembers({
    required String groupID,
    required bool isMute,
  }) async {
    if (kIsWeb) {
      return TencentCloudChatSdkPlatform.instance.muteAllGroupMembers(
        groupID: groupID,
        isMute: isMute,
      );
    }
    return TIMGroupManager.instance.muteAllGroupMembers(
      groupID: groupID,
      isMute: isMute,
    );
  }

  /// 邀请他人入群
  ///
  /// 注意
  ///
  /// ```
  /// 工作群（Work）：群里的任何人都可以邀请其他人进群。
  /// 会议群（Meeting）和公开群（Public）：只有通过rest api 使用 App 管理员身份才可以邀请其他人进群。
  /// 直播群（AVChatRoom）：不支持此功能。
  /// ```
  Future<V2TimValueCallback<List<V2TimGroupMemberOperationResult>>> inviteUserToGroup({
    required String groupID,
    required List<String> userList,
  }) async {
    if (kIsWeb) {
      return TencentCloudChatSdkPlatform.instance.inviteUserToGroup(groupID: groupID, userList: userList);
    }
    return TIMGroupManager.instance.inviteUserToGroup(groupID: groupID, userList: userList);
  }

  /// 踢人
  ///
  /// 注意
  ///
  /// ```
  /// 工作群（Work）：只有群主或 APP 管理员可以踢人。
  /// 公开群（Public）、会议群（Meeting）：群主、管理员和 APP 管理员可以踢人
  /// 直播群（AVChatRoom）：只支持禁言（muteGroupMember），不支持踢人。
  /// ```
  Future<V2TimCallback> kickGroupMember({
    required String groupID,
    required List<String> memberList,
    int? duration,
    String? reason,
  }) async {
    if (kIsWeb) {
      return TencentCloudChatSdkPlatform.instance.kickGroupMember(
        groupID: groupID,
        memberList: memberList,
        duration: duration,
      );
    }
    return TIMGroupManager.instance.kickGroupMember(
      groupID: groupID,
      memberList: memberList,
      duration: duration,
      reason: reason,
    );
  }

  /// 切换群成员的角色。
  ///
  /// 注意
  ///
  /// ```
  /// 公开群（Public）和会议群（Meeting）：只有群主才能对群成员进行普通成员和管理员之间的角色切换。
  /// 其他群不支持设置群成员角色。
  /// 转让群组请调用 transferGroupOwner 接口。
  /// ```
  ///
  /// 参数
  ///
  /// ```
  /// role	切换的角色支持： V2TIMGroupMemberFullInfo.V2TIM_GROUP_MEMBER_ROLE_MEMBER：普通群成员 V2TIMGroupMemberFullInfo.V2TIM_GROUP_MEMBER_ROLE_ADMIN：管理员
  /// ```
  Future<V2TimCallback> setGroupMemberRole({
    required String groupID,
    required String userID,
    required GroupMemberRoleTypeEnum role,
  }) async {
    if (kIsWeb) {
      return TencentCloudChatSdkPlatform.instance
          .setGroupMemberRole(groupID: groupID, userID: userID, role: EnumUtils.convertGroupMemberRoleTypeEnum(role));
    }
    return TIMGroupManager.instance.setGroupMemberRole(
      groupID: groupID,
      userID: userID,
      role: role,
    );
  }

  /// 转让群主
  ///
  /// 注意
  ///
  /// ```
  /// 普通类型的群（Work、Public、Meeting）：只有群主才有权限进行群转让操作。
  /// 直播群（AVChatRoom）：不支持转让群主。
  /// ```
  Future<V2TimCallback> transferGroupOwner({
    required String groupID,
    required String userID,
  }) async {
    if (kIsWeb) {
      return TencentCloudChatSdkPlatform.instance.transferGroupOwner(groupID: groupID, userID: userID);
    }
    return TIMGroupManager.instance.transferGroupOwner(groupID: groupID, userID: userID);
  }

  ///获取加群的申请列表
  ///
  ///web 不支持
  ///
  Future<V2TimValueCallback<V2TimGroupApplicationResult>> getGroupApplicationList() async {
    if (kIsWeb) {
      return TencentCloudChatSdkPlatform.instance.getGroupApplicationList();
    }
    return TIMGroupManager.instance.getGroupApplicationList();
  }

  /// 同意某一条加群申请
  ///
  /// [application] 群申请，传入从接口 [getGroupApplicationList] 获取的群申请对象，8.5.6864+4 版本及以上建议传入该字段。
  ///
  /// web 端使用时必须传入webMessageInstance 字段。 对应【群系统通知】的消息实例
  ///
  Future<V2TimCallback> acceptGroupApplication({
    required String groupID,
    String? reason,
    required String fromUser,
    required String toUser,
    int? addTime,
    GroupApplicationTypeEnum? type,
    V2TimGroupApplication? application,
    String? webMessageInstance,
  }) async {
    if (kIsWeb) {
      return TencentCloudChatSdkPlatform.instance.acceptGroupApplication(
        groupID: groupID,
        reason: reason,
        fromUser: fromUser,
        toUser: toUser,
        addTime: addTime,
        type: type?.index,
        webMessageInstance: webMessageInstance,
      );
    }
    return TIMGroupManager.instance.acceptGroupApplication(
      groupID: groupID,
      reason: reason,
      fromUser: fromUser,
      toUser: toUser,
      addTime: addTime,
      type: type,
      application: application,
    );
  }

  /// 拒绝某一条加群申请
  ///
  /// 参数：
  ///
  /// [application] 群申请，传入从接口 [getGroupApplicationList] 获取的群申请对象，8.5.6864+4 版本及以上建议传入该字段。
  ///
  /// [webMessageInstance] [web端实例](https://web.sdk.qcloud.com/im/doc/zh-cn/SDK.html#handleGroupApplication)
  ///
  /// [type] 群未决请求类型 [GroupApplicationTypeEnum]
  ///
  /// [fromUser]  请求者ID
  ///
  /// [toUser] 获取处理者 ID, 请求加群:0，邀请加群:被邀请人
  ///
  /// [addTime] 获取群未决添加的时间
  ///
  ///  ```
  /// web 端使用时必须传入webMessageInstance 字段。 对应【群系统通知】的消息实例
  /// ```
  Future<V2TimCallback> refuseGroupApplication({
    required String groupID,
    String? reason,
    required String fromUser,
    required String toUser,
    required int addTime,
    required GroupApplicationTypeEnum type,
    V2TimGroupApplication? application,
    String? webMessageInstance,
  }) async {
    if (kIsWeb) {
      return TencentCloudChatSdkPlatform.instance.refuseGroupApplication(
          groupID: groupID,
          fromUser: fromUser,
          toUser: toUser,
          addTime: addTime,
          type: type.index,
          webMessageInstance: webMessageInstance);
    }
    return TIMGroupManager.instance.refuseGroupApplication(
      groupID: groupID,
      fromUser: fromUser,
      toUser: toUser,
      addTime: addTime,
      type: type,
      application: application,
    );
  }

  ///标记申请列表为已读
  ///
  /// web 不支持
  ///
  Future<V2TimCallback> setGroupApplicationRead() async {
    if (kIsWeb) {
      return TencentCloudChatSdkPlatform.instance.setGroupApplicationRead();
    }
    return TIMGroupManager.instance.setGroupApplicationRead();
  }

  /// 搜索本地群资料
  ///
  /// 该功能为 IM 旗舰版功能，[购买旗舰版套餐包](https://buy.cloud.tencent.com/avc?from=17474)后可使用，详见[价格说明](https://cloud.tencent.com/document/product/269/11673?from=17176#.E5.9F.BA.E7.A1.80.E6.9C.8D.E5.8A.A1.E8.AF.A6.E6.83.85)
  ///
  ///```
  /// web 不支持， 请使用 searchGroupByID
  ///```
  Future<V2TimValueCallback<List<V2TimGroupInfo>>> searchGroups({
    required V2TimGroupSearchParam searchParam,
  }) async {
    if (kIsWeb) {
      return TencentCloudChatSdkPlatform.instance.searchGroups(searchParam: searchParam);
    }

    return TIMGroupManager.instance.searchGroups(searchParam: searchParam);
  }

  /// 搜索云端群资料
  ///
  /// 该功能为 IM 增值功能，详见[价格说明](https://cloud.tencent.com/document/product/269/11673?from=17176#.E5.9F.BA.E7.A1.80.E6.9C.8D.E5.8A.A1.E8.AF.A6.E6.83.85)
  ///
  ///```
  /// web 不支持
  ///```
  Future<V2TimValueCallback<V2TimGroupSearchResult>> searchCloudGroups({
    required V2TimGroupSearchParam searchParam,
  }) async {
    if (kIsWeb) {
      return TencentCloudChatSdkPlatform.instance.searchCloudGroups(searchParam: searchParam);
    }

    return TIMGroupManager.instance.searchCloudGroups(searchParam: searchParam);
  }

  /// 搜索本地群成员资料
  ///
  /// 该功能为 IM 旗舰版功能，[购买旗舰版套餐包](https://buy.cloud.tencent.com/avc?from=17474)后可使用，详见[价格说明](https://cloud.tencent.com/document/product/269/11673?from=17176#.E5.9F.BA.E7.A1.80.E6.9C.8D.E5.8A.A1.E8.AF.A6.E6.83.85)
  /// ```
  /// web 不支持
  /// ```
  Future<V2TimValueCallback<V2GroupMemberInfoSearchResult>> searchGroupMembers({
    required V2TimGroupMemberSearchParam param,
  }) async {
    if (kIsWeb) {
      return TencentCloudChatSdkPlatform.instance.searchGroupMembers(param: param);
    }

    return TIMGroupManager.instance.searchGroupMembers(param: param);
  }

  /// 搜索云端群成员
  ///
  /// 该功能为 IM 增值功能，详见[价格说明](https://cloud.tencent.com/document/product/269/11673?from=17176#.E5.9F.BA.E7.A1.80.E6.9C.8D.E5.8A.A1.E8.AF.A6.E6.83.85)
  ///
  ///```
  /// web 不支持
  ///```
  Future<V2TimValueCallback<V2GroupMemberInfoSearchResult>> searchCloudGroupMembers({
    required V2TimGroupMemberSearchParam param,
  }) async {
    if (kIsWeb) {
      return TencentCloudChatSdkPlatform.instance.searchCloudGroupMembers(param: param);
    }

    return TIMGroupManager.instance.searchCloudGroupMembers(param: param);
  }

  /// 通过 groupID 搜索群组
  /// 注意： 好友工作群不能被搜索
  /// 仅 web 支持该搜索方式
  ///
  Future<V2TimValueCallback<V2TimGroupInfo>> searchGroupByID({
    required String groupID,
  }) async {
    if (kIsWeb) {
      return TencentCloudChatSdkPlatform.instance.searchGroupByID(groupID: groupID);
    }
    return TIMGroupManager.instance.searchGroupByID(groupID: groupID);
  }

  /// 获取当前用户已经加入的支持话题的社群列表
  /// 4.0.1及以上版本支持
  /// web版本不支持
  ///
  Future<V2TimValueCallback<List<V2TimGroupInfo>>> getJoinedCommunityList() async {
    if (kIsWeb) {
      return TencentCloudChatSdkPlatform.instance.getJoinedCommunityList();
    }
    return TIMGroupManager.instance.getJoinedCommunityList();
  }

  /// 创建话题
  /// 4.0.1及以上版本支持
  /// web版本不支持
  ///
  Future<V2TimValueCallback<String>> createTopicInCommunity({
    required String groupID,
    required V2TimTopicInfo topicInfo,
  }) async {
    if (kIsWeb) {
      return TencentCloudChatSdkPlatform.instance.createTopicInCommunity(
        groupID: groupID,
        topicInfo: topicInfo,
      );
    }
    return TIMGroupManager.instance.createTopicInCommunity(
      groupID: groupID,
      topicInfo: topicInfo,
    );
  }

  /// 删除话题
  /// 4.0.1及以上版本支持
  /// web版本不支持
  ///
  Future<V2TimValueCallback<List<V2TimTopicOperationResult>>> deleteTopicFromCommunity({
    required String groupID,
    required List<String> topicIDList,
  }) async {
    if (kIsWeb) {
      return TencentCloudChatSdkPlatform.instance.deleteTopicFromCommunity(groupID: groupID, topicIDList: topicIDList);
    }
    return TIMGroupManager.instance.deleteTopicFromCommunity(groupID: groupID, topicIDList: topicIDList);
  }

  /// 修改话题信息
  /// 4.0.1及以上版本支持
  /// web版本不支持
  ///
  Future<V2TimCallback> setTopicInfo({
    required V2TimTopicInfo topicInfo,
  }) async {
    if (kIsWeb) {
      return TencentCloudChatSdkPlatform.instance.setTopicInfo(
        topicInfo: topicInfo,
      );
    }
    return TIMGroupManager.instance.setTopicInfo(
      topicInfo: topicInfo,
    );
  }

  /// 获取话题列表。
  /// 4.0.1及以上版本支持
  /// web版本不支持
  ///
  Future<V2TimValueCallback<List<V2TimTopicInfoResult>>> getTopicInfoList({
    required String groupID,
    required List<String> topicIDList,
  }) async {
    if (kIsWeb) {
      return TencentCloudChatSdkPlatform.instance.getTopicInfoList(groupID: groupID, topicIDList: topicIDList);
    }
    return TIMGroupManager.instance.getTopicInfoList(groupID: groupID, topicIDList: topicIDList);
  }

  /// 设置群计数器（5.0.8 及其以上版本支持）
  /// 注意
  /// 该计数器的 key 如果存在，则直接更新计数器的 value 值；如果不存在，则添加该计数器的 key-value；
  /// 当群计数器设置成功后，在 succ 回调中会返回最终成功设置的群计数器信息；
  /// 除了社群和话题，群计数器支持所有的群组类型。
  ///
  Future<V2TimValueCallback<Map<String, int>>> setGroupCounters({
    required String groupID,
    required Map<String, int> counters,
  }) async {
    if (kIsWeb) {
      return TencentCloudChatSdkPlatform.instance.setGroupCounters(
        groupID: groupID,
        counters: counters,
      );
    }
    return TIMGroupManager.instance.setGroupCounters(
      groupID: groupID,
      counters: counters,
    );
  }

  /// 获取群计数器（5.0.8 及其以上版本支持）
  ///
  /// 注意
  /// 如果 keys 为空，则表示获取群内的所有计数器；
  /// 除了社群和话题，群计数器支持所有的群组类型。
  ///
  Future<V2TimValueCallback<Map<String, int>>> getGroupCounters({
    required String groupID,
    required List<String> keys,
  }) async {
    if (kIsWeb) {
      return TencentCloudChatSdkPlatform.instance.getGroupCounters(
        groupID: groupID,
        keys: keys,
      );
    }
    return TIMGroupManager.instance.getGroupCounters(
      groupID: groupID,
      keys: keys,
    );
  }

  /// 递增群计数器（5.0.8 及其以上版本支持）
  ///
  ///   参数
  /// groupID	群 ID
  /// key	群计数器的 key
  /// value	群计数器的递增的变化量，计数器 key 对应的 value 变更方式为： new_value = old_value + value
  /// 注意
  /// 成功后的回调，会返回当前计数器做完递增操作后的 value
  /// 该计数器的 key 如果存在，则直接在当前值的基础上根据传入的 value 作递增操作；反之，添加 key，并在默认值为 0 的基础上根据传入的 value 作递增操作；
  /// 除了社群和话题，群计数器支持所有的群组类型。
  ///
  Future<V2TimValueCallback<Map<String, int>>> increaseGroupCounter({
    required String groupID,
    required String key,
    required int value,
  }) async {
    if (kIsWeb) {
      return TencentCloudChatSdkPlatform.instance.increaseGroupCounter(
        groupID: groupID,
        key: key,
        value: value,
      );
    }
    return TIMGroupManager.instance.increaseGroupCounter(
      groupID: groupID,
      key: key,
      value: value,
    );
  }

  /// 递减群计数器（7.0 及其以上版本支持）
  ///
  /// 参数
  /// groupID	群 ID
  /// key	群计数器的 key
  /// value	群计数器的递减的变化量，计数器 key 对应的 value 变更方式为： new_value = old_value - value
  /// 注意
  /// 成功后的回调，会返回当前计数器做完递减操作后的 value
  /// 该计数器的 key 如果存在，则直接在当前值的基础上根据传入的 value 作递减操作；反之，添加 key，并在默认值为 0 的基础上根据传入的 value 作递减操作
  /// 除了社群和话题，群计数器支持所有的群组类型。
  ///
  Future<V2TimValueCallback<Map<String, int>>> decreaseGroupCounter({
    required String groupID,
    required String key,
    required int value,
  }) async {
    if (kIsWeb) {
      return TencentCloudChatSdkPlatform.instance.decreaseGroupCounter(
        groupID: groupID,
        key: key,
        value: value,
      );
    }
    return TIMGroupManager.instance.decreaseGroupCounter(
      groupID: groupID,
      key: key,
      value: value,
    );
  }

  Future<V2TimCallback> markGroupMemberList({
    required String groupID,
    required List<String> memberIDList,
    required int markType,
    required bool enableMark,
  }) async {
    if (kIsWeb) {
      return TencentCloudChatSdkPlatform.instance.markGroupMemberList(
        groupID: groupID,
        memberIDList: memberIDList,
        markType: markType,
        enableMark: enableMark,
      );
    }
    return TIMGroupManager.instance.markGroupMemberList(
      groupID: groupID,
      memberIDList: memberIDList,
      markType: markType,
      enableMark: enableMark,
    );
  }

  ///@nodoc
  Map buildParam(Map param) {
    param["TIMManagerName"] = "groupManager";
    return param;
  }

  ///@nodoc
  formatJson(jsonSrc) {
    return json.decode(json.encode(jsonSrc));
  }
}
