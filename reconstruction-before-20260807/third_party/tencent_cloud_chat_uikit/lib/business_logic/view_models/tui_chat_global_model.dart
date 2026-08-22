// ignore_for_file: avoid_print, unnecessary_getters_setters, unused_element
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:tencent_cloud_chat_uikit/ui/views/TIMUIKitSearch/conversation_search_utils.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tencent_cloud_chat_sdk/enum/V2TimAdvancedMsgListener.dart';
import 'package:tencent_cloud_chat_sdk/enum/history_msg_get_type_enum.dart';
import 'package:tencent_cloud_chat_sdk/enum/message_elem_type.dart';
import 'package:tencent_cloud_chat_sdk/enum/message_priority_enum.dart';
import 'package:tencent_cloud_chat_sdk/enum/message_status.dart';
import 'package:tencent_cloud_chat_sdk/enum/offlinePushInfo.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_conversation.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_conversation.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_custom_elem.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_custom_elem.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_group_application.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_group_application.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_group_member_full_info.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_group_member_full_info.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_image.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_image.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_message.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_message.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_message_download_progress.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_message_download_progress.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_message_receipt.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_message_receipt.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_msg_create_info_result.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_msg_create_info_result.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_value_callback.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_value_callback.dart';
import 'package:tencent_cloud_chat_uikit/base_widgets/tim_ui_kit_class.dart';
import 'package:tencent_cloud_chat_uikit/business_logic/life_cycle/chat_life_cycle.dart';
import 'package:tencent_cloud_chat_uikit/business_logic/separate_models/tui_chat_model_tools.dart';
import 'package:tencent_cloud_chat_uikit/business_logic/services/group_member_store.dart';
import 'package:tencent_cloud_chat_uikit/business_logic/view_models/chat_ui_state_store.dart';
import 'package:tencent_cloud_chat_uikit/data_services/group/group_services.dart';
import 'package:tencent_cloud_chat_uikit/data_services/message/message_services.dart';
import 'package:tencent_cloud_chat_uikit/data_services/message/conversation_peer_read_coordinator.dart';
import 'package:tencent_cloud_chat_uikit/data_services/services_locatar.dart';
import 'package:tencent_cloud_chat_uikit/tencent_cloud_chat_uikit.dart';
import 'package:tencent_cloud_chat_uikit/ui/constants/history_message_constant.dart';
import 'package:tencent_cloud_chat_uikit/ui/utils/error_message_converter.dart';
import 'package:tencent_cloud_chat_uikit/ui/utils/chat_history_trace.dart';
import 'package:tencent_cloud_chat_uikit/ui/utils/history_pagination_anchor.dart';
import 'package:tencent_cloud_chat_uikit/ui/utils/chat_jitter_diag.dart';
import 'package:tencent_cloud_chat_uikit/ui/utils/chat_media_send_utils.dart';
import 'package:tencent_cloud_chat_uikit/ui/utils/chat_message_height_cache.dart';
import 'package:tencent_cloud_chat_uikit/ui/utils/message_inbound_batch_coalescer.dart';
import 'package:tencent_cloud_chat_uikit/ui/utils/message_inbound_chunk_reveal.dart';
import 'package:tencent_cloud_chat_uikit/ui/widgets/chat_send_fly_overlay.dart';
import 'package:tencent_cloud_chat_uikit/ui/utils/logger.dart';
import 'package:tencent_cloud_chat_uikit/ui/utils/message.dart';

enum ConvType { none, c2c, group }

enum HistoryMessagePosition {
  bottom,
  inTwoScreen,
  awayTwoScreen,
  notShowLatest
}

/// 搜索跳转进会话时的加载/定位状态（供消息列表 UI 与 _loadData 共用）。
enum SearchJumpStatus {
  idle,
  loading,
  success,
  failed,
}

enum GroupSystemNoticeType {
  grantAdministrator,
  revokeAdministrator,
  transferOwner,
}

class GroupSystemNoticeItem {
  final String id;
  final String groupID;
  final String groupName;
  final String groupFaceUrl;
  final GroupSystemNoticeType type;
  final String operatorUserID;
  final String operatorName;
  final String targetUserID;
  final String targetName;
  final int timestamp;

  GroupSystemNoticeItem({
    required this.id,
    required this.groupID,
    required this.groupName,
    required this.groupFaceUrl,
    required this.type,
    required this.operatorUserID,
    required this.operatorName,
    required this.targetUserID,
    required this.targetName,
    required this.timestamp,
  });
}

class CurrentConversation {
  final String conversationID;
  final ConvType conversationType;

  CurrentConversation(this.conversationID, this.conversationType);
}

class AppContactPresenceBridge {
  final Listenable? presenceListenable;
  final MemberPresenceLabelBuilder? presenceLabelBuilder;
  final MemberPresenceLoadingChecker? presenceLoadingChecker;
  final MemberPresenceOnlineResolver? presenceOnlineResolver;
  final void Function(List<String> userIds)? onContactListLoaded;

  const AppContactPresenceBridge({
    this.presenceListenable,
    this.presenceLabelBuilder,
    this.presenceLoadingChecker,
    this.presenceOnlineResolver,
    this.onContactListLoaded,
  });
}

class _InboundUnreadState {
  int unreadCount = 0;
  int receivedCount = 0;
  int lockedEntryUnreadCount = 0;
  final List<V2TimMessage> bufferedMessages = <V2TimMessage>[];
  final Set<String> bufferedMessageKeys = <String>{};

  bool get isEmpty =>
      unreadCount == 0 &&
      receivedCount == 0 &&
      lockedEntryUnreadCount == 0 &&
      bufferedMessages.isEmpty &&
      bufferedMessageKeys.isEmpty;

  void clear() {
    unreadCount = 0;
    receivedCount = 0;
    lockedEntryUnreadCount = 0;
    bufferedMessages.clear();
    bufferedMessageKeys.clear();
  }
}

class TUIChatGlobalModel extends ChangeNotifier implements TIMUIKitClass {
  static void Function(TUIChatGlobalModel model)? registerAppExtensions;

  static void ensureAppExtensionsRegistered() {
    setupServiceLocator();
    registerAppExtensions?.call(serviceLocator<TUIChatGlobalModel>());
  }

  final MessageService _messageService = serviceLocator<MessageService>();
  final GroupServices _groupServices = serviceLocator<GroupServices>();
  final ChatUiStateStore _chatUiStateStore = serviceLocator<ChatUiStateStore>();
  final Map<String, List<V2TimMessage>?> _messageListMap = {};
  final Map<String, SearchJumpStatus> _searchJumpStatusMap = {};
  final Map<String, List<V2TimMessage>> _localMergerMessageCache = {};
  final Set<String> _initialHistoryLoadedConvs = {};
  final Map<String, bool> _mayHaveOlderHistoryByConv = {};
  final Map<String, Future<void>> _openHydrateInFlightByConv = {};
  final Map<String, V2TimMessageReceipt> _messageReadReceiptMap = {};
  final Map<String, int> _c2cPeerReadTimestampMap = {};
  final Map<String, int> _messageListProgressMap = {};
  final Map<String, String> _fileListLocationMap = {};
  final Map<String, Size> _fileMessageSizeMap = {};
  final Set<String> _cancelledOutgoingMediaIds = <String>{};
  final Map<String, dynamic> _preloadImageMap = {};
  final Map<String, HistoryMessagePosition> _historyMessagePositionMap = {};
  final List<CurrentConversation> _currentConversationList = [];

  Map<String, dynamic> get preloadImageMap => _preloadImageMap;

  ChatLifeCycle? _lifeCycle;
  bool _isDownloading = false;
  final List<Map<String, String>> _waitingDownloadList =
      List.empty(growable: true); // example {"savePath":"","url":"",msgId:""}
  int _totalUnreadCount = 0;
  String localKeyPrefix = "TUIKit_conversation_stored_";
  String localMsgIDListKey = "TUIKit_conversation_list";

  late V2TimAdvancedMsgListener advancedMsgListener;
  final Map<String, _InboundUnreadState> _inboundUnreadStateByConversation =
      <String, _InboundUnreadState>{};
  final Map<String, int> _unreadTongueRemainingByConversation = {};
  final Map<String, bool> _unreadTongueBelowByConversation = {};
  final Map<String, int> _dismissedEntryUnreadTongueCountByConversation = {};
  int _unreadTongueMetricsVersion = 0;

  // use for generate a new sliver list to show received message list
  final Set<String> _deferredUntilUserBottomConversations = <String>{};

  TIMUIKitChatConfig chatConfig = const TIMUIKitChatConfig();
  List<V2TimGroupApplication>? _groupApplicationList;
  DateTime? _lastGroupApplicationRefreshAt;
  Future<void>? _groupApplicationRefreshTask;
  Timer? _pendingGroupApplicationRefreshTimer;
  static const Duration _groupApplicationRefreshInterval =
      Duration(seconds: 20);
  List<GroupSystemNoticeItem> _groupSystemNoticeList = [];
  String Function(V2TimMessage message)? _abstractMessageBuilder;
  Widget Function(
    BuildContext context,
    TextEditingController controller,
    ValueChanged<String> onChanged,
  )? _appSearchBarBuilder;
  Widget Function(BuildContext context)? _appForwardSelectFriendPage;
  Widget Function(BuildContext context)? _appForwardSelectGroupPage;
  AppContactPresenceBridge Function(BuildContext context)?
      _appContactPresenceBridgeBuilder;
  final Map<String, int> _c2cMessageEditStatusMap =
      Map.from({}); // 0 normal 1 sending
  final Map<String, bool> _c2cMessageFromUserActiveMap = Map.from({});
  final Map<String, Timer> _c2cMessageActiveTimer = Map.from({});
  bool _showC2cMessageEditStatus = true;
  final Map<String, Timer> _c2cMessageStatusShowTimer = Map.from({});
  Map<String, List> loadingMessage = {};
  final Set<String> _messageEnterAnimationKeys = <String>{};
  final Map<String, int> _enterAnimationThrottleMarkMsByConv = <String, int>{};
  final Map<String, String> _enterAnimationThrottlePendingKeyByConv =
      <String, String>{};
  ChatSendFlyOverlayRequest? _sendFlyOverlayRequest;
  final Map<String, ScrollController> _activeChatScrollControllerMap = {};
  final Map<String, double> _mediaPreviewScrollOffsetMap = {};
  final Map<String, String> _mediaPreviewAnchorMsgIDMap = {};
  static const int _mediaPreviewRestoreLockMilliseconds = 300;
  static const int _mediaPreviewRestoreTailLockMilliseconds = 80;
  bool _isMediaPreviewOverlayOpen = false;
  int _walletOverlayDepth = 0;
  bool _isRestoringScrollAfterMediaPreview = false;
  int _mediaPreviewRestoreVersion = 0;
  int _mediaPreviewRestoreLockUntil = 0;
  int _outgoingPinScrollSuppressUntilMs = 0;
  bool _isChatListUserScrolling = false;
  /// Open chat page SSOT for scroll UI (wired from [ChatPageUiNotifiers]).
  ValueNotifier<HistoryMessagePosition>? _openPageHistoryPosition;
  ValueNotifier<bool>? _openPageUserScrolling;
  String? _openPageConvId;
  final Map<String, int> _messageListRevisionByConv = {};
  final Map<String, int> _messageProjectionRevisionByConv = {};
  final Map<String, Set<String>> _inboundHiddenKeysByConv = {};
  final Set<String> _authoritativeDeferredIncomingKeys = <String>{};
  final Set<String> _inboundFastForwardMessageKeys = <String>{};
  final Map<String, int> _outgoingLocalSeqByConv = {};
  final Map<String, List<V2TimMessage>> _messageListDisplayCache = {};
  final Map<String, Timer> _activeReadReportDebounceMap = {};
  final Map<String, int> _lastActiveReadReportAtMs = {};
  static const int _activeReadReportDebounceMs = 1200;
  static const int _activeReadReportMinIntervalMs = 3000;
  bool _notifyPending = false;
  bool _notifyScheduled = false;
  static const int _inboundBatchMaxSize = 50;
  static const Duration _inboundBatchMaxDelay = Duration(milliseconds: 50);
  static const int _bulkMessageSyncThreshold = 2;
  late final MessageInboundBatchCoalescer _inboundBatchCoalescer;
  late final MessageInboundChunkedReveal _inboundChunkReveal;
  final Map<String, int> _bulkMessageSyncDepthByConv = <String, int>{};
  final Map<String, bool> _pendingPinAfterBulkByConv = <String, bool>{};
  int _inboundScrollFollowSeq = 0;
  int _inboundPresentationSupersedeSeq = 0;
  bool _inboundScrollFollowSessionEnding = false;
  List<V2TimMessage> _lastInboundScrollFollowChunk = const [];
  bool _chatAppForeground = true;
  int _suppressInboundAnimationUntilMs = 0;

  bool get isChatListUserScrolling =>
      _openPageUserScrolling?.value ?? _isChatListUserScrolling;

  /// Bind the open history list's page UI notifiers as SSOT for scroll flags.
  void attachOpenChatPageUi({
    required String conversationId,
    required ValueNotifier<HistoryMessagePosition> historyPosition,
    required ValueNotifier<bool> userScrolling,
  }) {
    final convId = _safeConversationId(conversationId);
    _openPageConvId = convId;
    _openPageHistoryPosition = historyPosition;
    _openPageUserScrolling = userScrolling;
    final seeded =
        _historyMessagePositionMap[convId] ?? HistoryMessagePosition.bottom;
    if (historyPosition.value != seeded) {
      historyPosition.value = seeded;
    }
    userScrolling.value = false;
    _isChatListUserScrolling = false;
  }

  void detachOpenChatPageUi({
    required ValueNotifier<HistoryMessagePosition> historyPosition,
    required ValueNotifier<bool> userScrolling,
  }) {
    if (!identical(_openPageHistoryPosition, historyPosition)) {
      return;
    }
    final convId = _openPageConvId;
    if (convId != null && convId.isNotEmpty) {
      _historyMessagePositionMap[convId] = historyPosition.value;
    }
    _openPageHistoryPosition = null;
    _openPageUserScrolling = null;
    _openPageConvId = null;
    _isChatListUserScrolling = false;
  }

  void _storeHistoryMessagePosition(
    String conversationID,
    HistoryMessagePosition position,
  ) {
    final convId = _safeConversationId(conversationID);
    if (convId.isEmpty) {
      return;
    }
    _historyMessagePositionMap[convId] = position;
    final page = _openPageHistoryPosition;
    final pageConv = _openPageConvId;
    if (page != null &&
        pageConv != null &&
        _isSameConversationID(convId, pageConv) &&
        page.value != position) {
      page.value = position;
    }
  }

  bool get shouldAnimateInboundPresentation =>
      _chatAppForeground &&
      DateTime.now().millisecondsSinceEpoch >= _suppressInboundAnimationUntilMs;

  void setChatAppLifecycleState(AppLifecycleState state) {
    final wasForeground = _chatAppForeground;
    final foreground = state == AppLifecycleState.resumed;
    _chatAppForeground = foreground;
    if (foreground && !wasForeground) {
      // Resume recovery may merge a large server-side backlog over several
      // asynchronous callbacks. Treat that window as synchronization, not as
      // a sequence of newly arriving foreground messages.
      _suppressInboundAnimationUntilMs =
          DateTime.now().millisecondsSinceEpoch + 5000;
    }

    final convId = currentSelectedConv.trim();
    if (convId.isNotEmpty && !foreground) {
      // Rows not yet presented stay deferred. Do not reveal the queue while
      // transitioning to background, otherwise it will be replayed on resume.
      _inboundChunkReveal.cancelToBuffer(convId);
    }
    _messageEnterAnimationKeys.clear();
    _markNeedsNotify();
  }

  bool isBulkMessageSyncActive([String? conversationID]) {
    if (conversationID != null) {
      final convId = _safeConversationId(conversationID);
      return (_bulkMessageSyncDepthByConv[convId] ?? 0) > 0;
    }
    return _bulkMessageSyncDepthByConv.values.any((depth) => depth > 0);
  }

  void _beginBulkMessageSync(String conversationID) {
    final convId = _safeConversationId(conversationID);
    if (convId.isEmpty) {
      return;
    }
    _bulkMessageSyncDepthByConv[convId] =
        (_bulkMessageSyncDepthByConv[convId] ?? 0) + 1;
    ChatJitterDiag.log(
      'bulk_message_sync_begin',
      conv: convId,
      extras: <String, Object?>{
        'depth': _bulkMessageSyncDepthByConv[convId],
      },
    );
  }

  void _endBulkMessageSync(String conversationID) {
    final convId = _safeConversationId(conversationID);
    if (convId.isEmpty) {
      return;
    }
    final next = (_bulkMessageSyncDepthByConv[convId] ?? 0) - 1;
    if (next <= 0) {
      _bulkMessageSyncDepthByConv.remove(convId);
    } else {
      _bulkMessageSyncDepthByConv[convId] = next;
    }
    ChatJitterDiag.log(
      'bulk_message_sync_end',
      conv: convId,
      extras: <String, Object?>{
        'depth': _bulkMessageSyncDepthByConv[convId] ?? 0,
      },
    );
    _flushDeferredPinToBottom(convId);
  }

  void _flushDeferredPinToBottom(String conversationID) {
    final convId = _safeConversationId(conversationID);
    if (convId.isEmpty) {
      return;
    }
    if (!isBulkMessageSyncActive(convId) &&
        !isChunkedRevealActive(convId) &&
        (_pendingPinAfterBulkByConv.remove(convId) ?? false)) {
      requestPinToBottom(convId, force: true);
    }
  }

  bool isChunkedRevealActive([String? conversationID]) {
    if (conversationID != null) {
      return _inboundChunkReveal.isActiveFor(conversationID);
    }
    return _inboundChunkReveal.pendingCountFor(currentSelectedConv) > 0 ||
        _inboundChunkReveal.isActiveFor(currentSelectedConv);
  }

  /// Acknowledges that the message list finished laying out and animating the
  /// currently revealed projection group. The next group is not exposed until
  /// this acknowledgement, so burst traffic can never stack row controllers.
  void completeInboundProjectionReveal(String conversationID) {
    _inboundChunkReveal.completeCurrentReveal(conversationID);
  }

  bool isInboundProjectionRevealWaiting(String conversationID) =>
      _inboundChunkReveal.isWaitingForTransaction(conversationID);

  int pendingInboundProjectionCount(String conversationID) =>
      _inboundChunkReveal.pendingCountFor(conversationID);

  bool consumeInboundFastForwardFlag(V2TimMessage message) {
    return _inboundFastForwardMessageKeys.remove(messageDedupKey(message));
  }

  void cancelInboundProjectionRevealToBuffer(String conversationID) {
    _inboundChunkReveal.cancelToBuffer(conversationID);
  }

  @Deprecated('Use isChunkedRevealActive')
  bool isPacedRevealActive([String? conversationID]) =>
      isChunkedRevealActive(conversationID);

  int get inboundScrollFollowSeq => _inboundScrollFollowSeq;

  /// Bumped when paced reveal cancels an in-flight push so only the newest
  /// message keeps its animation. Message list should abort without acking.
  int get inboundPresentationSupersedeSeq => _inboundPresentationSupersedeSeq;

  bool get inboundScrollFollowSessionEnding =>
      _inboundScrollFollowSessionEnding;

  List<V2TimMessage> get lastInboundScrollFollowChunk =>
      _lastInboundScrollFollowChunk;

  int messageListRevisionFor(String conversationID) =>
      _messageListRevisionByConv[conversationID] ?? 0;

  int messageProjectionRevisionFor(String conversationID) =>
      _messageProjectionRevisionByConv[_inboundStateKey(conversationID)] ?? 0;

  String _authoritativeDeferredKey(
    String conversationID,
    V2TimMessage message,
  ) {
    final normalized = _normalizeConversationID(conversationID);
    final convKey = normalized.isEmpty ? conversationID : normalized;
    return '$convKey|${messageDedupKey(message)}';
  }

  void _revealDeferredProjectionAcrossAliases(
    String conversationID,
    Iterable<V2TimMessage> messages,
  ) {
    final snapshot = List<V2TimMessage>.from(messages);
    if (snapshot.isEmpty) {
      return;
    }
    _revealInboundProjectionChunk(conversationID, snapshot);
    final pendingKeys = snapshot.map(messageDedupKey).toSet();
    for (final alias in List<String>.from(_inboundHiddenKeysByConv.keys)) {
      if (alias == conversationID) {
        continue;
      }
      final hidden = _inboundHiddenKeysByConv[alias];
      if (hidden == null || !hidden.any(pendingKeys.contains)) {
        continue;
      }
      _revealInboundProjectionChunk(alias, snapshot);
    }
  }

  void _hideInboundProjection(
    String conversationID,
    Iterable<V2TimMessage> messages,
  ) {
    final convKey = _inboundStateKey(conversationID);
    final hidden = _inboundHiddenKeysByConv.putIfAbsent(
      convKey,
      () => <String>{},
    );
    for (final message in messages) {
      hidden.add(messageDedupKey(message));
    }
  }

  bool _revealInboundProjectionChunk(
    String conversationID,
    Iterable<V2TimMessage> messages,
  ) {
    final convKey = _inboundStateKey(conversationID);
    final hidden = _inboundHiddenKeysByConv[convKey];
    if (hidden == null || hidden.isEmpty) {
      return false;
    }
    var changed = false;
    for (final message in messages) {
      changed = hidden.remove(messageDedupKey(message)) || changed;
    }
    if (hidden.isEmpty) {
      _inboundHiddenKeysByConv.remove(convKey);
    }
    if (changed) {
      _bumpMessageProjectionRevisionFor(convKey);
    }
    return changed;
  }

  bool _revealAllInboundProjection(String conversationID) {
    final convKey = _inboundStateKey(conversationID);
    final hidden = _inboundHiddenKeysByConv.remove(convKey);
    _authoritativeDeferredIncomingKeys.removeWhere(
      (key) => key.startsWith('$convKey|'),
    );
    if (hidden == null || hidden.isEmpty) {
      return false;
    }
    _bumpMessageProjectionRevisionFor(convKey);
    return true;
  }

  bool _revealAllDeferredProjectionAcrossAliases(String conversationID) {
    var changed = false;
    final aliases = List<String>.from(_inboundHiddenKeysByConv.keys);
    for (final alias in aliases) {
      if (_isSameConversationID(alias, conversationID)) {
        changed = _revealAllInboundProjection(alias) || changed;
      }
    }
    // Also clears authoritative deferred keys when no projection alias remains.
    changed = _revealAllInboundProjection(conversationID) || changed;
    return changed;
  }

  void _bumpMessageProjectionRevisionFor(String conversationID) {
    final convKey = _inboundStateKey(conversationID);
    _messageProjectionRevisionByConv[convKey] =
        (_messageProjectionRevisionByConv[convKey] ?? 0) + 1;
    _messageListDisplayCache.removeWhere(
      (key, _) => _isSameConversationID(key, convKey),
    );
  }

  void _bumpMessageListRevisionFor(String conversationID,
      {String reason = ''}) {
    final next = (_messageListRevisionByConv[conversationID] ?? 0) + 1;
    _messageListRevisionByConv[conversationID] = next;
    // 与投影 revision 一致：按等价会话 ID 清展示缓存，避免群 ID 别名打空洞。
    _messageListDisplayCache.removeWhere(
      (key, _) => _isSameConversationID(key, conversationID),
    );
    // 仅「绕过 setMessageList 的原地改表」清签名，迫使下次 setMessageList 再比对。
    // setMessageList 自己 bump 时绝不能清：否则刚写入的签名立刻失效，
    // 进页 hydrate / loadLatest 原样回写会每次都 signatureChanged→再 bump→整表抖。
    final fromSetMessageList = reason == 'setMessageList_signature' ||
        reason == 'setMessageList_delete';
    if (!fromSetMessageList) {
      _messageListContentSignatureByConv.remove(conversationID);
    }
    ChatJitterDiag.log(
      'message_list_revision_bump',
      conv: conversationID,
      extras: <String, Object?>{
        'rev': next,
        'reason': reason.isEmpty ? 'unspecified' : reason,
        'stack': ChatJitterDiag.compactStack(),
      },
    );
  }

  void _scheduleNotifyListeners() {
    if (_notifyScheduled) {
      return;
    }
    _notifyScheduled = true;
    scheduleMicrotask(() {
      _notifyScheduled = false;
      if (!_notifyPending) {
        return;
      }
      _notifyPending = false;
      notifyListeners();
    });
  }

  void _markNeedsNotify() {
    _notifyPending = true;
    _scheduleNotifyListeners();
  }

  bool isOutgoingMediaCancelled(String? id) {
    if (id == null || id.isEmpty) {
      return false;
    }
    return _cancelledOutgoingMediaIds.contains(id);
  }

  void markOutgoingMediaCancelled(String? id) {
    if (id != null && id.isNotEmpty) {
      _cancelledOutgoingMediaIds.add(id);
    }
  }

  void clearOutgoingMediaCancelled(String? id) {
    if (id != null && id.isNotEmpty) {
      _cancelledOutgoingMediaIds.remove(id);
    }
  }

  int _normalizedOutgoingStatus(V2TimMessage item, int? fallback) {
    final status =
        item.status ?? fallback ?? MessageStatus.V2TIM_MSG_STATUS_SEND_SUCC;
    if (status == MessageStatus.V2TIM_MSG_STATUS_SENDING &&
        (item.msgID?.isNotEmpty ?? false)) {
      return MessageStatus.V2TIM_MSG_STATUS_SEND_SUCC;
    }
    return status;
  }

  V2TimMessage? _messageInConversation(
    String conversationID, {
    String? clientId,
    String? msgID,
  }) {
    final list = _messageListMap[conversationID];
    if (list == null || list.isEmpty) {
      return null;
    }
    for (final item in list) {
      if (clientId != null &&
          clientId.isNotEmpty &&
          item.id != null &&
          item.id == clientId) {
        return item;
      }
      if (msgID != null &&
          msgID.isNotEmpty &&
          item.msgID != null &&
          item.msgID == msgID) {
        return item;
      }
    }
    return null;
  }

  int _receiptTimestamp(int value) {
    if (value > 1000000000000) {
      return value ~/ 1000;
    }
    return value;
  }

  V2TimMessage? messageInConversationByKey(
    String conversationID,
    String messageKey,
  ) {
    final key = messageKey.trim();
    if (key.isEmpty) {
      return null;
    }
    final list = _messageListMap[conversationID];
    if (list == null || list.isEmpty) {
      return null;
    }
    for (final item in list) {
      if (item.msgID == key || item.id == key) {
        return item;
      }
      final seq = item.seq?.trim();
      if (seq != null && seq.isNotEmpty && 'seq_$seq' == key) {
        return item;
      }
      if (ChatUiStateStore.messageKeyOf(item) == key) {
        return item;
      }
    }
    return null;
  }

  void _markMessageRowChanged(
    String conversationID,
    V2TimMessage message, {
    String? extraKey,
  }) {
    final keys = <String>{
      ChatUiStateStore.messageKeyOf(message),
    };
    final msgID = message.msgID?.trim();
    if (msgID != null && msgID.isNotEmpty) {
      keys.add(msgID);
    }
    final id = message.id?.trim();
    if (id != null && id.isNotEmpty) {
      keys.add(id);
    }
    final seq = message.seq?.trim();
    if (seq != null && seq.isNotEmpty) {
      keys.add('seq_$seq');
    }
    final key = extraKey?.trim();
    if (key != null && key.isNotEmpty) {
      keys.add(key);
    }
    _chatUiStateStore.markMessagesChanged(conversationID, keys);
  }

  void _markMessageRowChangedByIds(
    String conversationID, {
    String? msgID,
    String? clientId,
  }) {
    final keys = <String>{};
    final mid = msgID?.trim();
    if (mid != null && mid.isNotEmpty) {
      keys.add(mid);
    }
    final cid = clientId?.trim();
    if (cid != null && cid.isNotEmpty) {
      keys.add(cid);
    }
    final message = _messageInConversation(
      conversationID,
      clientId: cid,
      msgID: mid,
    );
    if (message != null) {
      keys.add(ChatUiStateStore.messageKeyOf(message));
      final messageId = message.id?.trim();
      if (messageId != null && messageId.isNotEmpty) {
        keys.add(messageId);
      }
      final messageMsgID = message.msgID?.trim();
      if (messageMsgID != null && messageMsgID.isNotEmpty) {
        keys.add(messageMsgID);
      }
    }
    if (keys.isNotEmpty) {
      _chatUiStateStore.markMessagesChanged(conversationID, keys);
    }
  }

  void _markMessageRowsChangedByMsgID(String msgID) {
    final key = msgID.trim();
    if (key.isEmpty) {
      return;
    }
    for (final entry in _messageListMap.entries.toList()) {
      final list = entry.value;
      if (list == null || list.isEmpty) {
        continue;
      }
      for (final message in list) {
        if (message.msgID == key || message.id == key) {
          _markMessageRowChanged(entry.key, message, extraKey: key);
        }
      }
    }
  }

  void markMessageRowsChangedByMsgIDs(Iterable<String?> msgIDs) {
    final keys = msgIDs
        .whereType<String>()
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toSet();
    if (keys.isEmpty) {
      return;
    }
    for (final key in keys) {
      _markMessageRowsChangedByMsgID(key);
    }
  }

  int messageStatusInConversation(
    String conversationID, {
    String? clientId,
    String? msgID,
    int? fallback,
    int? elemType,
  }) {
    final list = _messageListMap[conversationID];
    if (list == null || list.isEmpty) {
      return fallback ?? MessageStatus.V2TIM_MSG_STATUS_SEND_SUCC;
    }
    for (final item in list) {
      if (clientId != null &&
          clientId.isNotEmpty &&
          item.id != null &&
          item.id == clientId) {
        return _normalizedOutgoingStatus(item, fallback);
      }
      if (msgID != null &&
          msgID.isNotEmpty &&
          item.msgID != null &&
          item.msgID == msgID) {
        return _normalizedOutgoingStatus(item, fallback);
      }
    }
    if (fallback == MessageStatus.V2TIM_MSG_STATUS_SENDING) {
      final hasSelfSending = list.any(
        (item) =>
            item.isSelf == true &&
            item.status == MessageStatus.V2TIM_MSG_STATUS_SENDING &&
            !(item.msgID?.isNotEmpty ?? false) &&
            (elemType == null || item.elemType == elemType),
      );
      if (!hasSelfSending) {
        return MessageStatus.V2TIM_MSG_STATUS_SEND_SUCC;
      }
      return MessageStatus.V2TIM_MSG_STATUS_SENDING;
    }
    return fallback ?? MessageStatus.V2TIM_MSG_STATUS_SEND_SUCC;
  }

  void applyOutgoingSendResult(
    V2TimValueCallback<V2TimMessage> sendMsgRes,
    String convID,
    String clientId,
    ConvType convType,
    GroupReceiptAllowType? groupType,
    ValueChanged<String>? setInputField,
  ) {
    final dataMsgID = sendMsgRes.data?.msgID;
    if (isOutgoingMediaCancelled(clientId) ||
        isOutgoingMediaCancelled(dataMsgID)) {
      return;
    }
    try {
      updateMessage(
        sendMsgRes,
        convID,
        clientId,
        convType,
        groupType,
        setInputField,
      );
    } catch (e) {
      outputLogger.i('updateMessage error: $e');
    }
  }

  void setChatListUserScrolling(bool scrolling) {
    final page = _openPageUserScrolling;
    if (page != null) {
      if (page.value != scrolling) {
        page.value = scrolling;
      }
    } else {
      _isChatListUserScrolling = scrolling;
    }
    if (scrolling) {
      final convId = _safeConversationId(currentSelectedConv);
      if (convId.isNotEmpty && _inboundChunkReveal.isActiveFor(convId)) {
        _inboundChunkReveal.cancelToBuffer(convId);
      }
    }
  }

  TUIChatGlobalModel() {
    _inboundBatchCoalescer = MessageInboundBatchCoalescer(
      maxBatchSize: _inboundBatchMaxSize,
      maxDelay: _inboundBatchMaxDelay,
      onFlush: _flushInboundMessageBatch,
    );
    _inboundChunkReveal = MessageInboundChunkedReveal(
      interval: Duration(milliseconds: chatConfig.inboundChunkRevealIntervalMs),
      maxChunkSize: chatConfig.inboundChunkRevealMaxChunk,
      alignToFrame: true,
      burstBoostChunk: 0,
      // Under sustained traffic, commit stale presentation work immediately
      // and keep only the newest bubble for the visible push animation.
      maxAnimatedBacklog: 1,
      // Paced reveal is presentation-only. Keeping it outside bulk-sync allows
      // each released row to run its extent animation while chunk-active guards
      // still suppress competing list-push and pin paths.
      onSessionBegin: (_) {},
      onSessionEnd: (convId) {
        _inboundScrollFollowSessionEnding = true;
        _lastInboundScrollFollowChunk = const [];
        _inboundScrollFollowSeq++;
        _flushDeferredPinToBottom(convId);
        _markNeedsNotify();
      },
      onRevealChunk: (convId, chunk) {
        _lastInboundScrollFollowChunk = chunk;
        _inboundScrollFollowSessionEnding = false;
        _revealInboundProjectionChunk(convId, chunk);
        if (chunk.length == 1) {
          final message = chunk.first;
          if (message.isSelf != true &&
              _inboundChunkReveal.pendingCountFor(convId) == 0) {
            _markIncomingMessageEnterAnimation(message);
          }
        }
        _inboundScrollFollowSeq++;
        _markNeedsNotify();
      },
      onDrainRemaining: _drainChunkRevealToBuffer,
      onSupersede: (convId) {
        _inboundPresentationSupersedeSeq++;
        _markNeedsNotify();
      },
      onFastForward: (convId, messages) {
        for (final message in messages) {
          _inboundFastForwardMessageKeys.add(messageDedupKey(message));
        }
        _revealInboundProjectionChunk(convId, messages);
        _markNeedsNotify();
      },
    );
    advancedMsgListener = V2TimAdvancedMsgListener(
      onRecvC2CReadReceipt: (List<V2TimMessageReceipt> receiptList) {
        _onReceiveC2CReadReceipt(receiptList);
      },
      onRecvMessageRevoked: (String msgID) {
        onMessageRevoked(msgID);
      },
      onRecvNewMessage: (V2TimMessage newMsg) {
        _onReceiveNewMsg(newMsg);
      },
      onSendMessageProgress: (V2TimMessage messagae, int progress) {
        _onSendMessageProgress(messagae, progress);
      },
      onRecvMessageReadReceipts: (List<V2TimMessageReceipt> receiptList) {
        _onReceiveMessageReadReceipts(receiptList);
      },
      onRecvMessageModified: (V2TimMessage newMsg) {
        onMessageModified(newMsg);
      },
      onMessageDownloadProgressCallback:
          (V2TimMessageDownloadProgress messageProgress) {
        onMessageDownloadProgressCallback(messageProgress);
      },
    );
  }

  bool get isDownloading => _isDownloading;

  bool get hasWaiting => _waitingDownloadList.isNotEmpty;

  Map<String, String> get currentDownLoad => _waitingDownloadList.first;

  int getWaitingListLength() {
    return _waitingDownloadList.length;
  }

  void addWaitingList(String msgID) {
    outputLogger.i("add to waiting list success");
    bool contains = false;
    for (Map<String, String> element in _waitingDownloadList) {
      String msgIDItem = element["msgID"] ?? "";
      if (msgIDItem.isNotEmpty) {
        if (msgID == msgIDItem) {
          contains = true;
          break;
        }
      }
    }
    if (!contains) {
      _waitingDownloadList.add(Map.from({
        "msgID": msgID,
      }));
      // setMessageProgress(msgID, 1); // 有一点进度条，表示等待中
    }
  }

  downloadFile() async {
    if (_isDownloading || _waitingDownloadList.isEmpty) {
      return;
    }

    final nextDownload = _waitingDownloadList.first;
    final msgID = nextDownload["msgID"] ?? "";
    if (msgID.isEmpty || _messageListProgressMap[msgID] == 100) {
      return;
    }

    _isDownloading = true;
    await _messageService.downloadMessage(
      msgID: msgID,
      messageType: 6,
      imageType: 0,
      isSnapshot: false,
    );

    outputLogger.i("start another download");
  }

  int getReceived(msgID) {
    return messageListProgressMap[msgID] ?? 0;
  }

  bool isWaiting(String msgID) {
    return _waitingDownloadList.where((element) {
      String msgIDItem = element["msgID"] ?? "";
      if (msgIDItem.isNotEmpty) {
        if (msgID == msgIDItem) {
          return true;
        }
      }
      return false;
    }).isNotEmpty;
  }

  Map<String, int> get messageListProgressMap {
    return _messageListProgressMap;
  }

  Map<String, List<V2TimMessage>?> get messageListMap {
    return _messageListMap;
  }

  String _normalizeMergerCacheKey(String? key) {
    return key?.trim() ?? '';
  }

  void cacheLocalMergerMessageList({
    required Iterable<String?> keys,
    required List<V2TimMessage> messages,
  }) {
    if (messages.isEmpty) {
      return;
    }
    final normalizedKeys = keys
        .map(_normalizeMergerCacheKey)
        .where((item) => item.isNotEmpty)
        .toSet();
    if (normalizedKeys.isEmpty) {
      return;
    }
    final cached = messages.map(_cloneMessage).toList(growable: false);
    for (final key in normalizedKeys) {
      _localMergerMessageCache[key] = cached;
    }
  }

  void bindLocalMergerMessageKeys({
    required String? sourceKey,
    required Iterable<String?> keys,
  }) {
    final source = _normalizeMergerCacheKey(sourceKey);
    if (source.isEmpty) {
      return;
    }
    final cached = _localMergerMessageCache[source];
    if (cached == null || cached.isEmpty) {
      return;
    }
    cacheLocalMergerMessageList(keys: keys, messages: cached);
  }

  List<V2TimMessage>? getLocalMergerMessageList(String? key) {
    final normalized = _normalizeMergerCacheKey(key);
    if (normalized.isEmpty) {
      return null;
    }
    final cached = _localMergerMessageCache[normalized];
    if (cached == null || cached.isEmpty) {
      return null;
    }
    return cached.map(_cloneMessage).toList(growable: false);
  }

  int get totalUnReadCount {
    return _totalUnreadCount;
  }

  set totalUnReadCount(int newValue) {
    _totalUnreadCount = newValue;
    notifyListeners();
  }

  String _inboundStateKey(String? conversationID) {
    final safe = _safeConversationId(conversationID).trim();
    final normalized = _normalizeConversationID(safe);
    return normalized.isEmpty ? safe : normalized;
  }

  _InboundUnreadState _inboundUnreadStateFor(
    String? conversationID, {
    bool create = true,
  }) {
    final key = _inboundStateKey(conversationID);
    if (!create) {
      return _inboundUnreadStateByConversation[key] ?? _InboundUnreadState();
    }
    return _inboundUnreadStateByConversation.putIfAbsent(
      key,
      _InboundUnreadState.new,
    );
  }

  int unreadCountForTongueFor(String conversationID) =>
      _inboundUnreadStateFor(conversationID, create: false).unreadCount;

  int lockedEntryUnreadCountFor(String conversationID) =>
      _inboundUnreadStateFor(
        conversationID,
        create: false,
      ).lockedEntryUnreadCount;

  int get receivedNewMessageCount =>
      _inboundUnreadStateFor(currentSelectedConv, create: false).receivedCount;

  set receivedNewMessageCount(int value) {
    _inboundUnreadStateFor(currentSelectedConv).receivedCount = value;
  }

  int get unreadCountForTongue => unreadCountForTongueFor(currentSelectedConv);

  int get lockedEntryUnreadCount =>
      lockedEntryUnreadCountFor(currentSelectedConv);

  bool get hasLockedEntryUnread => lockedEntryUnreadCount > 0;

  bool hasLockedEntryUnreadFor(String conversationID) {
    return lockedEntryUnreadCountFor(conversationID) > 0;
  }

  set unreadCountForTongue(int value) {
    setUnreadCountForTongue(value);
  }

  void lockEntryUnreadForTongue({
    required String conversationID,
    required int unreadCount,
    bool notify = true,
  }) {
    final convId = _normalizeConversationID(conversationID);
    if (convId.isEmpty || unreadCount <= 0) {
      return;
    }
    final state = _inboundUnreadStateFor(convId);
    state.lockedEntryUnreadCount = unreadCount;
    state.unreadCount = unreadCount;
    _dismissedEntryUnreadTongueCountByConversation.remove(convId);
    if (conversationID != convId) {
      _dismissedEntryUnreadTongueCountByConversation.remove(conversationID);
    }
    setUnreadTongueMetrics(
      conversationID: convId,
      remaining: unreadCount,
      below: false,
      notify: notify,
    );
  }

  void unlockEntryUnreadForTongue({
    String? conversationID,
    bool notify = true,
  }) {
    final convId = _inboundStateKey(conversationID);
    if (_deferredUntilUserBottomConversations.contains(convId)) {
      return;
    }
    final state = _inboundUnreadStateFor(convId, create: false);
    if (state.lockedEntryUnreadCount <= 0 && state.unreadCount <= 0) {
      return;
    }
    state.clear();
    _inboundUnreadStateByConversation.remove(convId);
    if (notify) {
      notifyListeners();
    }
  }

  void setUnreadCountForTongue(
    int value, {
    String? conversationID,
    bool notify = true,
  }) {
    final state = _inboundUnreadStateFor(conversationID);
    if (value == 0 && state.lockedEntryUnreadCount > 0) {
      return;
    }
    state.unreadCount = value;
    if (notify) {
      notifyListeners();
    }
  }

  int get unreadTongueMetricsVersion => _unreadTongueMetricsVersion;

  int getUnreadTongueRemaining(String conversationID) {
    final normalized = _normalizeConversationID(conversationID);
    final direct = _unreadTongueRemainingByConversation[conversationID];
    if (direct != null) {
      return direct;
    }
    if (normalized.isNotEmpty) {
      final normalizedRemaining =
          _unreadTongueRemainingByConversation[normalized];
      if (normalizedRemaining != null) {
        return normalizedRemaining;
      }
    }
    return unreadCountForTongueFor(conversationID);
  }

  bool getUnreadTongueBelow(String conversationID) {
    final normalized = _normalizeConversationID(conversationID);
    if (_unreadTongueBelowByConversation.containsKey(conversationID)) {
      return _unreadTongueBelowByConversation[conversationID] ?? true;
    }
    if (normalized.isNotEmpty &&
        _unreadTongueBelowByConversation.containsKey(normalized)) {
      return _unreadTongueBelowByConversation[normalized] ?? true;
    }
    return true;
  }

  void setUnreadTongueMetrics({
    required String conversationID,
    required int remaining,
    required bool below,
    bool notify = true,
  }) {
    final convId = _normalizeConversationID(conversationID);
    if (convId.isEmpty) {
      return;
    }
    final safeRemaining = remaining < 0 ? 0 : remaining;
    if (_unreadTongueRemainingByConversation[convId] == safeRemaining &&
        _unreadTongueBelowByConversation[convId] == below) {
      return;
    }
    _unreadTongueRemainingByConversation[convId] = safeRemaining;
    _unreadTongueBelowByConversation[convId] = below;
    _unreadTongueMetricsVersion++;
    if (notify) {
      notifyListeners();
    }
  }

  void clearUnreadTongueMetrics(String conversationID, {bool notify = false}) {
    if (conversationID.isEmpty) {
      return;
    }
    final convId = _inboundStateKey(conversationID);
    final removedRemaining =
        _unreadTongueRemainingByConversation.remove(convId) != null;
    final removedBelow =
        _unreadTongueBelowByConversation.remove(convId) != null;
    final changed = removedRemaining || removedBelow;
    if (changed) {
      _unreadTongueMetricsVersion++;
      if (notify) {
        notifyListeners();
      }
    }
  }

  int getDismissedEntryUnreadTongueCount(String conversationID) {
    return _dismissedEntryUnreadTongueCountByConversation[
            _inboundStateKey(conversationID)] ??
        0;
  }

  void markEntryUnreadTongueDismissed({
    required String conversationID,
    required int unreadCount,
    bool notify = false,
  }) {
    final convId = _inboundStateKey(conversationID);
    if (convId.isEmpty) {
      return;
    }
    final safeCount = unreadCount < 0 ? 0 : unreadCount;
    final previous =
        _dismissedEntryUnreadTongueCountByConversation[convId] ?? 0;
    if (safeCount <= previous) {
      return;
    }
    _dismissedEntryUnreadTongueCountByConversation[convId] = safeCount;
    if (notify) {
      notifyListeners();
    }
  }

  void clearEntryUnreadTongueDismissed(String conversationID,
      {bool notify = false}) {
    final convId = _inboundStateKey(conversationID);
    if (convId.isEmpty) {
      return;
    }
    final changed =
        _dismissedEntryUnreadTongueCountByConversation.remove(convId) != null;
    if (changed && notify) {
      notifyListeners();
    }
  }

  void clearReceivedUnreadState({
    String? conversationID,
    bool notify = false,
  }) {
    final convId = _inboundStateKey(conversationID);
    if (_deferredUntilUserBottomConversations.contains(convId)) {
      return;
    }
    final state = _inboundUnreadStateFor(convId, create: false);
    if (state.lockedEntryUnreadCount > 0) {
      return;
    }
    state.clear();
    _inboundUnreadStateByConversation.remove(convId);
    _dismissedEntryUnreadTongueCountByConversation.remove(convId);
    if (notify) {
      notifyListeners();
    }
  }

  bool _shouldDeferIncomingToVisibleList(
    String convID, {
    required HistoryMessagePosition position,
    required bool isActuallyNearBottom,
  }) {
    if (!_isSameConversationID(convID, currentSelectedConv)) {
      return false;
    }
    // 长按菜单打开时：即便贴底也先缓冲，避免背景列表被新消息顶走。
    if (isMessageContextMenuOverlayOpen) {
      return true;
    }
    // 已离开底部超过约一屏（「回到底部」应出现）：新消息只缓冲，不再上推。
    if (_isActiveChatAwayOneScreen(convID)) {
      return true;
    }
    if (isActuallyNearBottom) {
      return false;
    }
    if (position == HistoryMessagePosition.bottom &&
        unreadCountForTongue == 0) {
      return false;
    }
    return true;
  }

  void _bufferIncomingWhileReadingAway(
    String convID,
    V2TimMessage mountedMessage, {
    required String route,
    required HistoryMessagePosition position,
    required bool isActuallyNearBottom,
  }) {
    if (!_chatAppForeground) {
      final normalizedConvId = _inboundStateKey(convID);
      _deferredUntilUserBottomConversations.add(normalizedConvId);
      _storeHistoryMessagePosition(
        normalizedConvId,
        HistoryMessagePosition.notShowLatest,
      );
    }
    final state = _inboundUnreadStateFor(convID);
    final messageKey = messageDedupKey(mountedMessage);
    if (!state.bufferedMessageKeys.add(messageKey)) {
      return;
    }
    state.unreadCount++;
    state.receivedCount++;
    state.bufferedMessages.add(mountedMessage);
    ChatJitterDiag.logReadingHistoryIncoming(
      action: 'route_buffer',
      conv: convID,
      extras: <String, Object?>{
        'route': route,
        'position': position.name,
        'nearBottom': isActuallyNearBottom,
        'tongueUnread': state.unreadCount,
        'bufferedLen': state.bufferedMessages.length,
        'msgId': mountedMessage.msgID,
      },
    );
    _markNeedsNotify();
  }

  /// 将看历史期间缓冲的新消息合并进可见列表（回到底部 / 点未读条时调用）。
  bool flushDeferredIncomingMessages(
    String convID, {
    bool notify = true,
    bool userInitiated = false,
  }) {
    final normalizedConvId = _inboundStateKey(convID);
    if (_deferredUntilUserBottomConversations.contains(normalizedConvId) &&
        !userInitiated) {
      return false;
    }
    if (userInitiated) {
      if (_inboundChunkReveal.isActiveFor(convID)) {
        _inboundChunkReveal.cancelToBuffer(convID);
      } else if (_inboundChunkReveal.isActiveFor(normalizedConvId)) {
        _inboundChunkReveal.cancelToBuffer(normalizedConvId);
      }
      _deferredUntilUserBottomConversations.remove(normalizedConvId);
    }
    final projectionRevealed = userInitiated
        ? _revealAllDeferredProjectionAcrossAliases(convID)
        : false;
    final state = _inboundUnreadStateFor(normalizedConvId, create: false);
    if (state.bufferedMessages.isEmpty) {
      if (projectionRevealed && notify) {
        _markNeedsNotify();
      }
      return projectionRevealed;
    }
    final pending = List<V2TimMessage>.from(state.bufferedMessages);
    state.bufferedMessages.clear();
    state.bufferedMessageKeys.clear();
    final alreadyAuthoritative = <V2TimMessage>[];
    final needsUpsert = <V2TimMessage>[];
    for (final message in pending) {
      final key = _authoritativeDeferredKey(convID, message);
      if (_authoritativeDeferredIncomingKeys.remove(key)) {
        alreadyAuthoritative.add(message);
      } else {
        needsUpsert.add(message);
      }
    }
    _revealDeferredProjectionAcrossAliases(convID, alreadyAuthoritative);
    final storageKey = _resolveMessageListStorageKey(convID);
    final result = _upsertIncomingMessageBatch(storageKey, needsUpsert);
    if (result.inserted) {
      _bumpMessageListRevisionFor(
        storageKey,
        reason: 'flush_deferred_batch',
      );
    }
    ChatJitterDiag.logReadingHistoryIncoming(
      action: 'flush_deferred',
      conv: storageKey,
      extras: <String, Object?>{
        'count': pending.length,
        'listLen': _messageListMap[storageKey]?.length,
      },
    );
    if (notify) {
      _markNeedsNotify();
    }
    return true;
  }

  List<V2TimGroupApplication> get groupApplicationList =>
      _groupApplicationList ?? [];
  List<GroupSystemNoticeItem> get groupSystemNoticeList =>
      _groupSystemNoticeList;

  String Function(V2TimMessage message)? get abstractMessageBuilder =>
      _abstractMessageBuilder;

  Widget Function(
    BuildContext context,
    TextEditingController controller,
    ValueChanged<String> onChanged,
  )? get appSearchBarBuilder => _appSearchBarBuilder;

  Widget Function(BuildContext context)? get appForwardSelectFriendPage =>
      _appForwardSelectFriendPage;

  Widget Function(BuildContext context)? get appForwardSelectGroupPage =>
      _appForwardSelectGroupPage;

  AppContactPresenceBridge Function(BuildContext context)?
      get appContactPresenceBridgeBuilder => _appContactPresenceBridgeBuilder;

  Map<String, V2TimMessageReceipt> get messageReadReceiptMap =>
      _messageReadReceiptMap;

  String get currentSelectedConv => _currentConversationList.isNotEmpty
      ? _currentConversationList[_currentConversationList.length - 1]
          .conversationID
      : "";

  ConvType? get currentSelectedConvType => _currentConversationList.isNotEmpty
      ? _currentConversationList[_currentConversationList.length - 1]
          .conversationType
      : null;

  String _normalizeConversationID(String? value) {
    var id = value?.trim() ?? '';
    if (id.isEmpty) {
      return '';
    }
    final lower = id.toLowerCase();
    if (lower.startsWith('c2c_')) {
      id = id.substring(4);
    } else if (lower.startsWith('group_')) {
      id = id.substring(6);
    } else if (id.startsWith('C2C')) {
      id = id.substring(3);
    } else if (id.startsWith('GROUP')) {
      id = id.substring(5);
    }
    return id;
  }

  bool _isSameConversationID(String? left, String? right) {
    final a = _normalizeConversationID(left);
    final b = _normalizeConversationID(right);
    if (a.isEmpty || b.isEmpty) {
      return false;
    }
    if (a == b) {
      return true;
    }
    // 社群短码与完整 `@TGS#_@TGS#` 等价（不引入 app 包依赖，仅做结构归一）。
    return _communityIdsEquivalent(a, b);
  }

  static bool _communityIdsEquivalent(String left, String right) {
    String shortOf(String raw) {
      var id = raw.trim();
      if (id.isEmpty) {
        return '';
      }
      final upper = id.toUpperCase();
      const prefix = '@TGS#_@TGS#';
      if (upper.startsWith(prefix)) {
        return id.substring(prefix.length);
      }
      final hash = id.indexOf('#');
      if (hash >= 0 && hash + 1 < id.length && upper.contains('TGS#')) {
        return id.substring(hash + 1);
      }
      if (id.startsWith('@')) {
        return id.substring(1);
      }
      return id;
    }

    final a = shortOf(left);
    final b = shortOf(right);
    return a.isNotEmpty && b.isNotEmpty && a == b;
  }

  String? _messageConversationID(V2TimMessage message) {
    final groupID = TencentUtils.checkString(message.groupID);
    if (groupID != null) {
      final normalized = _normalizeConversationID(groupID);
      return normalized.isNotEmpty ? normalized : groupID;
    }
    final userID = TencentUtils.checkString(message.userID);
    if (userID != null) {
      final normalized = _normalizeConversationID(userID);
      return normalized.isNotEmpty ? normalized : userID;
    }
    final sender = TencentUtils.checkString(message.sender);
    if (sender == null) {
      return null;
    }
    final normalized = _normalizeConversationID(sender);
    return normalized.isNotEmpty ? normalized : sender;
  }

  setCurrentConversation(CurrentConversation value, {bool notify = true}) {
    _currentConversationList.add(value);
    if (notify) {
      notifyListeners();
    }
  }

  clearCurrentConversation({bool notify = false}) {
    if (_currentConversationList.isNotEmpty) {
      final leaving = _currentConversationList.last.conversationID;
      _inboundBatchCoalescer.flushConversation(leaving);
      _inboundChunkReveal.flushConversation(leaving);
      _revealAllInboundProjection(leaving);
      // Buffered messages are not yet authoritative. Commit them before the
      // active conversation is removed so switching routes cannot lose rows.
      flushDeferredIncomingMessages(
        leaving,
        notify: false,
        userInitiated: true,
      );
      final stateKey = _inboundStateKey(leaving);
      _inboundUnreadStateByConversation.remove(stateKey);
      _deferredUntilUserBottomConversations.remove(stateKey);
    }
    if (_currentConversationList.isNotEmpty) {
      _currentConversationList.removeLast();
    }
    if (notify) {
      notifyListeners();
    }
  }

  /// History warm / open-gate keys: bare id + matching `group_` / `c2c_` shape.
  ///
  /// For group/community ids, always stamp both bare and `group_` so
  /// `@TGS#_@TGS#…` warm flags hit `group_@TGS#_@TGS#…` open reads.
  /// Do **not** invent both `group_` and `c2c_` for ambiguous bare ids.
  Set<String> _historyFlagKeys(String conversationID) {
    final trimmed = conversationID.trim();
    if (trimmed.isEmpty) {
      return const <String>{};
    }
    final normalized = _normalizeConversationID(trimmed);
    final keys = <String>{trimmed};
    if (normalized.isNotEmpty) {
      keys.add(normalized);
      final lower = trimmed.toLowerCase();
      if (lower.startsWith('group_')) {
        keys.add('group_$normalized');
      } else if (lower.startsWith('c2c_')) {
        keys.add('c2c_$normalized');
      } else if (_looksLikeGroupHistoryId(normalized)) {
        keys.add('group_$normalized');
      }
    }
    for (final mapKey in _messageListMap.keys) {
      if (_isSameConversationID(mapKey, trimmed)) {
        keys.add(mapKey);
      }
    }
    return keys;
  }

  bool _looksLikeGroupHistoryId(String id) {
    final value = id.trim();
    if (value.isEmpty) {
      return false;
    }
    final upper = value.toUpperCase();
    if (upper.contains('TGS#')) {
      return true;
    }
    // Community short token (has uppercase); keep in sync with app ChatIdFormat.
    final token = value.startsWith('@') ? value.substring(1) : value;
    if (token.isEmpty || token.toUpperCase().contains('TGS#')) {
      return false;
    }
    if (!RegExp(r'^[A-Za-z0-9_]+$').hasMatch(token)) {
      return false;
    }
    return RegExp(r'[A-Z]').hasMatch(token);
  }

  void _clearHistoryFlagsForConversation(String conversationID) {
    final trimmed = conversationID.trim();
    if (trimmed.isEmpty) {
      return;
    }
    _initialHistoryLoadedConvs.removeWhere(
      (key) => _isSameConversationID(key, trimmed),
    );
    _mayHaveOlderHistoryByConv
        .removeWhere((key, _) => _isSameConversationID(key, trimmed));
  }

  bool hasInitialHistoryLoaded(String conversationID) {
    final trimmed = conversationID.trim();
    if (trimmed.isEmpty) {
      return false;
    }
    if (_initialHistoryLoadedConvs.contains(trimmed)) {
      return true;
    }
    final normalized = _normalizeConversationID(trimmed);
    if (normalized.isNotEmpty &&
        _initialHistoryLoadedConvs.contains(normalized)) {
      return true;
    }
    for (final key in _initialHistoryLoadedConvs) {
      if (_isSameConversationID(key, trimmed)) {
        return true;
      }
    }
    return false;
  }

  void markInitialHistoryLoaded(String conversationID) {
    for (final key in _historyFlagKeys(conversationID)) {
      _initialHistoryLoadedConvs.add(key);
    }
  }

  void markInitialHistoryMayHaveOlder(
    String conversationID, {
    required bool mayHaveOlder,
  }) {
    final keys = _historyFlagKeys(conversationID);
    if (keys.isEmpty) {
      return;
    }
    if (mayHaveOlder) {
      for (final key in keys) {
        _mayHaveOlderHistoryByConv[key] = true;
      }
    } else {
      for (final key in keys) {
        _mayHaveOlderHistoryByConv.remove(key);
      }
    }
  }

  bool mayHaveOlderHistory(String conversationID) {
    final trimmed = conversationID.trim();
    if (trimmed.isEmpty) {
      return false;
    }
    if (_mayHaveOlderHistoryByConv[trimmed] == true) {
      return true;
    }
    final normalized = _normalizeConversationID(trimmed);
    if (normalized.isNotEmpty &&
        _mayHaveOlderHistoryByConv[normalized] == true) {
      return true;
    }
    for (final entry in _mayHaveOlderHistoryByConv.entries) {
      if (entry.value && _isSameConversationID(entry.key, trimmed)) {
        return true;
      }
    }
    return false;
  }

  /// Raw in-memory window for warm/open short-circuit (alias-aware).
  ///
  /// 若本 key 上是空 list、但等价别名仍有消息，优先返回非空别名窗——
  /// 否则 tip-strip / hydrate_keep_empty 写过的空占位会永远挡住真实暖窗（灰屏）。
  List<V2TimMessage>? rawMessageList(String conversationID) {
    final trimmed = conversationID.trim();
    if (trimmed.isEmpty) {
      return null;
    }
    List<V2TimMessage>? emptyPlaceholder;
    final direct = _messageListMap[trimmed];
    if (direct != null) {
      if (direct.isNotEmpty) {
        return direct;
      }
      emptyPlaceholder = direct;
    }
    final normalized = _normalizeConversationID(trimmed);
    if (normalized.isNotEmpty) {
      final byNorm = _messageListMap[normalized];
      if (byNorm != null && byNorm.isNotEmpty) {
        return byNorm;
      }
      emptyPlaceholder ??= byNorm;
    }
    for (final entry in _messageListMap.entries) {
      if (!_isSameConversationID(entry.key, trimmed)) {
        continue;
      }
      final aliasList = entry.value;
      if (aliasList == null) {
        continue;
      }
      if (aliasList.isNotEmpty) {
        return aliasList;
      }
      emptyPlaceholder ??= aliasList;
    }
    return emptyPlaceholder;
  }

  /// 是否仍有进页 hydrate / 冷开并行 peek 在飞（别名感知）。
  bool hasOpenHydrateInFlight(String conversationID) {
    return _findOpenHydrateInFlight(conversationID) != null;
  }

  Future<void>? _findOpenHydrateInFlight(String conversationID) {
    final trimmed = conversationID.trim();
    if (trimmed.isEmpty) {
      return null;
    }
    final direct = _openHydrateInFlightByConv[trimmed];
    if (direct != null) {
      return direct;
    }
    final normalized = _normalizeConversationID(trimmed);
    if (normalized.isNotEmpty) {
      final byNorm = _openHydrateInFlightByConv[normalized];
      if (byNorm != null) {
        return byNorm;
      }
    }
    for (final entry in _openHydrateInFlightByConv.entries) {
      if (_isSameConversationID(entry.key, trimmed)) {
        return entry.value;
      }
    }
    return null;
  }

  /// 聊天页 initState 启动的首屏灌入任务；hydrate 可短暂等待以避免 0→N 闪屏。
  void registerOpenHydrateInFlight(
    String conversationID,
    Future<void> future,
  ) {
    final key = conversationID.trim();
    if (key.isEmpty) {
      return;
    }
    final existing = _findOpenHydrateInFlight(key);
    final tracked = existing == null
        ? future
        : Future.wait<void>(<Future<void>>[existing, future]);
    // 主 key + 等价别名都挂上，避免 c2c_/group_/裸 id 互相等不到。
    for (final alias in _historyFlagKeys(key)) {
      _openHydrateInFlightByConv[alias] = tracked;
    }
    unawaited(
      tracked.whenComplete(() {
        for (final alias in _historyFlagKeys(key)) {
          if (identical(_openHydrateInFlightByConv[alias], tracked)) {
            _openHydrateInFlightByConv.remove(alias);
          }
        }
      }),
    );
  }

  Future<void> awaitOpenHydrateInFlight(
    String conversationID, {
    Duration timeout = const Duration(milliseconds: 450),
  }) async {
    final inFlight = _findOpenHydrateInFlight(conversationID);
    if (inFlight == null) {
      return;
    }
    try {
      await inFlight.timeout(timeout);
    } on TimeoutException {
      // hydrate 自行兜底。
    }
  }

  int rawMessageCount(String conversationID) {
    return rawMessageList(conversationID)?.length ?? 0;
  }

  void removeMessageList(String conversationID) {
    final normalized = _normalizeConversationID(conversationID);
    final keys = <String>{
      if (conversationID.trim().isNotEmpty) conversationID.trim(),
      if (normalized.isNotEmpty) normalized,
    };
    keys.addAll(
      _messageListMap.keys
          .where(
            (mapKey) =>
                keys.any((key) => _isSameConversationID(mapKey, key)),
          )
          .toList(growable: false),
    );
    // Drop every loaded/mayHaveOlder alias first — leftover flags after a wipe
    // make open path think the window is warm while map is empty (灰屏).
    _clearHistoryFlagsForConversation(conversationID);
    for (final key in keys) {
      _messageListMap.remove(key);
      _messageListContentSignatureByConv.remove(key);
      _historyMessagePositionMap.remove(key);
      _searchJumpStatusMap.remove(key);
      _messageListDisplayCache.removeWhere(
        (cacheKey, _) => _isSameConversationID(cacheKey, key),
      );
    }
    if (keys.isNotEmpty) {
      _markNeedsNotify();
    }
  }

  /// 清空聊天记录后的内存态：空列表 + 已加载完成。
  /// 必须保留 initialLoaded，否则消息列表会一直显示 bootstrapping 转圈。
  void clearLocalHistoryAsEmptyLoaded(String conversationID) {
    final normalized = _normalizeConversationID(conversationID);
    final keys = <String>{
      if (conversationID.trim().isNotEmpty) conversationID.trim(),
      if (normalized.isNotEmpty) normalized,
    };
    // hydrate / 预载会把同一份列表写在等价别名 key（如 group_ 前缀）下；
    // 只清字面 key 会留下旧窗口，再进页时被别名读回（清空后仍闪旧记录）。
    keys.addAll(
      _messageListMap.keys
          .where(
            (mapKey) =>
                keys.any((key) => _isSameConversationID(mapKey, key)),
          )
          .toList(growable: false),
    );
    for (final key in keys) {
      _messageListMap[key] = <V2TimMessage>[];
      _messageListContentSignatureByConv.remove(key);
      _initialHistoryLoadedConvs.add(key);
      _mayHaveOlderHistoryByConv.remove(key);
      _storeHistoryMessagePosition(key, HistoryMessagePosition.bottom);
      _searchJumpStatusMap.remove(key);
      // 展示层缓存必须同步失效：否则清空后再进页，getMessageList 仍会
      // 命中旧缓存，把已清空的消息整窗闪现一帧再塌掉（进页「抖两次」）。
      _messageListDisplayCache.removeWhere(
        (cacheKey, _) => _isSameConversationID(cacheKey, key),
      );
    }
    if (keys.isNotEmpty) {
      _markNeedsNotify();
    }
  }

  SearchJumpStatus getSearchJumpStatus(String conversationID) {
    return _searchJumpStatusMap[conversationID] ?? SearchJumpStatus.idle;
  }

  void setSearchJumpStatus(
    String conversationID,
    SearchJumpStatus status, {
    bool notify = false,
  }) {
    if (status == SearchJumpStatus.idle) {
      _searchJumpStatusMap.remove(conversationID);
    } else {
      _searchJumpStatusMap[conversationID] = status;
    }
    if (notify) {
      notifyListeners();
    }
  }

  void clearSearchJumpStatus(String conversationID, {bool notify = false}) {
    setSearchJumpStatus(conversationID, SearchJumpStatus.idle, notify: notify);
  }

  V2TimMessageReceipt? getMessageReadReceipt(String msgID) {
    return messageReadReceiptMap[msgID];
  }

  String _normalizeC2CKey(String value) {
    var key = value.trim();
    if (key.isEmpty) {
      return key;
    }
    if (key.toLowerCase().startsWith('c2c_')) {
      return key.substring(4);
    }
    if (key.toUpperCase().startsWith('C2C')) {
      return key.substring(3);
    }
    return key;
  }

  bool _isC2CConversationForPeer(String conversationID, String peerID) {
    final conv = _normalizeC2CKey(conversationID).toLowerCase();
    final peer = _normalizeC2CKey(peerID).toLowerCase();
    if (conv.isEmpty || peer.isEmpty) {
      return false;
    }
    return conv == peer;
  }

  int _c2cPeerReadTimestampFor(String conversationID) {
    final convKey = _normalizeC2CKey(conversationID).toLowerCase();
    if (convKey.isEmpty) {
      return 0;
    }
    var timestamp = 0;
    _c2cPeerReadTimestampMap.forEach((peerID, readAt) {
      if (_normalizeC2CKey(peerID).toLowerCase() == convKey &&
          readAt > timestamp) {
        timestamp = readAt;
      }
    });
    return timestamp;
  }

  bool isOutgoingC2CMessagePeerRead({
    required String conversationID,
    required V2TimMessage message,
  }) {
    if (message.isSelf != true) {
      return false;
    }
    final current = _messageInConversation(
      conversationID,
      clientId: message.id,
      msgID: message.msgID,
    );
    if (current?.isPeerRead == true || message.isPeerRead == true) {
      return true;
    }

    final msgID = current?.msgID ?? message.msgID;
    if (msgID != null && msgID.isNotEmpty) {
      final receipt = _messageReadReceiptMap[msgID];
      if (receipt?.isPeerRead == true) {
        return true;
      }
    }

    final readAt = _c2cPeerReadTimestampFor(conversationID);
    if (readAt <= 0) {
      return false;
    }
    final sentAt = current?.timestamp ?? message.timestamp ?? 0;
    return sentAt > 0 && sentAt <= readAt;
  }

  setShowC2cEditStatus(bool show) {
    _showC2cMessageEditStatus = show;
  }

  /// set edit status from chats
  setC2cMessageEditStatus(String userID, int status) {
    _c2cMessageEditStatusMap[userID] = status;
    if (status == 1) {
      if (_c2cMessageStatusShowTimer[userID] != null) {
        if (_c2cMessageStatusShowTimer[userID]!.isActive) {
          _c2cMessageStatusShowTimer[userID]!.cancel();
          _c2cMessageEditStatusMap[userID] = 0;
        }
      }
      _c2cMessageStatusShowTimer[userID] =
          Timer.periodic(const Duration(seconds: 5), (timer) {
        _c2cMessageEditStatusMap[userID] = 0;
        Timer? t = _c2cMessageStatusShowTimer[userID];
        if (t != null && t.isActive) {
          // 取消当前的定时器
          t.cancel();
        }
      });
    }
    notifyListeners();
  }

  int getC2cMessageEditStatus(String userID) {
    return _c2cMessageEditStatusMap[userID] ?? 0;
  }

  set abstractMessageBuilder(String Function(V2TimMessage message)? value) {
    _abstractMessageBuilder = value;
  }

  set appSearchBarBuilder(
    Widget Function(
      BuildContext context,
      TextEditingController controller,
      ValueChanged<String> onChanged,
    )? value,
  ) {
    _appSearchBarBuilder = value;
  }

  set appForwardSelectFriendPage(Widget Function(BuildContext context)? value) {
    _appForwardSelectFriendPage = value;
  }

  set appForwardSelectGroupPage(Widget Function(BuildContext context)? value) {
    _appForwardSelectGroupPage = value;
  }

  set appContactPresenceBridgeBuilder(
    AppContactPresenceBridge Function(BuildContext context)? value,
  ) {
    _appContactPresenceBridgeBuilder = value;
  }

  set lifeCycle(ChatLifeCycle? value) {
    _lifeCycle = value;
    // messageShouldMount 变更后必须失效展示缓存，否则会继续用带「零高度行」的旧列表。
    _messageListDisplayCache.clear();
  }

  set groupApplicationList(List<V2TimGroupApplication> value) {
    _groupApplicationList = value;
  }

  void addGroupSystemNotice(GroupSystemNoticeItem notice) {
    _groupSystemNoticeList.removeWhere((item) => item.id == notice.id);
    _groupSystemNoticeList = [notice, ..._groupSystemNoticeList]
      ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
    notifyListeners();
  }

  setChatConfig(TIMUIKitChatConfig config) {
    chatConfig = config;
    _inboundChunkReveal.configure(
      interval: Duration(milliseconds: config.inboundChunkRevealIntervalMs),
      maxChunkSize: config.inboundChunkRevealMaxChunk,
      alignToFrame: true,
      burstBoostChunk: 0,
    );
  }

  initMessageMapFromLocalDatabase(
      List<V2TimConversation?> conversations) async {
    int index = 0;
    for (V2TimConversation? conversationItem in conversations) {
      if (conversationItem == null || conversationItem.type == null) {
        return;
      }
      final conversationID =
          TencentUtils.checkString(conversationItem.userID) ??
              TencentUtils.checkString(conversationItem.groupID) ??
              conversationItem.conversationID;
      if (messageListMap[conversationID] == null ||
          messageListMap[conversationID]!.isEmpty) {
        index++;
        Future.delayed(Duration(milliseconds: 500 * index), () {
          preloadMessageForConversation(
              conversationID: conversationID,
              conversationType: ConvType.values[conversationItem.type!]);
        });
      }
    }
  }

  preloadMessageForConversation({
    required ConvType conversationType,
    required String conversationID,
  }) async {
    final response = await _messageService.getHistoryMessageList(
        count: 10,
        getType: HistoryMsgGetTypeEnum.V2TIM_GET_LOCAL_OLDER_MSG,
        userID: conversationType == ConvType.c2c ? conversationID : null,
        groupID: conversationType == ConvType.group ? conversationID : null);
    if (_messageListMap[conversationID] == null ||
        _messageListMap[conversationID]!.isEmpty) {
      _messageListMap[conversationID] = response;
      // 会话列表预载时先种行高，进聊天页不再全靠 56 估。
      ChatMessageHeightCache.instance.seedEstimatesForMessages(response);
    }
  }

  clearMessageMapFromLocal() async {
    final prefs = await SharedPreferences.getInstance();
    final List<String>? localMsgIDList = prefs.getStringList(localMsgIDListKey);

    if (localMsgIDList != null) {
      for (String convID in localMsgIDList) {
        prefs.remove("$localKeyPrefix$convID");
      }
    }

    prefs.remove(localMsgIDListKey);
  }

  Future<void> updateMessageFromController(
      {required String msgID,
      required String conversationID,
      required ConvType conversationType}) async {
    final TUIChatModelTools tools = serviceLocator<TUIChatModelTools>();
    V2TimMessage? newMessage = await tools.getExistingMessageByID(
        msgID: msgID,
        conversationID: conversationID,
        conversationType: conversationType);
    if (newMessage != null) {
      onMessageModified(newMessage, currentSelectedConv);
    }
  }

  clearData() {
    _inboundBatchCoalescer.cancelAllSilently();
    _inboundChunkReveal.cancelAllSilently();
    _messageListMap.clear();
    _initialHistoryLoadedConvs.clear();
    _mayHaveOlderHistoryByConv.clear();
    _currentConversationList.clear();
    _totalUnreadCount = 0;
    _pendingGroupApplicationRefreshTimer?.cancel();
    _groupApplicationRefreshTask = null;
    _lastGroupApplicationRefreshAt = null;
    _groupApplicationList?.clear();
    _groupSystemNoticeList.clear();
    _totalUnreadCount = 0;
    _inboundUnreadStateByConversation.clear();
    _deferredUntilUserBottomConversations.clear();
    _messageReadReceiptMap.clear();
    _messageListProgressMap.clear();
    _localMergerMessageCache.clear();
    _messageProjectionRevisionByConv.clear();
    _messageListRevisionByConv.clear();
    _inboundHiddenKeysByConv.clear();
    _authoritativeDeferredIncomingKeys.clear();
    _inboundFastForwardMessageKeys.clear();
    _messageListDisplayCache.clear();
    _bulkMessageSyncDepthByConv.clear();
    _pendingPinAfterBulkByConv.clear();
    _lastInboundScrollFollowChunk = const <V2TimMessage>[];
    _inboundScrollFollowSessionEnding = false;
    notifyListeners();
  }

  clearReceivedNewMessageCount() {
    _inboundUnreadStateFor(currentSelectedConv).receivedCount = 0;
  }

  _preLoadImage(List<V2TimMessage> msgList) {
    List<V2TimMessage> needPreViewList =
        msgList.sublist(0, max(0, min(5, msgList.length - 1)));
    for (var msgItem in needPreViewList) {
      V2TimImage? getImageFromList(V2TimImageTypesEnum imgType) {
        V2TimImage? img = MessageUtils.getImageFromImgList(
            msgItem.imageElem?.imageList,
            HistoryMessageDartConstant.imgPriorMap[imgType] ??
                HistoryMessageDartConstant.oriImgPrior);
        return img;
      }

      V2TimImage? originalImg = getImageFromList(V2TimImageTypesEnum.small);
      if (originalImg?.localUrl != null && originalImg!.localUrl != "") {
        try {
          ImageConfiguration configuration = const ImageConfiguration();
          final image = FileImage(File((originalImg.localUrl!)));

          image.resolve(configuration).addListener(
              ImageStreamListener((ImageInfo image, bool synchronousCall) {
            final tempImg = image.image;
            _preloadImageMap[msgItem.seq! +
                msgItem.timestamp.toString() +
                (msgItem.msgID ?? "")] = tempImg;
            outputLogger.i("cacheImage ${msgItem.msgID}");
          }));
        } catch (e) {
          outputLogger.i("cacheImage error ${msgItem.msgID}");
        }
      }
    }
  }

  int getMessageProgress(String? msgID) {
    return _messageListProgressMap[msgID] ?? 0;
  }

  Size? getFileMessageSize(String? msgID) {
    if (msgID == null || msgID.isEmpty) {
      return null;
    }
    return _fileMessageSizeMap[msgID];
  }

  String getFileMessageLocation(String? msgID) {
    return _fileListLocationMap[msgID] ?? '';
  }

  setMessageProgress(String msgID, int progress) {
    _messageListProgressMap[msgID] = progress;
    if (progress > 0 && progress < 100) {
      _isDownloading = true;
    } else {
      _isDownloading = false;
      _waitingDownloadList.removeWhere((element) {
        String msgIDItem = element["msgID"] ?? "";
        if (msgIDItem.isNotEmpty) {
          if (msgID == msgIDItem) {
            outputLogger.i("remove download");
            return true;
          }
        }
        return false;
      });
    }
    _markNeedsNotify();
  }

  void clearMessageProgress(String? msgID) {
    if (msgID == null || msgID.isEmpty) {
      return;
    }
    _messageListProgressMap.remove(msgID);
    _fileListLocationMap.remove(msgID);
    _fileMessageSizeMap.remove(msgID);
    notifyListeners();
  }

  void clearUploadProgress(String? msgID) {
    if (msgID == null || msgID.isEmpty) {
      return;
    }
    _messageListProgressMap.remove(msgID);
    _markNeedsNotify();
  }

  setFileMessageLocation(String msgID, String location, {Size? imageSize}) {
    _fileListLocationMap[msgID] = location;
    if (imageSize != null && imageSize.width > 0 && imageSize.height > 0) {
      _fileMessageSizeMap[msgID] = imageSize;
    }
    notifyListeners();
  }

  _editStatusCheck(V2TimMessage msg) {
    bool isStatusMessage = false;
    if (msg.customElem != null &&
        TencentUtils.checkString(msg.groupID) == null) {
      V2TimCustomElem customElem = msg.customElem!;
      String sender = msg.sender ?? "";
      if (customElem.data!.isNotEmpty) {
        try {
          Map<String, dynamic>? data = json.decode(customElem.data ?? "");
          if (data != null) {
            var businessID = data["businessID"];
            int? userAction = data["userAction"];
            String? actionParam = data["actionParam"];
            if (businessID.toString() == "user_typing_status") {
              int? typingStatus = data["typingStatus"];
              if (sender != "") {
                if (typingStatus != null) {
                  setC2cMessageEditStatus(sender, typingStatus);
                } else {
                  // 兼容旧版本逻辑
                  if (userAction != null) {
                    if (userAction == 14) {
                      if (actionParam != null) {
                        setC2cMessageEditStatus(sender,
                            actionParam == "EIMAMSG_InputStatus_Ing" ? 1 : 0);
                      }
                    }
                  }
                }
              }
              return true;
            }
          }
        } catch (err) {
          // err;
        }
      }
    }
    return isStatusMessage;
  }

  _checkFromUserisActive(V2TimMessage msg) async {
    // check message is c2c message and message cloudcustomdata field is not null
    if (msg.groupID == null && msg.cloudCustomData != null) {
      try {
        Map<String, dynamic> data = json.decode(msg.cloudCustomData ?? "");
        Map<String, dynamic>? messageFeature = data["messageFeature"];
        if (messageFeature != null) {
          int needTyping = messageFeature["needTyping"];
          if (needTyping == 1) {
            _c2cMessageFromUserActiveMap[msg.sender ?? ""] = true;

            if (_c2cMessageActiveTimer[msg.sender ?? ""] != null) {
              Timer? t = _c2cMessageActiveTimer[msg.sender ?? ""];
              if (t != null && t.isActive) {
                //取消原来的定时器
                t.cancel();
              }
            }
            _c2cMessageActiveTimer[msg.sender ?? ""] =
                Timer.periodic(const Duration(seconds: 30), (timer) {
              _c2cMessageFromUserActiveMap[msg.sender ?? ""] = false;
              Timer? t = _c2cMessageActiveTimer[msg.sender ?? ""];
              if (t != null && t.isActive) {
                // 取消当前的定时器
                t.cancel();
              }
            });
          }
        }
      } catch (err) {
        // err
      }
    }
  }

  sendEditStatusMessage(bool isEditing, String toUser) async {
    if (!_showC2cMessageEditStatus) {
      return;
    }
    if (!(_c2cMessageFromUserActiveMap[toUser] ?? false)) {
      return;
    }
    V2TimMsgCreateInfoResult? res = await _messageService.createCustomMessage(
        data: json.encode({
      "businessID": "user_typing_status",
      "typingStatus": isEditing == true ? 1 : 0,
      "userAction": 14,
      "version": 0,
      "actionParam": isEditing == true
          ? "EIMAMSG_InputStatus_Ing"
          : "EIMAMSG_InputStatus_End"
    }));
    if (res != null) {
      _sendMessage(
        id: res.id!,
        convID: toUser,
        convType: ConvType.c2c,
        onlineUserOnly: true,
        isEditStatusMessage: true,
      );
    }
  }

  void refreshGroupApplicationList({bool force = false}) {
    if (_groupApplicationRefreshTask != null) {
      if (force) {
        _pendingGroupApplicationRefreshTimer?.cancel();
        _pendingGroupApplicationRefreshTimer = Timer(
          const Duration(milliseconds: 300),
          () => refreshGroupApplicationList(force: true),
        );
      }
      return;
    }

    final now = DateTime.now();
    final last = _lastGroupApplicationRefreshAt;
    if (!force && last != null) {
      final elapsed = now.difference(last);
      if (elapsed < _groupApplicationRefreshInterval) {
        _pendingGroupApplicationRefreshTimer?.cancel();
        _pendingGroupApplicationRefreshTimer = Timer(
          _groupApplicationRefreshInterval - elapsed,
          () => refreshGroupApplicationList(force: true),
        );
        return;
      }
    }

    _lastGroupApplicationRefreshAt = now;
    final task = _loadGroupApplicationList();
    _groupApplicationRefreshTask = task.whenComplete(() {
      if (identical(_groupApplicationRefreshTask, task)) {
        _groupApplicationRefreshTask = null;
      }
    });
  }

  Future<void> _loadGroupApplicationList() async {
    final res = await _groupServices.getGroupApplicationList();
    final nextList = res.data?.groupApplicationList
            ?.whereType<V2TimGroupApplication>()
            .toList() ??
        [];
    if (_isSameGroupApplicationList(
        _groupApplicationList ?? const [], nextList)) {
      return;
    }
    _groupApplicationList = nextList;
    notifyListeners();
  }

  bool _isSameGroupApplicationList(
    List<V2TimGroupApplication> oldList,
    List<V2TimGroupApplication> nextList,
  ) {
    if (oldList.length != nextList.length) return false;
    for (var i = 0; i < oldList.length; i++) {
      final oldItem = oldList[i];
      final nextItem = nextList[i];
      if (oldItem.groupID != nextItem.groupID ||
          oldItem.fromUser != nextItem.fromUser ||
          oldItem.toUser != nextItem.toUser ||
          oldItem.addTime != nextItem.addTime ||
          oldItem.type != nextItem.type ||
          oldItem.handleStatus != nextItem.handleStatus ||
          oldItem.handleResult != nextItem.handleResult) {
        return false;
      }
    }
    return true;
  }

  cancelAllTimer() {
    _c2cMessageActiveTimer.forEach((key, value) {
      if (value.isActive) {
        value.cancel();
      }
    });
    _c2cMessageStatusShowTimer.forEach((key, value) {
      if (value.isActive) {
        value.cancel();
      }
    });
  }

  static const String _outgoingLocalSeqKey = '__outgoingLocalSeq';
  static const String _outgoingLocalSentAtKey = '__outgoingLocalSentAt';

  static int? _outgoingRandomValue(V2TimMessage message) {
    final random = message.random;
    if (random == null || random == 0) {
      return null;
    }
    return random;
  }

  static int? _readOutgoingLocalSeq(V2TimMessage message) {
    return _readOutgoingLocalInt(message, _outgoingLocalSeqKey);
  }

  static int? _readOutgoingLocalSentAt(V2TimMessage message) {
    return _readOutgoingLocalInt(message, _outgoingLocalSentAtKey);
  }

  static int? _readOutgoingLocalInt(V2TimMessage message, String key) {
    final raw = message.localCustomData?.trim();
    if (raw == null || raw.isEmpty) {
      return null;
    }
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) {
        return null;
      }
      final value = decoded[key];
      if (value is int) {
        return value;
      }
      if (value is num) {
        return value.toInt();
      }
    } catch (_) {}
    return null;
  }

  static void _writeOutgoingLocalSeq(V2TimMessage message, int seq) {
    final data = <String, dynamic>{};
    final raw = message.localCustomData?.trim();
    if (raw != null && raw.isNotEmpty) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is Map) {
          data.addAll(Map<String, dynamic>.from(decoded));
        }
      } catch (_) {}
    }
    data[_outgoingLocalSeqKey] = seq;
    data[_outgoingLocalSentAtKey] ??=
        DateTime.now().millisecondsSinceEpoch ~/ 1000;
    message.localCustomData = jsonEncode(data);
  }

  static void _preserveOutgoingLocalOrderData(
    V2TimMessage previous,
    V2TimMessage merged,
  ) {
    final previousRaw = previous.localCustomData?.trim();
    if (previousRaw == null || previousRaw.isEmpty) {
      return;
    }
    final data = <String, dynamic>{};
    final mergedRaw = merged.localCustomData?.trim();
    if (mergedRaw != null && mergedRaw.isNotEmpty) {
      try {
        final decoded = jsonDecode(mergedRaw);
        if (decoded is Map) {
          data.addAll(Map<String, dynamic>.from(decoded));
        }
      } catch (_) {}
    }
    try {
      final previousDecoded = jsonDecode(previousRaw);
      if (previousDecoded is Map) {
        for (final key in const [
          _outgoingLocalSeqKey,
          _outgoingLocalSentAtKey,
        ]) {
          if (previousDecoded.containsKey(key)) {
            data[key] = previousDecoded[key];
          }
        }
      }
    } catch (_) {}
    if (data.isNotEmpty) {
      merged.localCustomData = jsonEncode(data);
    }
  }

  void assignOutgoingLocalSeq(String conversationID, V2TimMessage message) {
    final convID = _safeConversationId(conversationID);
    if (convID.isEmpty) {
      return;
    }
    final next = (_outgoingLocalSeqByConv[convID] ?? 0) + 1;
    _outgoingLocalSeqByConv[convID] = next;
    _writeOutgoingLocalSeq(message, next);
    _logOutgoingSendOrder(
      event: 'tap',
      convID: convID,
      message: message,
      clientId: message.id,
      mergePath: 'assign_local_seq',
    );
  }

  void _logOutgoingSendOrder({
    required String event,
    required String convID,
    required V2TimMessage message,
    String? clientId,
    String? mergePath,
    int? existingIndex,
    bool? reordered,
    String? warn,
  }) {
    if (!ChatJitterDiag.enabled) {
      return;
    }
    final list = _messageListMap[convID] ?? const <V2TimMessage>[];
    final msgID = message.msgID?.trim() ?? '';
    final idValue = clientId?.trim().isNotEmpty == true
        ? clientId!.trim()
        : (message.id?.trim() ?? '');
    var finalIndex = -1;
    for (var i = 0; i < list.length; i++) {
      final item = list[i];
      if (msgID.isNotEmpty && item.msgID == msgID) {
        finalIndex = i;
        break;
      }
      if (idValue.isNotEmpty && item.id == idValue) {
        finalIndex = i;
        break;
      }
    }
    final localSeq = _readOutgoingLocalSeq(message);
    final existing = existingIndex ?? -1;
    final reorderFlag = reordered == true;
    final warnSuffix = warn == null || warn.isEmpty ? '' : ' warn=$warn';
    debugPrint(
      '[IM_SEND_ORDER] event=$event conv=$convID clientId=$idValue msgID=$msgID '
      'tapOrder=$localSeq localSeq=$localSeq serverSeq=${message.seq ?? ''} '
      'timestamp=${message.timestamp ?? ''} finalIndex=$finalIndex listLen=${list.length} '
      'existingIndex=$existing path=${mergePath ?? ''} reordered=$reorderFlag '
      'isSelf=${message.isSelf} random=${message.random}$warnSuffix',
    );
    outputLogger.i(
      '[IM_SEND_ORDER] event=$event conv=$convID clientId=$idValue msgID=$msgID '
      'localSeq=$localSeq serverSeq=${message.seq ?? ''} ts=${message.timestamp ?? ''} '
      'path=${mergePath ?? ''} reordered=$reorderFlag warn=${warn ?? ''}',
    );
  }

  static String? _outgoingCorrelationKey(V2TimMessage message) {
    if (message.isSelf != true) {
      return null;
    }
    final random = _outgoingRandomValue(message);
    if (random != null) {
      return 'rand:$random';
    }
    final id = message.id?.trim();
    if (id != null && id.isNotEmpty) {
      return 'id:$id';
    }
    return null;
  }

  static bool _isClientPlaceholderMessage(V2TimMessage message) {
    if (message.isSelf != true) {
      return false;
    }
    if (message.status != MessageStatus.V2TIM_MSG_STATUS_SENDING) {
      return false;
    }
    final id = message.id;
    return id != null && id.isNotEmpty;
  }

  static bool _isResolvedOutgoingMessage(V2TimMessage message) {
    if (message.isSelf != true) {
      return false;
    }
    // C2C 镜像 dup（对方内容却标 isSelf）不是真实 outgoing ack。
    if (_isC2cConversationMessage(message) &&
        _c2cDirectionConsistencyScore(message) < 3) {
      return false;
    }
    final msgID = message.msgID?.trim();
    if (msgID == null || msgID.isEmpty) {
      return false;
    }
    final id = message.id?.trim();
    if (id != null && id.isNotEmpty && id == msgID) {
      return false;
    }
    return message.status != MessageStatus.V2TIM_MSG_STATUS_SENDING;
  }

  static bool _outgoingMessagesCorrelate(
    V2TimMessage a,
    V2TimMessage b,
  ) {
    if (a.isSelf != true || b.isSelf != true) {
      return false;
    }
    final keyA = _outgoingCorrelationKey(a);
    final keyB = _outgoingCorrelationKey(b);
    if (keyA != null && keyB != null && keyA == keyB) {
      return true;
    }
    if (_outgoingRandomValue(a) != null || _outgoingRandomValue(b) != null) {
      return false;
    }
    final placeholder = _isClientPlaceholderMessage(a) ||
        _isClientPlaceholderMessage(b) ||
        _isResolvedOutgoingMessage(a) ||
        _isResolvedOutgoingMessage(b);
    if (!placeholder) {
      return false;
    }
    if (a.elemType != b.elemType) {
      return false;
    }
    // Never correlate by timestamp alone: same-second sends share timestamp
    // and would merge acks into the wrong placeholder.
    return false;
  }

  static String _messageOrderSignature(V2TimMessage message) {
    // Mirror compareMessagesChronological: seq only drives ordering for group
    // messages. For C2C the sort key is the timestamp, so the signature must be
    // timestamp-based, otherwise an in-place update could skip a needed re-sort.
    if (!_usesTimelineLocalOrdering(message) && _hasGroupSeqOrdering(message)) {
      return 'seq:${_messageSortSeq(message)}|${_readOutgoingLocalSeq(message) ?? ''}';
    }
    return '${_messageSortTimestamp(message)}|${message.seq ?? ''}|${_readOutgoingLocalSeq(message) ?? ''}|${_messageTimelineSortRank(message)}';
  }

  static bool _needsReorderAfterMerge(
    V2TimMessage previous,
    V2TimMessage merged,
  ) {
    final prevLocal = _readOutgoingLocalSeq(previous);
    final mergedLocal = _readOutgoingLocalSeq(merged);
    // 同一条发出消息的回执：存储列表保留点击顺序，避免服务端时间戳微调造成跳动。
    // 展示顺序由 getMessageList 在缓存失效后按时间重排（见 _applyListAfterInPlaceMerge）。
    if (prevLocal != null && prevLocal == mergedLocal) {
      return false;
    }
    return _messageOrderSignature(previous) != _messageOrderSignature(merged);
  }

  void _applyListAfterInPlaceMerge(
    String convID,
    List<V2TimMessage> list, {
    required bool reorder,
  }) {
    if (reorder) {
      _messageListMap[convID] = sortMessagesNewestFirst(list);
      _bumpMessageListRevisionFor(convID, reason: 'in_place_reorder');
      return;
    }
    final ordered = isNewestFirstStorageOrderValid(list)
        ? list
        : sortMessagesNewestFirst(list);
    _messageListMap[convID] = ordered;
    _bumpMessageListRevisionFor(
      convID,
      reason: ordered == list
          ? 'in_place_merge_invalidate'
          : 'in_place_storage_resort',
    );
  }

  /// 存储序列为 newest-first：任一相邻对 chronologically 逆序则需重排。
  @visibleForTesting
  static bool isNewestFirstStorageOrderValid(List<V2TimMessage> list) {
    if (list.length < 2) {
      return true;
    }
    for (var i = 0; i < list.length - 1; i++) {
      if (compareMessagesChronological(list[i], list[i + 1]) < 0) {
        return false;
      }
    }
    return true;
  }

  /// 秒级 epoch；字段误存毫秒时归一化（Web/归档混源常见）。
  @visibleForTesting
  static int normalizeMessageEpochSeconds(int? raw) {
    if (raw == null || raw <= 0) {
      return 0;
    }
    if (raw >= 1000000000000) {
      return raw ~/ 1000;
    }
    return raw;
  }

  static int messageEpochSecondsForDisplay(V2TimMessage message) {
    return normalizeMessageEpochSeconds(_messageSortTimestamp(message));
  }

  static int _findOutgoingPlaceholderIndex(
    List<V2TimMessage> list,
    V2TimMessage incoming,
  ) {
    final candidates = <int>[];
    for (var i = 0; i < list.length; i++) {
      final element = list[i];
      if (!_isClientPlaceholderMessage(element)) {
        continue;
      }
      if (element.elemType != incoming.elemType) {
        continue;
      }
      candidates.add(i);
    }
    if (candidates.isEmpty) {
      return -1;
    }
    if (candidates.length == 1) {
      return candidates.first;
    }
    final incomingRandom = _outgoingRandomValue(incoming);
    if (incomingRandom != null) {
      for (final i in candidates) {
        if (list[i].random == incomingRandom) {
          return i;
        }
      }
    }
    final incomingId = incoming.id?.trim();
    if (incomingId != null && incomingId.isNotEmpty) {
      for (final i in candidates) {
        if (list[i].id == incomingId) {
          return i;
        }
      }
    }
    final incomingMsgID = incoming.msgID?.trim();
    if (incomingMsgID != null && incomingMsgID.isNotEmpty) {
      for (final i in candidates) {
        if (list[i].msgID?.trim() == incomingMsgID) {
          return i;
        }
      }
    }
    final incomingLocalSeq = _readOutgoingLocalSeq(incoming);
    if (incomingLocalSeq != null) {
      for (final i in candidates) {
        if (_readOutgoingLocalSeq(list[i]) == incomingLocalSeq) {
          return i;
        }
      }
    }
    if (incoming.elemType == MessageElemType.V2TIM_ELEM_TYPE_SOUND) {
      final newDuration = incoming.soundElem?.duration;
      for (final i in candidates) {
        if (list[i].soundElem?.duration == newDuration) {
          return i;
        }
      }
    }
    // Ambiguous when multiple placeholders share type without random/id/msgID.
    // Orphan-insert + chronological sort is safer than guessing FIFO.
    return -1;
  }

  /// Binds SDK-assigned [msgID] to a sending placeholder before send completes.
  void bindOutgoingSyncMsgId(
    String conversationID,
    String clientId,
    String msgID,
  ) {
    final convID = _normalizeConversationID(conversationID);
    final id = clientId.trim();
    final serverMsgID = msgID.trim();
    if (convID.isEmpty || id.isEmpty || serverMsgID.isEmpty) {
      return;
    }
    final list = _messageListMap[convID];
    if (list == null || list.isEmpty) {
      return;
    }
    final index = list.indexWhere(
      (item) =>
          item.isSelf == true &&
          item.id == id &&
          (item.msgID == null || item.msgID!.isEmpty || item.msgID == id),
    );
    if (index == -1) {
      return;
    }
    final updated = _cloneMessage(list[index]);
    updated.msgID = serverMsgID;
    final next = [...list];
    next[index] = updated;
    _messageListMap[convID] = next;
    _chatUiStateStore.bindMessageAlias(
      convID,
      id,
      ChatUiStateStore.messageKeyOf(updated),
    );
    _markMessageRowChanged(convID, updated, extraKey: id);
    _markNeedsNotify();
  }

  @visibleForTesting
  static int findOutgoingPlaceholderIndexForTesting(
    List<V2TimMessage> list,
    V2TimMessage incoming,
  ) {
    return _findOutgoingPlaceholderIndex(list, incoming);
  }

  @visibleForTesting
  static void preserveOutgoingLocalOrderDataForTesting(
    V2TimMessage previous,
    V2TimMessage merged,
  ) {
    _preserveOutgoingLocalOrderData(previous, merged);
  }

  @visibleForTesting
  static int? readOutgoingLocalSeqForTesting(V2TimMessage message) {
    return _readOutgoingLocalSeq(message);
  }

  int findReplaceableOutgoingIndex(
    String convID,
    V2TimMessage message, {
    String? priorTempId,
    List<V2TimMessage>? listOverride,
  }) {
    final list = listOverride ?? _messageListMap[convID] ?? [];
    if (priorTempId != null && priorTempId.isNotEmpty) {
      final byTemp = list.indexWhere(
        (item) => item.id == priorTempId || item.msgID == priorTempId,
      );
      if (byTemp != -1) {
        return byTemp;
      }
    }
    final id = message.id;
    if (id != null && id.isNotEmpty) {
      final byId = list.indexWhere((item) => item.id == id);
      if (byId != -1) {
        return byId;
      }
    }
    final msgID = message.msgID;
    if (msgID != null && msgID.isNotEmpty) {
      final byMsgID = list.indexWhere((item) => item.msgID == msgID);
      if (byMsgID != -1) {
        return byMsgID;
      }
    }
    return _findOutgoingPlaceholderIndex(list, message);
  }

  void _preserveSoundLocalPath(V2TimMessage? previous, V2TimMessage resolved) {
    if (previous == null ||
        previous.elemType != MessageElemType.V2TIM_ELEM_TYPE_SOUND ||
        resolved.elemType != MessageElemType.V2TIM_ELEM_TYPE_SOUND) {
      return;
    }
    final prevSound = previous.soundElem;
    final nextSound = resolved.soundElem;
    if (prevSound == null || nextSound == null) {
      return;
    }
    final localPath = prevSound.path ?? prevSound.localUrl;
    if (localPath == null || localPath.isEmpty) {
      return;
    }
    nextSound.path = localPath;
    nextSound.localUrl = prevSound.localUrl ?? localPath;
  }

  void _preserveImageLocalPath(V2TimMessage? previous, V2TimMessage resolved) {
    if (previous == null ||
        previous.elemType != MessageElemType.V2TIM_ELEM_TYPE_IMAGE ||
        resolved.elemType != MessageElemType.V2TIM_ELEM_TYPE_IMAGE) {
      return;
    }
    final prevPath = previous.imageElem?.path;
    if (prevPath == null || prevPath.isEmpty) {
      return;
    }
    resolved.imageElem ??= previous.imageElem;
    resolved.imageElem!.path = prevPath;
  }

  void _preserveImageDisplaySize(V2TimMessage resolved, String clientId) {
    if (resolved.elemType != MessageElemType.V2TIM_ELEM_TYPE_IMAGE) {
      return;
    }
    Size? size = _fileMessageSizeMap[clientId];
    final msgID = resolved.msgID?.trim();
    if ((size == null || size.width <= 0 || size.height <= 0) &&
        msgID != null &&
        msgID.isNotEmpty) {
      size = _fileMessageSizeMap[msgID];
    }
    if (size == null || size.width <= 0 || size.height <= 0) {
      return;
    }
    final imageList = resolved.imageElem?.imageList;
    if (imageList == null || imageList.isEmpty) {
      return;
    }
    final width = size.width.round();
    final height = size.height.round();
    for (final image in imageList) {
      if (image == null) {
        continue;
      }
      image.width = width;
      image.height = height;
    }
  }

  void _migrateFileMessageMetadata(String clientId, String? msgID) {
    if (clientId.isEmpty || msgID == null || msgID.isEmpty) {
      return;
    }
    final location = _fileListLocationMap[clientId];
    if (location != null && location.isNotEmpty) {
      _fileListLocationMap.putIfAbsent(msgID, () => location);
    }
    final size = _fileMessageSizeMap[clientId];
    if (size != null) {
      _fileMessageSizeMap.putIfAbsent(msgID, () => size);
    }
  }

  void _registerSoundLocalPath(V2TimMessage message) {
    if (message.elemType != MessageElemType.V2TIM_ELEM_TYPE_SOUND) {
      return;
    }
    final localPath = message.soundElem?.path ?? message.soundElem?.localUrl;
    if (localPath == null || localPath.isEmpty) {
      return;
    }
    final msgID = message.msgID;
    if (msgID != null && msgID.isNotEmpty) {
      setFileMessageLocation(msgID, localPath);
    }
    final clientId = message.id;
    if (clientId != null && clientId.isNotEmpty) {
      setFileMessageLocation(clientId, localPath);
    }
  }

  bool _messageCorrelatesWithStored(
    V2TimMessage stored,
    V2TimMessage incoming,
  ) {
    if (messagesCorrelateForDedup(stored, incoming)) {
      return true;
    }
    if (incoming.isSelf == true && _outgoingMessagesCorrelate(stored, incoming)) {
      return true;
    }
    return false;
  }

  void _mergeMessageAtIndex(
    String convID,
    List<V2TimMessage> list,
    int index,
    V2TimMessage newMsg, {
    bool replacingPlaceholder = false,
    bool forceSuccess = false,
  }) {
    final updated = [...list];
    final previous = list[index];
    final merged = _cloneMessage(newMsg);
    final isSelf = _isC2cConversationMessage(previous) &&
            _isC2cConversationMessage(newMsg)
        ? _resolveMergedIsSelf(previous, newMsg)
        : (previous.isSelf == true || newMsg.isSelf == true);
    merged.isSelf = isSelf;

    if (isSelf) {
      final clientId = previous.id;
      if (clientId != null && clientId.isNotEmpty) {
        merged.id = clientId;
      }
      _preserveOutgoingLocalOrderData(previous, merged);
      if (previous.elemType == MessageElemType.V2TIM_ELEM_TYPE_SOUND &&
          merged.elemType == MessageElemType.V2TIM_ELEM_TYPE_SOUND) {
        _preserveSoundLocalPath(previous, merged);
      }
      if (previous.elemType == MessageElemType.V2TIM_ELEM_TYPE_IMAGE &&
          merged.elemType == MessageElemType.V2TIM_ELEM_TYPE_IMAGE) {
        _preserveImageLocalPath(previous, merged);
        final clientId = previous.id?.trim() ?? '';
        if (clientId.isNotEmpty) {
          _preserveImageDisplaySize(merged, clientId);
          _migrateFileMessageMetadata(clientId, merged.msgID);
          final layoutSize = readPersistedImageLayoutSize(previous) ??
              _fileMessageSizeMap[clientId] ??
              ((merged.msgID?.isNotEmpty ?? false)
                  ? _fileMessageSizeMap[merged.msgID!]
                  : null);
          if (layoutSize != null) {
            applyImageLayoutToMessage(merged, layoutSize);
          }
        }
      }
      if (forceSuccess ||
          merged.status == MessageStatus.V2TIM_MSG_STATUS_SEND_SUCC) {
        merged.status = MessageStatus.V2TIM_MSG_STATUS_SEND_SUCC;
      } else if (merged.status == MessageStatus.V2TIM_MSG_STATUS_SEND_FAIL) {
        merged.status = MessageStatus.V2TIM_MSG_STATUS_SEND_FAIL;
      } else if (previous.status == MessageStatus.V2TIM_MSG_STATUS_SEND_SUCC) {
        merged.status = MessageStatus.V2TIM_MSG_STATUS_SEND_SUCC;
      } else {
        merged.status = MessageStatus.V2TIM_MSG_STATUS_SENDING;
      }
    } else if (merged.status == MessageStatus.V2TIM_MSG_STATUS_SENDING) {
      merged.status = MessageStatus.V2TIM_MSG_STATUS_SEND_SUCC;
    }
    final previousKey = ChatUiStateStore.messageKeyOf(previous);
    updated[index] = merged;
    final reorder = _needsReorderAfterMerge(previous, merged);
    _applyListAfterInPlaceMerge(convID, updated, reorder: reorder);
    _registerSoundLocalPath(merged);
    _chatUiStateStore.bindMessageAlias(
      convID,
      previousKey,
      ChatUiStateStore.messageKeyOf(merged),
    );
    _markMessageRowChanged(convID, merged, extraKey: previousKey);
    if (isSelf) {
      _logOutgoingSendOrder(
        event: 'merge_self',
        convID: convID,
        message: merged,
        clientId: merged.id,
        mergePath: replacingPlaceholder ? 'placeholder_merge' : 'inplace_merge',
        existingIndex: index,
        reordered: reorder,
      );
    }
  }

  bool _upsertIncomingMessage(
    String convID,
    V2TimMessage newMsg, {
    bool forceSuccess = false,
    bool bumpRevision = true,
  }) {
    final list = _messageListMap[convID] ?? [];
    if (newMsg.isSelf == true) {
      final id = newMsg.id;
      final index = list.indexWhere(
        (element) => _messageCorrelatesWithStored(element, newMsg),
      );
      if (index != -1) {
        _logOutgoingSendOrder(
          event: 'upsert_self',
          convID: convID,
          message: newMsg,
          clientId: id,
          mergePath: 'correlate_merge',
          existingIndex: index,
        );
        _mergeMessageAtIndex(
          convID,
          list,
          index,
          newMsg,
          forceSuccess: forceSuccess,
        );
        return true;
      }
      final placeholderIndex = _findOutgoingPlaceholderIndex(list, newMsg);
      if (placeholderIndex != -1) {
        _logOutgoingSendOrder(
          event: 'upsert_self',
          convID: convID,
          message: newMsg,
          clientId: id,
          mergePath: 'placeholder_merge',
          existingIndex: placeholderIndex,
        );
        _mergeMessageAtIndex(
          convID,
          list,
          placeholderIndex,
          newMsg,
          replacingPlaceholder: true,
          forceSuccess: forceSuccess,
        );
        return true;
      }
      _logOutgoingSendOrder(
        event: 'upsert_self',
        convID: convID,
        message: newMsg,
        clientId: id,
        mergePath: 'orphan_insert',
        existingIndex: -1,
        warn: 'recv_without_placeholder',
      );
      _messageListMap[convID] = sortMessagesNewestFirst(
        dedupeMessages([newMsg, ...list]),
      );
      if (bumpRevision) {
        _bumpMessageListRevisionFor(convID);
      }
      return false;
    }
    final existingIndex = list.indexWhere(
      (element) => _messageCorrelatesWithStored(element, newMsg),
    );
    if (existingIndex != -1) {
      _mergeMessageAtIndex(
        convID,
        list,
        existingIndex,
        newMsg,
        forceSuccess: true,
      );
      return true;
    }
    _messageListMap[convID] = sortMessagesNewestFirst(
      dedupeMessages([newMsg, ...list]),
    );
    if (bumpRevision) {
      _bumpMessageListRevisionFor(convID);
    }
    return false;
  }

  /// Applies a burst without sorting the full conversation once per message.
  ///
  /// The common path (all messages are new) performs one final sort. If a
  /// duplicate appears inside the burst, pending inserts are flushed first so
  /// the existing single-message merge semantics remain unchanged.
  ({
    bool inserted,
    V2TimMessage? lastInserted,
    List<V2TimMessage> insertedMessages,
  }) _upsertIncomingMessageBatch(
    String convID,
    List<V2TimMessage> messages,
  ) {
    if (messages.isEmpty) {
      return (
        inserted: false,
        lastInserted: null,
        insertedMessages: const <V2TimMessage>[],
      );
    }

    final pending = <V2TimMessage>[];
    final insertedMessages = <V2TimMessage>[];
    var inserted = false;
    V2TimMessage? lastInserted;

    void flushPending() {
      if (pending.isEmpty) {
        return;
      }
      _messageListMap[convID] = sortMessagesNewestFirst(
        <V2TimMessage>[
          ...pending,
          ...(_messageListMap[convID] ?? const <V2TimMessage>[]),
        ],
      );
      pending.clear();
    }

    bool matchesStoredIdentity(V2TimMessage message) {
      return (_messageListMap[convID] ?? const <V2TimMessage>[]).any(
        (item) => _messageCorrelatesWithStored(item, message),
      );
    }

    bool matchesPendingIdentity(V2TimMessage message) {
      final msgID = message.msgID;
      final id = message.id;
      return pending.any((item) {
        if (msgID != null && msgID.isNotEmpty && item.msgID == msgID) {
          return true;
        }
        return id != null && id.isNotEmpty && item.id == id;
      });
    }

    for (final message in messages) {
      // Self-message correlation has additional placeholder rules. Keep that
      // mature path intact; active-chat self sync normally bypasses batching.
      if (message.isSelf == true) {
        flushPending();
        final merged = _upsertIncomingMessage(
          convID,
          message,
          forceSuccess: true,
          bumpRevision: false,
        );
        if (!merged) {
          inserted = true;
          lastInserted = message;
          insertedMessages.add(message);
        }
        continue;
      }

      if (matchesPendingIdentity(message)) {
        // Sequential behavior would have inserted the first copy before this
        // callback arrived, so expose pending rows to the regular merge path.
        flushPending();
      }
      if (matchesStoredIdentity(message)) {
        _upsertIncomingMessage(
          convID,
          message,
          bumpRevision: false,
        );
        continue;
      }

      pending.add(message);
      inserted = true;
      lastInserted = message;
      insertedMessages.add(message);
    }
    flushPending();
    return (
      inserted: inserted,
      lastInserted: lastInserted,
      insertedMessages: insertedMessages,
    );
  }

  void _stageInboundChunkReveal(
    String conversationID,
    List<V2TimMessage> messages,
  ) {
    final result = _upsertIncomingMessageBatch(conversationID, messages);
    if (!result.inserted) {
      _markNeedsNotify();
      return;
    }

    // Install the projection barrier before invalidating the display cache.
    // The canonical list is complete immediately, but only reveal ticks may
    // make these rows visible.
    _hideInboundProjection(conversationID, result.insertedMessages);
    _bumpMessageListRevisionFor(
      conversationID,
      reason: 'inbound_authority_batch',
    );
    _storeHistoryMessagePosition(
      conversationID,
      HistoryMessagePosition.bottom,
    );
    if (lockedEntryUnreadCountFor(conversationID) == 0) {
      flushDeferredIncomingMessages(conversationID, notify: false);
      clearReceivedUnreadState(
        conversationID: conversationID,
        notify: false,
      );
    }
    _inboundChunkReveal.enqueueAll(
      conversationID,
      result.insertedMessages,
    );
  }

  void _flushInboundMessageBatch(
    String conversationID,
    List<V2TimMessage> messages,
  ) {
    if (messages.isEmpty) {
      return;
    }
    final convId = _resolveMessageListStorageKey(
      _safeConversationId(conversationID),
    );
    if (convId.isEmpty) {
      return;
    }
    if (_shouldChunkRevealInbound(convId, messages)) {
      ChatJitterDiag.log(
        'inbound_chunk_reveal_enqueue',
        conv: convId,
        extras: <String, Object?>{
          'count': messages.length,
          'intervalMs': chatConfig.inboundChunkRevealIntervalMs,
          'maxChunk': chatConfig.inboundChunkRevealMaxChunk,
        },
      );
      _stageInboundChunkReveal(convId, messages);
      return;
    }
    final isBulk = messages.length >= _bulkMessageSyncThreshold;
    if (isBulk) {
      _beginBulkMessageSync(convId);
    }
    try {
      _applyInboundMessageBatch(convId, messages);
    } finally {
      if (isBulk) {
        _endBulkMessageSync(convId);
      }
    }
  }

  bool _shouldChunkRevealInbound(
    String convID,
    List<V2TimMessage> messages,
  ) {
    if (!chatConfig.inboundChunkRevealEnabled ||
        messages.isEmpty ||
        !shouldAnimateInboundPresentation) {
      return false;
    }
    if (!_isSameConversationID(convID, currentSelectedConv)) {
      return false;
    }
    // While the user explicitly returns to the bottom, incoming rows must join
    // the authoritative list immediately. Starting another reveal transaction
    // would keep moving the scroll target and can make the button never settle.
    if (isUserScrollToBottomInProgress(convID)) {
      return false;
    }
    if (_isChatListUserScrolling) {
      return false;
    }
    _syncHistoryPositionFromActiveScroll(convID);
    final position = getMessageListPosition(convID);
    final isActuallyNearBottom = _isActiveChatNearBottom(convID);
    if (_shouldDeferIncomingToVisibleList(
      convID,
      position: position,
      isActuallyNearBottom: isActuallyNearBottom,
    )) {
      return false;
    }
    if (!isActuallyNearBottom &&
        !(position == HistoryMessagePosition.bottom &&
            unreadCountForTongue == 0)) {
      return false;
    }
    return true;
  }

  void _drainChunkRevealToBuffer(
    String convID,
    List<V2TimMessage> messages,
  ) {
    if (messages.isEmpty) {
      return;
    }
    _syncHistoryPositionFromActiveScroll(convID);
    final position = getMessageListPosition(convID);
    final isActuallyNearBottom = _isActiveChatNearBottom(convID);
    for (final message in messages) {
      if (message.isSelf == true) {
        _revealInboundProjectionChunk(convID, <V2TimMessage>[message]);
        continue;
      }
      _authoritativeDeferredIncomingKeys.add(
        _authoritativeDeferredKey(convID, message),
      );
      _bufferIncomingWhileReadingAway(
        convID,
        message,
        route: 'chunk_reveal_cancelled',
        position: position,
        isActuallyNearBottom: isActuallyNearBottom,
      );
    }
    ChatJitterDiag.log(
      'inbound_chunk_reveal_drain_buffer',
      conv: convID,
      extras: <String, Object?>{
        'count': messages.length,
        'tongueUnread': unreadCountForTongue,
      },
    );
    _markNeedsNotify();
  }

  void _applyInboundMessageBatch(
    String convID,
    List<V2TimMessage> messages,
  ) {
    if (messages.isEmpty) {
      return;
    }
    final isActiveConversation =
        _isSameConversationID(convID, currentSelectedConv);
    var listDirty = false;
    V2TimMessage? enterAnimationCandidate;

    if (!isActiveConversation) {
      final result = _upsertIncomingMessageBatch(convID, messages);
      listDirty = result.inserted;
      if (listDirty) {
        _bumpMessageListRevisionFor(
          convID,
          reason: 'inbound_batch_inactive',
        );
      }
      _markNeedsNotify();
      return;
    }

    _syncHistoryPositionFromActiveScroll(convID);
    final position = getMessageListPosition(convID);
    final isActuallyNearBottom = _isActiveChatNearBottom(convID);
    final isReturningToBottom = isUserScrollToBottomInProgress(convID);
    var clearedUnreadState = false;
    final messagesToUpsert = <V2TimMessage>[];

    for (final message in messages) {
      if (message.isSelf == true) {
        _syncSelfSentMessage(convID, message, forceSuccess: true);
        listDirty = true;
        continue;
      }

      if (!_chatAppForeground) {
        _bufferIncomingWhileReadingAway(
          convID,
          message,
          route: 'app_background',
          position: HistoryMessagePosition.notShowLatest,
          isActuallyNearBottom: false,
        );
        continue;
      }

      if (!isReturningToBottom &&
          _shouldDeferIncomingToVisibleList(
            convID,
            position: position,
            isActuallyNearBottom: isActuallyNearBottom,
          )) {
        _bufferIncomingWhileReadingAway(
          convID,
          message,
          route: position == HistoryMessagePosition.notShowLatest
              ? 'notShowLatest'
              : 'awayFromBottom',
          position: position,
          isActuallyNearBottom: isActuallyNearBottom,
        );
        continue;
      }

      if (isReturningToBottom ||
          isActuallyNearBottom ||
          (position == HistoryMessagePosition.bottom &&
              unreadCountForTongue == 0)) {
        if (isActuallyNearBottom) {
          _storeHistoryMessagePosition(convID, HistoryMessagePosition.bottom);
        }
        if (!isReturningToBottom &&
            !clearedUnreadState &&
            lockedEntryUnreadCountFor(convID) == 0) {
          flushDeferredIncomingMessages(convID, notify: false);
          clearReceivedUnreadState(
            conversationID: convID,
            notify: false,
          );
          clearedUnreadState = true;
        }
        messagesToUpsert.add(message);
      } else {
        _bufferIncomingWhileReadingAway(
          convID,
          message,
          route: 'awayFromBottom',
          position: position,
          isActuallyNearBottom: isActuallyNearBottom,
        );
      }
    }

    final upsertResult = _upsertIncomingMessageBatch(convID, messagesToUpsert);
    if (upsertResult.inserted) {
      listDirty = true;
      enterAnimationCandidate = upsertResult.lastInserted;
    }

    if (listDirty) {
      _bumpMessageListRevisionFor(
        convID,
        reason: 'inbound_batch_active',
      );
    }

    if (enterAnimationCandidate != null) {
      _markIncomingMessageEnterAnimation(enterAnimationCandidate);
    }

    final isBulk = messages.length >= _bulkMessageSyncThreshold;
    if (listDirty &&
        isActuallyNearBottom &&
        !_shouldDeferIncomingToVisibleList(
          convID,
          position: position,
          isActuallyNearBottom: isActuallyNearBottom,
        )) {
      final scrollFollowActive = chatConfig.inboundScrollFollowEnabled &&
          isChunkedRevealActive(convID);
      if (isBulk ||
          isBulkMessageSyncActive(convID) ||
          isChunkedRevealActive(convID)) {
        if (!scrollFollowActive) {
          _pendingPinAfterBulkByConv[convID] = true;
        }
      } else {
        requestPinToBottom(convID);
      }
    }

    ChatJitterDiag.logInboundFlow(
      action: 'batch_applied',
      conv: convID,
      extras: <String, Object?>{
        'count': messages.length,
        'upserted': messagesToUpsert.length,
        'listDirty': listDirty,
        'bulk': isBulk,
        'nearBottom': isActuallyNearBottom,
        'bottomLocked': isInboundPresentationBottomLocked(convID),
        'returningToBottom': isReturningToBottom,
        'logicalPosition': position.name,
        'tongueUnread': unreadCountForTongue,
        'buffered': _inboundUnreadStateFor(convID, create: false)
            .bufferedMessages
            .length,
        'queue': pendingInboundProjectionCount(convID),
      },
    );
    _markNeedsNotify();
  }

  bool _syncSelfSentMessage(
    String convID,
    V2TimMessage newMsg, {
    bool forceSuccess = false,
  }) {
    if (newMsg.isSelf != true) {
      return false;
    }
    if (forceSuccess &&
        (isOutgoingMediaCancelled(newMsg.id) ||
            isOutgoingMediaCancelled(newMsg.msgID))) {
      return false;
    }
    return _upsertIncomingMessage(
      convID,
      newMsg,
      forceSuccess: forceSuccess,
    );
  }

  void _syncGroupMemberFromMessage(V2TimMessage message) {
    final groupID = TencentUtils.checkString(message.groupID);
    final userID = TencentUtils.checkString(message.sender) ??
        TencentUtils.checkString(message.userID);
    if (groupID == null || userID == null) {
      return;
    }

    final nameCard = TencentUtils.checkString(message.nameCard);
    final nickName = TencentUtils.checkString(message.nickName);
    final friendRemark = TencentUtils.checkString(message.friendRemark);
    final faceUrl = TencentUtils.checkString(message.faceUrl);
    if (nameCard == null &&
        nickName == null &&
        friendRemark == null &&
        faceUrl == null) {
      return;
    }

    final current = GroupMemberStore.instance.memberOf(groupID, userID);
    if (current == null) {
      GroupMemberStore.instance.putMember(
        groupID,
        V2TimGroupMemberFullInfo(
          userID: userID,
          nameCard: nameCard,
          nickName: nickName,
          friendRemark: friendRemark,
          faceUrl: faceUrl,
        ),
      );
      return;
    }

    var changed = false;
    if (nameCard != null && current.nameCard != nameCard) {
      current.nameCard = nameCard;
      changed = true;
    }
    if (nickName != null && current.nickName != nickName) {
      current.nickName = nickName;
      changed = true;
    }
    if (friendRemark != null && current.friendRemark != friendRemark) {
      current.friendRemark = friendRemark;
      changed = true;
    }
    if (faceUrl != null && current.faceUrl != faceUrl) {
      current.faceUrl = faceUrl;
      changed = true;
    }
    if (changed) {
      GroupMemberStore.instance.putMember(groupID, current);
    }
  }

  _onReceiveNewMsg(V2TimMessage msgComing) async {
    final initialConvID = _messageConversationID(msgComing);
    if (initialConvID == null || initialConvID.isEmpty) {
      return;
    }

    V2TimMessage? mountedMessage = msgComing;
    if (_lifeCycle?.newMessageWillMount != null) {
      try {
        mountedMessage = await _lifeCycle!.newMessageWillMount(msgComing);
      } catch (e) {
        outputLogger.i('newMessageWillMount error: $e');
        mountedMessage = msgComing;
      }
    }
    if (mountedMessage == null) {
      return;
    }
    mountedMessage = _normalizeInboundC2cDirection(mountedMessage);

    final rawConvID = _messageConversationID(mountedMessage) ?? initialConvID;
    final convID = _resolveMessageListStorageKey(rawConvID);
    _syncGroupMemberFromMessage(mountedMessage);

    // Typing/status custom messages should update typing state only. They must not
    // enter the visible message list, but they also must not stop normal message
    // events in other conversations.
    final bool isEditMessage = _editStatusCheck(mountedMessage);
    if (isEditMessage) {
      return;
    }

    _checkFromUserisActive(mountedMessage);
    final convType = TencentUtils.checkString(mountedMessage.groupID) != null
        ? ConvType.group
        : ConvType.c2c;
    final isActiveConversation =
        _isSameConversationID(convID, currentSelectedConv);

    if (isActiveConversation &&
        chatConfig.isAutoReportRead &&
        lockedEntryUnreadCountFor(convID) == 0) {
      _scheduleActiveReadReport(
        convID: convID,
        convType: convType,
      );
    }

    // Self-sent sync on the active chat must stay immediate for send UX.
    if (isActiveConversation && mountedMessage.isSelf == true) {
      _syncSelfSentMessage(convID, mountedMessage, forceSuccess: true);
      _markNeedsNotify();
      return;
    }

    _inboundBatchCoalescer.enqueue(convID, mountedMessage);
  }

  String _revokedCloudCustomData(String? raw, bool isAdmin) {
    final data = <String, dynamic>{};
    final source = raw?.trim();
    if (source != null && source.isNotEmpty) {
      try {
        final decoded = jsonDecode(source);
        if (decoded is Map) {
          data.addAll(Map<String, dynamic>.from(decoded));
        }
      } catch (_) {
        // Keep the original message render stable even when old custom data is invalid.
      }
    }
    data['isRevoke'] = true;
    data['revokeByAdmin'] = isAdmin;
    return jsonEncode(data);
  }

  void _addRevokeLookupKey(List<String> keys, String? key) {
    final value = key?.trim();
    if (value == null || value.isEmpty || keys.contains(value)) {
      return;
    }
    keys.add(value);

    if (value.startsWith('c2c_')) {
      final pure = value.substring(4);
      if (pure.isNotEmpty && !keys.contains(pure)) {
        keys.add(pure);
      }
    } else if (value.startsWith('C2C')) {
      final pure = value.substring(3);
      if (pure.isNotEmpty && !keys.contains(pure)) {
        keys.add(pure);
      }
    } else if (!value.startsWith('group_') && !value.startsWith('GROUP')) {
      final c2cKey = 'c2c_$value';
      if (!keys.contains(c2cKey)) {
        keys.add(c2cKey);
      }
    }

    if (value.startsWith('group_')) {
      final pure = value.substring(6);
      if (pure.isNotEmpty && !keys.contains(pure)) {
        keys.add(pure);
      }
    } else if (value.startsWith('GROUP')) {
      final pure = value.substring(5);
      if (pure.isNotEmpty && !keys.contains(pure)) {
        keys.add(pure);
      }
    }
  }

  bool markMessageRevokedNow(
    String msgID, {
    String? convID,
    bool isAdmin = false,
  }) {
    final targetMsgID = msgID.trim();
    if (targetMsgID.isEmpty) {
      return false;
    }

    final keys = <String>[];
    _addRevokeLookupKey(keys, convID);
    _addRevokeLookupKey(keys, currentSelectedConv);
    for (final key in _messageListMap.keys) {
      _addRevokeLookupKey(keys, key);
    }

    var didUpdate = false;
    for (final key in keys) {
      final activeMessageList = _messageListMap[key];
      if (activeMessageList == null || activeMessageList.isEmpty) {
        continue;
      }

      var changed = false;
      final changedMessageKeys = <String>{};
      final updated = activeMessageList.map((item) {
        if (item.msgID != targetMsgID) {
          return item;
        }

        item.status = MessageStatus.V2TIM_MSG_STATUS_LOCAL_REVOKED;
        item.cloudCustomData =
            _revokedCloudCustomData(item.cloudCustomData, isAdmin);
        // Keep the stable msgID for future SDK callbacks; only refresh the local id
        // when it is empty so the list can rebuild without breaking later matching.
        item.id ??=
            item.msgID ?? DateTime.now().millisecondsSinceEpoch.toString();
        changedMessageKeys.add(ChatUiStateStore.messageKeyOf(item));
        changed = true;
        return item;
      }).toList(growable: true);

      if (!changed) {
        continue;
      }

      final state = _inboundUnreadStateFor(key, create: false);
      state.bufferedMessages
          .removeWhere((element) => element.msgID == targetMsgID);
      final revokedMessages = updated
          .where((element) => element.msgID == targetMsgID)
          .toList(growable: false);
      for (final message in revokedMessages) {
        final dedupKey = messageDedupKey(message);
        state.bufferedMessageKeys.remove(dedupKey);
        _inboundFastForwardMessageKeys.remove(dedupKey);
        _authoritativeDeferredIncomingKeys.remove(
          _authoritativeDeferredKey(key, message),
        );
      }
      _revealDeferredProjectionAcrossAliases(key, revokedMessages);
      _messageListMap[key] = updated;
      for (final messageKey in changedMessageKeys) {
        _chatUiStateStore.markMessageChanged(key, messageKey);
      }
      _bumpMessageListRevisionFor(key);
      didUpdate = true;
    }

    if (didUpdate) {
      // Revoke is a user-visible command. Refresh immediately like WeChat instead
      // of waiting for the next route switch/history reload.
      _notifyPending = false;
      notifyListeners();
    }
    return didUpdate;
  }

  onMessageRevoked(String msgID, [String? convID]) {
    markMessageRevokedNow(msgID, convID: convID);
  }

  void markMessageChangedByMessage(
    String conversationID,
    V2TimMessage message,
  ) {
    final messageKey = ChatUiStateStore.messageKeyOf(message);
    if (messageKey.isEmpty) {
      return;
    }
    _chatUiStateStore.markMessageChanged(conversationID, messageKey);
    _markNeedsNotify();
  }

  onMessageModified(V2TimMessage modifiedMessage, [String? convID]) async {
    final String? exactId = TencentUtils.checkString(modifiedMessage.userID) ??
        TencentUtils.checkString(modifiedMessage.groupID);
    final resolvedConvID = convID ?? exactId;
    if (resolvedConvID == null || resolvedConvID.isEmpty) {
      return;
    }
    if (modifiedMessage.isSelf == true &&
        _syncSelfSentMessage(
          resolvedConvID,
          modifiedMessage,
          forceSuccess: modifiedMessage.status ==
              MessageStatus.V2TIM_MSG_STATUS_SEND_SUCC,
        )) {
      _chatUiStateStore.markMessageChangedByMessage(
        resolvedConvID,
        modifiedMessage,
      );
      _markNeedsNotify();
      return;
    }
    final activeMessageList = _messageListMap[resolvedConvID];
    if (activeMessageList == null || activeMessageList.isEmpty) {
      return;
    }
    final V2TimMessage newMsg =
        await _lifeCycle?.modifiedMessageWillMount(modifiedMessage) ??
            modifiedMessage;
    final msgID = newMsg.msgID;
    final clientId = newMsg.id;
    var changed = false;
    final changedKeys = <String>{};
    _messageListMap[resolvedConvID] = activeMessageList.map((item) {
      final itemKey = ChatUiStateStore.messageKeyOf(item);
      if (msgID != null && msgID.isNotEmpty && item.msgID == msgID) {
        changed = true;
        changedKeys.add(itemKey);
        changedKeys.add(msgID);
        return newMsg;
      }
      if (clientId != null &&
          clientId.isNotEmpty &&
          item.id != null &&
          item.id == clientId) {
        changed = true;
        changedKeys.add(itemKey);
        changedKeys.add(clientId);
        return newMsg;
      }
      return item;
    }).toList();
    if (changed) {
      changedKeys.add(ChatUiStateStore.messageKeyOf(newMsg));
      if (msgID != null && msgID.isNotEmpty) {
        changedKeys.add(msgID);
      }
      if (clientId != null && clientId.isNotEmpty) {
        changedKeys.add(clientId);
      }
      _chatUiStateStore.markMessagesChanged(resolvedConvID, changedKeys);
      _markNeedsNotify();
    }
  }

  _onReceiveC2CReadReceipt(List<V2TimMessageReceipt> receiptList) {
    var changed = false;
    final peerReadConvIds = <String, int>{};
    for (var receipt in receiptList) {
      final peerID = receipt.userID.trim();
      if (peerID.isEmpty) {
        continue;
      }
      final readAt = _receiptTimestamp(receipt.timestamp);
      final peerKey = _normalizeC2CKey(peerID).toLowerCase();
      if (readAt > (_c2cPeerReadTimestampMap[peerKey] ?? 0)) {
        _c2cPeerReadTimestampMap[peerKey] = readAt;
        changed = true;
      }

      final normalizedPeer = _normalizeC2CKey(peerID);
      if (normalizedPeer.isNotEmpty) {
        peerReadConvIds['c2c_$normalizedPeer'] = readAt;
      }

      for (final entry in _messageListMap.entries.toList()) {
        if (!_isC2CConversationForPeer(entry.key, peerID)) {
          continue;
        }
        peerReadConvIds[entry.key] = readAt;
        final list = entry.value;
        if (list == null || list.isEmpty) {
          continue;
        }
        var convChanged = false;
        final changedKeys = <String>{};
        final updated = list.map((element) {
          final isSelf = element.isSelf ?? true;
          final timestamp = element.timestamp ?? 0;
          final shouldMarkRead = isSelf &&
              element.isPeerRead != true &&
              (readAt <= 0 || timestamp <= 0 || timestamp <= readAt);
          if (shouldMarkRead) {
            element.isPeerRead = true;
            final msgID = element.msgID;
            if (msgID != null && msgID.isNotEmpty) {
              _messageReadReceiptMap[msgID] = V2TimMessageReceipt(
                userID: peerID,
                timestamp: readAt,
                msgID: msgID,
                isPeerRead: true,
              );
            }
            changedKeys.add(ChatUiStateStore.messageKeyOf(element));
            if (msgID != null && msgID.isNotEmpty) {
              changedKeys.add(msgID);
            }
            convChanged = true;
          }
          return element;
        }).toList();
        if (convChanged) {
          _messageListMap[entry.key] = updated;
          _chatUiStateStore.markMessagesChanged(entry.key, changedKeys);
          changed = true;
        }
      }
    }
    for (final entry in peerReadConvIds.entries) {
      ConversationPeerReadCoordinator.scheduleNotify(
        conversationID: entry.key,
        peerReadAtSec: entry.value,
      );
    }
    if (changed) {
      _markNeedsNotify();
    }
  }

  _onReceiveMessageReadReceipts(List<V2TimMessageReceipt> receiptList) {
    try {
      var changed = false;
      for (var receipt in receiptList) {
        final msgID = receipt.msgID;
        if (msgID != null && msgID.isNotEmpty) {
          final next = V2TimMessageReceipt(
            userID: receipt.userID,
            timestamp: _receiptTimestamp(receipt.timestamp),
            msgID: msgID,
            isPeerRead: receipt.isPeerRead,
            readCount: receipt.readCount,
            unreadCount: receipt.unreadCount,
            groupID: receipt.groupID,
          );
          final previous = _messageReadReceiptMap[msgID];
          if (previous?.isPeerRead != next.isPeerRead ||
              previous?.timestamp != next.timestamp ||
              previous?.readCount != next.readCount ||
              previous?.unreadCount != next.unreadCount) {
            _messageReadReceiptMap[msgID] = next;
            changed = true;
          }
          if (_isReceiptFullyRead(next)) {
            final convId = _conversationIdForReadReceipt(next);
            if (convId != null && convId.isNotEmpty) {
              ConversationPeerReadCoordinator.scheduleNotify(
                conversationID: convId,
                msgID: msgID,
                peerReadAtSec: next.timestamp,
              );
            }
          }
        }
      }
      if (changed) {
        for (final receipt in receiptList) {
          final msgID = receipt.msgID;
          if (msgID != null && msgID.isNotEmpty) {
            _markMessageRowsChangedByMsgID(msgID);
          }
        }
        _markNeedsNotify();
      }
    } catch (e) {}
  }

  bool _isReceiptFullyRead(V2TimMessageReceipt receipt) {
    if (receipt.isPeerRead == true) {
      return true;
    }
    final unread = receipt.unreadCount;
    final read = receipt.readCount ?? 0;
    return unread != null && unread == 0 && read > 0;
  }

  String? _conversationIdForReadReceipt(V2TimMessageReceipt receipt) {
    final group = receipt.groupID?.trim() ?? '';
    if (group.isNotEmpty) {
      return group.startsWith('group_') ? group : 'group_$group';
    }
    final msgID = receipt.msgID?.trim() ?? '';
    if (msgID.isNotEmpty) {
      for (final entry in _messageListMap.entries) {
        final list = entry.value;
        if (list == null || list.isEmpty) {
          continue;
        }
        for (final message in list) {
          if (message.msgID == msgID) {
            return entry.key;
          }
        }
      }
    }
    final peer = _normalizeC2CKey(receipt.userID);
    if (peer.isNotEmpty) {
      return 'c2c_$peer';
    }
    return null;
  }

  _onSendMessageProgress(V2TimMessage message, int progress) {
    final convID = TencentUtils.checkString(message.userID) ?? message.groupID;
    if (convID == null || convID.isEmpty) {
      return;
    }
    final msgID = message.msgID;
    final id = message.id;
    if (isOutgoingMediaCancelled(id) || isOutgoingMediaCancelled(msgID)) {
      return;
    }
    final progressClamped = progress.clamp(0, 100);
    if (progressClamped > 0 && progressClamped < 100) {
      if (msgID != null && msgID.isNotEmpty) {
        setMessageProgress(msgID, progressClamped);
      }
      if (id != null && id.isNotEmpty) {
        setMessageProgress(id, progressClamped);
      }
      _markMessageRowChangedByIds(convID, msgID: msgID, clientId: id);
      _markNeedsNotify();
    } else if (progressClamped >= 100) {
      if (msgID != null && msgID.isNotEmpty) {
        clearUploadProgress(msgID);
      }
      if (id != null && id.isNotEmpty) {
        clearUploadProgress(id);
      }
      _markMessageRowChangedByIds(convID, msgID: msgID, clientId: id);
    }
    if (progressClamped >= 100 ||
        message.status == MessageStatus.V2TIM_MSG_STATUS_SEND_SUCC) {
      if (_syncSelfSentMessage(
        convID,
        message,
        forceSuccess: true,
      )) {
        _markNeedsNotify();
        return;
      }
    }
    final list = _messageListMap[convID];
    if (list == null || list.isEmpty) {
      return;
    }
    var changed = false;
    final updated = list.map((item) {
      final sameMsgID = msgID != null &&
          msgID.isNotEmpty &&
          item.msgID != null &&
          item.msgID == msgID;
      final sameId =
          id != null && id.isNotEmpty && item.id != null && item.id == id;
      if (!sameMsgID && !sameId) {
        return item;
      }
      if (item.status == MessageStatus.V2TIM_MSG_STATUS_SENDING &&
          progressClamped >= 100) {
        final next = _cloneMessage(message);
        next.status = MessageStatus.V2TIM_MSG_STATUS_SEND_SUCC;
        changed = true;
        return next;
      }
      return item;
    }).toList();
    if (changed) {
      _messageListMap[convID] = updated;
      _markMessageRowChangedByIds(convID, msgID: msgID, clientId: id);
      _markNeedsNotify();
    }
  }

  Future<void> onMessageDownloadProgressCallback(
      V2TimMessageDownloadProgress messageProgress) async {
    final currentProgress = getMessageProgress(messageProgress.msgID);
    if (kDebugMode) {
      print(
          "onMessageDownloadProgressCallback, ${messageProgress.type} - ${messageProgress.isFinish} - ${messageProgress.currentSize} - $currentProgress - ");
    }

    if (messageProgress.isError || messageProgress.errorCode != 0) {
      V2TimMessage? message =
          await _findAndRetrieveMessage(messageProgress.msgID);
      _handleDownloadError(messageProgress, message);
      return;
    }

    if (messageProgress.isFinish && currentProgress < 100) {
      V2TimMessage? message =
          await _findAndRetrieveMessage(messageProgress.msgID);
      _handleFinishedDownload(messageProgress, message);
      return;
    }

    _updateProgressIfNeeded(messageProgress, currentProgress);
  }

  Future<V2TimMessage?> _findAndRetrieveMessage(String messageId) async {
    final messages =
        await _messageService.findMessages(messageIDList: [messageId]);
    return messages?.first;
  }

  void _handleFinishedDownload(
      V2TimMessageDownloadProgress messageProgress, V2TimMessage? message) {
    if (message != null) {
      bool isImageType =
          message.elemType == MessageElemType.V2TIM_ELEM_TYPE_IMAGE;
      bool isVideoType =
          message.elemType == MessageElemType.V2TIM_ELEM_TYPE_VIDEO;
      const originalImageType = 0;
      if (!isImageType && !isVideoType) {
        _updateMessageLocationAndDownloadFile(messageProgress);
      } else if ((isImageType && messageProgress.type == originalImageType) ||
          (isVideoType && !messageProgress.isSnapshot)) {
        Future.delayed(const Duration(seconds: 1),
            () => _updateMessageAndDownloadFile(message, messageProgress));
      } else {
        return;
      }
    } else {
      _updateMessageLocationAndDownloadFile(messageProgress);
    }
  }

  void _handleDownloadError(
      V2TimMessageDownloadProgress messageProgress, V2TimMessage? message) {
    setMessageProgress(messageProgress.msgID, 0);
    _markMessageRowsChangedByMsgID(messageProgress.msgID);
    _markNeedsNotify();
    downloadFile();
  }

  void _updateMessageAndDownloadFile(
      V2TimMessage message, V2TimMessageDownloadProgress messageProgress) {
    updateAsyncMessage(
        message,
        TencentUtils.checkString(message.userID) ??
            TencentUtils.checkString(message.groupID) ??
            "");

    _updateMessageLocationAndDownloadFile(messageProgress);
  }

  void _updateMessageLocationAndDownloadFile(
      V2TimMessageDownloadProgress messageProgress) {
    setFileMessageLocation(messageProgress.msgID, messageProgress.path);
    setMessageProgress(messageProgress.msgID, 100);
    _markMessageRowsChangedByMsgID(messageProgress.msgID);
    _markNeedsNotify();
    downloadFile();
  }

  void _updateProgressIfNeeded(
      V2TimMessageDownloadProgress messageProgress, int currentProgress) {
    try {
      if (messageProgress.totalSize != -1 && !messageProgress.isFinish) {
        int progress = min(
            99,
            (messageProgress.currentSize / messageProgress.totalSize * 100)
                .floor());
        if (progress > 1 && progress > currentProgress) {
          setMessageProgress(messageProgress.msgID, progress);
          _markMessageRowsChangedByMsgID(messageProgress.msgID);
          _markNeedsNotify();
        }
      }
    } catch (e) {
      outputLogger.i("calculate error: ${messageProgress.toJson()}");
    }
  }

  void addAdvancedMsgListener() {
    _messageService.addAdvancedMsgListener(listener: advancedMsgListener);
  }

  void removeAdvanceMsgListener() {
    _messageService.removeAdvancedMsgListener(listener: advancedMsgListener);
  }

  markMessageAsRead({
    required String convID,
    required ConvType convType,
  }) async {
    if (convType == ConvType.c2c) {
      return _messageService.markC2CMessageAsRead(userID: convID);
    }
    if (kIsWeb) {
      return null;
    }
    return _messageService.markGroupMessageAsRead(groupID: convID);
  }

  void _scheduleActiveReadReport({
    required String convID,
    required ConvType convType,
  }) {
    final normalizedConvID = _normalizeConversationID(convID);
    if (normalizedConvID.isEmpty) {
      return;
    }

    if (convType == ConvType.c2c) {
      _activeReadReportDebounceMap[normalizedConvID]?.cancel();
      _activeReadReportDebounceMap[normalizedConvID] = Timer(
        const Duration(milliseconds: 500),
        () {
          _activeReadReportDebounceMap.remove(normalizedConvID);
          if (_isSameConversationID(normalizedConvID, currentSelectedConv)) {
            markMessageAsRead(convID: normalizedConvID, convType: convType);
          }
        },
      );
      return;
    }

    if (kIsWeb) {
      return;
    }

    final now = DateTime.now().millisecondsSinceEpoch;
    final last = _lastActiveReadReportAtMs[normalizedConvID] ?? 0;
    final elapsed = now - last;
    final delayMs = elapsed >= _activeReadReportMinIntervalMs
        ? _activeReadReportDebounceMs
        : _activeReadReportMinIntervalMs - elapsed;

    _activeReadReportDebounceMap[normalizedConvID]?.cancel();
    _activeReadReportDebounceMap[normalizedConvID] = Timer(
      Duration(milliseconds: delayMs),
      () async {
        _activeReadReportDebounceMap.remove(normalizedConvID);
        if (!_isSameConversationID(normalizedConvID, currentSelectedConv)) {
          return;
        }
        await markMessageAsRead(convID: normalizedConvID, convType: convType);
        _lastActiveReadReportAtMs[normalizedConvID] =
            DateTime.now().millisecondsSinceEpoch;
      },
    );
  }

  Future<GroupReceiptAllowType?> _loadGroupReceiptType(String groupID) async {
    final groupInfoList =
        await _groupServices.getGroupsInfo(groupIDList: [groupID]);
    if (groupInfoList == null || groupInfoList.isEmpty) {
      return null;
    }
    final groupInfo = groupInfoList.first.groupInfo;
    const groupTypeMap = {
      "Meeting": GroupReceiptAllowType.meeting,
      "Public": GroupReceiptAllowType.public,
      "Work": GroupReceiptAllowType.work,
      "Community": GroupReceiptAllowType.community,
    };
    return groupTypeMap[groupInfo?.groupType];
  }

  bool _isReadReceiptAllowedGroup(GroupReceiptAllowType? groupType) {
    return groupType == GroupReceiptAllowType.work ||
        groupType == GroupReceiptAllowType.public ||
        groupType == GroupReceiptAllowType.meeting;
  }

  Future<V2TimValueCallback<V2TimMessage>?>? sendMessageFromController({
    required V2TimMessage? messageInfo,
    required ConvType convType,
    required String convID,
    ValueChanged<String>? setInputField,
    OfflinePushInfo? offlinePushInfo,
    MessagePriorityEnum priority = MessagePriorityEnum.V2TIM_PRIORITY_NORMAL,
    bool? onlineUserOnly,
    bool? isExcludedFromUnreadCount,
    bool? needReadReceipt,
    String? cloudCustomData,
    String? localCustomData,
  }) {
    final TUIChatModelTools tools = serviceLocator<TUIChatModelTools>();
    List<V2TimMessage> currentHistoryMsgList = _messageListMap[convID] ?? [];
    if (messageInfo != null) {
      final messageInfoWithSender = messageInfo.sender == null
          ? tools.setUserInfoForMessage(messageInfo, messageInfo.id!)
          : messageInfo;
      messageInfoWithSender.status = MessageStatus.V2TIM_MSG_STATUS_SENDING;
      markMessageEnterAnimation(messageInfoWithSender);
      prepareForOutgoingMessage(convID);
      assignOutgoingLocalSeq(convID, messageInfoWithSender);
      currentHistoryMsgList = [messageInfoWithSender, ...currentHistoryMsgList];
      setMessageList(convID, currentHistoryMsgList);
      requestPinToBottom(convID, force: true);
      if (loadingMessage[convID] != null &&
          loadingMessage[convID]!.isNotEmpty) {
        loadingMessage[convID]!.add(messageInfoWithSender);
      } else {
        loadingMessage[convID] = <V2TimMessage>[messageInfoWithSender];
      }
      return _sendMessage(
        priority: priority,
        onlineUserOnly: onlineUserOnly,
        isExcludedFromUnreadCount: isExcludedFromUnreadCount,
        needReadReceipt: needReadReceipt,
        cloudCustomData: cloudCustomData,
        localCustomData: localCustomData,
        isExcludedFromContentModeration:
            messageInfo.isExcludedFromContentModeration ?? false,
        convID: convID,
        setInputField: setInputField,
        id: messageInfo.id as String,
        convType: ConvType.values[convType.index],
        offlinePushInfo: offlinePushInfo ??
            tools.buildMessagePushInfo(
                messageInfo, convID, ConvType.values[convType.index]),
      );
    }
    return null;
  }

  Future<V2TimValueCallback<V2TimMessage>?> sendReplyMessageFromController({
    required String text,
    required V2TimMessage messageBeenReplied,
    required String convID,
    required ConvType convType,
    ValueChanged<String>? setInputField,
    OfflinePushInfo? offlinePushInfo,
    MessagePriorityEnum priority = MessagePriorityEnum.V2TIM_PRIORITY_NORMAL,
    bool? onlineUserOnly,
    bool? isExcludedFromUnreadCount,
    bool? needReadReceipt,
    String? localCustomData,
  }) async {
    if (text.isEmpty) {
      return null;
    }
    final TUIChatModelTools tools = serviceLocator<TUIChatModelTools>();
    List<V2TimMessage> currentHistoryMsgList = _messageListMap[convID] ?? [];
    V2TimMsgCreateInfoResult? textMessageInfo =
        await _messageService.createTextMessage(text: text);

    textMessageInfo = await _messageService.createTextAtMessage(
        text: text +
            "\n@${TencentUtils.checkString(messageBeenReplied.nickName) ?? TencentUtils.checkString(messageBeenReplied.sender) ?? TencentUtils.checkString(messageBeenReplied.userID)}",
        atUserList: [
          TencentUtils.checkString(messageBeenReplied.sender) ??
              TencentUtils.checkString(messageBeenReplied.userID) ??
              ""
        ]);

    final V2TimMessage? messageInfo = textMessageInfo!.messageInfo;

    if (messageInfo != null) {
      final messageInfoWithSender = messageInfo.sender == null
          ? tools.setUserInfoForMessage(
              messageInfo, messageInfo.id ?? textMessageInfo.id ?? "")
          : messageInfo;
      messageInfoWithSender.status = MessageStatus.V2TIM_MSG_STATUS_SENDING;
      final hasNickName = messageBeenReplied.nickName != null &&
          messageBeenReplied.nickName != "";
      final cloudCustomData = {
        "messageReply": {
          "messageID": messageBeenReplied.msgID,
          "messageAbstract": tools.getMessageAbstract(
              messageBeenReplied, abstractMessageBuilder),
          "messageSender": hasNickName
              ? messageBeenReplied.nickName
              : messageBeenReplied.sender,
          "messageType": messageBeenReplied.elemType,
          "version": 1
        }
      };
      messageInfoWithSender.cloudCustomData = json.encode(cloudCustomData);

      markMessageEnterAnimation(messageInfoWithSender);
      prepareForOutgoingMessage(convID);
      assignOutgoingLocalSeq(convID, messageInfoWithSender);
      currentHistoryMsgList = [messageInfoWithSender, ...currentHistoryMsgList];
      setMessageList(convID, currentHistoryMsgList);
      requestPinToBottom(convID, force: true);
      if (loadingMessage[convID] != null &&
          loadingMessage[convID]!.isNotEmpty) {
        loadingMessage[convID]!.add(messageInfoWithSender);
      } else {
        loadingMessage[convID] = <V2TimMessage>[messageInfoWithSender];
      }

      return _sendMessage(
        cloudCustomData: json.encode(cloudCustomData),
        id: textMessageInfo.id as String,
        offlinePushInfo: offlinePushInfo ??
            tools.buildMessagePushInfo(
                messageInfo, convID, ConvType.values[convType.index]),
        priority: priority,
        onlineUserOnly: onlineUserOnly,
        isExcludedFromUnreadCount: isExcludedFromUnreadCount,
        needReadReceipt: needReadReceipt,
        localCustomData: localCustomData,
        convID: convID,
        setInputField: setInputField,
        convType: ConvType.values[convType.index],
      );
    }
    return null;
  }

  Future<bool> setLocalCustomData(
      String msgID, String localCustomData, String conversationID) async {
    final res = await _messageService.setLocalCustomData(
        msgID: msgID, localCustomData: localCustomData);
    List<V2TimMessage> messageList = _messageListMap[conversationID] ?? [];
    if (res.code == 0) {
      messageList = messageList.map((item) {
        if (item.msgID == msgID) {
          item.localCustomData = localCustomData;
          // item.id = DateTime.now().millisecondsSinceEpoch.toString();
        }
        return item;
      }).toList();
      setMessageList(conversationID, messageList,
          needResetNewMessageCount: false);
      return true;
    }
    return false;
  }

  Future<bool> setLocalCustomInt(
      String msgID, int localCustomInt, String conversationID) async {
    final res = await _messageService.setLocalCustomInt(
        msgID: msgID, localCustomInt: localCustomInt);
    List<V2TimMessage> messageList = _messageListMap[conversationID] ?? [];
    if (res.code == 0) {
      messageList = messageList.map((item) {
        if (item.msgID == msgID) {
          item.localCustomInt = HistoryMessageDartConstant.read;
          // item.id = DateTime.now().millisecondsSinceEpoch.toString();
        }
        return item;
      }).toList();
      setMessageList(conversationID, messageList,
          needResetNewMessageCount: false);
      return true;
    }
    return false;
  }

  Future<V2TimValueCallback<V2TimMessage>> _sendMessage({
    required String id,
    required String convID,
    required ConvType convType,
    OfflinePushInfo? offlinePushInfo,
    bool? onlineUserOnly = false,
    bool? isEditStatusMessage = false,
    GroupReceiptAllowType? groupType,
    ValueChanged<String>? setInputField,
    MessagePriorityEnum priority = MessagePriorityEnum.V2TIM_PRIORITY_NORMAL,
    bool? isExcludedFromUnreadCount,
    bool? needReadReceipt,
    String? cloudCustomData,
    String? localCustomData,
    bool isExcludedFromContentModeration = false,
  }) async {
    String receiver = convType == ConvType.c2c ? convID : '';
    String groupID = convType == ConvType.group ? convID : '';
    final receiptGroupType = groupType ??
        (convType == ConvType.group
            ? await _loadGroupReceiptType(groupID)
            : null);
    final useReadReceipt =
        (needReadReceipt ?? chatConfig.isShowReadingStatus) &&
            (convType != ConvType.group ||
                _isReadReceiptAllowedGroup(receiptGroupType));
    final sendMsgRes = await _messageService.sendMessage(
        id: id,
        receiver: receiver,
        needReadReceipt: useReadReceipt,
        groupID: groupID,
        priority: priority,
        localCustomData: localCustomData,
        isExcludedFromUnreadCount: isExcludedFromUnreadCount ?? false,
        offlinePushInfo: offlinePushInfo,
        isExcludedFromContentModeration: isExcludedFromContentModeration,
        onlineUserOnly: onlineUserOnly ?? false,
        cloudCustomData: cloudCustomData ??
            json.encode({
              "messageFeature": {
                "needTyping": 1,
                "version": 1,
              }
            }));
    if (isEditStatusMessage == false) {
      updateMessage(
          sendMsgRes, convID, id, convType, receiptGroupType, setInputField);
    }
    if (_lifeCycle?.messageDidSend != null) {
      _lifeCycle!.messageDidSend(sendMsgRes);
    }

    return sendMsgRes;
  }

  String? _messageEnterAnimationKey(V2TimMessage message) {
    final id = message.id;
    if (id != null && id.toString().isNotEmpty) {
      return id.toString();
    }
    final msgID = message.msgID;
    if (msgID != null && msgID.isNotEmpty) {
      return msgID;
    }
    return null;
  }

  void markMessageEnterAnimation(V2TimMessage message) {
    final skip = chatConfig.skipMessageEnterAnimationForMessage;
    if (skip != null && skip(message)) {
      return;
    }
    final convId = _messageConversationID(message);
    if (convId != null && isBulkMessageSyncActive(convId)) {
      return;
    }
    final key = _messageEnterAnimationKey(message);
    if (key == null) {
      return;
    }
    final throttleMs = chatConfig.messageEnterAnimationThrottleMs;
    if (convId != null && throttleMs > 0) {
      final now = DateTime.now().millisecondsSinceEpoch;
      final lastMark = _enterAnimationThrottleMarkMsByConv[convId] ?? 0;
      if (now - lastMark < throttleMs) {
        final superseded = _enterAnimationThrottlePendingKeyByConv[convId];
        if (superseded != null) {
          _messageEnterAnimationKeys.remove(superseded);
        }
      }
      _enterAnimationThrottleMarkMsByConv[convId] = now;
      _enterAnimationThrottlePendingKeyByConv[convId] = key;
    }
    _messageEnterAnimationKeys.add(key);
    _maybeScheduleSendFlyOverlay(message, key);
  }

  ChatSendFlyOverlayRequest? get sendFlyOverlayRequest =>
      _sendFlyOverlayRequest;

  bool isSendFlyOverlayPendingForMessage(V2TimMessage message) {
    final req = _sendFlyOverlayRequest;
    if (req == null) {
      return false;
    }
    final key = _messageEnterAnimationKey(message);
    return key != null && key == req.messageKey;
  }

  bool shouldHideBubbleForSendFly(V2TimMessage message) {
    if (!chatConfig.sendFlyOverlayEnabled) {
      return false;
    }
    return isSendFlyOverlayPendingForMessage(message);
  }

  void reportSendFlyTargetRect(V2TimMessage message, Rect rect) {
    final req = _sendFlyOverlayRequest;
    if (req == null) {
      return;
    }
    final key = _messageEnterAnimationKey(message);
    if (key == null || key != req.messageKey) {
      return;
    }
    final existing = req.targetRect;
    if (existing != null &&
        (existing.top - rect.top).abs() < 0.5 &&
        (existing.height - rect.height).abs() < 0.5) {
      return;
    }
    _sendFlyOverlayRequest = req.copyWith(targetRect: rect);
    notifyListeners();
  }

  void completeSendFlyOverlay() {
    if (_sendFlyOverlayRequest == null) {
      return;
    }
    _sendFlyOverlayRequest = null;
    notifyListeners();
  }

  void _maybeScheduleSendFlyOverlay(V2TimMessage message, String key) {
    if (!chatConfig.sendFlyOverlayEnabled) {
      return;
    }
    if (message.isSelf != true) {
      return;
    }
    if (message.elemType != MessageElemType.V2TIM_ELEM_TYPE_TEXT) {
      return;
    }
    final text = message.textElem?.text?.trim() ?? '';
    if (text.isEmpty) {
      return;
    }
    final convId = _messageConversationID(message);
    if (convId == null || convId.isEmpty) {
      return;
    }
    _sendFlyOverlayRequest = ChatSendFlyOverlayRequest(
      messageKey: key,
      text: text,
      conversationId: convId,
    );
    notifyListeners();
  }

  void _markIncomingMessageEnterAnimation(V2TimMessage message) {
    if (message.isSelf == true) {
      return;
    }
    if (!shouldAnimateInboundPresentation) {
      return;
    }
    // WeChat list-push mode animates the viewport itself: a complete row starts
    // below the list's clipping edge and the scroll offset moves back to the
    // bottom. A per-bubble translate would double the movement and make the
    // row appear to expand or rebound.
    if (chatConfig.messageEnterAnimationStyle ==
            MessageEnterAnimationStyle.wechat &&
        chatConfig.messageEnterAnimationListPushEnabled) {
      return;
    }
    final convId = _messageConversationID(message);
    if (convId != null && isBulkMessageSyncActive(convId)) {
      return;
    }
    if (convId != null && !_isActiveChatNearBottom(convId)) {
      return;
    }
    markMessageEnterAnimation(message);
  }

  /// 消息是否仍在播放入场动画（仿微信 notifyItemInserted 后 ItemAnimator 未结束）。
  bool isMessageEnterAnimationPending(V2TimMessage message) {
    final key = _messageEnterAnimationKey(message);
    if (key == null) {
      return false;
    }
    return _messageEnterAnimationKeys.contains(key);
  }

  void finishMessageEnterAnimation(V2TimMessage message) {
    final key = _messageEnterAnimationKey(message);
    if (key != null) {
      _messageEnterAnimationKeys.remove(key);
    }
  }

  @Deprecated('Use isMessageEnterAnimationPending')
  bool shouldPlayMessageEnterAnimation(V2TimMessage message) {
    return isMessageEnterAnimationPending(message);
  }

  @Deprecated('Use markMessageEnterAnimation')
  void markOutgoingMessageEnterAnimation(V2TimMessage message) {
    markMessageEnterAnimation(message);
  }

  @Deprecated('Use isMessageEnterAnimationPending')
  bool shouldPlayOutgoingEnterAnimation(V2TimMessage message) {
    return isMessageEnterAnimationPending(message);
  }

  /// 覆盖 msgID/seq/状态的内容签名。打开会话后本地校验、头像回填等
  /// 路径会把同样的列表原样写回；签名一致时跳过 revision bump，
  /// 避免 Selector 因 revision 变化整表重建（进入页面时头像/列表抖动）。
  ///
  /// 故意不含 faceUrl：头像回填只改展示字段，不应触发消息列表 revision。
  static bool _listHasCorrelatingDup(List<V2TimMessage> messages) {
    if (messages.length < 2) {
      return false;
    }
    final scanCount = messages.length < 32 ? messages.length : 32;
    for (var i = 0; i < scanCount; i++) {
      for (var j = i + 1; j < scanCount; j++) {
        if (messagesCorrelateForDedup(messages[i], messages[j])) {
          return true;
        }
      }
    }
    return false;
  }

  static String _messageListContentSignature(List<V2TimMessage> messageList) {
    final buffer = StringBuffer()
      ..write(messageList.length)
      ..write(';');
    for (final message in messageList) {
      buffer
        ..write(message.msgID ?? message.id ?? '')
        ..write(':')
        ..write(message.seq ?? '')
        ..write(':')
        ..write(message.status ?? '')
        ..write(';');
    }
    return buffer.toString();
  }

  final Map<String, String> _messageListContentSignatureByConv = {};

  void setMessageList(String conversationID, List<V2TimMessage> messageList,
      {bool needResetNewMessageCount = true,
      bool isDeleteMsg = false,
      /// true：整表替换，不与旧内存拼接（会话预览首屏 / 已合并全量列表写入用）。
      bool replace = false}) {
    final previous = _messageListMap[conversationID] ?? const <V2TimMessage>[];
    // 始终 dedupe：分页写入常已含 previous，再拼接会产生重复 key，表现为顶部无法加载。
    final mergedInput = replace || isDeleteMsg || previous.isEmpty
        ? messageList
        : <V2TimMessage>[...messageList, ...previous];
    var sorted = sortMessagesNewestFirst(dedupeMessages(mergedInput));
    final secondPass = sortMessagesNewestFirst(dedupeMessages(sorted));
    if (secondPass.length < sorted.length) {
      sorted = secondPass;
    }
    if (replace || isDeleteMsg || previous.isEmpty || sorted.length != previous.length) {
      final prevNewest = previous.isEmpty ? 0 : (previous.first.timestamp ?? 0);
      final nextNewest = sorted.isEmpty ? 0 : (sorted.first.timestamp ?? 0);
      ChatHistoryTrace.log(
        replace ? 'set_list_replace' : 'set_list_merge',
        conversationID: conversationID,
        extras: <String, Object?>{
          'isDeleteMsg': isDeleteMsg,
          'prevCount': previous.length,
          'nextCount': sorted.length,
          'prevNewestTs': prevNewest,
          'nextNewestTs': nextNewest,
          'windowWentOlder':
              prevNewest > 0 && nextNewest > 0 && nextNewest < prevNewest,
          ...ChatHistoryTrace.windowSummary(previous, prefix: 'prev'),
          ...ChatHistoryTrace.windowSummary(sorted, prefix: 'next'),
        },
      );
    }
    final normalizedConvId = _inboundStateKey(conversationID);
    final unreadState = _inboundUnreadStateFor(normalizedConvId, create: false);
    final holdUntilUserBottom =
        _deferredUntilUserBottomConversations.contains(normalizedConvId);
    var projectionChanged = false;
    if (replace) {
      // 会话预览同源首屏 / 分页全量写回：必须露出完整窗口。
      // 否则上一轮 inbound hide（群聊未读缓充）会把窗口内消息滤掉，出现空洞。
      projectionChanged =
          _revealAllDeferredProjectionAcrossAliases(conversationID);
      final authoritativePrefix = '$normalizedConvId|';
      _authoritativeDeferredIncomingKeys.removeWhere(
        (key) => key.startsWith(authoritativePrefix),
      );
    } else if (holdUntilUserBottom &&
        unreadState.bufferedMessageKeys.isNotEmpty) {
      final authoritativeDeferred = sorted
          .where(
            (message) => unreadState.bufferedMessageKeys.contains(
              messageDedupKey(message),
            ),
          )
          .toList(growable: false);
      if (authoritativeDeferred.isNotEmpty) {
        projectionChanged = true;
        _hideInboundProjection(conversationID, authoritativeDeferred);
        for (final message in authoritativeDeferred) {
          _authoritativeDeferredIncomingKeys.add(
            _authoritativeDeferredKey(conversationID, message),
          );
        }
      }
    }
    // 先算内容签名：进页 hydrate / peek 原样回写时必须跳过 bump+notify，
    // 否则短会话一次打开会固定多轮 list_rebuild（日志里 spacer 晚到也叠在这上面）。
    if (_listHasCorrelatingDup(sorted)) {
      final tightened = sortMessagesNewestFirst(dedupeMessages(sorted));
      if (tightened.length < sorted.length) {
        sorted = tightened;
      }
    }
    var signature = _messageListContentSignature(sorted);
    var signatureChanged =
        _messageListContentSignatureByConv[conversationID] != signature;
    if (!signatureChanged && !isDeleteMsg && !_listHasCorrelatingDup(sorted)) {
      // 列表语义未变：仍补种行高供短历史估 spacer，但不掀翻 UI。
      ChatMessageHeightCache.instance.seedEstimatesForMessages(sorted);
      _messageListContentSignatureByConv[conversationID] = signature;
      if (needResetNewMessageCount && !holdUntilUserBottom) {
        unreadState.receivedCount = 0;
      }
      // 签名未变但投影显隐变了：仍需通知，否则缓充消息会一直藏着。
      if (projectionChanged) {
        _markNeedsNotify();
      }
      return;
    }

    _messageListMap[conversationID] = sorted;
    // 首屏 / 增量写入时补种缺省行高，避免冷进页 short-history 全靠常量估算。
    ChatMessageHeightCache.instance.seedEstimatesForMessages(sorted);
    _messageListContentSignatureByConv[conversationID] = signature;
    _bumpMessageListRevisionFor(
      conversationID,
      reason:
          isDeleteMsg ? 'setMessageList_delete' : 'setMessageList_signature',
    );
    // bump 对 setMessageList_* 不再清签名；此处再写一次以防旧调用路径。
    _messageListContentSignatureByConv[conversationID] = signature;
    if (needResetNewMessageCount && !holdUntilUserBottom) {
      unreadState.receivedCount = 0;
    }

    if (isDeleteMsg) {
      final retainedKeys = sorted.map(messageDedupKey).toSet();
      final removedKeys = previous
          .map(messageDedupKey)
          .where((key) => !retainedKeys.contains(key))
          .toSet();
      if (removedKeys.isNotEmpty) {
        final projectionKey = _inboundStateKey(conversationID);
        final hidden = _inboundHiddenKeysByConv[projectionKey];
        hidden?.removeWhere(removedKeys.contains);
        if (hidden != null && hidden.isEmpty) {
          _inboundHiddenKeysByConv.remove(projectionKey);
        }
        final authoritativePrefix = '$projectionKey|';
        _authoritativeDeferredIncomingKeys.removeWhere(
          (key) =>
              key.startsWith(authoritativePrefix) &&
              removedKeys.contains(key.substring(authoritativePrefix.length)),
        );
        final state = _inboundUnreadStateFor(conversationID, create: false);
        state.bufferedMessages.removeWhere(
          (message) => removedKeys.contains(messageDedupKey(message)),
        );
        state.bufferedMessageKeys.removeWhere(removedKeys.contains);
        _inboundFastForwardMessageKeys.removeWhere(removedKeys.contains);
        _bumpMessageProjectionRevisionFor(projectionKey);
      }
      HistoryMessagePosition position = getMessageListPosition(conversationID);
      if (position == HistoryMessagePosition.awayTwoScreen) {
        _storeHistoryMessagePosition(
          conversationID,
          HistoryMessagePosition.notShowLatest,
        );
      }
    }

    _markNeedsNotify();
  }

  V2TimMessage _cloneMessage(V2TimMessage message) {
    try {
      return V2TimMessage.fromJson(
        Map<String, dynamic>.from(message.toJson()),
      );
    } catch (_) {
      return message;
    }
  }

  int _findMessageIndexForUpdate(
    List<V2TimMessage> messageList,
    String id,
    V2TimMessage sentMessage,
  ) {
    return findReplaceableOutgoingIndex(
      '',
      sentMessage,
      priorTempId: id,
      listOverride: messageList,
    );
  }

  updateMessage(
      V2TimValueCallback<V2TimMessage> sendMsgRes,
      String convID,
      String id,
      ConvType convType,
      GroupReceiptAllowType? groupType,
      ValueChanged<String>? setInputField) {
    List<V2TimMessage> currentHistoryMsgList = _messageListMap[convID] ?? [];
    final V2TimMessage sendMsgResData = sendMsgRes.data as V2TimMessage;
    final resolvedMessage = _cloneMessage(sendMsgResData);

    // Always set the correct status based on send result
    if (sendMsgRes.code == 0) {
      resolvedMessage.status = MessageStatus.V2TIM_MSG_STATUS_SEND_SUCC;
      setMessageProgress(id, 100);
      final resolvedMsgID = resolvedMessage.msgID?.trim();
      if (resolvedMsgID != null && resolvedMsgID.isNotEmpty) {
        setMessageProgress(resolvedMsgID, 100);
      }
    } else {
      resolvedMessage.status = MessageStatus.V2TIM_MSG_STATUS_SEND_FAIL;
    }
    if (resolvedMessage.id == null || resolvedMessage.id!.isEmpty) {
      resolvedMessage.id = id;
    }
    final targetIndex =
        _findMessageIndexForUpdate(currentHistoryMsgList, id, resolvedMessage);
    if (sendMsgRes.code != 0 &&
        resolvedMessage.status == MessageStatus.V2TIM_MSG_STATUS_SEND_FAIL) {
      ErrorMessageConverter.attachSendFailCode(
          resolvedMessage, sendMsgRes.code);
      final msgID = resolvedMessage.msgID;
      if (msgID != null &&
          msgID.isNotEmpty &&
          resolvedMessage.localCustomData != null) {
        _messageService.setLocalCustomData(
            msgID: msgID, localCustomData: resolvedMessage.localCustomData!);
      }
    }
    V2TimMessage? previousForMerge;
    if (targetIndex != -1) {
      currentHistoryMsgList = [...currentHistoryMsgList];
      previousForMerge = currentHistoryMsgList[targetIndex];
      _preserveSoundLocalPath(previousForMerge, resolvedMessage);
      _preserveImageLocalPath(previousForMerge, resolvedMessage);
      _preserveImageDisplaySize(resolvedMessage, id);
      _preserveOutgoingLocalOrderData(previousForMerge, resolvedMessage);
      currentHistoryMsgList[targetIndex] = resolvedMessage;
    } else {
      currentHistoryMsgList = [resolvedMessage, ...currentHistoryMsgList];
    }
    final resolvedId = resolvedMessage.id ?? id;
    final resolvedMsgID = resolvedMessage.msgID;
    if (sendMsgRes.code == 0) {
      clearUploadProgress(resolvedId);
      if (resolvedMsgID != null && resolvedMsgID.isNotEmpty) {
        clearUploadProgress(resolvedMsgID);
      }
      _migrateFileMessageMetadata(id, resolvedMsgID);
      if (resolvedMessage.elemType == MessageElemType.V2TIM_ELEM_TYPE_IMAGE) {
        final layoutSize = _fileMessageSizeMap[id] ??
            ((resolvedMsgID?.isNotEmpty ?? false)
                ? _fileMessageSizeMap[resolvedMsgID!]
                : null);
        if (layoutSize != null &&
            layoutSize.width > 0 &&
            layoutSize.height > 0) {
          applyImageLayoutToMessage(resolvedMessage, layoutSize);
          if (resolvedMsgID != null && resolvedMsgID.isNotEmpty) {
            _messageService.setLocalCustomData(
              msgID: resolvedMsgID,
              localCustomData: resolvedMessage.localCustomData ?? '',
            );
          }
        }
      }
    }
    if (resolvedId.isNotEmpty || (resolvedMsgID?.isNotEmpty ?? false)) {
      currentHistoryMsgList = currentHistoryMsgList.where((element) {
        if (identical(element, resolvedMessage)) {
          return true;
        }
        final sameId = resolvedId.isNotEmpty && element.id == resolvedId;
        final sameMsgID = resolvedMsgID != null &&
            resolvedMsgID.isNotEmpty &&
            element.msgID == resolvedMsgID;
        if (!sameId && !sameMsgID) {
          return true;
        }
        return false;
      }).toList();
    }
    if (loadingMessage[convID] != null && loadingMessage[convID]!.isNotEmpty) {
      loadingMessage[convID]!.removeWhere((element) => element.id == id);
    }
    if (chatConfig.isShowReadingStatus &&
        groupType != GroupReceiptAllowType.community &&
        sendMsgRes.data?.msgID != null) {
      _messageReadReceiptMap[sendMsgRes.data!.msgID!] =
          V2TimMessageReceipt(timestamp: 0, userID: "", readCount: 0);
    }
    _registerSoundLocalPath(resolvedMessage);
    // 占位符原位回填：优先保留点击顺序；但必须让展示层按最新时间戳重排。
    final shouldSort = targetIndex == -1;
    if (shouldSort) {
      currentHistoryMsgList = sortMessagesNewestFirst(currentHistoryMsgList);
    } else if (!isNewestFirstStorageOrderValid(currentHistoryMsgList)) {
      currentHistoryMsgList = sortMessagesNewestFirst(currentHistoryMsgList);
    }
    _messageListMap[convID] = currentHistoryMsgList;
    _chatUiStateStore.bindMessageAlias(
      convID,
      id,
      ChatUiStateStore.messageKeyOf(resolvedMessage),
    );
    // temp id 上已测到的行高迁到正式 msgID，避免 send_done 后失缓存再估高抖动。
    ChatMessageHeightCache.instance.rememberAlias(
      id,
      resolvedMessage.msgID,
    );
    final knownHeight =
        ChatMessageHeightCache.instance.heightFor(resolvedMessage);
    if (knownHeight != null && knownHeight > 0) {
      ChatMessageHeightCache.instance.remember(resolvedMessage, knownHeight);
    }
    _markMessageRowChanged(convID, resolvedMessage, extraKey: id);
    // 无论是否整表 sort，都 bump revision 清掉展示缓存，避免旧顺序+新时间戳错乱。
    _bumpMessageListRevisionFor(
      convID,
      reason: shouldSort ? 'send_done_insert_sort' : 'send_done_inplace_invalidate',
    );
    _logOutgoingSendOrder(
      event: 'send_done',
      convID: convID,
      message: resolvedMessage,
      clientId: id,
      mergePath: targetIndex != -1 ? 'update_replace' : 'update_insert',
      existingIndex: targetIndex,
      reordered: shouldSort,
    );
    // 发送后 350ms suppress 窗口内推迟整表 notify，让 list-push 先播完。
    if (targetIndex != -1 && shouldSuppressOutgoingPinScroll()) {
      Future<void>.delayed(const Duration(milliseconds: 380), () {
        _markNeedsNotify();
      });
    } else {
      _markNeedsNotify();
    }
  }

  void updateAsyncMessage(
    V2TimMessage message,
    String convID,
  ) {
    if (message.id == null || message.id!.isEmpty) {
      message.id =
          message.msgID ?? DateTime.now().millisecondsSinceEpoch.toString();
    }

    final activeMessageList = _messageListMap[convID];
    if (activeMessageList == null || activeMessageList.isEmpty) {
      return;
    }
    final msgID = message.msgID;
    final changedKeys = <String>{};
    var changed = false;
    _messageListMap[convID] = activeMessageList.map((item) {
      if (item.msgID == msgID) {
        changedKeys.add(ChatUiStateStore.messageKeyOf(item));
        changed = true;
        return message;
      }
      return item;
    }).toList();
    if (changed) {
      changedKeys.add(ChatUiStateStore.messageKeyOf(message));
      if (msgID != null && msgID.isNotEmpty) {
        changedKeys.add(msgID);
      }
      _chatUiStateStore.markMessagesChanged(convID, changedKeys);
      if (convID == currentSelectedConv) {
        _markNeedsNotify();
      }
    }
  }

  /// 群 dedup 用：与 [_normalizeConversationID] 同规则，但不依赖实例。
  static String _normalizeGroupIdForDedup(String? value) {
    final raw = value?.trim() ?? '';
    if (raw.isEmpty) {
      return '';
    }
    var normalized = raw;
    if (normalized.startsWith('GROUP')) {
      normalized = normalized.substring(5);
    }
    if (normalized.startsWith('group_')) {
      normalized = normalized.substring(6);
    }
    return normalized.trim();
  }

  static String _groupShortTokenForDedup(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) {
      return '';
    }
    if (trimmed.startsWith('@TGS#_')) {
      final idx = trimmed.indexOf('@TGS#_', 1);
      return idx > 0 ? trimmed.substring(idx) : trimmed;
    }
    return trimmed;
  }

  static bool _groupIdsEquivalentForDedup(String? left, String? right) {
    final a = _normalizeGroupIdForDedup(left);
    final b = _normalizeGroupIdForDedup(right);
    if (a.isEmpty && b.isEmpty) {
      return true;
    }
    if (a.isEmpty || b.isEmpty) {
      return false;
    }
    if (a == b) {
      return true;
    }
    final shortA = _groupShortTokenForDedup(a);
    final shortB = _groupShortTokenForDedup(b);
    if (shortA.isNotEmpty && shortA == shortB) {
      return true;
    }
    return false;
  }

  /// 群消息：含 groupID、归档 msgKey，或带 archiveHistory 的群归档行（C2C 归档不算）。
  static bool _isGroupLikeMessage(V2TimMessage message) {
    final userID = message.userID?.trim() ?? '';
    if (userID.isNotEmpty) {
      return false;
    }
    final groupID = message.groupID?.trim() ?? '';
    if (groupID.isNotEmpty) {
      return true;
    }
    final msgID = message.msgID?.trim() ?? '';
    if (msgID.contains('@TGS#') && msgID.contains(':')) {
      return true;
    }
    if (HistoryPaginationAnchor.isArchiveHistoryMessage(message)) {
      return true;
    }
    return false;
  }

  /// 从 groupID 或归档 msgKey（@TGS#xxx:seq）解析 canonical 群 token。
  static String _normalizedGroupIdForMessage(V2TimMessage message) {
    final fromGroup = _normalizeGroupIdForDedup(message.groupID);
    if (fromGroup.isNotEmpty) {
      return _groupShortTokenForDedup(fromGroup);
    }
    final msgID = message.msgID?.trim() ?? '';
    if (msgID.isEmpty) {
      return '';
    }
    final colon = msgID.lastIndexOf(':');
    if (colon > 0) {
      final prefix = msgID.substring(0, colon);
      final normalized = _normalizeGroupIdForDedup(prefix);
      if (normalized.isNotEmpty) {
        return _groupShortTokenForDedup(normalized);
      }
    }
    return _groupShortTokenForDedup(_normalizeGroupIdForDedup(msgID));
  }

  static int _messageSortSeq(V2TimMessage message) {
    final fromField = int.tryParse(message.seq?.toString() ?? '') ?? 0;
    if (fromField > 0) {
      return fromField;
    }
    final msgID = message.msgID?.trim() ?? '';
    if (msgID.isEmpty) {
      return 0;
    }
    final colon = msgID.lastIndexOf(':');
    if (colon <= 0 || colon + 1 >= msgID.length) {
      return 0;
    }
    final suffix = msgID.substring(colon + 1);
    if (!RegExp(r'^\d+$').hasMatch(suffix)) {
      return 0;
    }
    return int.tryParse(suffix) ?? 0;
  }

  /// Whether [message] carries a group-global monotonic [seq] that can be
  /// trusted for chronological ordering.
  ///
  /// Only GROUP messages have a conversation-wide monotonic seq. In C2C (1-to-1)
  /// chats each side numbers its own messages independently, so seq is NOT
  /// comparable across senders and must never drive ordering — timestamps are
  /// the source of truth there.
  static bool _hasGroupSeqOrdering(V2TimMessage message) {
    if (_messageSortSeq(message) <= 0) {
      return false;
    }
    return _isGroupLikeMessage(message);
  }

  /// A self message that is still being sent (no server [seq] yet) and carries
  /// a local outgoing sequence. Such a row is the most recently tapped message
  /// and must sort as the newest on a timestamp tie.
  static bool _isLiveOutgoingPlaceholder(V2TimMessage message) {
    return _messageSortSeq(message) <= 0 &&
        message.isSelf == true &&
        _readOutgoingLocalSeq(message) != null &&
        message.status == MessageStatus.V2TIM_MSG_STATUS_SENDING;
  }

  /// Messages without a server [seq] (local group tips, sending placeholders).
  static bool _usesTimelineLocalOrdering(V2TimMessage message) {
    if (_messageSortSeq(message) > 0) {
      return false;
    }
    final raw = message.localCustomData?.trim() ?? '';
    if (raw.isNotEmpty) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is Map) {
          if (decoded['localGroupTips'] == true) {
            return true;
          }
          if (decoded.containsKey('timelineRank')) {
            return true;
          }
        }
      } catch (_) {}
    }
    return message.isSelf == true &&
        _readOutgoingLocalSeq(message) != null &&
        message.status == MessageStatus.V2TIM_MSG_STATUS_SENDING;
  }

  static int _messageTimelineSortRank(V2TimMessage message) {
    final raw = message.localCustomData?.trim() ?? '';
    if (raw.isEmpty) {
      return 50;
    }
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map) {
        final rank = decoded['timelineRank'];
        if (rank is num) {
          return rank.toInt();
        }
      }
    } catch (_) {}
    return 50;
  }

  static int _messageSortTimestamp(V2TimMessage message) {
    final timestamp = normalizeMessageEpochSeconds(message.timestamp);
    if (timestamp > 0) {
      return timestamp;
    }
    final localSentAt =
        normalizeMessageEpochSeconds(_readOutgoingLocalSentAt(message));
    if (localSentAt > 0) {
      return localSentAt;
    }
    return 0;
  }

  static int compareMessagesChronological(V2TimMessage a, V2TimMessage b) {
    final sa = _messageSortSeq(a);
    final sb = _messageSortSeq(b);
    final aLocalTimeline = _usesTimelineLocalOrdering(a);
    final bLocalTimeline = _usesTimelineLocalOrdering(b);

    // In GROUP chats the server seq is the source of truth: msgID/server
    // timestamps can be non-monotonic while seq stays ordered (see logs). In
    // C2C chats seq is per-sender and NOT chronological, so it must not be used
    // here — fall through to timestamp ordering instead.
    final aGroupSeq = !aLocalTimeline && _hasGroupSeqOrdering(a);
    final bGroupSeq = !bLocalTimeline && _hasGroupSeqOrdering(b);
    if (aGroupSeq && bGroupSeq) {
      if (sa != sb) {
        return sa.compareTo(sb);
      }
    }

    final ta = _messageSortTimestamp(a);
    final tb = _messageSortTimestamp(b);
    if (ta != tb) {
      return ta.compareTo(tb);
    }
    // Equal timestamps (same-second send): a live SENDING placeholder was just
    // created locally and is therefore newer than any already-resolved message
    // it ties with. Sends are serialized, so any resolved row in the list was
    // dispatched before this placeholder was tapped. Without this, the
    // placeholder (seq=0) loses the seq tie-break below and briefly renders
    // *above* (older than) the previous message, then snaps back once its own
    // server seq arrives — the visible "reorder then recover" flicker.
    final aSendingPlaceholder = _isLiveOutgoingPlaceholder(a);
    final bSendingPlaceholder = _isLiveOutgoingPlaceholder(b);
    if (aSendingPlaceholder != bSendingPlaceholder) {
      return aSendingPlaceholder ? 1 : -1;
    }
    // C2C 同秒（真实 timestamp）：我方先发、对方后回，升序里 self 在前。
    if (ta == tb &&
        ta > 0 &&
        _isC2cLikeMessage(a) &&
        _isC2cLikeMessage(b) &&
        a.isSelf != b.isSelf) {
      if (a.isSelf == true) {
        return -1;
      }
      if (b.isSelf == true) {
        return 1;
      }
    }
    final rankA = _messageTimelineSortRank(a);
    final rankB = _messageTimelineSortRank(b);
    if (rankA != rankB) {
      return rankA.compareTo(rankB);
    }
    if (aGroupSeq && bGroupSeq && sa != sb) {
      return sa.compareTo(sb);
    }
    final la = _readOutgoingLocalSeq(a);
    final lb = _readOutgoingLocalSeq(b);
    if (la != null && lb != null && la != lb) {
      return la.compareTo(lb);
    }
    if (la != null && lb == null) {
      return 1;
    }
    if (la == null && lb != null) {
      return -1;
    }
    final ma = a.msgID ?? a.id ?? '';
    final mb = b.msgID ?? b.id ?? '';
    return ma.compareTo(mb);
  }

  static List<V2TimMessage> sortMessagesChronologicallyAsc(
    List<V2TimMessage> messages,
  ) {
    return List<V2TimMessage>.from(messages)
      ..sort(compareMessagesChronological);
  }

  /// 腾讯 SDK / 端上自消息 msgID（数字 TIM id 或 `userId-ts-random`；非归档 `@TGS#:seq`）。
  static bool _isLikelyTencentSdkMsgId(String? msgID) {
    final id = msgID?.trim() ?? '';
    if (id.isEmpty) {
      return false;
    }
    if (RegExp(r'^\d{6,}-').hasMatch(id)) {
      return true;
    }
    // 自消息常见：`q14gkm5swv-1785731054-174908238`
    return RegExp(r'^[A-Za-z0-9_-]+-\d+-\d+$').hasMatch(id) &&
        !_c2cArchiveMsgKeyWirePattern.hasMatch(id);
  }

  static final RegExp _sdkMsgIdWirePattern =
      RegExp(r'^(\d{6,})-(\d+)-(\d+)$');
  /// 端上自消息：`{userId}-{timestamp}-{random}`（日志 acnj / q14gkm5swv）。
  static final RegExp _sdkUserMsgIdWirePattern =
      RegExp(r'^([A-Za-z0-9_-]+)-(\d+)-(\d+)$');
  static final RegExp _c2cArchiveMsgKeyWirePattern =
      RegExp(r'^(\d+)_(\d+)_(\d+)$');

  /// C2C 跨源稳定身份：sender + timestampSec + random。
  static ({String sender, int timestampSec, int random})? _c2cWireIdentity(
    V2TimMessage message,
  ) {
    if (!_isC2cConversationMessage(message) && !_isC2cLikeMessage(message)) {
      return null;
    }
    final sender = _normalizedC2cAccountId(
      (message.sender?.trim().isNotEmpty ?? false)
          ? message.sender
          : message.userID,
    );
    var ts = message.timestamp ?? 0;
    if (ts > 1000000000000) {
      ts = ts ~/ 1000;
    }
    var random = message.random ?? 0;
    final msgID = message.msgID?.trim() ?? '';
    if (msgID.isNotEmpty) {
      final sdk = _sdkMsgIdWirePattern.firstMatch(msgID) ??
          _sdkUserMsgIdWirePattern.firstMatch(msgID);
      if (sdk != null && !_c2cArchiveMsgKeyWirePattern.hasMatch(msgID)) {
        final sdkTs = int.tryParse(sdk.group(2) ?? '') ?? 0;
        final sdkRandom = int.tryParse(sdk.group(3) ?? '') ?? 0;
        if (ts <= 0 && sdkTs > 0) {
          ts = sdkTs;
        }
        if (random <= 0 && sdkRandom > 0) {
          random = sdkRandom;
        }
      } else {
        final archive = _c2cArchiveMsgKeyWirePattern.firstMatch(msgID);
        if (archive != null) {
          final keyRandom = int.tryParse(archive.group(2) ?? '') ?? 0;
          final keyTs = int.tryParse(archive.group(3) ?? '') ?? 0;
          if (random <= 0 && keyRandom > 0) {
            random = keyRandom;
          }
          if (ts <= 0 && keyTs > 0) {
            ts = keyTs;
          }
        }
      }
    }
    if (sender.isEmpty || ts <= 0 || random <= 0) {
      return null;
    }
    return (sender: sender, timestampSec: ts, random: random);
  }

  @visibleForTesting
  static ({String sender, int timestampSec, int random})?
      parseC2cWireIdentityForTesting(V2TimMessage message) {
    return _c2cWireIdentity(message);
  }

  /// 历史合并后用于幂等判断的身份签名（wire 优先，否则 messageDedupKey）。
  static String historyIdentitySignature(List<V2TimMessage> messages) {
    final keys = <String>[];
    for (final message in messages) {
      final wire = _c2cWireIdentity(message);
      if (wire != null) {
        keys.add('c2cwi:${wire.sender}:${wire.timestampSec}:${wire.random}');
        continue;
      }
      if (_hasGroupSeqOrdering(message)) {
        final seq = _messageSortSeq(message);
        if (seq > 0) {
          keys.add(
            'gseq:${_normalizedGroupIdForMessage(message)}:$seq',
          );
          continue;
        }
      }
      keys.add(messageDedupKey(message));
    }
    keys.sort();
    return keys.join('|');
  }

  @visibleForTesting
  static String historyIdentitySignatureForTesting(
    List<V2TimMessage> messages,
  ) {
    return historyIdentitySignature(messages);
  }

  /// 胜出行吸收对侧本地媒体路径，并在方向分更高时采纳 isSelf。
  static V2TimMessage _finalizePreferredDedupMessage(
    V2TimMessage preferred,
    V2TimMessage other,
  ) {
    _absorbMediaLocalPaths(preferred, other);
    // 归档↔SDK 不同 msgID：把已测行高粘到保留行，避免短历史 spacer 再估高。
    ChatMessageHeightCache.instance.rememberAliasesBetween(preferred, other);
    if (_isC2cConversationMessage(preferred) &&
        _isC2cConversationMessage(other)) {
      final preferredScore = _c2cDirectionConsistencyScore(preferred);
      final otherScore = _c2cDirectionConsistencyScore(other);
      if (otherScore > preferredScore) {
        preferred.isSelf = other.isSelf;
      }
    }
    return preferred;
  }

  static void _absorbMediaLocalPaths(V2TimMessage winner, V2TimMessage donor) {
    if (winner.elemType == MessageElemType.V2TIM_ELEM_TYPE_IMAGE &&
        donor.elemType == MessageElemType.V2TIM_ELEM_TYPE_IMAGE) {
      final donorPath = donor.imageElem?.path?.trim() ?? '';
      final winnerPath = winner.imageElem?.path?.trim() ?? '';
      if (donorPath.isNotEmpty && winnerPath.isEmpty) {
        winner.imageElem ??= donor.imageElem;
        winner.imageElem?.path = donorPath;
      }
    }
    if (winner.elemType == MessageElemType.V2TIM_ELEM_TYPE_SOUND &&
        donor.elemType == MessageElemType.V2TIM_ELEM_TYPE_SOUND) {
      final donorPath =
          donor.soundElem?.path ?? donor.soundElem?.localUrl ?? '';
      if (donorPath.isNotEmpty) {
        winner.soundElem ??= donor.soundElem;
        winner.soundElem?.path = donor.soundElem?.path ?? donorPath;
        winner.soundElem?.localUrl =
            donor.soundElem?.localUrl ?? winner.soundElem?.localUrl;
      }
    }
    if (winner.elemType == MessageElemType.V2TIM_ELEM_TYPE_VIDEO &&
        donor.elemType == MessageElemType.V2TIM_ELEM_TYPE_VIDEO) {
      final donorPath = donor.videoElem?.localVideoUrl?.trim() ??
          donor.videoElem?.videoPath?.trim() ??
          '';
      final winnerPath = winner.videoElem?.localVideoUrl?.trim() ??
          winner.videoElem?.videoPath?.trim() ??
          '';
      if (donorPath.isNotEmpty && winnerPath.isEmpty) {
        winner.videoElem ??= donor.videoElem;
        if ((winner.videoElem?.localVideoUrl?.trim().isEmpty ?? true) &&
            (donor.videoElem?.localVideoUrl?.trim().isNotEmpty ?? false)) {
          winner.videoElem?.localVideoUrl = donor.videoElem?.localVideoUrl;
        }
        if ((winner.videoElem?.videoPath?.trim().isEmpty ?? true) &&
            (donor.videoElem?.videoPath?.trim().isNotEmpty ?? false)) {
          winner.videoElem?.videoPath = donor.videoElem?.videoPath;
        }
      }
    }
    if (winner.elemType == MessageElemType.V2TIM_ELEM_TYPE_FILE &&
        donor.elemType == MessageElemType.V2TIM_ELEM_TYPE_FILE) {
      final donorPath = donor.fileElem?.localUrl?.trim() ??
          donor.fileElem?.path?.trim() ??
          '';
      final winnerPath = winner.fileElem?.localUrl?.trim() ??
          winner.fileElem?.path?.trim() ??
          '';
      if (donorPath.isNotEmpty && winnerPath.isEmpty) {
        winner.fileElem ??= donor.fileElem;
        winner.fileElem?.localUrl =
            donor.fileElem?.localUrl ?? winner.fileElem?.localUrl;
        winner.fileElem?.path = donor.fileElem?.path ?? winner.fileElem?.path;
      }
    }
  }

  static void _applyDedupPreference(
    List<V2TimMessage> result,
    int index,
    V2TimMessage candidate, {
    String? candidateDedupKey,
    Map<String, int>? dedupKeyToResultIndex,
  }) {
    final existing = result[index];
    if (_preferMessageForDedup(candidate, existing)) {
      result[index] = _finalizePreferredDedupMessage(candidate, existing);
      if (candidateDedupKey != null && dedupKeyToResultIndex != null) {
        dedupKeyToResultIndex[candidateDedupKey] = index;
      }
    } else {
      result[index] = _finalizePreferredDedupMessage(existing, candidate);
    }
  }

  /// 同一 dedupKey 冲突时保留哪条（incoming 为 true 则替换 existing）。
  static bool _preferMessageForDedup(
    V2TimMessage incoming,
    V2TimMessage existing,
  ) {
    final incomingArchive =
        HistoryPaginationAnchor.isArchiveHistoryMessage(incoming);
    final existingArchive =
        HistoryPaginationAnchor.isArchiveHistoryMessage(existing);

    // 后端归档历史 SoT：先于「resolved outgoing」判断，避免 SDK isSelf 压过归档。
    if (incomingArchive != existingArchive) {
      final incomingSeq = _messageSortSeq(incoming);
      final existingSeq = _messageSortSeq(existing);
      final sameGroupSeq = !_isC2cConversationMessage(incoming) &&
          !_isC2cConversationMessage(existing) &&
          incomingSeq > 0 &&
          incomingSeq == existingSeq;
      final c2cPair = _isC2cConversationMessage(incoming) &&
          _isC2cConversationMessage(existing);
      if (sameGroupSeq || c2cPair || messagesCorrelateForDedup(incoming, existing)) {
        return incomingArchive;
      }
    }

    final existingResolved = _isResolvedOutgoingMessage(existing);
    final incomingResolved = _isResolvedOutgoingMessage(incoming);
    if (incomingResolved && !existingResolved) {
      return true;
    }
    if (!incomingResolved && existingResolved) {
      return false;
    }

    // 群历史（含 Web SDK 缺 groupID）：同 seq 时后端归档优先。
    final incomingSeqEarly = _messageSortSeq(incoming);
    final existingSeqEarly = _messageSortSeq(existing);
    if (!_isC2cConversationMessage(incoming) &&
        !_isC2cConversationMessage(existing) &&
        incomingSeqEarly > 0 &&
        incomingSeqEarly == existingSeqEarly) {
      if (incomingArchive && !existingArchive) {
        return true;
      }
      if (!incomingArchive && existingArchive) {
        return false;
      }
    }

    // 群消息：后端归档历史优先于 SDK 漫游副本。
    if (_isGroupLikeMessage(incoming) &&
        _isGroupLikeMessage(existing) &&
        _messageSortSeq(incoming) > 0 &&
        _messageSortSeq(incoming) == _messageSortSeq(existing)) {
      if (incomingArchive && !existingArchive) {
        return true;
      }
      if (!incomingArchive && existingArchive) {
        return false;
      }
    }

    // C2C：后端归档历史为 SoT；SDK 仅覆盖 client echo。
    if (_isC2cConversationMessage(incoming) &&
        _isC2cConversationMessage(existing)) {
      final incomingSdk = _isLikelyTencentSdkMsgId(incoming.msgID);
      final existingSdk = _isLikelyTencentSdkMsgId(existing.msgID);
      if (incomingArchive && existingSdk) {
        return true;
      }
      if (incomingSdk && existingArchive) {
        return false;
      }
      if (incomingArchive && !existingArchive) {
        return true;
      }
      if (!incomingArchive && existingArchive) {
        return false;
      }
      if (incomingSdk && _isC2cClientEchoMessage(existing)) {
        return true;
      }
      if (_isC2cClientEchoMessage(incoming) && existingSdk) {
        return false;
      }
      final incomingScore = _c2cDirectionConsistencyScore(incoming);
      final existingScore = _c2cDirectionConsistencyScore(existing);
      if (incomingScore != existingScore) {
        return incomingScore > existingScore;
      }
    }

    return false;
  }

  static bool _isC2cConversationMessage(V2TimMessage message) {
    return _isC2cLikeMessage(message) &&
        (message.userID?.trim().isNotEmpty ?? false);
  }

  /// 无 C2C userID 即非单聊；群消息也有 sender，不能凭 sender 判 C2C。
  static bool _isC2cLikeMessage(V2TimMessage message) {
    if (_isGroupLikeMessage(message)) {
      return false;
    }
    return message.userID?.trim().isNotEmpty ?? false;
  }

  static bool _isC2cClientEchoMessage(V2TimMessage message) {
    if (_isLikelyTencentSdkMsgId(message.msgID)) {
      return false;
    }
    final id = message.id?.trim() ?? '';
    return id.isNotEmpty;
  }

  /// 同秒同内容：TIM SDK 副本 vs 会话预览/client id echo（userID 可能不一致）。
  static bool _c2cPreviewEchoCorrelate(V2TimMessage a, V2TimMessage b) {
    if (!_isC2cLikeMessage(a) || !_isC2cLikeMessage(b)) {
      return false;
    }
    final tsA = a.timestamp ?? 0;
    final tsB = b.timestamp ?? 0;
    if (tsA <= 0 || tsA != tsB) {
      return false;
    }
    final fpA = _messageContentFingerprint(a);
    final fpB = _messageContentFingerprint(b);
    if (fpA == null || fpB == null || fpA != fpB) {
      return false;
    }
    final aSdk = _isLikelyTencentSdkMsgId(a.msgID);
    final bSdk = _isLikelyTencentSdkMsgId(b.msgID);
    if (aSdk && bSdk) {
      final aMsgID = a.msgID!.trim();
      final bMsgID = b.msgID!.trim();
      return aMsgID == bMsgID;
    }
    if (aSdk || bSdk) {
      return true;
    }
    if (a.isSelf != b.isSelf) {
      return true;
    }
    return _isC2cClientEchoMessage(a) || _isC2cClientEchoMessage(b);
  }

  /// C2C 账号归一化（去 c2c_ 前缀、@ 后缀），与 app 侧 ChatIdFormat 语义对齐。
  static String _normalizedC2cAccountId(String? raw) {
    var id = raw?.trim() ?? '';
    if (id.isEmpty) {
      return '';
    }
    if (id.startsWith('c2c_')) {
      id = id.substring(4);
    }
    final at = id.indexOf('@');
    if (at > 0) {
      id = id.substring(0, at);
    }
    return id.toLowerCase();
  }

  /// sender 与 peer/userID 方向一致时得分更高（3=一致，1=镜像 dup）。
  static int _c2cDirectionConsistencyScore(V2TimMessage message) {
    if (!_isC2cConversationMessage(message)) {
      return 0;
    }
    final peer = _normalizedC2cAccountId(message.userID);
    final sender = _normalizedC2cAccountId(message.sender);
    if (peer.isEmpty || sender.isEmpty) {
      return 0;
    }
    final fromPeer = peer == sender;
    final isSelf = message.isSelf == true;
    if (fromPeer && !isSelf) {
      return 3;
    }
    if (!fromPeer && isSelf) {
      return 3;
    }
    return 1;
  }

  /// C2C 镜像 dup：sender 为 peer 却被标成 isSelf（Web 漫游常见）。
  static bool _isC2cMirrorMislabeledSelf(V2TimMessage message) {
    return message.isSelf == true &&
        _isC2cConversationMessage(message) &&
        _c2cDirectionConsistencyScore(message) < 3;
  }

  V2TimMessage _normalizeInboundC2cDirection(V2TimMessage message) {
    if (!_isC2cMirrorMislabeledSelf(message)) {
      return message;
    }
    final fixed = _cloneMessage(message);
    fixed.isSelf = false;
    return fixed;
  }

  static bool _resolveMergedIsSelf(V2TimMessage a, V2TimMessage b) {
    final scoreA = _c2cDirectionConsistencyScore(a);
    final scoreB = _c2cDirectionConsistencyScore(b);
    if (scoreA > scoreB) {
      return a.isSelf == true;
    }
    if (scoreB > scoreA) {
      return b.isSelf == true;
    }
    final peer = _normalizedC2cAccountId(a.userID ?? b.userID);
    if (peer.isNotEmpty) {
      final senderA = _normalizedC2cAccountId(a.sender);
      final senderB = _normalizedC2cAccountId(b.sender);
      if (senderA == peer && senderB == peer) {
        // 双方 sender 均为 peer：真实方向是 incoming（左收）。
        return false;
      }
      if (senderA == peer && senderB != peer) {
        return a.isSelf == true;
      }
      if (senderB == peer && senderA != peer) {
        return b.isSelf == true;
      }
    }
    return a.isSelf == true && b.isSelf == true;
  }

  static String? _messageContentFingerprint(V2TimMessage message) {
    final text = message.textElem?.text?.trim();
    if (text != null && text.isNotEmpty) {
      return text;
    }
    return null;
  }

  /// C2C 跨源去重键：优先 wire identity（ts+random）；无 random 时降级文本指纹。
  static String? _c2cCrossSourceDedupKey(V2TimMessage message) {
    if (!_isC2cConversationMessage(message)) {
      return null;
    }
    final wire = _c2cWireIdentity(message);
    if (wire != null) {
      return 'c2cwi:${wire.sender}:${wire.timestampSec}:${wire.random}';
    }
    final userID = _normalizedC2cAccountId(message.userID);
    final ts = message.timestamp ?? 0;
    if (userID.isEmpty || ts <= 0) {
      return null;
    }
    final fingerprint = _messageContentFingerprint(message);
    if (fingerprint == null || fingerprint.isEmpty) {
      return null;
    }
    return 'c2cx:$userID:$ts:${message.elemType}:$fingerprint';
  }

  static bool _c2cCrossSourceCorrelate(V2TimMessage a, V2TimMessage b) {
    final keyA = _c2cCrossSourceDedupKey(a);
    final keyB = _c2cCrossSourceDedupKey(b);
    if (keyA == null || keyB == null || keyA != keyB) {
      return false;
    }
    // wire identity 已对齐：任意来源组合均视为同一条。
    if (keyA.startsWith('c2cwi:')) {
      return true;
    }
    final aArchive = HistoryPaginationAnchor.isArchiveHistoryMessage(a);
    final bArchive = HistoryPaginationAnchor.isArchiveHistoryMessage(b);
    final aSdk = _isLikelyTencentSdkMsgId(a.msgID);
    final bSdk = _isLikelyTencentSdkMsgId(b.msgID);
    if ((aArchive && bSdk) || (bArchive && aSdk)) {
      return true;
    }
    // 同会话同内容 isSelf 镜像（左收右发）：归档/TIM 或双 SDK echo。
    if (a.isSelf != b.isSelf) {
      return true;
    }
    return false;
  }

  /// 群聊 archive↔SDK 跨源：同 seq 视为同一条（Web SDK 常缺 groupID/@TGS#）。
  static String? _groupCrossSourceDedupKey(V2TimMessage message) {
    if (!_isGroupLikeMessage(message) &&
        !HistoryPaginationAnchor.isArchiveHistoryMessage(message)) {
      return null;
    }
    final seq = _messageSortSeq(message);
    if (seq <= 0) {
      return null;
    }
    if (_isLikelyTencentSdkMsgId(message.msgID) &&
        !_isGroupLikeMessage(message)) {
      // Web SDK 群消息偶发缺 groupID：用 seq-only 键与归档侧配对。
      return 'gseqx:*:$seq';
    }
    final token = _normalizedGroupIdForMessage(message);
    return 'gseqx:${token.isEmpty ? '*' : token}:$seq';
  }

  static bool _groupCrossSourceCorrelate(V2TimMessage a, V2TimMessage b) {
    if (_isC2cConversationMessage(a) || _isC2cConversationMessage(b)) {
      return false;
    }
    final seqA = _messageSortSeq(a);
    final seqB = _messageSortSeq(b);
    if (seqA <= 0 || seqB <= 0 || seqA != seqB) {
      return false;
    }
    final aArchive = HistoryPaginationAnchor.isArchiveHistoryMessage(a);
    final bArchive = HistoryPaginationAnchor.isArchiveHistoryMessage(b);
    final aSdk = _isLikelyTencentSdkMsgId(a.msgID);
    final bSdk = _isLikelyTencentSdkMsgId(b.msgID);
    if ((aArchive && bSdk) || (bArchive && aSdk)) {
      return true;
    }
    if (!_isGroupLikeMessage(a) || !_isGroupLikeMessage(b)) {
      return false;
    }
    final tokenA = _normalizedGroupIdForMessage(a);
    final tokenB = _normalizedGroupIdForMessage(b);
    if (tokenA.isNotEmpty &&
        tokenB.isNotEmpty &&
        _groupIdsEquivalentForDedup(tokenA, tokenB)) {
      return true;
    }
    if (tokenA.isEmpty || tokenB.isEmpty) {
      return true;
    }
    return false;
  }

  static String messageDedupKey(V2TimMessage message) {
    // 群聊：seq 为会话内单调序号，SDK 与归档 msgKey 不同但 seq 相同 → 用 seq 去重。
    if (_hasGroupSeqOrdering(message)) {
      final groupToken = _normalizedGroupIdForMessage(message);
      final seq = _messageSortSeq(message);
      return 'gseq:$groupToken:$seq';
    }
    final msgID = message.msgID?.trim();
    if (msgID != null && msgID.isNotEmpty) {
      return 'msg:$msgID';
    }
    final id = message.id?.trim();
    if (id != null && id.isNotEmpty) {
      return 'id:$id';
    }
    return [
      message.sender ?? message.userID ?? '',
      message.timestamp ?? '',
      message.seq ?? '',
      message.elemType,
      message.random,
    ].join('|');
  }

  static List<V2TimMessage> dedupeMessages(List<V2TimMessage> messages) {
    if (messages.isEmpty) {
      return const <V2TimMessage>[];
    }
    final dedupKeyToResultIndex = <String, int>{};
    final correlationToResultIndex = <String, int>{};
    final crossSourceToResultIndex = <String, int>{};
    final groupCrossSourceToResultIndex = <String, int>{};
    final result = <V2TimMessage>[];
    for (final message in messages) {
      final key = messageDedupKey(message);
      final corr = _outgoingCorrelationKey(message);
      if (corr != null) {
        final existingIdx = correlationToResultIndex[corr];
        if (existingIdx != null) {
          _applyDedupPreference(
            result,
            existingIdx,
            message,
            candidateDedupKey: key,
            dedupKeyToResultIndex: dedupKeyToResultIndex,
          );
          continue;
        }
      }
      final groupCrossKey = _groupCrossSourceDedupKey(message);
      var groupCrossMatched = false;
      if (groupCrossKey != null) {
        final existingIdx = groupCrossSourceToResultIndex[groupCrossKey];
        if (existingIdx != null) {
          final existing = result[existingIdx];
          if (_groupCrossSourceCorrelate(message, existing)) {
            _applyDedupPreference(
              result,
              existingIdx,
              message,
              candidateDedupKey: key,
              dedupKeyToResultIndex: dedupKeyToResultIndex,
            );
            groupCrossMatched = true;
          }
        }
        if (!groupCrossMatched && groupCrossKey.contains(':*:')) {
          final seqSuffix =
              groupCrossKey.substring(groupCrossKey.lastIndexOf(':'));
          for (var i = 0; i < result.length; i++) {
            final existingKey = _groupCrossSourceDedupKey(result[i]);
            if (existingKey == null || !existingKey.endsWith(seqSuffix)) {
              continue;
            }
            if (_groupCrossSourceCorrelate(message, result[i])) {
              _applyDedupPreference(
                result,
                i,
                message,
                candidateDedupKey: key,
                dedupKeyToResultIndex: dedupKeyToResultIndex,
              );
              groupCrossSourceToResultIndex[groupCrossKey] = i;
              if (existingKey != groupCrossKey) {
                groupCrossSourceToResultIndex[existingKey] = i;
              }
              groupCrossMatched = true;
              break;
            }
          }
        }
        if (groupCrossMatched) {
          continue;
        }
      }
      final crossKey = _c2cCrossSourceDedupKey(message);
      if (crossKey != null) {
        final existingIdx = crossSourceToResultIndex[crossKey];
        if (existingIdx != null) {
          final existing = result[existingIdx];
          if (_c2cCrossSourceCorrelate(message, existing)) {
            _applyDedupPreference(
              result,
              existingIdx,
              message,
              candidateDedupKey: key,
              dedupKeyToResultIndex: dedupKeyToResultIndex,
            );
            continue;
          }
        }
      }
      var correlateIdx = -1;
      for (var i = 0; i < result.length; i++) {
        if (messagesCorrelateForDedup(message, result[i])) {
          correlateIdx = i;
          break;
        }
      }
      if (correlateIdx >= 0) {
        _applyDedupPreference(
          result,
          correlateIdx,
          message,
          candidateDedupKey: key,
          dedupKeyToResultIndex: dedupKeyToResultIndex,
        );
        if (corr != null) {
          correlationToResultIndex[corr] = correlateIdx;
        }
        if (crossKey != null) {
          crossSourceToResultIndex[crossKey] = correlateIdx;
        }
        if (groupCrossKey != null) {
          groupCrossSourceToResultIndex[groupCrossKey] = correlateIdx;
        }
        continue;
      }
      final existingIdx = dedupKeyToResultIndex[key];
      if (existingIdx != null) {
        _applyDedupPreference(
          result,
          existingIdx,
          message,
          candidateDedupKey: key,
          dedupKeyToResultIndex: dedupKeyToResultIndex,
        );
        if (corr != null) {
          correlationToResultIndex[corr] = existingIdx;
        }
        continue;
      }
      final resultIndex = result.length;
      result.add(message);
      dedupKeyToResultIndex[key] = resultIndex;
      if (corr != null) {
        correlationToResultIndex[corr] = resultIndex;
      }
      if (crossKey != null) {
        crossSourceToResultIndex[crossKey] = resultIndex;
      }
      if (groupCrossKey != null) {
        groupCrossSourceToResultIndex[groupCrossKey] = resultIndex;
      }
    }
    return result;
  }

  @visibleForTesting
  static List<V2TimMessage> dedupeMessagesForTesting(
    List<V2TimMessage> messages,
  ) {
    return dedupeMessages(messages);
  }

  static bool _groupPreviewStubCorrelate(V2TimMessage a, V2TimMessage b) {
    if (_isC2cConversationMessage(a) || _isC2cConversationMessage(b)) {
      return false;
    }
    final tsA = a.timestamp ?? 0;
    final tsB = b.timestamp ?? 0;
    if (tsA <= 0 || tsA != tsB) {
      return false;
    }
    final seqA = _messageSortSeq(a);
    final seqB = _messageSortSeq(b);
    if (seqA > 0 && seqB > 0 && seqA != seqB) {
      return false;
    }
    final aSdk = _isLikelyTencentSdkMsgId(a.msgID);
    final bSdk = _isLikelyTencentSdkMsgId(b.msgID);
    final aStub = seqA <= 0 || !aSdk;
    final bStub = seqB <= 0 || !bSdk;
    if (!aStub && !bStub) {
      return false;
    }
    final senderA = a.sender?.trim() ?? '';
    final senderB = b.sender?.trim() ?? '';
    if (senderA.isNotEmpty && senderB.isNotEmpty && senderA != senderB) {
      return false;
    }
    final fpA = _messageContentFingerprint(a);
    final fpB = _messageContentFingerprint(b);
    if (aStub && bStub) {
      // 双 stub 必须内容指纹一致，避免同秒不同消息误并。
      if (fpA == null || fpB == null || fpA != fpB) {
        return false;
      }
      return true;
    }
    // SDK 头 + 会话 preview stub：允许 preview 缺 textElem。
    if (fpA != null && fpB != null && fpA != fpB) {
      return false;
    }
    return true;
  }

  static bool _sameSelfNonC2cEchoCorrelate(V2TimMessage a, V2TimMessage b) {
    if (a.isSelf != true || b.isSelf != true) {
      return false;
    }
    if (_isC2cConversationMessage(a) || _isC2cConversationMessage(b)) {
      return false;
    }
    if (a.elemType != b.elemType) {
      return false;
    }
    final tsA = a.timestamp ?? 0;
    final tsB = b.timestamp ?? 0;
    if (tsA <= 0 || tsA != tsB) {
      return false;
    }
    final fpA = _messageContentFingerprint(a);
    final fpB = _messageContentFingerprint(b);
    if (fpA == null || fpB == null || fpA != fpB) {
      return false;
    }
    final senderA = a.sender?.trim() ?? '';
    final senderB = b.sender?.trim() ?? '';
    if (senderA.isNotEmpty && senderB.isNotEmpty && senderA != senderB) {
      return false;
    }
    return true;
  }

  static bool messagesCorrelateForDedup(V2TimMessage a, V2TimMessage b) {
    final seqA = _messageSortSeq(a);
    final seqB = _messageSortSeq(b);
    if (seqA > 0 &&
        seqA == seqB &&
        !_isC2cConversationMessage(a) &&
        !_isC2cConversationMessage(b)) {
      if (_isGroupLikeMessage(a) ||
          _isGroupLikeMessage(b) ||
          (a.isSelf == true && b.isSelf == true)) {
        return true;
      }
    }
    if (_hasGroupSeqOrdering(a) &&
        _hasGroupSeqOrdering(b) &&
        _groupIdsEquivalentForDedup(
          _normalizedGroupIdForMessage(a),
          _normalizedGroupIdForMessage(b),
        ) &&
        seqA == seqB) {
      return true;
    }
    final aMsgID = a.msgID?.trim() ?? '';
    final bMsgID = b.msgID?.trim() ?? '';
    if (aMsgID.isNotEmpty && bMsgID.isNotEmpty && aMsgID == bMsgID) {
      return true;
    }
    final aId = a.id?.trim() ?? '';
    final bId = b.id?.trim() ?? '';
    if (aId.isNotEmpty && bId.isNotEmpty && aId == bId) {
      return true;
    }
    if (aMsgID.isNotEmpty && bId.isNotEmpty && aMsgID == bId) {
      return true;
    }
    if (aId.isNotEmpty && bMsgID.isNotEmpty && aId == bMsgID) {
      return true;
    }
    if (_c2cCrossSourceCorrelate(a, b)) {
      return true;
    }
    if (_groupCrossSourceCorrelate(a, b)) {
      return true;
    }
    if (_c2cPreviewEchoCorrelate(a, b)) {
      return true;
    }
    if (_sameSelfNonC2cEchoCorrelate(a, b)) {
      return true;
    }
    if (_groupPreviewStubCorrelate(a, b)) {
      return true;
    }
    return _outgoingMessagesCorrelate(a, b);
  }

  /// Merge fetched history with any messages upserted while loading.
  ///
  /// 注意：会保留 [existing] 里的全部历史。首屏若要以会话预览窗口为准，
  /// 请用 [mergePeekWindowWithLiveMemory] + [setMessageList] `replace: true`。
  static List<V2TimMessage> mergeHistoricalWithInMemory({
    List<V2TimMessage>? existing,
    required List<V2TimMessage> fetched,
  }) {
    if (existing == null || existing.isEmpty) {
      return sortMessagesNewestFirst(dedupeMessages(fetched));
    }
    return sortMessagesNewestFirst(
      dedupeMessages(<V2TimMessage>[...existing, ...fetched]),
    );
  }

  /// 进聊合窗时须保留的本地群灰字（勿被 peek 窗口冲掉）。
  /// 成员变动 tip（member_added/removed/left）已换轨 IM GroupTips，不再保留。
  static bool _isPreservedLocalGroupTip(V2TimMessage message) {
    final raw = message.localCustomData?.trim() ?? '';
    if (raw.isNotEmpty) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is Map && decoded['localGroupTips'] == true) {
          final action =
              decoded['action']?.toString().trim().toLowerCase() ?? '';
          if (action == 'member_added' ||
              action == 'member_removed' ||
              action == 'member_left') {
            return false;
          }
          return true;
        }
      } catch (_) {}
    }
    final msgID = message.msgID?.trim() ?? '';
    if (msgID.startsWith('local_gt_') ||
        msgID.startsWith('ce_') ||
        msgID.startsWith('local_')) {
      return true;
    }
    final id = message.id?.trim() ?? '';
    return id.startsWith('local_gt_') ||
        id.startsWith('ce_') ||
        id.startsWith('local_');
  }

  /// 以 peek 窗补齐实时/在途消息；不得驱逐后端归档历史（含窗外独有补洞）。
  /// 历史冲突以后端归档为 SoT，由最终 [dedupeMessages] prefer 收敛。
  static List<V2TimMessage> mergePeekWindowWithLiveMemory({
    List<V2TimMessage>? existing,
    required List<V2TimMessage> fetched,
  }) {
    final window = dedupeMessages(fetched);
    if (existing == null || existing.isEmpty) {
      return sortMessagesNewestFirst(window);
    }
    if (window.isEmpty) {
      return sortMessagesNewestFirst(dedupeMessages(existing));
    }

    V2TimMessage? newestInWindow;
    for (final message in window) {
      if (newestInWindow == null ||
          compareMessagesChronological(message, newestInWindow) > 0) {
        newestInWindow = message;
      }
    }

    final live = <V2TimMessage>[];
    var retainedArchiveCount = 0;
    for (final message in existing) {
      // 后端归档（含校对补洞）：一律保留，禁止 SDK peek 窗整表冲掉后再靠校对灌回。
      if (HistoryPaginationAnchor.isArchiveHistoryMessage(message)) {
        live.add(message);
        retainedArchiveCount++;
        continue;
      }
      final coveredByWindow = window.any(
        (windowMessage) => messagesCorrelateForDedup(message, windowMessage),
      );
      if (coveredByWindow) {
        continue;
      }
      if (_isPreservedLocalGroupTip(message)) {
        live.add(message);
        continue;
      }
      final sending = message.isSelf == true &&
          (message.status == MessageStatus.V2TIM_MSG_STATUS_SENDING ||
              _isLiveOutgoingPlaceholder(message));
      if (sending) {
        live.add(message);
        continue;
      }
      if (newestInWindow != null &&
          compareMessagesChronological(message, newestInWindow) > 0) {
        live.add(message);
      }
    }

    final merged = sortMessagesNewestFirst(
      dedupeMessages(<V2TimMessage>[...window, ...live]),
    );
    if (retainedArchiveCount > 0) {
      ChatHistoryTrace.log(
        'peek_merge_retained_archive',
        extras: <String, Object?>{
          'retainedArchiveCount': retainedArchiveCount,
          'windowCount': window.length,
          'mergedCount': merged.length,
        },
      );
    }
    return merged;
  }

  static List<V2TimMessage> sortMessagesNewestFirst(
    List<V2TimMessage> messages,
  ) {
    return List<V2TimMessage>.from(messages)
      ..sort((a, b) => compareMessagesChronological(b, a));
  }

  @visibleForTesting
  static List<V2TimMessage> appendDistinctIncomingBatchForTesting({
    required List<V2TimMessage> existing,
    required List<V2TimMessage> incoming,
  }) {
    return sortMessagesNewestFirst(
      <V2TimMessage>[...incoming, ...existing],
    );
  }

  @visibleForTesting
  static List<V2TimMessage> filterHiddenProjectionForTesting({
    required Iterable<V2TimMessage> authoritativeMessages,
    required Set<String> hiddenKeys,
  }) {
    return authoritativeMessages
        .where((message) => !hiddenKeys.contains(messageDedupKey(message)))
        .toList(growable: false);
  }

  List<V2TimMessage>? getMessageList(String conversationID) {
    final cached = _messageListDisplayCache[conversationID];
    if (cached != null) {
      return cached;
    }
    final convKey = _inboundStateKey(conversationID);
    final hidden = _inboundHiddenKeysByConv[convKey];
    // 合并 c2c_/裸 id 等别名桶，避免入站写到另一 key 时对话页读不到。
    final authoritative =
        _collectAuthoritativeMessages(conversationID).reversed.toList();
    final visible = hidden == null
        ? authoritative
        : filterHiddenProjectionForTesting(
            authoritativeMessages: authoritative,
            hiddenKeys: hidden,
          );
    final list = visible
        .where((element) => _lifeCycle?.messageShouldMount(element) ?? true)
        .toList();
    final mountedList = _lifeCycle?.messageListShouldMount(list) ?? list;
    final finalList = List<V2TimMessage>.from(mountedList)
      ..sort(compareMessagesChronological);
    final interval = chatConfig.timeDividerConfig?.timeInterval ?? 300;
    final result = attachTimeDividersForTesting(
      finalList,
      intervalSeconds: interval,
    ).reversed.toList();
    _messageListDisplayCache[conversationID] = result;
    return result;
  }

  /// 无可见行高的消息不参与时间分割线锚点（否则会留下孤儿分割线）。
  @visibleForTesting
  static bool messageAnchorsTimeDivider(V2TimMessage message) {
    if (message.elemType == 11 || message.elemType == 101) {
      return false;
    }
    // 与列表 item 一致：空群 tip 渲染为 SizedBox.shrink。
    if (message.elemType == MessageElemType.V2TIM_ELEM_TYPE_GROUP_TIPS &&
        message.groupTipsElem == null) {
      return false;
    }
    return true;
  }

  /// 按时间升序插入分割线，并去掉「后面没有真实消息」的孤儿分割线。
  @visibleForTesting
  static List<V2TimMessage> attachTimeDividersForTesting(
    List<V2TimMessage> chronologicalAsc, {
    int intervalSeconds = 300,
  }) {
    final listWithTimestamp = <V2TimMessage>[];
    for (final item in chronologicalAsc) {
      if (!messageAnchorsTimeDivider(item)) {
        continue;
      }
      final lastAnchor = _lastTimeDividerAnchor(listWithTimestamp);
      final shouldInsertDivider = listWithTimestamp.isEmpty ||
          (lastAnchor?.timestamp != null &&
              item.timestamp != null &&
              item.timestamp! - lastAnchor!.timestamp! > intervalSeconds);
      if (shouldInsertDivider) {
        listWithTimestamp.add(_buildTimeDividerMessage(item.timestamp));
      }
      listWithTimestamp.add(item);
    }
    return stripOrphanTimeDividersForTesting(listWithTimestamp);
  }

  static V2TimMessage _buildTimeDividerMessage(int? timestamp) {
    final ts = timestamp ?? 0;
    final message = V2TimMessage.fromJson(<String, dynamic>{
      'message_server_time': ts,
      'message_msg_id': 'time-divider-$ts',
      'message_is_from_self': false,
      'message_custom_str': '',
      'message_risk_type_identified': 0,
      'message_sender_group_member_info': <String, dynamic>{},
      'message_group_at_user_array': <String>[],
      'elem_type': 11,
    });
    message.elemType = 11;
    message.timestamp = ts;
    message.msgID = 'time-divider-$ts';
    message.isSelf = false;
    message.userID = '';
    return message;
  }

  static V2TimMessage? _lastTimeDividerAnchor(List<V2TimMessage> list) {
    for (var i = list.length - 1; i >= 0; i--) {
      if (messageAnchorsTimeDivider(list[i])) {
        return list[i];
      }
    }
    return null;
  }

  /// 时间升序列表：去掉连续分割线，以及末尾无真实消息的分割线。
  @visibleForTesting
  static List<V2TimMessage> stripOrphanTimeDividersForTesting(
    List<V2TimMessage> chronologicalAsc,
  ) {
    final out = <V2TimMessage>[];
    for (var i = 0; i < chronologicalAsc.length; i++) {
      final item = chronologicalAsc[i];
      if (item.elemType == 11) {
        final next =
            i + 1 < chronologicalAsc.length ? chronologicalAsc[i + 1] : null;
        if (next == null || next.elemType == 11 || next.elemType == 101) {
          continue;
        }
        if (out.isNotEmpty && out.last.elemType == 11) {
          continue;
        }
        out.add(item);
        continue;
      }
      out.add(item);
    }
    return out;
  }

  bool get isMediaPreviewOverlayOpen => _isMediaPreviewOverlayOpen;

  bool get isWalletOverlayOpen => _walletOverlayDepth > 0;

  int _mediaPickerOverlayDepth = 0;
  /// 长按消息菜单 / tooltip 打开期间禁止列表上推，新消息先缓冲。
  int _messageContextMenuOverlayDepth = 0;
  int _pinToBottomRequestSeq = 0;
  String? _pinToBottomRequestConvId;
  bool _pinToBottomForce = false;
  String? _userScrollToBottomConvId;
  int _userScrollToBottomUntilMs = 0;
  /// list-push / viewport insert 期间会短暂离开 minScrollExtent；此锁防止
  /// 「回到底部」胶囊被误判点亮后又熄灭。
  String? _inboundViewportPushConvId;
  int _inboundViewportPushUntilMs = 0;

  bool get isMediaPickerOverlayOpen => _mediaPickerOverlayDepth > 0;

  bool get isMessageContextMenuOverlayOpen =>
      _messageContextMenuOverlayDepth > 0;

  int get pinToBottomRequestSeq => _pinToBottomRequestSeq;

  String? get pinToBottomRequestConvId => _pinToBottomRequestConvId;

  bool get pinToBottomForce => _pinToBottomForce;

  void beginUserScrollToBottom(
    String conversationID, {
    int lockMilliseconds = 700,
  }) {
    final convId = _inboundStateKey(conversationID);
    if (convId.isEmpty) {
      return;
    }
    final nextUntil = DateTime.now().millisecondsSinceEpoch + lockMilliseconds;
    if (_userScrollToBottomConvId == convId &&
        _userScrollToBottomUntilMs >= nextUntil) {
      return;
    }
    _userScrollToBottomConvId = convId;
    _userScrollToBottomUntilMs = nextUntil;
  }

  bool isUserScrollToBottomInProgress(String? conversationID) {
    final convId = _inboundStateKey(conversationID);
    if (convId.isEmpty || _userScrollToBottomConvId != convId) {
      return false;
    }
    return DateTime.now().millisecondsSinceEpoch < _userScrollToBottomUntilMs;
  }

  void beginInboundViewportPush(
    String conversationID, {
    int lockMilliseconds = 1200,
  }) {
    final convId = _inboundStateKey(conversationID);
    if (convId.isEmpty) {
      return;
    }
    final nextUntil = DateTime.now().millisecondsSinceEpoch + lockMilliseconds;
    if (_inboundViewportPushConvId == convId &&
        _inboundViewportPushUntilMs >= nextUntil) {
      return;
    }
    _inboundViewportPushConvId = convId;
    _inboundViewportPushUntilMs = nextUntil;
  }

  void endInboundViewportPush(
    String conversationID, {
    int settleMilliseconds = 320,
  }) {
    final convId = _inboundStateKey(conversationID);
    if (convId.isEmpty || _inboundViewportPushConvId != convId) {
      return;
    }
    _inboundViewportPushUntilMs =
        DateTime.now().millisecondsSinceEpoch + settleMilliseconds;
  }

  bool isInboundViewportPushActive(String? conversationID) {
    final convId = _inboundStateKey(conversationID);
    if (convId.isEmpty || _inboundViewportPushConvId != convId) {
      return false;
    }
    return DateTime.now().millisecondsSinceEpoch < _inboundViewportPushUntilMs;
  }

  void endUserScrollToBottom(String conversationID) {
    final convId = _inboundStateKey(conversationID);
    if (_userScrollToBottomConvId != convId) {
      return;
    }
    _userScrollToBottomConvId = null;
    _userScrollToBottomUntilMs = 0;
  }

  void requestPinToBottom(String conversationID, {bool force = false}) {
    final convId = _safeConversationId(conversationID);
    if (convId.isEmpty) {
      return;
    }
    if (isBulkMessageSyncActive(convId) || isChunkedRevealActive(convId)) {
      _pendingPinAfterBulkByConv[convId] =
          force || (_pendingPinAfterBulkByConv[convId] ?? false);
      return;
    }
    _pinToBottomRequestConvId = convId;
    _pinToBottomForce = force;
    _pinToBottomRequestSeq++;
    _markNeedsNotify();
  }

  void beginMediaPickerOverlay() {
    _mediaPickerOverlayDepth++;
  }

  void endMediaPickerOverlay() {
    final wasOpen = _mediaPickerOverlayDepth > 0;
    if (_mediaPickerOverlayDepth > 0) {
      _mediaPickerOverlayDepth--;
    }
    if (wasOpen && _mediaPickerOverlayDepth == 0) {
      _markNeedsNotify();
    }
  }

  void beginMessageContextMenuOverlay() {
    _messageContextMenuOverlayDepth++;
  }

  void endMessageContextMenuOverlay({String? conversationID}) {
    final wasOpen = _messageContextMenuOverlayDepth > 0;
    if (_messageContextMenuOverlayDepth > 0) {
      _messageContextMenuOverlayDepth--;
    }
    if (!wasOpen || _messageContextMenuOverlayDepth > 0) {
      return;
    }
    final convId = _safeConversationId(
      conversationID ?? currentSelectedConv,
    );
    if (convId.isNotEmpty) {
      // 菜单关闭后把缓冲消息并回可见列表；贴底时继续上推/贴底跟随。
      flushDeferredIncomingMessages(
        convId,
        notify: true,
        userInitiated: true,
      );
      if (_isActiveChatNearBottom(convId)) {
        clearReceivedUnreadState(
          conversationID: convId,
          notify: false,
        );
        requestPinToBottom(convId);
      }
    } else {
      _markNeedsNotify();
    }
  }

  void beginWalletOverlay({
    String? conversationID,
    String? anchorMessageID,
  }) {
    _walletOverlayDepth++;
    saveScrollBeforeRouteOverlay(
      conversationID,
      anchorMessageID: anchorMessageID,
      lockMilliseconds: 1200,
    );
  }

  void endWalletOverlay({String? conversationID}) {
    if (_walletOverlayDepth > 0) {
      _walletOverlayDepth--;
    }
    restoreScrollAfterRouteOverlay(
      conversationID,
      lockMilliseconds: 900,
    );
  }

  ScrollPosition? _singleScrollPositionOrNull(ScrollController controller) {
    if (!controller.hasClients || controller.positions.length != 1) {
      return null;
    }
    return controller.position;
  }

  void saveScrollBeforeRouteOverlay(
    String? conversationID, {
    String? anchorMessageID,
    int lockMilliseconds = 800,
  }) {
    final convId = _safeConversationId(conversationID);
    if (convId.isEmpty) {
      return;
    }
    final controller = _activeChatScrollControllerMap[convId];
    final position =
        controller == null ? null : _singleScrollPositionOrNull(controller);
    if (position != null && position.hasPixels) {
      _mediaPreviewScrollOffsetMap[convId] = position.pixels;
    }
    final anchor = anchorMessageID?.trim() ?? '';
    if (anchor.isNotEmpty) {
      _mediaPreviewAnchorMsgIDMap[convId] = anchor;
    }
    _syncHistoryPositionFromActiveScroll(convId);
  }

  void restoreScrollAfterRouteOverlay(
    String? conversationID, {
    int lockMilliseconds = 800,
  }) {
    final convId = _safeConversationId(conversationID);
    if (convId.isEmpty) {
      _isRestoringScrollAfterMediaPreview = false;
      return;
    }
    _isRestoringScrollAfterMediaPreview = true;
    _mediaPreviewRestoreVersion++;
    _mediaPreviewRestoreLockUntil =
        DateTime.now().millisecondsSinceEpoch + lockMilliseconds;
    _syncHistoryPositionFromActiveScroll(convId);
    notifyListeners();
  }

  bool get isRestoringScrollAfterMediaPreview {
    final now = DateTime.now().millisecondsSinceEpoch;
    return _isRestoringScrollAfterMediaPreview ||
        now < _mediaPreviewRestoreLockUntil;
  }

  int get mediaPreviewRestoreVersion => _mediaPreviewRestoreVersion;

  void bindActiveChatScrollController({
    required String conversationID,
    required ScrollController scrollController,
  }) {
    if (conversationID.isEmpty) {
      return;
    }
    _activeChatScrollControllerMap[conversationID] = scrollController;
  }

  void clearActiveChatScrollController({String? conversationID}) {
    if (conversationID != null && conversationID.isNotEmpty) {
      _activeChatScrollControllerMap.remove(conversationID);
      return;
    }
    _activeChatScrollControllerMap.clear();
  }

  bool hasPendingScrollRestore(String? conversationID) {
    final convId = _safeConversationId(conversationID);
    if (convId.isEmpty) {
      return false;
    }
    // 仅「正在恢复滚动」时阻塞列表；预览期间保存的 offset 不应改变列表位姿。
    return _isRestoringScrollAfterMediaPreview ||
        DateTime.now().millisecondsSinceEpoch < _mediaPreviewRestoreLockUntil;
  }

  bool isInboundPresentationBottomLocked(String convId) {
    if (_isChatListUserScrolling ||
        !_isSameConversationID(convId, currentSelectedConv)) {
      return false;
    }
    // list-push 会故意 jump 离底再 animate 回来；这段物理偏移不是用户上滑看历史。
    // 不限 chunked reveal：单条连续收消息同样会误闪「回到底部」。
    if (isInboundViewportPushActive(convId)) {
      return true;
    }
    if (!isChunkedRevealActive(convId)) {
      return false;
    }
    // A viewport insert deliberately moves pixels away from minScrollExtent
    // while a tall row slides in. That visual offset is not user history
    // navigation, so keep the pre-transaction logical position authoritative.
    return getMessageListPosition(convId) == HistoryMessagePosition.bottom;
  }

  void _syncHistoryPositionFromActiveScroll(String convId) {
    if (isInboundPresentationBottomLocked(convId)) {
      _storeHistoryMessagePosition(convId, HistoryMessagePosition.bottom);
      final controller = _activeChatScrollControllerMap[convId];
      final position =
          controller == null ? null : _singleScrollPositionOrNull(controller);
      if (position != null &&
          position.hasPixels &&
          position.hasContentDimensions &&
          position.pixels > position.minScrollExtent + 80) {
        ChatJitterDiag.logInboundFlow(
          action: 'physical_away_ignored',
          conv: convId,
          extras: <String, Object?>{
            'pixels': position.pixels.toStringAsFixed(1),
            'minExtent': position.minScrollExtent.toStringAsFixed(1),
            'distance':
                (position.pixels - position.minScrollExtent).toStringAsFixed(1),
            'maxExtent': position.maxScrollExtent.toStringAsFixed(1),
            'logicalPosition': HistoryMessagePosition.bottom.name,
            'queue': pendingInboundProjectionCount(convId),
            'waiting': isInboundProjectionRevealWaiting(convId),
          },
          throttleKey: 'physical_away_ignored',
          minIntervalMs: 200,
        );
      }
      return;
    }
    final controller = _activeChatScrollControllerMap[convId];
    final position =
        controller == null ? null : _singleScrollPositionOrNull(controller);
    if (position != null &&
        position.hasPixels &&
        position.hasContentDimensions) {
      const nearThreshold = 80.0;
      final viewport = position.viewportDimension;
      final distance = position.pixels - position.minScrollExtent;
      final previous = getMessageListPosition(convId);
      final HistoryMessagePosition next;
      if (viewport > 0 && distance > viewport) {
        next = HistoryMessagePosition.awayTwoScreen;
      } else if (distance > nearThreshold) {
        next = HistoryMessagePosition.inTwoScreen;
      } else {
        next = HistoryMessagePosition.bottom;
      }
      _storeHistoryMessagePosition(convId, next);
      if (previous != next) {
        ChatJitterDiag.logInboundFlow(
          action: 'logical_position_sync',
          conv: convId,
          extras: <String, Object?>{
            'before': previous.name,
            'after': next.name,
            'pixels': position.pixels.toStringAsFixed(1),
            'minExtent': position.minScrollExtent.toStringAsFixed(1),
            'distance': distance.toStringAsFixed(1),
            'viewport': viewport.toStringAsFixed(1),
            'userScrolling': isChatListUserScrolling,
            'chunkActive': isChunkedRevealActive(convId),
          },
        );
      }
    }
  }

  bool _isActiveChatNearBottom(String convId, {double threshold = 80.0}) {
    if (isInboundPresentationBottomLocked(convId)) {
      return true;
    }
    final controller = _activeChatScrollControllerMap[convId];
    if (controller == null) {
      return false;
    }
    final position = _singleScrollPositionOrNull(controller);
    if (position == null) {
      return false;
    }
    if (!position.hasPixels || !position.hasContentDimensions) {
      return false;
    }
    return position.pixels <= position.minScrollExtent + threshold;
  }

  /// 物理滚动已离开底部超过约一屏（与「回到底部」出现阈值对齐）。
  bool _isActiveChatAwayOneScreen(String convId) {
    if (isInboundPresentationBottomLocked(convId)) {
      return false;
    }
    final controller = _activeChatScrollControllerMap[convId];
    if (controller == null) {
      return false;
    }
    final position = _singleScrollPositionOrNull(controller);
    if (position == null ||
        !position.hasPixels ||
        !position.hasContentDimensions) {
      return false;
    }
    final viewport = position.viewportDimension;
    if (viewport <= 0) {
      return false;
    }
    final distance = position.pixels - position.minScrollExtent;
    return distance > viewport;
  }

  void saveScrollBeforeMediaPreview(
    String? conversationID, {
    String? anchorMessageID,
  }) {
    _isMediaPreviewOverlayOpen = true;
    saveScrollBeforeRouteOverlay(
      conversationID,
      anchorMessageID: anchorMessageID,
      lockMilliseconds: _mediaPreviewRestoreLockMilliseconds,
    );
  }

  void restoreScrollAfterMediaPreview(String? conversationID) {
    final convId = _safeConversationId(conversationID);
    if (convId.isEmpty) {
      _isMediaPreviewOverlayOpen = false;
      return;
    }
    if (!_needsActiveScrollRestoreAfterPreview(convId)) {
      _clearMediaPreviewScrollRestoreState(convId);
      _isMediaPreviewOverlayOpen = false;
      return;
    }
    restoreScrollAfterRouteOverlay(
      conversationID,
      lockMilliseconds: _mediaPreviewRestoreLockMilliseconds,
    );
    _isMediaPreviewOverlayOpen = false;
  }

  /// 预览路由已完全 pop 且滚动恢复结束后调用（与 [restoreScrollAfterMediaPreview] 解耦兜底）。
  void endMediaPreviewOverlay() {
    _isMediaPreviewOverlayOpen = false;
  }

  bool _needsActiveScrollRestoreAfterPreview(String convId) {
    final offset = _mediaPreviewScrollOffsetMap[convId];
    final controller = _activeChatScrollControllerMap[convId];
    if (offset != null && controller != null) {
      final position = _singleScrollPositionOrNull(controller);
      if (position != null &&
          position.hasPixels &&
          position.hasContentDimensions) {
        final target = offset.clamp(
          position.minScrollExtent,
          position.maxScrollExtent,
        );
        return (position.pixels - target).abs() > 0.5;
      }
    }
    final anchor = _mediaPreviewAnchorMsgIDMap[convId];
    return anchor != null && anchor.isNotEmpty;
  }

  void _clearMediaPreviewScrollRestoreState(String convId) {
    _isRestoringScrollAfterMediaPreview = false;
    _mediaPreviewRestoreLockUntil = 0;
    _mediaPreviewScrollOffsetMap.remove(convId);
    _mediaPreviewAnchorMsgIDMap.remove(convId);
  }

  /// 画廊预览关闭前更新锚点，避免左右滑到别的图后仍滚回入口消息。
  void updateMediaPreviewCloseAnchor(
    String? conversationID,
    String? anchorMessageID,
  ) {
    final convId = _safeConversationId(conversationID);
    if (convId.isEmpty) {
      return;
    }
    final anchor = anchorMessageID?.trim() ?? '';
    if (anchor.isNotEmpty) {
      _mediaPreviewAnchorMsgIDMap[convId] = anchor;
    }
  }

  String? getScrollRestoreAnchorMsgID(String? conversationID) {
    final convId = _safeConversationId(conversationID);
    if (convId.isEmpty) {
      return null;
    }
    return _mediaPreviewAnchorMsgIDMap[convId];
  }

  double? getScrollRestoreOffset(String? conversationID) {
    final convId = _safeConversationId(conversationID);
    if (convId.isEmpty) {
      return null;
    }
    return _mediaPreviewScrollOffsetMap[convId];
  }

  void finishScrollAfterMediaPreview(String? conversationID) {
    final convId = _safeConversationId(conversationID);
    if (convId.isNotEmpty) {
      final controller = _activeChatScrollControllerMap[convId];
      final position =
          controller == null ? null : _singleScrollPositionOrNull(controller);
      if (position != null &&
          position.hasPixels &&
          position.hasContentDimensions) {
        const threshold = 80.0;
        if (position.pixels > position.minScrollExtent + threshold) {
          _storeHistoryMessagePosition(
            convId,
            HistoryMessagePosition.inTwoScreen,
          );
        } else {
          _storeHistoryMessagePosition(convId, HistoryMessagePosition.bottom);
        }
      }
      _mediaPreviewRestoreLockUntil = DateTime.now().millisecondsSinceEpoch +
          _mediaPreviewRestoreTailLockMilliseconds;
    }
    Future<void>.delayed(
        const Duration(milliseconds: _mediaPreviewRestoreTailLockMilliseconds),
        () {
      final now = DateTime.now().millisecondsSinceEpoch;
      if (now < _mediaPreviewRestoreLockUntil) {
        return;
      }
      if (convId.isNotEmpty) {
        _clearMediaPreviewScrollRestoreState(convId);
      } else {
        _isRestoringScrollAfterMediaPreview = false;
        _mediaPreviewRestoreLockUntil = 0;
      }
    });
  }

  String _safeConversationId(String? conversationID) {
    if (conversationID != null && conversationID.isNotEmpty) {
      return conversationID;
    }
    return currentSelectedConv;
  }

  /// 入站/展示共用的 messageListMap 存储键。
  ///
  /// Web/C2C 常见分裂：历史灌在 `c2c_userId`，`onRecvNewMessage` 算出的是裸
  /// `userId`。若各写各的桶，会话预览（conversation listener）会更新，但聊天
  /// 页 `getMessageList(c2c_…)` 仍读旧桶 → 预览有字、对话页不刷新。
  String _resolveMessageListStorageKey(String conversationID) {
    final trimmed = conversationID.trim();
    if (trimmed.isEmpty) {
      return trimmed;
    }

    final selected = currentSelectedConv.trim();
    if (selected.isNotEmpty &&
        _isSameConversationID(trimmed, selected) &&
        _messageListMap.containsKey(selected)) {
      return selected;
    }

    String? emptyAlias;
    for (final entry in _messageListMap.entries) {
      if (!_isSameConversationID(entry.key, trimmed)) {
        continue;
      }
      final list = entry.value;
      if (list != null && list.isNotEmpty) {
        return entry.key;
      }
      emptyAlias ??= entry.key;
    }
    if (emptyAlias != null) {
      return emptyAlias;
    }

    if (selected.isNotEmpty && _isSameConversationID(trimmed, selected)) {
      return selected;
    }
    return trimmed;
  }

  /// 合并等价会话 ID 下所有非空桶（防御双写残留）。
  List<V2TimMessage> _collectAuthoritativeMessages(String conversationID) {
    final trimmed = conversationID.trim();
    if (trimmed.isEmpty) {
      return const <V2TimMessage>[];
    }
    final buckets = <List<V2TimMessage>>[];
    for (final entry in _messageListMap.entries) {
      if (!_isSameConversationID(entry.key, trimmed)) {
        continue;
      }
      final list = entry.value;
      if (list != null && list.isNotEmpty) {
        buckets.add(list);
      }
    }
    if (buckets.isEmpty) {
      return const <V2TimMessage>[];
    }
    if (buckets.length == 1) {
      return buckets.first;
    }
    return sortMessagesNewestFirst(
      dedupeMessages(
        <V2TimMessage>[
          for (final bucket in buckets) ...bucket,
        ],
      ),
    );
  }

  HistoryMessagePosition getMessageListPosition(String? conversationID) {
    final convId = _safeConversationId(conversationID);
    if (hasPendingScrollRestore(convId)) {
      _storeHistoryMessagePosition(
        convId,
        HistoryMessagePosition.notShowLatest,
      );
      return HistoryMessagePosition.notShowLatest;
    }
    final page = _openPageHistoryPosition;
    final pageConv = _openPageConvId;
    if (page != null &&
        pageConv != null &&
        _isSameConversationID(convId, pageConv)) {
      return page.value;
    }
    final HistoryMessagePosition? position = _historyMessagePositionMap[convId];
    if (position == null) {
      _storeHistoryMessagePosition(convId, HistoryMessagePosition.bottom);
      return HistoryMessagePosition.bottom;
    }
    return position;
  }

  void prepareForOutgoingMessage(String conversationID) {
    final convId = _safeConversationId(conversationID);
    if (convId.isEmpty) {
      return;
    }
    _mediaPreviewScrollOffsetMap.remove(convId);
    _mediaPreviewAnchorMsgIDMap.remove(convId);
    _isRestoringScrollAfterMediaPreview = false;
    _mediaPreviewRestoreLockUntil = 0;
    _storeHistoryMessagePosition(convId, HistoryMessagePosition.bottom);
    flushDeferredIncomingMessages(
      convId,
      notify: false,
      userInitiated: true,
    );
    unlockEntryUnreadForTongue(
      conversationID: convId,
      notify: false,
    );
    clearReceivedUnreadState(
      conversationID: convId,
      notify: false,
    );
    _outgoingPinScrollSuppressUntilMs =
        DateTime.now().millisecondsSinceEpoch + 350;
  }

  bool shouldSuppressOutgoingPinScroll() {
    return DateTime.now().millisecondsSinceEpoch <
        _outgoingPinScrollSuppressUntilMs;
  }

  void setMessageListPosition(
      String conversationID, HistoryMessagePosition position,
      {bool notify = true}) {
    final convId = _safeConversationId(conversationID);
    final previous = getMessageListPosition(convId);
    HistoryMessagePosition next = position;
    if (position == HistoryMessagePosition.bottom &&
        _deferredUntilUserBottomConversations.contains(
          _inboundStateKey(convId),
        )) {
      next = HistoryMessagePosition.notShowLatest;
    } else if (position == HistoryMessagePosition.bottom &&
        hasPendingScrollRestore(convId)) {
      next = HistoryMessagePosition.notShowLatest;
    }
    _storeHistoryMessagePosition(convId, next);
    // Scroll-position churn must not fan out to every Global listener when
    // the logical value is unchanged (page-local UI is SSOT while attached).
    if (notify && previous != next) {
      notifyListeners();
    }
  }
}
