import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tencent_cloud_chat_demo/src/api/group_join_api.dart';
import 'package:tencent_cloud_chat_demo/src/i18n/app_i18n.dart';
import 'package:tencent_cloud_chat_demo/src/pages/group_self_hosted_join_application_list_page.dart';
import 'package:tencent_cloud_chat_demo/src/provider/theme.dart';
import 'package:tencent_cloud_chat_uikit/data_services/group/group_services.dart';
import 'package:tencent_cloud_chat_uikit/data_services/services_locatar.dart';
import 'package:tencent_cloud_chat_uikit/tencent_cloud_chat_uikit.dart';

class GroupApplicationList extends StatefulWidget {
  /// group ID
  final String groupID;

  /// 已知群类型时可传入，避免额外请求。
  final String? groupType;

  const GroupApplicationList({
    super.key,
    required this.groupID,
    this.groupType,
  });

  @override
  State<GroupApplicationList> createState() => _GroupApplicationListState();
}

class _GroupApplicationListState extends State<GroupApplicationList> {
  final GroupServices _groupServices = serviceLocator<GroupServices>();
  bool? _usesSelfHostedJoin;

  @override
  void initState() {
    super.initState();
    _resolveJoinMode();
  }

  Future<void> _resolveJoinMode() async {
    if (GroupJoinApi.isSelfHostedJoinGroupType(widget.groupType)) {
      if (!mounted) return;
      setState(() => _usesSelfHostedJoin = true);
      return;
    }
    if (widget.groupType != null && widget.groupType!.trim().isNotEmpty) {
      if (!mounted) return;
      setState(() => _usesSelfHostedJoin = false);
      return;
    }
    try {
      final res = await _groupServices.getGroupsInfo(
        groupIDList: [widget.groupID],
      );
      var groupType = '';
      if (res != null) {
        for (final item in res) {
          if (item.resultCode == 0 && item.groupInfo?.groupType != null) {
            groupType = item.groupInfo!.groupType.trim();
            break;
          }
        }
      }
      if (!mounted) return;
      setState(
        () => _usesSelfHostedJoin =
            GroupJoinApi.isSelfHostedJoinGroupType(groupType),
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _usesSelfHostedJoin = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Provider.of<DefaultThemeData>(context).theme;
    final i18n = AppI18n.of(context);
    return Scaffold(
      appBar: AppBar(
        iconTheme: IconThemeData(
          color: theme.primaryColor ?? const Color(0xFF1E90FF),
        ),
        elevation: 0,
        backgroundColor: theme.primaryColor,
        title: Text(
          i18n.t(
            zhHans: '进群申请列表',
            zhHant: '進群申請列表',
            en: 'Join Requests',
            ja: '参加申請一覧',
            ko: '가입 신청 목록',
          ),
          style: const TextStyle(
            color: Colors.white,
            fontSize: 17,
          ),
        ),
      ),
      body: _usesSelfHostedJoin == null
          ? const Center(child: CircularProgressIndicator())
          : _usesSelfHostedJoin!
              ? GroupSelfHostedJoinApplicationListPage(
                  groupId: widget.groupID,
                )
              : TIMUIKitGroupApplicationList(groupID: widget.groupID),
    );
  }
}
