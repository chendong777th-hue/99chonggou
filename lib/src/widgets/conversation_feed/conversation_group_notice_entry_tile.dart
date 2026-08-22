import 'package:flutter/material.dart';
import 'package:tencent_cloud_chat_demo/src/i18n/app_i18n.dart';
import 'package:tencent_cloud_chat_demo/src/services/group_join_application_service.dart';
import 'package:tencent_cloud_chat_demo/src/services/group_notice_feed_log.dart';
import 'package:tencent_cloud_chat_demo/src/services/group_notice_unread_service.dart';
import 'package:tencent_cloud_chat_demo/src/services/group_system_notice_service.dart';
import 'package:tencent_cloud_chat_demo/src/widgets/conversation_feed/conversation_feed_ui.dart';
import 'package:tencent_cloud_chat_demo/src/widgets/conversation_feed/conversation_group_notice_presenter.dart';
import 'package:tencent_cloud_chat_demo/src/widgets/conversation_feed/conversation_slidable.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_group_application.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_group_application.dart';
import 'package:tencent_cloud_chat_uikit/business_logic/view_models/tui_chat_global_model.dart'
    show GroupSystemNoticeItem;
import 'package:tencent_cloud_chat_uikit/theme/color.dart';
import 'package:tencent_cloud_chat_uikit/theme/tui_theme.dart';
import 'package:tencent_cloud_chat_uikit/ui/controller/tim_uikit_conversation_controller.dart';
import 'package:tencent_cloud_chat_uikit/ui/views/TIMUIKitConversation/tim_uikit_conversation.dart'
    show ConversationItemSlidePanel;
import 'package:tencent_cloud_chat_uikit/ui/widgets/unread_message.dart';

class ConversationGroupNoticeEntryTile extends StatefulWidget {
  const ConversationGroupNoticeEntryTile({
    super.key,
    required this.theme,
    required this.controller,
    required this.onTap,
    required this.onPin,
    required this.onToggleMute,
    required this.onDelete,
    this.isPinned = false,
    this.isMuted = false,
    this.wrapWithSlidable = true,
    this.isEditing = false,
    this.isSelected = false,
    this.onToggleSelect,
  });

  final TUITheme theme;
  final TIMUIKitConversationController controller;
  final VoidCallback onTap;
  final Future<void> Function() onPin;
  final Future<void> Function() onToggleMute;
  final Future<void> Function() onDelete;
  final bool isPinned;
  final bool isMuted;
  final bool wrapWithSlidable;
  final bool isEditing;
  final bool isSelected;
  final VoidCallback? onToggleSelect;

  @override
  State<ConversationGroupNoticeEntryTile> createState() =>
      _ConversationGroupNoticeEntryTileState();
}

class _ConversationGroupNoticeEntryTileState
    extends State<ConversationGroupNoticeEntryTile> {
  final Map<String, String> _applicationGroupNameCache = {};
  late final Listenable _tileListenable;

  @override
  void initState() {
    super.initState();
    _tileListenable = Listenable.merge([
      GroupNoticeUnreadService.instance,
      GroupJoinApplicationService.instance,
      GroupSystemNoticeService.instance,
    ]);
  }

  List<V2TimGroupApplication> _applications() {
    return GroupJoinApplicationService.instance.applications;
  }

  List<GroupSystemNoticeItem> _notices() {
    return List<GroupSystemNoticeItem>.from(
      GroupSystemNoticeService.instance.notices,
    )..sort((a, b) => b.timestamp.compareTo(a.timestamp));
  }

  bool _warmUpApplicationGroupNames(List<V2TimGroupApplication> applications) {
    var cacheUpdated = false;
    for (final groupID in applications.map((e) => e.groupID).toSet()) {
      if (_applicationGroupNameCache.containsKey(groupID)) {
        continue;
      }
      final fromService =
          GroupJoinApplicationService.instance.groupNameFor(groupID);
      if (fromService != null && fromService.isNotEmpty) {
        _applicationGroupNameCache[groupID] = fromService;
        cacheUpdated = true;
        continue;
      }
      final conversation =
          widget.controller.model.getConversation('group_$groupID');
      final showName = conversation?.showName?.trim() ?? '';
      if (showName.isNotEmpty) {
        _applicationGroupNameCache[groupID] = showName;
        cacheUpdated = true;
      }
    }
    return cacheUpdated;
  }

  String _resolveGroupName(String groupId) {
    return _applicationGroupNameCache[groupId] ??
        GroupJoinApplicationService.instance.groupNameFor(groupId) ??
        groupId;
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _tileListenable,
      builder: (context, child) {
        final applications = _applications();
        final notices = _notices();
        if (_warmUpApplicationGroupNames(applications)) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              setState(() {});
            }
          });
        }
        final presenter = ConversationGroupNoticePresenter(
          context: context,
          groupNameResolver: _resolveGroupName,
        );
        final avatarSize = conversationFeedAvatarSize(context);
        final titleSize = conversationFeedTitleFontSize(context);
        final subtitleSize = conversationFeedSubtitleFontSize(context);
        final timeSize = conversationFeedTimestampFontSize(context);
        final unreadCount = presenter.unreadCount(applications, notices);
        final displayUnreadCount = widget.isMuted ? 0 : unreadCount;
        final showMutedDot = widget.isMuted && unreadCount > 0;
        GroupNoticeFeedLog.log('entry_tile_build', extras: {
          'unread': unreadCount,
          'displayUnread': displayUnreadCount,
          'muted': widget.isMuted,
          'showMutedDot': showMutedDot,
          'pinned': widget.isPinned,
          'snap': GroupNoticeFeedLog.snapshot(
            applications: applications,
            notices: notices,
            unread: unreadCount,
          ),
        });
        final editing = widget.isEditing;
        final rowContent = Padding(
          padding: conversationFeedRowPadding(context),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              if (editing) ...[
                Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: widget.isSelected
                          ? (widget.theme.primaryColor ??
                              const Color(0xFF1E90FF))
                          : Colors.transparent,
                      border: Border.all(
                        color: widget.isSelected
                            ? (widget.theme.primaryColor ??
                                const Color(0xFF1E90FF))
                            : (widget.theme.weakTextColor ??
                                const Color(0xFFBDBDBD)),
                        width: 1.8,
                      ),
                    ),
                    child: widget.isSelected
                        ? const Icon(
                            Icons.check,
                            size: 16,
                            color: Colors.white,
                          )
                        : null,
                  ),
                ),
              ],
              SizedBox(
                width: avatarSize,
                height: avatarSize,
                child: Stack(
                  fit: StackFit.expand,
                  clipBehavior: Clip.none,
                  children: [
                    buildConversationSystemEntryAvatar(
                      conversationGroupNoticeEntryIconAsset,
                      size: avatarSize,
                    ),
                    if (displayUnreadCount > 0 || showMutedDot)
                      Positioned(
                        top: showMutedDot ? -2.5 : -4.5,
                        right: showMutedDot ? -2.5 : -4.5,
                        child: UnconstrainedBox(
                          child: UnreadMessage(
                            unreadCount: displayUnreadCount,
                            width: showMutedDot ? 10 : 18,
                            height: showMutedDot ? 10 : 18,
                          ),
                        ),
                      ),
                  ],
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
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              presenter.title(applications, notices),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                height: 1.2,
                                color:
                                    widget.theme.conversationItemTitleTextColor,
                                fontSize: titleSize,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          if (widget.isMuted) ...[
                            const SizedBox(width: 6),
                            Icon(
                              Icons.notifications_off_rounded,
                              size: 16,
                              color: widget.theme.weakTextColor,
                            ),
                          ],
                          if (presenter
                              .previewTime(applications, notices)
                              .isNotEmpty)
                            Text(
                              presenter.previewTime(
                                applications,
                                notices,
                              ),
                              style: TextStyle(
                                fontSize: timeSize,
                                height: 1.2,
                                color:
                                    widget.theme.conversationItemTitmeTextColor,
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              presenter.previewSubtitle(
                                applications,
                                notices,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                height: 1.2,
                                color: widget
                                    .theme.conversationItemLastMessageTextColor,
                                fontSize: subtitleSize,
                              ),
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
        );
        final content = Material(
          color: conversationFeedItemBackground(
            widget.theme,
            pinned: widget.isPinned,
          ),
          child: InkWell(
            onTap: editing ? () => widget.onToggleSelect?.call() : widget.onTap,
            child: Stack(
              children: [
                rowContent,
                Positioned(
                  left: conversationFeedDividerInset(
                    context,
                    editing: editing,
                  ),
                  right: 0,
                  bottom: 0,
                  child: Container(
                    height: 0.6,
                    color:
                        widget.theme.weakDividerColor ?? hexToColor('E5E6E9'),
                  ),
                ),
              ],
            ),
          ),
        );
        if (!widget.wrapWithSlidable || editing) {
          return content;
        }
        final i18n = AppI18n.of(context);
        final pinLabel = widget.isPinned
            ? i18n.t(
                zhHans: '取消置顶',
                zhHant: '取消置頂',
                en: 'Unpin',
                ja: 'ピン留め解除',
                ko: '고정 해제',
              )
            : i18n.t(
                zhHans: '置顶',
                zhHant: '置頂',
                en: 'Pin',
                ja: 'ピン留め',
                ko: '고정',
              );
        final disturbLabel = widget.isMuted
            ? i18n.t(
                zhHans: '取消免打扰',
                zhHant: '取消免打擾',
                en: 'Unmute',
                ja: 'ミュート解除',
                ko: '알림 켜기',
              )
            : i18n.t(
                zhHans: '免打扰',
                zhHant: '免打擾',
                en: 'Mute',
                ja: 'ミュート',
                ko: '알림 끄기',
              );
        return conversationSlidable(
          context: context,
          endActionPane: conversationActionPane(
            webFeel: conversationSlidableUseWebFeel(context),
            children: [
              ConversationItemSlidePanel(
                onPressed: (context) {
                  widget.onPin();
                },
                backgroundColor: const Color(0xFFF5A623),
                foregroundColor: Colors.white,
                label: pinLabel,
                padding: EdgeInsets.zero,
              ),
              ConversationItemSlidePanel(
                onPressed: (context) {
                  widget.onToggleMute();
                },
                backgroundColor:
                    widget.theme.primaryColor ?? const Color(0xFF006EFF),
                foregroundColor: Colors.white,
                label: disturbLabel,
                padding: EdgeInsets.zero,
              ),
              ConversationItemSlidePanel(
                onPressed: (context) {
                  widget.onDelete();
                },
                backgroundColor: const Color(0xFFFF584C),
                foregroundColor: Colors.white,
                label: i18n.t(
                  zhHans: '删除',
                  zhHant: '刪除',
                  en: 'Delete',
                  ja: '削除',
                  ko: '삭제',
                ),
                padding: EdgeInsets.zero,
              ),
            ],
          ),
          child: content,
        );
      },
    );
  }
}
