// ignore_for_file: unused_import

import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:tencent_chat_i18n_tool/tencent_chat_i18n_tool.dart';
import 'package:tencent_cloud_chat_sdk/enum/message_elem_type.dart';
import 'package:tencent_cloud_chat_sdk/enum/message_status.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_message.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_message.dart';
import 'package:tencent_cloud_chat_uikit/business_logic/separate_models/tui_chat_model_tools.dart';
import 'package:tencent_cloud_chat_uikit/ui/utils/common_utils.dart';
import 'package:tencent_cloud_chat_uikit/ui/utils/chat_message_width.dart';
import 'package:tencent_cloud_chat_uikit/ui/utils/platform.dart';
import 'package:tencent_cloud_chat_uikit/ui/utils/screen_utils.dart';
import 'package:tencent_cloud_chat_uikit/ui/views/TIMUIKitChat/TIMUIKitTextField/special_text/DefaultSpecialTextSpanBuilder.dart';
import 'package:extended_text/extended_text.dart';
import 'package:tencent_cloud_chat_uikit/base_widgets/tim_callback.dart';
import 'package:tencent_cloud_chat_uikit/base_widgets/tim_ui_kit_base.dart';
import 'package:tencent_cloud_chat_uikit/base_widgets/tim_ui_kit_state.dart';
import 'package:tencent_cloud_chat_uikit/business_logic/separate_models/tui_chat_separate_view_model.dart';
import 'package:tencent_cloud_chat_uikit/business_logic/view_models/tui_chat_global_model.dart';
import 'package:tencent_cloud_chat_uikit/data_services/services_locatar.dart';
import 'package:tencent_cloud_chat_uikit/theme/tui_theme.dart';
import 'package:tencent_cloud_chat_uikit/ui/views/TIMUIKitChat/TIMUIKitMessageItem/TIMUIKitMessageReaction/tim_uikit_message_reaction_show_panel.dart';
import 'package:tencent_cloud_chat_uikit/ui/views/TIMUIKitChat/TIMUIKitMessageItem/main.dart';
import 'package:tencent_cloud_chat_uikit/ui/views/TIMUIKitChat/TIMUIKitMessageItem/tim_uikit_chat_face_elem.dart';
import 'package:tencent_cloud_chat_uikit/ui/views/TIMUIKitChat/tim_uikit_chat_config.dart';
import 'package:tencent_cloud_chat_uikit/ui/views/TIMUIKitChat/tim_uikit_cloud_custom_data.dart';
import 'package:tencent_cloud_chat_uikit/ui/utils/deferred_hyperlink_text.dart';
import 'package:tencent_cloud_chat_uikit/ui/utils/message_hyperlink_text_cache.dart';
import 'package:tencent_cloud_chat_uikit/ui/widgets/link_preview/link_preview_entry.dart';
import 'package:tencent_cloud_chat_uikit/ui/widgets/link_preview/models/link_preview_content.dart';
import 'package:tencent_cloud_chat_uikit/ui/widgets/link_preview/widgets/link_preview.dart';
import 'package:tencent_cloud_chat_uikit/ui/utils/error_message_converter.dart';
import 'package:tencent_cloud_chat_uikit/ui/utils/logger.dart';
import 'package:tencent_cloud_chat_uikit/ui/utils/message_bubble_text_color.dart';
import 'package:tencent_cloud_chat_uikit/ui/utils/message_jump_highlight.dart';
import 'package:tencent_cloud_chat_uikit/ui/widgets/message_bubble_watermark.dart';
import 'package:tencent_cloud_chat_uikit/ui/widgets/tim_uikit_reply_quote_card.dart';
import 'package:tim_ui_kit_sticker_plugin/utils/tim_custom_face_data.dart';

class TIMUIKitReplyElem extends StatefulWidget {
  final V2TimMessage message;
  final Function scrollToIndex;
  final bool isShowJump;
  final VoidCallback clearJump;
  final TextStyle? fontStyle;
  final BorderRadius? borderRadius;
  final Color? backgroundColor;
  final EdgeInsetsGeometry? textPadding;
  final TUIChatSeparateViewModel chatModel;
  final bool? isShowMessageReaction;
  final List<CustomEmojiFaceData> customEmojiStickerList;

  const TIMUIKitReplyElem({
    Key? key,
    required this.message,
    required this.scrollToIndex,
    this.isShowJump = false,
    required this.clearJump,
    this.fontStyle,
    this.borderRadius,
    this.isShowMessageReaction,
    this.backgroundColor,
    this.textPadding,
    this.customEmojiStickerList = const [],
    required this.chatModel,
  }) : super(key: key);

  @override
  State<StatefulWidget> createState() => _TIMUIKitReplyElemState();
}

class _TIMUIKitReplyElemState extends TIMUIKitState<TIMUIKitReplyElem> {
  MessageRepliedData? repliedMessage;
  V2TimMessage? rawMessage;
  bool isShowJumpState = false;
  bool isShining = false;
  Timer? _jumpHighlightTimer;

  MessageRepliedData? _getRepliedMessage() {
    try {
      final CloudCustomData messageCloudCustomData = CloudCustomData.fromJson(json.decode(
          TencentUtils.checkString(widget.message.cloudCustomData) != null ? widget.message.cloudCustomData! : "{}"));
      if (messageCloudCustomData.messageReply != null) {
        final MessageRepliedData repliedMessage = MessageRepliedData.fromJson(messageCloudCustomData.messageReply!);
        return repliedMessage;
      }
      return null;
    } catch (error) {
      return null;
    }
  }

  _getMessageByMessageID() async {
    final MessageRepliedData? cloudCustomData = _getRepliedMessage();
    if (cloudCustomData != null) {
      if (mounted) {
        setState(() {
          repliedMessage = cloudCustomData;
        });
      }

      final messageID = cloudCustomData.messageID;
      if (PlatformUtils().isWeb) {
        return;
      }
      V2TimMessage? message = await widget.chatModel.findMessage(messageID);
      if (message == null) {
        try {
          final RepliedMessageAbstract repliedMessageAbstract =
              RepliedMessageAbstract.fromJson(jsonDecode(cloudCustomData.messageAbstract));
          if (repliedMessageAbstract.isNotEmpty) {
            message = V2TimMessage(
                elemType: 0,
                seq: repliedMessageAbstract.seq,
                timestamp: repliedMessageAbstract.timestamp,
                msgID: repliedMessageAbstract.msgID);
          }
        } catch (e) {
          // ignore: avoid_print
          outputLogger.i(e.toString());
        }
      }
      if (message != null) {
        if (mounted) {
          setState(() {
            rawMessage = message;
          });
        }
      }
    }
  }

  @override
  void initState() {
    _getMessageByMessageID();
    super.initState();
  }

  @override
  void didUpdateWidget(covariant TIMUIKitReplyElem oldWidget) {
    WidgetsBinding.instance.addPostFrameCallback((mag) {
      super.didUpdateWidget(oldWidget);
      _getMessageByMessageID();
    });
  }

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

  void _jumpToRawMsg() {
    if (rawMessage?.status != MessageStatus.V2TIM_MSG_STATUS_LOCAL_REVOKED && rawMessage?.timestamp != null) {
      widget.scrollToIndex(rawMessage);
    } else {
      onTIMCallback(TIMCallback(type: TIMCallbackType.INFO, infoRecommendText: TIM_t("无法定位到原消息")));
    }
  }

  Widget _buildInlineMeta(BuildContext context, TUITheme theme, Color? bubbleColor) {
    return MessageBubbleWatermark(
      message: widget.message,
      chatModel: widget.chatModel,
      theme: theme,
      bubbleColor: bubbleColor,
    );
  }

  bool _shouldPlaceMetaOnNewLine(
    BuildContext context,
    TextStyle textStyle,
    bool isDesktopScreen,
    Color? bubbleColor,
  ) {
    final rawText = ErrorMessageConverter.localizeMessageText(
      widget.message.textElem?.text ?? '',
    );
    if (rawText.isEmpty) {
      return false;
    }
    if (rawText.contains('\n')) {
      return true;
    }

    final maxBubbleWidth = chatMessageMaxWidth(
      context,
      desktopMaxWidth: 380,
      desktopMinWidth: 240,
      desktopFactor: 0.44,
      mobileFactor: 0.70,
    );
    final horizontalPadding =
        MessageBubbleTextColor.messageBubblePaddingHorizontal * 2;
    final isFromSelf = widget.message.isSelf ?? true;
    final inlineMetaWidth = isFromSelf &&
            widget.chatModel.conversationType == ConvType.c2c &&
            widget.chatModel.chatConfig.isShowReadingStatus
        ? 58.0
        : (isFromSelf &&
                widget.chatModel.chatConfig.isShowReadingStatus &&
                (widget.message.needReadReceipt ?? false) &&
                widget.chatModel.canUseReadReceipt
            ? 58.0
            : 40.0);

    final textPainter = TextPainter(
      text: TextSpan(text: rawText, style: textStyle),
      textDirection: Directionality.of(context),
      maxLines: null,
    )..layout(
        maxWidth: maxBubbleWidth - horizontalPadding - inlineMetaWidth,
      );

    return textPainter.computeLineMetrics().length > 1;
  }

  Widget? _renderPreviewWidget(Color bubbleColor) {
    // If the link preview info from [localCustomData] is available, use it to render the preview card.
    // Otherwise, it will returns null.
    if (widget.message.localCustomData != null && widget.message.localCustomData!.isNotEmpty) {
      try {
        final String localJSON = widget.message.localCustomData!;
        final LocalCustomDataModel? localPreviewInfo = LocalCustomDataModel.fromMap(json.decode(localJSON));
        if (localPreviewInfo != null && !localPreviewInfo.isLinkPreviewEmpty()) {
          return Container(
            margin: const EdgeInsets.only(top: 8),
            child:
                // You can use this default widget [LinkPreviewWidget] to render preview card, or you can use custom widget.
                LinkPreviewWidget(
                  linkPreview: localPreviewInfo,
                  bubbleBackgroundColor: bubbleColor,
                ),
          );
        } else {
          return null;
        }
      } catch (e) {
        return null;
      }
    } else {
      return null;
    }
  }

  @override
  Widget tuiBuild(BuildContext context, TUIKitBuildValue value) {
    final theme = value.theme;
    final isDesktopScreen = TUIKitScreenUtils.getFormFactor(context) == DeviceType.Desktop;
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

    final isFromSelf = widget.message.isSelf ?? true;

    final defaultStyle = isFromSelf
        ? (theme.chatMessageItemFromSelfBgColor ?? theme.lightPrimaryMaterialColor.shade50)
        : (theme.chatMessageItemFromOthersBgColor);

    final backgroundColor =
        isShowJumpState ? kMessageJumpHighlightColor : (defaultStyle ?? widget.backgroundColor);

    final bubbleColor = backgroundColor ?? Colors.white;
    final borderRadius = isFromSelf
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
    final displayText = ErrorMessageConverter.localizeMessageText(
      widget.message.textElem?.text ?? '',
    );
    final messageKey = widget.message.msgID ??
        widget.message.id?.toString() ??
        '${widget.message.timestamp}_${displayText.hashCode}';
    final useQQPackage =
        widget.chatModel.chatConfig.stickerPanelConfig?.useQQStickerPackage ??
            true;
    final useTencentCloudChatPackage = widget.chatModel.chatConfig
            .stickerPanelConfig?.useTencentCloudChatStickerPackage ??
        true;
    final useTencentCloudChatPackageOldKeys = widget.chatModel.chatConfig
            .stickerPanelConfig?.useTencentCloudChatStickerPackageOldKeys ??
        false;
    final textStyle = MessageBubbleTextColor.bodyTextStyle(
      theme: theme,
      backgroundColor: bubbleColor,
      fontStyle: widget.fontStyle,
      fontSize: MessageBubbleTextColor.messageBodyFontSize,
      lineHeight: widget.chatModel.chatConfig.textHeight <= 0
          ? MessageBubbleTextColor.messageBodyLineHeight
          : widget.chatModel.chatConfig.textHeight,
    );
    final replyTextWidget = DeferredHyperlinkText(
      identity: '$messageKey\u0000$displayText',
      displayText: displayText,
      textStyle: textStyle,
      isUseQQPackage: useQQPackage,
      isUseTencentCloudChatPackage: useTencentCloudChatPackage,
      isUseTencentCloudChatPackageOldKeys: useTencentCloudChatPackageOldKeys,
      customEmojiStickerList: widget.customEmojiStickerList,
      buildEnriched: () {
        if (widget.chatModel.chatConfig.urlPreviewType != UrlPreviewType.none) {
          return MessageHyperlinkTextCache.instance.getOrCreate(
            messageKey: messageKey,
            messageText: displayText,
            isMarkdown:
                widget.chatModel.chatConfig.isSupportMarkdownForTextMessage,
            onLinkTap: widget.chatModel.chatConfig.onTapLink,
            onTapChatIdMention: widget.chatModel.chatConfig.onTapChatIdMention,
            isUseQQPackage: useQQPackage,
            isUseTencentCloudChatPackage: useTencentCloudChatPackage,
            isUseTencentCloudChatPackageOldKeys:
                useTencentCloudChatPackageOldKeys,
            customEmojiStickerList: widget.customEmojiStickerList,
            isEnableTextSelection:
                widget.chatModel.chatConfig.isEnableTextSelection ?? false,
          );
        }
        return ({TextStyle? style}) => ExtendedText(
              displayText,
              softWrap: true,
              style: style ?? textStyle,
              specialTextSpanBuilder: DefaultSpecialTextSpanBuilder(
                isUseQQPackage: useQQPackage,
                isUseTencentCloudChatPackage: useTencentCloudChatPackage,
                isUseTencentCloudChatPackageOldKeys:
                    useTencentCloudChatPackageOldKeys,
                customEmojiStickerList: widget.customEmojiStickerList,
                showAtBackground: true,
              ),
            );
      },
    );
    final shouldPlaceMetaOnNewLine = _shouldPlaceMetaOnNewLine(
          context,
          textStyle,
          isDesktopScreen,
          backgroundColor,
        );
    final replyBodyWithMeta = shouldPlaceMetaOnNewLine
        ? replyTextWidget
        : Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Flexible(child: replyTextWidget),
              const SizedBox(width: 6),
              _buildInlineMeta(context, theme, backgroundColor),
            ],
          );
    return Container(
      padding: widget.textPadding ?? MessageBubbleTextColor.messageBubblePadding,
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: widget.borderRadius ?? borderRadius,
        border: MessageBubbleTextColor.othersBubbleBorder(
          isFromSelf: isFromSelf,
          bubbleBackground: backgroundColor,
        ),
      ),
      constraints: BoxConstraints(
        maxWidth: chatMessageMaxWidth(
          context,
          desktopMaxWidth: 380,
          desktopMinWidth: 240,
          desktopFactor: 0.44,
          mobileFactor: 0.70,
        ),
      ),
      child: GestureDetector(
        onTap: _jumpToRawMsg,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TIMUIKitReplyQuoteCard(
              senderLabel: repliedMessage?.messageSender ?? "",
              contentMessage: rawMessage,
              fallbackReplyData: repliedMessage,
              chatModel: widget.chatModel,
              theme: theme,
              bubbleColor: bubbleColor,
            ),
            const SizedBox(
              height: 12,
            ),
            replyBodyWithMeta,
            if (shouldPlaceMetaOnNewLine)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                // 引用气泡正文 Column 为 start；时间/已读仍须贴右下角。
                child: Align(
                  alignment: Alignment.centerRight,
                  child: _buildInlineMeta(context, theme, backgroundColor),
                ),
              ),
            // If the link preview info is available, render the preview card.
            if (_renderPreviewWidget(bubbleColor) != null &&
                widget.chatModel.chatConfig.urlPreviewType == UrlPreviewType.previewCardAndHyperlink)
              _renderPreviewWidget(bubbleColor)!,
            if (widget.isShowMessageReaction ?? true) TIMUIKitMessageReactionShowPanel(message: widget.message)
          ],
        ),
      ),
    );
  }
}
