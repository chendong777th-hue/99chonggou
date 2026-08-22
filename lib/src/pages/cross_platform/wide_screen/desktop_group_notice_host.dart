import 'package:flutter/foundation.dart';
import 'package:tencent_cloud_chat_demo/src/pages/cross_platform/wide_screen/desktop_profile_host.dart';

/// Web / 桌面：群通知嵌在主壳右侧，左侧继续显示导航 + 群列表（对标资料侧栏）。
class DesktopGroupNoticeHost {
  DesktopGroupNoticeHost._();

  static final ValueNotifier<bool> openNotifier = ValueNotifier<bool>(false);

  /// 由 [HomePageWideScreen] 注册：切到「群聊」Tab，保证左侧是群会话列表。
  static VoidCallback? requestShowGroupTab;

  /// 打开群通知前关闭其它右侧面板（如归档）。
  static VoidCallback? requestClosePeerPanels;

  static bool get isOpen => openNotifier.value;

  static void open() {
    DesktopProfileHost.close();
    requestClosePeerPanels?.call();
    if (!openNotifier.value) {
      openNotifier.value = true;
    }
    requestShowGroupTab?.call();
  }

  static void close() {
    if (!openNotifier.value) {
      return;
    }
    openNotifier.value = false;
  }
}
