import 'dart:async';

import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tencent_cloud_chat_demo/src/api/group_notice_api.dart';
import 'package:tencent_cloud_chat_demo/src/api/me_group_api.dart';
import 'package:tencent_cloud_chat_demo/src/models/group_notice_inbox_change.dart';
import 'package:tencent_cloud_chat_demo/src/services/contact_social_cache_store.dart';
import 'package:tencent_cloud_chat_demo/src/services/group_notice_feed_log.dart';
import 'package:tencent_cloud_chat_demo/src/services/group_system_notice_service.dart';
import 'package:tencent_cloud_chat_demo/utils/chat_id_format.dart';

/// 群系统通知 inbox 游标增量补偿（非全量）。
///
/// `GET /me/group-notices/changes?since_seq=` → upsert / 软删 / 已读水位。
class GroupNoticeIncrementalSyncService {
  GroupNoticeIncrementalSyncService._();

  static final GroupNoticeIncrementalSyncService instance =
      GroupNoticeIncrementalSyncService._();

  static const _cursorPrefix = 'group_notice_inbox_seq_';
  static const _pageLimit = 100;
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

  /// 冷启 / TCP auth / 快照后：按游标补洞。
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
    GroupNoticeFeedLog.log('inbox_sync_begin', extras: {
      'reason': reason,
      'ownerTail': owner.length <= 6 ? owner : owner.substring(owner.length - 6),
    });
    try {
      await _pullAndApply(owner: owner, reason: reason);
      GroupNoticeFeedLog.log('inbox_sync_done', extras: {'reason': reason});
    } on GroupNoticeInboxCursorExpiredException {
      GroupNoticeFeedLog.log('inbox_sync_cursor_expired', extras: {
        'reason': reason,
      });
      await clearCursor(ownerUserId: owner);
      try {
        await GroupSystemNoticeService.instance.refresh(force: true);
      } catch (_) {
        // 快照失败仍尝试用 since_seq=0 重建游标。
      }
      await writeCursor(0, ownerUserId: owner);
      await _pullAndApply(owner: owner, reason: '${reason}_after_snapshot');
      GroupNoticeFeedLog.log('inbox_sync_done', extras: {
        'reason': '${reason}_after_snapshot',
      });
    } on DioError catch (e) {
      final code = MeGroupApi.readDioCode(e).toUpperCase();
      GroupNoticeFeedLog.log('inbox_sync_dio', extras: {
        'reason': reason,
        'code': code,
        'status': e.response?.statusCode,
      });
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
      final page = await GroupNoticeApi.instance.fetchGroupNoticeInboxChanges(
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

  Future<void> _applyEvent(GroupNoticeInboxChangeEvent event) async {
    GroupNoticeFeedLog.log('inbox_event', extras: {
      'seq': event.seq,
      'kind': event.isReadWatermark
          ? 'READ_WATERMARK'
          : event.isDeleted
              ? 'DELETED'
              : event.isUpserted
                  ? 'UPSERT'
                  : 'OTHER',
      'noticeId': event.noticeId,
      'lastReadAtMs': event.lastReadAtMs,
    });
    if (event.isReadWatermark) {
      GroupSystemNoticeService.instance
          .applyRemoteReadWatermark(event.lastReadAtMs);
      return;
    }
    if (event.isDeleted) {
      final id = event.noticeId.trim();
      if (id.isEmpty) {
        return;
      }
      await GroupSystemNoticeService.instance.removeNoticeById(id);
      return;
    }
    if (event.isUpserted) {
      final record = event.toRecord();
      if (record == null) {
        GroupNoticeFeedLog.log('inbox_upsert_record_null', extras: {
          'seq': event.seq,
          'noticeId': event.noticeId,
        });
        return;
      }
      GroupSystemNoticeService.instance.upsertNotice(record.toUIKitNotice());
    }
  }

  /// TCP 事件若带 inbox seq，向前推进游标（不回退）。
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
