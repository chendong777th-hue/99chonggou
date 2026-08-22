import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tencent_cloud_chat_demo/src/i18n/app_i18n.dart';
import 'package:tencent_cloud_chat_demo/src/navigation/app_page_transitions.dart';
import 'package:tencent_cloud_chat_demo/src/pages/join_group_application_page.dart';
import 'package:tencent_cloud_chat_demo/src/provider/theme.dart';
import 'package:tencent_cloud_chat_demo/src/models/group_join_source.dart';
import 'package:tencent_cloud_chat_demo/utils/chat_id_format.dart';
import 'package:tencent_cloud_chat_demo/utils/group_join_lookup.dart';
import 'package:tencent_cloud_chat_demo/utils/toast.dart';
import 'package:tencent_cloud_chat_sdk/enum/group_type.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_conversation.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_conversation.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_group_info.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_group_info.dart';
import 'package:tencent_cloud_chat_uikit/business_logic/view_models/tui_friendship_view_model.dart';
import 'package:tencent_cloud_chat_uikit/data_services/conversation/conversation_services.dart';
import 'package:tencent_cloud_chat_uikit/data_services/core/tim_uikit_wide_modal_operation_key.dart';
import 'package:tencent_cloud_chat_uikit/data_services/group/group_services.dart';
import 'package:tencent_cloud_chat_uikit/data_services/services_locatar.dart';
import 'package:tencent_cloud_chat_uikit/theme/tui_theme.dart';
import 'package:tencent_cloud_chat_uikit/ui/utils/screen_utils.dart';
import 'package:tencent_cloud_chat_uikit/ui/widgets/avatar.dart';
import 'package:tencent_cloud_chat_demo/src/ui/utils/desktop_modal_layout.dart';
import 'package:tencent_cloud_chat_uikit/ui/widgets/wide_popup.dart';

class SelfHostedAddGroup extends StatefulWidget {
  final void Function(String groupID, V2TimConversation conversation)
      onTapExistGroup;
  final VoidCallback? closeFunc;

  const SelfHostedAddGroup({
    Key? key,
    required this.onTapExistGroup,
    this.closeFunc,
  }) : super(key: key);

  @override
  State<SelfHostedAddGroup> createState() => _SelfHostedAddGroupState();
}

class _SelfHostedAddGroupState extends State<SelfHostedAddGroup> {
  final TextEditingController _controller = TextEditingController();
  final GroupServices _groupServices = serviceLocator<GroupServices>();
  final ConversationService _conversationService =
      serviceLocator<ConversationService>();
  final TUIFriendShipViewModel _friendshipViewModel =
      serviceLocator<TUIFriendShipViewModel>();
  final FocusNode _focusNode = FocusNode();

  List<V2TimGroupInfo>? _groupResult;
  List<V2TimGroupInfo>? _joinedGroupList;
  bool _showResult = false;

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  String _groupTypeLabel(AppI18n i18n, String type) {
    switch (type) {
      case GroupType.AVChatRoom:
        return i18n.t(
          zhHans: '聊天室',
          zhHant: '聊天室',
          en: 'Chat room',
          ja: 'チャットルーム',
          ko: '채팅방',
        );
      case GroupType.Meeting:
        return i18n.t(
          zhHans: '会议群',
          zhHant: '會議群',
          en: 'Meeting group',
          ja: '会議グループ',
          ko: '회의 그룹',
        );
      case GroupType.Public:
        return i18n.t(
          zhHans: '公开群',
          zhHant: '公開群',
          en: 'Public group',
          ja: '公開グループ',
          ko: '공개 그룹',
        );
      case GroupType.Work:
        return i18n.t(
          zhHans: '工作群',
          zhHant: '工作群',
          en: 'Work group',
          ja: 'ワークグループ',
          ko: '업무 그룹',
        );
      case GroupType.Community:
        return i18n.t(
          zhHans: '社群',
          zhHant: '社群',
          en: 'Community',
          ja: 'コミュニティ',
          ko: '커뮤니티',
        );
      default:
        return i18n.t(
          zhHans: '未知群',
          zhHant: '未知群',
          en: 'Unknown group',
          ja: '不明なグループ',
          ko: '알 수 없는 그룹',
        );
    }
  }

  Future<V2TimConversation?> _getGroupConversation(String groupID) async {
    _joinedGroupList ??= await _groupServices.getJoinedGroupList();
    final joined = _joinedGroupList?.any((item) => item.groupID == groupID) ??
        false;
    if (!joined) {
      return null;
    }
    final conversation = await _conversationService
        .getConversationListByConversationId(convID: 'group_$groupID');
    if (conversation != null) {
      return conversation;
    }
    await _friendshipViewModel.loadGroupListData();
    final index = _friendshipViewModel.groupList
        .indexWhere((item) => item.groupID == groupID);
    if (index < 0) {
      return null;
    }
    final groupInfo = _friendshipViewModel.groupList[index];
    return V2TimConversation(
      conversationID: 'group_$groupID',
      type: 2,
      groupID: groupID,
      showName: groupInfo.groupName,
      groupType: groupInfo.groupType,
    );
  }

  Future<void> _searchGroup(String groupId) async {
    final trimmed = groupId.trim();
    if (trimmed.isEmpty) {
      return;
    }
    try {
      final info = await GroupJoinLookup.resolve(
        groupKey: trimmed,
        joinSource: GroupJoinSource.search,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _groupResult = info == null ? const <V2TimGroupInfo>[] : [info];
        _showResult = true;
      });
    } on GroupJoinLookupDisabledException catch (error) {
      if (!mounted) {
        return;
      }
      ToastUtils.toast(GroupJoinLookup.disabledMessage(
        AppI18n.of(context),
        error,
      ));
      setState(() {
        _groupResult = const <V2TimGroupInfo>[];
        _showResult = true;
      });
    }
  }

  Future<void> _openJoinPage(V2TimGroupInfo groupInfo) async {
    final groupID = ChatIdFormat.canonicalGroupStorageId(groupInfo.groupID);
    if (groupID.isEmpty) {
      return;
    }
    final existing = await _getGroupConversation(groupID);
    if (!mounted) {
      return;
    }
    if (existing != null) {
      ToastUtils.toast(
        AppI18n.of(context).t(
          zhHans: '您已是群成员',
          zhHant: '您已是群成員',
          en: 'You are already a member',
          ja: 'すでにメンバーです',
          ko: '이미 멤버입니다',
        ),
      );
      widget.closeFunc?.call();
      widget.onTapExistGroup(groupID, existing);
      return;
    }

    widget.closeFunc?.call();
    final isDesktop =
        TUIKitScreenUtils.getFormFactor(context) == DeviceType.Desktop;
    // 已在「添加群聊」弹窗内：局部 push，避免 isShow 互斥导致打不开或全屏。
    if (isDesktop && TUIKitWidePopup.isShow) {
      await Navigator.of(context).push(
        AppMaterialPageRoute(
          builder: (context) => JoinGroupApplicationPage(
            groupInfo: groupInfo,
            joinSource: GroupJoinSource.search,
          ),
        ),
      );
      return;
    }
    if (isDesktop) {
      final size = DesktopModalLayout.medium(context);
      await TUIKitWidePopup.showPopupWindow(
        operationKey: TUIKitWideModalOperationKey.addGroup,
        context: context,
        width: size.width,
        height: size.height,
        borderRadius: const BorderRadius.all(Radius.circular(20)),
        title: AppI18n.of(context).t(
          zhHans: '添加群聊',
          zhHant: '添加群聊',
          en: 'Join Group',
          ja: 'グループに参加',
          ko: '그룹 추가',
        ),
        child: (_) => JoinGroupApplicationPage(
          groupInfo: groupInfo,
          joinSource: GroupJoinSource.search,
        ),
      );
      return;
    }

    await Navigator.push(
      context,
      AppMaterialPageRoute(
        builder: (context) => JoinGroupApplicationPage(
          groupInfo: groupInfo,
          joinSource: GroupJoinSource.search,
        ),
      ),
    );
  }

  Widget _buildResultItem(
    V2TimGroupInfo groupInfo,
    TUITheme theme,
    AppI18n i18n,
    bool isDesktop,
  ) {
    final faceUrl = groupInfo.faceUrl ?? '';
    final groupID = ChatIdFormat.canonicalGroupStorageId(groupInfo.groupID);
    final showName = groupInfo.groupName ?? groupID;
    final groupType = _groupTypeLabel(i18n, groupInfo.groupType);
    return InkWell(
      onTap: () => _openJoinPage(groupInfo),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          children: [
            Container(
              width: isDesktop ? 38 : 48,
              height: isDesktop ? 38 : 48,
              margin: const EdgeInsets.only(right: 16),
              child: Avatar(faceUrl: faceUrl, showName: showName),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  showName,
                  style: TextStyle(
                    fontSize: isDesktop ? 16 : 18,
                    color: theme.darkTextColor,
                  ),
                ),
                Text(
                  'ID: $groupID',
                  style: TextStyle(fontSize: 12, color: theme.weakTextColor),
                ),
                Text(
                  i18n.format(
                    zhHans: '群类型: {option1}',
                    zhHant: '群類型: {option1}',
                    en: 'Group type: {option1}',
                    ja: 'グループタイプ: {option1}',
                    ko: '그룹 유형: {option1}',
                    vars: {'option1': groupType},
                  ),
                  style: TextStyle(fontSize: 12, color: theme.weakTextColor),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Provider.of<DefaultThemeData>(context).theme;
    final i18n = AppI18n.of(context);
    final isDesktop =
        TUIKitScreenUtils.getFormFactor(context) == DeviceType.Desktop;
    final backgroundColor =
        theme.weakBackgroundColor ?? theme.wideBackgroundColor ?? Colors.white;
    final cursorColor = backgroundColor.computeLuminance() < 0.2
        ? Colors.white
        : theme.primaryColor ?? const Color(0xFF1E90FF);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 20),
          child: TextField(
            autofocus: true,
            focusNode: _focusNode,
            controller: _controller,
            cursorColor: cursorColor,
            style: TextStyle(color: theme.darkTextColor),
            textInputAction: TextInputAction.search,
            onChanged: (value) {
              if (value.trim().isEmpty) {
                setState(() => _showResult = false);
              }
            },
            onSubmitted: (value) {
              if (value.trim().isNotEmpty) {
                _searchGroup(value);
                _focusNode.requestFocus();
              }
            },
            decoration: InputDecoration(
              prefixIcon: Icon(
                Icons.search_outlined,
                color: theme.weakTextColor,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(width: 0, style: BorderStyle.none),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide.none,
              ),
              contentPadding: EdgeInsets.zero,
              hintStyle: TextStyle(color: theme.weakTextColor),
              fillColor: theme.inputFillColor,
              filled: true,
              hintText: i18n.t(
                zhHans: '搜索群ID',
                zhHant: '搜尋群ID',
                en: 'Search group ID',
                ja: 'グループIDを検索',
                ko: '그룹 ID 검색',
              ),
            ),
          ),
        ),
        if (_showResult)
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: SingleChildScrollView(
                child: Column(
                  children: _groupResult == null || _groupResult!.isEmpty
                      ? [
                          Container(
                            margin: const EdgeInsets.only(top: 20),
                            child: Center(
                              child: Text(
                                i18n.t(
                                  zhHans: '该群聊不存在',
                                  zhHant: '該群聊不存在',
                                  en: 'Group not found',
                                  ja: 'グループが見つかりません',
                                  ko: '그룹을 찾을 수 없습니다',
                                ),
                                style: TextStyle(
                                  color: theme.weakTextColor,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                          ),
                        ]
                      : _groupResult!
                          .map(
                            (group) => _buildResultItem(
                              group,
                              theme,
                              i18n,
                              isDesktop,
                            ),
                          )
                          .toList(),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
