import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:tencent_cloud_chat_demo/src/widgets/app_network_image.dart';
import 'package:tencent_cloud_chat_demo/utils/conversation_face_url.dart';
import 'package:tencent_cloud_chat_demo/utils/user_avatar.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_user_status.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_user_status.dart';
import 'package:tencent_cloud_chat_uikit/ui/utils/image_mem_cache_utils.dart';
import 'package:tencent_cloud_chat_uikit/ui/widgets/avatar.dart';

class AppUserAvatar extends StatefulWidget {
  const AppUserAvatar({
    super.key,
    required this.faceUrl,
    required this.showName,
    this.size = 72,
    this.borderRadius,
    this.onlineStatus,

    /// `1` 单聊 / 用户；`2` 群聊。决定占位默认头像。
    this.type = 1,
    this.showPlaceholder = true,
    this.preferRasterPlaceholder = false,
  });

  final String faceUrl;
  final String showName;
  final double size;
  final BorderRadius? borderRadius;
  final V2TimUserStatus? onlineStatus;
  final int type;
  final bool showPlaceholder;
  final bool preferRasterPlaceholder;

  @override
  State<AppUserAvatar> createState() => _AppUserAvatarState();
}

class _AppUserAvatarState extends State<AppUserAvatar> {
  Widget _rasterDefaultLayer(BuildContext context) {
    final cacheSize = ImageMemCacheSize.forLogicalSize(widget.size, context);
    return Image.asset(
      widget.type == 2
          ? 'images/default_group_head.png'
          : 'images/default_c2c_head.png',
      package: 'tencent_cloud_chat_uikit',
      width: widget.size,
      height: widget.size,
      fit: BoxFit.cover,
      cacheWidth: cacheSize,
      cacheHeight: cacheSize,
      filterQuality: FilterQuality.low,
    );
  }

  Widget _defaultLayer(BuildContext context) {
    if (widget.preferRasterPlaceholder) {
      return _rasterDefaultLayer(context);
    }
    return Avatar(
      faceUrl: '',
      showName: widget.showName,
      onlineStatus: widget.onlineStatus,
      borderRadius: BorderRadius.zero,
      type: widget.type == 2 ? 2 : 1,
    );
  }

  @override
  Widget build(BuildContext context) {
    final assetPath = widget.faceUrl.trim();
    if (assetPath.startsWith('assets/')) {
      if (!widget.showPlaceholder &&
          (assetPath == ConversationFaceUrl.defaultGroupFaceAsset ||
              assetPath == UserAvatarHelper.appDefaultAvatarAsset)) {
        return SizedBox(width: widget.size, height: widget.size);
      }
      if (widget.preferRasterPlaceholder &&
          assetPath == ConversationFaceUrl.defaultGroupFaceAsset) {
        return SizedBox(
          width: widget.size,
          height: widget.size,
          child: ClipOval(child: _rasterDefaultLayer(context)),
        );
      }
      return SizedBox(
        width: widget.size,
        height: widget.size,
        child: ClipOval(
          child: assetPath.toLowerCase().endsWith('.svg')
              ? SvgPicture.asset(
                  assetPath,
                  width: widget.size,
                  height: widget.size,
                  fit: BoxFit.cover,
                )
              : Image.asset(
                  assetPath,
                  width: widget.size,
                  height: widget.size,
                  fit: BoxFit.cover,
                ),
        ),
      );
    }

    // 群聊无有效网络头像时直接用群默认图，不要叠用户默认底图。
    final resolved = UserAvatarHelper.usableAvatarOrEmpty(widget.faceUrl);
    if (resolved.isEmpty && !widget.showPlaceholder) {
      return SizedBox(width: widget.size, height: widget.size);
    }
    if (resolved.isEmpty && widget.type == 2) {
      if (widget.preferRasterPlaceholder) {
        return SizedBox(
          width: widget.size,
          height: widget.size,
          child: ClipOval(child: _rasterDefaultLayer(context)),
        );
      }
      return SizedBox(
        width: widget.size,
        height: widget.size,
        child: ClipOval(
          child: SvgPicture.asset(
            ConversationFaceUrl.defaultGroupFaceAsset,
            width: widget.size,
            height: widget.size,
            fit: BoxFit.cover,
          ),
        ),
      );
    }

    // 网络层始终保持挂载。CachedNetworkImage 自身负责内存/磁盘缓存。
    final headers = resolved.isEmpty
        ? null
        : UserAvatarHelper.httpHeadersFor(
            UserAvatarHelper.resolveDisplayUrl(resolved) ?? resolved,
          );
    final cacheSize = ImageMemCacheSize.forLogicalSize(widget.size, context);
    final shouldLoadNetwork = resolved.isNotEmpty;

    return RepaintBoundary(
      child: SizedBox(
        width: widget.size,
        height: widget.size,
        child: ClipOval(
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (widget.showPlaceholder) _defaultLayer(context),
              if (shouldLoadNetwork)
                AppNetworkImage(
                  url: UserAvatarHelper.resolveDisplayUrl(resolved) ?? resolved,
                  cacheKey: resolved,
                  useOldImageOnUrlChange: true,
                  headers: headers,
                  width: widget.size,
                  height: widget.size,
                  fit: BoxFit.cover,
                  memCacheWidth: cacheSize,
                  memCacheHeight: cacheSize,
                  maxWidthDiskCache: cacheSize,
                  maxHeightDiskCache: cacheSize,
                  fadeInDuration: Duration.zero,
                  fadeOutDuration: Duration.zero,
                  placeholder: (_, __) => const SizedBox.shrink(),
                  imageBuilder: (context, imageProvider) {
                    return Image(
                      image: imageProvider,
                      width: widget.size,
                      height: widget.size,
                      fit: BoxFit.cover,
                      gaplessPlayback: true,
                      filterQuality: FilterQuality.low,
                    );
                  },
                  errorWidget: (_, __, ___) => const SizedBox.shrink(),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
