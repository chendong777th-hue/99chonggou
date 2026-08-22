import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:tencent_chat_i18n_tool/tencent_chat_i18n_tool.dart';
import 'package:tencent_cloud_chat_demo/src/models/moments/moment_models.dart';
import 'package:tencent_cloud_chat_demo/src/navigation/app_page_transitions.dart';
import 'package:tencent_cloud_chat_demo/src/pages/moments/moments_detail_page.dart';
import 'package:tencent_cloud_chat_demo/src/services/moments/moments_error_mapper.dart';
import 'package:tencent_cloud_chat_demo/src/services/moments/moments_store.dart';
import 'package:tencent_cloud_chat_demo/src/theme/app_colors.dart';
import 'package:tencent_cloud_chat_demo/src/ui/app_tokens.dart';
import 'package:tencent_cloud_chat_demo/src/widgets/app_empty_state.dart';
import 'package:tencent_cloud_chat_demo/src/pages/moments/moments_navigation.dart';
import 'package:tencent_cloud_chat_demo/src/pages/moments/moments_user_avatar.dart';
import 'package:tencent_cloud_chat_demo/src/services/peer_profile_refresh_bus.dart';
import 'package:tencent_cloud_chat_demo/utils/user_display_profile.dart';
import 'package:tencent_cloud_chat_demo/src/pages/moments/moments_media_thumbnail.dart';
import 'package:tencent_cloud_chat_demo/src/widgets/app_list_pressable.dart';

const Color _momentsNameColor = AppTokens.ink600;

Color _momentsPageBackground(bool dark) =>
    dark ? AppColors.background(dark: true) : AppColors.card(dark: false);

class MomentsNotificationsPage extends StatefulWidget {
  const MomentsNotificationsPage({super.key});

  @override
  State<MomentsNotificationsPage> createState() =>
      _MomentsNotificationsPageState();
}

class _MomentsNotificationsPageState extends State<MomentsNotificationsPage> {
  static const double _loadMoreTriggerExtent = 360;

  final ScrollController _scrollController = ScrollController();
  bool _loading = true;
  bool _loadingMore = false;
  bool _hasMore = false;
  String? _nextCursor;
  String? _error;
  String? _loadMoreError;
  List<MomentNotification> _items = const [];

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    PeerProfileRefreshBus.instance.revision.addListener(_onPeerProfileRefresh);
    _load();
  }

  @override
  void dispose() {
    PeerProfileRefreshBus.instance.revision.removeListener(_onPeerProfileRefresh);
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onPeerProfileRefresh() {
    if (!mounted) return;
    setState(() {});
  }

  void _onScroll() {
    if (!_scrollController.hasClients ||
        _loading ||
        _loadingMore ||
        !_hasMore) {
      return;
    }
    if (_scrollController.position.extentAfter <= _loadMoreTriggerExtent) {
      _loadMore();
    }
  }

  Future<void> _load() async {
    if (mounted) {
      setState(() {
        _loading = true;
        _error = null;
        _loadMoreError = null;
      });
    }
    try {
      final page = await MomentsStore.loadNotificationsPage();
      await _markRead(page.items, readAll: true);
      if (!mounted) return;
      setState(() {
        _items = page.items;
        _nextCursor = page.nextCursor;
        _hasMore =
            page.hasMore && (page.nextCursor?.trim().isNotEmpty ?? false);
        _loading = false;
        _loadingMore = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = MomentsErrorMapper.map(e).userMessage;
        _loading = false;
        _loadingMore = false;
      });
    }
  }

  Future<void> _loadMore() async {
    final cursor = _nextCursor?.trim() ?? '';
    if (_loadingMore || !_hasMore || cursor.isEmpty) {
      return;
    }
    setState(() {
      _loadingMore = true;
      _loadMoreError = null;
    });
    try {
      final page = await MomentsStore.loadNotificationsPage(cursor: cursor);
      await _markRead(page.items);
      if (!mounted) return;
      final seen = _items.map((item) => item.id).toSet();
      final merged = <MomentNotification>[
        ..._items,
        ...page.items.where((item) => seen.add(item.id)),
      ];
      setState(() {
        _items = merged;
        _nextCursor = page.nextCursor;
        _hasMore =
            page.hasMore && (page.nextCursor?.trim().isNotEmpty ?? false);
        _loadingMore = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadMoreError = MomentsErrorMapper.map(e).userMessage;
        _loadingMore = false;
      });
    }
  }

  Future<void> _markRead(
    List<MomentNotification> items, {
    bool readAll = false,
  }) async {
    try {
      await MomentsStore.markNotificationsRead(
        notificationIds: readAll ? const [] : items.map((e) => e.id).toList(),
        readAll: readAll,
      );
    } catch (_) {
      // 已读失败不阻断列表展示，下次进入还会重试。
    }
  }

  Future<void> _openDetail(MomentNotification item) async {
    await Navigator.push<void>(
      context,
      AppMaterialPageRoute(
        builder: (_) => MomentsDetailPage(postId: item.postId),
      ),
    );
    if (!mounted) return;
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: _momentsPageBackground(dark),
      appBar: AppBar(
        elevation: 0,
        centerTitle: true,
        backgroundColor: AppColors.card(dark: dark),
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          color: _momentsNameColor,
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          TIM_t('全部互动消息'),
          style: TextStyle(
            color: AppColors.text(dark: dark),
            fontSize: 17,
            fontWeight: FontWeight.w600,
          ),
        ),
        actions: [
          IconButton(
            onPressed: () {},
            icon: const Icon(Icons.more_horiz_rounded),
            color: AppColors.text(dark: dark),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CupertinoActivityIndicator())
          : _error != null
              ? Center(
                  child: _NotificationsErrorState(
                    message: _error!,
                    dark: dark,
                    onRetry: _load,
                  ),
                )
              : _items.isEmpty
                  ? Center(
                      child: AppEmptyState(
                        imageWidth: 160,
                        message: TIM_t('还没有朋友圈消息'),
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _load,
                      child: ListView.separated(
                        controller: _scrollController,
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.fromLTRB(0, 0, 0, 24),
                        itemCount: _items.length + 1,
                        separatorBuilder: (_, index) =>
                            index >= _items.length - 1
                                ? const SizedBox.shrink()
                                : Divider(
                                    height: 1,
                                    thickness: 0.6,
                                    indent: 88,
                                    color: AppColors.line(dark: dark),
                                  ),
                        itemBuilder: (context, index) {
                          if (index >= _items.length) {
                            return _LoadMoreFooter(
                              dark: dark,
                              loading: _loadingMore,
                              hasMore: _hasMore,
                              error: _loadMoreError,
                              onRetry: _loadMore,
                            );
                          }
                          final item = _items[index];
                          return _NotificationTile(
                            item: item,
                            dark: dark,
                            onTap: () => _openDetail(item),
                          );
                        },
                      ),
                    ),
    );
  }
}

class _NotificationTile extends StatelessWidget {
  const _NotificationTile({
    required this.item,
    required this.dark,
    required this.onTap,
  });

  final MomentNotification item;
  final bool dark;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AppListPressable(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            GestureDetector(
              onTap: () => openAuthorMomentsPage(context, author: item.actor),
              behavior: HitTestBehavior.opaque,
              child: MomentsUserAvatar(
                user: item.actor,
                size: 48,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _NotificationContent(item: item, dark: dark),
            ),
            const SizedBox(width: 12),
            _PostPreview(item: item, dark: dark),
          ],
        ),
      ),
    );
  }
}

class _NotificationsErrorState extends StatelessWidget {
  const _NotificationsErrorState({
    required this.message,
    required this.dark,
    required this.onRetry,
  });

  final String message;
  final bool dark;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AppEmptyState(
            imageWidth: 160,
            message: message,
            padding: EdgeInsets.zero,
          ),
          const SizedBox(height: 14),
          FilledButton(
            onPressed: onRetry,
            style: FilledButton.styleFrom(
              backgroundColor: _momentsNameColor,
              foregroundColor: Colors.white,
            ),
            child: Text(TIM_t('重试')),
          ),
        ],
      ),
    );
  }
}

class _LoadMoreFooter extends StatelessWidget {
  const _LoadMoreFooter({
    required this.dark,
    required this.loading,
    required this.hasMore,
    required this.error,
    required this.onRetry,
  });

  final bool dark;
  final bool loading;
  final bool hasMore;
  final String? error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 18),
        child: Center(
          child: CupertinoActivityIndicator(
            color: AppColors.subText(dark: dark),
          ),
        ),
      );
    }
    if (error != null) {
      return AppListPressable(
        onTap: onRetry,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
          child: Center(
            child: Text(
              error!.isEmpty ? TIM_t('加载失败，点击重试') : error!,
              style: TextStyle(
                color: AppColors.subText(dark: dark),
                fontSize: 13,
              ),
            ),
          ),
        ),
      );
    }
    if (!hasMore) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 18),
        child: Center(
          child: Text(
            TIM_t('没有更多了'),
            style: TextStyle(
              color: AppColors.subText(dark: dark),
              fontSize: 12,
            ),
          ),
        ),
      );
    }
    return const SizedBox(height: 12);
  }
}

class _NotificationContent extends StatelessWidget {
  const _NotificationContent({
    required this.item,
    required this.dark,
  });

  final MomentNotification item;
  final bool dark;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          UserDisplayProfile.nameOfSnapshot(item.actor),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: _momentsNameColor,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 4),
        _NotificationMessage(item: item, dark: dark),
        const SizedBox(height: 5),
        Text(
          _formatMessageTime(item.createdAt),
          style: TextStyle(
            color: AppColors.subText(dark: dark),
            fontSize: 14,
          ),
        ),
      ],
    );
  }
}

class _NotificationMessage extends StatelessWidget {
  const _NotificationMessage({
    required this.item,
    required this.dark,
  });

  final MomentNotification item;
  final bool dark;

  @override
  Widget build(BuildContext context) {
    if (item.type == MomentNotificationType.like) {
      return Icon(
        Icons.favorite_border_rounded,
        color: _momentsNameColor.withValues(alpha: 0.9),
        size: 24,
      );
    }

    final commentText = item.comment?.text.trim() ?? '';
    if (item.type == MomentNotificationType.reply && item.replyToUser != null) {
      return RichText(
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        text: TextSpan(
          style: TextStyle(
            color: AppColors.text(dark: dark),
            fontSize: 15,
            height: 1.25,
          ),
          children: [
            TextSpan(text: '${TIM_t('回复了')} '),
            TextSpan(
              text: UserDisplayProfile.nameOfSnapshot(item.replyToUser!),
              style: const TextStyle(
                color: _momentsNameColor,
                fontWeight: FontWeight.w600,
              ),
            ),
            TextSpan(text: commentText.isEmpty ? '' : '：$commentText'),
          ],
        ),
      );
    }

    return Text(
      commentText.isEmpty ? TIM_t('评论了你的动态') : commentText,
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
        color: AppColors.text(dark: dark),
        fontSize: 15,
        height: 1.25,
      ),
    );
  }
}

class _PostPreview extends StatelessWidget {
  const _PostPreview({
    required this.item,
    required this.dark,
  });

  final MomentNotification item;
  final bool dark;

  @override
  Widget build(BuildContext context) {
    final previewPath = item.postPreviewPath?.trim() ?? '';
    if (previewPath.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(6),
        child: SizedBox(
          width: 64,
          height: 64,
          child: _previewImage(previewPath),
        ),
      );
    }
    return Container(
      width: 64,
      height: 64,
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: AppColors.surfaceAlt(dark: dark),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        item.postText.trim().isEmpty ? TIM_t('动态') : item.postText.trim(),
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: AppColors.subText(dark: dark),
          fontSize: 12,
          height: 1.2,
        ),
      ),
    );
  }

  Widget _previewImage(String raw) {
    return MomentsMediaThumbnail(path: raw, fallbackLogicalSize: 96);
  }
}

String _formatMessageTime(DateTime createdAt) {
  final local = createdAt.toLocal();
  return '${local.month}月${local.day}日 ${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
}
