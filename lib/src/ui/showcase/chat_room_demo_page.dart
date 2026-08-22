import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:tencent_cloud_chat_demo/src/ui/app_tokens.dart';
import 'package:tencent_cloud_chat_demo/src/ui/components/app_avatar.dart';
import 'package:tencent_cloud_chat_demo/src/ui/components/chat_bubble.dart';
import 'package:tencent_cloud_chat_demo/src/ui/components/chat_input_bar.dart';

class ChatRoomDemoPage extends StatelessWidget {
  final String name;
  final bool online;

  const ChatRoomDemoPage({
    Key? key,
    required this.name,
    this.online = false,
  }) : super(key: key);

  static final _messages = <Map<String, dynamic>>[
    {'text': '嗨，最新的设计稿我看了，整体方向很好', 'mine': false, 'time': '14:02'},
    {'text': '有几个小细节想和你确认一下', 'mine': false, 'time': '14:02'},
    {'text': '好的，你说', 'mine': true, 'time': '14:03'},
    {'text': '首页的卡片间距是 16 还是 20？我看 figma 上标注的是 16，但实际看起来有点紧', 'mine': false, 'time': '14:04'},
    {'text': '是 20，figma 上我刚更新了。之前标注有误，抱歉', 'mine': true, 'time': '14:05'},
    {'text': '了解，那我按 20 来。另外导航栏的 icon 用 outlined 还是 filled？', 'mine': false, 'time': '14:06'},
    {'text': '默认 outlined，选中态 filled，和 iOS 原生保持一致', 'mine': true, 'time': '14:06'},
    {'text': '👍 明白了，我今天下午就能出一版', 'mine': false, 'time': '14:07'},
    {'text': '太好了，辛苦！有问题随时找我', 'mine': true, 'time': '14:08'},
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTokens.surfaceAlt,
      body: Column(
        children: [
          _buildNavBar(context),
          Expanded(
            child: ListView.builder(
              reverse: true,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              itemCount: _messages.length,
              itemBuilder: (_, i) {
                final idx = _messages.length - 1 - i;
                final m = _messages[idx];
                final isMine = m['mine'] as bool;
                final showAvatar = !isMine &&
                    (idx == 0 || _messages[idx - 1]['mine'] == true);
                return Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    mainAxisAlignment:
                        isMine ? MainAxisAlignment.end : MainAxisAlignment.start,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      if (!isMine && showAvatar)
                        Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: AppAvatar(name: name, size: 32),
                        )
                      else if (!isMine)
                        const SizedBox(width: 40),
                      ChatBubble(
                        text: m['text'] as String,
                        isMine: isMine,
                        time: m['time'] as String,
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
          const ChatInputBar(),
        ],
      ),
    );
  }

  Widget _buildNavBar(BuildContext context) {
    final top = MediaQuery.of(context).padding.top;
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          padding: EdgeInsets.fromLTRB(8, top + 8, 16, 12),
          decoration: BoxDecoration(
            color: AppTokens.surface.withOpacity(0.88),
            border: const Border(
              bottom: BorderSide(color: AppTokens.divider, width: 1),
            ),
          ),
          child: Row(
            children: [
              IconButton(
                onPressed: () => Navigator.maybePop(context),
                icon: const Icon(Icons.arrow_back_ios_new_rounded,
                    size: 18, color: AppTokens.brand500),
              ),
              AppAvatar(name: name, size: 36, showOnline: online),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name, style: AppTokens.bodyStrong.copyWith(fontSize: 15)),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        if (online)
                          Container(
                            width: 6,
                            height: 6,
                            margin: const EdgeInsets.only(right: 5),
                            decoration: const BoxDecoration(
                              color: AppTokens.success,
                              shape: BoxShape.circle,
                            ),
                          ),
                        Text(
                          online ? '在线' : '离线',
                          style: AppTokens.caption.copyWith(fontSize: 12),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              _navIcon(Icons.phone_outlined),
              const SizedBox(width: 12),
              _navIcon(Icons.videocam_outlined),
              const SizedBox(width: 12),
              _navIcon(Icons.more_horiz_rounded),
            ],
          ),
        ),
      ),
    );
  }

  Widget _navIcon(IconData icon) {
    return Container(
      width: 34,
      height: 34,
      decoration: BoxDecoration(
        color: AppTokens.ink25,
        borderRadius: BorderRadius.circular(9),
      ),
      child: Icon(icon, size: 18, color: AppTokens.ink600),
    );
  }
}
