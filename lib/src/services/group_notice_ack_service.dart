import 'package:shared_preferences/shared_preferences.dart';
import 'package:tencent_cloud_chat_demo/utils/chat_id_format.dart';
import 'package:tencent_cloud_chat_uikit/data_services/core/core_services_implements.dart';
import 'package:tencent_cloud_chat_uikit/data_services/services_locatar.dart';

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

  String _scopedKey(String groupId) {
    final id = groupId.trim();
    final userId = ChatIdFormat.rawUserUid(
      serviceLocator<CoreServicesImpl>().loginUserInfo?.userID ?? '',
    );
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
    final prefs = await SharedPreferences.getInstance();
    final scoped = prefs.getString(_scopedKey(id))?.trim();
    if (scoped != null && scoped.isNotEmpty) {
      return scoped;
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
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_scopedKey(id), value);
  }
}
