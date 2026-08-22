import 'dart:async' show unawaited;

import 'package:flutter/material.dart';
import 'package:loading_animation_widget/loading_animation_widget.dart';
import 'package:tencent_chat_i18n_tool/tencent_chat_i18n_tool.dart';
import 'package:tencent_cloud_chat_sdk/enum/group_member_filter_enum.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_group_info.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_group_info.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_group_member_full_info.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_group_member_full_info.dart';
import 'package:tencent_cloud_chat_uikit/base_widgets/tim_ui_kit_state.dart';
import 'package:tencent_cloud_chat_uikit/business_logic/view_models/tui_self_info_view_model.dart';
import 'package:tencent_cloud_chat_uikit/business_logic/view_models/tui_chat_global_model.dart';
import 'package:tencent_cloud_chat_uikit/data_services/group/group_services.dart';
import 'package:tencent_cloud_chat_uikit/data_services/group/self_hosted_group_bridge.dart';
import 'package:tencent_cloud_chat_uikit/data_services/services_locatar.dart';
import 'package:tencent_cloud_chat_uikit/ui/utils/platform.dart';
import 'package:tencent_cloud_chat_uikit/ui/utils/screen_utils.dart';
import 'package:tencent_cloud_chat_uikit/ui/views/TIMUIKitGroupProfile/widgets/tim_ui_group_member_search.dart';
import 'package:tencent_cloud_chat_uikit/ui/views/TIMUIKitSearch/conversation_search_utils.dart';
import 'package:tencent_cloud_chat_uikit/ui/widgets/group_member_list.dart';
import 'package:tencent_cloud_chat_uikit/base_widgets/tim_ui_kit_base.dart';
import 'package:tencent_cloud_chat_uikit/theme/tui_theme.dart';

class AtText extends StatefulWidget {
  final String? groupID;
  final V2TimGroupInfo? groupInfo;
  final List<V2TimGroupMemberFullInfo?>? groupMemberList;

  /// 兼容旧入参；分页以本页网络返回的 nextSeq 为准，勿信会话 open-shell 的 seq=0。
  final String? initialNextSeq;
  final VoidCallback? closeFunc;
  final Function(List<V2TimGroupMemberFullInfo> memberInfo)? onChooseMember;
  final bool canAtAll;

  // some Group type cant @all
  final String? groupType;

  const AtText({
    this.groupID,
    this.groupType,
    Key? key,
    this.groupInfo,
    this.groupMemberList,
    this.initialNextSeq,
    this.closeFunc,
    this.onChooseMember,
    this.canAtAll = false,
  }) : super(key: key);

  @override
  State<StatefulWidget> createState() => _AtTextState();
}

class _AtTextState extends TIMUIKitState<AtText> {
  final TUISelfInfoViewModel _selfInfoViewModel =
      serviceLocator<TUISelfInfoViewModel>();
  final GroupServices _groupServices = serviceLocator<GroupServices>();

  List<V2TimGroupMemberFullInfo> selectedGroupMemberList = [];
  List<V2TimGroupMemberFullInfo?> _members = [];
  /// 仅由本页 getGroupMemberList 写入；勿用聊天 open-shell 的假 seq=0。
  String _nextSeq = '0';
  String _keyword = '';
  bool _loadingFirst = false;
  bool _loadingMore = false;

  bool get _hasMoreMembers {
    final seq = _nextSeq.trim();
    return seq.isNotEmpty && seq != '0';
  }

  @override
  void initState() {
    super.initState();
    // 瞬时种子（可能是 open-shell 残缺集）；正式窗口与群成员列表一致：seq=0 首页 + 触底续页。
    _members = List<V2TimGroupMemberFullInfo?>.from(
      widget.groupMemberList ?? const <V2TimGroupMemberFullInfo?>[],
    );
    // 忽略 initialNextSeq：open-shell 常把它留在 "0"，会误判「没有更多」。
    _nextSeq = '0';

    final gid = widget.groupID?.trim() ?? '';
    if (gid.isEmpty) {
      return;
    }
    unawaited(_bootstrapMemberWindow(gid));
  }

  /// 对齐群成员页：可选本地首窗 hydrate → 必拉网络第 1 页 → 自动翻完剩余页。
  Future<void> _bootstrapMemberWindow(String groupID) async {
    await _hydrateFromCache(groupID);
    if (!mounted) {
      return;
    }
    await _loadPage(groupID: groupID, seq: '0', isFirst: true);
    if (!mounted) {
      return;
    }
    await _drainRemainingPages(groupID);
  }

  /// 触底不可靠时仍保证名单完整；上限防死循环。
  Future<void> _drainRemainingPages(String groupID) async {
    var guard = 0;
    while (mounted && _hasMoreMembers && !_loadingMore && guard < 100) {
      guard++;
      await _loadMoreMembers();
    }
    // ignore: avoid_print
    print(
      '[AtMemberDiag] drain done pages=$guard total=${_members.length} '
      'nextSeq=$_nextSeq',
    );
  }

  Future<void> _hydrateFromCache(String groupID) async {
    if (!SelfHostedGroupBridge.enabled) {
      return;
    }
    try {
      final cached =
          await SelfHostedGroupBridge.loadCachedGroupMemberList(groupID);
      if (!mounted || cached.isEmpty) {
        return;
      }
      const pageSize = 100;
      final window =
          cached.length > pageSize ? cached.sublist(0, pageSize) : cached;
      setState(() {
        _members = List<V2TimGroupMemberFullInfo?>.from(window);
      });
    } catch (_) {}
  }

  void _submitAtMemberList() {
    if (widget.closeFunc != null) {
      widget.closeFunc!();
    }

    if (widget.onChooseMember != null) {
      widget.onChooseMember!(selectedGroupMemberList);
    } else {
      Navigator.pop(context, selectedGroupMemberList);
    }
  }

  List<V2TimGroupMemberFullInfo?> _visibleMembers() {
    final selfId = _selfInfoViewModel.loginInfo?.userID?.trim() ?? '';
    final base = _members
        .where(
          (member) =>
              member != null &&
              member.userID.trim().isNotEmpty &&
              member.userID != selfId,
        )
        .toList();
    return filterGroupMembersByKeyword(base, _keyword);
  }

  void _handleSearchText(String text) {
    final next = text.trim().toLowerCase();
    if (next == _keyword) {
      return;
    }
    setState(() => _keyword = next);
  }

  Future<void> _loadMoreMembers() async {
    final gid = widget.groupID?.trim() ?? '';
    if (gid.isEmpty ||
        !_hasMoreMembers ||
        _loadingMore ||
        _loadingFirst ||
        _keyword.isNotEmpty) {
      return;
    }
    _loadingMore = true;
    try {
      await _loadPage(groupID: gid, seq: _nextSeq, isFirst: false);
    } finally {
      _loadingMore = false;
    }
  }

  /// 只拉一页；禁止递归整表。触底请用 [_loadMoreMembers]。
  Future<void> _loadPage({
    required String groupID,
    required String seq,
    required bool isFirst,
  }) async {
    // 有种子/缓存时静默刷新首页，避免整页转圈；空列表才显示 loading。
    final showFirstSpinner = isFirst && _members.isEmpty;
    if (showFirstSpinner && mounted) {
      setState(() => _loadingFirst = true);
    }
    try {
      final res = await _groupServices.getGroupMemberList(
        groupID: groupID,
        filter: GroupMemberFilterTypeEnum.V2TIM_GROUP_MEMBER_FILTER_ALL,
        count: 100,
        nextSeq: seq,
      );
      final page = res.data;
      if (res.code != 0 || page == null) {
        // ignore: avoid_print
        print(
          '[AtMemberDiag] page fail isFirst=$isFirst code=${res.code} '
          'desc=${res.desc} seq=$seq',
        );
        return;
      }
      final pageMembers = page.memberInfoList ?? const [];
      if (!mounted) {
        return;
      }
      setState(() {
        if (isFirst) {
          _members = List<V2TimGroupMemberFullInfo?>.from(pageMembers);
        } else {
          final existing = _members
              .map((e) => e?.userID.trim() ?? '')
              .where((id) => id.isNotEmpty)
              .toSet();
          final appended = pageMembers
              .where((m) => !existing.contains(m.userID.trim()))
              .toList(growable: false);
          _members = [..._members, ...appended];
        }
        _nextSeq = (page.nextSeq ?? '0').trim();
        if (_nextSeq.isEmpty) {
          _nextSeq = '0';
        }
      });
      // ignore: avoid_print
      print(
        '[AtMemberDiag] page isFirst=$isFirst count=${pageMembers.length} '
        'total=${_members.length} nextSeq=$_nextSeq',
      );
    } finally {
      if (isFirst && mounted && _loadingFirst) {
        setState(() => _loadingFirst = false);
      }
    }
  }

  @override
  Widget tuiBuild(BuildContext context, TUIKitBuildValue value) {
    final TUITheme theme = value.theme;

    Widget mentionedMembersBody() {
      if (_loadingFirst && _members.isEmpty) {
        return Center(
          child: LoadingAnimationWidget.staggeredDotsWave(
            color: theme.primaryColor ?? Colors.grey,
            size: 40,
          ),
        );
      }
      final presenceBridge = serviceLocator<TUIChatGlobalModel>()
          .appContactPresenceBridgeBuilder
          ?.call(context);
      return GroupProfileMemberList(
        groupType: widget.groupType ?? "",
        memberList: _visibleMembers(),
        canAtAll: widget.canAtAll,
        canSelectMember: true,
        canSlideDelete: false,
        isShowIndexBar: false,
        presenceListenable: presenceBridge?.presenceListenable,
        presenceLabelBuilder: presenceBridge?.presenceLabelBuilder,
        presenceLoadingChecker: presenceBridge?.presenceLoadingChecker,
        presenceOnlineResolver: presenceBridge?.presenceOnlineResolver,
        onMemberListLoaded: presenceBridge?.onContactListLoaded,
        onSelectedMemberChange: (selectedMemberList) {
          selectedGroupMemberList = selectedMemberList;
          final isAtAllSelected = selectedGroupMemberList.any(
            (element) =>
                element.userID == GroupProfileMemberList.AT_ALL_USER_ID,
          );

          if (isAtAllSelected) {
            _submitAtMemberList();
          }
        },
        touchBottomCallBack: _loadMoreMembers,
        customTopArea: PlatformUtils().isWeb
            ? null
            : GroupMemberSearchTextField(
                onTextChange: _handleSearchText,
              ),
      );
    }

    return TUIKitScreenUtils.getDeviceWidget(
      context: context,
      desktopWidget: mentionedMembersBody(),
      defaultWidget: Scaffold(
        appBar: AppBar(
          shadowColor: theme.weakBackgroundColor,
          iconTheme: IconThemeData(
            color: theme.appbarTextColor,
          ),
          backgroundColor: theme.appbarBgColor ?? theme.primaryColor,
          leading: Row(
            children: [
              IconButton(
                padding: const EdgeInsets.only(left: 16),
                constraints: const BoxConstraints(),
                icon: Image.asset(
                  'images/arrow_back.png',
                  package: 'tencent_cloud_chat_uikit',
                  height: 34,
                  width: 34,
                  color: theme.appbarTextColor,
                ),
                onPressed: () async {
                  Navigator.pop(context);
                },
              ),
            ],
          ),
          centerTitle: true,
          leadingWidth: 100,
          title: Text(
            TIM_t("选择提醒人"),
            style: TextStyle(
              color: theme.appbarTextColor,
              fontSize: 17,
            ),
          ),
          actions: [
            TextButton(
              onPressed: _submitAtMemberList,
              child: Text(
                TIM_t("确定"),
                style: TextStyle(
                  color: theme.appbarTextColor,
                  fontSize: 14,
                ),
              ),
            )
          ],
        ),
        body: mentionedMembersBody(),
      ),
    );
  }
}
