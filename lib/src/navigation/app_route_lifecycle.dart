import 'package:flutter/material.dart';
import 'package:tencent_cloud_chat_demo/src/navigation/orphan_overlay_guard.dart';

/// 路由生命周期：pop 后 post-frame 清理可能泄漏的全局 Overlay。
class AppRouteLifecycleObserver extends NavigatorObserver {
  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPop(route, previousRoute);
    OrphanOverlayGuard.scheduleCleanup(
      reason: 'route_pop_${route.settings.name ?? route.runtimeType}',
    );
  }
}

bool isCurrentRoute(BuildContext context) {
  final route = ModalRoute.of(context);
  if (route == null) return true;
  return route.isCurrent && route.isActive;
}

/// 栈顶 active 路由：重页面（Chat/会话列表）据此控制 [TickerMode]。
///
/// 只要路由仍在栈内且 [ModalRoute.isActive]，就保持绘制/Ticker 开启。
/// 此前在「active 但被聊天页盖住」时返回 false，pop 后 TickerMode 重开会话列表头像闪一下；
/// 半透明媒体/钱包/选图叠层同理，由 isActive 覆盖，无需再单独判断叠层 flag。
bool routeAcceptsUserInput(BuildContext context) {
  final route = ModalRoute.of(context);
  if (route == null) {
    return true;
  }
  return route.isActive;
}
