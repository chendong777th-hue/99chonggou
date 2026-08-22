import 'package:flutter/foundation.dart';
import 'package:tencent_cloud_chat_demo/src/services/active_chat_registry.dart';

/// 判断会话是否仍在聊天栈内，用于抑制列表未读 bump。
class ForegroundChatGuard {
  ForegroundChatGuard._();

  @visibleForTesting
  static bool Function(String? conversationId)? debugOverride;

  static bool isActiveConversation(String? conversationId) {
    final override = debugOverride;
    if (override != null) {
      return override(conversationId);
    }
    final id = conversationId?.trim() ?? '';
    if (id.isEmpty) {
      return false;
    }
    // 栈内仍打开（含被资料/代理页盖住、routeVisible=false）则压本会话未读；
    // 只有 ActiveChatRegistry.leave 之后才允许列表 bump。
    return ActiveChatRegistry.instance.matchesOpenConversation(id);
  }
}
