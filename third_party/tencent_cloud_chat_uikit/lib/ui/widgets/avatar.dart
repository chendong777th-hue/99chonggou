import 'dart:async' show unawaited;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_user_status.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_user_status.dart';
import 'package:tencent_cloud_chat_uikit/business_logic/view_models/tui_self_info_view_model.dart';
import 'package:tencent_cloud_chat_uikit/ui/utils/common_utils.dart';
import 'package:tencent_cloud_chat_uikit/ui/utils/image_mem_cache_utils.dart';
import 'package:tencent_cloud_chat_uikit/ui/utils/media_preview_presenter.dart';
import 'package:tencent_cloud_chat_uikit/ui/widgets/chat_web_image_lightbox.dart';
import 'package:tencent_cloud_chat_uikit/ui/widgets/image_screen.dart';
import 'package:tencent_cloud_chat_uikit/ui/widgets/media_preview_slide_metrics.dart';
import 'package:tencent_cloud_chat_uikit/base_widgets/tim_ui_kit_statelesswidget.dart';
import 'package:tencent_cloud_chat_uikit/data_services/core/core_services_implements.dart';
import 'package:tencent_cloud_chat_uikit/data_services/services_locatar.dart';
import 'package:tencent_cloud_chat_uikit/base_widgets/tim_ui_kit_base.dart';
import 'package:tencent_cloud_chat_uikit/theme/tui_theme.dart';

class Avatar extends TIMUIKitStatelessWidget {
  final String faceUrl;
  final String showName;
  final bool isFromLocalAsset;
  final CoreServicesImpl coreService = serviceLocator<CoreServicesImpl>();
  final BorderRadius? borderRadius;
  final V2TimUserStatus? onlineStatus;
  final int? type; // 1 c2c 2 group
  final bool isShowBigWhenClick;
  final TUISelfInfoViewModel selfInfoViewModel =
      serviceLocator<TUISelfInfoViewModel>();

  Avatar(
      {Key? key,
      required this.faceUrl,
      this.onlineStatus,
      required this.showName,
      this.isShowBigWhenClick = false,
      this.isFromLocalAsset = false,
      this.borderRadius,
      this.type = 1})
      : super(key: key);

  Widget getImageWidget(BuildContext context, TUITheme theme) {
    Widget buildAssetAvatar(String path, {String? package}) {
      if (path.toLowerCase().endsWith('.svg')) {
        return SvgPicture.asset(
          path,
          fit: BoxFit.cover,
          package: package,
        );
      }
      return Image.asset(
        path,
        fit: BoxFit.cover,
        package: package,
      );
    }

    Widget defaultAvatar() {
      if (type == 1) {
        return buildAssetAvatar(
          'images/default_c2c_head.png',
          package: 'tencent_cloud_chat_uikit',
        );
      } else {
        final assetPath = TencentUtils.checkString(
                selfInfoViewModel.globalConfig?.defaultAvatarAssetPath) ??
            'images/default_group_head.png';
        return buildAssetAvatar(
          assetPath,
          package:
              selfInfoViewModel.globalConfig?.defaultAvatarAssetPath != null
                  ? null
                  : 'tencent_cloud_chat_uikit',
        );
      }
    }

    // Real network URL: hold a neutral opaque surface while decoding.
    // Do NOT flash the default C2C/group head when faceUrl is already known
    // (profile open from a list that already showed this peer).
    Widget placeholderForFaceUrl(String url) {
      if (url.trim().isEmpty || _isDefaultAvatarUrl(url)) {
        return defaultAvatar();
      }
      return const ColoredBox(color: Color(0xFFE8E8E8));
    }

    // final emptyAvatarBuilder = coreService.emptyAvatarBuilder;
    if (faceUrl != "") {
      if (isFromLocalAsset) {
        return buildAssetAvatar(faceUrl);
      }
      if (_isDefaultAvatarUrl(faceUrl)) {
        return defaultAvatar();
      }
      if (kIsWeb && _isOssLikeNetworkUrl(faceUrl)) {
        return LayoutBuilder(
          builder: (context, constraints) {
            return RepaintBoundary(
              child: Image.network(
                faceUrl,
                fit: BoxFit.cover,
                width: double.infinity,
                height: double.infinity,
                gaplessPlayback: true,
                webHtmlElementStrategy: WebHtmlElementStrategy.prefer,
                loadingBuilder: (context, child, loadingProgress) {
                  if (loadingProgress == null) {
                    return child;
                  }
                  return placeholderForFaceUrl(faceUrl);
                },
                errorBuilder: (_, __, ___) => defaultAvatar(),
              ),
            );
          },
        );
      }
      return LayoutBuilder(
        builder: (context, constraints) {
          final cacheSize = ImageMemCacheSize.forBox(constraints, context);
          return RepaintBoundary(
            child: CachedNetworkImage(
              imageUrl: faceUrl,
              cacheKey: faceUrl,
              useOldImageOnUrlChange: true,
              fit: BoxFit.cover,
              width: double.infinity,
              height: double.infinity,
              memCacheWidth: cacheSize,
              memCacheHeight: cacheSize,
              maxWidthDiskCache: cacheSize,
              maxHeightDiskCache: cacheSize,
              fadeInDuration: const Duration(milliseconds: 0),
              fadeOutDuration: Duration.zero,
              // 真实 URL 冷解码用中性底，避免默认头闪一下再换成真头像。
              placeholder: (context, url) => placeholderForFaceUrl(url),
              imageBuilder: (context, imageProvider) => Image(
                image: imageProvider,
                fit: BoxFit.cover,
                width: double.infinity,
                height: double.infinity,
                gaplessPlayback: true,
                filterQuality: FilterQuality.low,
              ),
              errorWidget: (BuildContext context, String c, dynamic s) {
                return defaultAvatar();
              },
            ),
          );
        },
      );
    } else {
      return defaultAvatar();
    }
  }

  Widget _clipAvatar(
      {required BorderRadius borderRadius, required Widget child}) {
    final radius = borderRadius.topLeft.x;
    if (radius >= 999) {
      return ClipOval(child: child);
    }
    return ClipRRect(borderRadius: borderRadius, child: child);
  }

  bool _isDefaultAvatarUrl(String url) {
    final lower = url.trim().toLowerCase();
    return lower.contains('default_c2c_head') ||
        lower.contains('default_group_head');
  }

  bool _isOssLikeNetworkUrl(String url) {
    final trimmed = url.trim();
    if (!trimmed.startsWith('http://') && !trimmed.startsWith('https://')) {
      return false;
    }
    return true;
  }

  ImageProvider getImageProvider() {
    ImageProvider defaultAvatar() {
      if (type == 1) {
        return Image.asset('images/default_c2c_head.png',
                fit: BoxFit.cover, package: 'tencent_cloud_chat_uikit')
            .image;
      } else {
        return Image.asset(
                TencentUtils.checkString(selfInfoViewModel
                        .globalConfig?.defaultAvatarAssetPath) ??
                    'images/default_group_head.png',
                fit: BoxFit.cover,
                package:
                    selfInfoViewModel.globalConfig?.defaultAvatarAssetPath !=
                            null
                        ? null
                        : 'tencent_cloud_chat_uikit')
            .image;
      }
    }

    if (faceUrl != "") {
      if (isFromLocalAsset) {
        return Image.asset(faceUrl).image;
      }
      if (_isDefaultAvatarUrl(faceUrl)) {
        return defaultAvatar();
      }
      if (kIsWeb && _isOssLikeNetworkUrl(faceUrl)) {
        return NetworkImage(
          faceUrl,
          webHtmlElementStrategy: WebHtmlElementStrategy.prefer,
        );
      }
      return CachedNetworkImageProvider(
        faceUrl,
      );
    } else {
      return defaultAvatar();
    }
  }

  ({String path, String? package}) _resolveDefaultAvatarAsset() {
    if (type == 1) {
      return (
        path: 'images/default_c2c_head.png',
        package: 'tencent_cloud_chat_uikit'
      );
    }
    final custom = TencentUtils.checkString(
      selfInfoViewModel.globalConfig?.defaultAvatarAssetPath,
    );
    if (custom != null) {
      return (path: custom, package: null);
    }
    return (
      path: 'images/default_group_head.png',
      package: 'tencent_cloud_chat_uikit'
    );
  }

  Future<void> _openBigAvatar(BuildContext context) async {
    final downloadFn = _buildPreviewDownloadFn(context);
    final trimmed = faceUrl.trim();

    void openAssetPreview() {
      final asset = _resolveDefaultAvatarAsset();
      if (asset.path.toLowerCase().endsWith('.svg')) {
        pushMediaPreview(
          context: context,
          enableGestureBack: false,
          child: _AvatarAssetPreviewPage(
            assetPath: asset.path,
            package: asset.package,
            downloadFn: downloadFn,
          ),
        );
        return;
      }
      pushMediaPreview(
        context: context,
        enableGestureBack: false,
        child: ImageScreen(
          imageProvider: getImageProvider(),
          heroTag: '',
          downloadFn: downloadFn,
          downloadOnly: true,
          fitTallImagesToScreenWidth: false,
        ),
      );
    }

    // Web：禁止走 ImageScreen（会读像素触发 Same-Origin / CORS 红屏）。
    if (kIsWeb) {
      if (trimmed.isEmpty ||
          isFromLocalAsset ||
          _isDefaultAvatarUrl(trimmed) ||
          (!trimmed.startsWith('http://') &&
              !trimmed.startsWith('https://') &&
              !trimmed.startsWith('data:'))) {
        openAssetPreview();
        return;
      }

      var previewUrl = trimmed;
      final preparer =
          selfInfoViewModel.globalConfig?.prepareWebAvatarPreviewUrl;
      if (preparer != null) {
        try {
          final prepared = await preparer(trimmed);
          if (prepared != null && prepared.trim().isNotEmpty) {
            previewUrl = prepared.trim();
          }
        } catch (_) {}
      }
      if (!context.mounted) {
        return;
      }

      await ChatWebImageLightbox.show(
        context: context,
        imageUrl: previewUrl,
        onDownload: downloadFn == null
            ? null
            : () {
                unawaited(downloadFn());
              },
      );
      return;
    }

    if (trimmed.isEmpty) {
      openAssetPreview();
      return;
    }

    pushMediaPreview(
      context: context,
      enableGestureBack: false,
      child: ImageScreen(
        imageProvider: getImageProvider(),
        heroTag: '',
        downloadFn: downloadFn,
        downloadOnly: true,
        fitTallImagesToScreenWidth: false,
      ),
    );
  }

  Future<void> Function()? _buildPreviewDownloadFn(BuildContext context) {
    final saver = selfInfoViewModel.globalConfig?.saveAvatarPreview;
    if (saver == null) {
      return null;
    }
    final fallback =
        faceUrl.trim().isEmpty ? _resolveDefaultAvatarAsset() : null;
    return () => saver(
          context,
          faceUrl: faceUrl,
          showName: showName,
          avatarType: type ?? 1,
          fallbackAssetPath: fallback?.path,
          fallbackAssetPackage: fallback?.package,
        );
  }

  @override
  Widget tuiBuild(BuildContext context, TUIKitBuildValue value) {
    final TUITheme theme = value.theme;

    return Stack(
      fit: StackFit.expand,
      clipBehavior: Clip.none,
      children: [
        if (isShowBigWhenClick)
          GestureDetector(
            onTap: () {
              unawaited(_openBigAvatar(context));
            },
            child: ClipRRect(
              borderRadius: borderRadius ??
                  selfInfoViewModel.globalConfig?.defaultAvatarBorderRadius ??
                  BorderRadius.circular(4.8),
              child: getImageWidget(context, theme),
            ),
          ),
        if (!isShowBigWhenClick)
          _clipAvatar(
            borderRadius: borderRadius ??
                selfInfoViewModel.globalConfig?.defaultAvatarBorderRadius ??
                BorderRadius.circular(4.8),
            child: getImageWidget(context, theme),
          ),
        if (onlineStatus?.statusType == 1)
          Positioned(
            bottom: -1.5,
            right: -1.5,
            child: Container(
              width: 12,
              height: 12,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: Colors.white,
                  width: 2.0,
                ),
                color:
                    theme.conversationItemOnlineStatusBgColor ?? Colors.green,
              ),
              child: null,
            ),
          ),
      ],
    );
  }
}

class _AvatarAssetPreviewPage extends StatefulWidget {
  const _AvatarAssetPreviewPage({
    required this.assetPath,
    this.package,
    this.downloadFn,
  });

  final String assetPath;
  final String? package;
  final Future<void> Function()? downloadFn;

  @override
  State<_AvatarAssetPreviewPage> createState() =>
      _AvatarAssetPreviewPageState();
}

class _AvatarAssetPreviewPageState extends State<_AvatarAssetPreviewPage> {
  final MediaPreviewSlideMetrics _slideMetrics = MediaPreviewSlideMetrics();
  bool _isSaving = false;
  bool _isClosing = false;

  @override
  void dispose() {
    _slideMetrics.dispose();
    super.dispose();
  }

  Future<void> _close() async {
    if (_isClosing || !mounted) {
      return;
    }
    _isClosing = true;
    await Navigator.of(context).maybePop();
  }

  Future<void> _handleDownload() async {
    final downloadFn = widget.downloadFn;
    if (downloadFn == null || _isSaving) {
      return;
    }
    setState(() => _isSaving = true);
    try {
      await downloadFn();
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  void _handleSlideEnd(Velocity velocity) {
    if (_isClosing) {
      return;
    }
    if (mediaPreviewShouldDismissForSlide(
      _slideMetrics.slideOffset,
      velocity.pixelsPerSecond.dy,
    )) {
      _close();
      return;
    }
    _slideMetrics.resetBackdrop();
  }

  @override
  Widget build(BuildContext context) {
    final isSvg = widget.assetPath.toLowerCase().endsWith('.svg');
    final chromeAnimation = mediaPreviewChromeAnimation(context);
    final screenSize = MediaQuery.sizeOf(context);
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          Positioned.fill(
            child: ListenableBuilder(
              listenable: _slideMetrics,
              builder: (context, _) {
                return ColoredBox(
                  color: Colors.black.withValues(
                    alpha: _slideMetrics.backdropOpacity,
                  ),
                );
              },
            ),
          ),
          MediaPreviewVerticalDismissLayer(
            metrics: _slideMetrics,
            onSlideEndWithVelocity: _handleSlideEnd,
            child: GestureDetector(
              onTap: _close,
              child: Center(
                child: ListenableBuilder(
                  listenable: _slideMetrics,
                  builder: (context, child) {
                    return Transform.translate(
                      offset: _slideMetrics.slideOffset,
                      child: child,
                    );
                  },
                  child: InteractiveViewer(
                    minScale: 0.8,
                    maxScale: 4,
                    child: SizedBox(
                      width: screenSize.width,
                      height: screenSize.height,
                      child: Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: screenSize.width * 0.08,
                          vertical: 24,
                        ),
                        child: isSvg
                            ? SvgPicture.asset(
                                widget.assetPath,
                                package: widget.package,
                                fit: BoxFit.contain,
                              )
                            : Image.asset(
                                widget.assetPath,
                                package: widget.package,
                                fit: BoxFit.contain,
                              ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          SafeArea(
            child: FadeTransition(
              opacity: chromeAnimation,
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back_ios_new_rounded,
                        color: Colors.white),
                    onPressed: _close,
                  ),
                  const Spacer(),
                  if (widget.downloadFn != null)
                    IconButton(
                      icon: _isSaving
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.download_rounded,
                              color: Colors.white),
                      onPressed: _isSaving ? null : _handleDownload,
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
