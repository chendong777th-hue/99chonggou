import 'package:flutter/foundation.dart';
import 'package:tencent_cloud_chat_demo/src/pages/cross_platform/wide_screen/desktop_profile_host.dart';

/// Web / 桌面：归档列表嵌在主壳右侧，左侧继续显示导航 + 会话列表。
enum DesktopArchiveScope { c2c, group }

class DesktopArchiveHost {
  DesktopArchiveHost._();

  static final ValueNotifier<DesktopArchiveScope?> scopeNotifier =
      ValueNotifier<DesktopArchiveScope?>(null);

  /// 由 [HomePageWideScreen] 注册：切到对应 Tab。
  static VoidCallback? requestShowMessagesTab;
  static VoidCallback? requestShowGroupTab;

  /// 打开归档前关闭其它右侧面板（如群通知）。
  static VoidCallback? requestClosePeerPanels;

  static bool get isOpen => scopeNotifier.value != null;

  static DesktopArchiveScope? get scope => scopeNotifier.value;

  static void open(DesktopArchiveScope scope) {
    DesktopProfileHost.close();
    requestClosePeerPanels?.call();
    scopeNotifier.value = scope;
    if (scope == DesktopArchiveScope.group) {
      requestShowGroupTab?.call();
    } else {
      requestShowMessagesTab?.call();
    }
  }

  static void close() {
    if (scopeNotifier.value == null) {
      return;
    }
    scopeNotifier.value = null;
  }
}
