import 'package:flutter/foundation.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_friend_info.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_friend_info.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_user_full_info.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_user_full_info.dart';

class UserProfileCachedSnapshot {
  const UserProfileCachedSnapshot({
    this.remark = '',
    this.nickname = '',
    this.avatarUrl = '',
  });

  final String remark;
  final String nickname;
  final String avatarUrl;
}

typedef UserProfileLocalFriendLoader = Future<V2TimFriendInfo?> Function(
  String userId,
);
typedef UserProfileLocalFriendSaver = Future<void> Function(
  V2TimFriendInfo info,
);
typedef UserProfileLocalFriendMerger = Future<V2TimFriendInfo?> Function(
  String userId,
  V2TimFriendInfo? remote,
);
typedef UserProfileLocalUserSaver = Future<void> Function(
  V2TimUserFullInfo info,
);
typedef UserProfileHostedRemarkMerger = Future<V2TimFriendInfo?> Function(
  String userId,
  V2TimFriendInfo? info,
);
typedef UserProfileCachedReader = UserProfileCachedSnapshot? Function(
  String userId,
);

/// Bridge from UIKit profile flows to app-local user profile cache.
class UserProfileLocalBridge {
  UserProfileLocalBridge._();

  static UserProfileLocalFriendLoader? _loadFriendInfo;
  static UserProfileLocalFriendSaver? _saveFriendInfo;
  static UserProfileLocalFriendMerger? _mergePreferLocal;
  static UserProfileLocalUserSaver? _saveUserInfo;
  static UserProfileHostedRemarkMerger? _mergeHostedFriendRemark;
  static UserProfileCachedReader? _readCached;
  static Listenable? _changeListenable;

  static bool get enabled => _loadFriendInfo != null;

  static void configure({
    UserProfileLocalFriendLoader? loadFriendInfo,
    UserProfileLocalFriendSaver? saveFriendInfo,
    UserProfileLocalFriendMerger? mergePreferLocal,
    UserProfileLocalUserSaver? saveUserInfo,
    UserProfileHostedRemarkMerger? mergeHostedFriendRemark,
    UserProfileCachedReader? readCached,
    Listenable? changeListenable,
  }) {
    _loadFriendInfo = loadFriendInfo;
    _saveFriendInfo = saveFriendInfo;
    _mergePreferLocal = mergePreferLocal;
    _saveUserInfo = saveUserInfo;
    _mergeHostedFriendRemark = mergeHostedFriendRemark;
    _readCached = readCached;
    _changeListenable = changeListenable;
  }

  static void clear() {
    _loadFriendInfo = null;
    _saveFriendInfo = null;
    _mergePreferLocal = null;
    _saveUserInfo = null;
    _mergeHostedFriendRemark = null;
    _readCached = null;
    _changeListenable = null;
  }

  /// 同步读本地资料镜像；未安装桥时返回 null。
  static UserProfileCachedSnapshot? readCached(String? userId) {
    final id = userId?.trim() ?? '';
    if (id.isEmpty) {
      return null;
    }
    return _readCached?.call(id);
  }

  static String cachedAvatarUrl(String? userId, {String? fallback}) {
    final local = readCached(userId)?.avatarUrl.trim() ?? '';
    if (local.isNotEmpty) {
      return local;
    }
    return fallback?.trim() ?? '';
  }

  static Listenable? get changeListenable => _changeListenable;

  static Future<V2TimFriendInfo?> loadLocal(String userId) async {
    final loader = _loadFriendInfo;
    if (loader == null) {
      return null;
    }
    return loader(userId);
  }

  static Future<V2TimFriendInfo?> mergePreferLocal(
    String userId,
    V2TimFriendInfo? remote,
  ) async {
    final merger = _mergePreferLocal;
    if (merger != null) {
      return merger(userId, remote);
    }
    return remote;
  }

  static Future<void> saveFriendInfo(V2TimFriendInfo? info) async {
    if (info == null) {
      return;
    }
    final saver = _saveFriendInfo;
    if (saver == null) {
      return;
    }
    await saver(info);
  }

  static Future<void> saveUserInfo(V2TimUserFullInfo? info) async {
    if (info == null) {
      return;
    }
    final saver = _saveUserInfo;
    if (saver == null) {
      return;
    }
    await saver(info);
  }

  static final Map<String, int> _publicUpsertLastMs = <String, int>{};
  static const int _publicUpsertMinIntervalMs = 2000;

  /// Ingest live public nick/face from IM snapshots (friend-info / messages).
  /// Debounced per user. Empty fields are ignored (do not clear local).
  /// Remark is never written here.
  static Future<bool> upsertPublicProfileFromSnapshot({
    required String userId,
    String? nickName,
    String? faceUrl,
  }) async {
    final id = userId.trim();
    if (id.isEmpty) {
      return false;
    }
    final nick = nickName?.trim() ?? '';
    final face = faceUrl?.trim() ?? '';
    if (nick.isEmpty && face.isEmpty) {
      return false;
    }
    final cached = readCached(id);
    final sameNick = nick.isEmpty || nick == (cached?.nickname.trim() ?? '');
    final sameFace = face.isEmpty || face == (cached?.avatarUrl.trim() ?? '');
    if (sameNick && sameFace) {
      return false;
    }
    final now = DateTime.now().millisecondsSinceEpoch;
    final last = _publicUpsertLastMs[id] ?? 0;
    if (now - last < _publicUpsertMinIntervalMs) {
      return false;
    }
    _publicUpsertLastMs[id] = now;
    await saveUserInfo(
      V2TimUserFullInfo(
        userID: id,
        nickName: nick.isNotEmpty ? nick : null,
        faceUrl: face.isNotEmpty ? face : null,
      ),
    );
    return true;
  }

  @visibleForTesting
  static void resetPublicUpsertDebounceForTest() {
    _publicUpsertLastMs.clear();
  }

  /// 用自托管好友库（与通讯录同源）补齐 [friendRemark]。
  static Future<V2TimFriendInfo?> mergeHostedFriendRemark(
    String userId,
    V2TimFriendInfo? info,
  ) async {
    final merger = _mergeHostedFriendRemark;
    if (merger == null) {
      return info;
    }
    return merger(userId, info);
  }

  /// 自托管好友只有昵称/头像/备注。个性签名、性别、生日仍以 IM 公开资料为准，
  /// 不覆盖昵称、头像、备注。
  static V2TimFriendInfo mergeImPublicProfile({
    required String userId,
    V2TimFriendInfo? info,
    V2TimUserFullInfo? im,
  }) {
    final id = userId.trim();
    final target = info ?? V2TimFriendInfo(userID: id);
    if (im == null) {
      return target;
    }
    target.userProfile ??= V2TimUserFullInfo(userID: id);
    final profile = target.userProfile!;
    final signature = im.selfSignature?.trim() ?? '';
    if (signature.isNotEmpty) {
      profile.selfSignature = signature;
    }
    if (im.gender != null) {
      profile.gender = im.gender;
    }
    if (im.birthday != null) {
      profile.birthday = im.birthday;
    }
    return target;
  }
}
