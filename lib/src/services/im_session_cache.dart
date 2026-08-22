import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:tencent_cloud_chat_demo/src/api/auth_api.dart';

/// Caches the last IM UserSig so cold start can proceed offline when possible.
class ImSessionCache {
  ImSessionCache._();

  static final ImSessionCache instance = ImSessionCache._();

  static const _sdkAppIdKey = 'im_session_sdk_app_id';
  static const _userIdKey = 'im_session_user_id';
  static const _userSigKey = 'im_session_user_sig';
  static const _expiresAtKey = 'im_session_expires_at_ms';

  final FlutterSecureStorage _secure = const FlutterSecureStorage();

  Future<void> save(UserSigResult sig) async {
    final expiresAt = DateTime.now()
        .add(Duration(seconds: sig.expiresIn))
        .millisecondsSinceEpoch;
    await _secure.write(key: _sdkAppIdKey, value: sig.sdkAppId.toString());
    await _secure.write(key: _userIdKey, value: sig.userId);
    await _secure.write(key: _userSigKey, value: sig.userSig);
    await _secure.write(key: _expiresAtKey, value: expiresAt.toString());
  }

  /// 读取上次保存的 SDK AppID（UserSig 过期时仍可用于 IM SDK init）。
  Future<int?> readCachedSdkAppId() async {
    final sdkAppIdRaw = await _secure.read(key: _sdkAppIdKey);
    if (sdkAppIdRaw == null || sdkAppIdRaw.isEmpty) {
      return null;
    }
    final sdkAppId = int.tryParse(sdkAppIdRaw);
    if (sdkAppId == null || sdkAppId <= 0) {
      return null;
    }
    return sdkAppId;
  }

  Future<UserSigResult?> loadIfValid() async {
    final sdkAppIdRaw = await _secure.read(key: _sdkAppIdKey);
    final userId = await _secure.read(key: _userIdKey);
    final userSig = await _secure.read(key: _userSigKey);
    final expiresAtRaw = await _secure.read(key: _expiresAtKey);
    if (sdkAppIdRaw == null ||
        userId == null ||
        userSig == null ||
        expiresAtRaw == null) {
      return null;
    }
    final expiresAt = int.tryParse(expiresAtRaw);
    if (expiresAt == null ||
        DateTime.now().millisecondsSinceEpoch >= expiresAt) {
      return null;
    }
    final sdkAppId = int.tryParse(sdkAppIdRaw);
    if (sdkAppId == null) {
      return null;
    }
    final remainingSec =
        ((expiresAt - DateTime.now().millisecondsSinceEpoch) / 1000)
            .floor()
            .clamp(1, 1 << 31);
    return UserSigResult(
      sdkAppId: sdkAppId,
      userId: userId,
      userSig: userSig,
      expiresIn: remainingSec,
    );
  }

  Future<UserSigResult?> loadIfValidForUser(String userId) async {
    final trimmed = userId.trim();
    if (trimmed.isEmpty) {
      return null;
    }
    final cached = await loadIfValid();
    if (cached == null) {
      return null;
    }
    if (cached.userId.trim() == trimmed) {
      return cached;
    }
    return null;
  }

  Future<void> clear() async {
    await _secure.delete(key: _sdkAppIdKey);
    await _secure.delete(key: _userIdKey);
    await _secure.delete(key: _userSigKey);
    await _secure.delete(key: _expiresAtKey);
  }
}
