import 'package:tencent_cloud_chat_sdk/models/v2_tim_friend_info.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_friend_info.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_user_full_info.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_user_full_info.dart';

import 'package:tencent_cloud_chat_demo/src/api/auth_api.dart';

class UserProfileRecord {
  UserProfileRecord({
    required this.userId,
    this.nickname = '',
    this.avatarUrl = '',
    this.avatarVersion = 0,
    this.selfSignature = '',
    this.friendRemark = '',
    this.gender,
    this.birthday,
    this.updatedAt = 0,
  });

  final String userId;
  final String nickname;
  final String avatarUrl;
  final int avatarVersion;
  final String selfSignature;
  final String friendRemark;
  final int? gender;
  final int? birthday;
  final int updatedAt;

  UserProfileRecord copyWith({
    String? userId,
    String? nickname,
    String? avatarUrl,
    int? avatarVersion,
    String? selfSignature,
    String? friendRemark,
    int? gender,
    int? birthday,
    int? updatedAt,
  }) {
    return UserProfileRecord(
      userId: userId ?? this.userId,
      nickname: nickname ?? this.nickname,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      avatarVersion: avatarVersion ?? this.avatarVersion,
      selfSignature: selfSignature ?? this.selfSignature,
      friendRemark: friendRemark ?? this.friendRemark,
      gender: gender ?? this.gender,
      birthday: birthday ?? this.birthday,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  factory UserProfileRecord.fromRow(Map<String, Object?> row) {
    return UserProfileRecord(
      userId: row['user_id']?.toString() ?? '',
      nickname: row['nickname']?.toString() ?? '',
      avatarUrl: row['avatar_url']?.toString() ?? '',
      avatarVersion: (row['avatar_version'] as int?) ?? 0,
      selfSignature: row['self_signature']?.toString() ?? '',
      friendRemark: row['friend_remark']?.toString() ?? '',
      gender: row['gender'] as int?,
      birthday: row['birthday'] as int?,
      updatedAt: (row['updated_at'] as int?) ?? 0,
    );
  }

  factory UserProfileRecord.fromFriendInfo(V2TimFriendInfo info) {
    final profile = info.userProfile;
    return UserProfileRecord(
      userId: info.userID.trim(),
      nickname: profile?.nickName?.trim() ?? '',
      avatarUrl: profile?.faceUrl?.trim() ?? '',
      selfSignature: profile?.selfSignature?.trim() ?? '',
      friendRemark: info.friendRemark?.trim() ?? '',
      gender: profile?.gender,
      birthday: profile?.birthday,
    );
  }

  factory UserProfileRecord.fromUserFullInfo(V2TimUserFullInfo info) {
    return UserProfileRecord(
      userId: info.userID?.trim() ?? '',
      nickname: info.nickName?.trim() ?? '',
      avatarUrl: info.faceUrl?.trim() ?? '',
      selfSignature: info.selfSignature?.trim() ?? '',
      gender: info.gender,
      birthday: info.birthday,
    );
  }

  factory UserProfileRecord.fromMeResult(MeResult me) {
    return UserProfileRecord(
      userId: me.userId.trim(),
      nickname: me.nickname.trim(),
      avatarUrl: me.avatarUrl?.trim() ?? '',
      avatarVersion: me.avatarVersion,
    );
  }

  V2TimFriendInfo toV2TimFriendInfo() {
    return V2TimFriendInfo(
      userID: userId,
      friendRemark: friendRemark,
      userProfile: V2TimUserFullInfo(
        userID: userId,
        nickName: nickname,
        faceUrl: avatarUrl,
        selfSignature: selfSignature,
        gender: gender,
        birthday: birthday,
      ),
    );
  }

  V2TimUserFullInfo toV2TimUserFullInfo() {
    return V2TimUserFullInfo(
      userID: userId,
      nickName: nickname,
      faceUrl: avatarUrl,
      selfSignature: selfSignature,
      gender: gender,
      birthday: birthday,
    );
  }

  /// 远端资料写入本地缓存：远端非空字段覆盖本地。
  UserProfileRecord mergeRemote(V2TimFriendInfo? remote) {
    if (remote == null) {
      return this;
    }
    final profile = remote.userProfile;
    return copyWith(
      nickname: _preferRemote(profile?.nickName, nickname),
      avatarUrl: _preferRemote(profile?.faceUrl, avatarUrl),
      selfSignature: _preferRemote(profile?.selfSignature, selfSignature),
      friendRemark: _preferRemote(remote.friendRemark, friendRemark),
      gender: profile?.gender ?? gender,
      birthday: profile?.birthday ?? birthday,
      updatedAt: DateTime.now().toUtc().millisecondsSinceEpoch,
    );
  }

  UserProfileRecord mergeRemoteUserInfo(V2TimUserFullInfo? remote) {
    if (remote == null) {
      return this;
    }
    return copyWith(
      nickname: _preferRemote(remote.nickName, nickname),
      avatarUrl: _preferRemote(remote.faceUrl, avatarUrl),
      selfSignature: _preferRemote(remote.selfSignature, selfSignature),
      gender: remote.gender ?? gender,
      birthday: remote.birthday ?? birthday,
      updatedAt: DateTime.now().toUtc().millisecondsSinceEpoch,
    );
  }

  static String _preferRemote(String? incoming, String current) {
    final remote = incoming?.trim() ?? '';
    if (remote.isNotEmpty) {
      return remote;
    }
    return current.trim();
  }

  /// SDK 资料写入本地：公开昵称/头像远端非空覆盖本地；备注仍以本地为准（允许为空表示已清空）。
  UserProfileRecord mergeSdkRemotePreferLocal(V2TimFriendInfo? remote) {
    if (remote == null) {
      return this;
    }
    final profile = remote.userProfile;
    return copyWith(
      nickname: _preferRemote(profile?.nickName, nickname),
      avatarUrl: _preferRemote(profile?.faceUrl, avatarUrl),
      selfSignature: _preferRemote(profile?.selfSignature, selfSignature),
      friendRemark: friendRemark,
      gender: profile?.gender ?? gender,
      birthday: profile?.birthday ?? birthday,
      updatedAt: DateTime.now().toUtc().millisecondsSinceEpoch,
    );
  }

  /// SDK 用户资料写入本地：公开昵称/头像远端非空覆盖本地。
  UserProfileRecord mergeSdkRemoteUserInfoPreferLocal(
      V2TimUserFullInfo? remote) {
    if (remote == null) {
      return this;
    }
    return copyWith(
      nickname: _preferRemote(remote.nickName, nickname),
      avatarUrl: _preferRemote(remote.faceUrl, avatarUrl),
      selfSignature: _preferRemote(remote.selfSignature, selfSignature),
      gender: remote.gender ?? gender,
      birthday: remote.birthday ?? birthday,
      updatedAt: DateTime.now().toUtc().millisecondsSinceEpoch,
    );
  }
}
