import 'package:tencent_cloud_chat_demo/src/services/conversation_local/conversation_sync_service.dart';
import 'package:tencent_cloud_chat_uikit/data_services/message/conversation_peer_read_coordinator.dart';

/// 对方已读 → 会话列表 lastMessage.isPeerRead 写回。
class ConversationPeerReadSyncService {
  ConversationPeerReadSyncService._();

  static void register() {
    ConversationPeerReadCoordinator.register(
      ({
        required String conversationID,
        String? msgID,
        int? peerReadAtSec,
      }) {
        return ConversationSyncService.instance.markLastMessagePeerRead(
          conversationID: conversationID,
          msgID: msgID,
          peerReadAtSec: peerReadAtSec,
        );
      },
    );
  }
}
