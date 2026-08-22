import 'package:shared_preferences/shared_preferences.dart';
import 'package:tencent_cloud_chat_demo/utils/chat_id_format.dart';
import 'package:tencent_cloud_chat_uikit/data_services/core/core_services_implements.dart';
import 'package:tencent_cloud_chat_uikit/data_services/services_locatar.dart';

/// 群公告跑马灯的「关闭」状态存储。
///
/// 与弹窗的「我知道了」(GroupNoticeAckService) 完全独立：使用不同的 key 前缀，
/// 且按公告内容记录——公告内容变化后跑马灯会重新出现。
class GroupNoticeMarqueeDismissService {
  GroupNoticeMarqueeDismissService._();

  static final GroupNoticeMarqueeDismissService instance =
      GroupNoticeMarqueeDismissService._();

  static const String _prefix = 'group_notice_marquee_dismiss_v1_';

  String _scopedKey(String groupId) {
    final id = groupId.trim();
    final userId = ChatIdFormat.rawUserUid(
      serviceLocator<CoreServicesImpl>().loginUserInfo?.userID ?? '',
    );
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
    final prefs = await SharedPreferences.getInstance();
    final value = prefs.getString(_scopedKey(id))?.trim();
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
    final dismissed = await getDismissedNotice(groupId);
    return dismissed != null && dismissed == body;
  }

  Future<void> saveDismissedNotice(String groupId, String notice) async {
    final id = groupId.trim();
    final body = notice.trim();
    if (id.isEmpty || body.isEmpty) {
      return;
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_scopedKey(id), body);
  }
}
