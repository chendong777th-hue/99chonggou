import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'package:tencent_cloud_chat_demo/src/i18n/app_i18n.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:tencent_cloud_chat_demo/src/provider/presence_provider.dart';
import 'package:tencent_cloud_chat_demo/src/provider/theme.dart';
import 'package:tencent_cloud_chat_demo/src/qr_code_page.dart';
import 'package:tencent_cloud_chat_demo/src/tencent_page.dart';
import 'package:tencent_cloud_chat_demo/src/services/group_notice_refresh_bus.dart';
import 'package:tencent_cloud_chat_demo/src/services/peer_profile_refresh_bus.dart';
import 'package:tencent_cloud_chat_demo/src/widgets/conversation_profile_pin_bar.dart';
import 'package:tencent_cloud_chat_demo/src/widgets/group_profile_join_mode_row.dart';
import 'package:tencent_cloud_chat_demo/src/group_info_detail.dart';
import 'package:tencent_cloud_chat_demo/src/api/me_group_api.dart';
import 'package:tencent_cloud_chat_demo/src/services/group_local/group_local_store.dart';
import 'package:tencent_cloud_chat_demo/src/utils/conversation_group_title_color.dart';
import 'package:tencent_cloud_chat_demo/utils/chat_id_format.dart';
import 'package:tencent_cloud_chat_demo/utils/conversation_face_url.dart';
import 'package:tencent_cloud_chat_demo/utils/group_display_resolver.dart';
import 'package:tencent_cloud_chat_demo/src/navigation/group_leave_navigation.dart';
import 'package:tencent_cloud_chat_demo/src/platform/clipboard_guard.dart';
import 'package:tencent_cloud_chat_demo/src/services/conversation_local/conversation_list_notifier.dart';
import 'package:tencent_cloud_chat_demo/src/services/conversation_local/conversation_sync_service.dart';
import 'package:tencent_cloud_chat_demo/src/services/conversation_local/conversation_perf_flags.dart';
import 'package:tencent_cloud_chat_demo/src/services/im_group_receive_opt.dart';
import 'package:tencent_cloud_chat_demo/utils/dio_error_message.dart';
import 'package:tencent_cloud_chat_demo/utils/toast.dart';
import 'package:tencent_cloud_chat_sdk/enum/group_type.dart';
import 'package:tencent_cloud_chat_sdk/enum/receive_message_opt_enum.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_conversation.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_conversation.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_group_member_full_info.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_group_member_full_info.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_group_info.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_group_info.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_message.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_message.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_user_full_info.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_user_full_info.dart';
import 'package:tencent_cloud_chat_uikit/business_logic/life_cycle/group_profile_life_cycle.dart';
import 'package:tencent_cloud_chat_uikit/business_logic/separate_models/tui_group_profile_model.dart';
import 'package:tencent_cloud_chat_uikit/business_logic/view_models/tui_friendship_view_model.dart';
import 'package:tencent_cloud_chat_uikit/business_logic/view_models/tui_self_info_view_model.dart';
import 'package:tencent_cloud_chat_uikit/data_services/services_locatar.dart';
import 'package:tencent_cloud_chat_uikit/tencent_cloud_chat_uikit.dart';
import 'package:tencent_cloud_chat_uikit/ui/utils/message_anchor.dart';
import 'package:tencent_cloud_chat_uikit/ui/utils/platform.dart';
import 'package:tencent_cloud_chat_uikit/ui/utils/screen_utils.dart';
import 'package:tencent_cloud_chat_demo/utils/friend_add_source.dart';
import 'package:tencent_cloud_chat_demo/utils/friend_mutual_utils.dart';
import 'package:tencent_cloud_chat_demo/utils/theme.dart';
import 'package:tencent_cloud_chat_demo/utils/user_display_profile.dart';
import 'package:tencent_cloud_chat_demo/utils/profile_page_nav.dart';
import 'package:tencent_cloud_chat_demo/src/group_manage_page.dart';
import 'package:tencent_cloud_chat_demo/src/pages/profile_nickname_edit_page.dart';
import 'package:tencent_cloud_chat_demo/src/utils/group_invite_member_page_meta.dart';
import 'package:tencent_cloud_chat_demo/utils/app_material_theme.dart';
import 'package:tencent_cloud_chat_uikit/ui/views/TIMUIKitAddFriend/tim_uikit_send_application.dart';
import 'package:tencent_cloud_chat_uikit/ui/views/TIMUIKitGroupProfile/group_member/tui_add_group_member.dart';
import 'package:tencent_cloud_chat_uikit/ui/views/TIMUIKitGroupProfile/group_member/tui_delete_group_member.dart';
import 'package:tencent_cloud_chat_uikit/ui/views/TIMUIKitGroupProfile/group_member/tui_group_member_list.dart';
import 'package:tencent_cloud_chat_uikit/ui/views/TIMUIKitGroupProfile/group_profile_widget.dart';
import 'package:tencent_cloud_chat_uikit/ui/views/TIMUIKitGroupProfile/widgets/tim_uikit_group_button_area.dart';
import 'package:tencent_cloud_chat_demo/src/pages/profile_signature_edit_page.dart';
import 'package:tencent_cloud_chat_uikit/ui/views/TIMUIKitGroupProfile/widgets/tim_ui_group_profile_widget.dart';
import 'package:tencent_cloud_chat_uikit/ui/views/TIMUIKitGroupProfile/widgets/tim_uikit_group_detail_card.dart';
import 'package:tencent_cloud_chat_demo/src/widgets/group_member_preview_skeleton.dart';
import 'package:tencent_cloud_chat_demo/src/widgets/group_profile_type_indicators.dart';
import 'package:tencent_cloud_chat_uikit/ui/widgets/avatar.dart';
import 'package:tencent_cloud_chat_uikit/ui/widgets/text_input_bottom_sheet.dart';
import 'package:tencent_cloud_chat_uikit/theme/tui_theme.dart';
import 'package:tencent_cloud_chat_demo/src/navigation/app_chat_route.dart';
import 'package:tencent_cloud_chat_demo/src/navigation/app_page_transitions.dart';
import 'package:tencent_cloud_chat_demo/src/search.dart';
import 'package:tencent_cloud_chat_demo/src/pages/complaint/complaint_reason_page.dart';
import 'package:tencent_cloud_chat_demo/src/user_profile.dart';
import 'package:tencent_cloud_chat_demo/src/ui/utils/desktop_modal_layout.dart';
import 'package:tencent_cloud_chat_uikit/data_services/core/tim_uikit_wide_modal_operation_key.dart';
import 'package:tencent_cloud_chat_uikit/ui/widgets/wide_popup.dart';

String _resolveGroupDisplayAlias(V2TimGroupInfo groupInfo) {
  // 群资料「群ID」展示后端原文（如 m2BXTRBN5CK），不展示客户端展开的完整 IM ID。
  return ChatIdFormat.displayGroupAlias(
    groupInfo.customInfo?['displayAlias'],
    groupIdFallback: groupInfo.groupID,
  );
}

int _resolveDisplayedMemberCount(
  TUIGroupProfileModel model,
  List<V2TimGroupMemberFullInfo?> memberList,
) {
  final listed = memberList.whereType<V2TimGroupMemberFullInfo>().length;
  final reported = model.groupInfo?.memberCount ?? 0;
  if (listed > reported) {
    return listed;
  }
  return reported > 0 ? reported : listed;
}

class GroupProfilePage extends StatelessWidget {
  final String groupID;
  final sdkInstance = TIMUIKitCore.getSDKInstance();
  final coreInstance = TIMUIKitCore.getInstance();

  GroupProfilePage({Key? key, required this.groupID}) : super(key: key);

  bool _isWideScreen(BuildContext context) {
    return TUIKitScreenUtils.getFormFactor(context) == DeviceType.Desktop;
  }

  bool _canManageGroup(V2TimGroupInfo groupInfo) {
    return GroupRolePolicy.isManagerRole(groupInfo.role);
  }

  String _groupNameCardForEdit(TUIGroupProfileModel model) {
    return model.getSelfNameCard().trim();
  }

  String _groupNameCardHintBaseline(TUIGroupProfileModel model) {
    final nameCard = _groupNameCardForEdit(model);
    if (nameCard.isNotEmpty) {
      return nameCard;
    }
    final selfInfo = serviceLocator<TUISelfInfoViewModel>().loginInfo;
    final profileNickname = selfInfo?.nickName?.trim() ?? '';
    if (profileNickname.isNotEmpty) {
      return profileNickname;
    }
    final loginUserID = selfInfo?.userID;
    if (loginUserID != null) {
      for (final member
          in model.groupMemberList ?? <V2TimGroupMemberFullInfo?>[]) {
        if (member?.userID == loginUserID) {
          final memberNick = member?.nickName?.trim() ?? '';
          if (memberNick.isNotEmpty) {
            return memberNick;
          }
          break;
        }
      }
    }
    return '';
  }

  String _getMemberShowName(V2TimGroupMemberFullInfo? item) {
    if (item == null) {
      return '';
    }
    return UserDisplayProfile.nameOfMember(item);
  }

  int _memberPreviewSortRank(
    V2TimGroupMemberFullInfo member,
    String? selfUserId,
  ) {
    final roleRank = GroupRolePolicy.memberSortRank(member.role);
    if (roleRank < 2) {
      return roleRank;
    }
    if (selfUserId != null && member.userID == selfUserId) {
      return 2;
    }
    return 3;
  }

  List<V2TimGroupMemberFullInfo> _sortedMembersForPreview(
    List<V2TimGroupMemberFullInfo?> memberList,
    String? selfUserId,
  ) {
    final members = memberList.whereType<V2TimGroupMemberFullInfo>().toList();
    members.sort((a, b) {
      final rankCompare = _memberPreviewSortRank(a, selfUserId).compareTo(
        _memberPreviewSortRank(b, selfUserId),
      );
      if (rankCompare != 0) {
        return rankCompare;
      }
      return _getMemberShowName(a).compareTo(_getMemberShowName(b));
    });
    return members;
  }

  String? _memberRolePreviewLabel(
    BuildContext context,
    V2TimGroupMemberFullInfo member,
  ) {
    final i18n = AppI18n.of(context);
    switch (GroupRolePolicy.roleBadgeKey(member.role)) {
      case 'owner':
        return i18n.t(
          zhHans: '群主',
          zhHant: '群主',
          en: 'Owner',
          ja: 'オーナー',
          ko: '그룹장',
        );
      case 'admin':
        return i18n.t(
          zhHans: '管理员',
          zhHant: '管理員',
          en: 'Admin',
          ja: '管理者',
          ko: '관리자',
        );
      default:
        return null;
    }
  }

  Color _memberRolePreviewColor(
      TUITheme theme, V2TimGroupMemberFullInfo member) {
    switch (GroupRolePolicy.roleBadgeKey(member.role)) {
      case 'owner':
        return theme.primaryColor ?? const Color(0xFF1E90FF);
      case 'admin':
        return theme.infoColor ?? const Color(0xFF909399);
      default:
        return Colors.transparent;
    }
  }

  Future<void> _openSearchMessage(
    BuildContext context,
    V2TimConversation? conversation,
  ) async {
    // 从群资料页进入“查找聊天内容”时，搜索页用于替代当前资料页。
    // 搜索结果点击后 Search 会用 pushReplacement 替换成聊天页，最终栈为：
    // 原聊天页 -> 目标聊天页，避免“聊天页 -> 资料页 -> 搜索页 -> 聊天页”叠加。
    await Navigator.pushReplacement(
      context,
      AppMaterialPageRoute(
        settings: const RouteSettings(name: AppRoutes.searchInConversation),
        builder: (context) => Search(
          onTapConversation:
              (V2TimConversation conversation, MessageAnchor? anchor) {
            openChatWithAnchor(context, conversation, anchor: anchor);
          },
          conversation: conversation,
        ),
      ),
    );
  }

  Future<void> _openComplaint(
    BuildContext context,
    TUIGroupProfileModel model,
    V2TimGroupInfo groupInfo,
  ) async {
    // 群资料入口按「投诉本群」处理，不再弹选人；接口仍需 reportedUserId。
    final reportedUserId = _resolveGroupComplaintTargetId(model, groupInfo);
    if (reportedUserId == null || reportedUserId.isEmpty) {
      ToastUtils.toast(AppI18n.of(context).t(
        zhHans: '暂无可投诉对象',
        zhHant: '暫無可投訴對象',
        en: 'No one available to report.',
        ja: '通報できる対象がいません。',
        ko: '신고할 대상이 없습니다.',
      ));
      return;
    }
    await ComplaintReasonPage.openGroup(
      context,
      groupId: groupInfo.groupID,
      reportedUserId: reportedUserId,
      reportedUserName: groupInfo.groupName?.trim().isNotEmpty == true
          ? groupInfo.groupName!.trim()
          : groupInfo.groupID,
    );
  }

  /// 群资料投诉：优先群主；群主是自己时取其他成员，满足接口必填 reportedUserId。
  String? _resolveGroupComplaintTargetId(
    TUIGroupProfileModel model,
    V2TimGroupInfo groupInfo,
  ) {
    final selfId =
        serviceLocator<TUISelfInfoViewModel>().loginInfo?.userID?.trim() ?? '';
    final ownerId = groupInfo.owner?.trim() ?? '';
    if (ownerId.isNotEmpty && ownerId != selfId) {
      return ownerId;
    }
    for (final member in model.groupMemberList) {
      final userId = member?.userID.trim() ?? '';
      if (userId.isNotEmpty && userId != selfId) {
        return userId;
      }
    }
    return null;
  }

  Future<void> _openDesktopSubpage({
    required BuildContext context,
    required String title,
    required Widget page,
    required TUIKitWideModalOperationKey operationKey,
    Size Function(BuildContext)? desktopSize,
    VoidCallback? onConfirm,
    VoidCallback? onCancel,
    String? confirmText,
  }) async {
    final size = (desktopSize ?? DesktopModalLayout.large)(context);
    await TUIKitWidePopup.showPopupWindow(
      operationKey: operationKey,
      context: context,
      title: title,
      width: size.width,
      height: size.height,
      borderRadius: const BorderRadius.all(Radius.circular(16)),
      onCancel: onCancel,
      onConfirm: onConfirm,
      confirmText: confirmText,
      child: (closeFunc) => page,
    );
  }

  void _openGroupMemberList(
    BuildContext context,
    TUIGroupProfileModel model,
    List<V2TimGroupMemberFullInfo?> memberList,
  ) {
    final presence = Provider.of<PresenceProvider>(context, listen: false);
    final friendship = serviceLocator<TUIFriendShipViewModel>();
    final page = GroupProfileMemberListPage(
      model: model,
      memberList: memberList,
      presenceListenable: presence,
      presenceLabelBuilder: (userId, imOnline) => presence.onlineLabelFor(
        userId: userId,
        imOnline: imOnline,
        isMutualFriend: friendCanMessage(friendship, userId),
      ),
      presenceLoadingChecker: (userId, imOnline) =>
          presence.isLastSeenLoading(userId: userId, imOnline: imOnline),
      onMemberListLoaded: (userIds) {
        presence.ensure(userIds);
      },
    );
    if (DesktopModalLayout.isDesktop(context)) {
      final count = memberList.whereType<V2TimGroupMemberFullInfo>().length;
      unawaited(_openDesktopSubpage(
        context: context,
        title: AppI18n.of(context).format(
          zhHans: '群成员({option1}人)',
          zhHant: '群成員({option1}人)',
          en: 'Members ({option1})',
          ja: 'メンバー({option1})',
          ko: '멤버({option1})',
          vars: {'option1': '$count'},
        ),
        page: page,
        operationKey: TUIKitWideModalOperationKey.groupMembersList,
        desktopSize: DesktopModalLayout.medium,
        onConfirm: () {},
        confirmText: AppI18n.of(context).t(
          zhHans: '关闭',
          zhHant: '關閉',
          en: 'Close',
          ja: '閉じる',
          ko: '닫기',
        ),
      ));
      return;
    }
    Navigator.push(
      context,
      AppMaterialPageRoute(builder: (context) => page),
    );
  }

  Future<void> _openAddGroupMember(
    BuildContext context,
    TUIGroupProfileModel model,
  ) async {
    final presence = Provider.of<PresenceProvider>(context, listen: false);
    final friendship = serviceLocator<TUIFriendShipViewModel>();
    final page = AddGroupMemberPage(
      key: addGroupMemberKey,
      model: model,
      presenceListenable: presence,
      presenceLabelBuilder: (userId, imOnline) => presence.onlineLabelFor(
        userId: userId,
        imOnline: imOnline,
        isMutualFriend: friendCanMessage(friendship, userId),
      ),
      presenceLoadingChecker: (userId, imOnline) =>
          presence.isLastSeenLoading(userId: userId, imOnline: imOnline),
      onContactListLoaded: (userIds) {
        presence.ensure(userIds);
      },
      inviteNeedsApprovalLoader: () =>
          GroupInviteMemberPageMeta.inviteNeedsApproval(model.groupID),
      existingMemberUserIdsLoader: () =>
          GroupInviteMemberPageMeta.existingMemberUserIds(model.groupID),
      pendingReviewUserIdsLoader: () =>
          GroupInviteMemberPageMeta.pendingReviewUserIds(
        model.groupID,
        memberUserIds: model.groupMemberList
            .map((item) => item?.userID ?? '')
            .where((id) => id.trim().isNotEmpty)
            .toSet(),
      ),
    );
    if (DesktopModalLayout.isDesktop(context)) {
      await _openDesktopSubpage(
        context: context,
        title: AppI18n.of(context).t(
          zhHans: '添加成员',
          zhHant: '添加成員',
          en: 'Add Members',
          ja: 'メンバーを追加',
          ko: '멤버 추가',
        ),
        page: page,
        operationKey: TUIKitWideModalOperationKey.addGroupMembers,
        onCancel: () {},
        onConfirm: () {
          addGroupMemberKey.currentState?.submitAdd();
        },
        confirmText: AppI18n.of(context).t(
          zhHans: '完成',
          zhHant: '完成',
          en: 'Done',
          ja: '完了',
          ko: '완료',
        ),
      );
    } else {
      await Navigator.push(
        context,
        AppMaterialPageRoute(builder: (context) => page),
      );
    }
    if (!context.mounted) {
      return;
    }
    // 邀请增量已由 API 热路径写入；此处只刷群资料人数，禁止整表 reload。
    await model.loadGroupInfo(model.groupID);
  }

  Future<void> _openDeleteGroupMember(
    BuildContext context,
    TUIGroupProfileModel model,
  ) async {
    final presence = Provider.of<PresenceProvider>(context, listen: false);
    final friendship = serviceLocator<TUIFriendShipViewModel>();
    final deleteKey = GlobalKey<DeleteGroupMemberPageState>();
    final page = DeleteGroupMemberPage(
      key: deleteKey,
      model: model,
      presenceListenable: presence,
      presenceLabelBuilder: (userId, imOnline) => presence.onlineLabelFor(
        userId: userId,
        imOnline: imOnline,
        isMutualFriend: friendCanMessage(friendship, userId),
      ),
      presenceLoadingChecker: (userId, imOnline) =>
          presence.isLastSeenLoading(userId: userId, imOnline: imOnline),
      onMemberListLoaded: (userIds) {
        presence.ensure(userIds);
      },
    );
    if (DesktopModalLayout.isDesktop(context)) {
      await _openDesktopSubpage(
        context: context,
        title: AppI18n.of(context).t(
          zhHans: '删除群成员',
          zhHant: '刪除群成員',
          en: 'Remove Members',
          ja: 'メンバーを削除',
          ko: '멤버 삭제',
        ),
        page: page,
        operationKey: TUIKitWideModalOperationKey.kickOffGroupMembers,
        onCancel: () {},
        onConfirm: () {
          unawaited(deleteKey.currentState?.submitDelete() ?? Future.value());
        },
        confirmText: AppI18n.of(context).t(
          zhHans: '完成',
          zhHant: '完成',
          en: 'Done',
          ja: '完了',
          ko: '완료',
        ),
      );
    } else {
      await Navigator.push(
        context,
        AppMaterialPageRoute(builder: (context) => page),
      );
    }
    if (!context.mounted) {
      return;
    }
    await model.reloadGroupMembers(model.groupID);
    await model.loadGroupInfo(model.groupID);
  }

  Future<void> _openGroupNotice(
    BuildContext context,
    TUIGroupProfileModel model,
    String notification,
  ) async {
    final result = await ProfileSignatureEditPage.pushGroupNotice(
      context,
      model: model,
      initialNotification: notification,
    );
    if (result != null) {
      GroupNoticeRefreshBus.instance.notifyRefresh(
        groupID,
        notification: model.groupInfo?.notification,
      );
    }
  }

  void _openGroupManage(
    BuildContext context,
    TUIGroupProfileModel model,
  ) {
    final page = GroupManagePage(
      model: model,
      groupID: groupID,
    );
    if (DesktopModalLayout.isDesktop(context)) {
      unawaited(_openDesktopSubpage(
        context: context,
        title: AppI18n.of(context).t(
          zhHans: '群管理',
          zhHant: '群管理',
          en: 'Group Manage',
          ja: 'グループ管理',
          ko: '그룹 관리',
        ),
        page: page,
        operationKey: TUIKitWideModalOperationKey.custom,
      ));
      return;
    }
    Navigator.push(
      context,
      AppMaterialPageRoute(builder: (context) => page),
    );
  }

  void _openGroupInfoDetail(
    BuildContext context,
    V2TimGroupInfo groupInfo,
    TUIGroupProfileModel model,
  ) {
    final page = GroupInfoDetailPage(
      groupInfo: groupInfo,
      model: model,
    );
    if (DesktopModalLayout.isDesktop(context)) {
      unawaited(_openDesktopSubpage(
        context: context,
        title: AppI18n.of(context).t(
          zhHans: '群详情',
          zhHant: '群詳情',
          en: 'Group Info',
          ja: 'グループ情報',
          ko: '그룹 정보',
        ),
        page: page,
        operationKey: TUIKitWideModalOperationKey.custom,
        desktopSize: DesktopModalLayout.medium,
      ));
      return;
    }
    Navigator.push(
      context,
      AppMaterialPageRoute(builder: (context) => page),
    );
  }

  void _openGroupQrCode(
    BuildContext context,
    V2TimGroupInfo groupInfo,
  ) {
    final page = QRCodePage(
      type: QRCodePageType.group,
      title: AppI18n.of(context).t(
        zhHans: '群二维码',
        zhHant: '群 QR 碼',
        en: 'Group QR Code',
        ja: 'グループQRコード',
        ko: '그룹 QR 코드',
      ),
      displayName: groupInfo.groupName ?? groupInfo.groupID,
      aliasLabel: AppI18n.of(context).t(
        zhHans: '群ID',
        zhHant: '群ID',
        en: 'Group ID',
        ja: 'グループID',
        ko: '그룹 ID',
      ),
      aliasValue: _resolveGroupDisplayAlias(groupInfo),
      qrPayloadId: ChatIdFormat.canonicalGroupStorageId(groupInfo.groupID),
      faceUrl: groupInfo.faceUrl ?? "",
      shareText: "${AppI18n.of(context).t(
        zhHans: '群二维码',
        zhHant: '群 QR 碼',
        en: 'Group QR Code',
        ja: 'グループQRコード',
        ko: '그룹 QR 코드',
      )} ${_resolveGroupDisplayAlias(groupInfo)}",
      embedded: DesktopModalLayout.isDesktop(context),
    );
    if (DesktopModalLayout.isDesktop(context)) {
      unawaited(_openDesktopSubpage(
        context: context,
        title: AppI18n.of(context).t(
          zhHans: '群二维码',
          zhHant: '群 QR 碼',
          en: 'Group QR Code',
          ja: 'グループQRコード',
          ko: '그룹 QR 코드',
        ),
        page: page,
        operationKey: TUIKitWideModalOperationKey.custom,
        desktopSize: DesktopModalLayout.qrCode,
      ));
      return;
    }
    Navigator.push(
      context,
      AppMaterialPageRoute(builder: (context) => page),
    );
  }

  Future<void> _copyGroupAlias(BuildContext context, String alias) async {
    final text = alias.trim();
    if (text.isEmpty) {
      return;
    }
    await ClipboardGuard.copy(text);
    ToastUtils.toast(AppI18n.of(context).t(
      zhHans: '群ID已复制',
      zhHant: '群ID已複製',
      en: 'Group ID copied',
      ja: 'グループIDをコピーしました',
      ko: '그룹 ID 복사됨',
    ));
  }

  Widget _buildGroupAliasRow({
    required BuildContext context,
    required TUITheme theme,
    required String groupAlias,
    required VoidCallback onQrTap,
  }) {
    final titleColor = theme.darkTextColor ?? Colors.black;
    final valueColor = theme.primaryColor ?? const Color(0xFF1E90FF);
    final iconColor = theme.darkTextColor ?? Colors.black;
    return SizedBox(
      height: 56,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          children: [
            Expanded(
              child: Text(
                AppI18n.of(context).t(
                  zhHans: '群ID',
                  zhHant: '群ID',
                  en: 'Group ID',
                  ja: 'グループID',
                  ko: '그룹 ID',
                ),
                style: TextStyle(
                  fontSize: 15,
                  color: titleColor,
                ),
              ),
            ),
            Expanded(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  if (groupAlias.isNotEmpty)
                    Flexible(
                      child: InkWell(
                        onTap: () => _copyGroupAlias(context, groupAlias),
                        borderRadius: BorderRadius.circular(4),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Text(
                            groupAlias,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.right,
                            style: TextStyle(
                              fontSize: 15,
                              color: valueColor,
                            ),
                          ),
                        ),
                      ),
                    ),
                  const SizedBox(width: 8),
                  InkWell(
                    onTap: onQrTap,
                    borderRadius: BorderRadius.circular(4),
                    child: Padding(
                      padding: const EdgeInsets.all(4),
                      child: Icon(
                        Icons.qr_code_2_rounded,
                        color: iconColor,
                        size: 22,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showEditNameCard(
    BuildContext context,
    TUITheme theme,
    TUIGroupProfileModel model,
  ) async {
    await ProfileNicknameEditPage.pushGroupNameCard(
      context,
      initialNameCard: _groupNameCardForEdit(model),
      hintBaseline: _groupNameCardHintBaseline(model),
      onSave: (String newText) async {
        final res = await model.setNameCard(newText.trim());
        if (res == null || res.code != 0) {
          ToastUtils.toast(
            DioErrorMessage.sanitizeUserText(
              res?.desc,
              fallback: AppI18n.of(context).t(
                zhHans: '保存失败',
                zhHant: '儲存失敗',
                en: 'Save failed',
                ja: '保存に失敗',
                ko: '저장 실패',
              ),
            ),
          );
          return false;
        }
        ToastUtils.toast(AppI18n.of(context).t(
          zhHans: '修改成功',
          zhHant: '修改成功',
          en: 'Updated',
          ja: '変更しました',
          ko: '수정되었습니다',
        ));
        return true;
      },
    );
  }

  Widget _buildSectionGap(TUITheme theme) {
    final baseColor =
        theme.appbarBgColor ?? theme.wideBackgroundColor ?? Colors.white;
    final isDarkBackground =
        ThemeData.estimateBrightnessForColor(baseColor) == Brightness.dark;
    return Container(
      height: 18,
      color: isDarkBackground ? baseColor : const Color(0xFFF1F1F1),
    );
  }

  Widget _buildSectionCard(
    TUITheme theme,
    List<Widget> children,
  ) {
    final itemBackgroundColor = theme.conversationItemBgColor ??
        theme.wideBackgroundColor ??
        Colors.white;
    return Container(
      color: itemBackgroundColor,
      child: Column(
        children: List.generate(children.length * 2 - 1, (index) {
          if (index.isOdd) {
            return Divider(
              height: 1,
              thickness: 1,
              indent: 16,
              endIndent: 16,
              color: theme.weakDividerColor,
            );
          }
          return children[index ~/ 2];
        }),
      ),
    );
  }

  Widget _buildArrowRow({
    required TUITheme theme,
    required String title,
    String? value,
    VoidCallback? onTap,
    bool showArrow = true,
    Color? valueColor,
    Widget? trailingWidget,
  }) {
    final titleColor = theme.darkTextColor ?? Colors.black;
    final trailingColor =
        valueColor ?? theme.weakTextColor ?? const Color(0xFF999999);
    return InkWell(
      onTap: onTap,
      child: SizedBox(
        height: 56,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 15,
                    color: titleColor,
                  ),
                ),
              ),
              if ((value != null && value.isNotEmpty) || showArrow)
                Expanded(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      if (value != null && value.isNotEmpty)
                        Flexible(
                          child: Text(
                            value,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.right,
                            style: TextStyle(
                              fontSize: 15,
                              color: trailingColor,
                            ),
                          ),
                        ),
                      if (trailingWidget != null) ...[
                        const SizedBox(width: 8),
                        trailingWidget,
                      ],
                      if (showArrow) ...[
                        const SizedBox(width: 6),
                        Icon(
                          Icons.keyboard_arrow_right,
                          color: theme.weakTextColor,
                          size: 20,
                        ),
                      ],
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGroupPinRow(TUIGroupProfileModel model) {
    return ConversationGroupProfilePinBar(
      groupID: groupID,
      conversation: model.conversation,
      source: 'group_profile',
      isUseCheckedBoxOnWide: false,
      onApplied: (pinned) {
        if (model.conversation != null) {
          model.conversation!.isPinned = pinned;
        }
      },
    );
  }

  Widget _buildSwitchRow({
    required TUITheme theme,
    required String title,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return SizedBox(
      height: 56,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          children: [
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  fontSize: 15,
                  color: theme.darkTextColor ?? Colors.black,
                ),
              ),
            ),
            Transform.scale(
              scale: 0.92,
              child: CupertinoSwitch(
                value: value,
                onChanged: onChanged,
                activeTrackColor: theme.primaryColor,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 群资料免打扰：先纠偏本地真实群 ID（多为 `@TGS#_mc…`），再多候选重试并回写本地。
  Future<void> _setGroupMessageDisturb(
    BuildContext context,
    TUIGroupProfileModel model,
    bool value,
  ) async {
    final candidates = await ImGroupReceiveOpt.resolveCandidates(model.groupID);
    if (candidates.isEmpty) {
      return;
    }
    var primaryImId = candidates.first;
    // 补齐会话壳，避免 SDK getConversation 未命中时开关无法落状态。
    if (model.conversation == null) {
      for (final item in ConversationListNotifier.instance.conversations) {
        final gid = item.groupID?.trim() ?? '';
        if (gid.isNotEmpty &&
            candidates.any((id) => ChatIdFormat.groupIdsEquivalent(gid, id))) {
          model.conversation = item;
          break;
        }
      }
    }
    final previousId = model.groupID;
    var lastCode = -1;
    var lastDesc = '';
    var ok = false;
    String? successId;
    final optIndex = value
        ? ReceiveMsgOptEnum.V2TIM_RECEIVE_NOT_NOTIFY_MESSAGE.index
        : ReceiveMsgOptEnum.V2TIM_RECEIVE_MESSAGE.index;
    final prevOpt = model.conversation?.recvOpt ?? 0;
    final optimistic = ConversationPerfFlags.recvOptOptimisticUiEnabled;
    if (optimistic) {
      // 072 phase-6 allowlist: pending-only UI projection. Success is
      // published by the Coordinator commit; SDK failure rolls this back.
      final conversation = model.conversation;
      final seedIds = <String>{
        for (final id in candidates) 'group_$id',
        if (conversation != null &&
            conversation.conversationID.trim().isNotEmpty)
          conversation.conversationID.trim(),
      };
      if (conversation != null) {
        conversation.recvOpt = optIndex;
      }
      for (final conversationId in seedIds) {
        ConversationListNotifier.instance.applyRecvOptLocally(
          conversationID: conversationId,
          recvOpt: optIndex,
          snapshot: conversation,
        );
      }
    }
    // 国内社群：优先控制台真源 `@TGS#_mc…`，避免先打错误加成 `@TGS#_@TGS#m2…`。
    for (final id in candidates) {
      model.groupID = id;
      final attempt = await model.setMessageDisturb(value);
      lastCode = attempt.code;
      lastDesc = attempt.desc;
      if (attempt.code == 0) {
        debugPrint('GroupProfile disturb ok id=$id');
        ok = true;
        successId = id;
        primaryImId = id;
        break;
      }
      debugPrint(
        'GroupProfile disturb fail id=$id code=${attempt.code} desc=${attempt.desc}',
      );
    }
    // 成功时把模型钉在真实 IM ID，避免后续操作继续用错误加成形态。
    model.groupID = (ok && successId != null && successId.isNotEmpty)
        ? successId
        : previousId;
    if (!ok) {
      if (optimistic) {
        final conversation = model.conversation;
        if (conversation != null) {
          conversation.recvOpt = prevOpt;
        }
        final seedIds = <String>{
          for (final id in candidates) 'group_$id',
          if (conversation != null &&
              conversation.conversationID.trim().isNotEmpty)
            conversation.conversationID.trim(),
        };
        for (final conversationId in seedIds) {
          ConversationListNotifier.instance.applyRecvOptLocally(
            conversationID: conversationId,
            recvOpt: prevOpt,
            snapshot: conversation,
          );
        }
      }
      if (context.mounted) {
        ToastUtils.toast(AppI18n.of(context).t(
          zhHans: '设置失败($lastCode) $lastDesc',
          zhHant: '設置失敗($lastCode) $lastDesc',
          en: 'Failed ($lastCode) $lastDesc',
          ja: '失敗($lastCode) $lastDesc',
          ko: '실패($lastCode) $lastDesc',
        ));
      }
      return;
    }

    final conversation = model.conversation;
    if (conversation != null) {
      final conversationId = conversation.conversationID.trim().isNotEmpty
          ? conversation.conversationID.trim()
          : 'group_$primaryImId';
      try {
        await ConversationSyncService.instance.applyConversationMuteLocally(
          conversationID: conversationId,
          recvOpt: optIndex,
          snapshot: conversation,
        );
      } catch (e) {
        debugPrint('GroupProfile disturb commit failed: $e');
      }
    } else {
      final persistIds = <String>{
        'group_$primaryImId',
        for (final id in candidates) 'group_$id',
      };
      for (final conversationId in persistIds) {
        try {
          await ConversationSyncService.instance.applyConversationMuteLocally(
            conversationID: conversationId,
            recvOpt: optIndex,
          );
        } catch (e) {
          debugPrint('GroupProfile disturb shell commit failed: $e');
        }
      }
    }
  }

  Widget _buildMemberPreviewItem(
    BuildContext context,
    TUITheme theme,
    TUIGroupProfileModel model,
    V2TimGroupMemberFullInfo memberInfo,
  ) {
    final showName = _getMemberShowName(memberInfo);
    final roleLabel = _memberRolePreviewLabel(context, memberInfo);
    final roleColor = _memberRolePreviewColor(theme, memberInfo);
    return InkWell(
      onTapDown: (details) {
        if (model.onClickUser != null) {
          model.onClickUser!(memberInfo, details);
        }
      },
      child: SizedBox(
        width: 54,
        child: Column(
          children: [
            SizedBox(
              width: 40,
              height: 40,
              child: Stack(
                clipBehavior: Clip.none,
                alignment: Alignment.center,
                children: [
                  Avatar(
                    faceUrl: UserDisplayProfile.avatarOfMember(memberInfo),
                    showName: showName,
                    type: 1,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  if (roleLabel != null)
                    Positioned(
                      left: -4,
                      right: -4,
                      bottom: -3,
                      child: Container(
                        alignment: Alignment.center,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 3,
                          vertical: 1,
                        ),
                        decoration: BoxDecoration(
                          color: roleColor,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          roleLabel,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 8,
                            fontWeight: FontWeight.w600,
                            height: 1.1,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 4),
            Text(
              showName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 11,
                color: theme.weakTextColor,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMemberActionItem({
    required BuildContext context,
    required TUITheme theme,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    final baseColor =
        theme.appbarBgColor ?? theme.wideBackgroundColor ?? Colors.white;
    final isDarkBackground =
        ThemeData.estimateBrightnessForColor(baseColor) == Brightness.dark;
    final buttonBackgroundColor =
        isDarkBackground ? const Color(0xFF2E3238) : const Color(0xFFF1F3F5);
    final iconColor =
        isDarkBackground ? const Color(0xFFB8BDC7) : const Color(0xFF9AA0A6);
    return InkWell(
      onTap: onTap,
      child: SizedBox(
        width: 54,
        child: Column(
          children: [
            Container(
              width: 40,
              height: 40,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: buttonBackgroundColor,
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                color: iconColor,
                size: 22,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              AppI18n.of(context).t(
                zhHans: '操作',
                zhHant: '操作',
                en: 'Actions',
                ja: '操作',
                ko: '작업',
              ),
              style: const TextStyle(
                fontSize: 10,
                color: Colors.transparent,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMemberPreviewCard(
    BuildContext context,
    TUITheme theme,
    V2TimGroupInfo groupInfo,
    TUIGroupProfileModel model,
    List<V2TimGroupMemberFullInfo?> memberList,
  ) {
    final itemBackgroundColor = theme.conversationItemBgColor ??
        theme.wideBackgroundColor ??
        Colors.white;
    final groupId = groupInfo.groupID.trim();
    final localRecord = groupId.isEmpty
        ? null
        : GroupLocalStore.instance.readCached(groupId: groupId);
    final localName = localRecord?.groupName.trim() ?? '';
    final groupName = (localName.isNotEmpty &&
            !GroupDisplayResolver.looksLikeGroupIdLabel(
              localName,
              groupId: groupId,
            ))
        ? localName
        : (groupInfo.groupName?.trim().isNotEmpty == true
            ? groupInfo.groupName!.trim()
            : groupInfo.groupID);
    final groupFaceUrl = ConversationFaceUrl.resolve(
      userId: null,
      conversationFaceUrl: groupInfo.faceUrl,
      isGroup: true,
      groupId: groupId,
      groupList: serviceLocator<TUIFriendShipViewModel>().groupList,
    );
    final avatarVersion = localRecord?.avatarVersion ?? 0;
    final canOpenGroupInfo = _canManageGroup(groupInfo);
    final canInviteMember = model.canInviteMember();
    final canKickOffMember = model.canKickOffMember();
    final localMemberCount = localRecord?.memberCount ?? 0;
    final memberCount = localMemberCount > 0
        ? localMemberCount
        : _resolveDisplayedMemberCount(model, memberList);
    const maxPreviewSlots = 10;
    final actionSlotCount =
        (canInviteMember ? 1 : 0) + (canKickOffMember ? 1 : 0);
    final maxMemberSlots = maxPreviewSlots - actionSlotCount;
    final listedMembers =
        memberList.whereType<V2TimGroupMemberFullInfo>().toList();
    final showAvatarSkeleton =
        model.isGroupMemberListLoading && listedMembers.isEmpty;
    final skeletonEstimate =
        memberCount > 0 ? memberCount : (groupInfo.memberCount ?? 0);
    final selfUserId = serviceLocator<TUISelfInfoViewModel>().loginInfo?.userID;
    final memberPreviewItems = _sortedMembersForPreview(memberList, selfUserId)
        .take(maxMemberSlots)
        .map(
          (member) => _buildMemberPreviewItem(
            context,
            theme,
            model,
            member,
          ),
        )
        .toList();
    final previewItems = <Widget>[
      ...memberPreviewItems,
      if (canInviteMember)
        _buildMemberActionItem(
          context: context,
          theme: theme,
          icon: Icons.add,
          onTap: () => unawaited(_openAddGroupMember(context, model)),
        ),
      if (canKickOffMember)
        _buildMemberActionItem(
          context: context,
          theme: theme,
          icon: Icons.remove,
          onTap: () => _openDeleteGroupMember(context, model),
        ),
    ];

    return Container(
      color: itemBackgroundColor,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 18, 16, 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: InkWell(
                    onTap: canOpenGroupInfo
                        ? () => _openGroupInfoDetail(
                              context,
                              groupInfo,
                              model,
                            )
                        : null,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        buildGroupTitleWithOptionalFlame(
                          name: groupName,
                          groupType: groupInfo.groupType,
                          flameSize: 16,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: conversationGroupTitleColor(
                              fallback: theme.darkTextColor ?? Colors.black,
                              groupType: groupInfo.groupType,
                            ),
                          ),
                        ),
                        // 超级大群 / 普通群等类型徽章放在昵称下方。
                        if (groupProfileShowsTypeCategory(
                                groupInfo.groupType) ||
                            groupProfileIsSuperLargeGroup(
                                groupInfo.groupType)) ...[
                          const SizedBox(height: 6),
                          Wrap(
                            crossAxisAlignment: WrapCrossAlignment.center,
                            spacing: 8,
                            runSpacing: 4,
                            children: [
                              GroupProfileTypeNameBadge(
                                groupType: groupInfo.groupType,
                                theme: theme,
                              ),
                              GroupProfileTypeIdBadge(
                                groupType: groupInfo.groupType,
                                theme: theme,
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                SizedBox(
                  width: 56,
                  height: 56,
                  child: Avatar(
                    faceUrl: groupFaceUrl,
                    showName: groupName,
                    type: 2,
                    isShowBigWhenClick: true,
                    previewFaceUrl: localRecord?.avatarPreviewUrl,
                    previewUrlResolver: () async {
                      final result = await MeGroupApi.instance
                          .fetchGroupAvatarPreview(groupId);
                      return result.previewUrl;
                    },
                    avatarCacheKey:
                        'avatar|group|$groupId|$avatarVersion|thumb',
                    previewCacheKey:
                        'avatar|group|$groupId|$avatarVersion|preview',
                    borderRadius: BorderRadius.circular(28),
                  ),
                ),
                if (canOpenGroupInfo) ...[
                  const SizedBox(width: 8),
                  InkWell(
                    onTap: () =>
                        _openGroupInfoDetail(context, groupInfo, model),
                    borderRadius: BorderRadius.circular(20),
                    child: Padding(
                      padding: const EdgeInsets.all(4),
                      child: Icon(
                        Icons.keyboard_arrow_right,
                        color: theme.weakTextColor,
                        size: 22,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 6, 16, 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (showAvatarSkeleton)
                  GroupMemberPreviewSkeletonGrid(
                    theme: theme,
                    estimatedMemberCount: skeletonEstimate,
                    actionSlotCount: actionSlotCount,
                  )
                else
                  GridView.count(
                    crossAxisCount: 5,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    mainAxisSpacing: 4,
                    crossAxisSpacing: 4,
                    childAspectRatio: 0.96,
                    children: previewItems,
                  ),
                InkWell(
                  onTap: () => _openGroupMemberList(context, model, memberList),
                  child: Padding(
                    padding: const EdgeInsets.only(top: 10, bottom: 2),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            AppI18n.of(context).t(
                              zhHans: '群成员',
                              zhHant: '群成員',
                              en: 'Members',
                              ja: 'メンバー',
                              ko: '멤버',
                            ),
                            style: TextStyle(
                              fontSize: 14,
                              color: theme.darkTextColor ?? Colors.black,
                            ),
                          ),
                        ),
                        Text(
                          AppI18n.of(context).format(
                            zhHans: '共{option1}人',
                            zhHant: '共{option1}人',
                            en: '{option1} members',
                            ja: '計{option1}人',
                            ko: '총 {option1}명',
                            vars: {'option1': '$memberCount'},
                          ),
                          style: TextStyle(
                            fontSize: 14,
                            color: theme.weakTextColor,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Icon(
                          Icons.keyboard_arrow_right,
                          color: theme.weakTextColor,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          _buildSectionGap(theme),
        ],
      ),
    );
  }

  Widget _buildMobileGroupProfile(
    BuildContext context,
    TUITheme theme,
    V2TimGroupInfo groupInfo,
    List<V2TimGroupMemberFullInfo?> groupMemberList,
    TUIGroupProfileModel model,
  ) {
    final canManageGroup = _canManageGroup(groupInfo);
    final localRecord = GroupLocalStore.instance.readCached(
      groupId: groupInfo.groupID,
    );
    // Presence of a Store row is authoritative even when the notice is empty;
    // otherwise a cleared notice is resurrected from stale SDK groupInfo.
    final notice = localRecord != null
        ? localRecord.notice.trim()
        : (groupInfo.notification ?? "").trim();
    final groupNoticeText = notice.isEmpty
        ? AppI18n.of(context).t(
            zhHans: '暂无群公告',
            zhHant: '暫無群公告',
            en: 'No group notice',
            ja: 'グループのお知らせはありません',
            ko: '그룹 공지 없음',
          )
        : notice;
    final nameCard = model.getSelfNameCard().trim();
    final showMuteSwitch = groupInfo.groupType != GroupType.Meeting;
    final localAlias = localRecord?.displayAlias.trim() ?? '';
    final groupAlias = localAlias.isNotEmpty
        ? localAlias
        : _resolveGroupDisplayAlias(groupInfo);

    final basicRows = <Widget>[
      _buildGroupAliasRow(
        context: context,
        theme: theme,
        groupAlias: groupAlias,
        onQrTap: () => _openGroupQrCode(context, groupInfo),
      ),
      _buildArrowRow(
        theme: theme,
        title: AppI18n.of(context).t(
          zhHans: '群公告',
          zhHant: '群公告',
          en: 'Group Notice',
          ja: 'グループのお知らせ',
          ko: '그룹 공지',
        ),
        value: groupNoticeText,
        onTap: canManageGroup
            ? () =>
                _openGroupNotice(context, model, groupInfo.notification ?? "")
            : null,
        showArrow: canManageGroup,
      ),
      _buildArrowRow(
        theme: theme,
        title: AppI18n.of(context).t(
          zhHans: '我的群昵称',
          zhHant: '我的群暱稱',
          en: 'My Group Nickname',
          ja: 'グループ内のニックネーム',
          ko: '그룹 닉네임',
        ),
        value: nameCard.isEmpty
            ? AppI18n.of(context).t(
                zhHans: '未设置',
                zhHant: '未設定',
                en: 'Not set',
                ja: '未設定',
                ko: '설정 안 됨',
              )
            : nameCard,
        onTap: () => _showEditNameCard(context, theme, model),
      ),
    ];

    final chatRows = <Widget>[
      _buildArrowRow(
        theme: theme,
        title: AppI18n.of(context).t(
          zhHans: '查找聊天内容',
          zhHant: '查找聊天內容',
          en: 'Search in Chat',
          ja: 'チャット内を検索',
          ko: '채팅 내 검색',
        ),
        onTap: () => _openSearchMessage(context, model.conversation),
      ),
      if (showMuteSwitch)
        _buildSwitchRow(
          theme: theme,
          title: AppI18n.of(context).t(
            zhHans: '消息免打扰',
            zhHant: '訊息免打擾',
            en: 'Mute Notifications',
            ja: '通知をミュート',
            ko: '알림 끄기',
          ),
          value: (model.conversation?.recvOpt ?? 0) != 0,
          onChanged: (value) => _setGroupMessageDisturb(context, model, value),
        ),
      _buildGroupPinRow(model),
    ];

    final manageRows = <Widget>[
      if (canManageGroup)
        _buildArrowRow(
          theme: theme,
          title: AppI18n.of(context).t(
            zhHans: '管理群',
            zhHant: '管理群',
            en: 'Manage Group',
            ja: 'グループ管理',
            ko: '그룹 관리',
          ),
          onTap: () => _openGroupManage(context, model),
        ),
    ];

    final sectionCards = <Widget>[
      if (basicRows.isNotEmpty) _buildSectionCard(theme, basicRows),
      if (chatRows.isNotEmpty) _buildSectionGap(theme),
      if (chatRows.isNotEmpty) _buildSectionCard(theme, chatRows),
      if (manageRows.isNotEmpty) _buildSectionGap(theme),
      if (manageRows.isNotEmpty) _buildSectionCard(theme, manageRows),
    ];

    return Column(
      children: [
        _buildMemberPreviewCard(
          context,
          theme,
          groupInfo,
          model,
          groupMemberList,
        ),
        ...sectionCards,
        _buildSectionGap(theme),
        _buildSectionCard(
          theme,
          [
            _buildArrowRow(
              theme: theme,
              title: AppI18n.of(context).t(
                zhHans: '投诉',
                zhHant: '投訴',
                en: 'Complaint',
                ja: '通報',
                ko: '신고',
              ),
              onTap: () => _openComplaint(context, model, groupInfo),
            ),
          ],
        ),
        _buildSectionGap(theme),
        GroupProfileButtonArea(groupInfo.groupID, model),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Provider.of<DefaultThemeData>(context).theme;
    final appBarBaseColor =
        theme.appbarBgColor ?? theme.wideBackgroundColor ?? Colors.white;
    final isDarkBackground =
        ThemeData.estimateBrightnessForColor(appBarBaseColor) ==
            Brightness.dark;
    final isWideScreen = _isWideScreen(context);
    final TUISelfInfoViewModel _selfInfoViewModel =
        serviceLocator<TUISelfInfoViewModel>();
    final TUIFriendShipViewModel _friendShipViewModel =
        serviceLocator<TUIFriendShipViewModel>();
    final isDarkTheme = Provider.of<DefaultThemeData>(context, listen: false)
            .currentThemeType ==
        ThemeType.dark;
    final overlayStyle =
        buildAppSystemUiOverlayStyle(theme, isDark: isDarkTheme);
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: overlayStyle,
      child: TencentPage(
        name: 'groupProfile',
        child: AnimatedBuilder(
          animation: Listenable.merge(<Listenable>[
            PeerProfileRefreshBus.instance.revision,
            GroupLocalStore.instance.commitListenable,
          ]),
          builder: (context, _) {
            return Scaffold(
              backgroundColor:
                  isDarkBackground ? appBarBaseColor : const Color(0xFFF1F1F1),
              extendBody: true,
              appBar: AppBar(
                  systemOverlayStyle: overlayStyle,
                  title: Text(
                    AppI18n.of(context).t(
                      zhHans: '群聊',
                      zhHant: '群聊',
                      en: 'Groups',
                      ja: 'グループ',
                      ko: '그룹',
                    ),
                    style: TextStyle(
                      color: theme.appbarTextColor ?? theme.darkTextColor,
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  iconTheme: IconThemeData(
                    color: theme.primaryColor ?? const Color(0xFF1E90FF),
                  ),
                  shadowColor: theme.weakDividerColor,
                  backgroundColor: theme.appbarBgColor ?? Colors.white),
              body: SafeArea(
                top: false,
                child: TIMUIKitGroupProfile(
                  lifeCycle: GroupProfileLifeCycle(didLeaveGroup: () async {
                    await GroupLeaveNavigation.returnToMessageList(context);
                  }),
                  groupID: groupID,
                  onClickUser: (V2TimGroupMemberFullInfo memberInfo, _) {
                    final userID = memberInfo.userID.trim();
                    if (userID.isEmpty ||
                        userID == _selfInfoViewModel.loginInfo?.userID) {
                      return;
                    }
                    ProfilePageNav.openUserProfileOrAddFriend(
                      context,
                      userID: userID,
                      nickname: UserDisplayProfile.nameOfMember(memberInfo),
                      avatarUrl: UserDisplayProfile.avatarOfMember(memberInfo),
                      addSource: FriendAddSource.card,
                      groupId: groupID,
                    );
                  },
                  builder: isWideScreen
                      ? null
                      : (context, groupInfo, groupMemberList) {
                          final model =
                              Provider.of<TUIGroupProfileModel>(context);
                          return _buildMobileGroupProfile(
                            context,
                            theme,
                            groupInfo,
                            groupMemberList,
                            model,
                          );
                        },
                  profileWidgetBuilder: isWideScreen
                      ? GroupProfileWidgetBuilder(
                          detailCard: (groupInfo, updateGroupName) {
                            final local = GroupLocalStore.instance.readCached(
                              groupId: groupInfo.groupID,
                            );
                            return GroupProfileDetailCard(
                              groupInfo: groupInfo,
                              isHavePermission: _canManageGroup(groupInfo),
                              updateGroupName: updateGroupName,
                              previewFaceUrl: local?.avatarPreviewUrl,
                              previewUrlResolver: () async {
                                final result = await MeGroupApi.instance
                                    .fetchGroupAvatarPreview(groupInfo.groupID);
                                return result.previewUrl;
                              },
                              avatarCacheKey:
                                  'avatar|group|${groupInfo.groupID}|${local?.avatarVersion ?? 0}|thumb',
                              previewCacheKey:
                                  'avatar|group|${groupInfo.groupID}|${local?.avatarVersion ?? 0}|preview',
                            );
                          },
                          searchMessage: () {
                            return TIMUIKitGroupProfileWidget.searchMessage(
                                (V2TimConversation? conversation) {
                              _openSearchMessage(context, conversation);
                            });
                          },
                          groupJoiningModeBar:
                              (groupAddOptType, handleActionTap) {
                            return const GroupProfileJoinModeRow();
                          },
                          pinedConversationBar: (isPinned, onChange) {
                            return Consumer<TUIGroupProfileModel>(
                              builder: (context, model, _) {
                                return ConversationGroupProfilePinBar(
                                  groupID: groupID,
                                  conversation: model.conversation,
                                  source: 'group_profile_wide',
                                  onApplied: (pinned) {
                                    if (model.conversation != null) {
                                      model.conversation!.isPinned = pinned;
                                    }
                                  },
                                );
                              },
                            );
                          },
                        )
                      : null,
                  profileWidgetsOrder: isWideScreen
                      ? const [
                          GroupProfileWidgetEnum.detailCard,
                          GroupProfileWidgetEnum.operationDivider,
                          GroupProfileWidgetEnum.memberListTile,
                          GroupProfileWidgetEnum.operationDivider,
                          GroupProfileWidgetEnum.searchMessage,
                          GroupProfileWidgetEnum.operationDivider,
                          GroupProfileWidgetEnum.groupNotice,
                          GroupProfileWidgetEnum.groupManage,
                          GroupProfileWidgetEnum.groupJoiningModeBar,
                          GroupProfileWidgetEnum.operationDivider,
                          GroupProfileWidgetEnum.pinedConversationBar,
                          GroupProfileWidgetEnum.muteGroupMessageBar,
                          GroupProfileWidgetEnum.operationDivider,
                          GroupProfileWidgetEnum.nameCardBar,
                          GroupProfileWidgetEnum.operationDivider,
                          GroupProfileWidgetEnum.buttonArea,
                        ]
                      : null,
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
