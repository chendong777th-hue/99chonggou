import 'package:dio/dio.dart';
import 'package:tencent_cloud_chat_demo/utils/api_response_util.dart';
import 'package:tencent_cloud_chat_sdk/enum/group_type.dart';

import 'api_client.dart';

class GroupTypeCreateLimitInfo {
  const GroupTypeCreateLimitInfo({
    required this.groupType,
    required this.max,
    required this.used,
    required this.remaining,
    required this.limited,
  });

  final String groupType;
  final int max;
  final int used;
  final int remaining;
  final bool limited;

  /// 创建或加入桶是否仍有名额（语义由调用方决定）。
  bool get canCreate {
    if (remaining <= 0 && max > 0) {
      return false;
    }
    return !limited || remaining > 0;
  }

  bool get canJoin => canCreate;

  bool get isExhausted {
    if (max > 0 && remaining <= 0) {
      return true;
    }
    return limited && remaining <= 0;
  }

  factory GroupTypeCreateLimitInfo.fromJson(Map<String, dynamic> json) {
    return GroupTypeCreateLimitInfo(
      groupType: json['groupType']?.toString() ?? '',
      max: _readInt(json['max']),
      used: _readInt(json['used']),
      remaining: _readInt(json['remaining']),
      limited: _readBool(json['limited']),
    );
  }

  static int _readInt(dynamic value) {
    if (value is int) {
      return value;
    }
    if (value is num) {
      return value.toInt();
    }
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  static bool _readBool(dynamic value) {
    if (value is bool) {
      return value;
    }
    if (value is num) {
      return value != 0;
    }
    final text = value?.toString().trim().toLowerCase() ?? '';
    return text == 'true' || text == '1' || text == 'yes' || text == 'on';
  }
}

/// v2.0：加入分桶 + 社群创建；Work 创建限制已取消。
class GroupCreateLimitsResponse {
  const GroupCreateLimitsResponse({
    required this.enabled,
    this.joinGroups,
    this.communityJoinGroups,
    this.communityGroups,
  });

  final bool enabled;
  final GroupTypeCreateLimitInfo? joinGroups;
  final GroupTypeCreateLimitInfo? communityJoinGroups;
  final GroupTypeCreateLimitInfo? communityGroups;

  /// 仅返回**创建**额度：只有 Community；Work/Public 创建不限制。
  GroupTypeCreateLimitInfo? infoForGroupType(String groupType) {
    if (groupType == GroupType.Community) {
      return communityGroups;
    }
    return null;
  }

  GroupTypeCreateLimitInfo? joinInfoForGroupType(String groupType) {
    switch (groupType) {
      case GroupType.Community:
        return communityJoinGroups;
      case GroupType.Public:
      case GroupType.Work:
      case GroupType.Meeting:
        return joinGroups;
      default:
        return joinGroups;
    }
  }

  bool get canJoinNonCommunity {
    if (!enabled) {
      return true;
    }
    final info = joinGroups;
    if (info == null) {
      return true;
    }
    return info.canJoin;
  }

  bool get canJoinCommunity {
    if (!enabled) {
      return true;
    }
    final info = communityJoinGroups;
    if (info == null) {
      return true;
    }
    return info.canJoin;
  }

  bool canCreateGroupType(String groupType) {
    if (!enabled) {
      return true;
    }
    if (groupType != GroupType.Community) {
      return true;
    }
    final info = communityGroups;
    if (info == null) {
      return true;
    }
    return info.canCreate;
  }

  /// 作为群主发起建群：创建额度 ∧ 对应加入额度（建群也占加入名额）。
  bool canStartCreateAsOwner(String groupType) {
    if (!enabled) {
      return true;
    }
    if (!canCreateGroupType(groupType)) {
      return false;
    }
    final joinInfo = joinInfoForGroupType(groupType);
    if (joinInfo == null) {
      return true;
    }
    return joinInfo.canJoin;
  }

  factory GroupCreateLimitsResponse.fromJson(Map<String, dynamic> json) {
    GroupTypeCreateLimitInfo? parseInfo(dynamic raw) {
      if (raw is Map<String, dynamic>) {
        return GroupTypeCreateLimitInfo.fromJson(raw);
      }
      if (raw is Map) {
        return GroupTypeCreateLimitInfo.fromJson(Map<String, dynamic>.from(raw));
      }
      return null;
    }

    return GroupCreateLimitsResponse(
      enabled: GroupTypeCreateLimitInfo._readBool(json['enabled']),
      joinGroups: parseInfo(json['joinGroups']),
      communityJoinGroups: parseInfo(json['communityJoinGroups']),
      communityGroups: parseInfo(json['communityGroups']),
    );
  }
}

class GroupCreateLimitApi {
  GroupCreateLimitApi._();
  static final GroupCreateLimitApi instance = GroupCreateLimitApi._();

  Dio get _dio => ApiClient.instance.dio;

  Future<GroupCreateLimitsResponse> fetch() async {
    final res = await _dio.get('/me/group-create-limits');
    final payload = unwrapApiPayload(res.data);
    if (payload is Map<String, dynamic>) {
      return GroupCreateLimitsResponse.fromJson(payload);
    }
    if (payload is Map) {
      return GroupCreateLimitsResponse.fromJson(Map<String, dynamic>.from(payload));
    }
    return const GroupCreateLimitsResponse(enabled: false);
  }
}
