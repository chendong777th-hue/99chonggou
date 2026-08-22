import 'package:tencent_cloud_chat_demo/src/api/group_join_api.dart';
import 'package:tencent_cloud_chat_demo/src/services/group_join_application_service.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_group_application.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_group_application.dart';

class GroupJoinApplicationMapper {
  GroupJoinApplicationMapper._();

  static V2TimGroupApplication toUIKitApplication(
    GroupJoinApplicationRecord record,
  ) {
    final addTimeSeconds = (record.createdAtMs ?? 0) > 0
        ? (record.createdAtMs! >= 1000000000000
            ? record.createdAtMs! ~/ 1000
            : record.createdAtMs!)
        : DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final statusMapping = _mapStatus(record.status);
    return V2TimGroupApplication(
      groupID: record.groupId,
      fromUser: record.fromUserId,
      fromUserNickName: record.fromUserNickName,
      fromUserFaceUrl: record.fromUserFaceUrl,
      toUser: record.toUserId,
      addTime: addTimeSeconds,
      requestMsg: record.message,
      type: record.isInvite ? 2 : 0,
      handleStatus: statusMapping.$1,
      handleResult: statusMapping.$2,
      authentication:
          '${GroupJoinApplicationService.applicationAuthPrefix}${record.id}',
    );
  }

  static (int handleStatus, int handleResult) handleFlagsForStatus(
    String status,
  ) {
    return _mapStatus(status);
  }

  static (int handleStatus, int handleResult) _mapStatus(String status) {
    switch (status.trim().toLowerCase()) {
      case 'approved':
      case 'accepted':
      case 'added':
        return (1, 1);
      case 'rejected':
      case 'declined':
        return (1, 2);
      default:
        return (0, 0);
    }
  }
}
