import 'package:tencent_cloud_chat_demo/src/services/contact_social_cache_store.dart';
import 'package:tencent_cloud_chat_demo/src/services/conversation_local/conversation_list_notifier.dart';
import 'package:tencent_cloud_chat_demo/src/services/conversation_local/conversation_local_store.dart';
import 'package:tencent_cloud_chat_demo/src/services/conversation_local/conversation_mutation_coordinator.dart';
import 'package:tencent_cloud_chat_demo/src/services/conversation_local/conversation_mutation_event.dart';
import 'package:tencent_cloud_chat_demo/src/services/conversation_local/conversation_mutation_shadow_bridge.dart';
import 'package:tencent_cloud_chat_demo/utils/chat_id_format.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_conversation.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_conversation.dart';
import 'package:tencent_cloud_chat_uikit/business_logic/mobile_async_commit_guard.dart';

/// 会话草稿：仅读写本地库，不依赖 IM SDK。
class ConversationDraftService {
  ConversationDraftService._();

  static final ConversationDraftService instance = ConversationDraftService._();
  final MobileAsyncCommitGuard _commitGuard = MobileAsyncCommitGuard();

  Future<void> persistDraft({
    required String conversationID,
    required String rawInputText,
  }) async {
    final id = conversationID.trim();
    if (id.isEmpty) {
      return;
    }
    final token = _commitGuard.begin('draft-write', key: id);
    final commit = await _commitDraft(id, rawInputText);
    if (!_commitGuard.canCommit(token)) return;
    await _notifyList(commit);
  }

  Future<void> clearDraft({required String conversationID}) async {
    final id = conversationID.trim();
    if (id.isEmpty) {
      return;
    }
    final token = _commitGuard.begin('draft-write', key: id);
    final commit = await _commitDraft(id, '');
    if (!_commitGuard.canCommit(token)) return;
    await _notifyList(commit);
  }

  /// Clears all IDs known to represent the same active conversation. This is
  /// used after send because group routes can expose both a bare IM ID and a
  /// `group_` UI storage ID during normalization.
  Future<void> clearDraftForConversationIds(
    Iterable<String> conversationIDs,
  ) async {
    final ids = conversationIDs
        .map((id) => id.trim())
        .where((id) => id.isNotEmpty)
        .toSet();
    for (final id in ids) {
      await clearDraft(conversationID: id);
    }
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

  Future<void> _notifyList(
    ConversationDatabaseCommitResult<V2TimConversation>? commit,
  ) async {
    if (commit == null || !commit.shouldNotifyUi) {
      return;
    }
    await ConversationListNotifier.instance.applyCommittedBatch(
      commit.uiBatch,
    );
  }

  Future<ConversationDatabaseCommitResult<V2TimConversation>?> _commitDraft(
    String id,
    String text,
  ) async {
    final owner = ChatIdFormat.rawUserUid(
      ContactSocialCacheStore.safeLoginUserId(),
    );
    if (owner.isEmpty) {
      return null;
    }
    final durable =
        await ConversationLocalStore.instance.coordinatorDurableState(
      ownerUserId: owner,
      conversationId: id,
    );
    ConversationMutationShadowBridge.instance.restoreDurableConversationState(
      ownerUserId: owner,
      conversationId: id,
      generation: durable.generation,
      tombstoned: durable.tombstoned,
    );
    final plan = await ConversationMutationShadowBridge.instance
        .prepareLocalIntentCommit(
      ownerUserId: owner,
      conversationId: id,
      fieldPatch: <ConversationMutationField, Object?>{
        ConversationMutationField.draft: text,
      },
    );
    if (plan == null) {
      return null;
    }
    return ConversationLocalStore.instance.commitCoordinatorPlan(
      plan: plan,
    );
  }
}
