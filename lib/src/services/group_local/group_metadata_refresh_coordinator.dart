import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:tencent_cloud_chat_demo/src/models/me_group_record.dart';
import 'package:tencent_cloud_chat_demo/src/services/group_local/group_info_resolver.dart';
import 'package:tencent_cloud_chat_demo/src/services/group_local/group_membership_sync_service.dart';
import 'package:tencent_cloud_chat_demo/utils/chat_id_format.dart';

enum GroupMetadataSource { localPlaceholder, remoteDetail, explicitEvent }

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
    this.throttle = const Duration(seconds: 60),
  })  : _readLocal = readLocal ?? GroupInfoResolver.instance.readGroup,
        _refreshRemote = refreshRemote ??
            ((groupId) => GroupMembershipSyncService.instance
                .refreshGroupDetail(groupId, refresh: true));

  static final GroupMetadataRefreshCoordinator instance =
      GroupMetadataRefreshCoordinator();

  final Future<MeGroupRecord?> Function(String groupId) _readLocal;
  final Future<void> Function(String groupId) _refreshRemote;
  final Duration throttle;
  final Map<String, Future<GroupMetadataSnapshot?>> _inFlight = {};
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
      generation: generation,
    );
  }

  Future<GroupMetadataSnapshot?> refresh(
    String groupId, {
    bool force = false,
  }) {
    final key = _key(groupId);
    if (key.isEmpty) return Future.value();
    final existing = _inFlight[key];
    if (existing != null) return existing;
    final generation = _generation[key] ?? 0;
    final task = _refreshOnce(
      groupId,
      key: key,
      generation: generation,
      force: force,
    );
    _inFlight[key] = task;
    return task.whenComplete(() {
      if (identical(_inFlight[key], task)) _inFlight.remove(key);
    });
  }

  Future<GroupMetadataSnapshot?> _refreshOnce(
    String groupId, {
    required String key,
    required int generation,
    required bool force,
  }) async {
    final now = DateTime.now();
    final last = _lastRemoteRefresh[key];
    if (force || last == null || now.difference(last) >= throttle) {
      await _refreshRemote(groupId);
      _lastRemoteRefresh[key] = DateTime.now();
    }
    final record = await _readLocal(groupId);
    if ((_generation[key] ?? 0) != generation) return null;
    return _fromRecord(
      record,
      groupId: groupId,
      source: GroupMetadataSource.remoteDetail,
      generation: generation,
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
