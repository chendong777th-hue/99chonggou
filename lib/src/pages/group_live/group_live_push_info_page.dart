import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:tencent_cloud_chat_demo/src/api/group_live_api.dart';
import 'package:tencent_cloud_chat_demo/src/i18n/app_i18n.dart';
import 'package:tencent_cloud_chat_demo/src/models/group_live_models.dart';
import 'package:tencent_cloud_chat_demo/src/navigation/app_page_transitions.dart';
import 'package:tencent_cloud_chat_demo/src/pages/group_live/group_live_authorize_page.dart';
import 'package:tencent_cloud_chat_demo/src/pages/group_live/group_live_online_live_scaffold.dart';
import 'package:tencent_cloud_chat_demo/src/pages/group_live/group_live_routing.dart';
import 'package:tencent_cloud_chat_demo/src/services/group_local/group_info_resolver.dart';
import 'package:tencent_cloud_chat_demo/src/ui/app_tokens.dart';
import 'package:tencent_cloud_chat_demo/src/utils/group_live_error_message.dart';
import 'package:tencent_cloud_chat_demo/src/widgets/app_dialog.dart';
import 'package:tencent_cloud_chat_demo/utils/toast.dart';
import 'package:tencent_cloud_chat_sdk/enum/group_member_role.dart';
import 'package:tencent_cloud_chat_uikit/tencent_cloud_chat_uikit.dart';
import 'package:tencent_cloud_chat_uikit/ui/utils/group_role_policy.dart';

class GroupLivePushInfoPage extends StatefulWidget {
  const GroupLivePushInfoPage({
    super.key,
    required this.liveSessionId,
    this.initialSession,
    this.groupId,
  });

  final String liveSessionId;
  final GroupLiveSession? initialSession;
  final String? groupId;

  static Future<void> open(
    BuildContext context, {
    required String liveSessionId,
    GroupLiveSession? initialSession,
    String? groupId,
  }) {
    return Navigator.of(context).push<void>(
      AppMaterialPageRoute(
        builder: (_) => GroupLivePushInfoPage(
          liveSessionId: liveSessionId,
          initialSession: initialSession,
          groupId: groupId,
        ),
      ),
    );
  }

  @override
  State<GroupLivePushInfoPage> createState() => _GroupLivePushInfoPageState();
}

class _GroupLivePushInfoPageState extends State<GroupLivePushInfoPage> {
  GroupLivePushInfo? _info;
  GroupLiveSession? _session;
  bool _loading = true;
  bool _submitting = false;
  bool _refreshing = false;
  bool _pendingSchedule = false;
  bool _canManageLive = false;
  bool _errorReschedulable = false;
  String? _error;
  String? _errorSubtitle;

  @override
  void initState() {
    super.initState();
    _session = widget.initialSession;
    unawaited(_load());
  }

  Future<void> _load({bool refreshing = false}) async {
    setState(() {
      if (refreshing) {
        _refreshing = true;
      } else {
        _loading = true;
      }
      _error = null;
      _errorSubtitle = null;
      _errorReschedulable = false;
      if (!refreshing) {
        _pendingSchedule = false;
      }
    });
    try {
      final session = await GroupLiveApi.instance.sessionDetail(
        liveSessionId: widget.liveSessionId,
      );
      final groupId = _groupId.isNotEmpty ? _groupId : session.groupId.trim();
      final userId = GroupLiveRouting.currentUserId();
      final role = groupId.isEmpty
          ? GroupMemberRoleType.V2TIM_GROUP_MEMBER_ROLE_MEMBER
          : (await GroupInfoResolver.instance.myRole(groupId)) ??
              GroupMemberRoleType.V2TIM_GROUP_MEMBER_ROLE_MEMBER;

      if (!mounted) return;

      final canView = GroupLiveRouting.canViewPushInfoScreen(
        session: session,
        currentUserId: userId,
        role: role,
      );
      final canManage = GroupRolePolicy.isManagerRole(role);

      if (!canView) {
        setState(() {
          _session = session;
          _canManageLive = canManage;
          _loading = false;
          _refreshing = false;
          _error = GroupLiveErrorMessage.pushInfoAccessDenied();
        });
        return;
      }

      final blocked = GroupLiveErrorMessage.blockedPushInfoMessage(session);
      if (blocked != null) {
        if (kDebugMode) {
          // ignore: avoid_print
          print(
            '[GroupLive] push-info skipped: status=${session.status.wire} '
            'endReason=${session.endReason?.name ?? 'null'} '
            'expireAt=${session.expireAt?.toIso8601String() ?? 'null'}',
          );
        }
        if (!mounted) return;
        setState(() {
          _session = session;
          _canManageLive = canManage;
          _loading = false;
          _refreshing = false;
          _error = blocked;
          _errorSubtitle = GroupLiveErrorMessage.sessionTimingSubtitle(session);
          _errorReschedulable = canManage &&
              GroupLiveErrorMessage.canRescheduleAfterEnd(session);
        });
        return;
      }

      try {
        final info = await GroupLiveApi.instance.pushInfo(
          liveSessionId: widget.liveSessionId,
        );
        if (!mounted) return;
        setState(() {
          _info = info;
          _session = session;
          _canManageLive = canManage;
          _pendingSchedule = false;
          _loading = false;
          _refreshing = false;
        });
        return;
      } on GroupLiveApiException catch (e) {
        final code = e.code.trim().toUpperCase();
        if (code == 'LIVE_NOT_AUTHORIZED_YET' ||
            session.status == GroupLiveStatus.scheduled) {
          if (!mounted) return;
          setState(() {
            _session = session;
            _canManageLive = canManage;
            _pendingSchedule = true;
            _loading = false;
            _refreshing = false;
          });
          return;
        }
        if (code == 'LIVE_SESSION_EXPIRED') {
          if (kDebugMode) {
            // ignore: avoid_print
            print(
              '[GroupLive] push-info LIVE_SESSION_EXPIRED '
              'status=${session.status.wire} '
              'expireAt=${session.expireAt?.toIso8601String() ?? 'null'}',
            );
          }
          if (!mounted) return;
          setState(() {
            _session = session;
            _canManageLive = canManage;
            _loading = false;
            _refreshing = false;
            _error = GroupLiveErrorMessage.from(
              GroupLiveApiException('LIVE_SESSION_EXPIRED', ''),
            );
            _errorSubtitle = GroupLiveErrorMessage.sessionTimingSubtitle(session);
            _errorReschedulable = canManage;
          });
          return;
        }
        rethrow;
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _refreshing = false;
        _error = GroupLiveErrorMessage.from(e);
      });
    }
  }

  Future<void> _openReschedule() async {
    final groupId = _groupId;
    if (groupId.isEmpty || !mounted) return;
    await GroupLiveAuthorizePage.openScheduleReplacing(
      context,
      groupId: groupId,
    );
  }

  /// 结束直播 = 删除本次直播配置；若已在推流则先结束推流（stop），否则撤销预约（revoke）。
  Future<void> _endLive() async {
    final session = _session;
    final groupId = _groupId;
    if (session == null || !_canManageLive || groupId.isEmpty) return;

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
              zhHans: '确定结束本次直播吗？结束后推流地址将失效，需重新配置。',
              zhHant: '確定結束本次直播嗎？結束後推流地址將失效，需重新配置。',
              en: 'End this live? Streaming credentials will become invalid.',
              ja: 'この配信を終了しますか？終了後は配信URLが無効になります。',
              ko: '이 라이브를 종료할까요? 종료 후 推流 정보가 무효화됩니다.',
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
        await GroupLiveApi.instance.stop(groupId: groupId);
      } else {
        await GroupLiveApi.instance.revoke(groupId: groupId);
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

  bool get _canEndLive {
    final session = _session;
    if (session == null || !_canManageLive) return false;
    return session.status == GroupLiveStatus.scheduled ||
        session.status == GroupLiveStatus.authorized ||
        session.isLive;
  }

  Widget? _buildBottomButton(AppI18n i18n) {
    if (!_canEndLive) return null;
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

  Widget _obsGuideLink(AppI18n i18n) {
    return TextButton(
      onPressed: () => showGroupLiveObsGuideSheet(
        context,
        hint: _info?.obsHint,
      ),
      style: TextButton.styleFrom(
        padding: EdgeInsets.zero,
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        foregroundColor: GroupLiveOnlineLiveScaffold.primaryBlue,
      ),
      child: Text(
        i18n.t(
          zhHans: '芯象配置',
          zhHant: '芯象配置',
          en: 'Xinxian setup',
          ja: '芯象の設定',
          ko: '芯象 설정',
        ),
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  String get _groupId =>
      widget.groupId?.trim() ??
      _session?.groupId.trim() ??
      widget.initialSession?.groupId.trim() ??
      '';

  String get _pushUrl {
    final server = _info?.rtmpServer.trim() ?? '';
    final streamKey = _info?.streamKey.trim() ?? '';
    if (server.isEmpty) return streamKey;
    if (streamKey.isEmpty) return server;
    return '${server.replaceFirst(RegExp(r'/+$'), '')}/'
        '${streamKey.replaceFirst(RegExp(r'^/+'), '')}';
  }

  Widget _buildPendingScheduleBody(AppI18n i18n) {
    final pendingHint = i18n.t(
      zhHans: '正在获取推流地址',
      zhHant: '正在取得推流地址',
      en: 'Loading streaming URL',
      ja: '配信URLを取得しています',
      ko: '推流 주소를 불러오는 중',
    );
    final timingHint = GroupLiveErrorMessage.sessionTimingSubtitle(
      _session ??
          GroupLiveSession(
            liveSessionId: widget.liveSessionId,
            groupId: _groupId,
            roomName: '',
            anchorUserId: '',
            status: GroupLiveStatus.scheduled,
          ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const GroupLiveOnlineLiveHeader(),
        const SizedBox(height: 24),
        GroupLiveFormSection(
          title: i18n.t(
            zhHans: '直播设置',
            zhHant: '直播設置',
            en: 'Live settings',
            ja: '配信設定',
            ko: '라이브 설정',
          ),
          trailing: _obsGuideLink(i18n),
          children: [
            GroupLiveCopyField(
              label: i18n.t(
                zhHans: '推流地址',
                zhHant: '推流地址',
                en: 'Streaming URL',
                ja: '配信URL',
                ko: '推流 주소',
              ),
              value: pendingHint,
              onCopy: () {},
            ),
          ],
        ),
        const SizedBox(height: 12),
        Text(
          timingHint ??
              i18n.t(
                zhHans: '推流地址可在开播前获取，到点后点击刷新重新加载',
                zhHant: '推流地址可在開播前取得，到點後點擊重新整理再次載入',
                en: 'Streaming URL is available before start. Refresh after the scheduled time.',
                ja: '配信URLは開始前に取得できます。開始時刻後に更新してください。',
                ko: '방송 전에도 推流 주소를 받을 수 있습니다. 시작 시간 후 새로고침하세요.',
              ),
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 13, color: AppTokens.ink500),
        ),
      ],
    );
  }

  Widget? _buildPendingBottomButton(AppI18n i18n) {
    if (!_pendingSchedule) return null;
    final refreshButton = GroupLivePrimaryButton(
      label: i18n.t(
        zhHans: '刷新状态',
        zhHant: '刷新狀態',
        en: 'Refresh',
        ja: '更新',
        ko: '새로고침',
      ),
      loading: _refreshing,
      onPressed: _refreshing ? null : () => unawaited(_load(refreshing: true)),
    );
    if (!_canEndLive) {
      return refreshButton;
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        GroupLivePrimaryButton(
          label: i18n.t(
            zhHans: '结束直播',
            zhHant: '結束直播',
            en: 'End live',
            ja: '配信終了',
            ko: '라이브 종료',
          ),
          loading: _submitting,
          onPressed: () => unawaited(_endLive()),
        ),
        const SizedBox(height: 10),
        refreshButton,
      ],
    );
  }

  Widget _buildErrorBody(AppI18n i18n) {
    return Column(
      children: [
        const GroupLiveOnlineLiveHeader(),
        const SizedBox(height: 24),
        Text(
          _error!,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 15,
            height: 1.5,
            color: AppTokens.ink800,
            fontWeight: FontWeight.w500,
          ),
        ),
        if (_errorSubtitle != null) ...[
          const SizedBox(height: 12),
          Text(
            _errorSubtitle!,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 13, color: AppTokens.ink500),
          ),
        ],
      ],
    );
  }

  Widget? _buildErrorBottomButton(AppI18n i18n) {
    if (_errorReschedulable && _groupId.isNotEmpty) {
      return GroupLivePrimaryButton(
        label: i18n.t(
          zhHans: '重新预约',
          zhHant: '重新預約',
          en: 'Schedule again',
          ja: '再度予約',
          ko: '다시 예약',
        ),
        onPressed: () => unawaited(_openReschedule()),
      );
    }
    return GroupLivePrimaryButton(
      label: i18n.t(
        zhHans: '重试',
        zhHant: '重試',
        en: 'Retry',
        ja: '再試行',
        ko: '재시도',
      ),
      onPressed: () => unawaited(_load()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final i18n = AppI18n.of(context);

    if (_loading) {
      return const GroupLiveOnlineLiveScaffold(
        body: Center(
          child: Padding(
            padding: EdgeInsets.only(top: 120),
            child: CircularProgressIndicator(),
          ),
        ),
      );
    }

    if (_pendingSchedule) {
      return GroupLiveOnlineLiveScaffold(
        body: _buildPendingScheduleBody(i18n),
        bottomButton: _buildPendingBottomButton(i18n),
      );
    }

    if (_error != null) {
      return GroupLiveOnlineLiveScaffold(
        body: _buildErrorBody(i18n),
        bottomButton: _buildErrorBottomButton(i18n),
      );
    }

    return GroupLiveOnlineLiveScaffold(
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const GroupLiveOnlineLiveHeader(),
          const SizedBox(height: 24),
          GroupLiveFormSection(
            title: i18n.t(
              zhHans: '直播设置',
              zhHant: '直播設置',
              en: 'Live settings',
              ja: '配信設定',
              ko: '라이브 설정',
            ),
            trailing: _obsGuideLink(i18n),
            children: [
              GroupLiveCopyField(
                label: i18n.t(
                  zhHans: '推流地址',
                  zhHant: '推流地址',
                  en: 'Streaming URL',
                  ja: '配信URL',
                  ko: '推流 주소',
                ),
                value: _pushUrl,
                onCopy: () => groupLiveCopyToClipboard(
                  context,
                  label: '推流地址',
                  value: _pushUrl,
                ),
              ),
              GroupLivePushQrField(value: _pushUrl),
            ],
          ),
        ],
      ),
      bottomButton: _buildBottomButton(i18n),
    );
  }
}
