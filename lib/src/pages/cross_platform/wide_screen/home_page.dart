import 'package:bitsdojo_window/bitsdojo_window.dart';
import 'package:flutter/material.dart';
import 'package:tencent_cloud_chat_demo/src/conversation.dart';
import 'package:tencent_cloud_chat_demo/src/services/conversation_refresh_bus.dart';
import 'package:tencent_cloud_chat_demo/src/pages/cross_platform/wide_screen/contact_and_profile.dart';
import 'package:tencent_cloud_chat_demo/src/pages/cross_platform/wide_screen/me_and_tencent.dart';
import 'package:tencent_cloud_chat_demo/src/provider/login_user_Info.dart';
import 'package:tencent_cloud_chat_demo/src/services/app_update_service.dart';
import 'package:tencent_cloud_chat_sdk/manager/v2_tim_manager.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_conversation.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_conversation.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_message.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_message.dart';
import 'package:tencent_cloud_chat_uikit/tencent_cloud_chat_uikit.dart';
import 'package:tencent_cloud_chat_uikit/ui/utils/message_anchor.dart';
import 'package:tencent_cloud_chat_demo/src/pages/cross_platform/wide_screen/left_bar.dart';
import 'package:tencent_cloud_chat_demo/src/pages/cross_platform/wide_screen/desktop_profile_host.dart';
import 'package:tencent_cloud_chat_demo/src/pages/cross_platform/wide_screen/desktop_group_notice_host.dart';
import 'package:tencent_cloud_chat_demo/src/pages/cross_platform/wide_screen/desktop_archive_host.dart';
import 'package:tencent_cloud_chat_demo/src/pages/cross_platform/wide_screen/desktop_create_group_host.dart';
import 'package:tencent_cloud_chat_demo/src/provider/theme.dart';
import 'package:tencent_cloud_chat_uikit/theme/color.dart';
import 'package:tencent_cloud_chat_uikit/ui/utils/platform.dart';
import 'conversation_and_chat.dart';
import 'package:provider/provider.dart';
import 'package:tencent_cloud_chat_demo/src/utils/launch_system_ui.dart';
class HomePageWideScreen extends StatefulWidget {
  const HomePageWideScreen({Key? key}) : super(key: key);

  @override
  State<StatefulWidget> createState() => HomePageWideScreenState();
}

class HomePageWideScreenState extends State<HomePageWideScreen> {
  final V2TIMManager _sdkInstance = TIMUIKitCore.getSDKInstance();

  int homePageIndex = 0;
  V2TimConversation? currentC2CConversation;
  V2TimConversation? currentGroupConversation;
  MessageAnchor? currentC2CMessageAnchor;
  MessageAnchor? currentGroupMessageAnchor;

  @override
  initState() {
    super.initState();
    getLoginUserInfo();
    DesktopProfileHost.requestShowMessagesTab = _showMessagesTab;
    DesktopProfileHost.requestClosePeerPanels = _closeRightPanels;
    DesktopGroupNoticeHost.requestShowGroupTab = _showGroupTab;
    DesktopGroupNoticeHost.requestClosePeerPanels = _closeNoticePeers;
    DesktopArchiveHost.requestShowMessagesTab = _showMessagesTab;
    DesktopArchiveHost.requestShowGroupTab = _showGroupTab;
    DesktopArchiveHost.requestClosePeerPanels = _closeArchivePeers;
    DesktopCreateGroupHost.requestShowMessagesTab = _showMessagesTab;
    DesktopCreateGroupHost.requestShowGroupTab = _showGroupTab;
    DesktopCreateGroupHost.requestClosePeerPanels = _closeCreateGroupPeers;
    ConversationRefreshBus.instance.revision
        .addListener(_onConversationRefreshBus);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      LaunchSystemUi.completeStartup(context);
      Future<void>.delayed(const Duration(seconds: 2), () {
        if (mounted) {
          AppUpdateService.instance.check(context, manual: false);
        }
      });
    });
  }

  void _closeRightPanels() {
    DesktopGroupNoticeHost.close();
    DesktopArchiveHost.close();
    DesktopCreateGroupHost.close();
  }

  void _closeNoticePeers() {
    DesktopArchiveHost.close();
    DesktopCreateGroupHost.close();
  }

  void _closeArchivePeers() {
    DesktopGroupNoticeHost.close();
    DesktopCreateGroupHost.close();
  }

  void _closeCreateGroupPeers() {
    DesktopGroupNoticeHost.close();
    DesktopArchiveHost.close();
  }

  void _showMessagesTab() {
    if (!mounted) {
      return;
    }
    setState(() {
      homePageIndex = 0;
    });
  }

  void _showGroupTab() {
    if (!mounted) {
      return;
    }
    setState(() {
      homePageIndex = 1;
    });
  }

  @override
  void dispose() {
    if (DesktopProfileHost.requestShowMessagesTab == _showMessagesTab) {
      DesktopProfileHost.requestShowMessagesTab = null;
    }
    if (DesktopProfileHost.requestClosePeerPanels == _closeRightPanels) {
      DesktopProfileHost.requestClosePeerPanels = null;
    }
    if (DesktopGroupNoticeHost.requestShowGroupTab == _showGroupTab) {
      DesktopGroupNoticeHost.requestShowGroupTab = null;
    }
    if (DesktopGroupNoticeHost.requestClosePeerPanels == _closeNoticePeers) {
      DesktopGroupNoticeHost.requestClosePeerPanels = null;
    }
    if (DesktopArchiveHost.requestShowMessagesTab == _showMessagesTab) {
      DesktopArchiveHost.requestShowMessagesTab = null;
    }
    if (DesktopArchiveHost.requestShowGroupTab == _showGroupTab) {
      DesktopArchiveHost.requestShowGroupTab = null;
    }
    if (DesktopArchiveHost.requestClosePeerPanels == _closeArchivePeers) {
      DesktopArchiveHost.requestClosePeerPanels = null;
    }
    if (DesktopCreateGroupHost.requestShowMessagesTab == _showMessagesTab) {
      DesktopCreateGroupHost.requestShowMessagesTab = null;
    }
    if (DesktopCreateGroupHost.requestShowGroupTab == _showGroupTab) {
      DesktopCreateGroupHost.requestShowGroupTab = null;
    }
    if (DesktopCreateGroupHost.requestClosePeerPanels ==
        _closeCreateGroupPeers) {
      DesktopCreateGroupHost.requestClosePeerPanels = null;
    }
    ConversationRefreshBus.instance.revision
        .removeListener(_onConversationRefreshBus);
    super.dispose();
  }

  void _onConversationRefreshBus() {
    if (ConversationRefreshBus.instance.lastReason != 'group_self_removed') {
      return;
    }
    final targetId =
        ConversationRefreshBus.instance.lastConversationId?.trim() ?? '';
    final currentId = currentGroupConversation?.conversationID?.trim() ?? '';
    if (targetId.isNotEmpty &&
        currentId.isNotEmpty &&
        targetId != currentId) {
      return;
    }
    if (!mounted) {
      return;
    }
    setState(() {
      currentGroupConversation = null;
      currentGroupMessageAnchor = null;
    });
  }

  _navigateToChat(V2TimConversation conversation, [MessageAnchor? anchor]) {
    final isGroup = conversation.type == 2 ||
        ((conversation.groupID ?? '').trim().isNotEmpty) ||
        ((conversation.conversationID ?? '').toUpperCase().startsWith('GROUP'));
    DesktopProfileHost.close();
    DesktopGroupNoticeHost.close();
    DesktopArchiveHost.close();
    DesktopCreateGroupHost.close();
    setState(() {
      homePageIndex = isGroup ? 1 : 0;
      if (isGroup) {
        currentGroupConversation = conversation;
        currentGroupMessageAnchor = anchor;
      } else {
        currentC2CConversation = conversation;
        currentC2CMessageAnchor = anchor;
      }
    });
  }

  getLoginUserInfo() async {
    if (PlatformUtils().isWeb) {
      return;
    }
    final res = await _sdkInstance.getLoginUser();
    if (res.code == 0) {
      final result = await _sdkInstance.getUsersInfo(userIDList: [res.data!]);

      if (result.code == 0) {
        Provider.of<LoginUserInfo>(context, listen: false)
            .setLoginUserInfo(result.data![0]);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Provider.of<DefaultThemeData>(context).theme;
    final sideBarColor =
        theme.chatHeaderBgColor ?? theme.appbarBgColor ?? hexToColor("3f4c68");
    final sideBarTextColor = theme.appbarTextColor ?? Colors.white;
    return Row(
      children: [
        Container(
          width: 64,
          decoration: BoxDecoration(
              color: sideBarColor),
          child: Row(
            mainAxisSize: MainAxisSize.max,
            children: [
              Expanded(
                child: LeftBar(
                  index: homePageIndex,
                  onChange: (index) {
                    if (index != 0 && index != 1) {
                      DesktopProfileHost.close();
                      DesktopGroupNoticeHost.close();
                      DesktopArchiveHost.close();
                      DesktopCreateGroupHost.close();
                    } else if (index == 0) {
                      DesktopGroupNoticeHost.close();
                      if (DesktopArchiveHost.scope ==
                          DesktopArchiveScope.group) {
                        DesktopArchiveHost.close();
                      }
                      if (DesktopCreateGroupHost.args?.scope ==
                          DesktopCreateGroupScope.group) {
                        DesktopCreateGroupHost.close();
                      }
                    } else if (index == 1) {
                      DesktopProfileHost.close();
                      if (DesktopArchiveHost.scope == DesktopArchiveScope.c2c) {
                        DesktopArchiveHost.close();
                      }
                      if (DesktopCreateGroupHost.args?.scope ==
                          DesktopCreateGroupScope.c2c) {
                        DesktopCreateGroupHost.close();
                      }
                    }
                    setState(() {
                      homePageIndex = index;
                    });
                  },
                ),
              )
            ],
          ),
        ),
        Expanded(
            child: Column(
              children: [
                if(PlatformUtils().isWindows) Container(
                  height: 40,
                  decoration: BoxDecoration(
                      color: sideBarColor),
                child: Row(
                  children: [
                    Expanded(child: MoveWindow()),
                    MinimizeWindowButton(colors: WindowButtonColors(
                      iconNormal: sideBarTextColor
                    ),),
                    MaximizeWindowButton(colors: WindowButtonColors(
                        iconNormal: sideBarTextColor
                    ),),
                    CloseWindowButton(colors: WindowButtonColors(
                        iconNormal: sideBarTextColor
                    ),)
                  ],
                ),),
                Expanded(child: IndexedStack(
                  index: homePageIndex,
                  children: [
                    ConversationAndChat(
                      conversation: currentC2CConversation,
                      searchJumpAnchor: currentC2CMessageAnchor,
                      listScope: ConversationListScope.c2c,
                      showDesktopUserProfile: true,
                    ),
                    ConversationAndChat(
                      conversation: currentGroupConversation,
                      searchJumpAnchor: currentGroupMessageAnchor,
                      listScope: ConversationListScope.group,
                      showDesktopUserProfile: true,
                    ),
                    ContactsAndProfile(onNavigateToChat: _navigateToChat),
                    const MeAndTencent(),
                  ],
                ))
              ],
            )
        )
      ],
    );
  }
}
