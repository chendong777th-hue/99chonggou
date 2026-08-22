import 'package:flutter/material.dart';
import 'package:tencent_cloud_chat_demo/src/i18n/app_i18n.dart';
import 'package:tencent_cloud_chat_demo/src/services/group_join_application_service.dart';
import 'package:tencent_cloud_chat_demo/src/theme/app_colors.dart';
import 'package:tencent_cloud_chat_demo/src/widgets/app_user_avatar.dart';
import 'package:tencent_cloud_chat_demo/utils/chat_id_format.dart';
import 'package:tencent_cloud_chat_demo/utils/conversation_face_url.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_group_application.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_group_application.dart';
import 'package:tencent_cloud_chat_uikit/data_services/group/group_services.dart';
import 'package:tencent_cloud_chat_uikit/data_services/services_locatar.dart';

/// 单群进群申请列表（Public / Meeting / Community，REST）。
class GroupSelfHostedJoinApplicationListPage extends StatefulWidget {
  final String groupId;

  const GroupSelfHostedJoinApplicationListPage({
    super.key,
    required this.groupId,
  });

  @override
  State<GroupSelfHostedJoinApplicationListPage> createState() =>
      _GroupSelfHostedJoinApplicationListPageState();
}

class _GroupSelfHostedJoinApplicationListPageState
    extends State<GroupSelfHostedJoinApplicationListPage> {
  final GroupServices _groupServices = serviceLocator<GroupServices>();
  List<V2TimGroupApplication> _applications = const [];
  bool _loading = true;
  String _groupName = '';

  @override
  void initState() {
    super.initState();
    _load();
    GroupJoinApplicationService.instance
        .addListener(_onGlobalApplicationsChanged);
  }

  @override
  void dispose() {
    GroupJoinApplicationService.instance
        .removeListener(_onGlobalApplicationsChanged);
    super.dispose();
  }

  void _onGlobalApplicationsChanged() {
    if (!mounted) {
      return;
    }
    setState(() {
      _applications = GroupJoinApplicationService.instance.applications
          .where(
            (item) =>
                ChatIdFormat.groupIdsEquivalent(item.groupID, widget.groupId),
          )
          .toList();
    });
  }

  Future<void> _load({bool showSpinner = true}) async {
    if (showSpinner && mounted) {
      setState(() => _loading = true);
    }
    try {
      final applications =
          await GroupJoinApplicationService.instance.loadApplicationsForGroup(
        widget.groupId,
        includeHandled: true,
      );
      final res = await _groupServices.getGroupsInfo(
        groupIDList: [widget.groupId],
      );
      var groupName = widget.groupId;
      if (res != null) {
        for (final item in res) {
          if (item.resultCode == 0 &&
              item.groupInfo?.groupName?.trim().isNotEmpty == true) {
            groupName = item.groupInfo!.groupName!.trim();
            break;
          }
        }
      }
      if (!mounted) return;
      setState(() {
        _groupName = groupName;
        _applications = applications;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  String _content(V2TimGroupApplication application) {
    final i18n = AppI18n.of(context);
    final applicant = GroupJoinApplicationService.instance.resolveDisplayName(
      userId: application.fromUser,
      apiNickName: application.fromUserNickName,
    );
    final displayApplicant = applicant.isNotEmpty
        ? applicant
        : i18n.t(
            zhHans: '有人',
            zhHant: '有人',
            en: 'Someone',
            ja: '誰か',
            ko: '누군가',
          );
    if (application.type == 2) {
      final target = application.toUser?.trim() ?? '';
      if (target.isNotEmpty) {
        final targetName =
            GroupJoinApplicationService.instance.resolveDisplayName(
          userId: target,
        );
        return i18n.format(
          zhHans: '{option1} 邀请 {option2} 加入 {option3}',
          zhHant: '{option1} 邀請 {option2} 加入 {option3}',
          en: '{option1} invited {option2} to {option3}',
          ja: '{option1}が{option2}を{option3}に招待',
          ko: '{option1}님이 {option2}님을 {option3}에 초대',
          vars: {
            'option1': displayApplicant,
            'option2': targetName,
            'option3': _groupName,
          },
        );
      }
    }
    return i18n.format(
      zhHans: '{option1} 申请加入 {option2}',
      zhHant: '{option1} 申請加入 {option2}',
      en: '{option1} requested to join {option2}',
      ja: '{option1}が{option2}への参加を申請',
      ko: '{option1}님이 {option2} 참가를 요청함',
      vars: {'option1': displayApplicant, 'option2': _groupName},
    );
  }

  Future<void> _approve(V2TimGroupApplication application) async {
    await GroupJoinApplicationService.instance.approve(application);
  }

  Future<void> _reject(V2TimGroupApplication application) async {
    await GroupJoinApplicationService.instance.reject(application);
  }

  Widget _buildTrailing(V2TimGroupApplication application, bool dark) {
    final i18n = AppI18n.of(context);
    final muted = AppColors.subText(dark: dark);
    if (application.handleResult == 1) {
      return Text(
        i18n.t(
          zhHans: '已同意',
          zhHant: '已同意',
          en: 'Accepted',
          ja: '承認済み',
          ko: '승인됨',
        ),
        style: TextStyle(color: muted),
      );
    }
    if (application.handleResult == 2) {
      return Text(
        i18n.t(
          zhHans: '已拒绝',
          zhHant: '已拒絕',
          en: 'Declined',
          ja: '拒否済み',
          ko: '거절됨',
        ),
        style: TextStyle(color: muted),
      );
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        TextButton(
          onPressed: () => _reject(application),
          style: TextButton.styleFrom(
            foregroundColor: AppColors.subText(dark: dark),
          ),
          child: Text(i18n.t(
            zhHans: '拒绝',
            zhHant: '拒絕',
            en: 'Reject',
            ja: '拒否',
            ko: '거절',
          )),
        ),
        TextButton(
          onPressed: () => _approve(application),
          style: TextButton.styleFrom(
            foregroundColor: AppColors.primaryBlue,
          ),
          child: Text(i18n.t(
            zhHans: '同意',
            zhHant: '同意',
            en: 'Approve',
            ja: '承認',
            ko: '승인',
          )),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final i18n = AppI18n.of(context);
    final dark = Theme.of(context).brightness == Brightness.dark;
    final bg = AppColors.background(dark: dark);
    final textColor = AppColors.text(dark: dark);
    final subColor = AppColors.subText(dark: dark);

    if (_loading) {
      return ColoredBox(
        color: bg,
        child: const Center(child: CircularProgressIndicator()),
      );
    }
    if (_applications.isEmpty) {
      return ColoredBox(
        color: bg,
        child: Center(
          child: Text(
            i18n.t(
              zhHans: '暂无群通知',
              zhHant: '暫無群組通知',
              en: 'No group notices',
              ja: 'グループ通知はありません',
              ko: '그룹 알림 없음',
            ),
            style: TextStyle(color: subColor),
          ),
        ),
      );
    }

    return ColoredBox(
      color: bg,
      child: RefreshIndicator(
        onRefresh: () => _load(showSpinner: false),
        child: ListView.separated(
          itemCount: _applications.length,
          separatorBuilder: (_, __) => Divider(
            height: 1,
            color: AppColors.line(dark: dark),
          ),
          itemBuilder: (context, index) {
            final application = _applications[index];
            return ListTile(
              tileColor: AppColors.card(dark: dark),
              leading: AppUserAvatar(
                faceUrl: ConversationFaceUrl.defaultGroupFaceAsset,
                showName: _groupName,
                size: 44,
                type: 2,
              ),
              title: Text(
                _content(application),
                style: TextStyle(color: textColor),
              ),
              subtitle: application.requestMsg?.trim().isNotEmpty == true
                  ? Text(
                      application.requestMsg!.trim(),
                      style: TextStyle(color: subColor),
                    )
                  : null,
              trailing: _buildTrailing(application, dark),
            );
          },
        ),
      ),
    );
  }
}
