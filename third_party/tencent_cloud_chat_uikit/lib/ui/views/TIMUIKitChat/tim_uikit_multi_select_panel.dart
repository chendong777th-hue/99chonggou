import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tencent_chat_i18n_tool/tencent_chat_i18n_tool.dart';
import 'package:tencent_cloud_chat_sdk/enum/message_status.dart';
import 'package:tencent_cloud_chat_uikit/base_widgets/tim_ui_kit_statelesswidget.dart';
import 'package:tencent_cloud_chat_uikit/business_logic/separate_models/tui_chat_separate_view_model.dart';
import 'package:tencent_cloud_chat_uikit/business_logic/view_models/tui_chat_global_model.dart';
import 'package:tencent_cloud_chat_uikit/data_services/core/tim_uikit_wide_modal_operation_key.dart';
import 'package:tencent_cloud_chat_uikit/ui/utils/screen_utils.dart';
import 'package:tencent_cloud_chat_uikit/ui/utils/wide_popup_layout.dart';
import 'package:tencent_cloud_chat_uikit/ui/widgets/forward_message_screen.dart';
import 'package:tencent_cloud_chat_uikit/ui/widgets/wide_popup.dart';
import 'package:tencent_cloud_chat_uikit/base_widgets/tim_ui_kit_base.dart';
import 'package:tencent_cloud_chat_uikit/base_widgets/tim_callback.dart';
import 'package:tencent_cloud_chat_uikit/theme/color.dart';
import 'package:tencent_cloud_chat_uikit/theme/tui_theme.dart';

class MultiSelectPanel extends TIMUIKitStatelessWidget {
  final int forwardMsgNumLimit = 30;

  final ConvType conversationType;

  MultiSelectPanel({Key? key, required this.conversationType})
      : super(key: key);

  _handleForwardMessage(BuildContext context, bool isMergerForward,
      TUIChatSeparateViewModel model) {

    // 是否有选中消息
    if (model.getSelectedMessageList().isEmpty) {
      onTIMCallback(TIMCallback(
          type: TIMCallbackType.INFO,
          infoRecommendText: TIM_t("请选择要操作的消息！")));
      return;
    }

    for (var v2TimMessage in model.getSelectedMessageList()) {
      // 失败消息不支持转发
      if (v2TimMessage.status == MessageStatus.V2TIM_MSG_STATUS_SEND_FAIL) {
        onTIMCallback(TIMCallback(
            type: TIMCallbackType.INFO,
            infoRecommendText: TIM_t("发送失败消息不支持转发！")));
        return;
      }

      // 投票消息不支持转发
      if (model.isVoteMessage(v2TimMessage)) {
        onTIMCallback(TIMCallback(
          type: TIMCallbackType.INFO,
          infoRecommendText: TIM_t("投票消息不支持转发！")));
        return;
      }

      // 红包/转账消息不支持转发
      if (model.isWalletCardMessage(v2TimMessage)) {
        onTIMCallback(TIMCallback(
          type: TIMCallbackType.INFO,
          infoRecommendText: TIM_t("钱包消息不可转发")));
        return;
      }

      // 个人名片不支持转发
      if (model.isContactCardMessage(v2TimMessage)) {
        onTIMCallback(TIMCallback(
          type: TIMCallbackType.INFO,
          infoRecommendText: TIM_t("个人名片不支持转发！")));
        return;
      }
    }

    // 逐条转发限制在 30 条以内
    if (!isMergerForward && model.getSelectedMessageList().length > forwardMsgNumLimit) {
      _showForwardLimitDialog(context);
      return;
    }

    Navigator.push(
        context,
        MaterialPageRoute(
            builder: (context) => ForwardMessageScreen(
                  model: model,
                  isMergerForward: isMergerForward,
                  conversationType: conversationType,
                )));
  }

  // 弹出逐条转发超限的对话框
  Future<bool?> _showForwardLimitDialog(BuildContext context) {
    return showDialog<bool>(
      context: context,
      builder: (context) {
        return CupertinoAlertDialog(
          title: Text(TIM_t("转发消息过多，暂不支持逐条转发")),
          actions: [
            CupertinoDialogAction(
              child: Text(TIM_t("确定")),
              onPressed: () {
                Navigator.of(context).pop(true);
              },
            ),
            CupertinoDialogAction(
              child: Text(TIM_t("取消")),
              isDestructiveAction: true,
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  _handleForwardMessageWide(BuildContext context, bool isMergerForward,
      TUIChatSeparateViewModel model) {
    final popupSize = WidePopupLayout.large(context);
    TUIKitWidePopup.showPopupWindow(
        operationKey: TUIKitWideModalOperationKey.forward,
        context: context,
        isDarkBackground: false,
        title: TIM_t("转发"),
        width: popupSize.width,
        height: popupSize.height,
        onCancel: () {},
        onConfirm: () {
          forwardMessageScreenKey.currentState?.handleForwardMessage();
        },
        confirmText: TIM_t("发送"),
        child: (onClose) => Container(
          padding: const EdgeInsets.symmetric( horizontal: 10),
          child: ForwardMessageScreen(
            model: model,
            key: forwardMessageScreenKey,
            onClose: onClose,
            isMergerForward: isMergerForward,
            conversationType: conversationType,
          ),
        )
    );
  }

  Widget _panelShell({
    required TUITheme theme,
    required Widget child,
    EdgeInsetsGeometry? padding,
  }) {
    return Container(
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(
            color: theme.weakDividerColor ?? CommonColor.weakDividerColor,
          ),
        ),
        color: theme.selectPanelBgColor ?? theme.primaryColor,
      ),
      padding: padding,
      child: child,
    );
  }

  Widget _actionItem({
    required TUITheme theme,
    required String iconAsset,
    required String label,
    required VoidCallback onPressed,
    double iconSize = 24,
  }) {
    final labelColor =
        theme.selectPanelTextIconColor ?? theme.darkTextColor ?? Colors.black87;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(6),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 4),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Image.asset(
                iconAsset,
                package: 'tencent_cloud_chat_uikit',
                width: iconSize,
                height: iconSize,
                color: theme.selectPanelTextIconColor,
              ),
              const SizedBox(height: 4),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: TextStyle(color: labelColor, fontSize: 11),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _compactActionBar({
    required BuildContext context,
    required TUITheme theme,
    required TUIChatSeparateViewModel model,
    required bool isDesktop,
  }) {
    return _panelShell(
      theme: theme,
      padding: EdgeInsets.only(
        top: 8,
        bottom: isDesktop ? 12 : 8,
        left: 8,
        right: 8,
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            Expanded(
              child: _actionItem(
                theme: theme,
                iconAsset: 'images/forward.png',
                label: TIM_t("逐条转发"),
                onPressed: () {
                  if (isDesktop) {
                    _handleForwardMessageWide(context, false, model);
                  } else {
                    _handleForwardMessage(context, false, model);
                  }
                },
              ),
            ),
            Expanded(
              child: _actionItem(
                theme: theme,
                iconAsset: 'images/merge_forward.png',
                label: TIM_t("合并转发"),
                onPressed: () {
                  if (isDesktop) {
                    _handleForwardMessageWide(context, true, model);
                  } else {
                    _handleForwardMessage(context, true, model);
                  }
                },
              ),
            ),
            Expanded(
              child: _actionItem(
                theme: theme,
                iconAsset: 'images/delete.png',
                label: TIM_t("删除"),
                onPressed: () => _confirmDelete(context, theme, model, isDesktop),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDelete(
    BuildContext context,
    TUITheme theme,
    TUIChatSeparateViewModel model,
    bool isDesktop,
  ) {
    if (isDesktop) {
      TUIKitWidePopup.showSecondaryConfirmDialog(
        operationKey: TUIKitWideModalOperationKey.confirmDeleteMessages,
        context: context,
        text: TIM_t("确定删除已选消息"),
        theme: theme,
        onCancel: () {},
        onConfirm: () async {
          model.deleteSelectedMsg();
          model.updateMultiSelectStatus(false);
        },
      );
      return;
    }
    showCupertinoModalPopup<String>(
      context: context,
      builder: (BuildContext context) {
        return CupertinoActionSheet(
          title: Text(TIM_t("确定删除已选消息")),
          cancelButton: CupertinoActionSheetAction(
            onPressed: () => Navigator.pop(context, "cancel"),
            child: Text(TIM_t("取消")),
            isDefaultAction: false,
          ),
          actions: [
            CupertinoActionSheetAction(
              onPressed: () {
                model.deleteSelectedMsg();
                model.updateMultiSelectStatus(false);
                Navigator.pop(context, "cancel");
              },
              child: Text(
                TIM_t("删除"),
                style: TextStyle(color: theme.cautionColor),
              ),
              isDefaultAction: false,
            )
          ],
        );
      },
    );
  }

  Widget _wideActionBar({
    required BuildContext context,
    required TUITheme theme,
    required TUIChatSeparateViewModel model,
  }) {
    return _panelShell(
      theme: theme,
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _actionItem(
            theme: theme,
            iconAsset: 'images/forward.png',
            label: TIM_t("逐条转发"),
            iconSize: 26,
            onPressed: () => _handleForwardMessageWide(context, false, model),
          ),
          const SizedBox(width: 40),
          _actionItem(
            theme: theme,
            iconAsset: 'images/merge_forward.png',
            label: TIM_t("合并转发"),
            iconSize: 26,
            onPressed: () => _handleForwardMessageWide(context, true, model),
          ),
          const SizedBox(width: 40),
          _actionItem(
            theme: theme,
            iconAsset: 'images/delete.png',
            label: TIM_t("删除"),
            iconSize: 26,
            onPressed: () => _confirmDelete(context, theme, model, true),
          ),
          const SizedBox(width: 16),
          IconButton(
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            iconSize: 20,
            onPressed: () => model.updateMultiSelectStatus(false),
            icon: Icon(Icons.close, color: theme.darkTextColor, size: 20),
          ),
        ],
      ),
    );
  }

  @override
  Widget tuiBuild(BuildContext context, TUIKitBuildValue value) {
    final TUITheme theme = value.theme;
    final TUIChatSeparateViewModel model =
        Provider.of<TUIChatSeparateViewModel>(context);
    final isDesktop =
        TUIKitScreenUtils.getFormFactor(context) == DeviceType.Desktop;

    return LayoutBuilder(
      builder: (context, constraints) {
        // 聊天窗口较窄时（分屏/小窗）用等分底栏，避免桌面版 Wrap 横向溢出。
        final useCompact = constraints.maxWidth < 520;
        if (useCompact) {
          return _compactActionBar(
            context: context,
            theme: theme,
            model: model,
            isDesktop: isDesktop,
          );
        }
        if (isDesktop) {
          return _wideActionBar(context: context, theme: theme, model: model);
        }
        return _compactActionBar(
          context: context,
          theme: theme,
          model: model,
          isDesktop: false,
        );
      },
    );
  }
}
