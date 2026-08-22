import 'package:tencent_cloud_chat_demo/src/services/conversation_local/conversation_list_notifier.dart';
import 'package:tencent_cloud_chat_demo/src/services/conversation_local/conversation_local_store.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_conversation.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_conversation.dart';

/// 会话草稿：仅读写本地库，不依赖 IM SDK。
class ConversationDraftService {
  ConversationDraftService._();

  static final ConversationDraftService instance = ConversationDraftService._();

  Future<void> persistDraft({
    required String conversationID,
    required String rawInputText,
  }) async {
    final id = conversationID.trim();
    if (id.isEmpty) {
      return;
    }
    final updated = await ConversationLocalStore.instance.updateLocalDraft(
      conversationID: id,
      draftText: rawInputText,
    );
    await _notifyList(updated);
  }

  Future<void> clearDraft({required String conversationID}) async {
    final id = conversationID.trim();
    if (id.isEmpty) {
      return;
    }
    final updated = await ConversationLocalStore.instance.clearLocalDraft(
      conversationID: id,
    );
    await _notifyList(updated);
  }

  Future<String?> loadDraftText({required String conversationID}) async {
    final id = conversationID.trim();
    if (id.isEmpty) {
      return null;
    }
    final text = await ConversationLocalStore.instance.localDraftTextFor(
      conversationID: id,
    );
    return text.isEmpty ? null : text;
  }

  Future<void> _notifyList(V2TimConversation? updated) async {
    if (updated == null) {
      return;
    }
    await ConversationListNotifier.instance.applyConversationsFromStore(
      upserted: [updated],
    );
  }
}
