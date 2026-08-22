import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:tencent_cloud_chat_demo/src/api/group_join_api.dart';
import 'package:tencent_cloud_chat_demo/src/api/me_group_api.dart';
import 'package:tencent_cloud_chat_demo/src/models/group_join_option.dart';
import 'package:tencent_cloud_chat_demo/src/models/me_group_record.dart';
import 'package:tencent_cloud_chat_demo/src/services/contact_social_cache_store.dart';
import 'package:tencent_cloud_chat_demo/src/services/group_local/group_local_store.dart';
import 'package:tencent_cloud_chat_demo/utils/chat_id_format.dart';
import 'package:tencent_cloud_chat_sdk/enum/group_member_role.dart';

/// REST 建群群主角色（与 `GroupProfileView.myRole` 一致）。
const int kGroupCreateOwnerRole = 400;

const _recoveryDelays = <Duration>[
  Duration.zero,
  Duration(milliseconds: 800),
  Duration(milliseconds: 2000),
  Duration(milliseconds: 4000),
];

class GroupCreateParams {
  const GroupCreateParams({
    required this.groupType,
    required this.groupName,
    this.memberUserIds = const <String>[],
    this.avatarUrl,
    this.introduction,
  });

  final String groupType;
  final String groupName;
  final List<String> memberUserIds;
  final String? avatarUrl;
  final String? introduction;
}

class GroupCreateOutcome {
  const GroupCreateOutcome({
    required this.record,
    required this.isNewGroup,
  });

  final MeGroupRecord record;
  final bool isNewGroup;
}

/// 建群单飞 + 5xx/超时后 recovery（快照 diff + `GET /me/groups?refresh=true`）。
class GroupCreateService {
  GroupCreateService._();

  static final GroupCreateService instance = GroupCreateService._();

  bool _creating = false;
  Set<String> _lastSnapshotGroupIds = const <String>{};
  GroupCreateParams? _lastCreateParams;
  int _lastAttemptStartedAtMs = 0;
  int _createFlowGeneration = 0;

  bool get isCreating => _creating;

  /// 每次用户发起建群时递增；仅最新一代才应执行跳转聊天页，
  /// 避免高频连建时较慢的旧请求在较晚完成时覆盖新群页面。
  int beginCreateFlow() => ++_createFlowGeneration;

  bool isLatestCreateFlow(int generation) =>
      generation > 0 && generation == _createFlowGeneration;

  Future<GroupCreateOutcome?> createWithRecovery(GroupCreateParams params) async {
    if (_creating) {
      return null;
    }
    _creating = true;
    final attemptStartedAtMs = DateTime.now().millisecondsSinceEpoch;
    final snapshotGroupIds = await _snapshotGroupIds();
    _lastCreateParams = params;
    _lastSnapshotGroupIds = snapshotGroupIds;
    _lastAttemptStartedAtMs = attemptStartedAtMs;
    try {
      final record = await _createOnce(params);
      if (record.groupId.trim().isNotEmpty) {
        return GroupCreateOutcome(record: record, isNewGroup: true);
      }
      debugPrint(
        'GroupCreateService: POST /group returned empty groupId, attempting recovery',
      );
      return _outcomeFromRecoveredRecord(
        await _tryRecoverRecentlyCreatedGroup(
          params: params,
          attemptStartedAtMs: attemptStartedAtMs,
          snapshotGroupIds: snapshotGroupIds,
        ),
        snapshotGroupIds: snapshotGroupIds,
      );
    } on DioError catch (e) {
      if (!shouldAttemptGroupCreateRecovery(e)) {
        rethrow;
      }
      final recovered = await _tryRecoverRecentlyCreatedGroup(
        params: params,
        attemptStartedAtMs: attemptStartedAtMs,
        snapshotGroupIds: snapshotGroupIds,
      );
      final outcome = _outcomeFromRecoveredRecord(
        recovered,
        snapshotGroupIds: snapshotGroupIds,
      );
      if (outcome != null) {
        debugPrint(
          'GroupCreateService: recovered group ${outcome.record.groupId} after '
          '${MeGroupApi.readDioCode(e)} isNewGroup=${outcome.isNewGroup} '
          'memberCount=${outcome.record.memberCount} '
          'expectedMembers=${params.memberUserIds.length}',
        );
        return outcome;
      }
      debugPrint(
        'GroupCreateService: recovery failed after ${MeGroupApi.readDioCode(e)}',
      );
      rethrow;
    } finally {
      _creating = false;
    }
  }

  /// 失败提示前最后一轮 recovery（使用本次建群前的快照 diff）。
  Future<GroupCreateOutcome?> recoverAfterFailure() async {
    final params = _lastCreateParams;
    if (params == null) {
      return null;
    }
    return _outcomeFromRecoveredRecord(
      await _tryRecoverRecentlyCreatedGroup(
        params: params,
        attemptStartedAtMs: _lastAttemptStartedAtMs,
        snapshotGroupIds: _lastSnapshotGroupIds,
        delays: const [
          Duration(milliseconds: 1200),
          Duration(milliseconds: 2500),
        ],
      ),
      snapshotGroupIds: _lastSnapshotGroupIds,
    );
  }

  GroupCreateOutcome? _outcomeFromRecoveredRecord(
    MeGroupRecord? record, {
    required Set<String> snapshotGroupIds,
  }) {
    if (record == null || record.groupId.trim().isEmpty) {
      return null;
    }
    final groupId = record.groupId.trim();
    return GroupCreateOutcome(
      record: record,
      isNewGroup: !snapshotGroupIds.contains(groupId),
    );
  }

  Future<MeGroupRecord> _createOnce(GroupCreateParams params) {
    return MeGroupApi.instance.createGroup(
      groupType: params.groupType,
      groupName: params.groupName,
      memberUserIds: params.memberUserIds,
      avatarUrl: params.avatarUrl,
      joinOptions: GroupJoinApi.isSelfHostedJoinGroupType(params.groupType)
          ? const GroupJoinOptions(
              applyJoinOption: GroupJoinOption.needPermission,
              inviteJoinOption: GroupJoinOption.needPermission,
              allowJoinByQrCode: true,
              allowJoinByAlias: true,
            )
          : null,
      introduction: params.introduction,
    );
  }

  Future<Set<String>> _snapshotGroupIds() async {
    final owner = _currentUserId();
    if (owner.isEmpty) {
      return const <String>{};
    }
    final local = await GroupLocalStore.instance.readAll(ownerUserId: owner);
    return local
        .map((group) => group.groupId.trim())
        .where((id) => id.isNotEmpty)
        .toSet();
  }

  String _currentUserId() {
    return ChatIdFormat.rawUserUid(ContactSocialCacheStore.safeLoginUserId());
  }

  Future<MeGroupRecord?> _tryRecoverRecentlyCreatedGroup({
    required GroupCreateParams params,
    required int attemptStartedAtMs,
    required Set<String> snapshotGroupIds,
    List<Duration> delays = _recoveryDelays,
  }) async {
    final currentUserId = _currentUserId();
    for (final delay in delays) {
      if (delay > Duration.zero) {
        await Future.delayed(delay);
      }

      final local = await GroupLocalStore.instance.readAll(
        ownerUserId: currentUserId,
      );
      final fromLocalSnapshot = findRecoverableGroupBySnapshot(
        groups: local,
        beforeGroupIds: snapshotGroupIds,
        attemptStartedAtMs: attemptStartedAtMs,
        preferredGroupName: params.groupName,
        preferredGroupType: params.groupType,
        currentUserId: currentUserId,
      );
      if (fromLocalSnapshot != null) {
        return fromLocalSnapshot;
      }

      final fromLocalName = findRecoverableCreatedGroup(
        groups: local,
        groupName: params.groupName,
        groupType: params.groupType,
        attemptStartedAtMs: attemptStartedAtMs,
        currentUserId: currentUserId,
        excludeGroupIds: snapshotGroupIds,
      );
      if (fromLocalName != null) {
        return fromLocalName;
      }

      try {
        final networkGroups = await MeGroupApi.instance.fetchMyGroupsFromNetwork(
          refresh: true,
        );
        final fromNetworkSnapshot = findRecoverableGroupBySnapshot(
          groups: networkGroups,
          beforeGroupIds: snapshotGroupIds,
          attemptStartedAtMs: attemptStartedAtMs,
          preferredGroupName: params.groupName,
          preferredGroupType: params.groupType,
          currentUserId: currentUserId,
        );
        if (fromNetworkSnapshot != null) {
          return fromNetworkSnapshot;
        }

        final fromNetworkName = findRecoverableCreatedGroup(
          groups: networkGroups,
          groupName: params.groupName,
          groupType: params.groupType,
          attemptStartedAtMs: attemptStartedAtMs,
          currentUserId: currentUserId,
          excludeGroupIds: snapshotGroupIds,
        );
        if (fromNetworkName != null) {
          return fromNetworkName;
        }
      } catch (e) {
        debugPrint('GroupCreateService: recovery fetch failed: $e');
      }
    }
    return null;
  }
}

bool isGroupCreateOwnerRole(int role) {
  return role == kGroupCreateOwnerRole ||
      role == GroupMemberRoleType.V2TIM_GROUP_MEMBER_ROLE_OWNER;
}

bool isRecoverableCreatedGroup(
  MeGroupRecord group, {
  required String currentUserId,
}) {
  if (isGroupCreateOwnerRole(group.myRole)) {
    return true;
  }
  if (currentUserId.isEmpty) {
    return false;
  }
  final owner = ChatIdFormat.rawUserUid(group.ownerUserId);
  return owner.isNotEmpty && owner == currentUserId;
}

bool shouldAttemptGroupCreateRecovery(DioError error) {
  final code = MeGroupApi.readDioCode(error).trim().toUpperCase();
  const blocked = {
    'CREATE_LIMIT_EXCEEDED',
    'GROUP_CREATE_LIMIT_COMMUNITY',
    'GROUP_JOIN_LIMIT_EXCEEDED',
    'GROUP_JOIN_LIMIT',
    'GROUP_JOIN_LIMIT_COMMUNITY',
    'NOT_FRIEND',
    'INVALID_INPUT',
    'GROUP_TYPE_NOT_SUPPORTED',
    'BATCH_TOO_LARGE',
  };
  if (blocked.contains(code)) {
    return false;
  }

  switch (error.type) {
    case DioErrorType.connectTimeout:
    case DioErrorType.sendTimeout:
    case DioErrorType.receiveTimeout:
    case DioErrorType.other:
    case DioErrorType.cancel:
      return true;
    default:
      break;
  }

  final status = error.response?.statusCode ?? 0;
  if (status >= 500) {
    return true;
  }
  if (status >= 200 && status < 300) {
    return true;
  }
  if (status == 0) {
    return true;
  }
  return false;
}

MeGroupRecord? findRecoverableGroupBySnapshot({
  required List<MeGroupRecord> groups,
  required Set<String> beforeGroupIds,
  required int attemptStartedAtMs,
  String? preferredGroupName,
  String? preferredGroupType,
  String? currentUserId,
  int? nowMs,
}) {
  final ownerId = ChatIdFormat.rawUserUid(currentUserId ?? '');
  final newGroups = groups
      .where(
        (group) =>
            group.groupId.trim().isNotEmpty &&
            !beforeGroupIds.contains(group.groupId.trim()),
      )
      .toList(growable: false);
  if (newGroups.isEmpty) {
    return null;
  }

  final ownedGroups = newGroups
      .where((group) => isRecoverableCreatedGroup(group, currentUserId: ownerId))
      .toList(growable: false);
  var candidates = ownedGroups.isNotEmpty ? ownedGroups : newGroups;

  final normalizedName = preferredGroupName?.trim() ?? '';
  if (normalizedName.isNotEmpty) {
    final namedMatches = candidates
        .where((group) => group.groupName.trim() == normalizedName)
        .toList(growable: false);
    if (namedMatches.length == 1) {
      return namedMatches.first;
    }
    if (namedMatches.isNotEmpty) {
      candidates = namedMatches;
    }
  }

  final normalizedType = preferredGroupType?.trim().toLowerCase() ?? '';
  if (normalizedType.isNotEmpty && candidates.length > 1) {
    final typedMatches = candidates
        .where(
          (group) => group.groupType.trim().toLowerCase() == normalizedType,
        )
        .toList(growable: false);
    if (typedMatches.length == 1) {
      return typedMatches.first;
    }
    if (typedMatches.isNotEmpty) {
      candidates = typedMatches;
    }
  }

  if (candidates.length == 1) {
    return candidates.first;
  }

  return pickRecoverableGroupClosestToAttempt(
    candidates: candidates,
    attemptStartedAtMs: attemptStartedAtMs,
    nowMs: nowMs,
  );
}

int recoverableGroupEventTimeMs(MeGroupRecord group) {
  return group.joinedAt > 0 ? group.joinedAt : group.updatedAt;
}

/// 同名群较多时，取业务时间与本次建群请求最接近的一条；并列则放弃猜测。
MeGroupRecord? pickRecoverableGroupClosestToAttempt({
  required List<MeGroupRecord> candidates,
  required int attemptStartedAtMs,
  int? nowMs,
}) {
  if (candidates.isEmpty) {
    return null;
  }
  if (candidates.length == 1) {
    return candidates.first;
  }

  final now = nowMs ?? DateTime.now().millisecondsSinceEpoch;
  MeGroupRecord? best;
  int? bestDistance;

  for (final group in candidates) {
    final eventTime = recoverableGroupEventTimeMs(group);
    final referenceTime = eventTime > 0 ? eventTime : now;
    final distance = (referenceTime - attemptStartedAtMs).abs();
    if (best == null) {
      best = group;
      bestDistance = distance;
      continue;
    }
    if (distance < bestDistance!) {
      best = group;
      bestDistance = distance;
      continue;
    }
    if (distance == bestDistance) {
      return null;
    }
  }
  return best;
}

MeGroupRecord? findRecoverableCreatedGroup({
  required List<MeGroupRecord> groups,
  required String groupName,
  required String groupType,
  required int attemptStartedAtMs,
  String? currentUserId,
  Set<String> excludeGroupIds = const <String>{},
  Duration maxAge = const Duration(minutes: 10),
  Duration attemptLeadTime = const Duration(seconds: 5),
  int? nowMs,
}) {
  final normalizedName = groupName.trim();
  final normalizedType = groupType.trim().toLowerCase();
  final ownerId = ChatIdFormat.rawUserUid(currentUserId ?? '');
  final now = nowMs ?? DateTime.now().millisecondsSinceEpoch;
  final minTime = attemptStartedAtMs - attemptLeadTime.inMilliseconds;
  final maxAgeMs = maxAge.inMilliseconds;
  final excluded = excludeGroupIds
      .map((id) => id.trim())
      .where((id) => id.isNotEmpty)
      .toSet();

  final matches = <MeGroupRecord>[];

  for (final group in groups) {
    final groupId = group.groupId.trim();
    if (groupId.isEmpty || excluded.contains(groupId)) {
      continue;
    }
    if (normalizedName.isNotEmpty && group.groupName.trim() != normalizedName) {
      continue;
    }
    if (!isRecoverableCreatedGroup(group, currentUserId: ownerId)) {
      continue;
    }
    if (normalizedType.isNotEmpty &&
        group.groupType.trim().toLowerCase() != normalizedType) {
      continue;
    }
    final eventTime = recoverableGroupEventTimeMs(group);
    if (!_isWithinRecoveryWindow(
      eventTime: eventTime,
      attemptStartedAtMs: attemptStartedAtMs,
      now: now,
      minTime: minTime,
      maxAgeMs: maxAgeMs,
    )) {
      continue;
    }
    matches.add(group);
  }

  if (matches.isEmpty) {
    return null;
  }
  if (matches.length == 1) {
    return matches.first;
  }
  return pickRecoverableGroupClosestToAttempt(
    candidates: matches,
    attemptStartedAtMs: attemptStartedAtMs,
    nowMs: now,
  );
}

bool _isWithinRecoveryWindow({
  required int eventTime,
  required int attemptStartedAtMs,
  required int now,
  required int minTime,
  required int maxAgeMs,
}) {
  if (eventTime > 0) {
    return eventTime >= minTime && now - eventTime <= maxAgeMs;
  }
  return now - attemptStartedAtMs <= maxAgeMs;
}
