import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:tencent_chat_i18n_tool/tencent_chat_i18n_tool.dart';
import 'package:tencent_cloud_chat_demo/src/models/moments/moment_models.dart';
import 'package:tencent_cloud_chat_demo/src/services/moments/moments_error_mapper.dart';
import 'package:tencent_cloud_chat_demo/src/services/moments/moments_store.dart';
import 'package:tencent_cloud_chat_demo/src/theme/app_colors.dart';
import 'package:tencent_cloud_chat_demo/src/ui/app_tokens.dart';
import 'package:tencent_cloud_chat_demo/utils/toast.dart';
import 'package:tencent_cloud_chat_demo/src/widgets/app_dialog.dart';
import 'package:tencent_cloud_chat_demo/src/widgets/app_empty_state.dart';
import 'package:tencent_cloud_chat_demo/src/pages/moments/moments_user_avatar.dart';
import 'package:tencent_cloud_chat_demo/src/services/peer_profile_refresh_bus.dart';
import 'package:tencent_cloud_chat_demo/utils/user_display_profile.dart';
import 'package:tencent_cloud_chat_demo/src/widgets/app_list_pressable.dart';
import 'package:tencent_cloud_chat_demo/src/pages/moments/moments_image_preview.dart';
import 'package:tencent_cloud_chat_demo/src/pages/moments/moments_navigation.dart';
import 'package:tencent_cloud_chat_demo/src/pages/moments/moments_video_player_page.dart';
import 'package:tencent_cloud_chat_demo/src/pages/moments/moments_media_thumbnail.dart';
import 'package:tencent_cloud_chat_demo/src/pages/moments/moments_media_layout.dart';

const Color _momentsNameColor = AppTokens.ink600;

Color _momentsPageBackground(bool dark) =>
    dark ? AppColors.background(dark: true) : AppColors.card(dark: false);

Color _momentsPanelColor(bool dark) => AppColors.surfaceAlt(dark: dark);

class MomentsDetailPage extends StatefulWidget {
  const MomentsDetailPage({
    super.key,
    required this.postId,
  });

  final String postId;

  @override
  State<MomentsDetailPage> createState() => _MomentsDetailPageState();
}

class _MomentsDetailPageState extends State<MomentsDetailPage> {
  MomentPost? _post;
  bool _loading = true;
  String? _error;
  MomentComment? _replyToComment;
  final TextEditingController _commentController = TextEditingController();
  final FocusNode _commentFocusNode = FocusNode();
  bool _liking = false;
  bool _commentSubmitting = false;
  bool _commentDeleting = false;

  @override
  void initState() {
    super.initState();
    PeerProfileRefreshBus.instance.revision.addListener(_onPeerProfileRefresh);
    _load();
  }

  void _onPeerProfileRefresh() {
    if (!mounted) return;
    setState(() {});
  }

  @override
  void dispose() {
    PeerProfileRefreshBus.instance.revision.removeListener(_onPeerProfileRefresh);
    _commentController.dispose();
    _commentFocusNode.dispose();
    super.dispose();
  }

  Future<void> _load({bool showLoading = true}) async {
    if (showLoading) {
      setState(() => _loading = true);
    }
    try {
      final post = await MomentsStore.findPost(widget.postId);
      if (!mounted) return;
      setState(() {
        _post = post;
        _error = null;
        _loading = false;
      });
    } catch (e) {
      final error = MomentsErrorMapper.map(e);
      if (!mounted) return;
      if (showLoading) {
        setState(() {
          _post = null;
          _error = error.userMessage;
          _loading = false;
        });
      } else {
        ToastUtils.toast(error.userMessage);
      }
    }
  }

  Future<void> _toggleLike() async {
    final post = _post;
    if (post == null) return;
    if (_liking) return;
    _liking = true;
    try {
      final updated = await MomentsStore.toggleLike(post.id, current: post);
      if (!mounted) return;
      setState(() => _post = updated);
    } catch (e) {
      ToastUtils.toast(MomentsErrorMapper.map(e, action: 'like').userMessage);
    } finally {
      _liking = false;
    }
  }

  Future<void> _sendComment() async {
    final post = _post;
    if (post == null) return;
    if (_commentSubmitting) return;
    final text = _commentController.text.trim();
    if (text.isEmpty) {
      ToastUtils.toast(TIM_t('请输入评论内容'));
      return;
    }
    final replyTo = _replyToComment;
    setState(() => _commentSubmitting = true);
    try {
      await MomentsStore.addComment(
        post.id,
        text,
        replyToCommentId: replyTo?.id,
      );
      _commentController.clear();
      setState(() => _replyToComment = null);
      await _load(showLoading: false);
    } catch (e) {
      ToastUtils.toast(
        MomentsErrorMapper.map(e, action: 'comment').userMessage,
      );
    } finally {
      if (mounted) {
        setState(() => _commentSubmitting = false);
      }
    }
  }

  void _startReply(MomentComment comment) {
    setState(() => _replyToComment = comment);
    _commentFocusNode.requestFocus();
  }

  void _cancelReply() {
    setState(() => _replyToComment = null);
  }

  Future<void> _showCommentActions(
    MomentComment comment, {
    required String selfId,
    required bool isPostOwner,
  }) async {
    final canDelete = comment.canBeDeletedBy(
      selfId: selfId,
      isPostOwner: isPostOwner,
    );
    await showCupertinoModalPopup<void>(
      context: context,
      builder: (sheetContext) => CupertinoActionSheet(
        actions: [
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.pop(sheetContext);
              _startReply(comment);
            },
            child: Text(TIM_t('回复')),
          ),
          if (canDelete)
            CupertinoActionSheetAction(
              isDestructiveAction: true,
              onPressed: () {
                Navigator.pop(sheetContext);
                _deleteComment(comment);
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

  Future<void> _deleteComment(MomentComment comment) async {
    final post = _post;
    if (post == null || _commentDeleting) {
      return;
    }
    final ok = await AppDialog.confirm(
      title: TIM_t('删除评论'),
      message: TIM_t('删除后无法恢复，确定删除吗？'),
      confirmText: TIM_t('删除'),
      destructive: true,
    );
    if (ok != true) {
      return;
    }
    setState(() => _commentDeleting = true);
    try {
      final updated = await MomentsStore.deleteComment(post.id, comment.id);
      if (!mounted) {
        return;
      }
      if (_replyToComment?.id == comment.id) {
        _replyToComment = null;
      }
      setState(() => _post = updated);
      ToastUtils.toast(TIM_t('已删除'));
    } catch (e) {
      ToastUtils.toast(
        MomentsErrorMapper.map(e, action: 'delete').userMessage,
      );
    } finally {
      if (mounted) {
        setState(() => _commentDeleting = false);
      }
    }
  }

  Future<void> _deletePost() async {
    final post = _post;
    if (post == null) return;
    final ok = await AppDialog.confirm(
      title: TIM_t('删除朋友圈'),
      message: TIM_t('删除后无法恢复，确定删除吗？'),
      confirmText: TIM_t('删除'),
      destructive: true,
    );
    if (ok != true) return;
    try {
      await MomentsStore.deletePost(post.id);
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      ToastUtils.toast(
        MomentsErrorMapper.map(e, action: 'delete').userMessage,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final selfId = MomentsStore.safeLoginUserId();
    final post = _post;
    final isOwner = post?.isOwnedBy(selfId) ?? false;

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
          TIM_t('详情'),
          style: TextStyle(
            color: AppColors.text(dark: dark),
            fontSize: 17,
            fontWeight: FontWeight.w600,
          ),
        ),
        actions: [
          IconButton(
            onPressed: () => _commentFocusNode.requestFocus(),
            icon: const Icon(Icons.more_horiz_rounded),
            color: AppColors.text(dark: dark),
          ),
        ],
      ),
      bottomNavigationBar: !_loading && post != null
          ? _CommentComposer(
              controller: _commentController,
              focusNode: _commentFocusNode,
              dark: dark,
              replyToComment: _replyToComment,
              submitting: _commentSubmitting,
              onCancelReply: _cancelReply,
              onSend: _sendComment,
            )
          : null,
      body: _loading
          ? const Center(child: CupertinoActivityIndicator())
          : post == null
              ? Center(
                  child: AppEmptyState(
                    imageWidth: 180,
                    message: _error ?? TIM_t('内容已删除或不存在'),
                  ),
                )
              : GestureDetector(
                  onTap: () => FocusScope.of(context).unfocus(),
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(20, 18, 20, 96),
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          GestureDetector(
                            onTap: () => openAuthorMomentsPage(context,
                                author: post.author),
                            behavior: HitTestBehavior.opaque,
                            child: MomentsUserAvatar(
                              user: post.author,
                              size: 44,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: _DetailMomentBody(
                              post: post,
                              dark: dark,
                              isOwner: isOwner,
                              onDelete: _deletePost,
                              onComment: () => _commentFocusNode.requestFocus(),
                            ),
                          ),
                        ],
                      ),
                      if (post.likeCount > 0 || post.commentCount > 0) ...[
                        const SizedBox(height: 8),
                        _DetailInteractionPanel(
                          post: post,
                          dark: dark,
                          liked: post.likedBy(selfId),
                          onLike: _toggleLike,
                          onCommentLongPress: (comment) => _showCommentActions(
                            comment,
                            selfId: selfId,
                            isPostOwner: isOwner,
                          ),
                        ),
                      ],
                      if (post.likeCount == 0 && post.commentCount == 0)
                        Padding(
                          padding: const EdgeInsets.only(top: 22),
                          child: Center(
                            child: Text(
                              TIM_t('还没有互动'),
                              style: TextStyle(
                                color: AppColors.subText(dark: dark),
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
    );
  }
}

class _CommentComposer extends StatelessWidget {
  const _CommentComposer({
    required this.controller,
    required this.focusNode,
    required this.dark,
    required this.replyToComment,
    required this.submitting,
    required this.onCancelReply,
    required this.onSend,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final bool dark;
  final MomentComment? replyToComment;
  final bool submitting;
  final VoidCallback onCancelReply;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: AppColors.card(dark: dark),
          border: Border(
            top: BorderSide(color: AppColors.line(dark: dark), width: 0.6),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (replyToComment != null) ...[
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        '${TIM_t('回复')} ${UserDisplayProfile.nameOfSnapshot(replyToComment!.author)}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: AppColors.subText(dark: dark),
                          fontSize: 12,
                        ),
                      ),
                    ),
                    GestureDetector(
                      onTap: onCancelReply,
                      child: Icon(
                        Icons.close_rounded,
                        size: 18,
                        color: AppColors.subText(dark: dark),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
              ],
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: controller,
                      focusNode: focusNode,
                      minLines: 1,
                      maxLines: 4,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) {
                        if (!submitting) {
                          onSend();
                        }
                      },
                      decoration: InputDecoration(
                        hintText: replyToComment == null
                            ? TIM_t('写评论')
                            : '${TIM_t('回复')} ${UserDisplayProfile.nameOfSnapshot(replyToComment!.author)}',
                        isDense: true,
                        filled: true,
                        fillColor: _momentsPanelColor(dark),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(18),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  TextButton(
                    onPressed: submitting ? null : onSend,
                    child: Text(
                      submitting ? TIM_t('发送中') : TIM_t('发送'),
                      style: TextStyle(
                        color: submitting
                            ? AppColors.subText(dark: dark)
                            : _momentsNameColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DetailMomentBody extends StatelessWidget {
  const _DetailMomentBody({
    required this.post,
    required this.dark,
    required this.isOwner,
    required this.onDelete,
    required this.onComment,
  });

  final MomentPost post;
  final bool dark;
  final bool isOwner;
  final VoidCallback onDelete;
  final VoidCallback onComment;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (post.text.trim().isNotEmpty) ...[
          Text(
            post.text.trim(),
            style: TextStyle(
              color: AppColors.text(dark: dark),
              fontSize: 15,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 8),
        ],
        if (post.hasMedia)
          _DetailMediaGrid(
            post: post,
            onImageTap: (index) => openMomentImagePreview(
              context,
              post: post,
              attachmentIndex: index,
            ),
            onVideoTap: (item) => MomentsVideoPlayerPage.push(
              context,
              source: item.displayPath,
              title: UserDisplayProfile.nameOfSnapshot(post.author),
            ),
          ),
        const SizedBox(height: 8),
        _DetailMetaRow(
          post: post,
          dark: dark,
          isOwner: isOwner,
          onDelete: onDelete,
          onComment: onComment,
        ),
      ],
    );
  }
}

class _DetailMetaRow extends StatelessWidget {
  const _DetailMetaRow({
    required this.post,
    required this.dark,
    required this.isOwner,
    required this.onDelete,
    required this.onComment,
  });

  final MomentPost post;
  final bool dark;
  final bool isOwner;
  final VoidCallback onDelete;
  final VoidCallback onComment;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            _formatDetailMeta(post),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: AppColors.subText(dark: dark),
              fontSize: 13,
            ),
          ),
        ),
        if (isOwner)
          IconButton(
            onPressed: onDelete,
            icon: const Icon(Icons.delete_outline_rounded),
            color: _momentsNameColor,
            iconSize: 20,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints.tightFor(width: 32, height: 32),
          ),
        IconButton(
          onPressed: onComment,
          icon: const Icon(Icons.more_horiz_rounded),
          color: _momentsNameColor,
          iconSize: 22,
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints.tightFor(width: 32, height: 32),
        ),
      ],
    );
  }
}

class _DetailInteractionPanel extends StatelessWidget {
  const _DetailInteractionPanel({
    required this.post,
    required this.dark,
    required this.liked,
    required this.onLike,
    required this.onCommentLongPress,
  });

  final MomentPost post;
  final bool dark;
  final bool liked;
  final VoidCallback onLike;
  final void Function(MomentComment comment) onCommentLongPress;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: _momentsPanelColor(dark),
        borderRadius: BorderRadius.circular(7),
      ),
      child: Column(
        children: [
          if (post.likeCount > 0)
            _DetailLikesRow(
                post: post, dark: dark, liked: liked, onLike: onLike),
          if (post.likeCount > 0 && post.commentCount > 0)
            Divider(
              height: 1,
              indent: 64,
              color: AppColors.line(dark: dark),
            ),
          if (post.commentCount > 0)
            _DetailCommentsRows(
              post: post,
              dark: dark,
              onLongPress: onCommentLongPress,
            ),
        ],
      ),
    );
  }
}

class _DetailLikesRow extends StatelessWidget {
  const _DetailLikesRow({
    required this.post,
    required this.dark,
    required this.liked,
    required this.onLike,
  });

  final MomentPost post;
  final bool dark;
  final bool liked;
  final VoidCallback onLike;

  @override
  Widget build(BuildContext context) {
    return AppListPressable(
      onTap: onLike,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(0, 6, 12, 6),
        child: Row(
          children: [
            SizedBox(
              width: 44,
              child: Center(
                child: Icon(
                  liked
                      ? Icons.favorite_rounded
                      : Icons.favorite_border_rounded,
                  color: _momentsNameColor,
                  size: 20,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Wrap(
                spacing: 5,
                runSpacing: 5,
                children: post.likes.take(8).map((item) {
                  return GestureDetector(
                    onTap: () =>
                        openAuthorMomentsPage(context, author: item.author),
                    behavior: HitTestBehavior.opaque,
                    child: MomentsUserAvatar(
                      user: item.author,
                      size: 32,
                    ),
                  );
                }).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DetailCommentsRows extends StatelessWidget {
  const _DetailCommentsRows({
    required this.post,
    required this.dark,
    required this.onLongPress,
  });

  final MomentPost post;
  final bool dark;
  final void Function(MomentComment comment) onLongPress;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: post.comments.map((item) {
        final index = post.comments.indexOf(item);
        return Column(
          children: [
            GestureDetector(
              // 单击弹出回复/删除；长按同样入口，避免只能长按才删。
              onTap: () => onLongPress(item),
              onLongPress: () => onLongPress(item),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(0, 6, 12, 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (index == 0)
                      const SizedBox(
                        width: 44,
                        child: Center(
                          child: Icon(
                            Icons.mode_comment_outlined,
                            color: _momentsNameColor,
                            size: 20,
                          ),
                        ),
                      )
                    else
                      const SizedBox(width: 44),
                    const SizedBox(width: 10),
                    GestureDetector(
                      onTap: () =>
                          openAuthorMomentsPage(context, author: item.author),
                      behavior: HitTestBehavior.opaque,
                      child: MomentsUserAvatar(
                        user: item.author,
                        size: 32,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _DetailCommentBody(
                        comment: item,
                        dark: dark,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (index < post.comments.length - 1)
              Divider(
                height: 1,
                indent: 94,
                color: AppColors.line(dark: dark),
              ),
          ],
        );
      }).toList(),
    );
  }
}

class _DetailCommentBody extends StatelessWidget {
  const _DetailCommentBody({
    required this.comment,
    required this.dark,
  });

  final MomentComment comment;
  final bool dark;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Text(
                UserDisplayProfile.nameOfSnapshot(comment.author),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: _momentsNameColor,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              _formatCommentTime(comment.createdAt),
              style: TextStyle(
                color: AppColors.subText(dark: dark),
                fontSize: 11,
              ),
            ),
          ],
        ),
        const SizedBox(height: 1),
        if (comment.isReply)
          RichText(
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            text: TextSpan(
              style: TextStyle(
                color: AppColors.text(dark: dark),
                fontSize: 14,
                height: 1.24,
                fontWeight: FontWeight.w500,
              ),
              children: [
                TextSpan(text: TIM_t('回复 ')),
                TextSpan(
                  text: UserDisplayProfile.nameOfSnapshot(comment.replyToUser!),
                  style: const TextStyle(
                    color: _momentsNameColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const TextSpan(text: '：'),
                TextSpan(text: comment.text),
              ],
            ),
          )
        else
          Text(
            comment.text,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: AppColors.text(dark: dark),
              fontSize: 14,
              height: 1.24,
              fontWeight: FontWeight.w500,
            ),
          ),
      ],
    );
  }
}

class _DetailMediaGrid extends StatelessWidget {
  const _DetailMediaGrid({
    required this.post,
    required this.onImageTap,
    required this.onVideoTap,
  });

  final MomentPost post;
  final void Function(int index) onImageTap;
  final void Function(MomentAttachment item) onVideoTap;

  @override
  Widget build(BuildContext context) {
    final items = post.attachments;
    if (items.length == 1) {
      final item = items.first;
      return MomentsSingleMediaFrame(
        item: item,
        imageProvider:
            item.isImage ? momentImageProvider(item.displayPath) : null,
        maxLongImageHeight: 520,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: _detailMedia(item, 0),
        ),
      );
    }
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: EdgeInsets.zero,
      itemCount: items.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisSpacing: 6,
        crossAxisSpacing: 6,
      ),
      itemBuilder: (context, index) {
        final item = items[index];
        return ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: _detailMedia(item, index),
        );
      },
    );
  }

  Widget _detailMedia(MomentAttachment item, int index) {
    final raw = item.displayPath;
    final onTap =
        item.isVideo ? () => onVideoTap(item) : () => onImageTap(index);
    return _MediaTapSurface(
      onTap: onTap,
      child: MomentsMediaThumbnail(path: raw, fallbackLogicalSize: 220),
    );
  }
}

class _MediaTapSurface extends StatelessWidget {
  const _MediaTapSurface({
    required this.child,
    this.onTap,
  });

  final Widget child;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    if (onTap == null) {
      return child;
    }
    return GestureDetector(
      onTap: onTap,
      child: child,
    );
  }
}

String _formatDetailMeta(MomentPost post) {
  final local = post.createdAt.toLocal();
  final date =
      '${local.year}年${local.month}月${local.day}日 ${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
  final location = post.location?.trim() ?? '';
  if (location.isEmpty) return date;
  return '$date  $location';
}

String _formatCommentTime(DateTime time) {
  final local = time.toLocal();
  return '${local.month}月${local.day}日 ${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
}
