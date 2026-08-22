import 'dart:async';
import 'dart:developer' as developer;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:tencent_chat_i18n_tool/tencent_chat_i18n_tool.dart';
import 'package:tencent_cloud_chat_sdk/enum/group_member_role.dart';
import 'package:tencent_cloud_chat_sdk/enum/group_type.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_callback.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_callback.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_group_info.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_group_info.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_group_member_full_info.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_group_member_full_info.dart';
import 'package:tencent_cloud_chat_uikit/base_widgets/tim_ui_kit_base.dart';
import 'package:tencent_cloud_chat_uikit/base_widgets/tim_ui_kit_statelesswidget.dart';
import 'package:tencent_cloud_chat_uikit/business_logic/separate_models/tui_group_profile_model.dart';
import 'package:tencent_cloud_chat_uikit/business_logic/view_models/tui_chat_global_model.dart';
import 'package:tencent_cloud_chat_uikit/data_services/core/tim_uikit_wide_modal_operation_key.dart';
import 'package:tencent_cloud_chat_uikit/data_services/group/group_member_feedback_bridge.dart';
import 'package:tencent_cloud_chat_uikit/data_services/group/self_hosted_group_bridge.dart';
import 'package:tencent_cloud_chat_uikit/data_services/group/self_hosted_group_leave_diag_bridge.dart';
import 'package:tencent_cloud_chat_uikit/data_services/group/self_hosted_group_leave_bridge.dart';
import 'package:tencent_cloud_chat_uikit/data_services/group/self_hosted_group_leave_confirm_bridge.dart';
import 'package:tencent_cloud_chat_uikit/data_services/message/archive_history_provider.dart';
import 'package:tencent_cloud_chat_uikit/data_services/services_locatar.dart';
import 'package:tencent_cloud_chat_uikit/tencent_cloud_chat_uikit.dart';
import 'package:tencent_cloud_chat_uikit/ui/controller/tim_uikit_chat_controller.dart';
import 'package:tencent_cloud_chat_uikit/ui/utils/platform.dart';
import 'package:tencent_cloud_chat_uikit/ui/utils/screen_utils.dart';
import 'package:tencent_cloud_chat_uikit/ui/widgets/wide_popup.dart';
import 'package:tencent_cloud_chat_uikit/ui/utils/wide_popup_layout.dart';
import 'package:tencent_cloud_chat_uikit/theme/color.dart';
import '/theme/tui_theme.dart';

class GroupProfileButtonArea extends TIMUIKitStatelessWidget {
  final String groupID;
  final TUIGroupProfileModel model;
  final sdkInstance = TIMUIKitCore.getSDKInstance();
  final coreInstance = TIMUIKitCore.getInstance();
  final TIMUIKitChatController _timuiKitChatController =
      TIMUIKitChatController();
  final TUIChatGlobalModel _chatGlobalModel =
      serviceLocator<TUIChatGlobalModel>();

  GroupProfileButtonArea(this.groupID, this.model, {Key? key})
      : super(key: key);

  final _operationList = [
    {"label": TIM_t("清空消息"), "id": "clearHistory"},
    {"label": TIM_t("转让群主"), "id": "transimitOwner"},
    {"label": TIM_t("退出群组"), "id": "quitGroup"},
    {"label": TIM_t("解散群组"), "id": "dismissGroup"}
  ];

  void _logTransferOwner(
    String event, {
    required String userID,
    Object? code,
    Object? desc,
    Object? route,
  }) {
    final line = StringBuffer('GroupGovernance event=$event')
      ..write(' groupId=$groupID')
      ..write(' newOwnerUserId=$userID');
    if (route != null) {
      line.write(' route=$route');
    }
    if (code != null) {
      line.write(' code=$code');
    }
    if (desc != null) {
      line.write(' desc=$desc');
    }
    final text = line.toString();
    developer.log(text, name: 'GroupGovernance');
    // ignore: avoid_print
    print(text);
  }

  Future<void> _performGroupClearHistory(BuildContext context) async {
    ArchiveHistoryProvider.markHistoryClearPending(groupID);
    _chatGlobalModel.clearLocalHistoryAsEmptyLoaded(groupID);

    BuildContext? loadingContext;
    var loadingShown = false;
    if (context.mounted) {
      loadingShown = true;
      // 不要 await showDialog（会等到关闭才返回）；先弹出再等一帧，避免清空
      // API 极快返回时 dismiss 误 pop 掉群资料页，用户完全看不到 loading。
      unawaited(
        showDialog<void>(
          context: context,
          barrierDismissible: false,
          useRootNavigator: true,
          builder: (dialogContext) {
            loadingContext = dialogContext;
            return Center(
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const SizedBox(
                        width: 32,
                        height: 32,
                        child: CircularProgressIndicator(strokeWidth: 3),
                      ),
                      const SizedBox(height: 14),
                      Text(TIM_t('正在清空...')),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      );
      await Future<void>.delayed(const Duration(milliseconds: 50));
    }

    Future<void> dismissLoading() async {
      if (!loadingShown) {
        return;
      }
      loadingShown = false;
      final dialogCtx = loadingContext;
      if (dialogCtx != null && dialogCtx.mounted) {
        Navigator.of(dialogCtx).pop();
      }
    }

    try {
      if (PlatformUtils().isWeb) {
        final res = await sdkInstance
            .getConversationManager()
            .deleteConversation(conversationID: "group_$groupID");
        if (res.code == 0) {
          _chatGlobalModel.clearLocalHistoryAsEmptyLoaded(groupID);
          await ArchiveHistoryProvider.completeHistoryClear(
            isGroup: true,
            conversationID: groupID,
          );
          GroupMemberFeedbackBridge.show(TIM_t("聊天记录已清空"));
        } else {
          ArchiveHistoryProvider.clearHistoryClearPending(groupID);
          GroupMemberFeedbackBridge.show(TIM_t("清空聊天记录失败"));
        }
        return;
      }
      final res = await sdkInstance
          .getMessageManager()
          .clearGroupHistoryMessage(groupID: groupID);
      if (res.code == 0) {
        _chatGlobalModel.clearLocalHistoryAsEmptyLoaded(groupID);
        await ArchiveHistoryProvider.completeHistoryClear(
          isGroup: true,
          conversationID: groupID,
        );
        GroupMemberFeedbackBridge.show(TIM_t("聊天记录已清空"));
      } else {
        ArchiveHistoryProvider.clearHistoryClearPending(groupID);
        GroupMemberFeedbackBridge.show(TIM_t("清空聊天记录失败"));
      }
    } catch (_) {
      ArchiveHistoryProvider.clearHistoryClearPending(groupID);
      GroupMemberFeedbackBridge.show(TIM_t("清空聊天记录失败"));
    } finally {
      await dismissLoading();
    }
  }

  _clearHistory(BuildContext context, theme) async {
    final isDesktopScreen =
        TUIKitScreenUtils.getFormFactor(context) == DeviceType.Desktop;

    if (isDesktopScreen) {
      TUIKitWidePopup.showSecondaryConfirmDialog(
          operationKey: TUIKitWideModalOperationKey.confirmClearChatHistory,
          context: context,
          text: TIM_t("清空聊天记录"),
          theme: theme,
          onCancel: () {},
          onConfirm: () async {
            await _performGroupClearHistory(context);
          });
    } else {
      showCupertinoModalPopup<String>(
        context: context,
        builder: (BuildContext sheetContext) {
          return CupertinoActionSheet(
            title: Text(TIM_t("清空聊天记录")),
            message: Text(TIM_t("清空后无法恢复，确定清空该群的聊天记录吗？")),
            cancelButton: CupertinoActionSheetAction(
              onPressed: () {
                Navigator.pop(
                  sheetContext,
                );
              },
              child: Text(TIM_t("取消")),
              isDefaultAction: false,
            ),
            actions: [
              CupertinoActionSheetAction(
                onPressed: () async {
                  Navigator.pop(
                    sheetContext,
                  );
                  // 等二次确认 sheet 卸掉后再弹 loading，避免两路 pop/push 打架。
                  await Future<void>.delayed(const Duration(milliseconds: 120));
                  if (!context.mounted) {
                    return;
                  }
                  await _performGroupClearHistory(context);
                },
                child: Text(
                  TIM_t("清空"),
                  style: TextStyle(color: theme.cautionColor),
                ),
                isDefaultAction: false,
              )
            ],
          );
        },
      );
    }
  }

  Future<void> _syncSelfLeftLocal() async {
    await SelfHostedGroupBridge.notifySelfLeftGroup(groupID);
  }

  bool _isSameUser(String? left, String? right) {
    final a = left?.trim() ?? '';
    final b = right?.trim() ?? '';
    return a.isNotEmpty && b.isNotEmpty && a == b;
  }

  bool _isGroupOwner(V2TimGroupInfo? groupInfo) {
    if (groupInfo == null) {
      return false;
    }
    if (groupInfo.role == GroupMemberRoleType.V2TIM_GROUP_MEMBER_ROLE_OWNER) {
      return true;
    }
    final selfId =
        coreInstance.loginUserInfo?.userID ?? coreInstance.loginInfo.userID;
    return _isSameUser(groupInfo.owner, selfId);
  }

  bool _ownerShouldDismiss(String groupType) {
    if (SelfHostedGroupBridge.governanceEnabled) {
      return true;
    }
    return groupType != GroupType.Work;
  }

  bool _ownerShouldQuit(String groupType) {
    if (SelfHostedGroupBridge.governanceEnabled) {
      return false;
    }
    return groupType == GroupType.Work;
  }

  void _showLeaveActionFailure(V2TimCallback res, {required bool dismiss}) {
    SelfHostedGroupLeaveDiagBridge.log(
      'ui_action_fail',
      groupId: groupID,
      extras: <String, Object?>{
        'action': dismiss ? 'dismiss' : 'leave',
        'code': res.code,
        'desc': res.desc,
      },
    );
    GroupMemberFeedbackBridge.show(
      SelfHostedGroupLeaveBridge.formatMessage(
        dismiss: dismiss,
        code: res.code,
        desc: res.desc,
      ),
    );
  }

  Future<void> _handleLeaveResult(
    BuildContext context,
    V2TimCallback res, {
    required bool dismiss,
  }) async {
    if (res.code == 0) {
      SelfHostedGroupLeaveDiagBridge.log(
        'ui_action_ok',
        groupId: groupID,
        extras: <String, Object?>{'action': dismiss ? 'dismiss' : 'leave'},
      );
      final successMessage = dismiss ? TIM_t('已解散群聊') : TIM_t('已退出群聊');
      GroupMemberFeedbackBridge.show(successMessage);
      await _completeLeaveSuccess(context, model);
      return;
    }
    _showLeaveActionFailure(res, dismiss: dismiss);
  }

  Future<V2TimCallback> _leaveGroup() async {
    if (SelfHostedGroupBridge.governanceEnabled) {
      SelfHostedGroupLeaveDiagBridge.log(
        'remote_leave_start',
        groupId: groupID,
        extras: const <String, Object?>{'route': 'self_hosted'},
      );
      return SelfHostedGroupBridge.leaveGroup(groupID);
    }
    SelfHostedGroupLeaveDiagBridge.log(
      'remote_leave_start',
      groupId: groupID,
      extras: const <String, Object?>{'route': 'sdk_quitGroup'},
    );
    return sdkInstance.quitGroup(groupID: groupID);
  }

  Future<V2TimCallback> _dismissGroupRemote() async {
    if (SelfHostedGroupBridge.governanceEnabled) {
      SelfHostedGroupLeaveDiagBridge.log(
        'remote_dismiss_start',
        groupId: groupID,
        extras: const <String, Object?>{'route': 'self_hosted'},
      );
      return SelfHostedGroupBridge.dismissGroup(groupID);
    }
    SelfHostedGroupLeaveDiagBridge.log(
      'remote_dismiss_start',
      groupId: groupID,
      extras: const <String, Object?>{'route': 'sdk_dismissGroup'},
    );
    return sdkInstance.dismissGroup(groupID: groupID);
  }

  Future<V2TimCallback> _transferGroupOwnerRemote(String userID) async {
    if (SelfHostedGroupBridge.governanceEnabled) {
      _logTransferOwner(
        'transfer_owner_ui_request',
        userID: userID,
        route: 'self_hosted',
      );
      final res = await SelfHostedGroupBridge.transferGroupOwner(
        groupID: groupID,
        userID: userID,
      );
      _logTransferOwner(
        'transfer_owner_ui_result',
        userID: userID,
        route: 'self_hosted',
        code: res.code,
        desc: res.desc,
      );
      return res;
    }
    _logTransferOwner(
      'transfer_owner_ui_request',
      userID: userID,
      route: 'sdk_fallback',
    );
    final res = await sdkInstance
        .getGroupManager()
        .transferGroupOwner(groupID: groupID, userID: userID);
    _logTransferOwner(
      'transfer_owner_ui_result',
      userID: userID,
      route: 'sdk_fallback',
      code: res.code,
      desc: res.desc,
    );
    return res;
  }

  String _transferOwnerDisplayName(V2TimGroupMemberFullInfo member) {
    for (final value in [
      member.nickName,
      member.nameCard,
      member.friendRemark,
      member.userID,
    ]) {
      final text = value?.trim() ?? '';
      if (text.isNotEmpty) {
        return text;
      }
    }
    return '';
  }

  Future<bool> _confirmTransferOwner(
    BuildContext context, {
    required String displayName,
    required TUITheme theme,
  }) async {
    if (!context.mounted) {
      return false;
    }
    final name =
        displayName.trim().isEmpty ? TIM_t('该成员') : displayName.trim();
    final message = TIM_t_para(
      '确定将群主转让给 {{option1}}？',
      '确定将群主转让给 $name？',
    )(option1: name);
    final isDesktopScreen =
        TUIKitScreenUtils.getFormFactor(context) == DeviceType.Desktop;
    if (isDesktopScreen) {
      final completer = Completer<bool>();
      TUIKitWidePopup.showSecondaryConfirmDialog(
        operationKey: TUIKitWideModalOperationKey.confirmGeneral,
        context: context,
        text: message,
        theme: theme,
        onCancel: () {
          if (!completer.isCompleted) {
            completer.complete(false);
          }
        },
        onConfirm: () {
          if (!completer.isCompleted) {
            completer.complete(true);
          }
        },
      );
      return completer.future;
    }
    HapticFeedback.mediumImpact();
    final result = await showCupertinoDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return CupertinoAlertDialog(
          title: Text(TIM_t('转让群主')),
          content: Text(message),
          actions: [
            CupertinoDialogAction(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: Text(TIM_t('取消')),
            ),
            CupertinoDialogAction(
              isDestructiveAction: true,
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: Text(TIM_t('确定')),
            ),
          ],
        );
      },
    );
    return result == true;
  }

  Future<void> _transferOwnerAfterConfirm(
    BuildContext context, {
    required String groupID,
    required V2TimGroupMemberFullInfo member,
    required TUITheme theme,
  }) async {
    final confirmed = await _confirmTransferOwner(
      context,
      displayName: _transferOwnerDisplayName(member),
      theme: theme,
    );
    if (!confirmed || !context.mounted) {
      return;
    }
    final userID = member.userID;
    final res = await _transferGroupOwnerRemote(userID);
    if (res.code != 0) {
      return;
    }
    _chatGlobalModel.addGroupSystemNotice(
      GroupSystemNoticeItem(
        id: "owner|$groupID|${coreInstance.loginInfo.userID}|$userID|${DateTime.now().millisecondsSinceEpoch}",
        groupID: groupID,
        groupName: model.groupInfo?.groupName ?? groupID,
        groupFaceUrl: model.groupInfo?.faceUrl ?? "",
        type: GroupSystemNoticeType.transferOwner,
        operatorUserID: coreInstance.loginInfo.userID,
        operatorName: coreInstance.loginInfo.loginUser?.nickName ??
            coreInstance.loginInfo.userID,
        targetUserID: userID,
        targetName: _transferOwnerDisplayName(member),
        timestamp: DateTime.now().millisecondsSinceEpoch,
      ),
    );
  }

  Future<void> _completeLeaveSuccess(
    BuildContext context,
    TUIGroupProfileModel model,
  ) async {
    SelfHostedGroupLeaveDiagBridge.log(
      'ui_complete_success_start',
      groupId: groupID,
    );
    await _syncSelfLeftLocal();
    try {
      await sdkInstance
          .getConversationManager()
          .deleteConversation(conversationID: "group_$groupID");
    } catch (e) {
      SelfHostedGroupLeaveDiagBridge.log(
        'ui_delete_conversation_fail',
        groupId: groupID,
        extras: <String, Object?>{'error': e.toString()},
      );
    }
    final onLeave = model.lifeCycle?.didLeaveGroup;
    if (onLeave != null) {
      await onLeave();
      SelfHostedGroupLeaveDiagBridge.log(
        'ui_complete_success_done',
        groupId: groupID,
        extras: const <String, Object?>{'via': 'lifecycle'},
      );
      return;
    }
    if (context.mounted) {
      final navigator = Navigator.of(context, rootNavigator: true);
      if (navigator.canPop()) {
        navigator.popUntil((route) => route.isFirst);
      }
    }
    SelfHostedGroupLeaveDiagBridge.log(
      'ui_complete_success_done',
      groupId: groupID,
      extras: const <String, Object?>{'via': 'pop'},
    );
  }

  _quitGroup(BuildContext context, TUITheme theme) async {
    SelfHostedGroupLeaveDiagBridge.log(
      'ui_tap',
      groupId: groupID,
      extras: const <String, Object?>{'action': 'leave'},
    );
    final confirmed =
        await SelfHostedGroupLeaveConfirmBridge.confirm(dismiss: false);
    SelfHostedGroupLeaveDiagBridge.log(
      confirmed ? 'ui_confirm_ok' : 'ui_confirm_cancel',
      groupId: groupID,
      extras: const <String, Object?>{'action': 'leave'},
    );
    if (!confirmed || !context.mounted) {
      return;
    }
    final res = await _leaveGroup();
    if (!context.mounted) {
      return;
    }
    await _handleLeaveResult(context, res, dismiss: false);
  }

  _dismissGroup(BuildContext context, theme) async {
    SelfHostedGroupLeaveDiagBridge.log(
      'ui_tap',
      groupId: groupID,
      extras: const <String, Object?>{'action': 'dismiss'},
    );
    final confirmed =
        await SelfHostedGroupLeaveConfirmBridge.confirm(dismiss: true);
    SelfHostedGroupLeaveDiagBridge.log(
      confirmed ? 'ui_confirm_ok' : 'ui_confirm_cancel',
      groupId: groupID,
      extras: const <String, Object?>{'action': 'dismiss'},
    );
    if (!confirmed || !context.mounted) {
      return;
    }
    final res = await _dismissGroupRemote();
    if (!context.mounted) {
      return;
    }
    await _handleLeaveResult(context, res, dismiss: true);
  }

  _transmitOwner(BuildContext context, String groupID, TUITheme theme) async {
    final isDesktopScreen =
        TUIKitScreenUtils.getFormFactor(context) == DeviceType.Desktop;

    if (isDesktopScreen) {
      final popupSize = WidePopupLayout.large(context);
      TUIKitWidePopup.showPopupWindow(
        operationKey: TUIKitWideModalOperationKey.setAdmins,
        context: context,
        title: TIM_t("转让群主"),
        width: popupSize.width,
        height: popupSize.height,
        onCancel: () {},
        onConfirm: () {
          selectNewGroupOwnerKey.currentState?.onSubmit();
        },
        confirmText: TIM_t("完成"),
        child: (onClose) => SelectNewGroupOwner(
          model: model,
          key: selectNewGroupOwnerKey,
          groupID: groupID,
          onSelectedMember: (selectedMember) async {
            if (selectedMember.isEmpty) {
              return;
            }
            await _transferOwnerAfterConfirm(
              context,
              groupID: groupID,
              member: selectedMember.first,
              theme: theme,
            );
          },
        ),
      );
    } else {
      List<V2TimGroupMemberFullInfo>? selectedMember = await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => SelectNewGroupOwner(
            model: model,
            groupID: groupID,
          ),
        ),
      );
      if (selectedMember != null &&
          selectedMember.isNotEmpty &&
          context.mounted) {
        await _transferOwnerAfterConfirm(
          context,
          groupID: groupID,
          member: selectedMember.first,
          theme: theme,
        );
      }
    }
  }

  List<Widget> _renderGroupOperation(
      BuildContext context, TUITheme theme, bool isOwner, String groupType) {
    final isDesktopScreen =
        TUIKitScreenUtils.getFormFactor(context) == DeviceType.Desktop;
    final itemBackgroundColor = theme.conversationItemBgColor ??
        theme.wideBackgroundColor ??
        Colors.white;
    return _operationList
        .where((element) {
          final id = element["id"];
          if (!isOwner) {
            return ["quitGroup", "clearHistory"].contains(id);
          }
          if (id == "clearHistory" || id == "transimitOwner") {
            return true;
          }
          if (id == "dismissGroup") {
            return _ownerShouldDismiss(groupType);
          }
          if (id == "quitGroup") {
            return _ownerShouldQuit(groupType);
          }
          return false;
        })
        .map((e) => isDesktopScreen
            ? OutlinedButton(
                onPressed: () {
                  if (e["id"]! == "clearHistory") {
                    _clearHistory(context, theme);
                  } else if (e["id"] == "quitGroup") {
                    _quitGroup(context, theme);
                  } else if (e["id"] == "dismissGroup") {
                    _dismissGroup(context, theme);
                  } else if (e["id"] == "transimitOwner") {
                    _transmitOwner(context, groupID, theme);
                  }
                },
                child: Text(
                  e["label"]!,
                  style: TextStyle(color: theme.cautionColor),
                ))
            : InkWell(
                onTap: () {
                  if (e["id"]! == "clearHistory") {
                    _clearHistory(context, theme);
                  } else if (e["id"] == "quitGroup") {
                    _quitGroup(context, theme);
                  } else if (e["id"] == "dismissGroup") {
                    _dismissGroup(context, theme);
                  } else if (e["id"] == "transimitOwner") {
                    _transmitOwner(context, groupID, theme);
                  }
                },
                child: Container(
                  width: double.infinity,
                  alignment: Alignment.center,
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  decoration: BoxDecoration(
                      color: itemBackgroundColor,
                      border: Border(
                          bottom: BorderSide(
                              color: theme.weakDividerColor ??
                                  CommonColor.weakDividerColor))),
                  child: Text(
                    e["label"]!,
                    style: TextStyle(color: theme.cautionColor, fontSize: 17),
                  ),
                ),
              ))
        .toList();
  }

  @override
  Widget tuiBuild(BuildContext context, TUIKitBuildValue value) {
    final theme = value.theme;
    final groupInfo = model.groupInfo;
    final isOwner = _isGroupOwner(groupInfo);

    final isDesktopScreen =
        TUIKitScreenUtils.getFormFactor(context) == DeviceType.Desktop;
    if (isDesktopScreen) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Wrap(
          spacing: 28,
          children: [
            ..._renderGroupOperation(
                context, theme, isOwner, groupInfo?.groupType ?? "")
          ],
        ),
      );
    }

    return Column(
      children: [
        ..._renderGroupOperation(
            context, theme, isOwner, groupInfo?.groupType ?? "")
      ],
    );
  }
}
