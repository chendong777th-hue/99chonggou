import 'package:dio/dio.dart';
import 'package:tencent_cloud_chat_demo/src/api/group_quota_limit_error.dart';
import 'package:tencent_cloud_chat_demo/src/models/group_join_option.dart';
import 'package:tencent_cloud_chat_demo/src/models/group_join_source.dart';
import 'package:tencent_cloud_chat_demo/utils/api_response_util.dart';
import 'package:tencent_cloud_chat_demo/utils/chat_id_format.dart';
import 'package:tencent_cloud_chat_demo/utils/group_join_lookup.dart';
import 'package:tencent_cloud_chat_sdk/enum/group_type.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_group_info.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_group_info.dart';

import 'api_client.dart';

void _groupInviteDiag(String message) {
  // ignore: avoid_print
  print('[GroupInviteDiag] $message');
}

/// 单群 `GET /group/{id}/join-applications` 触发服务端扇出限流。
class GroupJoinAppsRateLimitedException implements Exception {
  const GroupJoinAppsRateLimitedException([
    this.message = 'RATE_LIMITED',
  ]);

  final String message;

  @override
  String toString() => message;
}

int? _readInt(dynamic value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '');
}

/// Work / Public / Meeting / Community 加群、邀请、审批 REST API。
class GroupJoinApi {
  GroupJoinApi._();

  static final GroupJoinApi instance = GroupJoinApi._();

  Dio get _dio => ApiClient.instance.dio;

  static bool isSelfHostedJoinGroupType(String? groupType) {
    final normalized = groupType?.trim();
    return normalized == GroupType.Public ||
        normalized == GroupType.Meeting ||
        normalized == GroupType.Community;
  }

  /// 建群 / 退群 / 踢人等治理走 REST（非直播群）。
  static bool isSelfHostedGovernanceGroupType(String? groupType) {
    final normalized = groupType?.trim();
    if (normalized == null || normalized.isEmpty) {
      return true;
    }
    return normalized != GroupType.AVChatRoom;
  }

  String _groupPath(String groupId) =>
      '/group/${Uri.encodeComponent(ChatIdFormat.apiGroupId(groupId))}';

  Future<GroupJoinOptions> fetchJoinOptions(String groupId) async {
    final res = await _dio.get('${_groupPath(groupId)}/join-options');
    final payload = unwrapApiPayload(res.data);
    if (payload is Map) {
      return GroupJoinOptions.fromJson(Map<String, dynamic>.from(payload));
    }
    return const GroupJoinOptions(
      applyJoinOption: GroupJoinOption.needPermission,
      inviteJoinOption: GroupJoinOption.needPermission,
      allowJoinByQrCode: true,
      allowJoinByAlias: true,
    );
  }

  /// GET /group/{groupId}/pending-invitees
  /// 任意群成员可读：本群邀请待审被邀请人 userId 列表（不含主动申请）。
  Future<List<String>> fetchPendingInvitees(String groupId) async {
    final id = groupId.trim();
    if (id.isEmpty) {
      return const <String>[];
    }
    try {
      final res = await _dio.get('${_groupPath(id)}/pending-invitees');
      return parsePendingInviteeUserIds(unwrapApiPayload(res.data));
    } on DioError catch (e) {
      final code = readDioCode(e);
      if (code == 'NOT_GROUP_MEMBER' ||
          code == 'GROUP_NOT_FOUND' ||
          code == 'NOT_FOUND') {
        return const <String>[];
      }
      rethrow;
    }
  }

  static List<String> parsePendingInviteeUserIds(dynamic payload) {
    if (payload is! Map) {
      return const <String>[];
    }
    final map = Map<String, dynamic>.from(payload);
    final raw = map['userIds'] ?? map['items'] ?? map['users'];
    if (raw is! List) {
      return const <String>[];
    }
    final ids = raw
        .map((item) {
          if (item is Map) {
            return ChatIdFormat.rawUserUid(
              item['userId']?.toString() ?? item['id']?.toString() ?? '',
            );
          }
          return ChatIdFormat.rawUserUid(item?.toString() ?? '');
        })
        .where((item) => item.isNotEmpty)
        .toSet()
        .toList(growable: false);
    ids.sort();
    return ids;
  }

  /// GET /group/join-lookup — 按加群来源查群；关闭对应入口时返回业务错误码。
  Future<V2TimGroupInfo?> lookupJoinTarget({
    required String keyword,
    required GroupJoinSource joinSource,
  }) async {
    final query = keyword.trim();
    if (query.isEmpty) {
      return null;
    }
    try {
      final res = await _dio.get(
        '/group/join-lookup',
        queryParameters: <String, dynamic>{
          'keyword': query,
          'joinSource': joinSource.storageValue,
        },
      );
      final errorCode = _readEnvelopeErrorCode(res.data);
      if (errorCode == 'JOIN_BY_ALIAS_DISABLED' ||
          errorCode == 'JOIN_BY_QR_DISABLED') {
        throw GroupJoinLookupDisabledException(errorCode!);
      }
      if (errorCode == 'GROUP_NOT_FOUND') {
        return null;
      }
      final payload = unwrapApiPayload(res.data);
      if (payload is! Map) {
        return null;
      }
      return _groupInfoFromLookup(Map<String, dynamic>.from(payload));
    } on DioError catch (error) {
      final code = readDioCode(error);
      if (code == 'JOIN_BY_ALIAS_DISABLED' || code == 'JOIN_BY_QR_DISABLED') {
        throw GroupJoinLookupDisabledException(code);
      }
      if (code == 'GROUP_NOT_FOUND') {
        return null;
      }
      rethrow;
    }
  }

  static String? _readEnvelopeErrorCode(dynamic raw) {
    if (raw is! Map) {
      return null;
    }
    final map = Map<String, dynamic>.from(raw);
    final codeRaw = map['code'];
    final message = map['message']?.toString().trim() ?? '';
    if (codeRaw is num && codeRaw != 0) {
      if (message.isNotEmpty &&
          message.toLowerCase() != 'ok' &&
          !RegExp(r'^\d+$').hasMatch(message)) {
        return message;
      }
      if (codeRaw == 404) {
        return 'GROUP_NOT_FOUND';
      }
    }
    if (codeRaw is String) {
      final normalized = codeRaw.trim();
      if (normalized.isNotEmpty &&
          normalized != '0' &&
          normalized.toLowerCase() != 'ok') {
        return normalized;
      }
    }
    if (message == 'JOIN_BY_ALIAS_DISABLED' ||
        message == 'JOIN_BY_QR_DISABLED' ||
        message == 'GROUP_NOT_FOUND') {
      return message;
    }
    return null;
  }

  V2TimGroupInfo? _groupInfoFromLookup(Map<String, dynamic> json) {
    final groupId = _readString(json, const [
      'groupId',
      'group_id',
      'groupID',
    ]);
    if (groupId == null || groupId.isEmpty) {
      return null;
    }
    final memberCount = _readInt(
      json['memberCount'] ?? json['member_count'],
    );
    return V2TimGroupInfo(
      groupID: groupId,
      groupType:
          json['groupType']?.toString() ?? json['group_type']?.toString() ?? '',
      groupName:
          json['groupName']?.toString() ?? json['group_name']?.toString(),
      faceUrl: json['avatarUrl']?.toString() ?? json['avatar_url']?.toString(),
      introduction: json['introduction']?.toString(),
      memberCount: memberCount,
    );
  }

  static String? _readString(Map<String, dynamic> json, List<String> keys) {
    for (final key in keys) {
      final value = json[key]?.toString().trim();
      if (value != null && value.isNotEmpty) {
        return value;
      }
    }
    return null;
  }

  Future<GroupJoinOptions> updateJoinOptions(
    String groupId,
    GroupJoinOptions options,
  ) async {
    final res = await _dio.put(
      '${_groupPath(groupId)}/join-options',
      data: options.toJson(),
    );
    final payload = unwrapApiPayload(res.data);
    if (payload is Map) {
      return GroupJoinOptions.fromJson(Map<String, dynamic>.from(payload));
    }
    return options;
  }

  Future<GroupJoinResult> applyJoin({
    required String groupId,
    String? message,
    GroupJoinSource? joinSource,
  }) async {
    try {
      final res = await _dio.post(
        '${_groupPath(groupId)}/join',
        data: <String, dynamic>{
          if (message != null && message.trim().isNotEmpty)
            'message': message.trim(),
          if (joinSource != null) 'joinSource': joinSource.storageValue,
        },
      );
      return GroupJoinResult.fromPayload(unwrapApiPayload(res.data));
    } on DioError catch (e) {
      return GroupJoinResult.failed(readDioCode(e));
    }
  }

  /// 单页拉取。limit 默认 50，上限 100（与后端契约对齐）。
  Future<List<GroupJoinApplicationRecord>> fetchMyJoinApplications({
    int limit = 50,
    int offset = 0,
    bool includeHandled = true,
    String? status,
  }) async {
    try {
      final pageLimit = limit.clamp(1, 100);
      final res = await _dio.get(
        '/me/join-applications',
        queryParameters: <String, dynamic>{
          'limit': pageLimit,
          'offset': offset < 0 ? 0 : offset,
          if (includeHandled) 'includeHandled': 'true',
          if (status != null && status.trim().isNotEmpty)
            'status': status.trim(),
        },
      );
      final list = extractApiList(
        res.data,
        listKeys: const ['items', 'applications', 'results'],
      );
      return list
          .whereType<Map>()
          .map(
            (item) => GroupJoinApplicationRecord.fromJson(
              Map<String, dynamic>.from(item),
            ),
          )
          .where((item) => item.id > 0)
          .toList();
    } on DioError catch (_) {
      return const <GroupJoinApplicationRecord>[];
    }
  }

  /// 群通知页削峰：只打 `/me/join-applications`，按页拉齐（含管理员可见跨群审批）。
  Future<List<GroupJoinApplicationRecord>> fetchAllMyJoinApplications({
    bool includeHandled = true,
    String? status,
    int pageLimit = 100,
  }) async {
    final all = <GroupJoinApplicationRecord>[];
    var offset = 0;
    final limit = pageLimit.clamp(1, 100);
    var total = 0;
    do {
      final page = await fetchMyJoinApplications(
        limit: limit,
        offset: offset,
        includeHandled: includeHandled,
        status: status,
      );
      all.addAll(page);
      // 无 total 时以空页 / 不足一页为终止条件。
      if (page.isEmpty) {
        break;
      }
      offset += page.length;
      if (page.length < limit) {
        break;
      }
      // 防御：避免异常 total 导致死循环。
      total += page.length;
      if (total >= 10000) {
        break;
      }
    } while (true);
    return all;
  }

  Future<List<GroupJoinApplicationRecord>> fetchJoinApplications(
    String groupId, {
    bool includeHandled = true,
  }) async {
    try {
      final res = await _dio.get(
        '${_groupPath(groupId)}/join-applications',
        queryParameters: includeHandled
            ? const <String, dynamic>{'includeHandled': 'true'}
            : null,
      );
      final list = extractApiList(
        res.data,
        listKeys: const ['items', 'applications', 'results'],
      );
      return list
          .whereType<Map>()
          .map(
            (item) => GroupJoinApplicationRecord.fromJson(
              Map<String, dynamic>.from(item),
              fallbackGroupId: groupId,
            ),
          )
          .where((item) => item.id > 0)
          .toList();
    } on DioError catch (e) {
      if (isJoinAppsRateLimited(e)) {
        throw const GroupJoinAppsRateLimitedException();
      }
      final code = readDioCode(e);
      if (code == 'NOT_GROUP_ADMIN' || code == 'NOT_GROUP_MEMBER') {
        return const <GroupJoinApplicationRecord>[];
      }
      rethrow;
    }
  }

  /// 单群 join-applications 限流：HTTP 429 或 body code/message 含 RATE_LIMITED。
  static bool isJoinAppsRateLimited(DioError error) {
    if (error.response?.statusCode == 429) {
      return true;
    }
    final code = readDioCode(error).trim().toUpperCase();
    if (code == 'RATE_LIMITED' || code.contains('RATE_LIMITED')) {
      return true;
    }
    final data = error.response?.data;
    if (data is Map) {
      final reason = data['reason']?.toString().trim().toUpperCase() ?? '';
      if (reason == 'RATE_LIMITED' || reason.contains('RATE_LIMITED')) {
        return true;
      }
    }
    return false;
  }

  Future<void> approveJoinApplication({
    required String groupId,
    required int applicationId,
  }) async {
    await _dio.post(
      '${_groupPath(groupId)}/join-applications/$applicationId/approve',
    );
  }

  Future<void> rejectJoinApplication({
    required String groupId,
    required int applicationId,
  }) async {
    await _dio.post(
      '${_groupPath(groupId)}/join-applications/$applicationId/reject',
    );
  }

  /// DELETE /me/join-applications/{applicationId} — 软删除（仅对当前用户隐藏）。
  Future<void> deleteMyJoinApplication(int applicationId) async {
    final id = applicationId;
    if (id <= 0) {
      throw ArgumentError.value(applicationId, 'applicationId', 'invalid id');
    }
    await _dio.delete('/me/join-applications/$id');
  }

  /// DELETE /me/join-applications — 无 body 隐藏全部；body `{ applicationIds }` 批量隐藏；可选 `status` 过滤。
  /// 响应 `{ deleted: N }`；审批单不物理删除，其他管理员仍可见。
  Future<int> deleteMyJoinApplications({
    List<int>? applicationIds,
    String? status,
  }) async {
    final ids = applicationIds?.where((id) => id > 0).toList(growable: false) ??
        const <int>[];
    final res = await _dio.delete(
      '/me/join-applications',
      queryParameters: status != null && status.trim().isNotEmpty
          ? <String, dynamic>{'status': status.trim()}
          : null,
      data: ids.isNotEmpty ? <String, dynamic>{'applicationIds': ids} : null,
    );
    final payload = unwrapApiPayload(res.data);
    if (payload is Map) {
      final deleted = _readInt(
        payload['deleted'] ?? payload['deletedCount'] ?? payload['count'],
      );
      if (deleted != null) {
        return deleted;
      }
    }
    return ids.isEmpty ? 0 : ids.length;
  }

  Future<GroupInviteResponse> inviteMembers({
    required String groupId,
    required List<String> userIds,
    String? message,
  }) async {
    final id = groupId.trim();
    final normalized = userIds
        .map(ChatIdFormat.rawUserUid)
        .where((item) => item.isNotEmpty)
        .toSet()
        .toList();
    if (id.isEmpty || normalized.isEmpty) {
      _groupInviteDiag(
        'inviteMembers INVALID_INPUT groupId="$id" userIds=$userIds',
      );
      return GroupInviteResponse(
        results: const <GroupInviteMemberResult>[],
        topLevelCode: 'INVALID_INPUT',
      );
    }

    final path = '${_groupPath(id)}/members';
    final body = <String, dynamic>{
      'userIds': normalized,
      if (message != null && message.trim().isNotEmpty)
        'message': message.trim(),
    };
    _groupInviteDiag('HTTP POST $path body=$body');

    try {
      final res = await _dio.post(path, data: body);
      _groupInviteDiag(
        'HTTP status=${res.statusCode} raw=${res.data}',
      );
      final unwrapped = unwrapApiPayload(res.data);
      _groupInviteDiag('unwrapped=$unwrapped');
      final parsed = GroupInviteResponse.fromPayload(
        unwrapped,
        requested: normalized,
      );
      _groupInviteDiag(
        'parsed topLevelCode=${parsed.topLevelCode} '
        'results=${parsed.results.map((e) => '${e.userId}:${e.status.name}'
            '${e.code == null ? '' : '(${e.code})'}').join(',')}',
      );
      return parsed;
    } on DioError catch (e) {
      final quotaError = GroupQuotaLimitError.tryParse(e.response?.data);
      _groupInviteDiag(
        'HTTP DioError status=${e.response?.statusCode} '
        'code=${readDioCode(e)} data=${e.response?.data}',
      );
      return GroupInviteResponse(
        results: normalized
            .map(
              (userId) => GroupInviteMemberResult(
                userId: userId,
                status: GroupInviteMemberStatus.failed,
                code: readDioCode(e),
              ),
            )
            .toList(),
        topLevelCode: readDioCode(e),
        quotaError: quotaError,
      );
    }
  }

  static String readDioCode(DioError error) {
    final data = error.response?.data;
    if (data is Map) {
      final map = Map<String, dynamic>.from(data);
      final code = map['code']?.toString().trim();
      if (code != null && code.isNotEmpty) {
        return code;
      }
      final message = map['message']?.toString().trim();
      if (message != null && message.isNotEmpty) {
        return message;
      }
    }
    final message = error.message.trim();
    return message.isNotEmpty ? message : 'REQUEST_FAILED';
  }
}

enum GroupInviteMemberStatus {
  added,
  alreadyMember,
  pending,
  failed,
}

class GroupInviteMemberResult {
  const GroupInviteMemberResult({
    required this.userId,
    required this.status,
    this.code,
    this.applicationId,
    this.imResult,
  });

  final String userId;
  final GroupInviteMemberStatus status;
  final String? code;
  final int? applicationId;
  final int? imResult;

  factory GroupInviteMemberResult.fromJson(Map<String, dynamic> json) {
    final userId = ChatIdFormat.rawUserUid(
      json['userId']?.toString() ?? json['memberID']?.toString() ?? '',
    );
    final statusRaw = json['status']?.toString().trim().toLowerCase() ?? '';
    GroupInviteMemberStatus status;
    switch (statusRaw) {
      case 'added':
        status = GroupInviteMemberStatus.added;
        break;
      case 'already_member':
        status = GroupInviteMemberStatus.alreadyMember;
        break;
      case 'pending':
        status = GroupInviteMemberStatus.pending;
        break;
      default:
        final imResult = _readInt(json['imResult'] ?? json['result']);
        if (imResult == 1) {
          status = GroupInviteMemberStatus.added;
        } else if (imResult == 3) {
          status = GroupInviteMemberStatus.pending;
        } else if (imResult == 2) {
          status = GroupInviteMemberStatus.alreadyMember;
        } else {
          status = GroupInviteMemberStatus.failed;
        }
    }
    return GroupInviteMemberResult(
      userId: userId,
      status: status,
      code: json['code']?.toString(),
      applicationId: _readInt(json['applicationId']),
      imResult: _readInt(json['imResult'] ?? json['result']),
    );
  }
}

class GroupInviteResponse {
  const GroupInviteResponse({
    required this.results,
    this.topLevelCode,
    this.quotaError,
  });

  final List<GroupInviteMemberResult> results;
  final String? topLevelCode;
  final GroupQuotaLimitError? quotaError;

  bool get hasSuccess => results.any(
        (item) =>
            item.status == GroupInviteMemberStatus.added ||
            item.status == GroupInviteMemberStatus.pending ||
            item.status == GroupInviteMemberStatus.alreadyMember,
      );

  bool get allFailed =>
      results.isNotEmpty &&
      results.every((item) => item.status == GroupInviteMemberStatus.failed);

  factory GroupInviteResponse.fromPayload(
    dynamic payload, {
    required List<String> requested,
  }) {
    if (payload is Map) {
      final map = Map<String, dynamic>.from(payload);
      final rawResults = map['results'] ?? map['items'] ?? map['members'];
      if (rawResults is List && rawResults.isNotEmpty) {
        final parsed = rawResults
            .whereType<Map>()
            .map(
              (item) => GroupInviteMemberResult.fromJson(
                Map<String, dynamic>.from(item),
              ),
            )
            .toList();
        if (parsed.isNotEmpty) {
          _groupInviteDiag(
            'fromPayload path=results_list count=${parsed.length}',
          );
          return GroupInviteResponse(results: parsed);
        }
        _groupInviteDiag(
          'fromPayload path=results_list_empty_maps rawResults=$rawResults',
        );
      } else {
        _groupInviteDiag(
          'fromPayload no usable results/items/members '
          'rawResultsType=${rawResults.runtimeType} rawResults=$rawResults',
        );
      }
      final code = map['code']?.toString();
      if (code != null && code.isNotEmpty) {
        _groupInviteDiag('fromPayload path=top_level_code code=$code');
        return GroupInviteResponse(
          results: requested
              .map(
                (userId) => GroupInviteMemberResult(
                  userId: userId,
                  status: GroupInviteMemberStatus.failed,
                  code: code,
                ),
              )
              .toList(),
          topLevelCode: code,
          quotaError: GroupQuotaLimitError.tryParse(map),
        );
      }
    } else {
      _groupInviteDiag(
        'fromPayload payloadNotMap type=${payload.runtimeType} value=$payload',
      );
    }
    _groupInviteDiag(
      'fromPayload path=FABRICATE_ADDED requested=$requested '
      '(HTTP ok but no results → treat all as added)',
    );
    return GroupInviteResponse(
      results: requested
          .map(
            (userId) => GroupInviteMemberResult(
              userId: userId,
              status: GroupInviteMemberStatus.added,
              imResult: 1,
            ),
          )
          .toList(),
    );
  }
}

enum GroupJoinOutcome {
  added,
  pending,
  failed,
}

class GroupJoinResult {
  const GroupJoinResult({
    required this.outcome,
    this.code,
    this.applicationId,
  });

  final GroupJoinOutcome outcome;
  final String? code;
  final int? applicationId;

  factory GroupJoinResult.fromPayload(dynamic payload) {
    if (payload is! Map) {
      return const GroupJoinResult(outcome: GroupJoinOutcome.added);
    }
    final map = Map<String, dynamic>.from(payload);
    final status = map['status']?.toString().trim().toLowerCase();
    switch (status) {
      case 'pending':
        return GroupJoinResult(
          outcome: GroupJoinOutcome.pending,
          applicationId: _readInt(map['applicationId']),
        );
      case 'failed':
        return GroupJoinResult(
          outcome: GroupJoinOutcome.failed,
          code: map['code']?.toString(),
        );
      case 'added':
      default:
        return const GroupJoinResult(outcome: GroupJoinOutcome.added);
    }
  }

  factory GroupJoinResult.failed(String code) {
    return GroupJoinResult(
      outcome: GroupJoinOutcome.failed,
      code: code,
    );
  }
}

class GroupJoinApplicationRecord {
  const GroupJoinApplicationRecord({
    required this.id,
    required this.groupId,
    required this.applicationType,
    required this.fromUserId,
    this.toUserId,
    this.message,
    this.status = 'pending',
    this.createdAtMs,
    this.handledAtMs,
    this.handledByUserId,
    this.handledByNickName,
    this.fromUserNickName,
    this.toUserNickName,
    this.fromUserFaceUrl,
    this.groupName,
    this.groupAvatarUrl,
  });

  final int id;
  final String groupId;
  final String applicationType;
  final String fromUserId;
  final String? toUserId;
  final String? message;
  final String status;
  final int? createdAtMs;
  final int? handledAtMs;
  final String? handledByUserId;
  final String? handledByNickName;
  final String? fromUserNickName;
  final String? toUserNickName;
  final String? fromUserFaceUrl;
  final String? groupName;
  final String? groupAvatarUrl;

  bool get isInvite => applicationType.trim().toLowerCase() == 'invite';

  factory GroupJoinApplicationRecord.fromJson(
    Map<String, dynamic> json, {
    String? fallbackGroupId,
  }) {
    final applicationType =
        json['applicationType']?.toString().trim().toLowerCase() ?? 'join';
    final isInvite = applicationType == 'invite';
    return GroupJoinApplicationRecord(
      id: _readInt(json['applicationId'] ?? json['id']) ?? 0,
      groupId: json['groupId']?.toString().trim().isNotEmpty == true
          ? json['groupId'].toString().trim()
          : (fallbackGroupId?.trim() ?? ''),
      applicationType: applicationType,
      fromUserId: ChatIdFormat.rawUserUid(
        json['fromUserId']?.toString() ??
            json['fromUser']?.toString() ??
            json['inviterUserId']?.toString() ??
            '',
      ),
      toUserId: _optionalUserId(
        json['toUserId'] ?? json['toUser'] ?? json['inviteeUserId'],
      ),
      message: json['message']?.toString() ?? json['requestMsg']?.toString(),
      status: json['status']?.toString().trim().toLowerCase() ?? 'pending',
      createdAtMs: readTimestampMs(
        json['createdAt'] ??
            json['createdAtMs'] ??
            json['addTime'] ??
            json['ts'],
      ),
      handledAtMs: readTimestampMs(json['handledAt'] ?? json['handledAtMs']),
      handledByUserId: _optionalUserId(
        json['handledByUserId'] ?? json['handlerUserId'],
      ),
      handledByNickName:
          json['handledByNickName']?.toString().trim().isNotEmpty == true
              ? json['handledByNickName'].toString().trim()
              : null,
      groupName: json['groupName']?.toString().trim(),
      groupAvatarUrl: json['groupAvatarUrl']?.toString().trim(),
      fromUserNickName: _readNickName(
        json,
        isInvite
            ? const [
                'fromUserNickName',
                'fromNickname',
                'fromNickName',
                'inviterNickName',
                'inviterNickname',
              ]
            : const [
                'fromUserNickName',
                'fromNickname',
                'fromNickName',
                'nickname',
                'nickName',
              ],
      ),
      toUserNickName: _readNickName(
        json,
        const [
          'toUserNickName',
          'toNickname',
          'toNickName',
          'inviteeNickName',
          'inviteeNickname',
          'inviteeNick',
        ],
      ),
      fromUserFaceUrl: json['fromUserFaceUrl']?.toString(),
    );
  }

  bool get isPending {
    final normalized = status.trim().toLowerCase();
    return normalized.isEmpty || normalized == 'pending';
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'applicationId': id,
      'groupId': groupId,
      'applicationType': applicationType,
      'fromUserId': fromUserId,
      if (toUserId != null) 'toUserId': toUserId,
      if (message != null) 'message': message,
      'status': status,
      if (createdAtMs != null) 'createdAtMs': createdAtMs,
      if (handledAtMs != null) 'handledAtMs': handledAtMs,
      if (handledByUserId != null) ...{
        'handledByUserId': handledByUserId,
        'handlerUserId': handledByUserId,
      },
      if (handledByNickName != null) 'handledByNickName': handledByNickName,
      if (fromUserNickName != null) 'fromUserNickName': fromUserNickName,
      if (toUserNickName != null) 'toUserNickName': toUserNickName,
      if (fromUserFaceUrl != null) 'fromUserFaceUrl': fromUserFaceUrl,
      if (groupName != null) 'groupName': groupName,
      if (groupAvatarUrl != null) 'groupAvatarUrl': groupAvatarUrl,
    };
  }

  static int? readTimestampMs(dynamic value) => _readTimestampMs(value);

  static String? _readNickName(
    Map<String, dynamic> json,
    List<String> keys,
  ) {
    for (final key in keys) {
      final value = json[key]?.toString().trim();
      if (value != null && value.isNotEmpty) {
        return value;
      }
    }
    return null;
  }

  static String? _optionalUserId(dynamic value) {
    final id = ChatIdFormat.rawUserUid(value?.toString() ?? '');
    return id.isEmpty ? null : id;
  }

  static int? _readTimestampMs(dynamic value) {
    final parsed = _readInt(value);
    if (parsed == null || parsed <= 0) {
      return null;
    }
    return parsed < 1000000000000 ? parsed * 1000 : parsed;
  }
}
