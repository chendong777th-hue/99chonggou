import 'dart:async';

import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tencent_cloud_chat_demo/src/api/me_group_api.dart';
import 'package:tencent_cloud_chat_demo/src/models/group_entity_change.dart';
import 'package:tencent_cloud_chat_demo/src/services/contact_social_cache_store.dart';
import 'package:tencent_cloud_chat_demo/src/services/group_local/group_membership_sync_service.dart';
import 'package:tencent_cloud_chat_demo/src/services/group_local/group_metadata_refresh_coordinator.dart';
import 'package:tencent_cloud_chat_demo/utils/chat_id_format.dart';

/// 群展示 Entity 游标增量补偿（非全量）。
///
/// `GET /me/groups/changes?since_seq=` → 汇总变更群并刷新当前群详情。
class GroupEntityIncrementalSyncService {
  GroupEntityIncrementalSyncService._();

  static final GroupEntityIncrementalSyncService instance =
      GroupEntityIncrementalSyncService._();

  static const _cursorPrefix = 'group_entity_seq_';
  static const _pageLimit = 200;
  static const _maxPagesPerRun = 50;

  Future<void>? _inFlight;
  String? _inFlightOwner;

  String _ownerUserId() {
    return ChatIdFormat.rawUserUid(ContactSocialCacheStore.safeLoginUserId());
  }

  String _cursorKey(String owner) => '$_cursorPrefix$owner';

  Future<int> readCursor({String? ownerUserId}) async {
    final owner = (ownerUserId ?? _ownerUserId()).trim();
    if (owner.isEmpty) {
      return 0;
    }
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_cursorKey(owner)) ?? 0;
  }

  Future<void> writeCursor(int seq, {String? ownerUserId}) async {
    final owner = (ownerUserId ?? _ownerUserId()).trim();
    if (owner.isEmpty || seq < 0) {
      return;
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_cursorKey(owner), seq);
  }

  Future<void> clearCursor({String? ownerUserId}) async {
    final owner = (ownerUserId ?? _ownerUserId()).trim();
    if (owner.isEmpty) {
      return;
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_cursorKey(owner));
  }

  Future<void> clearSession() async {
    final owner = _ownerUserId();
    _inFlight = null;
    _inFlightOwner = null;
    if (owner.isNotEmpty) {
      await clearCursor(ownerUserId: owner);
    }
  }

  /// 冷启 / TCP auth / 快照后：按游标补洞，禁止扫全群详情。
  Future<void> sync({String reason = 'manual'}) {
    final owner = _ownerUserId();
    if (owner.isEmpty) {
      return Future<void>.value();
    }
    final active = _inFlight;
    if (active != null && _inFlightOwner == owner) {
      return active;
    }
    late final Future<void> task;
    _inFlightOwner = owner;
    task = _runSync(owner: owner, reason: reason).whenComplete(() {
      if (identical(_inFlight, task)) {
        _inFlight = null;
        _inFlightOwner = null;
      }
    });
    _inFlight = task;
    return task;
  }

  Future<void> _runSync({
    required String owner,
    required String reason,
  }) async {
    try {
      await _pullAndApply(owner: owner, reason: reason);
    } on GroupEntityCursorExpiredException {
      await clearCursor(ownerUserId: owner);
      try {
        await GroupMembershipSyncService.instance.syncFull(
          reason: 'entity_cursor_expired_$reason',
          refresh: true,
        );
      } catch (_) {
        // 快照失败仍尝试用 since_seq=0 重建游标。
      }
      await writeCursor(0, ownerUserId: owner);
      await _pullAndApply(owner: owner, reason: '${reason}_after_snapshot');
    } on DioError catch (e) {
      final code = MeGroupApi.readDioCode(e).toUpperCase();
      // 后端未部署时静默跳过，避免打断冷启。
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
    required String reason,
  }) async {
    var since = await readCursor(ownerUserId: owner);
    var pages = 0;
    final changedGroups = <String>{};
    while (pages < _maxPagesPerRun) {
      if (_ownerUserId() != owner) {
        return;
      }
      pages += 1;
      final page = await MeGroupApi.instance.fetchGroupEntityChanges(
        sinceSeq: since,
        limit: _pageLimit,
      );
      for (final event in page.events) {
        if (_ownerUserId() != owner) {
          return;
        }
        if (event.isInfoUpdated) {
          final groupId = ChatIdFormat.canonicalGroupStorageId(event.groupId);
          if (groupId.isNotEmpty) {
            changedGroups.add(groupId);
          }
        }
      }
      final next = page.nextSeq > since ? page.nextSeq : since;
      if (next != since) {
        since = next;
        await writeCursor(since, ownerUserId: owner);
      } else if (page.events.isNotEmpty) {
        final maxSeq = page.events.fold<int>(
          since,
          (m, e) => e.seq > m ? e.seq : m,
        );
        if (maxSeq > since) {
          since = maxSeq;
          await writeCursor(since, ownerUserId: owner);
        }
      }
      if (!page.hasMore) {
        break;
      }
      if (page.events.isEmpty && page.nextSeq <= since) {
        break;
      }
    }
    // A page may contain many historical changes for the same group. Fetch
    // one current detail snapshot per group after consuming the cursor; never
    // apply event payload fields in sequence.
    for (final groupId in changedGroups) {
      if (_ownerUserId() != owner) {
        return;
      }
      await GroupMetadataRefreshCoordinator.instance
          .refresh(groupId, force: true);
    }
  }

  /// TCP 事件若带 seq，仅连续时推进游标；有缺口时交给 Difference 补齐。
  Future<void> noteRealtimeSeq(int seq) async {
    if (seq <= 0) {
      return;
    }
    final owner = _ownerUserId();
    if (owner.isEmpty) {
      return;
    }
    final current = await readCursor(ownerUserId: owner);
    if (seq == current + 1) {
      await writeCursor(seq, ownerUserId: owner);
    }
  }
}
