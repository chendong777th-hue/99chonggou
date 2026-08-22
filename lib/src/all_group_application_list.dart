import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_slidable_plus_plus/flutter_slidable_plus_plus.dart';
import 'package:tencent_cloud_chat_demo/src/i18n/app_i18n.dart';
import 'package:provider/provider.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_conversation.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_conversation.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_group_application.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_group_application.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_group_info_result.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_group_info_result.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_user_full_info.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_user_full_info.dart';
import 'package:tencent_cloud_chat_uikit/business_logic/view_models/tui_chat_global_model.dart'
    show GroupSystemNoticeItem, GroupSystemNoticeType;
import 'package:tencent_cloud_chat_uikit/business_logic/view_models/tui_conversation_view_model.dart';
import 'package:tencent_cloud_chat_uikit/data_services/friendShip/friendship_services.dart';
import 'package:tencent_cloud_chat_uikit/data_services/group/group_services.dart';
import 'package:tencent_cloud_chat_uikit/data_services/services_locatar.dart';

import 'package:tencent_cloud_chat_demo/src/services/group_join_application_service.dart';
import 'package:tencent_cloud_chat_demo/src/services/group_system_notice_service.dart';
import 'package:tencent_cloud_chat_demo/src/services/group_notice_unread_service.dart';
import 'package:tencent_cloud_chat_demo/src/provider/theme.dart';
import 'package:tencent_cloud_chat_demo/src/navigation/app_chat_route.dart';
import 'package:tencent_cloud_chat_demo/src/widgets/app_user_avatar.dart';
import 'package:tencent_cloud_chat_demo/src/widgets/app_dialog.dart';
import 'package:dio/dio.dart';
import 'package:tencent_cloud_chat_demo/src/api/me_group_api.dart';
import 'package:tencent_cloud_chat_demo/utils/conversation_face_url.dart';
import 'package:tencent_cloud_chat_demo/utils/group_notice_open_gate.dart';
import 'package:tencent_cloud_chat_demo/utils/toast.dart';
import 'package:tencent_cloud_chat_uikit/data_services/conversation/conversation_services.dart';
import 'package:tencent_cloud_chat_uikit/ui/views/TIMUIKitConversation/tim_uikit_conversation.dart';
import 'package:tencent_cloud_chat_demo/src/navigation/app_page_transitions.dart';
import 'package:tencent_cloud_chat_demo/src/ui/utils/desktop_modal_layout.dart';

enum _ApplicationStatus {
  none,
  accept,
  reject,
}

enum _NoticeRowKind {
  application,
  system,
}

class _NoticeRowItem {
  final _NoticeRowKind kind;
  final V2TimGroupApplication? application;
  final GroupSystemNoticeItem? systemNotice;
  final int timestamp;

  const _NoticeRowItem.application(this.application, this.timestamp)
      : kind = _NoticeRowKind.application,
        systemNotice = null;

  const _NoticeRowItem.system(this.systemNotice, this.timestamp)
      : kind = _NoticeRowKind.system,
        application = null;
}

String _groupNoticePlaceholderIfEmpty(String? faceUrl) {
  final trimmed = faceUrl?.trim() ?? '';
  final lower = trimmed.toLowerCase();
  if (trimmed.isEmpty ||
      lower.contains('default_c2c_head') ||
      lower.contains('default_group_head')) {
    return ConversationFaceUrl.defaultGroupFaceAsset;
  }
  return trimmed;
}

class AllGroupApplicationListPage extends StatefulWidget {
  const AllGroupApplicationListPage({
    Key? key,
    this.embedded = false,
    this.shellEmbedded = false,
    this.onClose,
    this.onOpenConversation,
  }) : super(key: key);

  /// Web / 桌面弹窗内嵌时去掉内层 AppBar，由外层标题栏负责关闭。
  final bool embedded;

  /// 嵌在主壳右侧：保留返回栏，左侧主壳继续显示导航 + 群列表。
  final bool shellEmbedded;
  final VoidCallback? onClose;

  /// 主壳内打开群聊：关闭侧栏并切到对应会话，避免再全屏 push Chat。
  final ValueChanged<V2TimConversation>? onOpenConversation;

  @override
  State<AllGroupApplicationListPage> createState() =>
      _AllGroupApplicationListPageState();
}

class _AllGroupApplicationListPageState
    extends State<AllGroupApplicationListPage> {
  final FriendshipServices _friendshipServices =
      serviceLocator<FriendshipServices>();
  final GroupServices _groupServices = serviceLocator<GroupServices>();
  final TUIConversationViewModel _conversationViewModel =
      serviceLocator<TUIConversationViewModel>();
  final ConversationService _conversationService =
      serviceLocator<ConversationService>();
  final GroupJoinApplicationService _joinApplicationService =
      GroupJoinApplicationService.instance;
  final GroupSystemNoticeService _systemNoticeService =
      GroupSystemNoticeService.instance;

  List<V2TimGroupApplication> _groupApplicationList = [];
  List<_ApplicationStatus> _applicationStatusList = [];
  List<_NoticeRowItem> _noticeRows = [];
  final Map<String, String> _groupNameCache = {};
  final Map<String, String> _groupFaceUrlCache = {};
  final Map<String, String> _userNameCache = {};
  final Set<String> _processingApplicationKeys = {};
  bool _warmUpInProgress = false;
  bool _warmUpScheduled = false;
  bool _deletingNotice = false;
  String? _selectedRowKey;
  V2TimUserFullInfo? _selectedUserInfo;
  bool _loadingSelectedUser = false;

  bool get _isDesktop => DesktopModalLayout.isDesktop(context);

  String _noticeRowKey(_NoticeRowItem item) {
    if (item.kind == _NoticeRowKind.application && item.application != null) {
      return 'app_${_applicationKey(item.application!)}';
    }
    final notice = item.systemNotice;
    if (notice == null) {
      return 'empty';
    }
    return 'sys_${notice.groupID}_${notice.timestamp}_${notice.type}';
  }

  _NoticeRowItem? get _selectedRow {
    final key = _selectedRowKey;
    if (key == null) {
      return null;
    }
    for (final row in _noticeRows) {
      if (_noticeRowKey(row) == key) {
        return row;
      }
    }
    return null;
  }

  Future<void> _selectNoticeRow(_NoticeRowItem item) async {
    final key = _noticeRowKey(item);
    setState(() {
      _selectedRowKey = key;
      _selectedUserInfo = null;
      _loadingSelectedUser =
          item.kind == _NoticeRowKind.application && item.application != null;
    });
    if (item.kind != _NoticeRowKind.application || item.application == null) {
      return;
    }
    final userInfo = await _loadTargetUserInfo(item.application!);
    if (!mounted || _selectedRowKey != key) {
      return;
    }
    setState(() {
      _selectedUserInfo = userInfo;
      _loadingSelectedUser = false;
    });
  }

  @override
  void initState() {
    super.initState();
    _refreshLocalList();
    _joinApplicationService.addListener(_onGroupNoticeDataUpdated);
    _systemNoticeService.addListener(_onGroupNoticeDataUpdated);
    unawaited(_joinApplicationService.refresh());
    unawaited(_systemNoticeService.refresh(force: true));
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scheduleWarmUpGroupInfo();
    });
  }

  @override
  void dispose() {
    _joinApplicationService.removeListener(_onGroupNoticeDataUpdated);
    _systemNoticeService.removeListener(_onGroupNoticeDataUpdated);
    super.dispose();
  }

  void _onGroupNoticeDataUpdated() {
    if (!mounted) {
      return;
    }
    _refreshLocalList();
    final selected = _selectedRowKey;
    if (selected != null &&
        !_noticeRows.any((row) => _noticeRowKey(row) == selected)) {
      _selectedRowKey = null;
      _selectedUserInfo = null;
      _loadingSelectedUser = false;
    }
    setState(() {});
    _scheduleWarmUpGroupInfo();
  }

  void _scheduleWarmUpGroupInfo() {
    if (_warmUpInProgress || _warmUpScheduled) {
      return;
    }
    _warmUpScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      _warmUpScheduled = false;
      if (!mounted || _warmUpInProgress) {
        return;
      }
      _warmUpInProgress = true;
      try {
        await _warmUpGroupInfo();
      } finally {
        _warmUpInProgress = false;
      }
    });
  }

  int _normalizeToMilliseconds(int? timestamp) {
    if (timestamp == null || timestamp <= 0) {
      return 0;
    }
    // SDK/application data may mix seconds and milliseconds. Normalize once
    // so sorting and display both use the same unit.
    return timestamp < 1000000000000 ? timestamp * 1000 : timestamp;
  }

  void _refreshLocalList() {
    final previousStatus = <String, _ApplicationStatus>{};
    if (_groupApplicationList.length == _applicationStatusList.length) {
      for (int i = 0; i < _groupApplicationList.length; i++) {
        previousStatus[_applicationKey(_groupApplicationList[i])] =
            _applicationStatusList[i];
      }
    }
    _groupApplicationList = _joinApplicationService.applications;
    _applicationStatusList = _groupApplicationList
        .map(
          (item) =>
              previousStatus[_applicationKey(item)] ?? _ApplicationStatus.none,
        )
        .toList();
    _seedGroupDisplayCaches();
    _noticeRows = [
      ..._groupApplicationList.map(
        (item) => _NoticeRowItem.application(
          item,
          _normalizeToMilliseconds(item.addTime),
        ),
      ),
      ..._systemNoticeService.notices.map(
        (item) => _NoticeRowItem.system(
          item,
          _normalizeToMilliseconds(item.timestamp),
        ),
      ),
    ]..sort((a, b) => b.timestamp.compareTo(a.timestamp));
  }

  void _seedGroupDisplayCaches() {
    for (final application in _groupApplicationList) {
      final groupId = application.groupID.trim();
      if (groupId.isEmpty) {
        continue;
      }
      final name = _joinApplicationService.groupNameFor(groupId);
      if (name != null) {
        _groupNameCache[groupId] = name;
      }
      final avatar = _joinApplicationService.groupAvatarFor(groupId);
      if (avatar != null) {
        _groupFaceUrlCache[groupId] = avatar;
      }
    }
    for (final notice in _systemNoticeService.notices) {
      final groupId = notice.groupID.trim();
      if (groupId.isEmpty) {
        continue;
      }
      final name = notice.groupName.trim();
      if (name.isNotEmpty) {
        _groupNameCache[groupId] = name;
      }
      final avatar = notice.groupFaceUrl.trim();
      if (avatar.isNotEmpty) {
        _groupFaceUrlCache[groupId] = avatar;
      }
    }
  }

  String _applicationKey(V2TimGroupApplication applicationInfo) {
    return [
      applicationInfo.groupID,
      applicationInfo.fromUser ?? "",
      applicationInfo.toUser ?? "",
      applicationInfo.addTime?.toString() ?? "0",
      applicationInfo.type.toString(),
      applicationInfo.authentication,
    ].join("|");
  }

  Future<void> _confirmAndDeleteApplication(
    V2TimGroupApplication application,
  ) async {
    if (_deletingNotice ||
        !_joinApplicationService.canDeleteApplicationForCurrentUser(
          application,
        )) {
      return;
    }
    final i18n = AppI18n.of(context);
    final confirmed = await AppDialog.confirm(
      title: i18n.t(
        zhHans: '删除记录',
        zhHant: '刪除記錄',
        en: 'Delete Record',
        ja: '記録を削除',
        ko: '기록 삭제',
      ),
      message: i18n.t(
        zhHans: '确定删除这条群通知吗？',
        zhHant: '確定刪除這條群通知嗎？',
        en: 'Delete this group notice?',
        ja: 'このグループ通知を削除しますか？',
        ko: '이 그룹 알림을 삭제하시겠습니까?',
      ),
      confirmText: i18n.t(
        zhHans: '删除',
        zhHant: '刪除',
        en: 'Delete',
        ja: '削除',
        ko: '삭제',
      ),
      destructive: true,
    );
    if (!confirmed || !mounted) {
      return;
    }
    setState(() => _deletingNotice = true);
    try {
      await _joinApplicationService.deleteApplication(application);
    } finally {
      if (mounted) {
        setState(() => _deletingNotice = false);
      }
    }
  }

  Future<void> _confirmAndDeleteSystemNotice(
    GroupSystemNoticeItem notice,
  ) async {
    if (_deletingNotice) {
      return;
    }
    final i18n = AppI18n.of(context);
    final confirmed = await AppDialog.confirm(
      title: i18n.t(
        zhHans: '删除记录',
        zhHant: '刪除記錄',
        en: 'Delete Record',
        ja: '記録を削除',
        ko: '기록 삭제',
      ),
      message: i18n.t(
        zhHans: '确定删除这条群通知吗？',
        zhHant: '確定刪除這條群通知嗎？',
        en: 'Delete this group notice?',
        ja: 'このグループ通知を削除しますか？',
        ko: '이 그룹 알림을 삭제하시겠습니까?',
      ),
      confirmText: i18n.t(
        zhHans: '删除',
        zhHant: '刪除',
        en: 'Delete',
        ja: '削除',
        ko: '삭제',
      ),
      destructive: true,
    );
    if (!confirmed || !mounted) {
      return;
    }
    setState(() => _deletingNotice = true);
    try {
      await _systemNoticeService.deleteNotice(notice);
    } finally {
      if (mounted) {
        setState(() => _deletingNotice = false);
      }
    }
  }

  Future<void> _clearAllGroupNotices() async {
    if (_deletingNotice || _noticeRows.isEmpty) {
      return;
    }
    setState(() => _deletingNotice = true);
    try {
      final results = await Future.wait<bool>([
        _joinApplicationService.clearAllApplications(),
        _systemNoticeService.clearAllNotices(),
      ]);
      if (!mounted) {
        return;
      }
      if (results.every((item) => item)) {
        await GroupNoticeUnreadService.instance.markRead(
          readAtMs: DateTime.now().millisecondsSinceEpoch,
        );
        ToastUtils.toast(AppI18n.of(context).t(
          zhHans: '已清空群通知',
          zhHant: '已清空群通知',
          en: 'Group notices cleared',
          ja: 'グループ通知をクリアしました',
          ko: '그룹 알림을 비웠습니다',
        ));
      } else {
        ToastUtils.toast(AppI18n.of(context).t(
          zhHans: '清空失败，请稍后重试',
          zhHant: '清空失敗，請稍後重試',
          en: 'Failed to clear group notices. Please try again.',
          ja: 'クリアに失敗しました。しばらくして再試行してください。',
          ko: '비우기에 실패했습니다. 잠시 후 다시 시도해 주세요.',
        ));
      }
    } finally {
      if (mounted) {
        setState(() => _deletingNotice = false);
      }
    }
  }

  void _showMoreActions() {
    final i18n = AppI18n.of(context);
    showCupertinoModalPopup<void>(
      context: context,
      builder: (sheetContext) => CupertinoActionSheet(
        actions: [
          CupertinoActionSheetAction(
            isDestructiveAction: true,
            onPressed: () async {
              Navigator.pop(sheetContext);
              if (_noticeRows.isEmpty || _deletingNotice) {
                return;
              }
              await _clearAllGroupNotices();
            },
            child: Text(i18n.t(
              zhHans: '清空群通知',
              zhHant: '清空群通知',
              en: 'Clear Group Notices',
              ja: 'グループ通知をクリア',
              ko: '그룹 알림 비우기',
            )),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.pop(sheetContext),
          child: Text(i18n.t(
            zhHans: '取消',
            zhHant: '取消',
            en: 'Cancel',
            ja: 'キャンセル',
            ko: '취소',
          )),
        ),
      ),
    );
  }

  Widget _wrapNoticeRowWithDelete({
    required Widget child,
    VoidCallback? onDelete,
  }) {
    if (onDelete == null) {
      return child;
    }
    final i18n = AppI18n.of(context);
    return Slidable(
      groupTag: 'group-notice-list',
      endActionPane: ActionPane(
        extentRatio: 0.22,
        motion: const DrawerMotion(),
        children: [
          ConversationItemSlidePanel(
            onPressed: (_) => onDelete(),
            backgroundColor: const Color(0xFFFF584C),
            foregroundColor: Colors.white,
            label: i18n.t(
              zhHans: '删除',
              zhHant: '刪除',
              en: 'Delete',
              ja: '削除',
              ko: '삭제',
            ),
            padding: EdgeInsets.zero,
          ),
        ],
      ),
      child: child,
    );
  }

  int _findApplicationIndex(V2TimGroupApplication applicationInfo) {
    final key = _applicationKey(applicationInfo);
    return _groupApplicationList.indexWhere(
      (item) => _applicationKey(item) == key,
    );
  }

  String _getGroupName(String groupID) {
    return _groupNameCache[groupID] ?? groupID;
  }

  String _getGroupFaceUrl(String groupID) {
    return _groupFaceUrlCache[groupID] ?? "";
  }

  String _resolvePersonName({
    required String? userId,
    String? apiNickName,
    required String fallback,
  }) {
    final id = userId?.trim() ?? '';
    if (id.isEmpty) {
      return fallback;
    }
    final nick = apiNickName?.trim();
    if (nick != null && nick.isNotEmpty) {
      return nick;
    }
    final fromService =
        GroupJoinApplicationService.instance.resolveDisplayName(userId: id);
    if (fromService.isNotEmpty && fromService != id) {
      return fromService;
    }
    final cached = _userNameCache[id];
    if (cached != null && cached.isNotEmpty && cached != id) {
      return cached;
    }
    return id;
  }

  String _someoneFallback() {
    return AppI18n.of(context).t(
      zhHans: '有人',
      zhHant: '有人',
      en: 'Someone',
      ja: '誰か',
      ko: '누군가',
    );
  }

  String _getContent(
    V2TimGroupApplication applicationInfo,
    String groupName,
  ) {
    final applicant = _resolvePersonName(
      userId: applicationInfo.fromUser,
      apiNickName: applicationInfo.fromUserNickName,
      fallback: _someoneFallback(),
    );
    final target = applicationInfo.toUser?.trim() ?? "";
    final targetName = target.isNotEmpty
        ? _resolvePersonName(
            userId: target,
            apiNickName: null,
            fallback: target,
          )
        : "";
    switch (applicationInfo.type) {
      case 0:
        return AppI18n.of(context).format(
          zhHans: '{option1} 申请加入 {option2}',
          zhHant: '{option1} 申請加入 {option2}',
          en: '{option1} requested to join {option2}',
          ja: '{option1}が{option2}への参加を申請',
          ko: '{option1}님이 {option2} 참가를 요청함',
          vars: {'option1': applicant, 'option2': groupName},
        );
      case 1:
      case 2:
        if (targetName.isNotEmpty) {
          return AppI18n.of(context).format(
            zhHans: '{option1} 邀请 {option2} 加入群聊',
            zhHant: '{option1} 邀請 {option2} 加入群聊',
            en: '{option1} invited {option2} to the group',
            ja: '{option1}が{option2}をグループに招待',
            ko: '{option1}님이 {option2}님을 그룹에 초대',
            vars: {'option1': applicant, 'option2': targetName},
          );
        }
        return AppI18n.of(context).format(
          zhHans: '{option1} 邀请成员加入群聊',
          zhHant: '{option1} 邀請成員加入群聊',
          en: '{option1} invited members to the group',
          ja: '{option1}がメンバーをグループに招待',
          ko: '{option1}님이 멤버를 그룹에 초대',
          vars: {'option1': applicant},
        );
      default:
        return AppI18n.of(context).format(
          zhHans: '{option1} 发起入群申请',
          zhHant: '{option1} 發起入群申請',
          en: '{option1} requested to join the group',
          ja: '{option1}がグループ参加を申請',
          ko: '{option1}님이 그룹 가입을 요청',
          vars: {'option1': applicant},
        );
    }
  }

  String _formatTimeLabelFromMilliseconds(int timestampMs) {
    if (timestampMs == 0) {
      return "";
    }
    final date = DateTime.fromMillisecondsSinceEpoch(timestampMs);
    final now = DateTime.now();
    final sameDay =
        now.year == date.year && now.month == date.month && now.day == date.day;
    if (sameDay) {
      final hh = date.hour.toString().padLeft(2, '0');
      final mm = date.minute.toString().padLeft(2, '0');
      return "$hh:$mm";
    }

    final yesterday = now.subtract(const Duration(days: 1));
    final isYesterday = yesterday.year == date.year &&
        yesterday.month == date.month &&
        yesterday.day == date.day;
    if (isYesterday) {
      return AppI18n.of(context).t(
        zhHans: '昨天',
        zhHant: '昨天',
        en: 'Yesterday',
        ja: '昨日',
        ko: '어제',
      );
    }

    final weekdays = [
      AppI18n.of(context).t(
        zhHans: '周一',
        zhHant: '週一',
        en: 'Mon',
        ja: '月',
        ko: '월',
      ),
      AppI18n.of(context).t(
        zhHans: '周二',
        zhHant: '週二',
        en: 'Tue',
        ja: '火',
        ko: '화',
      ),
      AppI18n.of(context).t(
        zhHans: '周三',
        zhHant: '週三',
        en: 'Wed',
        ja: '水',
        ko: '수',
      ),
      AppI18n.of(context).t(
        zhHans: '周四',
        zhHant: '週四',
        en: 'Thu',
        ja: '木',
        ko: '목',
      ),
      AppI18n.of(context).t(
        zhHans: '周五',
        zhHant: '週五',
        en: 'Fri',
        ja: '金',
        ko: '금',
      ),
      AppI18n.of(context).t(
        zhHans: '周六',
        zhHant: '週六',
        en: 'Sat',
        ja: '土',
        ko: '토',
      ),
      AppI18n.of(context).t(
        zhHans: '周日',
        zhHant: '週日',
        en: 'Sun',
        ja: '日',
        ko: '일',
      ),
    ];
    final diffDays = now.difference(date).inDays;
    if (diffDays < 7 && date.weekday >= 1 && date.weekday <= 7) {
      return weekdays[date.weekday - 1];
    }
    return AppI18n.of(context).format(
      zhHans: '{month}月{day}日',
      zhHant: '{month}月{day}日',
      en: '{month}/{day}',
      ja: '{month}月{day}日',
      ko: '{month}월 {day}일',
      vars: {
        'month': '${date.month}',
        'day': '${date.day}',
      },
    );
  }

  String _getTimeLabel(V2TimGroupApplication applicationInfo) {
    return _formatTimeLabelFromMilliseconds(
      _normalizeToMilliseconds(applicationInfo.addTime),
    );
  }

  String _getSourceLabel(V2TimGroupApplication applicationInfo) {
    final applicant = _resolvePersonName(
      userId: applicationInfo.fromUser,
      apiNickName: applicationInfo.fromUserNickName,
      fallback: _someoneFallback(),
    );
    switch (applicationInfo.type) {
      case 0:
        return AppI18n.of(context).format(
          zhHans: '{option1} 的申请',
          zhHant: '{option1} 的申請',
          en: "{option1}'s request",
          ja: '{option1}の申請',
          ko: '{option1}님의 요청',
          vars: {'option1': applicant},
        );
      case 1:
      case 2:
        return AppI18n.of(context).format(
          zhHans: '成员 {option1} 的邀请',
          zhHant: '成員 {option1} 的邀請',
          en: 'Invitation from member {option1}',
          ja: 'メンバー{option1}からの招待',
          ko: '멤버 {option1}의 초대',
          vars: {'option1': applicant},
        );
      default:
        return applicant;
    }
  }

  String _getSystemNoticeContent(GroupSystemNoticeItem notice) {
    switch (notice.type) {
      case GroupSystemNoticeType.grantAdministrator:
        return AppI18n.of(context).format(
          zhHans: '{option1} 将 {option2} 设为管理员',
          zhHant: '{option1} 將 {option2} 設為管理員',
          en: '{option1} made {option2} an admin',
          ja: '{option1}が{option2}を管理者に設定',
          ko: '{option1}님이 {option2}님을 관리자로 지정',
          vars: {
            'option1': notice.operatorName,
            'option2': notice.targetName,
          },
        );
      case GroupSystemNoticeType.revokeAdministrator:
        return AppI18n.of(context).format(
          zhHans: '{option1} 取消了 {option2} 的管理员身份',
          zhHant: '{option1} 取消了 {option2} 的管理員身份',
          en: '{option1} removed {option2} as admin',
          ja: '{option1}が{option2}の管理者を解除',
          ko: '{option1}님이 {option2}님의 관리자를 해제',
          vars: {
            'option1': notice.operatorName,
            'option2': notice.targetName,
          },
        );
      case GroupSystemNoticeType.transferOwner:
        if (notice.operatorName.isEmpty &&
            notice.targetName ==
                AppI18n.of(context).t(
                  zhHans: '你',
                  zhHant: '你',
                  en: 'You',
                  ja: 'あなた',
                  ko: '나',
                )) {
          return AppI18n.of(context).t(
            zhHans: '群主已转让给你',
            zhHant: '群主已轉讓給你',
            en: 'Group ownership transferred to you',
            ja: 'グループオーナーがあなたに譲渡されました',
            ko: '그룹장이 당신에게 양도되었습니다',
          );
        }
        return AppI18n.of(context).format(
          zhHans: '{option1} 转让群主给 {option2}',
          zhHant: '{option1} 轉讓群主給 {option2}',
          en: '{option1} transferred ownership to {option2}',
          ja: '{option1}が{option2}にオーナーを譲渡',
          ko: '{option1}님이 {option2}님에게 그룹장 양도',
          vars: {
            'option1': notice.operatorName,
            'option2': notice.targetName,
          },
        );
    }
  }

  Future<V2TimUserFullInfo?> _loadTargetUserInfo(
    V2TimGroupApplication applicationInfo,
  ) async {
    final targetUserID = applicationInfo.toUser?.trim() ?? "";
    final fallbackUserID = applicationInfo.fromUser?.trim() ?? "";
    final userID = targetUserID.isNotEmpty ? targetUserID : fallbackUserID;
    if (userID.isEmpty) {
      return null;
    }
    final users = await _friendshipServices.getUsersInfo(userIDList: [userID]);
    if (users == null || users.isEmpty) {
      return null;
    }
    return users.first;
  }

  bool _isApplicationAccepted(V2TimGroupApplication applicationInfo) {
    final applicationIndex = _findApplicationIndex(applicationInfo);
    if (applicationIndex >= 0 &&
        applicationIndex < _applicationStatusList.length &&
        _applicationStatusList[applicationIndex] == _ApplicationStatus.accept) {
      return true;
    }
    return applicationInfo.handleResult == 1;
  }

  Future<V2TimConversation?> _resolveGroupConversation(String groupID) async {
    final id = groupID.trim();
    if (id.isEmpty) {
      return null;
    }
    final conversationID = 'group_$id';
    final cached = _conversationViewModel.getConversation(conversationID);
    if (cached != null) {
      return cached;
    }
    final conversation = await _conversationService.getConversation(
      conversationID: conversationID,
    );
    if (conversation != null) {
      return conversation;
    }
    final fromList = await _conversationService
        .getConversationListByConversationId(convID: conversationID);
    if (fromList != null) {
      return fromList;
    }
    final groupName = _getGroupName(id);
    return V2TimConversation(
      conversationID: conversationID,
      type: 2,
      groupID: id,
      showName: groupName.isNotEmpty ? groupName : id,
      faceUrl: _getGroupFaceUrl(id),
    );
  }

  Future<void> _openGroupChat(
    BuildContext context,
    String groupID,
  ) async {
    final id = groupID.trim();
    if (id.isEmpty) {
      ToastUtils.toast(AppI18n.of(context).t(
        zhHans: '您不在该群聊中',
        zhHant: '您不在該群聊中',
        en: 'You are not in this group',
        ja: 'このグループに参加していません',
        ko: '이 그룹에 없습니다',
      ));
      return;
    }

    GroupNoticeOpenGate gate;
    try {
      final detail = await MeGroupApi.instance.fetchGroupDetail(
        id,
        refresh: true,
      );
      gate = interpretMeGroupDetailForOpen(record: detail);
    } on DioError catch (error) {
      gate = interpretMeGroupDetailForOpen(
        errorCode: MeGroupApi.readDioCode(error),
      );
    } catch (_) {
      gate = GroupNoticeOpenGate.unavailable;
    }
    if (!context.mounted) {
      return;
    }
    switch (gate) {
      case GroupNoticeOpenGate.denyNotInGroup:
        ToastUtils.toast(AppI18n.of(context).t(
          zhHans: '您不在该群聊中',
          zhHant: '您不在該群聊中',
          en: 'You are not in this group',
          ja: 'このグループに参加していません',
          ko: '이 그룹에 없습니다',
        ));
        return;
      case GroupNoticeOpenGate.unavailable:
        ToastUtils.toast(AppI18n.of(context).t(
          zhHans: '网络异常，请稍后重试',
          zhHant: '網路異常，請稍後重試',
          en: 'Network error. Please try again later.',
          ja: 'ネットワークエラーです。しばらくしてから再試行してください',
          ko: '네트워크 오류입니다. 잠시 후 다시 시도해 주세요',
        ));
        return;
      case GroupNoticeOpenGate.allow:
        break;
    }

    final conversation = await _resolveGroupConversation(id);
    if (!context.mounted) {
      return;
    }
    if (conversation == null) {
      ToastUtils.toast(AppI18n.of(context).t(
        zhHans: '进入群聊失败',
        zhHant: '進入群聊失敗',
        en: 'Failed to open group',
        ja: 'グループを開けませんでした',
        ko: '그룹 입장 실패',
      ));
      return;
    }
    if (widget.onOpenConversation != null) {
      widget.onClose?.call();
      widget.onOpenConversation!(conversation);
      return;
    }
    await Navigator.push(
      context,
      appChatRoute(conversation),
    );
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _openApplicationDetail(
    BuildContext context,
    V2TimGroupApplication applicationInfo,
  ) async {
    final applicationIndex = _findApplicationIndex(applicationInfo);
    if (applicationIndex < 0 ||
        applicationIndex >= _applicationStatusList.length) {
      return;
    }
    if (_isDesktop) {
      final row = _NoticeRowItem.application(
        applicationInfo,
        _normalizeToMilliseconds(applicationInfo.addTime),
      );
      await _selectNoticeRow(row);
      return;
    }
    final theme = Provider.of<DefaultThemeData>(context, listen: false).theme;
    final groupName = _getGroupName(applicationInfo.groupID);
    final groupFaceUrl = _getGroupFaceUrl(applicationInfo.groupID);
    final userInfo = await _loadTargetUserInfo(applicationInfo);
    if (!context.mounted) {
      return;
    }
    await Navigator.push(
      context,
      AppMaterialPageRoute(
        builder: (context) => _GroupApplicationDetailPage(
          applicationInfo: applicationInfo,
          groupName: groupName,
          groupFaceUrl: groupFaceUrl,
          sourceLabel: _getSourceLabel(applicationInfo),
          userInfo: userInfo,
          onAccept: () => _acceptApplication(applicationInfo),
          onReject: () => _rejectApplication(applicationInfo),
          currentStatus: _applicationStatusList[applicationIndex],
          canApprove:
              _joinApplicationService.canApproveApplicationForCurrentUser(
            applicationInfo,
          ),
          themeModel: theme,
        ),
      ),
    );
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _openSystemNoticeChat(
    BuildContext context,
    GroupSystemNoticeItem notice,
  ) async {
    if (_isDesktop) {
      await _selectNoticeRow(
        _NoticeRowItem.system(
          notice,
          _normalizeToMilliseconds(notice.timestamp),
        ),
      );
      return;
    }
    await _openGroupChat(context, notice.groupID);
  }

  Future<void> _warmUpGroupInfo() async {
    final groupIDs =
        _groupApplicationList.map((e) => e.groupID).toSet().toList();
    if (groupIDs.isEmpty) {
      return;
    }

    bool changed = false;
    for (final groupID in groupIDs) {
      final hasGroupName = (_groupNameCache[groupID] ?? "").isNotEmpty;
      final hasGroupFaceUrl = (_groupFaceUrlCache[groupID] ?? "").isNotEmpty;
      if (hasGroupName && hasGroupFaceUrl) {
        continue;
      }
      final conversation =
          _conversationViewModel.getConversation("group_$groupID");
      final conversationName = conversation?.showName?.trim() ?? "";
      final conversationFaceUrl = conversation?.faceUrl ?? "";
      if (conversationName.isNotEmpty) {
        _groupNameCache[groupID] = conversationName;
        changed = true;
      }
      if (conversationFaceUrl.isNotEmpty) {
        _groupFaceUrlCache[groupID] = conversationFaceUrl;
        changed = true;
      }
    }
    if (changed && mounted) {
      setState(() {});
    }

    final unresolvedGroupIDs = groupIDs.where((groupID) {
      final hasGroupName = (_groupNameCache[groupID] ?? "").isNotEmpty;
      final hasGroupFaceUrl = (_groupFaceUrlCache[groupID] ?? "").isNotEmpty;
      return !(hasGroupName && hasGroupFaceUrl);
    }).toList();
    if (unresolvedGroupIDs.isEmpty) {
      return;
    }

    final List<V2TimGroupInfoResult>? groupInfoList =
        await _groupServices.getGroupsInfo(groupIDList: unresolvedGroupIDs);
    if (groupInfoList == null) {
      return;
    }
    bool resolved = false;
    for (final item in groupInfoList) {
      if (item.resultCode != 0 || item.groupInfo == null) {
        continue;
      }
      final groupInfo = item.groupInfo!;
      final groupName = (groupInfo.groupName ?? "").trim();
      final groupFaceUrl = groupInfo.faceUrl ?? "";
      if (groupName.isNotEmpty) {
        _groupNameCache[groupInfo.groupID] = groupName;
        resolved = true;
      }
      if (groupFaceUrl.isNotEmpty) {
        _groupFaceUrlCache[groupInfo.groupID] = groupFaceUrl;
        resolved = true;
      }
    }
    if (resolved && mounted) {
      setState(() {});
    }

    final targetUserIDs = <String>{};
    for (final item in _groupApplicationList) {
      final fromUser = item.fromUser?.trim() ?? '';
      final toUser = item.toUser?.trim() ?? '';
      final handledBy =
          _joinApplicationService.handledByUserIdFor(item)?.trim() ?? '';
      if (fromUser.isNotEmpty && !_userNameCache.containsKey(fromUser)) {
        targetUserIDs.add(fromUser);
      }
      if (toUser.isNotEmpty && !_userNameCache.containsKey(toUser)) {
        targetUserIDs.add(toUser);
      }
      if (handledBy.isNotEmpty && !_userNameCache.containsKey(handledBy)) {
        final known = _joinApplicationService.resolveDisplayName(
          userId: handledBy,
        );
        // 接口已有昵称则不必再拉；仍是 userId 时走 IM SDK 补昵称。
        if (known.isEmpty || known == handledBy) {
          targetUserIDs.add(handledBy);
        } else {
          _userNameCache[handledBy] = known;
        }
      }
    }
    if (targetUserIDs.isEmpty) {
      return;
    }
    final users = await _friendshipServices.getUsersInfo(
      userIDList: targetUserIDs.toList(),
    );
    if (users == null) {
      return;
    }
    bool resolvedUsers = false;
    for (final user in users) {
      final userID = user.userID ?? "";
      final nickName = (user.nickName ?? "").trim();
      if (userID.isEmpty) {
        continue;
      }
      _userNameCache[userID] = nickName.isNotEmpty ? nickName : userID;
      if (nickName.isNotEmpty) {
        GroupJoinApplicationService.instance.cacheDisplayName(userID, nickName);
      }
      resolvedUsers = true;
    }
    if (resolvedUsers && mounted) {
      setState(() {});
    }
  }

  Future<void> _acceptApplication(
    V2TimGroupApplication applicationInfo,
  ) async {
    final applicationIndex = _findApplicationIndex(applicationInfo);
    if (applicationIndex < 0 ||
        applicationIndex >= _applicationStatusList.length) {
      return;
    }
    final applicationKey = _applicationKey(applicationInfo);
    if (_processingApplicationKeys.contains(applicationKey)) {
      return;
    }
    _processingApplicationKeys.add(applicationKey);
    setState(() {
      _applicationStatusList[applicationIndex] = _ApplicationStatus.accept;
    });
    final ok =
        await GroupJoinApplicationService.instance.approve(applicationInfo);
    if (!mounted) {
      return;
    }
    _processingApplicationKeys.remove(applicationKey);
    if (ok) {
      setState(() {});
      return;
    }
    setState(() {
      _applicationStatusList[applicationIndex] = _ApplicationStatus.none;
    });
  }

  Future<void> _rejectApplication(
    V2TimGroupApplication applicationInfo,
  ) async {
    final applicationIndex = _findApplicationIndex(applicationInfo);
    if (applicationIndex < 0 ||
        applicationIndex >= _applicationStatusList.length) {
      return;
    }
    final applicationKey = _applicationKey(applicationInfo);
    if (_processingApplicationKeys.contains(applicationKey)) {
      return;
    }
    _processingApplicationKeys.add(applicationKey);
    setState(() {
      _applicationStatusList[applicationIndex] = _ApplicationStatus.reject;
    });
    final ok =
        await GroupJoinApplicationService.instance.reject(applicationInfo);
    if (!mounted) {
      return;
    }
    _processingApplicationKeys.remove(applicationKey);
    if (ok) {
      setState(() {});
      return;
    }
    setState(() {
      _applicationStatusList[applicationIndex] = _ApplicationStatus.none;
    });
  }

  Widget _buildAvatar({
    required String groupName,
    required String faceUrl,
  }) {
    return AppUserAvatar(
      faceUrl: _groupNoticePlaceholderIfEmpty(faceUrl),
      showName: groupName,
      size: 48,
      type: 2,
    );
  }

  Widget _buildStatusWidget(
    BuildContext context,
    V2TimGroupApplication applicationInfo,
  ) {
    final applicationIndex = _findApplicationIndex(applicationInfo);
    if (applicationIndex < 0 ||
        applicationIndex >= _applicationStatusList.length) {
      return const SizedBox.shrink();
    }
    final theme = Provider.of<DefaultThemeData>(context).theme;
    final currentStatus = _applicationStatusList[applicationIndex];
    final primaryColor = theme.primaryColor ?? const Color(0xFF1E90FF);
    final secondaryTextColor = theme.weakTextColor ?? const Color(0xFF999999);
    final pillBackgroundColor =
        theme.selectPanelBgColor ?? const Color(0xFFF1F2F6);
    if (currentStatus == _ApplicationStatus.accept ||
        applicationInfo.handleResult == 1) {
      return _buildPill(
        AppI18n.of(context).t(
          zhHans: '已同意',
          zhHant: '已同意',
          en: 'Accepted',
          ja: '承認済み',
          ko: '승인됨',
        ),
        textColor: secondaryTextColor,
        backgroundColor: pillBackgroundColor,
      );
    }
    if (currentStatus == _ApplicationStatus.reject ||
        applicationInfo.handleResult == 2) {
      return _buildPill(
        AppI18n.of(context).t(
          zhHans: '已拒绝',
          zhHant: '已拒絕',
          en: 'Declined',
          ja: '拒否済み',
          ko: '거절됨',
        ),
        textColor: secondaryTextColor,
        backgroundColor: pillBackgroundColor,
      );
    }
    if (applicationInfo.handleStatus != 0) {
      return const SizedBox.shrink();
    }
    if (!_joinApplicationService.canApproveApplicationForCurrentUser(
      applicationInfo,
    )) {
      if (_joinApplicationService.isWaitingAdminApprovalForCurrentUser(
        applicationInfo,
      )) {
        return _buildPill(
          AppI18n.of(context).t(
            zhHans: '待审批',
            zhHant: '待審批',
            en: 'Pending',
            ja: '承認待ち',
            ko: '승인 대기',
          ),
          textColor: secondaryTextColor,
          backgroundColor: pillBackgroundColor,
        );
      }
      return const SizedBox.shrink();
    }
    final applicationKey = _applicationKey(applicationInfo);
    if (_processingApplicationKeys.contains(applicationKey)) {
      return SizedBox(
        width: 52,
        height: 40,
        child: Center(
          child: SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: primaryColor,
            ),
          ),
        ),
      );
    }
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => _acceptApplication(applicationInfo),
      child: Container(
        width: 52,
        height: 40,
        decoration: BoxDecoration(
          color: primaryColor,
          borderRadius: BorderRadius.circular(10),
        ),
        child: const Icon(
          Icons.check_rounded,
          color: Colors.white,
          size: 22,
        ),
      ),
    );
  }

  Widget _buildPill(
    String label, {
    required Color textColor,
    required Color backgroundColor,
  }) {
    return Container(
      width: 52,
      height: 40,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 14,
          color: textColor,
          fontWeight: FontWeight.w500,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }

  Widget _buildSystemNoticeItem(
    BuildContext context,
    GroupSystemNoticeItem notice,
  ) {
    final theme = Provider.of<DefaultThemeData>(context).theme;
    final itemBackgroundColor = theme.conversationItemBgColor ??
        theme.wideBackgroundColor ??
        Colors.white;
    final titleTextColor = theme.darkTextColor ?? Colors.black;
    final secondaryTextColor = theme.weakTextColor ?? const Color(0xFF999999);
    final timeLabel = _formatTimeLabelFromMilliseconds(
      _normalizeToMilliseconds(notice.timestamp),
    );

    return Material(
      color: itemBackgroundColor,
      child: InkWell(
        onTap: () => _openSystemNoticeChat(context, notice),
        child: Container(
          color: _isDesktop &&
                  _selectedRowKey ==
                      _noticeRowKey(
                        _NoticeRowItem.system(
                          notice,
                          _normalizeToMilliseconds(notice.timestamp),
                        ),
                      )
              ? (theme.selectPanelBgColor ?? const Color(0xFFF1F2F6))
              : itemBackgroundColor,
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildAvatar(
                groupName: notice.groupName,
                faceUrl: notice.groupFaceUrl,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Flexible(
                          child: Text(
                            notice.groupName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: titleTextColor,
                            ),
                          ),
                        ),
                        if (timeLabel.isNotEmpty) ...[
                          const SizedBox(width: 8),
                          Text(
                            timeLabel,
                            style: TextStyle(
                              fontSize: 13,
                              color: secondaryTextColor,
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _getSystemNoticeContent(notice),
                      style: TextStyle(
                        fontSize: 13,
                        color: theme.primaryColor ?? const Color(0xFF1E90FF),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              _buildPill(
                AppI18n.of(context).t(
                  zhHans: '通知',
                  zhHant: '通知',
                  en: 'Notifications',
                  ja: '通知',
                  ko: '알림',
                ),
                textColor: secondaryTextColor,
                backgroundColor:
                    theme.selectPanelBgColor ?? const Color(0xFFF1F2F6),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildItem(
    BuildContext context,
    V2TimGroupApplication applicationInfo,
  ) {
    final theme = Provider.of<DefaultThemeData>(context).theme;
    final itemBackgroundColor = theme.conversationItemBgColor ??
        theme.wideBackgroundColor ??
        Colors.white;
    final titleTextColor = theme.darkTextColor ?? Colors.black;
    final secondaryTextColor = theme.weakTextColor ?? const Color(0xFF999999);
    final groupName = _getGroupName(applicationInfo.groupID);
    final groupFaceUrl = _getGroupFaceUrl(applicationInfo.groupID);
    final timeLabel = _getTimeLabel(applicationInfo);
    final handledByUserId =
        _joinApplicationService.handledByUserIdFor(applicationInfo);
    final handledBy = handledByUserId == null
        ? ''
        : _resolvePersonName(
            userId: handledByUserId,
            apiNickName: _joinApplicationService
                .recordFor(applicationInfo)
                ?.handledByNickName,
            fallback: handledByUserId,
          );

    return Material(
      color: itemBackgroundColor,
      child: InkWell(
        onTap: () {
          if (_isApplicationAccepted(applicationInfo)) {
            if (_isDesktop) {
              unawaited(
                _selectNoticeRow(
                  _NoticeRowItem.application(
                    applicationInfo,
                    _normalizeToMilliseconds(applicationInfo.addTime),
                  ),
                ),
              );
              return;
            }
            _openGroupChat(context, applicationInfo.groupID);
            return;
          }
          _openApplicationDetail(context, applicationInfo);
        },
        child: Container(
          color: _isDesktop &&
                  _selectedRowKey ==
                      _noticeRowKey(
                        _NoticeRowItem.application(
                          applicationInfo,
                          _normalizeToMilliseconds(applicationInfo.addTime),
                        ),
                      )
              ? (theme.selectPanelBgColor ?? const Color(0xFFF1F2F6))
              : itemBackgroundColor,
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildAvatar(
                groupName: groupName,
                faceUrl: groupFaceUrl,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Flexible(
                          child: Text(
                            groupName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: titleTextColor,
                            ),
                          ),
                        ),
                        if (timeLabel.isNotEmpty) ...[
                          const SizedBox(width: 8),
                          Text(
                            timeLabel,
                            style: TextStyle(
                              fontSize: 13,
                              color: secondaryTextColor,
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _getContent(applicationInfo, groupName),
                      style: TextStyle(
                        fontSize: 13,
                        color: theme.primaryColor ?? const Color(0xFF1E90FF),
                      ),
                    ),
                    if (handledBy.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        AppI18n.of(context).format(
                          zhHans: '处理管理员：{name}',
                          zhHant: '處理管理員：{name}',
                          en: 'Handled by: {name}',
                          ja: '処理管理者：{name}',
                          ko: '처리 관리자: {name}',
                          vars: {'name': handledBy},
                        ),
                        style: TextStyle(
                          fontSize: 12,
                          color: secondaryTextColor,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 12),
              _buildStatusWidget(context, applicationInfo),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNoticeList({
    required Color listBackgroundColor,
    required Color dividerColor,
  }) {
    if (_noticeRows.isEmpty) {
      final theme = Provider.of<DefaultThemeData>(context).theme;
      return Center(
        child: Text(
          AppI18n.of(context).t(
            zhHans: '暂无群通知',
            zhHant: '暫無群組通知',
            en: 'No group notices',
            ja: 'グループ通知はありません',
            ko: '그룹 알림 없음',
          ),
          style: TextStyle(
            fontSize: 15,
            color: theme.weakTextColor ?? const Color(0xFF999999),
          ),
        ),
      );
    }
    return Container(
      color: listBackgroundColor,
      child: ListView.separated(
        itemCount: _noticeRows.length,
        separatorBuilder: (context, index) => Container(
          height: 0.6,
          margin: const EdgeInsets.only(left: 78),
          color: dividerColor,
        ),
        itemBuilder: (context, index) {
          final item = _noticeRows[index];
          if (item.kind == _NoticeRowKind.application &&
              item.application != null) {
            final application = item.application!;
            final canDelete = _joinApplicationService
                .canDeleteApplicationForCurrentUser(application);
            return _wrapNoticeRowWithDelete(
              onDelete: canDelete
                  ? () => _confirmAndDeleteApplication(application)
                  : null,
              child: _buildItem(
                context,
                application,
              ),
            );
          }
          if (item.kind == _NoticeRowKind.system &&
              item.systemNotice != null) {
            return _wrapNoticeRowWithDelete(
              onDelete: () =>
                  _confirmAndDeleteSystemNotice(item.systemNotice!),
              child: _buildSystemNoticeItem(
                context,
                item.systemNotice!,
              ),
            );
          }
          return const SizedBox.shrink();
        },
      ),
    );
  }

  Widget _buildDesktopDetailPane({
    required Color pageBackgroundColor,
    required Color listBackgroundColor,
    required Color dividerColor,
  }) {
    final theme = Provider.of<DefaultThemeData>(context).theme;
    final selected = _selectedRow;
    if (selected == null) {
      return ColoredBox(
        color: pageBackgroundColor,
        child: Center(
          child: Text(
            AppI18n.of(context).t(
              zhHans: '选择一条群通知查看详情',
              zhHant: '選擇一條群通知查看詳情',
              en: 'Select a notice to view details',
              ja: '通知を選択して詳細を表示',
              ko: '알림을 선택해 상세 보기',
            ),
            style: TextStyle(
              fontSize: 15,
              color: theme.weakTextColor ?? const Color(0xFF999999),
            ),
          ),
        ),
      );
    }

    if (selected.kind == _NoticeRowKind.system &&
        selected.systemNotice != null) {
      final notice = selected.systemNotice!;
      final titleColor = theme.darkTextColor ?? Colors.black;
      final secondary = theme.weakTextColor ?? const Color(0xFF999999);
      final primary = theme.primaryColor ?? const Color(0xFF1E90FF);
      return ColoredBox(
        color: pageBackgroundColor,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(28, 28, 28, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  _buildAvatar(
                    groupName: notice.groupName,
                    faceUrl: notice.groupFaceUrl,
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          notice.groupName,
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: titleColor,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          _formatTimeLabelFromMilliseconds(
                            _normalizeToMilliseconds(notice.timestamp),
                          ),
                          style: TextStyle(fontSize: 13, color: secondary),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: listBackgroundColor,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: dividerColor.withValues(alpha: 0.8)),
                ),
                child: Text(
                  _getSystemNoticeContent(notice),
                  style: TextStyle(fontSize: 15, color: titleColor, height: 1.45),
                ),
              ),
              const Spacer(),
              SizedBox(
                height: 48,
                child: ElevatedButton(
                  onPressed: () => _openGroupChat(context, notice.groupID),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primary,
                    foregroundColor: Colors.white,
                    elevation: 0,
                  ),
                  child: Text(
                    AppI18n.of(context).t(
                      zhHans: '进入群聊',
                      zhHant: '進入群聊',
                      en: 'Open Group',
                      ja: 'グループを開く',
                      ko: '그룹 열기',
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (selected.kind == _NoticeRowKind.application &&
        selected.application != null) {
      final application = selected.application!;
      final applicationIndex = _findApplicationIndex(application);
      if (applicationIndex < 0) {
        return const SizedBox.shrink();
      }
      if (_loadingSelectedUser) {
        return ColoredBox(
          color: pageBackgroundColor,
          child: const Center(child: CircularProgressIndicator()),
        );
      }
      return _GroupApplicationDetailPage(
        applicationInfo: application,
        groupName: _getGroupName(application.groupID),
        groupFaceUrl: _getGroupFaceUrl(application.groupID),
        sourceLabel: _getSourceLabel(application),
        userInfo: _selectedUserInfo,
        onAccept: () => _acceptApplication(application),
        onReject: () => _rejectApplication(application),
        currentStatus: _applicationStatusList[applicationIndex],
        canApprove: _joinApplicationService
            .canApproveApplicationForCurrentUser(application),
        themeModel: theme,
        embedded: true,
      );
    }

    return const SizedBox.shrink();
  }

  Widget _buildDesktopDualPane({
    required Color pageBackgroundColor,
    required Color listBackgroundColor,
    required Color dividerColor,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          width: widget.shellEmbedded ? 320 : 380,
          child: _buildNoticeList(
            listBackgroundColor: listBackgroundColor,
            dividerColor: dividerColor,
          ),
        ),
        VerticalDivider(width: 1, thickness: 0.6, color: dividerColor),
        Expanded(
          child: _buildDesktopDetailPane(
            pageBackgroundColor: pageBackgroundColor,
            listBackgroundColor: listBackgroundColor,
            dividerColor: dividerColor,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Provider.of<DefaultThemeData>(context).theme;
    const lightPageBackgroundColor = Color(0xFFF5F6F8);
    final appBarBaseColor =
        theme.appbarBgColor ?? theme.wideBackgroundColor ?? Colors.white;
    final isDarkBackground =
        ThemeData.estimateBrightnessForColor(appBarBaseColor) ==
            Brightness.dark;
    final pageBackgroundColor = isDarkBackground
        ? (theme.weakBackgroundColor ??
            theme.wideBackgroundColor ??
            const Color(0xFF0F0F0F))
        : lightPageBackgroundColor;
    final listBackgroundColor = isDarkBackground
        ? (theme.conversationItemBgColor ??
            theme.wideBackgroundColor ??
            const Color(0xFF171717))
        : Colors.white;
    final appBarBackgroundColor = theme.appbarBgColor ?? listBackgroundColor;
    final appBarTextColor =
        theme.appbarTextColor ?? theme.darkTextColor ?? Colors.black;
    final dividerColor = theme.weakDividerColor ?? const Color(0xFFE5E6E9);
    final useDualPane = _isDesktop;
    final body = useDualPane
        ? _buildDesktopDualPane(
            pageBackgroundColor: pageBackgroundColor,
            listBackgroundColor: listBackgroundColor,
            dividerColor: dividerColor,
          )
        : _buildNoticeList(
            listBackgroundColor: listBackgroundColor,
            dividerColor: dividerColor,
          );

    if (widget.embedded) {
      return Material(
        color: pageBackgroundColor,
        child: body,
      );
    }

    if (widget.shellEmbedded) {
      return Material(
        color: pageBackgroundColor,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              height: 52,
              padding: const EdgeInsets.symmetric(horizontal: 4),
              decoration: BoxDecoration(
                color: appBarBackgroundColor,
                border: Border(
                  bottom: BorderSide(color: dividerColor, width: 0.6),
                ),
              ),
              child: Row(
                children: [
                  IconButton(
                    tooltip: AppI18n.of(context).t(
                      zhHans: '返回',
                      zhHant: '返回',
                      en: 'Back',
                      ja: '戻る',
                      ko: '뒤로',
                    ),
                    onPressed: () {
                      if (widget.onClose != null) {
                        widget.onClose!();
                        return;
                      }
                      Navigator.of(context).maybePop();
                    },
                    icon: Icon(
                      Icons.arrow_back_ios_new_rounded,
                      color: theme.primaryColor ?? const Color(0xFF1E90FF),
                      size: 18,
                    ),
                  ),
                  Expanded(
                    child: Text(
                      AppI18n.of(context).t(
                        zhHans: '群通知',
                        zhHant: '群組通知',
                        en: 'Group Notices',
                        ja: 'グループ通知',
                        ko: '그룹 알림',
                      ),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: appBarTextColor,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: AppI18n.of(context).t(
                      zhHans: '更多',
                      zhHant: '更多',
                      en: 'More',
                      ja: 'その他',
                      ko: '더보기',
                    ),
                    onPressed: _showMoreActions,
                    icon: Icon(
                      Icons.more_horiz,
                      color: theme.primaryColor ?? const Color(0xFF1E90FF),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(child: body),
          ],
        ),
      );
    }

    return Scaffold(
      backgroundColor: pageBackgroundColor,
      appBar: AppBar(
        leading: IconButton(
          onPressed: () {
            Navigator.of(context).pop();
          },
          icon: Icon(
            Icons.arrow_back_ios_new_rounded,
            color: theme.primaryColor ?? const Color(0xFF1E90FF),
            size: 22,
          ),
        ),
        backgroundColor: appBarBackgroundColor,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Text(
          AppI18n.of(context).t(
            zhHans: '群通知',
            zhHant: '群組通知',
            en: 'Group Notices',
            ja: 'グループ通知',
            ko: '그룹 알림',
          ),
          style: TextStyle(
            color: appBarTextColor,
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            tooltip: AppI18n.of(context).t(
              zhHans: '更多',
              zhHant: '更多',
              en: 'More',
              ja: 'その他',
              ko: '더보기',
            ),
            onPressed: _showMoreActions,
            icon: Icon(
              Icons.more_horiz,
              color: theme.primaryColor ?? const Color(0xFF1E90FF),
            ),
          ),
        ],
      ),
      body: body,
    );
  }
}

class _GroupApplicationDetailPage extends StatelessWidget {
  final V2TimGroupApplication applicationInfo;
  final String groupName;
  final String groupFaceUrl;
  final String sourceLabel;
  final V2TimUserFullInfo? userInfo;
  final Future<void> Function() onAccept;
  final Future<void> Function() onReject;
  final _ApplicationStatus currentStatus;
  final bool canApprove;
  final dynamic themeModel;
  final bool embedded;

  const _GroupApplicationDetailPage({
    required this.applicationInfo,
    required this.groupName,
    required this.groupFaceUrl,
    required this.sourceLabel,
    required this.userInfo,
    required this.onAccept,
    required this.onReject,
    required this.currentStatus,
    required this.canApprove,
    required this.themeModel,
    this.embedded = false,
  });

  String _getGenderLabel(BuildContext context) {
    switch (userInfo?.gender) {
      case 1:
        return AppI18n.of(context).t(
          zhHans: '男',
          zhHant: '男',
          en: 'Male',
          ja: '男性',
          ko: '남성',
        );
      case 2:
        return AppI18n.of(context).t(
          zhHans: '女',
          zhHant: '女',
          en: 'Female',
          ja: '女性',
          ko: '여성',
        );
      default:
        return AppI18n.of(context).t(
          zhHans: '保密',
          zhHant: '保密',
          en: 'Private',
          ja: '非公開',
          ko: '비공개',
        );
    }
  }

  Widget _buildDetailAvatar() {
    return AppUserAvatar(
      faceUrl:
          _groupNoticePlaceholderIfEmpty(userInfo?.faceUrl ?? groupFaceUrl),
      showName: groupName,
      size: 72,
      type: 2,
    );
  }

  Widget _buildInfoRow({
    required String title,
    required String value,
    required Color titleColor,
    required Color valueColor,
    required Color backgroundColor,
    required Color dividerColor,
  }) {
    return Container(
      color: backgroundColor,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                fontSize: 16,
                color: titleColor,
              ),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              color: valueColor,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Provider.of<DefaultThemeData>(context).theme;
    const lightPageBackgroundColor = Color(0xFFF5F6F8);
    final appBarBaseColor =
        theme.appbarBgColor ?? theme.wideBackgroundColor ?? Colors.white;
    final isDarkBackground =
        ThemeData.estimateBrightnessForColor(appBarBaseColor) ==
            Brightness.dark;
    final pageBackgroundColor = isDarkBackground
        ? (theme.weakBackgroundColor ??
            theme.wideBackgroundColor ??
            const Color(0xFF0F0F0F))
        : lightPageBackgroundColor;
    final cardBackgroundColor = isDarkBackground
        ? (theme.conversationItemBgColor ??
            theme.wideBackgroundColor ??
            const Color(0xFF171717))
        : Colors.white;
    final titleColor = theme.darkTextColor ?? Colors.black;
    final valueColor = theme.weakTextColor ?? const Color(0xFF999999);
    final dividerColor = theme.weakDividerColor ?? const Color(0xFFE5E6E9);
    final primaryColor = theme.primaryColor ?? const Color(0xFF1E90FF);

    final content = Column(
      children: [
        Container(
          color: cardBackgroundColor,
          padding: const EdgeInsets.fromLTRB(16, 18, 16, 18),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      userInfo?.nickName?.isNotEmpty == true
                          ? userInfo!.nickName!
                          : (userInfo?.userID ??
                              AppI18n.of(context).t(
                                zhHans: '未知用户',
                                zhHant: '未知使用者',
                                en: 'Unknown User',
                                ja: '不明なユーザー',
                                ko: '알 수 없는 사용자',
                              )),
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: titleColor,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: theme.selectPanelBgColor ??
                            const Color(0xFFF1F2F6),
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: Text(
                        _ApplicationStatus.accept == currentStatus ||
                                applicationInfo.handleResult == 1
                            ? AppI18n.of(context).t(
                                zhHans: '已同意',
                                zhHant: '已同意',
                                en: 'Accepted',
                                ja: '承認済み',
                                ko: '승인됨',
                              )
                            : _ApplicationStatus.reject == currentStatus ||
                                    applicationInfo.handleResult == 2
                                ? AppI18n.of(context).t(
                                    zhHans: '已拒绝',
                                    zhHant: '已拒絕',
                                    en: 'Declined',
                                    ja: '拒否済み',
                                    ko: '거절됨',
                                  )
                                : applicationInfo.handleStatus == 0 &&
                                        !canApprove
                                    ? AppI18n.of(context).t(
                                        zhHans: '等待管理员审批',
                                        zhHant: '等待管理員審批',
                                        en: 'Pending admin approval',
                                        ja: '管理者の承認待ち',
                                        ko: '관리자 승인 대기',
                                      )
                                    : AppI18n.of(context).format(
                                        zhHans: '申请加入 {group}',
                                        zhHant: '申請加入 {group}',
                                        en: 'Request to join {group}',
                                        ja: '{group}への参加申請',
                                        ko: '{group} 참가 요청',
                                        vars: {'group': groupName},
                                      ),
                        style: TextStyle(
                          fontSize: 15,
                          color: valueColor,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              _buildDetailAvatar(),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _buildInfoRow(
          title: AppI18n.of(context).t(
            zhHans: '来源',
            zhHant: '來源',
            en: 'Source',
            ja: 'ソース',
            ko: '출처',
          ),
          value: sourceLabel,
          titleColor: titleColor,
          valueColor: valueColor,
          backgroundColor: cardBackgroundColor,
          dividerColor: dividerColor,
        ),
        Container(height: 0.6, color: dividerColor),
        _buildInfoRow(
          title: AppI18n.of(context).t(
            zhHans: 'ID号',
            zhHant: 'ID號',
            en: 'ID',
            ja: 'ID',
            ko: 'ID',
          ),
          value: userInfo?.userID ?? applicationInfo.toUser ?? "",
          titleColor: titleColor,
          valueColor: valueColor,
          backgroundColor: cardBackgroundColor,
          dividerColor: dividerColor,
        ),
        Container(height: 0.6, color: dividerColor),
        _buildInfoRow(
          title: AppI18n.of(context).t(
            zhHans: '性别',
            zhHant: '性別',
            en: 'Gender',
            ja: '性別',
            ko: '성별',
          ),
          value: _getGenderLabel(context),
          titleColor: titleColor,
          valueColor: valueColor,
          backgroundColor: cardBackgroundColor,
          dividerColor: dividerColor,
        ),
        Container(height: 0.6, color: dividerColor),
        _buildInfoRow(
          title: AppI18n.of(context).t(
            zhHans: '个性签名',
            zhHant: '個性簽名',
            en: 'Bio',
            ja: '自己紹介',
            ko: '상태 메시지',
          ),
          value: userInfo?.selfSignature?.isNotEmpty == true
              ? userInfo!.selfSignature!
              : AppI18n.of(context).t(
                  zhHans: '对方什么都没有写',
                  zhHant: '對方什麼都沒有寫',
                  en: 'No bio yet',
                  ja: '自己紹介はありません',
                  ko: '소개 없음',
                ),
          titleColor: titleColor,
          valueColor: valueColor,
          backgroundColor: cardBackgroundColor,
          dividerColor: dividerColor,
        ),
        const Spacer(),
        if (currentStatus == _ApplicationStatus.none &&
            applicationInfo.handleStatus == 0 &&
            canApprove) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: () {
                  unawaited(onAccept());
                  if (!embedded && Navigator.of(context).canPop()) {
                    Navigator.pop(context);
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryColor,
                  foregroundColor: Colors.white,
                  elevation: 0,
                ),
                child: Text(AppI18n.of(context).t(
                  zhHans: '同意',
                  zhHant: '同意',
                  en: 'Accept',
                  ja: '承認',
                  ko: '승인',
                )),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
            child: SizedBox(
              width: double.infinity,
              height: 50,
              child: OutlinedButton(
                onPressed: () {
                  unawaited(onReject());
                  if (!embedded && Navigator.of(context).canPop()) {
                    Navigator.pop(context);
                  }
                },
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: dividerColor),
                  backgroundColor: cardBackgroundColor,
                  foregroundColor: titleColor,
                ),
                child: Text(AppI18n.of(context).t(
                  zhHans: '拒绝',
                  zhHant: '拒絕',
                  en: 'Decline',
                  ja: '拒否',
                  ko: '거절',
                )),
              ),
            ),
          ),
        ] else
          const SizedBox(height: 24),
      ],
    );

    if (embedded) {
      return ColoredBox(
        color: pageBackgroundColor,
        child: content,
      );
    }

    return Scaffold(
      backgroundColor: pageBackgroundColor,
      appBar: AppBar(
        leading: IconButton(
          onPressed: () {
            Navigator.of(context).pop();
          },
          icon: Icon(
            Icons.arrow_back_ios_new_rounded,
            color: primaryColor,
            size: 22,
          ),
        ),
        backgroundColor: theme.appbarBgColor ?? cardBackgroundColor,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: const Text(""),
      ),
      body: content,
    );
  }
}
