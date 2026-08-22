import 'package:flutter/material.dart';
import 'package:tencent_cloud_chat_demo/src/ui/app_tokens.dart';
import 'package:tencent_cloud_chat_demo/src/ui/app_responsive.dart';
import 'app_avatar.dart';

class ConversationTile extends StatelessWidget {
  final String name;
  final String? avatarUrl;
  final String lastMessage;
  final String time;
  final int unreadCount;
  final bool isPinned;
  final bool isOnline;
  final VoidCallback? onTap;

  const ConversationTile({
    Key? key,
    required this.name,
    this.avatarUrl,
    required this.lastMessage,
    required this.time,
    this.unreadCount = 0,
    this.isPinned = false,
    this.isOnline = false,
    this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final isDesktop = context.isDesktopFormFactor;
    final avatarSize = isDesktop ? 40.0 : 44.0;
    final titleFontSize = isDesktop ? 13.0 : 15.0;
    final subtitleFontSize = isDesktop ? 12.0 : 13.0;
    return Material(
      color: isPinned ? AppTokens.ink25 : AppTokens.surface,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: AppResponsive.listRowPadding(
            context,
            mobileHorizontal: 16,
            desktopHorizontal: 16,
            mobileVertical: 8,
            desktopVertical: 8,
          ),
          child: Row(
            children: [
              AppAvatar(
                name: name,
                imageUrl: avatarUrl,
                size: avatarSize,
                showOnline: isOnline,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            name,
                            style: AppTokens.bodyStrong.copyWith(
                              fontSize: titleFontSize,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Text(
                          time,
                          style: AppTokens.caption.copyWith(fontSize: 11),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            lastMessage,
                            style: AppTokens.caption.copyWith(
                              fontSize: subtitleFontSize,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (unreadCount > 0) _badge(),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _badge() {
    final label = unreadCount > 99 ? '99+' : '$unreadCount';
    return Container(
      margin: const EdgeInsets.only(left: 8),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      constraints: const BoxConstraints(minWidth: 20),
      decoration: BoxDecoration(
        color: AppTokens.brand500,
        borderRadius: BorderRadius.circular(AppTokens.rPill),
      ),
      alignment: Alignment.center,
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
