import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tencent_cloud_chat_demo/src/i18n/app_i18n.dart';
import 'package:tencent_cloud_chat_demo/src/provider/theme.dart';
import 'package:tencent_cloud_chat_demo/utils/friend_add_source.dart';
import 'package:tencent_cloud_chat_demo/src/user_profile.dart';
import 'package:tencent_cloud_chat_sdk/manager/v2_tim_manager.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_conversation.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_conversation.dart';
import 'package:tencent_cloud_chat_uikit/tencent_cloud_chat_uikit.dart';
import 'package:tencent_cloud_chat_uikit/ui/utils/screen_utils.dart';
import 'package:tencent_cloud_chat_demo/src/navigation/app_page_transitions.dart';

class AddFriend extends StatelessWidget {
  final ValueChanged<V2TimConversation>? directToChat;
  final VoidCallback? closeFunc;

  const AddFriend({Key? key, this.directToChat, this.closeFunc}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = Provider.of<DefaultThemeData>(context).theme;
    final i18n = AppI18n.of(context);
    return TUIKitScreenUtils.getDeviceWidget(
        context: context,
        desktopWidget: TIMUIKitAddFriend(
          closeFunc: closeFunc,
          addSource: FriendAddSource.search,
          onTapAlreadyFriendsItem: (String userID) async {
            final V2TIMManager _sdkInstance = TIMUIKitCore.getSDKInstance();
            final conversationID = "c2c_$userID";
            final res = await _sdkInstance.getConversationManager().getConversation(conversationID: conversationID);

            if (res.code == 0) {
              final conversation = res.data ?? V2TimConversation(conversationID: conversationID, userID: userID, type: 1);
              if (directToChat != null) {
                directToChat!(conversation);
              }
            }
          },
        ),
        defaultWidget: Scaffold(
          backgroundColor: theme.weakBackgroundColor ?? Colors.white,
          appBar: AppBar(
            shadowColor: theme.weakDividerColor,
            surfaceTintColor: Colors.transparent,
            iconTheme: IconThemeData(
              color: theme.primaryColor ?? const Color(0xFF1E90FF),
            ),
            title: Text(
              i18n.t(
                zhHans: '添加好友',
                zhHant: '添加好友',
                en: 'Add Friend',
                ja: '友達を追加',
                ko: '친구 추가',
              ),
              style: TextStyle(
                color: theme.primaryColor ?? const Color(0xFF1E90FF),
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            backgroundColor: theme.appbarBgColor ?? Colors.white,
          ),
          body: TIMUIKitAddFriend(
            addSource: FriendAddSource.search,
            onTapAlreadyFriendsItem: (String userID) {
              Navigator.push(
                  context,
                  AppMaterialPageRoute(
                    builder: (context) => UserProfile(userID: userID),
                  ));
            },
          ),
        ));
  }
}
