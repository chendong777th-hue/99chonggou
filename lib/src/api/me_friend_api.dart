import 'package:dio/dio.dart';
import 'package:tencent_cloud_chat_demo/src/models/friend_contact_change.dart';
import 'package:tencent_cloud_chat_demo/src/services/friend_local/friend_local_store.dart';
import 'package:tencent_cloud_chat_demo/src/services/friend_local/friend_sync_service.dart';
import 'package:tencent_cloud_chat_demo/src/services/friend_realtime/friend_realtime_event.dart';
import 'package:tencent_cloud_chat_demo/src/services/platform_official_account_service.dart';
import 'package:tencent_cloud_chat_demo/utils/api_response_util.dart';
import 'package:tencent_cloud_chat_demo/utils/chat_id_format.dart';
import 'package:tencent_cloud_chat_sdk/enum/friend_type_enum.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_friend_info.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_friend_info.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_user_full_info.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_user_full_info.dart';
import 'package:tencent_cloud_chat_sdk/tencent_im_sdk_plugin.dart';
import 'package:tencent_cloud_chat_uikit/tencent_cloud_chat_uikit.dart';

import 'api_client.dart';

class MeFriendApi {
  MeFriendApi._();
  static final MeFriendApi instance = MeFriendApi._();

  static const Duration _relationCacheTtl = Duration(seconds: 8);

  final Map<String, Future<FriendRelation?>> _relationRequests =
      <String, Future<FriendRelation?>>{};
  final Map<String, _CachedFriendRelation> _relationCache =
      <String, _CachedFriendRelation>{};

  Dio get _dio => ApiClient.instance.dio;

  String? _currentSelfUserId() {
    try {
      final id = ChatIdFormat.rawUserUid(
        TIMUIKitCore.getInstance().loginInfo.userID,
      );
      return id.isEmpty ? null : id;
    } catch (_) {
      return null;
    }
  }

  bool _isSelfPeer(String peerUserId) {
    final self = _currentSelfUserId();
    if (self == null) {
      return false;
    }
    return ChatIdFormat.rawUserUid(peerUserId) == self;
  }

  /// GET /me/friends — 读本地库（UI 数据源）。
  Future<List<MeFriendRecord>> fetchFriends() async {
    return FriendLocalStore.instance.readAll();
  }

  /// GET /me/friends — 仅网络拉取（供全量同步使用）。
  Future<List<MeFriendRecord>> fetchFriendsFromNetwork() async {
    final snapshot = await fetchFriendsSnapshotFromNetwork();
    return snapshot.records;
  }

  /// Snapshot：分页拉齐通讯录，并带回 `syncSeq` 供本地游标重置。
  Future<MeFriendsNetworkSnapshot> fetchFriendsSnapshotFromNetwork({
    int pageLimit = 100,
    int maxPages = 200,
  }) async {
    final safeLimit = pageLimit.clamp(1, 1000);
    final records = <MeFriendRecord>[];
    var syncSeq = 0;
    String? cursor;
    for (var page = 0; page < maxPages; page++) {
      final res = await _dio.get(
        '/me/friends',
        queryParameters: <String, dynamic>{
          'limit': safeLimit,
          if (cursor != null && cursor.isNotEmpty) 'cursor': cursor,
        },
      );
      final payload = unwrapApiPayload(res.data);
      final list =
          extractApiList(res.data, listKeys: const ['items', 'friends']);
      for (final item in list.whereType<Map>()) {
        final record = MeFriendRecord.fromJson(Map<String, dynamic>.from(item));
        if (record.friendUserId.isNotEmpty) {
          records.add(record);
        }
      }
      if (payload is Map) {
        final map = Map<String, dynamic>.from(payload);
        final pageSeq = _readInt(map['syncSeq'] ?? map['sync_seq']);
        if (pageSeq > syncSeq) {
          syncSeq = pageSeq;
        }
        final next =
            (map['nextCursor'] ?? map['next_cursor'] ?? map['cursor'] ?? '')
                .toString()
                .trim();
        final hasMore = _readBool(map['hasMore'] ?? map['has_more']);
        if (!hasMore || next.isEmpty || next == cursor) {
          break;
        }
        cursor = next;
      } else {
        break;
      }
    }
    return MeFriendsNetworkSnapshot(records: records, syncSeq: syncSeq);
  }

  /// Difference：`GET /me/friends/changes?since_seq=&limit=`
  Future<FriendContactChangesPage> fetchFriendsChanges({
    required int sinceSeq,
    int limit = 100,
  }) async {
    final safeLimit = limit.clamp(1, 1000);
    final since = sinceSeq < 0 ? 0 : sinceSeq;
    try {
      final res = await _dio.get(
        '/me/friends/changes',
        queryParameters: <String, dynamic>{
          'since_seq': since,
          'limit': safeLimit,
        },
      );
      final payload = unwrapApiPayload(res.data);
      if (payload is Map) {
        return FriendContactChangesPage.fromJson(
          Map<String, dynamic>.from(payload),
        );
      }
      return FriendContactChangesPage(
        nextSeq: since,
        hasMore: false,
        events: const <FriendContactChangeEvent>[],
      );
    } on DioError catch (e) {
      final code = readDioCode(e).toUpperCase();
      final status = e.response?.statusCode;
      if (status == 410 ||
          code.contains('SNAPSHOT_REQUIRED') ||
          code.contains('CURSOR_EXPIRED') ||
          code.contains('SEQ_EXPIRED') ||
          code.contains('INVALID_CURSOR') ||
          code.contains('CURSOR_INVALID')) {
        throw FriendContactSnapshotRequiredException(
          code.isNotEmpty ? code : 'SNAPSHOT_REQUIRED',
        );
      }
      rethrow;
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
      final reason = map['reason']?.toString().trim();
      if (reason != null && reason.isNotEmpty) {
        return reason;
      }
      final message = map['message']?.toString().trim();
      if (message != null && message.isNotEmpty) {
        return message;
      }
    }
    final message = error.message.trim();
    return message.isNotEmpty ? message : 'REQUEST_FAILED';
  }

  static int _readInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  static bool _readBool(dynamic value) {
    if (value is bool) return value;
    if (value is num) return value != 0;
    final text = value?.toString().trim().toLowerCase() ?? '';
    return text == 'true' || text == '1' || text == 'yes';
  }

  /// 选人页统一数据源：与通讯录 Tab 对齐，不走 IM SDK 本地好友库。
  Future<List<V2TimFriendInfo>> loadFriendsForPickers() async {
    final friends = await fetchV2TimFriends(allowLegacySdkFallback: false);
    return friends
        .where(
          (item) =>
              !PlatformOfficialAccountService.shouldHideFromContactAndPickers(
            item.userID,
          ),
        )
        .toList();
  }

  Future<List<V2TimFriendInfo>> fetchV2TimFriends({
    bool allowLegacySdkFallback = false,
  }) async {
    final records = await FriendSyncService.instance.loadFriendsForUIKit();
    if (records.isNotEmpty || !allowLegacySdkFallback) {
      return records;
    }

    // Migration safeguard: if 99chat-server has not backfilled user_friend yet,
    // /me/friends returns an empty list and the contact UI looks broken.  Keep
    // the screen usable by falling back to the legacy IM SDK list only while the
    // backend list is empty. New add/delete/remark/request operations still use
    // the self-hosted backend.
    return _fetchLegacySdkFriendList();
  }

  Future<List<V2TimFriendInfo>> _fetchLegacySdkFriendList() async {
    try {
      final res = await TencentImSDKPlugin.v2TIMManager
          .getFriendshipManager()
          .getFriendList();
      if (res.code == 0 && res.data != null) {
        return res.data!;
      }
    } catch (_) {
      // Ignore legacy fallback failures; the backend result remains authoritative.
    }
    return const <V2TimFriendInfo>[];
  }

  /// PUT /me/friends/{friendUserId}/remark
  Future<void> updateRemark({
    required String friendUserId,
    required String remark,
  }) async {
    final id = friendUserId.trim();
    if (id.isEmpty) return;
    await _dio.put('/me/friends/$id/remark', data: {'remark': remark.trim()});
    await FriendSyncService.instance.applyOptimisticRemark(
      friendUserId: id,
      remark: remark.trim(),
    );
  }

  /// DELETE /me/friends/{friendUserId}
  Future<void> deleteFriend(String friendUserId) async {
    final id = friendUserId.trim();
    if (id.isEmpty) return;
    await _dio.delete('/me/friends/$id');
    _relationCache.remove(ChatIdFormat.rawUserUid(id));
    await FriendSyncService.instance.applyOptimisticDelete(id);
  }

  /// GET /me/friends/{peerUserId}/relation
  Future<FriendRelation> fetchRelation(String peerUserId) async {
    final id = ChatIdFormat.rawUserUid(peerUserId);
    if (id.isEmpty) {
      throw ArgumentError.value(peerUserId, 'peerUserId', 'empty peerUserId');
    }
    if (_isSelfPeer(id)) {
      throw ArgumentError.value(
          peerUserId, 'peerUserId', 'cannot query self relation');
    }
    final res = await _dio.get(
      '/me/friends/${Uri.encodeComponent(id)}/relation',
    );
    final payload = unwrapApiPayload(res.data);
    final map = payload is Map<String, dynamic>
        ? payload
        : payload is Map
            ? Map<String, dynamic>.from(payload)
            : <String, dynamic>{};
    return FriendRelation.fromJson(map);
  }

  /// 是否应进入好友资料（自托管 relation + 本地库 + IM SDK 兜底）。
  Future<bool> isFriend(String friendUserId) async {
    final id = ChatIdFormat.rawUserUid(friendUserId);
    if (id.isEmpty) {
      return false;
    }
    if (_isSelfPeer(id)) {
      return false;
    }

    final cached = await cachedByUserId(id);
    if (cached != null && _recordIsKnownFriend(cached)) {
      return true;
    }

    final relation = await tryFetchRelation(id);
    if (relation != null && _relationIsKnownFriend(relation)) {
      return true;
    }

    // Do not fall back to Tencent IM SDK friendship here. 99chat-server is the
    // authoritative relationship source; IM friendship may be stale after
    // migration and must not unlock self-hosted friend/profile flows.
    return false;
  }

  /// 映射为 IM SDK `checkFriend` 的 resultType，供 UIKit 资料页使用。
  Future<int> imFriendCheckResultType(String peerUserId) async {
    final id = ChatIdFormat.rawUserUid(peerUserId);
    if (id.isEmpty) {
      return 0;
    }
    if (_isSelfPeer(id)) {
      return 0;
    }

    final cached = await cachedByUserId(id);
    if (cached != null) {
      return _recordToImResultType(cached);
    }

    final relation = await tryFetchRelation(id);
    if (relation != null) {
      return _relationToImResultType(relation);
    }

    final cachedAfter = await cachedByUserId(id);
    if (cachedAfter != null) {
      return _recordToImResultType(cachedAfter);
    }

    // Backend relation owns the result. Returning 0 is safer than treating a
    // stale IM SDK friendship as valid and enabling C2C too early.
    return 0;
  }

  /// 查询 relation；客户端/服务端参数错误时返回 null，不向外抛异常。
  Future<FriendRelation?> tryFetchRelation(String peerUserId) async {
    final id = ChatIdFormat.rawUserUid(peerUserId);
    if (id.isEmpty) {
      return null;
    }
    if (_isSelfPeer(id)) {
      return null;
    }
    final cached = _relationCache[id];
    if (cached != null && !cached.isExpired) {
      return cached.relation;
    }

    final running = _relationRequests[id];
    if (running != null) {
      return running;
    }

    late final Future<FriendRelation?> task;
    task = _fetchRelationSafely(id).then((relation) {
      if (relation != null) {
        _relationCache[id] = _CachedFriendRelation(
          relation: relation,
          expiresAt: DateTime.now().add(_relationCacheTtl),
        );
      }
      return relation;
    }).whenComplete(() {
      if (identical(_relationRequests[id], task)) {
        _relationRequests.remove(id);
      }
    });
    _relationRequests[id] = task;
    return task;
  }

  Future<MeFriendRecord?> cachedByUserId(String friendUserId) async {
    final id = ChatIdFormat.rawUserUid(friendUserId);
    if (id.isEmpty) return null;
    final matches = await FriendLocalStore.instance.readByIds(
      friendUserIds: <String>[id],
    );
    if (matches.isNotEmpty) {
      return matches.first;
    }
    return null;
  }

  Future<FriendRelation?> _fetchRelationSafely(String id) async {
    try {
      return await fetchRelation(id);
    } on DioError catch (_) {
      return null;
    } catch (_) {
      return null;
    }
  }
}

class _CachedFriendRelation {
  const _CachedFriendRelation({
    required this.relation,
    required this.expiresAt,
  });

  final FriendRelation relation;
  final DateTime expiresAt;

  bool get isExpired => !DateTime.now().isBefore(expiresAt);
}

class MeFriendsNetworkSnapshot {
  const MeFriendsNetworkSnapshot({
    required this.records,
    required this.syncSeq,
  });

  final List<MeFriendRecord> records;
  final int syncSeq;
}

class FriendRelation {
  FriendRelation({
    required this.peerUserId,
    required this.isFriend,
    required this.inMyFriendList,
    required this.peerDeletedMe,
    required this.canMessage,
  });

  final String peerUserId;
  final bool isFriend;
  final bool inMyFriendList;
  final bool peerDeletedMe;
  final bool canMessage;

  factory FriendRelation.fromJson(Map<String, dynamic> json) {
    final isFriend = _asBool(json['isFriend'] ?? json['is_friend']);
    final inMyFriendList =
        _asBool(json['inMyFriendList'] ?? json['in_my_friend_list']);
    return FriendRelation(
      peerUserId: _asString(json['peerUserId'] ?? json['peer_user_id']),
      isFriend: isFriend,
      inMyFriendList: inMyFriendList,
      peerDeletedMe: _asBool(json['peerDeletedMe'] ?? json['peer_deleted_me']),
      canMessage: _asBool(
        json['canMessage'] ?? json['can_message'],
        fallback: isFriend || inMyFriendList,
      ),
    );
  }
}

bool _recordIsKnownFriend(MeFriendRecord record) {
  return record.canMessage || record.inMyFriendList || record.isFriend;
}

bool _relationIsKnownFriend(FriendRelation relation) {
  return relation.canMessage || relation.inMyFriendList || relation.isFriend;
}

bool _isRelationLookupFailure(DioError e) {
  if (_isRelationNotFriendError(e)) {
    return true;
  }
  final status = e.response?.statusCode;
  if (status == 400) {
    return true;
  }
  return false;
}

bool _isRelationNotFriendError(DioError e) {
  final status = e.response?.statusCode;
  if (status == 404) {
    return true;
  }
  final data = e.response?.data;
  if (data is Map) {
    final code = data['code']?.toString();
    return code == 'USER_NOT_FOUND' || code == 'FRIEND_NOT_FOUND';
  }
  return false;
}

int _relationToImResultType(FriendRelation relation) {
  if (relation.canMessage) {
    return 3;
  }
  if (relation.inMyFriendList) {
    return 1;
  }
  if (relation.isFriend) {
    return 2;
  }
  return 0;
}

int _recordToImResultType(MeFriendRecord record) {
  if (record.canMessage) {
    return 3;
  }
  if (record.inMyFriendList) {
    return 1;
  }
  if (record.isFriend) {
    return 2;
  }
  return 0;
}

Future<bool> _isFriendViaImSdk(String userId) async {
  final imType = await _imSdkFriendResultType(userId);
  return imType == 3 || imType == 1;
}

Future<int> _imSdkFriendResultType(String userId) async {
  try {
    final res = await TencentImSDKPlugin.v2TIMManager
        .getFriendshipManager()
        .checkFriend(
      userIDList: [userId],
      checkType: FriendTypeEnum.V2TIM_FRIEND_TYPE_BOTH,
    );
    if (res.code != 0 || res.data == null) {
      return 0;
    }
    for (final item in res.data!) {
      if (ChatIdFormat.rawUserUid(item.userID) != userId) {
        continue;
      }
      final type = item.resultType;
      if (type == 3 || type == 1 || type == 2) {
        return type;
      }
    }
  } catch (_) {
    // Ignore IM fallback failures.
  }
  return 0;
}

class MeFriendRecord {
  MeFriendRecord({
    required this.friendUserId,
    required this.remark,
    required this.friendNickname,
    required this.friendAvatarUrl,
    this.friendAvatarVersion,
    required this.addedAt,
    required this.peerDeletedMe,
    required this.canMessage,
    this.inMyFriendList = true,
    this.isFriend = true,
    this.lastActiveAt,
    this.lastActiveVisibility,
  });

  final String friendUserId;
  final String remark;
  final String friendNickname;
  final String friendAvatarUrl;
  final int? friendAvatarVersion;
  final int addedAt;
  final bool peerDeletedMe;
  final bool canMessage;
  final bool inMyFriendList;
  final bool isFriend;
  final int? lastActiveAt;
  final String? lastActiveVisibility;

  String get displayName {
    if (remark.trim().isNotEmpty) return remark.trim();
    if (friendNickname.trim().isNotEmpty) return friendNickname.trim();
    return friendUserId;
  }

  factory MeFriendRecord.fromJson(Map<String, dynamic> json) {
    final friendUserId = _asString(
      json['friendUserId'] ??
          json['friend_user_id'] ??
          json['peerUserId'] ??
          json['peer_user_id'] ??
          json['targetUserId'] ??
          json['target_user_id'] ??
          json['userId'] ??
          json['user_id'],
    );
    return MeFriendRecord(
      friendUserId: friendUserId,
      remark: _asString(json['remark'] ?? json['friendRemark']),
      friendNickname: _asString(
        json['friendNickname'] ??
            json['friend_nickname'] ??
            json['nickname'] ??
            json['nickName'] ??
            json['showName'],
      ),
      friendAvatarUrl: _asString(
        json['friendAvatarUrl'] ??
            json['friend_avatar_url'] ??
            json['avatarUrl'] ??
            json['faceUrl'],
      ),
      friendAvatarVersion: _readNullableInt(
        json['friendAvatarVersion'] ?? json['friend_avatar_version'],
      ),
      addedAt: _parseTimestamp(json['addedAt'] ?? json['added_at']),
      peerDeletedMe: _asBool(json['peerDeletedMe'] ?? json['peer_deleted_me']),
      canMessage:
          _asBool(json['canMessage'] ?? json['can_message'], fallback: true),
      inMyFriendList: _asBool(
        json['inMyFriendList'] ?? json['in_my_friend_list'],
        fallback: true,
      ),
      isFriend: _asBool(
        json['isFriend'] ?? json['is_friend'],
        fallback:
            _asBool(json['canMessage'] ?? json['can_message'], fallback: true),
      ),
      lastActiveAt: _parseOptionalTimestamp(
        json['lastActiveAt'] ?? json['last_active_at'],
      ),
      lastActiveVisibility: json['lastActiveVisibility']?.toString() ??
          json['last_active_visibility']?.toString(),
    );
  }

  factory MeFriendRecord.fromListChangedEvent(FriendRealtimeEvent event) {
    final peerUserId = _asString(event.peerUserId);
    return MeFriendRecord(
      friendUserId: peerUserId,
      remark: event.remark?.trim() ?? '',
      friendNickname: event.peerNickname?.trim() ?? '',
      friendAvatarUrl: event.peerAvatarUrl?.trim() ?? '',
      friendAvatarVersion: null,
      addedAt: _parseTimestamp(event.addedAt),
      peerDeletedMe: event.peerDeletedMe ?? false,
      canMessage: event.canMessage ?? true,
      inMyFriendList: event.inMyFriendList ?? true,
      isFriend: event.isFriend ?? event.canMessage ?? true,
      lastActiveAt: event.lastActiveAt,
      lastActiveVisibility: event.lastActiveVisibility,
    );
  }

  MeFriendRecord copyWith({
    String? friendUserId,
    String? remark,
    String? friendNickname,
    String? friendAvatarUrl,
    int? friendAvatarVersion,
    int? addedAt,
    bool? peerDeletedMe,
    bool? canMessage,
    bool? inMyFriendList,
    bool? isFriend,
    int? lastActiveAt,
    String? lastActiveVisibility,
  }) {
    return MeFriendRecord(
      friendUserId: friendUserId ?? this.friendUserId,
      remark: remark ?? this.remark,
      friendNickname: friendNickname ?? this.friendNickname,
      friendAvatarUrl: friendAvatarUrl ?? this.friendAvatarUrl,
      friendAvatarVersion: friendAvatarVersion ?? this.friendAvatarVersion,
      addedAt: addedAt ?? this.addedAt,
      peerDeletedMe: peerDeletedMe ?? this.peerDeletedMe,
      canMessage: canMessage ?? this.canMessage,
      inMyFriendList: inMyFriendList ?? this.inMyFriendList,
      isFriend: isFriend ?? this.isFriend,
      lastActiveAt: lastActiveAt ?? this.lastActiveAt,
      lastActiveVisibility: lastActiveVisibility ?? this.lastActiveVisibility,
    );
  }

  V2TimFriendInfo toV2TimFriendInfo() {
    return V2TimFriendInfo(
      userID: friendUserId,
      friendRemark: remark,
      friendCustomInfo: <String, String>{
        'peerDeletedMe': peerDeletedMe ? '1' : '0',
        'canMessage': canMessage ? '1' : '0',
        'isFriend': isFriend ? '1' : '0',
        'inMyFriendList': inMyFriendList ? '1' : '0',
        if (addedAt > 0) 'addedAt': addedAt.toString(),
        if (friendAvatarVersion != null)
          'friendAvatarVersion': friendAvatarVersion.toString(),
      },
      userProfile: V2TimUserFullInfo(
        userID: friendUserId,
        nickName: friendNickname,
        faceUrl: friendAvatarUrl,
      ),
    );
  }
}

String _asString(Object? value) => value?.toString().trim() ?? '';

int? _readNullableInt(Object? value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString().trim() ?? '');
}

bool _asBool(Object? value, {bool fallback = false}) {
  if (value == null) return fallback;
  if (value is bool) return value;
  if (value is num) return value != 0;
  final text = value.toString().trim().toLowerCase();
  if (text.isEmpty) return fallback;
  return text == 'true' || text == '1' || text == 'yes' || text == 'y';
}

int _parseTimestamp(Object? value) {
  if (value == null) return 0;
  if (value is int) return value < 1000000000000 ? value * 1000 : value;
  if (value is num) {
    final parsed = value.toInt();
    return parsed < 1000000000000 ? parsed * 1000 : parsed;
  }
  final text = value.toString().trim();
  if (text.isEmpty) return 0;
  final numeric = int.tryParse(text);
  if (numeric != null)
    return numeric < 1000000000000 ? numeric * 1000 : numeric;
  final dt = DateTime.tryParse(text);
  return dt?.toUtc().millisecondsSinceEpoch ?? 0;
}

int? _parseOptionalTimestamp(Object? value) {
  if (value == null) {
    return null;
  }
  final parsed = _parseTimestamp(value);
  return parsed == 0 ? null : parsed;
}
