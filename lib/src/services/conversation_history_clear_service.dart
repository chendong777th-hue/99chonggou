import 'package:tencent_cloud_chat_demo/src/services/call_result_repository.dart';
import 'package:tencent_cloud_chat_demo/src/services/conversation_local/conversation_local_store.dart';
import 'package:tencent_cloud_chat_demo/src/services/conversation_local/conversation_sync_service.dart';
import 'package:tencent_cloud_chat_demo/src/services/group_local/group_change_event_sync_service.dart';
import 'package:tencent_cloud_chat_demo/src/services/group_local/group_local_tips_service.dart';
import 'package:tencent_cloud_chat_demo/src/services/group_local/group_tips_operator_patch_service.dart';
import 'package:tencent_cloud_chat_demo/src/services/message_history_coverage_store.dart';
import 'package:tencent_cloud_chat_demo/utils/chat_id_format.dart';
import 'package:tencent_cloud_chat_uikit/data_services/message/archive_history_provider.dart';
import 'package:tencent_cloud_chat_uikit/business_logic/view_models/tui_chat_global_model.dart';
import 'package:tencent_cloud_chat_uikit/data_services/services_locatar.dart';

/// 聊天记录清空后的本地预览/列表同步。
class ConversationHistoryClearService {
  ConversationHistoryClearService._();

  static void register() {
    ArchiveHistoryProvider.registerClearCoordinator(_onHistoryCleared);
    ArchiveHistoryProvider.registerHistoryClearedAtResolver(
      (conversationID) => ConversationLocalStore.instance.historyClearedAtMs(
        conversationID,
      ),
    );
  }

  static Future<void> _onHistoryCleared({
    required bool isGroup,
    required String conversationID,
  }) async {
    final fullConversationId = _fullConversationId(
      isGroup: isGroup,
      conversationID: conversationID,
    );
    await CallResultRepository.instance.removeByConversationId(
      fullConversationId,
    );
    final snapshot = await ConversationLocalStore.instance.conversationById(
      fullConversationId,
    );
    await ConversationSyncService.instance.onConversationHistoryCleared(
      conversationID: fullConversationId,
      snapshot: snapshot,
    );
    final clearEpoch = await ConversationLocalStore.instance.historyClearedAtMs(
      fullConversationId,
    );
    await MessageHistoryCoverageStore.instance.clearConversation(
      fullConversationId,
      isGroup: isGroup,
      clearEpoch: clearEpoch,
    );
    try {
      await serviceLocator<TUIChatGlobalModel>().invalidateMessageHistoryCoverage(
        fullConversationId,
        isGroup: isGroup,
        clearEpoch: clearEpoch,
      );
    } catch (_) {}
    if (isGroup) {
      await _clearGroupLocalTipsArtifacts(conversationID);
    }
  }

  /// 自建群灰字/操作者补丁不在 IM 历史里，清空会话时需单独清掉，否则进群又会灌回。
  static Future<void> _clearGroupLocalTipsArtifacts(
    String conversationID,
  ) async {
    final raw = conversationID.trim();
    final groupId = raw.startsWith('group_')
        ? raw.substring(6)
        : ChatIdFormat.canonicalGroupStorageId(raw);
    if (groupId.isEmpty) {
      return;
    }
    await GroupLocalTipsService.instance.clearHistoryForGroup(groupId);
    await GroupTipsOperatorPatchService.instance.clearHistoryForGroup(groupId);
    await GroupChangeEventSyncService.instance.markHistoryCleared(groupId);
  }

  static String _fullConversationId({
    required bool isGroup,
    required String conversationID,
  }) {
    final id = conversationID.trim();
    if (id.startsWith('c2c_') || id.startsWith('group_')) {
      return id;
    }
    return isGroup ? 'group_$id' : 'c2c_$id';
  }
}
