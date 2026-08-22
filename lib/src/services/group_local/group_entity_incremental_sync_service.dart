import 'dart:async';

import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tencent_cloud_chat_demo/src/api/me_group_api.dart';
import 'package:tencent_cloud_chat_demo/src/models/group_entity_change.dart';
import 'package:tencent_cloud_chat_demo/src/services/contact_social_cache_store.dart';
import 'package:tencent_cloud_chat_demo/src/services/group_local/group_membership_sync_service.dart';
import 'package:tencent_cloud_chat_demo/utils/chat_id_format.dart';

/// 群展示 Entity 游标增量补偿（非全量）。
///
/// `GET /me/groups/changes?since_seq=` → 只 upsert 变更群名/头像/公告。
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
        await _applyEvent(event);
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
  }

  Future<void> _applyEvent(GroupEntityChangeEvent event) async {
    if (!event.isInfoUpdated || event.groupId.isEmpty) {
      return;
    }
    final sync = GroupMembershipSyncService.instance;
    final name = event.groupName.trim();
    final avatar = event.avatarUrl.trim();
    final notice = event.notice.trim();
    final type = event.type.trim().toLowerCase();

    final wantName = name.isNotEmpty &&
        (type.contains('name') ||
            type.contains('info') ||
            type == 'group_info_updated');
    final wantAvatar = avatar.isNotEmpty &&
        (type.contains('avatar') ||
            type.contains('info') ||
            type == 'group_info_updated');
    final wantNotice = notice.isNotEmpty &&
        (type.contains('notice') ||
            type.contains('info') ||
            type == 'group_info_updated');

    // GROUP_INFO_UPDATED：有字段就写；专用 action 按字段。
    if (type == 'group_info_updated' || type.contains('info_updated')) {
      if (name.isNotEmpty) {
        await sync.applyOptimisticGroupName(
          groupId: event.groupId,
          groupName: name,
        );
      }
      if (avatar.isNotEmpty) {
        await sync.upsertGroupAvatar(
          groupId: event.groupId,
          avatarUrl: avatar,
        );
      }
      if (notice.isNotEmpty) {
        await sync.applyOptimisticNotice(
          groupId: event.groupId,
          notice: notice,
        );
      }
      if (name.isEmpty && avatar.isEmpty && notice.isEmpty) {
        await sync.refreshGroupDetail(event.groupId, refresh: true);
      }
      return;
    }

    if (wantName || (type.contains('name') && name.isEmpty)) {
      if (name.isNotEmpty) {
        await sync.applyOptimisticGroupName(
          groupId: event.groupId,
          groupName: name,
        );
      } else {
        await sync.refreshGroupDetail(event.groupId, refresh: true);
        return;
      }
    }
    if (wantAvatar || (type.contains('avatar') && avatar.isEmpty)) {
      if (avatar.isNotEmpty) {
        await sync.upsertGroupAvatar(
          groupId: event.groupId,
          avatarUrl: avatar,
        );
      } else {
        await sync.refreshGroupDetail(event.groupId, refresh: true);
        return;
      }
    }
    if (wantNotice) {
      await sync.applyOptimisticNotice(
        groupId: event.groupId,
        notice: notice,
      );
    }
  }

  /// TCP 事件若带 seq，向前推进游标（不回退）。
  Future<void> noteRealtimeSeq(int seq) async {
    if (seq <= 0) {
      return;
    }
    final owner = _ownerUserId();
    if (owner.isEmpty) {
      return;
    }
    final current = await readCursor(ownerUserId: owner);
    if (seq > current) {
      await writeCursor(seq, ownerUserId: owner);
    }
  }
}
