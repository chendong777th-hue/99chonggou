import 'dart:async' show unawaited;
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:tencent_cloud_chat_uikit/ui/widgets/chat_image_load_placeholder.dart';
import 'package:tencent_cloud_chat_uikit/ui/widgets/media_preview_chrome.dart';

/// Web 聊天气泡图片预览：Telegram Web 式全屏遮罩 lightbox（非 ImageScreen 路由）。
class ChatWebImageLightbox extends StatefulWidget {
  const ChatWebImageLightbox({
    required this.imageUrl,
    this.imageUrlResolver,
    this.onDownload,
    this.onDownloadUrl,
    this.onOpenExternal,
    super.key,
  });

  final String imageUrl;
  final Future<String?> Function()? imageUrlResolver;
  final VoidCallback? onDownload;
  final Future<void> Function(String imageUrl)? onDownloadUrl;
  final VoidCallback? onOpenExternal;

  static Future<void> show({
    required BuildContext context,
    required String imageUrl,
    Future<String?> Function()? imageUrlResolver,
    VoidCallback? onDownload,
    Future<void> Function(String imageUrl)? onDownloadUrl,
    VoidCallback? onOpenExternal,
  }) {
    return showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Close image preview',
      barrierColor: Colors.black.withValues(alpha: 0.88),
      transitionDuration: const Duration(milliseconds: 180),
      pageBuilder: (context, animation, secondaryAnimation) {
        return ChatWebImageLightbox(
          imageUrl: imageUrl,
          imageUrlResolver: imageUrlResolver,
          onDownload: onDownload,
          onDownloadUrl: onDownloadUrl,
          onOpenExternal: onOpenExternal,
        );
      },
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        return FadeTransition(opacity: animation, child: child);
      },
    );
  }

  @override
  State<ChatWebImageLightbox> createState() => _ChatWebImageLightboxState();
}

class _ChatWebImageLightboxState extends State<ChatWebImageLightbox> {
  final TransformationController _transformController =
      TransformationController();
  final GlobalKey _viewerKey =
      GlobalKey(debugLabel: 'ChatWebImageLightboxViewer');
  final FocusNode _focusNode = FocusNode(debugLabel: 'ChatWebImageLightbox');
  int _rotationTurns = 0;
  late String _imageUrl;
  bool _resolvedUrlAvailable = false;

  @override
  void initState() {
    super.initState();
    _imageUrl = widget.imageUrl;
    if (widget.imageUrlResolver != null) {
      unawaited(_resolveImageUrl());
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _focusNode.requestFocus();
      }
    });
  }

  Future<void> _resolveImageUrl() async {
    try {
      final resolved = (await widget.imageUrlResolver!())?.trim() ?? '';
      if (!mounted || resolved.isEmpty) {
        return;
      }
      setState(() {
        _imageUrl = resolved;
        _resolvedUrlAvailable = true;
      });
    } catch (_) {}
  }

  @override
  void dispose() {
    _transformController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _close() {
    Navigator.of(context).pop();
  }

  WebHtmlElementStrategy _webImageElementStrategyFor(String url) {
    if (url.startsWith('blob:') || url.startsWith('data:image')) {
      return WebHtmlElementStrategy.fallback;
    }
    return WebHtmlElementStrategy.prefer;
  }

  void _zoomBy(double factor) {
    final viewerContext = _viewerKey.currentContext;
    if (viewerContext == null) {
      return;
    }
    final renderBox = viewerContext.findRenderObject() as RenderBox?;
    if (renderBox == null || !renderBox.hasSize) {
      return;
    }

    final current = _transformController.value.getMaxScaleOnAxis();
    if (current <= 0) {
      return;
    }
    final target = (current * factor).clamp(0.35, 8.0);
    final scaleFactor = target / current;
    if ((scaleFactor - 1.0).abs() < 0.001) {
      return;
    }

    // 必须在 InteractiveViewer 视口坐标系中取焦点，再 toScene；
    // 直接用 MediaQuery 屏幕中心会在已有平移/缩放下产生左右漂移。
    final viewportSize = renderBox.size;
    final viewportCenter = Offset(
      viewportSize.width / 2,
      viewportSize.height / 2,
    );
    final focalPointScene = _transformController.toScene(viewportCenter);

    _transformController.value = _transformController.value.clone()
      ..translate(focalPointScene.dx, focalPointScene.dy)
      ..scale(scaleFactor)
      ..translate(-focalPointScene.dx, -focalPointScene.dy);
  }

  void _resetView() {
    _transformController.value = Matrix4.identity();
    setState(() => _rotationTurns = 0);
  }

  void _rotate() {
    setState(() => _rotationTurns = (_rotationTurns + 1) % 4);
  }

  Widget _buildImage() {
    final url = _imageUrl;
    return Image.network(
      url,
      fit: BoxFit.contain,
      gaplessPlayback: true,
      webHtmlElementStrategy: kIsWeb
          ? _webImageElementStrategyFor(url)
          : WebHtmlElementStrategy.never,
      errorBuilder: (context, error, stackTrace) {
        return ChatImageLoadPlaceholder.preview(
          width: math.min(MediaQuery.sizeOf(context).width * 0.72, 320),
          height: math.min(MediaQuery.sizeOf(context).height * 0.42, 240),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.escape): _close,
      },
      child: Focus(
        autofocus: true,
        focusNode: _focusNode,
        child: Material(
          type: MaterialType.transparency,
          child: Stack(
            fit: StackFit.expand,
            children: [
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: _close,
                child: const SizedBox.expand(),
              ),
              Positioned.fill(
                child: GestureDetector(
                  onTap: () {},
                  child: InteractiveViewer(
                    key: _viewerKey,
                    transformationController: _transformController,
                    minScale: 0.35,
                    maxScale: 8,
                    panEnabled: true,
                    scaleEnabled: true,
                    clipBehavior: Clip.none,
                    child: Transform.rotate(
                      angle: _rotationTurns * math.pi / 2,
                      child: SizedBox(
                        width: MediaQuery.sizeOf(context).width,
                        height: MediaQuery.sizeOf(context).height,
                        child: Center(child: _buildImage()),
                      ),
                    ),
                  ),
                ),
              ),
              MediaPreviewTopBar(
                title: '',
                subtitle: '',
                onBack: _close,
              ),
              Positioned(
                left: 0,
                right: 0,
                bottom: MediaQuery.paddingOf(context).bottom + 16,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _ToolbarButton(
                      icon: Icons.remove_rounded,
                      onPressed: () => _zoomBy(1 / 1.25),
                    ),
                    const SizedBox(width: 6),
                    _ToolbarButton(
                      icon: Icons.add_rounded,
                      onPressed: () => _zoomBy(1.25),
                    ),
                    const SizedBox(width: 6),
                    _ToolbarButton(
                      icon: Icons.rotate_right_rounded,
                      onPressed: _rotate,
                    ),
                    const SizedBox(width: 6),
                    _ToolbarButton(
                      icon: Icons.fit_screen_rounded,
                      onPressed: _resetView,
                    ),
                    if (widget.onDownload != null ||
                        (_resolvedUrlAvailable &&
                            widget.onDownloadUrl != null)) ...[
                      const SizedBox(width: 6),
                      _ToolbarButton(
                        icon: Icons.download_rounded,
                        onPressed: widget.onDownload ??
                            () {
                              unawaited(widget.onDownloadUrl!(_imageUrl));
                            },
                      ),
                    ],
                    if (widget.onOpenExternal != null) ...[
                      const SizedBox(width: 6),
                      _ToolbarButton(
                        icon: Icons.open_in_new_rounded,
                        onPressed: widget.onOpenExternal,
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ToolbarButton extends StatelessWidget {
  const _ToolbarButton({
    required this.icon,
    this.onPressed,
  });

  final IconData icon;
  final VoidCallback? onPressed;

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
