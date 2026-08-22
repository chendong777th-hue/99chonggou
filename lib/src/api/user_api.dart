import 'package:dio/dio.dart';

import 'package:tencent_cloud_chat_demo/src/api/auth_api.dart';
import 'package:tencent_cloud_chat_demo/src/models/me_group_record.dart';
import 'package:tencent_cloud_chat_demo/utils/api_response_util.dart';
import 'package:tencent_cloud_chat_demo/utils/chat_id_format.dart';

import 'api_client.dart';

/// `GET /users/{peerUserId}/common-groups` 分页结果。
class CommonGroupsPage {
  const CommonGroupsPage({
    required this.peerUserId,
    required this.items,
    required this.total,
    required this.limit,
    required this.offset,
  });

  final String peerUserId;
  final List<MeGroupRecord> items;
  final int total;
  final int limit;
  final int offset;

  factory CommonGroupsPage.fromJson(
    Map<String, dynamic> json, {
    String fallbackPeerUserId = '',
    int fallbackLimit = 50,
    int fallbackOffset = 0,
  }) {
    final list = extractApiList(
      json,
      listKeys: const ['items', 'groups', 'results'],
    );
    final items = list
        .whereType<Map>()
        .map((e) => MeGroupRecord.fromJson(Map<String, dynamic>.from(e)))
        .where((e) => e.groupId.isNotEmpty)
        .toList(growable: false);
    return CommonGroupsPage(
      peerUserId: ChatIdFormat.rawUserUid(
        json['peerUserId']?.toString() ??
            json['peer_user_id']?.toString() ??
            fallbackPeerUserId,
      ),
      items: items,
      total: _readInt(json, const ['total'], fallback: items.length),
      limit: _readInt(json, const ['limit'], fallback: fallbackLimit),
      offset: _readInt(json, const ['offset'], fallback: fallbackOffset),
    );
  }
}

int _readInt(
  Map<String, dynamic> json,
  List<String> keys, {
  required int fallback,
}) {
  for (final key in keys) {
    final value = json[key];
    if (value is int) {
      return value;
    }
    if (value is num) {
      return value.toInt();
    }
    if (value is String) {
      final parsed = int.tryParse(value.trim());
      if (parsed != null) {
        return parsed;
      }
    }
  }
  return fallback;
}

class UserApi {
  UserApi._();
  static final UserApi instance = UserApi._();


  Dio get _dio => ApiClient.instance.dio;

  Future<AddFriendPrivacySettings> fetchPrivacy() async {
    final res = await _dio.get('/me/privacy');
    return AddFriendPrivacySettings.fromJson(_payloadMap(res.data));
  }

  /// 读取指定用户的加好友隐私（需 JWT）。
  /// 用户不存在或已禁用 → 404，返回 null。
  Future<AddFriendPrivacySettings?> fetchUserPrivacy(String userId) async {
    final id = userId.trim();
    if (id.isEmpty) {
      return null;
    }
    try {
      final res = await _dio.get('/users/$id/privacy');
      return AddFriendPrivacySettings.fromJson(_payloadMap(res.data));
    } on DioError catch (e) {
      if (e.response?.statusCode == 404) {
        return null;
      }
      rethrow;
    }
  }

  /// 按渠道预检是否允许添加好友（card | qr | group）。
  Future<AddFriendCheckResult> checkAddFriend({
    required String targetUserId,
    required String channel,
  }) async {
    final res = await _dio.post('/users/add-friend/check', data: {
      'targetUserId': targetUserId.trim(),
      'channel': channel.trim(),
    });
    return AddFriendCheckResult.fromJson(_payloadMap(res.data));
  }

  /// 是否允许通过二维码添加该用户。
  Future<bool> canAddFriendViaQr(String targetUserId) async {
    final id = targetUserId.trim();
    if (id.isEmpty) {
      return false;
    }
    try {
      final check = await checkAddFriend(
        targetUserId: id,
        channel: AddFriendCheckChannel.qr,
      );
      return check.allowed;
    } catch (_) {
      try {
        final remote = await fetchUserPrivacy(id);
        return remote?.allowViaQrCode ?? false;
      } catch (_) {
        return false;
      }
    }
  }

  Future<AddFriendPrivacySettings> updatePrivacy(
    AddFriendPrivacySettings settings,
  ) async {
    final res = await _dio.put('/me/privacy', data: settings.toJson());
    return AddFriendPrivacySettings.fromJson(_payloadMap(res.data));
  }

  /// GET /me/friend-add-verify
  Future<FriendAddVerifySettings> fetchFriendAddVerify() async {
    final res = await _dio.get('/me/friend-add-verify');
    return FriendAddVerifySettings.fromJson(_payloadMap(res.data));
  }

  /// PUT /me/friend-add-verify
  Future<FriendAddVerifySettings> updateFriendAddVerify({
    required bool friendAddRequiresVerify,
  }) async {
    final res = await _dio.put('/me/friend-add-verify', data: {
      'friendAddRequiresVerify': friendAddRequiresVerify,
    });
    return FriendAddVerifySettings.fromJson(_payloadMap(res.data));
  }

  /// GET /me/online-privacy-protection
  Future<OnlinePrivacySettings> fetchOnlinePrivacyProtection() async {
    final res = await _dio.get('/me/online-privacy-protection');
    return OnlinePrivacySettings.fromJson(_payloadMap(res.data));
  }

  /// PUT /me/online-privacy-protection
  Future<OnlinePrivacySettings> updateOnlinePrivacyProtection({
    required String lastActiveVisibility,
  }) async {
    final res = await _dio.put('/me/online-privacy-protection', data: {
      'lastActiveVisibility':
          LastActiveVisibility.normalize(lastActiveVisibility),
    });
    return OnlinePrivacySettings.fromJson(_payloadMap(res.data));
  }

  /// GET /users/{userId}/online-privacy-protection
  Future<OnlinePrivacySettings?> fetchUserOnlinePrivacyProtection(
    String userId,
  ) async {
    final id = userId.trim();
    if (id.isEmpty) {
      return null;
    }
    try {
      final res = await _dio.get('/users/$id/online-privacy-protection');
      return OnlinePrivacySettings.fromJson(_payloadMap(res.data));
    } on DioError catch (e) {
      if (e.response?.statusCode == 404) {
        return null;
      }
      rethrow;
    }
  }

  Future<UserSearchResult> searchUser({
    required String keyword,
    String? phoneCountry,
  }) async {
    final res = await _dio.post('/users/search', data: {
      'keyword': keyword.trim(),
      if (phoneCountry != null && phoneCountry.isNotEmpty)
        'phoneCountry': phoneCountry,
    });
    return UserSearchResult.fromJson(_payloadMap(res.data));
  }

  /// 按 userId 拉取用户公开资料：`GET /users/{userId}/profile`（需登录）。
  ///
  /// 已知 UID 场景使用本方法，**不走** `POST /users/search`，不计搜人频控。
  /// 用户不存在或已禁用 → 404，返回 null。
  Future<UserSearchResult?> tryFetchUserById(String userId) async {
    final id = ChatIdFormat.rawUserUid(userId);
    if (id.isEmpty) {
      return null;
    }
    try {
      final res = await _dio.get(
        '/users/${Uri.encodeComponent(id)}/profile',
      );
      final result = UserSearchResult.fromJson(_payloadMap(res.data));
      if (ChatIdFormat.rawUserUid(result.userId) != id) {
        return null;
      }
      return result;
    } on DioError catch (e) {
      if (e.response?.statusCode == 404) {
        return null;
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  /// 批量匹配通讯录手机号（注册状态 + 是否好友）。
  Future<List<ContactMatchItem>> matchContacts({
    required List<String> phones,
    String? phoneCountry,
    bool includeFriendStatus = true,
  }) async {
    if (phones.isEmpty) {
      return const [];
    }
    final res = await _dio.post('/users/contacts/match', data: {
      'phones': phones,
      if (phoneCountry != null && phoneCountry.isNotEmpty)
        'phoneCountry': phoneCountry,
      'includeFriendStatus': includeFriendStatus,
    });
    return ContactMatchResponse.fromJson(_payloadMap(res.data)).items;
  }

  Future<NicknameCheckResult> checkNickname(String nickname) {
    return _checkNicknameWithPaths(
      nickname,
      const ['/me/nickname/check'],
    );
  }

  /// 注册页未登录状态下使用公开昵称可用性接口。
  ///
  /// 固定请求 GET /nicknames/available?nickname=xxx。
  /// 该接口不需要登录 token，避免注册页输入时触发 401 和卡顿。
  Future<NicknameCheckResult> checkNicknameForRegister(String nickname) async {
    final value = nickname.trim();
    final res = await _dio.get(
      '/nicknames/available',
      queryParameters: {'nickname': value},
    );
    return _nicknameCheckResultFromRaw(res.data, boolAsExists: false);
  }

  Future<NicknameCheckResult> _checkNicknameWithPaths(
    String nickname,
    List<String> paths,
  ) async {
    final value = nickname.trim();
    DioError? lastError;
    for (final path in paths) {
      try {
        final res = await _dio.get(
          path,
          queryParameters: {'nickname': value},
        );
        return _nicknameCheckResultFromRaw(res.data);
      } on DioError catch (e) {
        lastError = e;
        if (_shouldTryNextNicknameCheckPath(e)) {
          continue;
        }
        rethrow;
      }
    }
    if (lastError != null) {
      throw lastError;
    }
    return NicknameCheckResult(available: true);
  }

  bool _shouldTryNextNicknameCheckPath(DioError e) {
    final status = e.response?.statusCode;
    return status == 404 || status == 405;
  }

  bool _isNicknameExistsError(DioError e) {
    final data = e.response?.data;
    final payload = unwrapApiPayload(data);
    if (payload is Map) {
      final map = Map<String, dynamic>.from(payload);
      final reason = _readKnownNicknameReason(
        map['reason'] ?? map['code'] ?? map['message'] ?? map['msg'],
      );
      if (reason == 'NICKNAME_EXISTS') return true;
    }
    if (data is Map) {
      final map = Map<String, dynamic>.from(data);
      final reason = _readKnownNicknameReason(
        map['reason'] ?? map['code'] ?? map['message'] ?? map['msg'],
      );
      if (reason == 'NICKNAME_EXISTS') return true;
    }
    final message = e.message;
    return _readKnownNicknameReason(message) == 'NICKNAME_EXISTS';
  }

  Future<NicknameUpdateResult> updateNickname(String nickname) async {
    final res = await _dio.patch(
      '/me/nickname',
      data: {'nickname': nickname.trim()},
    );
    return NicknameUpdateResult.fromJson(_payloadMap(res.data));
  }

  /// 当前登录用户与对方的共同群聊：`GET /users/{peerUserId}/common-groups`
  Future<CommonGroupsPage> fetchCommonGroups(
    String peerUserId, {
    int limit = 50,
    int offset = 0,
  }) async {
    final peer = ChatIdFormat.rawUserUid(peerUserId);
    if (peer.isEmpty) {
      return const CommonGroupsPage(
        peerUserId: '',
        items: [],
        total: 0,
        limit: 50,
        offset: 0,
      );
    }
    final res = await _dio.get(
      '/users/${Uri.encodeComponent(peer)}/common-groups',
      queryParameters: <String, dynamic>{
        'limit': limit.clamp(1, 500),
        'offset': offset < 0 ? 0 : offset,
      },
    );
    return CommonGroupsPage.fromJson(
      _payloadMap(res.data),
      fallbackPeerUserId: peer,
      fallbackLimit: limit,
      fallbackOffset: offset,
    );
  }
}

Map<String, dynamic> _payloadMap(dynamic raw) {
  final payload = unwrapApiPayload(raw);
  if (payload is Map<String, dynamic>) {
    return payload;
  }
  if (payload is Map) {
    return Map<String, dynamic>.from(payload);
  }
  return const <String, dynamic>{};
}


bool? _readBool(Map<String, dynamic> json, List<String> keys) {
  for (final key in keys) {
    final value = json[key];
    if (value is bool) return value;
    if (value is num) return value != 0;
    if (value is String) {
      final normalized = value.trim().toLowerCase();
      if (normalized == 'true' || normalized == '1' || normalized == 'yes') {
        return true;
      }
      if (normalized == 'false' || normalized == '0' || normalized == 'no') {
        return false;
      }
    }
  }
  return null;
}

String? _readString(Map<String, dynamic> json, List<String> keys) {
  for (final key in keys) {
    final value = json[key];
    if (value is String && value.trim().isNotEmpty) {
      return value.trim();
    }
  }
  return null;
}

String? _readKnownNicknameReason(dynamic value) {
  final text = value?.toString().trim();
  if (text == null || text.isEmpty || text == '0') return null;
  final upper = text.toUpperCase();
  switch (upper) {
    case 'NICKNAME_EXISTS':
    case 'USERNAME_EXISTS':
    case 'NICKNAME_TAKEN':
    case 'USERNAME_TAKEN':
      return 'NICKNAME_EXISTS';
    case 'NICKNAME_COOLDOWN':
      return 'NICKNAME_COOLDOWN';
    case 'INVALID_INPUT':
      return 'INVALID_INPUT';
    case 'NICKNAME_CHECK_UNAVAILABLE':
      return 'NICKNAME_CHECK_UNAVAILABLE';
  }
  final lower = text.toLowerCase();
  if (lower.contains('nickname_exists') ||
      lower.contains('username_exists') ||
      lower.contains('nickname already') ||
      lower.contains('username already') ||
      lower.contains('already exists') ||
      lower.contains('taken') ||
      text.contains('用户名已存在') ||
      text.contains('昵称已存在') ||
      text.contains('昵称已被使用')) {
    return 'NICKNAME_EXISTS';
  }
  return null;
}


NicknameCheckResult _nicknameCheckResultFromRaw(
  dynamic raw, {
  bool boolAsExists = true,
}) {
  final payload = unwrapApiPayload(raw);
  if (payload is bool) {
    final exists = boolAsExists ? payload : !payload;
    return NicknameCheckResult(
      available: !exists,
      reason: exists ? 'NICKNAME_EXISTS' : null,
    );
  }
  if (payload is num) {
    final exists = boolAsExists ? payload != 0 : payload == 0;
    return NicknameCheckResult(
      available: !exists,
      reason: exists ? 'NICKNAME_EXISTS' : null,
    );
  }
  if (payload is String) {
    final normalized = payload.trim().toLowerCase();
    if (normalized == 'true' || normalized == '1' || normalized == 'yes') {
      final exists = boolAsExists;
      return NicknameCheckResult(
        available: !exists,
        reason: exists ? 'NICKNAME_EXISTS' : null,
      );
    }
    if (normalized == 'false' || normalized == '0' || normalized == 'no') {
      final exists = !boolAsExists;
      return NicknameCheckResult(
        available: !exists,
        reason: exists ? 'NICKNAME_EXISTS' : null,
      );
    }
  }
  if (payload is Map<String, dynamic>) {
    return NicknameCheckResult.fromJson(payload);
  }
  if (payload is Map) {
    return NicknameCheckResult.fromJson(Map<String, dynamic>.from(payload));
  }
  return NicknameCheckResult(
    available: false,
    reason: 'NICKNAME_CHECK_UNAVAILABLE',
  );
}

class NicknameCheckResult {
  NicknameCheckResult({
    required this.available,
    this.reason,
    this.nextChangeableAt,
  });

  final bool available;
  final String? reason;
  final DateTime? nextChangeableAt;

  factory NicknameCheckResult.fromJson(Map<String, dynamic> json) {
    final available = _readBool(json, const [
      'available',
      'isAvailable',
      'is_available',
      'valid',
      'canUse',
      'can_use',
      'usable',
      'ok',
    ]);
    final exists = _readBool(json, const [
      'exists',
      'exist',
      'isExists',
      'is_exists',
      'nicknameExists',
      'nickname_exists',
      'usernameExists',
      'username_exists',
      'duplicated',
      'duplicate',
      'taken',
      'used',
      'isUsed',
      'is_used',
    ]);
    final reason = _readKnownNicknameReason(
      json['reason'] ?? json['code'] ?? json['message'] ?? json['msg'],
    );
    return NicknameCheckResult(
      available: available ?? (exists != null ? !exists : reason == null),
      reason: reason,
      nextChangeableAt: MeResult.parseIsoDateTime(
        json['nextChangeableAt'] ?? json['next_changeable_at'],
      ),
    );
  }
}

class NicknameUpdateResult {
  NicknameUpdateResult({
    required this.nickname,
    this.nextChangeableAt,
  });

  final String nickname;
  final DateTime? nextChangeableAt;

  factory NicknameUpdateResult.fromJson(Map<String, dynamic> json) =>
      NicknameUpdateResult(
        nickname: _readString(json, const ['nickname', 'nickName', 'name']) ?? '',
        nextChangeableAt: MeResult.parseIsoDateTime(
          json['nextChangeableAt'] ?? json['next_changeable_at'],
        ),
      );
}



/// 加好友渠道，与 POST /users/add-friend/check 的 channel 一致。
class AddFriendCheckChannel {
  AddFriendCheckChannel._();

  static const String card = 'card';
  static const String qr = 'qr';
  static const String group = 'group';
}

class AddFriendCheckResult {
  AddFriendCheckResult({
    required this.allowed,
    this.reason,
  });

  final bool allowed;
  final String? reason;

  factory AddFriendCheckResult.fromJson(Map<String, dynamic> json) =>
      AddFriendCheckResult(
        allowed: json['allowed'] as bool? ?? false,
        reason: json['reason'] as String?,
      );
}

class FriendAddVerifySettings {
  FriendAddVerifySettings({required this.friendAddRequiresVerify});

  final bool friendAddRequiresVerify;

  factory FriendAddVerifySettings.fromJson(Map<String, dynamic> json) =>
      FriendAddVerifySettings(
        friendAddRequiresVerify: json['friendAddRequiresVerify'] as bool? ??
            json['friend_add_requires_verify'] as bool? ??
            true,
      );
}

/// `everyone` · `friends_only` · `hidden`
class LastActiveVisibility {
  LastActiveVisibility._();

  static const String everyone = 'everyone';
  static const String friendsOnly = 'friends_only';
  static const String hidden = 'hidden';

  static String normalize(String? raw) {
    final value = raw?.trim().toLowerCase() ?? '';
    switch (value) {
      case friendsOnly:
        return friendsOnly;
      case hidden:
        return hidden;
      case everyone:
        return everyone;
      default:
        return everyone;
    }
  }

  /// 是否可向当前用户展示精确最后上线时间（含「在线」文案/绿点）。
  static bool shouldShowLastActive({
    required String? visibility,
    required bool isMutualFriend,
  }) {
    final value = visibility?.trim().toLowerCase() ?? '';
    switch (value) {
      case everyone:
        return true;
      case friendsOnly:
        return isMutualFriend;
      case hidden:
        return false;
      default:
        return false;
    }
  }

  /// 对方开启「不显示在线时间」时，仅展示粗粒度分档文案。
  static bool shouldShowCoarseLastActive({required String? visibility}) {
    return normalize(visibility) == hidden;
  }

  /// 是否展示任意形式的最后上线文案（精确或粗粒度）。
  static bool shouldShowAnyLastActive({
    required String? visibility,
    required bool isMutualFriend,
  }) {
    return shouldShowLastActive(
          visibility: visibility,
          isMutualFriend: isMutualFriend,
        ) ||
        shouldShowCoarseLastActive(visibility: visibility);
  }
}

class OnlinePrivacySettings {
  OnlinePrivacySettings({required this.lastActiveVisibility});

  final String lastActiveVisibility;

  factory OnlinePrivacySettings.fromJson(Map<String, dynamic> json) =>
      OnlinePrivacySettings(
        lastActiveVisibility: LastActiveVisibility.normalize(
          json['lastActiveVisibility']?.toString() ??
              json['last_active_visibility']?.toString(),
        ),
      );
}

class AddFriendPrivacySettings {
  AddFriendPrivacySettings({
    required this.allowViaQrCode,
    required this.allowViaCard,
    required this.allowViaGroup,
    required this.allowViaPhone,
    required this.allowViaUid,
  });

  bool allowViaQrCode;
  bool allowViaCard;
  bool allowViaGroup;
  bool allowViaPhone;
  bool allowViaUid;

  factory AddFriendPrivacySettings.defaults() => AddFriendPrivacySettings(
        allowViaQrCode: true,
        allowViaCard: true,
        allowViaGroup: true,
        allowViaPhone: true,
        allowViaUid: true,
      );

  factory AddFriendPrivacySettings.fromJson(Map<String, dynamic> json) =>
      AddFriendPrivacySettings(
        allowViaQrCode: json['allowViaQrCode'] as bool? ?? true,
        allowViaCard: json['allowViaCard'] as bool? ?? true,
        allowViaGroup: json['allowViaGroup'] as bool? ?? true,
        allowViaPhone: json['allowViaPhone'] as bool? ?? true,
        allowViaUid: json['allowViaUid'] as bool? ?? true,
      );

  Map<String, dynamic> toJson() => {
        'allowViaQrCode': allowViaQrCode,
        'allowViaCard': allowViaCard,
        'allowViaGroup': allowViaGroup,
        'allowViaPhone': allowViaPhone,
        'allowViaUid': allowViaUid,
      };

  AddFriendPrivacySettings copyWith({
    bool? allowViaQrCode,
    bool? allowViaCard,
    bool? allowViaGroup,
    bool? allowViaPhone,
    bool? allowViaUid,
  }) {
    return AddFriendPrivacySettings(
      allowViaQrCode: allowViaQrCode ?? this.allowViaQrCode,
      allowViaCard: allowViaCard ?? this.allowViaCard,
      allowViaGroup: allowViaGroup ?? this.allowViaGroup,
      allowViaPhone: allowViaPhone ?? this.allowViaPhone,
      allowViaUid: allowViaUid ?? this.allowViaUid,
    );
  }
}


int? _parseNullableTimestamp(Object? value) {
  if (value == null) return null;
  if (value is int) return value < 1000000000000 ? value * 1000 : value;
  if (value is num) {
    final intValue = value.toInt();
    return intValue < 1000000000000 ? intValue * 1000 : intValue;
  }
  final text = value.toString().trim();
  if (text.isEmpty) return null;
  final numeric = int.tryParse(text);
  if (numeric != null) {
    return numeric < 1000000000000 ? numeric * 1000 : numeric;
  }
  final dt = DateTime.tryParse(text);
  return dt?.toUtc().millisecondsSinceEpoch;
}

class UserSearchResult {
  UserSearchResult({
    required this.userId,
    required this.nickname,
    this.avatarUrl,
    this.phoneMasked,
    this.lastActiveAt,
    this.lastActiveVisibility,
  });

  final String userId;
  final String nickname;
  final String? avatarUrl;
  final String? phoneMasked;
  final int? lastActiveAt;
  final String? lastActiveVisibility;

  factory UserSearchResult.fromJson(Map<String, dynamic> json) {
    final avatar = json['avatarUrl'] ?? json['faceUrl'] ?? json['avatar'];
    final lastActiveRaw = json['lastActiveAt'] ?? json['last_active_at'];
    return UserSearchResult(
      userId: (json['userId'] ?? json['userID'] ?? json['uid'] ?? '').toString(),
      nickname: (json['nickname'] ?? json['nickName'] ?? '').toString(),
      avatarUrl: avatar is String && avatar.trim().isNotEmpty ? avatar.trim() : null,
      phoneMasked: (json['phoneMasked'] ?? json['phone_masked'])?.toString(),
      lastActiveAt: _parseNullableTimestamp(lastActiveRaw),
      lastActiveVisibility: json['lastActiveVisibility']?.toString() ??
          json['last_active_visibility']?.toString(),
    );
  }
}

class ContactMatchItem {
  ContactMatchItem({
    required this.phone,
    required this.registered,
    this.userId,
    this.nickname,
    this.avatarUrl,
    this.isFriend,
    this.lastActiveAt,
    this.lastActiveVisibility,
  });

  final String phone;
  final bool registered;
  final String? userId;
  final String? nickname;
  final String? avatarUrl;
  final bool? isFriend;
  final int? lastActiveAt;
  final String? lastActiveVisibility;

  factory ContactMatchItem.fromJson(Map<String, dynamic> json) {
    final avatar = json['avatarUrl'] ?? json['faceUrl'] ?? json['avatar'];
    return ContactMatchItem(
      phone: (json['phone'] ?? '').toString(),
      registered: _readBool(json, const ['registered']) ?? false,
      userId: (json['userId'] ?? json['userID'] ?? json['uid'])?.toString(),
      nickname: (json['nickname'] ?? json['nickName'])?.toString(),
      avatarUrl: avatar is String && avatar.trim().isNotEmpty ? avatar.trim() : null,
      isFriend: _readBool(json, const ['isFriend', 'is_friend']),
      lastActiveAt: _parseNullableTimestamp(
        json['lastActiveAt'] ?? json['last_active_at'],
      ),
      lastActiveVisibility: json['lastActiveVisibility']?.toString() ??
          json['last_active_visibility']?.toString(),
    );
  }

  UserSearchResult? toUserSearchResult() {
    if (!registered) {
      return null;
    }
    final id = (userId ?? '').trim();
    if (id.isEmpty) {
      return null;
    }
    return UserSearchResult(
      userId: id,
      nickname: (nickname ?? '').trim().isNotEmpty ? nickname!.trim() : id,
      avatarUrl: avatarUrl,
      lastActiveAt: lastActiveAt,
      lastActiveVisibility: lastActiveVisibility,
    );
  }
}

class ContactMatchResponse {
  ContactMatchResponse({required this.items});

  final List<ContactMatchItem> items;

  factory ContactMatchResponse.fromJson(Map<String, dynamic> json) {
    final rawItems = extractApiList(json, listKeys: const ['items']);
    return ContactMatchResponse(
      items: rawItems
          .whereType<Map>()
          .map((e) => ContactMatchItem.fromJson(Map<String, dynamic>.from(e)))
          .where((e) => e.phone.trim().isNotEmpty)
          .toList(),
    );
  }
}
