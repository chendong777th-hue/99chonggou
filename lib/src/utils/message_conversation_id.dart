import 'package:tencent_cloud_chat_demo/src/services/contact_social_cache_store.dart';
import 'package:tencent_cloud_chat_demo/utils/chat_id_format.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_message.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_message.dart';

/// C2C / 群聊会话 ID 解析，与 UIKit `_messageConversationID` 语义对齐。
class MessageConversationId {
  MessageConversationId._();

  static String _normalizeLoginUserId(String? loginUserId) {
    final raw = loginUserId?.trim() ?? '';
    if (raw.isNotEmpty) {
      return ChatIdFormat.rawUserUid(raw);
    }
    return ChatIdFormat.rawUserUid(ContactSocialCacheStore.safeLoginUserId());
  }

  /// C2C peer：优先非本人的 [userID]，否则非本人的 [sender]。
  static String? resolveC2CPeerId({
    String? userID,
    String? sender,
    String? loginUserId,
  }) {
    final login = _normalizeLoginUserId(loginUserId);
    final uid = ChatIdFormat.rawUserUid(userID);
    final from = ChatIdFormat.rawUserUid(sender);

    if (uid.isNotEmpty && (login.isEmpty || uid != login)) {
      return uid;
    }
    if (from.isNotEmpty && (login.isEmpty || from != login)) {
      return from;
    }
    return null;
  }

  static String? resolve({
    String? conversationID,
    String? groupID,
    String? userID,
    String? sender,
    String? loginUserId,
  }) {
    final directConversationId = conversationID?.trim() ?? '';
    if (directConversationId.isNotEmpty) {
      return directConversationId;
    }

    final normalizedGroupId = groupID?.trim() ?? '';
    if (normalizedGroupId.isNotEmpty) {
      return 'group_$normalizedGroupId';
    }

    final peer = resolveC2CPeerId(
      userID: userID,
      sender: sender,
      loginUserId: loginUserId,
    );
    if (peer != null && peer.isNotEmpty) {
      return 'c2c_$peer';
    }
    return null;
  }

  static String? fromMessage(
    V2TimMessage message, {
    String? loginUserId,
  }) {
    final groupId = message.groupID?.trim() ?? '';
    if (groupId.isNotEmpty) {
      return 'group_$groupId';
    }
    final peer = resolveC2CPeerId(
      userID: message.userID,
      sender: message.sender,
      loginUserId: loginUserId,
    );
    if (peer == null || peer.isEmpty) {
      return null;
    }
    return 'c2c_$peer';
  }

  /// 校验会话预览消息的归属，阻止 SDK/缓存中的脏 lastMessage 串到另一行。
  /// 无法从消息解析会话时不误杀；能够解析时必须与目标会话同类型、同 ID。
  static bool messageBelongsToConversation(
    V2TimMessage? message,
    String? conversationId, {
    String? loginUserId,
  }) {
    if (message == null) {
      return true;
    }
    final target = conversationId?.trim() ?? '';
    if (target.isEmpty) {
      return false;
    }
    final groupId = message.groupID?.trim() ?? '';
    if (groupId.isNotEmpty) {
      return sameConversation(target, 'group_$groupId');
    }
    final peerId = message.userID?.trim() ?? '';
    if (peerId.isNotEmpty) {
      return sameConversation(target, 'c2c_$peerId');
    }
    final explicitLogin = loginUserId?.trim() ?? '';
    if (explicitLogin.isNotEmpty) {
      final resolved = resolveC2CPeerId(
        userID: message.userID,
        sender: message.sender,
        loginUserId: explicitLogin,
      );
      if (resolved != null && resolved.isNotEmpty) {
        return sameConversation(target, 'c2c_$resolved');
      }
    }
    // 缺少 groupID/userID 时 sender 可能是自己，无法无歧义判断，不误杀。
    return true;
  }

  /// 去掉 `c2c_` / `group_` 等前缀，用于会话 ID 等价比较。
  static String normalizeComparableKey(String? raw) {
    var id = raw?.trim() ?? '';
    if (id.isEmpty) {
      return '';
    }
    final lower = id.toLowerCase();
    if (lower.startsWith('c2c_')) {
      return id.substring(4);
    }
    if (lower.startsWith('group_')) {
      return id.substring(6);
    }
    if (id.startsWith('C2C')) {
      return id.substring(3);
    }
    if (id.startsWith('GROUP')) {
      return id.substring(5);
    }
    return id;
  }

  /// 单聊会话形态（含脏孪生 `group_c2c_`）。
  static bool looksLikeC2cConversationId(String? raw) {
    final id = raw?.trim().toLowerCase() ?? '';
    if (id.isEmpty) {
      return false;
    }
    return id.startsWith('c2c_') || id.startsWith('group_c2c_');
  }

  /// 群会话前缀形态（排除 `group_c2c_`）。
  static bool looksLikeGroupConversationId(String? raw) {
    final id = raw?.trim().toLowerCase() ?? '';
    if (id.isEmpty || looksLikeC2cConversationId(id)) {
      return false;
    }
    return id.startsWith('group_');
  }

  /// 会话相等：同类型内兼容裸 id / 群别名；**禁止** `c2c_x` ≡ `group_x`。
  static bool sameConversation(String? left, String? right) {
    final leftId = left?.trim() ?? '';
    final rightId = right?.trim() ?? '';
    if (leftId.isEmpty || rightId.isEmpty) {
      return false;
    }
    final leftC2c = looksLikeC2cConversationId(leftId);
    final rightC2c = looksLikeC2cConversationId(rightId);
    final leftGroup = looksLikeGroupConversationId(leftId);
    final rightGroup = looksLikeGroupConversationId(rightId);
    if ((leftC2c && rightGroup) || (leftGroup && rightC2c)) {
      return false;
    }
    final a = normalizeComparableKey(leftId);
    final b = normalizeComparableKey(rightId);
    if (a.isEmpty || b.isEmpty) {
      return false;
    }
    if (a == b) {
      return true;
    }
    return ChatIdFormat.groupIdsEquivalent(a, b) ||
        ChatIdFormat.groupIdsEquivalent(leftId, rightId);
  }

  static bool isSelfC2CConversation(
    String? conversationId,
    String? loginUserId,
  ) {
    final id = conversationId?.trim() ?? '';
    if (!id.startsWith('c2c_')) {
      return false;
    }
    final login = _normalizeLoginUserId(loginUserId);
    if (login.isEmpty) {
      return false;
    }
    final peer = ChatIdFormat.rawUserUid(id.replaceFirst('c2c_', ''));
    return peer.isNotEmpty && peer == login;
  }
}
