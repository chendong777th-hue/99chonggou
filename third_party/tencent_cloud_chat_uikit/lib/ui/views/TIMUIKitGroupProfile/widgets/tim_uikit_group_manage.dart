import 'dart:async';
import 'dart:math';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:tencent_chat_i18n_tool/language_json/strings.g.dart';
import 'package:tencent_chat_i18n_tool/tencent_chat_i18n_tool.dart';
import 'package:tencent_cloud_chat_demo/src/api/me_group_api.dart';
import 'package:tencent_cloud_chat_demo/src/constants/group_governance_limits.dart';
import 'package:tencent_cloud_chat_demo/utils/group_admin_role_message.dart';
import 'package:tencent_cloud_chat_sdk/enum/group_member_role.dart';
import 'package:tencent_cloud_chat_sdk/enum/group_type.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_group_member_full_info.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_group_member_full_info.dart';
import 'package:tencent_cloud_chat_sdk/tencent_im_sdk_plugin.dart';
import 'package:tencent_cloud_chat_uikit/base_widgets/tim_ui_kit_base.dart';
import 'package:tencent_cloud_chat_uikit/base_widgets/tim_ui_kit_state.dart';
import 'package:tencent_cloud_chat_uikit/business_logic/separate_models/tui_group_profile_model.dart';
import 'package:tencent_cloud_chat_uikit/business_logic/view_models/tui_chat_global_model.dart';
import 'package:tencent_cloud_chat_uikit/data_services/core/tim_uikit_wide_modal_operation_key.dart';
import 'package:tencent_cloud_chat_uikit/data_services/core/core_services_implements.dart';
import 'package:tencent_cloud_chat_uikit/data_services/group/group_member_feedback_bridge.dart';
import 'package:tencent_cloud_chat_uikit/data_services/services_locatar.dart';
import 'package:tencent_cloud_chat_uikit/ui/utils/group_role_policy.dart';
import 'package:tencent_cloud_chat_uikit/ui/utils/screen_utils.dart';
import 'package:tencent_cloud_chat_uikit/ui/views/TIMUIKitProfile/widget/tim_uikit_operation_item.dart';
import 'package:tencent_cloud_chat_uikit/ui/widgets/avatar.dart';
import 'package:tencent_cloud_chat_uikit/ui/widgets/column_menu.dart';
import 'package:tencent_cloud_chat_uikit/ui/views/TIMUIKitGroupProfile/widgets/tim_ui_group_member_search.dart';
import 'package:tencent_cloud_chat_uikit/ui/views/TIMUIKitSearch/conversation_search_utils.dart';
import 'package:tencent_cloud_chat_uikit/ui/widgets/group_member_list.dart';
import 'package:tencent_cloud_chat_uikit/ui/widgets/wide_popup.dart';
import 'package:tencent_cloud_chat_uikit/ui/utils/wide_popup_layout.dart';
import 'package:tencent_cloud_chat_uikit/base_widgets/tim_callback.dart';
import 'package:tencent_cloud_chat_uikit/theme/color.dart';
import 'package:tencent_cloud_chat_uikit/theme/tui_theme.dart';
import 'package:tencent_cloud_chat_uikit/theme/tui_theme_view_model.dart';

Color _groupManageSurfaceColor(TUITheme theme) {
  return theme.conversationItemBgColor ??
      theme.wideBackgroundColor ??
      Colors.white;
}

Color _groupManagePageBackground(TUITheme theme) {
  return theme.chatBgColor ??
      theme.weakBackgroundColor ??
      theme.wideBackgroundColor ??
      Colors.white;
}

/// 群管理危险操作确认：缩放淡入动画 + 震动，降低误触。
Future<bool> _confirmGroupManageAction(
  BuildContext context, {
  required String title,
  required String message,
  String confirmText = '确定',
  bool destructive = true,
}) async {
  if (!context.mounted) {
    return false;
  }
  HapticFeedback.mediumImpact();
  final result = await showGeneralDialog<bool>(
    context: context,
    barrierDismissible: false,
    barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
    barrierColor: Colors.black.withValues(alpha: 0.45),
    transitionDuration: const Duration(milliseconds: 240),
    pageBuilder: (dialogContext, animation, secondaryAnimation) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 40),
          child: CupertinoAlertDialog(
            title: Text(title),
            content: Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(message),
            ),
            actions: [
              CupertinoDialogAction(
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: Text(TIM_t('取消')),
              ),
              CupertinoDialogAction(
                isDestructiveAction: destructive,
                onPressed: () => Navigator.of(dialogContext).pop(true),
                child: Text(confirmText),
              ),
            ],
          ),
        ),
      );
    },
    transitionBuilder: (context, animation, secondaryAnimation, child) {
      final curve = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutCubic,
        reverseCurve: Curves.easeInCubic,
      );
      return FadeTransition(
        opacity: curve,
        child: ScaleTransition(
          scale: Tween<double>(begin: 0.92, end: 1).animate(curve),
          child: child,
        ),
      );
    },
  );
  return result == true;
}

Future<bool> _confirmEnableMuteAll(BuildContext context) {
  return _confirmGroupManageAction(
    context,
    title: TIM_t('开启全员禁言'),
    message: TIM_t('开启后，普通成员将无法在群内发言。确定开启吗？'),
    confirmText: TIM_t('开启'),
    destructive: true,
  );
}

Future<bool> _confirmDisableMuteAll(BuildContext context) {
  return _confirmGroupManageAction(
    context,
    title: TIM_t('关闭全员禁言'),
    message: TIM_t('关闭后，普通成员可恢复发言。确定关闭吗？'),
    confirmText: TIM_t('关闭'),
    destructive: true,
  );
}

Future<bool> _confirmRemoveAdmin(BuildContext context, String displayName) {
  final name = displayName.trim().isEmpty ? TIM_t('该成员') : displayName.trim();
  return _confirmGroupManageAction(
    context,
    title: TIM_t('取消管理员'),
    message: TIM_t_para(
      '确定取消「{{option1}}」的管理员身份吗？',
      '确定取消「$name」的管理员身份吗？',
    )(option1: name),
    confirmText: TIM_t('取消管理员'),
    destructive: true,
  );
}

GlobalKey<_GroupProfileAddAdminState> groupProfileAddAdminKey = GlobalKey();

class GroupProfileGroupManage extends StatefulWidget {
  const GroupProfileGroupManage({Key? key}) : super(key: key);

  @override
  State<StatefulWidget> createState() => GroupProfileGroupManageState();
}

class GroupProfileGroupManageState
    extends TIMUIKitState<GroupProfileGroupManage> {
  bool isShowManageBox = false;

  @override
  Widget tuiBuild(BuildContext context, TUIKitBuildValue value) {
    final tr = Translations.of(context);
    final TUITheme theme = value.theme;
    final isDesktopScreen =
        TUIKitScreenUtils.getFormFactor(context) == DeviceType.Desktop;
    final model = Provider.of<TUIGroupProfileModel>(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
          color: _groupManageSurfaceColor(theme),
          border: isDesktopScreen
              ? null
              : Border(
                  bottom: BorderSide(
                      color: theme.weakDividerColor ??
                          CommonColor.weakDividerColor))),
      child: Column(
        children: [
          InkWell(
            onTap: () {
              final isDesktopScreen =
                  TUIKitScreenUtils.getFormFactor(context) ==
                      DeviceType.Desktop;
              if (!isDesktopScreen) {
                Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) => GroupProfileGroupManagePage(
                              model: model,
                            )));
              } else {
                setState(() {
                  isShowManageBox = !isShowManageBox;
                });
              }
            },
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  tr.k_038lh6u,
                  style: TextStyle(
                      fontSize: isDesktopScreen ? 14 : 16,
                      color: theme.darkTextColor),
                ),
                AnimatedRotation(
                  turns: isShowManageBox ? 0.25 : 0,
                  duration: const Duration(milliseconds: 200),
                  child: Icon(Icons.keyboard_arrow_right,
                      color: theme.weakTextColor),
                )
              ],
            ),
          ),
          if (isShowManageBox)
            GroupProfileGroupManagePage(
              model: model,
            )
        ],
      ),
    );
  }
}

/// 管理员设置页面
class GroupProfileGroupManagePage extends StatefulWidget {
  final TUIGroupProfileModel model;

  /// 插在群管理项上方的自定义区块（如加群方式、群隐私保护）。
  final List<Widget>? headerWidgets;

  /// 移动端 AppBar 标题，默认「群管理」。
  final String? appBarTitle;

  final MemberPresenceLabelBuilder? presenceLabelBuilder;
  final MemberPresenceLoadingChecker? presenceLoadingChecker;
  final MemberPresenceOnlineResolver? presenceOnlineResolver;
  final Listenable? presenceListenable;
  final void Function(List<String> userIds)? onMemberPresenceRequested;

  const GroupProfileGroupManagePage({
    Key? key,
    required this.model,
    this.headerWidgets,
    this.appBarTitle,
    this.presenceLabelBuilder,
    this.presenceLoadingChecker,
    this.presenceOnlineResolver,
    this.presenceListenable,
    this.onMemberPresenceRequested,
  }) : super(key: key);

  @override
  State<StatefulWidget> createState() => _GroupProfileGroupManagePageState();
}

class _GroupProfileGroupManagePageState
    extends TIMUIKitState<GroupProfileGroupManagePage> {
  int? serverTime;
  List<V2TimGroupMemberFullInfo> _mutedMembers = const [];

  @override
  void initState() {
    super.initState();
    unawaited(_bootstrapManagePage());
  }

  Future<void> _bootstrapManagePage() async {
    await _refreshServerTime();
    final groupId = widget.model.groupID.trim();
    if (groupId.isEmpty) {
      return;
    }
    await widget.model.loadGroupInfo(groupId);
    await widget.model.reloadGroupMembers(groupId);
    _seedMutedMembersFromModel();
    await _refreshMutedMembers(keepExistingOnEmpty: true);
    await _refreshServerTime();
  }

  Future<void> _refreshServerTime() async {
    final res = await TencentImSDKPlugin.v2TIMManager.getServerTime();
    if (!mounted) {
      return;
    }
    setState(() {
      serverTime = res.data;
    });
  }

  int get _currentCompareTime =>
      serverTime ?? DateTime.now().millisecondsSinceEpoch ~/ 1000;

  void _seedMutedMembersFromModel() {
    final localMuted = widget.model.groupMemberList
        .whereType<V2TimGroupMemberFullInfo>()
        .where((member) => (member.muteUntil ?? 0) > _currentCompareTime)
        .toList(growable: false);
    if (localMuted.isEmpty) {
      return;
    }
    setState(() {
      _mutedMembers = _mergeMutedMembers(_mutedMembers, localMuted);
    });
  }

  List<V2TimGroupMemberFullInfo> _mergeMutedMembers(
    List<V2TimGroupMemberFullInfo> base,
    List<V2TimGroupMemberFullInfo> incoming,
  ) {
    final map = <String, V2TimGroupMemberFullInfo>{
      for (final member in base)
        if (member.userID.trim().isNotEmpty) member.userID.trim(): member,
    };
    for (final member in incoming) {
      final id = member.userID.trim();
      if (id.isNotEmpty) {
        map[id] = member;
      }
    }
    return map.values.toList(growable: false);
  }

  void _upsertMutedMembersFromSelection(
    List<V2TimGroupMemberFullInfo?> selectedMember,
  ) {
    final now = _currentCompareTime;
    final next =
        selectedMember.whereType<V2TimGroupMemberFullInfo>().map((member) {
      if ((member.muteUntil ?? 0) <= now) {
        member.muteUntil = now + 315360000;
      }
      return member;
    }).toList(growable: false);
    if (next.isEmpty) {
      return;
    }
    setState(() {
      _mutedMembers = _mergeMutedMembers(_mutedMembers, next);
    });
  }

  void _removeMutedMemberLocally(String userId) {
    final id = userId.trim();
    if (id.isEmpty) {
      return;
    }
    setState(() {
      _mutedMembers =
          _mutedMembers.where((member) => member.userID.trim() != id).toList();
    });
  }

  Future<void> _refreshMutedMembers({bool keepExistingOnEmpty = false}) async {
    final groupId = widget.model.groupID.trim();
    if (groupId.isEmpty) {
      return;
    }
    final res = await MeGroupApi.instance.fetchMutedMembers(groupId);
    if (!mounted || res == null) {
      return;
    }
    setState(() {
      widget.model.groupInfo?.isAllMuted = res.isAllMuted;
      final next =
          res.members.map(_mutedRecordToMemberInfo).toList(growable: false);
      if (next.isEmpty && keepExistingOnEmpty && _mutedMembers.isNotEmpty) {
        return;
      }
      _mutedMembers = next;
    });
  }

  V2TimGroupMemberFullInfo _mutedRecordToMemberInfo(
    MutedGroupMemberRecord record,
  ) {
    V2TimGroupMemberFullInfo? localMember;
    for (final member in widget.model.groupMemberList) {
      if (member?.userID.trim() == record.userId) {
        localMember = member;
        break;
      }
    }
    return V2TimGroupMemberFullInfo(
      userID: record.userId,
      muteUntil: record.muteUntilSec,
      nameCard:
          record.nameCard.isNotEmpty ? record.nameCard : localMember?.nameCard,
      nickName: localMember?.nickName,
      friendRemark: localMember?.friendRemark,
      faceUrl: localMember?.faceUrl,
      role: _roleFromApi(record.imRole, fallback: localMember?.role),
    );
  }

  int _roleFromApi(String role, {int? fallback}) {
    switch (role.trim().toLowerCase()) {
      case 'owner':
        return GroupMemberRoleType.V2TIM_GROUP_MEMBER_ROLE_OWNER;
      case 'admin':
        return GroupMemberRoleType.V2TIM_GROUP_MEMBER_ROLE_ADMIN;
      case 'member':
        return GroupMemberRoleType.V2TIM_GROUP_MEMBER_ROLE_MEMBER;
      default:
        return fallback ?? GroupMemberRoleType.V2TIM_GROUP_MEMBER_ROLE_MEMBER;
    }
  }

  @override
  Widget tuiBuild(BuildContext context, TUIKitBuildValue value) {
    return MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: widget.model),
          ChangeNotifierProvider.value(
              value: serviceLocator<TUIThemeViewModel>())
        ],
        builder: (context, w) {
          final tr = Translations.of(context);
          final memberList =
              Provider.of<TUIGroupProfileModel>(context).groupMemberList;
          final theme = Provider.of<TUIThemeViewModel>(context).theme;
          final isAllMuted = widget.model.groupInfo?.isAllMuted ?? false;
          final groupType = widget.model.groupInfo?.groupType ?? '';
          final bool isAllowSetManager = groupType != GroupType.Work;
          final bool isAllowMuteMember = groupType != GroupType.Work;
          final isDesktopScreen =
              TUIKitScreenUtils.getFormFactor(context) == DeviceType.Desktop;
          final mutedUserIds = _mutedMembers
              .map((member) => member.userID.trim())
              .where((id) => id.isNotEmpty)
              .toSet();

          Widget managePage() {
            return Column(
              children: [
                if (widget.headerWidgets != null &&
                    widget.headerWidgets!.isNotEmpty) ...[
                  ...widget.headerWidgets!,
                  if (!isDesktopScreen)
                    Container(
                      height: 8,
                      color: _groupManagePageBackground(theme),
                    ),
                ],
                if (isAllowSetManager) ...[
                  Container(
                    padding: EdgeInsets.only(
                        top: 12,
                        left: isDesktopScreen ? 0 : 16,
                        bottom: isDesktopScreen ? 0 : 12,
                        right: isDesktopScreen ? 0 : 12),
                    decoration: BoxDecoration(
                        color: _groupManageSurfaceColor(theme),
                        border: isDesktopScreen
                            ? null
                            : Border(
                                bottom: BorderSide(
                                    color: theme.weakDividerColor ??
                                        CommonColor.weakDividerColor))),
                    child: InkWell(
                      onTap: isDesktopScreen
                          ? null
                          : () {
                              Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) =>
                                        GroupProfileSetManagerPage(
                                      model: widget.model,
                                      presenceLabelBuilder:
                                          widget.presenceLabelBuilder,
                                      presenceLoadingChecker:
                                          widget.presenceLoadingChecker,
                                      presenceOnlineResolver:
                                          widget.presenceOnlineResolver,
                                      presenceListenable:
                                          widget.presenceListenable,
                                      onMemberPresenceRequested:
                                          widget.onMemberPresenceRequested,
                                    ),
                                  ));
                            },
                      child: isDesktopScreen
                          ? Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(tr.k_15i9w72,
                                    style: TextStyle(
                                        fontSize: 14,
                                        color: theme.darkTextColor)),
                              ],
                            )
                          : Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(tr.k_0k5wyiy,
                                    style: TextStyle(
                                        fontSize: isDesktopScreen ? 14 : 16,
                                        color: theme.darkTextColor)),
                                Icon(Icons.keyboard_arrow_right,
                                    color: theme.weakTextColor)
                              ],
                            ),
                    ),
                  ),
                  if (isDesktopScreen)
                    GroupProfileSetManagerPage(
                      model: widget.model,
                      presenceLabelBuilder: widget.presenceLabelBuilder,
                      presenceLoadingChecker: widget.presenceLoadingChecker,
                      presenceOnlineResolver: widget.presenceOnlineResolver,
                      presenceListenable: widget.presenceListenable,
                      onMemberPresenceRequested:
                          widget.onMemberPresenceRequested,
                    ),
                ],
                if (!isDesktopScreen)
                  Container(
                    padding: const EdgeInsets.only(
                        top: 12, left: 16, bottom: 12, right: 12),
                    decoration: BoxDecoration(
                        color: _groupManageSurfaceColor(theme),
                        border: Border(
                            bottom: BorderSide(
                                color: theme.weakDividerColor ??
                                    CommonColor.weakDividerColor))),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          TIM_t("全员禁言"),
                          style: TextStyle(
                              fontSize: 16, color: theme.darkTextColor),
                        ),
                        CupertinoSwitch(
                            value: isAllMuted,
                            onChanged: (value) async {
                              if (value) {
                                final confirmed =
                                    await _confirmEnableMuteAll(context);
                                if (!confirmed) {
                                  return;
                                }
                              } else {
                                final confirmed =
                                    await _confirmDisableMuteAll(context);
                                if (!confirmed) {
                                  return;
                                }
                              }
                              await widget.model.setMuteAll(value);
                            },
                            activeColor: theme.primaryColor)
                      ],
                    ),
                  ),
                if (isDesktopScreen && isAllowMuteMember)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(tr.k_002wddw,
                          style: TextStyle(
                              fontSize: 14, color: theme.darkTextColor)),
                    ],
                  ),
                if (isDesktopScreen)
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: TIMUIKitOperationItem(
                      isEmpty: false,
                      operationName: tr.k_0goiuwk,
                      type: "switch",
                      isUseCheckedBoxOnWide: true,
                      operationDescription: tr.k_1g889xx,
                      operationValue: isAllMuted,
                      onSwitchChange: (value) async {
                        if (value) {
                          final confirmed = await _confirmEnableMuteAll(context);
                          if (!confirmed) {
                            return;
                          }
                        } else {
                          final confirmed =
                              await _confirmDisableMuteAll(context);
                          if (!confirmed) {
                            return;
                          }
                        }
                        await widget.model.setMuteAll(value);
                      },
                    ),
                  ),
                if (!isDesktopScreen)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        vertical: 10, horizontal: 16),
                    color: theme.weakBackgroundColor ??
                        theme.conversationItemPinedBgColor,
                    alignment: Alignment.topLeft,
                    child: Text(
                      tr.k_1g889xx,
                      style:
                          TextStyle(fontSize: 12, color: theme.weakTextColor),
                    ),
                  ),
                if (!isAllMuted && isAllowMuteMember)
                  InkWell(
                    child: Container(
                        color: _groupManageSurfaceColor(theme),
                        padding: const EdgeInsets.only(left: 16),
                        child: Container(
                          padding: !isDesktopScreen
                              ? const EdgeInsets.symmetric(
                                  vertical: 12,
                                )
                              : const EdgeInsets.only(
                                  bottom: 4,
                                ),
                          decoration: isDesktopScreen
                              ? null
                              : BoxDecoration(
                                  color: _groupManageSurfaceColor(theme),
                                  border: Border(
                                      bottom: BorderSide(
                                          color: theme.weakDividerColor ??
                                              CommonColor.weakDividerColor))),
                          child: Row(
                            children: [
                              Icon(
                                Icons.add_circle_outline,
                                color: theme.primaryColor,
                                size: 20,
                              ),
                              const SizedBox(
                                width: 12,
                              ),
                              Text(
                                tr.k_0wlrefq,
                                style: TextStyle(
                                  fontSize: isDesktopScreen ? 14 : 16,
                                  color: theme.darkTextColor,
                                ),
                              )
                            ],
                          ),
                        )),
                    onTap: () async {
                      Widget muteMember() {
                        return GroupProfileAddAdmin(
                          key: groupProfileAddAdminKey,
                          appbarTitle: tr.k_0goox5g,
                          presenceLabelBuilder: widget.presenceLabelBuilder,
                          presenceLoadingChecker: widget.presenceLoadingChecker,
                          presenceOnlineResolver: widget.presenceOnlineResolver,
                          presenceListenable: widget.presenceListenable,
                          onMemberPresenceRequested:
                              widget.onMemberPresenceRequested,
                          memberList: memberList.where((element) {
                            final userId = element?.userID.trim() ?? '';
                            final isMute = mutedUserIds.contains(userId);
                            return !isMute &&
                                GroupRolePolicy.canMuteTargetMember(
                                  selfRole: widget.model.groupInfo?.role,
                                  targetRole: element?.role,
                                  groupType: groupType,
                                  isAllMuted: isAllMuted,
                                );
                          }).toList(),
                          selectCompletedHandler:
                              (context, selectedMember) async {
                            if (selectedMember.isNotEmpty) {
                              for (final member in selectedMember) {
                                final userID = member!.userID;
                                await widget.model
                                    .muteGroupMember(userID, true, serverTime);
                              }
                              _upsertMutedMembersFromSelection(selectedMember);
                              await _refreshServerTime();
                              await _refreshMutedMembers(
                                  keepExistingOnEmpty: true);
                              GroupMemberFeedbackBridge.show(TIM_t('设置禁言成功'));
                            }
                          },
                        );
                      }

                      if (isDesktopScreen) {
                        final popupSize = WidePopupLayout.large(context);
                        TUIKitWidePopup.showPopupWindow(
                            operationKey: TUIKitWideModalOperationKey.setMute,
                            context: context,
                            title: TIM_t("设置禁言"),
                            width: popupSize.width,
                            height: popupSize.height,
                            onCancel: () {},
                            onConfirm: () async {
                              final success = await groupProfileAddAdminKey
                                  .currentState
                                  ?.onSubmit();
                              if (success == true) {
                                await _refreshServerTime();
                                await _refreshMutedMembers(
                                    keepExistingOnEmpty: true);
                              }
                            },
                            confirmText: TIM_t("完成"),
                            child: (onClose) => muteMember());
                      } else {
                        await Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (context) => muteMember()));
                        await _refreshMutedMembers(keepExistingOnEmpty: true);
                      }
                    },
                  ),
                if (!isAllMuted && isAllowMuteMember)
                  ..._mutedMembers
                      .map((e) => Container(
                            padding: isDesktopScreen
                                ? const EdgeInsets.only(left: 16)
                                : null,
                            child: GestureDetector(
                              onSecondaryTapDown: (details) {
                                TUIKitWidePopup.showPopupWindow(
                                    operationKey:
                                        TUIKitWideModalOperationKey.setUnmute,
                                    isDarkBackground: false,
                                    borderRadius: const BorderRadius.all(
                                        Radius.circular(4)),
                                    context: context,
                                    offset: Offset(
                                        min(
                                            details.globalPosition.dx,
                                            MediaQuery.of(context).size.width -
                                                80),
                                        details.globalPosition.dy),
                                    child: (onClose) => TUIKitColumnMenu(data: [
                                          ColumnMenuItem(
                                              label: TIM_t("解除禁言"),
                                              icon: const Icon(
                                                  Icons.remove_circle_outline,
                                                  size: 16),
                                              onClick: () async {
                                                await widget.model
                                                    .muteGroupMember(e.userID,
                                                        false, serverTime);
                                                _removeMutedMemberLocally(
                                                    e.userID);
                                                await _refreshMutedMembers();
                                                onClose();
                                              }),
                                        ]));
                              },
                              child: _buildListItem(
                                context,
                                e,
                                removeText: TIM_t("解除禁言"),
                                onRemove: () async {
                                  await widget.model.muteGroupMember(
                                    e.userID,
                                    false,
                                    serverTime,
                                  );
                                  _removeMutedMemberLocally(e.userID);
                                  await _refreshMutedMembers();
                                },
                              ),
                            ),
                          ))
                      .toList()
              ],
            );
          }

          return TUIKitScreenUtils.getDeviceWidget(
              context: context,
              desktopWidget: managePage(),
              defaultWidget: Scaffold(
                backgroundColor: _groupManagePageBackground(theme),
                appBar: AppBar(
                  title: Text(
                    widget.appBarTitle ?? tr.k_038lh6u,
                    style: TextStyle(
                      color: theme.chatHeaderTitleTextColor ??
                          theme.appbarTextColor,
                      fontSize: 17,
                    ),
                  ),
                  backgroundColor:
                      theme.chatHeaderBgColor ?? theme.appbarBgColor,
                  surfaceTintColor: Colors.transparent,
                  elevation: 0,
                  scrolledUnderElevation: 0,
                  shadowColor: theme.weakDividerColor,
                  iconTheme: IconThemeData(
                    color: theme.primaryColor ?? const Color(0xFF1E90FF),
                  ),
                  leading: IconButton(
                    padding: const EdgeInsets.only(left: 16),
                    constraints: const BoxConstraints(),
                    icon: Image.asset(
                      'images/arrow_back.png',
                      package: 'tencent_cloud_chat_uikit',
                      height: 34,
                      width: 34,
                      color: theme.primaryColor ?? const Color(0xFF1E90FF),
                    ),
                    onPressed: () {
                      Navigator.pop(context);
                    },
                  ),
                ),
                body: SingleChildScrollView(
                  child: managePage(),
                ),
              ));
        });
  }
}

_getShowName(V2TimGroupMemberFullInfo? item) {
  final friendRemark = item?.friendRemark ?? "";
  final nameCard = item?.nameCard ?? "";
  final nickName = item?.nickName ?? "";
  final userID = item?.userID ?? "";
  return friendRemark.isNotEmpty
      ? friendRemark
      : nameCard.isNotEmpty
          ? nameCard
          : nickName.isNotEmpty
              ? nickName
              : userID;
}

Widget _buildListItem(
  BuildContext context,
  V2TimGroupMemberFullInfo memberInfo, {
  VoidCallback? onRemove,
  String? removeText,
}) {
  final theme = Provider.of<TUIThemeViewModel>(context).theme;
  final isDesktopScreen =
      TUIKitScreenUtils.getFormFactor(context) == DeviceType.Desktop;
  final removeColor = theme.cautionColor ?? CommonColor.cautionColor;

  return Container(
    color: _groupManageSurfaceColor(theme),
    child: Column(children: [
      ListTile(
        tileColor: _groupManageSurfaceColor(theme),
        contentPadding: EdgeInsets.symmetric(
          horizontal: isDesktopScreen ? 0 : 16,
          vertical: isDesktopScreen ? 0 : 4,
        ),
        leading: SizedBox(
          width: isDesktopScreen ? 30 : 36,
          height: isDesktopScreen ? 30 : 36,
          child: Avatar(
            faceUrl: memberInfo.faceUrl ?? "",
            showName: _getShowName(memberInfo),
            type: 2,
          ),
        ),
        title: Text(
          _getShowName(memberInfo),
          style: TextStyle(
            fontSize: isDesktopScreen ? 14 : 16,
            color: theme.darkTextColor,
          ),
        ),
        trailing: onRemove == null
            ? null
            : TextButton(
                onPressed: onRemove,
                style: TextButton.styleFrom(
                  foregroundColor: removeColor,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: Text(
                  removeText ?? TIM_t("删除"),
                  style: TextStyle(fontSize: isDesktopScreen ? 13 : 14),
                ),
              ),
        onTap: () {},
      ),
      if (!isDesktopScreen)
        Divider(
            thickness: 1,
            indent: 74,
            endIndent: onRemove == null ? 0 : 16,
            color: theme.weakDividerColor,
            height: 0)
    ]),
  );
}

/// 选择管理员
class GroupProfileSetManagerPage extends StatefulWidget {
  final TUIGroupProfileModel model;
  final MemberPresenceLabelBuilder? presenceLabelBuilder;
  final MemberPresenceLoadingChecker? presenceLoadingChecker;
  final MemberPresenceOnlineResolver? presenceOnlineResolver;
  final Listenable? presenceListenable;
  final void Function(List<String> userIds)? onMemberPresenceRequested;

  const GroupProfileSetManagerPage({
    Key? key,
    required this.model,
    this.presenceLabelBuilder,
    this.presenceLoadingChecker,
    this.presenceOnlineResolver,
    this.presenceListenable,
    this.onMemberPresenceRequested,
  }) : super(key: key);

  @override
  State<StatefulWidget> createState() => _GroupProfileSetManagerPageState();
}

class _GroupProfileSetManagerPageState
    extends TIMUIKitState<GroupProfileSetManagerPage> {
  final TUIChatGlobalModel _chatGlobalModel =
      serviceLocator<TUIChatGlobalModel>();
  final CoreServicesImpl _coreServices = serviceLocator<CoreServicesImpl>();

  List<V2TimGroupMemberFullInfo?> _getAdminMemberList(
      List<V2TimGroupMemberFullInfo?> memberList) {
    return memberList
        .where((member) =>
            member?.role == GroupMemberRoleType.V2TIM_GROUP_MEMBER_ROLE_ADMIN)
        .toList();
  }

  List<V2TimGroupMemberFullInfo?> _getOwnerList(
      List<V2TimGroupMemberFullInfo?> memberList) {
    return memberList
        .where((member) =>
            member?.role == GroupMemberRoleType.V2TIM_GROUP_MEMBER_ROLE_OWNER)
        .toList();
  }

  void _appendAdminNotice({
    required V2TimGroupMemberFullInfo memberFullInfo,
    required bool isGrant,
  }) {
    _chatGlobalModel.addGroupSystemNotice(
      GroupSystemNoticeItem(
        id: "${isGrant ? "grant" : "revoke"}|${widget.model.groupID}|${_coreServices.loginInfo.userID}|${memberFullInfo.userID}|${DateTime.now().millisecondsSinceEpoch}",
        groupID: widget.model.groupID,
        groupName: widget.model.groupInfo?.groupName ?? widget.model.groupID,
        groupFaceUrl: widget.model.groupInfo?.faceUrl ?? "",
        type: isGrant
            ? GroupSystemNoticeType.grantAdministrator
            : GroupSystemNoticeType.revokeAdministrator,
        operatorUserID: _coreServices.loginInfo.userID,
        operatorName: _coreServices.loginInfo.loginUser?.nickName ??
            _coreServices.loginInfo.userID,
        targetUserID: memberFullInfo.userID,
        targetName: memberFullInfo.nickName ??
            memberFullInfo.nameCard ??
            memberFullInfo.userID,
        timestamp: DateTime.now().millisecondsSinceEpoch,
      ),
    );
  }

  Future<void> _grantAdministrators(
    List<V2TimGroupMemberFullInfo?> selectedMember,
  ) async {
    if (selectedMember.isEmpty) {
      GroupMemberFeedbackBridge.show(TIM_t('请选择成员'));
      return;
    }
    final currentAdminCount =
        _getAdminMemberList(widget.model.groupMemberList).length;
    final slotsLeft =
        GroupGovernanceLimits.maxAdminCount - currentAdminCount;
    if (slotsLeft <= 0) {
      GroupMemberFeedbackBridge.show(GroupAdminRoleMessage.adminLimitReached());
      return;
    }
    if (selectedMember.length > slotsLeft) {
      GroupMemberFeedbackBridge.show(GroupAdminRoleMessage.adminLimitReached());
      return;
    }
    final userIDs = selectedMember
        .map((member) => member?.userID?.trim() ?? '')
        .where((userID) => userID.isNotEmpty)
        .toList(growable: false);
    if (userIDs.isEmpty) {
      GroupMemberFeedbackBridge.show(TIM_t('请选择成员'));
      return;
    }
    final res = await widget.model.setMembersToAdmin(userIDs);
    if (res.code == 0) {
      for (final member in selectedMember) {
        if (member == null || (member.userID?.trim().isEmpty ?? true)) {
          continue;
        }
        _appendAdminNotice(memberFullInfo: member, isGrant: true);
      }
      await widget.model.reloadGroupMembers(widget.model.groupID);
      GroupMemberFeedbackBridge.show(TIM_t('设置管理员成功'));
      return;
    }
    GroupMemberFeedbackBridge.show(
      res.desc?.trim().isNotEmpty == true
          ? GroupAdminRoleMessage.normalizeFeedback(res.desc!.trim())
          : TIM_t('设置管理员失败'),
    );
  }

  List<V2TimGroupMemberFullInfo?> _memberCandidatesForAdmin(
    List<V2TimGroupMemberFullInfo?> memberList,
  ) {
    return memberList
        .where(
          (element) =>
              element?.role ==
              GroupMemberRoleType.V2TIM_GROUP_MEMBER_ROLE_MEMBER,
        )
        .toList();
  }

  _removeAdmin(
      BuildContext context, V2TimGroupMemberFullInfo memberFullInfo) async {
    final displayName = _getShowName(memberFullInfo);
    final confirmed = await _confirmRemoveAdmin(context, displayName);
    if (!confirmed) {
      return;
    }
    final res = await widget.model.setMemberToNormal(memberFullInfo.userID);
    if (res.code == 0) {
      _appendAdminNotice(memberFullInfo: memberFullInfo, isGrant: false);
      onTIMCallback(TIMCallback(
          type: TIMCallbackType.INFO,
          infoRecommendText: TIM_t("成功取消管理员身份"),
          infoCode: 6661003));
      return;
    }
    GroupMemberFeedbackBridge.show(
      res.desc?.trim().isNotEmpty == true ? res.desc!.trim() : TIM_t('设置管理员失败'),
    );
  }

  @override
  Widget tuiBuild(BuildContext context, TUIKitBuildValue value) {
    final TUITheme theme = value.theme;
    if (widget.model.groupInfo?.groupType == GroupType.Work) {
      return const SizedBox.shrink();
    }

    return MultiProvider(
      providers: [ChangeNotifierProvider.value(value: widget.model)],
      builder: (context, w) {
        final model = Provider.of<TUIGroupProfileModel>(context);
        final memberList = model.groupMemberList;
        final adminList = _getAdminMemberList(memberList);
        final ownerList = _getOwnerList(memberList);
        final String option2 = adminList.length.toString();
        final String adminLimit = GroupGovernanceLimits.maxAdminCount.toString();
        final remainingAdminSlots =
            GroupGovernanceLimits.maxAdminCount - adminList.length;
        final isDesktopScreen =
            TUIKitScreenUtils.getFormFactor(context) == DeviceType.Desktop;

        Widget adminPage() {
          return SingleChildScrollView(
              child: Column(
            children: [
              if (!isDesktopScreen)
                Container(
                  alignment: Alignment.topLeft,
                  color: theme.weakDividerColor,
                  padding:
                      const EdgeInsets.symmetric(vertical: 6, horizontal: 16),
                  child: Text(
                    TIM_t("群主"),
                    style: TextStyle(fontSize: 14, color: theme.weakTextColor),
                  ),
                ),
              if (isDesktopScreen)
                Container(
                  alignment: Alignment.topLeft,
                  padding: const EdgeInsets.only(top: 10, bottom: 4, left: 16),
                  child: Text(
                    TIM_t("群主"),
                    style: TextStyle(fontSize: 14, color: theme.primaryColor),
                  ),
                ),
              ...ownerList
                  .map(
                    (e) => Container(
                      padding: isDesktopScreen
                          ? const EdgeInsets.only(left: 16)
                          : null,
                      child: _buildListItem(context, e!),
                    ),
                  )
                  .toList(),
              if (!isDesktopScreen)
                Container(
                  alignment: Alignment.topLeft,
                  color: theme.weakDividerColor,
                  padding:
                      const EdgeInsets.symmetric(vertical: 6, horizontal: 16),
                  child: Text(
                    TIM_t_para(
                            "管理员 ({{option2}}/{{option1}})",
                            "管理员 ($option2/$adminLimit)")(
                        option2: option2, option1: adminLimit),
                    style: TextStyle(fontSize: 14, color: theme.weakTextColor),
                  ),
                ),
              if (isDesktopScreen)
                Container(
                  alignment: Alignment.topLeft,
                  padding: const EdgeInsets.only(top: 10, bottom: 4, left: 16),
                  child: Text(
                    TIM_t_para(
                            "管理员 ({{option2}}/{{option1}})",
                            "管理员 ($option2/$adminLimit)")(
                        option2: option2, option1: adminLimit),
                    style: TextStyle(fontSize: 14, color: theme.primaryColor),
                  ),
                ),
              InkWell(
                child: Container(
                    color: _groupManageSurfaceColor(theme),
                    padding: const EdgeInsets.only(left: 16),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        vertical: 12,
                      ),
                      decoration: isDesktopScreen
                          ? null
                          : BoxDecoration(
                              color: _groupManageSurfaceColor(theme),
                              border: Border(
                                  bottom: BorderSide(
                                      color: theme.weakDividerColor ??
                                          CommonColor.weakDividerColor))),
                      child: Row(
                        children: [
                          Icon(
                            Icons.add_circle_outline,
                            color: theme.primaryColor,
                            size: 20,
                          ),
                          const SizedBox(
                            width: 12,
                          ),
                          Text(
                            TIM_t("添加管理员"),
                            style: TextStyle(
                              fontSize: isDesktopScreen ? 14 : 16,
                              color: theme.darkTextColor,
                            ),
                          )
                        ],
                      ),
                    )),
                onTap: () async {
                  if (remainingAdminSlots <= 0) {
                    GroupMemberFeedbackBridge.show(
                      GroupAdminRoleMessage.adminLimitReached(),
                    );
                    return;
                  }
                  final addAdminKey = GlobalKey<_GroupProfileAddAdminState>();
                  if (isDesktopScreen) {
                    final popupSize = WidePopupLayout.large(context);
                    TUIKitWidePopup.showPopupWindow(
                        operationKey: TUIKitWideModalOperationKey.setAdmins,
                        context: context,
                        title: TIM_t("设置管理员"),
                        width: popupSize.width,
                        height: popupSize.height,
                        onCancel: () {},
                        onConfirm: () {
                          addAdminKey.currentState?.onSubmit();
                        },
                        confirmText: TIM_t("完成"),
                        child: (onClose) => GroupProfileAddAdmin(
                              key: addAdminKey,
                              memberList: _memberCandidatesForAdmin(memberList),
                              maxSelectNum: remainingAdminSlots,
                              appbarTitle: TIM_t("设置管理员"),
                              presenceLabelBuilder: widget.presenceLabelBuilder,
                              presenceLoadingChecker:
                                  widget.presenceLoadingChecker,
                              presenceOnlineResolver:
                                  widget.presenceOnlineResolver,
                              presenceListenable: widget.presenceListenable,
                              onMemberPresenceRequested:
                                  widget.onMemberPresenceRequested,
                              onReachBottom: () =>
                                  widget.model.loadMoreGroupMembers(),
                              selectCompletedHandler:
                                  (context, selectedMember) async {
                                await _grantAdministrators(selectedMember);
                              },
                            ));
                  } else {
                    await Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (context) => GroupProfileAddAdmin(
                                  key: addAdminKey,
                                  memberList:
                                      _memberCandidatesForAdmin(memberList),
                                  maxSelectNum: remainingAdminSlots,
                                  appbarTitle: TIM_t("设置管理员"),
                                  presenceLabelBuilder:
                                      widget.presenceLabelBuilder,
                                  presenceLoadingChecker:
                                      widget.presenceLoadingChecker,
                                  presenceOnlineResolver:
                                      widget.presenceOnlineResolver,
                                  presenceListenable: widget.presenceListenable,
                                  onMemberPresenceRequested:
                                      widget.onMemberPresenceRequested,
                                  onReachBottom: () =>
                                      widget.model.loadMoreGroupMembers(),
                                  selectCompletedHandler:
                                      (context, selectedMember) async {
                                    await _grantAdministrators(selectedMember);
                                  },
                                )));
                  }
                },
              ),
              ...adminList
                  .map((e) => GestureDetector(
                        onSecondaryTapDown: (details) {
                          TUIKitWidePopup.showPopupWindow(
                              operationKey:
                                  TUIKitWideModalOperationKey.deleteAdmin,
                              isDarkBackground: false,
                              borderRadius:
                                  const BorderRadius.all(Radius.circular(4)),
                              context: context,
                              offset: Offset(
                                  min(details.globalPosition.dx,
                                      MediaQuery.of(context).size.width - 80),
                                  details.globalPosition.dy),
                              child: (onClose) => TUIKitColumnMenu(data: [
                                    ColumnMenuItem(
                                        label: TIM_t("删除"),
                                        icon: const Icon(
                                            Icons.remove_circle_outline,
                                            size: 16),
                                        onClick: () {
                                          _removeAdmin(context, e);
                                          onClose();
                                        }),
                                  ]));
                        },
                        child: Container(
                          padding: isDesktopScreen
                              ? const EdgeInsets.only(left: 16)
                              : null,
                          child: _buildListItem(
                            context,
                            e!,
                            onRemove: () => _removeAdmin(context, e),
                          ),
                        ),
                      ))
                  .toList(),
            ],
          ));
        }

        return TUIKitScreenUtils.getDeviceWidget(
            context: context,
            desktopWidget: adminPage(),
            defaultWidget: Scaffold(
              backgroundColor: _groupManagePageBackground(theme),
              appBar: AppBar(
                title: Text(
                  TIM_t("设置管理员"),
                  style: TextStyle(
                    color:
                        theme.chatHeaderTitleTextColor ?? theme.appbarTextColor,
                    fontSize: 17,
                  ),
                ),
                shadowColor: theme.weakDividerColor,
                backgroundColor: theme.chatHeaderBgColor ?? theme.appbarBgColor,
                surfaceTintColor: Colors.transparent,
                elevation: 0,
                scrolledUnderElevation: 0,
                iconTheme: IconThemeData(
                  color: theme.primaryColor ?? const Color(0xFF1E90FF),
                ),
              ),
              body: adminPage(),
            ));
      },
    );
  }
}

/// 添加管理员
typedef GroupProfileMemberSelectHandler = Future<void> Function(
  BuildContext context,
  List<V2TimGroupMemberFullInfo?> selectedMemberList,
);

class GroupProfileAddAdmin extends StatefulWidget {
  final List<V2TimGroupMemberFullInfo?> memberList;
  final String appbarTitle;
  final int? maxSelectNum;
  final GroupProfileMemberSelectHandler? selectCompletedHandler;
  final MemberPresenceLabelBuilder? presenceLabelBuilder;
  final MemberPresenceLoadingChecker? presenceLoadingChecker;
  final MemberPresenceOnlineResolver? presenceOnlineResolver;
  final Listenable? presenceListenable;
  final void Function(List<String> userIds)? onMemberPresenceRequested;
  final Future<void> Function()? onReachBottom;

  const GroupProfileAddAdmin(
      {Key? key,
      required this.memberList,
      this.selectCompletedHandler,
      required this.appbarTitle,
      this.maxSelectNum,
      this.presenceLabelBuilder,
      this.presenceLoadingChecker,
      this.presenceOnlineResolver,
      this.presenceListenable,
      this.onMemberPresenceRequested,
      this.onReachBottom})
      : super(key: key);

  @override
  State<StatefulWidget> createState() => _GroupProfileAddAdminState();
}

class _GroupProfileAddAdminState extends TIMUIKitState<GroupProfileAddAdmin> {
  List<V2TimGroupMemberFullInfo> selectedMemberList = [];
  List<V2TimGroupMemberFullInfo?>? searchMemberList;
  bool _submitting = false;

  Future<bool> onSubmit() async {
    if (_submitting) {
      return false;
    }
    final members = selectedMemberList
        .map((member) => member as V2TimGroupMemberFullInfo?)
        .toList(growable: false);
    if (members.isEmpty) {
      GroupMemberFeedbackBridge.show(TIM_t('请选择成员'));
      return false;
    }
    final handler = widget.selectCompletedHandler;
    if (handler != null) {
      setState(() {
        _submitting = true;
      });
      try {
        await handler(
          context,
          members,
        );
      } finally {
        if (mounted) {
          setState(() {
            _submitting = false;
          });
        }
      }
    }
    return true;
  }

  void _handleSearchGroupMembers(String searchText) {
    final keyword = searchText.trim().toLowerCase();
    if (keyword.isEmpty) {
      setState(() {
        searchMemberList = null;
      });
      return;
    }
    final filtered = filterGroupMembersByKeyword(widget.memberList, keyword);
    setState(() {
      searchMemberList = filtered;
    });
  }

  Widget _memberPickerList() {
    return Stack(
      children: [
        AbsorbPointer(
          absorbing: _submitting,
          child: GroupProfileMemberList(
            customTopArea: GroupMemberSearchTextField(
              onTextChange: _handleSearchGroupMembers,
            ),
            memberList: searchMemberList ?? widget.memberList,
            canSelectMember: true,
            canSlideDelete: false,
            isShowIndexBar: false,
            maxSelectNum: widget.maxSelectNum,
            presenceLabelBuilder: widget.presenceLabelBuilder,
            presenceLoadingChecker: widget.presenceLoadingChecker,
            presenceOnlineResolver: widget.presenceOnlineResolver,
            presenceListenable: widget.presenceListenable,
            onMemberListLoaded: widget.onMemberPresenceRequested,
            onSelectedMemberChange: (selectedMember) {
              selectedMemberList = selectedMember;
            },
            touchBottomCallBack: () {
              final onReachBottom = widget.onReachBottom;
              if (onReachBottom != null) {
                unawaited(onReachBottom());
              }
            },
          ),
        ),
        if (_submitting)
          Positioned.fill(
            child: Container(
              color: Colors.black.withOpacity(0.04),
              alignment: Alignment.center,
              child: const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2.4),
              ),
            ),
          ),
      ],
    );
  }

  @override
  Widget tuiBuild(BuildContext context, TUIKitBuildValue value) {
    final TUITheme theme = value.theme;

    return TUIKitScreenUtils.getDeviceWidget(
        context: context,
        desktopWidget: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: _memberPickerList(),
        ),
        defaultWidget: Scaffold(
            backgroundColor: _groupManagePageBackground(theme),
            appBar: AppBar(
              title: Text(
                widget.appbarTitle,
                style: TextStyle(
                  color:
                      theme.chatHeaderTitleTextColor ?? theme.appbarTextColor,
                  fontSize: 17,
                ),
              ),
              shadowColor: theme.weakDividerColor,
              backgroundColor: theme.chatHeaderBgColor ?? theme.appbarBgColor,
              surfaceTintColor: Colors.transparent,
              elevation: 0,
              scrolledUnderElevation: 0,
              iconTheme: IconThemeData(
                color: theme.primaryColor ?? const Color(0xFF1E90FF),
              ),
              leadingWidth: 80,
              leading: TextButton(
                onPressed: _submitting
                    ? null
                    : () {
                        Navigator.of(context).pop();
                      },
                child: Text(
                  TIM_t("取消"),
                  style: TextStyle(
                    color: theme.primaryColor ?? theme.appbarTextColor,
                    fontSize: 14,
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: _submitting
                      ? null
                      : () async {
                          final shouldPop = await onSubmit();
                          if (shouldPop && context.mounted) {
                            Navigator.of(context).pop();
                          }
                        },
                  child: _submitting
                      ? SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: theme.primaryColor ?? theme.appbarTextColor,
                          ),
                        )
                      : Text(
                          TIM_t("完成"),
                          style: TextStyle(
                            color: theme.primaryColor ?? theme.appbarTextColor,
                            fontSize: 14,
                          ),
                        ),
                )
              ],
            ),
            body: _memberPickerList()));
  }
}
