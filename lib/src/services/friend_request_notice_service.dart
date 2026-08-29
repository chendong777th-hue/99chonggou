import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:tencent_cloud_chat_demo/src/i18n/app_i18n.dart';
import 'package:tencent_cloud_chat_demo/src/widgets/app_dialog.dart';
import 'package:tencent_cloud_chat_demo/src/api/friend_request_api.dart';
import 'package:tencent_cloud_chat_demo/src/friend_application_helper.dart';
import 'package:tencent_cloud_chat_demo/src/models/friend_request_record.dart';
import 'package:tencent_cloud_chat_demo/src/services/archived_conversation_sync_service.dart';
import 'package:tencent_cloud_chat_demo/src/services/conversation_folder_sync_service.dart';
import 'package:tencent_cloud_chat_demo/src/services/conversation_pin_sync_service.dart';
import 'package:tencent_cloud_chat_demo/src/services/call_recent_sync_service.dart';
import 'package:tencent_cloud_chat_demo/src/services/moments/moments_realtime_sync_service.dart';
import 'package:tencent_cloud_chat_demo/src/services/red_packet_realtime_sync_service.dart';
import 'package:tencent_cloud_chat_demo/src/services/conversation_refresh_bus.dart';
import 'package:tencent_cloud_chat_demo/src/services/contact_social_cache_store.dart';
import 'package:tencent_cloud_chat_demo/src/platform/route_handler.dart';
import 'package:tencent_cloud_chat_demo/src/services/friend_local/friend_contact_incremental_sync_service.dart';
import 'package:tencent_cloud_chat_demo/src/services/friend_local/friend_sync_service.dart';
import 'package:tencent_cloud_chat_demo/src/services/group_local/group_entity_incremental_sync_service.dart';
import 'package:tencent_cloud_chat_demo/src/services/group_local/group_sync_service.dart';
import 'package:tencent_cloud_chat_demo/src/services/group_join_application_service.dart';
import 'package:tencent_cloud_chat_demo/src/services/group_live/group_live_index_sync_service.dart';
import 'package:tencent_cloud_chat_demo/src/services/group_notice_bootstrap.dart';
import 'package:tencent_cloud_chat_demo/src/services/session_identity.dart';
import 'package:tencent_cloud_chat_demo/src/provider/presence_provider.dart';
import 'package:tencent_cloud_chat_demo/src/services/friend_realtime/friend_realtime_event.dart';
import 'package:tencent_cloud_chat_demo/src/services/friend_realtime_service.dart';
import 'package:tencent_cloud_chat_demo/src/services/in_app_notification_sound.dart';
import 'package:tencent_cloud_chat_demo/src/services/local_system_notification_service.dart';
import 'package:tencent_cloud_chat_demo/src/services/push_msgkey_dedup.dart';
import 'package:tencent_cloud_chat_demo/src/utils/friend_request_poll_gate.dart';
import 'package:tencent_cloud_chat_demo/src/utils/contact_data_source_enter_gate.dart';
import 'package:tencent_cloud_chat_demo/utils/chat_id_format.dart';
import 'package:tencent_cloud_chat_demo/utils/user_avatar.dart';
import 'package:tencent_cloud_chat_uikit/business_logic/view_models/tui_friendship_view_model.dart';
import 'package:tencent_cloud_chat_uikit/business_logic/view_models/tui_self_info_view_model.dart';
import 'package:tencent_cloud_chat_uikit/data_services/services_locatar.dart';
import 'package:tencent_cloud_chat_uikit/tencent_cloud_chat_uikit.dart';

class FriendRequestNoticeService {
  FriendRequestNoticeService._();

  static final FriendRequestNoticeService instance =
      FriendRequestNoticeService._();

  static const Duration _pollInterval = Duration(seconds: 60);

  /// 非通讯录 Tab、TCP 正常时的低频补洞（不全应用 500ms 轮询）。
  static const Duration _contactSyncSlowInterval = Duration(seconds: 15);

  /// 进页已 local+pull 一次，Tab 内仅低频兜底。
  static const Duration _contactSyncTabInterval = Duration(seconds: 30);
  static const Duration _contactSyncFastInterval = Duration(seconds: 5);

  /// 成友等关键事件：0 / 500ms / 1000ms / 1500ms，≤1.5s 内多端对齐。
  static const Duration _contactSyncBurstStep = Duration(milliseconds: 500);
  static const int _contactSyncBurstShots = 4;
  static const int _groupTabIndex = 1;
  static const int _contactTabIndex = 2;
  static const Duration _joinApplicationsResumeDebounce = Duration(seconds: 1);
  static const Duration _dataSourceEnterDebounce = Duration(seconds: 2);

  bool _started = false;
  bool _appInForeground = true;
  int _homeTabIndex = 0;
  Timer? _pollTimer;
  Timer? _contactSyncTimer;
  int _contactSyncBurstGeneration = 0;
  DateTime? _lastJoinApplicationsResumeAt;
  DateTime? _lastContactDataSourceEnterAt;
  DateTime? _lastGroupDataSourceEnterAt;
  final ContactDataSourceEnterSingleFlight _contactDataSourceEnterFlight =
      ContactDataSourceEnterSingleFlight();
  DateTime? _lastRequestToastAt;
  DateTime? _lastFriendAddedNoticeAt;
  String? _lastFriendAddedNoticeKey;
  final Set<int> _notifiedIncomingIds = <int>{};
  final Set<String> _notifiedIncomingKeys = <String>{};
  final Set<int> _readIncomingIds = <int>{};
  final Set<String> _readIncomingKeys = <String>{};

  final ValueNotifier<int> pendingApplicationCount = ValueNotifier<int>(0);
  int _sessionClearGeneration = 0;

  // ignore: avoid_print
  static void _log(String message) {
    // Verbose notice tracing disabled.
  }

  void start() {
    ensureRunning();
  }

  void ensureRunning() {
    final restarting = _started;
    _started = true;

    FriendRealtimeService.instance.onEvent = _handleRealtimeEvent;
    FriendRealtimeService.instance.addAuthOkListener(_onRealtimeAuthOk);
    FriendRealtimeService.instance.start();

    FriendSyncService.instance.onBecameFriendsCompleted = (reason) {
      kickContactSyncBurst(reason: reason);
    };

    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(_pollInterval, (_) {
      if (!shouldPollFriendRequests(
        realtimeReady: FriendRealtimeService.instance.isRealtimeReady,
      )) {
        return;
      }
      unawaited(_pollIncomingRequests());
    });

    _startContactSyncPolling();

    _log(
      'ensureRunning restarting=$restarting poll=${_pollInterval.inSeconds}s '
      'contactSyncSlow=${_contactSyncSlowInterval.inSeconds}s',
    );

    unawaited(_pollIncomingRequests());
    unawaited(refreshPendingCount(notifyUnseen: true));
  }

  /// 首页底部 Tab 切换：通讯录/群聊 Tab 走「先本地再拉一次」。
  void onHomeTabChanged(int index, {bool skipDataSourceEnter = false}) {
    _homeTabIndex = index;
    if (!_started) {
      return;
    }
    if (!skipDataSourceEnter) {
      if (index == _contactTabIndex) {
        unawaited(enterContactDataSource(reason: 'contact_tab'));
      } else if (index == _groupTabIndex) {
        unawaited(enterGroupDataSource(reason: 'group_tab'));
      }
    }
    _startContactSyncPolling();
  }

  /// 进入通讯录数据源：先展示本地 SQLite，再 Difference 补新好友。
  /// Concurrent callers (home Tab + list widget) join one in-flight Future.
  Future<void> enterContactDataSource({required String reason}) {
    if (!_started) {
      return Future<void>.value();
    }
    return _contactDataSourceEnterFlight.run(
      () => _enterContactDataSourceBody(reason: reason),
    );
  }

  Future<void> _enterContactDataSourceBody({required String reason}) async {
    await FriendSyncService.instance.hydrateContactListFromLocal();
    final now = DateTime.now();
    if (!ContactDataSourceEnterGate.shouldRunNetworkPhase(
      now: now,
      lastEnterAt: _lastContactDataSourceEnterAt,
      debounce: _dataSourceEnterDebounce,
    )) {
      return;
    }
    _lastContactDataSourceEnterAt = now;
    await _syncFriendContactDifference(reason: '${reason}_enter');
    await FriendSyncService.instance.refreshUIKitLists(force: false);
  }

  /// 进入群聊相关列表：本地群库增量对账一次。
  Future<void> enterGroupDataSource({required String reason}) async {
    if (!_started) {
      return;
    }
    final now = DateTime.now();
    final last = _lastGroupDataSourceEnterAt;
    if (last != null && now.difference(last) < _dataSourceEnterDebounce) {
      return;
    }
    _lastGroupDataSourceEnterAt = now;
    try {
      await GroupEntityIncrementalSyncService.instance.sync(
        reason: '${reason}_enter',
      );
      await serviceLocator<TUIFriendShipViewModel>().loadGroupListData();
    } catch (e) {
      _log('enterGroupDataSource failed reason=$reason: $e');
    }
  }

  void _onRealtimeAuthOk() {
    unawaited(_syncFriendContactDifference(reason: 'tcp_auth_ok'));
    kickContactSyncBurst(reason: 'tcp_auth_ok');
    _startContactSyncPolling();
    unawaited(_pollIncomingRequests());
    unawaited(refreshPendingCount(notifyUnseen: true));
  }

  void onAppLifecycleChanged(AppLifecycleState state) {
    if (!_started) {
      return;
    }
    FriendRealtimeService.instance.onAppLifecycleChanged(state);
    switch (state) {
      case AppLifecycleState.resumed:
        _appInForeground = true;
        kickContactSyncBurst(reason: 'app_resumed');
        _startContactSyncPolling();
        unawaited(_pollIncomingRequests());
        unawaited(refreshPendingCount(notifyUnseen: true));
        unawaited(GroupNoticeBootstrap.refreshFromNetwork());
        GroupLiveIndexSyncService.instance.onAppResumed();
        _refreshJoinApplicationsOnResume();
        return;
      case AppLifecycleState.paused:
      case AppLifecycleState.hidden:
      case AppLifecycleState.detached:
        _appInForeground = false;
        _stopContactSyncPolling();
        return;
      case AppLifecycleState.inactive:
        return;
    }
  }

  Duration _contactSyncPollInterval() {
    if (!FriendRealtimeService.instance.isRealtimeReady) {
      return _contactSyncFastInterval;
    }
    if (_homeTabIndex == _contactTabIndex) {
      return _contactSyncTabInterval;
    }
    return _contactSyncSlowInterval;
  }

  void _startContactSyncPolling() {
    if (!_started || !_appInForeground) {
      return;
    }
    _contactSyncTimer?.cancel();
    final interval = _contactSyncPollInterval();
    unawaited(_syncFriendContactDifference(reason: 'contact_sync_poll'));
    _contactSyncTimer = Timer.periodic(interval, (_) {
      unawaited(_syncFriendContactDifference(reason: 'contact_sync_poll'));
    });
  }

  /// 成友/切 Tab 等关键时机：短时 burst 补拉，不恢复全应用 500ms 轮询。
  void kickContactSyncBurst({required String reason}) {
    if (!_started) {
      return;
    }
    final generation = ++_contactSyncBurstGeneration;
    unawaited(
      _syncFriendContactDifference(
        reason: '${reason}_burst_0',
        restart: true,
      ),
    );
    for (var shot = 1; shot < _contactSyncBurstShots; shot++) {
      final delay = _contactSyncBurstStep * shot;
      Timer(delay, () {
        if (!_started || generation != _contactSyncBurstGeneration) {
          return;
        }
        unawaited(
          _syncFriendContactDifference(
            reason: '${reason}_burst_$shot',
            restart: shot == 1,
          ),
        );
      });
    }
  }

  void _stopContactSyncPolling() {
    _contactSyncBurstGeneration++;
    _contactSyncTimer?.cancel();
    _contactSyncTimer = null;
  }

  void _refreshJoinApplicationsOnResume() {
    final now = DateTime.now();
    final last = _lastJoinApplicationsResumeAt;
    if (last != null &&
        now.difference(last) < _joinApplicationsResumeDebounce) {
      return;
    }
    _lastJoinApplicationsResumeAt = now;
    unawaited(
      GroupJoinApplicationService.instance.refresh(
        force: true,
        syncMembership: false,
      ),
    );
  }

  Future<void> stop() async {
    _sessionClearGeneration++;
    _pollTimer?.cancel();
    _pollTimer = null;
    _stopContactSyncPolling();
    if (!_started) {
      _lastRequestToastAt = null;
      _lastFriendAddedNoticeAt = null;
      _lastFriendAddedNoticeKey = null;
      _notifiedIncomingIds.clear();
      _notifiedIncomingKeys.clear();
      _readIncomingIds.clear();
      _readIncomingKeys.clear();
      pendingApplicationCount.value = 0;
      return;
    }
    _started = false;
    _lastRequestToastAt = null;
    _lastFriendAddedNoticeAt = null;
    _lastFriendAddedNoticeKey = null;
    _notifiedIncomingIds.clear();
    _notifiedIncomingKeys.clear();
    _readIncomingIds.clear();
    _readIncomingKeys.clear();
    pendingApplicationCount.value = 0;
    FriendSyncService.instance.onBecameFriendsCompleted = null;
    FriendRealtimeService.instance.onEvent = null;
    FriendRealtimeService.instance.removeAuthOkListener(_onRealtimeAuthOk);
    await FriendRealtimeService.instance.stop();
  }

  Future<void> _pollIncomingRequests() async {
    if (!_started) {
      return;
    }
    final identity = SessionIdentityService.instance.capture();
    final clearGeneration = _sessionClearGeneration;
    if (identity.ownerUserId.isEmpty) {
      return;
    }
    try {
      final incoming = await FriendRequestApi.instance.fetchIncomingPending();
      if (!_isCurrentRefresh(identity, clearGeneration)) {
        return;
      }
      await _syncIncomingNotifications(
        incoming,
        source: 'poll',
        identity: identity,
        clearGeneration: clearGeneration,
      );
    } catch (e) {
      _log('poll failed $e');
    }
  }

  Future<void> _syncIncomingNotifications(
    List<FriendRequestRecord> incoming, {
    required String source,
    bool notifyUnseen = true,
    SessionIdentity? identity,
    int? clearGeneration,
  }) async {
    if (identity != null &&
        !_isCurrentRefresh(
            identity, clearGeneration ?? _sessionClearGeneration)) {
      return;
    }
    final unreadCount = incoming.where(_isUnreadForBadge).length;
    if (pendingApplicationCount.value != unreadCount) {
      pendingApplicationCount.value = unreadCount;
    }
    if (!notifyUnseen || incoming.isEmpty) {
      return;
    }

    final unseen = incoming.where(_isUnseenIncoming).toList();
    if (unseen.isEmpty) {
      return;
    }

    unseen.sort((a, b) => b.displayTimestamp.compareTo(a.displayTimestamp));
    final latest = unseen.first;
    _markIncomingNotified(latest);
    _log(
      'notify unseen source=$source id=${latest.id} from=${latest.userID} '
      'unread=$unreadCount',
    );
    await _notifyFriendRequestReceived(
      userID: latest.userID,
      displayName: latest.nickname,
      faceUrl: latest.faceUrl,
      expectedIdentity: identity,
      expectedClearGeneration: clearGeneration,
    );
  }

  bool _isCurrentRefresh(SessionIdentity identity, int clearGeneration) {
    return _started &&
        clearGeneration == _sessionClearGeneration &&
        SessionIdentityService.instance.isCurrent(identity);
  }

  bool _isUnseenIncoming(FriendRequestRecord record) {
    if (record.hasServerId) {
      return !_notifiedIncomingIds.contains(record.id);
    }
    return !_notifiedIncomingKeys.contains(record.identityKey);
  }

  bool _isUnreadForBadge(FriendRequestRecord record) {
    if (record.hasServerId) {
      return !_readIncomingIds.contains(record.id);
    }
    return !_readIncomingKeys.contains(record.identityKey);
  }

  void _markIncomingRead(FriendRequestRecord record) {
    if (record.hasServerId) {
      _readIncomingIds.add(record.id!);
      return;
    }
    _readIncomingKeys.add(record.identityKey);
  }

  void _markIncomingNotified(FriendRequestRecord record) {
    if (record.hasServerId) {
      _notifiedIncomingIds.add(record.id!);
      return;
    }
    _notifiedIncomingKeys.add(record.identityKey);
  }

  void _markIncomingNotifiedByEvent(FriendRealtimeEvent event) {
    final requestId = event.requestId;
    if (requestId != null && requestId > 0) {
      _notifiedIncomingIds.add(requestId);
    }
  }

  Future<void> _handleRealtimeEvent(FriendRealtimeEvent event) async {
    final identity = SessionIdentityService.instance.capture();
    final clearGeneration = _sessionClearGeneration;
    if (!_isCurrentRefresh(identity, clearGeneration)) return;
    _log(
      'realtime event=${event.event} from=${event.fromUserId} '
      'to=${event.toUserId} requestId=${event.requestId}',
    );
    final selfId = _selfUserId();

    switch (event.event) {
      case 'friend_request_received':
        if (selfId.isNotEmpty &&
            event.toUserId.trim().isNotEmpty &&
            !_isSameUser(event.toUserId, selfId)) {
          if (kDebugMode) {
            debugPrint(
              'FriendRequestNotice: skip received '
              'target=${event.toUserId} self=$selfId',
            );
          }
          return;
        }
        await _onFriendRequestReceived(event, identity, clearGeneration);
        return;
      case 'friend_request_accepted':
      case 'friend_request_rejected':
        if (selfId.isNotEmpty && !_eventInvolvesSelf(event, selfId)) {
          return;
        }
        if (event.event == 'friend_request_accepted') {
          await _onFriendRequestAccepted(event, identity, clearGeneration);
        } else {
          await _onFriendRequestRejected(event, identity, clearGeneration);
        }
        return;
      case 'friend_request_auto_accepted':
      case 'friend_restored':
        if (selfId.isNotEmpty && !_eventInvolvesSelf(event, selfId)) {
          return;
        }
        await _onFriendRelationshipChanged(event, identity, clearGeneration);
        return;
      case 'friend_list_changed':
        await _onFriendListChanged(event);
        return;
      case 'group_changed':
        await _onGroupChanged(event);
        return;
      case 'call_recent_changed':
        await _onCallRecentChanged(event);
        return;
      case 'presence_changed':
        _onPresenceChanged(event);
        return;
      case 'red_packet_changed':
        await _onRedPacketChanged(event);
        return;
      case 'moment_changed':
        await _onMomentChanged(event);
        return;
      case 'conversation_archive_changed':
        await _onConversationArchiveChanged(event);
        return;
      case 'conversation_folder_changed':
        await _onConversationFolderChanged(event);
        return;
      case 'conversation_pin_changed':
        await _onConversationPinChanged(event);
        return;
      default:
        return;
    }
  }

  Future<void> _onMomentChanged(FriendRealtimeEvent event) async {
    await MomentsRealtimeSyncService.instance.handleRealtimeEvent(event);
  }

  Future<void> _onConversationArchiveChanged(FriendRealtimeEvent event) async {
    await ArchivedConversationSyncService.instance.handleRealtimeEvent(event);
  }

  Future<void> _onConversationFolderChanged(FriendRealtimeEvent event) async {
    await ConversationFolderSyncService.instance.handleRealtimeEvent(event);
  }

  Future<void> _onConversationPinChanged(FriendRealtimeEvent event) async {
    await ConversationPinSyncService.instance.handleRealtimeEvent(event);
  }

  Future<void> _onFriendListChanged(FriendRealtimeEvent event) async {
    final changed = await FriendSyncService.instance.applyListChanged(event);
    if (!changed) {
      await FriendSyncService.instance
          .syncFull(reason: 'list_changed_fallback');
    }
    await FriendSyncService.instance.refreshUIKitLists(force: true);
    unawaited(
      _syncFriendContactDifference(
        reason: 'friend_list_changed',
        restart: true,
      ),
    );
    kickContactSyncBurst(reason: 'friend_list_changed');
  }

  /// 多端登录补洞：TCP 就绪时仍周期拉 Difference，避免仅本机收到成友事件。
  Future<void> _syncFriendContactDifference({
    required String reason,
    bool restart = false,
  }) async {
    if (!_started) {
      return;
    }
    try {
      await FriendContactIncrementalSyncService.instance.sync(
        reason: reason,
        restart: restart,
      );
    } catch (e) {
      _log('friend contact difference failed reason=$reason: $e');
    }
  }

  Future<void> _onGroupChanged(FriendRealtimeEvent event) async {
    await GroupSyncService.instance.handleRealtimeEvent(event);
  }

  Future<void> _onCallRecentChanged(FriendRealtimeEvent event) async {
    await CallRecentSyncService.instance.handleRealtimeEvent(event);
  }

  Future<void> _onRedPacketChanged(FriendRealtimeEvent event) async {
    await RedPacketRealtimeSyncService.instance.handleRealtimeEvent(event);
  }

  void _onPresenceChanged(FriendRealtimeEvent event) {
    final peerId = event.peerUserId?.trim() ?? '';
    if (peerId.isEmpty) {
      return;
    }
    PresenceProvider.activeInstance?.applyPresenceChanged(
      peerUserId: peerId,
      lastActiveAt: event.lastActiveAt ?? event.ts,
      lastActiveVisibility: event.lastActiveVisibility,
      online: event.online ?? true,
    );
  }

  Future<void> _onFriendRequestReceived(
    FriendRealtimeEvent event,
    SessionIdentity identity,
    int clearGeneration,
  ) async {
    _markIncomingNotifiedByEvent(event);
    await refreshPendingCount();
    ConversationRefreshBus.instance.requestRefresh(
      reason: 'friend_application_added',
    );
    final userID = event.fromUserId.trim();
    final dedupKey = _friendNoticeKey(
      requestId: event.requestId,
      userId: userID,
    );
    if (PushMsgKeyDedup.instance.wasHandled(dedupKey)) {
      return;
    }
    if (!PushMsgKeyDedup.instance.tryClaim(dedupKey)) {
      return;
    }
    final name = await _resolveDisplayName(userID);
    if (!_isCurrentRefresh(identity, clearGeneration)) return;
    await _notifyFriendRequestReceived(
      userID: userID,
      displayName: name,
      expectedIdentity: identity,
      expectedClearGeneration: clearGeneration,
    );
  }

  String _friendNoticeKey({int? requestId, required String userId}) {
    if (requestId != null && requestId > 0) {
      return 'friend_request:$requestId';
    }
    final id = userId.trim();
    return 'friend_request:user:$id';
  }

  Future<void> _notifyFriendRequestReceived({
    required String userID,
    String? displayName,
    String? faceUrl,
    SessionIdentity? expectedIdentity,
    int? expectedClearGeneration,
  }) async {
    bool isCurrent() =>
        expectedIdentity == null ||
        _isCurrentRefresh(
          expectedIdentity,
          expectedClearGeneration ?? _sessionClearGeneration,
        );
    if (!isCurrent()) return;
    final now = DateTime.now();
    final last = _lastRequestToastAt;
    if (last != null && now.difference(last) < const Duration(seconds: 2)) {
      return;
    }

    final id = userID.trim();
    final name = (displayName ?? '').trim().isNotEmpty
        ? displayName!.trim()
        : (id.isNotEmpty ? await _resolveDisplayName(id) : '');
    if (!isCurrent()) return;
    final text = name.isEmpty
        ? AppI18n.current.t(
            zhHans: '收到新的好友申请',
            zhHant: '收到新的好友申請',
            en: 'New friend request received',
            ja: '新しい友達申請が届きました',
            ko: '새 친구 요청을 받았습니다',
          )
        : AppI18n.current.format(
            zhHans: '{name} 请求添加你为好友',
            zhHant: '{name} 請求新增你為好友',
            en: '{name} sent you a friend request',
            ja: '{name} さんから友達申請が届きました',
            ko: '{name}님이 친구 요청을 보냈습니다',
            vars: {'name': name},
          );
    final title = AppI18n.current.t(
      zhHans: '新的好友申请',
      zhHant: '新的好友申請',
      en: 'New friend request',
      ja: '新しい友達申請',
      ko: '새 친구 요청',
    );
    final apiFace = (faceUrl ?? '').trim();
    final resolvedFaceUrl = apiFace.isNotEmpty &&
            UserAvatarHelper.resolveDisplayUrl(apiFace) != null
        ? apiFace
        : (id.isNotEmpty ? await _resolveFaceUrl(id) : '');
    if (!isCurrent()) return;
    final shown = await _showFriendNotice(
      key: 'friend_application_$id',
      title: title,
      body: text,
      faceUrl: resolvedFaceUrl,
      showName: name.isEmpty ? title : name,
      userID: id,
      type: 'friend_request',
      onTap: RouteHandler.openNewContact,
      expectedIdentity: expectedIdentity,
      expectedClearGeneration: expectedClearGeneration,
    );
    if (shown) {
      _lastRequestToastAt = DateTime.now();
    }
  }

  Future<void> _onFriendRequestAccepted(
    FriendRealtimeEvent event,
    SessionIdentity identity,
    int clearGeneration,
  ) async {
    final peerUserId = _peerUserIdFromEvent(event);
    await FriendSyncService.instance.onBecameFriends(
      peerUserId: peerUserId,
      nickname: event.peerNickname,
      avatarUrl: event.peerAvatarUrl,
      remark: event.remark ?? '',
      reason: 'friend_request_accepted',
    );
    if (!_isCurrentRefresh(identity, clearGeneration)) return;
    kickContactSyncBurst(reason: 'friend_request_accepted');
    await refreshPendingCount();
    await _showFriendOutcomeNotice(
      peerUserId: peerUserId,
      title: AppI18n.current.t(
        zhHans: '好友申请已通过',
        zhHant: '好友申請已通過',
        en: 'Friend request accepted',
        ja: '友達申請が承認されました',
        ko: '친구 요청이 수락되었습니다',
      ),
      bodyBuilder: (name) => name.isEmpty
          ? AppI18n.current.t(
              zhHans: '对方已同意你的好友申请',
              zhHant: '對方已同意你的好友申請',
              en: 'Your friend request was accepted',
              ja: '友達申請が承認されました',
              ko: '친구 요청이 수락되었습니다',
            )
          : AppI18n.current.format(
              zhHans: '{name} 已同意你的好友申请',
              zhHant: '{name} 已同意你的好友申請',
              en: '{name} accepted your friend request',
              ja: '{name} さんが友達申請を承認しました',
              ko: '{name}님이 친구 요청을 수락했습니다',
              vars: {'name': name},
            ),
      noticeType: 'friend_request_accepted',
      openConversation: true,
      expectedIdentity: identity,
      expectedClearGeneration: clearGeneration,
    );
  }

  Future<void> _onFriendRequestRejected(
    FriendRealtimeEvent event,
    SessionIdentity identity,
    int clearGeneration,
  ) async {
    await refreshPendingCount();
    if (!_isCurrentRefresh(identity, clearGeneration)) return;
    ConversationRefreshBus.instance.requestRefresh(
      reason: 'friend_application_refresh',
    );
    final peerUserId = _peerUserIdFromEvent(event);
    await _showFriendOutcomeNotice(
      peerUserId: peerUserId,
      title: AppI18n.current.t(
        zhHans: '好友申请未通过',
        zhHant: '好友申請未通過',
        en: 'Friend request declined',
        ja: '友達申請は承認されませんでした',
        ko: '친구 요청이 거절되었습니다',
      ),
      bodyBuilder: (name) => name.isEmpty
          ? AppI18n.current.t(
              zhHans: '对方拒绝了你的好友申请',
              zhHant: '對方拒絕了你的好友申請',
              en: 'Your friend request was declined',
              ja: '友達申請は拒否されました',
              ko: '친구 요청이 거절되었습니다',
            )
          : AppI18n.current.format(
              zhHans: '{name} 拒绝了你的好友申请',
              zhHant: '{name} 拒絕了你的好友申請',
              en: '{name} declined your friend request',
              ja: '{name} さんが友達申請を拒否しました',
              ko: '{name}님이 친구 요청을 거절했습니다',
              vars: {'name': name},
            ),
      noticeType: 'friend_request_rejected',
      openConversation: false,
      onTap: RouteHandler.openNewContact,
      expectedIdentity: identity,
      expectedClearGeneration: clearGeneration,
    );
  }

  Future<void> _onFriendRelationshipChanged(
    FriendRealtimeEvent event,
    SessionIdentity identity,
    int clearGeneration,
  ) async {
    final selfId = _selfUserId();
    final peerUserId = _isSameUser(event.fromUserId, selfId)
        ? event.toUserId.trim()
        : event.fromUserId.trim();
    final resolvedPeer =
        peerUserId.isNotEmpty ? peerUserId : _peerUserIdFromEvent(event);
    await FriendSyncService.instance.onBecameFriends(
      peerUserId: resolvedPeer,
      nickname: event.peerNickname,
      avatarUrl: event.peerAvatarUrl,
      remark: event.remark ?? '',
      reason: event.event,
    );
    if (!_isCurrentRefresh(identity, clearGeneration)) return;
    kickContactSyncBurst(reason: event.event);
    if (resolvedPeer.isNotEmpty && event.event != 'friend_restored') {
      // friend_restored 不进「新的朋友」历史；自动通过写入已处理。
      final direction = _isSameUser(event.toUserId, selfId)
          ? FriendRequestDirection.incoming
          : FriendRequestDirection.outgoing;
      unawaited(
        FriendApplicationHelper.recordBecameFriendsHistory(
          userID: resolvedPeer,
          nickname: event.peerNickname ?? '',
          faceUrl: event.peerAvatarUrl ?? '',
          addSource: 'auto',
          direction: direction,
        ),
      );
    }
    await refreshPendingCount();
    if (event.event == 'friend_restored') {
      return;
    }

    if (resolvedPeer.isEmpty) {
      return;
    }

    await _showFriendOutcomeNotice(
      peerUserId: resolvedPeer,
      title: AppI18n.current.t(
        zhHans: '已成为好友',
        zhHant: '已成為好友',
        en: 'You are now friends',
        ja: '友達になりました',
        ko: '친구가 되었습니다',
      ),
      bodyBuilder: (name) => name.isEmpty
          ? AppI18n.current.t(
              zhHans: '你们已成为好友',
              zhHant: '你們已成為好友',
              en: 'You are now friends',
              ja: '友達になりました',
              ko: '친구가 되었습니다',
            )
          : AppI18n.current.format(
              zhHans: '你与 {name} 已成为好友',
              zhHant: '你與 {name} 已成為好友',
              en: 'You and {name} are now friends',
              ja: '{name} さんと友達になりました',
              ko: '{name}님과 친구가 되었습니다',
              vars: {'name': name},
            ),
      noticeType: event.event,
      openConversation: true,
      expectedIdentity: identity,
      expectedClearGeneration: clearGeneration,
    );
  }

  Future<void> _showFriendOutcomeNotice({
    required String peerUserId,
    required String title,
    required String Function(String name) bodyBuilder,
    required String noticeType,
    required bool openConversation,
    FutureOr<void> Function()? onTap,
    SessionIdentity? expectedIdentity,
    int? expectedClearGeneration,
  }) async {
    bool isCurrent() =>
        expectedIdentity == null ||
        _isCurrentRefresh(
          expectedIdentity,
          expectedClearGeneration ?? _sessionClearGeneration,
        );
    if (!isCurrent()) return;
    if (peerUserId.isEmpty) {
      return;
    }

    final dedupKey = 'friend_outcome:${noticeType}_$peerUserId';
    if (PushMsgKeyDedup.instance.wasHandled(dedupKey)) {
      return;
    }
    if (!PushMsgKeyDedup.instance.tryClaim(dedupKey)) {
      return;
    }

    final now = DateTime.now();
    final last = _lastFriendAddedNoticeAt;
    if (_lastFriendAddedNoticeKey == peerUserId &&
        last != null &&
        now.difference(last) < const Duration(seconds: 2)) {
      return;
    }

    final name = await _resolveDisplayName(peerUserId);
    if (!isCurrent()) return;
    final faceUrl = await _resolveFaceUrl(peerUserId);
    if (!isCurrent()) return;
    final shown = await _showFriendNotice(
      key: '${noticeType}_$peerUserId',
      title: title,
      body: bodyBuilder(name),
      showName: name.isEmpty ? title : name,
      faceUrl: faceUrl,
      userID: peerUserId,
      type: noticeType,
      conversationID: openConversation ? 'c2c_$peerUserId' : null,
      onTap: onTap ??
          (openConversation
              ? () => RouteHandler.openConversation('c2c_$peerUserId')
              : RouteHandler.openNewContact),
      expectedIdentity: expectedIdentity,
      expectedClearGeneration: expectedClearGeneration,
    );
    if (shown) {
      _lastFriendAddedNoticeAt = DateTime.now();
      _lastFriendAddedNoticeKey = peerUserId;
    }
  }

  Future<bool> _showFriendNotice({
    required String key,
    required String title,
    required String body,
    required String userID,
    required String type,
    required FutureOr<void> Function() onTap,
    String? conversationID,
    String faceUrl = '',
    String showName = '',
    SessionIdentity? expectedIdentity,
    int? expectedClearGeneration,
  }) async {
    if (expectedIdentity != null &&
        !_isCurrentRefresh(
          expectedIdentity,
          expectedClearGeneration ?? _sessionClearGeneration,
        )) {
      return false;
    }
    unawaited(InAppNotificationSound.playMessageReceived());

    final systemShown =
        await LocalSystemNotificationService.instance.showChatMessage(
      title: title,
      body: body,
      conversationID: conversationID ?? '',
      ext: jsonEncode(<String, dynamic>{
        'type': type,
        'userID': userID,
        'conversationID': conversationID ?? '',
      }),
      avatarUrl: faceUrl.isNotEmpty ? faceUrl : null,
    );
    if (expectedIdentity != null &&
        !_isCurrentRefresh(
          expectedIdentity,
          expectedClearGeneration ?? _sessionClearGeneration,
        )) {
      return false;
    }
    if (systemShown) {
      if (kDebugMode) {
        debugPrint(
          'FriendRequestNotice: system notification shown type=$type',
        );
      }
      return true;
    }

    final noticeShown = AppDialog.showNotice(
      title: title,
      message: body.isNotEmpty ? body : title,
      duration: const Duration(seconds: 3),
      onTap: onTap,
    );
    if (noticeShown) {
      if (kDebugMode) {
        debugPrint('FriendRequestNotice: app notice shown type=$type');
      }
      return true;
    }
    return false;
  }

  /// 离线 Push / 前台补推时刷新待处理申请并尝试弹出提示。
  Future<void> handlePushFriendRequest({
    String? fromUserId,
    String? displayName,
    int? requestId,
  }) async {
    await refreshPendingCount(notifyUnseen: true);
    final id = fromUserId?.trim() ?? '';
    if (id.isEmpty) {
      return;
    }
    final dedupKey = _friendNoticeKey(requestId: requestId, userId: id);
    if (PushMsgKeyDedup.instance.wasHandled(dedupKey)) {
      return;
    }
    if (!PushMsgKeyDedup.instance.tryClaim(dedupKey)) {
      return;
    }
    await _notifyFriendRequestReceived(userID: id, displayName: displayName);
  }

  Future<void> handlePushFriendList(Map<String, dynamic> data) async {
    await FriendSyncService.instance.handlePushFriendList(data);
  }

  Future<void> handlePushGroupChanged(Map<String, dynamic> data) async {
    await GroupSyncService.instance.handlePushGroupChanged(data);
  }

  Future<void> refreshPendingCount({
    bool markRead = false,
    bool notifyUnseen = false,
  }) async {
    final identity = SessionIdentityService.instance.capture();
    final clearGeneration = _sessionClearGeneration;
    if (identity.ownerUserId.isEmpty ||
        !_isCurrentRefresh(identity, clearGeneration)) {
      return;
    }
    try {
      if (markRead) {
        final incoming = await FriendRequestApi.instance.fetchIncomingPending();
        if (!_isCurrentRefresh(identity, clearGeneration)) {
          return;
        }
        for (final record in incoming) {
          _markIncomingRead(record);
        }
        pendingApplicationCount.value = 0;
        return;
      }
      final incoming = await FriendRequestApi.instance.fetchIncomingPending();
      if (!_isCurrentRefresh(identity, clearGeneration)) {
        return;
      }
      await _syncIncomingNotifications(
        incoming,
        source: 'refresh',
        notifyUnseen: notifyUnseen,
        identity: identity,
        clearGeneration: clearGeneration,
      );
    } catch (e) {
      _log('refreshPendingCount failed $e');
    }
  }

  String _selfUserId() {
    final authoritative = ChatIdFormat.rawUserUid(
      ContactSocialCacheStore.safeLoginUserId(),
    );
    if (authoritative.isNotEmpty) return authoritative;
    try {
      final fromCore = ChatIdFormat.rawUserUid(
        TIMUIKitCore.getInstance().loginInfo.userID,
      );
      if (fromCore.isNotEmpty) {
        return fromCore;
      }
    } catch (_) {}
    return ChatIdFormat.rawUserUid(
      serviceLocator<TUISelfInfoViewModel>().loginInfo?.userID,
    );
  }

  bool _eventInvolvesSelf(FriendRealtimeEvent event, String selfId) {
    return _isSameUser(event.fromUserId, selfId) ||
        _isSameUser(event.toUserId, selfId);
  }

  String _peerUserIdFromEvent(FriendRealtimeEvent event) {
    final selfId = _selfUserId();
    if (selfId.isNotEmpty && _isSameUser(event.fromUserId, selfId)) {
      return event.toUserId.trim();
    }
    if (selfId.isNotEmpty && _isSameUser(event.toUserId, selfId)) {
      return event.fromUserId.trim();
    }
    return event.toUserId.trim().isNotEmpty
        ? event.toUserId.trim()
        : event.fromUserId.trim();
  }

  bool _isSameUser(String? a, String? b) {
    final left = ChatIdFormat.rawUserUid(a);
    final right = ChatIdFormat.rawUserUid(b);
    return left.isNotEmpty && right.isNotEmpty && left == right;
  }

  Future<String> _resolveDisplayName(String userId) async {
    final id = userId.trim();
    if (id.isEmpty) {
      return '';
    }
    try {
      final res =
          await TIMUIKitCore.getSDKInstance().getUsersInfo(userIDList: [id]);
      if (res.code == 0 && res.data != null && res.data!.isNotEmpty) {
        final nick = res.data!.first.nickName?.trim() ?? '';
        if (nick.isNotEmpty) {
          return nick;
        }
      }
    } catch (_) {}
    return id;
  }

  Future<String> _resolveFaceUrl(String userId) async {
    final id = userId.trim();
    if (id.isEmpty) {
      return '';
    }
    try {
      final res =
          await TIMUIKitCore.getSDKInstance().getUsersInfo(userIDList: [id]);
      if (res.code == 0 && res.data != null && res.data!.isNotEmpty) {
        return res.data!.first.faceUrl?.trim() ?? '';
      }
    } catch (_) {}
    return '';
  }
}
