import 'package:bitsdojo_window/bitsdojo_window.dart';
import 'package:flutter/cupertino.dart';
import 'package:tencent_cloud_chat_demo/src/conversation.dart';
import 'package:tencent_cloud_chat_demo/src/pages/home_page.dart';
import 'package:tencent_cloud_chat_demo/src/provider/theme.dart';
import 'package:provider/provider.dart';
import 'package:tencent_cloud_chat_uikit/tencent_cloud_chat_uikit.dart';
import 'package:tencent_cloud_chat_demo/src/pages/cross_platform/wide_screen/user_avatar.dart';
import 'package:tencent_cloud_chat_demo/src/widgets/conversation_scope_unread_badge.dart';
import 'package:tencent_cloud_chat_demo/src/widgets/friend_request_unread_badge.dart';
import 'package:tencent_cloud_chat_uikit/theme/color.dart';

class LeftBar extends StatefulWidget {
  final int index;
  final ValueChanged<int> onChange;

  const LeftBar({Key? key, required this.index, required this.onChange})
      : super(key: key);

  @override
  State<LeftBar> createState() => _LeftBarState();
}

class _LeftBarState extends State<LeftBar> {
  Color _inactiveIconColor(theme) {
    return theme.weakTextColor ?? hexToColor("d9dbe2");
  }

  Widget _badgeOverlay({required Widget icon, required Widget badge}) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        icon,
        Positioned(
          top: -5,
          left: 12,
          child: UnconstrainedBox(child: badge),
        ),
      ],
    );
  }

  List<NavigationBarData> getBottomNavigatorList(BuildContext context, theme) {
    final primary = theme.primaryColor ?? CommonColor.primaryColor;
    final inactive = _inactiveIconColor(theme);
    return [
      NavigationBarData(
        index: 0,
        title: '\u6d88\u606f',
        selectedIcon: _badgeOverlay(
          icon: ColorFiltered(
            colorFilter: ColorFilter.mode(primary, BlendMode.srcATop),
            child: Image.asset(
              "assets/chat_active.png",
              width: 24,
              height: 24,
            ),
          ),
          badge: const ConversationScopeUnreadBadge(
            scope: ConversationListScope.c2c,
          ),
        ),
        unselectedIcon: _badgeOverlay(
          icon: ColorFiltered(
            colorFilter: ColorFilter.mode(inactive, BlendMode.srcATop),
            child: Image.asset(
              "assets/chat.png",
              width: 24,
              height: 24,
            ),
          ),
          badge: const ConversationScopeUnreadBadge(
            scope: ConversationListScope.c2c,
          ),
        ),
      ),
      NavigationBarData(
        index: 1,
        title: '\u7fa4\u804a',
        selectedIcon: _badgeOverlay(
          icon: ColorFiltered(
            colorFilter: ColorFilter.mode(primary, BlendMode.srcATop),
            child: Image.asset(
              "assets/group_conv.png",
              width: 24,
              height: 24,
            ),
          ),
          badge: const ConversationScopeUnreadBadge(
            scope: ConversationListScope.group,
          ),
        ),
        unselectedIcon: _badgeOverlay(
          icon: ColorFiltered(
            colorFilter: ColorFilter.mode(inactive, BlendMode.srcATop),
            child: Image.asset(
              "assets/group_conv.png",
              width: 24,
              height: 24,
            ),
          ),
          badge: const ConversationScopeUnreadBadge(
            scope: ConversationListScope.group,
          ),
        ),
      ),
      NavigationBarData(
        index: 2,
        title: '\u901a\u8baf\u5f55',
        selectedIcon: _badgeOverlay(
          icon: ColorFiltered(
            colorFilter: ColorFilter.mode(primary, BlendMode.srcATop),
            child: Image.asset(
              "assets/contact_active.png",
              width: 24,
              height: 24,
            ),
          ),
          badge: const ContactUnreadBadge(
            width: 16,
            height: 16,
          ),
        ),
        unselectedIcon: _badgeOverlay(
          icon: ColorFiltered(
            colorFilter: ColorFilter.mode(inactive, BlendMode.srcATop),
            child: Image.asset(
              "assets/contact.png",
              width: 24,
              height: 24,
            ),
          ),
          badge: const ContactUnreadBadge(
            width: 16,
            height: 16,
          ),
        ),
      ),
      NavigationBarData(
        index: 3,
        title: '\u6211\u7684',
        selectedIcon: ColorFiltered(
          colorFilter: ColorFilter.mode(
            theme.primaryColor ?? hexToColor("3370ff"),
            BlendMode.srcATop,
          ),
          child: Image.asset(
            "assets/profile_active.png",
            width: 24,
            height: 24,
          ),
        ),
        unselectedIcon: ColorFiltered(
          colorFilter: ColorFilter.mode(inactive, BlendMode.srcATop),
          child: Image.asset(
            "assets/profile.png",
            width: 24,
            height: 24,
          ),
        ),
      ),
    ];
  }

  List<Widget> bottomNavigatorList(BuildContext context, theme) {
    final selectedBackgroundColor =
        (theme.primaryColor ?? hexToColor("273044")).withValues(alpha: 0.16);
    final selectedTextColor = theme.appbarTextColor ?? hexToColor("d9dbe2");
    final unselectedTextColor = theme.weakTextColor ?? hexToColor("d9dbe2");
    return getBottomNavigatorList(context, theme).map((e) {
      return Container(
        width: 60,
        height: 60,
        decoration: BoxDecoration(
          color: widget.index == e.index ? selectedBackgroundColor : null,
          borderRadius: BorderRadius.circular(8.0),
        ),
        child: GestureDetector(
          onTap: () {
            widget.onChange(e.index!);
          },
          child: MouseRegion(
            cursor: SystemMouseCursors.click,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                SizedBox(
                  child: widget.index == e.index
                      ? e.selectedIcon
                      : e.unselectedIcon,
                ),
                const SizedBox(height: 4),
                Text(
                  e.title,
                  style: TextStyle(
                    color: widget.index == e.index
                        ? selectedTextColor
                        : unselectedTextColor,
                    fontSize: 10,
                  ),
                )
              ],
            ),
          ),
        ),
      );
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Provider.of<DefaultThemeData>(context).theme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      mainAxisAlignment: MainAxisAlignment.start,
      children: [
        SizedBox(
          height: 40,
          child: MoveWindow(
            child: Container(),
          ),
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: bottomNavigatorList(context, theme),
        ),
        Expanded(
            child: MoveWindow(
          child: Container(),
        )),
        UserAvatar(
          onChangeIndex: widget.onChange,
        ),
      ],
    );
  }
}
