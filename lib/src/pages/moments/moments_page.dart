import 'dart:async';
import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tencent_chat_i18n_tool/tencent_chat_i18n_tool.dart';
import 'package:tencent_cloud_chat_demo/src/i18n/app_i18n.dart';
import 'package:tencent_cloud_chat_demo/src/models/moments/moment_settings_models.dart';
import 'package:tencent_cloud_chat_demo/src/models/moments/moment_models.dart';
import 'package:tencent_cloud_chat_demo/src/navigation/app_page_transitions.dart';
import 'package:tencent_cloud_chat_demo/src/pages/moments/moments_cover_picker.dart';
import 'package:tencent_cloud_chat_demo/src/pages/moments/moments_compose_page.dart';
import 'package:tencent_cloud_chat_demo/src/pages/settings/moments_permission_page.dart';
import 'package:tencent_cloud_chat_demo/src/pages/moments/moments_detail_page.dart';
import 'package:tencent_cloud_chat_demo/src/pages/moments/moments_image_preview.dart';
import 'package:tencent_cloud_chat_demo/src/pages/moments/moments_notifications_page.dart';
import 'package:tencent_cloud_chat_demo/src/pages/moments/moments_media_thumbnail.dart';
import 'package:tencent_cloud_chat_demo/src/pages/moments/moments_media_layout.dart';
import 'package:tencent_cloud_chat_demo/src/pages/moments/moments_video_player_page.dart';
import 'package:tencent_cloud_chat_demo/src/services/moments/moments_error_mapper.dart';
import 'package:tencent_cloud_chat_demo/src/services/moments/moments_feed_controller.dart';
import 'package:tencent_cloud_chat_demo/src/services/moments/moments_local_prefs.dart';
import 'package:tencent_cloud_chat_demo/src/services/moments/moments_refresh_bus.dart';
import 'package:tencent_cloud_chat_demo/src/services/moments/moments_settings_service.dart';
import 'package:tencent_cloud_chat_demo/src/services/moments/moments_store.dart';
import 'package:tencent_cloud_chat_demo/src/theme/app_colors.dart';
import 'package:tencent_cloud_chat_demo/src/ui/app_tokens.dart';
import 'package:tencent_cloud_chat_demo/utils/toast.dart';
import 'package:tencent_cloud_chat_demo/src/widgets/app_dialog.dart';
import 'package:tencent_cloud_chat_demo/src/widgets/app_empty_state.dart';
import 'package:tencent_cloud_chat_demo/src/widgets/app_list_pressable.dart';
import 'package:tencent_cloud_chat_demo/src/pages/moments/moments_user_avatar.dart';
import 'package:tencent_cloud_chat_demo/src/widgets/app_user_avatar.dart';
import 'package:tencent_cloud_chat_demo/src/provider/login_user_Info.dart';
import 'package:tencent_cloud_chat_demo/src/services/peer_profile_refresh_bus.dart';
import 'package:tencent_cloud_chat_demo/utils/user_display_profile.dart';

const Color _momentsNameColor = AppTokens.ink600;
const Color _momentsActionBarColor = Color(0xF0202126);

Color _momentsPageBackground(bool dark) =>
    dark ? AppColors.background(dark: true) : AppColors.card(dark: false);

Color _momentsPanelColor(bool dark) => AppColors.surfaceAlt(dark: dark);

Color _momentsButtonColor(bool dark) =>
    dark ? AppTokens.surfaceAltDark : AppTokens.ink50;

class MomentsPage extends StatefulWidget {
  const MomentsPage({
    super.key,
    this.authorId,
    this.profileName,
    this.profileAvatarUrl,
    this.showCoverHeader = true,
    this.embedded = false,
    this.onClose,
  });

  final String? authorId;
  final String? profileName;
  final String? profileAvatarUrl;
  final bool showCoverHeader;

  /// 嵌入桌面右栏时由外层提供返回；内部返回调用 [onClose]。
  final bool embedded;
  final VoidCallback? onClose;

  @override
  State<MomentsPage> createState() => _MomentsPageState();
}

class _MomentsPageState extends State<MomentsPage> {
  final ScrollController _scrollController = ScrollController();
  late final MomentsFeedController _feedController;
  final Set<String> _likingPostIds = <String>{};
  final Set<String> _commentingPostIds = <String>{};
  final Set<String> _deletingCommentIds = <String>{};
  int _notificationUnreadCount = 0;
  String? _coverUrl;
  int? _visibleRangeDays;
  VoidCallback? _momentsRefreshListener;
  static const String _coverAsset = 'assets/img/moments_cover.webp';
  static const double _loadMoreTriggerExtent = 420;

  @override
  void initState() {
    super.initState();
    _feedController = MomentsFeedController(authorId: widget.authorId);
    final cachedCover =
        MomentsSettingsService.instance.cachedSettings?.coverUrl?.trim();
    if (cachedCover != null && cachedCover.isNotEmpty) {
      _coverUrl = cachedCover;
    }
    _scrollController.addListener(_onScroll);
    _momentsRefreshListener = () {
      if (!mounted) return;
      _load(showRefreshing: true);
    };
    MomentsRefreshBus.instance.revision.addListener(_momentsRefreshListener!);
    PeerProfileRefreshBus.instance.revision.addListener(_onPeerProfileRefresh);
    _load();
    unawaited(_primeCoverFromCache());
    _loadHeaderExtras();
  }

  Future<void> _primeCoverFromCache() async {
    final settings = await MomentsSettingsService.instance.hydrateFromLocal();
    if (!mounted) return;
    final cover = settings.coverUrl?.trim() ?? '';
    if (cover.isEmpty || cover == _coverUrl) {
      return;
    }
    setState(() => _coverUrl = cover);
  }

  Future<void> _loadHeaderExtras() async {
    final selfId = MomentsStore.safeLoginUserId();
    final isSelfMomentsPage = _feedController.isProfileList &&
        widget.authorId?.trim() == selfId.trim();
    final results = await Future.wait([
      MomentsStore.fetchNotificationUnreadCount(),
      if (isSelfMomentsPage)
        MomentsSettingsService.instance.loadSettings(forceRefresh: true)
      else
        Future.value(null),
    ]);
    if (!mounted) return;
    setState(() {
      _notificationUnreadCount = results[0] as int;
      if (isSelfMomentsPage && results[1] is MomentsSettings) {
        final settings = results[1] as MomentsSettings;
        _coverUrl = settings.coverUrl;
        _visibleRangeDays = settings.visibleRangeDays;
      }
    });
  }

  void _onPeerProfileRefresh() {
    if (!mounted) return;
    setState(() {});
  }

  @override
  void dispose() {
    if (_momentsRefreshListener != null) {
      MomentsRefreshBus.instance.revision
          .removeListener(_momentsRefreshListener!);
    }
    PeerProfileRefreshBus.instance.revision.removeListener(_onPeerProfileRefresh);
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients ||
        _feedController.loading ||
        _feedController.loadingMore ||
        !_feedController.hasMore) {
      return;
    }
    final position = _scrollController.position;
    if (position.extentAfter <= _loadMoreTriggerExtent) {
      _loadMore();
    }
  }

  Future<void> _load({bool showRefreshing = false}) async {
    if (!showRefreshing && mounted) {
      setState(() {});
    }
    await _feedController.load(showRefreshing: showRefreshing);
    if (!mounted) return;
    await _loadHeaderExtras();
    if (!mounted) return;
    setState(() {});
  }

  Future<void> _loadMore() async {
    setState(() {});
    await _feedController.loadMore();
    if (!mounted) return;
    setState(() {});
  }

  Widget _buildLoadMoreFooter(bool dark) {
    if (_feedController.loadingMore) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 18),
        child: Center(
          child: CupertinoActivityIndicator(
            color: AppColors.subText(dark: dark),
          ),
        ),
      );
    }
    if (_feedController.loadMoreError != null) {
      return AppListPressable(
        onTap: _loadMore,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
          child: Center(
            child: Text(
              _feedController.loadMoreError ?? TIM_t('加载失败，点击重试'),
              style: TextStyle(
                color: AppColors.subText(dark: dark),
                fontSize: 13,
              ),
            ),
          ),
        ),
      );
    }
    if (!_feedController.hasMore && _feedController.posts.isNotEmpty) {
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
    return const SizedBox.shrink();
  }

  Future<void> _openCompose() async {
    final created = await Navigator.push<MomentPost?>(
      context,
      AppMaterialPageRoute(
        builder: (_) => MomentsComposePage(initialDraft: _feedController.draft),
      ),
    );
    if (!mounted) return;
    if (created != null) {
      await _feedController.refreshAfterNavigation();
      if (!mounted) return;
      setState(() {});
      ToastUtils.toast(TIM_t('已发布'));
      return;
    }
    await _feedController.refreshAfterNavigation();
    if (!mounted) return;
    setState(() {});
  }

  Future<void> _openDetail(MomentPost post) async {
    await Navigator.push<void>(
      context,
      AppMaterialPageRoute(
        builder: (_) => MomentsDetailPage(postId: post.id),
      ),
    );
    if (!mounted) return;
    await _feedController.refreshAfterNavigation();
    if (!mounted) return;
    setState(() {});
  }

  Future<void> _openNotifications() async {
    await Navigator.push<void>(
      context,
      AppMaterialPageRoute(
        builder: (_) => const MomentsNotificationsPage(),
      ),
    );
    if (!mounted) return;
    await _feedController.refreshAfterNavigation();
    await _loadHeaderExtras();
    if (!mounted) return;
    setState(() {});
  }

  Future<void> _pickCover() async {
    try {
      final url = await MomentsCoverPicker.pickAndSave(context);
      if (!mounted || url == null) return;
      setState(() => _coverUrl = url);
      ToastUtils.toast(TIM_t('封面已更新'));
    } catch (e) {
      if (!mounted) return;
      ToastUtils.toast(
          MomentsErrorMapper.map(e, action: 'publish').userMessage);
    }
  }

  Future<void> _toggleLike(MomentPost post) async {
    if (!_likingPostIds.add(post.id)) {
      return;
    }
    try {
      await _feedController.toggleLike(post);
      if (!mounted) return;
      setState(() {});
    } catch (e) {
      ToastUtils.toast(MomentsErrorMapper.map(e, action: 'like').userMessage);
    } finally {
      _likingPostIds.remove(post.id);
    }
  }

  Future<void> _quickComment(
    MomentPost post, {
    MomentComment? replyTo,
  }) async {
    if (_commentingPostIds.contains(post.id)) {
      return;
    }
    final controller = TextEditingController();
    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        final dark = Theme.of(sheetContext).brightness == Brightness.dark;
        return _CommentSheet(
          controller: controller,
          dark: dark,
          replyTo: replyTo,
        );
      },
    );
    if (ok != true || !mounted) {
      controller.dispose();
      return;
    }
    final text = controller.text.trim();
    if (text.isEmpty) {
      controller.dispose();
      ToastUtils.toast(TIM_t('请输入评论内容'));
      return;
    }
    if (!_commentingPostIds.add(post.id)) {
      controller.dispose();
      return;
    }
    try {
      await _feedController.addComment(
        post,
        text,
        replyToCommentId: replyTo?.id,
      );
      if (!mounted) return;
      setState(() {});
      ToastUtils.toast(
        replyTo == null ? TIM_t('已评论') : TIM_t('已回复'),
      );
    } catch (e) {
      ToastUtils.toast(
        MomentsErrorMapper.map(e, action: 'comment').userMessage,
      );
    } finally {
      _commentingPostIds.remove(post.id);
      controller.dispose();
    }
  }

  Future<void> _deletePost(MomentPost post) async {
    final ok = await AppDialog.confirm(
      title: TIM_t('删除朋友圈'),
      message: TIM_t('删除后无法恢复，确定删除吗？'),
      confirmText: TIM_t('删除'),
      destructive: true,
    );
    if (ok != true) return;
    try {
      await _feedController.deletePost(post);
      if (!mounted) return;
      setState(() {});
      ToastUtils.toast(TIM_t('已删除'));
    } catch (e) {
      ToastUtils.toast(
        MomentsErrorMapper.map(e, action: 'delete').userMessage,
      );
    }
  }

  Future<void> _showCommentActions(
    MomentPost post,
    MomentComment comment,
  ) async {
    final selfId = MomentsStore.safeLoginUserId();
    final canDelete = comment.canBeDeletedBy(
      selfId: selfId,
      isPostOwner: post.isOwnedBy(selfId),
    );
    await showCupertinoModalPopup<void>(
      context: context,
      builder: (sheetContext) => CupertinoActionSheet(
        actions: [
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.pop(sheetContext);
              // ActionSheet 关闭后再弹输入层，避免双 sheet 叠层冲突。
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (!mounted) return;
                _quickComment(post, replyTo: comment);
              });
            },
            child: Text(TIM_t('回复')),
          ),
          if (canDelete)
            CupertinoActionSheetAction(
              isDestructiveAction: true,
              onPressed: () {
                Navigator.pop(sheetContext);
                _deleteComment(post, comment);
              },
              child: Text(TIM_t('删除')),
            ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.pop(sheetContext),
          child: Text(TIM_t('取消')),
        ),
      ),
    );
  }

  Future<void> _deleteComment(MomentPost post, MomentComment comment) async {
    final commentId = comment.id.trim();
    if (commentId.isEmpty || !_deletingCommentIds.add(commentId)) {
      return;
    }
    final ok = await AppDialog.confirm(
      title: TIM_t('删除评论'),
      message: TIM_t('删除后无法恢复，确定删除吗？'),
      confirmText: TIM_t('删除'),
      destructive: true,
    );
    if (ok != true) {
      _deletingCommentIds.remove(commentId);
      return;
    }
    try {
      await _feedController.deleteComment(post, commentId);
      if (!mounted) return;
      setState(() {});
      ToastUtils.toast(TIM_t('已删除'));
    } catch (e) {
      ToastUtils.toast(
        MomentsErrorMapper.map(e, action: 'delete').userMessage,
      );
    } finally {
      _deletingCommentIds.remove(commentId);
    }
  }

  String _visibleRangeFriendHint(AppI18n i18n, int days) {
    switch (days) {
      case MomentsLocalPrefs.visibleRangeAll:
        return i18n.t(
          zhHans: '仅对朋友展示全部内容',
          zhHant: '僅對朋友展示全部內容',
          en: 'Friends can view all of your posts.',
          ja: 'Friends can view all of your posts.',
          ko: 'Friends can view all of your posts.',
        );
      case 3:
        return i18n.t(
          zhHans: '仅对朋友展示最近三天的内容',
          zhHant: '僅對朋友展示最近三天的內容',
          en: 'Friends can only view posts from the last 3 days.',
          ja: 'Friends can only view posts from the last 3 days.',
          ko: 'Friends can only view posts from the last 3 days.',
        );
      case 90:
        return i18n.t(
          zhHans: '仅对朋友展示最近三个月的内容',
          zhHant: '僅對朋友展示最近三個月的內容',
          en: 'Friends can only view posts from the last 3 months.',
          ja: 'Friends can only view posts from the last 3 months.',
          ko: 'Friends can only view posts from the last 3 months.',
        );
      case 180:
        return i18n.t(
          zhHans: '仅对朋友展示最近半年的内容',
          zhHant: '僅對朋友展示最近半年的內容',
          en: 'Friends can only view posts from the last 6 months.',
          ja: 'Friends can only view posts from the last 6 months.',
          ko: 'Friends can only view posts from the last 6 months.',
        );
      case 365:
        return i18n.t(
          zhHans: '仅对朋友展示最近一年的内容',
          zhHant: '僅對朋友展示最近一年的內容',
          en: 'Friends can only view posts from the last year.',
          ja: 'Friends can only view posts from the last year.',
          ko: 'Friends can only view posts from the last year.',
        );
      default:
        return MomentsLocalPrefs.visibleRangeFriendHint(days);
    }
  }

  String _visibleRangeViewerHint(AppI18n i18n, int days) {
    switch (days) {
      case 3:
        return i18n.t(
          zhHans: '仅展示最近三天的内容',
          zhHant: '僅展示最近三天的內容',
          en: 'Only showing posts from the last 3 days.',
          ja: 'Only showing posts from the last 3 days.',
          ko: 'Only showing posts from the last 3 days.',
        );
      case 90:
        return i18n.t(
          zhHans: '仅展示最近三个月的内容',
          zhHant: '僅展示最近三個月的內容',
          en: 'Only showing posts from the last 3 months.',
          ja: 'Only showing posts from the last 3 months.',
          ko: 'Only showing posts from the last 3 months.',
        );
      case 180:
        return i18n.t(
          zhHans: '仅展示最近半年的内容',
          zhHant: '僅展示最近半年的內容',
          en: 'Only showing posts from the last 6 months.',
          ja: 'Only showing posts from the last 6 months.',
          ko: 'Only showing posts from the last 6 months.',
        );
      case 365:
        return i18n.t(
          zhHans: '仅展示最近一年的内容',
          zhHant: '僅展示最近一年的內容',
          en: 'Only showing posts from the last year.',
          ja: 'Only showing posts from the last year.',
          ko: 'Only showing posts from the last year.',
        );
      default:
        return _visibleRangeFriendHint(i18n, days);
    }
  }

  Future<void> _openMomentsPermissionSettings() async {
    await Navigator.push<void>(
      context,
      AppMaterialPageRoute(
        builder: (_) => const MomentsPermissionPage(),
      ),
    );
    if (!mounted) return;
    await _loadHeaderExtras();
    if (!mounted) return;
    setState(() {});
  }

  Future<void> _openAuthorMoments(MomentUserSnapshot author) async {
    final authorId = author.id.trim();
    if (authorId.isEmpty) {
      return;
    }
    final profileName = UserDisplayProfile.nameOfSnapshot(author);
    final avatarUrl = UserDisplayProfile.avatarOfSnapshot(author);
    await Navigator.push<void>(
      context,
      AppMaterialPageRoute(
        builder: (_) => MomentsPage(
          authorId: authorId,
          profileName: profileName,
          profileAvatarUrl: avatarUrl.isNotEmpty ? avatarUrl : null,
          showCoverHeader: true,
        ),
      ),
    );
    if (!mounted) return;
    await _feedController.refreshAfterNavigation();
    if (!mounted) return;
    setState(() {});
  }

  String _resolveHeaderAvatar({
    required bool isProfileList,
    required String selfAvatar,
    required List<MomentPost> posts,
  }) {
    if (!isProfileList) {
      return selfAvatar;
    }
    final fromWidget = widget.profileAvatarUrl?.trim() ?? '';
    if (fromWidget.isNotEmpty) {
      return fromWidget;
    }
    for (final post in posts) {
      final avatar = post.author.avatarUrl.trim();
      if (avatar.isNotEmpty) {
        return avatar;
      }
    }
    return 'assets/default_avatar.png';
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final i18n = AppI18n.of(context);
    final loginUser = Provider.of<LoginUserInfo>(context).loginUserInfo;
    final selfId = MomentsStore.safeLoginUserId();
    final selfNameResolved = UserDisplayProfile.name(
      userId: selfId,
      imNickName: loginUser.nickName,
      fallbackName: i18n.t(
        zhHans: '我',
        zhHant: '我',
        en: 'Me',
        ja: '自分',
        ko: '나',
      ),
    );
    final selfName = selfNameResolved.trim().isNotEmpty
        ? selfNameResolved
        : i18n.t(
            zhHans: '我',
            zhHant: '我',
            en: 'Me',
            ja: '自分',
            ko: '나',
          );
    final liveSelfAvatar = UserDisplayProfile.avatar(
      userId: selfId,
      fallbackIm: loginUser.faceUrl,
      isSelf: true,
    );
    final selfAvatar = liveSelfAvatar.trim().isNotEmpty
        ? liveSelfAvatar
        : 'assets/default_avatar.png';
    final isProfileList = _feedController.isProfileList;
    final posts = _feedController.posts;
    final pageTitle = widget.profileName?.trim().isNotEmpty == true
        ? widget.profileName!.trim()
        : selfName;
    final isSelfMomentsPage =
        isProfileList && widget.authorId?.trim() == selfId.trim();
    final canOpenSelfMoments = !isProfileList;
    final showMomentsActions = !isProfileList || isSelfMomentsPage;
    final headerName = isProfileList ? pageTitle : selfName;
    final headerAvatar = _resolveHeaderAvatar(
      isProfileList: isProfileList,
      selfAvatar: selfAvatar,
      posts: posts,
    );
    final headerCoverPath =
        isProfileList && !isSelfMomentsPage ? null : _coverUrl;
    final visibleRangeDays = isSelfMomentsPage
        ? _visibleRangeDays
        : _feedController.authorVisibleRangeDays;
    final showVisibleRangeHint = isProfileList &&
        visibleRangeDays != null &&
        visibleRangeDays != MomentsLocalPrefs.visibleRangeAll;
    final profileTimelineEntries = isProfileList
        ? _profileTimelineEntries(posts)
        : const <_ProfileTimelineEntry>[];

    void handleBack() {
      if (widget.onClose != null) {
        widget.onClose!();
        return;
      }
      Navigator.of(context).pop();
    }

    return Scaffold(
      backgroundColor: _momentsPageBackground(dark),
      appBar: isProfileList && !widget.showCoverHeader
          ? AppBar(
              elevation: 0,
              backgroundColor: AppColors.card(dark: dark),
              surfaceTintColor: Colors.transparent,
              leading: IconButton(
                icon: const Icon(Icons.arrow_back_ios_new_rounded),
                color: _momentsNameColor,
                onPressed: handleBack,
              ),
              title: Text(
                pageTitle,
                style: TextStyle(
                  color: AppColors.text(dark: dark),
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                ),
              ),
            )
          : null,
      body: RefreshIndicator(
              onRefresh: () => _load(showRefreshing: true),
              child: CustomScrollView(
                controller: _scrollController,
                physics: const AlwaysScrollableScrollPhysics(
                  parent: BouncingScrollPhysics(),
                ),
                slivers: [
                  if (widget.showCoverHeader)
                    SliverToBoxAdapter(
                      child: _MomentsCoverHeader(
                        scrollController: _scrollController,
                        dark: dark,
                        displayName: headerName,
                        displayAvatar: headerAvatar,
                        coverAsset: _coverAsset,
                        coverPath: headerCoverPath,
                        onCompose: showMomentsActions ? _openCompose : null,
                        onNotifications:
                            showMomentsActions ? _openNotifications : null,
                        notificationUnreadCount: _notificationUnreadCount,
                        onCoverTap: showMomentsActions ? _pickCover : null,
                        onBack: widget.embedded ? null : handleBack,
                        onProfileTap: canOpenSelfMoments
                            ? () => _openAuthorMoments(
                                  MomentUserSnapshot(
                                    id: selfId,
                                    name: selfName,
                                    avatarUrl: selfAvatar,
                                  ),
                                )
                            : null,
                      ),
                    ),
                  if (isSelfMomentsPage)
                    SliverToBoxAdapter(
                      child: _TodayComposerEntry(
                        dark: dark,
                        onTap: _openCompose,
                      ),
                    ),
                  if (showVisibleRangeHint)
                    SliverToBoxAdapter(
                      child: _VisibleRangeHintSection(
                        dark: dark,
                        hint: isSelfMomentsPage
                            ? _visibleRangeFriendHint(i18n, visibleRangeDays)
                            : _visibleRangeViewerHint(i18n, visibleRangeDays),
                        showGoSettings: isSelfMomentsPage,
                        onGoSettings: _openMomentsPermissionSettings,
                      ),
                    ),
                  if (_feedController.error != null)
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                        child: Text(
                          _feedController.error!,
                          style: TextStyle(
                            color: AppColors.subText(dark: dark),
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ),
                  if (_feedController.loading && posts.isEmpty)
                    const SliverFillRemaining(
                      hasScrollBody: false,
                      child: Center(child: CupertinoActivityIndicator()),
                    )
                  else if (posts.isEmpty)
                    SliverFillRemaining(
                      hasScrollBody: false,
                      child: Center(
                        child: AppEmptyState(
                          imageWidth: 180,
                          message: i18n.t(
                            zhHans: isProfileList ? '还没有发布朋友圈' : '还没有朋友圈内容',
                            zhHant: isProfileList ? '還沒有發佈朋友圈' : '還沒有朋友圈內容',
                            en: isProfileList
                                ? 'No posts yet.'
                                : 'No moments yet.',
                            ja: isProfileList ? 'まだ投稿はありません。' : 'まだ投稿はありません。',
                            ko: isProfileList
                                ? '아직 게시물이 없습니다.'
                                : '아직 게시물이 없습니다.',
                          ),
                        ),
                      ),
                    )
                  else if (isProfileList)
                    SliverPadding(
                      padding: EdgeInsets.fromLTRB(
                        0,
                        widget.showCoverHeader ? 4 : 12,
                        0,
                        24,
                      ),
                      sliver: SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (context, index) {
                            final entry = profileTimelineEntries[index];
                            return Column(
                              children: [
                                _ProfileTimelineItem(
                                  post: entry.post,
                                  dark: dark,
                                  showDate: entry.showDate,
                                  groupDate: entry.day,
                                  onTap: () => _openDetail(entry.post),
                                ),
                                if (index < profileTimelineEntries.length - 1)
                                  Divider(
                                    height: 22,
                                    thickness: 0.6,
                                    indent: 96,
                                    color: AppColors.line(dark: dark),
                                  ),
                              ],
                            );
                          },
                          childCount: profileTimelineEntries.length,
                        ),
                      ),
                    )
                  else
                    SliverPadding(
                      padding: EdgeInsets.fromLTRB(
                        0,
                        widget.showCoverHeader ? 4 : 12,
                        0,
                        24,
                      ),
                      sliver: SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (context, index) {
                            final post = posts[index];
                            return Column(
                              children: [
                                _MomentCard(
                                  post: post,
                                  dark: dark,
                                  onTap: () => _openDetail(post),
                                  onAuthorTap: () =>
                                      _openAuthorMoments(post.author),
                                  onLike: () => _toggleLike(post),
                                  onComment: () => _quickComment(post),
                                  onCommentLongPress: (comment) =>
                                      _showCommentActions(post, comment),
                                  onDelete: post.isOwnedBy(
                                          MomentsStore.safeLoginUserId())
                                      ? () => _deletePost(post)
                                      : null,
                                ),
                                if (index < posts.length - 1)
                                  Divider(
                                    height: 12,
                                    thickness: 0.6,
                                    color: AppColors.line(dark: dark),
                                  ),
                              ],
                            );
                          },
                          childCount: posts.length,
                        ),
                      ),
                    ),
                  if (posts.isNotEmpty)
                    SliverToBoxAdapter(
                      child: _buildLoadMoreFooter(dark),
                    ),
                ],
              ),
            ),
    );
  }

  List<_ProfileTimelineEntry> _profileTimelineEntries(List<MomentPost> posts) {
    if (posts.isEmpty) {
      return const [];
    }
    final entries = <_ProfileTimelineEntry>[];
    DateTime? currentDay;
    for (final post in posts) {
      final local = post.createdAt.toLocal();
      final day = DateTime(local.year, local.month, local.day);
      final showDate = currentDay == null || day != currentDay;
      entries.add(
        _ProfileTimelineEntry(
          post: post,
          day: day,
          showDate: showDate,
        ),
      );
      currentDay = day;
    }
    return entries;
  }
}

class _ProfileTimelineEntry {
  const _ProfileTimelineEntry({
    required this.post,
    required this.day,
    required this.showDate,
  });

  final MomentPost post;
  final DateTime day;
  final bool showDate;
}

class _MomentsCoverHeader extends StatefulWidget {
  const _MomentsCoverHeader({
    required this.scrollController,
    required this.dark,
    required this.displayName,
    required this.displayAvatar,
    required this.coverAsset,
    required this.onCompose,
    required this.onNotifications,
    required this.onProfileTap,
    this.coverPath,
    this.notificationUnreadCount = 0,
    this.onCoverTap,
    this.onBack,
  });

  final ScrollController scrollController;
  final bool dark;
  final String displayName;
  final String displayAvatar;
  final String coverAsset;
  final String? coverPath;
  final int notificationUnreadCount;
  final VoidCallback? onCompose;
  final VoidCallback? onNotifications;
  final VoidCallback? onCoverTap;
  final VoidCallback? onProfileTap;
  final VoidCallback? onBack;

  @override
  State<_MomentsCoverHeader> createState() => _MomentsCoverHeaderState();
}

class _MomentsCoverHeaderState extends State<_MomentsCoverHeader> {
  double _stretch = 0;

  @override
  void initState() {
    super.initState();
    widget.scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    widget.scrollController.removeListener(_onScroll);
    super.dispose();
  }

  void _onScroll() {
    if (!widget.scrollController.hasClients) return;
    final next = widget.scrollController.offset < 0
        ? -widget.scrollController.offset
        : 0.0;
    if ((next - _stretch).abs() < 0.5) return;
    setState(() => _stretch = next);
  }

  @override
  Widget build(BuildContext context) {
    return _HeaderCard(
      dark: widget.dark,
      displayName: widget.displayName,
      displayAvatar: widget.displayAvatar,
      coverAsset: widget.coverAsset,
      coverPath: widget.coverPath,
      coverStretch: _stretch,
      onCompose: widget.onCompose,
      onNotifications: widget.onNotifications,
      notificationUnreadCount: widget.notificationUnreadCount,
      onCoverTap: widget.onCoverTap,
      onProfileTap: widget.onProfileTap,
      onBack: widget.onBack,
    );
  }
}

class _CoverImage extends StatelessWidget {
  const _CoverImage({
    required this.coverAsset,
    this.coverPath,
  });

  final String coverAsset;
  final String? coverPath;

  @override
  Widget build(BuildContext context) {
    const coverFallback = Color(0xFF3A3A3A);
    final path = coverPath?.trim() ?? '';
    final image = path.isNotEmpty &&
            (path.startsWith('http') || File(path).existsSync())
        ? MomentsMediaThumbnail(
            path: path,
            fallbackLogicalSize: 420,
            placeholderColor: coverFallback,
          )
        : Image.asset(
            coverAsset,
            fit: BoxFit.cover,
            gaplessPlayback: true,
          );
    return ColoredBox(
      color: coverFallback,
      child: image,
    );
  }
}

class _NotificationIconButton extends StatelessWidget {
  const _NotificationIconButton({
    required this.onPressed,
    required this.unreadCount,
  });

  final VoidCallback onPressed;
  final int unreadCount;

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        IconButton(
          tooltip: TIM_t('消息'),
          onPressed: onPressed,
          icon: const Icon(Icons.notifications_none_rounded),
          color: Colors.white,
        ),
        if (unreadCount > 0)
          Positioned(
            right: 6,
            top: 6,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
              constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
              decoration: BoxDecoration(
                color: AppColors.primaryRed,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.white, width: 1.2),
              ),
              alignment: Alignment.center,
              child: Text(
                unreadCount > 99 ? '99+' : '$unreadCount',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  height: 1,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _HeaderCard extends StatelessWidget {
  const _HeaderCard({
    required this.dark,
    required this.displayName,
    required this.displayAvatar,
    required this.coverAsset,
    required this.onCompose,
    required this.onNotifications,
    required this.onProfileTap,
    this.coverPath,
    this.coverStretch = 0,
    this.notificationUnreadCount = 0,
    this.onCoverTap,
    this.onBack,
  });

  static const double _coverBaseHeight = 224;
  static const double _headerBaseHeight = 268;
  static const double _profileTop = 190;

  final bool dark;
  final String displayName;
  final String displayAvatar;
  final String coverAsset;
  final String? coverPath;
  final double coverStretch;
  final int notificationUnreadCount;
  final VoidCallback? onCompose;
  final VoidCallback? onNotifications;
  final VoidCallback? onCoverTap;
  final VoidCallback? onProfileTap;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    final coverHeight = _coverBaseHeight + coverStretch;
    final headerHeight = _headerBaseHeight + coverStretch;
    final profileTop = _profileTop + coverStretch;
    final zoomScale = 1 + (coverStretch / _coverBaseHeight) * 0.35;

    return SizedBox(
      height: headerHeight,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: coverHeight,
            child: ClipRect(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  GestureDetector(
                    onTap: onCoverTap,
                    child: Transform.scale(
                      scale: zoomScale,
                      alignment: Alignment.topCenter,
                      child: Align(
                        alignment: Alignment.topCenter,
                        child: SizedBox(
                          height: coverHeight,
                          width: MediaQuery.sizeOf(context).width,
                          child: _CoverImage(
                            coverAsset: coverAsset,
                            coverPath: coverPath,
                          ),
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    child: SafeArea(
                      bottom: false,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: Row(
                          children: [
                            if (onBack != null)
                              IconButton(
                                onPressed: onBack,
                                icon: const Icon(
                                    Icons.arrow_back_ios_new_rounded),
                                color: Colors.white,
                                tooltip: TIM_t('返回'),
                              )
                            else
                              const SizedBox(width: 48),
                            const Spacer(),
                            if (onNotifications != null)
                              _NotificationIconButton(
                                onPressed: onNotifications!,
                                unreadCount: notificationUnreadCount,
                              ),
                            if (onCompose != null)
                              IconButton(
                                tooltip: TIM_t('发布'),
                                onPressed: onCompose,
                                icon: const Icon(Icons.camera_alt_outlined),
                                color: Colors.white,
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            right: 16,
            top: profileTop,
            child: AppListPressable(
              onTap: onProfileTap,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Text(
                      displayName,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        shadows: [
                          Shadow(
                            color: Color(0x66000000),
                            blurRadius: 6,
                            offset: Offset(0, 2),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Container(
                    padding: const EdgeInsets.all(3),
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                    ),
                    child: AppUserAvatar(
                      faceUrl: displayAvatar,
                      showName: displayName,
                      size: 78,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _VisibleRangeHintSection extends StatelessWidget {
  const _VisibleRangeHintSection({
    required this.dark,
    required this.hint,
    required this.showGoSettings,
    required this.onGoSettings,
  });

  final bool dark;
  final String hint;
  final bool showGoSettings;
  final VoidCallback onGoSettings;

  @override
  Widget build(BuildContext context) {
    final i18n = AppI18n.of(context);
    final lineColor = AppColors.line(dark: dark);
    final textColor = AppColors.subText(dark: dark);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 12),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Divider(
                  color: lineColor,
                  height: 1,
                  thickness: 0.6,
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Text(
                  hint,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: textColor,
                    fontSize: 13,
                    height: 1.35,
                  ),
                ),
              ),
              Expanded(
                child: Divider(
                  color: lineColor,
                  height: 1,
                  thickness: 0.6,
                ),
              ),
            ],
          ),
          if (showGoSettings) ...[
            const SizedBox(height: 12),
            AppListPressable(
              onTap: onGoSettings,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Text(
                  i18n.t(
                    zhHans: '前往设置',
                    zhHant: '前往設定',
                    en: 'Go to Settings',
                    ja: '設定へ',
                    ko: '설정으로 이동',
                  ),
                  style: const TextStyle(
                    color: AppColors.primaryBlue,
                    fontSize: 14,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _TodayComposerEntry extends StatelessWidget {
  const _TodayComposerEntry({
    required this.dark,
    required this.onTap,
  });

  final bool dark;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AppListPressable(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 18, 16, 18),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 64,
              child: Text(
                TIM_t('今天'),
                textAlign: TextAlign.right,
                style: TextStyle(
                  color: AppColors.text(dark: dark),
                  fontSize: 28,
                  height: 1,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Container(
              width: 104,
              height: 104,
              decoration: BoxDecoration(
                color: dark ? const Color(0xFF22252B) : const Color(0xFFF6F6F6),
                borderRadius: BorderRadius.circular(2),
              ),
              alignment: Alignment.center,
              child: Icon(
                Icons.camera_alt_rounded,
                size: 34,
                color: dark
                    ? AppColors.darkSubText.withValues(alpha: 0.55)
                    : const Color(0xFFD0D0D0),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MomentCard extends StatefulWidget {
  const _MomentCard({
    required this.post,
    required this.dark,
    required this.onTap,
    required this.onAuthorTap,
    required this.onLike,
    required this.onComment,
    required this.onCommentLongPress,
    required this.onDelete,
  });

  final MomentPost post;
  final bool dark;
  final VoidCallback onTap;
  final VoidCallback onAuthorTap;
  final VoidCallback onLike;
  final VoidCallback onComment;
  final void Function(MomentComment comment) onCommentLongPress;
  final VoidCallback? onDelete;

  @override
  State<_MomentCard> createState() => _MomentCardState();
}

class _MomentCardState extends State<_MomentCard> {
  bool _showActions = false;

  void _hideActions() {
    if (_showActions) {
      setState(() => _showActions = false);
    }
  }

  void _runAction(VoidCallback action) {
    _hideActions();
    action();
  }

  @override
  Widget build(BuildContext context) {
    final selfId = MomentsStore.safeLoginUserId();
    final dark = widget.dark;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              GestureDetector(
                onTap: widget.onAuthorTap,
                behavior: HitTestBehavior.opaque,
                child: MomentsUserAvatar(
                  user: widget.post.author,
                  size: 44,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    GestureDetector(
                      onTap: widget.onAuthorTap,
                      behavior: HitTestBehavior.opaque,
                      child: Text(
                        UserDisplayProfile.nameOfSnapshot(widget.post.author),
                        style: const TextStyle(
                          color: _momentsNameColor,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(height: 2),
                    if (widget.post.text.trim().isNotEmpty)
                      GestureDetector(
                        onTap: widget.onTap,
                        child: Text(
                          widget.post.text,
                          style: TextStyle(
                            color: AppColors.text(dark: dark),
                            fontSize: 15,
                            height: 1.45,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
          if (widget.post.hasMedia) ...[
            const SizedBox(height: 5),
            Padding(
              padding: const EdgeInsets.only(left: 54),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 322),
                child: _MediaGrid(post: widget.post),
              ),
            ),
          ],
          const SizedBox(height: 3),
          Padding(
            padding: const EdgeInsets.only(left: 54),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Row(
                  children: [
                    GestureDetector(
                      onTap: widget.onTap,
                      child: Text(
                        _formatRelative(widget.post.createdAt),
                        style: TextStyle(
                          color: AppColors.subText(dark: dark),
                          fontSize: 11,
                        ),
                      ),
                    ),
                    if ((widget.post.location ?? '').trim().isNotEmpty) ...[
                      const SizedBox(width: 8),
                      Text(
                        widget.post.location!.trim(),
                        style: TextStyle(
                          color: AppColors.subText(dark: dark),
                          fontSize: 11,
                        ),
                      ),
                    ],
                    const Spacer(),
                    _MomentMoreButton(
                      dark: dark,
                      onTap: () {
                        setState(() => _showActions = !_showActions);
                      },
                    ),
                  ],
                ),
                if (_showActions)
                  Positioned(
                    right: 40,
                    top: -6,
                    child: _MomentInlineActions(
                      likedBySelf: widget.post.likedBy(selfId),
                      canDelete: widget.onDelete != null,
                      onOpen: () => _runAction(widget.onTap),
                      onLike: () => _runAction(widget.onLike),
                      onComment: () => _runAction(widget.onComment),
                      onDelete: widget.onDelete == null
                          ? null
                          : () => _runAction(widget.onDelete!),
                    ),
                  ),
              ],
            ),
          ),
          if (widget.post.likes.isNotEmpty ||
              widget.post.comments.isNotEmpty ||
              widget.post.commentCount > 0) ...[
            const SizedBox(height: 5),
            Padding(
              padding: const EdgeInsets.only(left: 54),
              child: _EngagementRow(
                post: widget.post,
                dark: dark,
                onTap: widget.onTap,
                onCommentLongPress: widget.onCommentLongPress,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ProfileTimelineItem extends StatelessWidget {
  const _ProfileTimelineItem({
    required this.post,
    required this.dark,
    required this.showDate,
    required this.groupDate,
    required this.onTap,
  });

  final MomentPost post;
  final bool dark;
  final bool showDate;
  final DateTime groupDate;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AppListPressable(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 64,
              child:
                  showDate ? _TimelineDate(date: groupDate, dark: dark) : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (post.hasMedia) ...[
                    _ProfileTimelineMedia(post: post),
                    const SizedBox(width: 12),
                  ],
                  Expanded(
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: post.text.trim().isNotEmpty
                          ? Text(
                              post.text.trim(),
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: AppColors.text(dark: dark),
                                fontSize: 16,
                                height: 1.35,
                              ),
                            )
                          : Text(
                              post.hasMedia ? TIM_t('分享图片') : TIM_t('这一刻'),
                              style: TextStyle(
                                color: AppColors.subText(dark: dark),
                                fontSize: 15,
                              ),
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TimelineDate extends StatelessWidget {
  const _TimelineDate({
    required this.date,
    required this.dark,
  });

  final DateTime date;
  final bool dark;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final local = date.toLocal();
    final isThisYear = local.year == now.year;

    if (local == today) {
      return Text(
        TIM_t('今天'),
        textAlign: TextAlign.right,
        style: TextStyle(
          color: AppColors.text(dark: dark),
          fontSize: 28,
          height: 1,
          fontWeight: FontWeight.w700,
        ),
      );
    }
    if (local == yesterday) {
      return Text(
        TIM_t('昨天'),
        textAlign: TextAlign.right,
        style: TextStyle(
          color: AppColors.text(dark: dark),
          fontSize: 28,
          height: 1,
          fontWeight: FontWeight.w700,
        ),
      );
    }

    final dayText = local.day.toString().padLeft(2, '0');
    final monthText =
        isThisYear ? '${local.month}月' : '${local.year}.${local.month}';

    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        Text(
          dayText,
          style: TextStyle(
            color: AppColors.text(dark: dark),
            fontSize: 26,
            height: 1,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(width: 2),
        Text(
          monthText,
          style: TextStyle(
            color: AppColors.subText(dark: dark),
            fontSize: 12,
          ),
        ),
      ],
    );
  }
}

class _ProfileTimelineMedia extends StatelessWidget {
  const _ProfileTimelineMedia({required this.post});

  final MomentPost post;

  @override
  Widget build(BuildContext context) {
    final items = post.attachments;
    if (items.isEmpty) return const SizedBox.shrink();
    return SizedBox(
      width: 104,
      height: 104,
      child: _buildCollage(context, items),
    );
  }

  Widget _buildCollage(BuildContext context, List<MomentAttachment> items) {
    if (items.length == 1) {
      return _collageTile(context, items.first, 0);
    }
    if (items.length == 2) {
      return Row(
        children: [
          Expanded(child: _collageTile(context, items[0], 0)),
          const SizedBox(width: 3),
          Expanded(child: _collageTile(context, items[1], 1)),
        ],
      );
    }
    if (items.length > 4) {
      return Row(
        children: [
          Expanded(child: _collageTile(context, items[0], 0)),
          const SizedBox(width: 3),
          Expanded(
            child: Stack(
              fit: StackFit.expand,
              children: [
                _collageTile(context, items[1], 1),
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.42),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Center(
                    child: Text(
                      '+${items.length - 2}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      );
    }
    if (items.length == 3) {
      return Row(
        children: [
          Expanded(
            child: _collageTile(context, items[0], 0),
          ),
          const SizedBox(width: 3),
          Expanded(
            child: Column(
              children: [
                Expanded(child: _collageTile(context, items[1], 1)),
                const SizedBox(height: 3),
                Expanded(child: _collageTile(context, items[2], 2)),
              ],
            ),
          ),
        ],
      );
    }
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: EdgeInsets.zero,
      itemCount: 4,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 3,
        crossAxisSpacing: 3,
      ),
      itemBuilder: (context, index) {
        return Stack(
          fit: StackFit.expand,
          children: [
            _collageTile(context, items[index], index),
            if (index == 3 && items.length > 4)
              DecoratedBox(
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.42),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Center(
                  child: Text(
                    '+${items.length - 4}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _collageTile(
    BuildContext context,
    MomentAttachment item,
    int index,
  ) {
    return _MomentMediaTile(
      item: item,
      onTap: () => _openMedia(context, post, index),
    );
  }

  void _openMedia(BuildContext context, MomentPost post, int index) {
    final item = post.attachments[index];
    if (item.isVideo) {
      final path = item.displayPath;
      if (path.isEmpty) return;
      MomentsVideoPlayerPage.push(
        context,
        source: path,
        title: UserDisplayProfile.nameOfSnapshot(post.author),
      );
      return;
    }
    openMomentImagePreview(
      context,
      post: post,
      attachmentIndex: index,
    );
  }
}

class _MediaGrid extends StatelessWidget {
  const _MediaGrid({required this.post});

  final MomentPost post;

  @override
  Widget build(BuildContext context) {
    final items = post.attachments;
    if (items.isEmpty) return const SizedBox.shrink();
    if (items.length == 1) {
      final item = items.first;
      return MomentsSingleMediaFrame(
        item: item,
        imageProvider:
            item.isImage ? momentImageProvider(item.displayPath) : null,
        child: _MomentMediaTile(
          item: item,
          onTap: () => _openMedia(context, post, 0),
        ),
      );
    }
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: EdgeInsets.zero,
      itemCount: items.length > 9 ? 9 : items.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisSpacing: 4,
        crossAxisSpacing: 4,
      ),
      itemBuilder: (context, index) {
        final item = items[index];
        return _MomentMediaTile(
          item: item,
          onTap: () => _openMedia(context, post, index),
        );
      },
    );
  }

  void _openMedia(BuildContext context, MomentPost post, int index) {
    final item = post.attachments[index];
    if (item.isVideo) {
      final path = item.displayPath;
      if (path.isEmpty) return;
      MomentsVideoPlayerPage.push(
        context,
        source: path,
        title: UserDisplayProfile.nameOfSnapshot(post.author),
      );
      return;
    }
    openMomentImagePreview(
      context,
      post: post,
      attachmentIndex: index,
    );
  }
}

class _MomentMediaTile extends StatelessWidget {
  const _MomentMediaTile({
    required this.item,
    required this.onTap,
  });

  final MomentAttachment item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final child = Stack(
      fit: StackFit.expand,
      children: [
        _mediaImage(),
        if (item.isVideo)
          const Center(
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: Color(0x66000000),
                shape: BoxShape.circle,
              ),
              child: Padding(
                padding: EdgeInsets.all(10),
                child: Icon(
                  Icons.play_arrow_rounded,
                  color: Colors.white,
                  size: 28,
                ),
              ),
            ),
          ),
        if (item.isVideo && (item.durationSec ?? 0) > 0)
          Positioned(
            right: 6,
            bottom: 6,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: const Color(0x66000000),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                child: Text(
                  _formatDuration(item.durationSec!),
                  style: const TextStyle(color: Colors.white, fontSize: 10),
                ),
              ),
            ),
          ),
        if (MomentsMediaLayout.isLongImage(item))
          Positioned(
            right: 6,
            bottom: 6,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: const Color(0x8A000000),
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                child: Text('长图',
                    style: TextStyle(color: Colors.white, fontSize: 10)),
              ),
            ),
          ),
      ],
    );
    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(6),
        child: child,
      ),
    );
  }

  Widget _mediaImage() {
    final raw = item.displayPath;
    return MomentsMediaThumbnail(path: raw, fallbackLogicalSize: 160);
  }

  String _formatDuration(int seconds) {
    final safe = seconds < 0 ? 0 : seconds;
    final minutes = safe ~/ 60;
    final remainder = safe % 60;
    return '${minutes.toString().padLeft(2, '0')}:${remainder.toString().padLeft(2, '0')}';
  }
}

class _EngagementRow extends StatelessWidget {
  const _EngagementRow({
    required this.post,
    required this.dark,
    required this.onTap,
    required this.onCommentLongPress,
  });

  final MomentPost post;
  final bool dark;
  final VoidCallback onTap;
  final void Function(MomentComment comment) onCommentLongPress;

  @override
  Widget build(BuildContext context) {
    final likePreview = post.likes.take(8).toList();
    final commentPreview = post.comments.take(2).toList();
    final showLikes = likePreview.isNotEmpty;
    final showComments = commentPreview.isNotEmpty || post.commentCount > 0;
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: _momentsPanelColor(dark),
        borderRadius: BorderRadius.circular(6),
      ),
      padding: const EdgeInsets.fromLTRB(9, 7, 9, 7),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (showLikes) ...[
            GestureDetector(
              onTap: onTap,
              behavior: HitTestBehavior.opaque,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.favorite_rounded,
                    size: 15,
                    color: AppColors.primaryRed,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Wrap(
                      spacing: 4,
                      runSpacing: 4,
                      children: likePreview
                          .map(
                            (item) => MomentsUserAvatar(
                              user: item.author,
                              size: 24,
                            ),
                          )
                          .toList(),
                    ),
                  ),
                ],
              ),
            ),
          ],
          if (showComments) ...[
            if (showLikes) ...[
              const SizedBox(height: 6),
              Divider(
                height: 1,
                thickness: 0.6,
                color: AppColors.line(dark: dark),
              ),
              const SizedBox(height: 6),
            ],
            if (commentPreview.isNotEmpty)
              ...commentPreview.map((item) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 3),
                  child: SizedBox(
                    width: double.infinity,
                    child: GestureDetector(
                      // 整行拉满宽度：点右侧空白同样弹出回复/删除。
                      onTap: () => onCommentLongPress(item),
                      onLongPress: () => onCommentLongPress(item),
                      behavior: HitTestBehavior.opaque,
                      child: _CommentInlineText(
                        comment: item,
                        dark: dark,
                        maxLines: 2,
                      ),
                    ),
                  ),
                );
              })
            else if (post.commentCount > 0)
              GestureDetector(
                onTap: onTap,
                behavior: HitTestBehavior.opaque,
                child: Text(
                  _formatCommentCount(post.commentCount),
                  style: TextStyle(
                    color: AppColors.subText(dark: dark),
                    fontSize: 13,
                    height: 1.25,
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }
}

class _CommentInlineText extends StatelessWidget {
  const _CommentInlineText({
    required this.comment,
    required this.dark,
    this.maxLines,
  });

  final MomentComment comment;
  final bool dark;
  final int? maxLines;

  @override
  Widget build(BuildContext context) {
    return Text.rich(
      TextSpan(
        style: TextStyle(
          color: AppColors.text(dark: dark),
          fontSize: 13,
          height: 1.25,
        ),
        children: [
          TextSpan(
            text: UserDisplayProfile.nameOfSnapshot(comment.author),
            style: const TextStyle(
              color: _momentsNameColor,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (comment.isReply) ...[
            TextSpan(text: TIM_t(' 回复 ')),
            TextSpan(
              text: UserDisplayProfile.nameOfSnapshot(comment.replyToUser!),
              style: const TextStyle(
                color: _momentsNameColor,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
          const TextSpan(text: '：'),
          TextSpan(text: comment.text),
        ],
      ),
      maxLines: maxLines,
      overflow: maxLines == null ? TextOverflow.clip : TextOverflow.ellipsis,
    );
  }
}

class _MomentMoreButton extends StatelessWidget {
  const _MomentMoreButton({
    required this.dark,
    required this.onTap,
  });

  final bool dark;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AppListPressable(
      onTap: onTap,
      child: Container(
        width: 34,
        height: 24,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: _momentsButtonColor(dark),
          borderRadius: BorderRadius.circular(4),
        ),
        child: const Icon(
          Icons.more_horiz_rounded,
          color: _momentsNameColor,
          size: 19,
        ),
      ),
    );
  }
}

class _MomentInlineActions extends StatelessWidget {
  const _MomentInlineActions({
    required this.likedBySelf,
    required this.canDelete,
    required this.onOpen,
    required this.onLike,
    required this.onComment,
    this.onDelete,
  });

  final bool likedBySelf;
  final bool canDelete;
  final VoidCallback onOpen;
  final VoidCallback onLike;
  final VoidCallback onComment;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Container(
        height: 36,
        decoration: BoxDecoration(
          color: _momentsActionBarColor,
          borderRadius: BorderRadius.circular(6),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _InlineActionButton(
              icon: likedBySelf
                  ? Icons.favorite_rounded
                  : Icons.favorite_border_rounded,
              label: likedBySelf ? TIM_t('取消') : TIM_t('赞'),
              onTap: onLike,
            ),
            const _InlineActionDivider(),
            _InlineActionButton(
              icon: Icons.mode_comment_outlined,
              label: TIM_t('评论'),
              onTap: onComment,
            ),
            const _InlineActionDivider(),
            _InlineActionButton(
              icon: Icons.notes_rounded,
              label: TIM_t('详情'),
              onTap: onOpen,
            ),
            if (canDelete) ...[
              const _InlineActionDivider(),
              _InlineActionButton(
                icon: Icons.delete_outline_rounded,
                label: TIM_t('删除'),
                onTap: onDelete,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _InlineActionButton extends StatelessWidget {
  const _InlineActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(4),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 9),
        child: Row(
          children: [
            Icon(icon, color: Colors.white, size: 17),
            const SizedBox(width: 4),
            Text(
              label,
              style: const TextStyle(color: Colors.white, fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }
}

class _InlineActionDivider extends StatelessWidget {
  const _InlineActionDivider();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 0.6,
      height: 18,
      color: Colors.white.withValues(alpha: 0.18),
    );
  }
}

class _CommentSheet extends StatelessWidget {
  const _CommentSheet({
    required this.controller,
    required this.dark,
    this.replyTo,
  });

  final TextEditingController controller;
  final bool dark;
  final MomentComment? replyTo;

  @override
  Widget build(BuildContext context) {
    final target = replyTo;
    final replyName = target == null
        ? ''
        : UserDisplayProfile.nameOfSnapshot(target.author).trim();
    final title = replyTo == null
        ? TIM_t('评论')
        : '${TIM_t('回复')} ${replyName.isEmpty ? TIM_t('评论') : replyName}';
    final hint = replyTo == null
        ? TIM_t('说点什么')
        : '${TIM_t('回复')} ${replyName.isEmpty ? '' : replyName}'.trim();

    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: AppColors.card(dark: dark),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: AppColors.text(dark: dark),
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (replyTo != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    replyTo!.text,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: AppColors.subText(dark: dark),
                      fontSize: 13,
                      height: 1.3,
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                TextField(
                  controller: controller,
                  autofocus: true,
                  minLines: 2,
                  maxLines: 5,
                  textInputAction: TextInputAction.send,
                  onSubmitted: (_) => Navigator.of(context).pop(true),
                  decoration: InputDecoration(
                    hintText: hint,
                    filled: true,
                    fillColor: _momentsPanelColor(dark),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(false),
                      child: Text(TIM_t('取消')),
                    ),
                    const SizedBox(width: 8),
                    FilledButton(
                      onPressed: () => Navigator.of(context).pop(true),
                      child: Text(TIM_t('发送')),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

String _formatRelative(DateTime createdAt) {
  final local = createdAt.toLocal();
  final diff = DateTime.now().difference(local);
  if (diff.inMinutes < 1) {
    return TIM_t('刚刚');
  }
  if (diff.inHours < 1) {
    final option1 = diff.inMinutes.toString();
    return TIM_t_para('{{option1}} 分钟前', '$option1 分钟前')(
      option1: option1,
    );
  }
  if (diff.inDays < 1) {
    final option1 = diff.inHours.toString();
    return TIM_t_para('{{option1}} 小时前', '$option1 小时前')(
      option1: option1,
    );
  }
  if (diff.inDays < 7) {
    final option1 = diff.inDays.toString();
    return TIM_t_para('{{option1}} 天前', '$option1 天前')(
      option1: option1,
    );
  }
  return '${local.month.toString().padLeft(2, '0')}-${local.day.toString().padLeft(2, '0')}';
}

String _formatCommentCount(int count) {
  final option1 = count.toString();
  return TIM_t_para('{{option1}} 评论', '$option1 评论')(option1: option1);
}
