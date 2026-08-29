import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tencent_cloud_chat_demo/src/i18n/app_i18n.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_conversation.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_conversation.dart';
import 'package:tencent_cloud_chat_demo/src/provider/theme.dart';
import 'package:tencent_cloud_chat_demo/src/navigation/app_chat_route.dart';
import 'package:tencent_cloud_chat_demo/src/widgets/self_hosted_add_group.dart';
import 'package:tencent_cloud_chat_uikit/ui/utils/screen_utils.dart';

class AddGroup extends StatelessWidget {
  final ValueChanged<V2TimConversation>? directToChat;
  final VoidCallback? closeFunc;

  const AddGroup({Key? key, this.directToChat, this.closeFunc})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = Provider.of<DefaultThemeData>(context).theme;
    final i18n = AppI18n.of(context);
    return TUIKitScreenUtils.getDeviceWidget(
        context: context,
        desktopWidget: SelfHostedAddGroup(
          closeFunc: closeFunc,
          onTapExistGroup: (groupID, conversation) {
            if (directToChat != null) {
              directToChat!(conversation);
            }
          },
        ),
        defaultWidget: Scaffold(
          backgroundColor: theme.weakBackgroundColor ?? Colors.white,
          appBar: AppBar(
            shadowColor: theme.weakDividerColor,
            surfaceTintColor: Colors.transparent,
            title: Text(
              i18n.t(
                zhHans: '添加群聊',
                zhHant: '添加群聊',
                en: 'Join Group',
                ja: 'グループに参加',
                ko: '그룹 추가',
              ),
              style: TextStyle(
                color: theme.primaryColor ?? const Color(0xFF1E90FF),
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            backgroundColor: theme.appbarBgColor ?? Colors.white,
          ),
          body: SelfHostedAddGroup(
            onTapExistGroup: (groupID, conversation) {
              openOrReuseAppChat(context, conversation);
            },
          ),
        ));
  }
}
