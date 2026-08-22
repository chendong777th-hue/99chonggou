import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:tencent_cloud_chat_uikit/ui/utils/ios_back_gesture.dart';

import 'full_screen_back_route.dart';
import 'route_visibility_host.dart';

abstract class AppRoutes {
  static const chat = 'chat';
  static const groupProfile = 'groupProfile';
  static const c2cChatSettings = 'c2c_chat_settings';
  static const search = 'search';
  static const searchInConversation = 'search_in_conversation';
  static const searchAllFriends = 'search_all_friends';
  static const searchAllGroups = 'search_all_groups';
  static const walletOverlay = 'wallet_overlay';
  /// 通讯录 →「我的群聊」列表页。
  static const myGroupList = 'myGroupList';
}

class AppPageTransitionsBuilder extends PageTransitionsBuilder {
  const AppPageTransitionsBuilder();

  static const _cupertino = CupertinoPageTransitionsBuilder();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    final page = _cupertino.buildTransitions<T>(
      route,
      context,
      animation,
      secondaryAnimation,
      child,
    );
    // 全屏返回路由自带手势；仅模态等 IosBackGestureRoute 再挂边缘手势。
    if (route is FullScreenBackPageRoute) {
      return page;
    }
    if (route is IosBackGestureRoute) {
      return (route as IosBackGestureRoute).wrapWithIosBackGesture(page);
    }
    return page;
  }
}

/// 模态全屏页：无全屏侧滑返回。
class AppFullscreenDialogRoute<T> extends PageRoute<T>
    with CupertinoRouteTransitionMixin<T>, IosBackGestureRouteMixin<T> {
  AppFullscreenDialogRoute({
    required this.builder,
    super.settings,
    super.allowSnapshotting = false,
    this.maintainState = true,
  }) : super(fullscreenDialog: true);

  final WidgetBuilder builder;

  @override
  final bool maintainState;

  @override
  Widget buildContent(BuildContext context) {
    return RouteVisibilityHost(
      child: RepaintBoundary(child: builder(context)),
    );
  }

  @override
  String? get title => null;

  @override
  Duration get transitionDuration => const Duration(milliseconds: 300);

  @override
  Duration get reverseTransitionDuration => const Duration(milliseconds: 300);

  @override
  bool get popGestureEnabled => false;

  @override
  Widget buildTransitions(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    return const AppPageTransitionsBuilder().buildTransitions<T>(
      this,
      context,
      animation,
      secondaryAnimation,
      child,
    );
  }
}

/// 默认页面路由：Android / iOS 全屏右滑返回。
class AppMaterialPageRoute<T> extends FullScreenBackPageRoute<T> {
  AppMaterialPageRoute({
    required WidgetBuilder builder,
    RouteSettings? settings,
    bool maintainState = true,
    bool? allowSnapshotting,
    bool enableFullScreenBackGesture = true,
    double edgeStartWidthPx = 24.0,
    int routeVisibilityDeferredFrames = 1,
    Duration transitionDuration = const Duration(milliseconds: 300),
  }) : super(
          settings: settings,
          maintainState: maintainState,
          allowSnapshotting: allowSnapshotting ?? !kIsWeb,
          enableFullScreenBackGesture: enableFullScreenBackGesture,
          edgeStartWidthPx: edgeStartWidthPx,
          transitionDuration: transitionDuration,
          reverseTransitionDuration: transitionDuration,
          builder: (context) => RouteVisibilityHost(
            deferredFrameCount: routeVisibilityDeferredFrames,
            child: builder(context),
          ),
        );
}

extension AppNavigation on BuildContext {
  Future<T?> pushAppPage<T>(Widget page, {RouteSettings? settings}) {
    return Navigator.of(this).push<T>(
      AppMaterialPageRoute<T>(
        settings: settings,
        builder: (_) => page,
      ),
    );
  }
}
