import 'package:flutter/foundation.dart';
import 'package:tencent_cloud_chat_demo/utils/chat_id_format.dart';

/// Web / 桌面：在主壳内打开用户资料，左侧继续显示导航 + 会话列表（对标 Telegram）。
class DesktopProfileHost {
  DesktopProfileHost._();

  static final ValueNotifier<String?> userIdNotifier = ValueNotifier<String?>(null);
  static final ValueNotifier<String?> groupIdNotifier = ValueNotifier<String?>(null);

  /// 由 [HomePageWideScreen] 注册：切到「消息」Tab，保证左侧是会话列表。
  static VoidCallback? requestShowMessagesTab;

  /// 打开资料前关闭其它右侧面板（如群通知），由 Home 注册。
  static VoidCallback? requestClosePeerPanels;

  static String? get userId => userIdNotifier.value;

  static String? get groupId => groupIdNotifier.value;

  static bool get isOpen {
    final id = userIdNotifier.value?.trim() ?? '';
    return id.isNotEmpty;
  }

  static void open(String userId, {String? groupId}) {
    final id = ChatIdFormat.rawUserUid(userId);
    if (id.isEmpty) {
      return;
    }
    requestClosePeerPanels?.call();
    final gid = groupId?.trim() ?? '';
    groupIdNotifier.value = gid.isEmpty ? null : gid;
    userIdNotifier.value = id;
    requestShowMessagesTab?.call();
  }

  static void close() {
    if (userIdNotifier.value == null && groupIdNotifier.value == null) {
      return;
    }
    userIdNotifier.value = null;
    groupIdNotifier.value = null;
  }
}
