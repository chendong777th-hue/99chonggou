import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tencent_cloud_chat_demo/src/i18n/app_i18n.dart';
import 'package:tencent_cloud_chat_demo/src/provider/theme.dart';
import 'package:tencent_cloud_chat_demo/src/ui/app_tokens.dart';

class ChatInputBar extends StatefulWidget {
  final ValueChanged<String>? onSend;

  const ChatInputBar({Key? key, this.onSend}) : super(key: key);

  @override
  State<ChatInputBar> createState() => _ChatInputBarState();
}

class _ChatInputBarState extends State<ChatInputBar> {
  final _ctrl = TextEditingController();
  bool _hasText = false;

  @override
  void initState() {
    super.initState();
    _ctrl.addListener(() {
      final has = _ctrl.text.trim().isNotEmpty;
      if (has != _hasText) setState(() => _hasText = has);
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _send() {
    final text = _ctrl.text.trim();
    if (text.isEmpty) return;
    widget.onSend?.call(text);
    _ctrl.clear();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Provider.of<DefaultThemeData>(context).theme;
    final bottom = MediaQuery.of(context).padding.bottom;
    return Container(
      padding: EdgeInsets.fromLTRB(12, 8, 12, 8 + bottom),
      decoration: BoxDecoration(
        color: theme.conversationItemBgColor ?? AppTokens.surface,
        border: Border(
            top: BorderSide(
                color: theme.weakDividerColor ?? AppTokens.divider, width: 1)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          _iconBtn(Icons.add_rounded),
          const SizedBox(width: 8),
          Expanded(
            child: Container(
              constraints: const BoxConstraints(maxHeight: 120),
              decoration: BoxDecoration(
                color: theme.inputFillColor ?? AppTokens.ink25,
                borderRadius: BorderRadius.circular(22),
                border: Border.all(
                    color: theme.weakDividerColor ?? AppTokens.ink100, width: 1),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: TextField(
                      controller: _ctrl,
                      maxLines: 5,
                      minLines: 1,
                      style: AppTokens.body.copyWith(
                        fontSize: 15,
                        color: theme.darkTextColor ?? AppTokens.ink800,
                      ),
                      cursorColor: theme.primaryColor ?? AppTokens.brand500,
                      decoration: InputDecoration(
                        hintText: AppI18n.of(context).t(
                          zhHans: '输入消息...',
                          zhHant: '輸入訊息...',
                          en: 'Type a message...',
                          ja: 'メッセージを入力...',
                          ko: '메시지 입력...',
                        ),
                        hintStyle: AppTokens.body.copyWith(
                            color: theme.weakTextColor ?? AppTokens.ink300,
                            fontSize: 15),
                        border: InputBorder.none,
                        filled: false,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(right: 4, bottom: 4),
                    child: _iconBtn(Icons.emoji_emotions_outlined),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            transitionBuilder: (child, anim) =>
                ScaleTransition(scale: anim, child: child),
            child: _hasText
                ? GestureDetector(
                    key: const ValueKey('send'),
                    onTap: _send,
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: AppTokens.brand500,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: AppTokens.shadowBrand,
                      ),
                      child: const Icon(Icons.arrow_upward_rounded,
                          color: Colors.white, size: 20),
                    ),
                  )
                : GestureDetector(
                    key: const ValueKey('mic'),
                    child: _iconBtn(Icons.mic_none_rounded),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _iconBtn(IconData icon) {
    final theme = Provider.of<DefaultThemeData>(context).theme;
    return Container(
      width: 40,
      height: 40,
      alignment: Alignment.center,
      child: Icon(
        icon,
        color: theme.weakTextColor ?? AppTokens.ink400,
        size: 24,
      ),
    );
  }
}
