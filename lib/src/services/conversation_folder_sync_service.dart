import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tencent_cloud_chat_demo/src/api/conversation_folder_api.dart';
import 'package:tencent_cloud_chat_demo/src/services/archived_conversation_sync_service.dart';
import 'package:tencent_cloud_chat_demo/src/services/contact_social_cache_store.dart';
import 'package:tencent_cloud_chat_demo/src/services/conversation_folder_store.dart';
import 'package:tencent_cloud_chat_demo/src/services/conversation_refresh_bus.dart';
import 'package:tencent_cloud_chat_demo/src/services/friend_realtime/friend_realtime_event.dart';
import 'package:tencent_cloud_chat_demo/src/utils/archived_conversation_ref.dart';
import 'package:tencent_cloud_chat_demo/utils/chat_id_format.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_conversation.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_conversation.dart';
import 'package:tencent_cloud_chat_uikit/ui/views/TIMUIKitConversation/archived_conversation_store.dart';
import 'package:uuid/uuid.dart';

/// 会话自定义分组：本地 Store + 服务端多端同步。
class ConversationFolderSyncService {
  ConversationFolderSyncService._();

  static final ConversationFolderSyncService instance =
      ConversationFolderSyncService._();

  static const _migratedPrefix = 'conversation_folders_migrated_v1_';
  static const _sharedScopeMigratedPrefix =
      'conversation_folders_shared_scope_v1_';
  static const Duration _loginSyncCooldown = Duration(minutes: 2);
  static const _uuid = Uuid();

  DateTime? _lastLoginSyncAt;
  Future<void>? _loginSyncInFlight;
  Future<void>? _refreshInFlight;

  Future<void> syncOnLogin({bool force = false}) {
    if (!force &&
        _lastLoginSyncAt != null &&
        DateTime.now().difference(_lastLoginSyncAt!) < _loginSyncCooldown) {
      return Future<void>.value();
    }
    return _loginSyncInFlight ??= _syncOnLogin(force: force).whenComplete(() {
      _loginSyncInFlight = null;
    });
  }

  Future<void> _syncOnLogin({required bool force}) async {
    try {
      await ConversationFolderStore.instance.ensureLoaded();
      await _migrateLocalToServerIfNeeded();
      await refreshFromServer();
      await _migrateFoldersToSharedScopeIfNeeded();
      _lastLoginSyncAt = DateTime.now();
    } catch (e, st) {
      debugPrint('ConversationFolderSync: login sync failed: $e\n$st');
      if (force) {
        rethrow;
      }
    }
  }

  /// 将历史 c2c/group 分组元数据重写为 scope=all（后端需已放宽）。
  Future<void> _migrateFoldersToSharedScopeIfNeeded() async {
    if (await _isSharedScopeMigrated()) {
      return;
    }
    final folders = ConversationFolderStore.instance.folders;
    for (final folder in folders) {
      await _reportUpsertFolder(folder);
    }
    await _markSharedScopeMigrated();
  }

  Future<void> refreshFromServer() {
    return _refreshInFlight ??= _refreshFromServerCore().whenComplete(() {
      _refreshInFlight = null;
    });
  }

  Future<void> _refreshFromServerCore() async {
    final page = await ConversationFolderApi.instance.fetch();
    final folders = page.folders
        .map(ConversationFolder.fromDto)
        .where((folder) => folder.folderId.isNotEmpty && folder.name.isNotEmpty)
        .toList(growable: false);
    // 服务端历史脏数据可能一会话多组：本地折叠并尽量上报移出。
    final collapsed =
        ConversationFolderStore.collapseExclusiveMembership(folders);
    await ConversationFolderStore.instance.replaceAll(collapsed.folders);
    await _reportExclusiveMembershipRemovals(collapsed.removedByFolderId);
    ConversationRefreshBus.instance.requestRefresh(
      reason: 'conversation_folder_remote',
    );
  }

  Future<void> handleRealtimeEvent(FriendRealtimeEvent event) async {
    if (event.event.trim() != 'conversation_folder_changed') {
      return;
    }
    await refreshFromServer();
    ConversationRefreshBus.instance.requestRefresh(
      reason: event.folderBatch == true
          ? 'conversation_folder_remote_batch'
          : 'conversation_folder_remote',
    );
  }

  /// 创建分组（本地优先，再上报）。单聊/群聊共用，无 scope 拆分。
  ///
  /// 分组名不可与已有分组重复（trim 后大小写不敏感）。
  Future<ConversationFolder> createFolder({
    required String name,
  }) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) {
      throw ArgumentError('name is required');
    }
    await ConversationFolderStore.instance.ensureLoaded();
    if (ConversationFolderStore.instance.isNameTaken(trimmed)) {
      throw DuplicateConversationFolderNameException(trimmed);
    }
    final existing = ConversationFolderStore.instance.folders;
    final folder = ConversationFolder(
      folderId: _uuid.v4(),
      name: trimmed,
      scope: ConversationFolder.sharedScope,
      sortOrder: existing.isEmpty
          ? 0
          : existing.map((f) => f.sortOrder).reduce((a, b) => a > b ? a : b) +
              1,
      members: const <String, int?>{},
      updatedAt: DateTime.now().millisecondsSinceEpoch,
      createdAt: DateTime.now().millisecondsSinceEpoch,
    );
    await ConversationFolderStore.instance.upsertFolder(folder);
    // 后端已上线：创建后等待上报，便于多端尽快对齐；失败仍保留本地。
    await _reportUpsertFolder(folder);
    return ConversationFolderStore.instance.folderById(folder.folderId) ??
        folder;
  }

  Future<void> renameFolder({
    required String folderId,
    required String name,
  }) async {
    final folder = ConversationFolderStore.instance.folderById(folderId);
    if (folder == null) {
      return;
    }
    final trimmed = name.trim();
    if (trimmed.isEmpty) {
      return;
    }
    if (ConversationFolderStore.normalizeFolderName(folder.name) ==
        ConversationFolderStore.normalizeFolderName(trimmed)) {
      // 仅大小写/空白变化且规范化后相同：若展示名也完全一致则 no-op。
      if (folder.name == trimmed) {
        return;
      }
    } else if (ConversationFolderStore.instance.isNameTaken(
      trimmed,
      excludingFolderId: folder.folderId,
    )) {
      throw DuplicateConversationFolderNameException(trimmed);
    }
    final updated = folder.copyWith(
      name: trimmed,
      updatedAt: DateTime.now().millisecondsSinceEpoch,
    );
    await ConversationFolderStore.instance.upsertFolder(updated);
    await _reportUpsertFolder(updated);
  }

  Future<void> deleteFolder(String folderId) async {
    final id = folderId.trim();
    if (id.isEmpty) {
      return;
    }
    await ConversationFolderStore.instance.removeFolder(id);
    unawaited(() async {
      try {
        await ConversationFolderApi.instance.deleteFolder(id);
      } catch (e) {
        debugPrint('ConversationFolderSync: delete failed: $e');
      }
    }());
  }

  /// 将会话加入指定分组；自动解除归档，并保证一会话仅在一组。
  ///
  /// 远端顺序：先 join 目标组，成功后再 leave 旧组；join 失败则回滚本地。
  Future<void> addConversationsToFolder({
    required String folderId,
    required List<V2TimConversation> conversations,
  }) async {
    final folder = ConversationFolderStore.instance.folderById(folderId);
    if (folder == null || conversations.isEmpty) {
      return;
    }
    final refs = <ArchivedConversationRef>[];
    final leaveByFolder = <String, List<ArchivedConversationRef>>{};
    final conversationsToUnarchive = <V2TimConversation>[];
    for (final conversation in conversations) {
      final ref = ArchivedConversationRef.fromConversation(conversation);
      if (ref == null) {
        continue;
      }
      final previousFolderIds = ConversationFolderStore.instance
          .folderIdsContaining(ref.conversationId);
      // 已仅在目标组：本地/远端均 no-op，避免刷成员时间与重复上报。
      if (previousFolderIds.length == 1 &&
          previousFolderIds.contains(folder.folderId)) {
        continue;
      }
      refs.add(ref);
      conversationsToUnarchive.add(conversation);
      for (final previousId in previousFolderIds) {
        if (previousId == folder.folderId) {
          continue;
        }
        leaveByFolder
            .putIfAbsent(previousId, () => <ArchivedConversationRef>[])
            .add(ref);
      }
    }
    if (refs.isEmpty) {
      return;
    }

    final snapshot = ConversationFolderStore.instance.folders
        .map(
          (item) => ConversationFolder(
            folderId: item.folderId,
            name: item.name,
            scope: item.scope,
            sortOrder: item.sortOrder,
            members: Map<String, int?>.from(item.members),
            updatedAt: item.updatedAt,
            createdAt: item.createdAt,
          ),
        )
        .toList(growable: false);

    final stamp = DateTime.now().millisecondsSinceEpoch;
    for (final ref in refs) {
      await ConversationFolderStore.instance.setMemberInFolders(
        conversationId: ref.conversationId,
        folderIds: {folder.folderId},
        memberUpdatedAt: stamp,
      );
    }
    final touched =
        ConversationFolderStore.instance.folderById(folder.folderId);
    if (touched != null) {
      await ConversationFolderStore.instance.upsertFolder(
        touched.copyWith(updatedAt: stamp),
      );
    }

    // 仅回滚「原本已归档」的会话；未归档的不要误归档。
    final previouslyArchived = conversationsToUnarchive
        .where(_isLocallyArchivedConversation)
        .toList(growable: false);

    await ArchivedConversationSyncService.instance.setArchivedForConversations(
      conversationsToUnarchive,
      archived: false,
    );

    final joinOk = await _reportMembers(
      folderId: folder.folderId,
      refs: refs,
      inFolder: true,
    );
    if (!joinOk) {
      // 先恢复归档（会顺带清当前分组成员），再还原分组快照。
      if (previouslyArchived.isNotEmpty) {
        await ArchivedConversationSyncService.instance
            .setArchivedForConversations(
          previouslyArchived,
          archived: true,
        );
      }
      await ConversationFolderStore.instance.replaceAll(snapshot);
      debugPrint(
        'ConversationFolderSync: join failed, membership+archive rolled back',
      );
      return;
    }

    for (final entry in leaveByFolder.entries) {
      final leaveOk = await _reportMembers(
        folderId: entry.key,
        refs: entry.value,
        inFolder: false,
        retries: 2,
      );
      if (!leaveOk) {
        debugPrint(
          'ConversationFolderSync: leave folder ${entry.key} failed after join; '
          'local exclusive, remote may heal on next refresh',
        );
      }
    }
  }

  Future<void> removeConversationsFromFolder({
    required String folderId,
    required List<V2TimConversation> conversations,
  }) async {
    final folder = ConversationFolderStore.instance.folderById(folderId);
    if (folder == null || conversations.isEmpty) {
      return;
    }
    final refs = <ArchivedConversationRef>[];
    final members = Map<String, int?>.from(folder.members);
    for (final conversation in conversations) {
      final ref = ArchivedConversationRef.fromConversation(conversation);
      if (ref == null) {
        continue;
      }
      final before = members.length;
      members.removeWhere(
        (id, _) => ConversationFolder.sameFolderConversation(
          id,
          ref.conversationId,
        ),
      );
      if (members.length != before) {
        refs.add(ref);
      }
    }
    if (refs.isEmpty) {
      return;
    }
    await ConversationFolderStore.instance.upsertFolder(
      folder.copyWith(
        members: members,
        updatedAt: DateTime.now().millisecondsSinceEpoch,
      ),
    );
    await _reportMembers(
      folderId: folder.folderId,
      refs: refs,
      inFolder: false,
      retries: 2,
    );
  }

  /// 归档前调用：从全部分组移除这些会话（本地 + 上报）。
  Future<void> removeConversationsFromAllFolders(
    List<V2TimConversation> conversations,
  ) async {
    if (conversations.isEmpty) {
      return;
    }
    await ConversationFolderStore.instance.ensureLoaded();
    final byFolder = <String, List<ArchivedConversationRef>>{};
    final touchedConversationIds = <String>{};
    for (final conversation in conversations) {
      final ref = ArchivedConversationRef.fromConversation(conversation);
      if (ref == null) {
        continue;
      }
      for (final folder
          in ConversationFolderStore.instance.foldersNotifier.value) {
        if (!folder.containsConversationId(ref.conversationId)) {
          continue;
        }
        byFolder
            .putIfAbsent(folder.folderId, () => <ArchivedConversationRef>[])
            .add(ref);
        touchedConversationIds.add(ref.conversationId);
      }
    }
    for (final conversationId in touchedConversationIds) {
      await ConversationFolderStore.instance.removeConversationFromAllFolders(
        conversationId,
      );
    }
    for (final entry in byFolder.entries) {
      unawaited(
        _reportMembers(
          folderId: entry.key,
          refs: entry.value,
          inFolder: false,
        ),
      );
    }
  }

  Future<void> clearSession() async {
    _lastLoginSyncAt = null;
    _loginSyncInFlight = null;
    _refreshInFlight = null;
    await ConversationFolderStore.instance.clearSession();
  }

  Future<void> _reportUpsertFolder(ConversationFolder folder) async {
    try {
      final result = await ConversationFolderApi.instance.upsertFolder(
        folderId: folder.folderId,
        name: folder.name,
        scope: ConversationFolder.sharedScope,
        sortOrder: folder.sortOrder,
      );
      final serverFolder = result.folder;
      if (serverFolder == null || serverFolder.folderId.isEmpty) {
        return;
      }
      if (serverFolder.folderId != folder.folderId) {
        // 服务端分配了新 ID：全量刷新对齐。
        await refreshFromServer();
        return;
      }
      // 合并服务端时间戳；若响应带 members 则一并覆盖。
      final merged = ConversationFolder.fromDto(serverFolder);
      final keepMembers = serverFolder.members.isEmpty
          ? Map<String, int?>.from(folder.members)
          : Map<String, int?>.from(merged.members);
      await ConversationFolderStore.instance.upsertFolder(
        merged.copyWith(members: keepMembers),
      );
    } catch (e, st) {
      debugPrint('ConversationFolderSync: upsert folder failed: $e\n$st');
    }
  }

  /// 返回是否上报成功；[retries] 为失败后的额外重试次数。
  ///
  /// HTTP 成功但业务体 `ok: false` 视为失败（不可当成功短路）。
  Future<bool> _reportMembers({
    required String folderId,
    required List<ArchivedConversationRef> refs,
    required bool inFolder,
    int retries = 0,
  }) async {
    if (refs.isEmpty) {
      return true;
    }
    var attempt = 0;
    final maxAttempts = 1 + (retries < 0 ? 0 : retries);
    while (attempt < maxAttempts) {
      attempt += 1;
      try {
        final result = await ConversationFolderApi.instance.updateMembers(
          folderId: folderId,
          members: refs
              .map(
                (ref) => ConversationFolderMemberRef(
                  chatType: ref.chatType,
                  peerId: ref.chatType == 'group'
                      ? ChatIdFormat.canonicalGroupStorageId(ref.peerId)
                      : ChatIdFormat.rawUserUid(ref.peerId),
                ),
              )
              .toList(growable: false),
          inFolder: inFolder,
        );
        if (!result.ok) {
          debugPrint(
            'ConversationFolderSync: members report ok:false '
            '(attempt $attempt/$maxAttempts) folder=$folderId inFolder=$inFolder',
          );
          if (attempt >= maxAttempts) {
            return false;
          }
          continue;
        }
        return true;
      } catch (e, st) {
        debugPrint(
          'ConversationFolderSync: members report failed '
          '(attempt $attempt/$maxAttempts): $e\n$st',
        );
        if (attempt >= maxAttempts) {
          return false;
        }
      }
    }
    return false;
  }

  bool _isLocallyArchivedConversation(V2TimConversation conversation) {
    final ref = ArchivedConversationRef.fromConversation(conversation);
    if (ref == null) {
      return false;
    }
    final ids = ref.chatType == 'group'
        ? archivedConversationGroupIDsNotifier.value
        : archivedConversationC2cIDsNotifier.value;
    for (final id in ids) {
      if (ConversationFolder.sameFolderConversation(id, ref.conversationId)) {
        return true;
      }
    }
    return false;
  }

  Future<void> _reportExclusiveMembershipRemovals(
    Map<String, List<String>> removedByFolderId,
  ) async {
    if (removedByFolderId.isEmpty) {
      return;
    }
    for (final entry in removedByFolderId.entries) {
      final refs = <ArchivedConversationRef>[];
      for (final conversationId in entry.value) {
        final ref =
            ArchivedConversationRef.fromConversationId(conversationId);
        if (ref != null) {
          refs.add(ref);
        }
      }
      if (refs.isEmpty) {
        continue;
      }
      final ok = await _reportMembers(
        folderId: entry.key,
        refs: refs,
        inFolder: false,
        retries: 2,
      );
      if (!ok) {
        debugPrint(
          'ConversationFolderSync: exclusive heal leave failed for ${entry.key}',
        );
      }
    }
  }

  Future<void> _migrateLocalToServerIfNeeded() async {
    if (await _isMigrated()) {
      return;
    }
    final local = ConversationFolderStore.instance.foldersNotifier.value;
    if (local.isNotEmpty) {
      try {
        final collapsed =
            ConversationFolderStore.collapseExclusiveMembership(local);
        if (collapsed.removedByFolderId.isNotEmpty) {
          await ConversationFolderStore.instance
              .replaceAll(collapsed.folders);
        }
        await ConversationFolderApi.instance.replaceAll(
          collapsed.folders
              .map((folder) => folder.toDto())
              .toList(growable: false),
        );
      } catch (e, st) {
        debugPrint('ConversationFolderSync: migrate failed: $e\n$st');
        // 迁移失败不阻断登录；下次仍可重试。
        return;
      }
    }
    await _markMigrated();
  }

  String _prefsScope() => ContactSocialCacheStore.accountScope();

  Future<bool> _isMigrated() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('$_migratedPrefix${_prefsScope()}') == true;
  }

  Future<void> _markMigrated() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('$_migratedPrefix${_prefsScope()}', true);
  }

  Future<bool> _isSharedScopeMigrated() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('$_sharedScopeMigratedPrefix${_prefsScope()}') == true;
  }

  Future<void> _markSharedScopeMigrated() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('$_sharedScopeMigratedPrefix${_prefsScope()}', true);
  }
}

/// 分组名称与已有分组冲突。
class DuplicateConversationFolderNameException implements Exception {
  DuplicateConversationFolderNameException(this.name);

  final String name;

  @override
  String toString() => 'DuplicateConversationFolderNameException($name)';
}
