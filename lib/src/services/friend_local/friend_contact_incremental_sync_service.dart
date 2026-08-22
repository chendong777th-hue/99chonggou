import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tencent_cloud_chat_demo/src/api/me_friend_api.dart';
import 'package:tencent_cloud_chat_demo/src/models/friend_contact_change.dart';
import 'package:tencent_cloud_chat_demo/src/services/contact_social_cache_store.dart';
import 'package:tencent_cloud_chat_demo/src/services/friend_local/friend_sync_service.dart';
import 'package:tencent_cloud_chat_demo/src/services/friend_realtime/friend_realtime_event.dart';
import 'package:tencent_cloud_chat_demo/utils/chat_id_format.dart';

/// 好友通讯录 Versioned Sync（Difference + Snapshot 回退）。
///
/// `GET /me/friends/changes?since_seq=` → 按 type/tcpAction upsert/删除；
/// 游标过期 → Snapshot `/me/friends` + `syncSeq` 重置。
class FriendContactIncrementalSyncService {
  FriendContactIncrementalSyncService._();

  static final FriendContactIncrementalSyncService instance =
      FriendContactIncrementalSyncService._();

  static const _cursorPrefix = 'last_friend_contact_seq_';
  static const _pageLimit = 100;
  static const _maxPagesPerRun = 50;

  Future<void>? _inFlight;
  String? _inFlightOwner;
  int _pullGeneration = 0;

  @visibleForTesting
  String? debugOwnerUserId;

  @visibleForTesting
  int get debugPullGeneration => _pullGeneration;

  /// 成友后作废进行中的 Difference，避免用同意前的响应把游标推过 CONTACT_CREATED。
  void invalidateInFlightPull() {
    _pullGeneration++;
  }

  String _ownerUserId() {
    final override = debugOwnerUserId?.trim();
    if (override != null && override.isNotEmpty) {
      return override;
    }
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
    _pullGeneration++;
    _inFlight = null;
    _inFlightOwner = null;
    if (owner.isNotEmpty) {
      await clearCursor(ownerUserId: owner);
    }
  }

  /// Snapshot 成功后用响应 `syncSeq` 重置游标（可回退）。
  Future<void> resetCursorFromSnapshot(
    int syncSeq, {
    String? ownerUserId,
  }) async {
    final owner = (ownerUserId ?? _ownerUserId()).trim();
    if (owner.isEmpty) {
      return;
    }
    final seq = syncSeq < 0 ? 0 : syncSeq;
    await writeCursor(seq, ownerUserId: owner);
  }

  /// 冷启 / TCP auth / 成友后：按游标补洞。
  ///
  /// [restart] 为 true 时不沿用进行中的旧拉取（同意好友后必须重拉，否则会漏 CONTACT_CREATED）。
  Future<void> sync({
    String reason = 'manual',
    bool restart = false,
  }) {
    final owner = _ownerUserId();
    if (owner.isEmpty) {
      return Future<void>.value();
    }
    if (restart) {
      _pullGeneration++;
    }
    final active = _inFlight;
    if (active != null && _inFlightOwner == owner && !restart) {
      return active;
    }
    late final Future<void> task;
    final generation = _pullGeneration;
    _inFlightOwner = owner;
    task = _runSync(
      owner: owner,
      reason: reason,
      generation: generation,
    ).whenComplete(() {
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
    required int generation,
  }) async {
    try {
      await _pullAndApply(
        owner: owner,
        reason: reason,
        generation: generation,
      );
    } on FriendContactSnapshotRequiredException {
      if (generation != _pullGeneration) {
        return;
      }
      await clearCursor(ownerUserId: owner);
      try {
        await FriendSyncService.instance.syncFull(
          reason: 'friend_contact_snapshot_required_$reason',
        );
      } catch (_) {
        // 快照失败仍尝试 since_seq=0 重建。
      }
      if (generation != _pullGeneration) {
        return;
      }
      await _pullAndApply(
        owner: owner,
        reason: '${reason}_after_snapshot',
        generation: generation,
      );
    } on DioError catch (e) {
      final code = MeFriendApi.readDioCode(e).toUpperCase();
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
    required int generation,
  }) async {
    var since = await readCursor(ownerUserId: owner);
    var pages = 0;
    var anyApplied = false;
    while (pages < _maxPagesPerRun) {
      if (_ownerUserId() != owner || generation != _pullGeneration) {
        return;
      }
      pages += 1;
      final page = await MeFriendApi.instance.fetchFriendsChanges(
        sinceSeq: since,
        limit: _pageLimit,
      );
      if (generation != _pullGeneration) {
        return;
      }
      for (final event in page.events) {
        if (_ownerUserId() != owner || generation != _pullGeneration) {
          return;
        }
        final applied = await _applyEvent(event);
        if (applied) {
          anyApplied = true;
        }
      }
      if (generation != _pullGeneration) {
        return;
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
    if (anyApplied && generation == _pullGeneration) {
      await FriendSyncService.instance.refreshUIKitLists(force: true);
    }
  }

  Future<bool> _applyEvent(FriendContactChangeEvent event) async {
    if (event.peerUserId.isEmpty && event.seq <= 0) {
      return false;
    }
    final action = event.resolvedTcpAction;
    if (action.isEmpty) {
      return false;
    }
    return FriendSyncService.instance.applyListChanged(
      FriendRealtimeEvent(
        event: 'friend_list_changed',
        fromUserId: '',
        toUserId: '',
        action: action,
        peerUserId: event.peerUserId,
        peerNickname: event.peerNickname,
        peerAvatarUrl: event.peerAvatarUrl,
        remark: event.remark,
        inMyFriendList: event.inMyFriendList,
        isFriend: event.isFriend,
        peerDeletedMe: event.peerDeletedMe,
        canMessage: event.canMessage,
        lastActiveAt: event.lastActiveAt,
        lastActiveVisibility: event.lastActiveVisibility,
        seq: event.seq > 0 ? event.seq : null,
      ),
      fromDifference: true,
    );
  }

  /// TCP 事件带 `seq` 时：仅连续推进游标，禁止跳号以免漏 Difference。
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

  /// TCP 去重：`seq <= cursor` 视为已由 Difference/前序事件覆盖。
  Future<bool> shouldApplyRealtimeSeq(int? seq) async {
    if (seq == null || seq <= 0) {
      return true;
    }
    final current = await readCursor();
    return seq > current;
  }
}
