import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tencent_cloud_chat_uikit/business_logic/view_models/chat_ui_state_store.dart';
import 'package:tencent_cloud_chat_uikit/business_logic/view_models/tui_chat_global_model.dart';
import 'package:tencent_cloud_chat_uikit/data_services/services_locatar.dart';
import 'package:tencent_cloud_chat_uikit/ui/utils/media_preview_overlay_route.dart';
import 'package:tencent_cloud_chat_uikit/ui/utils/media_preview_video_utils.dart';
import 'package:tencent_cloud_chat_uikit/ui/utils/platform.dart';

const double _hiddenPreviewHeroOpacity = 0.001;

/// 预览入场动画结束后锁定遮罩/工具栏为全不透明，避免半透明黑底叠聊天页灰背景发灰。
class MediaPreviewEntranceLatch {
  MediaPreviewEntranceLatch({required this.onSettled});

  final VoidCallback onSettled;

  bool settled = false;
  bool _bound = false;
  bool _disposed = false;
  bool _onSettledScheduled = false;
  Animation<double>? _animation;
  AnimationStatusListener? _statusListener;
  Timer? _fallbackTimer;

  void bind(Animation<double> animation, {Duration? routeDuration}) {
    if (_disposed || settled || _bound) {
      return;
    }
    _bound = true;
    _animation = animation;
    final instant = routeDuration == Duration.zero ||
        animation.status == AnimationStatus.completed ||
        animation.value >= 0.999;
    if (instant) {
      _markSettled(deferCallback: true);
      return;
    }
    void onStatus(AnimationStatus status) {
      if (status != AnimationStatus.completed) {
        return;
      }
      animation.removeStatusListener(onStatus);
      _statusListener = null;
      _markSettled();
    }

    _statusListener = onStatus;
    animation.addStatusListener(onStatus);
    _fallbackTimer?.cancel();
    _fallbackTimer = Timer(
      mediaPreviewBackdropDuration + const Duration(milliseconds: 80),
      _markSettled,
    );
  }

  void _markSettled({bool deferCallback = false}) {
    _fallbackTimer?.cancel();
    _fallbackTimer = null;
    if (settled) {
      return;
    }
    settled = true;
    if (deferCallback) {
      if (_onSettledScheduled) {
        return;
      }
      _onSettledScheduled = true;
      scheduleMicrotask(() {
        if (_disposed) {
          return;
        }
        onSettled();
      });
      return;
    }
    onSettled();
  }

  void dispose() {
    _disposed = true;
    _fallbackTimer?.cancel();
    _fallbackTimer = null;
    final animation = _animation;
    final listener = _statusListener;
    if (animation != null && listener != null) {
      animation.removeStatusListener(listener);
    }
    _statusListener = null;
    _animation = null;
  }

  double scrimOpacity(
      Animation<double> routeAnimation, double backdropOpacity) {
    final slide = backdropOpacity.clamp(0.0, 1.0);
    if (settled) {
      return slide;
    }
    return (routeAnimation.value.clamp(0.0, 1.0) * slide).clamp(0.0, 1.0);
  }

  Animation<double> chromeOpacity(Animation<double> routeAnimation) {
    return settled
        ? const AlwaysStoppedAnimation<double>(1.0)
        : CurvedAnimation(
            parent: routeAnimation,
            curve: const Interval(0.4, 1.0, curve: Curves.easeOutCubic),
          );
  }
}

/// 预览打开/关闭时隐藏聊天气泡等处 Hero 源图，避免与飞行层叠影闪烁。
class MediaPreviewHeroRegistry extends ChangeNotifier {
  MediaPreviewHeroRegistry._();

  static final MediaPreviewHeroRegistry instance = MediaPreviewHeroRegistry._();

  final Set<Object> _hiddenTags = <Object>{};
  final Set<Object> _liveTargetTags = <Object>{};

  bool isHidden(Object tag) => _hiddenTags.contains(tag);

  /// [PreviewHero] mount 期间为 true；离屏未构建时为 false，用于关闭 Hero 降级。
  bool isTargetLive(Object tag) => _liveTargetTags.contains(tag);

  void markTargetLive(Object tag) {
    _liveTargetTags.add(tag);
  }

  void markTargetDead(Object tag) {
    _liveTargetTags.remove(tag);
  }

  void hide(Object tag) {
    if (_hiddenTags.add(tag)) {
      notifyListeners();
    }
  }

  void show(Object tag) {
    if (_hiddenTags.remove(tag)) {
      notifyListeners();
    }
  }

  void showAll(Iterable<Object> tags) {
    var changed = false;
    for (final tag in tags) {
      if (_hiddenTags.remove(tag)) {
        changed = true;
      }
    }
    if (changed) {
      notifyListeners();
    }
  }

  /// 恢复指定 tag 的源图可见；仅当确有 tag 从隐藏态恢复时才通知，避免无关 [PreviewHero] 重建。
  void revealAll(Iterable<Object> tags) {
    final pending = tags.where((tag) => tag.toString().isNotEmpty).toSet();
    if (pending.isEmpty) {
      return;
    }
    var changed = false;
    for (final tag in pending) {
      if (_hiddenTags.remove(tag)) {
        changed = true;
      }
    }
    if (changed) {
      notifyListeners();
    }
  }

  /// 预览完全结束后恢复所有仍被隐藏的源图（图集等多图场景）。
  void revealAllHidden() {
    if (_hiddenTags.isEmpty) {
      return;
    }
    _hiddenTags.clear();
    notifyListeners();
  }

  /// Hero 飞回动画结束后再显示源图，避免关闭预览时气泡闪一下。
  void scheduleRevealAll(
    Iterable<Object> tags, {
    Duration delay = mediaPreviewHeroFlightDuration,
  }) {
    final pending = tags.where((tag) => tag.toString().isNotEmpty).toSet();
    if (pending.isEmpty) {
      return;
    }
    Future<void>.delayed(delay, () {
      revealAll(pending);
    });
  }
}

/// 包裹 [Hero]：预览期间将源图透明（保留占位），对应 Telegram hidden media。
class PreviewHero extends StatefulWidget {
  const PreviewHero({
    super.key,
    required this.tag,
    required this.child,
    this.placeholderBuilder,
  });

  final Object tag;
  final Widget child;
  final HeroPlaceholderBuilder? placeholderBuilder;

  @override
  State<PreviewHero> createState() => _PreviewHeroState();
}

class _PreviewHeroState extends State<PreviewHero> {
  late bool _hidden;

  @override
  void initState() {
    super.initState();
    MediaPreviewHeroRegistry.instance.markTargetLive(widget.tag);
    _hidden = MediaPreviewHeroRegistry.instance.isHidden(widget.tag);
    MediaPreviewHeroRegistry.instance.addListener(_onRegistryChanged);
  }

  void _onRegistryChanged() {
    final nextHidden = MediaPreviewHeroRegistry.instance.isHidden(widget.tag);
    if (nextHidden == _hidden) {
      return;
    }
    setState(() => _hidden = nextHidden);
  }

  @override
  void didUpdateWidget(PreviewHero oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.tag != widget.tag) {
      MediaPreviewHeroRegistry.instance.markTargetDead(oldWidget.tag);
      MediaPreviewHeroRegistry.instance.markTargetLive(widget.tag);
      final nextHidden = MediaPreviewHeroRegistry.instance.isHidden(widget.tag);
      if (nextHidden != _hidden) {
        _hidden = nextHidden;
      }
    }
  }

  @override
  void dispose() {
    MediaPreviewHeroRegistry.instance.removeListener(_onRegistryChanged);
    MediaPreviewHeroRegistry.instance.markTargetDead(widget.tag);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Hero(
      tag: widget.tag,
      placeholderBuilder: widget.placeholderBuilder == null
          ? null
          : (context, size, child) =>
              widget.placeholderBuilder!(context, size, widget.child),
      child: Opacity(
        // Keep the source media painted while hidden. A true 0 opacity can skip
        // painting and force an image repaint when returning from gallery item B.
        opacity: _hidden ? _hiddenPreviewHeroOpacity : 1.0,
        child: widget.child,
      ),
    );
  }
}

/// 预览页工具栏淡入淡出（由 [MediaPreviewChromeScope] 提供）。
class MediaPreviewChromeScope extends InheritedWidget {
  const MediaPreviewChromeScope({
    required this.animation,
    required super.child,
    super.key,
  });

  final Animation<double> animation;

  static Animation<double> of(BuildContext context) {
    final scope =
        context.dependOnInheritedWidgetOfExactType<MediaPreviewChromeScope>();
    return scope?.animation ?? const AlwaysStoppedAnimation<double>(1.0);
  }

  @override
  bool updateShouldNotify(MediaPreviewChromeScope oldWidget) {
    return animation != oldWidget.animation;
  }
}

/// 读取媒体预览工具栏淡入淡出动画。
Animation<double> mediaPreviewChromeAnimation(BuildContext context) {
  return MediaPreviewChromeScope.of(context);
}

/// 打开全屏图片/视频预览（Overlay 路由 + 统一背景动画）。
/// [opaque] 为 false 时下滑可透出下层聊天页。
///
/// [restoreChatScrollConversationID]：打开前若调用过
/// [TUIChatGlobalModel.saveScrollBeforeMediaPreview]，关闭后由此处**必定**
/// 触发 [TUIChatGlobalModel.restoreScrollAfterMediaPreview]，不依赖气泡
/// State 是否仍 mounted（列表回收会导致 elem dispose，从而永久锁滚动）。
Future<T?> pushMediaPreview<T>({
  required BuildContext context,
  required Widget child,
  bool opaque = false,
  bool requiresOpaquePlatformView = false,
  bool enableGestureBack = true,
  Duration? transitionDuration,
  Duration? reverseTransitionDuration,
  RouteSettings? settings,
  String? restoreChatScrollConversationID,
}) async {
  final restoreConvId = restoreChatScrollConversationID?.trim() ?? '';
  if (!context.mounted) {
    if (restoreConvId.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        serviceLocator<TUIChatGlobalModel>()
            .restoreScrollAfterMediaPreview(restoreConvId);
      });
    }
    return null;
  }
  unawaited(applySystemUiForMediaPreview());
  unawaited(warmUpMediaPreviewAudioSession());
  final forceOpaqueCover =
      opaque || (PlatformUtils().isIOS && requiresOpaquePlatformView);
  try {
    final navigator = Navigator.of(context, rootNavigator: true);
    return await navigator.push<T>(
      MediaPreviewOverlayRoute<T>(
        // iOS UiKitView 会在 Flutter 纹理上打洞。barrier 为 null 时洞里能看到
        // 底下聊天页：声音在播、画面发灰、会话还隐约在。必须不透明黑底盖住。
        opaque: forceOpaqueCover,
        barrierColor: forceOpaqueCover ? Colors.black : null,
        enableGestureBack: enableGestureBack,
        transitionDuration: transitionDuration ?? mediaPreviewBackdropDuration,
        reverseTransitionDuration:
            reverseTransitionDuration ?? mediaPreviewBackdropDuration,
        settings: settings,
        pageBuilder: (context, animation, secondaryAnimation) {
          final duration = transitionDuration ?? mediaPreviewBackdropDuration;
          // 零时长入场：CurvedAnimation 可能停在 dismissed/中间值，遮罩半透明、
          // 工具栏 Interval 不出现。直接锁在 1，让首帧就是全黑预览底。
          final Animation<double> curved = duration == Duration.zero
              ? const AlwaysStoppedAnimation<double>(1.0)
              : CurvedAnimation(
                  parent: animation,
                  curve: mediaPreviewBackdropCurve,
                  reverseCurve: mediaPreviewBackdropReverseCurve,
                );
          // 预览路由不在聊天页 Provider 子树内；补齐全局 store，并强制
          // TickerMode，避免视频/图片在无 ticker 时永久灰块占位。
          Widget page = MediaPreviewChromeScope(
            animation: curved,
            child: TickerMode(
              enabled: true,
              child: MultiProvider(
                providers: [
                  ChangeNotifierProvider<TUIChatGlobalModel>.value(
                    value: serviceLocator<TUIChatGlobalModel>(),
                  ),
                  ChangeNotifierProvider<ChatUiStateStore>.value(
                    value: serviceLocator<ChatUiStateStore>(),
                  ),
                ],
                child: child,
              ),
            ),
          );
          if (forceOpaqueCover) {
            page = ColoredBox(color: Colors.black, child: page);
          }
          return page;
        },
      ),
    );
  } finally {
    unawaited(restoreSystemUiAfterMediaPreview());
    if (restoreConvId.isNotEmpty) {
      // pop 完成后下一帧恢复；不读调用方 State.mounted。
      WidgetsBinding.instance.addPostFrameCallback((_) {
        serviceLocator<TUIChatGlobalModel>()
            .restoreScrollAfterMediaPreview(restoreConvId);
      });
    }
  }
}

/// Hero 飞行动画时长（与 [MediaPreviewOverlayRoute.transitionDuration] 一致）。
const Duration mediaPreviewHeroFlightDuration = mediaPreviewBackdropDuration;

Duration mediaPreviewCloseWaitDuration() {
  final transitionMs = mediaPreviewBackdropDuration.inMilliseconds;
  final heroMs = mediaPreviewHeroFlightDuration.inMilliseconds;
  return Duration(milliseconds: transitionMs > heroMs ? transitionMs : heroMs);
}
