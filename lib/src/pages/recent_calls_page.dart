import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:tencent_cloud_chat_demo/src/api/call_record_api.dart';
import 'package:tencent_cloud_chat_demo/src/i18n/app_i18n.dart';
import 'package:tencent_cloud_chat_demo/src/services/call_recent_refresh_bus.dart';
import 'package:tencent_cloud_chat_demo/src/pages/contact_card_user_picker_page.dart';
import 'package:tencent_cloud_chat_demo/utils/dio_error_message.dart';
import 'package:tencent_cloud_chat_demo/utils/media_url_resolver.dart';
import 'package:tencent_cloud_chat_demo/utils/navigation_routes.dart';
import 'package:tencent_cloud_chat_demo/src/theme/app_colors.dart';
import 'package:tencent_cloud_chat_demo/src/widgets/app_empty_state.dart';
import 'package:tencent_cloud_chat_demo/src/widgets/app_dialog.dart';
import 'package:tencent_cloud_chat_demo/src/user_profile.dart';
import 'package:tencent_cloud_chat_demo/src/services/call_launcher.dart';
import 'package:tencent_cloud_chat_sdk/tencent_im_sdk_plugin.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_user_full_info.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_user_full_info.dart';
import 'package:tencent_cloud_chat_uikit/ui/widgets/avatar.dart';
import 'package:adaptive_action_sheet/adaptive_action_sheet.dart';

enum _RecentCallTab { all, missed }

const double _kRecentCallRowMinHeight = 72;
const double _kRecentCallNameFontSize = 16;
const double _kRecentCallMetaFontSize = 13;
const double _kRecentCallTimeFontSize = 13;
const double _kRecentCallSectionRadius = 16;

class RecentCallsPage extends StatefulWidget {
  const RecentCallsPage({super.key});

  @override
  State<RecentCallsPage> createState() => _RecentCallsPageState();
}

class _RecentCallsPageState extends State<RecentCallsPage> {
  _RecentCallTab _tab = _RecentCallTab.all;
  bool _editing = false;
  bool _loading = true;
  bool _deleting = false;
  String? _error;
  List<CallRecordItem> _records = <CallRecordItem>[];
  final Map<String, V2TimUserFullInfo> _userInfoMap =
      <String, V2TimUserFullInfo>{};

  @override
  void initState() {
    super.initState();
    CallRecentRefreshBus.instance.revision.addListener(_onCallRecentRefresh);
    _loadCalls();
  }

  @override
  void dispose() {
    CallRecentRefreshBus.instance.revision.removeListener(_onCallRecentRefresh);
    super.dispose();
  }

  void _onCallRecentRefresh() {
    final event = CallRecentRefreshBus.instance.lastRefresh.value;
    if (event == null || !mounted) {
      return;
    }
    if (event.action == 'added' && event.item != null) {
      _applyAddedRecord(event.item!);
      return;
    }
    _loadCalls();
  }

  bool _matchesCurrentTab(CallRecordItem item) {
    if (_tab == _RecentCallTab.all) {
      return true;
    }
    return item.result == 'missed';
  }

  void _applyAddedRecord(CallRecordItem item) {
    if (!_matchesCurrentTab(item)) {
      setState(() {
        _records.removeWhere((e) => e.callId == item.callId);
      });
      return;
    }
    setState(() {
      _records.removeWhere((e) => e.callId == item.callId);
      _records.insert(0, item);
      _loading = false;
      _error = null;
    });
    _hydratePeerProfiles([item]);
  }

  Future<void> _loadCalls() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final result = await CallRecordApi.instance
          .fetchRecent(
            filter: _tab == _RecentCallTab.missed
                ? CallRecordFilter.missed
                : CallRecordFilter.all,
          )
          .timeout(const Duration(seconds: 12));
      if (!mounted) return;
      setState(() {
        _records = result.items;
        _loading = false;
      });
      _hydratePeerProfiles(result.items);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = DioErrorMessage.forApp(e);
        _loading = false;
      });
    }
  }

  Future<void> _deleteOne(CallRecordItem item) async {
    if (_deleting || item.callId.isEmpty) return;
    final i18n = AppI18n.of(context);
    final confirmed = await AppDialog.confirm(
      title: i18n.t(
        zhHans: '删除记录',
        zhHant: '刪除記錄',
        en: 'Delete Record',
        ja: '履歴を削除',
        ko: '기록 삭제',
      ),
      message: i18n.t(
        zhHans: '确定删除这条通话记录吗？',
        zhHant: '確定刪除這筆通話記錄嗎？',
        en: 'Are you sure you want to delete this call record?',
        ja: 'この通話履歴を削除しますか？',
        ko: '이 통화 기록을 삭제하시겠습니까?',
      ),
      cancelText: i18n.t(
        zhHans: '取消',
        zhHant: '取消',
        en: 'Cancel',
        ja: 'キャンセル',
        ko: '취소',
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
    if (confirmed != true) return;

    setState(() => _deleting = true);
    try {
      await CallRecordApi.instance.deleteOne(item.callId);
      if (!mounted) return;
      setState(() {
        _records.removeWhere((e) => e.callId == item.callId);
      });
    } finally {
      if (mounted) setState(() => _deleting = false);
    }
  }

  Future<void> _deleteCurrentFilter() async {
    if (_deleting) return;
    final filter = _tab == _RecentCallTab.missed
        ? CallRecordFilter.missed
        : CallRecordFilter.all;
    final i18n = AppI18n.of(context);
    final label = filter == CallRecordFilter.missed
        ? i18n.t(
            zhHans: '未接记录',
            zhHant: '未接記錄',
            en: 'missed call records',
            ja: '不在着履歴',
            ko: '부재중 기록',
          )
        : i18n.t(
            zhHans: '全部记录',
            zhHant: '全部記錄',
            en: 'all call records',
            ja: 'すべての履歴',
            ko: '전체 기록',
          );
    final confirmed = await AppDialog.confirm(
      title: i18n.t(
        zhHans: '删除记录',
        zhHant: '刪除記錄',
        en: 'Delete Record',
        ja: '履歴を削除',
        ko: '기록 삭제',
      ),
      message: i18n.format(
        zhHans: '确定删除当前{label}吗？',
        zhHant: '確定刪除目前的{label}嗎？',
        en: 'Are you sure you want to delete the current {label}?',
        ja: '現在の{label}を削除しますか？',
        ko: '현재 {label}을(를) 삭제하시겠습니까?',
        vars: {'label': label},
      ),
      cancelText: i18n.t(
        zhHans: '取消',
        zhHant: '取消',
        en: 'Cancel',
        ja: 'キャンセル',
        ko: '취소',
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
    if (confirmed != true) return;

    setState(() => _deleting = true);
    try {
      await CallRecordApi.instance.deleteBatch(filter);
      if (!mounted) return;
      setState(() {
        _records = <CallRecordItem>[];
        _editing = false;
      });
    } finally {
      if (mounted) setState(() => _deleting = false);
    }
  }

  String _tabLabel(_RecentCallTab tab) {
    final i18n = AppI18n.of(context);
    switch (tab) {
      case _RecentCallTab.missed:
        return i18n.t(
          zhHans: '未接',
          zhHant: '未接',
          en: 'Missed',
          ja: '不在着',
          ko: '부재중',
        );
      case _RecentCallTab.all:
        return i18n.t(
          zhHans: '全部',
          zhHant: '全部',
          en: 'All',
          ja: 'すべて',
          ko: '전체',
        );
    }
  }

  String _resultText(CallRecordItem item) {
    final i18n = AppI18n.of(context);
    if (item.result == 'answered') {
      if (item.durationSec > 0) {
        return i18n.format(
          zhHans: '接听，{sec}秒',
          zhHant: '接聽，{sec}秒',
          en: 'Answered, {sec}s',
          ja: '応答済み、{sec}秒',
          ko: '응답, {sec}초',
          vars: {'sec': item.durationSec.toString()},
        );
      }
      return i18n.t(
        zhHans: '接听',
        zhHant: '接聽',
        en: 'Answered',
        ja: '応答済み',
        ko: '응답',
      );
    }
    if (item.result == 'missed') {
      return i18n.t(
        zhHans: '未接',
        zhHant: '未接',
        en: 'Missed',
        ja: '不在着',
        ko: '부재중',
      );
    }
    if (item.result == 'rejected') {
      return i18n.t(
        zhHans: '拒接',
        zhHant: '拒接',
        en: 'Declined',
        ja: '拒否',
        ko: '거절됨',
      );
    }
    if (item.result == 'canceled') {
      return i18n.t(
        zhHans: '已取消',
        zhHant: '已取消',
        en: 'Cancelled',
        ja: 'キャンセル済み',
        ko: '취소됨',
      );
    }
    if (item.result == 'busy') {
      return i18n.t(
        zhHans: '忙线未接',
        zhHant: '忙線未接',
        en: 'Busy',
        ja: '話し中',
        ko: '통화 중',
      );
    }
    if (item.direction == 'outgoing') {
      return i18n.t(
        zhHans: '拨出',
        zhHant: '撥出',
        en: 'Outgoing',
        ja: '発信',
        ko: '발신',
      );
    }
    return i18n.t(
      zhHans: '通话',
      zhHant: '通話',
      en: 'Call',
      ja: '通話',
      ko: '통화',
    );
  }

  Color _nameColor(CallRecordItem item, bool dark) {
    return item.result == 'missed'
        ? const Color(0xFFE64340)
        : AppColors.text(dark: dark);
  }

  Widget _callMediaTypeIcon({required bool isVideo, required bool dark}) {
    final color = AppColors.subText(dark: dark);
    return Image.asset(
      isVideo ? 'assets/img/video.webp' : 'assets/img/call.png',
      width: isVideo ? 19 : 18,
      height: isVideo ? 19 : 18,
      fit: BoxFit.contain,
      color: color,
      colorBlendMode: BlendMode.srcIn,
      gaplessPlayback: true,
    );
  }

  String _timeText(CallRecordItem item) {
    if (item.occurredAt <= 0) return '';
    final date = DateTime.fromMillisecondsSinceEpoch(item.occurredAt);
    final now = DateTime.now();
    final sameYear = date.year == now.year;
    final hh = date.hour.toString().padLeft(2, '0');
    final mm = date.minute.toString().padLeft(2, '0');
    final hm = '$hh:$mm';
    if (sameYear) {
      return hm;
    }
    return '${date.year}/${date.month}/${date.day}';
  }

  Future<void> _startCall(CallRecordItem item) async {
    if (_editing) return;
    final userId = item.peerUserId.trim();
    if (userId.isEmpty) return;
    await _showCallTypeSheet(userId);
  }

  Future<void> _startNewCall() async {
    if (_editing) return;
    final userId = await pickContactCardUser(context);
    if (!mounted || userId == null || userId.trim().isEmpty) return;
    await _showCallTypeSheet(userId.trim());
  }

  Future<void> _showCallTypeSheet(String userId) async {
    if (userId.isEmpty) return;
    final i18n = AppI18n.of(context);
    showAdaptiveActionSheet(
      context: context,
      actions: <BottomSheetAction>[
        BottomSheetAction(
          title: Text(
            i18n.t(
              zhHans: '语音通话',
              zhHant: '語音通話',
              en: 'Voice Call',
              ja: '音声通話',
              ko: '음성 통화',
            ),
            style: TextStyle(
              fontSize: 18,
              color: AppColors.primaryBlue,
            ),
          ),
          onPressed: (_) async {
            Navigator.of(context, rootNavigator: true).pop();
            await CallLauncher.startBridgeC2C(
              context,
              userId: userId,
              video: false,
            );
          },
        ),
        BottomSheetAction(
          title: Text(
            i18n.t(
              zhHans: '视频通话',
              zhHant: '視訊通話',
              en: 'Video Call',
              ja: 'ビデオ通話',
              ko: '영상 통화',
            ),
            style: TextStyle(
              fontSize: 18,
              color: AppColors.primaryBlue,
            ),
          ),
          onPressed: (_) async {
            Navigator.of(context, rootNavigator: true).pop();
            await CallLauncher.startBridgeC2C(
              context,
              userId: userId,
              video: true,
            );
          },
        ),
      ],
      cancelAction: CancelAction(
        title: Text(
          i18n.t(
            zhHans: '取消',
            zhHant: '取消',
            en: 'Cancel',
            ja: 'キャンセル',
            ko: '취소',
          ),
          style: const TextStyle(fontSize: 18),
        ),
      ),
    );
  }

  Future<void> _hydratePeerProfiles(List<CallRecordItem> items) async {
    final ids = items
        .map((e) => e.peerUserId.trim())
        .where((e) => e.isNotEmpty && !_userInfoMap.containsKey(e))
        .toSet()
        .toList();
    if (ids.isEmpty) return;
    final res =
        await TencentImSDKPlugin.v2TIMManager.getUsersInfo(userIDList: ids);
    final data = res.data;
    if (res.code != 0 || data == null || data.isEmpty) return;
    if (!mounted) return;
    setState(() {
      for (final user in data) {
        final userId = user.userID?.trim() ?? '';
        if (userId.isNotEmpty) {
          _userInfoMap[userId] = user;
        }
      }
    });
  }

  String _displayPeerName(CallRecordItem item) {
    final userId = item.peerUserId.trim();
    final userInfo = userId.isEmpty ? null : _userInfoMap[userId];
    final nick = userInfo?.nickName?.trim() ?? '';
    if (nick.isNotEmpty) return nick;
    if (item.peerName.trim().isNotEmpty) return item.peerName.trim();
    return userId;
  }

  String _displayPeerAvatar(CallRecordItem item) {
    final userId = item.peerUserId.trim();
    final userInfo = userId.isEmpty ? null : _userInfoMap[userId];
    final faceUrl = userInfo?.faceUrl?.trim() ?? '';
    if (faceUrl.isNotEmpty) {
      return MediaUrlResolver.resolve(faceUrl) ?? faceUrl;
    }
    return MediaUrlResolver.resolve(item.peerAvatar) ?? item.peerAvatar;
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final i18n = AppI18n.of(context);

    return Scaffold(
      backgroundColor: AppColors.background(dark: dark),
      appBar: AppBar(
        elevation: 0,
        centerTitle: true,
        backgroundColor: AppColors.card(dark: dark),
        surfaceTintColor: Colors.transparent,
        leadingWidth: _editing ? 100 : null,
        leading: _editing
            ? TextButton(
                onPressed:
                    _records.isEmpty || _deleting ? null : _deleteCurrentFilter,
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.only(left: 14, right: 6),
                  alignment: Alignment.centerLeft,
                ),
                child: Text(
                  _tab == _RecentCallTab.missed
                      ? i18n.t(
                          zhHans: '删除未接',
                          zhHant: '刪除未接',
                          en: 'Delete Missed',
                          ja: '不在着を削除',
                          ko: '부재중 삭제',
                        )
                      : i18n.t(
                          zhHans: '删除全部',
                          zhHant: '刪除全部',
                          en: 'Delete All',
                          ja: 'すべて削除',
                          ko: '전체 삭제',
                        ),
                  style: TextStyle(
                    color: _records.isEmpty || _deleting
                        ? AppColors.subText(dark: dark)
                        : const Color(0xFFE64340),
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              )
            : IconButton(
                icon: const Icon(Icons.arrow_back_ios_new_rounded),
                color: AppColors.primaryBlue,
                onPressed: () => Navigator.of(context).pop(),
              ),
        title: Container(
          width: 164,
          height: 34,
          padding: const EdgeInsets.all(2),
          decoration: BoxDecoration(
            color: dark ? const Color(0xFF2A2D33) : const Color(0xFFF1F2F5),
            borderRadius: BorderRadius.circular(17),
          ),
          child: Row(
            children: _RecentCallTab.values.map((tab) {
              final selected = tab == _tab;
              return Expanded(
                child: GestureDetector(
                  onTap: () {
                    setState(() {
                      _tab = tab;
                    });
                    _loadCalls();
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: selected
                          ? AppColors.card(dark: dark)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(15),
                      boxShadow: selected
                          ? [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.06),
                                blurRadius: 6,
                                offset: const Offset(0, 1),
                              ),
                            ]
                          : null,
                    ),
                    child: Text(
                      _tabLabel(tab),
                      style: TextStyle(
                        color: AppColors.text(dark: dark),
                        fontSize: 15,
                        fontWeight:
                            selected ? FontWeight.w600 : FontWeight.w500,
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
        actions: [
          SizedBox(
            width: 68,
            child: TextButton(
              onPressed: _records.isEmpty
                  ? null
                  : () {
                      setState(() {
                        _editing = !_editing;
                      });
                    },
              child: Text(
                _editing
                    ? i18n.t(
                        zhHans: '完成',
                        zhHant: '完成',
                        en: 'Done',
                        ja: '完了',
                        ko: '완료',
                      )
                    : i18n.t(
                        zhHans: '编辑',
                        zhHant: '編輯',
                        en: 'Edit',
                        ja: '編集',
                        ko: '편집',
                      ),
                style: TextStyle(
                  color: _records.isEmpty
                      ? AppColors.subText(dark: dark)
                      : AppColors.primaryBlue,
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: Column(
        children: [
          Container(
            margin: const EdgeInsets.fromLTRB(16, 12, 16, 10),
            decoration: BoxDecoration(
              color: AppColors.card(dark: dark),
              borderRadius: BorderRadius.circular(_kRecentCallSectionRadius),
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: _startNewCall,
                borderRadius: BorderRadius.circular(_kRecentCallSectionRadius),
                child: Container(
                  constraints: const BoxConstraints(minHeight: 56),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Row(
                    children: [
                      SvgPicture.asset(
                        'assets/img/start_new_call.svg',
                        width: 24,
                        height: 24,
                        fit: BoxFit.contain,
                        colorFilter: const ColorFilter.mode(
                          AppColors.primaryBlue,
                          BlendMode.srcIn,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Text(
                          i18n.t(
                            zhHans: '开始新通话',
                            zhHant: '開始新通話',
                            en: 'Start a New Call',
                            ja: '新しい通話を開始',
                            ko: '새 통화 시작',
                          ),
                          style: TextStyle(
                            color: AppColors.primaryBlue,
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 32),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                _error!,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: AppColors.subText(dark: dark),
                                  fontSize: 14,
                                ),
                              ),
                              const SizedBox(height: 12),
                              TextButton(
                                onPressed: _loadCalls,
                                child: Text(i18n.t(
                                  zhHans: '重试',
                                  zhHant: '重試',
                                  en: 'Retry',
                                  ja: '再試行',
                                  ko: '다시 시도',
                                )),
                              ),
                            ],
                          ),
                        ),
                      )
                    : _records.isEmpty
                        ? AppEmptyState(
                            message: _tab == _RecentCallTab.missed
                                ? i18n.t(
                                    zhHans: '暂无未接记录',
                                    zhHant: '暫無未接記錄',
                                    en: 'No missed calls',
                                    ja: '不在着履歴はありません',
                                    ko: '부재중 기록이 없습니다',
                                  )
                                : i18n.t(
                                    zhHans: '暂无通话记录',
                                    zhHant: '暫無通話記錄',
                                    en: 'No call records',
                                    ja: '通話履歴はありません',
                                    ko: '통화 기록이 없습니다',
                                  ),
                          )
                        : ListView.separated(
                            itemCount: _records.length,
                            separatorBuilder: (_, __) => Divider(
                              height: 1,
                              indent: _editing ? 122 : 88,
                              endIndent: 16,
                              color: AppColors.line(dark: dark),
                            ),
                            itemBuilder: (context, index) {
                              final item = _records[index];
                              final isVideo =
                                  item.mediaType.toLowerCase() == 'video';
                              return InkWell(
                                onTap: _editing ? null : () => _startCall(item),
                                child: Container(
                                  color: AppColors.card(dark: dark),
                                  constraints: const BoxConstraints(
                                    minHeight: _kRecentCallRowMinHeight,
                                  ),
                                  padding:
                                      const EdgeInsets.fromLTRB(16, 10, 16, 10),
                                  child: Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.center,
                                    children: [
                                      AnimatedSwitcher(
                                        duration:
                                            const Duration(milliseconds: 180),
                                        child: _editing
                                            ? Padding(
                                                key: const ValueKey('delete'),
                                                padding: const EdgeInsets.only(
                                                    right: 12),
                                                child: GestureDetector(
                                                  onTap: _deleting
                                                      ? null
                                                      : () => _deleteOne(item),
                                                  child: Container(
                                                    width: 20,
                                                    height: 20,
                                                    decoration:
                                                        const BoxDecoration(
                                                      color: Color(0xFFE64340),
                                                      shape: BoxShape.circle,
                                                    ),
                                                    alignment: Alignment.center,
                                                    child: const Icon(
                                                      Icons.remove_rounded,
                                                      size: 14,
                                                      color: Colors.white,
                                                    ),
                                                  ),
                                                ),
                                              )
                                            : const SizedBox(
                                                key: ValueKey('empty'),
                                                width: 0,
                                              ),
                                      ),
                                      SizedBox(
                                        width: 20,
                                        child: Center(
                                          child: _callMediaTypeIcon(
                                            isVideo: isVideo,
                                            dark: dark,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      SizedBox(
                                        width: 42,
                                        height: 42,
                                        child: Avatar(
                                          faceUrl: _displayPeerAvatar(item),
                                          showName: _displayPeerName(item),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            Text(
                                              _displayPeerName(item),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: TextStyle(
                                                color: _nameColor(item, dark),
                                                fontSize:
                                                    _kRecentCallNameFontSize,
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                            const SizedBox(height: 3),
                                            Text(
                                              _resultText(item),
                                              style: TextStyle(
                                                color: item.result == 'missed'
                                                    ? const Color(0xFFE64340)
                                                    : AppColors.subText(
                                                        dark: dark),
                                                fontSize:
                                                    _kRecentCallMetaFontSize,
                                                height: 1.25,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.end,
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          Text(
                                            _timeText(item),
                                            style: TextStyle(
                                              color:
                                                  AppColors.subText(dark: dark),
                                              fontSize:
                                                  _kRecentCallTimeFontSize,
                                            ),
                                          ),
                                          const SizedBox(height: 6),
                                          GestureDetector(
                                            onTap: item.peerUserId
                                                    .trim()
                                                    .isEmpty
                                                ? null
                                                : () {
                                                    Navigator.push(
                                                      context,
                                                      NavigationRoutes
                                                          .cupertino(
                                                        builder: (_) =>
                                                            UserProfile(
                                                          userID:
                                                              item.peerUserId,
                                                        ),
                                                      ),
                                                    );
                                                  },
                                            child: Icon(
                                              Icons.info_outline_rounded,
                                              color:
                                                  item.peerUserId.trim().isEmpty
                                                      ? AppColors.subText(
                                                          dark: dark)
                                                      : AppColors.primaryBlue,
                                              size: 22,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
          ),
        ],
      ),
    );
  }
}
