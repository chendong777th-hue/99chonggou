import 'package:tencent_cloud_chat_demo/utils/chat_id_format.dart';
import 'package:tencent_cloud_chat_demo/utils/object_url_normalize.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_group_info.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_group_info.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_group_info_result.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_group_info_result.dart';

class MeGroupRecord {
  MeGroupRecord({
    required this.groupId,
    required this.groupType,
    required this.groupName,
    required this.displayAlias,
    required this.avatarUrl,
    this.avatarPreviewUrl = '',
    this.avatarVersion = 0,
    required this.notice,
    required this.memberCount,
    required this.myRole,
    required this.myNameCard,
    required this.joinedAt,
    required this.updatedAt,
    this.ownerUserId = '',
    this.noticeUpdatedAt = 0,
    this.noticeUpdatedBy = '',
    this.isAllMuted = false,
    this.gameEnabled = false,
  });

  final String groupId;
  final String groupType;
  final String groupName;
  final String displayAlias;
  final String avatarUrl;
  final String avatarPreviewUrl;
  final int avatarVersion;
  final String notice;
  final int memberCount;
  final int myRole;
  final String myNameCard;
  final int joinedAt;
  final int updatedAt;
  final String ownerUserId;
  final int noticeUpdatedAt;

  /// 最近修改群公告的用户 userId；历史数据可能为空。
  final String noticeUpdatedBy;
  final bool isAllMuted;

  /// 后端群资料开关；缺失或无法解析时按关闭处理。
  final bool gameEnabled;

  MeGroupRecord copyWith({
    String? groupId,
    String? groupType,
    String? groupName,
    String? displayAlias,
    String? avatarUrl,
    String? avatarPreviewUrl,
    int? avatarVersion,
    String? notice,
    int? memberCount,
    int? myRole,
    String? myNameCard,
    int? joinedAt,
    int? updatedAt,
    String? ownerUserId,
    int? noticeUpdatedAt,
    String? noticeUpdatedBy,
    bool? isAllMuted,
    bool? gameEnabled,
  }) {
    return MeGroupRecord(
      groupId: groupId ?? this.groupId,
      groupType: groupType ?? this.groupType,
      groupName: groupName ?? this.groupName,
      displayAlias: displayAlias ?? this.displayAlias,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      avatarPreviewUrl: avatarPreviewUrl ?? this.avatarPreviewUrl,
      avatarVersion: avatarVersion ?? this.avatarVersion,
      notice: notice ?? this.notice,
      memberCount: memberCount ?? this.memberCount,
      myRole: myRole ?? this.myRole,
      myNameCard: myNameCard ?? this.myNameCard,
      joinedAt: joinedAt ?? this.joinedAt,
      updatedAt: updatedAt ?? this.updatedAt,
      ownerUserId: ownerUserId ?? this.ownerUserId,
      noticeUpdatedAt: noticeUpdatedAt ?? this.noticeUpdatedAt,
      noticeUpdatedBy: noticeUpdatedBy ?? this.noticeUpdatedBy,
      isAllMuted: isAllMuted ?? this.isAllMuted,
      gameEnabled: gameEnabled ?? this.gameEnabled,
    );
  }

  factory MeGroupRecord.fromJson(
    Map<String, dynamic> json, {
    MeGroupRecord? preserveIsAllMutedFrom,
  }) {
    final rawGroupId = _asString(
      json['groupId'] ?? json['group_id'] ?? json['groupID'],
    );
    // 本地存储/REST 用后端群 ID，禁止加成 `@TGS#_@TGS#`。
    final apiId = ChatIdFormat.apiGroupId(rawGroupId);
    final groupId = apiId.isNotEmpty ? apiId : rawGroupId;
    return MeGroupRecord(
      groupId: groupId,
      groupType: _asString(json['groupType'] ?? json['group_type']),
      groupName: _asString(json['groupName'] ?? json['group_name']),
      displayAlias: ChatIdFormat.displayGroupAlias(
        _asString(json['displayAlias'] ?? json['display_alias']),
        groupIdFallback: rawGroupId,
      ),
      avatarUrl: normalizeObjectUrl(
        _asString(json['avatarUrl'] ?? json['avatar_url'] ?? json['faceUrl']),
      ),
      avatarPreviewUrl: normalizeObjectUrl(
        _asString(json['avatarPreviewUrl'] ?? json['avatar_preview_url']),
      ),
      avatarVersion: _asInt(json['avatarVersion'] ?? json['avatar_version']),
      notice: _asString(json['notice'] ?? json['notification']),
      memberCount: _asInt(json['memberCount'] ?? json['member_count']),
      myRole: _asInt(json['myRole'] ?? json['my_role'] ?? json['role']),
      myNameCard: _asString(json['myNameCard'] ?? json['my_name_card']),
      joinedAt: _parseTimestampMs(json['joinedAt'] ?? json['joined_at']),
      updatedAt: _parseTimestampMs(json['updatedAt'] ?? json['updated_at']),
      ownerUserId: _asString(json['ownerUserId'] ?? json['owner_user_id']),
      noticeUpdatedAt: _parseTimestampMs(
        json['noticeUpdatedAt'] ?? json['notice_updated_at'],
      ),
      noticeUpdatedBy: ChatIdFormat.rawUserUid(
        _asString(json['noticeUpdatedBy'] ?? json['notice_updated_by']),
      ),
      isAllMuted: jsonHasIsAllMutedField(json)
          ? parseBoolLikeIM(
              json['isAllMuted'] ??
                  json['is_all_muted'] ??
                  json['shutUpAllMember'] ??
                  json['shut_up_all_member'],
            )
          : (preserveIsAllMutedFrom?.isAllMuted ?? false),
      gameEnabled: parseBoolLikeIM(json['gameEnabled'] ?? json['game_enabled']),
    );
  }

  /// REST `GET /group/{id}` 与群列表 item 目前不含禁言字段时，保留本地值。
  static bool jsonHasIsAllMutedField(Map<String, dynamic> json) {
    return json.containsKey('isAllMuted') ||
        json.containsKey('is_all_muted') ||
        json.containsKey('shutUpAllMember') ||
        json.containsKey('shut_up_all_member');
  }

  /// 兼容 REST bool 与 IM/TCP 的 `"On"` / `"Off"` 字符串。
  static bool parseBoolLikeIM(dynamic value) {
    if (value is bool) {
      return value;
    }
    if (value is num) {
      return value != 0;
    }
    final text = value?.toString().trim().toLowerCase() ?? '';
    if (text.isEmpty) {
      return false;
    }
    if (text == 'off' || text == 'false' || text == '0' || text == 'no') {
      return false;
    }
    return text == 'on' || text == 'true' || text == '1' || text == 'yes';
  }

  V2TimGroupInfo toV2TimGroupInfo() {
    final customInfo = <String, String>{};
    if (displayAlias.isNotEmpty) {
      customInfo['displayAlias'] = displayAlias;
    }
    if (noticeUpdatedBy.isNotEmpty) {
      customInfo['noticeUpdatedBy'] = noticeUpdatedBy;
    }
    customInfo['gameEnabled'] = gameEnabled.toString();
    // IM：短码 m2… 原样；mc… → @TGS#_mc…；误加成 @TGS#_@TGS#m2… 回退短码。
    final imGroupId = ChatIdFormat.isIMGroupOrCommunityId(groupId)
        ? ChatIdFormat.normalizeGroupId(groupId)
        : groupId;
    return V2TimGroupInfo(
      groupID: imGroupId.isNotEmpty ? imGroupId : groupId,
      groupType: groupType,
      groupName: groupName,
      faceUrl: avatarUrl,
      notification: notice,
      memberCount: memberCount,
      role: myRole,
      owner: ownerUserId.isNotEmpty ? ownerUserId : null,
      joinTime: joinedAt > 0 ? joinedAt ~/ 1000 : null,
      lastInfoTime: noticeUpdatedAt > 0 ? noticeUpdatedAt ~/ 1000 : null,
      isAllMuted: isAllMuted,
      customInfo: customInfo.isEmpty ? null : customInfo,
    );
  }

  V2TimGroupInfoResult toV2TimGroupInfoResult() {
    return V2TimGroupInfoResult(
      resultCode: 0,
      resultMessage: '',
      groupInfo: toV2TimGroupInfo(),
    );
  }

  static String _asString(dynamic value) => value?.toString().trim() ?? '';

  static int _asInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  static int _parseTimestampMs(dynamic value) {
    final parsed = _asInt(value);
    if (parsed <= 0) return 0;
    return parsed < 1000000000000 ? parsed * 1000 : parsed;
  }
}

class GroupMemberRecord {
  GroupMemberRecord({
    required this.userId,
    required this.nickname,
    required this.avatarUrl,
    required this.friendRemark,
    required this.nameCard,
    required this.role,
    required this.joinedAt,
    required this.isSelf,
    this.muteUntil = 0,
    this.invitedByUserId = '',
    this.invitedByNickname = '',
    this.joinChannel = '',
  });

  final String userId;
  final String nickname;
  final String avatarUrl;
  final String friendRemark;
  final String nameCard;
  final int role;
  final int joinedAt;
  final bool isSelf;
  final int muteUntil;

  /// 邀请人业务 userId；无则空串。
  final String invitedByUserId;

  /// 邀请人昵称；无则空串。
  final String invitedByNickname;

  /// `invite` | `group_id` | 空（历史/未知）。
  final String joinChannel;

  String get displayName {
    if (nameCard.trim().isNotEmpty) return nameCard.trim();
    if (friendRemark.trim().isNotEmpty) return friendRemark.trim();
    if (nickname.trim().isNotEmpty) return nickname.trim();
    return userId;
  }

  GroupMemberRecord copyWith({
    String? userId,
    String? nickname,
    String? avatarUrl,
    String? friendRemark,
    String? nameCard,
    int? role,
    int? joinedAt,
    bool? isSelf,
    int? muteUntil,
    String? invitedByUserId,
    String? invitedByNickname,
    String? joinChannel,
  }) {
    return GroupMemberRecord(
      userId: userId ?? this.userId,
      nickname: nickname ?? this.nickname,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      friendRemark: friendRemark ?? this.friendRemark,
      nameCard: nameCard ?? this.nameCard,
      role: role ?? this.role,
      joinedAt: joinedAt ?? this.joinedAt,
      isSelf: isSelf ?? this.isSelf,
      muteUntil: muteUntil ?? this.muteUntil,
      invitedByUserId: invitedByUserId ?? this.invitedByUserId,
      invitedByNickname: invitedByNickname ?? this.invitedByNickname,
      joinChannel: joinChannel ?? this.joinChannel,
    );
  }

  factory GroupMemberRecord.fromJson(Map<String, dynamic> json) {
    return GroupMemberRecord(
      userId: ChatIdFormat.rawUserUid(
        json['userId']?.toString() ?? json['user_id']?.toString() ?? '',
      ),
      nickname: _asString(json['nickname'] ?? json['nickName']),
      avatarUrl: _asString(
        json['avatarUrl'] ?? json['avatar_url'] ?? json['faceUrl'],
      ),
      friendRemark: _asString(json['friendRemark'] ?? json['friend_remark']),
      nameCard: _asString(json['nameCard'] ?? json['name_card']),
      role: _asInt(json['role']),
      joinedAt: _parseTimestampMs(json['joinedAt'] ?? json['joined_at']),
      isSelf: _asBool(json['isSelf'] ?? json['is_self']),
      muteUntil: _parseMuteUntil(
        json['muteUntil'] ?? json['mute_until'] ?? json['muteUntilSec'],
      ),
      invitedByUserId: ChatIdFormat.rawUserUid(
        json['invitedByUserId']?.toString() ??
            json['invited_by_user_id']?.toString() ??
            '',
      ),
      invitedByNickname: _asString(
        json['invitedByNickname'] ?? json['invited_by_nickname'],
      ),
      joinChannel: _normalizeJoinChannel(
        json['joinChannel'] ?? json['join_channel'],
      ),
    );
  }

  static String _normalizeJoinChannel(dynamic value) {
    final raw = _asString(value).toLowerCase();
    if (raw == 'invite' || raw == 'group_id') {
      return raw;
    }
    return '';
  }

  static String _asString(dynamic value) => value?.toString().trim() ?? '';

  static int _asInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  static bool _asBool(dynamic value) {
    if (value is bool) return value;
    if (value is num) return value != 0;
    final text = value?.toString().trim().toLowerCase() ?? '';
    return text == 'true' || text == '1' || text == 'yes';
  }

  static int _parseTimestampMs(dynamic value) {
    final parsed = _asInt(value);
    if (parsed <= 0) return 0;
    return parsed < 1000000000000 ? parsed * 1000 : parsed;
  }

  static int _parseMuteUntil(dynamic value) {
    final parsed = _asInt(value);
    if (parsed <= 0) return 0;
    return parsed >= 1000000000000 ? parsed ~/ 1000 : parsed;
  }
}
