import 'dart:io';
import 'package:tencent_cloud_chat_demo/src/platform/permission_guard.dart';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tencent_cloud_chat_demo/src/i18n/app_i18n.dart';
import 'package:tencent_cloud_chat_demo/src/api/sticker_api.dart';
import 'package:tencent_cloud_chat_demo/src/models/sticker_models.dart';
import 'package:tencent_cloud_chat_demo/src/provider/theme.dart';
import 'package:tencent_cloud_chat_demo/src/provider/user_sticker_provider.dart';
import 'package:tencent_cloud_chat_demo/src/widgets/sticker/sticker_image.dart';
import 'package:tencent_cloud_chat_demo/src/widgets/app_dialog.dart';
import 'package:tencent_cloud_chat_demo/utils/sticker_compress_util.dart';
import 'package:tencent_cloud_chat_demo/utils/sticker_constants.dart';
import 'package:tencent_cloud_chat_demo/utils/sticker_upload_error.dart';
import 'package:tencent_cloud_chat_demo/utils/sticker_upload_media.dart';
import 'package:tencent_cloud_chat_demo/utils/sticker_panel_packages.dart';
import 'package:tencent_cloud_chat_demo/utils/theme.dart';
import 'package:tencent_cloud_chat_demo/utils/toast.dart';
import 'package:tencent_cloud_chat_uikit/ui/utils/image_edit/editable_asset_picker.dart';
import 'package:wechat_assets_picker/wechat_assets_picker.dart';

enum _StickerGridEntryKind { favorite, upload }

class _StickerGridEntry {
  const _StickerGridEntry({
    required this.item,
    required this.kind,
  });

  final StickerItem item;
  final _StickerGridEntryKind kind;
}

/// 微信风格「添加的单个表情」：展示收藏 + 自定义上传，首格上传，支持整理删除。
class StickerUploadPage extends StatefulWidget {
  const StickerUploadPage({super.key});

  @override
  State<StickerUploadPage> createState() => _StickerUploadPageState();
}

class _StickerUploadPageState extends State<StickerUploadPage> {
  static const Color _lightPageBg = Color(0xFFEDEDED);
  static const Set<String> _staticExtensions = {
    'png',
    'jpg',
    'jpeg',
    'webp',
  };

  bool _uploading = false;
  bool _organizing = false;

  @override
  void initState() {
    super.initState();
    UserStickerProvider.shared.addListener(_onProviderChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      UserStickerProvider.shared.refresh(force: true);
    });
  }

  @override
  void dispose() {
    UserStickerProvider.shared.removeListener(_onProviderChanged);
    super.dispose();
  }

  void _onProviderChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  List<StickerItem> _uploadStickers() {
    for (final pack in UserStickerProvider.shared.serverPacks) {
      if (pack.packId == StickerConstants.userUploadPackId) {
        return pack.stickers;
      }
    }
    return const [];
  }

  List<_StickerGridEntry> _allStickerEntries() {
    final provider = UserStickerProvider.shared;
    final favorites = provider.favorites;
    final uploads = _uploadStickers();
    final merged = mergeFavoritesAndUploadStickers(
      favorites: favorites,
      uploads: uploads,
    );
    final favoriteIds = favorites
        .map((f) => f.stickerId.trim())
        .where((id) => id.isNotEmpty)
        .toSet();
    return merged
        .map(
          (item) => _StickerGridEntry(
            item: item,
            kind: favoriteIds.contains(item.stickerId.trim())
                ? _StickerGridEntryKind.favorite
                : _StickerGridEntryKind.upload,
          ),
        )
        .toList();
  }

  Future<void> _uploadMediaFile(
    File file, {
    required String mediaType,
    bool compressStatic = true,
  }) async {
    if (_uploading) {
      return;
    }
    File uploadFile = file;
    var deleteAfterUpload = false;
    final isGif = mediaType == StickerUploadMediaType.gif;
    final isVideo = mediaType == StickerUploadMediaType.video;

    if (!isVideo && compressStatic) {
      final prepared = await StickerCompressUtil.compressForUpload(
        file,
        isGif: isGif,
      );
      if (prepared == null) {
        ToastUtils.toast(AppI18n.current.t(
          zhHans: '无法处理图片',
          zhHant: '無法處理圖片',
          en: 'Unable to process the image.',
          ja: '画像を処理できません。',
          ko: '이미지를 처리할 수 없습니다.',
        ));
        return;
      }
      uploadFile = prepared.file;
      deleteAfterUpload = prepared.deleteAfterUpload;
      mediaType = prepared.isGif
          ? StickerUploadMediaType.gif
          : StickerUploadMediaType.image;
    }

    final length = await uploadFile.length();
    if (length <= 0) {
      ToastUtils.toast(AppI18n.current.t(
        zhHans: '无法读取文件',
        zhHant: '無法讀取文件',
        en: 'Unable to read the file.',
        ja: 'ファイルを読み取れません。',
        ko: '파일을 읽을 수 없습니다.',
      ));
      return;
    }
    final maxBytes = isVideo
        ? StickerUploadMediaType.videoMaxBytes
        : (isGif
            ? StickerUploadMediaType.gifMaxBytes
            : StickerUploadMediaType.staticMaxBytes);
    if (length > maxBytes) {
      ToastUtils.toast(
        isVideo
            ? AppI18n.current.t(
                zhHans: '视频不能超过 50MB',
                zhHant: '視頻不能超過 50MB',
                en: 'Video must not exceed 50 MB.',
                ja: '動画は50MB以下にしてください。',
                ko: '동영상은 50MB를 초과할 수 없습니다.',
              )
            : isGif
                ? AppI18n.current.t(
                    zhHans: 'GIF 不能超过 5MB',
                    zhHant: 'GIF 不能超過 5MB',
                    en: 'GIF must not exceed 5 MB.',
                    ja: 'GIFは5MB以下にしてください。',
                    ko: 'GIF는 5MB를 초과할 수 없습니다.',
                  )
                : AppI18n.current.t(
                    zhHans: '图片不能超过 2MB',
                    zhHant: '圖片不能超過 2MB',
                    en: 'Image must not exceed 2 MB.',
                    ja: '画像は2MB以下にしてください。',
                    ko: '이미지는 2MB를 초과할 수 없습니다.',
                  ),
      );
      return;
    }

    setState(() => _uploading = true);
    try {
      final item = await StickerApi.instance.uploadSticker(
        uploadFile,
        mediaType: mediaType,
        isGif: mediaType == StickerUploadMediaType.gif,
      );
      await UserStickerProvider.shared.afterUpload(item);
    } catch (e) {
      ToastUtils.toast(StickerUploadError.message(e));
    } finally {
      if (deleteAfterUpload) {
        try {
          if (await uploadFile.exists()) {
            await uploadFile.delete();
          }
        } catch (_) {}
      }
      if (mounted) {
        setState(() => _uploading = false);
      }
    }
  }

  bool _pathLooksGif(String path) {
    final lower = path.toLowerCase();
    return lower.endsWith('.gif') || lower.contains('.gif?');
  }

  Future<bool> _isGifAsset(AssetEntity asset, String path) async {
    if (_pathLooksGif(path)) {
      return true;
    }
    final title = asset.title?.toLowerCase() ?? '';
    if (title.endsWith('.gif')) {
      return true;
    }
    final mime = await asset.mimeTypeAsync;
    if (mime != null && mime.toLowerCase().contains('gif')) {
      return true;
    }
    return false;
  }

  bool _isAllowedStaticMime(String? mime) {
    if (mime == null || mime.isEmpty) {
      return false;
    }
    final m = mime.toLowerCase();
    return m.contains('png') ||
        m.contains('jpeg') ||
        m.contains('jpg') ||
        m.contains('webp');
  }

  bool _isAllowedStaticPath(String path) {
    final dot = path.lastIndexOf('.');
    if (dot < 0 || dot >= path.length - 1) {
      return false;
    }
    return _staticExtensions.contains(path.substring(dot + 1).toLowerCase());
  }

  /// 相册选图/短视频（≤10 秒视频由服务端转 GIF）。
  Future<void> _pickAndUpload() async {
    if (_uploading || _organizing) {
      return;
    }
    final allowed = await PermissionGuard.photosForPick(context);
    if (!allowed || !mounted) {
      return;
    }
    final theme = Provider.of<DefaultThemeData>(context, listen: false).theme;
    final pickedAssets = await EditableAssetPicker.pickAssets(
      context,
      pickerConfig: AssetPickerConfig(
        maxAssets: 1,
        requestType: RequestType.common,
        themeColor: theme.primaryColor ?? const Color(0xFF1E90FF),
        selectPredicate: (context, asset, isSelected) =>
            asset.type == AssetType.image || asset.type == AssetType.video,
      ),
    );
    if (!mounted || pickedAssets == null || pickedAssets.isEmpty) {
      return;
    }
    final asset = pickedAssets.first;

    if (asset.type == AssetType.video) {
      final durationSec = asset.videoDuration.inSeconds;
      if (durationSec > StickerUploadMediaType.videoMaxDurationSec) {
        ToastUtils.toast(AppI18n.current.t(
          zhHans: '视频不能超过 10 秒',
          zhHant: '視頻不能超過 10 秒',
          en: 'Video must be 10 seconds or shorter.',
          ja: '動画は10秒以内にしてください。',
          ko: '동영상은 10초 이하여야 합니다.',
        ));
        return;
      }
      final file = await EditableAssetPicker.resolveFile(asset);
      if (file == null || !file.existsSync()) {
        ToastUtils.toast(AppI18n.current.t(
          zhHans: '无法读取文件',
          zhHant: '無法讀取文件',
          en: 'Unable to read the file.',
          ja: 'ファイルを読み取れません。',
          ko: '파일을 읽을 수 없습니다.',
        ));
        return;
      }
      final mime = await asset.mimeTypeAsync;
      if (!StickerUploadMediaType.isVideoPath(file.path) &&
          !StickerUploadMediaType.isVideoMime(mime)) {
        ToastUtils.toast(AppI18n.current.t(
          zhHans: '仅支持 MP4 / MOV / WebM 视频',
          zhHant: '僅支持 MP4 / MOV / WebM 視頻',
          en: 'Only MP4, MOV, or WebM video is supported.',
          ja: 'MP4 / MOV / WebM のみ対応しています。',
          ko: 'MP4, MOV, WebM 동영상만 지원합니다.',
        ));
        return;
      }
      await _uploadMediaFile(
        file,
        mediaType: StickerUploadMediaType.video,
        compressStatic: false,
      );
      return;
    }

    if (asset.type != AssetType.image) {
      ToastUtils.toast(AppI18n.current.t(
        zhHans: '仅支持图片、GIF 或 10 秒内视频',
        zhHant: '僅支持圖片、GIF 或 10 秒內視頻',
        en: 'Only images, GIFs, or videos up to 10s are supported.',
        ja: '画像・GIF・10秒以内の動画のみ対応しています。',
        ko: '이미지, GIF, 10초 이내 동영상만 지원합니다.',
      ));
      return;
    }
    final file = await EditableAssetPicker.resolveFile(asset);
    if (file == null || !file.existsSync()) {
      ToastUtils.toast(AppI18n.current.t(
        zhHans: '无法读取文件',
        zhHant: '無法讀取文件',
        en: 'Unable to read the file.',
        ja: 'ファイルを読み取れません。',
        ko: '파일을 읽을 수 없습니다.',
      ));
      return;
    }
    final path = file.path;
    final isGif = await _isGifAsset(asset, path);
    if (!isGif &&
        !_isAllowedStaticPath(path) &&
        !_isAllowedStaticMime(await asset.mimeTypeAsync)) {
      ToastUtils.toast(AppI18n.current.t(
        zhHans: '仅支持 PNG/JPEG/WebP、GIF 或 10 秒内视频',
        zhHant: '僅支持 PNG/JPEG/WebP、GIF 或 10 秒內視頻',
        en: 'Only PNG, JPEG, WebP, GIF, or short video is supported.',
        ja: 'PNG/JPEG/WebP・GIF・10秒以内の動画のみ対応しています。',
        ko: 'PNG, JPEG, WebP, GIF 또는 10초 이내 동영상만 지원합니다.',
      ));
      return;
    }
    await _uploadMediaFile(
      file,
      mediaType:
          isGif ? StickerUploadMediaType.gif : StickerUploadMediaType.image,
    );
  }

  Future<void> _confirmDelete(_StickerGridEntry entry) async {
    final i18n = AppI18n.of(context);
    final isFavorite = entry.kind == _StickerGridEntryKind.favorite;
    final ok = await AppDialog.confirm(
      title: i18n.t(
        zhHans: '删除表情',
        zhHant: '刪除表情',
        en: 'Delete Sticker',
        ja: 'スタンプを削除',
        ko: '스티커 삭제',
      ),
      message: isFavorite
          ? i18n.t(
              zhHans: '确定从收藏中移除',
              zhHant: '確定從收藏中移除',
              en: 'Remove from favorites?',
              ja: 'お気に入りから削除しますか？',
              ko: '즐겨찾기에서 제거하시겠습니까?',
            )
          : i18n.t(
              zhHans: '确定删除该表情',
              zhHant: '確定刪除該表情',
              en: 'Delete this sticker?',
              ja: 'このスタンプを削除しますか？',
              ko: '이 스티커를 삭제하시겠습니까?',
            ),
      confirmText: i18n.t(
        zhHans: '删除',
        zhHant: '刪除',
        en: 'Delete',
        ja: '削除',
        ko: '삭제',
      ),
      destructive: true,
    );
    if (ok != true) {
      return;
    }
    try {
      if (isFavorite) {
        await UserStickerProvider.shared.unfavorite(entry.item.stickerId);
      } else {
        await UserStickerProvider.shared.removeUpload(entry.item.stickerId);
      }
      ToastUtils.toast(AppI18n.current.t(
        zhHans: '已删除',
        zhHant: '已刪除',
        en: 'Deleted',
        ja: '削除しました',
        ko: '삭제됨',
      ));
    } catch (_) {
      ToastUtils.toast(AppI18n.current.t(
        zhHans: '删除失败',
        zhHant: '刪除失敗',
        en: 'Failed to delete.',
        ja: '削除に失敗しました。',
        ko: '삭제에 실패했습니다.',
      ));
    }
  }

  void _onStickerTap(_StickerGridEntry entry) {
    if (!_organizing) {
      return;
    }
    _confirmDelete(entry);
  }

  _StickerUploadPageColors _resolveColors(BuildContext context) {
    final theme = Provider.of<DefaultThemeData>(context).theme;
    final themeType = Provider.of<DefaultThemeData>(context).currentThemeType;
    final isDark = themeType == ThemeType.dark;
    final pageBackground = isDark
        ? (theme.weakBackgroundColor ??
            theme.wideBackgroundColor ??
            const Color(0xFF0F0F0F))
        : _lightPageBg;
    final tileBackground = isDark
        ? (theme.conversationItemBgColor ??
            theme.wideBackgroundColor ??
            const Color(0xFF171717))
        : Colors.white;
    return _StickerUploadPageColors(
      pageBackground: pageBackground,
      tileBackground: tileBackground,
      titleColor: theme.darkTextColor ?? Colors.black,
      actionColor: theme.primaryColor ?? const Color(0xFF1E90FF),
      addIconColor: theme.weakTextColor ?? const Color(0xFF8A8A8A),
      loadingScrim: isDark ? const Color(0x88000000) : const Color(0x55000000),
    );
  }

  @override
  Widget build(BuildContext context) {
    final i18n = AppI18n.of(context);
    final colors = _resolveColors(context);
    final entries = _allStickerEntries();
    final count = entries.length;
    final title = i18n.format(
      zhHans: '添加的单个表情 ({count})',
      zhHant: '添加的單個表情 ({count})',
      en: 'Custom Stickers ({count})',
      ja: '追加したスタンプ ({count})',
      ko: '추가한 스티커 ({count})',
      vars: {'count': count.toString()},
    );

    return Scaffold(
      backgroundColor: colors.pageBackground,
      appBar: AppBar(
        backgroundColor: colors.pageBackground,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: TextButton(
          onPressed: _uploading ? null : () => Navigator.pop(context),
          child: Text(
            i18n.t(
              zhHans: '关闭',
              zhHant: '關閉',
              en: 'Close',
              ja: '閉じる',
              ko: '닫기',
            ),
            style: TextStyle(
              color: colors.actionColor,
              fontSize: 16,
            ),
          ),
        ),
        leadingWidth: 72,
        title: Text(
          title,
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w600,
            color: colors.titleColor,
          ),
        ),
        centerTitle: true,
        actions: [
          TextButton(
            onPressed: _uploading
                ? null
                : () {
                    setState(() => _organizing = !_organizing);
                  },
            child: Text(
              _organizing
                  ? i18n.t(
                      zhHans: '完成',
                      zhHant: '完成',
                      en: 'Done',
                      ja: '完了',
                      ko: '완료',
                    )
                  : i18n.t(
                      zhHans: '整理',
                      zhHant: '整理',
                      en: 'Organize',
                      ja: '整理',
                      ko: '정리',
                    ),
              style: TextStyle(
                color: colors.actionColor,
                fontSize: 16,
              ),
            ),
          ),
        ],
      ),
      body: Stack(
        children: [
          GridView.builder(
            padding: const EdgeInsets.fromLTRB(8, 4, 8, 16),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 4,
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
              childAspectRatio: 1,
            ),
            itemCount: count + 1,
            itemBuilder: (context, index) {
              if (index == 0) {
                return _AddTile(
                  onTap: _pickAndUpload,
                  enabled: !_uploading && !_organizing,
                  tileBackground: colors.tileBackground,
                  addIconColor: colors.addIconColor,
                );
              }
              final entry = entries[index - 1];
              return _StickerTile(
                item: entry.item,
                organizing: _organizing,
                onTap: () => _onStickerTap(entry),
                tileBackground: colors.tileBackground,
              );
            },
          ),
          if (_uploading)
            ColoredBox(
              color: colors.loadingScrim,
              child: const Center(child: CircularProgressIndicator()),
            ),
        ],
      ),
    );
  }
}

class _StickerUploadPageColors {
  const _StickerUploadPageColors({
    required this.pageBackground,
    required this.tileBackground,
    required this.titleColor,
    required this.actionColor,
    required this.addIconColor,
    required this.loadingScrim,
  });

  final Color pageBackground;
  final Color tileBackground;
  final Color titleColor;
  final Color actionColor;
  final Color addIconColor;
  final Color loadingScrim;
}

class _AddTile extends StatelessWidget {
  const _AddTile({
    required this.onTap,
    required this.enabled,
    required this.tileBackground,
    required this.addIconColor,
  });

  final VoidCallback onTap;
  final bool enabled;
  final Color tileBackground;
  final Color addIconColor;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: tileBackground,
          borderRadius: BorderRadius.circular(4),
        ),
        child: Center(
          child: Icon(
            Icons.add,
            size: 36,
            color: enabled ? addIconColor : addIconColor.withValues(alpha: 0.4),
          ),
        ),
      ),
    );
  }
}

class _StickerTile extends StatelessWidget {
  const _StickerTile({
    required this.item,
    required this.organizing,
    required this.onTap,
    required this.tileBackground,
  });

  final StickerItem item;
  final bool organizing;
  final VoidCallback onTap;
  final Color tileBackground;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Stack(
        fit: StackFit.expand,
        children: [
          DecoratedBox(
            decoration: BoxDecoration(
              color: tileBackground,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Padding(
              padding: const EdgeInsets.all(6),
              child: StickerImage(
                item: item,
                preferAnimated: true,
                fit: BoxFit.contain,
              ),
            ),
          ),
          if (organizing)
            Positioned(
              top: 2,
              right: 2,
              child: Container(
                width: 22,
                height: 22,
                decoration: const BoxDecoration(
                  color: Color(0xFFE54D42),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.close,
                  size: 16,
                  color: Colors.white,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
