import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tencent_cloud_chat_demo/src/i18n/app_i18n.dart';
import 'package:tencent_cloud_chat_demo/src/navigation/app_chat_route.dart';
import 'package:tencent_cloud_chat_demo/src/provider/theme.dart';
import 'package:tencent_cloud_chat_demo/src/services/group_local/group_local_perf_flags.dart';
import 'package:tencent_cloud_chat_demo/src/services/group_local/my_group_az_skeleton.dart';
import 'package:tencent_cloud_chat_demo/src/services/group_local/my_group_list_controller.dart';
import 'package:tencent_cloud_chat_demo/src/utils/conversation_group_title_color.dart';
import 'package:tencent_cloud_chat_demo/src/widgets/app_empty_state.dart';
import 'package:tencent_cloud_chat_demo/src/widgets/group_list_role_badge.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_conversation.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_conversation.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_group_info.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_group_info.dart';
import 'package:tencent_cloud_chat_uikit/data_services/services_locatar.dart';
import 'package:tencent_cloud_chat_uikit/tencent_cloud_chat_uikit.dart';
import 'package:tencent_cloud_chat_uikit/theme/tui_theme_view_model.dart';
import 'package:tencent_cloud_chat_uikit/ui/utils/screen_utils.dart';
import 'package:tencent_cloud_chat_uikit/ui/widgets/avatar.dart';
import 'package:tencent_cloud_chat_uikit/ui/widgets/az_list_view.dart';

class GroupList extends StatefulWidget {
  final void Function(V2TimGroupInfo groupInfo, V2TimConversation conversation)?
      onTapItem;

  const GroupList({Key? key, this.onTapItem}) : super(key: key);

  @override
  State<GroupList> createState() => _GroupListState();
}

class _GroupListState extends State<GroupList> {
  static const _footerMarker = '__group_count_footer__';
  static const _searchDebounce = Duration(milliseconds: 250);

  final sdkInstance = TIMUIKitCore.getSDKInstance();
  final MyGroupListController _controller = MyGroupListController.instance;
  final TextEditingController _searchController = TextEditingController();

  String _searchKeyword = '';
  Timer? _searchDebounceTimer;

  @override
  void initState() {
    super.initState();
    if (GroupLocalPerfFlags.myGroupListAzOptimizeEnabled) {
      _searchKeyword = '';
      _controller.addListener(_onControllerChanged);
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        // 进页对齐空搜索框：清单例残留 keyword 后再加载完整列表。
        await _controller.clearSearch(reload: false);
        if (!mounted) {
          return;
        }
        await _controller.ensureLoaded();
      });
    }
  }

  @override
  void dispose() {
    _searchDebounceTimer?.cancel();
    _searchController.dispose();
    if (GroupLocalPerfFlags.myGroupListAzOptimizeEnabled) {
      _controller.removeListener(_onControllerChanged);
      // 离页清 keyword，避免再进仍是过滤结果；不 reload。
      unawaited(_controller.clearSearch(reload: false));
    }
    super.dispose();
  }

  void _onControllerChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _jumpToChatPage(
    BuildContext context,
    V2TimGroupInfo groupInfo,
    V2TimConversation conversation,
  ) async {
    if (widget.onTapItem != null) {
      widget.onTapItem!(groupInfo, conversation);
      return;
    }
    final res = await sdkInstance
        .getConversationManager()
        .getConversation(conversationID: 'group_${groupInfo.groupID}');
    if (res.code == 0) {
      final conversationData = res.data;
      if (conversationData != null && context.mounted) {
        openOrReuseAppChat(context, conversationData);
      }
    }
  }

  Future<void> _onTapSkeleton(MyGroupAzSkeleton skeleton) async {
    final groupInfo = skeleton.toV2TimGroupInfo();
    var conversation = V2TimConversation(
      conversationID: 'group_${groupInfo.groupID}',
      groupID: groupInfo.groupID,
      type: 2,
      showName: groupInfo.groupName,
      groupType: groupInfo.groupType,
      faceUrl: groupInfo.faceUrl,
    );
    final res = await sdkInstance
        .getConversationManager()
        .getConversation(conversationID: 'group_${groupInfo.groupID}');
    if (res.code == 0 && res.data != null) {
      conversation = res.data!;
    }
    if (!mounted) {
      return;
    }
    await _jumpToChatPage(context, groupInfo, conversation);
  }

  Widget _buildGroupCountFooter(BuildContext context, int count) {
    final theme = Provider.of<DefaultThemeData>(context, listen: false).theme;
    final isDesktop =
        TUIKitScreenUtils.getFormFactor(context) == DeviceType.Desktop;
    final i18n = AppI18n.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      child: Center(
        child: Text(
          i18n.format(
            zhHans: '共{count}个群',
            zhHant: '共{count}個群',
            en: '{count} groups',
            ja: 'グループ {count} 件',
            ko: '그룹 {count}개',
            vars: {'count': count.toString()},
          ),
          style: TextStyle(
            color: theme.weakTextColor ?? const Color(0xFF999999),
            fontSize: isDesktop ? 12 : 13,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }

  Widget _buildOptimizedItem(
    BuildContext context,
    MyGroupAzSkeleton skeleton,
  ) {
    final theme = Provider.of<DefaultThemeData>(context, listen: false).theme;
    final showName = skeleton.showName;
    final faceUrl = skeleton.avatarUrl;
    final isDesktopScreen = kIsWeb ||
        TUIKitScreenUtils.getFormFactor(context) == DeviceType.Desktop;
    final itemBackgroundColor = theme.conversationItemBgColor ??
        theme.weakBackgroundColor ??
        Colors.white;
    final memberCount = skeleton.memberCount;
    final i18n = AppI18n.of(context);
    final memberCountLabel = i18n.format(
      zhHans: '{count}人',
      zhHant: '{count}人',
      en: '{count} members',
      ja: '{count}人',
      ko: '{count}명',
      vars: {'count': memberCount.toString()},
    );
    final avatarSize = isDesktopScreen ? 48.0 : 40.0;
    final avatarTextGap = isDesktopScreen ? 10.0 : 12.0;
    final rowPad = isDesktopScreen ? 6.0 : 4.0;
    final titleFontSize = isDesktopScreen ? 13.0 : 15.0;
    final subtitleFontSize = isDesktopScreen ? 11.0 : 12.0;
    final minHeight = isDesktopScreen ? 64.0 : 56.0;

    return Material(
      color: isDesktopScreen
          ? (theme.wideBackgroundColor ?? itemBackgroundColor)
          : itemBackgroundColor,
      child: InkWell(
        onTap: () => unawaited(_onTapSkeleton(skeleton)),
        child: Container(
          constraints: BoxConstraints(minHeight: minHeight),
          padding: EdgeInsets.only(top: rowPad, left: 16),
          child: Column(
            children: [
              Padding(
                padding: EdgeInsets.only(right: 16, bottom: rowPad),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Container(
                      height: avatarSize,
                      width: avatarSize,
                      margin: EdgeInsets.only(right: avatarTextGap),
                      child: Avatar(
                        faceUrl: faceUrl,
                        showName: showName,
                        type: 2,
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                    Expanded(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          buildGroupTitleWithOptionalFlame(
                            name: showName,
                            groupType: skeleton.groupType,
                            flameSize: titleFontSize - 1,
                            style: TextStyle(
                              color: conversationGroupTitleColor(
                                fallback:
                                    theme.conversationItemTitleTextColor ??
                                        theme.darkTextColor ??
                                        Colors.black,
                                groupType: skeleton.groupType,
                              ),
                              fontSize: titleFontSize,
                              fontWeight: FontWeight.w600,
                              height: 1.15,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            memberCountLabel,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: theme.weakTextColor ??
                                  const Color(0xFF999999),
                              fontSize: subtitleFontSize,
                              height: 1.15,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    GroupListSelfRoleBadge(role: skeleton.myRole),
                  ],
                ),
              ),
              Padding(
                padding: EdgeInsets.only(left: avatarSize + avatarTextGap),
                child: Container(
                  height: 0.6,
                  color: theme.weakDividerColor ?? const Color(0xFFE5E5EA),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOptimizedGroupList(AppI18n i18n) {
    if (_controller.isLoading && _controller.isEmpty) {
      return const Center(child: CircularProgressIndicator(strokeWidth: 2));
    }
    if (_controller.isEmpty) {
      return AppEmptyState(
        message: i18n.t(
          zhHans: '暂无群聊',
          zhHant: '暫無群聊',
          en: 'No groups yet',
          ja: 'グループはありません',
          ko: '그룹이 없습니다',
        ),
      );
    }

    final showList = _controller.azShowList;
    final effectiveList = <ISuspensionBeanImpl>[
      ...showList,
      ISuspensionBeanImpl<Object>(
        memberInfo: _footerMarker,
        tagIndex: '',
      ),
    ];

    return ChangeNotifierProvider<TUIThemeViewModel>.value(
      value: serviceLocator<TUIThemeViewModel>(),
      child: AZListViewContainer(
        isShowIndexBar: true,
        memberList: effectiveList,
        itemBuilder: (context, index) {
          final memberInfo = effectiveList[index].memberInfo;
          if (memberInfo == _footerMarker) {
            return _buildGroupCountFooter(context, _controller.displayCount);
          }
          return _buildOptimizedItem(
            context,
            memberInfo as MyGroupAzSkeleton,
          );
        },
      ),
    );
  }

  Widget _buildLegacyGroupList(AppI18n i18n) {
    return TIMUIKitGroup(
      onTapItem: (groupInfo, conversation) {
        unawaited(_jumpToChatPage(context, groupInfo, conversation));
      },
      emptyBuilder: (_) {
        return AppEmptyState(
          message: i18n.t(
            zhHans: '暂无群聊',
            zhHant: '暫無群聊',
            en: 'No groups yet',
            ja: 'グループはありません',
            ko: '그룹이 없습니다',
          ),
        );
      },
      groupCollector: (groupInfo) {
        final groupID = groupInfo?.groupID ?? '';
        return !groupID.contains('im_discuss_');
      },
      searchKeyword: _searchKeyword,
      isShowIndexBar: true,
      showSelfRoleBadge: true,
      showGroupCount: true,
      groupCountFooterBuilder: _buildGroupCountFooter,
    );
  }

  Widget _buildGroupList(AppI18n i18n) {
    if (GroupLocalPerfFlags.myGroupListAzOptimizeEnabled) {
      return _buildOptimizedGroupList(i18n);
    }
    return _buildLegacyGroupList(i18n);
  }

  void _onSearchChanged(String value) {
    if (!GroupLocalPerfFlags.myGroupListAzOptimizeEnabled) {
      setState(() {
        _searchKeyword = value;
      });
      return;
    }
    _searchDebounceTimer?.cancel();
    _searchDebounceTimer = Timer(_searchDebounce, () {
      unawaited(_controller.setSearchKeyword(value));
    });
  }

  Widget _buildSearchBar(AppI18n i18n) {
    final theme = Provider.of<DefaultThemeData>(context).theme;
    final iconColor = (theme.appbarTextColor ?? const Color(0xFF979797))
        .withValues(alpha: 0.7);
    final textColor = theme.darkTextColor ?? Colors.black;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 16),
      child: Container(
        decoration: BoxDecoration(
          color: theme.inputFillColor ?? const Color(0xFFF7F7F8),
          borderRadius: const BorderRadius.all(Radius.circular(4)),
        ),
        height: 40,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            children: [
              Icon(Icons.search, color: iconColor, size: 18),
              const SizedBox(width: 6),
              Expanded(
                child: TextField(
                  controller: _searchController,
                  onChanged: _onSearchChanged,
                  textInputAction: TextInputAction.search,
                  style: TextStyle(fontSize: 14, color: textColor),
                  cursorColor: theme.primaryColor,
                  decoration: InputDecoration(
                    hintText: i18n.t(
                      zhHans: '搜索群聊',
                      zhHant: '搜尋群聊',
                      en: 'Search groups',
                      ja: 'グループを検索',
                      ko: '그룹 검색',
                    ),
                    hintStyle: TextStyle(fontSize: 14, color: iconColor),
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(vertical: 9),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPageBody(AppI18n i18n) {
    return Column(
      children: [
        _buildSearchBar(i18n),
        Expanded(child: _buildGroupList(i18n)),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Provider.of<DefaultThemeData>(context).theme;
    final i18n = AppI18n.of(context);

    return TUIKitScreenUtils.getDeviceWidget(
      context: context,
      desktopWidget: Container(
        color: theme.weakBackgroundColor ?? Colors.white,
        child: _buildPageBody(i18n),
      ),
      defaultWidget: Scaffold(
        backgroundColor: theme.weakBackgroundColor ?? Colors.white,
        appBar: AppBar(
          surfaceTintColor: Colors.transparent,
          title: Text(
            i18n.t(
              zhHans: '群聊',
              zhHant: '群聊',
              en: 'Groups',
              ja: 'グループ',
              ko: '그룹',
            ),
            style: TextStyle(
              color:
                  theme.appbarTextColor ?? theme.darkTextColor ?? Colors.black,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          backgroundColor: theme.appbarBgColor ?? Colors.white,
          shadowColor: theme.weakDividerColor,
          iconTheme: IconThemeData(
            color: theme.primaryColor ?? const Color(0xFF1E90FF),
          ),
        ),
        body: _buildPageBody(i18n),
      ),
    );
  }
}
