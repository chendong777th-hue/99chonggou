import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';
import 'package:tencent_cloud_chat_sdk/enum/message_elem_type.dart';
import 'package:tencent_cloud_chat_sdk/enum/message_status.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_message.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_message.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_message_receipt.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_message_receipt.dart';
import 'package:tencent_cloud_chat_uikit/business_logic/separate_models/tui_chat_separate_view_model.dart';
import 'package:tencent_cloud_chat_uikit/business_logic/view_models/tui_chat_global_model.dart';
import 'package:tencent_cloud_chat_uikit/theme/tui_theme.dart';
import 'package:tencent_cloud_chat_uikit/ui/utils/message_receipt_icon_color.dart';
import 'package:tencent_cloud_chat_uikit/ui/utils/time_ago.dart';

enum MessageBubbleWatermarkStyle {
  /// 图片/视频等深色媒体上的白色水印。
  onDarkMedia,

  /// 文本/卡片等浅色气泡上的半透明水印。
  onLightBubble,
}

/// 气泡右下角时间 + 已读勾（C2C 单勾/双勾）。
class MessageBubbleWatermark extends StatelessWidget {
  const MessageBubbleWatermark({
    super.key,
    required this.message,
    required this.chatModel,
    required this.theme,
    this.style = MessageBubbleWatermarkStyle.onLightBubble,
    this.bubbleColor,
    this.showGradientScrim = false,
  });

  final V2TimMessage message;
  final TUIChatSeparateViewModel chatModel;
  final TUITheme theme;
  final MessageBubbleWatermarkStyle style;
  final Color? bubbleColor;
  final bool showGradientScrim;

  bool get _isSelf => message.isSelf ?? true;

  bool get _canShowReceipt =>
      _isSelf &&
      chatModel.chatConfig.isShowReadingStatus &&
      message.status == MessageStatus.V2TIM_MSG_STATUS_SEND_SUCC;

  Color _resolveTextColor(BuildContext context) {
    if (style == MessageBubbleWatermarkStyle.onDarkMedia) {
      return Colors.white;
    }
    final bg = bubbleColor ??
        (_isSelf
            ? (theme.chatMessageItemFromSelfBgColor ??
                theme.lightPrimaryMaterialColor.shade50)
            : (theme.chatMessageItemFromOthersBgColor ?? Colors.white));
    final isDarkBubble =
        ThemeData.estimateBrightnessForColor(bg) == Brightness.dark;
  if (isDarkBubble) {
      return Colors.white.withValues(alpha: 0.84);
    }
    return (theme.weakTextColor ?? Colors.black).withValues(alpha: 0.72);
  }

  TextStyle _timeStyle(BuildContext context) {
    final color = _resolveTextColor(context);
    return TextStyle(
      color: color,
      fontSize: 11,
      height: 1,
      shadows: style == MessageBubbleWatermarkStyle.onDarkMedia
          ? const [
              Shadow(color: Color(0x66000000), blurRadius: 2),
            ]
          : null,
    );
  }

  Widget? _buildReadWidget(BuildContext context) {
    if (!_canShowReceipt) {
      return null;
    }
    if (chatModel.conversationType == ConvType.c2c) {
      return Selector<TUIChatGlobalModel, bool>(
        selector: (context, global) {
          final receipt = global.getMessageReadReceipt(message.msgID ?? "");
          return (message.isPeerRead ?? false) || (receipt?.isPeerRead ?? false);
        },
        builder: (context, isPeerRead, child) {
          final iconColor = style == MessageBubbleWatermarkStyle.onDarkMedia
              ? Colors.white.withValues(alpha: isPeerRead ? 1.0 : 0.88)
              : MessageReceiptIconColor.resolve(
                  context: context,
                  theme: theme,
                  isPeerRead: isPeerRead,
                );
          return SvgPicture.asset(
            isPeerRead ? 'assets/2.svg' : 'assets/1.svg',
            width: isPeerRead ? 16 : 12,
            height: 10,
            colorFilter: ColorFilter.mode(iconColor, BlendMode.srcIn),
          );
        },
      );
    }
    if (!(message.needReadReceipt ?? false) || !chatModel.canUseReadReceipt) {
      return null;
    }
    return Selector<TUIChatGlobalModel, V2TimMessageReceipt?>(
      selector: (context, global) =>
          global.getMessageReadReceipt(message.msgID ?? ""),
      builder: (context, receipt, child) {
        final readCount = receipt?.readCount ?? 0;
        final unreadCount = receipt?.unreadCount ?? 0;
        if (readCount == 0 && unreadCount == 0) {
          return const SizedBox.shrink();
        }
        final allRead = unreadCount == 0 && readCount > 0;
        final iconColor = style == MessageBubbleWatermarkStyle.onDarkMedia
            ? Colors.white.withValues(alpha: 0.92)
            : (theme.primaryColor ?? Colors.blue).withValues(alpha: 0.85);
        return SvgPicture.asset(
          allRead ? 'assets/2.svg' : 'assets/1.svg',
          width: allRead ? 16 : 12,
          height: 10,
          colorFilter: ColorFilter.mode(iconColor, BlendMode.srcIn),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final timeText = TimeAgo().getTimeForBubble(message.timestamp ?? 0);
    final readWidget = _buildReadWidget(context);

    final metaRow = Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          timeText,
          style: _timeStyle(context),
          maxLines: 1,
          softWrap: false,
        ),
        if (readWidget != null) ...[
          const SizedBox(width: 4),
          readWidget,
        ],
      ],
    );

    if (!showGradientScrim) {
      return IgnorePointer(child: metaRow);
    }

    return IgnorePointer(
      child: Stack(
        fit: StackFit.expand,
        clipBehavior: Clip.none,
        children: [
          const Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: SizedBox(
              height: 42,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Color(0x00000000),
                      Color(0x8C000000),
                    ],
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            right: 8,
            bottom: 6,
            child: metaRow,
          ),
        ],
      ),
    );
  }
}

const Set<String> _selfTimedCustomMessageKeys = <String>{
  'friend_became_friends',
  'group_create',
  'group_tip',
  'red_packet_claim_notice',
  'av_call',
  'rtc_call',
  'contact_card',
  'wallet_transfer',
  'wallet_red_packet',
  'wallet_order',
  'platform_wallet_notice',
};

void _collectCustomMessageKeys(
  Object? source,
  Set<String> keys, {
  int depth = 0,
}) {
  if (source == null || depth > 3) {
    return;
  }
  if (source is String) {
    final trimmed = source.trim();
    if (trimmed.isEmpty) {
      return;
    }
    if (trimmed.startsWith('{') || trimmed.startsWith('[')) {
      try {
        _collectCustomMessageKeys(jsonDecode(trimmed), keys, depth: depth + 1);
      } catch (_) {}
    } else if (_selfTimedCustomMessageKeys.contains(trimmed) ||
        trimmed.contains('av_call') ||
        trimmed.contains('rtc_call')) {
      keys.add(trimmed);
    }
    return;
  }
  if (source is! Map) {
    return;
  }
  for (final entry in source.entries) {
    final key = entry.key.toString().trim();
    final value = entry.value;
    if (key == 'businessID' ||
        key == 'customType' ||
        key == 'type' ||
        key == 'cmd') {
      final text = value?.toString().trim() ?? '';
      if (text.isNotEmpty) {
        keys.add(text);
      }
    }
    _collectCustomMessageKeys(value, keys, depth: depth + 1);
  }
}

bool _customMessageHasSelfTimedLayout(Set<String> keys) {
  for (final key in keys) {
    if (_selfTimedCustomMessageKeys.contains(key)) {
      return true;
    }
    if (key.contains('av_call') || key.contains('rtc_call')) {
      return true;
    }
  }
  return false;
}

bool shouldSkipMessageBubbleWatermark(V2TimMessage message) {
  final elemType = message.elemType;
  if (elemType == MessageElemType.V2TIM_ELEM_TYPE_TEXT ||
      elemType == MessageElemType.V2TIM_ELEM_TYPE_IMAGE ||
      elemType == MessageElemType.V2TIM_ELEM_TYPE_SOUND) {
    return true;
  }
  if (elemType != MessageElemType.V2TIM_ELEM_TYPE_CUSTOM) {
    return false;
  }

  final localRaw = message.localCustomData?.trim() ?? '';
  if (localRaw.contains('localCallBubble')) {
    return true;
  }

  final raw = message.customElem?.data?.trim() ?? '';
  if (raw.isEmpty) {
    return false;
  }

  // Fast path: C2C/group call custom payloads (also catches nested JSON strings).
  if (raw.contains('av_call') ||
      raw.contains('rtc_call') ||
      raw.contains('lk_call') ||
      raw.contains('inviteID') ||
      raw.contains('callId')) {
    return true;
  }

  try {
    final decoded = jsonDecode(raw);
    final keys = <String>{};
    _collectCustomMessageKeys(decoded, keys);
    return _customMessageHasSelfTimedLayout(keys);
  } catch (_) {
    return false;
  }
}

/// 在气泡右下角叠加水印时间（文本/语音/图片/通话卡片自行处理）。
Widget wrapMessageBubbleWithWatermark({
  required Widget child,
  required V2TimMessage message,
  required TUIChatSeparateViewModel model,
  required TUITheme theme,
  Color? bubbleColor,
}) {
  if (shouldSkipMessageBubbleWatermark(message)) {
    return child;
  }

  final elemType = message.elemType;
  final wrappedChild = elemType == MessageElemType.V2TIM_ELEM_TYPE_FACE
      ? Padding(
          padding: const EdgeInsets.only(bottom: 14, right: 2),
          child: child,
        )
      : child;

  return Stack(
    clipBehavior: Clip.hardEdge,
    children: [
      wrappedChild,
      Positioned(
        right: 8,
        bottom: 6,
        child: MessageBubbleWatermark(
          message: message,
          chatModel: model,
          theme: theme,
          bubbleColor: bubbleColor,
        ),
      ),
    ],
  );
}
