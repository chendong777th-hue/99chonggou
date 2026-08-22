import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_gallery_saver_plus/image_gallery_saver_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:tencent_chat_i18n_tool/tencent_chat_i18n_tool.dart';
import 'package:tencent_cloud_chat_demo/src/models/moments/moment_models.dart';
import 'package:tencent_cloud_chat_demo/src/navigation/app_page_transitions.dart';
import 'package:tencent_cloud_chat_demo/src/provider/theme.dart';
import 'package:tencent_cloud_chat_demo/src/services/chat_external_message_sender.dart';
import 'package:tencent_cloud_chat_demo/src/widgets/conversation_share_picker_page.dart';
import 'package:tencent_cloud_chat_demo/utils/user_display_profile.dart';
import 'package:tencent_cloud_chat_demo/utils/media_url_resolver.dart';
import 'package:tencent_cloud_chat_demo/utils/toast.dart';
import 'package:tencent_cloud_chat_uikit/tencent_cloud_chat_uikit.dart';
import 'package:tencent_cloud_chat_uikit/ui/utils/media_preview_presenter.dart';
import 'package:tencent_cloud_chat_uikit/ui/widgets/image_gallery_item.dart';
import 'package:tencent_cloud_chat_uikit/ui/widgets/image_screen.dart';

String momentImageHeroTag(MomentPost post, int attachmentIndex) {
  return 'moment_media_${post.id}_$attachmentIndex';
}

ImageProvider? momentImageProvider(String raw) {
  if (raw.isEmpty) return null;
  if (raw.startsWith('assets/')) {
    return AssetImage(raw);
  }
  final resolved = MediaUrlResolver.resolve(raw) ?? raw;
  if (resolved.startsWith('http')) {
    return CachedNetworkImageProvider(
      resolved,
      headers: MediaUrlResolver.authHeadersFor(resolved),
    );
  }
  return FileImage(File(resolved));
}

Future<Uint8List?> _momentImageBytes(String raw) async {
  final path = raw.trim();
  if (path.isEmpty || kIsWeb) return null;
  try {
    if (path.startsWith('assets/')) {
      final data = await rootBundle.load(path);
      return data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
    }
    final resolved = MediaUrlResolver.resolve(path) ?? path;
    if (resolved.startsWith('http')) {
      final response = await Dio().get<List<int>>(
        resolved,
        options: Options(
          responseType: ResponseType.bytes,
          headers: MediaUrlResolver.authHeadersFor(resolved),
        ),
      );
      final data = response.data;
      return data == null ? null : Uint8List.fromList(data);
    }
    return File(resolved).readAsBytes();
  } catch (_) {
    return null;
  }
}

Future<void> _saveMomentImage(MomentAttachment item) async {
  if (kIsWeb) {
    ToastUtils.toast(TIM_t('当前暂不支持保存图片'));
    return;
  }
  final bytes = await _momentImageBytes(item.displayPath);
  if (bytes == null || bytes.isEmpty) {
    ToastUtils.toast(TIM_t('保存失败'));
    return;
  }
  try {
    final result = await ImageGallerySaverPlus.saveImage(
      bytes,
      quality: 100,
      name: 'moment_${DateTime.now().millisecondsSinceEpoch}',
    );
    ToastUtils.toast(result == null ? TIM_t('保存失败') : TIM_t('图片已保存'));
  } catch (_) {
    ToastUtils.toast(TIM_t('保存失败'));
  }
}

Future<void> _forwardMomentImage(
  BuildContext context,
  MomentAttachment item,
) async {
  if (kIsWeb) {
    ToastUtils.toast(TIM_t('当前暂不支持转发图片'));
    return;
  }
  final bytes = await _momentImageBytes(item.displayPath);
  if (bytes == null || bytes.isEmpty || !context.mounted) {
    ToastUtils.toast(TIM_t('图片加载失败'));
    return;
  }
  final theme = Provider.of<DefaultThemeData>(context, listen: false).theme;
  final target = await Navigator.of(context).push<ConversationShareTarget>(
    AppFullscreenDialogRoute(
      builder: (_) => ConversationSharePickerPage(theme: theme),
    ),
  );
  if (target == null || !context.mounted) return;
  try {
    final directory = await getTemporaryDirectory();
    final file = File(
      '${directory.path}/moment_forward_${DateTime.now().microsecondsSinceEpoch}.jpg',
    );
    await file.writeAsBytes(bytes, flush: true);
    final created = await TIMUIKitCore.getSDKInstance()
        .getMessageManager()
        .createImageMessage(
          imagePath: file.path,
          imageName: 'moment_image.jpg',
        );
    final sent = created.code == 0 &&
        await ChatExternalMessageSender.sendCreatedMessage(
          messageInfo: created.data?.messageInfo,
          receiverUserId: target.userID,
          groupId: target.groupID,
          reason: 'moment_image_forwarded',
        );
    ToastUtils.toast(sent ? TIM_t('已转发') : TIM_t('转发失败'));
  } catch (_) {
    ToastUtils.toast(TIM_t('转发失败'));
  }
}

void openMomentImagePreview(
  BuildContext context, {
  required MomentPost post,
  required int attachmentIndex,
}) {
  if (attachmentIndex < 0 || attachmentIndex >= post.attachments.length) {
    return;
  }
  final tapped = post.attachments[attachmentIndex];
  if (!tapped.isImage) {
    return;
  }
  final tappedProvider = momentImageProvider(tapped.displayPath);
  if (tappedProvider == null) {
    return;
  }

  final galleryItems = <ImageGalleryItem>[];
  var initialIndex = 0;
  for (var i = 0; i < post.attachments.length; i++) {
    final item = post.attachments[i];
    if (!item.isImage) {
      continue;
    }
    final provider = momentImageProvider(item.displayPath);
    if (provider == null) {
      continue;
    }
    if (i == attachmentIndex) {
      initialIndex = galleryItems.length;
    }
    galleryItems.add(
      ImageGalleryItem(
        imageProvider: provider,
        heroTag: momentImageHeroTag(post, i),
        messageID: '${post.id}_$i',
        headerTitle: UserDisplayProfile.nameOfSnapshot(post.author),
        downloadFn: () => _saveMomentImage(item),
        forwardFn: () => _forwardMomentImage(context, item),
      ),
    );
  }

  pushMediaPreview(
    context: context,
    enableGestureBack: false,
    child: ImageScreen(
      imageProvider: tappedProvider,
      heroTag: momentImageHeroTag(post, attachmentIndex),
      headerTitle: UserDisplayProfile.nameOfSnapshot(post.author),
      galleryItems: galleryItems,
      initialIndex: initialIndex,
      downloadFn: () => _saveMomentImage(tapped),
      forwardFn: () => _forwardMomentImage(context, tapped),
      fitTallImagesToScreenWidth: false,
    ),
  );
}
