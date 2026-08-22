import 'package:tencent_cloud_chat_demo/utils/chat_id_format.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_conversation.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_conversation.dart';
import 'package:tencent_cloud_chat_uikit/ui/views/TIMUIKitConversation/archived_conversation_store.dart';

/// REST `chatType` + `peerId` 与 IM `conversationID` 互转。
class ArchivedConversationRef {
  const ArchivedConversationRef({
    required this.chatType,
    required this.peerId,
  });

  final String chatType;
  final String peerId;

  ConversationArchiveScope get scope {
    return chatType == 'group'
        ? ConversationArchiveScope.group
        : ConversationArchiveScope.c2c;
  }

  String get conversationId {
    return chatType == 'group' ? 'group_$peerId' : 'c2c_$peerId';
  }

  static ArchivedConversationRef? fromConversation(
    V2TimConversation conversation,
  ) {
    final groupId = conversation.groupID?.trim() ?? '';
    if (groupId.isNotEmpty || conversation.type == 2) {
      final resolved = groupId.isNotEmpty
          ? groupId
          : _peerFromConversationId(conversation.conversationID, 'group');
      if (resolved == null || resolved.isEmpty) {
        return null;
      }
      return ArchivedConversationRef(
        chatType: 'group',
        peerId: ChatIdFormat.canonicalGroupStorageId(resolved),
      );
    }
    final userId = ChatIdFormat.rawUserUid(conversation.userID);
    if (userId.isNotEmpty) {
      return ArchivedConversationRef(chatType: 'c2c', peerId: userId);
    }
    return fromConversationId(conversation.conversationID);
  }

  static ArchivedConversationRef? fromConversationId(String conversationID) {
    final id = conversationID.trim();
    if (id.isEmpty) {
      return null;
    }
    if (id.startsWith('group_')) {
      final peer = id.substring('group_'.length).trim();
      if (peer.isEmpty) {
        return null;
      }
      return ArchivedConversationRef(
        chatType: 'group',
        peerId: ChatIdFormat.canonicalGroupStorageId(peer),
      );
    }
    if (id.startsWith('c2c_')) {
      final peer = ChatIdFormat.rawUserUid(id.substring('c2c_'.length));
      if (peer.isEmpty) {
        return null;
      }
      return ArchivedConversationRef(chatType: 'c2c', peerId: peer);
    }
    return null;
  }

  static String? _peerFromConversationId(
    String? conversationID,
    String chatType,
  ) {
    final id = conversationID?.trim() ?? '';
    if (id.isEmpty) {
      return null;
    }
    final prefix = '${chatType}_';
    if (!id.startsWith(prefix)) {
      return null;
    }
    return id.substring(prefix.length).trim();
  }
}
