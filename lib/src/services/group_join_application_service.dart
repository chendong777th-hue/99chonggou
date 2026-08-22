import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tencent_cloud_chat_demo/src/api/group_join_api.dart';
import 'package:tencent_cloud_chat_demo/src/api/group_quota_limit_error.dart';
import 'package:tencent_cloud_chat_demo/src/i18n/app_i18n.dart';
import 'package:tencent_cloud_chat_demo/src/services/group_local/group_change_event_sync_service.dart';
import 'package:tencent_cloud_chat_demo/src/services/group_local/group_membership_sync_service.dart';
import 'package:tencent_cloud_chat_demo/src/services/group_local/group_sync_service.dart';
import 'package:tencent_cloud_chat_demo/src/services/group_local/group_tip_custom_sender.dart';
import 'package:tencent_cloud_chat_demo/utils/chat_id_format.dart';
import 'package:tencent_cloud_chat_demo/src/utils/group_join_application_dedupe.dart';
import 'package:tencent_cloud_chat_demo/src/utils/group_join_application_mapper.dart';
import 'package:tencent_cloud_chat_demo/src/utils/group_join_application_approval.dart';
import 'package:tencent_cloud_chat_demo/src/utils/group_notice_applications_merge.dart';
import 'package:tencent_cloud_chat_demo/utils/group_create_limit_message.dart';
import 'package:tencent_cloud_chat_demo/utils/toast.dart';
import 'package:tencent_cloud_chat_sdk/enum/group_type.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_group_application.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_group_application.dart';
import 'package:tencent_cloud_chat_uikit/data_services/core/core_services_implements.dart';
import 'package:tencent_cloud_chat_uikit/data_services/services_locatar.dart';

/// 自建群加群审批列表（REST），供会话「群通知」与审批页使用。
class GroupJoinApplicationService extends ChangeNotifier {
  GroupJoinApplicationService._();

  static final GroupJoinApplicationService instance =
      GroupJoinApplicationService._();

  static const String applicationAuthPrefix = 'join_app:';
  static const int _maxHandledHistory = 200;
  static const int _maxDismissedKeys = 500;

  List<V2TimGroupApplication> _applications = const [];
  bool _loading = false;
  final Set<String> _adminGroupIds = <String>{};
  final Map<String, String> _userDisplayNameCache = {};
  final Map<String, String> _groupNameCache = {};
  final Map<String, String> _groupAvatarCache = {};
  final Map<String, GroupJoinApplicationRecord> _applicationRecords = {};
  Set<String> _dismissedApplicationKeys = <String>{};
  bool _dismissedApplicationKeysLoaded = false;

  List<V2TimGroupApplication> get applications =>
      List<V2TimGroupApplication>.unmodifiable(_applications);

  bool get isLoading => _loading;

  String? groupNameFor(String groupId) {
    final cached = _groupNameCache[groupId.trim()];
    if (cached != null && cached.isNotEmpty) {
      return cached;
    }
    return null;
  }

  String? groupAvatarFor(String groupId) {
    final cached = _groupAvatarCache[groupId.trim()];
    if (cached != null && cached.isNotEmpty) {
      return cached;
    }
    return null;
  }

  GroupJoinApplicationRecord? recordFor(V2TimGroupApplication application) {
    final applicationId = applicationIdOf(application);
    if (applicationId == null) return null;
    return _applicationRecords['${application.groupID}|$applicationId'];
  }

  String? handledByUserIdFor(V2TimGroupApplication application) {
    final userId = recordFor(application)?.handledByUserId?.trim() ?? '';
    return userId.isEmpty ? null : userId;
  }

  String handledByNameFor(V2TimGroupApplication application) {
    final record = recordFor(application);
    if (record == null) return '';
    final userId = record.handledByUserId?.trim() ?? '';
    return resolveDisplayName(
      userId: userId,
      apiNickName: record.handledByNickName,
    );
  }

  /// 解析审批单展示名：接口昵称 > 已缓存昵称 > userId。
  String resolveDisplayName({
    required String? userId,
    String? apiNickName,
  }) {
    final nick = apiNickName?.trim();
    if (nick != null && nick.isNotEmpty) {
      return nick;
    }
    final id = userId?.trim() ?? '';
    if (id.isEmpty) {
      return '';
    }
    final cached = _userDisplayNameCache[id]?.trim();
    if (cached != null && cached.isNotEmpty) {
      return cached;
    }
    return id;
  }

  void _seedDisplayNames(List<GroupJoinApplicationRecord> records) {
    for (final record in records) {
      _putDisplayName(record.fromUserId, record.fromUserNickName);
      final toUserId = record.toUserId?.trim();
      if (toUserId != null && toUserId.isNotEmpty) {
        _putDisplayName(toUserId, record.toUserNickName);
      }
      final handledByUserId = record.handledByUserId?.trim();
      if (handledByUserId != null && handledByUserId.isNotEmpty) {
        _putDisplayName(handledByUserId, record.handledByNickName);
      }
    }
  }

  void _seedGroupDisplay(List<GroupJoinApplicationRecord> records) {
    for (final record in records) {
      final groupId = record.groupId.trim();
      if (groupId.isEmpty) {
        continue;
      }
      final groupName = record.groupName?.trim();
      if (groupName != null && groupName.isNotEmpty) {
        _groupNameCache[groupId] = groupName;
      }
      final avatar = record.groupAvatarUrl?.trim();
      if (avatar != null && avatar.isNotEmpty) {
        _groupAvatarCache[groupId] = avatar;
      }
    }
  }

  void _putDisplayName(String userId, String? nickName) {
    final id = userId.trim();
    final nick = nickName?.trim();
    if (id.isEmpty || nick == null || nick.isEmpty) {
      return;
    }
    _userDisplayNameCache[id] = nick;
  }

  void cacheDisplayName(String userId, String displayName) {
    _putDisplayName(userId, displayName);
  }

  String _currentUserId() {
    return ChatIdFormat.rawUserUid(
      serviceLocator<CoreServicesImpl>().loginUserInfo?.userID ?? '',
    );
  }

  String get _handledHistoryStorageKey {
    final userId = _currentUserId();
    if (userId.isEmpty) {
      return 'groupJoinApplicationHandledHistory';
    }
    return 'groupJoinApplicationHandledHistory_$userId';
  }

  String get _dismissedApplicationKeysStorageKey {
    final userId = _currentUserId();
    if (userId.isEmpty) {
      return 'groupJoinApplicationDismissedKeys';
    }
    return 'groupJoinApplicationDismissedKeys_$userId';
  }

  Future<Set<String>> _loadDismissedApplicationKeys(
      {bool force = false}) async {
    if (_dismissedApplicationKeysLoaded && !force) {
      return _dismissedApplicationKeys;
    }
    final prefs = await SharedPreferences.getInstance();
    final stored =
        prefs.getStringList(_dismissedApplicationKeysStorageKey) ?? const [];
    _dismissedApplicationKeys = stored
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toSet();
    _dismissedApplicationKeysLoaded = true;
    return _dismissedApplicationKeys;
  }

  Future<void> _saveDismissedApplicationKeys(Set<String> keys) async {
    final normalized = keys
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .take(_maxDismissedKeys)
        .toList(growable: false);
    _dismissedApplicationKeys = normalized.toSet();
    _dismissedApplicationKeysLoaded = true;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      _dismissedApplicationKeysStorageKey,
      normalized,
    );
  }

  Future<void> _markApplicationDismissed(
    V2TimGroupApplication application,
  ) async {
    final keys = await _loadDismissedApplicationKeys();
    final next = Set<String>.from(keys)..add(_applicationLocalKey(application));
    final applicationId = applicationIdOf(application);
    if (applicationId != null && applicationId > 0) {
      next
        ..add('id_$applicationId')
        ..add('${application.groupID}|$applicationId');
    }
    await _saveDismissedApplicationKeys(next);
  }

  bool _isRecordDismissed(
    GroupJoinApplicationRecord record,
    Set<String> dismissedKeys,
  ) {
    if (dismissedKeys.isEmpty) {
      return false;
    }
    if (dismissedKeys.contains(_recordKey(record))) {
      return true;
    }
    if (record.id > 0 && dismissedKeys.contains('id_${record.id}')) {
      return true;
    }
    return false;
  }

  bool _isApplicationDismissed(
    V2TimGroupApplication application,
    Set<String> dismissedKeys,
  ) {
    if (dismissedKeys.isEmpty) {
      return false;
    }
    if (dismissedKeys.contains(_applicationLocalKey(application))) {
      return true;
    }
    final applicationId = applicationIdOf(application);
    if (applicationId != null && applicationId > 0) {
      if (dismissedKeys.contains('id_$applicationId')) {
        return true;
      }
      if (dismissedKeys.contains('${application.groupID}|$applicationId')) {
        return true;
      }
    }
    return false;
  }

  bool _isAdminOnlyNotice(V2TimGroupApplication application) {
    final self = _currentUserId();
    if (self.isEmpty) {
      return false;
    }
    final from = ChatIdFormat.rawUserUid(application.fromUser);
    final to = ChatIdFormat.rawUserUid(application.toUser);
    if (from == self || to == self) {
      return false;
    }
    return _isAdminOfGroup(application.groupID);
  }

  void mergeDisplayNamesFromRecords(List<GroupJoinApplicationRecord> records) {
    _seedDisplayNames(records);
  }

  Future<void> refresh({
    bool force = false,
    bool syncMembership = true,
  }) async {
    if (_loading && !force) {
      return;
    }
    if (syncMembership) {
      _loading = true;
      notifyListeners();
    }
    try {
      final next = await _loadApplications(syncMembership: syncMembership);
      if (!_sameApplications(_applications, next)) {
        _applications = next;
        notifyListeners();
      }
    } catch (error, stack) {
      if (kDebugMode) {
        debugPrint(
            'GroupJoinApplicationService.refresh failed: $error\n$stack');
      }
    } finally {
      if (syncMembership) {
        _loading = false;
        notifyListeners();
      }
    }
  }

  /// 单群管理页：优先 `GET /group/{id}/join-applications`（一次）；
  /// 遇 `RATE_LIMITED` 短退避重试一次，仍限流则回退 `/me/join-applications` 过滤本群。
  /// 禁止在群通知聚合路径循环调用本方法。
  Future<List<V2TimGroupApplication>> loadApplicationsForGroup(
    String groupId, {
    bool includeHandled = true,
  }) async {
    final gid = groupId.trim();
    if (gid.isEmpty) {
      return const [];
    }
    if (_adminGroupIds.isEmpty) {
      final adminGroupIds =
          await GroupMembershipSyncService.instance.adminSelfHostedGroupIds();
      _adminGroupIds
        ..clear()
        ..addAll(_normalizedGroupIdKeys(adminGroupIds));
    }

    List<GroupJoinApplicationRecord> records;
    try {
      records = await _fetchJoinApplicationsWithRateLimitFallback(
        gid,
        includeHandled: includeHandled,
      );
    } catch (error, stack) {
      if (kDebugMode) {
        debugPrint(
          'GroupJoinApplicationService.loadApplicationsForGroup failed: '
          '$error\n$stack',
        );
      }
      return const [];
    }

    final dismissedKeys = await _loadDismissedApplicationKeys();
    final handledLocal = await _loadHandledHistoryLocal();
    final localForGroup = handledLocal
        .where((record) => ChatIdFormat.groupIdsEquivalent(record.groupId, gid))
        .toList(growable: false);
    final mergedRecords = dedupeGroupJoinApplicationRecords(
      _mergeRecords(records, localForGroup),
    )
        .where((record) => !_isRecordDismissed(record, dismissedKeys))
        .where(
          (record) => ChatIdFormat.groupIdsEquivalent(record.groupId, gid),
        )
        .toList(growable: false);

    _seedDisplayNames(mergedRecords);
    _seedGroupDisplay(mergedRecords);

    final dropKeys = _applicationRecords.keys
        .where((key) {
          final pipe = key.indexOf('|');
          final keyGroup = pipe >= 0 ? key.substring(0, pipe) : key;
          return ChatIdFormat.groupIdsEquivalent(keyGroup, gid);
        })
        .toList(growable: false);
    for (final key in dropKeys) {
      _applicationRecords.remove(key);
    }
    for (final record in mergedRecords) {
      _applicationRecords[_recordKey(record)] = record;
    }

    final mapped = mergedRecords
        .map(GroupJoinApplicationMapper.toUIKitApplication)
        .toList(growable: false);
    final others = _applications
        .where((item) => !ChatIdFormat.groupIdsEquivalent(item.groupID, gid))
        .toList(growable: false);
    _applications = dedupeGroupNoticeApplications([...others, ...mapped]);
    notifyListeners();
    return mapped;
  }

  Future<List<GroupJoinApplicationRecord>>
      _fetchJoinApplicationsWithRateLimitFallback(
    String groupId, {
    required bool includeHandled,
  }) async {
    Future<List<GroupJoinApplicationRecord>> once() =>
        GroupJoinApi.instance.fetchJoinApplications(
          groupId,
          includeHandled: includeHandled,
        );

    try {
      return await once();
    } on GroupJoinAppsRateLimitedException {
      await Future<void>.delayed(const Duration(milliseconds: 500));
      try {
        return await once();
      } on GroupJoinAppsRateLimitedException {
        if (kDebugMode) {
          debugPrint(
            'GroupJoinApplicationService: per-group RATE_LIMITED, '
            'fallback GET /me/join-applications',
          );
        }
        final all = await GroupJoinApi.instance.fetchAllMyJoinApplications(
          includeHandled: includeHandled,
        );
        return all
            .where(
              (record) =>
                  ChatIdFormat.groupIdsEquivalent(record.groupId, groupId),
            )
            .toList(growable: false);
      }
    }
  }

  Future<List<V2TimGroupApplication>> _loadApplications({
    bool syncMembership = true,
  }) async {
    if (syncMembership) {
      await GroupMembershipSyncService.instance.syncFull(
        reason: 'join_applications',
      );
    }
    // 本地角色仅用于 canApprove / admin-only UI；不按群循环打 join-applications。
    final adminGroupIds =
        await GroupMembershipSyncService.instance.adminSelfHostedGroupIds();
    _adminGroupIds
      ..clear()
      ..addAll(_normalizedGroupIdKeys(adminGroupIds));
    final handledLocal = await _loadHandledHistoryLocal();
    final dismissedKeys = await _loadDismissedApplicationKeys();

    // 削峰：群通知聚合只打 GET /me/join-applications（分页拉齐）。
    final records = <GroupJoinApplicationRecord>[];
    try {
      final myItems =
          await GroupJoinApi.instance.fetchAllMyJoinApplications(
        includeHandled: true,
      );
      records.addAll(myItems);
    } catch (_) {}

    final mergedRecords = dedupeGroupJoinApplicationRecords(
      _mergeRecords(records, handledLocal),
    ).where((record) => !_isRecordDismissed(record, dismissedKeys)).toList(
          growable: false,
        );
    _seedDisplayNames(mergedRecords);
    _seedGroupDisplay(mergedRecords);
    _applicationRecords
      ..clear()
      ..addEntries(
        mergedRecords.map(
          (record) => MapEntry<String, GroupJoinApplicationRecord>(
            _recordKey(record),
            record,
          ),
        ),
      );
    unawaited(_backfillLocalHistoryNicknames(mergedRecords, handledLocal));
    final mapped = mergedRecords
        .map(GroupJoinApplicationMapper.toUIKitApplication)
        .toList(growable: false);
    return dedupeGroupNoticeApplications(mapped);
  }

  String _recordKey(GroupJoinApplicationRecord record) {
    return '${record.groupId}|${record.id}';
  }

  List<GroupJoinApplicationRecord> _mergeRecords(
    List<GroupJoinApplicationRecord> fromApi,
    List<GroupJoinApplicationRecord> fromLocal,
  ) {
    final map = <String, GroupJoinApplicationRecord>{};
    for (final record in fromLocal) {
      if (!record.isPending) {
        map[_recordKey(record)] = record;
      }
    }
    for (final record in fromApi) {
      final key = _recordKey(record);
      final existing = map[key];
      map[key] =
          existing == null ? record : _mergeRecordFields(existing, record);
    }
    return map.values.toList(growable: false);
  }

  /// API 记录优先；昵称等人读字段在任一侧有值时保留。
  GroupJoinApplicationRecord _mergeRecordFields(
    GroupJoinApplicationRecord local,
    GroupJoinApplicationRecord api,
  ) {
    return GroupJoinApplicationRecord(
      id: api.id > 0 ? api.id : local.id,
      groupId: api.groupId.isNotEmpty ? api.groupId : local.groupId,
      applicationType: api.applicationType.isNotEmpty
          ? api.applicationType
          : local.applicationType,
      fromUserId: api.fromUserId.isNotEmpty ? api.fromUserId : local.fromUserId,
      toUserId: api.toUserId ?? local.toUserId,
      message: api.message ?? local.message,
      status: api.status.isNotEmpty ? api.status : local.status,
      createdAtMs: api.createdAtMs ?? local.createdAtMs,
      handledAtMs: api.handledAtMs ?? local.handledAtMs,
      handledByUserId: api.handledByUserId ?? local.handledByUserId,
      handledByNickName: api.handledByNickName ?? local.handledByNickName,
      fromUserNickName: api.fromUserNickName ?? local.fromUserNickName,
      toUserNickName: api.toUserNickName ?? local.toUserNickName,
      fromUserFaceUrl: api.fromUserFaceUrl ?? local.fromUserFaceUrl,
      groupName: api.groupName ?? local.groupName,
      groupAvatarUrl: api.groupAvatarUrl ?? local.groupAvatarUrl,
    );
  }

  Future<void> _backfillLocalHistoryNicknames(
    List<GroupJoinApplicationRecord> merged,
    List<GroupJoinApplicationRecord> previousLocal,
  ) async {
    if (previousLocal.isEmpty || merged.isEmpty) {
      return;
    }
    final mergedByKey = {
      for (final record in merged) _recordKey(record): record,
    };
    var changed = false;
    final nextLocal = previousLocal.map((record) {
      final enriched = mergedByKey[_recordKey(record)];
      if (enriched == null) {
        return record;
      }
      final mergedRecord = _mergeRecordFields(record, enriched);
      if (mergedRecord.fromUserNickName == record.fromUserNickName &&
          mergedRecord.toUserNickName == record.toUserNickName &&
          mergedRecord.fromUserFaceUrl == record.fromUserFaceUrl) {
        return record;
      }
      changed = true;
      return mergedRecord;
    }).toList(growable: false);
    if (!changed) {
      return;
    }
    await _saveHandledHistoryLocal(nextLocal);
  }

  Future<List<GroupJoinApplicationRecord>> _loadHandledHistoryLocal() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_handledHistoryStorageKey);
    if (raw == null || raw.isEmpty) {
      return const [];
    }
    try {
      final decoded = jsonDecode(raw) as List<dynamic>;
      return decoded
          .whereType<Map>()
          .map(
            (item) => GroupJoinApplicationRecord.fromJson(
              Map<String, dynamic>.from(item),
            ),
          )
          .where((item) => item.id > 0 && item.groupId.isNotEmpty)
          .toList(growable: false);
    } catch (_) {
      return const [];
    }
  }

  Future<void> _saveHandledHistoryLocal(
    List<GroupJoinApplicationRecord> records,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final normalized = records.take(_maxHandledHistory).toList(growable: false);
    await prefs.setString(
      _handledHistoryStorageKey,
      jsonEncode(normalized.map((item) => item.toJson()).toList()),
    );
  }

  Future<void> _appendHandledRecord(GroupJoinApplicationRecord record) async {
    _applicationRecords[_recordKey(record)] = record;
    final history = await _loadHandledHistoryLocal();
    history.removeWhere((item) => _recordKey(item) == _recordKey(record));
    history.insert(0, record);
    await _saveHandledHistoryLocal(history);
  }

  GroupJoinApplicationRecord _recordFromApplication(
    V2TimGroupApplication application, {
    required String status,
  }) {
    final addTime = application.addTime;
    int? createdAtMs;
    if (addTime != null && addTime > 0) {
      createdAtMs = addTime >= 1000000000000 ? addTime : addTime * 1000;
    }
    return GroupJoinApplicationRecord(
      id: resolveApplicationRecordId(application),
      groupId: application.groupID,
      applicationType: application.type == 2 ? 'invite' : 'join',
      fromUserId: application.fromUser ?? '',
      toUserId: application.toUser,
      message: application.requestMsg,
      status: status,
      createdAtMs: createdAtMs,
      handledByUserId: _currentUserId(),
      handledByNickName:
          serviceLocator<CoreServicesImpl>().loginUserInfo?.nickName,
      fromUserNickName: application.fromUserNickName,
      fromUserFaceUrl: application.fromUserFaceUrl,
    );
  }

  int resolveApplicationRecordId(V2TimGroupApplication application) {
    final restId = applicationIdOf(application);
    if (restId != null && restId > 0) {
      return restId;
    }
    final key = [
      application.groupID,
      application.fromUser ?? '',
      application.toUser ?? '',
      application.addTime ?? 0,
      application.type,
    ].join('|');
    var hash = key.hashCode & 0x7fffffff;
    if (hash == 0) {
      hash = 1;
    }
    return hash;
  }

  int? applicationIdOf(V2TimGroupApplication application) {
    final auth = application.authentication.trim();
    if (!auth.startsWith(applicationAuthPrefix)) {
      return null;
    }
    return int.tryParse(auth.substring(applicationAuthPrefix.length));
  }

  bool isSelfHostedApplication(V2TimGroupApplication application) {
    return application.authentication.trim().startsWith(applicationAuthPrefix);
  }

  /// 申请人 / 邀请人 / 被邀请人，或该群管理员，可通过 `/me/join-applications` 删除。
  bool canDeleteApplicationForCurrentUser(V2TimGroupApplication application) {
    final applicationId = applicationIdOf(application);
    if (applicationId == null || !isSelfHostedApplication(application)) {
      return false;
    }
    final self = _currentUserId();
    if (self.isEmpty) {
      return false;
    }
    final from = ChatIdFormat.rawUserUid(application.fromUser);
    final to = ChatIdFormat.rawUserUid(application.toUser);
    if (from == self || to == self) {
      return true;
    }
    return _isAdminOfGroup(application.groupID);
  }

  bool isPendingApplication(V2TimGroupApplication application) {
    return groupJoinApplicationIsPending(application);
  }

  /// 仅群主/管理员可审批待处理申请（邀请人/被邀请人除外）。
  bool canApproveApplicationForCurrentUser(V2TimGroupApplication application) {
    return groupJoinApplicationCanApproveForCurrentUser(
      application: application,
      adminGroupIds: _adminGroupIds,
      currentUserId: _currentUserId(),
    );
  }

  /// 申请人 / 邀请人 / 被邀请人查看自己的 pending 记录（不可自行审批）。
  bool isWaitingAdminApprovalForCurrentUser(
    V2TimGroupApplication application,
  ) {
    return groupJoinApplicationIsWaitingAsParticipant(
      application: application,
      adminGroupIds: _adminGroupIds,
      currentUserId: _currentUserId(),
    );
  }

  Set<String> _normalizedGroupIdKeys(Iterable<String> groupIds) {
    final keys = <String>{};
    for (final raw in groupIds) {
      final trimmed = raw.trim();
      if (trimmed.isEmpty) {
        continue;
      }
      keys.add(trimmed);
      final normalized = ChatIdFormat.normalizeGroupId(trimmed);
      if (normalized.isNotEmpty) {
        keys.add(normalized);
      }
    }
    return keys;
  }

  bool _isAdminOfGroup(String groupId) {
    final trimmed = groupId.trim();
    if (trimmed.isEmpty) {
      return false;
    }
    if (_adminGroupIds.contains(trimmed)) {
      return true;
    }
    final normalized = ChatIdFormat.normalizeGroupId(trimmed);
    return normalized.isNotEmpty && _adminGroupIds.contains(normalized);
  }

  Future<bool> clearAllApplications() async {
    if (_applications.isEmpty) {
      return true;
    }
    final snapshot = List<V2TimGroupApplication>.from(_applications);
    try {
      try {
        await GroupJoinApi.instance.deleteMyJoinApplications();
      } catch (error, stack) {
        if (kDebugMode) {
          debugPrint(
            'GroupJoinApplicationService.clearAllApplications api failed: $error\n$stack',
          );
        }
      }
      final dismissedKeys = await _loadDismissedApplicationKeys();
      final next = Set<String>.from(dismissedKeys);
      for (final application in snapshot) {
        next.add(_applicationLocalKey(application));
        final applicationId = applicationIdOf(application);
        if (applicationId != null && applicationId > 0) {
          next
            ..add('id_$applicationId')
            ..add('${application.groupID}|$applicationId');
        }
      }
      await _saveDismissedApplicationKeys(next);
      _applications = const [];
      notifyListeners();
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> deleteApplication(V2TimGroupApplication application) async {
    final applicationId = applicationIdOf(application);
    if (applicationId == null ||
        !canDeleteApplicationForCurrentUser(application)) {
      _toastDeleteFailed();
      return false;
    }
    final adminOnlyNotice = _isAdminOnlyNotice(application);
    try {
      try {
        await GroupJoinApi.instance.deleteMyJoinApplication(applicationId);
      } catch (_) {
        if (!adminOnlyNotice) {
          rethrow;
        }
      }
      await _markApplicationDismissed(application);
      await _removeApplicationLocally(application);
      _toastDeleteSuccess();
      unawaited(refresh(force: true, syncMembership: false));
      return true;
    } catch (_) {
      _toastDeleteFailed();
      return false;
    }
  }

  Future<void> _removeApplicationLocally(
    V2TimGroupApplication application,
  ) async {
    final dismissedKeys = await _loadDismissedApplicationKeys();
    final auth = application.authentication.trim();
    final key = _applicationLocalKey(application);
    _applications = _applications
        .where(
          (item) =>
              !_isApplicationDismissed(item, dismissedKeys) &&
              (auth.isEmpty || item.authentication.trim() != auth) &&
              _applicationLocalKey(item) != key,
        )
        .toList(growable: false);
    notifyListeners();

    final history = await _loadHandledHistoryLocal();
    final applicationId = applicationIdOf(application);
    final nextHistory = history
        .where(
          (item) =>
              item.id != applicationId &&
              _recordKey(item) !=
                  '${application.groupID}|${applicationId ?? 0}',
        )
        .toList(growable: false);
    if (nextHistory.length != history.length) {
      await _saveHandledHistoryLocal(nextHistory);
    }
  }

  String _applicationLocalKey(V2TimGroupApplication application) {
    return [
      application.groupID,
      application.fromUser ?? '',
      application.toUser ?? '',
      application.addTime?.toString() ?? '0',
      application.type.toString(),
      application.authentication,
    ].join('|');
  }

  void _toastDeleteSuccess() {
    ToastUtils.toast(AppI18n.current.t(
      zhHans: '已删除',
      zhHant: '已刪除',
      en: 'Deleted',
      ja: '削除しました',
      ko: '삭제됨',
    ));
  }

  void _toastDeleteFailed() {
    ToastUtils.toast(AppI18n.current.t(
      zhHans: '删除失败，请稍后重试',
      zhHant: '刪除失敗，請稍後重試',
      en: 'Delete failed. Please try again.',
      ja: '削除に失敗しました。しばらくして再試行してください。',
      ko: '삭제에 실패했습니다. 잠시 후 다시 시도해 주세요.',
    ));
  }

  V2TimGroupApplication _withHandledStatus(
    V2TimGroupApplication application,
    String status,
  ) {
    final flags = GroupJoinApplicationMapper.handleFlagsForStatus(status);
    return V2TimGroupApplication(
      groupID: application.groupID,
      fromUser: application.fromUser,
      fromUserNickName: application.fromUserNickName,
      fromUserFaceUrl: application.fromUserFaceUrl,
      toUser: application.toUser,
      addTime: application.addTime,
      requestMsg: application.requestMsg,
      handledMsg: application.handledMsg,
      type: application.type,
      handleStatus: flags.$1,
      handleResult: flags.$2,
      authentication: application.authentication,
    );
  }

  void _patchHandledApplicationLocally(
    V2TimGroupApplication application,
    String status,
  ) {
    final auth = application.authentication.trim();
    final index = _applications.indexWhere(
      (item) => item.authentication.trim() == auth,
    );
    if (index < 0) {
      return;
    }
    final next = List<V2TimGroupApplication>.from(_applications);
    next[index] = _withHandledStatus(next[index], status);
    _applications = next;
    notifyListeners();
  }

  void _toastApproveSuccess() {
    ToastUtils.toast(AppI18n.current.t(
      zhHans: '已同意进群申请',
      zhHant: '已同意進群申請',
      en: 'Join request accepted',
      ja: '参加申請を承認しました',
      ko: '참가 요청을 승인했습니다',
    ));
  }

  void _toastRejectSuccess() {
    ToastUtils.toast(AppI18n.current.t(
      zhHans: '已拒绝进群申请',
      zhHant: '已拒絕進群申請',
      en: 'Join request declined',
      ja: '参加申請を拒否しました',
      ko: '참가 요청을 거절했습니다',
    ));
  }

  void _toastActionFailed() {
    ToastUtils.toast(AppI18n.current.t(
      zhHans: '操作失败，请重试',
      zhHant: '操作失敗，請重試',
      en: 'Action failed, please try again',
      ja: '操作に失敗しました。もう一度お試しください',
      ko: '작업에 실패했습니다. 다시 시도해 주세요',
    ));
  }

  Future<bool> approve(V2TimGroupApplication application) async {
    if (!canApproveApplicationForCurrentUser(application)) {
      _toastActionFailed();
      return false;
    }
    final applicationId = applicationIdOf(application);
    if (applicationId == null) {
      _toastActionFailed();
      return false;
    }
    try {
      await GroupJoinApi.instance.approveJoinApplication(
        groupId: application.groupID,
        applicationId: applicationId,
      );
      _patchHandledApplicationLocally(application, 'approved');
      _toastApproveSuccess();
      unawaited(refresh(force: true, syncMembership: false));
      final memberAddedTargets =
          groupJoinApplicationMemberAddedTargets(application);
      if (memberAddedTargets.memberUserIds.isNotEmpty) {
        final inviterId = memberAddedTargets.operatorUserId;
        final inviterName = resolveDisplayName(
          userId: inviterId,
          apiNickName: application.fromUserNickName,
        );
        unawaited(
          GroupTipCustomSender.instance.send(
            groupId: application.groupID,
            action: 'member_added',
            memberUserIds: memberAddedTargets.memberUserIds,
            opUserId: inviterId,
            opUserName: inviterName.isNotEmpty ? inviterName : null,
          ),
        );
        unawaited(
          GroupSyncService.instance.notifyGroupMembersChanged(
            application.groupID,
            operatorUserId: memberAddedTargets.operatorUserId,
            memberUserIds: memberAddedTargets.memberUserIds,
          ),
        );
        unawaited(
          GroupChangeEventSyncService.instance.syncForGroup(
            application.groupID,
            reason: 'join_application_approved',
          ),
        );
      }
      return true;
    } on DioError catch (error) {
      final quota = GroupQuotaLimitError.tryParse(error.response?.data);
      final quotaMessage = quota == null
          ? null
          : GroupCreateLimitMessage.fromQuotaError(quota);
      if (quotaMessage != null) {
        ToastUtils.toast(quotaMessage);
      } else {
        final code = GroupJoinApi.readDioCode(error).toUpperCase();
        final mapped = GroupCreateLimitMessage.fromApiCode(
          code: code,
          groupType: GroupType.Public,
        );
        if (mapped != null) {
          ToastUtils.toast(mapped);
        } else {
          _toastActionFailed();
        }
      }
      return false;
    } catch (_) {
      _toastActionFailed();
      return false;
    }
  }

  Future<bool> reject(V2TimGroupApplication application) async {
    if (!canApproveApplicationForCurrentUser(application)) {
      _toastActionFailed();
      return false;
    }
    final applicationId = applicationIdOf(application);
    if (applicationId == null) {
      _toastActionFailed();
      return false;
    }
    try {
      await GroupJoinApi.instance.rejectJoinApplication(
        groupId: application.groupID,
        applicationId: applicationId,
      );
      _patchHandledApplicationLocally(application, 'rejected');
      _toastRejectSuccess();
      unawaited(refresh(force: true, syncMembership: false));
      return true;
    } catch (_) {
      _toastActionFailed();
      return false;
    }
  }

  bool _sameApplications(
    List<V2TimGroupApplication> oldList,
    List<V2TimGroupApplication> nextList,
  ) {
    if (oldList.length != nextList.length) {
      return false;
    }
    for (var i = 0; i < oldList.length; i++) {
      final oldItem = oldList[i];
      final nextItem = nextList[i];
      if (oldItem.groupID != nextItem.groupID ||
          oldItem.authentication != nextItem.authentication ||
          oldItem.fromUser != nextItem.fromUser ||
          oldItem.fromUserNickName != nextItem.fromUserNickName ||
          oldItem.fromUserFaceUrl != nextItem.fromUserFaceUrl ||
          oldItem.toUser != nextItem.toUser ||
          oldItem.handleResult != nextItem.handleResult ||
          oldItem.handleStatus != nextItem.handleStatus) {
        return false;
      }
    }
    return true;
  }

  void clearSession() {
    _applications = const [];
    _loading = false;
    _adminGroupIds.clear();
    _dismissedApplicationKeys = <String>{};
    _dismissedApplicationKeysLoaded = false;
    _userDisplayNameCache.clear();
    _groupNameCache.clear();
    _groupAvatarCache.clear();
    notifyListeners();
  }
}
