import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:tencent_cloud_chat_demo/src/api/presence_api.dart';
import 'package:tencent_cloud_chat_demo/src/api/user_api.dart';
import 'package:tencent_cloud_chat_demo/src/i18n/app_i18n.dart';
import 'package:tencent_cloud_chat_demo/src/services/contact_social_cache_store.dart';
import 'package:tencent_cloud_chat_demo/src/services/friend_realtime/presence_last_seen_codec.dart';
import 'package:tencent_cloud_chat_demo/src/services/friend_realtime_service.dart';
import 'package:tencent_cloud_chat_demo/utils/chat_id_format.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_user_status.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_user_status.dart';
import 'package:tencent_cloud_chat_uikit/business_logic/view_models/tui_self_info_view_model.dart';
import 'package:tencent_cloud_chat_uikit/data_services/services_locatar.dart';

class PresenceProvider extends ChangeNotifier {
  static PresenceProvider? activeInstance;

  PresenceProvider() {
    activeInstance = this;
    _ageTimer = Timer.periodic(const Duration(minutes: 1), (_) => _notifySafely());
    FriendRealtimeService.instance.addReadyListener(_onRealtimeReady);
    hydrateFromLocalCache();
  }

  final Map<String, int> _lastSeen = {};
  final Map<String, DateTime> _lastFetchAt = {};
  final Map<String, String> _lastActiveVisibility = {};
  final Set<String> _visibilityFromApi = {};
  final Map<String, DateTime> _visibilityFetchAt = {};
  final Set<String> _pending = {};
  final Set<String> _inFlight = {};
  final Set<String> _visibilityInFlight = {};
  Timer? _flushTimer;
  Timer? _heartbeatTimer;
  Timer? _ageTimer;
  bool _notifyScheduled = false;
  bool _heartbeatWanted = false;
  bool _heartbeatRunning = false;
  bool _flushInFlight = false;
  bool _disposed = false;
  bool _hydratedFromLocalCache = false;
  String? _activeScope;
  /// 列表/通讯录软刷新：有缓存则少打全量。
  static const Duration _softFetchTtl = Duration(minutes: 3);

  /// 聊天头 / IM 状态变更等需要较新数据。
  static const Duration _urgentFetchTtl = Duration(seconds: 25);

  static const Duration _visibilityTtl = Duration(hours: 1);
  static const Duration _backendOnlineTtl = Duration(seconds: 45);
  static const Duration _flushDebounce = Duration(milliseconds: 400);

  /// 单次 last-seen 的 userIds 上限（TCP / HTTP 对齐服务端 200）。
  static const int _maxBatchSize = PresenceLastSeenCodec.maxBatchSize;

  final Map<String, DateTime> _backendOnlineUntil = {};

  /// 单号体系：直接用 rawUserUid，不再区分业务号 / IM 号。
  Set<String> _keysFor(String raw) {
    final id = ChatIdFormat.rawUserUid(raw);
    if (id.isEmpty) {
      return <String>{};
    }
    return <String>{id};
  }

  void _writeLastSeen(String raw, int ts, DateTime now) {
    for (final key in _keysFor(raw)) {
      _lastSeen[key] = ts;
      _lastFetchAt[key] = now;
    }
  }

  void _writeVisibility(String raw, String normalized) {
    for (final key in _keysFor(raw)) {
      _lastActiveVisibility[key] = normalized;
      _visibilityFromApi.add(key);
    }
  }

  void _writeBackendOnline(String raw, bool online) {
    final until = DateTime.now().add(_backendOnlineTtl);
    for (final key in _keysFor(raw)) {
      if (online) {
        _backendOnlineUntil[key] = until;
      } else {
        _backendOnlineUntil.remove(key);
      }
      _pending.remove(key);
      _inFlight.remove(key);
    }
  }

  int? _lookupLastSeen(String raw) {
    for (final key in _keysFor(raw)) {
      final value = _lastSeen[key];
      if (value != null) {
        return value;
      }
    }
    return null;
  }

  String? _lookupVisibility(String raw) {
    for (final key in _keysFor(raw)) {
      final value = _lastActiveVisibility[key];
      if (value != null && value.isNotEmpty) {
        return value;
      }
    }
    return null;
  }

  bool _hasFetchedAny(String raw) {
    for (final key in _keysFor(raw)) {
      if (_lastSeen.containsKey(key) || _lastFetchAt.containsKey(key)) {
        return true;
      }
    }
    return false;
  }

  /// 单号体系：REST 直接用同一 userId。
  Future<String?> _resolveUserIdForRest(String raw) async {
    final id = ChatIdFormat.rawUserUid(raw);
    if (id.isEmpty || _isSelfUser(id)) {
      return null;
    }
    return id;
  }

  int? lastSeenOf(String userId) => _lookupLastSeen(userId);

  String? visibilityOf(String userId) {
    final id = ChatIdFormat.rawUserUid(userId);
    if (id.isEmpty) {
      return null;
    }
    return _lookupVisibility(id);
  }

  bool shouldShowPresence(
    String userId, {
    required bool isMutualFriend,
  }) {
    final id = ChatIdFormat.rawUserUid(userId);
    if (id.isEmpty) {
      return false;
    }
    return LastActiveVisibility.shouldShowLastActive(
      visibility: _lookupVisibility(id),
      isMutualFriend: isMutualFriend,
    );
  }

  bool shouldShowPresenceLabel(
    String userId, {
    required bool isMutualFriend,
  }) {
    final id = ChatIdFormat.rawUserUid(userId);
    if (id.isEmpty) {
      return false;
    }
    return LastActiveVisibility.shouldShowAnyLastActive(
      visibility: _lookupVisibility(id),
      isMutualFriend: isMutualFriend,
    );
  }

  bool _isHiddenPresence(String userId) {
    final id = ChatIdFormat.rawUserUid(userId);
    if (id.isEmpty) {
      return false;
    }
    return LastActiveVisibility.shouldShowCoarseLastActive(
      visibility: _lookupVisibility(id),
    );
  }

  void applyPresenceBatch({
    Map<String, int>? lastSeen,
    Map<String, String>? lastActiveVisibility,
  }) {
    if (_disposed) {
      return;
    }
    var changed = false;
    final persistSeen = <String, int>{};
    final persistVisibility = <String, String>{};
    if (lastSeen != null) {
      final now = DateTime.now();
      for (final entry in lastSeen.entries) {
        final id = ChatIdFormat.rawUserUid(entry.key);
        if (id.isEmpty) {
          continue;
        }
        final before = _lookupLastSeen(id);
        _writeLastSeen(id, entry.value, now);
        if (before != entry.value) {
          changed = true;
        }
        for (final key in _keysFor(id)) {
          persistSeen[key] = entry.value;
        }
      }
    }
    if (lastActiveVisibility != null) {
      for (final entry in lastActiveVisibility.entries) {
        final id = ChatIdFormat.rawUserUid(entry.key);
        final visibility = entry.value.trim();
        if (id.isEmpty || visibility.isEmpty) {
          continue;
        }
        final normalized = LastActiveVisibility.normalize(visibility);
        final before = _lookupVisibility(id);
        _writeVisibility(id, normalized);
        if (before != normalized) {
          changed = true;
        }
        for (final key in _keysFor(id)) {
          persistVisibility[key] = visibility;
        }
      }
    }
    if (changed) {
      _notifySafely();
    }
    if (persistSeen.isNotEmpty) {
      unawaited(ContactSocialCacheStore.mergePresenceLastSeen(persistSeen));
    }
    if (persistVisibility.isNotEmpty) {
      unawaited(
        ContactSocialCacheStore.mergePresenceVisibility(persistVisibility),
      );
    }
  }

  void _notifySafely() {
    if (_disposed) {
      return;
    }
    if (SchedulerBinding.instance.schedulerPhase == SchedulerPhase.idle) {
      notifyListeners();
      return;
    }
    if (_notifyScheduled) {
      return;
    }
    _notifyScheduled = true;
    SchedulerBinding.instance.addPostFrameCallback((_) {
      _notifyScheduled = false;
      if (!_disposed) {
        notifyListeners();
      }
    });
  }

  bool hasFetchedLastSeen(String userId) => _hasFetchedAny(userId);

  /// 聊天页标题等场景：最后活跃时间尚未拉取完成。
  ///
  /// 对方允许展示「在线」且确实在线时无需等待 lastSeen；hidden 始终需 lastSeen 映射粗粒度文案。
  bool isLastSeenLoading({
    required String userId,
    required bool imOnline,
    bool forChatHeader = false,
    bool isMutualFriend = false,
  }) {
    final id = ChatIdFormat.rawUserUid(userId);
    if (id.isEmpty || _isSelfUser(id)) {
      return false;
    }
    if (!shouldShowPresenceLabel(id, isMutualFriend: isMutualFriend)) {
      return false;
    }
    if (shouldShowPresence(id, isMutualFriend: isMutualFriend) &&
        resolveOnline(userId: id, imOnline: imOnline)) {
      return false;
    }
    return !hasFetchedLastSeen(id);
  }

  /// TCP `presence_changed`：始终缓存 lastActiveAt / lastActiveVisibility；展示由隐私判断。
  void applyPresenceChanged({
    required String peerUserId,
    String? imUserId,
    int? lastActiveAt,
    String? lastActiveVisibility,
    bool online = true,
  }) {
    if (_disposed) {
      return;
    }
    // 单号：优先 peerUserId；空时才回退 imUserId（同号兼容，不做双轨映射）。
    final primary = ChatIdFormat.rawUserUid(
      peerUserId.trim().isNotEmpty ? peerUserId : imUserId,
    );
    if (primary.isEmpty) {
      return;
    }
    final now = DateTime.now();
    final persistSeen = <String, int>{};
    final persistVisibility = <String, String>{};
    if (lastActiveAt != null) {
      _writeLastSeen(primary, lastActiveAt, now);
      for (final key in _keysFor(primary)) {
        persistSeen[key] = lastActiveAt;
      }
    }
    if (lastActiveVisibility != null &&
        lastActiveVisibility.trim().isNotEmpty) {
      final normalized = LastActiveVisibility.normalize(lastActiveVisibility);
      _writeVisibility(primary, normalized);
      for (final key in _keysFor(primary)) {
        persistVisibility[key] = normalized;
      }
    }
    _writeBackendOnline(primary, online);
    if (persistSeen.isNotEmpty) {
      unawaited(ContactSocialCacheStore.mergePresenceLastSeen(persistSeen));
    }
    if (persistVisibility.isNotEmpty) {
      unawaited(
        ContactSocialCacheStore.mergePresenceVisibility(persistVisibility),
      );
    }
    _notifySafely();
  }

  bool isBackendOnline(String userId) {
    final id = ChatIdFormat.rawUserUid(userId);
    if (id.isEmpty) {
      return false;
    }
    for (final key in _keysFor(id)) {
      final until = _backendOnlineUntil[key];
      if (until == null) {
        continue;
      }
      if (!DateTime.now().isBefore(until)) {
        _backendOnlineUntil.remove(key);
        continue;
      }
      return true;
    }
    return false;
  }

  bool resolveOnline({
    required String userId,
    required bool imOnline,
  }) {
    return imOnline || isBackendOnline(userId);
  }

  V2TimUserStatus? resolveAvatarOnlineStatus(
    String userId,
    V2TimUserStatus? imStatus, {
    bool isMutualFriend = false,
  }) {
    final id = ChatIdFormat.rawUserUid(userId);
    if (id.isEmpty ||
        !shouldShowPresence(id, isMutualFriend: isMutualFriend)) {
      return imStatus?.statusType == 1 ? null : imStatus;
    }
    if (imStatus?.statusType == 1) {
      return imStatus;
    }
    if (!isBackendOnline(id)) {
      return imStatus;
    }
    return V2TimUserStatus(userID: id, statusType: 1);
  }

  Future<void> hydrateFromLocalCache() async {
    if (_disposed) {
      return;
    }
    final scope = ContactSocialCacheStore.accountScope();
    if (ContactSocialCacheStore.consumeScopeInvalidation(scope) ||
        (_activeScope != null && _activeScope != scope)) {
      _lastSeen.clear();
      _lastFetchAt.clear();
      _lastActiveVisibility.clear();
      _visibilityFromApi.clear();
      _visibilityFetchAt.clear();
      _visibilityInFlight.clear();
      _backendOnlineUntil.clear();
      _pending.clear();
      _hydratedFromLocalCache = false;
    }
    _activeScope = scope;
    if (_hydratedFromLocalCache) {
      return;
    }
    _hydratedFromLocalCache = true;
    final cached = await ContactSocialCacheStore.readPresenceLastSeen();
    final cachedVisibility =
        await ContactSocialCacheStore.readPresenceVisibility();
    if (cached.isEmpty && cachedVisibility.isEmpty) {
      _notifySafely();
      return;
    }
    final now = DateTime.now();
    for (final entry in cached.entries) {
      final id = ChatIdFormat.rawUserUid(entry.key);
      if (id.isEmpty) {
        continue;
      }
      _writeLastSeen(id, entry.value, now);
    }
    for (final entry in cachedVisibility.entries) {
      final id = ChatIdFormat.rawUserUid(entry.key);
      if (id.isEmpty) {
        continue;
      }
      _writeVisibility(id, LastActiveVisibility.normalize(entry.value));
    }
    _notifySafely();
  }

  /// 补齐缺失的 lastSeen；已有缓存或 soft TTL 内不请求。
  void ensure(Iterable<String> userIds) {
    if (_disposed) return;
    bool added = false;
    for (final raw in userIds) {
      final id = ChatIdFormat.rawUserUid(raw);
      if (id.isEmpty || _isSelfUser(id)) continue;
      if (_lookupLastSeen(id) != null) continue;
      if (_isRecentlyFetched(id, ttl: _softFetchTtl)) continue;
      if (_keysFor(id).any(_inFlight.contains)) continue;
      if (_pending.add(id)) added = true;
    }
    if (added) {
      _scheduleFlush();
      _scheduleVisibilityPrefetchIfNeeded(userIds);
    }
  }

  /// 软刷新（默认 3 分钟 TTL）。聊天头 / IM 状态变更请传 [urgent]。
  void refresh(Iterable<String> userIds, {bool urgent = false}) {
    if (_disposed) return;
    final ttl = urgent ? _urgentFetchTtl : _softFetchTtl;
    bool added = false;
    for (final raw in userIds) {
      final id = ChatIdFormat.rawUserUid(raw);
      if (id.isEmpty || _isSelfUser(id)) continue;
      if (_isRecentlyFetched(id, ttl: ttl)) continue;
      if (_keysFor(id).any(_inFlight.contains)) continue;
      if (_pending.add(id)) added = true;
    }
    if (added) _scheduleFlush(immediate: urgent);
    _scheduleVisibilityPrefetchIfNeeded(userIds);
  }

  void _scheduleVisibilityPrefetchIfNeeded(Iterable<String> userIds) {
    if (_disposed || !_needsVisibilityPrefetch(userIds)) {
      return;
    }
    unawaited(_prefetchVisibility(userIds));
  }

  bool _needsVisibilityPrefetch(Iterable<String> userIds) {
    final now = DateTime.now();
    for (final raw in userIds) {
      final id = ChatIdFormat.rawUserUid(raw);
      if (id.isEmpty) {
        continue;
      }
      if (_lookupVisibility(id) != null &&
          _keysFor(id).any(_visibilityFromApi.contains)) {
        continue;
      }
      if (_keysFor(id).any(_visibilityInFlight.contains)) {
        continue;
      }
      if (_keysFor(id).any(_inFlight.contains)) {
        continue;
      }
      final recent = _keysFor(id).any((key) {
        final at = _visibilityFetchAt[key];
        return at != null && now.difference(at) <= _visibilityTtl;
      });
      if (recent) {
        continue;
      }
      return true;
    }
    return false;
  }

  bool canViewPreciseLastActive(
    String userId, {
    bool isMutualFriend = false,
  }) {
    return shouldShowPresence(userId, isMutualFriend: isMutualFriend);
  }

  Future<void> _prefetchVisibility(Iterable<String> userIds) async {
    if (_disposed) {
      return;
    }
    final now = DateTime.now();
    final todo = <String>[];
    for (final raw in userIds) {
      final id = ChatIdFormat.rawUserUid(raw);
      if (id.isEmpty) {
        continue;
      }
      if (_lookupVisibility(id) != null &&
          _keysFor(id).any(_visibilityFromApi.contains)) {
        continue;
      }
      if (_keysFor(id).any(_visibilityInFlight.contains)) {
        continue;
      }
      if (_keysFor(id).any(_inFlight.contains)) {
        continue;
      }
      final recent = _keysFor(id).any((key) {
        final at = _visibilityFetchAt[key];
        return at != null && now.difference(at) <= _visibilityTtl;
      });
      if (recent) {
        continue;
      }
      final restId = await _resolveUserIdForRest(id);
      if (restId == null || restId.isEmpty) {
        continue;
      }
      if (!todo.contains(restId)) {
        todo.add(restId);
      }
      if (todo.length >= 40) {
        break;
      }
    }
    if (todo.isEmpty) {
      return;
    }

    for (final id in todo) {
      for (final key in _keysFor(id)) {
        _visibilityFetchAt[key] = now;
        _visibilityInFlight.add(key);
      }
    }

    var changed = false;
    for (final id in todo) {
      try {
        final settings =
            await UserApi.instance.fetchUserOnlinePrivacyProtection(id);
        final next = settings?.lastActiveVisibility;
        if (next != null && next.trim().isNotEmpty) {
          final normalized = LastActiveVisibility.normalize(next);
          final before = _lookupVisibility(id);
          _writeVisibility(id, normalized);
          if (before != normalized) {
            changed = true;
          }
          final persist = <String, String>{};
          for (final key in _keysFor(id)) {
            persist[key] = next.trim();
          }
          unawaited(
            ContactSocialCacheStore.mergePresenceVisibility(persist),
          );
        }
      } catch (_) {
        // 无单独隐私接口结果时不写入默认值，避免 hidden 被误判为 everyone。
      } finally {
        for (final key in _keysFor(id)) {
          _visibilityInFlight.remove(key);
        }
      }
      if (_disposed) {
        return;
      }
    }
    if (changed && !_disposed) {
      _notifySafely();
    }
  }

  bool _isRecentlyFetched(String userId, {Duration? ttl}) {
    final bound = ttl ?? _softFetchTtl;
    final now = DateTime.now();
    for (final key in _keysFor(userId)) {
      final at = _lastFetchAt[key];
      if (at != null && now.difference(at) < bound) {
        return true;
      }
    }
    return false;
  }

  void _scheduleFlush({bool immediate = false}) {
    if (_disposed) return;
    _flushTimer?.cancel();
    _flushTimer = Timer(
      immediate ? Duration.zero : _flushDebounce,
      _flush,
    );
  }

  Future<void> _flush() async {
    if (_disposed || _pending.isEmpty || _flushInFlight) return;
    _flushInFlight = true;
    _flushTimer?.cancel();
    _flushTimer = null;

    // 合并后分片：一次最多 _maxBatchSize，其余留在 pending 串行续拉。
    final allPending = _pending.toList(growable: false);
    final batchIds = allPending.length <= _maxBatchSize
        ? allPending
        : allPending.sublist(0, _maxBatchSize);
    _pending.removeAll(batchIds);
    _inFlight.addAll(batchIds);

    final requestIds = <String>[];
    final now = DateTime.now();
    for (final id in batchIds) {
      final restId = await _resolveUserIdForRest(id);
      if (restId == null || restId.isEmpty) {
        for (final key in _keysFor(id)) {
          _lastFetchAt[key] = now;
        }
        continue;
      }
      if (!requestIds.contains(restId)) {
        requestIds.add(restId);
      }
    }

    try {
      if (requestIds.isNotEmpty) {
        PresenceLastSeenBatch result;
        if (FriendRealtimeService.instance.isRealtimeReady) {
          try {
            result = await FriendRealtimeService.instance
                .fetchPresenceLastSeen(requestIds);
          } on PresenceLastSeenTcpException catch (e) {
            if (!e.shouldFallbackToHttp) {
              for (final id in requestIds) {
                for (final key in _keysFor(id)) {
                  _lastFetchAt[key] = now;
                }
              }
              result = const PresenceLastSeenBatch(
                lastSeen: {},
                lastActiveVisibility: {},
              );
            } else {
              result = await PresenceApi.instance.fetchLastSeen(requestIds);
            }
          }
        } else {
          result = await PresenceApi.instance.fetchLastSeen(requestIds);
        }
        final seenUpdates = <String, int>{};
        final visibilityUpdates = <String, String>{};
        for (final id in requestIds) {
          final ts = result.lastSeen[id] ??
              _lookupByRawKey(result.lastSeen, id);
          if (ts != null) {
            _writeLastSeen(id, ts, now);
            for (final key in _keysFor(id)) {
              seenUpdates[key] = ts;
            }
          } else {
            for (final key in _keysFor(id)) {
              _lastFetchAt[key] = now;
            }
          }
          final visibility = result.lastActiveVisibility[id] ??
              _lookupByRawKey(result.lastActiveVisibility, id);
          if (visibility != null && visibility.trim().isNotEmpty) {
            final normalized = LastActiveVisibility.normalize(visibility);
            _writeVisibility(id, normalized);
            for (final key in _keysFor(id)) {
              visibilityUpdates[key] = visibility.trim();
            }
          }
        }
        if (seenUpdates.isNotEmpty) {
          await ContactSocialCacheStore.mergePresenceLastSeen(seenUpdates);
        }
        if (visibilityUpdates.isNotEmpty) {
          await ContactSocialCacheStore.mergePresenceVisibility(
            visibilityUpdates,
          );
        }
      }
      if (!_disposed) _notifySafely();
    } catch (_) {
      if (!_disposed) {
        _pending.addAll(batchIds);
        _scheduleFlush(immediate: false);
      }
    } finally {
      _inFlight.removeAll(batchIds);
      _flushInFlight = false;
      if (!_disposed && _pending.isNotEmpty) {
        _scheduleFlush(immediate: false);
      }
    }
  }

  T? _lookupByRawKey<T>(Map<String, T> map, String normalizedId) {
    if (map.containsKey(normalizedId)) {
      return map[normalizedId];
    }
    for (final entry in map.entries) {
      if (ChatIdFormat.rawUserUid(entry.key) == normalizedId) {
        return entry.value;
      }
    }
    return null;
  }

  void _onRealtimeReady(bool ready) {
    if (_disposed || !_heartbeatWanted) {
      return;
    }
    _syncHeartbeatTransport();
  }

  void startHeartbeat() {
    if (_disposed) {
      return;
    }
    _heartbeatWanted = true;
    _syncHeartbeatTransport();
  }

  void stopHeartbeat() {
    _heartbeatWanted = false;
    _stopHttpHeartbeatTimer();
  }

  void _syncHeartbeatTransport() {
    if (_disposed || !_heartbeatWanted) {
      _stopHttpHeartbeatTimer();
      return;
    }
    final tcpReady = FriendRealtimeService.instance.isRealtimeReady;
    if (!PresenceKeepAlivePolicy.shouldSendHttpHeartbeat(tcpReady: tcpReady)) {
      _stopHttpHeartbeatTimer();
      return;
    }
    if (_heartbeatRunning) {
      return;
    }
    _heartbeatRunning = true;
    _sendHeartbeat();
    _heartbeatTimer = Timer.periodic(
      const Duration(seconds: 30),
      (_) => _sendHeartbeat(),
    );
  }

  void _stopHttpHeartbeatTimer() {
    _heartbeatRunning = false;
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
  }

  Future<void> _sendHeartbeat() async {
    if (_disposed || !_heartbeatWanted) {
      return;
    }
    if (!PresenceKeepAlivePolicy.shouldSendHttpHeartbeat(
      tcpReady: FriendRealtimeService.instance.isRealtimeReady,
    )) {
      _stopHttpHeartbeatTimer();
      return;
    }
    try {
      await PresenceApi.instance.heartbeat();
    } catch (_) {}
  }

  /// 将服务端返回的 lastActiveAt（毫秒）映射为展示文案。
  String lastActiveLabelFromTimestamp(int lastSeenMs) {
    return _mapLastActiveTimestamp(lastSeenMs);
  }

  String _mapLastActiveTimestamp(int lastSeenMs) {
    final i18n = AppI18n.current;
    final diff = DateTime.now().difference(
      DateTime.fromMillisecondsSinceEpoch(lastSeenMs),
    );
    if (diff.inMinutes < 1) {
      return i18n.t(
        zhHans: '刚刚在线',
        zhHant: '剛剛在線',
        en: 'Just online',
        ja: 'たった今オンライン',
        ko: '방금 접속',
      );
    }
    if (diff.inHours < 1) {
      return i18n.format(
        zhHans: '{n}分钟前在线',
        zhHant: '{n}分鐘前在線',
        en: 'Online {n} min ago',
        ja: '{n}分前にオンライン',
        ko: '{n}분 전 접속',
        vars: {'n': '${diff.inMinutes}'},
      );
    }
    if (diff.inDays < 1) {
      return i18n.format(
        zhHans: '{n}小时前在线',
        zhHant: '{n}小時前在線',
        en: 'Online {n} h ago',
        ja: '{n}時間前にオンライン',
        ko: '{n}시간 전 접속',
        vars: {'n': '${diff.inHours}'},
      );
    }
    if (diff.inDays < 3) {
      return i18n.format(
        zhHans: '{n}天前在线',
        zhHant: '{n}天前在線',
        en: 'Online {n} d ago',
        ja: '{n}日前にオンライン',
        ko: '{n}일 전 접속',
        vars: {'n': '${diff.inDays}'},
      );
    }
    if (diff.inDays < 7) {
      return i18n.t(
        zhHans: '一周内曾上线',
        zhHant: '一週內曾上線',
        en: 'Online within a week',
        ja: '1週間以内にオンライン',
        ko: '일주일 내 접속',
      );
    }
    if (diff.inDays < 30) {
      return i18n.t(
        zhHans: '一月内曾上线',
        zhHant: '一月內曾上線',
        en: 'Online within a month',
        ja: '1ヶ月以内にオンライン',
        ko: '한 달 내 접속',
      );
    }
    return i18n.t(
      zhHans: '很久未上线',
      zhHant: '很久未上線',
      en: 'Offline for a long time',
      ja: '長い間オフライン',
      ko: '오래전에 접속',
    );
  }

  /// hidden 隐私：7 天内 / 一月内 / 很久未上线 三档粗粒度文案。
  String hiddenLastActiveLabelFromTimestamp(int lastSeenMs) {
    return presenceBucketLabel(imOnline: false, lastSeenMs: lastSeenMs);
  }

  String preciseLastActiveLabel(int lastSeenMs) =>
      lastActiveLabelFromTimestamp(lastSeenMs);

  String _presenceLabelForUser({
    required String id,
    required bool imOnline,
    required bool isMutualFriend,
    int? lastActiveAtOverride,
  }) {
    if (_isSelfUser(id)) {
      return presenceBucketLabel(imOnline: true, lastSeenMs: null);
    }
    if (!shouldShowPresenceLabel(id, isMutualFriend: isMutualFriend)) {
      return '';
    }
    final hidden = _isHiddenPresence(id);
    if (!hidden &&
        resolveOnline(userId: id, imOnline: imOnline)) {
      return presenceBucketLabel(imOnline: true, lastSeenMs: null);
    }
    final lastSeen = lastActiveAtOverride ?? _lookupLastSeen(id);
    if (lastSeen != null) {
      if (hidden) {
        return hiddenLastActiveLabelFromTimestamp(lastSeen);
      }
      return lastActiveLabelFromTimestamp(lastSeen);
    }
    if (!hasFetchedLastSeen(id)) {
      return '';
    }
    return presenceBucketLabel(imOnline: false, lastSeenMs: null);
  }

  /// 分档展示：在线 / 最近曾上线（7 天内）/ 一月内 / 很久未上线。
  String presenceBucketLabel({
    required bool imOnline,
    int? lastSeenMs,
  }) {
    final i18n = AppI18n.current;
    if (imOnline) {
      return i18n.t(
        zhHans: '在线',
        zhHant: '在線',
        en: 'Online',
        ja: 'オンライン',
        ko: '온라인',
      );
    }
    if (lastSeenMs == null) {
      return i18n.t(
        zhHans: '很久未上线',
        zhHant: '很久未上線',
        en: 'Offline for a long time',
        ja: '長い間オフライン',
        ko: '오래전에 접속',
      );
    }

    final diff = DateTime.now().difference(
      DateTime.fromMillisecondsSinceEpoch(lastSeenMs),
    );
    if (diff < const Duration(days: 7)) {
      return i18n.t(
        zhHans: '最近曾上线',
        zhHant: '最近曾上線',
        en: 'Recently online',
        ja: '最近オンライン',
        ko: '최근 접속',
      );
    }
    if (diff < const Duration(days: 30)) {
      return i18n.t(
        zhHans: '一个月内曾上线',
        zhHant: '一個月內曾上線',
        en: 'Online within a month',
        ja: '1ヶ月以内にオンライン',
        ko: '한 달 내 접속',
      );
    }
    return i18n.t(
      zhHans: '很久未上线',
      zhHant: '很久未上線',
      en: 'Offline for a long time',
      ja: '長い間オフライン',
      ko: '오래전에 접속',
    );
  }

  bool _isSelfUser(String userId) {
    final id = ChatIdFormat.rawUserUid(userId);
    if (id.isEmpty) {
      return false;
    }
    final selfId = ChatIdFormat.rawUserUid(
      serviceLocator<TUISelfInfoViewModel>().loginInfo?.userID,
    );
    return selfId.isNotEmpty && id == selfId;
  }

  String labelFor({
    required String userId,
    required bool imOnline,
    bool isMutualFriend = false,
    int? lastActiveAtOverride,
  }) {
    final id = ChatIdFormat.rawUserUid(userId);
    if (id.isEmpty) {
      return '';
    }
    return _presenceLabelForUser(
      id: id,
      imOnline: imOnline,
      isMutualFriend: isMutualFriend,
      lastActiveAtOverride: lastActiveAtOverride,
    );
  }

  /// 聊天页头部副标题：对方允许查看在线时优先展示「在线」，否则映射 lastActiveAt。
  String chatHeaderLabelFor({
    required String userId,
    required bool imOnline,
    bool isMutualFriend = false,
    int? lastActiveAtOverride,
  }) {
    final id = ChatIdFormat.rawUserUid(userId);
    if (id.isEmpty || _isSelfUser(id)) {
      return '';
    }
    return _presenceLabelForUser(
      id: id,
      imOnline: imOnline,
      isMutualFriend: isMutualFriend,
      lastActiveAtOverride: lastActiveAtOverride,
    );
  }

  /// 用于联系人/群成员列表（与 [labelFor] 分档规则一致）。
  String onlineLabelFor({
    required String userId,
    required bool imOnline,
    bool isMutualFriend = false,
    int? lastActiveAtOverride,
  }) {
    return labelFor(
      userId: userId,
      imOnline: imOnline,
      isMutualFriend: isMutualFriend,
      lastActiveAtOverride: lastActiveAtOverride,
    );
  }

  /// 列表副标题：优先用已缓存/接口返回的 lastActiveAt 映射文案。
  String listLabelFor({
    required String userId,
    required bool imOnline,
    bool isMutualFriend = false,
    int? lastActiveAtOverride,
  }) {
    return labelFor(
      userId: userId,
      imOnline: imOnline,
      isMutualFriend: isMutualFriend,
      lastActiveAtOverride: lastActiveAtOverride,
    );
  }

  static void clearActiveSessionState() {
    activeInstance?.clearSessionState();
  }

  void clearSessionState() {
    _lastSeen.clear();
    _lastFetchAt.clear();
    _lastActiveVisibility.clear();
    _visibilityFromApi.clear();
    _visibilityFetchAt.clear();
    _visibilityInFlight.clear();
    _backendOnlineUntil.clear();
    _pending.clear();
    _inFlight.clear();
    _hydratedFromLocalCache = false;
    _activeScope = null;
    _notifySafely();
  }

  @override
  void dispose() {
    if (activeInstance == this) {
      activeInstance = null;
    }
    FriendRealtimeService.instance.removeReadyListener(_onRealtimeReady);
    _disposed = true;
    _heartbeatWanted = false;
    _ageTimer?.cancel();
    _flushTimer?.cancel();
    _heartbeatTimer?.cancel();
    super.dispose();
  }
}
