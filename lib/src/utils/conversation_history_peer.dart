import 'package:tencent_cloud_chat_demo/utils/chat_id_format.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_conversation.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_conversation.dart';

/// 历史拉取身份：禁止把 `c2c_` 会话误判为群（避免 `group_id:c2c_…` → 10015）。
class ConversationHistoryPeer {
  const ConversationHistoryPeer._({
    required this.isGroup,
    this.userID,
    this.groupID,
  });

  final bool isGroup;
  final String? userID;
  final String? groupID;

  bool get canFetch => isGroup
      ? (groupID?.trim().isNotEmpty ?? false)
      : (userID?.trim().isNotEmpty ?? false);

  /// 判定优先级：`c2c_` / `group_` 前缀硬覆盖 type / groupID 误填。
  static ConversationHistoryPeer? resolve(V2TimConversation conversation) {
    final id = conversation.conversationID.trim();
    if (id.isEmpty) {
      return null;
    }
    final lower = id.toLowerCase();

    if (lower.startsWith('c2c_')) {
      final fromField = conversation.userID?.trim() ?? '';
      final peer = fromField.isNotEmpty
          ? ChatIdFormat.rawUserUid(fromField)
          : ChatIdFormat.rawUserUid(id.substring(4));
      if (peer.isEmpty) {
        return null;
      }
      return ConversationHistoryPeer._(isGroup: false, userID: peer);
    }

    if (lower.startsWith('group_')) {
      final rawGroupID = conversation.groupID?.trim();
      final canonical = ChatIdFormat.canonicalGroupStorageId(
        (rawGroupID != null && rawGroupID.isNotEmpty) ? rawGroupID : id,
      );
      if (canonical.isEmpty) {
        return null;
      }
      return ConversationHistoryPeer._(isGroup: true, groupID: canonical);
    }

    final rawGroupID = conversation.groupID?.trim() ?? '';
    if (conversation.type == 2 || rawGroupID.isNotEmpty) {
      final canonical = ChatIdFormat.canonicalGroupStorageId(
        rawGroupID.isNotEmpty ? rawGroupID : id,
      );
      if (canonical.isEmpty) {
        return null;
      }
      return ConversationHistoryPeer._(isGroup: true, groupID: canonical);
    }

    final userID = conversation.userID?.trim() ?? '';
    if (userID.isNotEmpty) {
      final peer = ChatIdFormat.rawUserUid(userID);
      if (peer.isEmpty) {
        return null;
      }
      return ConversationHistoryPeer._(isGroup: false, userID: peer);
    }
    return null;
  }
}
