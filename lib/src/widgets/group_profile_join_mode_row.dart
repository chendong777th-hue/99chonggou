import 'dart:async';
import 'dart:math';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tencent_cloud_chat_demo/src/api/group_join_api.dart';
import 'package:tencent_cloud_chat_demo/src/group_manage_page.dart';
import 'package:tencent_cloud_chat_demo/src/i18n/app_i18n.dart';
import 'package:tencent_cloud_chat_demo/src/models/group_join_option.dart';
import 'package:tencent_cloud_chat_demo/src/provider/theme.dart';
import 'package:tencent_cloud_chat_demo/src/ui/app_responsive.dart';
import 'package:tencent_cloud_chat_demo/src/services/group_local/group_tip_custom_sender.dart';
import 'package:tencent_cloud_chat_uikit/business_logic/separate_models/tui_group_profile_model.dart';
import 'package:tencent_cloud_chat_uikit/data_services/core/tim_uikit_wide_modal_operation_key.dart';
import 'package:tencent_cloud_chat_uikit/theme/color.dart';
import 'package:tencent_cloud_chat_uikit/theme/tui_theme.dart';
import 'package:tencent_cloud_chat_uikit/ui/utils/screen_utils.dart';
import 'package:tencent_cloud_chat_uikit/ui/views/TIMUIKitGroupProfile/widgets/tim_uikit_group_add_opt.dart';
import 'package:tencent_cloud_chat_uikit/ui/widgets/column_menu.dart';
import 'package:tencent_cloud_chat_uikit/ui/widgets/wide_popup.dart';

/// 群资料「加群方式」一行。
///
/// 自建 Public / Meeting / Community 以 REST `join-options.applyJoinOption` 为准；
/// 其它群类型仍走 IM SDK `groupAddOpt`，避免自建群长期显示「未知」。
/// Web / 桌面用锚点下拉菜单，手机才用 ActionSheet。
class GroupProfileJoinModeRow extends StatefulWidget {
  const GroupProfileJoinModeRow({super.key});

  @override
  State<GroupProfileJoinModeRow> createState() =>
      _GroupProfileJoinModeRowState();
}

class _GroupProfileJoinModeRowState extends State<GroupProfileJoinModeRow> {
  GroupJoinOptions? _options;
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _bootstrap());
  }

  Future<void> _bootstrap() async {
    final model = Provider.of<TUIGroupProfileModel>(context, listen: false);
    final groupInfo = model.groupInfo;
    if (groupInfo == null ||
        !GroupManagePage.usesSelfHostedJoinOptions(groupInfo)) {
      if (mounted) {
        setState(() => _loading = false);
      }
      return;
    }
    await _load(groupInfo.groupID);
  }

  Future<void> _load(String groupId) async {
    setState(() => _loading = true);
    try {
      final options = await GroupJoinApi.instance.fetchJoinOptions(groupId);
      if (!mounted) return;
      setState(() {
        _options = options;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  Future<void> _pickApplyOption({
    required TUITheme theme,
    required String groupId,
    required GroupJoinOptions current,
    required bool isDesktopScreen,
    Offset? globalPosition,
  }) async {
    if (_saving) return;
    final i18n = AppI18n.of(context);
    final pageContext = context;

    Future<void> select(GroupJoinOption option) async {
      await _saveApplyOption(
        pageContext,
        theme,
        groupId,
        current.copyWith(applyJoinOption: option),
      );
    }

    if (isDesktopScreen) {
      final dx = globalPosition?.dx ?? MediaQuery.of(context).size.width - 200;
      final dy = globalPosition?.dy ?? 120;
      await TUIKitWidePopup.showPopupWindow(
        operationKey: TUIKitWideModalOperationKey.groupAddOpt,
        isDarkBackground: false,
        borderRadius: const BorderRadius.all(Radius.circular(8)),
        context: context,
        offset: Offset(
          min(dx, MediaQuery.of(context).size.width - 186),
          dy,
        ),
        child: (onClose) => TUIKitColumnMenu(
          data: GroupJoinOption.values
              .map(
                (option) => ColumnMenuItem(
                  label: option.localizedLabel(i18n),
                  onClick: () {
                    onClose();
                    select(option);
                  },
                ),
              )
              .toList(),
        ),
      );
      return;
    }

    await showCupertinoModalPopup<void>(
      context: context,
      builder: (sheetContext) {
        return CupertinoActionSheet(
          title: Text(i18n.t(
            zhHans: '加群方式',
            zhHant: '加群方式',
            en: 'Join Method',
            ja: '参加方法',
            ko: '가입 방식',
          )),
          cancelButton: CupertinoActionSheetAction(
            onPressed: () => Navigator.pop(sheetContext),
            child: Text(i18n.t(
              zhHans: '取消',
              zhHant: '取消',
              en: 'Cancel',
              ja: 'キャンセル',
              ko: '취소',
            )),
          ),
          actions: GroupJoinOption.values
              .map(
                (option) => CupertinoActionSheetAction(
                  onPressed: () async {
                    Navigator.pop(sheetContext);
                    await select(option);
                  },
                  child: Text(
                    option.localizedLabel(i18n),
                    style: TextStyle(
                      color: option == current.applyJoinOption
                          ? theme.primaryColor
                          : null,
                    ),
                  ),
                ),
              )
              .toList(),
        );
      },
    );
  }

  Future<void> _saveApplyOption(
    BuildContext pageContext,
    TUITheme theme,
    String groupId,
    GroupJoinOptions next,
  ) async {
    final before = _options;
    setState(() => _saving = true);
    try {
      final saved =
          await GroupJoinApi.instance.updateJoinOptions(groupId, next);
      if (!mounted) return;
      setState(() {
        _options = saved;
        _saving = false;
      });
      if (before != null) {
        unawaited(
          GroupTipCustomSender.instance.sendJoinOptionsDiff(
            groupId: groupId,
            before: before,
            after: saved,
          ),
        );
      }
      _toast(
        pageContext,
        AppI18n.of(pageContext).t(
          zhHans: '修改成功',
          zhHant: '修改成功',
          en: 'Updated',
          ja: '更新しました',
          ko: '수정됨',
        ),
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _saving = false);
      _toast(
        pageContext,
        AppI18n.of(pageContext).t(
          zhHans: '修改失败',
          zhHant: '修改失敗',
          en: 'Update failed',
          ja: '更新に失敗しました',
          ko: '수정 실패',
        ),
      );
    }
  }

  void _toast(BuildContext context, String text) {
    final messenger = ScaffoldMessenger.maybeOf(context);
    if (messenger == null) return;
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        content: Text(text),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(milliseconds: 1300),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final model = Provider.of<TUIGroupProfileModel>(context);
    final groupInfo = model.groupInfo;
    if (groupInfo == null) {
      return const SizedBox.shrink();
    }
    if (!GroupManagePage.usesSelfHostedJoinOptions(groupInfo)) {
      return GroupProfileAddOpt();
    }

    final theme = Provider.of<DefaultThemeData>(context).theme;
    final isDesktopScreen =
        TUIKitScreenUtils.getFormFactor(context) == DeviceType.Desktop;
    final i18n = AppI18n.of(context);
    final options = _options;
    final value = _loading
        ? i18n.t(
            zhHans: '加载中…',
            zhHant: '載入中…',
            en: 'Loading…',
            ja: '読み込み中…',
            ko: '로딩 중…',
          )
        : (options?.applyJoinOption.localizedLabel(i18n) ??
            i18n.t(
              zhHans: '管理员审批',
              zhHant: '管理員審批',
              en: 'Admin Approval',
              ja: '管理者承認',
              ko: '관리자 승인',
            ));
    final itemBackgroundColor = theme.conversationItemBgColor ??
        theme.wideBackgroundColor ??
        Colors.white;
    final padding = AppResponsive.listRowPadding(
      context,
      mobileHorizontal: 16,
      desktopHorizontal: 18,
      mobileVertical: 12,
      desktopVertical: 10,
    );
    final minHeight = AppResponsive.listRowMinHeight(
      context,
      mobile: 52,
      desktop: 48,
    );
    final current = options ??
        const GroupJoinOptions(
          applyJoinOption: GroupJoinOption.needPermission,
          inviteJoinOption: GroupJoinOption.needPermission,
        );

    return Container(
      constraints: BoxConstraints(minHeight: minHeight),
      padding: padding,
      decoration: BoxDecoration(
        color: itemBackgroundColor,
        border: isDesktopScreen
            ? null
            : Border(
                bottom: BorderSide(
                  color: theme.weakDividerColor ?? CommonColor.weakDividerColor,
                ),
              ),
      ),
      child: InkWell(
        onTapDown: (_loading || _saving)
            ? null
            : (details) {
                _pickApplyOption(
                  theme: theme,
                  groupId: groupInfo.groupID,
                  current: current,
                  isDesktopScreen: isDesktopScreen,
                  globalPosition: details.globalPosition,
                );
              },
        child: Row(
          mainAxisAlignment: MainAxisAlignment.start,
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
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: isDesktopScreen ? 14 : 16,
                  color: theme.darkTextColor,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: MediaQuery.sizeOf(context).width * 0.42,
                  ),
                  child: Text(
                    value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: isDesktopScreen ? 14 : 16,
                      color: theme.weakTextColor,
                    ),
                  ),
                ),
                Icon(
                  Icons.keyboard_arrow_right,
                  color: theme.weakTextColor,
                  size: isDesktopScreen ? 18 : 20,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
