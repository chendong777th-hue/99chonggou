import 'package:flutter/foundation.dart';
import 'package:tencent_cloud_chat_demo/src/utils/conversation_preview_history_sync.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_message.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_message.dart';
import 'package:tencent_cloud_chat_uikit/business_logic/view_models/tui_chat_global_model.dart';
import 'package:tencent_cloud_chat_uikit/ui/constants/history_message_constant.dart';

/// 进聊前从内存暖窗派生的最小首屏快照（不是第二套消息库）。
@immutable
class ChatEntrySnapshot {
  const ChatEntrySnapshot({
    required this.conversationKey,
    required this.conversationID,
    required this.requestId,
    required this.messageCount,
    required this.initialHistoryLoaded,
    required this.mayHaveOlderHistory,
    required this.completeOpenWindow,
    required this.emptyConfirmed,
    required this.capturedAtMs,
    this.tipMsgID,
    this.tipTimestamp,
    this.layoutSizedImageCount,
    this.imageMessageCount,
  });

  final String conversationKey;
  final String conversationID;
  final int requestId;
  final int messageCount;
  final bool initialHistoryLoaded;
  final bool mayHaveOlderHistory;
  final bool completeOpenWindow;
  final bool emptyConfirmed;
  final String? tipMsgID;
  final int? tipTimestamp;
  final int capturedAtMs;
  final int? layoutSizedImageCount;
  final int? imageMessageCount;

  /// ViewportReady：可跳过空壳、优先走 history_gate_content_ready_skip。
  ///
  /// 与 [ConversationPreviewHistorySync.isCompleteOpenHistoryWindow] /
  /// 空会话确认同源，避免第二套完整窗定义。
  bool get isViewportReady {
    if (emptyConfirmed) {
      return true;
    }
    if (completeOpenWindow) {
      return true;
    }
    // 短会话已耗尽（条数 < 暖窗配额且无更早历史）——与 complete 短路径对齐。
    if (initialHistoryLoaded &&
        messageCount > 0 &&
        !mayHaveOlderHistory &&
        messageCount < HistoryMessageDartConstant.initialOpenFetchCount) {
      return true;
    }
    return false;
  }

  factory ChatEntrySnapshot.capture({
    required TUIChatGlobalModel globalModel,
    required String conversationKey,
    required String conversationID,
    required int requestId,
    V2TimMessage? tip,
  }) {
    final key = conversationKey.trim();
    final count = key.isEmpty ? 0 : globalModel.rawMessageCount(key);
    final loaded =
        key.isNotEmpty && globalModel.hasInitialHistoryLoaded(key);
    final mayOlder =
        key.isNotEmpty && globalModel.mayHaveOlderHistory(key);
    final complete = key.isNotEmpty &&
        ConversationPreviewHistorySync.isCompleteOpenHistoryWindow(
          globalModel: globalModel,
          conversationKey: key,
        );
    final empty = loaded && count == 0;
    return ChatEntrySnapshot(
      conversationKey: key,
      conversationID: conversationID.trim(),
      requestId: requestId,
      messageCount: count,
      initialHistoryLoaded: loaded,
      mayHaveOlderHistory: mayOlder,
      completeOpenWindow: complete,
      emptyConfirmed: empty,
      tipMsgID: tip?.msgID?.trim(),
      tipTimestamp: tip?.timestamp,
      capturedAtMs: DateTime.now().millisecondsSinceEpoch,
    );
  }
}
