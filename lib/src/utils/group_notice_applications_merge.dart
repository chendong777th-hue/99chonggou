import 'package:tencent_cloud_chat_demo/src/services/group_join_application_service.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_group_application.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_group_application.dart';

String groupNoticeApplicationKey(V2TimGroupApplication application) {
  final auth = application.authentication.trim();
  if (auth.startsWith(GroupJoinApplicationService.applicationAuthPrefix)) {
    return 'rest|$auth';
  }
  return [
    application.groupID,
    application.fromUser ?? '',
    application.toUser ?? '',
    application.addTime?.toString() ?? '0',
    application.type.toString(),
  ].join('|');
}

int _normalizeTimestampToMilliseconds(int? timestamp) {
  if (timestamp == null || timestamp <= 0) {
    return 0;
  }
  return timestamp < 1000000000000 ? timestamp * 1000 : timestamp;
}

/// REST 群申请去重排序，供「群通知」入口与列表使用。
List<V2TimGroupApplication> dedupeGroupNoticeApplications(
  List<V2TimGroupApplication> applications,
) {
  final merged = <String, V2TimGroupApplication>{};
  for (final item in applications) {
    merged[groupNoticeApplicationKey(item)] = item;
  }
  final list = merged.values.toList(growable: false)
    ..sort(
      (a, b) => _normalizeTimestampToMilliseconds(b.addTime)
          .compareTo(_normalizeTimestampToMilliseconds(a.addTime)),
    );
  return list;
}

@Deprecated('Use dedupeGroupNoticeApplications with REST-only applications')
List<V2TimGroupApplication> mergeGroupNoticeApplications({
  required List<V2TimGroupApplication> restApplications,
  List<V2TimGroupApplication> sdkApplications = const [],
}) {
  return dedupeGroupNoticeApplications([
    ...sdkApplications,
    ...restApplications,
  ]);
}
