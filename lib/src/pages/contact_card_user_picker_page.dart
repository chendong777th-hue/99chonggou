import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tencent_cloud_chat_demo/src/i18n/app_i18n.dart';
import 'package:tencent_cloud_chat_demo/src/provider/theme.dart';
import 'package:tencent_cloud_chat_demo/src/services/platform_official_account_service.dart';
import 'package:tencent_cloud_chat_demo/src/widgets/contact_style_search_bar.dart';
import 'package:tencent_cloud_chat_demo/src/widgets/contact_list_with_presence.dart';
import 'package:tencent_cloud_chat_demo/utils/toast.dart';
import 'package:tencent_cloud_chat_demo/utils/user_display_profile.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_friend_info.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_friend_info.dart';
import 'package:tencent_cloud_chat_demo/src/navigation/app_page_transitions.dart';
/// 弹出好友列表，返回所选用户的 userID。
Future<String?> pickContactCardUser(BuildContext context) {
  return Navigator.of(context).push<String>(
    AppMaterialPageRoute(
      builder: (context) => const ContactCardUserPickerPage(),
    ),
  );
}

class ContactCardUserPickerPage extends StatelessWidget {
  const ContactCardUserPickerPage({super.key});

  String _displayName(V2TimFriendInfo item) {
    return UserDisplayProfile.nameOfFriend(item);
  }

  @override
  Widget build(BuildContext context) {
    final i18n = AppI18n.of(context);
    final theme = Provider.of<DefaultThemeData>(context).theme;
    return _PickerScaffold(
      title: i18n.t(
        zhHans: '选择朋友',
        zhHant: '選擇朋友',
        en: 'Choose Friend',
        ja: '友だちを選択',
        ko: '친구 선택',
      ),
      theme: theme,
      itemLabelBuilder: _displayName,
      onTapItem: (V2TimFriendInfo item) {
        final userId = item.userID.trim();
        if (userId.isEmpty) {
          return;
        }
        if (PlatformOfficialAccountService.isPlatformOfficialAccount(userId)) {
          ToastUtils.toast(i18n.t(
            zhHans: '暂不支持分享该联系人名片',
            zhHant: '暫不支援分享該聯絡人名片',
            en: 'Sharing this contact card is not supported.',
            ja: 'この連絡先名刺の共有には対応していません。',
            ko: '이 연락처 명함 공유는 지원되지 않습니다.',
          ));
          return;
        }
        Navigator.pop(context, userId);
      },
    );
  }
}

class _PickerScaffold extends StatefulWidget {
  const _PickerScaffold({
    required this.title,
    required this.theme,
    required this.itemLabelBuilder,
    required this.onTapItem,
  });

  final String title;
  final dynamic theme;
  final String Function(V2TimFriendInfo item) itemLabelBuilder;
  final void Function(V2TimFriendInfo item) onTapItem;

  @override
  State<_PickerScaffold> createState() => _PickerScaffoldState();
}

class _PickerScaffoldState extends State<_PickerScaffold> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  bool _matches(V2TimFriendInfo item, String keyword) {
    if (keyword.isEmpty) return true;
    final k = keyword.toLowerCase();
    final displayName = widget.itemLabelBuilder(item).toLowerCase();
    final userId = item.userID.toLowerCase();
    return displayName.contains(k) || userId.contains(k);
  }

  @override
  Widget build(BuildContext context) {
    final i18n = AppI18n.of(context);
    final theme = widget.theme;
    return Scaffold(
      backgroundColor: theme.weakBackgroundColor ?? Colors.white,
      appBar: AppBar(
        centerTitle: true,
        elevation: 0,
        shadowColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        backgroundColor: theme.appbarBgColor ?? theme.weakBackgroundColor,
        title: Text(
          widget.title,
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
          ContactStyleSearchBar(
            controller: _searchController,
            onChanged: (_) => setState(() {}),
            hint: i18n.t(
              zhHans: '搜索',
              zhHant: '搜尋',
              en: 'Search',
              ja: '検索',
              ko: '검색',
            ),
          ),
          Expanded(
            child: ContactListWithPresence(
              isShowOnlineStatus: true,
              onTapItem: widget.onTapItem,
              filterItem: (item) => _matches(
                item,
                _searchController.text.trim(),
              ),
              emptyBuilder: (_) => Center(
                child: Text(
                  _searchController.text.trim().isEmpty
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
              topList: const [],
              topListItemBuilder: null,
            ),
          ),
        ],
      ),
    );
  }
}
