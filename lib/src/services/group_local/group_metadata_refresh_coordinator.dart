import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:tencent_cloud_chat_demo/src/models/me_group_record.dart';
import 'package:tencent_cloud_chat_demo/src/services/group_local/group_info_resolver.dart';
import 'package:tencent_cloud_chat_demo/src/services/group_local/group_local_store.dart';
import 'package:tencent_cloud_chat_demo/src/services/group_local/group_membership_sync_service.dart';
import 'package:tencent_cloud_chat_demo/utils/chat_id_format.dart';

enum GroupMetadataSource { localPlaceholder, remoteDetail, storeCommit }

@immutable
class GroupMetadataSnapshot {
  const GroupMetadataSnapshot({
    required this.groupId,
    required this.name,
    required this.memberCount,
    required this.notice,
    required this.avatarUrl,
    required this.source,
    required this.generation,
  });

  final String groupId;
  final String name;
  final int? memberCount;
  final String notice;
  final String avatarUrl;
  final GroupMetadataSource source;
  final int generation;

  String get uiSignature =>
      '$name\u0000${memberCount ?? ''}\u0000$notice\u0000$avatarUrl';
}

/// One coherent group-display snapshot per canonical group ID.
class GroupMetadataRefreshCoordinator {
  GroupMetadataRefreshCoordinator({
    Future<MeGroupRecord?> Function(String groupId)? readLocal,
    Future<void> Function(String groupId)? refreshRemote,
    int Function()? readStoreVersion,
    this.throttle = const Duration(seconds: 60),
  })  : _readLocal = readLocal ?? GroupInfoResolver.instance.readGroup,
        _refreshRemote = refreshRemote ??
            ((groupId) => GroupMembershipSyncService.instance
                .refreshGroupDetail(groupId, refresh: true)),
        _readStoreVersion = readStoreVersion ??
            (() => GroupLocalStore.instance.listDataRevision);

  static final GroupMetadataRefreshCoordinator instance =
      GroupMetadataRefreshCoordinator();

  final Future<MeGroupRecord?> Function(String groupId) _readLocal;
  final Future<void> Function(String groupId) _refreshRemote;
  final int Function() _readStoreVersion;
  final Duration throttle;
  final Map<String, Future<GroupMetadataSnapshot?>> _inFlight = {};
  final Map<String, bool> _inFlightRefreshesRemote = {};
  final Map<String, int> _generation = {};
  final Map<String, DateTime> _lastRemoteRefresh = {};

  String _key(String groupId) {
    final normalized = ChatIdFormat.canonicalGroupStorageId(groupId);
    return normalized.isNotEmpty ? normalized : groupId.trim();
  }

  Future<GroupMetadataSnapshot?> readLocalPlaceholder(String groupId) async {
    final key = _key(groupId);
    if (key.isEmpty) return null;
    final generation = _generation[key] ?? 0;
    final record = await _readLocal(groupId);
    if ((_generation[key] ?? 0) != generation) return null;
    return _fromRecord(
      record,
      groupId: groupId,
      source: GroupMetadataSource.localPlaceholder,
      generation: _readStoreVersion(),
    );
  }

  Future<GroupMetadataSnapshot?> refresh(
    String groupId, {
    bool force = false,
  }) {
    final key = _key(groupId);
    if (key.isEmpty) return Future.value();
    final existing = _inFlight[key];
    if (existing != null) {
      if (!force || (_inFlightRefreshesRemote[key] ?? false)) {
        return existing;
      }
      // A forced invalidation must not be swallowed by an in-flight local-only
      // read that was throttled. Once that read settles, start (or join) the
      // authoritative remote refresh.
      return _refreshAfterExisting(groupId, existing);
    }
    final generation = _generation[key] ?? 0;
    final last = _lastRemoteRefresh[key];
    final refreshesRemote =
        force || last == null || DateTime.now().difference(last) >= throttle;
    final task = _refreshOnce(
      groupId,
      key: key,
      generation: generation,
      refreshRemote: refreshesRemote,
    );
    _inFlight[key] = task;
    _inFlightRefreshesRemote[key] = refreshesRemote;
    return task.whenComplete(() {
      if (identical(_inFlight[key], task)) {
        _inFlight.remove(key);
        _inFlightRefreshesRemote.remove(key);
      }
    });
  }

  Future<GroupMetadataSnapshot?> _refreshAfterExisting(
    String groupId,
    Future<GroupMetadataSnapshot?> existing,
  ) async {
    try {
      await existing;
    } catch (_) {
      // The forced invalidation still needs its own authoritative attempt.
    }
    return refresh(groupId, force: true);
  }

  Future<GroupMetadataSnapshot?> _refreshOnce(
    String groupId, {
    required String key,
    required int generation,
    required bool refreshRemote,
  }) async {
    if (refreshRemote) {
      await _refreshRemote(groupId);
      _lastRemoteRefresh[key] = DateTime.now();
    }
    final record = await _readLocal(groupId);
    if ((_generation[key] ?? 0) != generation) return null;
    return _fromRecord(
      record,
      groupId: groupId,
      source: GroupMetadataSource.remoteDetail,
      generation: _readStoreVersion(),
    );
  }

  GroupMetadataSnapshot? _fromRecord(
    MeGroupRecord? record, {
    required String groupId,
    required GroupMetadataSource source,
    required int generation,
  }) {
    if (record == null) return null;
    return GroupMetadataSnapshot(
      groupId: groupId,
      name: record.groupName.trim(),
      memberCount: record.memberCount > 0 ? record.memberCount : null,
      notice: record.notice.trim(),
      avatarUrl: record.avatarUrl.trim(),
      source: source,
      generation: generation,
    );
  }

  void invalidate(String groupId) {
    final key = _key(groupId);
    if (key.isEmpty) return;
    _generation[key] = (_generation[key] ?? 0) + 1;
    _lastRemoteRefresh.remove(key);
  }

  @visibleForTesting
  int generationFor(String groupId) => _generation[_key(groupId)] ?? 0;
}
