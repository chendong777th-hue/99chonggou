// ignore_for_file: must_be_immutable

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tencent_chat_i18n_tool/tencent_chat_i18n_tool.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_group_member_full_info.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_group_member_full_info.dart';
import 'package:tencent_cloud_chat_uikit/ui/utils/screen_utils.dart';
import 'package:tencent_cloud_chat_uikit/base_widgets/tim_ui_kit_base.dart';
import 'package:tencent_cloud_chat_uikit/base_widgets/tim_ui_kit_state.dart';
import 'package:tencent_cloud_chat_uikit/data_services/group/group_member_feedback_bridge.dart';
import 'package:tencent_cloud_chat_uikit/data_services/group/self_hosted_group_kick_bridge.dart';
import 'package:tencent_cloud_chat_uikit/business_logic/separate_models/tui_group_profile_model.dart';
import 'package:tencent_cloud_chat_uikit/ui/views/TIMUIKitGroupProfile/widgets/tim_ui_group_member_search.dart';
import 'package:tencent_cloud_chat_uikit/ui/views/TIMUIKitSearch/conversation_search_utils.dart';
import 'package:tencent_cloud_chat_uikit/ui/widgets/group_member_list.dart';

import '../../../../theme/tui_theme.dart';

class GroupProfileMemberListPage extends StatefulWidget {
  List<V2TimGroupMemberFullInfo?> memberList;
  TUIGroupProfileModel model;
  final MemberPresenceLabelBuilder? presenceLabelBuilder;
  final MemberPresenceLoadingChecker? presenceLoadingChecker;
  final void Function(List<String> userIds)? onMemberListLoaded;
  final Listenable? presenceListenable;

  GroupProfileMemberListPage({
    Key? key,
    required this.memberList,
    required this.model,
    this.presenceLabelBuilder,
    this.presenceLoadingChecker,
    this.onMemberListLoaded,
    this.presenceListenable,
  }) : super(key: key);

  @override
  State<StatefulWidget> createState() => GroupProfileMemberListPageState();
}

class GroupProfileMemberListPageState
    extends TIMUIKitState<GroupProfileMemberListPage> {
  String _keyword = '';
  bool _loadMoreInFlight = false;

  @override
  void initState() {
    super.initState();
    // 打开页只保证第一页；禁止在此递归整表。
    final groupId = widget.model.groupID.trim();
    if (groupId.isNotEmpty && widget.model.groupMemberList.isEmpty) {
      widget.model.loadGroupMemberList(groupID: groupId);
    }
  }

  Future<void> _kickedOffMember(String userID) async {
    final res = await widget.model.kickOffMember([userID]);
    if (!mounted) {
      return;
    }
    if (res.code != 0) {
      GroupMemberFeedbackBridge.show(
        SelfHostedGroupKickBridge.formatMessage(
          success: false,
          code: res.code,
          desc: res.desc,
        ),
      );
      return;
    }
    GroupMemberFeedbackBridge.show(
      SelfHostedGroupKickBridge.formatMessage(success: true),
    );
  }

  void _handleSearchText(String text) {
    final next = text.trim().toLowerCase();
    if (next == _keyword) {
      return;
    }
    setState(() => _keyword = next);
  }

  List<V2TimGroupMemberFullInfo?> _visibleMembers(
    List<V2TimGroupMemberFullInfo?> source,
  ) {
    return filterGroupMembersByKeyword(source, _keyword);
  }

  Future<void> _onReachBottom() async {
    if (_loadMoreInFlight ||
        _keyword.isNotEmpty ||
        !widget.model.hasMoreGroupMembers ||
        widget.model.isGroupMemberListLoadingMore) {
      return;
    }
    _loadMoreInFlight = true;
    try {
      await widget.model.loadMoreGroupMembers();
    } finally {
      _loadMoreInFlight = false;
    }
  }

  Widget _memberBody({
    required TUITheme theme,
    required List<V2TimGroupMemberFullInfo?> members,
  }) {
    return GroupProfileMemberList(
      customTopArea: GroupMemberSearchTextField(
        onTextChange: _handleSearchText,
      ),
      memberList: members,
      removeMember: _kickedOffMember,
      touchBottomCallBack: _onReachBottom,
      isShowIndexBar: false,
      presenceLabelBuilder: widget.presenceLabelBuilder,
      presenceLoadingChecker: widget.presenceLoadingChecker,
      onMemberListLoaded: widget.onMemberListLoaded,
      presenceListenable: widget.presenceListenable,
      emptyBuilder: _keyword.isEmpty
          ? null
          : (context) => Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Text(
                    TIM_t("无匹配成员"),
                    style: TextStyle(
                      fontSize: 13,
                      color: theme.weakTextColor ?? const Color(0xFF9CA3AF),
                    ),
                  ),
                ),
              ),
      onTapMemberItem: (memberInfo, details) {
        if (widget.model.onClickUser != null) {
          widget.model.onClickUser!(memberInfo, details);
        }
      },
    );
  }

  @override
  Widget tuiBuild(BuildContext context, TUIKitBuildValue value) {
    final TUITheme theme = value.theme;
    final isDesktopScreen =
        TUIKitScreenUtils.getFormFactor() == DeviceType.Desktop;
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: widget.model),
      ],
      builder: (BuildContext context, Widget? w) {
        final TUIGroupProfileModel groupProfileModel =
            Provider.of<TUIGroupProfileModel>(context);
        final members = _visibleMembers(groupProfileModel.groupMemberList);
        String option1 = groupProfileModel.groupInfo?.memberCount.toString() ??
            widget.memberList.length.toString();
        if (isDesktopScreen) {
          return _memberBody(theme: theme, members: members);
        }
        return Scaffold(
          appBar: AppBar(
            title: Text(
              TIM_t_para("群成员({{option1}}人)", "群成员($option1人)")(
                  option1: option1),
              style: TextStyle(color: theme.appbarTextColor, fontSize: 17),
            ),
            shadowColor: theme.weakBackgroundColor,
            backgroundColor: theme.appbarBgColor ?? theme.primaryColor,
            iconTheme: IconThemeData(
              color: theme.primaryColor ?? const Color(0xFF1E90FF),
            ),
          ),
          body: _memberBody(theme: theme, members: members),
        );
      },
    );
  }
}
