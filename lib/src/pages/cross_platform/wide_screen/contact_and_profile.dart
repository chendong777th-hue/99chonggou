import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tencent_cloud_chat_demo/src/contact.dart';
import 'package:tencent_cloud_chat_demo/src/group_list.dart';
import 'package:tencent_cloud_chat_demo/src/i18n/app_i18n.dart';
import 'package:tencent_cloud_chat_demo/src/multi_platform_widget/search_entry/search_entry.dart';
import 'package:tencent_cloud_chat_demo/src/multi_platform_widget/search_entry/search_entry_wide.dart';
import 'package:tencent_cloud_chat_demo/src/pages/cross_platform/wide_screen/empty_widget.dart';
import 'package:tencent_cloud_chat_demo/src/provider/theme.dart';
import 'package:tencent_cloud_chat_demo/src/search.dart';
import 'package:tencent_cloud_chat_demo/src/user_profile.dart';
import 'package:tencent_cloud_chat_demo/utils/toast.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_conversation.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_conversation.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_message.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_message.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_group_info.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_group_info.dart';
import 'package:tencent_cloud_chat_uikit/tencent_cloud_chat_uikit.dart';
import 'package:tencent_cloud_chat_uikit/theme/color.dart';
import 'package:tencent_cloud_chat_uikit/ui/controller/tim_uikit_conversation_controller.dart';
import 'package:tencent_cloud_chat_uikit/ui/utils/message_anchor.dart';
import 'package:tencent_cloud_chat_uikit/ui/utils/platform.dart';

class ContactsAndProfile extends StatefulWidget {
  final void Function(V2TimConversation conversation, [MessageAnchor? anchor])
      onNavigateToChat;

  const ContactsAndProfile({Key? key, required this.onNavigateToChat})
      : super(key: key);

  @override
  State<ContactsAndProfile> createState() => _ContactsAndProfileState();
}

class _ContactsAndProfileState extends State<ContactsAndProfile> {
  final TIMUIKitConversationController _conversationController =
      TIMUIKitConversationController();

  bool isShowSearch = false;
  String? selectedItem;

  @override
  Widget build(BuildContext context) {
    final theme = Provider.of<DefaultThemeData>(context).theme;
    return Row(
      children: [
        ConstrainedBox(
          constraints: const BoxConstraints(minWidth: 300, maxWidth: 340),
          child: isShowSearch
              ? Search(
                  onTapConversation: (conversation, anchor) {
                    widget.onNavigateToChat(conversation, anchor);
                    setState(() => isShowSearch = false);
                  },
                  isAutoFocus: true,
                  onBack: () => setState(() => isShowSearch = false),
                )
              : DefaultTabController(
                  length: 2,
                  child: Container(
                    color: theme.wideBackgroundColor,
                    child: Column(
                      children: [
                        SearchEntry(
                          conversationController: _conversationController,
                          plusType: PlusType.add,
                          directToChat: (conversation) =>
                              widget.onNavigateToChat(conversation),
                          onClickSearch: () {
                            if (kIsWeb || PlatformUtils().isWeb) {
                              ToastUtils.toast(AppI18n.of(context).t(
                                zhHans: '网页端暂不支持消息搜索',
                                zhHant: '網頁端暫不支援訊息搜尋',
                                en: 'Message search is not available on Web',
                                ja: 'Webではメッセージ検索に対応していません',
                                ko: '웹에서는 메시지 검색을 지원하지 않습니다',
                              ));
                              return;
                            }
                            setState(() => isShowSearch = true);
                          },
                        ),
                        Container(
                          margin: const EdgeInsets.only(bottom: 4),
                          child: TabBar(
                            isScrollable: true,
                            labelColor: theme.primaryColor,
                            labelStyle: const TextStyle(fontWeight: FontWeight.bold),
                            unselectedLabelColor:
                                theme.weakTextColor ?? hexToColor('62626b'),
                            unselectedLabelStyle:
                                const TextStyle(fontWeight: FontWeight.normal),
                            indicatorSize: TabBarIndicatorSize.label,
                            indicatorColor:
                                theme.primaryColor ?? hexToColor('62626b'),
                            tabs: const [
                              Padding(
                                padding: EdgeInsets.fromLTRB(10, 0, 10, 6),
                                child: Text('\u901a\u8baf\u5f55'),
                              ),
                              Padding(
                                padding: EdgeInsets.fromLTRB(10, 0, 10, 6),
                                child: Text('\u7fa4\u804a'),
                              ),
                            ],
                          ),
                        ),
                        Expanded(
                          child: TabBarView(
                            children: [
                              Contact(
                                onTapItem: (userID) {
                                  setState(() => selectedItem = userID);
                                },
                              ),
                              GroupList(
                                onTapItem: (
                                  V2TimGroupInfo groupInfo,
                                  V2TimConversation conversation,
                                ) {
                                  widget.onNavigateToChat(conversation);
                                },
                              ),
                            ],
                          ),
                        )
                      ],
                    ),
                  ),
                ),
        ),
        SizedBox(
          width: 1,
          child: Container(color: theme.weakDividerColor),
        ),
        if (selectedItem == null || selectedItem!.isEmpty)
          const Expanded(
            child: EmptyWidget(
              title: '\u901a\u8baf\u5f55 & \u7fa4\u804a',
              description: '\u8bf7\u9009\u62e9\u8054\u7cfb\u4eba\u6216\u7fa4\u804a\uff0c\u4ee5\u67e5\u770b\u8be6\u60c5',
            ),
          ),
        if (selectedItem != null &&
            selectedItem!.isNotEmpty &&
            !selectedItem!.startsWith('group_'))
          Expanded(
            child: UserProfile(
              userID: selectedItem!,
              onClickSendMessage: (V2TimConversation conversation) {
                widget.onNavigateToChat(conversation);
              },
            ),
          )
      ],
    );
  }
}
