import 'dart:async' show unawaited;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:tencent_chat_i18n_tool/tencent_chat_i18n_tool.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_friend_info.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_friend_info.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_group_member_operation_result.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_group_member_operation_result.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_value_callback.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_value_callback.dart';
import 'package:tencent_cloud_chat_uikit/base_widgets/tim_ui_kit_base.dart';
import 'package:tencent_cloud_chat_uikit/base_widgets/tim_ui_kit_state.dart';
import 'package:tencent_cloud_chat_uikit/business_logic/separate_models/tui_group_profile_model.dart';
import 'package:tencent_cloud_chat_uikit/data_services/group/group_member_feedback_bridge.dart';
import 'package:tencent_cloud_chat_uikit/data_services/group/self_hosted_group_invite_bridge.dart';
import 'package:tencent_cloud_chat_uikit/ui/utils/screen_utils.dart';
import 'package:tencent_cloud_chat_uikit/ui/views/TIMUIKitGroupProfile/group_member/group_member_picker_search_bar.dart';
import 'package:tencent_cloud_chat_uikit/ui/views/TIMUIKitSearch/conversation_search_utils.dart';
import 'package:tencent_cloud_chat_uikit/ui/widgets/contact_list.dart';
import 'package:tencent_cloud_chat_uikit/theme/tui_theme.dart';

GlobalKey<_AddGroupMemberPageState> addGroupMemberKey = GlobalKey();

class AddGroupMemberPage extends StatefulWidget {
  final TUIGroupProfileModel model;
  final VoidCallback? onClose;
  final MemberPresenceLabelBuilder? presenceLabelBuilder;
  final MemberPresenceLoadingChecker? presenceLoadingChecker;
  final void Function(List<String> userIds)? onContactListLoaded;
  final Listenable? presenceListenable;

  /// 邀请是否需要管理员审批（用于顶部提示条）。
  final Future<bool> Function()? inviteNeedsApprovalLoader;

  /// 本群「进群审核中」的好友 userId 集合。
  final Future<Set<String>> Function()? pendingReviewUserIdsLoader;

  /// 本群已在群成员 userId（应覆盖全量，不限 UI 分页首屏）。
  final Future<Set<String>> Function()? existingMemberUserIdsLoader;

  const AddGroupMemberPage({
    Key? key,
    required this.model,
    this.onClose,
    this.presenceLabelBuilder,
    this.presenceLoadingChecker,
    this.onContactListLoaded,
    this.presenceListenable,
    this.inviteNeedsApprovalLoader,
    this.pendingReviewUserIdsLoader,
    this.existingMemberUserIdsLoader,
  }) : super(key: key);

  @override
  State<StatefulWidget> createState() => _AddGroupMemberPageState();
}

class _AddGroupMemberPageState extends TIMUIKitState<AddGroupMemberPage> {
  final GlobalKey<ContactListState> _contactListKey =
      GlobalKey<ContactListState>();
  List<V2TimFriendInfo> selectedContacts = [];
  final TextEditingController _searchController = TextEditingController();
  String _keyword = '';
  bool _submitting = false;
  bool _showApprovalHint = false;
  bool _approvalHintDismissed = false;
  /// 邀请禁选元数据（全量已在群/审核中等）就绪前只展示骨架，避免列表先亮再灰闪一下。
  bool _inviteMetaReady = false;
  Set<String> _pendingReviewUserIds = <String>{};
  Set<String> _existingMemberUserIds = <String>{};

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

  @override
  void initState() {
    super.initState();
    _existingMemberUserIds = {
      for (final member in widget.model.groupMemberList)
        if ((member?.userID ?? '').trim().isNotEmpty) member!.userID.trim(),
    };
    _searchController.addListener(() {
      final next = _searchController.text.trim().toLowerCase();
      if (next == _keyword) return;
      _safeSetState(() => _keyword = next);
    });
    final hasInviteMetaLoaders = widget.inviteNeedsApprovalLoader != null ||
        widget.pendingReviewUserIdsLoader != null ||
        widget.existingMemberUserIdsLoader != null;
    if (!hasInviteMetaLoaders) {
      _inviteMetaReady = true;
      return;
    }
    unawaited(_loadInviteMeta());
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadInviteMeta() async {
    final needsApprovalLoader = widget.inviteNeedsApprovalLoader;
    final pendingLoader = widget.pendingReviewUserIdsLoader;
    final existingLoader = widget.existingMemberUserIdsLoader;
    bool needsApproval = false;
    Set<String> pending = const <String>{};
    Set<String> existing = const <String>{};
    try {
      try {
        if (needsApprovalLoader != null) {
          needsApproval = await needsApprovalLoader();
        }
      } catch (_) {}
      try {
        if (existingLoader != null) {
          existing = await existingLoader();
        }
      } catch (_) {}
      try {
        if (pendingLoader != null) {
          pending = await pendingLoader();
        }
      } catch (_) {}
    } finally {
      if (mounted) {
        final mergedExisting = <String>{
          ..._existingMemberUserIds,
          ...existing.map((id) => id.trim()).where((id) => id.isNotEmpty),
        };
        _safeSetState(() {
          _showApprovalHint = needsApproval && !_approvalHintDismissed;
          _existingMemberUserIds = mergedExisting;
          _pendingReviewUserIds =
              pending.map((id) => id.trim()).where((id) => id.isNotEmpty).toSet()
                ..removeWhere(mergedExisting.contains);
          // 失败也放行：用首屏种子禁选，避免永久骨架。
          _inviteMetaReady = true;
        });
      }
    }
  }

  List<V2TimFriendInfo> _filteredContacts() {
    return filterFriendsByKeyword(widget.model.contactList, _keyword);
  }

  bool _isPendingReviewUser(String userId) {
    final id = userId.trim();
    if (id.isEmpty || _pendingReviewUserIds.isEmpty) {
      return false;
    }
    if (_pendingReviewUserIds.contains(id)) {
      return true;
    }
    for (final pending in _pendingReviewUserIds) {
      if (pending == id || id.endsWith(pending) || pending.endsWith(id)) {
        return true;
      }
    }
    return false;
  }

  bool _isExistingMemberUser(String userId) {
    final id = userId.trim();
    if (id.isEmpty || _existingMemberUserIds.isEmpty) {
      return false;
    }
    if (_existingMemberUserIds.contains(id)) {
      return true;
    }
    for (final member in _existingMemberUserIds) {
      final mid = member.trim();
      if (mid == id || id.endsWith(mid) || mid.endsWith(id)) {
        return true;
      }
    }
    return false;
  }

  bool get _allSelectableSelected =>
      _contactListKey.currentState?.areAllSelectableSelected ?? false;

  void _toggleSelectAll() {
    final state = _contactListKey.currentState;
    if (state == null) {
      return;
    }
    if (state.areAllSelectableSelected) {
      state.clearSelection();
    } else {
      state.selectAllSelectable();
    }
    _safeSetState(() {});
  }

  Widget _approvalHintBanner(TUITheme theme) {
    if (!_showApprovalHint) {
      return const SizedBox.shrink();
    }
    final bg = theme.weakBackgroundColor ?? const Color(0xFFF5F6F8);
    final textColor = theme.weakTextColor ?? const Color(0xFF666666);
    return Container(
      width: double.infinity,
      color: bg,
      padding: const EdgeInsets.fromLTRB(16, 10, 8, 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(
              TIM_t('当前群聊开启了入群需审核，对方同意入群后需群主审核通过才能入群'),
              style: TextStyle(
                color: textColor,
                fontSize: 13,
                height: 1.35,
              ),
            ),
          ),
          IconButton(
            visualDensity: VisualDensity.compact,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            onPressed: () {
              _safeSetState(() {
                _approvalHintDismissed = true;
                _showApprovalHint = false;
              });
            },
            icon: Icon(
              Icons.close,
              size: 18,
              color: textColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _searchBox(TUITheme theme) {
    final selectAllLabel = _allSelectableSelected ? TIM_t('取消全选') : TIM_t('全选');
    final searchEnabled = _inviteMetaReady && !_submitting;
    return IgnorePointer(
      ignoring: !searchEnabled,
      child: Opacity(
        opacity: searchEnabled ? 1 : 0.45,
        child: GroupMemberPickerSearchBar(
          controller: _searchController,
          keyword: _keyword,
          onClear: _searchController.clear,
          trailing: TextButton(
            onPressed: searchEnabled ? _toggleSelectAll : null,
            child: Text(
              selectAllLabel,
              style: TextStyle(
                color: theme.primaryColor ?? const Color(0xFF1E90FF),
                fontSize: 15,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _inviteContactListSkeleton(TUITheme theme) {
    final bar = (theme.weakTextColor ?? const Color(0xFF999999))
        .withValues(alpha: 0.22);
    final divider = theme.weakDividerColor ?? const Color(0xFFE7E7E7);
    return ListView.separated(
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(vertical: 4),
      itemCount: 10,
      separatorBuilder: (_, __) => Divider(
        height: 1,
        thickness: 0.5,
        indent: 72,
        color: divider,
      ),
      itemBuilder: (_, __) {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: bar,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 120,
                      height: 12,
                      decoration: BoxDecoration(
                        color: bar,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      width: 72,
                      height: 10,
                      decoration: BoxDecoration(
                        color: bar,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _contactList(TUITheme theme) {
    return ContactList(
      key: _contactListKey,
      bgColor: theme.wideBackgroundColor,
      groupMemberList: widget.model.groupMemberList,
      contactList: _filteredContacts(),
      selectionContactList: widget.model.contactList,
      isCanSelectMemberItem: true,
      maxSelectNum: kContactListMaxGroupSelection,
      isShowOnlineStatus: widget.presenceLabelBuilder != null,
      presenceLabelBuilder: widget.presenceLabelBuilder,
      presenceLoadingChecker: widget.presenceLoadingChecker,
      presenceListenable: widget.presenceListenable,
      onContactListLoaded: widget.onContactListLoaded,
      disabledUserIds: {
        ..._existingMemberUserIds,
        for (final friend in widget.model.contactList)
          if (_isPendingReviewUser(friend.userID)) friend.userID.trim(),
        ..._pendingReviewUserIds,
      },
      trailingStatusLabelBuilder: (userId) {
        if (_isExistingMemberUser(userId)) {
          return TIM_t('已在群内');
        }
        if (!_isPendingReviewUser(userId)) {
          return null;
        }
        return TIM_t('进群审核中');
      },
      onSelectedMemberItemChange: (selectedMember) {
        _safeSetState(() => selectedContacts = selectedMember);
      },
    );
  }

  Future<void> submitAdd() async {
    if (_submitting || selectedContacts.isEmpty) {
      return;
    }
    setState(() => _submitting = true);
    try {
      final userIDs = selectedContacts.map((e) => e.userID).toList();
      // ignore: avoid_print
      print(
        '[GroupInviteDiag] UI submitAdd groupId=${widget.model.groupID} '
        'userIDs=$userIDs',
      );
      final res = await widget.model.inviteUserToGroup(userIDs);
      if (!mounted) {
        return;
      }
      // ignore: avoid_print
      print(
        '[GroupInviteDiag] UI invite result code=${res.code} desc=${res.desc} '
        'data=${(res.data ?? const <V2TimGroupMemberOperationResult>[]).map((e) => '${e.memberID}:${e.result}').join(',')}',
      );
      if (res.code != 0) {
        GroupMemberFeedbackBridge.show(
          SelfHostedGroupInviteBridge.formatInviteResultMessage(
            code: res.code,
            desc: res.desc,
          ),
        );
        return;
      }
      final results = res.data ?? const <V2TimGroupMemberOperationResult>[];
      final failed = results.where((item) => (item.result ?? 0) == 0).length;
      if (failed > 0) {
        // ignore: avoid_print
        print('[GroupInviteDiag] UI toast branch=PARTIAL_SUCCESS');
        GroupMemberFeedbackBridge.show(
          SelfHostedGroupInviteBridge.formatInviteResultMessage(
            code: 0,
            desc: res.desc ?? 'PARTIAL_SUCCESS',
          ),
        );
        await _refreshPendingAfterInvite(results);
        return;
      }
      final hasPending = results.any((item) => item.result == 3) ||
          (res.desc?.toUpperCase().contains('PENDING') ?? false);
      if (SelfHostedGroupInviteBridge.enabled && hasPending) {
        // ignore: avoid_print
        print('[GroupInviteDiag] UI toast branch=PENDING_APPROVAL');
        GroupMemberFeedbackBridge.show(
          SelfHostedGroupInviteBridge.formatInviteResultMessage(
            code: 0,
            desc: res.desc ?? 'PENDING_APPROVAL',
          ),
        );
        await _refreshPendingAfterInvite(results);
        return;
      }
      final alreadyCount =
          results.where((item) => item.result == 2).length;
      final addedCount = results.where((item) => item.result == 1).length;
      if (results.isNotEmpty && alreadyCount == results.length) {
        // ignore: avoid_print
        print('[GroupInviteDiag] UI toast branch=ALREADY_MEMBER');
        GroupMemberFeedbackBridge.show(
          SelfHostedGroupInviteBridge.formatInviteResultMessage(
            code: 0,
            desc: res.desc ?? 'ALREADY_MEMBER',
          ),
        );
        if (mounted) {
          (widget.onClose ?? () => Navigator.pop(context))();
        }
        unawaited(_refreshMembersAfterInvite(res));
        return;
      }
      if (alreadyCount > 0 && addedCount > 0) {
        // ignore: avoid_print
        print('[GroupInviteDiag] UI toast branch=ALREADY_MEMBER_PARTIAL');
        GroupMemberFeedbackBridge.show(
          SelfHostedGroupInviteBridge.formatInviteResultMessage(
            code: 0,
            desc: res.desc ?? 'ALREADY_MEMBER_PARTIAL',
          ),
        );
        if (mounted) {
          (widget.onClose ?? () => Navigator.pop(context))();
        }
        unawaited(_refreshMembersAfterInvite(res));
        return;
      }
      // ignore: avoid_print
      print('[GroupInviteDiag] UI toast branch=SUCCESS_ADDED');
      GroupMemberFeedbackBridge.show(
        SelfHostedGroupInviteBridge.formatInviteSuccessMessage(),
      );
      // 先关页；成员增量由 GroupMemberApi 热路径完成，禁止此处 await 整表 reload。
      if (mounted) {
        (widget.onClose ?? () => Navigator.pop(context))();
      }
      unawaited(_refreshMembersAfterInvite(res));
    } finally {
      if (mounted) {
        setState(() => _submitting = false);
      }
    }
  }

  Future<void> _refreshPendingAfterInvite(
    List<V2TimGroupMemberOperationResult> results,
  ) async {
    final pendingFromResult = results
        .where((item) => item.result == 3)
        .map((item) => item.memberID?.trim() ?? '')
        .where((id) => id.isNotEmpty)
        .toSet();
    final fallbackPending = pendingFromResult.isEmpty
        ? selectedContacts
            .map((item) => item.userID.trim())
            .where((id) => id.isNotEmpty)
            .toSet()
        : pendingFromResult;

    Set<String> pending = Set<String>.from(_pendingReviewUserIds)
      ..addAll(fallbackPending);
    try {
      final loader = widget.pendingReviewUserIdsLoader;
      if (loader != null) {
        // 以服务端申请列表为准重新拉取。
        pending = await loader();
      }
    } catch (_) {}
    if (!mounted) {
      return;
    }
    _contactListKey.currentState?.clearSelection();
    _safeSetState(() {
      _pendingReviewUserIds = pending;
      selectedContacts = const [];
    });
  }

  Widget _confirmButton(TUITheme theme) {
    final enabled = !_submitting && selectedContacts.isNotEmpty;
    final color = enabled
        ? (theme.appbarTextColor ?? theme.darkTextColor ?? Colors.black)
        : (theme.weakTextColor ?? const Color(0xFFB0B0B0));
    return TextButton(
      onPressed: enabled ? submitAdd : null,
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
                color: color,
                fontSize: 16,
              ),
            ),
    );
  }

  Future<void> _refreshMembersAfterInvite(
    V2TimValueCallback<List<V2TimGroupMemberOperationResult>> res,
  ) async {
    final hasDirectAdd = (res.data ?? const <V2TimGroupMemberOperationResult>[])
        .any((item) => item.result == 1);
    if (!hasDirectAdd) {
      return;
    }
    final groupId = widget.model.groupInfo?.groupID?.trim() ?? '';
    if (groupId.isEmpty) {
      return;
    }
    // 仅刷新群资料人数；成员壳已由 invite API 增量写入，禁止 reloadGroupMembers 整表。
    await widget.model.loadGroupInfo(groupId);
  }

  Widget _body(TUITheme theme) {
    return AbsorbPointer(
      absorbing: _submitting,
      child: Column(
        children: [
          _approvalHintBanner(theme),
          _searchBox(theme),
          Expanded(
            child: _inviteMetaReady
                ? _contactList(theme)
                : _inviteContactListSkeleton(theme),
          ),
        ],
      ),
    );
  }

  @override
  Widget tuiBuild(BuildContext context, TUIKitBuildValue value) {
    final TUITheme theme = value.theme;

    return TUIKitScreenUtils.getDeviceWidget(
      context: context,
      desktopWidget: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: _body(theme),
      ),
      defaultWidget: Scaffold(
        appBar: AppBar(
          title: Text(
            TIM_t("选择联系人"),
            style: TextStyle(color: theme.appbarTextColor, fontSize: 17),
          ),
          actions: [
            _confirmButton(theme),
          ],
          shadowColor: theme.weakDividerColor,
          backgroundColor: theme.appbarBgColor ?? theme.primaryColor,
          iconTheme: IconThemeData(
            color: theme.appbarTextColor,
          ),
        ),
        body: _body(theme),
      ),
    );
  }
}
