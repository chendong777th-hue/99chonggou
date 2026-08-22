import 'package:flutter/material.dart';
import 'package:tencent_cloud_chat_uikit/base_widgets/tim_ui_kit_statelesswidget.dart';
import 'package:tencent_cloud_chat_uikit/base_widgets/tim_ui_kit_base.dart';
import 'package:tencent_cloud_chat_uikit/theme/color.dart';
import 'package:tencent_cloud_chat_uikit/theme/tui_theme.dart';

class UnreadMessage extends TIMUIKitStatelessWidget {
  final int unreadCount;
  final double? width;
  final double? height;

  static const double _fontSize = 11;
  static const FontWeight _fontWeight = FontWeight.w600;
  static const double _horizontalPadding = 6;
  static const double _verticalPadding = 2;
  static const double _minWidth = 20;

  UnreadMessage({
    Key? key,
    required this.unreadCount,
    this.width = 22.0,
    this.height = 22.0,
  }) : super(key: key);

  String generateUnreadText() =>
      unreadCount > 99 ? '99+' : unreadCount.toString();

  @override
  Widget tuiBuild(BuildContext context, TUIKitBuildValue value) {
    final TUITheme theme = value.theme;
    final bgColor = theme.conversationItemUnreadCountBgColor ??
        CommonColor.cautionColor;
    final textColor = theme.conversationItemUnreadCountTextColor ?? Colors.white;

    final unreadText = generateUnreadText();
    if (unreadText == '0') {
      final dotWidth = width ?? 10;
      final dotHeight = height ?? 10;
      return Container(
        width: dotWidth,
        height: dotHeight,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(dotHeight / 2),
          color: bgColor,
        ),
      );
    }

    final minHeight = height ?? 18;
    return Container(
      constraints: BoxConstraints(
        minWidth: _minWidth,
        minHeight: minHeight,
      ),
      padding: const EdgeInsets.symmetric(
        horizontal: _horizontalPadding,
        vertical: _verticalPadding,
      ),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(minHeight / 2),
        color: bgColor,
      ),
      alignment: Alignment.center,
      child: Text(
        unreadText,
        style: TextStyle(
          color: textColor,
          fontSize: _fontSize,
          fontWeight: _fontWeight,
          height: 1.0,
        ),
      ),
    );
  }
}
