import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:tencent_cloud_chat_demo/src/api/group_live_api.dart';
import 'package:tencent_cloud_chat_demo/src/models/group_live_models.dart';
import 'package:tencent_cloud_chat_demo/src/services/friend_realtime/friend_realtime_event.dart';
import 'package:tencent_cloud_chat_demo/src/services/group_live/group_live_index_store.dart';
import 'package:tencent_cloud_chat_demo/utils/chat_id_format.dart';

/// Fetches and patches the group live index for the conversation list.
class GroupLiveIndexSyncService {
  GroupLiveIndexSyncService._();

  static final GroupLiveIndexSyncService instance =
      GroupLiveIndexSyncService._();

  static const Duration _pollInterval = Duration(seconds: 45);

  final GroupLiveIndexStore _store = GroupLiveIndexStore.instance;

  Timer? _pollTimer;
  bool _tabVisible = false;
  bool _fetchInFlight = false;
  Future<void>? _fetchChain;

  GroupLiveIndexStore get store => _store;

  Future<void> fetchIndex({String reason = 'manual'}) {
    final next = (_fetchChain ?? Future<void>.value()).then(
      (_) => _fetchIndexOnce(reason: reason),
    );
    _fetchChain = next;
    return next;
  }

  void onGroupTabVisible() {
    _tabVisible = true;
    _startPolling();
    unawaited(fetchIndex(reason: 'group_tab_visible'));
  }

  void onGroupTabHidden() {
    _tabVisible = false;
    _stopPolling();
  }

  void onAppResumed() {
    if (_tabVisible) {
      unawaited(fetchIndex(reason: 'app_resumed'));
      _startPolling();
      return;
    }
    unawaited(fetchIndex(reason: 'app_resumed_cold'));
  }

  void reset() {
    _stopPolling();
    _tabVisible = false;
    _fetchChain = null;
    _store.clear();
  }

  Future<void> applyGroupLiveChanged(FriendRealtimeEvent event) async {
    if (event.event.trim() != 'group_changed') {
      return;
    }
    if (event.action?.trim().toLowerCase() != 'group_live_changed') {
      return;
    }
    final groupId = ChatIdFormat.normalizeGroupId(event.groupId);
    if (groupId.isEmpty) {
      return;
    }
    final detail = event.detail;
    if (detail == null || detail.isEmpty) {
      unawaited(fetchIndex(reason: 'tcp_group_live_changed_empty_detail'));
      return;
    }
    _store.applyTcpPatch(
      groupId: groupId,
      detail: Map<String, dynamic>.from(detail),
    );
  }

  void patchLocalSession(GroupLiveSession session, {int version = 0}) {
    _store.applyLocalSession(session, version: version);
  }

  Future<void> _fetchIndexOnce({required String reason}) async {
    if (_fetchInFlight) {
      return;
    }
    _fetchInFlight = true;
    try {
      final result = await GroupLiveApi.instance.liveIndex(
        ifNoneMatch: _store.etag,
      );
      switch (result.status) {
        case GroupLiveIndexFetchStatus.notModified:
          if (kDebugMode) {
            // ignore: avoid_print
            print('[GroupLiveIndex] 304 reason=$reason');
          }
          return;
        case GroupLiveIndexFetchStatus.updated:
          final snapshot = result.snapshot;
          if (snapshot == null) {
            return;
          }
          _store.applySnapshot(snapshot, etag: result.etag);
          if (kDebugMode) {
            // ignore: avoid_print
            print(
              '[GroupLiveIndex] updated reason=$reason '
              'revision=${snapshot.revision} items=${snapshot.items.length}',
            );
          }
      }
    } catch (e) {
      if (kDebugMode) {
        // ignore: avoid_print
        print('[GroupLiveIndex] fetch failed reason=$reason error=$e');
      }
    } finally {
      _fetchInFlight = false;
    }
  }

  void _startPolling() {
    if (!_tabVisible) {
      return;
    }
    _pollTimer ??= Timer.periodic(_pollInterval, (_) {
      unawaited(fetchIndex(reason: 'poll'));
    });
  }

  void _stopPolling() {
    _pollTimer?.cancel();
    _pollTimer = null;
  }
}
