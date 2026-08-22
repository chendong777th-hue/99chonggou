import 'package:tencent_cloud_chat_sdk/models/v2_tim_conversation.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_conversation.dart';
import 'package:tencent_cloud_chat_uikit/business_logic/view_models/tui_chat_global_model.dart';

/// 控制聊天页「x条未读 / 新消息」提示条是否启用。
///
/// - [entryUnreadTongueEnabled]：进入会话时的大量未读提示
/// - 单聊/群聊：上滑查看历史时收到当前会话新消息，仍显示「x条新消息」
class UnreadTonguePolicy {
  UnreadTonguePolicy._();

  /// 进入会话时「xxx条未读」入口提示。
  /// 暂时关闭：远历史按 seq 定位仍未稳定，先不展示入口未读条与跳转。
  static const bool entryUnreadTongueEnabled = false;

  /// 入口提示最少未读数（群/单聊共用）。
  static const int entryMinUnreadCount = 15;

  /// 兼容旧名。
  static const int groupMinUnreadCount = entryMinUnreadCount;

  static bool isGroupConversation(V2TimConversation conversation) {
    return conversation.type != 1;
  }

  static bool isEnabled(V2TimConversation conversation, int unreadCount) {
    return unreadCount >= entryMinUnreadCount;
  }

  static bool isEnabledForConvType(ConvType convType, int unreadCount) {
    return unreadCount >= entryMinUnreadCount;
  }

  static bool isEntryUnreadEnabled(
    V2TimConversation conversation,
    int unreadCount,
  ) {
    if (!entryUnreadTongueEnabled) {
      return false;
    }
    return isEnabled(conversation, unreadCount);
  }

  static bool isEntryUnreadEnabledForConvType(
    ConvType convType,
    int unreadCount,
  ) {
    if (!entryUnreadTongueEnabled) {
      return false;
    }
    return isEnabledForConvType(convType, unreadCount);
  }

  /// 上滑查看历史时，当前会话收到的新消息提示（单聊/群聊均启用）。
  static bool isLiveNewMessageTongueEnabled({required int unreadCount}) {
    return unreadCount > 0;
  }
}
