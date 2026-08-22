import 'package:flutter/material.dart';

/// 全局路由可见性观察（用于转场时暂停底层重页面绘制）。
final RouteObserver<PageRoute<dynamic>> appRouteObserver =
    RouteObserver<PageRoute<dynamic>>();

/// 标记当前路由是否处于栈顶；转场时底层页面可跳过重型 build。
class RouteVisibility extends InheritedWidget {
  final bool isVisible;

  const RouteVisibility({
    super.key,
    required this.isVisible,
    required super.child,
  });

  static bool isRouteVisible(BuildContext context) {
    return context
            .dependOnInheritedWidgetOfExactType<RouteVisibility>()
            ?.isVisible ??
        true;
  }

  /// 等路由转场结束（[isVisible] 变为 true）后再执行 [task]。
  static void scheduleWhenVisible(BuildContext context, VoidCallback task) {
    if (isRouteVisible(context)) {
      task();
      return;
    }
    void waitForVisible() {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!context.mounted) {
          return;
        }
        if (isRouteVisible(context)) {
          task();
        } else {
          waitForVisible();
        }
      });
    }
    waitForVisible();
  }

  @override
  bool updateShouldNotify(RouteVisibility oldWidget) {
    return isVisible != oldWidget.isVisible;
  }
}
