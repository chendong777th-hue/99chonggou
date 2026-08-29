import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:tencent_cloud_chat_demo/src/api/group_live_api.dart';
import 'package:tencent_cloud_chat_demo/src/i18n/app_i18n.dart';
import 'package:tencent_cloud_chat_demo/src/models/group_live_models.dart';
import 'package:tencent_cloud_chat_demo/src/navigation/app_page_transitions.dart';
import 'package:tencent_cloud_chat_demo/src/pages/group_live/group_live_online_live_scaffold.dart';
import 'package:tencent_cloud_chat_demo/src/pages/group_live/group_live_push_info_page.dart';
import 'package:tencent_cloud_chat_demo/src/pages/group_live/group_live_routing.dart';
import 'package:tencent_cloud_chat_demo/src/pages/wallet/api_wallet_repository.dart';
import 'package:tencent_cloud_chat_demo/src/pages/wallet/red_packet/red_packet_member.dart';
import 'package:tencent_cloud_chat_demo/src/pages/wallet/red_packet/red_packet_member_picker_page.dart';
import 'package:tencent_cloud_chat_demo/src/pages/wallet/wallet_store.dart';
import 'package:tencent_cloud_chat_demo/src/services/group_local/group_info_resolver.dart';
import 'package:tencent_cloud_chat_demo/src/services/group_local/group_member_local_store.dart';
import 'package:tencent_cloud_chat_demo/src/utils/group_live_error_message.dart';
import 'package:tencent_cloud_chat_demo/src/widgets/app_dialog.dart';
import 'package:tencent_cloud_chat_demo/utils/chat_id_format.dart';
import 'package:tencent_cloud_chat_demo/utils/toast.dart';
import 'package:tencent_cloud_chat_uikit/tencent_cloud_chat_uikit.dart';
import 'package:tencent_cloud_chat_uikit/ui/utils/group_role_policy.dart';

class GroupLiveAuthorizePage extends StatefulWidget {
  const GroupLiveAuthorizePage._({
    required this.groupId,
    this.initialSession,
    this.manageOnly = false,
  });

  final String groupId;
  final GroupLiveSession? initialSession;
  final bool manageOnly;

  static Future<void> openSchedule(BuildContext context,
      {required String groupId}) {
    return Navigator.of(context).push<void>(
      AppMaterialPageRoute(
        builder: (_) => GroupLiveAuthorizePage._(groupId: groupId),
      ),
    );
  }

  static Future<void> openScheduleReplacing(
    BuildContext context, {
    required String groupId,
  }) {
    return Navigator.of(context).pushReplacement(
      AppMaterialPageRoute<void>(
        builder: (_) => GroupLiveAuthorizePage._(groupId: groupId),
      ),
    );
  }

  static Widget buildManage({
    required String groupId,
    GroupLiveSession? initialSession,
  }) {
    return GroupLiveAuthorizePage._(
      groupId: groupId,
      initialSession: initialSession,
      manageOnly: true,
    );
  }

  static Future<void> openManage(
    BuildContext context, {
    required String groupId,
    GroupLiveSession? initialSession,
  }) {
    return Navigator.of(context).push<void>(
      AppMaterialPageRoute(
        builder: (_) => GroupLiveAuthorizePage._(
          groupId: groupId,
          initialSession: initialSession,
          manageOnly: true,
        ),
      ),
    );
  }

  @override
  State<GroupLiveAuthorizePage> createState() => _GroupLiveAuthorizePageState();
}

class _GroupLiveAuthorizePageState extends State<GroupLiveAuthorizePage> {
  final _roomNameController = TextEditingController();
  RedPacketMember? _anchor;
  DateTime? _scheduledAt;
  GroupLiveSession? _session;
  bool _submitting = false;
  bool _loadingMembers = false;
  bool? _isOwner;
  bool _isManager = false;
  List<RedPacketMember>? _cachedMembers;

  @override
  void initState() {
    super.initState();
    _session = widget.initialSession;
    if (_session != null) {
      _roomNameController.text = _session!.roomName;
      if (_session!.scheduledStartAt != null) {
        _scheduledAt = _session!.scheduledStartAt!.toLocal();
      }
    }
    unawaited(_loadRole());
    unawaited(_seedAnchorFromSession());
    unawaited(_warmMembersCache());
  }

  Future<void> _seedAnchorFromSession() async {
    final session = _session;
    if (session == null) return;
    final anchorId = session.anchorUserId.trim();
    if (anchorId.isEmpty) return;
    final members = await _membersForPicker();
    if (!mounted) return;
    for (final member in members) {
      if (member.userId.trim() == anchorId) {
        setState(() => _anchor = member);
        return;
      }
    }
    setState(
      () => _anchor = RedPacketMember(userId: anchorId, name: anchorId),
    );
  }

  @override
  void dispose() {
    _roomNameController.dispose();
    super.dispose();
  }

  Future<void> _loadRole() async {
    final role = await GroupInfoResolver.instance.myRole(widget.groupId);
    if (!mounted) return;
    setState(() {
      _isOwner = GroupRolePolicy.isOwnerRole(role);
      _isManager = GroupRolePolicy.isManagerRole(role);
    });
  }

  Future<List<RedPacketMember>> _loadLocalMembers() async {
    final groupId = ChatIdFormat.canonicalGroupStorageId(widget.groupId);
    if (groupId.isEmpty) {
      return const [];
    }
    final local =
        await GroupMemberLocalStore.instance.readAll(groupId: groupId);
    return local
        .map(
          (record) => RedPacketMember(
            userId: record.userId,
            name: record.friendRemark.trim().isNotEmpty
                ? record.friendRemark.trim()
                : record.displayName,
            publicName: record.nickname,
            avatar: record.avatarUrl,
          ),
        )
        .where((member) => member.userId.trim().isNotEmpty)
        .toList(growable: false);
  }

  Future<void> _warmMembersCache() async {
    final local = await _loadLocalMembers();
    if (!mounted) return;
    if (local.isNotEmpty) {
      setState(() => _cachedMembers = local);
    }
    unawaited(_refreshMembersFromApi());
  }

  Future<void> _refreshMembersFromApi() async {
    final groupId = ChatIdFormat.canonicalGroupStorageId(widget.groupId);
    if (groupId.isEmpty) {
      return;
    }
    try {
      final members = await WalletStore.instance.getMembers(
        groupId,
        repo: const ApiWalletRepository(),
      );
      if (!mounted || members.isEmpty) {
        return;
      }
      setState(() => _cachedMembers = members);
    } catch (_) {}
  }

  Future<List<RedPacketMember>> _membersForPicker() async {
    final cached = _cachedMembers;
    if (cached != null && cached.isNotEmpty) {
      return cached;
    }
    final local = await _loadLocalMembers();
    if (local.isNotEmpty) {
      _cachedMembers = local;
      return local;
    }
    final members = await WalletStore.instance.getMembers(
      ChatIdFormat.canonicalGroupStorageId(widget.groupId),
      repo: const ApiWalletRepository(),
    );
    if (members.isNotEmpty) {
      _cachedMembers = members;
    }
    return members;
  }

  Future<void> _pickAnchor() async {
    FocusManager.instance.primaryFocus?.unfocus();
    final i18n = AppI18n.of(context);

    var members = _cachedMembers;
    if (members == null || members.isEmpty) {
      setState(() => _loadingMembers = true);
      try {
        members = await _membersForPicker();
      } finally {
        if (mounted) setState(() => _loadingMembers = false);
      }
    } else {
      unawaited(_refreshMembersFromApi());
    }

    if (!mounted) return;

    final filtered =
        members.where((member) => member.userId.trim().isNotEmpty).toList();
    if (filtered.isEmpty) {
      ToastUtils.toast(i18n.t(
        zhHans: '暂无群成员，请稍后再试',
        zhHant: '暫無群成員，請稍後再試',
        en: 'No group members available. Try again later.',
        ja: 'グループメンバーがありません。後でもう一度お試しください。',
        ko: '그룹 멤버가 없습니다. 잠시 후 다시 시도해 주세요.',
      ));
      return;
    }

    final picked = await pickRedPacketMember(
      context,
      members: filtered,
      hideMemberIds: false,
      enablePresence: false,
      title: i18n.t(
        zhHans: '选择主播',
        zhHant: '選擇主播',
        en: 'Select anchor',
        ja: 'アンカーを選択',
        ko: '앵커 선택',
      ),
    );
    if (picked != null && mounted) {
      setState(() => _anchor = picked);
    }
  }

  bool _isScheduleTimeTooSoon(DateTime scheduledAt) {
    return scheduledAt.isBefore(groupLiveScheduleMinimumDate());
  }

  Future<void> _pickTime() async {
    final initial = _scheduledAt ?? groupLiveScheduleMinimumDate();
    final picked = await showGroupLiveScheduleTimePicker(
      context,
      initialDateTime: initial,
      minimumDate: groupLiveScheduleMinimumDate(),
      maximumDate: DateTime.now().add(const Duration(days: 7)),
    );
    if (picked == null || !mounted) return;
    setState(() => _scheduledAt = picked);
  }

  Future<void> _authorize() async {
    final roomName = _roomNameController.text.trim();
    final anchorId = _anchor?.userId.trim() ?? '';
    final scheduledAt = _scheduledAt;
    if (roomName.isEmpty || anchorId.isEmpty || scheduledAt == null) {
      ToastUtils.toast(AppI18n.of(context).t(
        zhHans: '请填写直播间名称、选择主播并设置开播时间',
        zhHant: '請填寫直播間名稱、選擇主播並設置開播時間',
        en: 'Enter room name, pick an anchor, and set start time.',
        ja: 'ルーム名・アンカー・開始時刻を入力してください。',
        ko: '라이브룸 이름, 앵커, 시작 시간을 설정해 주세요.',
      ));
      return;
    }
    if (_isScheduleTimeTooSoon(scheduledAt)) {
      ToastUtils.toast(AppI18n.of(context).t(
        zhHans: '开播时间需晚于当前时间至少 1 分钟',
        zhHant: '開播時間需晚於當前時間至少 1 分鐘',
        en: 'Start time must be at least 1 minute from now.',
        ja: '開始時刻は現在から1分以上後に設定してください。',
        ko: '시작 시간은 현재보다 최소 1분 이후여야 합니다.',
      ));
      return;
    }
    setState(() => _submitting = true);
    try {
      final session = await GroupLiveApi.instance.authorize(
        groupId: widget.groupId,
        anchorUserId: anchorId,
        roomName: roomName,
        scheduledStartAt: scheduledAt.toUtc(),
      );
      if (!mounted) return;
      await GroupLiveRouting.routeAfterAuthorize(
        context,
        session: session,
        groupId: widget.groupId,
      );
    } catch (e) {
      if (!mounted) return;
      ToastUtils.toast(GroupLiveErrorMessage.from(e));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _updateSchedule() async {
    final scheduledAt = _scheduledAt;
    if (scheduledAt == null) {
      ToastUtils.toast(AppI18n.of(context).t(
        zhHans: '请设置预计开播时间',
        zhHant: '請設置預計開播時間',
        en: 'Set a scheduled start time.',
        ja: '開始予定時刻を設定してください。',
        ko: '예상 시작 시간을 설정해 주세요.',
      ));
      return;
    }
    if (_isScheduleTimeTooSoon(scheduledAt)) {
      ToastUtils.toast(AppI18n.of(context).t(
        zhHans: '开播时间需晚于当前时间至少 1 分钟',
        zhHant: '開播時間需晚於當前時間至少 1 分鐘',
        en: 'Start time must be at least 1 minute from now.',
        ja: '開始時刻は現在から1分以上後に設定してください。',
        ko: '시작 시간은 현재보다 최소 1분 이후여야 합니다.',
      ));
      return;
    }
    setState(() => _submitting = true);
    try {
      final session = await GroupLiveApi.instance.updateSchedule(
        groupId: widget.groupId,
        roomName: _roomNameController.text.trim(),
        scheduledStartAt: scheduledAt.toUtc(),
      );
      if (!mounted) return;
      setState(() => _session = session);
      ToastUtils.toast(AppI18n.of(context).t(
        zhHans: '已更新预约',
        zhHant: '已更新預約',
        en: 'Schedule updated',
        ja: '予約を更新しました',
        ko: '예약 업데이트됨',
      ));
    } catch (e) {
      if (!mounted) return;
      ToastUtils.toast(GroupLiveErrorMessage.from(e));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  /// 结束直播 = 删除配置；若已在推流则同时结束推流。
  Future<void> _endLive() async {
    final session = _session;
    if (session == null) return;
    final i18n = AppI18n.of(context);
    final isLive = session.isLive;
    final confirmed = await AppDialog.confirm(
      title: i18n.t(
        zhHans: '结束直播',
        zhHant: '結束直播',
        en: 'End live',
        ja: '配信終了',
        ko: '라이브 종료',
      ),
      message: isLive
          ? i18n.t(
              zhHans: '确定结束本次直播吗？将同时结束推流，推流地址随即失效。',
              zhHant: '確定結束本次直播嗎？將同時結束推流，推流地址隨即失效。',
              en: 'End this live? Streaming will stop and credentials will become invalid.',
              ja: 'この配信を終了しますか？配信も停止し、URLは無効になります。',
              ko: '이 라이브를 종료할까요? 推流도 함께 종료되며 주소가 무효화됩니다.',
            )
          : i18n.t(
              zhHans: '确定结束本次直播吗？结束后需重新配置。',
              zhHant: '確定結束本次直播嗎？結束後需重新配置。',
              en: 'End this live? You will need to set it up again.',
              ja: 'この配信を終了しますか？終了後は再設定が必要です。',
              ko: '이 라이브를 종료할까요? 종료 후 다시 설정해야 합니다.',
            ),
      cancelText: i18n.t(
        zhHans: '取消',
        zhHant: '取消',
        en: 'Cancel',
        ja: 'キャンセル',
        ko: '취소',
      ),
      confirmText: i18n.t(
        zhHans: '结束',
        zhHant: '結束',
        en: 'End',
        ja: '終了',
        ko: '종료',
      ),
      destructive: true,
    );
    if (!confirmed || !mounted) return;

    setState(() => _submitting = true);
    try {
      if (isLive) {
        await GroupLiveApi.instance.stop(groupId: widget.groupId);
      } else {
        await GroupLiveApi.instance.revoke(groupId: widget.groupId);
      }
      if (!mounted) return;
      ToastUtils.toast(i18n.t(
        zhHans: isLive ? '已结束直播并停止推流' : '已结束直播',
        zhHant: isLive ? '已結束直播並停止推流' : '已結束直播',
        en: isLive ? 'Live ended and streaming stopped' : 'Live ended',
        ja: isLive ? '配信を終了し、推流も停止しました' : '配信を終了しました',
        ko: isLive ? '라이브와 推流를 종료했습니다' : '라이브를 종료했습니다',
      ));
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      ToastUtils.toast(GroupLiveErrorMessage.from(e));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _openPushInfo() async {
    final session = _session;
    if (session == null) return;
    await GroupLivePushInfoPage.open(
      context,
      liveSessionId: session.liveSessionId,
      initialSession: session,
      groupId: widget.groupId,
    );
  }

  @override
  Widget build(BuildContext context) {
    final i18n = AppI18n.of(context);
    final isManage = widget.manageOnly && _session != null;
    final canEditSchedule = _session?.status == GroupLiveStatus.scheduled;
    final canEndLive = _session != null &&
        (_session!.status == GroupLiveStatus.scheduled ||
            _session!.status == GroupLiveStatus.authorized ||
            _session!.isLive);
    final selfId = TIMUIKitCore.getInstance().loginInfo.userID.trim();
    final isAnchor = _session != null &&
        selfId.isNotEmpty &&
        selfId == _session!.anchorUserId.trim();
    final canOpenPush = _session != null &&
        (_session!.status == GroupLiveStatus.authorized ||
            _session!.status == GroupLiveStatus.live) &&
        (_isOwner == true || _isManager || isAnchor);

    return GroupLiveOnlineLiveScaffold(
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const GroupLiveScheduleHeader(),
          const SizedBox(height: 24),
          GroupLiveFormSection(
            title: i18n.t(
              zhHans: '直播设置',
              zhHant: '直播設置',
              en: 'Live settings',
              ja: '配信設定',
              ko: '라이브 설정',
            ),
            children: [
              GroupLiveRoomNameField(
                controller: _roomNameController,
                enabled: !isManage || canEditSchedule,
              ),
              if (!isManage)
                GroupLiveScheduleField(
                  label: i18n.t(
                    zhHans: '主播',
                    zhHant: '主播',
                    en: 'Anchor',
                    ja: 'アンカー',
                    ko: '앵커',
                  ),
                  value: _anchor?.name.trim() ?? '',
                  placeholder: _loadingMembers
                      ? i18n.t(
                          zhHans: '加载中…',
                          zhHant: '載入中…',
                          en: 'Loading…',
                          ja: '読み込み中…',
                          ko: '로딩 중…',
                        )
                      : i18n.t(
                          zhHans: '请选择主播',
                          zhHant: '請選擇主播',
                          en: 'Select anchor',
                          ja: 'アンカーを選択',
                          ko: '앵커 선택',
                        ),
                  trailing: GroupLiveFieldTrailing.chevron,
                  onTap:
                      _loadingMembers ? null : () => unawaited(_pickAnchor()),
                ),
              GroupLiveScheduleField(
                label: i18n.t(
                  zhHans: '预计开播时间',
                  zhHant: '預計開播時間',
                  en: 'Scheduled start',
                  ja: '開始予定',
                  ko: '예상 시작 시간',
                ),
                value: _scheduledAt == null
                    ? ''
                    : DateFormat('yyyy-MM-dd HH:mm')
                        .format(_scheduledAt!.toLocal()),
                placeholder: i18n.t(
                  zhHans: '可设置预计开播时间',
                  zhHant: '可設置預計開播時間',
                  en: 'Set scheduled start time',
                  ja: '開始予定時刻を設定',
                  ko: '예상 시작 시간 설정',
                ),
                trailing: GroupLiveFieldTrailing.calendar,
                onTap: (!isManage || canEditSchedule)
                    ? () => unawaited(_pickTime())
                    : null,
              ),
              if (canOpenPush)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: () => unawaited(_openPushInfo()),
                      child: Text(
                        i18n.t(
                          zhHans: '查看推流地址',
                          zhHant: '查看推流地址',
                          en: 'View push info',
                          ja: '配信URLを見る',
                          ko: '推流 주소 보기',
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
      bottomButton: _buildBottomButton(
        i18n: i18n,
        isManage: isManage,
        canEditSchedule: canEditSchedule,
        canEndLive: canEndLive,
      ),
    );
  }

  Widget? _buildBottomButton({
    required AppI18n i18n,
    required bool isManage,
    required bool canEditSchedule,
    required bool canEndLive,
  }) {
    if (!isManage) {
      return GroupLivePrimaryButton(
        label: i18n.t(
          zhHans: '下一步',
          zhHant: '下一步',
          en: 'Next',
          ja: '次へ',
          ko: '다음',
        ),
        loading: _submitting,
        onPressed: () => unawaited(_authorize()),
      );
    }
    if (canEditSchedule) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (canEndLive)
            TextButton(
              onPressed: _submitting ? null : () => unawaited(_endLive()),
              child: Text(
                i18n.t(
                  zhHans: '结束直播',
                  zhHant: '結束直播',
                  en: 'End live',
                  ja: '配信終了',
                  ko: '라이브 종료',
                ),
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFFEF5350),
                ),
              ),
            ),
          GroupLivePrimaryButton(
            label: i18n.t(
              zhHans: '保存修改',
              zhHant: '保存修改',
              en: 'Save changes',
              ja: '保存',
              ko: '저장',
            ),
            loading: _submitting,
            onPressed: () => unawaited(_updateSchedule()),
          ),
        ],
      );
    }
    if (canEndLive) {
      return GroupLivePrimaryButton(
        label: i18n.t(
          zhHans: '结束直播',
          zhHant: '結束直播',
          en: 'End live',
          ja: '配信終了',
          ko: '라이브 종료',
        ),
        loading: _submitting,
        onPressed: () => unawaited(_endLive()),
      );
    }
    return null;
  }
}
