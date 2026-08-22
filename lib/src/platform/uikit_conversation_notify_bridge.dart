import 'package:tencent_cloud_chat_demo/src/services/conversation_notify_sync_service.dart';
import 'package:tencent_cloud_chat_uikit/data_services/message/conversation_notify_bridge.dart';

class UikitConversationNotifyBridge {
  UikitConversationNotifyBridge._();

  static void install() {
    ConversationNotifyBridge.configure(
      reporter: ({
        required String chatType,
        required String peerId,
        required bool muted,
      }) {
        return ConversationNotifySyncService.instance.reportAfterImSuccess(
          chatType: chatType,
          peerId: peerId,
          muted: muted,
        );
      },
    );
  }
}
