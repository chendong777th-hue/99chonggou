import 'dart:async';

import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tencent_cloud_chat_demo/src/api/me_group_api.dart';
import 'package:tencent_cloud_chat_demo/src/models/group_member_change.dart';
import 'package:tencent_cloud_chat_demo/src/models/me_group_record.dart';
import 'package:tencent_cloud_chat_demo/src/services/contact_social_cache_store.dart';
import 'package:tencent_cloud_chat_demo/src/services/group_local/group_local_store.dart';
import 'package:tencent_cloud_chat_demo/src/services/group_local/group_member_local_store.dart';
import 'package:tencent_cloud_chat_demo/src/services/group_local/group_membership_sync_service.dart';
import 'package:tencent_cloud_chat_demo/utils/chat_id_format.dart';

/// 群成员流游标增量补偿（按群）。
///
/// `GET /me/groups/{id}/members/changes?since_seq=` → upsert/删除成员 + 权威人数。
class GroupMemberIncrementalSyncService {
  GroupMemberIncrementalSyncService._();

  static final GroupMemberIncrementalSyncService instance =
      GroupMemberIncrementalSyncService._();

  static const _cursorPrefix = 'group_member_seq_';
  static const _pageLimit = 100;
  static const _maxPagesPerGroup = 50;
  static const _maxGroupsPerRun = 80;
  static const _groupConcurrency = 3;

  final Map<String, Future<void>> _inFlightByGroup = <String, Future<void>>{};
  Future<void>? _syncAllInFlight;
  String? _syncAllOwner;

  String _ownerUserId() {
    return ChatIdFormat.rawUserUid(ContactSocialCacheStore.safeLoginUserId());
  }

  String _cursorKey(String owner, String groupId) {
    final gid = ChatIdFormat.normalizeGroupId(groupId);
    return '$_cursorPrefix${owner}_$gid';
  }

  Future<int> readCursor({
    required String groupId,
    String? ownerUserId,
  }) async {
    final owner = (ownerUserId ?? _ownerUserId()).trim();
    final gid = ChatIdFormat.normalizeGroupId(groupId);
    if (owner.isEmpty || gid.isEmpty) {
      return 0;
    }
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_cursorKey(owner, gid)) ?? 0;
  }

  Future<void> writeCursor(
    int seq, {
    required String groupId,
    String? ownerUserId,
  }) async {
    final owner = (ownerUserId ?? _ownerUserId()).trim();
    final gid = ChatIdFormat.normalizeGroupId(groupId);
    if (owner.isEmpty || gid.isEmpty || seq < 0) {
      return;
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_cursorKey(owner, gid), seq);
  }

  Future<void> clearCursor({
    required String groupId,
    String? ownerUserId,
  }) async {
    final owner = (ownerUserId ?? _ownerUserId()).trim();
    final gid = ChatIdFormat.normalizeGroupId(groupId);
    if (owner.isEmpty || gid.isEmpty) {
      return;
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_cursorKey(owner, gid));
  }

  Future<void> clearSession() async {
    final owner = _ownerUserId();
    _inFlightByGroup.clear();
    _syncAllInFlight = null;
    _syncAllOwner = null;
    if (owner.isEmpty) {
      return;
    }
    final prefs = await SharedPreferences.getInstance();
    final prefix = '$_cursorPrefix${owner}_';
    final keys = prefs.getKeys().where((k) => k.startsWith(prefix)).toList();
    for (final key in keys) {
      await prefs.remove(key);
    }
  }

  /// TCP `detail.seq`（成员流，勿用 groupSeq）前进游标。
  Future<void> noteRealtimeSeq({
    required String groupId,
    required int seq,
  }) async {
    if (seq <= 0) {
      return;
    }
    final owner = _ownerUserId();
    final gid = ChatIdFormat.normalizeGroupId(groupId);
    if (owner.isEmpty || gid.isEmpty) {
      return;
    }
    final current = await readCursor(groupId: gid, ownerUserId: owner);
    if (seq > current) {
      await writeCursor(seq, groupId: gid, ownerUserId: owner);
    }
  }

  /// 单群增量。
  Future<void> syncForGroup(
    String groupId, {
    String reason = 'manual',
  }) {
    final owner = _ownerUserId();
    final gid = ChatIdFormat.normalizeGroupId(groupId);
    if (owner.isEmpty || gid.isEmpty) {
      return Future<void>.value();
    }
    final key = '$owner|$gid';
    final active = _inFlightByGroup[key];
    if (active != null) {
      return active;
    }
    late final Future<void> task;
    task = _runSyncForGroup(
      owner: owner,
      groupId: gid,
      reason: reason,
    ).whenComplete(() {
      if (identical(_inFlightByGroup[key], task)) {
        _inFlightByGroup.remove(key);
      }
    });
    _inFlightByGroup[key] = task;
    return task;
  }

  /// 冷启 / 重连：遍历已加入群补成员流（限流）。
  Future<void> syncAllJoined({String reason = 'manual'}) {
    final owner = _ownerUserId();
    if (owner.isEmpty) {
      return Future<void>.value();
    }
    final active = _syncAllInFlight;
    if (active != null && _syncAllOwner == owner) {
      return active;
    }
    late final Future<void> task;
    _syncAllOwner = owner;
    task = _runSyncAllJoined(owner: owner, reason: reason).whenComplete(() {
      if (identical(_syncAllInFlight, task)) {
        _syncAllInFlight = null;
        _syncAllOwner = null;
      }
    });
    _syncAllInFlight = task;
    return task;
  }

  Future<void> _runSyncAllJoined({
    required String owner,
    required String reason,
  }) async {
    List<MeGroupRecord> groups;
    try {
      groups = await GroupLocalStore.instance.readAll(ownerUserId: owner);
    } catch (_) {
      return;
    }
    final ids = groups
        .map((g) => ChatIdFormat.normalizeGroupId(g.groupId))
        .where((id) => id.isNotEmpty)
        .take(_maxGroupsPerRun)
        .toList(growable: false);
    if (ids.isEmpty) {
      return;
    }
    for (var i = 0; i < ids.length; i += _groupConcurrency) {
      if (_ownerUserId() != owner) {
        return;
      }
      final chunk = ids.skip(i).take(_groupConcurrency);
      await Future.wait(
        chunk.map(
          (id) => syncForGroup(id, reason: reason),
        ),
      );
    }
  }

  Future<void> _runSyncForGroup({
    required String owner,
    required String groupId,
    required String reason,
  }) async {
    try {
      await _pullAndApply(owner: owner, groupId: groupId, reason: reason);
    } on GroupMemberCursorExpiredException {
      await clearCursor(groupId: groupId, ownerUserId: owner);
      try {
        await GroupMembershipSyncService.instance
            .syncMembersAfterMembershipChange(
          groupId,
          reason: 'member_cursor_expired_$reason',
        );
      } catch (_) {}
      await writeCursor(0, groupId: groupId, ownerUserId: owner);
      await _pullAndApply(
        owner: owner,
        groupId: groupId,
        reason: '${reason}_after_snapshot',
      );
    } on DioError catch (e) {
      final code = MeGroupApi.readDioCode(e).toUpperCase();
      if (code.contains('NOT_FOUND') ||
          e.response?.statusCode == 404 ||
          code.contains('NO_ROUTE')) {
        return;
      }
      rethrow;
    }
  }

  Future<void> _pullAndApply({
    required String owner,
    required String groupId,
    required String reason,
  }) async {
    var since = await readCursor(groupId: groupId, ownerUserId: owner);
    var pages = 0;
    var applied = false;
    var lastAction = 'member_added';
    while (pages < _maxPagesPerGroup) {
      if (_ownerUserId() != owner) {
        return;
      }
      pages += 1;
      final page = await MeGroupApi.instance.fetchGroupMemberChanges(
        groupId: groupId,
        sinceSeq: since,
        limit: _pageLimit,
      );
      for (final event in page.events) {
        if (_ownerUserId() != owner) {
          return;
        }
        final did = await _applyEvent(
          owner: owner,
          groupId: groupId,
          event: event,
        );
        if (did) {
          applied = true;
          if (event.isRemoved) {
            lastAction = 'member_removed';
          } else if (event.isUpserted) {
            lastAction = 'member_added';
          }
        }
      }
      if (page.memberCount > 0) {
        await GroupMembershipSyncService.instance.patchMemberCountForSync(
          groupId: groupId,
          memberCount: page.memberCount,
        );
        applied = true;
      }
      final next = page.nextSeq > since ? page.nextSeq : since;
      if (next != since) {
        since = next;
        await writeCursor(since, groupId: groupId, ownerUserId: owner);
      } else if (page.events.isNotEmpty) {
        final maxSeq = page.events.fold<int>(
          since,
          (m, e) => e.seq > m ? e.seq : m,
        );
        if (maxSeq > since) {
          since = maxSeq;
          await writeCursor(since, groupId: groupId, ownerUserId: owner);
        }
      }
      if (!page.hasMore) {
        break;
      }
      if (page.events.isEmpty && page.nextSeq <= since) {
        break;
      }
    }
    if (applied) {
      GroupMembershipSyncService.instance
          .notifyProfileRefresh(groupId, memberList: true);
      GroupMembershipSyncService.instance.notifyMembershipChatHeader(
        groupId,
        action: lastAction,
      );
    }
  }

  Future<bool> _applyEvent({
    required String owner,
    required String groupId,
    required GroupMemberChangeEvent event,
  }) async {
    final gid = ChatIdFormat.normalizeGroupId(
      event.groupId.isNotEmpty ? event.groupId : groupId,
    );
    if (gid.isEmpty) {
      return false;
    }
    if (event.isRemoved) {
      final uid = ChatIdFormat.rawUserUid(event.userId);
      if (uid.isEmpty) {
        return false;
      }
      await GroupMemberLocalStore.instance.deleteUsers(
        ownerUserId: owner,
        groupId: gid,
        userIds: <String>[uid],
      );
      if (event.memberCount > 0) {
        await GroupMembershipSyncService.instance.patchMemberCountForSync(
          groupId: gid,
          memberCount: event.memberCount,
        );
      }
      return true;
    }
    if (event.isUpserted) {
      final record = event.toMemberRecord(ownerUserId: owner);
      if (record == null) {
        return false;
      }
      await GroupMemberLocalStore.instance.upsertMany(
        ownerUserId: owner,
        groupId: gid,
        records: <GroupMemberRecord>[record],
      );
      if (event.memberCount > 0) {
        await GroupMembershipSyncService.instance.patchMemberCountForSync(
          groupId: gid,
          memberCount: event.memberCount,
        );
      }
      return true;
    }
    return false;
  }
}
