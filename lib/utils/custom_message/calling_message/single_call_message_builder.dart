import 'package:flutter/material.dart';
import 'package:tencent_cloud_chat_demo/utils/custom_message/calling_message/call_message_visual.dart';
import 'package:tencent_cloud_chat_demo/utils/custom_message/calling_message/calling_message_data_provider.dart';
import 'package:tencent_cloud_chat_demo/src/services/call_launcher.dart';

class CallMessageItem extends StatelessWidget {
  final CallingMessageDataProvider callingMessageDataProvider;
  final TextStyle? textStyle;
  final TextStyle? timeTextStyle;
  final String timeText;
  final bool isShowIcon;
  final String? contentOverride;
  final Color? backgroundColor;
  final BorderRadius? borderRadius;
  final Border? border;
  final EdgeInsetsGeometry padding;

  const CallMessageItem({
    Key? key,
    required this.callingMessageDataProvider,
    this.textStyle,
    this.timeTextStyle,
    this.timeText = '',
    this.isShowIcon = true,
    this.contentOverride,
    this.backgroundColor,
    this.borderRadius,
    this.border,
    this.padding = const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
  }) : super(key: key);

  double get _contentLineHeight {
    final fontSize = textStyle?.fontSize ?? 16;
    final height = textStyle?.height ?? 1.3;
    return fontSize * height;
  }

  Widget _buildMediaIcon({required bool isOutgoing}) {
    final asset = CallMessageVisual.iconAsset(
      mediaType: callingMessageDataProvider.streamMediaType,
      isOutgoing: isOutgoing,
    );
    return SizedBox(
      height: _contentLineHeight,
      child: Center(
        child: Padding(
          padding: EdgeInsets.only(
            right: isOutgoing ? 0 : 4,
            left: isOutgoing ? 4 : 0,
          ),
          child: Image.asset(
            asset,
            width: 16,
            height: 16,
            fit: BoxFit.contain,
            gaplessPlayback: true,
          ),
        ),
      ),
    );
  }

  void _onTap(BuildContext context) {
    CallLauncher.startC2C(
      context,
      userId: callingMessageDataProvider.callPeerID,
      video: callingMessageDataProvider.streamMediaType ==
          CallStreamMediaType.video,
      conversationId: callingMessageDataProvider.conversationID,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isOutgoing =
        callingMessageDataProvider.direction == CallMessageDirection.outcoming;
    final resolvedTimeText = timeText.trim();
    final resolvedTimeStyle = timeTextStyle ??
        TextStyle(
          fontSize: 11,
          height: 1,
          color: (textStyle?.color ?? Colors.black).withValues(alpha: 0.72),
        );
    final resolvedBorderRadius =
        borderRadius ?? BorderRadius.circular(10);
    final contentText = contentOverride ?? callingMessageDataProvider.content;

    return Semantics(
      label: '通话记录，点击回拨',
      button: true,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _onTap(context),
          borderRadius: resolvedBorderRadius,
          child: Ink(
            decoration: BoxDecoration(
              color: backgroundColor ?? Colors.transparent,
              borderRadius: resolvedBorderRadius,
              border: border,
            ),
            padding: padding,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                if (!isOutgoing && isShowIcon)
                  IgnorePointer(
                    child: _buildMediaIcon(isOutgoing: false),
                  ),
                IgnorePointer(
                  child: Text(
                    contentText,
                    style: textStyle,
                  ),
                ),
                if (isOutgoing && isShowIcon)
                  IgnorePointer(
                    child: _buildMediaIcon(isOutgoing: true),
                  ),
                if (resolvedTimeText.isNotEmpty) ...[
                  const SizedBox(width: 6),
                  IgnorePointer(
                    child: Text(
                      resolvedTimeText,
                      style: resolvedTimeStyle,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
