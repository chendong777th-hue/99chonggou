import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tencent_chat_i18n_tool/tencent_chat_i18n_tool.dart';
import 'package:tencent_cloud_chat_demo/src/models/moments/moment_models.dart';
import 'package:tencent_cloud_chat_demo/src/navigation/app_page_transitions.dart';
import 'package:tencent_cloud_chat_demo/src/pages/moments/moments_friend_multi_picker_page.dart';
import 'package:tencent_cloud_chat_demo/src/pages/moments/moments_media_thumbnail.dart';
import 'package:tencent_cloud_chat_demo/src/pages/moments/moments_media_layout.dart';
import 'package:tencent_cloud_chat_demo/src/services/moments/moments_error_mapper.dart';
import 'package:tencent_cloud_chat_demo/src/services/moments/moments_store.dart';
import 'package:tencent_cloud_chat_demo/src/services/app_gallery_picker.dart';
import 'package:tencent_cloud_chat_demo/src/services/photo_compress_util.dart';
import 'package:tencent_cloud_chat_demo/src/theme/app_colors.dart';
import 'package:tencent_cloud_chat_demo/src/ui/app_tokens.dart';
import 'package:tencent_cloud_chat_demo/utils/toast.dart';
import 'package:tencent_cloud_chat_demo/src/widgets/app_dialog.dart';
import 'package:tencent_cloud_chat_demo/src/widgets/app_list_pressable.dart';
import 'package:tencent_cloud_chat_demo/src/widgets/app_user_avatar.dart';
import 'package:tencent_cloud_chat_demo/src/provider/login_user_Info.dart';
import 'package:tencent_cloud_chat_demo/utils/user_display_profile.dart';
import 'package:wechat_assets_picker/wechat_assets_picker.dart';

const Color _momentsNameColor = AppTokens.ink600;

Color _momentsPageBackground(bool dark) =>
    dark ? AppColors.background(dark: true) : AppColors.card(dark: false);

class MomentsComposePage extends StatefulWidget {
  const MomentsComposePage({
    super.key,
    this.initialDraft,
  });

  final MomentDraft? initialDraft;

  @override
  State<MomentsComposePage> createState() => _MomentsComposePageState();
}

class _MomentsComposePageState extends State<MomentsComposePage> {
  late final TextEditingController _textController;
  final List<MomentAttachment> _attachments = <MomentAttachment>[];
  bool _submitting = false;
  bool _saveDraftOnExit = true;
  MomentPublishPrivacy _privacy = const MomentPublishPrivacy();
  int _uploadCompleted = 0;
  int _uploadTotal = 0;

  bool get _canSubmit =>
      _textController.text.trim().isNotEmpty || _attachments.isNotEmpty;

  @override
  void initState() {
    super.initState();
    final draft = widget.initialDraft;
    _textController = TextEditingController(text: draft?.text ?? '');
    if (draft != null) {
      _attachments.addAll(draft.attachments);
      _privacy = draft.privacy;
    }
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  Future<void> _pickMedia() async {
    List<AppGalleryMedia> picked;
    try {
      picked = await AppGalleryPicker.pick(
        context,
        maxAssets: 9 - _attachments.length,
        requestType: RequestType.common,
      );
    } catch (_) {
      ToastUtils.toast(TIM_t('无法打开相册'));
      return;
    }
    if (!mounted || picked.isEmpty) return;

    final next = <MomentAttachment>[..._attachments];
    for (final media in picked) {
      if (next.length >= 9) break;
      final path = media.file.path.trim();
      if (path.isEmpty) continue;
      if (media.isVideo) {
        final sizeBytes = await _safeFileLength(media.file);
        next.add(
          MomentAttachment(
            type: MomentMediaType.video,
            path: path,
            sizeBytes: sizeBytes,
          ),
        );
      } else {
        final file = media.file;
        final compressed = await PhotoCompressUtil.compressForUpload(file);
        final uploadFile = compressed?.file ?? file;
        next.add(
          MomentAttachment(
            type: MomentMediaType.image,
            path: uploadFile.path,
            sizeBytes: await _safeFileLength(uploadFile),
          ),
        );
      }
    }

    if (!mounted) return;
    setState(() {
      _attachments
        ..clear()
        ..addAll(next);
    });
    await _saveDraft();
  }

  Future<int?> _safeFileLength(File file) async {
    try {
      return await file.length();
    } catch (_) {
      return null;
    }
  }

  Future<void> _pickPrivacy() async {
    final mode = await AppDialog.actionSheet<MomentVisibilityMode>(
      title: TIM_t('谁可以看'),
      cancelText: TIM_t('取消'),
      actions: [
        AppActionSheetItem(
          text: TIM_t('公开'),
          subtitle: TIM_t('所有好友可见'),
          value: MomentVisibilityMode.friends,
        ),
        AppActionSheetItem(
          text: TIM_t('不给谁看'),
          value: MomentVisibilityMode.exclude,
        ),
        AppActionSheetItem(
          text: TIM_t('部分可见'),
          value: MomentVisibilityMode.partial,
        ),
      ],
    );
    if (!mounted || mode == null) return;
    if (mode == MomentVisibilityMode.friends) {
      setState(() => _privacy = const MomentPublishPrivacy());
      await _saveDraft();
      return;
    }
    final picked = await Navigator.push<List<MomentUserSnapshot>>(
      context,
      AppMaterialPageRoute(
        builder: (_) => MomentsFriendMultiPickerPage(
          title: mode == MomentVisibilityMode.exclude
              ? TIM_t('不给谁看')
              : TIM_t('部分可见'),
          initialSelectedIds:
              _privacy.selectedUsers.map((user) => user.id).toList(),
        ),
      ),
    );
    if (!mounted || picked == null) return;
    setState(() {
      _privacy = MomentPublishPrivacy(mode: mode, selectedUsers: picked);
    });
    await _saveDraft();
  }

  Future<void> _submit() async {
    if (_submitting) return;
    final text = _textController.text.trim();
    if (text.isEmpty && _attachments.isEmpty) {
      ToastUtils.toast(TIM_t('请填写内容或添加图片'));
      return;
    }

    setState(() {
      _submitting = true;
      _uploadCompleted = 0;
      _uploadTotal = _attachments.length;
    });
    try {
      final created = await MomentsStore.createPost(
        text: text,
        attachments: List<MomentAttachment>.from(_attachments),
        privacy: _privacy,
        onUploadProgress: (completed, total) {
          if (!mounted) return;
          setState(() {
            _uploadCompleted = completed;
            _uploadTotal = total;
          });
        },
      );
      await MomentsStore.saveDraft(null);
      _saveDraftOnExit = false;
      if (!mounted) return;
      Navigator.of(context).pop(created);
    } catch (e) {
      ToastUtils.toast(
        MomentsErrorMapper.map(e, action: 'publish').userMessage,
      );
    } finally {
      if (mounted) {
        setState(() {
          _submitting = false;
          _uploadCompleted = 0;
          _uploadTotal = 0;
        });
      }
    }
  }

  Future<void> _saveDraft() async {
    await MomentsStore.saveDraft(
      MomentDraft(
        text: _textController.text.trim(),
        attachments: List<MomentAttachment>.from(_attachments),
        updatedAt: DateTime.now(),
        privacy: _privacy,
      ),
    );
  }

  Future<void> _confirmLeave() async {
    await _saveDraft();
    _saveDraftOnExit = false;
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  Future<void> _removeAttachment(int index) async {
    setState(() => _attachments.removeAt(index));
    await _saveDraft();
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final loginUser = Provider.of<LoginUserInfo>(context).loginUserInfo;
    final selfId = MomentsStore.safeLoginUserId();
    final name = UserDisplayProfile.name(
      userId: selfId,
      imNickName: loginUser.nickName,
      fallbackName: TIM_t('我'),
    );
    final liveAvatar = UserDisplayProfile.avatar(
      userId: selfId,
      fallbackIm: loginUser.faceUrl,
      isSelf: true,
    );
    final avatar = liveAvatar.trim().isNotEmpty
        ? liveAvatar
        : 'assets/default_avatar.png';

    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop && _saveDraftOnExit) {
          _saveDraft();
        }
      },
      child: Scaffold(
        backgroundColor: _momentsPageBackground(dark),
        appBar: AppBar(
          elevation: 0,
          backgroundColor: AppColors.card(dark: dark),
          surfaceTintColor: Colors.transparent,
          leading: IconButton(
            icon: const Icon(Icons.close_rounded),
            color: _momentsNameColor,
            onPressed: _confirmLeave,
          ),
          title: Text(
            _submitting && _uploadTotal > 0
                ? TIM_t('上传中 $_uploadCompleted/$_uploadTotal')
                : TIM_t('发动态'),
            style: TextStyle(
              color: AppColors.text(dark: dark),
              fontSize: 17,
              fontWeight: FontWeight.w600,
            ),
          ),
          actions: [
            TextButton(
              onPressed: _submitting || !_canSubmit ? null : _submit,
              child: Text(
                _submitting ? TIM_t('发布中') : TIM_t('发布'),
                style: TextStyle(
                  color: _canSubmit
                      ? _momentsNameColor
                      : AppColors.subText(dark: dark),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        body: Column(
          children: [
            if (_submitting && _uploadTotal > 0)
              LinearProgressIndicator(
                minHeight: 3,
                value: _uploadCompleted / _uploadTotal,
                backgroundColor: AppColors.line(dark: dark),
                color: _momentsNameColor,
              ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        AppUserAvatar(
                          faceUrl: avatar,
                          showName: name,
                          size: 44,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            name,
                            style: TextStyle(
                              color: AppColors.text(dark: dark),
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _textController,
                      minLines: 4,
                      maxLines: 8,
                      decoration: InputDecoration(
                        hintText: TIM_t('这一刻的想法...'),
                        border: InputBorder.none,
                      ),
                      style: TextStyle(
                        color: AppColors.text(dark: dark),
                        fontSize: 16,
                        height: 1.45,
                      ),
                      onChanged: (_) {
                        setState(() {});
                        _saveDraft();
                      },
                    ),
                    const SizedBox(height: 12),
                    if (_attachments.isNotEmpty)
                      _AttachmentGrid(
                        attachments: _attachments,
                        dark: dark,
                        onRemove: _removeAttachment,
                      ),
                    const SizedBox(height: 12),
                    _ComposerMetaRow(
                      dark: dark,
                      privacyLabel: _privacy.summaryLabel(),
                      onPrivacyTap: _pickPrivacy,
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        _ComposerToolButton(
                          icon: Icons.photo_library_outlined,
                          label: TIM_t('相册'),
                          onTap: _pickMedia,
                          dark: dark,
                        ),
                        const Spacer(),
                        Text(
                          TIM_t('草稿自动保存'),
                          style: TextStyle(
                            color: AppColors.subText(dark: dark),
                            fontSize: 12,
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
    );
  }
}

class _ComposerMetaRow extends StatelessWidget {
  const _ComposerMetaRow({
    required this.dark,
    required this.privacyLabel,
    required this.onPrivacyTap,
  });

  final bool dark;
  final String privacyLabel;
  final VoidCallback onPrivacyTap;

  @override
  Widget build(BuildContext context) {
    return AppListPressable(
      onTap: onPrivacyTap,
      child: Row(
        children: [
          Icon(Icons.lock_outline_rounded, size: 18, color: _momentsNameColor),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              TIM_t('谁可以看'),
              style: TextStyle(
                color: AppColors.text(dark: dark),
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Text(
            privacyLabel,
            style: TextStyle(
              color: AppColors.subText(dark: dark),
              fontSize: 13,
            ),
          ),
          Icon(
            Icons.chevron_right_rounded,
            color: AppColors.subText(dark: dark),
            size: 20,
          ),
        ],
      ),
    );
  }
}

class _AttachmentGrid extends StatelessWidget {
  const _AttachmentGrid({
    required this.attachments,
    required this.dark,
    required this.onRemove,
  });

  final List<MomentAttachment> attachments;
  final bool dark;
  final Future<void> Function(int index) onRemove;

  @override
  Widget build(BuildContext context) {
    final columns = attachments.length == 1 ? 1 : 3;
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: attachments.length,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: columns,
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
        childAspectRatio: attachments.length == 1
            ? MomentsMediaLayout.singleAspectRatio(attachments.first)
            : 1,
      ),
      itemBuilder: (context, index) {
        final item = attachments[index];
        return Stack(
          fit: StackFit.expand,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: MomentsMediaThumbnail(
                path: item.displayPath,
                fallbackLogicalSize: attachments.length == 1 ? 320 : 120,
              ),
            ),
            if (item.isVideo)
              const Center(
                child: Icon(Icons.play_circle_fill_rounded,
                    color: Colors.white, size: 34),
              ),
            if (MomentsMediaLayout.isLongImage(item))
              Positioned(
                right: 6,
                bottom: 6,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.55),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                    child: Text('长图',
                        style: TextStyle(color: Colors.white, fontSize: 10)),
                  ),
                ),
              ),
            Positioned(
              top: 6,
              right: 6,
              child: GestureDetector(
                onTap: () => onRemove(index),
                child: Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.45),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.close_rounded,
                    size: 16,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _ComposerToolButton extends StatelessWidget {
  const _ComposerToolButton({
    required this.icon,
    required this.label,
    required this.onTap,
    required this.dark,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool dark;

  @override
  Widget build(BuildContext context) {
    return AppListPressable(
      onTap: onTap,
      child: Container(
        height: 40,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: AppColors.card(dark: dark),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.line(dark: dark)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 18, color: _momentsNameColor),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: AppColors.text(dark: dark),
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
