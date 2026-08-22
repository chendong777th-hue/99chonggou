import 'package:flutter/material.dart';
import 'package:loading_animation_widget/loading_animation_widget.dart';
import 'package:tencent_chat_i18n_tool/tencent_chat_i18n_tool.dart';
import 'package:tencent_cloud_chat_sdk/enum/group_member_filter_enum.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_group_member_full_info.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_group_member_full_info.dart';
import 'package:tencent_cloud_chat_uikit/base_widgets/tim_ui_kit_state.dart';
import 'package:tencent_cloud_chat_uikit/data_services/group/group_services.dart';
import 'package:tencent_cloud_chat_uikit/data_services/services_locatar.dart';
import 'package:tencent_cloud_chat_uikit/tencent_cloud_chat_uikit.dart';

import 'package:tencent_cloud_chat_uikit/ui/utils/platform.dart';
import 'package:tencent_cloud_chat_uikit/ui/views/TIMUIKitGroupProfile/widgets/tim_ui_group_member_search.dart';
import 'package:tencent_cloud_chat_uikit/ui/views/TIMUIKitSearch/conversation_search_utils.dart';
import 'package:tencent_cloud_chat_uikit/ui/widgets/group_member_list.dart';
import 'package:tencent_cloud_chat_uikit/base_widgets/tim_ui_kit_base.dart';

import 'package:tencent_cloud_chat_uikit/theme/tui_theme.dart';

class SelectCallInviter extends StatefulWidget {
  final String? groupID;
  const SelectCallInviter({
    this.groupID,
    Key? key,
  }) : super(key: key);

  @override
  State<StatefulWidget> createState() => _SelectCallInviterState();
}

class _SelectCallInviterState extends TIMUIKitState<SelectCallInviter> {
  final CoreServicesImpl _coreServicesImpl = serviceLocator<CoreServicesImpl>();
  final GroupServices _groupServices = serviceLocator<GroupServices>();
  List<V2TimGroupMemberFullInfo> selectedMember = [];
  List<V2TimGroupMemberFullInfo?> _groupMemberList = [];
  String _groupMemberListSeq = "0";
  String _keyword = '';
  bool loading = true;
  bool _loadingMore = false;

  bool get _hasMoreMembers {
    final seq = _groupMemberListSeq.trim();
    return seq.isNotEmpty && seq != '0';
  }

  @override
  void initState() {
    super.initState();
    if (widget.groupID != null) {
      _loadGroupMemberList(groupID: widget.groupID!);
    }
  }

  void _handleSearchText(String text) {
    final next = text.trim().toLowerCase();
    if (next == _keyword) {
      return;
    }
    setState(() => _keyword = next);
  }

  List<V2TimGroupMemberFullInfo?> _visibleMembers() {
    final selfId = _coreServicesImpl.loginInfo.userID;
    final base = _groupMemberList
        .where((element) => element?.userID != selfId)
        .toList();
    return filterGroupMembersByKeyword(base, _keyword);
  }

  /// 只拉一页；禁止递归整表。
  Future<void> _loadGroupMemberList(
      {required String groupID, int count = 100, String? seq}) async {
    final isFirst = seq == null || seq == "" || seq == "0";
    if (isFirst) {
      _groupMemberList = [];
      if (mounted) {
        setState(() => loading = true);
      }
    }
    await _loadGroupMemberListFunction(
        groupID: groupID, seq: seq, count: count);
    if (mounted) {
      setState(() {
        loading = false;
      });
    }
  }

  Future<void> _loadMoreMembers() async {
    final groupID = widget.groupID;
    if (groupID == null ||
        !_hasMoreMembers ||
        _loadingMore ||
        loading ||
        _keyword.isNotEmpty) {
      return;
    }
    _loadingMore = true;
    try {
      await _loadGroupMemberList(
        groupID: groupID,
        seq: _groupMemberListSeq,
      );
    } finally {
      _loadingMore = false;
    }
  }

  Future<String?> _loadGroupMemberListFunction(
      {required String groupID, int count = 100, String? seq}) async {
    final res = await _groupServices.getGroupMemberList(
        groupID: widget.groupID!,
        filter: GroupMemberFilterTypeEnum.V2TIM_GROUP_MEMBER_FILTER_ALL,
        count: count,
        nextSeq: seq ?? _groupMemberListSeq);
    final groupMemberListRes = res.data;
    if (res.code == 0 && groupMemberListRes != null) {
      final groupMemberListTemp = groupMemberListRes.memberInfoList ?? [];
      final isFirst = seq == null || seq == "" || seq == "0";
      if (isFirst) {
        _groupMemberList = List<V2TimGroupMemberFullInfo?>.from(
          groupMemberListTemp,
        );
      } else {
        final existing = _groupMemberList
            .map((e) => e?.userID)
            .whereType<String>()
            .toSet();
        final appended = groupMemberListTemp
            .where((m) => !existing.contains(m.userID.trim()))
            .toList(growable: false);
        _groupMemberList = [..._groupMemberList, ...appended];
      }
      _groupMemberListSeq = groupMemberListRes.nextSeq ?? "0";
      if (mounted) {
        setState(() {});
      }
    }
    return groupMemberListRes?.nextSeq;
  }

  @override
  Widget tuiBuild(BuildContext context, TUIKitBuildValue value) {
    final TUITheme theme = value.theme;
    final visibleMembers = _visibleMembers();

    return Scaffold(
        appBar: AppBar(
          shadowColor: theme.weakBackgroundColor,
          iconTheme: IconThemeData(
            color: theme.appbarTextColor,
          ),
          backgroundColor: theme.appbarBgColor ?? theme.primaryColor,
          leading: TextButton(
            onPressed: () {
              Navigator.pop(context);
            },
            child: Text(
              TIM_t("取消"),
              style: TextStyle(
                color: theme.appbarTextColor,
                fontSize: 14,
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                if (selectedMember.isNotEmpty) {
                  Navigator.pop(context, selectedMember);
                }
              },
              child: Text(
                TIM_t("完成"),
                style: TextStyle(
                  color: theme.appbarTextColor,
                  fontSize: 14,
                ),
              ),
            )
          ],
          centerTitle: true,
          leadingWidth: 80,
          title: Text(
            TIM_t("发起呼叫"),
            style: TextStyle(
              color: theme.appbarTextColor,
              fontSize: 17,
            ),
          ),
        ),
        body: (!loading && visibleMembers.isEmpty)
            ? Center(
                child: Text(
                  TIM_t("暂无群成员"),
                  style: TextStyle(color: theme.darkTextColor),
                ),
              )
            : loading
                ? Center(
                    child: LoadingAnimationWidget.staggeredDotsWave(
                      color: theme.primaryColor ?? Colors.grey,
                      size: 40,
                    ),
                  )
                : GroupProfileMemberList(
                    customTopArea: PlatformUtils().isWeb
                        ? null
                        : GroupMemberSearchTextField(
                            onTextChange: _handleSearchText,
                          ),
                    memberList: visibleMembers,
                    canSlideDelete: false,
                    canSelectMember: true,
                    touchBottomCallBack: _loadMoreMembers,
                    onSelectedMemberChange: (member) {
                      selectedMember = member;
                      setState(() {});
                    },
                  ));
  }
}
