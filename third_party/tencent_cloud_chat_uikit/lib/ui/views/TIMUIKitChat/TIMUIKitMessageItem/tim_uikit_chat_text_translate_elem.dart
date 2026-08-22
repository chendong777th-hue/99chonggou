import 'dart:async';
import 'dart:convert';

import 'package:tencent_chat_i18n_tool/tencent_chat_i18n_tool.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_message.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_message.dart';
import 'package:tencent_cloud_chat_uikit/ui/utils/screen_utils.dart';
import 'package:extended_text/extended_text.dart';
import 'package:flutter/material.dart';
import 'package:tencent_cloud_chat_uikit/base_widgets/tim_ui_kit_base.dart';
import 'package:tencent_cloud_chat_uikit/base_widgets/tim_ui_kit_state.dart';
import 'package:tencent_cloud_chat_uikit/business_logic/separate_models/tui_chat_separate_view_model.dart';
import 'package:tencent_cloud_chat_uikit/tencent_cloud_chat_uikit.dart';
import 'package:tencent_cloud_chat_uikit/ui/views/TIMUIKitChat/TIMUIKitTextField/special_text/DefaultSpecialTextSpanBuilder.dart';
import 'package:tencent_cloud_chat_uikit/ui/utils/message_bubble_text_color.dart';
import 'package:tencent_cloud_chat_uikit/ui/utils/message_jump_highlight.dart';
import 'package:tencent_cloud_chat_uikit/ui/utils/deferred_hyperlink_text.dart';
import 'package:tencent_cloud_chat_uikit/ui/utils/message_hyperlink_text_cache.dart';
import 'package:tencent_cloud_chat_uikit/ui/widgets/link_preview/link_preview_entry.dart';
import 'package:tencent_cloud_chat_uikit/ui/widgets/link_preview/models/link_preview_content.dart';

class TIMUIKitTextTranslationElem extends StatefulWidget {
  final V2TimMessage message;
  final bool isFromSelf;
  final bool isShowJump;
  final VoidCallback clearJump;
  final TextStyle? fontStyle;
  final BorderRadius? borderRadius;
  final Color? backgroundColor;
  final EdgeInsetsGeometry? textPadding;
  final TUIChatSeparateViewModel chatModel;
  final bool? isShowMessageReaction;
  final List<CustomEmojiFaceData> customEmojiStickerList;

  const TIMUIKitTextTranslationElem(
      {Key? key,
      required this.message,
      required this.isFromSelf,
      required this.isShowJump,
      required this.clearJump,
      this.fontStyle,
      this.borderRadius,
      this.isShowMessageReaction,
      this.backgroundColor,
      this.textPadding,
      required this.chatModel,
      this.customEmojiStickerList = const []})
      : super(key: key);

  @override
  State<StatefulWidget> createState() => _TIMUIKitTextTranslationElemState();
}

class _TIMUIKitTextTranslationElemState extends TIMUIKitState<TIMUIKitTextTranslationElem> {
  bool isShowJumpState = false;
  bool isShining = false;
  Timer? _jumpHighlightTimer;

  @override
  void dispose() {
    _jumpHighlightTimer?.cancel();
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
      clearJump: widget.clearJump,
      shouldRun: () => (widget.chatModel.jumpMsgID == widget.message.msgID) ||
          !(widget.message.msgID?.isNotEmpty ?? false),
      previousTimer: _jumpHighlightTimer,
    );
  }

  @override
  Widget tuiBuild(BuildContext context, TUIKitBuildValue value) {
    final theme = value.theme;
    final isDesktopScreen = TUIKitScreenUtils.getFormFactor(context) == DeviceType.Desktop;
    final borderRadius = widget.isFromSelf
        ? const BorderRadius.only(
            topLeft: Radius.circular(10),
            topRight: Radius.circular(2),
            bottomLeft: Radius.circular(10),
            bottomRight: Radius.circular(10))
        : const BorderRadius.only(
            topLeft: Radius.circular(2),
            topRight: Radius.circular(10),
            bottomLeft: Radius.circular(10),
            bottomRight: Radius.circular(10));
    if ((widget.chatModel.jumpMsgID == widget.message.msgID)) {}
    if (widget.isShowJump) {
      if (!isShining) {
        Future.delayed(Duration.zero, () {
          _showJumpColor();
        });
      } else {
        if ((widget.chatModel.jumpMsgID == widget.message.msgID) && (widget.message.msgID?.isNotEmpty ?? false)) {
          widget.clearJump();
        }
      }
    }

    final defaultStyle = widget.isFromSelf
        ? (theme.chatMessageItemFromSelfBgColor ?? theme.lightPrimaryMaterialColor.shade50)
        : (theme.chatMessageItemFromOthersBgColor);

    final backgroundColor =
        isShowJumpState ? kMessageJumpHighlightColor : (defaultStyle ?? widget.backgroundColor);

    final bubbleColor = backgroundColor ?? Colors.white;
    final bodyTextStyle = MessageBubbleTextColor.bodyTextStyle(
      theme: theme,
      backgroundColor: bubbleColor,
      fontStyle: widget.fontStyle,
      fontSize: MessageBubbleTextColor.messageBodyFontSize,
      lineHeight: widget.chatModel.chatConfig.textHeight <= 0
          ? MessageBubbleTextColor.messageBodyLineHeight
          : widget.chatModel.chatConfig.textHeight,
    );

    final LocalCustomDataModel localCustomData =
        LocalCustomDataModel.fromMap(json.decode(TencentUtils.checkString(widget.message.localCustomData) ?? "{}"));
    final String? translateText = localCustomData.translatedText;

    final translated = translateText ?? '';
    final messageKey = widget.message.msgID ??
        widget.message.id?.toString() ??
        '${widget.message.timestamp}_tr_${translated.hashCode}';
    final useQQPackage =
        widget.chatModel.chatConfig.stickerPanelConfig?.useQQStickerPackage ??
            true;
    final useTencentCloudChatPackage = widget.chatModel.chatConfig
            .stickerPanelConfig?.useTencentCloudChatStickerPackage ??
        true;
    final useTencentCloudChatPackageOldKeys = widget.chatModel.chatConfig
            .stickerPanelConfig?.useTencentCloudChatStickerPackageOldKeys ??
        false;

    return TencentUtils.checkString(translateText) != null
        ? Container(
            margin: const EdgeInsets.only(top: 6),
            padding: widget.textPadding ??
                MessageBubbleTextColor.messageBubblePadding,
            decoration: BoxDecoration(
              color: backgroundColor,
              borderRadius: widget.borderRadius ?? borderRadius,
              border: MessageBubbleTextColor.othersBubbleBorder(
                isFromSelf: widget.message.isSelf ?? true,
                bubbleBackground: backgroundColor,
              ),
            ),
            constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.7),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // If the [elemType] is text message, it will not be null here.
                // You can render the widget from extension directly, with a [TextStyle] optionally.
                DeferredHyperlinkText(
                  identity: '$messageKey\u0000$translated',
                  displayText: translated,
                  textStyle: bodyTextStyle,
                  isUseQQPackage: useQQPackage,
                  isUseTencentCloudChatPackage: useTencentCloudChatPackage,
                  isUseTencentCloudChatPackageOldKeys:
                      useTencentCloudChatPackageOldKeys,
                  customEmojiStickerList: widget.customEmojiStickerList,
                  buildEnriched: () {
                    if (widget.chatModel.chatConfig.urlPreviewType !=
                        UrlPreviewType.none) {
                      return MessageHyperlinkTextCache.instance.getOrCreate(
                        messageKey: messageKey,
                        messageText: translated,
                        isMarkdown: widget
                            .chatModel.chatConfig.isSupportMarkdownForTextMessage,
                        onLinkTap: widget.chatModel.chatConfig.onTapLink,
                        onTapChatIdMention:
                            widget.chatModel.chatConfig.onTapChatIdMention,
                        isUseQQPackage: useQQPackage,
                        isUseTencentCloudChatPackage: useTencentCloudChatPackage,
                        isUseTencentCloudChatPackageOldKeys:
                            useTencentCloudChatPackageOldKeys,
                        customEmojiStickerList: widget.customEmojiStickerList,
                        isEnableTextSelection: widget
                                .chatModel.chatConfig.isEnableTextSelection ??
                            false,
                      );
                    }
                    return ({TextStyle? style}) => ExtendedText(
                          translateText!,
                          softWrap: true,
                          style: style ?? bodyTextStyle,
                          specialTextSpanBuilder: DefaultSpecialTextSpanBuilder(
                            isUseQQPackage: useQQPackage,
                            isUseTencentCloudChatPackage:
                                useTencentCloudChatPackage,
                            isUseTencentCloudChatPackageOldKeys:
                                useTencentCloudChatPackageOldKeys,
                            customEmojiStickerList: widget.customEmojiStickerList,
                            showAtBackground: true,
                          ),
                        );
                  },
                ),
                const SizedBox(height: 6),
                Row(
                  mainAxisAlignment: MainAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    const Icon(
                      Icons.check_circle,
                      color: Color(0x72282c34),
                      size: 12,
                    ),
                    const SizedBox(
                      width: 4,
                    ),
                    Text(
                      TIM_t("翻译完成"),
                      style: const TextStyle(color: Color(0x72282c34), fontSize: 10),
                    )
                  ],
                )
              ],
            ),
          )
        : const SizedBox(width: 0, height: 0);
  }
}
