import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:tencent_chat_i18n_tool/tencent_chat_i18n_tool.dart';

class MediaPreviewCircleButton extends StatelessWidget {
  const MediaPreviewCircleButton({
    required this.icon,
    required this.onPressed,
    super.key,
  });

  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black.withValues(alpha: 0.45),
      shape: const CircleBorder(),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onPressed,
        child: SizedBox(
          width: 40,
          height: 40,
          child: Icon(icon, color: Colors.white, size: 22),
        ),
      ),
    );
  }
}

class MediaPreviewTopBar extends StatelessWidget {
  const MediaPreviewTopBar({
    required this.title,
    required this.subtitle,
    required this.onBack,
    this.onMore,
    this.galleryIndicator,
    super.key,
  });

  final String title;
  final String subtitle;
  final VoidCallback onBack;
  final VoidCallback? onMore;
  final String? galleryIndicator;

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.paddingOf(context).top + 8;
    return Positioned(
      top: top,
      left: 12,
      right: 12,
      child: Row(
        children: [
          MediaPreviewCircleButton(
            icon: Icons.arrow_back_ios_new_rounded,
            onPressed: onBack,
          ),
          Expanded(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 260),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.45),
                    borderRadius: BorderRadius.circular(28),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        title.isNotEmpty ? title : ' ',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          height: 1.15,
                        ),
                      ),
                      if (subtitle.isNotEmpty) ...[
                        const SizedBox(height: 1),
                        Text(
                          galleryIndicator != null
                              ? '$subtitle · $galleryIndicator'
                              : subtitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.82),
                            fontSize: 11,
                            height: 1.1,
                          ),
                        ),
                      ] else if (galleryIndicator != null) ...[
                        const SizedBox(height: 1),
                        Text(
                          galleryIndicator!,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.82),
                            fontSize: 11,
                            height: 1.1,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
          if (onMore != null)
            MediaPreviewCircleButton(
              icon: Icons.more_horiz_rounded,
              onPressed: onMore!,
            )
          else
            const SizedBox(width: 40, height: 40),
        ],
      ),
    );
  }
}

class MediaPreviewBottomBar extends StatelessWidget {
  const MediaPreviewBottomBar({
    this.onShare,
    this.onEdit,
    this.onDownload,
    this.onDelete,
    this.onOpenMedia,
    this.onTogglePlayback,
    this.isPlaybackActive,
    this.downloadOnly = false,
    this.showPreviewTools = false,
    this.onZoomOut,
    this.onZoomIn,
    this.onRotate,
    this.onResetView,
    super.key,
  });

  final VoidCallback? onShare;
  final VoidCallback? onEdit;
  final VoidCallback? onDownload;
  final VoidCallback? onDelete;
  final VoidCallback? onOpenMedia;
  final VoidCallback? onTogglePlayback;
  final bool? isPlaybackActive;
  final bool downloadOnly;
  final bool showPreviewTools;
  final VoidCallback? onZoomOut;
  final VoidCallback? onZoomIn;
  final VoidCallback? onRotate;
  final VoidCallback? onResetView;

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.paddingOf(context).bottom + 16;
    const horizontalPadding = 12.0;
    const actionSpacing = 4.0;
    if (downloadOnly) {
      if (onDownload == null) {
        return const SizedBox.shrink();
      }
      return Positioned(
        left: 0,
        right: horizontalPadding,
        bottom: bottom,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            _BottomAction(
              icon: Icons.download_rounded,
              onPressed: onDownload,
            ),
          ],
        ),
      );
    }
    return Positioned(
      left: 0,
      right: horizontalPadding,
      bottom: bottom,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          if (showPreviewTools)
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _BottomAction(
                  icon: Icons.remove_rounded,
                  onPressed: onZoomOut,
                ),
                const SizedBox(width: actionSpacing),
                _BottomAction(
                  icon: Icons.add_rounded,
                  onPressed: onZoomIn,
                ),
                const SizedBox(width: actionSpacing),
                _BottomAction(
                  icon: Icons.rotate_right_rounded,
                  onPressed: onRotate,
                ),
                const SizedBox(width: actionSpacing),
                _BottomAction(
                  icon: Icons.fit_screen_rounded,
                  onPressed: onResetView,
                ),
              ],
            )
          else if (onTogglePlayback != null && isPlaybackActive != null)
            _BottomAction(
              icon: isPlaybackActive!
                  ? Icons.pause_rounded
                  : Icons.play_arrow_rounded,
              onPressed: onTogglePlayback,
            )
          else
            const SizedBox(width: 40, height: 40),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              if (!showPreviewTools) ...[
                _BottomAction(
                  icon: Icons.ios_share_rounded,
                  onPressed: onShare,
                ),
                const SizedBox(width: actionSpacing),
                _BottomAction(
                  icon: Icons.title_rounded,
                  onPressed: onEdit,
                ),
                const SizedBox(width: actionSpacing),
              ],
              _BottomAction(
                icon: Icons.download_rounded,
                onPressed: onDownload,
              ),
              if (onOpenMedia != null) ...[
                const SizedBox(width: actionSpacing),
                _BottomAction(
                  icon: Icons.grid_view_rounded,
                  onPressed: onOpenMedia,
                ),
              ],
              if (!showPreviewTools) ...[
                const SizedBox(width: actionSpacing),
                _BottomAction(
                  icon: Icons.delete_outline_rounded,
                  onPressed: onDelete,
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _BottomAction extends StatelessWidget {
  const _BottomAction({
    required this.icon,
    this.onPressed,
  });

  final IconData icon;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    return Opacity(
      opacity: enabled ? 1.0 : 0.35,
      child: Material(
        color: Colors.black.withValues(alpha: 0.45),
        shape: const CircleBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onPressed,
          child: SizedBox(
            width: 40,
            height: 40,
            child: Icon(
              icon,
              color: Colors.white,
              size: 22,
            ),
          ),
        ),
      ),
    );
  }
}

Future<void> showMediaPreviewMoreSheet({
  required BuildContext context,
  VoidCallback? onDownload,
  VoidCallback? onEdit,
  VoidCallback? onForward,
  VoidCallback? onDelete,
}) async {
  final actions = <Widget>[];

  void addAction(String label, VoidCallback? handler) {
    if (handler == null) {
      return;
    }
    actions.add(
      CupertinoActionSheetAction(
        onPressed: () {
          Navigator.pop(context);
          handler();
        },
        child: Text(label),
      ),
    );
  }

  addAction(TIM_t('保存到相册'), onDownload);
  addAction(TIM_t('编辑'), onEdit);
  addAction(TIM_t('转发'), onForward);
  if (onDelete != null) {
    actions.add(
      CupertinoActionSheetAction(
        isDestructiveAction: true,
        onPressed: () {
          Navigator.pop(context);
          onDelete();
        },
        child: Text(TIM_t('删除')),
      ),
    );
  }

  if (actions.isEmpty) {
    return;
  }

  await showCupertinoModalPopup<void>(
    context: context,
    builder: (sheetContext) => CupertinoActionSheet(
      actions: actions,
      cancelButton: CupertinoActionSheetAction(
        onPressed: () => Navigator.pop(sheetContext),
        child: Text(TIM_t('取消')),
      ),
    ),
  );
}
