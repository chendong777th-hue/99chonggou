/// 群加入/社群创建额度业务错误（HTTP 403 body）。
class GroupOverLimitUser {
  const GroupOverLimitUser({
    required this.userId,
    required this.used,
    required this.max,
    required this.limitType,
  });

  final String userId;
  final int used;
  final int max;

  /// `join` | `communityJoin` | `communityCreate`
  final String limitType;

  factory GroupOverLimitUser.fromJson(Map<String, dynamic> json) {
    return GroupOverLimitUser(
      userId: json['userId']?.toString().trim() ?? '',
      used: _readInt(json['used']),
      max: _readInt(json['max']),
      limitType: json['limitType']?.toString().trim() ?? '',
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
}

class GroupQuotaLimitError {
  const GroupQuotaLimitError({
    required this.code,
    this.message = '',
    this.overLimitUsers = const <GroupOverLimitUser>[],
  });

  final String code;
  final String message;
  final List<GroupOverLimitUser> overLimitUsers;

  String get normalizedCode => code.trim().toUpperCase();

  bool get isCommunityCreateLimit {
    final c = normalizedCode;
    return c == 'GROUP_CREATE_LIMIT_COMMUNITY' ||
        c == 'CREATE_LIMIT_EXCEEDED' ||
        (c.contains('GROUP_CREATE_LIMIT') &&
            !c.contains('JOIN') &&
            overLimitUsers.every(
              (u) =>
                  u.limitType.isEmpty ||
                  u.limitType.toLowerCase() == 'communitycreate',
            ));
  }

  bool get isCommunityJoinLimit {
    final c = normalizedCode;
    if (c.contains('GROUP_JOIN_LIMIT_COMMUNITY')) {
      return true;
    }
    if (overLimitUsers.any(
      (u) => u.limitType.toLowerCase() == 'communityjoin',
    )) {
      return true;
    }
    return false;
  }

  bool get isJoinLimit {
    final c = normalizedCode;
    if (c == 'GROUP_JOIN_LIMIT_EXCEEDED' ||
        c.contains('GROUP_JOIN_LIMIT')) {
      return true;
    }
    return overLimitUsers.any((u) {
      final t = u.limitType.toLowerCase();
      return t == 'join' || t == 'communityjoin';
    });
  }

  bool get isQuotaLimit => isJoinLimit || isCommunityCreateLimit;

  static GroupQuotaLimitError? tryParse(dynamic data) {
    final map = _asMap(data);
    if (map == null) {
      return null;
    }
    final nested = _asMap(map['data']) ?? _asMap(map['error']);
    final source = nested ?? map;
    final code = (source['code'] ?? map['code'])?.toString().trim() ?? '';
    if (code.isEmpty) {
      return null;
    }
    final upper = code.toUpperCase();
    final looksLikeQuota = upper.contains('GROUP_JOIN_LIMIT') ||
        upper.contains('GROUP_CREATE_LIMIT') ||
        upper == 'CREATE_LIMIT_EXCEEDED' ||
        upper == 'GROUP_JOIN_LIMIT_EXCEEDED';
    final rawUsers =
        source['overLimitUsers'] ?? map['overLimitUsers'] ?? const [];
    final users = <GroupOverLimitUser>[];
    if (rawUsers is List) {
      for (final item in rawUsers) {
        if (item is Map) {
          users.add(
            GroupOverLimitUser.fromJson(Map<String, dynamic>.from(item)),
          );
        }
      }
    }
    if (!looksLikeQuota && users.isEmpty) {
      return null;
    }
    final message =
        (source['message'] ?? map['message'])?.toString().trim() ?? '';
    return GroupQuotaLimitError(
      code: code,
      message: message,
      overLimitUsers: users,
    );
  }

  static Map<String, dynamic>? _asMap(dynamic value) {
    if (value is Map<String, dynamic>) {
      return value;
    }
    if (value is Map) {
      return Map<String, dynamic>.from(value);
    }
    return null;
  }
}
