// ignore_for_file: file_names

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tencent_cloud_chat_demo/src/i18n/app_i18n.dart';
import 'package:tencent_cloud_chat_demo/src/navigation/app_chat_route.dart';
import 'package:tencent_cloud_chat_demo/src/friend_request_audit_page.dart';
import 'package:tencent_cloud_chat_demo/src/friend_application_helper.dart';
import 'package:tencent_cloud_chat_demo/src/models/friend_request_record.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_conversation.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_conversation.dart';
import 'package:tencent_cloud_chat_uikit/business_logic/view_models/tui_friendship_view_model.dart';
import 'package:tencent_cloud_chat_uikit/data_services/services_locatar.dart';
import 'package:tencent_cloud_chat_uikit/tencent_cloud_chat_uikit.dart';
import 'package:tencent_cloud_chat_uikit/ui/utils/friend_add_source.dart';
import 'package:tencent_cloud_chat_uikit/ui/utils/screen_utils.dart';
import 'package:tencent_cloud_chat_uikit/ui/utils/time_ago.dart';
import 'package:tencent_cloud_chat_demo/src/provider/theme.dart';
import 'package:tencent_cloud_chat_demo/src/widgets/app_empty_state.dart';
import 'package:tencent_cloud_chat_demo/src/services/friend_request_notice_service.dart';
import 'package:tencent_cloud_chat_demo/src/widgets/app_dialog.dart';
import 'package:tencent_cloud_chat_demo/src/widgets/app_user_avatar.dart';
import 'package:tencent_cloud_chat_demo/utils/toast.dart';

class NewContact extends StatefulWidget {
  const NewContact({Key? key}) : super(key: key);

  @override
  State<NewContact> createState() => _NewContactState();
}

class _NewContactState extends State<NewContact> {
  final TUIFriendShipViewModel _friendshipViewModel =
      serviceLocator<TUIFriendShipViewModel>();
  List<FriendRequestRecord> _handledHistory = [];
  List<FriendRequestRecord> _incomingPending = [];
  List<FriendRequestRecord> _sentRequests = [];
  bool _loadingPendingRequests = false;
  bool _isEditing = false;
  bool _deleting = false;
  final Set<String> _selectedKeys = <String>{};

  @override
  void initState() {
    super.initState();
    _friendshipViewModel.loadData();
    _loadPendingRequests();
    _loadHandledHistory();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _friendshipViewModel.markFriendApplicationAsRead();
      FriendRequestNoticeService.instance.refreshPendingCount(markRead: true);
    });
  }


  Future<void> _loadPendingRequests() async {
    if (_loadingPendingRequests) {
      return;
    }
    setState(() => _loadingPendingRequests = true);
    try {
      final incoming = await FriendApplicationHelper.loadIncomingPending();
      final sent = await FriendApplicationHelper.loadSentRequests();
      if (!mounted) return;
      setState(() {
        _incomingPending = incoming;
        _sentRequests = sent;
      });
      await FriendRequestNoticeService.instance.refreshPendingCount(
        markRead: true,
      );
    } finally {
      if (mounted) {
        setState(() => _loadingPendingRequests = false);
      }
    }
  }

  Future<void> _loadHandledHistory() async {
    final records = await FriendApplicationHelper.loadHandledHistory();
    if (mounted) {
      setState(() => _handledHistory = records);
    }
  }

  String _recordSelectionKey(FriendRequestRecord record) {
    return 'f:${record.identityKey}';
  }

  List<FriendRequestRecord> _allDeletableRecords() {
    return [
      ..._pendingApplications(),
      ..._incomingHandledRecords(),
      ..._sentApplications(),
    ];
  }

  List<String> _allSelectionKeys() {
    return _allDeletableRecords().map(_recordSelectionKey).toList();
  }

  bool _isAllSelected() {
    final allKeys = _allSelectionKeys();
    return allKeys.isNotEmpty && _selectedKeys.length == allKeys.length;
  }

  List<FriendRequestRecord> _pendingApplications() {
    final list = List<FriendRequestRecord>.from(_incomingPending);
    list.sort(
      (a, b) => _normalizeToMilliseconds(b.addTime)
          .compareTo(_normalizeToMilliseconds(a.addTime)),
    );
    return list;
  }

  List<FriendRequestRecord> _sentApplications() {
    final list = List<FriendRequestRecord>.from(_sentRequests);
    list.sort(
      (a, b) => _normalizeToMilliseconds(b.displayTimestamp)
          .compareTo(_normalizeToMilliseconds(a.displayTimestamp)),
    );
    return list;
  }

  List<FriendRequestRecord> _incomingHandledRecords() {
    final records = _handledHistory
        .where((item) =>
            (item.status == 'accepted' || item.status == 'rejected') &&
            item.isIncoming)
        .toList();
    records.sort(
      (a, b) => _normalizeToMilliseconds(b.displayTimestamp)
          .compareTo(_normalizeToMilliseconds(a.displayTimestamp)),
    );
    return records;
  }

  bool _hasIncomingSection() {
    return _pendingApplications().isNotEmpty ||
        _incomingHandledRecords().isNotEmpty;
  }

  bool _hasListItems() {
    return _hasIncomingSection() || _sentApplications().isNotEmpty;
  }

  void _toggleEditMode() {
    setState(() {
      _isEditing = !_isEditing;
      if (!_isEditing) {
        _selectedKeys.clear();
      }
    });
  }

  void _toggleSelection(String key) {
    setState(() {
      if (_selectedKeys.contains(key)) {
        _selectedKeys.remove(key);
      } else {
        _selectedKeys.add(key);
      }
    });
  }

  void _toggleSelectAll() {
    final allKeys = _allSelectionKeys();
    setState(() {
      if (_isAllSelected()) {
        _selectedKeys.clear();
      } else {
        _selectedKeys
          ..clear()
          ..addAll(allKeys);
      }
    });
  }

  Future<bool> _confirmDeleteDialog({required int count}) async {
    final i18n = AppI18n.of(context);
    return AppDialog.confirm(
      title: i18n.t(
        zhHans: '删除记录',
        zhHant: '刪除記錄',
        en: 'Delete Records',
        ja: '記録を削除',
        ko: '기록 삭제',
      ),
      message: count > 1
          ? i18n.format(
              zhHans: '确定删除选中的 {count} 条记录吗？',
              zhHant: '確定刪除選中的 {count} 條記錄嗎？',
              en: 'Delete {count} selected records?',
              ja: '選択した{count}件の記録を削除しますか？',
              ko: '선택한 {count}개의 기록을 삭제하시겠습니까?',
              vars: {'count': '$count'},
            )
          : i18n.t(
              zhHans: '确定删除这条记录吗？',
              zhHant: '確定刪除這條記錄嗎？',
              en: 'Delete this record?',
              ja: 'この記録を削除しますか？',
              ko: '이 기록을 삭제하시겠습니까?',
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
  }

  Future<void> _deleteSelected() async {
    if (_selectedKeys.isEmpty || _deleting) {
      return;
    }
    final count = _selectedKeys.length;
    if (!await _confirmDeleteDialog(count: count)) {
      return;
    }
    if (!mounted) {
      return;
    }

    final selectedRecords = _allDeletableRecords()
        .where((item) => _selectedKeys.contains(_recordSelectionKey(item)))
        .toList();

    setState(() => _deleting = true);
    try {
      if (selectedRecords.isNotEmpty) {
        await FriendApplicationHelper.deleteListRecords(selectedRecords);
      }
      await _loadPendingRequests();
      await _loadHandledHistory();
      if (mounted) {
        setState(() {
          _selectedKeys.clear();
          _isEditing = false;
        });
        ToastUtils.toast(AppI18n.of(context).t(
          zhHans: '已删除',
          zhHant: '已刪除',
          en: 'Deleted',
          ja: '削除しました',
          ko: '삭제됨',
        ));
      }
    } catch (_) {
      if (mounted) {
        ToastUtils.toast(AppI18n.of(context).t(
          zhHans: '删除失败，请稍后重试',
          zhHant: '刪除失敗，請稍後重試',
          en: 'Delete failed. Please try again.',
          ja: '削除に失敗しました。しばらくして再試行してください。',
          ko: '삭제에 실패했습니다. 잠시 후 다시 시도해 주세요.',
        ));
      }
    } finally {
      if (mounted) {
        setState(() => _deleting = false);
      }
    }
  }

  Future<void> _deleteRecord(FriendRequestRecord record) async {
    if (_deleting) {
      return;
    }
    setState(() => _deleting = true);
    try {
      await FriendApplicationHelper.deleteListRecords([record]);
      await _loadPendingRequests();
      await _loadHandledHistory();
      if (mounted) {
        ToastUtils.toast(AppI18n.of(context).t(
          zhHans: '已删除',
          zhHant: '已刪除',
          en: 'Deleted',
          ja: '削除しました',
          ko: '삭제됨',
        ));
      }
    } catch (_) {
      if (mounted) {
        ToastUtils.toast(AppI18n.of(context).t(
          zhHans: '删除失败，请稍后重试',
          zhHant: '刪除失敗，請稍後重試',
          en: 'Delete failed. Please try again.',
          ja: '削除に失敗しました。しばらくして再試行してください。',
          ko: '삭제에 실패했습니다. 잠시 후 다시 시도해 주세요.',
        ));
      }
    } finally {
      if (mounted) {
        setState(() => _deleting = false);
      }
    }
  }

  Widget _buildSwipeDeleteBackground() {
    return Container(
      alignment: Alignment.centerRight,
      padding: const EdgeInsets.only(right: 24),
      color: const Color(0xFFE64340),
      child: const Icon(Icons.delete_outline, color: Colors.white),
    );
  }

  Widget _wrapDismissible({
    required Key key,
    required Widget child,
    required bool enabled,
    required Future<void> Function() onDelete,
  }) {
    if (!enabled) {
      return child;
    }
    return Dismissible(
      key: key,
      direction: DismissDirection.endToStart,
      dismissThresholds: const {
        DismissDirection.endToStart: 0.25,
      },
      background: _buildSwipeDeleteBackground(),
      confirmDismiss: (_) => _confirmDeleteDialog(count: 1),
      onDismissed: (_) => onDelete(),
      child: child,
    );
  }

  Future<void> _openFriendChat(
    BuildContext context,
    FriendRequestRecord record,
  ) async {
    final userID = record.userID.trim();
    if (userID.isEmpty) {
      return;
    }
    final conversationID = 'c2c_$userID';
    final sdk = TIMUIKitCore.getSDKInstance();
    final res = await sdk
        .getConversationManager()
        .getConversation(conversationID: conversationID);

    final conversation = (res.code == 0 && res.data != null)
        ? res.data!
        : V2TimConversation(
            conversationID: conversationID,
            userID: userID,
            type: 1,
            showName: _getShowNameFromRecord(record),
            faceUrl: record.faceUrl,
          );

    if (!mounted) {
      return;
    }
    await Navigator.push(
      context,
      appChatRoute(conversation),
    );
  }

  Future<void> _openAuditPage(
    BuildContext context,
    FriendRequestRecord application,
  ) async {
    final result = await Navigator.push<bool>(
      context,
      FriendRequestAuditPage.route(application),
    );
    if (!mounted) {
      return;
    }
    await _loadPendingRequests();
    await FriendRequestNoticeService.instance.refreshPendingCount();
    await _loadHandledHistory();
    if (result == true) {
      setState(() {});
    }
  }


  String _getShowName(FriendRequestRecord item) {
    return TencentUtils.checkString(item.nickname) ??
        TencentUtils.checkString(item.userID) ??
        '';
  }

  String _getShowNameFromRecord(FriendRequestRecord item) {
    final nickname = item.nickname.trim();
    if (nickname.isNotEmpty) {
      return nickname;
    }
    return item.userID;
  }

  int _normalizeToMilliseconds(int? timestamp) {
    if (timestamp == null || timestamp <= 0) {
      return 0;
    }
    return timestamp < 1000000000000 ? timestamp * 1000 : timestamp;
  }

  String _formatTimeLabel(int? timestamp) {
    final milliseconds = _normalizeToMilliseconds(timestamp);
    if (milliseconds == 0) {
      return '';
    }
    final dateTime = DateTime.fromMillisecondsSinceEpoch(milliseconds);
    final now = DateTime.now();
    if (now.difference(dateTime).inHours < 24 &&
        dateTime.day == now.day &&
        dateTime.month == now.month &&
        dateTime.year == now.year) {
      final seconds = milliseconds ~/ 1000;
      return TimeAgo().getTimeStringForChat(seconds) ??
          AppI18n.current.t(
            zhHans: '刚刚',
            zhHant: '剛剛',
            en: 'Just now',
            ja: 'たった今',
            ko: '방금',
          );
    }
    final month = dateTime.month.toString().padLeft(2, '0');
    final day = dateTime.day.toString().padLeft(2, '0');
    return '${dateTime.year}-$month-$day';
  }

  String _resolveVerifyWording(String? addWording, {String? fallbackName}) {
    final wording = FriendAddSource.stripFromWording(addWording);
    if (wording.isEmpty) {
      return '';
    }

    final resolvedName = fallbackName?.trim() ?? '';
    if (resolvedName.isEmpty) {
      return wording;
    }

    return wording
        .replaceAll('{name}', resolvedName)
        .replaceAll('{option1}', resolvedName)
        .replaceAll('name)', resolvedName)
        .replaceAll('（name）', resolvedName)
        .replaceAll('(name)', resolvedName);
  }

  String _buildVerifyMessage(String? addWording, {String? fallbackName}) {
    final i18n = AppI18n.current;
    final wording = _resolveVerifyWording(
      addWording,
      fallbackName: fallbackName,
    );
    if (wording.isEmpty) {
      return i18n.format(
        zhHans: '验证：{option1}',
        zhHant: '驗證：{option1}',
        en: 'Verification: {option1}',
        ja: '認証：{option1}',
        ko: '인증: {option1}',
        vars: {
          'option1': i18n.t(
            zhHans: '请求添加你为好友',
            zhHant: '請求新增你為好友',
            en: 'Wants to add you as a friend',
            ja: '友達追加をリクエスト',
            ko: '친구 추가 요청',
          ),
        },
      );
    }
    final iAmPrefix = i18n.t(
      zhHans: '我是',
      zhHant: '我是',
      en: 'I am',
      ja: '私は',
      ko: '저는',
    );
    final verifyPrefix = i18n.t(
      zhHans: '验证',
      zhHant: '驗證',
      en: 'Verification',
      ja: '認証',
      ko: '인증',
    );
    if (wording.startsWith(iAmPrefix) ||
        wording.startsWith('我是') ||
        wording.startsWith(verifyPrefix)) {
      return wording;
    }
    return i18n.format(
      zhHans: '验证：{option1}',
      zhHant: '驗證：{option1}',
      en: 'Verification: {option1}',
      ja: '認証：{option1}',
      ko: '인증: {option1}',
      vars: {'option1': wording},
    );
  }

  Widget _buildNameWithTimeRow({
    required String showName,
    required String timeLabel,
    required Color titleTextColor,
    required Color secondaryTextColor,
  }) {
    return Row(
      children: [
        Flexible(
          fit: FlexFit.loose,
          child: Text(
            showName,
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
    );
  }

  Widget _buildSectionHeader({
    required String title,
    required Color backgroundColor,
    required Color textColor,
  }) {
    return Container(
      width: double.infinity,
      color: backgroundColor,
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 14,
          color: textColor,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Widget _buildVerifyButton({
    required AppI18n i18n,
    required Color primaryColor,
    required VoidCallback? onTap,
    required bool loading,
  }) {
    return InkWell(
      onTap: loading ? null : onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        constraints: const BoxConstraints(minWidth: 56),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: primaryColor,
          borderRadius: BorderRadius.circular(8),
        ),
        alignment: Alignment.center,
        child: loading
            ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : Text(
                i18n.t(
                  zhHans: '验证',
                  zhHant: '驗證',
                  en: 'Verify',
                  ja: '確認',
                  ko: '확인',
                ),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
      ),
    );
  }

  Widget _buildStatusPill({
    required String label,
    required Color textColor,
    required Color backgroundColor,
  }) {
    return Container(
      constraints: const BoxConstraints(minWidth: 56),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(8),
      ),
      alignment: Alignment.center,
      child: Text(
        label,
        style: TextStyle(
          color: textColor,
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Widget _buildSelectionIndicator({
    required bool selected,
    required Color primaryColor,
    required Color secondaryTextColor,
  }) {
    return Icon(
      selected ? Icons.check_circle : Icons.radio_button_unchecked,
      color: selected ? primaryColor : secondaryTextColor,
      size: 22,
    );
  }

  String _directionLabel(AppI18n i18n, FriendRequestRecord record) {
    if (record.isOutgoing) {
      return i18n.t(
        zhHans: '你发起的申请',
        zhHant: '你發起的申請',
        en: 'Sent by you',
        ja: 'あなたが送信',
        ko: '내가 보냄',
      );
    }
    return i18n.t(
      zhHans: '对方发起的申请',
      zhHant: '對方發起的申請',
      en: 'Received from them',
      ja: '相手から受信',
      ko: '상대가 보냄',
    );
  }

  Widget _buildDirectionIcon({
    required AppI18n i18n,
    required FriendRequestRecord record,
    required Color primaryColor,
    required Color secondaryTextColor,
  }) {
    final isOutgoing = record.isOutgoing;
    return Tooltip(
      message: _directionLabel(i18n, record),
      child: Icon(
        isOutgoing ? Icons.north_east_rounded : Icons.south_west_rounded,
        size: 18,
        color: isOutgoing ? primaryColor : secondaryTextColor,
      ),
    );
  }

  Widget _buildPendingItem({
    required BuildContext context,
    required AppI18n i18n,
    required FriendRequestRecord application,
    required Color itemBackgroundColor,
    required Color titleTextColor,
    required Color secondaryTextColor,
    required Color dividerColor,
    required Color primaryColor,
    required bool isEditing,
    required bool selected,
    required VoidCallback? onSelect,
  }) {
    final showName = _getShowName(application);
    final faceUrl = application.faceUrl;
    final timeLabel = _formatTimeLabel(application.addTime);
    return Material(
      color: itemBackgroundColor,
      child: InkWell(
        onTap: isEditing ? onSelect : null,
        child: Container(
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(color: dividerColor, width: 0.6),
            ),
          ),
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              if (isEditing) ...[
                _buildSelectionIndicator(
                  selected: selected,
                  primaryColor: primaryColor,
                  secondaryTextColor: secondaryTextColor,
                ),
                const SizedBox(width: 12),
              ],
              SizedBox(
                width: 48,
                height: 48,
                child: AppUserAvatar(
                  faceUrl: faceUrl,
                  showName: showName,
                  size: 48,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildNameWithTimeRow(
                      showName: showName,
                      timeLabel: timeLabel,
                      titleTextColor: titleTextColor,
                      secondaryTextColor: secondaryTextColor,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _buildVerifyMessage(
                        application.addWording,
                        fallbackName: showName,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 14,
                        color: secondaryTextColor,
                      ),
                    ),
                  ],
                ),
              ),
              if (!isEditing) ...[
                const SizedBox(width: 12),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    _buildDirectionIcon(
                      i18n: i18n,
                      record: application,
                      primaryColor: primaryColor,
                      secondaryTextColor: secondaryTextColor,
                    ),
                    const SizedBox(height: 6),
                    _buildVerifyButton(
                      i18n: i18n,
                      primaryColor: primaryColor,
                      onTap: () => _openAuditPage(context, application),
                      loading: false,
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRecentItem({
    required AppI18n i18n,
    required FriendRequestRecord record,
    required Color itemBackgroundColor,
    required Color titleTextColor,
    required Color secondaryTextColor,
    required Color dividerColor,
    required Color pillBackgroundColor,
    required Color primaryColor,
    required bool isEditing,
    required bool selected,
    VoidCallback? onTap,
    VoidCallback? onSelect,
  }) {
    final showName = _getShowNameFromRecord(record);
    final timeLabel = _formatTimeLabel(record.displayTimestamp);
    final statusLabel = record.isPending
        ? (record.isOutgoing
            ? i18n.t(
                zhHans: '等待验证',
                zhHant: '等待驗證',
                en: 'Pending',
                ja: '保留中',
                ko: '대기 중',
              )
            : i18n.t(
                zhHans: '待处理',
                zhHant: '待處理',
                en: 'Pending',
                ja: '保留中',
                ko: '대기 중',
              ))
        : record.status == 'rejected'
            ? i18n.t(
                zhHans: '已拒绝',
                zhHant: '已拒絕',
                en: 'Declined',
                ja: '拒否済み',
                ko: '거절됨',
              )
            : i18n.t(
                zhHans: '已同意',
                zhHant: '已同意',
                en: 'Accepted',
                ja: '承認済み',
                ko: '승인됨',
              );

    final content = Container(
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: dividerColor, width: 0.6),
        ),
      ),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          if (isEditing) ...[
            _buildSelectionIndicator(
              selected: selected,
              primaryColor: primaryColor,
              secondaryTextColor: secondaryTextColor,
            ),
            const SizedBox(width: 12),
          ],
          SizedBox(
            width: 48,
            height: 48,
            child: AppUserAvatar(
              faceUrl: record.faceUrl,
              showName: showName,
              size: 48,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildNameWithTimeRow(
                  showName: showName,
                  timeLabel: timeLabel,
                  titleTextColor: titleTextColor,
                  secondaryTextColor: secondaryTextColor,
                ),
                const SizedBox(height: 6),
                Text(
                  _buildVerifyMessage(
                    record.addWording,
                    fallbackName: _getShowNameFromRecord(record),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 14,
                    color: secondaryTextColor,
                  ),
                ),
              ],
            ),
          ),
          if (!isEditing) ...[
            const SizedBox(width: 12),
            Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                _buildDirectionIcon(
                  i18n: i18n,
                  record: record,
                  primaryColor: primaryColor,
                  secondaryTextColor: secondaryTextColor,
                ),
                const SizedBox(height: 6),
                _buildStatusPill(
                  label: statusLabel,
                  textColor: secondaryTextColor,
                  backgroundColor: pillBackgroundColor,
                ),
              ],
            ),
          ],
        ],
      ),
    );

    return Material(
      color: itemBackgroundColor,
      child: isEditing
          ? InkWell(
              onTap: onSelect,
              child: content,
            )
          : onTap == null
              ? content
              : InkWell(
                  onTap: onTap,
                  child: content,
                ),
    );
  }

  Widget _buildBody(BuildContext context) {
    final i18n = AppI18n.of(context);
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
    final sectionHeaderBackground = isDarkBackground
        ? (theme.conversationItemPinedBgColor ?? const Color(0xFF1A1A1A))
        : const Color(0xFFF0F1F3);
    final titleTextColor = theme.darkTextColor ?? Colors.black;
    final secondaryTextColor = theme.weakTextColor ?? const Color(0xFF999999);
    final sectionHeaderTextColor = secondaryTextColor;
    final dividerColor = theme.weakDividerColor ?? const Color(0xFFE5E6E9);
    final primaryColor = theme.primaryColor ?? const Color(0xFF1E90FF);
    final pillBackgroundColor =
        theme.selectPanelBgColor ?? const Color(0xFFF1F2F6);

    return AnimatedBuilder(
      animation: _friendshipViewModel,
      builder: (context, _) {
        final pendingApplications = _pendingApplications();
        final sentApplications = _sentApplications();
        final recentRecords = _incomingHandledRecords();

        if (!_hasIncomingSection() && sentApplications.isEmpty) {
          if (_isEditing) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (!mounted) return;
              setState(() {
                _isEditing = false;
                _selectedKeys.clear();
              });
            });
          }
          return AppEmptyState(
              message: i18n.t(
            zhHans: '暂无新联系人',
            zhHant: '暫無新聯絡人',
            en: 'No new contacts',
            ja: '新しい連絡先はありません',
            ko: '새 연락처가 없습니다',
          ));
        }

        final children = <Widget>[];

        if (_hasIncomingSection()) {
          children.add(
            _buildSectionHeader(
              title: i18n.t(
                zhHans: '对方添加我',
                zhHant: '對方添加我',
                en: 'Requests Received',
                ja: '相手からの申請',
                ko: '받은 요청',
              ),
              backgroundColor: sectionHeaderBackground,
              textColor: sectionHeaderTextColor,
            ),
          );
          for (final application in pendingApplications) {
            final selectionKey = _recordSelectionKey(application);
            children.add(
              _wrapDismissible(
                key: ValueKey<String>(selectionKey),
                enabled: !_isEditing && !_deleting,
                onDelete: () => _deleteRecord(application),
                child: _buildPendingItem(
                  context: context,
                  i18n: i18n,
                  application: application,
                  itemBackgroundColor: listBackgroundColor,
                  titleTextColor: titleTextColor,
                  secondaryTextColor: secondaryTextColor,
                  dividerColor: dividerColor,
                  primaryColor: primaryColor,
                  isEditing: _isEditing,
                  selected: _selectedKeys.contains(selectionKey),
                  onSelect: () => _toggleSelection(selectionKey),
                ),
              ),
            );
          }
          for (final record in recentRecords) {
            final selectionKey = _recordSelectionKey(record);
            children.add(
              _wrapDismissible(
                key: ValueKey<String>(selectionKey),
                enabled: !_isEditing && !_deleting,
                onDelete: () => _deleteRecord(record),
                child: _buildRecentItem(
                  i18n: i18n,
                  record: record,
                  itemBackgroundColor: listBackgroundColor,
                  titleTextColor: titleTextColor,
                  secondaryTextColor: secondaryTextColor,
                  dividerColor: dividerColor,
                  pillBackgroundColor: pillBackgroundColor,
                  primaryColor: primaryColor,
                  isEditing: _isEditing,
                  selected: _selectedKeys.contains(selectionKey),
                  onSelect: () => _toggleSelection(selectionKey),
                  onTap: _isEditing
                      ? null
                      : record.status == 'accepted'
                          ? () => _openFriendChat(context, record)
                          : null,
                ),
              ),
            );
          }
        }

        if (sentApplications.isNotEmpty) {
          children.add(
            _buildSectionHeader(
              title: i18n.t(
                zhHans: '我添加对方',
                zhHant: '我添加對方',
                en: 'Requests Sent',
                ja: '送信した申請',
                ko: '보낸 요청',
              ),
              backgroundColor: sectionHeaderBackground,
              textColor: sectionHeaderTextColor,
            ),
          );
          for (final application in sentApplications) {
            final selectionKey = _recordSelectionKey(application);
            children.add(
              _wrapDismissible(
                key: ValueKey<String>(selectionKey),
                enabled: !_isEditing && !_deleting,
                onDelete: () => _deleteRecord(application),
                child: _buildRecentItem(
                  i18n: i18n,
                  record: application,
                  itemBackgroundColor: listBackgroundColor,
                  titleTextColor: titleTextColor,
                  secondaryTextColor: secondaryTextColor,
                  dividerColor: dividerColor,
                  pillBackgroundColor: pillBackgroundColor,
                  primaryColor: primaryColor,
                  isEditing: _isEditing,
                  selected: _selectedKeys.contains(selectionKey),
                  onSelect: () => _toggleSelection(selectionKey),
                  onTap: _isEditing
                      ? null
                      : application.status == 'accepted'
                          ? () => _openFriendChat(context, application)
                          : null,
                ),
              ),
            );
          }
        }

        return Container(
          color: pageBackgroundColor,
          child: ListView(
            children: children,
          ),
        );
      },
    );
  }

  Widget? _buildEditBottomBar(BuildContext context) {
    if (!_isEditing) {
      return null;
    }
    final i18n = AppI18n.of(context);
    final theme = Provider.of<DefaultThemeData>(context).theme;
    final dividerColor = theme.weakDividerColor ?? const Color(0xFFE5E6E9);
    final listBackgroundColor = theme.conversationItemBgColor ?? Colors.white;

    return SafeArea(
      top: false,
      child: Container(
        decoration: BoxDecoration(
          color: listBackgroundColor,
          border: Border(
            top: BorderSide(color: dividerColor, width: 0.6),
          ),
        ),
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
        child: SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: _selectedKeys.isEmpty || _deleting
                ? null
                : _deleteSelected,
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFE64340),
              disabledBackgroundColor: dividerColor,
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
            child: _deleting
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : Text(
                    _selectedKeys.isEmpty
                        ? i18n.t(
                            zhHans: '删除',
                            zhHant: '刪除',
                            en: 'Delete',
                            ja: '削除',
                            ko: '삭제',
                          )
                        : i18n.format(
                            zhHans: '删除({count})',
                            zhHant: '刪除({count})',
                            en: 'Delete ({count})',
                            ja: '削除({count})',
                            ko: '삭제({count})',
                            vars: {'count': '${_selectedKeys.length}'},
                          ),
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
          ),
        ),
      ),
    );
  }

  PreferredSizeWidget? _buildAppBar(BuildContext context) {
    final i18n = AppI18n.of(context);
    final theme = Provider.of<DefaultThemeData>(context).theme;
    final appBarBackgroundColor = theme.appbarBgColor ?? Colors.white;
    final appBarTextColor =
        theme.appbarTextColor ?? theme.darkTextColor ?? Colors.black;
    final primaryColor = theme.primaryColor ?? const Color(0xFF1E90FF);
    final hasEditableItems = _hasListItems();

    return AppBar(
      leading: BackButton(color: primaryColor),
      title: Text(
        i18n.t(
          zhHans: '新的朋友',
          zhHant: '新的朋友',
          en: 'New Friends',
          ja: '新しい友達',
          ko: '새 친구',
        ),
        style: TextStyle(
          color: appBarTextColor,
          fontSize: 18,
          fontWeight: FontWeight.w700,
        ),
      ),
      centerTitle: true,
      backgroundColor: appBarBackgroundColor,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      actions: hasEditableItems
          ? (_isEditing
              ? [
                  TextButton(
                    onPressed: _toggleSelectAll,
                    child: Text(
                      _isAllSelected()
                          ? i18n.t(
                              zhHans: '取消全选',
                              zhHant: '取消全選',
                              en: 'Deselect All',
                              ja: '全選択解除',
                              ko: '전체 선택 해제',
                            )
                          : i18n.t(
                              zhHans: '全选',
                              zhHant: '全選',
                              en: 'Select All',
                              ja: '全選択',
                              ko: '전체 선택',
                            ),
                      style: TextStyle(color: primaryColor),
                    ),
                  ),
                  TextButton(
                    onPressed: _toggleEditMode,
                    child: Text(
                      i18n.t(
                        zhHans: '完成',
                        zhHant: '完成',
                        en: 'Done',
                        ja: '完了',
                        ko: '완료',
                      ),
                      style: TextStyle(color: primaryColor),
                    ),
                  ),
                ]
              : [
                  TextButton(
                    onPressed: _toggleEditMode,
                    child: Text(
                      i18n.t(
                        zhHans: '编辑',
                        zhHant: '編輯',
                        en: 'Edit',
                        ja: '編集',
                        ko: '편집',
                      ),
                      style: TextStyle(color: primaryColor),
                    ),
                  ),
                ])
          : null,
    );
  }

  Widget _buildPageScaffold(BuildContext context, {required bool showAppBar}) {
    return Scaffold(
      backgroundColor:
          Provider.of<DefaultThemeData>(context).theme.weakBackgroundColor,
      appBar: showAppBar ? _buildAppBar(context) : null,
      body: _buildBody(context),
      bottomNavigationBar: _buildEditBottomBar(context),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _friendshipViewModel,
      builder: (context, _) {
        return TUIKitScreenUtils.getDeviceWidget(
          context: context,
          desktopWidget: _buildPageScaffold(context, showAppBar: _hasListItems()),
          defaultWidget: _buildPageScaffold(context, showAppBar: true),
        );
      },
    );
  }
}
