import 'dart:async';

import 'package:flutter/material.dart';
import 'package:tencent_chat_i18n_tool/tencent_chat_i18n_tool.dart';
import 'package:tencent_cloud_chat_sdk/enum/message_status.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_merger_elem.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_merger_elem.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_message.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_message.dart';
import 'package:tencent_cloud_chat_uikit/base_widgets/tim_ui_kit_state.dart';
import 'package:tencent_cloud_chat_uikit/business_logic/separate_models/tui_chat_separate_view_model.dart';
import 'package:tencent_cloud_chat_uikit/business_logic/view_models/tui_chat_global_model.dart';
import 'package:tencent_cloud_chat_uikit/data_services/core/tim_uikit_wide_modal_operation_key.dart';
import 'package:tencent_cloud_chat_uikit/ui/utils/message_jump_highlight.dart';
import 'package:tencent_cloud_chat_uikit/ui/utils/screen_utils.dart';
import 'package:tencent_cloud_chat_uikit/ui/views/TIMUIKitChat/TIMUIKItMessageList/tim_uikit_chat_history_message_list_item.dart';
import 'package:tencent_cloud_chat_uikit/ui/widgets/merger_message_screen.dart';
import 'package:tencent_cloud_chat_uikit/base_widgets/tim_callback.dart';
import 'package:tencent_cloud_chat_uikit/base_widgets/tim_ui_kit_base.dart';
import 'package:tencent_cloud_chat_uikit/ui/widgets/wide_popup.dart';
import 'package:tencent_cloud_chat_uikit/theme/color.dart';
import 'package:tencent_cloud_chat_uikit/theme/tui_theme.dart';
import 'TIMUIKitMessageReaction/tim_uikit_message_reaction_show_panel.dart';

class TIMUIKitMergerElem extends StatefulWidget {
  final V2TimMergerElem mergerElem;
  final String messageID;
  final bool isSelf;
  final bool isShowJump;
  final VoidCallback? clearJump;
  final V2TimMessage message;
  final bool? isShowMessageReaction;
  final TUIChatSeparateViewModel model;
  final MessageItemBuilder? messageItemBuilder;

  const TIMUIKitMergerElem(
      {Key? key,
      required this.message,
      required this.model,
      required this.mergerElem,
      required this.isSelf,
      this.isShowMessageReaction,
      required this.messageID,
      required this.isShowJump,
      this.clearJump,
      this.messageItemBuilder})
      : super(key: key);

  @override
  State<StatefulWidget> createState() => TIMUIKitMergerElemState();
}

class TIMUIKitMergerElemState extends TIMUIKitState<TIMUIKitMergerElem> {
  bool isShowJumpState = false;
  bool isShining = false;
  Timer? _jumpHighlightTimer;
  late ScrollController _scrollController;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
  }

  @override
  void dispose() {
    _jumpHighlightTimer?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  void _showJumpColor() {
    _jumpHighlightTimer = MessageJumpHighlight.play(
      mounted: () => mounted,
      getIsShining: () => isShining,
      setIsShining: (value) => isShining = value,
      setState: setState,
      applyHighlight: (highlighted, {border}) {
        isShowJumpState = highlighted;
      },
      clearJump: () => widget.clearJump?.call(),
      previousTimer: _jumpHighlightTimer,
    );
  }

  String _resolveMergerMessageID() {
    final candidates = <String?>[
      widget.messageID,
      widget.message.msgID,
      widget.message.id,
    ];
    for (final value in candidates) {
      final id = value?.trim() ?? '';
      if (id.isNotEmpty) return id;
    }
    return '';
  }

  _handleTap(BuildContext context, TUIChatSeparateViewModel model) async {
    try {
      final mergerMsgID = _resolveMergerMessageID();
      if (mergerMsgID.isNotEmpty) {
        final isDesktopScreen = TUIKitScreenUtils.getFormFactor(context) == DeviceType.Desktop;

        if (isDesktopScreen) {
          TUIKitWidePopup.showPopupWindow(
            operationKey: TUIKitWideModalOperationKey.mergerMessageList,
            context: context,
            width: MediaQuery.of(context).size.width * 0.7,
            title: TIM_t("聊天记录"),
            height: MediaQuery.of(context).size.height * 0.7,
            child: (onClose) => Scrollbar(
              controller: _scrollController,
              child: wrapMergerMessageScreenWithProviders(
                MergerMessageScreen(
                    messageItemBuilder: widget.messageItemBuilder,
                    model: model,
                    msgID: mergerMsgID,
                    scrollController: _scrollController),
              ),
            ),
          );
        } else {
          Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => wrapMergerMessageScreenWithProviders(
                      MergerMessageScreen(
                          messageItemBuilder: widget.messageItemBuilder,
                          model: model,
                          msgID: mergerMsgID),
                    ),
              ));
        }
      }
    } catch (e) {
      onTIMCallback(TIMCallback(type: TIMCallbackType.INFO, infoRecommendText: TIM_t("无法定位到原消息"), infoCode: 6660401));
    }
  }

  List<String> _getAbstractList() {
    final list = widget.mergerElem.abstractList;
    if (list == null || list.isEmpty) {
      return const [];
    }
    if (list.length <= 4) {
      return list;
    }
    return list.sublist(0, 4);
  }

  @override
  Widget tuiBuild(BuildContext context, TUIKitBuildValue value) {
    final TUITheme theme = value.theme;
    if (widget.isShowJump) {
      if (!isShining) {
        Future.delayed(Duration.zero, () {
          _showJumpColor();
        });
      }
    }
    final isDesktopScreen = TUIKitScreenUtils.getFormFactor(context) == DeviceType.Desktop;
    final abstractLines = _getAbstractList();
    final title = widget.mergerElem.title?.trim().isNotEmpty == true
        ? widget.mergerElem.title!.trim()
        : TIM_t("聊天记录");
    final cardColor = theme.selectPanelBgColor ??
        theme.conversationItemBgColor ??
        Colors.white;
    final titleColor = theme.darkTextColor ?? Colors.black87;
    return Container(
      constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * (isDesktopScreen ? 0.3 : 0.6)),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.only(
          topLeft: widget.isSelf ? const Radius.circular(10) : Radius.zero,
          bottomLeft: const Radius.circular(10),
          topRight: widget.isSelf ? Radius.zero : const Radius.circular(10),
          bottomRight: const Radius.circular(10),
        ),
        border: Border.all(
          color: isShowJumpState
              ? kMessageJumpHighlightColor
              : (theme.weakDividerColor ?? CommonColor.weakDividerColor),
          width: 1,
        ),
      ),
      child: GestureDetector(
        onTap: () {
          _handleTap(context, widget.model);
        },
        child: Container(
          padding: EdgeInsets.fromLTRB(
            12,
            12,
            12,
            widget.isSelf &&
                    widget.model.conversationType == ConvType.c2c &&
                    widget.message.status == MessageStatus.V2TIM_MSG_STATUS_SEND_SUCC
                ? 22
                : 12,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      title,
                      softWrap: true,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.left,
                      maxLines: 1,
                      style: TextStyle(
                        fontSize: 14,
                        color: titleColor,
                      ),
                    ),
                  )
                ],
              ),
              if (abstractLines.isNotEmpty) ...[
                const SizedBox(
                  height: 4,
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.start,
                  children: abstractLines
                      .map(
                        (e) => Row(
                          children: [
                            Expanded(
                              child: Text(
                                e,
                                textAlign: TextAlign.left,
                                softWrap: true,
                                overflow: TextOverflow.ellipsis,
                                maxLines: 2,
                                style: TextStyle(
                                  color: theme.weakTextColor,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ],
                        ),
                      )
                      .toList(),
                ),
              ],
              const SizedBox(
                height: 4,
              ),
              const Divider(),
              Text(
                TIM_t("聊天记录"),
                style: TextStyle(
                  color: theme.weakTextColor,
                  fontSize: 10,
                ),
              ),
              if (widget.isShowMessageReaction ?? true) TIMUIKitMessageReactionShowPanel(message: widget.message)
            ],
          ),
        ),
      ),
    );
  }
}
