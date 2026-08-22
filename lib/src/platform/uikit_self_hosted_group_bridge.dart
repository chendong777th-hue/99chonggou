import 'package:tencent_cloud_chat_demo/src/api/group_member_api.dart';

import 'package:tencent_cloud_chat_demo/src/platform/group_invite_router.dart';
import 'package:tencent_cloud_chat_demo/src/services/group_local/group_member_local_store.dart';
import 'package:tencent_cloud_chat_demo/src/services/group_local/group_membership_sync_service.dart';
import 'package:tencent_cloud_chat_demo/src/services/group_local/group_local_store.dart';

import 'package:tencent_cloud_chat_demo/utils/chat_id_format.dart';

import 'package:tencent_cloud_chat_demo/src/services/group_leave_diag_log.dart';
import 'package:tencent_cloud_chat_demo/src/widgets/group_leave_confirm_dialog.dart';
import 'package:tencent_cloud_chat_demo/utils/group_leave_message.dart';
import 'package:tencent_cloud_chat_demo/utils/group_admin_role_message.dart';
import 'package:tencent_cloud_chat_demo/utils/group_invite_message.dart';

import 'package:tencent_cloud_chat_demo/utils/group_kick_message.dart';

import 'package:tencent_cloud_chat_demo/utils/toast.dart';

import 'package:tencent_cloud_chat_sdk/models/v2_tim_group_member_operation_result.dart'

    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_group_member_operation_result.dart';

import 'package:tencent_cloud_chat_sdk/models/v2_tim_value_callback.dart'

    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_value_callback.dart';

import 'package:tencent_cloud_chat_uikit/data_services/group/self_hosted_group_bridge.dart';
import 'package:tencent_cloud_chat_uikit/data_services/friendShip/self_hosted_friendship_bridge.dart'
    show SelfHostedIdSearchPage;

import 'package:tencent_cloud_chat_uikit/data_services/group/group_member_feedback_bridge.dart';

import 'package:tencent_cloud_chat_uikit/data_services/group/self_hosted_group_kick_bridge.dart';

import 'package:tencent_cloud_chat_uikit/data_services/group/self_hosted_group_invite_bridge.dart';

import 'package:tencent_cloud_chat_uikit/data_services/group/self_hosted_group_leave_bridge.dart';

import 'package:tencent_cloud_chat_uikit/data_services/group/self_hosted_group_leave_confirm_bridge.dart';

import 'package:tencent_cloud_chat_uikit/data_services/group/self_hosted_group_leave_diag_bridge.dart';



/// 群资料/成员/邀请走 99chat-server REST。

class UikitSelfHostedGroupBridge {

  UikitSelfHostedGroupBridge._();



  static void install() {

    final sync = GroupMembershipSyncService.instance;

    sync.install();

    SelfHostedGroupBridge.configure(

      loadJoinedGroupList: sync.loadJoinedGroupsForUIKit,

      loadGroupsInfo: sync.loadGroupsInfoForUIKit,

      searchGroupsLocal: ({
        required String keyword,
        int limit = 80,
        String? cursor,
      }) async {
        final page = await GroupLocalStore.instance.searchGroupIds(
          keyword: keyword,
          limit: limit,
          cursor: cursor,
        );
        return SelfHostedIdSearchPage(
          ids: page.ids,
          nextCursor: page.nextCursor,
          hasMore: page.hasMore,
        );
      },

      hydrateGroups: (groupIds) =>
          GroupLocalStore.instance.loadAsV2TimGroupInfosByIds(
        groupIds: groupIds,
      ),

      loadGroupMemberList: ({

        required String groupID,

        required int count,

        required String nextSeq,

      }) =>

          sync.loadGroupMemberPage(

            groupID: groupID,

            count: count,

            nextSeq: nextSeq,

          ),

      // 聊天记录「群成员」查找 / @ 选人等需要本地全量；首页窗口由调用方自行截取。
      loadCachedGroupMemberList: (groupID) =>
          GroupMemberLocalStore.instance.loadAsV2TimMembers(
            groupId: groupID,
          ),

      loadGroupMembersInfo: sync.loadGroupMembersInfo,

      updateGroupInfo: sync.updateGroupInfo,

      updateGroupMemberInfo: ({

        required String groupID,

        required String userID,

        String? nameCard,

      }) =>

          sync.updateMyNameCard(

            groupId: groupID,

            userId: userID,

            nameCard: nameCard ?? '',

          ),

      onSelfLeftGroup: sync.onSelfRemovedFromGroup,

      leaveGroup: sync.leaveGroup,

      dismissGroup: sync.dismissGroup,

      kickGroupMember: sync.kickGroupMember,

      setGroupMemberRole: sync.setGroupMemberRole,

      setGroupMemberRoles: sync.setGroupMemberRoles,

      transferGroupOwner: sync.transferGroupOwner,

      muteGroupMember: sync.muteGroupMember,

    );

    SelfHostedGroupInviteBridge.configure(

      inviteHandler: _inviteMembers,

      inviteResultMessageBuilder: ({required int code, String? desc}) {
        final text = desc?.trim() ?? '';
        if (text.isNotEmpty && RegExp(r'[\u4e00-\u9fa5]').hasMatch(text)) {
          return text;
        }
        return GroupInviteMessage.fromResult(code: code, desc: desc);
      },

      inviteSuccessMessageBuilder: GroupInviteMessage.success,

    );

    SelfHostedGroupKickBridge.configure(
      messageBuilder: ({required bool success, int? code, String? desc}) {
        if (success) {
          if (desc?.trim().toUpperCase() == 'PARTIAL_SUCCESS') {
            return GroupKickMessage.partialSuccess();
          }
          return GroupKickMessage.success();
        }
        return GroupKickMessage.failure(desc: desc);
      },
    );

    SelfHostedGroupLeaveBridge.configure(
      messageBuilder: ({required bool dismiss, int? code, String? desc}) =>
          GroupLeaveMessage.failure(dismiss: dismiss, code: code, desc: desc),
    );

    SelfHostedGroupLeaveConfirmBridge.configure(
      handler: ({required bool dismiss}) =>
          GroupLeaveConfirmDialog.show(dismiss: dismiss),
    );

    SelfHostedGroupLeaveDiagBridge.configure(
      handler: (event, {groupId, extras = const <String, Object?>{}}) {
        GroupLeaveDiagLog.log(event, groupId: groupId, extras: extras);
      },
    );

    GroupMemberFeedbackBridge.onShowMessage = (message) {
      final text = message.trim();
      if (text.isEmpty) {
        return;
      }
      // 邀请/踢人/成功提示已由各自 Message 类本地化；仅对原始错误码做管理员文案映射。
      if (RegExp(r'[\u4e00-\u9fa5]').hasMatch(text)) {
        ToastUtils.toast(text);
        return;
      }
      ToastUtils.toast(GroupAdminRoleMessage.normalizeFeedback(text));
    };

  }



  static Future<V2TimValueCallback<List<V2TimGroupMemberOperationResult>>>

      _inviteMembers({

    required String groupID,

    required String? groupType,

    required List<String> userList,

  }) async {

    final normalized = userList

        .map(ChatIdFormat.rawUserUid)

        .where((id) => id.isNotEmpty)

        .toList();

    if (normalized.isEmpty) {

      return V2TimValueCallback(

        code: -1,

        desc: 'INVALID_INPUT',

        data: const <V2TimGroupMemberOperationResult>[],

      );

    }



    if (shouldInviteViaRest(groupType)) {

      return GroupMemberApi.instance.inviteMembers(

        groupId: groupID,

        userIds: normalized,

      );

    }



    return V2TimValueCallback(

      code: -1,

      desc: 'GROUP_INVITE_NOT_SUPPORTED',

      data: const <V2TimGroupMemberOperationResult>[],

    );

  }

}

