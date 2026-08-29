import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tencent_cloud_chat_demo/src/i18n/app_i18n.dart';
import 'package:tencent_cloud_chat_demo/src/provider/theme.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_conversation.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_conversation.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_message.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_message.dart';
import 'package:tencent_cloud_chat_uikit/ui/controller/tim_uikit_conversation_controller.dart';
import 'package:tencent_cloud_chat_uikit/ui/utils/message_anchor.dart';
import 'package:tencent_cloud_chat_demo/src/navigation/app_chat_route.dart';
import 'package:tencent_cloud_chat_demo/src/search.dart';
import 'package:tencent_cloud_chat_demo/src/navigation/app_page_transitions.dart';

class SearchEntryNarrow extends StatefulWidget{
  final TIMUIKitConversationController conversationController;
  const SearchEntryNarrow({Key? key, required this.conversationController}) : super(key: key);

  @override
  State<SearchEntryNarrow> createState() => _SearchEntryNarrowState();
}

class _SearchEntryNarrowState extends State<SearchEntryNarrow> {
  late TIMUIKitConversationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = widget.conversationController;
  }

  void _handleOnConvItemTapedWithPlace(V2TimConversation? selectedConv,
      [MessageAnchor? anchor]) async {
    await openChatWithAnchor(context, selectedConv!, anchor: anchor);
    _controller.reloadData(count: 40);
  }

  Future<void> _openSearch() async {
    if (!mounted) return;
    await Navigator.push(
      context,
      AppMaterialPageRoute(
        settings: const RouteSettings(name: AppRoutes.search),
        builder: (context) => Search(
          onTapConversation: _handleOnConvItemTapedWithPlace,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Provider.of<DefaultThemeData>(context).theme;
    final iconColor =
        (theme.appbarTextColor ?? const Color(0xFF979797)).withValues(alpha: 0.7);
    return GestureDetector(
      onTap: _openSearch,
      child: Container(
        decoration: BoxDecoration(
          color: theme.appbarBgColor ?? Colors.white,
          boxShadow: const [],
          border: Border(
            bottom: BorderSide(
              color: theme.weakDividerColor ?? const Color(0xFFE5E6E9),
              width: 0.6,
            ),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
          child: Container(
            decoration: BoxDecoration(
              color: theme.inputFillColor ?? const Color(0xFFF7F7F8),
              borderRadius: const BorderRadius.all(Radius.circular(10)),
            ),
            height: 40,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                children: [
                  Icon(Icons.search, color: iconColor, size: 19),
                  const SizedBox(width: 8),
                  Text(
                    AppI18n.of(context).t(
                      zhHans: '搜索',
                      zhHant: '搜尋',
                      en: 'Search',
                      ja: '検索',
                      ko: '검색',
                    ),
                    style: TextStyle(
                      color: iconColor,
                      fontSize: 15,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
