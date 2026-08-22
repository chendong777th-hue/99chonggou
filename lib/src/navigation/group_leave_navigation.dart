import 'package:flutter/material.dart';
import 'package:tencent_cloud_chat_demo/src/navigation/app_page_transitions.dart';
import 'package:tencent_cloud_chat_demo/src/widgets/message_notification_banner.dart';
import 'package:tencent_cloud_chat_uikit/ui/utils/platform.dart';

/// 退群 / 解散后的返回目标：
/// - 若栈里有「我的群聊」列表（通讯录入口），回到该页；
/// - 否则回到消息首页。
class GroupLeaveNavigation {
  GroupLeaveNavigation._();

  @visibleForTesting
  static bool isMessageListRoute(Route<dynamic> route) {
    final name = route.settings.name?.trim() ?? '';
    if (name == '/homePage') {
      return true;
    }
    return route.isFirst;
  }

  @visibleForTesting
  static bool isMyGroupListRoute(Route<dynamic> route) {
    return route.settings.name == AppRoutes.myGroupList;
  }

  /// popUntil 谓词：优先停在我的群聊，否则消息列表。
  @visibleForTesting
  static bool isLeaveReturnTarget(Route<dynamic> route) {
    return isMyGroupListRoute(route) || isMessageListRoute(route);
  }

  static Future<void> returnToMessageList([BuildContext? context]) async {
    final rootNav = AppNavigator.key.currentState;
    if (rootNav != null) {
      rootNav.popUntil(isLeaveReturnTarget);
      return;
    }
    if (context == null || !context.mounted) {
      return;
    }
    final navigator = Navigator.of(context, rootNavigator: true);
    if (PlatformUtils().isWeb) {
      var safety = 8;
      while (navigator.canPop() && safety-- > 0) {
        final current = ModalRoute.of(context);
        if (current != null && isLeaveReturnTarget(current)) {
          break;
        }
        navigator.pop();
      }
      return;
    }
    navigator.popUntil(isLeaveReturnTarget);
  }
}
