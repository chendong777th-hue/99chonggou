// ignore_for_file: unused_element

import 'package:dotted_border/dotted_border.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tencent_chat_i18n_tool/tencent_chat_i18n_tool.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_group_member_full_info.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_group_member_full_info.dart';
import 'package:tencent_cloud_chat_uikit/base_widgets/tim_ui_kit_base.dart';
import 'package:tencent_cloud_chat_uikit/base_widgets/tim_ui_kit_statelesswidget.dart';
import 'package:tencent_cloud_chat_uikit/business_logic/separate_models/tui_group_profile_model.dart';
import 'package:tencent_cloud_chat_uikit/data_services/core/tim_uikit_wide_modal_operation_key.dart';
import 'package:tencent_cloud_chat_uikit/ui/utils/screen_utils.dart';
import 'package:tencent_cloud_chat_uikit/ui/views/TIMUIKitGroupProfile/group_member/tui_add_group_member.dart';
import 'package:tencent_cloud_chat_uikit/ui/views/TIMUIKitGroupProfile/group_member/tui_delete_group_member.dart';
import 'package:tencent_cloud_chat_uikit/ui/views/TIMUIKitGroupProfile/group_member/tui_group_member_list.dart';
import 'package:tencent_cloud_chat_uikit/ui/views/TIMUIKitSearch/conversation_search_utils.dart';
import 'package:tencent_cloud_chat_uikit/data_services/profile/user_profile_local_bridge.dart';
import 'package:tencent_cloud_chat_uikit/ui/widgets/avatar.dart';
import 'package:tencent_cloud_chat_uikit/ui/widgets/wide_popup.dart';
import 'package:tencent_cloud_chat_uikit/ui/utils/wide_popup_layout.dart';
import 'package:tencent_cloud_chat_uikit/theme/color.dart';
import 'package:tencent_cloud_chat_uikit/theme/tui_theme.dart';

class GroupMemberTitle extends TIMUIKitStatelessWidget {
  GroupMemberTitle({
    Key? key,
  }) : super(key: key);

  List<V2TimGroupMemberFullInfo?> _getMemberList(memberList, int showRange) {
    if (memberList.length > showRange) {
      return memberList.getRange(0, showRange).toList();
    } else {
      return memberList;
    }
  }

  _getShowName(V2TimGroupMemberFullInfo? item) {
    return memberDisplayName(
      friendRemark: item?.friendRemark,
      nameCard: item?.nameCard,
      nickName: item?.nickName,
      userID: item?.userID,
    );
  }

  List<Widget> _groupMemberListBuilder(List memberList, TUITheme theme, TUIGroupProfileModel model, int showRange) {
    final isDesktopScreen = TUIKitScreenUtils.getFormFactor() == DeviceType.Desktop;
    return _getMemberList(memberList, showRange).map((element) {
      final faceUrl = UserProfileLocalBridge.cachedAvatarUrl(
        element?.userID,
        fallback: element?.faceUrl,
      );
      final showName = _getShowName(element);
      return InkWell(
        onTapDown: (details) {
          if (model.onClickUser != null && element?.userID != null) {
            model.onClickUser!(element!, details);
          }
        },
        child: SizedBox(
          width: isDesktopScreen ? 36 : 60,
          height: isDesktopScreen ? 36 : 76,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              SizedBox(
                width: isDesktopScreen ? 36 : 50,
                height: isDesktopScreen ? 36 : 50,
                child: Avatar(
                  borderRadius: isDesktopScreen ? BorderRadius.circular(18) : null,
                  faceUrl: faceUrl,
                  showName: showName,
                  type: 1,
                ),
              ),
              if (!isDesktopScreen)
                const SizedBox(
                  height: 8,
                ),
              if (!isDesktopScreen)
                Text(
                  showName,
                  textAlign: TextAlign.center,
                  style: TextStyle(overflow: TextOverflow.ellipsis, color: theme.weakTextColor, fontSize: 10),
                )
            ],
          ),
        ),
      );
    }).toList();
  }

  List<Widget> _inviteMemberBuilder(bool isCanInviteMember, bool isCanKickOffMember, theme, BuildContext context) {
    return [];
  }

  void navigateToMemberList(
      BuildContext context, TUIGroupProfileModel model, List<V2TimGroupMemberFullInfo?> memberList) {
    final isDesktopScreen = TUIKitScreenUtils.getFormFactor(context) == DeviceType.Desktop;
    if (!isDesktopScreen) {
      Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => GroupProfileMemberListPage(model: model, memberList: memberList),
          ));
    } else {
      final option1 = memberList.length.toString();
      final popupSize = WidePopupLayout.medium(context);
      TUIKitWidePopup.showPopupWindow(
          operationKey: TUIKitWideModalOperationKey.groupMembersList,
          context: context,
          width: popupSize.width,
          height: popupSize.height,
          borderRadius: const BorderRadius.all(Radius.circular(16)),
          title: TIM_t_para("群成员({{option1}}人)", "群成员($option1人)")(option1: option1),
          onConfirm: () {},
          confirmText: TIM_t("关闭"),
          child: (onClose) => GroupProfileMemberListPage(model: model, memberList: memberList));
    }
  }

  @override
  Widget tuiBuild(BuildContext context, TUIKitBuildValue value) {
    final model = Provider.of<TUIGroupProfileModel>(context);
    final revision = UserProfileLocalBridge.changeListenable;
    if (revision == null) {
      return _buildBody(context, value.theme, model);
    }
    return AnimatedBuilder(
      animation: revision,
      builder: (context, _) => _buildBody(context, value.theme, model),
    );
  }

  Widget _buildBody(
    BuildContext context,
    TUITheme theme,
    TUIGroupProfileModel model,
  ) {
    final isDesktopScreen = TUIKitScreenUtils.getFormFactor(context) == DeviceType.Desktop;
    final memberAmount = model.groupInfo?.memberCount ?? 0;
    final option1 = memberAmount.toString();
    final memberList = model.groupMemberList;
    final isCanInviteMember = model.canInviteMember();
    final isCanKickOffMember = model.canKickOffMember();

    int showRange = isDesktopScreen ? 7 : 8;
    if (isDesktopScreen && isCanInviteMember) {
      showRange--;
    }
    if (isDesktopScreen && isCanKickOffMember) {
      showRange--;
    }

    final itemBackgroundColor =
        theme.conversationItemBgColor ?? theme.wideBackgroundColor ?? Colors.white;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      color: itemBackgroundColor,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.only(bottom: 12),
            decoration: isDesktopScreen
                ? null
                : BoxDecoration(
                    border: Border(bottom: BorderSide(color: theme.weakDividerColor ?? CommonColor.weakDividerColor))),
            child: InkWell(
              onTap: () async {
                navigateToMemberList(context, model, memberList);
              },
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(TIM_t("群成员"), style: TextStyle(color: theme.darkTextColor, fontSize: isDesktopScreen ? 14 : 16)),
                  Row(
                    children: [
                      Text(
                        TIM_t_para("{{option1}}人", "$option1人")(option1: option1),
                        style: TextStyle(color: theme.darkTextColor, fontSize: isDesktopScreen ? 14 : 16),
                      ),
                      Icon(
                        Icons.keyboard_arrow_right,
                        color: theme.weakTextColor,
                      ),
                    ],
                  )
                ],
              ),
            ),
          ),
          Container(
            // height: 90,
            padding: const EdgeInsets.only(top: 12),
            child: Wrap(
              spacing: isDesktopScreen ? 10 : 20,
              runSpacing: 10,
              alignment: WrapAlignment.start,
              children: [
                ..._groupMemberListBuilder(memberList, theme, model, showRange),
                if (isCanInviteMember)
                  DottedBorder(
                      borderType: BorderType.RRect,
                      radius: Radius.circular(isDesktopScreen ? 18 : 4.5),
                      color: theme.weakTextColor!,
                      dashPattern: const [6, 3],
                      child: SizedBox(
                        width: isDesktopScreen ? 32 : 48,
                        height: isDesktopScreen ? 32 : 48,
                        child: IconButton(
                          onPressed: () {
                            if (isDesktopScreen) {
                              final popupSize = WidePopupLayout.medium(context);
                              TUIKitWidePopup.showPopupWindow(
                                  context: context,
                                  operationKey: TUIKitWideModalOperationKey.addGroupMembers,
                                  width: popupSize.width,
                                  title: TIM_t("选择联系人"),
                                  height: popupSize.height,
                                  onCancel: () {},
                                  onConfirm: () {
                                    addGroupMemberKey.currentState?.submitAdd();
                                  },
                                  confirmText: TIM_t("完成"),
                                  child: (onClose) => AddGroupMemberPage(
                                        model: model,
                                        onClose: onClose,
                                        key: addGroupMemberKey,
                                      ));
                            } else {
                              Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => AddGroupMemberPage(
                                      model: model,
                                    ),
                                  ));
                            }
                          },
                          icon: Icon(
                            Icons.add,
                            size: isDesktopScreen ? 16 : 18,
                          ),
                          color: theme.weakTextColor,
                        ),
                      )),
                if (isCanKickOffMember)
                  DottedBorder(
                      borderType: BorderType.RRect,
                      radius: Radius.circular(isDesktopScreen ? 18 : 4.5),
                      color: theme.weakTextColor!,
                      dashPattern: const [6, 3],
                      child: SizedBox(
                        width: isDesktopScreen ? 32 : 48,
                        height: isDesktopScreen ? 32 : 48,
                        child: IconButton(
                          onPressed: () async {
                            if (isDesktopScreen) {
                              final deleteKey =
                                  GlobalKey<DeleteGroupMemberPageState>();
                              TUIKitWidePopup.showPopupWindow(
                                operationKey: TUIKitWideModalOperationKey
                                    .kickOffGroupMembers,
                                context: context,
                                width: WidePopupLayout.medium(context).width,
                                title: TIM_t("删除群成员"),
                                height: WidePopupLayout.medium(context).height,
                                onCancel: () {},
                                onConfirm: () async {
                                  await deleteKey.currentState?.submitDelete();
                                },
                                confirmText: TIM_t("完成"),
                                child: (onClose) => DeleteGroupMemberPage(
                                  model: model,
                                  onClose: onClose,
                                  key: deleteKey,
                                ),
                              );
                            } else {
                              await Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) =>
                                        DeleteGroupMemberPage(model: model),
                                  ));
                            }
                          },
                          icon: Icon(
                            Icons.remove,
                            size: isDesktopScreen ? 16 : 18,
                          ),
                          color: theme.weakTextColor,
                        ),
                      )),
              ],
            ),
          ),
          if (memberList.length > showRange)
            InkWell(
              child: Container(
                alignment: Alignment.center,
                margin: EdgeInsets.only(top: isDesktopScreen ? 12 : 16),
                child: Text(
                  TIM_t("查看更多群成员"),
                  style: TextStyle(color: theme.weakTextColor, fontSize: isDesktopScreen ? 12 : 14),
                ),
              ),
              onTap: () async {
                navigateToMemberList(context, model, memberList);
              },
            ),
        ],
      ),
    );
  }
}
