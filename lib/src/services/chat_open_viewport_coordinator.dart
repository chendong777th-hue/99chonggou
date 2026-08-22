import 'package:tencent_cloud_chat_demo/src/models/chat_entry_snapshot.dart';
import 'package:tencent_cloud_chat_demo/src/services/chat_open_perf_log.dart';
import 'package:tencent_cloud_chat_demo/src/services/conversation_history_warm_scheduler.dart';
import 'package:tencent_cloud_chat_demo/src/utils/conversation_preview_history_sync.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_conversation.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_conversation.dart';
import 'package:tencent_cloud_chat_uikit/business_logic/view_models/tui_chat_global_model.dart';
import 'package:tencent_cloud_chat_uikit/data_services/services_locatar.dart';

/// 进聊 ViewportReady 状态机：Prepare → Ready → Push（轻壳仅作 miss 兜底）。
enum ChatOpenViewportPhase {
  idle,
  preparing,
  prepared,
  viewportReady,
  transitioning,
  visible,
  cancelled,
}

class ChatOpenViewportCoordinator {
  ChatOpenViewportCoordinator._();

  static final ChatOpenViewportCoordinator instance =
      ChatOpenViewportCoordinator._();

  int _requestId = 0;
  String? _activeKey;
  ChatOpenViewportPhase _phase = ChatOpenViewportPhase.idle;

  /// Chat initState 一次性消费：该会话是否以 ViewportReady 进页。
  final Map<String, bool> _pendingReadyByKey = <String, bool>{};

  int get currentRequestId => _requestId;

  ChatOpenViewportPhase get phase => _phase;

  ChatOpenViewportPhase phaseFor(String conversationKey) {
    final key = conversationKey.trim();
    if (key.isEmpty || key != (_activeKey ?? '')) {
      return ChatOpenViewportPhase.idle;
    }
    return _phase;
  }

  bool isCurrent(int requestId, String conversationKey) {
    final key = conversationKey.trim();
    return requestId == _requestId &&
        key.isNotEmpty &&
        key == (_activeKey ?? '');
  }

  /// 消费进页 Ready 标记（只读一次）。
  bool takeOpenWasViewportReady(String conversationKey) {
    final key = conversationKey.trim();
    if (key.isEmpty) {
      return false;
    }
    return _pendingReadyByKey.remove(key) == true;
  }

  void markTransitioning(String conversationKey) {
    final key = conversationKey.trim();
    if (key.isEmpty || key != (_activeKey ?? '')) {
      return;
    }
    _phase = ChatOpenViewportPhase.transitioning;
  }

  void markVisible(String conversationKey) {
    final key = conversationKey.trim();
    if (key.isEmpty || key != (_activeKey ?? '')) {
      return;
    }
    _phase = ChatOpenViewportPhase.visible;
  }

  void resetForTest() {
    _requestId = 0;
    _activeKey = null;
    _phase = ChatOpenViewportPhase.idle;
    _pendingReadyByKey.clear();
  }

  /// 进页前最多等这么久把本地首屏窗灌满。已齐则立刻返回。
  /// 冷开超时后仍 push，由页内轻壳兜底——不要再加长到网络 RTT。
  static const Duration prepareTimeout = Duration(milliseconds: 400);

  /// Prepare + 等待暖窗完整或 [timeout]。返回快照；可能 `!isViewportReady`。
  Future<ChatEntrySnapshot> prepareForOpen({
    required V2TimConversation conversation,
    Duration timeout = prepareTimeout,
  }) async {
    final requestId = ++_requestId;
    final cacheKey =
        ConversationPreviewHistorySync.conversationMessageCacheKey(
              conversation,
            ) ??
            conversation.conversationID.trim();
    final conversationID = conversation.conversationID.trim();
    _activeKey = cacheKey;
    _phase = ChatOpenViewportPhase.preparing;
    ChatOpenPerfLog.mark(
      'viewport_preparing',
      conversationID: cacheKey,
      extras: <String, Object?>{
        'requestId': requestId,
        'timeoutMs': timeout.inMilliseconds,
      },
    );

    await ConversationHistoryWarmScheduler.instance.ensureCompleteOpenWindow(
      conversation: conversation,
      timeout: timeout,
    );

    final globalModel = serviceLocator<TUIChatGlobalModel>();
    final snap = ChatEntrySnapshot.capture(
      globalModel: globalModel,
      conversationKey: cacheKey,
      conversationID: conversationID,
      requestId: requestId,
      tip: conversation.lastMessage,
    );

    if (!isCurrent(requestId, cacheKey)) {
      _phase = ChatOpenViewportPhase.cancelled;
      ChatOpenPerfLog.mark(
        'viewport_prepare_stale',
        conversationID: cacheKey,
        extras: <String, Object?>{
          'requestId': requestId,
          'currentRequestId': _requestId,
        },
      );
      return snap;
    }

    _phase = ChatOpenViewportPhase.prepared;
    final ready = snap.isViewportReady;
    _pendingReadyByKey[cacheKey] = ready;
    if (ready) {
      _phase = ChatOpenViewportPhase.viewportReady;
      ChatOpenPerfLog.mark(
        'viewport_ready',
        conversationID: cacheKey,
        extras: <String, Object?>{
          'requestId': requestId,
          'rawCount': snap.messageCount,
          'completeWindow': snap.completeOpenWindow,
          'emptyConfirmed': snap.emptyConfirmed,
        },
      );
    } else {
      ChatOpenPerfLog.mark(
        'viewport_ready_miss',
        conversationID: cacheKey,
        extras: <String, Object?>{
          'requestId': requestId,
          'rawCount': snap.messageCount,
          'initialLoaded': snap.initialHistoryLoaded,
          'mayHaveOlder': snap.mayHaveOlderHistory,
        },
      );
    }
    return snap;
  }
}
