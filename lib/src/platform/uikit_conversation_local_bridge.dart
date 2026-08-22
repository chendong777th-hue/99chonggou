import 'dart:async';

import 'package:tencent_cloud_chat_demo/src/services/conversation_local/conversation_sync_service.dart';
import 'package:tencent_cloud_chat_uikit/business_logic/view_models/tui_conversation_view_model.dart';

/// 将 UIKit 会话 SDK 回调收口到本地 SQLite，供消息列表 UI 读库渲染。
///
/// 注意：UIKit `onPageLoaded` 来自混流 `getConversationList`，只允许 upsert
/// 行数据，**不得**推进 typed sync meta / `hasSyncedOnce`（由
/// [ConversationSyncService] ByFilter 路径负责）。
class UikitConversationLocalBridge {
  UikitConversationLocalBridge._();

  static void install() {
    ConversationSyncService.instance.install();
    TUIConversationViewModelHooks.onPageLoaded = ({
      required conversations,
      required isRefresh,
      required nextSeq,
      required haveMoreData,
      required hasLoadedOnce,
    }) {
      unawaited(
        ConversationSyncService.instance.onViewModelPageLoaded(
          conversations: conversations,
          isRefresh: isRefresh,
          nextSeq: nextSeq,
          haveMoreData: haveMoreData,
          hasLoadedOnce: hasLoadedOnce,
        ),
      );
    };
    TUIConversationViewModelHooks.onConversationsChanged = (conversations) {
      unawaited(
        ConversationSyncService.instance.onViewModelConversationsChanged(
          conversations,
        ),
      );
    };
    TUIConversationViewModelHooks.onConversationsDeleted = (conversationIds) {
      unawaited(
        ConversationSyncService.instance.onViewModelConversationsDeleted(
          conversationIds,
          force: true,
        ),
      );
    };
    TUIConversationViewModelHooks.onConversationReadLocally = (conversationID) {
      unawaited(
        ConversationSyncService.instance.markConversationReadLocally(
          conversationID,
        ),
      );
    };
  }
}
