import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tencent_cloud_chat_demo/src/api/conversation_folder_api.dart';
import 'package:tencent_cloud_chat_demo/src/services/contact_social_cache_store.dart';
import 'package:tencent_cloud_chat_demo/src/utils/archived_conversation_ref.dart';
import 'package:tencent_cloud_chat_demo/utils/chat_id_format.dart';

/// [collapseExclusiveMembership] 的结果：归一后的分组 + 被踢出的成员。
@immutable
class ExclusiveMembershipCollapse {
  const ExclusiveMembershipCollapse({
    required this.folders,
    required this.removedByFolderId,
  });

  final List<ConversationFolder> folders;
  /// folderId → 因「一会话仅一组」被移出的 conversationId 列表。
  final Map<String, List<String>> removedByFolderId;
}

/// 本地会话分组快照（按账号隔离；单聊/群聊共用同一套分组）。
@immutable
class ConversationFolder {
  const ConversationFolder({
    required this.folderId,
    required this.name,
    required this.sortOrder,
    required this.members,
    this.scope = sharedScope,
    this.updatedAt,
    this.createdAt,
  });

  /// 线上网关约定：单聊与群聊共用分组。
  static const String sharedScope = 'all';

  final String folderId;
  final String name;
  /// 始终为 [sharedScope]；读取时会把历史 `c2c`/`group` 归一化。
  final String scope;
  final int sortOrder;
  /// conversationId → 成员级 updatedAt（毫秒；可空）。
  final Map<String, int?> members;
  final int? updatedAt;
  final int? createdAt;

  Set<String> get conversationIds => members.keys.toSet();

  ConversationFolder copyWith({
    String? name,
    int? sortOrder,
    Map<String, int?>? members,
    Set<String>? conversationIds,
    int? updatedAt,
  }) {
    Map<String, int?> nextMembers;
    if (members != null) {
      nextMembers = Map<String, int?>.unmodifiable(members);
    } else if (conversationIds != null) {
      final rebuilt = <String, int?>{};
      for (final id in conversationIds) {
        final key = id.trim();
        if (key.isEmpty) {
          continue;
        }
        rebuilt[key] = this.members[key] ??
            _lookupMemberUpdatedAt(this.members, key);
      }
      nextMembers = Map<String, int?>.unmodifiable(rebuilt);
    } else {
      nextMembers = this.members;
    }
    return ConversationFolder(
      folderId: folderId,
      name: name ?? this.name,
      scope: sharedScope,
      sortOrder: sortOrder ?? this.sortOrder,
      members: nextMembers,
      updatedAt: updatedAt ?? this.updatedAt,
      createdAt: createdAt,
    );
  }

  bool containsConversationId(String conversationId) {
    final target = conversationId.trim();
    if (target.isEmpty) {
      return false;
    }
    for (final id in members.keys) {
      if (sameFolderConversation(id, target)) {
        return true;
      }
    }
    return false;
  }

  int? memberUpdatedAt(String conversationId) {
    final target = conversationId.trim();
    if (target.isEmpty) {
      return null;
    }
    if (members.containsKey(target)) {
      return members[target];
    }
    return _lookupMemberUpdatedAt(members, target);
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'folderId': folderId,
      'name': name,
      'scope': sharedScope,
      'sortOrder': sortOrder,
      'conversationIds': conversationIds.toList(growable: false),
      'members': members.entries
          .map(
            (e) => <String, dynamic>{
              'conversationId': e.key,
              'updatedAt': e.value,
            },
          )
          .toList(growable: false),
      'updatedAt': updatedAt,
      'createdAt': createdAt,
    };
  }

  factory ConversationFolder.fromJson(Map<String, dynamic> json) {
    final members = <String, int?>{};
    final rawMembers = json['members'];
    if (rawMembers is List) {
      for (final entry in rawMembers) {
        if (entry is! Map) {
          continue;
        }
        final map = Map<String, dynamic>.from(entry);
        final id = (map['conversationId'] ?? map['conversation_id'])
                ?.toString()
                .trim() ??
            '';
        if (id.isEmpty) {
          continue;
        }
        members[id] = _asInt(map['updatedAt'] ?? map['updated_at']);
      }
    }
    if (members.isEmpty) {
      final rawIds = json['conversationIds'] ?? json['conversation_ids'];
      if (rawIds is List) {
        for (final entry in rawIds) {
          final id = entry?.toString().trim() ?? '';
          if (id.isNotEmpty) {
            members[id] = null;
          }
        }
      }
    }
    return ConversationFolder(
      folderId: (json['folderId'] ?? json['folder_id'])?.toString().trim() ?? '',
      name: json['name']?.toString().trim() ?? '',
      scope: sharedScope,
      sortOrder: _asInt(json['sortOrder'] ?? json['sort_order']) ?? 0,
      members: Map<String, int?>.unmodifiable(members),
      updatedAt: _asInt(json['updatedAt'] ?? json['updated_at']),
      createdAt: _asInt(json['createdAt'] ?? json['created_at']),
    );
  }

  static ConversationFolder fromDto(ConversationFolderDto dto) {
    final members = <String, int?>{};
    for (final member in dto.members) {
      final ref = ArchivedConversationRef(
        chatType: member.chatType,
        peerId: member.chatType == 'group'
            ? ChatIdFormat.canonicalGroupStorageId(member.peerId)
            : ChatIdFormat.rawUserUid(member.peerId),
      );
      members[ref.conversationId] = member.updatedAt;
    }
    return ConversationFolder(
      folderId: dto.folderId,
      name: dto.name,
      scope: sharedScope,
      sortOrder: dto.sortOrder,
      members: Map<String, int?>.unmodifiable(members),
      updatedAt: dto.updatedAt,
      createdAt: dto.createdAt,
    );
  }

  ConversationFolderDto toDto() {
    final refs = <ConversationFolderMemberRef>[];
    for (final entry in members.entries) {
      final ref = ArchivedConversationRef.fromConversationId(entry.key);
      if (ref == null) {
        continue;
      }
      refs.add(
        ConversationFolderMemberRef(
          chatType: ref.chatType,
          peerId: ref.peerId,
          updatedAt: entry.value,
        ),
      );
    }
    return ConversationFolderDto(
      folderId: folderId,
      name: name,
      scope: sharedScope,
      sortOrder: sortOrder,
      members: refs,
      updatedAt: updatedAt,
      createdAt: createdAt,
    );
  }

  /// 分组成员身份：必须同 `chatType`，且 peer 在各自类型内等价。
  /// 故意不用 [MessageConversationId.sameConversation]（会把 c2c_x / group_x 当成同一会话）。
  static bool sameFolderConversation(String? left, String? right) {
    final a = ArchivedConversationRef.fromConversationId(left?.trim() ?? '');
    final b = ArchivedConversationRef.fromConversationId(right?.trim() ?? '');
    if (a == null || b == null) {
      return false;
    }
    if (a.chatType != b.chatType) {
      return false;
    }
    if (a.chatType == 'group') {
      return ChatIdFormat.groupIdsEquivalent(a.peerId, b.peerId);
    }
    return ChatIdFormat.rawUserUid(a.peerId) ==
        ChatIdFormat.rawUserUid(b.peerId);
  }

  static String? folderConversationIdentity(String? conversationId) {
    final ref =
        ArchivedConversationRef.fromConversationId(conversationId?.trim() ?? '');
    if (ref == null) {
      return null;
    }
    if (ref.chatType == 'group') {
      return 'group|${ChatIdFormat.canonicalGroupStorageId(ref.peerId)}';
    }
    return 'c2c|${ChatIdFormat.rawUserUid(ref.peerId)}';
  }
}

class ConversationFolderStore {
  ConversationFolderStore._();

  static final ConversationFolderStore instance = ConversationFolderStore._();

  static const _storagePrefix = 'conversation_folders_v1_';

  final ValueNotifier<List<ConversationFolder>> foldersNotifier =
      ValueNotifier<List<ConversationFolder>>(const <ConversationFolder>[]);

  String? _loadedAccountScope;

  String _accountScope() => ContactSocialCacheStore.accountScope();

  String _storageKey() => '$_storagePrefix${_accountScope()}';

  /// 单聊/群聊共用：返回全部自定义分组。
  List<ConversationFolder> get folders {
    return foldersNotifier.value;
  }

  bool get hasAnyFolder => foldersNotifier.value.isNotEmpty;

  /// 分组名是否已被占用（trim 后大小写不敏感；[excludingFolderId] 用于重命名自身）。
  bool isNameTaken(String name, {String? excludingFolderId}) {
    final normalized = normalizeFolderName(name);
    if (normalized.isEmpty) {
      return false;
    }
    final exclude = excludingFolderId?.trim() ?? '';
    for (final folder in foldersNotifier.value) {
      if (exclude.isNotEmpty && folder.folderId == exclude) {
        continue;
      }
      if (normalizeFolderName(folder.name) == normalized) {
        return true;
      }
    }
    return false;
  }

  /// 与 [isNameTaken] 同一套规范化：trim + 小写。
  static String normalizeFolderName(String name) {
    return name.trim().toLowerCase();
  }

  ConversationFolder? folderById(String folderId) {
    final id = folderId.trim();
    if (id.isEmpty) {
      return null;
    }
    for (final folder in foldersNotifier.value) {
      if (folder.folderId == id) {
        return folder;
      }
    }
    return null;
  }

  /// 会话是否属于任意自定义分组。
  bool isInAnyFolder(String conversationId) {
    return folderIdsContaining(conversationId).isNotEmpty;
  }

  /// 包含该会话的全部分组 ID（产品要求至多一个；此方法用于检测/修复）。
  Set<String> folderIdsContaining(String conversationId) {
    final target = conversationId.trim();
    if (target.isEmpty) {
      return const <String>{};
    }
    final ids = <String>{};
    for (final folder in foldersNotifier.value) {
      if (folder.containsConversationId(target)) {
        ids.add(folder.folderId);
      }
    }
    return ids;
  }

  /// 该会话当前所在分组；多组脏数据时取成员级赢家。
  ConversationFolder? folderContaining(String conversationId) {
    final target = conversationId.trim();
    if (target.isEmpty) {
      return null;
    }
    final candidates = foldersNotifier.value
        .where((folder) => folder.containsConversationId(target))
        .toList(growable: false);
    if (candidates.isEmpty) {
      return null;
    }
    if (candidates.length == 1) {
      return candidates.first;
    }
    candidates.sort(
      (a, b) => _compareMembershipClaim(
        memberUpdatedAt: a.memberUpdatedAt(target),
        sortOrder: a.sortOrder,
        folderId: a.folderId,
        otherMemberUpdatedAt: b.memberUpdatedAt(target),
        otherSortOrder: b.sortOrder,
        otherFolderId: b.folderId,
      ),
    );
    return candidates.first;
  }

  /// 将列表中的会话折叠为「一会话仅一组」。
  ///
  /// 冲突时优先保留**成员** `updatedAt` 更大者，其次 `sortOrder` 更小，再比 `folderId`。
  /// 不使用分组元数据 `folder.updatedAt`，避免重命名误抢成员。
  static ExclusiveMembershipCollapse collapseExclusiveMembership(
    List<ConversationFolder> folders,
  ) {
    if (folders.isEmpty) {
      return const ExclusiveMembershipCollapse(
        folders: <ConversationFolder>[],
        removedByFolderId: <String, List<String>>{},
      );
    }

    final claims = <_MembershipClaim>[];
    for (final folder in folders) {
      for (final entry in folder.members.entries) {
        final conversationId = entry.key.trim();
        if (conversationId.isEmpty) {
          continue;
        }
        final identity =
            ConversationFolder.folderConversationIdentity(conversationId);
        if (identity == null) {
          continue;
        }
        claims.add(
          _MembershipClaim(
            identity: identity,
            folderId: folder.folderId,
            conversationId: conversationId,
            memberUpdatedAt: entry.value,
            sortOrder: folder.sortOrder,
          ),
        );
      }
    }

    final winnerByIdentity = <String, _MembershipClaim>{};
    for (final claim in claims) {
      final existing = winnerByIdentity[claim.identity];
      if (existing == null) {
        winnerByIdentity[claim.identity] = claim;
        continue;
      }
      if (_compareMembershipClaim(
            memberUpdatedAt: claim.memberUpdatedAt,
            sortOrder: claim.sortOrder,
            folderId: claim.folderId,
            otherMemberUpdatedAt: existing.memberUpdatedAt,
            otherSortOrder: existing.sortOrder,
            otherFolderId: existing.folderId,
          ) <
          0) {
        winnerByIdentity[claim.identity] = claim;
      }
    }

    final next = <ConversationFolder>[];
    final removedByFolderId = <String, List<String>>{};
    for (final folder in folders) {
      final kept = <String, int?>{};
      final removed = <String>[];
      for (final entry in folder.members.entries) {
        final conversationId = entry.key.trim();
        if (conversationId.isEmpty) {
          continue;
        }
        final identity =
            ConversationFolder.folderConversationIdentity(conversationId);
        if (identity == null) {
          kept[conversationId] = entry.value;
          continue;
        }
        final winner = winnerByIdentity[identity];
        if (winner != null &&
            winner.folderId == folder.folderId &&
            ConversationFolder.sameFolderConversation(
              winner.conversationId,
              conversationId,
            )) {
          kept[conversationId] = entry.value;
        } else {
          removed.add(conversationId);
        }
      }
      if (removed.isNotEmpty) {
        removedByFolderId[folder.folderId] = removed;
      }
      next.add(
        kept.length == folder.members.length
            ? folder
            : folder.copyWith(members: kept),
      );
    }

    next.sort(_compareFolders);
    return ExclusiveMembershipCollapse(
      folders: List<ConversationFolder>.unmodifiable(next),
      removedByFolderId: removedByFolderId,
    );
  }

  Future<void> ensureLoaded() async {
    final scope = _accountScope();
    if (_loadedAccountScope == scope) {
      return;
    }
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_storageKey());
    if (raw == null || raw.trim().isEmpty) {
      _loadedAccountScope = scope;
      foldersNotifier.value = const <ConversationFolder>[];
      return;
    }
    try {
      final decoded = jsonDecode(raw);
      final folders = <ConversationFolder>[];
      if (decoded is List) {
        for (final entry in decoded) {
          if (entry is! Map) {
            continue;
          }
          final folder = ConversationFolder.fromJson(
            Map<String, dynamic>.from(entry),
          );
          if (folder.folderId.isEmpty || folder.name.isEmpty) {
            continue;
          }
          folders.add(folder);
        }
      }
      final collapsed = collapseExclusiveMembership(folders);
      _loadedAccountScope = scope;
      foldersNotifier.value =
          List<ConversationFolder>.unmodifiable(collapsed.folders);
      if (collapsed.removedByFolderId.isNotEmpty) {
        await _persist();
      }
    } catch (e) {
      debugPrint('ConversationFolderStore: load failed: $e');
      _loadedAccountScope = scope;
      foldersNotifier.value = const <ConversationFolder>[];
    }
  }

  Future<void> replaceAll(List<ConversationFolder> folders) async {
    final collapsed = collapseExclusiveMembership(folders);
    foldersNotifier.value =
        List<ConversationFolder>.unmodifiable(collapsed.folders);
    _loadedAccountScope = _accountScope();
    await _persist();
  }

  Future<void> upsertFolder(ConversationFolder folder) async {
    final normalized = folder.scope == ConversationFolder.sharedScope
        ? folder
        : ConversationFolder(
            folderId: folder.folderId,
            name: folder.name,
            scope: ConversationFolder.sharedScope,
            sortOrder: folder.sortOrder,
            members: folder.members,
            updatedAt: folder.updatedAt,
            createdAt: folder.createdAt,
          );
    final next = [...foldersNotifier.value];
    final index =
        next.indexWhere((item) => item.folderId == normalized.folderId);
    if (index >= 0) {
      next[index] = normalized;
    } else {
      next.add(normalized);
    }
    final collapsed = collapseExclusiveMembership(next);
    foldersNotifier.value =
        List<ConversationFolder>.unmodifiable(collapsed.folders);
    await _persist();
  }

  Future<void> removeFolder(String folderId) async {
    final id = folderId.trim();
    if (id.isEmpty) {
      return;
    }
    final next = foldersNotifier.value
        .where((folder) => folder.folderId != id)
        .toList(growable: false);
    foldersNotifier.value = List<ConversationFolder>.unmodifiable(next);
    await _persist();
  }

  /// 将会话放入指定分组集合。产品约束：至多一个分组；传入多个时只保留赢家。
  Future<void> setMemberInFolders({
    required String conversationId,
    required Set<String> folderIds,
    int? memberUpdatedAt,
  }) async {
    final target = conversationId.trim();
    if (target.isEmpty) {
      return;
    }
    final wanted =
        folderIds.map((id) => id.trim()).where((id) => id.isNotEmpty).toSet();
    String? exclusiveFolderId;
    if (wanted.length == 1) {
      exclusiveFolderId = wanted.first;
    } else if (wanted.length > 1) {
      final candidates = foldersNotifier.value
          .where((folder) => wanted.contains(folder.folderId))
          .toList(growable: false);
      if (candidates.isNotEmpty) {
        candidates.sort(
          (a, b) => _compareMembershipClaim(
            memberUpdatedAt: a.memberUpdatedAt(target) ?? memberUpdatedAt,
            sortOrder: a.sortOrder,
            folderId: a.folderId,
            otherMemberUpdatedAt: b.memberUpdatedAt(target) ?? memberUpdatedAt,
            otherSortOrder: b.sortOrder,
            otherFolderId: b.folderId,
          ),
        );
        exclusiveFolderId = candidates.first.folderId;
      } else {
        exclusiveFolderId = wanted.first;
      }
    }
    final stamp = memberUpdatedAt ?? DateTime.now().millisecondsSinceEpoch;
    final next = <ConversationFolder>[];
    for (final folder in foldersNotifier.value) {
      final members = Map<String, int?>.from(folder.members);
      members.removeWhere(
        (id, _) => ConversationFolder.sameFolderConversation(id, target),
      );
      if (exclusiveFolderId != null && folder.folderId == exclusiveFolderId) {
        members[target] = stamp;
      }
      next.add(folder.copyWith(members: members));
    }
    next.sort(_compareFolders);
    foldersNotifier.value = List<ConversationFolder>.unmodifiable(next);
    await _persist();
  }

  Future<void> removeConversationFromAllFolders(String conversationId) async {
    await setMemberInFolders(
      conversationId: conversationId,
      folderIds: const <String>{},
    );
  }

  Future<void> clearSession() async {
    _loadedAccountScope = null;
    foldersNotifier.value = const <ConversationFolder>[];
  }

  /// 注销：删除该账号隔离的分组 prefs，并卸内存。
  Future<void> clearForOwner(String? ownerUserId) async {
    final scope = ContactSocialCacheStore.accountScopeForUserId(ownerUserId);
    if (scope.isEmpty || scope == '_guest') {
      await clearSession();
      return;
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('$_storagePrefix$scope');
    if (_loadedAccountScope == scope) {
      _loadedAccountScope = null;
      foldersNotifier.value = const <ConversationFolder>[];
    }
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = jsonEncode(
      foldersNotifier.value.map((f) => f.toJson()).toList(growable: false),
    );
    await prefs.setString(_storageKey(), encoded);
  }

  static int _compareFolders(ConversationFolder a, ConversationFolder b) {
    final byOrder = a.sortOrder.compareTo(b.sortOrder);
    if (byOrder != 0) {
      return byOrder;
    }
    return a.name.compareTo(b.name);
  }

  /// 成员赢家：memberUpdatedAt 降序 → sortOrder 升序 → folderId 升序。
  static int _compareMembershipClaim({
    required int? memberUpdatedAt,
    required int sortOrder,
    required String folderId,
    required int? otherMemberUpdatedAt,
    required int otherSortOrder,
    required String otherFolderId,
  }) {
    final aUpdated = memberUpdatedAt ?? 0;
    final bUpdated = otherMemberUpdatedAt ?? 0;
    final byUpdated = bUpdated.compareTo(aUpdated);
    if (byUpdated != 0) {
      return byUpdated;
    }
    final byOrder = sortOrder.compareTo(otherSortOrder);
    if (byOrder != 0) {
      return byOrder;
    }
    return folderId.compareTo(otherFolderId);
  }
}

class _MembershipClaim {
  const _MembershipClaim({
    required this.identity,
    required this.folderId,
    required this.conversationId,
    required this.memberUpdatedAt,
    required this.sortOrder,
  });

  final String identity;
  final String folderId;
  final String conversationId;
  final int? memberUpdatedAt;
  final int sortOrder;
}

int? _asInt(dynamic value) {
  if (value is int) {
    return value;
  }
  if (value is num) {
    return value.toInt();
  }
  return int.tryParse(value?.toString() ?? '');
}

int? _lookupMemberUpdatedAt(Map<String, int?> members, String target) {
  for (final entry in members.entries) {
    if (ConversationFolder.sameFolderConversation(entry.key, target)) {
      return entry.value;
    }
  }
  return null;
}
