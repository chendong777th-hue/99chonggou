import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tencent_cloud_chat_demo/src/api/archived_conversation_api.dart';
import 'package:tencent_cloud_chat_demo/src/services/archived_conversation_entry_visibility.dart';
import 'package:tencent_cloud_chat_demo/src/services/contact_social_cache_store.dart';
import 'package:tencent_cloud_chat_demo/src/services/conversation_folder_sync_service.dart';
import 'package:tencent_cloud_chat_demo/src/services/conversation_refresh_bus.dart';
import 'package:tencent_cloud_chat_demo/src/services/friend_realtime/friend_realtime_event.dart';
import 'package:tencent_cloud_chat_demo/src/services/session_identity.dart';
import 'package:tencent_cloud_chat_demo/src/utils/archived_conversation_ref.dart';
import 'package:tencent_cloud_chat_demo/src/utils/message_conversation_id.dart';
import 'package:tencent_cloud_chat_demo/utils/chat_id_format.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_conversation.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_conversation.dart';
import 'package:tencent_cloud_chat_uikit/data_services/message/archive_history_provider.dart';
import 'package:tencent_cloud_chat_uikit/ui/views/TIMUIKitConversation/archived_conversation_store.dart';

/// 会话归档：本地 SP 缓存 + 服务端多端同步。
class ArchivedConversationSyncService {
  ArchivedConversationSyncService._();

  static final ArchivedConversationSyncService instance =
      ArchivedConversationSyncService._();

  static const _migratedPrefix = 'archived_conversations_migrated_v1_';
  static const _sincePrefix = 'archived_conversations_since_v1_';
  static const Duration _loginSyncCooldown = Duration(minutes: 2);
  static const int _batchSize = 100;

  DateTime? _lastLoginSyncAt;
  SessionIdentity? _lastLoginSyncIdentity;
  SessionIdentity? _loginSyncIdentity;
  Future<void>? _loginSyncInFlight;
  SessionIdentity? _refreshIdentity;
  Future<void>? _refreshInFlight;

  Future<void> syncOnLogin({bool force = false}) {
    final identity = SessionIdentityService.instance.capture();
    if (identity.ownerUserId.isEmpty) return Future<void>.value();
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
      await ensureArchivedConversationIDsLoaded(
        accountScope: _prefsScope(identity),
      );
      if (!_isCurrent(identity)) return;
      await _migrateLocalToServerIfNeeded(identity);
      if (!_isCurrent(identity)) return;
      await refreshFromServer(expectedIdentity: identity);
      if (!_isCurrent(identity)) return;
      _lastLoginSyncAt = DateTime.now();
      _lastLoginSyncIdentity = identity;
    } catch (e, st) {
      debugPrint('ArchivedConversationSync: login sync failed: $e\n$st');
      if (force) {
        rethrow;
      }
    }
  }

  /// 用户操作：先写本地，再上报服务端。
  Future<void> setArchivedForConversations(
    List<V2TimConversation> conversations, {
    required bool archived,
    SessionIdentity? expectedIdentity,
  }) async {
    final identity =
        expectedIdentity ?? SessionIdentityService.instance.capture();
    if (identity.ownerUserId.isEmpty || !_isCurrent(identity)) return;
    if (conversations.isEmpty) {
      return;
    }
    final refs = <ArchivedConversationRef>[];
    final idsByScope = <ConversationArchiveScope, Set<String>>{
      ConversationArchiveScope.c2c: {
        ...archivedConversationC2cIDsNotifier.value,
      },
      ConversationArchiveScope.group: {
        ...archivedConversationGroupIDsNotifier.value,
      },
    };
    for (final conversation in conversations) {
      final ref = ArchivedConversationRef.fromConversation(conversation);
      if (ref == null) {
        continue;
      }
      refs.add(ref);
      if (archived) {
        idsByScope[ref.scope]!.add(ref.conversationId);
      } else {
        idsByScope[ref.scope]!.remove(ref.conversationId);
      }
    }
    if (refs.isEmpty) {
      return;
    }
    // 归档 ↔ 分组互斥：归档时先踢出全部分组。
    if (archived) {
      await ConversationFolderSyncService.instance
          .removeConversationsFromAllFolders(
        conversations,
        expectedIdentity: identity,
      );
      if (!_isCurrent(identity)) return;
    }
    for (final scope in ConversationArchiveScope.values) {
      await saveArchivedConversationIDs(
        scope,
        idsByScope[scope]!,
        accountScope: _prefsScope(identity),
      );
      if (!_isCurrent(identity)) return;
    }
    unawaited(_reportToServer(refs, archived: archived, identity: identity));
  }

  /// 清空聊天记录后重申归档状态。
  ///
  /// 后端清档（`DELETE /me/messages/*`）可能连带丢掉服务端归档标记，
  /// 随后实时事件 / refreshFromServer 会把本地集合也带掉，归档会话
  /// 就掉回主消息列表。清空前本地已归档的，这里把标记钉回本地并向
  /// 服务端重报一次（幂等）。
  Future<void> reassertArchivedAfterHistoryClear({
    required bool isGroup,
    required String peerId,
  }) async {
    final identity = SessionIdentityService.instance.capture();
    if (identity.ownerUserId.isEmpty || !_isCurrent(identity)) return;
    final normalized = isGroup
        ? ChatIdFormat.canonicalGroupStorageId(peerId)
        : ChatIdFormat.rawUserUid(peerId);
    if (normalized.isEmpty) {
      return;
    }
    final ref = ArchivedConversationRef(
      chatType: isGroup ? 'group' : 'c2c',
      peerId: normalized,
    );
    await ensureArchivedConversationIDsLoaded(
      accountScope: _prefsScope(identity),
    );
    if (!_isCurrent(identity)) return;
    final notifier = archivedConversationIDsNotifierFor(ref.scope);
    final wasArchived = notifier.value.any(
      (id) => MessageConversationId.sameConversation(id, ref.conversationId),
    );
    if (!wasArchived) {
      return;
    }
    // 先钉回本地（实时事件可能已把它移除），再重报服务端。
    if (!notifier.value.contains(ref.conversationId)) {
      await saveArchivedConversationIDs(
        ref.scope,
        {...notifier.value, ref.conversationId},
        accountScope: _prefsScope(identity),
      );
      if (!_isCurrent(identity)) return;
    }
    try {
      await ArchivedConversationApi.instance.update(
        chatType: ref.chatType,
        peerId: ref.peerId,
        archived: true,
      );
    } catch (e) {
      debugPrint('ArchivedConversationSync: reassert failed: $e');
    }
  }

  Future<void> handleRealtimeEvent(FriendRealtimeEvent event) async {
    final identity = SessionIdentityService.instance.capture();
    if (identity.ownerUserId.isEmpty || !_isCurrent(identity)) return;
    if (event.event.trim() != 'conversation_archive_changed') {
      return;
    }
    if (event.archiveBatch == true) {
      await refreshFromServer(expectedIdentity: identity);
      if (!_isCurrent(identity)) return;
      ConversationRefreshBus.instance.requestRefresh(
        reason: 'conversation_archive_remote_batch',
      );
      return;
    }
    final ref = _refFromRealtimeEvent(event);
    if (ref == null) {
      await refreshFromServer(expectedIdentity: identity);
      if (!_isCurrent(identity)) return;
      ConversationRefreshBus.instance.requestRefresh(
        reason: 'conversation_archive_remote_fallback',
      );
      return;
    }
    final ids = {...archivedConversationIDsNotifierFor(ref.scope).value};
    if (event.archiveArchived == true) {
      ids.add(ref.conversationId);
    } else {
      // 清空聊天记录的宽限期内忽略「取消归档」事件：这是后端清档的
      // 级联误报，不是用户操作；采纳会让归档会话掉回主列表。
      if (ArchiveHistoryProvider.isInHistoryClearGrace(ref.conversationId)) {
        return;
      }
      ids.removeWhere(
        (id) => MessageConversationId.sameConversation(id, ref.conversationId),
      );
    }
    await saveArchivedConversationIDs(
      ref.scope,
      ids,
      accountScope: _prefsScope(identity),
    );
    if (!_isCurrent(identity)) return;
    ConversationRefreshBus.instance.requestRefresh(
      reason: 'conversation_archive_remote',
      conversationId: ref.conversationId,
    );
  }

  Future<void> refreshFromServer({SessionIdentity? expectedIdentity}) async {
    final identity =
        expectedIdentity ?? SessionIdentityService.instance.capture();
    if (identity.ownerUserId.isEmpty || !_isCurrent(identity)) return;
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
    final c2cIds = <String>{};
    final groupIds = <String>{};
    int? pageSince;
    var pages = 0;
    const maxPages = 20;
    var hasMore = true;
    int? lastCursor;
    // 全量快照：首包不带 since；仅在同一次 drain 内用 nextSince 续页。
    while (hasMore && pages < maxPages) {
      pages++;
      final page = await ArchivedConversationApi.instance.fetch(
        since: pageSince != null && pageSince > 0 ? pageSince : null,
      );
      if (!_isCurrent(identity)) return;
      for (final item in page.items) {
        final ref = ArchivedConversationRef(
          chatType: item.chatType,
          peerId: item.chatType == 'group'
              ? ChatIdFormat.canonicalGroupStorageId(item.peerId)
              : ChatIdFormat.rawUserUid(item.peerId),
        );
        if (ref.scope == ConversationArchiveScope.group) {
          groupIds.add(ref.conversationId);
        } else {
          c2cIds.add(ref.conversationId);
        }
      }
      final next = page.nextSince ?? page.serverTime;
      if (next != null && next > 0) {
        lastCursor = next;
        pageSince = next;
      }
      hasMore = page.hasMore;
      if (!hasMore) {
        break;
      }
      if (page.items.isEmpty) {
        break;
      }
      if (next == null || next <= 0) {
        debugPrint(
          'ArchivedConversationSync: hasMore without nextSince, stop drain',
        );
        break;
      }
    }
    if (!_isCurrent(identity)) return;
    // 清空聊天记录宽限期内的会话：服务端快照可能因清档级联暂时缺失
    // 其归档标记，保留本地状态，等重申（reassert）落地后自然一致。
    for (final id in archivedConversationC2cIDsNotifier.value) {
      if (ArchiveHistoryProvider.isInHistoryClearGrace(id)) {
        c2cIds.add(id);
      }
    }
    for (final id in archivedConversationGroupIDsNotifier.value) {
      if (ArchiveHistoryProvider.isInHistoryClearGrace(id)) {
        groupIds.add(id);
      }
    }
    await saveArchivedConversationIDs(
      ConversationArchiveScope.c2c,
      c2cIds,
      accountScope: _prefsScope(identity),
    );
    if (!_isCurrent(identity)) return;
    await saveArchivedConversationIDs(
      ConversationArchiveScope.group,
      groupIds,
      accountScope: _prefsScope(identity),
    );
    if (!_isCurrent(identity)) return;
    // 服务端快照落地后，立刻按可解析会话调和入口，避免脏 ID 空入口。
    unawaited(
      ArchivedConversationEntryVisibility.instance
          .reconcile(ConversationArchiveScope.c2c),
    );
    unawaited(
      ArchivedConversationEntryVisibility.instance
          .reconcile(ConversationArchiveScope.group),
    );
    if (lastCursor != null && lastCursor > 0) {
      await _writeSinceCursor(lastCursor, identity);
    }
  }

  Future<void> _migrateLocalToServerIfNeeded(SessionIdentity identity) async {
    if (await _isMigrated(identity)) {
      return;
    }
    final localItems = <ArchivedConversationItem>[];
    for (final conversationId in archivedConversationC2cIDsNotifier.value) {
      final ref = ArchivedConversationRef.fromConversationId(conversationId);
      if (ref == null) {
        continue;
      }
      localItems.add(
        ArchivedConversationItem(
          chatType: ref.chatType,
          peerId: ref.peerId,
        ),
      );
    }
    for (final conversationId in archivedConversationGroupIDsNotifier.value) {
      final ref = ArchivedConversationRef.fromConversationId(conversationId);
      if (ref == null) {
        continue;
      }
      localItems.add(
        ArchivedConversationItem(
          chatType: ref.chatType,
          peerId: ref.peerId,
        ),
      );
    }
    if (localItems.isNotEmpty) {
      for (var offset = 0; offset < localItems.length; offset += _batchSize) {
        final end = offset + _batchSize > localItems.length
            ? localItems.length
            : offset + _batchSize;
        await ArchivedConversationApi.instance.batchUpdate(
          localItems.sublist(offset, end),
          archived: true,
        );
        if (!_isCurrent(identity)) return;
      }
    }
    await _markMigrated(identity);
  }

  Future<void> _reportToServer(
    List<ArchivedConversationRef> refs, {
    required bool archived,
    required SessionIdentity identity,
  }) async {
    if (!_isCurrent(identity)) return;
    try {
      if (refs.length == 1) {
        final ref = refs.first;
        await ArchivedConversationApi.instance.update(
          chatType: ref.chatType,
          peerId: ref.peerId,
          archived: archived,
        );
        return;
      }
      final items = refs
          .map(
            (ref) => ArchivedConversationItem(
              chatType: ref.chatType,
              peerId: ref.peerId,
            ),
          )
          .toList(growable: false);
      for (var offset = 0; offset < items.length; offset += _batchSize) {
        if (!_isCurrent(identity)) return;
        final end = offset + _batchSize > items.length
            ? items.length
            : offset + _batchSize;
        await ArchivedConversationApi.instance.batchUpdate(
          items.sublist(offset, end),
          archived: archived,
        );
      }
    } catch (e, st) {
      debugPrint('ArchivedConversationSync: report failed: $e\n$st');
    }
  }

  ArchivedConversationRef? _refFromRealtimeEvent(FriendRealtimeEvent event) {
    final chatType = event.archiveChatType?.trim().toLowerCase() ?? '';
    final peerId = event.archivePeerId?.trim() ?? '';
    if (chatType.isEmpty || peerId.isEmpty) {
      return null;
    }
    if (chatType != 'c2c' && chatType != 'group') {
      return null;
    }
    return ArchivedConversationRef(
      chatType: chatType,
      peerId: chatType == 'group'
          ? ChatIdFormat.canonicalGroupStorageId(peerId)
          : ChatIdFormat.rawUserUid(peerId),
    );
  }

  Future<void> clearSession() async {
    _lastLoginSyncAt = null;
    _lastLoginSyncIdentity = null;
    _loginSyncIdentity = null;
    _loginSyncInFlight = null;
    _refreshInFlight = null;
    _refreshIdentity = null;
    clearArchivedConversationSessionState();
  }

  /// 注销：删除该账号归档同步 prefs，并卸内存。
  Future<void> clearForOwner(String? ownerUserId) async {
    final scope = ContactSocialCacheStore.accountScopeForUserId(ownerUserId);
    if (scope.isEmpty || scope == '_guest') {
      return;
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('$_migratedPrefix$scope');
    await prefs.remove('$_sincePrefix$scope');
    await clearArchivedConversationDataForAccountScope(scope);
    if (_prefsScope(SessionIdentityService.instance.capture()) == scope) {
      await clearSession();
    }
  }

  bool _isCurrent(SessionIdentity identity) =>
      SessionIdentityService.instance.isCurrent(identity);

  String _prefsScope(SessionIdentity identity) =>
      ContactSocialCacheStore.accountScopeForUserId(identity.ownerUserId);

  Future<bool> _isMigrated(SessionIdentity identity) async {
    final prefs = await SharedPreferences.getInstance();
    if (!_isCurrent(identity)) return true;
    return prefs.getBool('$_migratedPrefix${_prefsScope(identity)}') == true;
  }

  Future<void> _markMigrated(SessionIdentity identity) async {
    final prefs = await SharedPreferences.getInstance();
    if (!_isCurrent(identity)) return;
    await prefs.setBool('$_migratedPrefix${_prefsScope(identity)}', true);
  }

  Future<void> _writeSinceCursor(int since, SessionIdentity identity) async {
    if (since <= 0) {
      return;
    }
    final prefs = await SharedPreferences.getInstance();
    if (!_isCurrent(identity)) return;
    await prefs.setInt('$_sincePrefix${_prefsScope(identity)}', since);
  }
}
