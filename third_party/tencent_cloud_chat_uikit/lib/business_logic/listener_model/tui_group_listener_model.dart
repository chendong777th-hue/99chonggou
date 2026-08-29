// ignore_for_file: unnecessary_getters_setters

import 'dart:convert';

import 'package:flutter/cupertino.dart';
import 'package:tencent_chat_i18n_tool/tencent_chat_i18n_tool.dart';
import 'package:tencent_cloud_chat_sdk/enum/V2TimGroupListener.dart';
import 'package:tencent_cloud_chat_sdk/enum/group_change_info_type.dart';
import 'package:tencent_cloud_chat_sdk/manager/v2_tim_manager.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_group_change_info.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_group_change_info.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_group_info.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_group_info.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_group_info_result.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_group_info_result.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_group_member_info.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_group_member_info.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_group_member_full_info.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_group_member_full_info.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_group_member_change_info.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_group_member_change_info.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_topic_info.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_topic_info.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_value_callback.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_value_callback.dart';
import 'package:tencent_cloud_chat_sdk/tencent_im_sdk_plugin.dart';
import 'package:tencent_cloud_chat_uikit/business_logic/view_models/tui_chat_global_model.dart';
import 'package:tencent_cloud_chat_uikit/business_logic/view_models/tui_conversation_view_model.dart';
import 'package:tencent_cloud_chat_uikit/business_logic/view_models/tui_friendship_view_model.dart';
import 'package:tencent_cloud_chat_uikit/business_logic/services/display_name_store.dart';
import 'package:tencent_cloud_chat_uikit/business_logic/services/group_member_store.dart';
import 'package:tencent_cloud_chat_uikit/data_services/group/group_services.dart';
import 'package:tencent_cloud_chat_uikit/data_services/group/self_hosted_group_bridge.dart';
import 'package:tencent_cloud_chat_uikit/data_services/services_locatar.dart';
import 'package:tencent_cloud_chat_uikit/tencent_cloud_chat_uikit.dart';

enum UpdateType {
  groupInfo,
  memberEnter,
  memberLeave,
  memberListReload,
  joinApplicationList,
  groupDismissed,
  kickedFromGroup
}

class NeedUpdate {
  final String groupID;
  final UpdateType updateType;
  final dynamic extraData;
  int? groupInfoSubType;
  String? ownerID;

  NeedUpdate(this.groupID, this.updateType, this.extraData);
}

class TUIGroupListenerModel extends ChangeNotifier {
  final GroupServices _groupServices = serviceLocator<GroupServices>();
  V2TimGroupListener? _groupListener;
  NeedUpdate? _needUpdate;
  final TUIChatGlobalModel chatViewModel = serviceLocator<TUIChatGlobalModel>();
  late CoreServicesImpl coreInstance = TIMUIKitCore.getInstance();
  late V2TIMManager sdkInstance = TIMUIKitCore.getSDKInstance();

  NeedUpdate? get needUpdate => _needUpdate;

  set needUpdate(NeedUpdate? value) {
    Future.delayed(const Duration(seconds: 0), () {
      _needUpdate = value;
    });
  }

  void requestProfileRefresh(NeedUpdate update) {
    _needUpdate = update;
    notifyListeners();
  }

  TUIGroupListenerModel() {
    _groupListener = V2TimGroupListener(onMemberInvited:
        (groupID, opUser, memberList) {
      _needUpdate = NeedUpdate(groupID, UpdateType.memberEnter, memberList);
      chatViewModel.refreshGroupApplicationList(force: true);
      notifyListeners();
    }, onGrantAdministrator: (groupID, opUser, memberList) async {
      await _recordAdminNotice(
        groupID: groupID,
        opUser: opUser,
        memberList: memberList,
        isGrant: true,
      );
    }, onRevokeAdministrator: (groupID, opUser, memberList) async {
      await _recordAdminNotice(
        groupID: groupID,
        opUser: opUser,
        memberList: memberList,
        isGrant: false,
      );
    }, onMemberKicked: (groupID, opUser, memberList) async {
      if (_isLoginUserKickedFromGroup(groupID, memberList)) {
        _deleteGroupConversation(groupID);

        final groupName = await _getGroupName(groupID);
        _needUpdate =
            NeedUpdate(groupID, UpdateType.kickedFromGroup, groupName);
        notifyListeners();
      }
    }, onMemberEnter: (String groupID, List<V2TimGroupMemberInfo> memberList) {
      _needUpdate = NeedUpdate(groupID, UpdateType.memberEnter, memberList);
      notifyListeners();
    }, onMemberLeave: (String groupID, V2TimGroupMemberInfo member) {
      _needUpdate = NeedUpdate(groupID, UpdateType.memberLeave, [member]);
      notifyListeners();
    }, onGroupInfoChanged: (groupID, changeInfos) {
      _needUpdate = NeedUpdate(groupID, UpdateType.groupInfo, "");
      for (V2TimGroupChangeInfo info in changeInfos) {
        if (info.type ==
            GroupChangeInfoType.V2TIM_GROUP_INFO_CHANGE_TYPE_FACE_URL) {
          final url = info.value?.trim();
          if (url != null && url.isNotEmpty) {
            // Self-hosted groups commit metadata through the app's guarded
            // GroupLocalStore pipeline. The SDK callback is only a hint; do
            // not write its potentially stale snapshot into the conversation.
            if (!SelfHostedGroupBridge.enabled) {
              serviceLocator<TUIConversationViewModel>()
                  .updateGroupFaceUrl(groupID, url);
            }
          }
        }
        if (info.type ==
            GroupChangeInfoType.V2TIM_GROUP_INFO_CHANGE_TYPE_NAME) {
          final name = info.value?.trim();
          if (name != null && name.isNotEmpty) {
            if (!SelfHostedGroupBridge.enabled) {
              DisplayNameStore.instance.setGroup(groupID, name, notify: false);
              serviceLocator<TUIConversationViewModel>()
                  .updateGroupShowName(groupID, name);
              serviceLocator<TUIFriendShipViewModel>()
                  .updateGroupNameLocal(groupID, name);
            }
          }
        }
        if (info.type ==
            GroupChangeInfoType.V2TIM_GROUP_INFO_CHANGE_TYPE_OWNER) {
          _needUpdate!.groupInfoSubType =
              GroupChangeInfoType.V2TIM_GROUP_INFO_CHANGE_TYPE_OWNER;
          _needUpdate!.ownerID = info.value;
          _recordTransferOwnerNoticeForTarget(groupID, info.value);
        }
      }
      notifyListeners();
    }, onReceiveJoinApplication:
        (String groupID, V2TimGroupMemberInfo member, String opReason) async {
      _onReceiveJoinApplication(groupID, member, opReason);
      chatViewModel.refreshGroupApplicationList(force: true);
      notifyListeners();
    }, onGroupDismissed: (String groupID, V2TimGroupMemberInfo opUser) async {
      _deleteGroupConversation(groupID);
      final groupName = await _getGroupName(groupID);
      _needUpdate = NeedUpdate(groupID, UpdateType.groupDismissed, groupName);
      notifyListeners();
    }, onMemberInfoChanged: (String groupID, List<V2TimGroupMemberChangeInfo> changeInfoList) async {
      final loginUserID = coreInstance.loginInfo.userID;
      bool isCurrentUserMuteChanged = false;
      
      for (final changeInfo in changeInfoList) {
        final userID = changeInfo.userID ?? '';
        final muteTime = changeInfo.muteTime ?? 0;
        if (userID.isEmpty) continue;
        
        // Update local member info in GroupMemberStore
        final member = GroupMemberStore.instance.memberOf(groupID, userID);
        final updatedMember = V2TimGroupMemberFullInfo(
          userID: member?.userID ?? userID,
          role: member?.role,
          nickName: member?.nickName,
          nameCard: member?.nameCard,
          friendRemark: member?.friendRemark,
          faceUrl: member?.faceUrl,
          joinTime: member?.joinTime,
          muteUntil: muteTime,
          customInfo: member?.customInfo,
        );
        GroupMemberStore.instance.putMember(groupID, updatedMember);
        
        // Check if current user's mute state changed.
        if (userID == loginUserID) {
          isCurrentUserMuteChanged = true;
        }
      }
      
      // If the current user was muted or unmuted, force refresh the chat UI.
      if (isCurrentUserMuteChanged) {
        _needUpdate = NeedUpdate(groupID, UpdateType.memberListReload, null);
        notifyListeners();
      }
    });
  }

  setGroupListener() {
    _groupServices.addGroupListener(listener: _groupListener!);
  }

  removeGroupListener() {
    _groupServices.removeGroupListener(listener: _groupListener!);
  }

  getCommunityCategoryList(String groupID) async {
    final Map<String, String>? customInfo =
        await getCommunityCustomInfo(groupID);
    if (customInfo != null) {
      final String? categoryListString = customInfo["categoryList"];
      if (categoryListString != null && categoryListString.isNotEmpty) {
        return jsonDecode(categoryListString);
      }
    }
  }

  Future<Map<String, String>?> getCommunityCustomInfo(String groupID) async {
    V2TimValueCallback<List<V2TimGroupInfoResult>> res =
        await TencentImSDKPlugin.v2TIMManager
            .getGroupManager()
            .getGroupsInfo(groupIDList: [groupID]);
    if (res.code != 0) {
      final V2TimGroupInfoResult? groupInfo = res.data?[0];
      if (groupInfo != null) {
        Map<String, String>? customInfo = groupInfo.groupInfo?.customInfo;
        return customInfo;
      }
    }
    return null;
  }

  setCommunityCategoryList(
      String groupID, String groupType, List<String> newCategoryList) async {
    final Map<String, String>? customInfo =
        await getCommunityCustomInfo(groupID);
    customInfo?["categoryList"] = jsonEncode(newCategoryList);
    TencentImSDKPlugin.v2TIMManager.getGroupManager().setGroupInfo(
            info: V2TimGroupInfo(
          customInfo: customInfo,
          groupID: groupID,
          groupType: groupType,
          // ...其他资料
        ));
  }

  addCategoryForTopic(String groupID, String categoryName) {
    TencentImSDKPlugin.v2TIMManager.getGroupManager().setTopicInfo(
          topicInfo: V2TimTopicInfo(customString: categoryName),
        );
  }

  _onReceiveJoinApplication(
      String groupID, V2TimGroupMemberInfo member, String opReason) {
    Future.delayed(const Duration(milliseconds: 500),
        () => chatViewModel.refreshGroupApplicationList(force: true));
  }

  Future<String> _getGroupName(String groupID) async {
    final groupInfoList = await sdkInstance
        .getGroupManager()
        .getGroupsInfo(groupIDList: [groupID]);
    String groupName = TIM_t("群组");
    if (groupInfoList.data != null) {
      groupName = groupInfoList.data!.first.groupInfo?.groupName ?? groupName;
    }
    return groupName;
  }

  Future<String> _getGroupFaceUrl(String groupID) async {
    final groupInfoList = await sdkInstance
        .getGroupManager()
        .getGroupsInfo(groupIDList: [groupID]);
    if (groupInfoList.data != null) {
      return groupInfoList.data!.first.groupInfo?.faceUrl ?? "";
    }
    return "";
  }

  String _getDisplayName(V2TimGroupMemberInfo? member) {
    return TencentUtils.checkString(member?.friendRemark) ??
        TencentUtils.checkString(member?.nameCard) ??
        TencentUtils.checkString(member?.nickName) ??
        TencentUtils.checkString(member?.userID) ??
        "";
  }

  Future<void> _recordAdminNotice({
    required String groupID,
    required V2TimGroupMemberInfo opUser,
    required List<V2TimGroupMemberInfo> memberList,
    required bool isGrant,
  }) async {
    final loginUserID = coreInstance.loginInfo.userID;
    final groupName = await _getGroupName(groupID);
    final groupFaceUrl = await _getGroupFaceUrl(groupID);
    for (final member in memberList) {
      final targetUserID = member.userID ?? "";
      final operatorUserID = opUser.userID ?? "";
      final isOperator = operatorUserID == loginUserID;
      final isTarget = targetUserID == loginUserID;
      if (!isOperator && !isTarget) {
        continue;
      }
      chatViewModel.addGroupSystemNotice(
        GroupSystemNoticeItem(
          id: "${isGrant ? "grant" : "revoke"}|$groupID|$operatorUserID|$targetUserID|${DateTime.now().millisecondsSinceEpoch}",
          groupID: groupID,
          groupName: groupName,
          groupFaceUrl: groupFaceUrl,
          type: isGrant
              ? GroupSystemNoticeType.grantAdministrator
              : GroupSystemNoticeType.revokeAdministrator,
          operatorUserID: operatorUserID,
          operatorName: _getDisplayName(opUser),
          targetUserID: targetUserID,
          targetName: _getDisplayName(member),
          timestamp: DateTime.now().millisecondsSinceEpoch,
        ),
      );
    }
  }

  Future<void> _recordTransferOwnerNoticeForTarget(
    String groupID,
    String? newOwnerID,
  ) async {
    final loginUserID = coreInstance.loginInfo.userID;
    if (newOwnerID == null || newOwnerID.isEmpty || loginUserID != newOwnerID) {
      return;
    }
    final groupName = await _getGroupName(groupID);
    final groupFaceUrl = await _getGroupFaceUrl(groupID);
    chatViewModel.addGroupSystemNotice(
      GroupSystemNoticeItem(
        id: "owner-target|$groupID|$newOwnerID|${DateTime.now().millisecondsSinceEpoch}",
        groupID: groupID,
        groupName: groupName,
        groupFaceUrl: groupFaceUrl,
        type: GroupSystemNoticeType.transferOwner,
        operatorUserID: "",
        operatorName: "",
        targetUserID: newOwnerID,
        targetName: TIM_t("你"),
        timestamp: DateTime.now().millisecondsSinceEpoch,
      ),
    );
  }

  void _deleteGroupConversation(String groupID) async {
    if (SelfHostedGroupBridge.governanceEnabled) {
      await SelfHostedGroupBridge.notifySelfLeftGroup(groupID);
      return;
    }
    sdkInstance
        .getConversationManager()
        .deleteConversation(conversationID: "group_$groupID");
  }

  bool _isLoginUserKickedFromGroup(
      String groupID, List<V2TimGroupMemberInfo> memberList) {
    final loginUserInfo = coreInstance.loginInfo;
    int index = memberList
        .indexWhere((element) => element.userID == loginUserInfo.userID);
    if (index > -1) {
      return true;
    }
    return false;
  }
}
