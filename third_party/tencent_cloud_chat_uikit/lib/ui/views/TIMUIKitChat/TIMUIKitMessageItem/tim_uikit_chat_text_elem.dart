import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';
import 'package:tencent_cloud_chat_sdk/enum/message_status.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_message.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_message.dart';
import 'package:tencent_cloud_chat_uikit/ui/utils/screen_utils.dart';
import 'package:extended_text/extended_text.dart';
import 'package:tencent_cloud_chat_uikit/base_widgets/tim_ui_kit_base.dart';
import 'package:tencent_cloud_chat_uikit/base_widgets/tim_ui_kit_state.dart';
import 'package:tencent_cloud_chat_uikit/business_logic/separate_models/tui_chat_separate_view_model.dart';
import 'package:tencent_cloud_chat_uikit/business_logic/view_models/tui_chat_global_model.dart';
import 'package:tencent_cloud_chat_uikit/tencent_cloud_chat_uikit.dart';
import 'package:tencent_cloud_chat_uikit/ui/utils/error_message_converter.dart';
import 'package:tencent_cloud_chat_uikit/ui/utils/chat_message_height_cache.dart';
import 'package:tencent_cloud_chat_uikit/ui/utils/chat_message_width.dart';
import 'package:tencent_cloud_chat_uikit/ui/utils/message_bubble_text_color.dart';
import 'package:tencent_cloud_chat_uikit/ui/utils/message_jump_highlight.dart';
import 'package:tencent_cloud_chat_uikit/ui/utils/message_receipt_icon_color.dart';
import 'package:tencent_cloud_chat_uikit/ui/utils/outgoing_message_display.dart';
import 'package:tencent_cloud_chat_uikit/ui/utils/time_ago.dart';
import 'package:tencent_cloud_chat_uikit/ui/views/TIMUIKitChat/TIMUIKitTextField/special_text/chat_id_mention_text.dart';
import 'package:tencent_cloud_chat_uikit/ui/views/TIMUIKitChat/TIMUIKitTextField/special_text/DefaultSpecialTextSpanBuilder.dart';
import 'package:tencent_cloud_chat_uikit/ui/widgets/link_preview/common/utils.dart';
import 'package:tencent_cloud_chat_uikit/ui/utils/deferred_hyperlink_text.dart';
import 'package:tencent_cloud_chat_uikit/ui/utils/message_hyperlink_text_cache.dart';
import 'package:tencent_cloud_chat_uikit/ui/widgets/link_preview/link_preview_entry.dart';
import 'package:tencent_cloud_chat_uikit/ui/widgets/link_preview/widgets/link_preview.dart';
import 'TIMUIKitMessageReaction/tim_uikit_message_reaction_show_panel.dart';

abstract final class _ChatUiTokens {
  static const Color surfaceAltLight = Color(0xFFF1F3F5);
  static const double s2 = 4;
  static const double rMd = 12;
}

class TIMUIKitTextElem extends StatefulWidget {
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

  const TIMUIKitTextElem(
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
  State<StatefulWidget> createState() => _TIMUIKitTextElemState();
}

class _TIMUIKitTextElemState extends TIMUIKitState<TIMUIKitTextElem> {
  bool isShowJumpState = false;
  bool isShining = false;
  Timer? _jumpHighlightTimer;
  final GlobalKey _bubbleMeasureKey = GlobalKey();
  double? _lastRememberedHeight;

  @override
  void initState() {
    super.initState();
    // get the link preview info
    _getLinkPreview();
  }

  @override
  void didUpdateWidget(TIMUIKitTextElem oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.message.msgID == null && widget.message.msgID != null) {
      _getLinkPreview();
    }
  }

  @override
  void dispose() {
    _jumpHighlightTimer?.cancel();
    super.dispose();
  }

  void _rememberBubbleHeightIfNeeded() {
    final box =
        _bubbleMeasureKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) {
      return;
    }
    final height = box.size.height;
    if (_lastRememberedHeight != null &&
        (_lastRememberedHeight! - height).abs() < 0.5) {
      return;
    }
    _lastRememberedHeight = height;
    ChatMessageHeightCache.instance.remember(widget.message, height);
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
      shouldRun: () =>
          (widget.chatModel.jumpMsgID == widget.message.msgID) ||
          !(widget.message.msgID?.isNotEmpty ?? false),
      previousTimer: _jumpHighlightTimer,
    );
  }

  // get the link preview info
  _getLinkPreview() {
    if (widget.chatModel.chatConfig.urlPreviewType !=
        UrlPreviewType.previewCardAndHyperlink) {
      return;
    }
    try {
      if (widget.message.localCustomData != null &&
          widget.message.localCustomData!.isNotEmpty) {
        final String localJSON = widget.message.localCustomData!;
        final LocalCustomDataModel? localPreviewInfo =
            LocalCustomDataModel.fromMap(json.decode(localJSON));
        // If [localCustomData] is not empty, check if the link preview info exists
        if (localPreviewInfo == null || localPreviewInfo.isLinkPreviewEmpty()) {
          // If not exists, get it
          _initLinkPreview();
        }
      } else {
        // It [localCustomData] is empty, get the link info
        _initLinkPreview();
      }
    } catch (e) {
      return null;
    }
  }

  Future<void> _initLinkPreview() async {
    // Get the link preview info from extension, let it update the message UI automatically by providing a [onUpdateMessage].
    // The `onUpdateMessage` can use the `updateMessage()` from the [TIMUIKitChatController] directly.
    final originalMsgID = widget.message.msgID;
    final originalText = widget.message.textElem?.text;
    try {
      await LinkPreviewEntry.getFirstLinkPreviewContent(
        message: widget.message,
        onUpdateMessage: (message) {
          if (!mounted ||
              widget.message.msgID != originalMsgID ||
              widget.message.textElem?.text != originalText) {
            return;
          }
          final msgID = widget.message.msgID;
          if (msgID != null) {
            widget.chatModel.updateMessageFromController(
              msgID: msgID,
              message: message,
            );
          }
        },
      );
    } catch (_) {
      // Preview cards are best-effort; text and hyperlink rendering must not fail.
    }
  }

  Widget? _renderPreviewWidget(Color bubbleColor) {
    // If the link preview info from [localCustomData] is available, use it to render the preview card.
    // Otherwise, it will returns null.
    if (widget.message.localCustomData != null &&
        widget.message.localCustomData!.isNotEmpty) {
      try {
        final String localJSON = widget.message.localCustomData!;
        final LocalCustomDataModel? localPreviewInfo =
            LocalCustomDataModel.fromMap(json.decode(localJSON));
        if (localPreviewInfo != null &&
            !localPreviewInfo.isLinkPreviewEmpty()) {
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

  int _effectiveMessageStatus(BuildContext context) {
    final fallback =
        widget.message.status ?? MessageStatus.V2TIM_MSG_STATUS_SEND_SUCC;
    if (!widget.isFromSelf) {
      return fallback;
    }
    return context.select<TUIChatGlobalModel, int>((globalModel) {
      globalModel.messageListRevisionFor(widget.chatModel.conversationID);
      return globalModel.messageStatusInConversation(
        widget.chatModel.conversationID,
        clientId: widget.message.id,
        msgID: widget.message.msgID,
        fallback: fallback,
        elemType: widget.message.elemType,
      );
    });
  }

  Widget _buildInlineMeta(
    BuildContext context,
    TUIKitBuildValue value, {
    Color? metaBackground,
    int? liveStatus,
  }) {
    final theme = value.theme;
    final effectiveStatus = liveStatus ?? _effectiveMessageStatus(context);
    final timeText = TimeAgo().getTimeForBubble(widget.message.timestamp ?? 0);
    final bubbleColor = metaBackground ??
        (widget.isFromSelf
            ? (theme.chatMessageItemFromSelfBgColor ??
                theme.lightPrimaryMaterialColor.shade50)
            : (theme.chatMessageItemFromOthersBgColor ??
                _ChatUiTokens.surfaceAltLight));
    final Color baseColor = MessageBubbleTextColor.metaText(
      theme: theme,
      backgroundColor: bubbleColor,
      overrideColor: widget.fontStyle?.color,
    );
    final textStyle = TextStyle(
      fontSize: 11,
      height: 1,
      color: baseColor,
    );
    if (!widget.isFromSelf ||
        widget.chatModel.conversationType == ConvType.group) {
      return Text(timeText, style: textStyle);
    }

    final canShowC2CReceipt =
        widget.chatModel.conversationType == ConvType.c2c &&
            widget.chatModel.chatConfig.isShowReadingStatus;

    if (canShowC2CReceipt) {
      return Selector<TUIChatGlobalModel, bool>(
        selector: (context, model) {
          model.messageListRevisionFor(widget.chatModel.conversationID);
          return model.isOutgoingC2CMessagePeerRead(
            conversationID: widget.chatModel.conversationID,
            message: widget.message,
          );
        },
        builder: (context, isPeerRead, child) {
          return _buildMetaRow(
            context: context,
            theme: theme,
            textStyle: textStyle,
            timeText: timeText,
            isPeerRead: isPeerRead,
            status: effectiveStatus,
          );
        },
      );
    }

    return _buildMetaRow(
      context: context,
      theme: theme,
      textStyle: textStyle,
      timeText: timeText,
      isPeerRead: false,
      status: effectiveStatus,
    );
  }

  Widget _buildMetaRow({
    required BuildContext context,
    required dynamic theme,
    required TextStyle textStyle,
    required String timeText,
    required bool isPeerRead,
    required int status,
  }) {
    final showCheck = OutgoingMessageDisplay.shouldShowDeliveryCheck(
      status: status,
    );

    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          timeText,
          style: textStyle,
          maxLines: 1,
          softWrap: false,
        ),
        const SizedBox(width: 4),
        SizedBox(
          width: isPeerRead ? 16 : 12,
          height: 10,
          child: showCheck
              ? Align(
                  alignment: Alignment.center,
                  child: SvgPicture.asset(
                    isPeerRead ? 'assets/2.svg' : 'assets/1.svg',
                    width: isPeerRead ? 16 : 12,
                    height: 10,
                    colorFilter: ColorFilter.mode(
                      MessageReceiptIconColor.resolve(
                        context: context,
                        theme: theme,
                        isPeerRead: isPeerRead,
                      ),
                      BlendMode.srcIn,
                    ),
                  ),
                )
              : const SizedBox.shrink(),
        ),
      ],
    );
  }

  bool _shouldPlaceMetaOnNewLine(
    BuildContext context,
    TextStyle textStyle,
    bool isDesktopScreen,
  ) {
    final rawText = ErrorMessageConverter.localizeMessageText(
        widget.message.textElem?.text ?? "");
    if (rawText.isEmpty) {
      return false;
    }
    if (rawText.contains('\n')) {
      return true;
    }

    final textScaler = MediaQuery.textScalerOf(context);
    final maxBubbleWidth = chatMessageMaxWidth(
      context,
      desktopMaxWidth: 420,
      desktopMinWidth: 240,
      desktopFactor: 0.46,
      mobileFactor: 0.70,
    );
    final horizontalPadding =
        MessageBubbleTextColor.messageBubblePaddingHorizontal * 2;
    final inlineMetaWidth = widget.isFromSelf &&
            widget.chatModel.conversationType == ConvType.c2c &&
            widget.chatModel.chatConfig.isShowReadingStatus
        ? 58.0
        : 40.0;
    const inlineMetaGap = 6.0;

    // 先用气泡内容区的完整宽度排版，判断正文本身是否多行。
    final contentMaxWidth = maxBubbleWidth - horizontalPadding;
    final textPainter = TextPainter(
      text: TextSpan(text: rawText, style: textStyle),
      textDirection: Directionality.of(context),
      textScaler: textScaler,
      maxLines: null,
    )..layout(maxWidth: contentMaxWidth);

    if (textPainter.computeLineMetrics().length > 1) {
      return true;
    }

    // 单行时，再判断「正文 + 间距 + 时间戳/已读」是否仍放得下一行。
    final safetyMargin = 4.0 * textScaler.scale(1.0);
    return textPainter.size.width + inlineMetaGap + inlineMetaWidth >
        contentMaxWidth - safetyMargin;
  }

  @override
  Widget tuiBuild(BuildContext context, TUIKitBuildValue value) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _rememberBubbleHeightIfNeeded();
      }
    });
    final theme = value.theme;
    final isDesktopScreen =
        TUIKitScreenUtils.getFormFactor(context) == DeviceType.Desktop;
    final displayText = ErrorMessageConverter.localizeMessageText(
        widget.message.textElem?.text ?? "");
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
    final borderRadius = widget.isFromSelf
        ? const BorderRadius.only(
            topLeft: Radius.circular(_ChatUiTokens.rMd),
            topRight: Radius.circular(_ChatUiTokens.s2),
            bottomLeft: Radius.circular(_ChatUiTokens.rMd),
            bottomRight: Radius.circular(_ChatUiTokens.rMd),
          )
        : const BorderRadius.only(
            topLeft: Radius.circular(_ChatUiTokens.s2),
            topRight: Radius.circular(_ChatUiTokens.rMd),
            bottomLeft: Radius.circular(_ChatUiTokens.rMd),
            bottomRight: Radius.circular(_ChatUiTokens.rMd),
          );
    if ((widget.chatModel.jumpMsgID == widget.message.msgID)) {}
    if (widget.isShowJump) {
      if (!isShining) {
        Future.delayed(Duration.zero, () {
          _showJumpColor();
        });
      } else {
        if ((widget.chatModel.jumpMsgID == widget.message.msgID) &&
            (widget.message.msgID?.isNotEmpty ?? false)) {
          widget.clearJump();
        }
      }
    }

    final defaultStyle = widget.isFromSelf
        ? (theme.chatMessageItemFromSelfBgColor ??
            theme.lightPrimaryMaterialColor.shade50)
        : (theme.chatMessageItemFromOthersBgColor ??
            _ChatUiTokens.surfaceAltLight);

    final backgroundColor = isShowJumpState
        ? kMessageJumpHighlightColor
        : (widget.backgroundColor ?? defaultStyle);

    final bubbleColor = backgroundColor;
    const bodyFontSize = MessageBubbleTextColor.messageBodyFontSize;
    final configuredTextHeight = widget.chatModel.chatConfig.textHeight;
    final compactTextHeight = configuredTextHeight <= 0
        ? MessageBubbleTextColor.messageBodyLineHeight
        : configuredTextHeight.clamp(1.16, 1.22).toDouble();
    final textStyle = MessageBubbleTextColor.bodyTextStyle(
      theme: theme,
      backgroundColor: bubbleColor,
      fontStyle: widget.fontStyle,
      fontSize: bodyFontSize,
      lineHeight: compactTextHeight,
    );
    final liveStatus = _effectiveMessageStatus(context);
    final textWidget = DeferredHyperlinkText(
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
              widget.chatModel.chatConfig.onTapChatIdMention != null
                  ? LinkUtils.wrapChatIdMentionsForExtendedText(displayText)
                  : displayText,
              softWrap: true,
              style: style ?? textStyle,
              onSpecialTextTap: (dynamic parameter) {
                final raw = parameter.toString();
                if (raw.startsWith(ChatIdMentionText.flag)) {
                  final mention = raw.replaceAll(ChatIdMentionText.flag, '');
                  widget.chatModel.chatConfig.onTapChatIdMention
                      ?.call(ChatIdMentionText.parseRawId(mention));
                }
              },
              specialTextSpanBuilder: DefaultSpecialTextSpanBuilder(
                isUseQQPackage: useQQPackage,
                isUseTencentCloudChatPackage: useTencentCloudChatPackage,
                isUseTencentCloudChatPackageOldKeys:
                    useTencentCloudChatPackageOldKeys,
                customEmojiStickerList: widget.customEmojiStickerList,
                showAtBackground: true,
                checkHttpLink: true,
                checkChatIdMention:
                    widget.chatModel.chatConfig.onTapChatIdMention != null,
                onTapChatIdMention:
                    widget.chatModel.chatConfig.onTapChatIdMention,
              ),
            );
      },
    );
    final shouldPlaceMetaOnNewLine =
        _shouldPlaceMetaOnNewLine(context, textStyle, isDesktopScreen);

    final bubbleBody = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment:
          widget.isFromSelf ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: [
        shouldPlaceMetaOnNewLine
            ? textWidget
            : Row(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  textWidget,
                  const SizedBox(width: 6),
                  _buildInlineMeta(
                    context,
                    value,
                    metaBackground: bubbleColor,
                    liveStatus: liveStatus,
                  ),
                ],
              ),
        if (widget.chatModel.chatConfig.urlPreviewType ==
            UrlPreviewType.previewCardAndHyperlink)
          if (_renderPreviewWidget(bubbleColor) case final previewWidget?)
            previewWidget,
        if (shouldPlaceMetaOnNewLine)
          Padding(
            padding: const EdgeInsets.only(top: 2),
            // 对方多行气泡 Column 为 start 对齐；时间/已读仍须贴右下角。
            child: Align(
              alignment: Alignment.centerRight,
              child: _buildInlineMeta(
                context,
                value,
                metaBackground: bubbleColor,
                liveStatus: liveStatus,
              ),
            ),
          ),
        if (widget.isShowMessageReaction ?? true)
          TIMUIKitMessageReactionShowPanel(message: widget.message)
      ],
    );

    return IntrinsicWidth(
      child: Container(
        key: _bubbleMeasureKey,
        padding: widget.textPadding ??
            MessageBubbleTextColor.messageBubblePadding,
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: widget.borderRadius ?? borderRadius,
          border: MessageBubbleTextColor.othersBubbleBorder(
            isFromSelf: widget.isFromSelf,
            bubbleBackground: backgroundColor,
          ),
        ),
        constraints: BoxConstraints(
          maxWidth: chatMessageMaxWidth(
            context,
            desktopMaxWidth: 420,
            desktopMinWidth: 240,
            desktopFactor: 0.46,
            mobileFactor: 0.70,
          ),
        ),
        child: bubbleBody,
      ),
    );
  }
}
