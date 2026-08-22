import 'package:flutter/material.dart';
import 'package:tencent_cloud_chat_demo/src/i18n/app_i18n.dart';
import 'package:tencent_cloud_chat_demo/src/utils/conversation_unread_utils.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_conversation.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_conversation.dart';
import 'package:tencent_cloud_chat_uikit/theme/color.dart';
import 'package:tencent_cloud_chat_uikit/theme/tui_theme.dart';
import 'package:tencent_cloud_chat_uikit/ui/views/TIMUIKitConversation/archived_conversation_store.dart';
import 'package:tencent_cloud_chat_uikit/ui/widgets/unread_message.dart';
import 'package:tencent_cloud_chat_demo/src/widgets/conversation_feed/conversation_feed_ui.dart';

class ConversationArchivedEntryTile extends StatelessWidget {
  const ConversationArchivedEntryTile({
    super.key,
    required this.theme,
    required this.archiveScope,
    required this.getArchivedConversations,
    required this.onTap,
  });

  final TUITheme theme;
  final ConversationArchiveScope archiveScope;
  final List<V2TimConversation> Function() getArchivedConversations;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final archivedConversations = getArchivedConversations();
    final subtitle = _previewName(context, archivedConversations);
    final unreadCount = archivedConversations.fold<int>(
      0,
      (count, conversation) =>
          count + ConversationUnreadUtils.notifiableUnreadCount(conversation),
    );
    final avatarSize = conversationFeedAvatarSize(context);
    final titleSize = conversationFeedTitleFontSize(context);
    final subtitleSize = conversationFeedSubtitleFontSize(context);
    return Material(
      color: conversationFeedItemBackground(theme, pinned: false),
      child: InkWell(
        onTap: onTap,
        child: Stack(
          children: [
            Padding(
              padding: conversationFeedRowPadding(context),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.only(top: 0, bottom: 2, right: 0),
                    child: buildConversationSystemEntryAvatar(
                      conversationArchivedEntryIconAsset,
                      size: avatarSize,
                    ),
                  ),
                  Expanded(
                    child: Container(
                      margin: const EdgeInsets.only(left: 12),
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  AppI18n.of(context).t(
                                    zhHans: '归档',
                                    zhHant: '封存',
                                    en: 'Archive',
                                    ja: 'アーカイブ',
                                    ko: '보관',
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    height: 1.2,
                                    color: theme.conversationItemTitleTextColor,
                                    fontSize: titleSize,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  subtitle,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    height: 1.2,
                                    color: theme
                                        .conversationItemLastMessageTextColor,
                                    fontSize: subtitleSize,
                                  ),
                                ),
                              ),
                              if (unreadCount > 0)
                                Padding(
                                  padding: const EdgeInsets.only(left: 8),
                                  child: UnreadMessage(
                                    unreadCount: unreadCount,
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Positioned(
              left: conversationFeedDividerInset(context),
              right: 0,
              bottom: 0,
              child: Container(
                height: 0.6,
                color: theme.weakDividerColor ?? hexToColor('E5E6E9'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _previewName(
    BuildContext context,
    List<V2TimConversation> archivedConversations,
  ) {
    if (archivedConversations.isEmpty) {
      return AppI18n.of(context).t(
        zhHans: '已归档会话',
        zhHant: '已封存會話',
        en: 'Archived Chats',
        ja: 'アーカイブ済み',
        ko: '보관된 대화',
      );
    }
    final latestConversation = archivedConversations.first;
    final draftText = latestConversation.draftText?.trim() ?? '';
    if (draftText.isNotEmpty) {
      return '[${AppI18n.of(context).t(
        zhHans: '草稿',
        zhHant: '草稿',
        en: 'Draft',
        ja: '下書き',
        ko: '임시저장',
      )}]$draftText';
    }
    final names = archivedConversations
        .map((conversation) => conversation.showName?.trim() ?? '')
        .where((name) => name.isNotEmpty)
        .toList();
    if (names.isEmpty) {
      return AppI18n.of(context).t(
        zhHans: '已归档会话',
        zhHant: '已封存會話',
        en: 'Archived Chats',
        ja: 'アーカイブ済み',
        ko: '보관된 대화',
      );
    }
    return names.join('，');
  }
}
