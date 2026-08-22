import 'package:flutter/foundation.dart';
import 'package:tencent_cloud_chat_demo/src/services/im_web_ready_guard.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_conversation.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_conversation.dart';
import 'package:tencent_cloud_chat_sdk/tencent_im_sdk_plugin.dart';

class WebReadService {
  WebReadService._();

  static final WebReadService instance = WebReadService._();

  Future<void> markConversationRead(V2TimConversation conversation) async {
    if (!kIsWeb) {
      return;
    }
    final conversationID = _conversationID(conversation);
    if (conversationID.isEmpty || !conversationID.toLowerCase().startsWith('c2c')) {
      return;
    }
    final ready = await ImWebReadyGuard.instance.wait();
    if (!ready) {
      return;
    }
    try {
      await TencentImSDKPlugin.v2TIMManager
          .getConversationManager()
          .cleanConversationUnreadMessageCount(
            conversationID: conversationID,
            cleanTimestamp: 0,
            cleanSequence: 0,
          );
    } catch (e) {
      if (kDebugMode) {
        debugPrint('WebReadService: mark read ignored on web: $e');
      }
    }
  }

  String _conversationID(V2TimConversation conversation) {
    final fromConv = conversation.conversationID.trim();
    if (fromConv.isNotEmpty) {
      return fromConv;
    }
    final groupID = conversation.groupID?.trim() ?? '';
    if (groupID.isNotEmpty) {
      return 'group_$groupID';
    }
    final userID = conversation.userID?.trim() ?? '';
    if (userID.isNotEmpty) {
      return 'c2c_$userID';
    }
    return '';
  }
}
