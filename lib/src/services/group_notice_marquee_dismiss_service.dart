import 'package:shared_preferences/shared_preferences.dart';
import 'package:tencent_cloud_chat_demo/src/services/session_identity.dart';
import 'package:tencent_cloud_chat_demo/utils/chat_id_format.dart';

/// 群公告跑马灯的「关闭」状态存储。
///
/// 与弹窗的「我知道了」(GroupNoticeAckService) 完全独立：使用不同的 key 前缀，
/// 且按公告内容记录——公告内容变化后跑马灯会重新出现。
class GroupNoticeMarqueeDismissService {
  GroupNoticeMarqueeDismissService._();

  static final GroupNoticeMarqueeDismissService instance =
      GroupNoticeMarqueeDismissService._();

  static const String _prefix = 'group_notice_marquee_dismiss_v1_';

  String _scopedKey(String groupId, String ownerUserId) {
    final id = groupId.trim();
    final userId = ChatIdFormat.rawUserUid(ownerUserId);
    if (userId.isEmpty) {
      return '$_prefix$id';
    }
    return '$_prefix${userId}_$id';
  }

  /// 返回被关闭的公告内容；若未关闭则为 null。
  Future<String?> getDismissedNotice(String groupId) async {
    final id = groupId.trim();
    if (id.isEmpty) {
      return null;
    }
    final identity = SessionIdentityService.instance.capture();
    if (!_isCurrentOrGuest(identity)) return null;
    final prefs = await SharedPreferences.getInstance();
    if (!_isCurrentOrGuest(identity)) return null;
    final value = prefs.getString(_scopedKey(id, identity.ownerUserId))?.trim();
    if (value == null || value.isEmpty) {
      return null;
    }
    return value;
  }

  /// 判断某条公告内容当前是否已被关闭。
  Future<bool> isDismissed({
    required String groupId,
    required String notice,
  }) async {
    final body = notice.trim();
    if (body.isEmpty) {
      return false;
    }
    final identity = SessionIdentityService.instance.capture();
    final dismissed = await getDismissedNotice(groupId);
    if (!_isCurrentOrGuest(identity)) return false;
    return dismissed != null && dismissed == body;
  }

  Future<void> saveDismissedNotice(String groupId, String notice) async {
    final id = groupId.trim();
    final body = notice.trim();
    if (id.isEmpty || body.isEmpty) {
      return;
    }
    final identity = SessionIdentityService.instance.capture();
    if (!_isCurrentOrGuest(identity)) return;
    final prefs = await SharedPreferences.getInstance();
    if (!_isCurrentOrGuest(identity)) return;
    await prefs.setString(_scopedKey(id, identity.ownerUserId), body);
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
