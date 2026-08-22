import 'package:flutter/foundation.dart';
import 'package:tencent_cloud_chat_demo/src/create_group.dart';
import 'package:tencent_cloud_chat_demo/src/pages/cross_platform/wide_screen/desktop_profile_host.dart';

/// Web / 桌面：发起群聊选人嵌在主壳右侧，左侧继续显示导航 + 会话列表。
enum DesktopCreateGroupScope { c2c, group }

class DesktopCreateGroupArgs {
  const DesktopCreateGroupArgs({
    required this.scope,
    this.convType = GroupTypeForUIKit.community,
    this.initialSelectedUserIds,
    this.selectGroupTypeAfterMembers = false,
  });

  final DesktopCreateGroupScope scope;
  final GroupTypeForUIKit convType;
  final List<String>? initialSelectedUserIds;
  final bool selectGroupTypeAfterMembers;
}

class DesktopCreateGroupHost {
  DesktopCreateGroupHost._();

  static final ValueNotifier<DesktopCreateGroupArgs?> argsNotifier =
      ValueNotifier<DesktopCreateGroupArgs?>(null);

  static VoidCallback? requestShowMessagesTab;
  static VoidCallback? requestShowGroupTab;

  /// 打开前关闭归档 / 群通知等其它右侧面板。
  static VoidCallback? requestClosePeerPanels;

  static bool get isOpen => argsNotifier.value != null;

  static DesktopCreateGroupArgs? get args => argsNotifier.value;

  static void open({
    required DesktopCreateGroupScope scope,
    GroupTypeForUIKit convType = GroupTypeForUIKit.community,
    List<String>? initialSelectedUserIds,
    bool selectGroupTypeAfterMembers = false,
  }) {
    DesktopProfileHost.close();
    requestClosePeerPanels?.call();
    argsNotifier.value = DesktopCreateGroupArgs(
      scope: scope,
      convType: convType,
      initialSelectedUserIds: initialSelectedUserIds,
      selectGroupTypeAfterMembers: selectGroupTypeAfterMembers,
    );
    if (scope == DesktopCreateGroupScope.group) {
      requestShowGroupTab?.call();
    } else {
      requestShowMessagesTab?.call();
    }
  }

  static void close() {
    if (argsNotifier.value == null) {
      return;
    }
    argsNotifier.value = null;
  }
}
