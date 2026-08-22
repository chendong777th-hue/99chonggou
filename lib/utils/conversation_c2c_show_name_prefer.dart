import 'package:tencent_cloud_chat_demo/utils/chat_id_format.dart';

/// C2C 会话展示名合并：禁止用昵称盖掉已有备注（Store / existing）。
class ConversationC2cShowNamePrefer {
  ConversationC2cShowNamePrefer._();

  /// [storeName] 为 DisplayNameStore.c2c；非空时优先于会话行。
  static String preferC2cShowName({
    required String? existingShowName,
    required String? incomingShowName,
    required String? storeName,
  }) {
    final store = storeName?.trim() ?? '';
    final existing = existingShowName?.trim() ?? '';
    final incoming = incomingShowName?.trim() ?? '';

    if (store.isNotEmpty) {
      return store;
    }
    if (existing.isNotEmpty) {
      // Store 空时：已有行名优先，避免 SDK 昵称帧盖掉本地备注行。
      if (incoming.isEmpty || incoming == existing) {
        return existing;
      }
      // incoming 不同且 existing 非空：仍保 existing（禁降级）。
      return existing;
    }
    return incoming;
  }

  static String preferForConversationIds({
    required String conversationID,
    required String? userID,
    required String? existingShowName,
    required String? incomingShowName,
    required String? Function(String userId) readStore,
  }) {
    final id = conversationID.trim();
    final uid = ChatIdFormat.rawUserUid(
      (userID?.trim().isNotEmpty == true)
          ? userID
          : (id.startsWith('c2c_') ? id.substring(4) : ''),
    );
    if (!id.startsWith('c2c_') && uid.isEmpty) {
      final incoming = incomingShowName?.trim() ?? '';
      if (incoming.isNotEmpty) {
        return incoming;
      }
      return existingShowName?.trim() ?? '';
    }
    final store = uid.isEmpty ? '' : (readStore(uid)?.trim() ?? '');
    return preferC2cShowName(
      existingShowName: existingShowName,
      incomingShowName: incomingShowName,
      storeName: store,
    );
  }
}
