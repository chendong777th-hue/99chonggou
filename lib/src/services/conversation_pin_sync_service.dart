import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tencent_cloud_chat_demo/src/api/conversation_pin_api.dart';
import 'package:tencent_cloud_chat_demo/src/services/contact_social_cache_store.dart';
import 'package:tencent_cloud_chat_demo/src/services/conversation_local/conversation_list_notifier.dart';
import 'package:tencent_cloud_chat_demo/src/services/conversation_local/conversation_local_store.dart';
import 'package:tencent_cloud_chat_demo/src/services/conversation_local/conversation_perf_flags.dart';
import 'package:tencent_cloud_chat_demo/src/services/conversation_local/conversation_sync_service.dart';
import 'package:tencent_cloud_chat_demo/src/services/conversation_pin_flicker_log.dart';
import 'package:tencent_cloud_chat_demo/src/services/conversation_refresh_bus.dart';
import 'package:tencent_cloud_chat_demo/src/services/friend_realtime/friend_realtime_event.dart';
import 'package:tencent_cloud_chat_demo/src/services/session_identity.dart';
import 'package:tencent_cloud_chat_demo/src/utils/archived_conversation_ref.dart';
import 'package:tencent_cloud_chat_demo/src/utils/message_conversation_id.dart';
import 'package:tencent_cloud_chat_demo/utils/chat_id_format.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_callback.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_callback.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_conversation.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_conversation.dart';
import 'package:tencent_cloud_chat_sdk/tencent_im_sdk_plugin.dart';

class ConversationPinApplyResult {
  const ConversationPinApplyResult({
    required this.applied,
    required this.isPinned,
    this.sdkOk = false,
  });

  final bool applied;
  final bool isPinned;

  /// 腾讯 `pinConversation` 是否成功；仅自建路径时与 [applied] 同义。
  final bool sdkOk;
}

/// 会话置顶同步。
///
/// 默认「腾讯为主、自建跟写」：UI/本地集合以腾讯 pin 为准，自建仅跟写与迁移参考。
/// [ConversationPerfFlags.conversationPinTencentPrimary]==false 时回退旧「只信自建」。
class ConversationPinSyncService {
  ConversationPinSyncService._();

  static final ConversationPinSyncService instance =
      ConversationPinSyncService._();

  static const _cachePrefix = 'pinned_conversations_v1_';
  static const _sourceGatePrefix = 'pinned_source_backend_v1_';
  static const String _guestScope = '_guest';
  static const Duration _loginSyncCooldown = Duration(minutes: 2);
  static const Duration _localWriteAuthorityTtl = Duration(seconds: 3);
  static const Duration _migratePinGap = Duration(milliseconds: 50);
  static const int _tencentPinListPageSize = 100;
  static const int _tencentPinListMaxPages = 20;

  final Set<String> _pinnedConversationIds = <String>{};
  int _setUpdatedAtMs = 0;
  int _localWriteAuthorityUntilMs = 0;
  int _localWriteAuthorityMinUpdatedAtMs = 0;
  bool _isHydrated = false;

  DateTime? _lastLoginSyncAt;
  SessionIdentity? _lastLoginSyncIdentity;
  SessionIdentity? _loginSyncIdentity;
  Future<void>? _loginSyncInFlight;
  SessionIdentity? _refreshIdentity;
  Future<void>? _refreshInFlight;
  SessionIdentity? _tencentReconcileIdentity;
  Future<void>? _tencentReconcileInFlight;

  /// 单测注入：返回 `true` 表示腾讯置顶成功。
  @visibleForTesting
  static Future<bool> Function(String conversationID, bool isPinned)?
      debugPinConversationOverride;

  /// 单测注入：返回腾讯当前置顶 conversationID 集合。
  @visibleForTesting
  static Future<Set<String>> Function()? debugCollectTencentPinnedIdsOverride;

  /// 单测注入账号 scope（非空时跳过 `_guest` 门闩）。
  @visibleForTesting
  static String? debugAccountScopeOverride;

  /// 单测：跳过 prefs / SQLite / UI 刷新，只改内存集合。
  @visibleForTesting
  static bool debugSkipPersistAndUiForTest = false;

  /// 单测注入自建跟写；为 null 时走真实 API。
  @visibleForTesting
  static Future<void> Function({
    required String chatType,
    required String peerId,
    required bool pinned,
  })? debugFollowWriteOverride;

  Set<String> get pinnedConversationIds =>
      Set<String>.unmodifiable(_pinnedConversationIds);

  /// Whether the in-memory pin set has been hydrated from cache/SDK.
  /// When false, callers should not overwrite `isPinned` on conversation
  /// objects loaded from SQLite — the DB column is the only authority.
  bool get isHydrated => _isHydrated;

  /// Removes a conversation that no longer exists (for example after leaving
  /// or dissolving a group) from every local pin projection.
  Future<void> removeDeletedConversation(String conversationID) async {
    final identity = _captureIdentity();
    if (!_hasAccountScopedIdentity(identity)) return;
    final id = conversationID.trim();
    if (id.isEmpty) return;
    final hadMatch = _pinnedConversationIds.any(
      (pinned) => MessageConversationId.sameConversation(pinned, id),
    );
    if (!hadMatch) return;
    final previous = Set<String>.from(_pinnedConversationIds);
    _pinnedConversationIds.removeWhere(
      (pinned) => MessageConversationId.sameConversation(pinned, id),
    );
    await ConversationSyncService.instance.reconcileConversationPinSetLocally(
      previousPinnedConversationIds: previous,
      pinnedConversationIds: _pinnedConversationIds,
    );
    await _persistCache(identity);
  }

  int get setUpdatedAtMs => _setUpdatedAtMs;

  bool isPinnedConversationId(String? conversationID) {
    final id = conversationID?.trim() ?? '';
    if (id.isEmpty || _pinnedConversationIds.isEmpty) {
      return false;
    }
    if (_pinnedConversationIds.contains(id)) {
      return true;
    }
    for (final pinned in _pinnedConversationIds) {
      if (MessageConversationId.sameConversation(pinned, id)) {
        return true;
      }
    }
    return false;
  }

  /// 冷启动 / 登录：只读本地 prefs→内存→SQLite 标志，不上网。
  ///
  /// IM `loginInfo` 未就绪（scope=`_guest`）时 no-op，避免多账号串写。
  Future<void> hydrateLocalAndApplyUi({
    bool reloadUi = true,
    SessionIdentity? expectedIdentity,
  }) async {
    final identity = expectedIdentity ?? _captureIdentity();
    if (!_hasAccountScopedIdentity(identity)) {
      ConversationPinFlickerLog.log(
        'pin_local_hydrate_skip_guest',
        extras: <String, Object?>{
          'scope': _prefsScope(identity),
        },
      );
      return;
    }
    try {
      await _ensureBackendSourceGate(identity);
      if (!_isCurrent(identity)) return;
      await _hydrateFromCache(identity, reloadUi: reloadUi);
      if (!_isCurrent(identity)) return;
      _isHydrated = true;
      ConversationPinFlickerLog.log(
        'pin_local_hydrate',
        extras: <String, Object?>{
          'count': _pinnedConversationIds.length,
          'scope': _prefsScope(identity),
          'updatedAt': _setUpdatedAtMs,
          'tencentPrimary': ConversationPerfFlags.conversationPinTencentPrimary,
        },
      );
    } catch (e, st) {
      debugPrint('ConversationPinSync: local hydrate failed: $e\n$st');
      ConversationPinFlickerLog.log(
        'pin_local_hydrate_fail',
        extras: <String, Object?>{'error': '$e'},
      );
    }
  }

  Future<void> syncOnLogin({bool force = false}) {
    final identity = _captureIdentity();
    if (!_hasAccountScopedIdentity(identity)) return Future<void>.value();
    if (!force &&
        _lastLoginSyncIdentity == identity &&
        _lastLoginSyncAt != null &&
        DateTime.now().difference(_lastLoginSyncAt!) < _loginSyncCooldown) {
      return Future<void>.value();
    }
    final running = _loginSyncInFlight;
    if (running != null && _loginSyncIdentity == identity) return running;
    late final Future<void> task;
    task = _syncOnLogin(force: force, identity: identity).whenComplete(() {
      if (identical(_loginSyncInFlight, task)) {
        _loginSyncInFlight = null;
        _loginSyncIdentity = null;
      }
    });
    _loginSyncIdentity = identity;
    _loginSyncInFlight = task;
    return task;
  }

  Future<void> _syncOnLogin({
    required bool force,
    required SessionIdentity identity,
  }) async {
    try {
      await hydrateLocalAndApplyUi(expectedIdentity: identity);
      if (!_isCurrent(identity)) return;
      if (ConversationPerfFlags.conversationPinTencentPrimary) {
        await _syncOnLoginTencentPrimary(identity);
      } else {
        await refreshFromServer(expectedIdentity: identity);
      }
      if (!_isCurrent(identity)) return;
      _lastLoginSyncAt = DateTime.now();
      _lastLoginSyncIdentity = identity;
    } catch (e, st) {
      // 失败保留本地水合结果，不清空集合。
      debugPrint('ConversationPinSync: login sync failed: $e\n$st');
      if (force) {
        rethrow;
      }
    }
  }

  Future<void> _syncOnLoginTencentPrimary(SessionIdentity identity) async {
    List<ConversationPinItem> backendItems = const <ConversationPinItem>[];
    try {
      final page = await ConversationPinApi.instance.fetchAll();
      if (!_isCurrent(identity)) return;
      backendItems = page.items;
    } catch (e, st) {
      debugPrint(
        'ConversationPinSync: backend fetch for migrate failed: $e\n$st',
      );
      ConversationPinFlickerLog.log(
        'pin_login_backend_fetch_fail',
        extras: <String, Object?>{'error': '$e'},
      );
    }

    final tencentIds = await collectTencentPinnedConversationIds(
      expectedIdentity: identity,
    );
    if (!_isCurrent(identity)) return;
    final updatedAt = DateTime.now().toUtc().millisecondsSinceEpoch;
    await _applyItems(
      _itemsFromConversationIds(tencentIds),
      updatedAtMs: updatedAt,
      identity: identity,
    );
    ConversationPinFlickerLog.log(
      'pin_login_tencent_truth',
      extras: <String, Object?>{
        'tencentCount': tencentIds.length,
        'backendCount': backendItems.length,
      },
    );

    var merged = Set<String>.from(tencentIds);
    if (ConversationPerfFlags.conversationPinMigrateBackendToTencentOnLogin &&
        backendItems.isNotEmpty) {
      merged = await _migrateBackendPinsToTencent(
        backendItems: backendItems,
        alreadyPinned: merged,
        identity: identity,
      );
      if (!_sameIdSet(merged, tencentIds)) {
        await _applyItems(
          _itemsFromConversationIds(merged),
          updatedAtMs: DateTime.now().toUtc().millisecondsSinceEpoch,
          identity: identity,
        );
      }
    }

    if (ConversationPerfFlags.conversationPinFollowWriteBackend) {
      await _followWriteFullSetToBackend(
        merged,
        expectedIdentity: identity,
      );
    }
  }

  Future<Set<String>> _migrateBackendPinsToTencent({
    required List<ConversationPinItem> backendItems,
    required Set<String> alreadyPinned,
    required SessionIdentity identity,
  }) async {
    final next = Set<String>.from(alreadyPinned);
    var migrated = 0;
    var failed = 0;
    for (final item in backendItems) {
      final ref = ArchivedConversationRef(
        chatType: item.chatType,
        peerId: item.chatType == 'group'
            ? ChatIdFormat.canonicalGroupStorageId(item.peerId)
            : ChatIdFormat.rawUserUid(item.peerId),
      );
      if (ref.peerId.isEmpty) {
        continue;
      }
      final id = ref.conversationId;
      if (_setContainsConversation(next, id)) {
        continue;
      }
      final ok = await _pinConversationOnTencent(id, true);
      if (!_isCurrent(identity)) return next;
      if (ok) {
        next.add(id);
        migrated++;
      } else {
        failed++;
      }
      if (_migratePinGap > Duration.zero) {
        await Future<void>.delayed(_migratePinGap);
      }
    }
    ConversationPinFlickerLog.log(
      'pin_login_migrate_done',
      extras: <String, Object?>{
        'migrated': migrated,
        'failed': failed,
        'finalCount': next.length,
      },
    );
    return next;
  }

  /// 拉取腾讯当前置顶会话 ID（置顶在列表头部，遇首条非置顶可提前结束）。
  ///
  /// 例外：此处仍可用混流 `getConversationList` 扫 `isPinned`（日志可见
  /// `conversation_type:unknown`）。**禁止**在本路径写入
  /// [ConversationLocalStore] sync meta / `setHasSyncedOnce`——会话灌库游标
  /// 只允许 ByFilter typed 路径推进。
  Future<Set<String>> collectTencentPinnedConversationIds({
    SessionIdentity? expectedIdentity,
  }) async {
    final identity = expectedIdentity ?? _captureIdentity();
    if (!_hasAccountScopedIdentity(identity)) return <String>{};
    final override = debugCollectTencentPinnedIdsOverride;
    if (override != null) {
      return override();
    }
    final pinned = <String>{};
    var nextSeq = '0';
    for (var page = 0; page < _tencentPinListMaxPages; page++) {
      final res = await TencentImSDKPlugin.v2TIMManager
          .getConversationManager()
          .getConversationList(
            nextSeq: nextSeq,
            count: _tencentPinListPageSize,
          );
      if (!_isCurrent(identity)) return <String>{};
      if (res.code != 0) {
        ConversationPinFlickerLog.log(
          'pin_tencent_list_fail',
          extras: <String, Object?>{
            'code': res.code,
            'desc': res.desc,
            'page': page,
          },
        );
        break;
      }
      final data = res.data;
      final list = data?.conversationList ?? const <V2TimConversation>[];
      var hitUnpinned = false;
      for (final conversation in list) {
        final id = conversation.conversationID.trim();
        if (id.isEmpty) {
          continue;
        }
        if (conversation.isPinned == true) {
          pinned.add(id);
        } else {
          hitUnpinned = true;
          break;
        }
      }
      final finished = data?.isFinished == true;
      final seq = data?.nextSeq?.toString() ?? '';
      if (hitUnpinned ||
          finished ||
          seq.isEmpty ||
          seq == '0' ||
          seq == nextSeq) {
        break;
      }
      nextSeq = seq;
    }
    return pinned;
  }

  /// REST / 本地应用。腾讯为主时：先 IM，成功后再改本地；自建跟写失败不回滚。
  Future<ConversationPinApplyResult> setPinned({
    required V2TimConversation conversation,
    required bool pinned,
    String source = 'unknown',
    double? listScrollOffset,
  }) async {
    final identity = _captureIdentity();
    if (!_hasAccountScopedIdentity(identity)) {
      return ConversationPinApplyResult(
        applied: false,
        isPinned: conversation.isPinned ?? false,
        sdkOk: false,
      );
    }
    final ref = ArchivedConversationRef.fromConversation(conversation);
    if (ref == null) {
      return ConversationPinApplyResult(
        applied: false,
        isPinned: conversation.isPinned ?? false,
        sdkOk: false,
      );
    }
    final prevPinned = isPinnedConversationId(conversation.conversationID);
    if (prevPinned == pinned) {
      return ConversationPinApplyResult(
        applied: true,
        isPinned: pinned,
        sdkOk: true,
      );
    }

    if (ConversationPerfFlags.conversationPinTencentPrimary) {
      return _setPinnedTencentPrimary(
        conversation: conversation,
        ref: ref,
        pinned: pinned,
        prevPinned: prevPinned,
        source: source,
        listScrollOffset: listScrollOffset,
        identity: identity,
      );
    }
    return _setPinnedBackendPrimary(
      conversation: conversation,
      ref: ref,
      pinned: pinned,
      prevPinned: prevPinned,
      source: source,
      listScrollOffset: listScrollOffset,
      identity: identity,
    );
  }

  Future<ConversationPinApplyResult> _setPinnedTencentPrimary({
    required V2TimConversation conversation,
    required ArchivedConversationRef ref,
    required bool pinned,
    required bool prevPinned,
    required String source,
    required SessionIdentity identity,
    double? listScrollOffset,
  }) async {
    if (!_isCurrent(identity)) {
      return ConversationPinApplyResult(
        applied: false,
        isPinned: prevPinned,
        sdkOk: false,
      );
    }
    final conversationID = conversation.conversationID.trim();
    ConversationPinFlickerLog.log(
      'pin_tencent_start',
      conversationID: conversationID,
      extras: <String, Object?>{
        'source': source,
        'nextPinned': pinned,
        'prevPinned': prevPinned,
      },
    );

    final previousPinnedIds = Set<String>.from(_pinnedConversationIds);
    final previousUpdatedAt = _setUpdatedAtMs;
    final optimistic = ConversationPerfFlags.pinOptimisticUiEnabled &&
        !debugSkipPersistAndUiForTest;
    if (optimistic) {
      // 072 phase-6 allowlist: pending-only projection before Tencent ACK;
      // SDK failure restores the confirmed pin snapshot below.
      final updatedAt = DateTime.now().toUtc().millisecondsSinceEpoch;
      _armLocalWriteAuthority(updatedAt);
      // 先按当前集合算目标 items，再写入内存（勿在已改集合上二次 mutation）。
      final optimisticItems =
          _itemsAfterLocalMutation(ref: ref, pinned: pinned);
      final nextIds = <String>{};
      for (final item in optimisticItems) {
        final itemRef = ArchivedConversationRef(
          chatType: item.chatType,
          peerId: item.chatType == 'group'
              ? ChatIdFormat.canonicalGroupStorageId(item.peerId)
              : ChatIdFormat.rawUserUid(item.peerId),
        );
        if (itemRef.peerId.isNotEmpty) {
          nextIds.add(itemRef.conversationId);
        }
      }
      _pinnedConversationIds
        ..clear()
        ..addAll(nextIds);
      _setUpdatedAtMs = updatedAt;
      ConversationListNotifier.instance.applyPinnedWithDeferredReorder(
        conversationID: conversationID,
        isPinned: pinned,
        snapshot: conversation,
        listScrollOffset: listScrollOffset,
      );
      ConversationPinFlickerLog.log(
        'pin_phase_optimistic',
        conversationID: conversationID,
        extras: <String, Object?>{
          'source': source,
          'nextPinned': pinned,
        },
      );
    }

    final sdkOk = await _pinConversationOnTencent(conversationID, pinned);
    if (!_isCurrent(identity)) {
      return ConversationPinApplyResult(
        applied: false,
        isPinned: prevPinned,
        sdkOk: false,
      );
    }
    if (!sdkOk) {
      if (optimistic) {
        _pinnedConversationIds
          ..clear()
          ..addAll(previousPinnedIds);
        _setUpdatedAtMs = previousUpdatedAt;
        ConversationListNotifier.instance.applyPinnedWithDeferredReorder(
          conversationID: conversationID,
          isPinned: prevPinned,
          snapshot: conversation,
          listScrollOffset: listScrollOffset,
        );
        ConversationPinFlickerLog.log(
          'pin_phase_rollback',
          conversationID: conversationID,
          extras: <String, Object?>{'source': source},
        );
      }
      ConversationPinFlickerLog.log(
        'pin_tencent_fail',
        conversationID: conversationID,
        extras: <String, Object?>{'source': source},
      );
      return ConversationPinApplyResult(
        applied: false,
        isPinned: prevPinned,
        sdkOk: false,
      );
    }

    final updatedAt = DateTime.now().toUtc().millisecondsSinceEpoch;
    _armLocalWriteAuthority(updatedAt);
    final items = _itemsAfterLocalMutation(ref: ref, pinned: pinned);
    await _applyItems(
      items,
      updatedAtMs: updatedAt,
      listScrollOffset: listScrollOffset,
      changedConversationId: conversationID,
      changedPinned: pinned,
      snapshot: conversation,
      identity: identity,
    );
    if (!_isCurrent(identity)) {
      return ConversationPinApplyResult(
        applied: false,
        isPinned: prevPinned,
        sdkOk: false,
      );
    }

    if (ConversationPerfFlags.conversationPinFollowWriteBackend) {
      // 本地 UI 已更新；跟写失败只记日志，不回滚腾讯/本地。
      await _followWriteSingleToBackend(
        ref: ref,
        pinned: pinned,
        source: source,
        conversationID: conversationID,
        identity: identity,
      );
    }

    ConversationPinFlickerLog.log(
      'pin_tencent_ok',
      conversationID: conversationID,
      extras: <String, Object?>{
        'source': source,
        'pinned': pinned,
        'count': _pinnedConversationIds.length,
        'followWrite': ConversationPerfFlags.conversationPinFollowWriteBackend,
      },
    );
    return ConversationPinApplyResult(
      applied: true,
      isPinned: pinned,
      sdkOk: true,
    );
  }

  Future<ConversationPinApplyResult> _setPinnedBackendPrimary({
    required V2TimConversation conversation,
    required ArchivedConversationRef ref,
    required bool pinned,
    required bool prevPinned,
    required String source,
    required SessionIdentity identity,
    double? listScrollOffset,
  }) async {
    ConversationPinFlickerLog.log(
      'pin_backend_start',
      conversationID: conversation.conversationID,
      extras: <String, Object?>{
        'source': source,
        'nextPinned': pinned,
        'prevPinned': prevPinned,
      },
    );

    try {
      final result = await ConversationPinApi.instance.setPinned(
        chatType: ref.chatType,
        peerId: ref.peerId,
        pinned: pinned,
      );
      if (!_isCurrent(identity)) {
        return ConversationPinApplyResult(
          applied: false,
          isPinned: prevPinned,
          sdkOk: false,
        );
      }
      if (!result.ok && result.items.isEmpty) {
        return ConversationPinApplyResult(
          applied: false,
          isPinned: prevPinned,
          sdkOk: false,
        );
      }

      final updatedAt =
          result.updatedAt ?? DateTime.now().toUtc().millisecondsSinceEpoch;
      _armLocalWriteAuthority(updatedAt);
      if (result.items.isNotEmpty || result.ok) {
        final items = result.items.isNotEmpty
            ? result.items
            : _itemsAfterLocalMutation(ref: ref, pinned: pinned);
        await _applyItems(
          items,
          updatedAtMs: updatedAt,
          listScrollOffset: listScrollOffset,
          changedConversationId: conversation.conversationID.trim(),
          changedPinned: pinned,
          snapshot: conversation,
          identity: identity,
        );
        if (!_isCurrent(identity)) {
          return ConversationPinApplyResult(
            applied: false,
            isPinned: prevPinned,
            sdkOk: false,
          );
        }
      }

      ConversationPinFlickerLog.log(
        'pin_backend_ok',
        conversationID: conversation.conversationID,
        extras: <String, Object?>{
          'source': source,
          'pinned': pinned,
          'count': _pinnedConversationIds.length,
        },
      );
      return ConversationPinApplyResult(
        applied: true,
        isPinned: pinned,
        sdkOk: true,
      );
    } on ConversationPinLimitExceededException catch (e) {
      ConversationPinFlickerLog.log(
        'pin_backend_limit',
        conversationID: conversation.conversationID,
        extras: <String, Object?>{'source': source, 'error': '$e'},
      );
      rethrow;
    } catch (e, st) {
      debugPrint('ConversationPinSync: setPinned failed: $e\n$st');
      ConversationPinFlickerLog.log(
        'pin_backend_fail',
        conversationID: conversation.conversationID,
        extras: <String, Object?>{'source': source, 'error': '$e'},
      );
      return ConversationPinApplyResult(
        applied: false,
        isPinned: prevPinned,
        sdkOk: false,
      );
    }
  }

  Future<void> _followWriteSingleToBackend({
    required ArchivedConversationRef ref,
    required bool pinned,
    required String source,
    required String conversationID,
    required SessionIdentity identity,
  }) async {
    if (!_isCurrent(identity)) return;
    try {
      final override = debugFollowWriteOverride;
      if (override != null) {
        await override(
          chatType: ref.chatType,
          peerId: ref.peerId,
          pinned: pinned,
        );
      } else {
        await ConversationPinApi.instance.setPinned(
          chatType: ref.chatType,
          peerId: ref.peerId,
          pinned: pinned,
        );
      }
      if (!_isCurrent(identity)) return;
      ConversationPinFlickerLog.log(
        'pin_follow_write_ok',
        conversationID: conversationID,
        extras: <String, Object?>{
          'source': source,
          'pinned': pinned,
        },
      );
    } catch (e, st) {
      debugPrint(
        'ConversationPinSync: follow-write backend failed: $e\n$st',
      );
      ConversationPinFlickerLog.log(
        'pin_follow_write_fail',
        conversationID: conversationID,
        extras: <String, Object?>{
          'source': source,
          'pinned': pinned,
          'error': '$e',
        },
      );
    }
  }

  Future<void> _followWriteFullSetToBackend(
    Set<String> desiredIds, {
    SessionIdentity? expectedIdentity,
  }) async {
    final identity = expectedIdentity ?? _captureIdentity();
    if (!_hasAccountScopedIdentity(identity)) return;
    try {
      final page = await ConversationPinApi.instance.fetchAll();
      if (!_isCurrent(identity)) return;
      final backendIds = <String>{};
      for (final item in page.items) {
        final ref = ArchivedConversationRef(
          chatType: item.chatType,
          peerId: item.chatType == 'group'
              ? ChatIdFormat.canonicalGroupStorageId(item.peerId)
              : ChatIdFormat.rawUserUid(item.peerId),
        );
        if (ref.peerId.isNotEmpty) {
          backendIds.add(ref.conversationId);
        }
      }

      final toAdd = <ConversationPinItem>[];
      for (final id in desiredIds) {
        if (_setContainsConversation(backendIds, id)) {
          continue;
        }
        final item = _itemFromConversationId(id);
        if (item != null) {
          toAdd.add(item);
        }
      }
      final toRemove = <ConversationPinItem>[];
      for (final id in backendIds) {
        if (_setContainsConversation(desiredIds, id)) {
          continue;
        }
        final item = _itemFromConversationId(id);
        if (item != null) {
          toRemove.add(item);
        }
      }

      if (toAdd.isNotEmpty) {
        await ConversationPinApi.instance.batchSetPinned(toAdd, pinned: true);
        if (!_isCurrent(identity)) return;
      }
      if (toRemove.isNotEmpty) {
        await ConversationPinApi.instance
            .batchSetPinned(toRemove, pinned: false);
        if (!_isCurrent(identity)) return;
      }
      ConversationPinFlickerLog.log(
        'pin_follow_write_full_ok',
        extras: <String, Object?>{
          'desired': desiredIds.length,
          'added': toAdd.length,
          'removed': toRemove.length,
        },
      );
    } catch (e, st) {
      debugPrint(
        'ConversationPinSync: follow-write full set failed: $e\n$st',
      );
      ConversationPinFlickerLog.log(
        'pin_follow_write_full_fail',
        extras: <String, Object?>{'error': '$e'},
      );
    }
  }

  List<ConversationPinItem> _itemsAfterLocalMutation({
    required ArchivedConversationRef ref,
    required bool pinned,
  }) {
    final ids = Set<String>.from(_pinnedConversationIds);
    if (pinned) {
      ids.add(ref.conversationId);
    } else {
      ids.removeWhere(
        (id) => MessageConversationId.sameConversation(id, ref.conversationId),
      );
    }
    return _itemsFromConversationIds(ids);
  }

  List<ConversationPinItem> _itemsFromConversationIds(Iterable<String> ids) {
    return ids
        .map(_itemFromConversationId)
        .whereType<ConversationPinItem>()
        .toList(growable: false);
  }

  ConversationPinItem? _itemFromConversationId(String conversationId) {
    final parsed = ArchivedConversationRef.fromConversationId(conversationId);
    if (parsed == null) {
      return null;
    }
    return ConversationPinItem(
      chatType: parsed.chatType,
      peerId: parsed.peerId,
    );
  }

  Future<void> handleRealtimeEvent(FriendRealtimeEvent event) async {
    final identity = _captureIdentity();
    if (!_hasAccountScopedIdentity(identity)) return;
    if (event.event.trim() != 'conversation_pin_changed') {
      return;
    }

    // 腾讯为主：自建推送不得直接盖 UI；触发轻量腾讯对账。
    if (ConversationPerfFlags.conversationPinTencentPrimary) {
      ConversationPinFlickerLog.log(
        'pin_remote_deferred_to_tencent',
        extras: <String, Object?>{
          'remoteUpdatedAt': event.pinUpdatedAt ?? 0,
        },
      );
      unawaited(reconcileFromTencent(reason: 'conversation_pin_remote'));
      return;
    }

    final remoteUpdatedAt = event.pinUpdatedAt ?? 0;
    // sendToUser 可能把 echo 推回操作端：本端刚写成功后的短窗口直接忽略。
    if (_shouldIgnoreRemoteEchoOrStale(remoteUpdatedAt)) {
      ConversationPinFlickerLog.log(
        'pin_remote_ignored_echo_or_stale',
        extras: <String, Object?>{
          'remoteUpdatedAt': remoteUpdatedAt,
          'authorityUntil': _localWriteAuthorityUntilMs,
          'minUpdatedAt': _localWriteAuthorityMinUpdatedAtMs,
          'localSetUpdatedAt': _setUpdatedAtMs,
        },
      );
      return;
    }

    final items = event.pinItems;
    if (items != null) {
      await _applyItems(
        items,
        updatedAtMs: remoteUpdatedAt > 0
            ? remoteUpdatedAt
            : DateTime.now().toUtc().millisecondsSinceEpoch,
        identity: identity,
      );
      if (!_isCurrent(identity)) return;
      ConversationRefreshBus.instance.requestRefresh(
        reason: 'conversation_pin_remote',
      );
      return;
    }

    await refreshFromServer(expectedIdentity: identity);
    if (!_isCurrent(identity)) return;
    ConversationRefreshBus.instance.requestRefresh(
      reason: 'conversation_pin_remote_fallback',
    );
  }

  /// 以腾讯当前 pin 集合覆盖本地（不做自建→腾讯迁移）。
  Future<void> reconcileFromTencent({String reason = 'manual'}) {
    final identity = _captureIdentity();
    if (!_hasAccountScopedIdentity(identity)) return Future<void>.value();
    final running = _tencentReconcileInFlight;
    if (running != null && _tencentReconcileIdentity == identity) {
      return running;
    }
    late final Future<void> task;
    task = _reconcileFromTencentCore(
      reason: reason,
      identity: identity,
    ).whenComplete(() {
      if (identical(_tencentReconcileInFlight, task)) {
        _tencentReconcileInFlight = null;
        _tencentReconcileIdentity = null;
      }
    });
    _tencentReconcileIdentity = identity;
    _tencentReconcileInFlight = task;
    return task;
  }

  Future<void> _reconcileFromTencentCore({
    required String reason,
    required SessionIdentity identity,
  }) async {
    if (!_hasAccountScopedIdentity(identity)) {
      return;
    }
    try {
      final ids = await collectTencentPinnedConversationIds(
        expectedIdentity: identity,
      );
      if (!_isCurrent(identity)) return;
      await _applyItems(
        _itemsFromConversationIds(ids),
        updatedAtMs: DateTime.now().toUtc().millisecondsSinceEpoch,
        identity: identity,
      );
      ConversationRefreshBus.instance.requestRefresh(reason: reason);
      ConversationPinFlickerLog.log(
        'pin_tencent_reconcile_ok',
        extras: <String, Object?>{
          'reason': reason,
          'count': ids.length,
        },
      );
    } catch (e, st) {
      debugPrint('ConversationPinSync: tencent reconcile failed: $e\n$st');
      ConversationPinFlickerLog.log(
        'pin_tencent_reconcile_fail',
        extras: <String, Object?>{'reason': reason, 'error': '$e'},
      );
    }
  }

  Future<void> refreshFromServer({SessionIdentity? expectedIdentity}) async {
    if (ConversationPerfFlags.conversationPinTencentPrimary) {
      // 腾讯为主时「服务端刷新」= 腾讯对账；自建仅作跟写目标。
      return reconcileFromTencent(reason: 'refresh_from_server');
    }
    final identity = expectedIdentity ?? _captureIdentity();
    if (!_hasAccountScopedIdentity(identity)) return;
    final running = _refreshInFlight;
    if (running != null && _refreshIdentity == identity) return running;
    late final Future<void> task;
    task = _refreshFromServerCore(identity).whenComplete(() {
      if (identical(_refreshInFlight, task)) {
        _refreshInFlight = null;
        _refreshIdentity = null;
      }
    });
    _refreshIdentity = identity;
    _refreshInFlight = task;
    return task;
  }

  Future<void> _refreshFromServerCore(SessionIdentity identity) async {
    if (!_hasAccountScopedIdentity(identity)) {
      ConversationPinFlickerLog.log(
        'pin_server_refresh_skip_guest',
        extras: <String, Object?>{'scope': _prefsScope(identity)},
      );
      return;
    }
    try {
      final page = await ConversationPinApi.instance.fetchAll();
      if (!_isCurrent(identity)) return;
      final updatedAt = page.updatedAt ??
          page.serverTime ??
          DateTime.now().toUtc().millisecondsSinceEpoch;
      if (_shouldIgnoreRemoteEchoOrStale(updatedAt)) {
        ConversationPinFlickerLog.log(
          'pin_server_refresh_ignored_stale',
          extras: <String, Object?>{
            'remoteUpdatedAt': updatedAt,
            'localSetUpdatedAt': _setUpdatedAtMs,
            'count': page.items.length,
          },
        );
        return;
      }
      await _applyItems(page.items, updatedAtMs: updatedAt, identity: identity);
      ConversationPinFlickerLog.log(
        'pin_server_refresh_ok',
        extras: <String, Object?>{
          'count': _pinnedConversationIds.length,
          'updatedAt': updatedAt,
          'scope': _prefsScope(identity),
        },
      );
    } catch (e, st) {
      // 失败保留本地，不清空。
      debugPrint('ConversationPinSync: server refresh failed: $e\n$st');
      ConversationPinFlickerLog.log(
        'pin_server_refresh_fail',
        extras: <String, Object?>{
          'error': '$e',
          'localCount': _pinnedConversationIds.length,
        },
      );
      rethrow;
    }
  }

  Future<void> _applyItems(
    List<ConversationPinItem> items, {
    required int updatedAtMs,
    double? listScrollOffset,
    String? changedConversationId,
    bool? changedPinned,
    V2TimConversation? snapshot,
    SessionIdentity? identity,
  }) async {
    final capturedIdentity = identity ?? _captureIdentity();
    if (!_hasAccountScopedIdentity(capturedIdentity)) {
      return;
    }
    final next = <String>{};
    for (final item in items) {
      final ref = ArchivedConversationRef(
        chatType: item.chatType,
        peerId: item.chatType == 'group'
            ? ChatIdFormat.canonicalGroupStorageId(item.peerId)
            : ChatIdFormat.rawUserUid(item.peerId),
      );
      if (ref.peerId.isEmpty) {
        continue;
      }
      next.add(ref.conversationId);
    }

    final previous = Set<String>.from(_pinnedConversationIds);
    _pinnedConversationIds
      ..clear()
      ..addAll(next);
    _setUpdatedAtMs = updatedAtMs;
    if (debugSkipPersistAndUiForTest) {
      return;
    }
    await _persistCache(capturedIdentity);
    if (!_isCurrent(capturedIdentity)) return;

    if (changedConversationId != null &&
        changedConversationId.isNotEmpty &&
        changedPinned != null) {
      if (_pinSetChangedOutsideTarget(
        previous: previous,
        next: next,
        targetConversationId: changedConversationId,
      )) {
        await ConversationSyncService.instance
            .reconcileConversationPinSetLocally(
          previousPinnedConversationIds: previous,
          pinnedConversationIds: next,
        );
      }
      await ConversationSyncService.instance.applyConversationPinLocally(
        conversationID: changedConversationId,
        isPinned: changedPinned,
        snapshot: snapshot,
        listScrollOffset: listScrollOffset,
      );
    } else {
      await ConversationSyncService.instance.reconcileConversationPinSetLocally(
        previousPinnedConversationIds: previous,
        pinnedConversationIds: next,
      );
      await ConversationListNotifier.instance.restoreStoreProjection(
        reason: ConversationStoreProjectionReason.pinHydration,
      );
    }
  }

  bool _pinSetChangedOutsideTarget({
    required Set<String> previous,
    required Set<String> next,
    required String targetConversationId,
  }) {
    for (final id in previous) {
      if (MessageConversationId.sameConversation(id, targetConversationId)) {
        continue;
      }
      if (!_setContainsConversation(next, id)) {
        return true;
      }
    }
    for (final id in next) {
      if (MessageConversationId.sameConversation(id, targetConversationId)) {
        continue;
      }
      if (!_setContainsConversation(previous, id)) {
        return true;
      }
    }
    return false;
  }

  Future<void> _ensureBackendSourceGate(SessionIdentity identity) async {
    if (!_hasAccountScopedIdentity(identity)) {
      return;
    }
    // 腾讯为主时不再清掉本地集合（旧 gate 曾为「切自建真相」清空 SDK 残留）。
    if (ConversationPerfFlags.conversationPinTencentPrimary) {
      return;
    }
    final prefs = await SharedPreferences.getInstance();
    if (!_isCurrent(identity)) return;
    final key = '$_sourceGatePrefix${_prefsScope(identity)}';
    if (prefs.getBool(key) == true) {
      return;
    }
    final previous = Set<String>.from(_pinnedConversationIds);
    _pinnedConversationIds.clear();
    _setUpdatedAtMs = 0;
    await ConversationSyncService.instance.reconcileConversationPinSetLocally(
      previousPinnedConversationIds: previous,
      pinnedConversationIds: const <String>{},
    );
    await prefs.setBool(key, true);
    await _persistCache(identity);
  }

  Future<void> _hydrateFromCache(
    SessionIdentity identity, {
    bool reloadUi = true,
  }) async {
    if (!_hasAccountScopedIdentity(identity)) {
      return;
    }
    final prefs = await SharedPreferences.getInstance();
    if (!_isCurrent(identity)) return;
    final raw = prefs.getString('$_cachePrefix${_prefsScope(identity)}');
    if (raw == null || raw.isEmpty) {
      return;
    }
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) {
        return;
      }
      final map = Map<String, dynamic>.from(decoded);
      final ids = <String>{};
      final rawIds = map['ids'];
      if (rawIds is List) {
        for (final entry in rawIds) {
          final id = entry?.toString().trim() ?? '';
          if (id.isNotEmpty) {
            ids.add(id);
          }
        }
      }
      final previous = Set<String>.from(_pinnedConversationIds);
      if (!_isCurrent(identity)) return;
      _pinnedConversationIds
        ..clear()
        ..addAll(ids);
      _setUpdatedAtMs = _asInt(map['updatedAt']) ?? 0;
      await ConversationSyncService.instance.reconcileConversationPinSetLocally(
        previousPinnedConversationIds: previous,
        pinnedConversationIds: ids,
      );
      if (reloadUi) {
        if (!_isCurrent(identity)) return;
        await ConversationListNotifier.instance.restoreStoreProjection(
          reason: ConversationStoreProjectionReason.pinHydration,
        );
      }
    } catch (e, st) {
      debugPrint('ConversationPinSync: cache hydrate failed: $e\n$st');
    }
  }

  Future<void> _persistCache([SessionIdentity? expectedIdentity]) async {
    final identity = expectedIdentity ?? _captureIdentity();
    if (!_hasAccountScopedIdentity(identity)) {
      return;
    }
    final prefs = await SharedPreferences.getInstance();
    if (!_isCurrent(identity)) return;
    final payload = jsonEncode(<String, dynamic>{
      'updatedAt': _setUpdatedAtMs,
      'ids': _pinnedConversationIds.toList(growable: false),
    });
    await prefs.setString('$_cachePrefix${_prefsScope(identity)}', payload);
  }

  void _armLocalWriteAuthority(int updatedAtMs) {
    final now = DateTime.now().millisecondsSinceEpoch;
    _localWriteAuthorityUntilMs = now + _localWriteAuthorityTtl.inMilliseconds;
    _localWriteAuthorityMinUpdatedAtMs = updatedAtMs;
  }

  /// 本端刚 PUT 成功后的短窗口：忽略 TCP echo / 旧快照（sendToUser 可能推回操作端）。
  bool _shouldIgnoreRemoteEchoOrStale(int remoteUpdatedAtMs) {
    final now = DateTime.now().millisecondsSinceEpoch;
    if (now <= _localWriteAuthorityUntilMs) {
      // 权威窗口内：同版本或更旧一律当 echo/旧包忽略；仅接受明确更新的快照。
      if (remoteUpdatedAtMs <= 0) {
        return true;
      }
      return remoteUpdatedAtMs <= _localWriteAuthorityMinUpdatedAtMs;
    }
    if (remoteUpdatedAtMs <= 0) {
      return false;
    }
    return remoteUpdatedAtMs < _setUpdatedAtMs;
  }

  Future<bool> _pinConversationOnTencent(
    String conversationID,
    bool isPinned,
  ) async {
    final id = conversationID.trim();
    if (id.isEmpty) {
      return false;
    }
    final override = debugPinConversationOverride;
    if (override != null) {
      return override(id, isPinned);
    }
    try {
      final V2TimCallback result = await TencentImSDKPlugin.v2TIMManager
          .getConversationManager()
          .pinConversation(conversationID: id, isPinned: isPinned);
      if (result.code != 0) {
        ConversationPinFlickerLog.log(
          'pin_tencent_sdk_error',
          conversationID: id,
          extras: <String, Object?>{
            'code': result.code,
            'desc': result.desc,
            'isPinned': isPinned,
          },
        );
        return false;
      }
      return true;
    } catch (e, st) {
      debugPrint('ConversationPinSync: TIM pinConversation failed: $e\n$st');
      return false;
    }
  }

  Future<void> clearSession() async {
    _lastLoginSyncAt = null;
    _lastLoginSyncIdentity = null;
    _loginSyncIdentity = null;
    _loginSyncInFlight = null;
    _refreshInFlight = null;
    _refreshIdentity = null;
    _tencentReconcileInFlight = null;
    _tencentReconcileIdentity = null;
    _pinnedConversationIds.clear();
    _isHydrated = false;
    _setUpdatedAtMs = 0;
    _localWriteAuthorityUntilMs = 0;
    _localWriteAuthorityMinUpdatedAtMs = 0;
  }

  /// 注销：删除该账号置顶 prefs，并卸内存。
  Future<void> clearForOwner(String? ownerUserId) async {
    final scope = ContactSocialCacheStore.accountScopeForUserId(ownerUserId);
    await clearSession();
    if (scope.isEmpty || scope == _guestScope) {
      return;
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('$_cachePrefix$scope');
    await prefs.remove('$_sourceGatePrefix$scope');
  }

  /// 单测注入置顶集合（不写 prefs / 不改 SQLite）。
  @visibleForTesting
  void debugReplacePinnedIdsForTest(
    Iterable<String> ids, {
    bool markHydrated = false,
  }) {
    _pinnedConversationIds
      ..clear()
      ..addAll(
        ids.map((e) => e.trim()).where((e) => e.isNotEmpty),
      );
    if (markHydrated) {
      _isHydrated = true;
    }
  }

  /// 单测复位所有 debug 注入。
  @visibleForTesting
  static void debugResetTestHooks() {
    debugPinConversationOverride = null;
    debugCollectTencentPinnedIdsOverride = null;
    debugAccountScopeOverride = null;
    debugSkipPersistAndUiForTest = false;
    debugFollowWriteOverride = null;
  }

  /// 正式账号 scope：禁止用 `_guest` 读写正式置顶缓存。
  SessionIdentity _captureIdentity() {
    final override = debugAccountScopeOverride?.trim();
    if (override != null && override.isNotEmpty) {
      return SessionIdentity(
        ownerUserId: override,
        generation: SessionIdentityService.instance.generation,
      );
    }
    return SessionIdentityService.instance.capture();
  }

  bool _isCurrent(SessionIdentity identity) {
    final override = debugAccountScopeOverride?.trim();
    if (override != null && override.isNotEmpty) {
      return identity.ownerUserId == override &&
          SessionIdentityService.instance
              .isGenerationCurrent(identity.generation);
    }
    return SessionIdentityService.instance.isCurrent(identity);
  }

  bool _hasAccountScopedIdentity(SessionIdentity identity) {
    final scope = _prefsScope(identity);
    return scope.isNotEmpty && scope != _guestScope;
  }

  String _prefsScope([SessionIdentity? identity]) {
    final override = debugAccountScopeOverride?.trim();
    if (override != null && override.isNotEmpty) {
      return override;
    }
    return ContactSocialCacheStore.accountScopeForUserId(
      identity?.ownerUserId ?? ContactSocialCacheStore.safeLoginUserId(),
    );
  }

  static bool _setContainsConversation(Set<String> ids, String conversationId) {
    if (ids.contains(conversationId)) {
      return true;
    }
    for (final id in ids) {
      if (MessageConversationId.sameConversation(id, conversationId)) {
        return true;
      }
    }
    return false;
  }

  static bool _sameIdSet(Set<String> a, Set<String> b) {
    if (a.length != b.length) {
      return false;
    }
    for (final id in a) {
      if (!_setContainsConversation(b, id)) {
        return false;
      }
    }
    return true;
  }

  static int? _asInt(dynamic value) {
    if (value is int) {
      return value;
    }
    if (value is num) {
      return value.toInt();
    }
    return int.tryParse(value?.toString() ?? '');
  }
}
