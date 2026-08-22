import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:tencent_chat_i18n_tool/tencent_chat_i18n_tool.dart';
import 'package:tencent_cloud_chat_sdk/enum/message_elem_type.dart';
import 'package:tencent_cloud_chat_sdk/enum/message_status.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_message.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_message.dart';
import 'package:tencent_cloud_chat_uikit/business_logic/separate_models/tui_chat_separate_view_model.dart';
import 'package:tencent_cloud_chat_uikit/theme/color.dart';
import 'package:tencent_cloud_chat_uikit/theme/tui_theme.dart';
import 'package:tencent_cloud_chat_uikit/ui/utils/message.dart';
import 'package:tencent_cloud_chat_uikit/ui/utils/message_bubble_text_color.dart';
import 'package:tencent_cloud_chat_uikit/ui/views/TIMUIKitChat/TIMUIKitMessageItem/main.dart';
import 'package:tencent_cloud_chat_uikit/ui/views/TIMUIKitChat/TIMUIKitMessageItem/tim_uikit_chat_face_elem.dart';
import 'package:tencent_cloud_chat_uikit/ui/views/TIMUIKitChat/tim_uikit_cloud_custom_data.dart';

/// 消息气泡内、输入框上方共用的引用消息卡片样式。
class TIMUIKitReplyQuoteCard extends StatelessWidget {
  final String senderLabel;
  final V2TimMessage? contentMessage;
  final MessageRepliedData? fallbackReplyData;
  final TUIChatSeparateViewModel chatModel;
  final TUITheme theme;
  final Color bubbleColor;

  const TIMUIKitReplyQuoteCard({
    super.key,
    required this.senderLabel,
    required this.contentMessage,
    required this.chatModel,
    required this.theme,
    required this.bubbleColor,
    this.fallbackReplyData,
  });

  @override
  Widget build(BuildContext context) {
    final quoteBgColor = MessageBubbleTextColor.quoteBackground(bubbleColor);
    final quoteBorderColor = MessageBubbleTextColor.quoteBorder(bubbleColor);
    final quoteSenderColor = MessageBubbleTextColor.quoteSenderText(
      theme: theme,
      backgroundColor: bubbleColor,
    );
    final quoteContentColor = MessageBubbleTextColor.quoteContentText(
      theme: theme,
      backgroundColor: bubbleColor,
    );

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
      decoration: BoxDecoration(
        color: quoteBgColor,
        borderRadius: BorderRadius.circular(5),
        border: Border(
          left: BorderSide(color: quoteBorderColor, width: 3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "$senderLabel:",
            style: TextStyle(
              fontSize: 12,
              color: quoteSenderColor,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          TIMUIKitReplyQuoteContent.build(
            message: contentMessage,
            fallbackReplyData: fallbackReplyData,
            chatModel: chatModel,
            quoteContentColor: quoteContentColor,
          ),
        ],
      ),
    );
  }
}

class TIMUIKitReplyQuoteContent {
  TIMUIKitReplyQuoteContent._();

  static Widget buildText(String text, Color color, {int maxLines = 2}) {
    return Text(
      text,
      maxLines: maxLines,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
        fontSize: 12,
        height: 1.35,
        color: color,
        fontWeight: FontWeight.w400,
      ),
    );
  }

  static Widget build({
    required V2TimMessage? message,
    required MessageRepliedData? fallbackReplyData,
    required TUIChatSeparateViewModel chatModel,
    required Color quoteContentColor,
  }) {
    if (message == null) {
      return _renderMessageSummary(fallbackReplyData, quoteContentColor);
    }

    if (_isRevoked(message)) {
      final isAdminRevoke = _isAdminRevoke(message);
      return buildText(
        isAdminRevoke ? TIM_t("[消息被管理员撤回]") : TIM_t("[消息被撤回]"),
        quoteContentColor,
      );
    }

    final customAbstractMessage = chatModel.abstractMessageBuilder?.call(message);
    if (customAbstractMessage != null) {
      return buildText(customAbstractMessage, quoteContentColor);
    }

    final isSelf = message.isSelf ?? true;
    switch (message.elemType) {
      case MessageElemType.V2TIM_ELEM_TYPE_CUSTOM:
        return buildText(TIM_t("[自定义]"), quoteContentColor);
      case MessageElemType.V2TIM_ELEM_TYPE_SOUND:
        return buildText(TIM_t("[语音消息]"), quoteContentColor);
      case MessageElemType.V2TIM_ELEM_TYPE_TEXT:
        return buildText(message.textElem?.text ?? "", quoteContentColor);
      case MessageElemType.V2TIM_ELEM_TYPE_FACE:
        return _buildFaceReplyPreview(message, chatModel);
      case MessageElemType.V2TIM_ELEM_TYPE_FILE:
        return TIMUIKitFileElem(
          chatModel: chatModel,
          isShowMessageReaction: false,
          message: message,
          messageID: message.msgID,
          fileElem: message.fileElem,
          isSelf: isSelf,
          isShowJump: false,
        );
      case MessageElemType.V2TIM_ELEM_TYPE_IMAGE:
        return TIMUIKitImageElem(
          chatModel: chatModel,
          message: message,
          isFrom: "reply",
          isShowMessageReaction: false,
        );
      case MessageElemType.V2TIM_ELEM_TYPE_VIDEO:
        return TIMUIKitVideoElem(
          message,
          chatModel: chatModel,
          isFrom: "reply",
          isShowMessageReaction: false,
        );
      case MessageElemType.V2TIM_ELEM_TYPE_LOCATION:
        return buildText(TIM_t("[位置]"), quoteContentColor);
      case MessageElemType.V2TIM_ELEM_TYPE_MERGER:
        return TIMUIKitMergerElem(
          model: chatModel,
          isShowJump: false,
          isShowMessageReaction: false,
          message: message,
          mergerElem: message.mergerElem!,
          messageID: message.msgID ?? "",
          isSelf: isSelf,
        );
      default:
        return _renderMessageSummary(fallbackReplyData, quoteContentColor);
    }
  }

  static Widget _buildFaceReplyPreview(
    V2TimMessage message,
    TUIChatSeparateViewModel chatModel,
  ) {
    final customPreview = chatModel.chatConfig.faceReplyPreviewBuilder?.call(message);
    if (customPreview != null) {
      return Align(
        alignment: Alignment.centerLeft,
        child: customPreview,
      );
    }
    return Align(
      alignment: Alignment.centerLeft,
      child: SizedBox(
        height: 72,
        child: TIMUIKitFaceElem(
          model: chatModel,
          isShowJump: false,
          isShowMessageReaction: false,
          path: message.faceElem?.data ?? "",
          message: message,
        ),
      ),
    );
  }

  static Widget _renderMessageSummary(
    MessageRepliedData? fallbackReplyData,
    Color quoteContentColor,
  ) {
    try {
      final repliedMessageAbstract = RepliedMessageAbstract.fromJson(
        jsonDecode(fallbackReplyData?.messageAbstract ?? ""),
      );
      if (repliedMessageAbstract.elemType == MessageElemType.V2TIM_ELEM_TYPE_FACE) {
        return buildText(
          repliedMessageAbstract.summary ?? TIM_t("[表情消息]"),
          quoteContentColor,
        );
      }
      if (repliedMessageAbstract.summary?.isNotEmpty == true) {
        return buildText(repliedMessageAbstract.summary!, quoteContentColor);
      }
    } catch (_) {
      // fall through
    }
    return buildText(
      fallbackReplyData?.messageAbstract ?? TIM_t("[未知消息]"),
      quoteContentColor,
    );
  }

  static bool _isRevoked(V2TimMessage message) {
    if (message.status == MessageStatus.V2TIM_MSG_STATUS_LOCAL_REVOKED) {
      return true;
    }
    try {
      final customData = jsonDecode(message.cloudCustomData ?? "{}");
      return customData["isRevoke"] == true;
    } catch (_) {
      return false;
    }
  }

  static bool _isAdminRevoke(V2TimMessage message) {
    try {
      final customData = jsonDecode(message.cloudCustomData ?? "{}");
      return customData["revokeByAdmin"] == true;
    } catch (_) {
      return false;
    }
  }
}

/// 键盘上方引用预览，样式与气泡内引用区一致。
class TIMUIKitInputReplyPreview extends StatelessWidget {
  final V2TimMessage repliedMessage;
  final TUIChatSeparateViewModel chatModel;
  final TUITheme theme;
  final Color? backgroundColor;
  final VoidCallback onClose;

  const TIMUIKitInputReplyPreview({
    super.key,
    required this.repliedMessage,
    required this.chatModel,
    required this.theme,
    required this.onClose,
    this.backgroundColor,
  });

  Color _replyBubbleColor() {
    return theme.chatMessageItemFromSelfBgColor ??
        theme.lightPrimaryMaterialColor.shade50;
  }

  @override
  Widget build(BuildContext context) {
    final barColor =
        backgroundColor ?? theme.weakBackgroundColor ?? hexToColor("f5f5f6");
    final closeColor = theme.weakTextColor ?? hexToColor("8f959e");

    return Container(
      color: barColor,
      alignment: Alignment.centerLeft,
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: TIMUIKitReplyQuoteCard(
              senderLabel: MessageUtils.getDisplayName(repliedMessage),
              contentMessage: repliedMessage,
              chatModel: chatModel,
              theme: theme,
              bubbleColor: _replyBubbleColor(),
            ),
          ),
          const SizedBox(width: 8),
          InkWell(
            onTap: onClose,
            child: Icon(Icons.cancel, color: closeColor, size: 18),
          ),
        ],
      ),
    );
  }
}
