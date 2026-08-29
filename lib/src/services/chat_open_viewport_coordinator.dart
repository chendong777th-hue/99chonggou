import 'package:tencent_cloud_chat_demo/src/models/chat_entry_snapshot.dart';
import 'package:tencent_cloud_chat_demo/src/services/chat_open_perf_log.dart';
import 'package:tencent_cloud_chat_demo/src/services/conversation_history_warm_scheduler.dart';
import 'package:tencent_cloud_chat_demo/src/utils/conversation_preview_history_sync.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_conversation.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_conversation.dart';
import 'package:tencent_cloud_chat_uikit/business_logic/view_models/tui_chat_global_model.dart';
import 'package:tencent_cloud_chat_uikit/data_services/services_locatar.dart';

/// 进聊首窗预热状态机。
///
/// 导航不再等待 ViewportReady：Prepare 与 route transition 并行，Chat 页
/// 从首帧开始挂载稳定真实树。该协调器只负责预热、取消和性能观测，不能
/// 决定页面是否允许 push。
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
  }

  /// 后台最多尝试这么久把本地首屏窗灌满。它不阻塞 Navigator.push，
  /// 也不要加长到网络 RTT。
  static const Duration prepareTimeout = Duration(milliseconds: 400);

  /// Prepare + 等待暖窗完整或 [timeout]。调用方应 fire-and-forget，返回快照
  /// 仅用于观测/测试，可能 `!isViewportReady`。
  Future<ChatEntrySnapshot> prepareForOpen({
    required V2TimConversation conversation,
    Duration timeout = prepareTimeout,
  }) async {
    final requestId = ++_requestId;
    final cacheKey = ConversationPreviewHistorySync.conversationMessageCacheKey(
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

    // Prepare 可能在 route 已 transitioning/visible 后完成。不能把状态倒退
    // 回 prepared/viewportReady，否则后续生命周期判断会误以为页面尚未出现。
    final alreadyTransitioning =
        _phase == ChatOpenViewportPhase.transitioning ||
            _phase == ChatOpenViewportPhase.visible;
    if (!alreadyTransitioning) {
      _phase = ChatOpenViewportPhase.prepared;
    }
    final ready = snap.isViewportReady;
    if (ready) {
      if (!alreadyTransitioning) {
        _phase = ChatOpenViewportPhase.viewportReady;
      }
      ChatOpenPerfLog.mark(
        alreadyTransitioning ? 'viewport_ready_background' : 'viewport_ready',
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
