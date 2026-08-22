import 'package:awesome_video_player/awesome_video_player.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:tencent_cloud_chat_demo/src/i18n/app_i18n.dart';
import 'package:tencent_cloud_chat_demo/src/models/favorite_message_models.dart';
import 'package:tencent_cloud_chat_demo/src/pages/favorites/favorite_edit_page.dart';
import 'package:tencent_cloud_chat_demo/src/pages/favorites/widgets/favorite_media_preview.dart';
import 'package:tencent_cloud_chat_demo/src/theme/app_colors.dart';
import 'package:dio/dio.dart';
import 'package:tencent_cloud_chat_demo/src/api/favorite_message_api.dart';
import 'package:tencent_cloud_chat_demo/utils/media_url_resolver.dart';
import 'package:tencent_cloud_chat_demo/utils/toast.dart';
import 'package:tencent_cloud_chat_demo/src/platform/clipboard_guard.dart';
import 'package:tencent_cloud_chat_demo/src/widgets/app_dialog.dart';

/// 收藏详情：文本全文 / 图片查看 / 视频播放；支持编辑。
class FavoriteMessageDetailPage extends StatefulWidget {
  const FavoriteMessageDetailPage({
    super.key,
    required this.item,
    this.onChanged,
    this.onDeleted,
  });

  final FavoriteMessageItem item;
  final Future<void> Function(FavoriteMessageItem item)? onChanged;
  final VoidCallback? onDeleted;

  @override
  State<FavoriteMessageDetailPage> createState() =>
      _FavoriteMessageDetailPageState();
}

class _FavoriteMessageDetailPageState extends State<FavoriteMessageDetailPage> {
  late FavoriteMessageItem _item;
  BetterPlayerController? _videoController;
  String? _videoSourceKey;

  @override
  void initState() {
    super.initState();
    _item = widget.item;
  }

  @override
  void dispose() {
    _videoController?.dispose();
    super.dispose();
  }

  String? _resolveUrl(String? raw) {
    if (raw == null || raw.trim().isEmpty) return null;
    if (raw.startsWith('http')) {
      return MediaUrlResolver.resolve(raw) ?? raw;
    }
    return raw;
  }

  Map<String, String>? _headersFor(String url) {
    return MediaUrlResolver.authHeadersFor(url);
  }

  Future<void> _copyText() async {
    final text = _item.text?.trim() ?? '';
    if (text.isEmpty) return;
    await ClipboardGuard.copy(text);
    ToastUtils.toast(AppI18n.current.t(
      zhHans: '已复制',
      zhHant: '已複製',
      en: 'Copied',
      ja: 'コピーしました',
      ko: '복사됨',
    ));
  }

  void _resetVideoController() {
    _videoController?.dispose();
    _videoController = null;
    _videoSourceKey = null;
  }

  void _initVideoIfNeeded() {
    if (_item.type != FavoriteMessageType.video) {
      return;
    }
    final raw = _item.displayMediaPathOrUrl;
    if (raw == null || raw.isEmpty) return;
    if (_videoSourceKey == raw && _videoController != null) {
      return;
    }
    _resetVideoController();
    _videoSourceKey = raw;

    if (_item.isLocalMedia) {
      _videoController = BetterPlayerController(
        const BetterPlayerConfiguration(
          autoPlay: true,
          fit: BoxFit.contain,
          aspectRatio: 16 / 9,
          controlsConfiguration: BetterPlayerControlsConfiguration(
            enableFullscreen: true,
            enablePlayPause: true,
          ),
        ),
        betterPlayerDataSource: BetterPlayerDataSource(
          BetterPlayerDataSourceType.file,
          raw,
        ),
      );
      return;
    }

    final url = _resolveUrl(raw);
    if (url == null) return;
    _videoController = BetterPlayerController(
      const BetterPlayerConfiguration(
        autoPlay: true,
        fit: BoxFit.contain,
        aspectRatio: 16 / 9,
        controlsConfiguration: BetterPlayerControlsConfiguration(
          enableFullscreen: true,
          enablePlayPause: true,
        ),
      ),
      betterPlayerDataSource: BetterPlayerDataSource(
        BetterPlayerDataSourceType.network,
        url,
        headers: _headersFor(url),
      ),
    );
  }

  Future<void> _delete() async {
    final i18n = AppI18n.of(context);
    final ok = await AppDialog.confirm(
      title: i18n.t(
        zhHans: '删除收藏',
        zhHant: '刪除收藏',
        en: 'Delete Favorite',
        ja: 'お気に入りを削除',
        ko: '즐겨찾기 삭제',
      ),
      message: i18n.t(
        zhHans: '删除后无法恢复，确定删除吗？',
        zhHant: '刪除後無法恢復，確定刪除嗎？',
        en: 'This cannot be undone. Delete it?',
        ja: '削除後は元に戻せません。削除しますか？',
        ko: '삭제 후 복구할 수 없습니다. 삭제하시겠습니까?',
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
    if (ok != true || !mounted) return;
    try {
      await FavoriteMessageApi.instance.delete(_item.id);
      widget.onDeleted?.call();
      if (mounted) {
        ToastUtils.toast(AppI18n.current.t(
          zhHans: '已删除',
          zhHant: '已刪除',
          en: 'Deleted',
          ja: '削除しました',
          ko: '삭제됨',
        ));
        Navigator.pop(context);
      }
    } on DioError catch (e) {
      ToastUtils.toast(FavoriteMessageApi.errorMessage(e));
    }
  }

  Future<void> _edit() async {
    final updated = await FavoriteEditPage.pushEdit(context, _item);
    if (updated == null || !mounted) return;
    setState(() {
      _item = updated;
      if (_item.type != FavoriteMessageType.video) {
        _resetVideoController();
      }
    });
    await widget.onChanged?.call(updated);
    ToastUtils.toast(AppI18n.current.t(
      zhHans: '已保存',
      zhHant: '已儲存',
      en: 'Saved',
      ja: '保存しました',
      ko: '저장됨',
    ));
  }

  @override
  Widget build(BuildContext context) {
    _initVideoIfNeeded();
    final i18n = AppI18n.of(context);
    final dark = Theme.of(context).brightness == Brightness.dark;
    final isImage = _item.type == FavoriteMessageType.image;

    return Scaffold(
      backgroundColor:
          isImage ? Colors.black : AppColors.background(dark: dark),
      appBar: AppBar(
        elevation: 0,
        centerTitle: true,
        backgroundColor:
            isImage ? Colors.black : AppColors.card(dark: dark),
        surfaceTintColor: Colors.transparent,
        iconTheme: IconThemeData(
          color: isImage ? Colors.white : AppColors.primaryBlue,
        ),
        title: Text(
          _titleForType(_item.type, i18n),
          style: TextStyle(
            color: isImage ? Colors.white : AppColors.text(dark: dark),
            fontSize: 17,
            fontWeight: FontWeight.w600,
          ),
        ),
        actions: [
          if (_item.type == FavoriteMessageType.text)
            TextButton(
              onPressed: _copyText,
              child: Text(
                i18n.t(
                  zhHans: '复制',
                  zhHant: '複製',
                  en: 'Copy',
                  ja: 'コピー',
                  ko: '복사',
                ),
                style: TextStyle(
                  color: isImage ? Colors.white : AppColors.primaryBlue,
                ),
              ),
            ),
          IconButton(
            icon: Icon(
              Icons.edit_outlined,
              color: isImage ? Colors.white : AppColors.primaryBlue,
            ),
            onPressed: _edit,
            tooltip: i18n.t(
              zhHans: '编辑',
              zhHant: '編輯',
              en: 'Edit',
              ja: '編集',
              ko: '편집',
            ),
          ),
          IconButton(
            icon: Icon(
              Icons.delete_outline,
              color: isImage ? Colors.white70 : const Color(0xFFE64340),
            ),
            onPressed: _delete,
            tooltip: i18n.t(
              zhHans: '删除',
              zhHant: '刪除',
              en: 'Delete',
              ja: '削除',
              ko: '삭제',
            ),
          ),
        ],
      ),
      body: _buildBody(dark, i18n),
    );
  }

  String _titleForType(FavoriteMessageType type, AppI18n i18n) {
    switch (type) {
      case FavoriteMessageType.text:
        return i18n.t(
          zhHans: '详情',
          zhHant: '詳情',
          en: 'Details',
          ja: '詳細',
          ko: '상세',
        );
      case FavoriteMessageType.image:
        return i18n.t(
          zhHans: '图片',
          zhHant: '圖片',
          en: 'Image',
          ja: '画像',
          ko: '이미지',
        );
      case FavoriteMessageType.video:
        return i18n.t(
          zhHans: '视频',
          zhHant: '視頻',
          en: 'Video',
          ja: '動画',
          ko: '동영상',
        );
    }
  }

  Widget _buildBody(bool dark, AppI18n i18n) {
    switch (_item.type) {
      case FavoriteMessageType.text:
        return _buildTextBody(dark, i18n);
      case FavoriteMessageType.image:
        return _buildImageBody(i18n);
      case FavoriteMessageType.video:
        return _buildVideoBody(dark, i18n);
    }
  }

  Widget _buildTextBody(bool dark, AppI18n i18n) {
    final text = _item.text?.trim() ?? '';
    final meta = _metaLine(i18n);

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      children: [
        if (meta != null) ...[
          Text(
            meta,
            style: TextStyle(
              fontSize: 13,
              color: AppColors.subText(dark: dark),
            ),
          ),
          const SizedBox(height: 12),
        ],
        SelectableText(
          text.isEmpty
              ? i18n.t(
                  zhHans: '（无内容）',
                  zhHant: '（無內容）',
                  en: '(No content)',
                  ja: '（内容なし）',
                  ko: '(내용 없음)',
                )
              : text,
          style: TextStyle(
            fontSize: 17,
            height: 1.55,
            color: AppColors.text(dark: dark),
          ),
        ),
      ],
    );
  }

  Widget _buildImageBody(AppI18n i18n) {
    final pathOrUrl = _item.displayMediaPathOrUrl;
    if (pathOrUrl == null) {
      return Center(
        child: Text(
          i18n.t(
            zhHans: '暂无图片',
            zhHant: '暫無圖片',
            en: 'No image',
            ja: '画像がありません',
            ko: '이미지 없음',
          ),
          style: const TextStyle(color: Colors.white70),
        ),
      );
    }

    return Stack(
      children: [
        InteractiveViewer(
          minScale: 0.5,
          maxScale: 4,
          child: Center(
            child: FavoriteMediaPreview(
              pathOrUrl: pathOrUrl,
              fit: BoxFit.contain,
            ),
          ),
        ),
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: SafeArea(
            top: false,
            child: Container(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
              color: Colors.black.withValues(alpha: 0.48),
              child: Text(
                _metaLine(i18n)!,
                style: const TextStyle(
                  fontSize: 13,
                  height: 1.45,
                  color: Colors.white70,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildVideoBody(bool dark, AppI18n i18n) {
    final controller = _videoController;
    if (controller == null) {
      return Center(
        child: Text(
          i18n.t(
            zhHans: '无法播放视频',
            zhHant: '無法播放視頻',
            en: 'Unable to play video',
            ja: '動画を再生できません',
            ko: '동영상을 재생할 수 없습니다',
          ),
          style: TextStyle(color: AppColors.subText(dark: dark)),
        ),
      );
    }

    return Column(
      children: [
        AspectRatio(
          aspectRatio: 16 / 9,
          child: BetterPlayer(controller: controller),
        ),
        if (_metaLine(i18n) != null) ...[
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              _metaLine(i18n)!,
              style: TextStyle(
                fontSize: 13,
                color: AppColors.subText(dark: dark),
              ),
            ),
          ),
        ],
      ],
    );
  }

  String? _metaLine(AppI18n i18n) {
    final sender = _item.sourceSenderName?.trim() ?? '';
    final conv = _item.sourceConvLabel?.trim() ?? '';
    final parts = <String>[];
    if (sender.isNotEmpty) parts.add(sender);
    if (conv.isNotEmpty && conv != sender) parts.add(conv);
    final source = parts.isEmpty
        ? i18n.t(
            zhHans: '手动添加',
            zhHant: '手動新增',
            en: 'Manual',
            ja: '手動追加',
            ko: '직접 추가',
          )
        : parts.join(' · ');
    final sourceLabel = i18n.t(
      zhHans: '来源',
      zhHant: '來源',
      en: 'Source',
      ja: 'ソース',
      ko: '출처',
    );
    final timeLabel = i18n.t(
      zhHans: '收藏时间',
      zhHant: '收藏時間',
      en: 'Saved at',
      ja: '保存日時',
      ko: '저장 시간',
    );
    final time = DateFormat('yyyy-MM-dd HH:mm')
        .format(_item.favoritedAt.toLocal());
    return '$sourceLabel：$source\n$timeLabel：$time';
  }
}
