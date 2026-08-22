import 'dart:async' show unawaited;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:tencent_chat_i18n_tool/tencent_chat_i18n_tool.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_group_member_full_info.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_group_member_full_info.dart';
import 'package:tencent_cloud_chat_uikit/base_widgets/tim_ui_kit_base.dart';
import 'package:tencent_cloud_chat_uikit/base_widgets/tim_ui_kit_state.dart';
import 'package:tencent_cloud_chat_uikit/business_logic/separate_models/tui_group_profile_model.dart';
import 'package:tencent_cloud_chat_uikit/data_services/group/group_member_feedback_bridge.dart';
import 'package:tencent_cloud_chat_uikit/data_services/group/self_hosted_group_kick_bridge.dart';
import 'package:tencent_cloud_chat_uikit/ui/utils/group_role_policy.dart';
import 'package:tencent_cloud_chat_uikit/ui/utils/screen_utils.dart';
import 'package:tencent_cloud_chat_uikit/ui/views/TIMUIKitGroupProfile/group_member/group_member_picker_search_bar.dart';
import 'package:tencent_cloud_chat_uikit/ui/views/TIMUIKitSearch/conversation_search_utils.dart';
import 'package:tencent_cloud_chat_uikit/ui/widgets/group_member_list.dart';
import 'package:tencent_cloud_chat_uikit/ui/widgets/contact_list.dart';
import 'package:tencent_cloud_chat_uikit/theme/tui_theme.dart';

GlobalKey<DeleteGroupMemberPageState> deleteGroupMemberKey = GlobalKey();

class DeleteGroupMemberPage extends StatefulWidget {
  final TUIGroupProfileModel model;
  final VoidCallback? onClose;
  final MemberPresenceLabelBuilder? presenceLabelBuilder;
  final MemberPresenceLoadingChecker? presenceLoadingChecker;
  final void Function(List<String> userIds)? onMemberListLoaded;
  final Listenable? presenceListenable;

  const DeleteGroupMemberPage({
    Key? key,
    required this.model,
    this.onClose,
    this.presenceLabelBuilder,
    this.presenceLoadingChecker,
    this.onMemberListLoaded,
    this.presenceListenable,
  }) : super(key: key);

  @override
  State<StatefulWidget> createState() => DeleteGroupMemberPageState();
}

class DeleteGroupMemberPageState extends TIMUIKitState<DeleteGroupMemberPage> {
  List<V2TimGroupMemberFullInfo> selectedGroupMember = [];
  final TextEditingController _searchController = TextEditingController();
  String _keyword = '';
  bool _submitting = false;
  List<V2TimGroupMemberFullInfo?> _deletableMembersCache =
      const <V2TimGroupMemberFullInfo?>[];
  List<V2TimGroupMemberFullInfo?>? _sourceMemberListRef;
  int? _selfRoleCache;

  void _safeSetState(VoidCallback fn) {
    if (!mounted) {
      return;
    }
    if (SchedulerBinding.instance.schedulerPhase == SchedulerPhase.idle) {
      setState(fn);
      return;
    }
    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        setState(fn);
      }
    });
  }

  /// 群主可踢普通成员与管理员；管理员只能踢普通成员；群主本人不可被踢。
  bool _isDeletableBySelf(V2TimGroupMemberFullInfo member, int? selfRole) {
    return GroupRolePolicy.canKickTargetMember(
      selfRole: selfRole,
      targetRole: member.role,
    );
  }

  void _syncDeletableMembersCache() {
    if (_submitting && _deletableMembersCache.isNotEmpty) {
      return;
    }
    final source = widget.model.groupMemberList;
    final selfRole = widget.model.groupInfo?.role;
    if (identical(_sourceMemberListRef, source) &&
        _selfRoleCache == selfRole &&
        _deletableMembersCache.isNotEmpty) {
      return;
    }
    _sourceMemberListRef = source;
    _selfRoleCache = selfRole;
    final seen = <String>{};
    final members = <V2TimGroupMemberFullInfo?>[];
    for (final member in source) {
      if (member == null || !_isDeletableBySelf(member, selfRole)) {
        continue;
      }
      final userId = member.userID.trim();
      if (userId.isEmpty || seen.contains(userId)) {
        continue;
      }
      seen.add(userId);
      members.add(member);
    }
    _deletableMembersCache = members;
  }

  bool _sameSelectedMembers(List<V2TimGroupMemberFullInfo> next) {
    if (next.length != selectedGroupMember.length) {
      return false;
    }
    for (var i = 0; i < next.length; i++) {
      if (next[i].userID != selectedGroupMember[i].userID) {
        return false;
      }
    }
    return true;
  }

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      final next = _searchController.text.trim().toLowerCase();
      if (next == _keyword) return;
      _safeSetState(() => _keyword = next);
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<V2TimGroupMemberFullInfo?> _filteredMembers() {
    _syncDeletableMembersCache();
    return filterGroupMembersByKeyword(_deletableMembersCache, _keyword);
  }

  Widget _pickerBody(TUITheme theme) {
    final members = _filteredMembers();
    return AbsorbPointer(
      absorbing: _submitting,
      child: Column(
        children: [
          GroupMemberPickerSearchBar(
            controller: _searchController,
            keyword: _keyword,
            onClear: _searchController.clear,
          ),
          Expanded(
            child: GroupProfileMemberList(
              memberList: members,
              canSelectMember: true,
              canSlideDelete: false,
              isShowIndexBar: false,
              maxSelectNum: kContactListMaxGroupSelection,
              presenceLabelBuilder: widget.presenceLabelBuilder,
              presenceLoadingChecker: widget.presenceLoadingChecker,
              presenceListenable: widget.presenceListenable,
              onMemberListLoaded: widget.onMemberListLoaded,
              onSelectedMemberChange: (selectedMember) {
                if (_sameSelectedMembers(selectedMember)) {
                  return;
                }
                setState(() => selectedGroupMember = selectedMember);
              },
              touchBottomCallBack: () {
                if (_keyword.isNotEmpty ||
                    !widget.model.hasMoreGroupMembers ||
                    widget.model.isGroupMemberListLoadingMore) {
                  return;
                }
                unawaited(widget.model.loadMoreGroupMembers());
              },
            ),
          ),
        ],
      ),
    );
  }

  void _invalidateMemberCache() {
    _sourceMemberListRef = null;
    _selfRoleCache = null;
    _deletableMembersCache = const <V2TimGroupMemberFullInfo?>[];
  }

  Future<void> _closePage() async {
    if (widget.onClose != null) {
      widget.onClose!();
      return;
    }
    if (mounted) {
      await Navigator.maybePop(context, true);
    }
  }

  Future<void> submitDelete() async {
    if (_submitting) {
      return;
    }
    if (selectedGroupMember.isEmpty) {
      GroupMemberFeedbackBridge.show(TIM_t('请选择成员'));
      return;
    }
    setState(() => _submitting = true);
    try {
      final userIDs = selectedGroupMember
          .map((e) => e.userID.trim())
          .where((e) => e.isNotEmpty)
          .toList(growable: false);
      final res = await widget.model.kickOffMember(userIDs);
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
        _invalidateMemberCache();
        setState(() {
          _submitting = false;
          selectedGroupMember = const <V2TimGroupMemberFullInfo>[];
        });
        return;
      }
      final partialSuccess =
          res.desc?.trim().toUpperCase() == 'PARTIAL_SUCCESS';
      GroupMemberFeedbackBridge.show(
        SelfHostedGroupKickBridge.formatMessage(
          success: true,
          desc: partialSuccess ? res.desc : null,
        ),
      );
      await _closePage();
    } catch (_) {
      if (!mounted) {
        return;
      }
      GroupMemberFeedbackBridge.show(
        SelfHostedGroupKickBridge.formatMessage(success: false),
      );
      _invalidateMemberCache();
      setState(() {
        _submitting = false;
        selectedGroupMember = const <V2TimGroupMemberFullInfo>[];
      });
    }
  }

  Widget _confirmButton(TUITheme theme) {
    return TextButton(
      onPressed: _submitting ? null : submitDelete,
      child: _submitting
          ? SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: theme.appbarTextColor,
              ),
            )
          : Text(
              TIM_t("确定"),
              style: TextStyle(
                color: theme.appbarTextColor,
                fontSize: 16,
              ),
            ),
    );
  }

  @override
  Widget tuiBuild(BuildContext context, TUIKitBuildValue value) {
    final theme = value.theme;

    return TUIKitScreenUtils.getDeviceWidget(
        context: context,
        desktopWidget: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: _pickerBody(theme),
        ),
        defaultWidget: Scaffold(
            appBar: AppBar(
                title: Text(
                  TIM_t("删除群成员"),
                  style: TextStyle(color: theme.appbarTextColor, fontSize: 17),
                ),
                actions: [
                  _confirmButton(theme),
                ],
                shadowColor: theme.weakDividerColor,
                backgroundColor: theme.appbarBgColor ?? theme.primaryColor,
                iconTheme: IconThemeData(
                  color: theme.appbarTextColor,
                )),
            body: _pickerBody(theme)));
  }
}
