import 'package:flutter/material.dart';
import 'package:tencent_cloud_chat_demo/utils/friend_add_source.dart';
import 'package:tencent_cloud_chat_demo/src/ui/app_responsive.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_user_full_info.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_user_full_info.dart';
import 'package:tencent_cloud_chat_uikit/data_services/friendShip/friendship_services.dart';
import 'package:tencent_cloud_chat_uikit/data_services/services_locatar.dart';
import 'package:tencent_cloud_chat_uikit/theme/tui_theme.dart';
import 'package:tencent_cloud_chat_uikit/ui/utils/add_friend_navigator.dart';
import 'package:tencent_cloud_chat_uikit/ui/utils/error_message_converter.dart';

class C2cFriendMessageBlockedBar extends StatelessWidget {
  const C2cFriendMessageBlockedBar({
    super.key,
    required this.peerUserId,
    required this.theme,
  });

  final String peerUserId;
  final TUITheme theme;

  Future<void> _openReAddFriendPage(BuildContext context) async {
    final userID = peerUserId.trim();
    if (userID.isEmpty || !context.mounted) {
      return;
    }
    final friendshipServices = serviceLocator<FriendshipServices>();
    final users = await friendshipServices.getUsersInfo(userIDList: [userID]);
    if (!context.mounted) {
      return;
    }
    final friendInfo = (users != null && users.isNotEmpty)
        ? users.first
        : V2TimUserFullInfo(userID: userID);

    final openAddFriend = AddFriendNavigator.openAddFriendPage;
    if (openAddFriend != null) {
      await openAddFriend(
        context,
        userID: userID,
        friendInfo: friendInfo,
        addSource: FriendAddSource.chat,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = AppResponsive.isDesktop(context);
    final screenWidth = AppResponsive.screenWidth(context);
    final textScale = AppResponsive.textScale(context);
    final dark = Theme.of(context).brightness == Brightness.dark;
    final colorScheme = Theme.of(context).colorScheme;

    final linkColor = theme.primaryColor ?? colorScheme.primary;
    // Match the chat input chrome (weakBackground), not message-list bg.
    // Using chatBgColor made the home-indicator strip look like a white gap
    // when the banner itself reads as light gray.
    final surfaceColor = theme.weakBackgroundColor ??
        theme.wideBackgroundColor ??
        colorScheme.surface;
    final dividerColor = (theme.weakDividerColor ??
            colorScheme.outlineVariant)
        .withOpacity(dark ? 0.55 : 0.75);
    final mutedTextColor = theme.weakTextColor ??
        colorScheme.onSurface.withOpacity(dark ? 0.62 : 0.56);
    final iconBgColor = mutedTextColor.withOpacity(dark ? 0.14 : 0.08);

    final horizontalPadding = isDesktop ? 16.0 : (screenWidth < 360 ? 14.0 : 16.0);
    final verticalPadding = isDesktop ? 12.0 : 10.0;
    final messageStyle = TextStyle(
      fontSize: isDesktop ? 13.0 : 13.5,
      height: 1.25,
      color: mutedTextColor,
      fontWeight: FontWeight.w400,
    );
    final linkStyle = TextStyle(
      fontSize: isDesktop ? 13.0 : 13.5,
      height: 1.25,
      color: linkColor,
      fontWeight: FontWeight.w600,
    );

    final shouldStackAction =
        !isDesktop && (screenWidth < 360 || textScale > 1.18);

    Widget buildMessageText({required TextAlign textAlign}) {
      return Text.rich(
        TextSpan(
          style: messageStyle,
          children: [
            TextSpan(
              text: ErrorMessageConverter.friendDeletedByOtherHintPrefix,
            ),
            WidgetSpan(
              alignment: PlaceholderAlignment.baseline,
              baseline: TextBaseline.alphabetic,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => _openReAddFriendPage(context),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Text(
                    ErrorMessageConverter.friendDeletedByOtherHintLink,
                    style: linkStyle,
                  ),
                ),
              ),
            ),
          ],
        ),
        textAlign: textAlign,
      );
    }

    // SafeArea must sit *inside* the painted surface. If it wraps Material,
    // the home-indicator inset is unpainted and looks like a white gap under
    // the bar.
    return Material(
      color: surfaceColor,
      child: SafeArea(
        top: false,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: surfaceColor,
            border: Border(
              top: BorderSide(color: dividerColor, width: 0.5),
            ),
          ),
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              horizontalPadding,
              verticalPadding,
              horizontalPadding,
              verticalPadding + (isDesktop ? 2.0 : 4.0),
            ),
            child: shouldStackAction
                ? Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _BlockedIconBadge(
                            backgroundColor: iconBgColor,
                            iconColor: mutedTextColor,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: buildMessageText(
                              textAlign: TextAlign.start,
                            ),
                          ),
                        ],
                      ),
                    ],
                  )
                : Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      _BlockedIconBadge(
                        backgroundColor: iconBgColor,
                        iconColor: mutedTextColor,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: buildMessageText(textAlign: TextAlign.start),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}

class _BlockedIconBadge extends StatelessWidget {
  const _BlockedIconBadge({
    required this.backgroundColor,
    required this.iconColor,
  });

  final Color backgroundColor;
  final Color iconColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: backgroundColor,
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: Icon(
        Icons.person_off_outlined,
        size: 18,
        color: iconColor,
      ),
    );
  }
}
