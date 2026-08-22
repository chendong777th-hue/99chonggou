import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tencent_cloud_chat_demo/src/i18n/app_i18n.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_friend_info.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_friend_info.dart';
import 'package:tencent_cloud_chat_uikit/theme/color.dart';
import 'package:tencent_cloud_chat_uikit/ui/utils/screen_utils.dart';
import 'package:tencent_cloud_chat_uikit/ui/utils/message_anchor.dart';
import 'package:tencent_cloud_chat_uikit/ui/widgets/contact_list.dart';
import 'package:tencent_cloud_chat_uikit/business_logic/view_models/tui_friendship_view_model.dart';
import 'package:tencent_cloud_chat_uikit/data_services/services_locatar.dart';
import 'package:tencent_cloud_chat_demo/src/navigation/app_chat_route.dart';
import 'package:tencent_cloud_chat_demo/src/group_list.dart';
import 'package:tencent_cloud_chat_demo/src/provider/local_setting.dart';
import 'package:tencent_cloud_chat_demo/src/provider/theme.dart';
import 'package:tencent_cloud_chat_demo/src/search.dart';
import 'package:tencent_cloud_chat_demo/src/user_profile.dart';
import 'package:tencent_cloud_chat_demo/src/widgets/app_empty_state.dart';
import 'package:tencent_cloud_chat_demo/src/widgets/contact_list_with_presence.dart';
import 'package:tencent_cloud_chat_demo/src/theme/app_colors.dart';
import 'package:tencent_cloud_chat_demo/src/ui/app_tokens.dart';
import 'package:tencent_cloud_chat_demo/src/services/friend_request_notice_service.dart';
import 'package:tencent_cloud_chat_demo/utils/navigation_routes.dart';
import 'package:tencent_cloud_chat_demo/utils/profile_page_nav.dart';
import 'package:tencent_cloud_chat_demo/utils/theme.dart';
import 'package:tencent_cloud_chat_demo/src/utils/contact_conversation_peek.dart';
import 'package:tencent_cloud_chat_demo/src/all_group_application_list.dart';
import 'package:tencent_cloud_chat_demo/src/pages/cross_platform/wide_screen/desktop_group_notice_host.dart';
import 'package:tencent_cloud_chat_demo/src/services/group_notice_unread_service.dart';
import 'package:tencent_cloud_chat_demo/src/widgets/conversation_feed/conversation_feed_ui.dart';
import 'newContact.dart';
import 'package:tencent_cloud_chat_demo/src/navigation/app_page_transitions.dart';
import 'package:tencent_cloud_chat_demo/src/ui/utils/desktop_modal_layout.dart';
import 'package:tencent_cloud_chat_uikit/data_services/core/tim_uikit_wide_modal_operation_key.dart';
import 'package:tencent_cloud_chat_uikit/ui/widgets/wide_popup.dart';

class Contact extends StatefulWidget {
  final ValueChanged<String>? onTapItem;

  const Contact({Key? key, this.onTapItem}) : super(key: key);

  @override
  State<StatefulWidget> createState() => _ContactState();
}

class _ContactState extends State<Contact> {
  Widget _buildContactLoadingPlaceholder(
    BuildContext context, {
    required bool includeTopEntries,
  }) {
    final theme = Provider.of<DefaultThemeData>(context, listen: false).theme;
    final isDark = ThemeData.estimateBrightnessForColor(
          theme.weakBackgroundColor ?? AppColors.background(dark: false),
        ) ==
        Brightness.dark;
    final lineColor = (theme.weakDividerColor ?? AppColors.line(dark: isDark))
        .withValues(alpha: 0.35);
    final subLineColor = lineColor.withValues(alpha: 0.55);
    final blockColor = (theme.weakDividerColor ?? AppColors.line(dark: isDark))
        .withValues(alpha: 0.6);
    final dividerColor = theme.weakDividerColor ?? AppColors.line(dark: isDark);

    // 与 ContactListWithPresence 一致：分割线对齐文字列（avatar 40 + gap 12）。
    const avatarSize = 40.0;
    const avatarTextGap = 12.0;
    const dividerInset = avatarSize + avatarTextGap;

    Widget buildTopPlaceholder() {
      return Column(
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 8, left: 16),
            child: Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: avatarSize,
                    height: avatarSize,
                    margin: const EdgeInsets.only(right: avatarTextGap),
                    decoration: BoxDecoration(
                      color: blockColor,
                      shape: BoxShape.circle,
                    ),
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(top: 3, bottom: 10),
                      child: Container(
                        height: 14,
                        decoration: BoxDecoration(
                          color: lineColor,
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(left: dividerInset),
            child: Container(height: 0.6, color: dividerColor),
          ),
        ],
      );
    }

    Widget buildFriendPlaceholder(int index) {
      return Container(
        constraints: const BoxConstraints(minHeight: 56),
        padding: const EdgeInsets.only(top: 4, left: 16),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.only(right: 16, bottom: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    width: avatarSize,
                    height: avatarSize,
                    margin: const EdgeInsets.only(right: avatarTextGap),
                    decoration: BoxDecoration(
                      color: blockColor,
                      shape: BoxShape.circle,
                    ),
                  ),
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 120 + (index % 3) * 24,
                          height: 16,
                          decoration: BoxDecoration(
                            color: lineColor,
                            borderRadius: BorderRadius.circular(999),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Container(
                          width: 72 + (index % 2) * 16,
                          height: 13,
                          decoration: BoxDecoration(
                            color: subLineColor,
                            borderRadius: BorderRadius.circular(999),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(left: dividerInset),
              child: Container(height: 0.6, color: dividerColor),
            ),
          ],
        ),
      );
    }

    return ListView(
      key: const PageStorageKey<String>('contact_loading_placeholder'),
      children: [
        if (includeTopEntries) ...[
          buildTopPlaceholder(),
          buildTopPlaceholder(),
          buildTopPlaceholder(),
        ],
        for (var i = 0; i < 7; i++) buildFriendPlaceholder(i),
      ],
    );
  }

  @override
  void initState() {
    super.initState();
  }

  _topListItemTap(String id) {
    switch (id) {
      case "newContact":
        if (DesktopModalLayout.isDesktop(context)) {
          final size = DesktopModalLayout.large(context);
          TUIKitWidePopup.showPopupWindow(
            operationKey: TUIKitWideModalOperationKey.custom,
            context: context,
            title: AppI18n.of(context).t(
              zhHans: '新的朋友',
              zhHant: '新的朋友',
              en: 'New Friends',
              ja: '新しい友達',
              ko: '새 친구',
            ),
            width: size.width,
            height: size.height,
            borderRadius: const BorderRadius.all(Radius.circular(20)),
            child: (closeFunc) => const NewContact(),
          );
        } else {
          Navigator.push(
              context,
              AppMaterialPageRoute(
                builder: (context) => const NewContact(),
              ));
        }
        break;
      case "groupList":
        final isWideScreen =
            TUIKitScreenUtils.getFormFactor(context) == DeviceType.Desktop;
        if (isWideScreen) {
        } else {
          Navigator.push(
              context,
              AppMaterialPageRoute(
                settings: const RouteSettings(name: AppRoutes.myGroupList),
                builder: (context) => const GroupList(),
              ));
        }
        break;
      case "groupNotice":
        unawaited(GroupNoticeUnreadService.instance.markRead());
        if (DesktopModalLayout.isDesktop(context)) {
          DesktopGroupNoticeHost.open();
        } else {
          Navigator.push(
            context,
            AppMaterialPageRoute(
              builder: (context) => const AllGroupApplicationListPage(),
            ),
          );
        }
        break;
      default:
        break;
    }
  }

  String _getImagePathByID(String id) {
    final themeType = Provider.of<DefaultThemeData>(context).currentThemeType;
    final themeTypeSuffix = themeType == ThemeType.dark ? 'solemn' : 'brisk';
    switch (id) {
      case "newContact":
        return "assets/newContact_$themeTypeSuffix.png";
      case "groupList":
        return "assets/groupList_$themeTypeSuffix.png";
      case "groupNotice":
        return conversationGroupNoticeEntryIconAsset;
      case "customerService":
        return "assets/customerService.png";
      default:
        return "";
    }
  }

  Widget _buildTopEntryAvatar(String id) {
    final size = (kIsWeb ||
            TUIKitScreenUtils.getFormFactor(context) == DeviceType.Desktop)
        ? 48.0
        : 46.0;
    final Widget avatar;
    if (id == 'groupNotice') {
      avatar = buildConversationSystemEntryAvatar(
        conversationGroupNoticeEntryIconAsset,
        size: size,
        scale: 1.5,
      );
    } else {
      avatar = SizedBox(
        width: size,
        height: size,
        child: ClipOval(
          child: Image.asset(
            _getImagePathByID(id),
            fit: BoxFit.cover,
          ),
        ),
      );
    }

    if (id != 'newContact' && id != 'groupNotice') {
      return avatar;
    }

    if (id == 'groupNotice') {
      return AnimatedBuilder(
        animation: GroupNoticeUnreadService.instance,
        builder: (context, child) {
          final count = GroupNoticeUnreadService.instance.unreadCount;
          if (count <= 0) {
            return child!;
          }
          final label = count > 99 ? '99+' : '$count';
          return Stack(
            clipBehavior: Clip.none,
            children: [
              child!,
              Positioned(
                right: -4,
                top: -4,
                child: Container(
                  constraints: const BoxConstraints(minWidth: 16),
                  height: 16,
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  decoration: BoxDecoration(
                    color: AppTokens.danger,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.white, width: 1),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    label,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 9,
                      height: 1,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          );
        },
        child: avatar,
      );
    }

    return ValueListenableBuilder<int>(
      valueListenable:
          FriendRequestNoticeService.instance.pendingApplicationCount,
      builder: (context, count, child) {
        if (count <= 0) {
          return child!;
        }
        final label = count > 99 ? '99+' : '$count';
        return Stack(
          clipBehavior: Clip.none,
          children: [
            child!,
            Positioned(
              right: -4,
              top: -4,
              child: Container(
                constraints: const BoxConstraints(minWidth: 16),
                height: 16,
                padding: const EdgeInsets.symmetric(horizontal: 4),
                decoration: BoxDecoration(
                  color: AppTokens.danger,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.white, width: 1),
                ),
                alignment: Alignment.center,
                child: Text(
                  label,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 9,
                    height: 1,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        );
      },
      child: avatar,
    );
  }

  Future<void> _openSearch() async {
    await Navigator.push(
      context,
      AppMaterialPageRoute(
        settings: const RouteSettings(name: AppRoutes.search),
        builder: (context) => Search(
          onTapConversation: (conversation, anchor) async {
            await openChatWithAnchor(context, conversation, anchor: anchor);
          },
        ),
      ),
    );
  }

  void _showContactPeek(V2TimFriendInfo friend) {
    unawaited(
      ContactConversationPeek.show(
        context,
        friend: friend,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final i18n = AppI18n.of(context);
    final LocalSetting localSetting = Provider.of<LocalSetting>(context);
    final theme = Provider.of<DefaultThemeData>(context).theme;
    final friendShipModel = serviceLocator<TUIFriendShipViewModel>();
    final isWideScreen =
        TUIKitScreenUtils.getFormFactor(context) == DeviceType.Desktop;
    final iconColor =
        (theme.appbarTextColor ?? hexToColor("979797")).withValues(alpha: 0.7);
    return Container(
      color: theme.weakBackgroundColor ?? Colors.white,
      child: Column(
        children: [
          if (!isWideScreen)
            GestureDetector(
              onTap: _openSearch,
              child: Container(
                decoration: BoxDecoration(
                  color: theme.appbarBgColor ?? Colors.white,
                  boxShadow: const [],
                ),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 16),
                  child: Container(
                    decoration: BoxDecoration(
                      color: theme.inputFillColor ?? hexToColor("f7f7f8"),
                      borderRadius: const BorderRadius.all(Radius.circular(4)),
                    ),
                    height: 40,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Row(
                        children: [
                          Icon(
                            Icons.search,
                            color: iconColor,
                            size: 18,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            i18n.t(
                              zhHans: '搜索',
                              zhHant: '搜尋',
                              en: 'Search',
                              ja: '検索',
                              ko: '검색',
                            ),
                            style: TextStyle(
                              color: iconColor,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          Expanded(
            child: AnimatedBuilder(
              animation: friendShipModel,
              builder: (context, _) {
                final friendList = friendShipModel.friendList ?? const [];
                final isLoadingFirstScreen = !friendShipModel
                        .hasLoadedContactList &&
                    friendList.isEmpty &&
                    friendShipModel.isLoadingContactList;
                if (isLoadingFirstScreen) {
                  return _buildContactLoadingPlaceholder(
                    context,
                    includeTopEntries: !isWideScreen,
                  );
                }
                return ContactListWithPresence(
                  isShowOnlineStatus: localSetting.isShowOnlineStatus,
                  showContactCount: true,
                  topList: [
                    TopListItem(
                        name: i18n.t(
                          zhHans: '新的朋友',
                          zhHant: '新的朋友',
                          en: 'New Friends',
                          ja: '新しい友達',
                          ko: '새 친구',
                        ),
                        id: "newContact",
                        icon: _buildTopEntryAvatar("newContact"),
                        onTap: () {
                          _topListItemTap("newContact");
                        }),
                    TopListItem(
                        name: i18n.t(
                          zhHans: '群通知',
                          zhHant: '群組通知',
                          en: 'Group Notices',
                          ja: 'グループ通知',
                          ko: '그룹 알림',
                        ),
                        id: "groupNotice",
                        icon: _buildTopEntryAvatar("groupNotice"),
                        onTap: () {
                          _topListItemTap("groupNotice");
                        }),
                    if (!isWideScreen)
                      TopListItem(
                          name: i18n.t(
                            zhHans: '我的群聊',
                            zhHant: '我的群聊',
                            en: 'My Groups',
                            ja: 'マイグループ',
                            ko: '내 그룹',
                          ),
                          id: "groupList",
                          icon: _buildTopEntryAvatar("groupList"),
                          onTap: () {
                            _topListItemTap("groupList");
                          }),
                  ],
                  onTapItem: (item) {
                    if (widget.onTapItem != null) {
                      widget.onTapItem!(item.userID);
                    } else {
                      ProfilePageNav.openUserProfile(
                        context,
                        userID: item.userID,
                        addSource: 'contacts',
                      );
                    }
                  },
                  onLongPressItem: _showContactPeek,
                  emptyBuilder: (context) => AppEmptyState(
                    message: i18n.t(
                      zhHans: '无联系人',
                      zhHant: '無聯絡人',
                      en: 'No contacts',
                      ja: '連絡先がありません',
                      ko: '연락처가 없습니다',
                    ),
                  ),
                );
              },
            ),
          )
        ],
      ),
    );
  }
}
