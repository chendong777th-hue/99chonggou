import 'package:flutter/foundation.dart';
import 'package:tencent_cloud_chat_demo/src/services/group_join_application_service.dart';
import 'package:tencent_cloud_chat_demo/src/services/group_notice_feed_log.dart';
import 'package:tencent_cloud_chat_demo/src/services/group_system_notice_service.dart';

/// 监听群通知相关数据（REST 审批 + 系统通知）。
class GroupNoticeFeedListenable extends ChangeNotifier {
  GroupNoticeFeedListenable() {
    GroupJoinApplicationService.instance.addListener(_onChanged);
    GroupSystemNoticeService.instance.addListener(_onChanged);
  }

  void _onChanged() {
    GroupNoticeFeedLog.log('feed_listenable_notify', extras: {
      'apps': GroupJoinApplicationService.instance.applications.length,
      'notices': GroupSystemNoticeService.instance.notices.length,
    });
    notifyListeners();
  }

  @override
  void dispose() {
    GroupJoinApplicationService.instance.removeListener(_onChanged);
    GroupSystemNoticeService.instance.removeListener(_onChanged);
    super.dispose();
  }
}
