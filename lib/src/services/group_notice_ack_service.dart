import 'package:shared_preferences/shared_preferences.dart';
import 'package:tencent_cloud_chat_demo/src/services/session_identity.dart';
import 'package:tencent_cloud_chat_demo/utils/chat_id_format.dart';

class GroupNoticeAckService {
  GroupNoticeAckService._();

  static final GroupNoticeAckService instance = GroupNoticeAckService._();

  static const String _prefix = 'group_notice_ack_v1_';

  /// Stable id for a group notice revision (independent of push timestamp).
  static String buildSignature({
    required String groupId,
    required String notice,
    required int noticeUpdatedAtMs,
  }) {
    final id = groupId.trim();
    final body = notice.trim();
    final updatedAt = noticeUpdatedAtMs > 0 ? noticeUpdatedAtMs : 0;
    return '$id|$updatedAt|$body';
  }

  /// Returns true when [ackedSignature] matches [currentSignature] or a legacy
  /// signature for the same notice body.
  static bool isAcknowledged({
    required String? ackedSignature,
    required String currentSignature,
    required String groupId,
    required String notice,
  }) {
    final acked = ackedSignature?.trim() ?? '';
    if (acked.isEmpty) {
      return false;
    }
    if (acked == currentSignature.trim()) {
      return true;
    }

    final id = groupId.trim();
    final body = notice.trim();
    if (id.isEmpty || body.isEmpty) {
      return false;
    }
    if (!acked.startsWith('$id|')) {
      return false;
    }
    return acked.endsWith('|$body');
  }

  String _scopedKey(String groupId, String ownerUserId) {
    final id = groupId.trim();
    final userId = ChatIdFormat.rawUserUid(ownerUserId);
    if (userId.isEmpty) {
      return '$_prefix$id';
    }
    return '${_prefix}${userId}_$id';
  }

  String _legacyKey(String groupId) => '$_prefix${groupId.trim()}';

  Future<String?> getAckSignature(String groupId) async {
    final id = groupId.trim();
    if (id.isEmpty) {
      return null;
    }
    final identity = SessionIdentityService.instance.capture();
    final prefs = await SharedPreferences.getInstance();
    if (!_isCurrentOrGuest(identity)) return null;
    final scoped =
        prefs.getString(_scopedKey(id, identity.ownerUserId))?.trim();
    if (scoped != null && scoped.isNotEmpty) {
      return scoped;
    }
    if (identity.ownerUserId.isNotEmpty) {
      return null;
    }
    final legacy = prefs.getString(_legacyKey(id))?.trim();
    if (legacy == null || legacy.isEmpty) {
      return null;
    }
    return legacy;
  }

  Future<void> saveAckSignature(String groupId, String signature) async {
    final id = groupId.trim();
    final value = signature.trim();
    if (id.isEmpty || value.isEmpty) {
      return;
    }
    final identity = SessionIdentityService.instance.capture();
    if (!_isCurrentOrGuest(identity)) return;
    final prefs = await SharedPreferences.getInstance();
    if (!_isCurrentOrGuest(identity)) return;
    await prefs.setString(_scopedKey(id, identity.ownerUserId), value);
  }

  Future<void> clearForOwner(String ownerUserId) async {
    final owner = ChatIdFormat.rawUserUid(ownerUserId);
    if (owner.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    final prefix = '${_prefix}${owner}_';
    final keys =
        prefs.getKeys().where((key) => key.startsWith(prefix)).toList();
    for (final key in keys) {
      await prefs.remove(key);
    }
  }

  bool _isCurrentOrGuest(SessionIdentity identity) {
    if (identity.ownerUserId.isEmpty) {
      final current = SessionIdentityService.instance.capture();
      return current.ownerUserId.isEmpty &&
          current.generation == identity.generation;
    }
    return SessionIdentityService.instance.isCurrent(identity);
  }
}
