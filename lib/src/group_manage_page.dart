import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tencent_cloud_chat_demo/src/api/group_join_api.dart';
import 'package:tencent_cloud_chat_demo/src/i18n/app_i18n.dart';
import 'package:tencent_cloud_chat_demo/src/provider/presence_provider.dart';
import 'package:tencent_cloud_chat_demo/src/provider/theme.dart';
import 'package:tencent_cloud_chat_demo/src/widgets/group_join_options_header.dart';
import 'package:tencent_cloud_chat_demo/src/widgets/group_privacy_settings_row.dart';
import 'package:tencent_cloud_chat_demo/utils/friend_mutual_utils.dart';
import 'package:tencent_cloud_chat_sdk/enum/group_add_opt_type.dart';
import 'package:tencent_cloud_chat_sdk/enum/group_type.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_group_info.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_group_info.dart';
import 'package:tencent_cloud_chat_demo/utils/dio_error_message.dart';
import 'package:tencent_cloud_chat_uikit/business_logic/separate_models/tui_group_profile_model.dart';
import 'package:tencent_cloud_chat_uikit/business_logic/view_models/tui_friendship_view_model.dart';
import 'package:tencent_cloud_chat_uikit/data_services/services_locatar.dart';
import 'package:tencent_cloud_chat_uikit/theme/tui_theme.dart';
import 'package:tencent_cloud_chat_uikit/ui/utils/group_role_policy.dart';
import 'package:tencent_cloud_chat_uikit/ui/views/TIMUIKitGroupProfile/widgets/tim_uikit_group_manage.dart';

/// 群资料「管理群」页：加群方式、群隐私保护 + 原群管理能力。
class GroupManagePage extends StatelessWidget {
  final TUIGroupProfileModel model;
  final String groupID;

  const GroupManagePage({
    Key? key,
    required this.model,
    required this.groupID,
  }) : super(key: key);

  static bool canManageGroup(V2TimGroupInfo groupInfo) {
    return GroupRolePolicy.isManagerRole(groupInfo.role);
  }

  static bool usesSelfHostedJoinOptions(V2TimGroupInfo groupInfo) {
    return GroupJoinApi.isSelfHostedJoinGroupType(groupInfo.groupType);
  }

  static bool canEditJoinMode(V2TimGroupInfo groupInfo) {
    if (!canManageGroup(groupInfo)) {
      return false;
    }
    if (usesSelfHostedJoinOptions(groupInfo)) {
      return true;
    }
    final groupType = groupInfo.groupType;
    return groupType != GroupType.Work && groupType != GroupType.AVChatRoom;
  }

  static String groupAddOptLabel(int? groupAddOpt) {
    final i18n = AppI18n.current;
    switch (groupAddOpt) {
      case GroupAddOptType.V2TIM_GROUP_ADD_ANY:
        return i18n.t(
          zhHans: '自动审批',
          zhHant: '自動審批',
          en: 'Auto Approve',
          ja: '自動承認',
          ko: '자동 승인',
        );
      case GroupAddOptType.V2TIM_GROUP_ADD_AUTH:
        return i18n.t(
          zhHans: '管理员审批',
          zhHant: '管理員審批',
          en: 'Admin Approval',
          ja: '管理者承認',
          ko: '관리자 승인',
        );
      case GroupAddOptType.V2TIM_GROUP_ADD_FORBID:
        return i18n.t(
          zhHans: '禁止加群',
          zhHant: '禁止加群',
          en: 'Join Disabled',
          ja: '参加禁止',
          ko: '가입 금지',
        );
      default:
        return i18n.t(
          zhHans: '未知',
          zhHant: '未知',
          en: 'Unknown',
          ja: '不明',
          ko: '알 수 없음',
        );
    }
  }

  static void showGroupAddOptSheet(
    BuildContext context,
    TUITheme theme,
    TUIGroupProfileModel model,
  ) {
    final i18n = AppI18n.of(context);
    final pageContext = context;
    final actionList = [
      {
        'label': i18n.t(
          zhHans: '禁止加群',
          zhHant: '禁止加群',
          en: 'Join Disabled',
          ja: '参加禁止',
          ko: '가입 금지',
        ),
        'id': GroupAddOptType.V2TIM_GROUP_ADD_FORBID,
      },
      {
        'label': i18n.t(
          zhHans: '自动审批',
          zhHant: '自動審批',
          en: 'Auto Approve',
          ja: '自動承認',
          ko: '자동 승인',
        ),
        'id': GroupAddOptType.V2TIM_GROUP_ADD_ANY,
      },
      {
        'label': i18n.t(
          zhHans: '管理员审批',
          zhHant: '管理員審批',
          en: 'Admin Approval',
          ja: '管理者承認',
          ko: '관리자 승인',
        ),
        'id': GroupAddOptType.V2TIM_GROUP_ADD_AUTH,
      },
    ];
    showCupertinoModalPopup<String>(
      context: context,
      builder: (BuildContext context) {
        return CupertinoActionSheet(
          title: Text(i18n.t(
            zhHans: '加群方式',
            zhHant: '加群方式',
            en: 'Join Method',
            ja: '参加方法',
            ko: '가입 방식',
          )),
          cancelButton: CupertinoActionSheetAction(
            onPressed: () => Navigator.pop(context, 'cancel'),
            child: Text(i18n.t(
              zhHans: '取消',
              zhHant: '取消',
              en: 'Cancel',
              ja: 'キャンセル',
              ko: '취소',
            )),
            isDefaultAction: false,
          ),
          actions: actionList
              .map(
                (e) => CupertinoActionSheetAction(
                  onPressed: () async {
                    Navigator.pop(context, 'confirm');
                    final res = await model.setGroupAddOpt(e['id'] as int);
                    if (!pageContext.mounted) return;
                    final success = res?.code == 0;
                    final message = success
                        ? i18n.t(
                            zhHans: '修改成功',
                            zhHant: '修改成功',
                            en: 'Updated',
                            ja: '更新しました',
                            ko: '수정되었습니다',
                          )
                        : DioErrorMessage.sanitizeUserText(
                            res?.desc,
                            fallback: i18n.t(
                                zhHans: '修改失败',
                                zhHant: '修改失敗',
                                en: 'Update failed',
                                ja: '更新に失敗しました',
                                ko: '수정 실패',
                              ),
                          );
                    final messenger = ScaffoldMessenger.maybeOf(pageContext);
                    if (messenger != null) {
                      messenger.hideCurrentSnackBar();
                      messenger.showSnackBar(
                        SnackBar(
                          content: Text(message),
                          behavior: SnackBarBehavior.floating,
                          duration: const Duration(milliseconds: 1300),
                        ),
                      );
                    }
                  },
                  child: Text(
                    e['label'] as String,
                    style: TextStyle(color: theme.primaryColor),
                  ),
                  isDefaultAction: false,
                ),
              )
              .toList(),
        );
      },
    );
  }

  List<Widget> _buildHeaderWidgets(
    BuildContext context,
    TUITheme theme,
    V2TimGroupInfo groupInfo,
  ) {
    final i18n = AppI18n.of(context);
    final canManage = canManageGroup(groupInfo);
    final canEditJoin = canEditJoinMode(groupInfo);
    final surface =
        theme.conversationItemBgColor ?? theme.wideBackgroundColor ?? Colors.white;
    final divider = theme.weakDividerColor ?? const Color(0xFFE5E5E5);

    final rows = <Widget>[];

    if (canEditJoin) {
      final groupId =
          groupInfo.groupID.isNotEmpty ? groupInfo.groupID : groupID;
      if (usesSelfHostedJoinOptions(groupInfo)) {
        rows.add(
          GroupJoinOptionsHeader(
            groupId: groupId,
            theme: theme,
          ),
        );
      } else {
        rows.add(
          Material(
            color: surface,
            child: InkWell(
              onTap: () => showGroupAddOptSheet(context, theme, model),
              child: Container(
                height: 56,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  border: Border(bottom: BorderSide(color: divider, width: 0.5)),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        i18n.t(
                          zhHans: '加群方式',
                          zhHant: '加群方式',
                          en: 'Join Method',
                          ja: '参加方法',
                          ko: '가입 방식',
                        ),
                        style: TextStyle(
                          fontSize: 16,
                          color: theme.darkTextColor,
                        ),
                      ),
                    ),
                    Text(
                      groupAddOptLabel(groupInfo.groupAddOpt),
                      style: TextStyle(
                        fontSize: 15,
                        color: theme.weakTextColor,
                      ),
                    ),
                    Icon(
                      Icons.keyboard_arrow_right,
                      color: theme.weakTextColor,
                      size: 20,
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      }
    }

    if (canManage) {
      rows.add(
        Material(
          color: surface,
          child: GroupPrivacySettingsRow(
            groupId: groupInfo.groupID.isNotEmpty ? groupInfo.groupID : groupID,
            canEdit: true,
            theme: theme,
          ),
        ),
      );
    }

    return rows;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Provider.of<DefaultThemeData>(context).theme;
    final groupInfo = model.groupInfo;
    if (groupInfo == null) {
      return const SizedBox.shrink();
    }
    final presence = Provider.of<PresenceProvider>(context, listen: false);
    final friendship = serviceLocator<TUIFriendShipViewModel>();

    return ChangeNotifierProvider.value(
      value: model,
      child: GroupProfileGroupManagePage(
        model: model,
        appBarTitle: AppI18n.of(context).t(
          zhHans: '管理群',
          zhHant: '管理群',
          en: 'Manage Group',
          ja: 'グループ管理',
          ko: '그룹 관리',
        ),
        headerWidgets: _buildHeaderWidgets(context, theme, groupInfo),
        presenceListenable: presence,
        presenceLabelBuilder: (userId, imOnline) => presence.onlineLabelFor(
          userId: userId,
          imOnline: imOnline,
          isMutualFriend: friendCanMessage(friendship, userId),
        ),
        presenceLoadingChecker: (userId, imOnline) =>
            presence.isLastSeenLoading(userId: userId, imOnline: imOnline),
        presenceOnlineResolver: (userId, imOnline) =>
            presence.resolveOnline(userId: userId, imOnline: imOnline),
        onMemberPresenceRequested: (userIds) {
          presence.ensure(userIds);
        },
      ),
    );
  }
}
