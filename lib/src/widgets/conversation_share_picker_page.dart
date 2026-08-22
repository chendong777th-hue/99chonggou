import 'package:flutter/material.dart';
import 'package:tencent_cloud_chat_demo/src/i18n/app_i18n.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_conversation.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_conversation.dart';
import 'package:tencent_cloud_chat_uikit/tencent_cloud_chat_uikit.dart';
import 'package:tencent_cloud_chat_uikit/theme/tui_theme.dart';
import 'package:tencent_cloud_chat_uikit/ui/widgets/contact_style_entry_item.dart';
import 'package:tencent_cloud_chat_uikit/ui/widgets/recent_conversation_list.dart';
import 'package:tencent_cloud_chat_demo/src/navigation/app_page_transitions.dart';
import 'package:tencent_cloud_chat_demo/src/ui/components/app_search_bar.dart';
import 'package:tencent_cloud_chat_demo/src/widgets/forward_pick_pages.dart';

/// 分享内容时选择的会话目标（单聊或群聊）。
class ConversationShareTarget {
  final String userID;
  final String groupID;

  const ConversationShareTarget({
    this.userID = '',
    this.groupID = '',
  });

  factory ConversationShareTarget.fromConversation(V2TimConversation conversation) {
    final isC2C = conversation.type == 1;
    return ConversationShareTarget(
      userID: isC2C ? (conversation.userID ?? '') : '',
      groupID: isC2C ? '' : (conversation.groupID ?? ''),
    );
  }
}

/// 选择朋友 / 群聊 / 最近会话，用于分享文本。
class ConversationSharePickerPage extends StatefulWidget {
  final TUITheme theme;

  const ConversationSharePickerPage({
    super.key,
    required this.theme,
  });

  @override
  State<ConversationSharePickerPage> createState() =>
      _ConversationSharePickerPageState();
}

class _ConversationSharePickerPageState
    extends State<ConversationSharePickerPage> {
  final TextEditingController _searchController = TextEditingController();
  String _keyword = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _openFriendPicker() async {
    final target = await Navigator.push<ConversationShareTarget>(
      context,
      AppMaterialPageRoute(
        builder: (context) => ForwardSelectFriendPage(
          onTapItem: (item) async {
            final conversationID = 'c2c_${item.userID}';
            final res = await TIMUIKitCore.getSDKInstance()
                .getConversationManager()
                .getConversation(conversationID: conversationID);
            final conversation = res.data ??
                V2TimConversation(
                  conversationID: conversationID,
                  type: 1,
                  userID: item.userID,
                  showName: item.userProfile?.nickName ?? item.userID,
                  faceUrl: item.userProfile?.faceUrl,
                );
            if (!context.mounted) return;
            Navigator.pop(
              context,
              ConversationShareTarget.fromConversation(conversation),
            );
          },
        ),
      ),
    );
    if (!mounted || target == null) return;
    Navigator.pop(context, target);
  }

  Future<void> _openGroupPicker() async {
    final target = await Navigator.push<ConversationShareTarget>(
      context,
      AppMaterialPageRoute(
        builder: (context) => ForwardSelectGroupPage(
          onTapItem: (groupInfo, conversation) {
            Navigator.pop(
              context,
              ConversationShareTarget.fromConversation(conversation),
            );
          },
        ),
      ),
    );
    if (!mounted || target == null) return;
    Navigator.pop(context, target);
  }

  Widget _buildSearchBar(TUITheme theme) {
    return buildAppSearchBarInset(
      context: context,
      controller: _searchController,
      onChanged: (value) => setState(() => _keyword = value.trim()),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = widget.theme;
    final i18n = AppI18n.of(context);
    final backgroundColor =
        theme.weakBackgroundColor ?? theme.wideBackgroundColor ?? Colors.white;
    final appBarColor = theme.appbarBgColor ?? backgroundColor;
    final titleColor = theme.appbarTextColor ?? theme.darkTextColor;

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        centerTitle: true,
        elevation: 0,
        shadowColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        backgroundColor: appBarColor,
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: Icon(Icons.close, color: titleColor),
        ),
        title: Text(
          i18n.t(
            zhHans: '选择会话',
            zhHant: '選擇會話',
            en: 'Select Chat',
            ja: '会話を選択',
            ko: '대화 선택',
          ),
          style: TextStyle(
            color: titleColor,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: Column(
        children: [
          _buildSearchBar(theme),
          ContactStyleEntryItem(
            icon: contactStyleEntryIcon(
              context,
              theme,
              entryId: 'friend',
            ),
            title: i18n.t(
              zhHans: '选择朋友',
              zhHant: '選擇朋友',
              en: 'Select Friend',
              ja: '友達を選択',
              ko: '친구 선택',
            ),
            onTap: _openFriendPicker,
          ),
          ContactStyleEntryItem(
            icon: contactStyleEntryIcon(
              context,
              theme,
              entryId: 'group',
            ),
            title: i18n.t(
              zhHans: '选择群聊',
              zhHant: '選擇群聊',
              en: 'Select Group',
              ja: 'グループを選択',
              ko: '그룹 선택',
            ),
            onTap: _openGroupPicker,
            showDivider: false,
          ),
          Expanded(
            child: RecentForwardList(
              isMultiSelect: false,
              keyword: _keyword,
              sectionTitle: i18n.t(
                zhHans: '最近',
                zhHant: '最近',
                en: 'Recent',
                ja: '最近',
                ko: '최근',
              ),
              showSectionHeader: true,
              onChanged: (conversationList) {
                if (conversationList.isNotEmpty) {
                  Navigator.pop(
                    context,
                    ConversationShareTarget.fromConversation(conversationList.first),
                  );
                }
              },
            ),
          ),
        ],
      ),
    );
  }
}
