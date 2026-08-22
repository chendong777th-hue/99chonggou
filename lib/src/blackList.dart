// ignore_for_file: file_names

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tencent_cloud_chat_demo/src/i18n/app_i18n.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_friend_info.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_friend_info.dart';
import 'package:tencent_cloud_chat_uikit/tencent_cloud_chat_uikit.dart';

import 'package:tencent_cloud_chat_demo/src/provider/theme.dart';
import 'package:tencent_cloud_chat_demo/src/user_profile.dart';
import 'package:tencent_cloud_chat_demo/utils/profile_page_nav.dart';
import 'package:tencent_cloud_chat_uikit/ui/utils/screen_utils.dart';
import 'package:tencent_cloud_chat_demo/src/navigation/app_page_transitions.dart';

class BlackList extends StatelessWidget {
  const BlackList({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = Provider.of<DefaultThemeData>(context).theme;
    final i18n = AppI18n.of(context);

    Widget blockedUsers() {
      return TIMUIKitBlackList(
        emptyBuilder: (_) {
          return Center(
            child: Text(i18n.t(
              zhHans: '暂无黑名单',
              zhHant: '暫無黑名單',
              en: 'No blocked users',
              ja: 'ブロック中のユーザーはいません',
              ko: '차단한 사용자가 없습니다',
            )),
          );
        },
        onTapItem: (V2TimFriendInfo friendInfo) {
          final isWideScreen =
              TUIKitScreenUtils.getFormFactor(context) == DeviceType.Desktop;
          if (isWideScreen) {
            ProfilePageNav.openUserProfile(
              context,
              userID: friendInfo.userID,
            );
            return;
          }
          Navigator.push(
            context,
            AppMaterialPageRoute(
              builder: (context) => UserProfile(userID: friendInfo.userID),
            ),
          );
        },
      );
    }

    return TUIKitScreenUtils.getDeviceWidget(
        context: context,
        desktopWidget: blockedUsers(),
        defaultWidget: Scaffold(
          backgroundColor: theme.weakBackgroundColor ?? Colors.white,
          appBar: AppBar(
              surfaceTintColor: Colors.transparent,
              title: Text(
                i18n.t(
                  zhHans: '黑名单',
                  zhHant: '黑名單',
                  en: 'Blocklist',
                  ja: 'ブロックリスト',
                  ko: '차단 목록',
                ),
                style: TextStyle(
                  color: theme.appbarTextColor ?? theme.darkTextColor ?? Colors.black,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              backgroundColor: theme.appbarBgColor ?? Colors.white,
              shadowColor: theme.weakDividerColor,
              iconTheme: IconThemeData(
                color: theme.primaryColor ?? const Color(0xFF1E90FF),
              )),
          body: blockedUsers(),
        ));
  }
}
