import 'package:flutter/material.dart';
import 'package:tencent_cloud_chat_demo/src/ui/app_tokens.dart';
import 'package:tencent_cloud_chat_uikit/ui/utils/message_bubble_text_color.dart';

class ChatBubble extends StatelessWidget {
  final String text;
  final bool isMine;
  final String? time;
  final bool showTail;

  const ChatBubble({
    Key? key,
    required this.text,
    required this.isMine,
    this.time,
    this.showTail = true,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final bgColor = isMine ? AppTokens.brand500 : AppTokens.surface;
    final textColor = isMine ? Colors.white : AppTokens.ink800;
    final timeColor = isMine ? Colors.white.withOpacity(0.7) : AppTokens.ink300;
    final alignment = isMine ? CrossAxisAlignment.end : CrossAxisAlignment.start;

    return Column(
      crossAxisAlignment: alignment,
      children: [
        Container(
          constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.72,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(18),
              topRight: const Radius.circular(18),
              bottomLeft: Radius.circular(isMine ? 18 : 4),
              bottomRight: Radius.circular(isMine ? 4 : 18),
            ),
            boxShadow: isMine ? null : AppTokens.shadowSm,
            border: isMine ? null : Border.all(color: AppTokens.divider, width: 1),
          ),
          child: Text(
            text,
            style: MessageBubbleTextColor.messageBodyBaseStyle(
              fontSize: 15,
              lineHeight: 1.45,
            ).copyWith(
              color: textColor,
              fontWeight: MessageBubbleTextColor.messageBodyFontWeight,
            ),
          ),
        ),
        if (time != null)
          Padding(
            padding: const EdgeInsets.only(top: 4, left: 4, right: 4),
            child: Text(
              time!,
              style: TextStyle(fontSize: 11, color: timeColor),
            ),
          ),
      ],
    );
  }
}
