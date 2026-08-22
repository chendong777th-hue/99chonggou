import 'package:flutter/material.dart';
import 'package:lpinyin/lpinyin.dart';
import 'package:provider/provider.dart';
import 'package:tencent_cloud_chat_demo/src/i18n/app_i18n.dart';
import 'package:tencent_cloud_chat_demo/src/provider/theme.dart';
import 'package:tencent_cloud_chat_demo/src/services/platform_official_account_service.dart';
import 'package:tencent_cloud_chat_demo/src/ui/components/app_search_bar.dart';
import 'package:tencent_cloud_chat_demo/src/widgets/contact_list_with_presence.dart';
import 'package:tencent_cloud_chat_demo/src/widgets/message_notification_banner.dart';
import 'package:tencent_cloud_chat_demo/src/widgets/contact_style_search_bar.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_conversation.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_conversation.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_friend_info.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_friend_info.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_group_info.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_group_info.dart';
import 'package:tencent_cloud_chat_sdk/tencent_im_sdk_plugin.dart';
import 'package:tencent_cloud_chat_uikit/business_logic/view_models/tui_chat_global_model.dart';
import 'package:tencent_cloud_chat_uikit/data_services/services_locatar.dart';
import 'package:tencent_cloud_chat_uikit/ui/views/TIMUIKitGroup/tim_uikit_group.dart';

void registerAppUIKitExtensions(TUIChatGlobalModel globalModel) {
  globalModel.appSearchBarBuilder ??=
      (context, controller, onChanged) {
    return buildAppSearchBarInset(
      context: context,
      controller: controller,
      onChanged: onChanged,
    );
  };
  globalModel.appForwardSelectFriendPage =
      (context) => const ForwardSelectFriendPage();
  globalModel.appForwardSelectGroupPage =
      (context) => const ForwardSelectGroupPage();
  globalModel.appRootNavigator = () => AppNavigator.key.currentState;
}

void installForwardPickPages() {
  setupServiceLocator();
  TUIChatGlobalModel.registerAppExtensions = registerAppUIKitExtensions;
  registerAppUIKitExtensions(serviceLocator<TUIChatGlobalModel>());
}

Future<V2TimConversation?> openForwardSelectFriendPage(BuildContext context) {
  TUIChatGlobalModel.ensureAppExtensionsRegistered();
  return Navigator.of(context).push<V2TimConversation>(
    MaterialPageRoute(
      builder: (context) => const ForwardSelectFriendPage(),
    ),
  );
}

Future<V2TimConversation?> openForwardSelectGroupPage(BuildContext context) {
  TUIChatGlobalModel.ensureAppExtensionsRegistered();
  return Navigator.of(context).push<V2TimConversation>(
    MaterialPageRoute(
      builder: (context) => const ForwardSelectGroupPage(),
    ),
  );
}

class ForwardSelectFriendPage extends StatefulWidget {
  final void Function(V2TimFriendInfo friend)? onTapItem;
  final String? title;

  const ForwardSelectFriendPage({
    super.key,
    this.onTapItem,
    this.title,
  });

  @override
  State<ForwardSelectFriendPage> createState() =>
      _ForwardSelectFriendPageState();
}

class _ForwardSelectFriendPageState extends State<ForwardSelectFriendPage> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  String _friendName(V2TimFriendInfo item) {
    final remark = item.friendRemark?.trim() ?? '';
    if (remark.isNotEmpty) return remark;
    final nick = item.userProfile?.nickName?.trim() ?? '';
    if (nick.isNotEmpty) return nick;
    return item.userID;
  }

  bool _matchesSearch(V2TimFriendInfo item, String keyword) {
    if (keyword.isEmpty) {
      return true;
    }
    final name = _friendName(item);
    final pinyin = PinyinHelper.getPinyinE(name).toLowerCase();
    final haystack = '${item.userID} $name $pinyin'.toLowerCase();
    return haystack.contains(keyword);
  }

  Future<V2TimConversation> _buildConversation(V2TimFriendInfo item) async {
    final conversationID = 'c2c_${item.userID}';
    final res = await TencentImSDKPlugin.v2TIMManager
        .getConversationManager()
        .getConversation(conversationID: conversationID);
    if (res.code == 0 && res.data != null) {
      return res.data!;
    }
    return V2TimConversation(
      conversationID: conversationID,
      userID: item.userID,
      type: 1,
      showName: item.friendRemark?.isNotEmpty == true
          ? item.friendRemark
          : ((item.userProfile?.nickName?.isNotEmpty == true)
              ? item.userProfile?.nickName
              : item.userID),
      faceUrl: item.userProfile?.faceUrl,
    );
  }

  Future<void> _handleTap(V2TimFriendInfo item) async {
    if (widget.onTapItem != null) {
      widget.onTapItem!(item);
      return;
    }
    final conversation = await _buildConversation(item);
    if (!mounted) return;
    Navigator.pop(context, conversation);
  }

  Widget _buildSearchBar(BuildContext context) {
    final builder = serviceLocator<TUIChatGlobalModel>().appSearchBarBuilder;
    if (builder != null) {
      return builder(
        context,
        _searchController,
        (_) => setState(() {}),
      );
    }
    return ContactStyleSearchBar(
      controller: _searchController,
      onChanged: (_) => setState(() {}),
      showCancel: false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Provider.of<DefaultThemeData>(context).theme;
    final i18n = AppI18n.of(context);
    final keyword = _searchController.text.trim().toLowerCase();
    final title = widget.title ??
        i18n.t(
          zhHans: '选择朋友',
          zhHant: '選擇朋友',
          en: 'Select Friend',
          ja: '友達を選択',
          ko: '친구 선택',
        );

    return Scaffold(
      backgroundColor: theme.weakBackgroundColor ?? Colors.white,
      appBar: AppBar(
        centerTitle: true,
        elevation: 0,
        shadowColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        backgroundColor: theme.appbarBgColor ?? theme.weakBackgroundColor,
        title: Text(
          title,
          style: TextStyle(
            color: theme.appbarTextColor ?? theme.darkTextColor,
            fontSize: 17,
            fontWeight: FontWeight.w600,
          ),
        ),
        iconTheme: IconThemeData(
          color: theme.primaryColor ?? const Color(0xFF1E90FF),
        ),
      ),
      body: Column(
        children: [
          _buildSearchBar(context),
          Expanded(
            child: ContactListWithPresence(
              isShowOnlineStatus: true,
              onTapItem: _handleTap,
              filterItem: (item) {
                if (PlatformOfficialAccountService.shouldHideFromContactAndPickers(
                    item.userID)) {
                  return false;
                }
                return _matchesSearch(item, keyword);
              },
              emptyBuilder: (_) => Center(
                child: Text(
                  keyword.isEmpty
                      ? i18n.t(
                          zhHans: '暂无联系人',
                          zhHant: '暫無聯絡人',
                          en: 'No contacts',
                          ja: '連絡先がありません',
                          ko: '연락처 없음',
                        )
                      : i18n.t(
                          zhHans: '未找到相关联系人',
                          zhHant: '未找到相關聯絡人',
                          en: 'No matching contacts',
                          ja: '該当する連絡先が見つかりません',
                          ko: '관련 연락처를 찾을 수 없습니다',
                        ),
                  style: TextStyle(
                    color: theme.weakTextColor ?? Colors.grey,
                    fontSize: 14,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class ForwardSelectGroupPage extends StatefulWidget {
  final void Function(V2TimGroupInfo groupInfo, V2TimConversation conversation)?
      onTapItem;
  final String? title;
  final bool Function(V2TimGroupInfo? groupInfo)? groupCollector;

  const ForwardSelectGroupPage({
    super.key,
    this.onTapItem,
    this.title,
    this.groupCollector,
  });

  @override
  State<ForwardSelectGroupPage> createState() => _ForwardSelectGroupPageState();
}

class _ForwardSelectGroupPageState extends State<ForwardSelectGroupPage> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Widget _buildSearchBar(BuildContext context) {
    final builder = serviceLocator<TUIChatGlobalModel>().appSearchBarBuilder;
    if (builder != null) {
      return builder(
        context,
        _searchController,
        (_) => setState(() {}),
      );
    }
    return ContactStyleSearchBar(
      controller: _searchController,
      onChanged: (_) => setState(() {}),
      showCancel: false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Provider.of<DefaultThemeData>(context).theme;
    final i18n = AppI18n.of(context);
    final title = widget.title ??
        i18n.t(
          zhHans: '选择群聊',
          zhHant: '選擇群聊',
          en: 'Select Group',
          ja: 'グループを選択',
          ko: '그룹 선택',
        );

    return Scaffold(
      backgroundColor: theme.weakBackgroundColor ?? Colors.white,
      appBar: AppBar(
        centerTitle: true,
        elevation: 0,
        shadowColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        backgroundColor: theme.appbarBgColor ?? theme.weakBackgroundColor,
        title: Text(
          title,
          style: TextStyle(
            color: theme.appbarTextColor ?? theme.darkTextColor,
            fontSize: 17,
            fontWeight: FontWeight.w600,
          ),
        ),
        iconTheme: IconThemeData(
          color: theme.primaryColor ?? const Color(0xFF1E90FF),
        ),
      ),
      body: Column(
        children: [
          _buildSearchBar(context),
          Expanded(
            child: TIMUIKitGroup(
              searchKeyword: _searchController.text,
              isShowIndexBar: true,
              groupCollector: widget.groupCollector,
              onTapItem: widget.onTapItem ??
                  (groupInfo, conversation) {
                    Navigator.pop(context, conversation);
                  },
              emptyBuilder: (context) => Center(
                child: Text(
                  _searchController.text.trim().isEmpty
                      ? i18n.t(
                          zhHans: '暂无群聊',
                          zhHant: '暫無群聊',
                          en: 'No groups',
                          ja: 'グループがありません',
                          ko: '그룹 없음',
                        )
                      : i18n.t(
                          zhHans: '未找到相关群聊',
                          zhHant: '未找到相關群聊',
                          en: 'No matching groups',
                          ja: '該当するグループが見つかりません',
                          ko: '관련 그룹을 찾을 수 없습니다',
                        ),
                  style: TextStyle(
                    color: theme.weakTextColor ?? Colors.grey,
                    fontSize: 14,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
