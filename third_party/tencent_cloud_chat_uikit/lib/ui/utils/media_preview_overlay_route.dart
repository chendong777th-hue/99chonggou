import 'package:flutter/material.dart';
import 'package:tencent_cloud_chat_uikit/ui/utils/ios_back_gesture.dart';
import 'package:tencent_cloud_chat_uikit/ui/utils/media_preview_video_utils.dart';

/// 全屏媒体预览路由：背景与 Hero 共用 [transitionDuration]，几何转场由 Hero 完成。
class MediaPreviewOverlayRoute<T> extends PageRoute<T>
    with IosBackGestureRouteMixin<T> {
  MediaPreviewOverlayRoute({
    required this.pageBuilder,
    super.settings,
    this.opaque = false,
    this.barrierColor,
    this.enableGestureBack = true,
    this.transitionDuration = mediaPreviewBackdropDuration,
    this.reverseTransitionDuration = mediaPreviewBackdropDuration,
  });

  final RoutePageBuilder pageBuilder;

  @override
  final bool opaque;

  final bool enableGestureBack;

  @override
  final Duration transitionDuration;

  @override
  final Duration reverseTransitionDuration;

  @override
  String? get barrierLabel =>
      barrierColor == null ? null : 'Dismiss media preview';

  @override
  bool get maintainState => true;

  @override
  final Color? barrierColor;

  @override
  Widget buildPage(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
  ) {
    return pageBuilder(context, animation, secondaryAnimation);
  }

  @override
  Widget buildTransitions(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    // 入场不整页淡入：黑底由页内 scrim 跟 Hero 一起出现，避免和飞行层抢透明度。
    // 退场仍淡出整页，否则 pop 后黑底会停一拍。
    final fadingOut = animation.status == AnimationStatus.reverse ||
        animation.status == AnimationStatus.dismissed;
    final page = fadingOut
        ? FadeTransition(
            opacity: CurvedAnimation(
              parent: animation,
              curve: mediaPreviewBackdropCurve,
              reverseCurve: mediaPreviewBackdropReverseCurve,
            ),
            child: child,
          )
        : child;
    if (!enableGestureBack) {
      return page;
    }
    return wrapWithIosBackGesture(page);
  }
}
