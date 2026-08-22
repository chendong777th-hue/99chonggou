import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tencent_cloud_chat_demo/src/i18n/app_i18n.dart';
import 'package:tencent_cloud_chat_demo/src/navigation/app_chat_route.dart';
import 'package:tencent_cloud_chat_demo/src/pages/add_friend_page.dart';
import 'package:tencent_cloud_chat_demo/src/provider/theme.dart';
import 'package:tencent_cloud_chat_demo/src/services/contact_friends_lookup_service.dart';
import 'package:tencent_cloud_chat_demo/src/services/contact_invite_launcher.dart';
import 'package:tencent_cloud_chat_demo/src/widgets/app_empty_state.dart';
import 'package:tencent_cloud_chat_demo/src/widgets/contact_style_search_bar.dart';
import 'package:tencent_cloud_chat_demo/utils/chat_id_format.dart';
import 'package:tencent_cloud_chat_demo/utils/friend_add_source.dart';
import 'package:tencent_cloud_chat_demo/utils/toast.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_conversation.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_conversation.dart';
import 'package:tencent_cloud_chat_uikit/tencent_cloud_chat_uikit.dart';

class ContactFriendsPage extends StatefulWidget {
  const ContactFriendsPage({super.key, this.directToChat});

  final ValueChanged<V2TimConversation>? directToChat;

  @override
  State<ContactFriendsPage> createState() => _ContactFriendsPageState();
}

class _ContactFriendsPageState extends State<ContactFriendsPage> {
  final TextEditingController _searchController = TextEditingController();
  final _sdk = TIMUIKitCore.getSDKInstance();

  bool _loading = true;
  String? _errorMessage;
  List<ContactFriendEntry> _entries = const [];

  @override
  void initState() {
    super.initState();
    _loadEntries();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadEntries() async {
    setState(() {
      _loading = true;
      _errorMessage = null;
    });
    try {
      final entries = await ContactFriendsLookupService.loadEntries();
      if (!mounted) return;
      setState(() {
        _entries = entries;
        _loading = false;
      });
    } on ContactFriendsLookupException catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _errorMessage = e.message;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _errorMessage = AppI18n.of(context).t(
          zhHans: '加载通讯录失败，请稍后重试',
          zhHant: '載入通訊錄失敗，請稍後重試',
          en: 'Failed to load contacts. Please try again.',
          ja: '連絡先の読み込みに失敗しました。しばらくしてからお試しください。',
          ko: '연락처를 불러오지 못했습니다. 잠시 후 다시 시도해 주세요.',
        );
      });
    }
  }

  List<ContactFriendEntry> get _filteredEntries {
    final keyword = _searchController.text.trim().toLowerCase();
    if (keyword.isEmpty) {
      return _entries;
    }
    final filtered = _entries.where((entry) {
      final name = entry.displayName.toLowerCase();
      final phone = entry.primaryPhone.toLowerCase();
      return name.contains(keyword) || phone.contains(keyword);
    }).toList();
    filtered.sort(ContactFriendsLookupService.compareEntries);
    return filtered;
  }

  Future<void> _openChat(ContactFriendEntry entry) async {
    final userId = ChatIdFormat.rawUserUid(entry.user?.userId ?? '');
    if (userId.isEmpty) {
      return;
    }
    final conversationID = 'c2c_$userId';
    final res = await _sdk
        .getConversationManager()
        .getConversation(conversationID: conversationID);
    if (!mounted) {
      return;
    }
    final conversation = res.data ??
        V2TimConversation(
          conversationID: conversationID,
          userID: userId,
          type: 1,
        );
    if (widget.directToChat != null) {
      widget.directToChat!(conversation);
      return;
    }
    await Navigator.push(context, appChatRoute(conversation));
  }

  Future<void> _openAddFriend(ContactFriendEntry entry) async {
    final user = entry.user;
    final userId = ChatIdFormat.rawUserUid(user?.userId ?? '');
    if (userId.isEmpty) {
      return;
    }
    await AddFriendPage.open(
      context,
      userID: userId,
      nickname: user?.nickname.trim().isNotEmpty == true
          ? user!.nickname
          : entry.displayName,
      addSource: FriendAddSource.phone,
      lastActiveAt: user?.lastActiveAt,
      lastActiveVisibility: user?.lastActiveVisibility,
    );
    if (!mounted) {
      return;
    }
    await _loadEntries();
  }

  Future<void> _inviteBySms(ContactFriendEntry entry) async {
    final ok = await ContactInviteLauncher.openSmsInvite(
      phone: entry.primaryPhone,
    );
    if (!ok && mounted) {
      ToastUtils.toast(AppI18n.of(context).t(
        zhHans: '无法打开短信应用',
        zhHant: '無法開啟簡訊應用',
        en: 'Unable to open the SMS app',
        ja: 'SMSアプリを開けません',
        ko: '문자 앱을 열 수 없습니다',
      ));
    }
  }

  void _onActionTap(ContactFriendEntry entry) {
    switch (entry.status) {
      case ContactFriendStatus.registeredFriend:
        _openChat(entry);
        break;
      case ContactFriendStatus.registeredNotFriend:
        _openAddFriend(entry);
        break;
      case ContactFriendStatus.unregistered:
        _inviteBySms(entry);
        break;
    }
  }

  String _actionLabel(AppI18n i18n, ContactFriendStatus status) {
    switch (status) {
      case ContactFriendStatus.registeredFriend:
        return i18n.t(
          zhHans: '发消息',
          zhHant: '發訊息',
          en: 'Message',
          ja: 'メッセージ',
          ko: '메시지',
        );
      case ContactFriendStatus.registeredNotFriend:
        return i18n.t(
          zhHans: '添加好友',
          zhHant: '添加好友',
          en: 'Add Friend',
          ja: '友達追加',
          ko: '친구 추가',
        );
      case ContactFriendStatus.unregistered:
        return i18n.t(
          zhHans: '邀请好友',
          zhHant: '邀請好友',
          en: 'Invite',
          ja: '招待',
          ko: '초대',
        );
    }
  }

  Color _actionColor(dynamic theme, ContactFriendStatus status) {
    final primary = theme.primaryColor ?? const Color(0xFF1E90FF);
    switch (status) {
      case ContactFriendStatus.registeredFriend:
      case ContactFriendStatus.registeredNotFriend:
        return primary;
      case ContactFriendStatus.unregistered:
        return theme.weakTextColor ?? const Color(0xFF666666);
    }
  }

  Widget _buildBody(AppI18n i18n, dynamic theme) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: theme.weakTextColor ?? Colors.grey,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 16),
              TextButton(
                onPressed: _loadEntries,
                child: Text(i18n.t(
                  zhHans: '重试',
                  zhHant: '重試',
                  en: 'Retry',
                  ja: '再試行',
                  ko: '다시 시도',
                )),
              ),
            ],
          ),
        ),
      );
    }

    final items = _filteredEntries;
    if (items.isEmpty) {
      return AppEmptyState(
        message: _searchController.text.trim().isEmpty
            ? i18n.t(
                zhHans: '通讯录中没有联系人',
                zhHant: '通訊錄中沒有聯絡人',
                en: 'No contacts found',
                ja: '連絡先がありません',
                ko: '연락처가 없습니다',
              )
            : i18n.t(
                zhHans: '未找到相关联系人',
                zhHant: '未找到相關聯絡人',
                en: 'No matching contacts',
                ja: '該当する連絡先が見つかりません',
                ko: '관련 연락처를 찾을 수 없습니다',
              ),
      );
    }

    final dividerColor = theme.weakDividerColor ?? const Color(0xFFE7EBF0);
    return ListView.separated(
      padding: const EdgeInsets.only(bottom: 12),
      itemCount: items.length,
      separatorBuilder: (_, __) => Divider(
        height: 1,
        indent: 68,
        color: dividerColor,
      ),
      itemBuilder: (context, index) {
        final entry = items[index];
        return _ContactFriendRow(
          entry: entry,
          actionLabel: _actionLabel(i18n, entry.status),
          actionColor: _actionColor(theme, entry.status),
          onActionTap: () => _onActionTap(entry),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final i18n = AppI18n.of(context);
    final theme = Provider.of<DefaultThemeData>(context).theme;
    final pageBaseColor =
        theme.appbarBgColor ?? theme.wideBackgroundColor ?? Colors.white;
    final isDark =
        ThemeData.estimateBrightnessForColor(pageBaseColor) == Brightness.dark;
    final pageBackgroundColor =
        isDark ? (theme.weakBackgroundColor ?? pageBaseColor) : Colors.white;
    final surfaceColor = isDark ? pageBaseColor : Colors.white;

    return Scaffold(
      backgroundColor: pageBackgroundColor,
      appBar: AppBar(
        backgroundColor: surfaceColor,
        surfaceTintColor: Colors.transparent,
        shadowColor: Colors.transparent,
        iconTheme: IconThemeData(
          color: theme.primaryColor ?? const Color(0xFF1E90FF),
        ),
        title: Text(
          i18n.t(
            zhHans: '通讯录好友',
            zhHant: '通訊錄好友',
            en: 'Phone Contacts',
            ja: '連絡先の友達',
            ko: '연락처 친구',
          ),
          style: TextStyle(
            color: theme.appbarTextColor ?? theme.darkTextColor ?? Colors.black,
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
        centerTitle: true,
      ),
      body: Column(
        children: [
          ContactStyleSearchBar(
            controller: _searchController,
            onChanged: (_) => setState(() {}),
            showCancel: false,
            hint: i18n.t(
              zhHans: '搜索联系人',
              zhHant: '搜尋聯絡人',
              en: 'Search contacts',
              ja: '連絡先を検索',
              ko: '연락처 검색',
            ),
          ),
          Expanded(child: _buildBody(i18n, theme)),
        ],
      ),
    );
  }
}

class _ContactFriendRow extends StatelessWidget {
  const _ContactFriendRow({
    required this.entry,
    required this.actionLabel,
    required this.actionColor,
    required this.onActionTap,
  });

  final ContactFriendEntry entry;
  final String actionLabel;
  final Color actionColor;
  final VoidCallback onActionTap;

  @override
  Widget build(BuildContext context) {
    final theme = Provider.of<DefaultThemeData>(context).theme;
    final titleColor = theme.darkTextColor ?? const Color(0xFF111111);
    final subtitleColor = theme.weakTextColor ?? const Color(0xFF999999);
    final displayName = entry.displayName.trim();
    final initial = displayName.isNotEmpty ? displayName[0] : '#';

    return Material(
      color: theme.appbarBgColor ?? Colors.white,
      child: InkWell(
        onTap: onActionTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor:
                    (theme.primaryColor ?? const Color(0xFF1E90FF))
                        .withValues(alpha: 0.12),
                child: Text(
                  initial,
                  style: TextStyle(
                    color: theme.primaryColor ?? const Color(0xFF1E90FF),
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      entry.displayName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 16,
                        color: titleColor,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      entry.primaryPhone,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13,
                        color: subtitleColor,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              TextButton(
                onPressed: onActionTap,
                style: TextButton.styleFrom(
                  foregroundColor: actionColor,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  minimumSize: const Size(0, 36),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: Text(
                  actionLabel,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
