import 'package:flutter/material.dart';
import 'package:tencent_chat_i18n_tool/tencent_chat_i18n_tool.dart';
import 'package:tencent_cloud_chat_uikit/base_widgets/tim_ui_kit_statelesswidget.dart';
import 'package:tencent_cloud_chat_uikit/base_widgets/tim_ui_kit_base.dart';
import 'tim_uikit_chat_history_message_list_tongue.dart';

class TIMUIKitTongueItem extends TIMUIKitStatelessWidget {
  /// the callback after clicking
  final VoidCallback onClick;

  /// the value type currently
  final MessageListTongueType valueType;

  /// unread amount currently
  final int unreadCount;

  /// total amount of messages at me
  final String atNum;

  final int previousCount;

  TIMUIKitTongueItem({
    Key? key,
    required this.onClick,
    required this.valueType,
    required this.previousCount,
    required this.unreadCount,
    required this.atNum,
  }) : super(key: key);

  String _formatCount(int count) {
    if (count > 99) {
      return '99+';
    }
    return count.toString();
  }

  Map<MessageListTongueType, String> textType(BuildContext context) {
    final option1 = _formatCount(unreadCount);
    final option2 = atNum.toString();
    final option3 = _formatCount(previousCount);
    final String atMeString = option2 != ""
        ? TIM_t_para("有{{option2}}条@我消息", "有$option2条@我消息")(option2: option2)
        : TIM_t("有人@我");

    return {
      MessageListTongueType.showPrevious:
          TIM_t_para("{{option3}}条新消息", "$option3条新消息")(option3: option3),
      MessageListTongueType.toLatest: TIM_t("回到底部"),
      MessageListTongueType.showUnread:
          TIM_t_para("{{option1}}条新消息", "$option1条新消息")(option1: option1),
      MessageListTongueType.atMe: atMeString,
      MessageListTongueType.atAll: TIM_t("@所有人"),
    };
  }

  IconData _iconForType() {
    switch (valueType) {
      case MessageListTongueType.atMe:
      case MessageListTongueType.atAll:
        return Icons.keyboard_double_arrow_up;
      case MessageListTongueType.showPrevious:
      case MessageListTongueType.toLatest:
      case MessageListTongueType.showUnread:
      case MessageListTongueType.none:
        return Icons.keyboard_double_arrow_down;
    }
  }

  bool get _isBlueCapsule =>
      valueType == MessageListTongueType.showPrevious ||
      valueType == MessageListTongueType.showUnread ||
      valueType == MessageListTongueType.toLatest;

  @override
  Widget tuiBuild(BuildContext context, TUIKitBuildValue value) {
    final text = textType(context)[valueType] ?? "";
    final backgroundColor = _isBlueCapsule
        ? const Color(0xFF1296F6)
        : const Color(0xFFFFFFFF);
    final foregroundColor = _isBlueCapsule
        ? Colors.white
        : (value.theme.primaryColor ?? const Color(0xFF1296F6));
    return GestureDetector(
      onTap: onClick,
      child: Container(
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(22),
            bottomLeft: Radius.circular(22),
            topRight: Radius.zero,
            bottomRight: Radius.zero,
          ),
          border: _isBlueCapsule
              ? null
              : Border.all(color: const Color(0xFFE5E5E5), width: 1),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(_isBlueCapsule ? 0.14 : 0.08),
              offset: const Offset(0, 2),
              blurRadius: 8,
              spreadRadius: 0,
            ),
          ],
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Icon(
              _iconForType(),
              color: foregroundColor,
              size: 17,
            ),
            const SizedBox(width: 4),
            Text(
              text,
              style: TextStyle(
                color: foregroundColor,
                fontSize: 14.0,
                height: 1.0,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
