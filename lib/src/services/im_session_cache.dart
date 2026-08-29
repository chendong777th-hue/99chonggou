import 'dart:async';
import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:tencent_cloud_chat_demo/src/api/auth_api.dart';

/// Caches the last IM UserSig so cold start can proceed offline when possible.
class ImSessionCache {
  ImSessionCache._();

  static final ImSessionCache instance = ImSessionCache._();

  static const _sessionKey = 'im_session_v2';
  static const _sdkAppIdKey = 'im_session_sdk_app_id';
  static const _userIdKey = 'im_session_user_id';
  static const _userSigKey = 'im_session_user_sig';
  static const _expiresAtKey = 'im_session_expires_at_ms';

  final FlutterSecureStorage _secure = const FlutterSecureStorage();
  Future<void> _operationTail = Future<void>.value();

  Future<void> save(UserSigResult sig) => _synchronized(() async {
        final expiresAt = DateTime.now()
            .add(Duration(seconds: sig.expiresIn))
            .millisecondsSinceEpoch;
        final record = jsonEncode(<String, Object>{
          'sdkAppId': sig.sdkAppId,
          'userId': sig.userId.trim(),
          'userSig': sig.userSig,
          'expiresAtMs': expiresAt,
        });

        // Commit the complete session in one secure-storage write. Legacy keys
        // are removed only after the new record is durable.
        await _secure.write(key: _sessionKey, value: record);
        await _deleteLegacyKeys();
      });

  /// Persists a credential only while the caller still owns the session that
  /// requested it. The check runs inside the same serialized queue as the
  /// write, so a late account-A response cannot overwrite account B.
  Future<bool> saveIfCurrent(
    UserSigResult sig,
    bool Function() isCurrent,
  ) async {
    var saved = false;
    await _synchronized(() async {
      if (!isCurrent()) return;
      final expiresAt = DateTime.now()
          .add(Duration(seconds: sig.expiresIn))
          .millisecondsSinceEpoch;
      final record = jsonEncode(<String, Object>{
        'sdkAppId': sig.sdkAppId,
        'userId': sig.userId.trim(),
        'userSig': sig.userSig,
        'expiresAtMs': expiresAt,
      });
      await _secure.write(key: _sessionKey, value: record);
      await _deleteLegacyKeys();
      saved = isCurrent();
    });
    return saved;
  }

  /// Reads the last SDK AppID even when the UserSig has expired.
  Future<int?> readCachedSdkAppId() => _synchronized(() async {
        final record = await _readRecord(includeExpired: true);
        return record?.sdkAppId;
      });

  /// Returns the cached IM owner even when the UserSig has expired.
  /// Logout uses this only as a fallback after live UIKit/native identity.
  Future<String> readCachedUserId() => _synchronized(() async {
        final record = await _readRecord(includeExpired: true);
        return record?.userId ?? '';
      });

  Future<UserSigResult?> loadIfValid() => _synchronized(() async {
        final record = await _readRecord(includeExpired: false);
        return record?.toUserSigResult();
      });

  Future<UserSigResult?> loadIfValidForUser(String userId) async {
    final trimmed = userId.trim();
    if (trimmed.isEmpty) {
      return null;
    }
    return _synchronized(() async {
      final record = await _readRecord(includeExpired: false);
      if (record == null || record.userId != trimmed) {
        return null;
      }
      return record.toUserSigResult();
    });
  }

  Future<void> clear() => _synchronized(_deleteAllKeys);

  /// Removes only [userId]'s cached IM credential.
  ///
  /// This prevents a delayed logout for account A from deleting account B's
  /// freshly persisted session.
  Future<bool> clearForUser(String userId) async {
    final expected = userId.trim();
    if (expected.isEmpty) {
      return false;
    }
    var cleared = false;
    await _synchronized(() async {
      final record = await _readRecord(includeExpired: true);
      if (record == null || record.userId != expected) {
        return;
      }
      await _deleteAllKeys();
      cleared = true;
    });
    return cleared;
  }

  Future<_StoredImSession?> _readRecord({required bool includeExpired}) async {
    final raw = await _secure.read(key: _sessionKey);
    if (raw != null && raw.trim().isNotEmpty) {
      // Once the atomic format exists it is authoritative. Falling back to
      // leftover legacy keys after this record expires/corrupts could revive a
      // previous account.
      return _decodeRecord(raw, includeExpired: includeExpired);
    }

    final legacy = await _readLegacyRecord(includeExpired: includeExpired);
    if (legacy == null) {
      return null;
    }

    // Migrate old four-key records to the atomic representation. An expired
    // legacy record is still useful for owner/AppID lookup during logout.
    await _secure.write(key: _sessionKey, value: jsonEncode(legacy.toJson()));
    await _deleteLegacyKeys();
    return legacy;
  }

  Future<_StoredImSession?> _readLegacyRecord({
    required bool includeExpired,
  }) async {
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
    final sdkAppId = int.tryParse(sdkAppIdRaw);
    final expiresAt = int.tryParse(expiresAtRaw);
    if (sdkAppId == null || expiresAt == null) {
      return null;
    }
    return _validateRecord(
      _StoredImSession(
        sdkAppId: sdkAppId,
        userId: userId.trim(),
        userSig: userSig,
        expiresAtMs: expiresAt,
      ),
      includeExpired: includeExpired,
    );
  }

  _StoredImSession? _decodeRecord(
    String? raw, {
    required bool includeExpired,
  }) {
    if (raw == null || raw.trim().isEmpty) {
      return null;
    }
    try {
      final json = jsonDecode(raw);
      if (json is! Map) {
        return null;
      }
      final sdkAppId = _asInt(json['sdkAppId']);
      final expiresAtMs = _asInt(json['expiresAtMs']);
      if (sdkAppId == null || expiresAtMs == null) {
        return null;
      }
      return _validateRecord(
        _StoredImSession(
          sdkAppId: sdkAppId,
          userId: json['userId']?.toString().trim() ?? '',
          userSig: json['userSig']?.toString() ?? '',
          expiresAtMs: expiresAtMs,
        ),
        includeExpired: includeExpired,
      );
    } catch (_) {
      return null;
    }
  }

  _StoredImSession? _validateRecord(
    _StoredImSession record, {
    required bool includeExpired,
  }) {
    if (record.sdkAppId <= 0 ||
        record.userId.isEmpty ||
        record.userSig.isEmpty ||
        record.expiresAtMs <= 0) {
      return null;
    }
    if (!includeExpired &&
        DateTime.now().millisecondsSinceEpoch >= record.expiresAtMs) {
      return null;
    }
    return record;
  }

  int? _asInt(Object? value) {
    if (value is int) {
      return value;
    }
    return int.tryParse(value?.toString() ?? '');
  }

  Future<void> _deleteAllKeys() async {
    // Delete legacy keys first so an interrupted clear cannot resurrect them
    // after the atomic record is removed.
    await _deleteLegacyKeys();
    await _secure.delete(key: _sessionKey);
  }

  Future<void> _deleteLegacyKeys() async {
    await _secure.delete(key: _sdkAppIdKey);
    await _secure.delete(key: _userIdKey);
    await _secure.delete(key: _userSigKey);
    await _secure.delete(key: _expiresAtKey);
  }

  Future<T> _synchronized<T>(Future<T> Function() operation) {
    final result = Completer<T>();
    _operationTail = _operationTail.then<void>(
      (_) async {
        try {
          result.complete(await operation());
        } catch (error, stackTrace) {
          result.completeError(error, stackTrace);
        }
      },
      onError: (_) async {
        try {
          result.complete(await operation());
        } catch (error, stackTrace) {
          result.completeError(error, stackTrace);
        }
      },
    );
    return result.future;
  }
}

class _StoredImSession {
  const _StoredImSession({
    required this.sdkAppId,
    required this.userId,
    required this.userSig,
    required this.expiresAtMs,
  });

  final int sdkAppId;
  final String userId;
  final String userSig;
  final int expiresAtMs;

  Map<String, Object> toJson() => <String, Object>{
        'sdkAppId': sdkAppId,
        'userId': userId,
        'userSig': userSig,
        'expiresAtMs': expiresAtMs,
      };

  UserSigResult toUserSigResult() {
    final remainingSec =
        ((expiresAtMs - DateTime.now().millisecondsSinceEpoch) / 1000)
            .floor()
            .clamp(1, 1 << 31);
    return UserSigResult(
      sdkAppId: sdkAppId,
      userId: userId,
      userSig: userSig,
      expiresIn: remainingSec,
    );
  }
}
