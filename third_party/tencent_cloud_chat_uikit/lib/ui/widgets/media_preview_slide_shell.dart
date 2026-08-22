import 'package:extended_image/extended_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:tencent_cloud_chat_uikit/ui/utils/media_preview_presenter.dart';
import 'package:tencent_cloud_chat_uikit/ui/utils/media_preview_video_utils.dart';
import 'package:tencent_cloud_chat_uikit/ui/utils/platform.dart';
import 'package:tencent_cloud_chat_uikit/ui/widgets/media_preview_edge_back_layer.dart';
import 'package:tencent_cloud_chat_uikit/ui/widgets/media_preview_slide_metrics.dart';

typedef MediaPreviewSlideEndHandler = bool? Function(
  Offset offset, {
  ExtendedImageSlidePageState? state,
  ScaleEndDetails? details,
});

class MediaPreviewSlideShell extends StatelessWidget {
  const MediaPreviewSlideShell({
    super.key,
    required this.slidePageKey,
    required this.slideMetrics,
    required this.entranceLatch,
    required this.onSlidingPage,
    required this.slideEndHandler,
    required this.bodyBuilder,
    required this.chromeBuilder,
    required this.onClose,
    required this.opaquePlatformBackdrop,
    this.enableEdgeBack = true,
    this.slideType = SlideType.onlyImage,
    this.overlayChildren = const [],
  });

  final GlobalKey<ExtendedImageSlidePageState> slidePageKey;
  final MediaPreviewSlideMetrics slideMetrics;
  final MediaPreviewEntranceLatch entranceLatch;
  final OnSlidingPage onSlidingPage;
  final MediaPreviewSlideEndHandler slideEndHandler;
  final Widget Function(BuildContext context, Orientation orientation)
      bodyBuilder;
  final Widget Function(Animation<double> routeAnimation) chromeBuilder;
  final VoidCallback onClose;
  final bool opaquePlatformBackdrop;
  final bool enableEdgeBack;
  final SlideType slideType;
  final List<Widget> overlayChildren;

  @override
  Widget build(BuildContext context) {
    final chromeAnimation = mediaPreviewChromeAnimation(context);
    entranceLatch.bind(
      chromeAnimation,
      routeDuration: ModalRoute.of(context)?.transitionDuration,
    );
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (bool didPop, Object? result) {
        if (didPop) {
          return;
        }
        onClose();
      },
      child: AnnotatedRegion<SystemUiOverlayStyle>(
        value: mediaPreviewVideoOverlayStyle,
        child: Material(
          // iOS 预览里有 UiKitView：祖先必须不透明，否则平台层合成失败，
          // 只剩半透明罩 + 后台声音，聊天页透出来。
          color: PlatformUtils().isIOS && opaquePlatformBackdrop
              ? Colors.black
              : Colors.transparent,
          child: Container(
            color: PlatformUtils().isIOS && opaquePlatformBackdrop
                ? Colors.black
                : Colors.transparent,
            width: MediaQuery.sizeOf(context).width,
            height: MediaQuery.sizeOf(context).height,
            child: OrientationBuilder(
              builder: (context, orientation) {
                return Stack(
                  alignment: Alignment.center,
                  children: [
                    _buildScrimBackdrop(chromeAnimation),
                    Positioned.fill(
                      child: ListenableBuilder(
                        listenable: slideMetrics,
                        builder: (context, _) {
                          // onlyImage：缩放由图片/长图本体消费（跟手中心）；
                          // wholePage（视频）：整页缩放仍挂在外壳。
                          Widget slidePage = ExtendedImageSlidePage(
                            key: slidePageKey,
                            slideAxis: SlideAxis.vertical,
                            slidePageBackgroundHandler:
                                mediaPreviewSlideBackgroundHandler,
                            slideScaleHandler: mediaPreviewSlideScaleHandler,
                            onSlidingPage: onSlidingPage,
                            slideType: slideType,
                            resetPageDuration: mediaPreviewSlideResetDuration,
                            slideEndHandler: slideEndHandler,
                            child: bodyBuilder(context, orientation),
                          );
                          // 静止时不要套 Transform/Opacity：iOS 上 UiKitView 一旦进
                          // saveLayer，就会只出声不出画，底下聊天页透出来发灰。
                          final scale = slideMetrics.contentScale;
                          final opacity =
                              slideMetrics.contentOpacity.clamp(0.0, 1.0);
                          if (slideType == SlideType.wholePage &&
                              (scale - 1.0).abs() > 0.001) {
                            slidePage = Transform.scale(
                              scale: scale,
                              child: slidePage,
                            );
                          }
                          Widget painted = ColoredBox(
                            color: Colors.black,
                            child: MediaPreviewSlideVisualScope(
                              metrics: slideMetrics,
                              child: slidePage,
                            ),
                          );
                          if (opacity < 0.999) {
                            painted = Opacity(opacity: opacity, child: painted);
                          }
                          return painted;
                        },
                      ),
                    ),
                    Positioned.fill(
                      child: chromeBuilder(chromeAnimation),
                    ),
                    if (enableEdgeBack)
                      MediaPreviewEdgeBackLayer(onBack: onClose),
                    ...overlayChildren,
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildScrimBackdrop(Animation<double> routeAnimation) {
    return Positioned.fill(
      child: ListenableBuilder(
        listenable: slideMetrics,
        builder: (context, _) {
          // iOS 静止时必须实心黑。半透明黑叠聊天页 = 灰罩还能看到气泡。
          final opacity = PlatformUtils().isIOS &&
                  opaquePlatformBackdrop &&
                  slideMetrics.slideOffset.distance < 0.5
              ? 1.0
              : entranceLatch.scrimOpacity(
                  routeAnimation,
                  slideMetrics.backdropOpacity,
                );
          // 必须可命中：IgnorePointer 会让 onlyImage 下滑时空白区域穿透到下层
          // 聊天列表，表现为「关预览时会话记录被拖动」。
          return ColoredBox(
            color: Colors.black.withValues(alpha: opacity),
          );
        },
      ),
    );
  }
}
