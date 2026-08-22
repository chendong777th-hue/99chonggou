import 'package:flutter/foundation.dart';
import 'package:tencent_cloud_chat_demo/src/services/group_notice_unread_service.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_group_application.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_group_application.dart';
import 'package:tencent_cloud_chat_uikit/business_logic/view_models/tui_chat_global_model.dart'
    show GroupSystemNoticeItem;

/// 群通知会话列表实时刷新排查日志。控制台过滤：`[GroupNoticeFeed]`
///
/// 排查完后把 [enabled] 改回 `false`。
class GroupNoticeFeedLog {
  GroupNoticeFeedLog._();

  /// 临时打开：查「会话列表群通知不实时更新」。
  static const bool enabled = false;

  static int _seq = 0;

  static int nextSeq() => ++_seq;

  static void log(
    String event, {
    Map<String, Object?> extras = const <String, Object?>{},
  }) {
    if (!enabled) {
      return;
    }
    final seq = nextSeq();
    final ms = DateTime.now().millisecondsSinceEpoch;
    final buffer = StringBuffer('[GroupNoticeFeed] #$seq t=$ms event=$event');
    for (final entry in extras.entries) {
      final value = entry.value;
      if (value == null) {
        continue;
      }
      buffer.write(' ${entry.key}=$value');
    }
    // ignore: avoid_print
    print(buffer.toString());
  }

  static String snapshot({
    required List<V2TimGroupApplication> applications,
    required List<GroupSystemNoticeItem> notices,
    int? signature,
    int? unread,
  }) {
    final latest = latestGroupNoticeTimestampMs(applications, notices);
    final headNotice = notices.isEmpty
        ? '-'
        : '${notices.first.id}:${notices.first.type.index}@${notices.first.timestamp}';
    final headApp = applications.isEmpty
        ? '-'
        : '${applications.first.groupID}:${applications.first.handleStatus}@${applications.first.addTime}';
    return 'apps=${applications.length} notices=${notices.length} '
        'latest=$latest unread=${unread ?? '-'} sig=${signature ?? '-'} '
        'headN=$headNotice headA=$headApp';
  }
}
