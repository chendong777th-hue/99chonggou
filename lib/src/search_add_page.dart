import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tencent_cloud_chat_demo/src/i18n/app_i18n.dart';
import 'package:tencent_cloud_chat_demo/src/api/user_api.dart';
import 'package:tencent_cloud_chat_demo/utils/profile_page_nav.dart';
import 'package:tencent_cloud_chat_demo/src/env.dart';
import 'package:tencent_cloud_chat_demo/src/provider/theme.dart';
import 'package:tencent_cloud_chat_demo/src/pages/cross_platform/wide_screen/desktop_profile_host.dart';
import 'package:tencent_cloud_chat_demo/src/utils/qr_scanner_launcher.dart';
import 'package:tencent_cloud_chat_demo/src/ui/app_tokens.dart';
import 'package:tencent_cloud_chat_demo/src/pages/add_friend_page.dart';
import 'package:tencent_cloud_chat_demo/src/pages/contact_friends_page.dart';
import 'package:tencent_cloud_chat_demo/src/pages/join_group_application_page.dart';
import 'package:tencent_cloud_chat_demo/src/platform/permission_guard.dart';
import 'package:tencent_cloud_chat_demo/src/user_profile.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_conversation.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_conversation.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_group_info.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_group_info.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_user_full_info.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_user_full_info.dart';
import 'package:tencent_cloud_chat_uikit/business_logic/view_models/tui_self_info_view_model.dart';
import 'package:tencent_cloud_chat_uikit/data_services/services_locatar.dart';
import 'package:tencent_cloud_chat_demo/utils/chat_id_format.dart';
import 'package:tencent_cloud_chat_demo/src/models/group_join_source.dart';
import 'package:tencent_cloud_chat_demo/utils/group_join_lookup.dart';
import 'package:tencent_cloud_chat_demo/utils/friend_add_source.dart';
import 'package:tencent_cloud_chat_demo/utils/navigation_routes.dart';
import 'package:tencent_cloud_chat_uikit/tencent_cloud_chat_uikit.dart';
import 'package:tencent_cloud_chat_demo/utils/user_api_error_message.dart';
import 'package:tencent_cloud_chat_demo/src/navigation/app_page_transitions.dart';
import 'package:tencent_cloud_chat_demo/src/widgets/app_empty_state.dart';
import 'package:tencent_cloud_chat_demo/src/ui/utils/desktop_modal_layout.dart';

class SearchAddPage extends StatelessWidget {
  final ValueChanged<V2TimConversation>? directToChat;

  const SearchAddPage({Key? key, this.directToChat}) : super(key: key);

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
    final dividerColor = isDark
        ? (theme.weakDividerColor ?? const Color(0xFF2A2A2A))
        : const Color(0xFFE7EBF0);
    final rows = [
      _SearchAddRowData(
        title: i18n.t(
          zhHans: '搜索添加',
          zhHant: '搜尋添加',
          en: 'Search & Add',
          ja: '検索して追加',
          ko: '검색 및 추가',
        ),
        icon: Icons.person_search_rounded,
        iconBackgroundColor: const Color(0xFF2F8CFF),
        onTap: () {
          Navigator.push(
            context,
            AppMaterialPageRoute(
              builder: (context) => UnifiedSearchAddPage(
                directToChat: directToChat,
              ),
            ),
          );
        },
      ),
      if (!kIsWeb)
        _SearchAddRowData(
          title: i18n.t(
            zhHans: '扫描二维码',
            zhHant: '掃描 QR 碼',
            en: 'Scan QR Code',
            ja: 'QRコードをスキャン',
            ko: 'QR 코드 스캔',
          ),
          icon: Icons.qr_code_scanner_rounded,
          iconBackgroundColor: const Color(0xFF8E9BC3),
          onTap: () {
            QRScannerLauncher.open(context);
          },
        ),
      if (!kIsWeb)
        _SearchAddRowData(
          title: i18n.t(
            zhHans: '通讯录好友',
            zhHant: '通訊錄好友',
            en: 'Phone Contacts',
            ja: '連絡先の友達',
            ko: '연락처 친구',
          ),
          icon: Icons.contacts_rounded,
          iconBackgroundColor: const Color(0xFF34C759),
          onTap: () async {
            final allowed = await PermissionGuard.contactsForRead(context);
            if (!allowed || !context.mounted) {
              return;
            }
            Navigator.push(
              context,
              AppMaterialPageRoute(
                builder: (context) => ContactFriendsPage(
                  directToChat: directToChat,
                ),
              ),
            );
          },
        ),
    ];

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
            zhHans: '搜索添加',
            zhHant: '搜尋添加',
            en: 'Search & Add',
            ja: '検索して追加',
            ko: '검색 및 추가',
          ),
          style: TextStyle(
            color: theme.appbarTextColor ?? theme.darkTextColor ?? Colors.black,
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
        centerTitle: true,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(
            height: 1,
            color: dividerColor,
          ),
        ),
      ),
      body: ListView.separated(
        padding: const EdgeInsets.only(top: 10),
        itemCount: rows.length,
        separatorBuilder: (context, index) => Divider(
          height: 1,
          indent: 68,
          color: dividerColor,
        ),
        itemBuilder: (context, index) {
          final row = rows[index];
          return _SearchAddRowWidget(
            row: row,
            backgroundColor: surfaceColor,
          );
        },
      ),
    );
  }
}

class UnifiedSearchAddPage extends StatefulWidget {
  final ValueChanged<V2TimConversation>? directToChat;

  /// 嵌在宽屏弹窗内：去掉内层 AppBar，输入区用桌面样式，避免双标题。
  final bool embeddedInPopup;

  /// 宽屏弹窗关闭回调：打开已是好友的侧栏资料前先关弹窗。
  final VoidCallback? closeFunc;

  const UnifiedSearchAddPage({
    Key? key,
    this.directToChat,
    this.embeddedInPopup = false,
    this.closeFunc,
  }) : super(key: key);

  @override
  State<UnifiedSearchAddPage> createState() => _UnifiedSearchAddPageState();
}

class _UnifiedSearchAddPageState extends State<UnifiedSearchAddPage> {
  final TextEditingController _searchController = TextEditingController();
  final TUISelfInfoViewModel _selfInfoViewModel =
      serviceLocator<TUISelfInfoViewModel>();

  bool _isSearching = false;
  String _lastSearchKeyword = '';
  String? _lastUserAddSource;
  String? _inlineNotice;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  String _normalizeSearchKeyword(String input) =>
      ChatIdFormat.normalizeSearchKeyword(input);

  String _normalizeUserSearchKeyword(String input) {
    final trimmed = input.trim();
    if (trimmed.startsWith('@') && trimmed.length > 1) {
      return trimmed.substring(1).trim();
    }
    return trimmed;
  }

  void _setInlineNotice(String? value) {
    if (!mounted) {
      return;
    }
    setState(() {
      _inlineNotice = value?.trim().isEmpty == true ? null : value?.trim();
    });
  }

  void _showInvalidKeywordToast(AppI18n i18n) {
    _setInlineNotice(i18n.t(
      zhHans: '请输入有效手机号、UID 或群聊 ID',
      zhHant: '請輸入有效手機號、UID 或群聊 ID',
      en: 'Enter a valid phone number, UID, or group chat ID',
      ja: '有効な電話番号、UID、またはグループチャットIDを入力してください',
      ko: '유효한 전화번호, UID 또는 그룹 채팅 ID를 입력하세요',
    ));
  }

  void _dismissKeyboard() {
    FocusManager.instance.primaryFocus?.unfocus();
  }

  Future<void> _performSearch() async {
    _dismissKeyboard();
    final i18n = AppI18n.of(context);
    final rawKeyword = _searchController.text.trim();
    final isGroupSearch = ChatIdFormat.isIMGroupOrCommunityId(rawKeyword);
    final userKeyword = _normalizeUserSearchKeyword(rawKeyword);
    final isUserSearch = !isGroupSearch && _isUserSearchKeyword(userKeyword);
    // 群搜统一展开为完整 IM 群 ID，避免短别名与暖窗 / SDK key 分桶。
    final keyword = isGroupSearch
        ? _normalizeSearchKeyword(rawKeyword)
        : (isUserSearch ? userKeyword : _normalizeSearchKeyword(rawKeyword));
    if (_isSearching) {
      return;
    }
    if (keyword.isEmpty || (!isGroupSearch && !isUserSearch)) {
      if (rawKeyword.isNotEmpty) {
        _showInvalidKeywordToast(i18n);
      }
      return;
    }
    setState(() {
      _isSearching = true;
      _lastSearchKeyword = keyword;
      _lastUserAddSource = null;
      _inlineNotice = null;
    });

    try {
      final results = <_UnifiedSearchResult>[];

      if (isGroupSearch) {
        await _appendGroupSearchResults(keyword, results);
      } else if (isUserSearch) {
        try {
          final hit = await UserApi.instance.searchUser(
            keyword: keyword,
            phoneCountry:
                _needsPhoneCountry(keyword) ? AppEnv.defaultPhoneCountry : null,
          );
          final userInfo = V2TimUserFullInfo(
            userID: hit.userId,
            nickName: hit.nickname,
            faceUrl: hit.avatarUrl,
          );
          _lastUserAddSource =
              FriendAddSource.resolveSearchKeywordSource(keyword);
          results.add(
            _UnifiedSearchResult.user(
              userInfo,
              avatarUrl: hit.avatarUrl,
              phoneMasked: hit.phoneMasked,
              addSource: _lastUserAddSource,
              lastActiveAt: hit.lastActiveAt,
              lastActiveVisibility: hit.lastActiveVisibility,
            ),
          );
        } on DioError catch (e) {
          _setInlineNotice(UserApiErrorMessage.fromSearch(e));
          return;
        } catch (_) {
          _setInlineNotice(i18n.t(
            zhHans: '搜索失败',
            zhHant: '搜尋失敗',
            en: 'Search failed',
            ja: '検索に失敗',
            ko: '검색 실패',
          ));
          return;
        }
      }

      if (!mounted) return;
      await _handleSearchResults(results);
    } finally {
      if (mounted) {
        setState(() => _isSearching = false);
      }
    }
  }

  Future<void> _handleSearchResults(List<_UnifiedSearchResult> results) async {
    final i18n = AppI18n.of(context);
    if (results.isEmpty) {
      _setInlineNotice(
        ChatIdFormat.isIMGroupOrCommunityId(_lastSearchKeyword)
            ? i18n.t(
                zhHans: '未找到该群聊',
                zhHant: '未找到該群聊',
                en: 'Group chat not found',
                ja: 'グループチャットが見つかりません',
                ko: '그룹 채팅을 찾을 수 없습니다',
              )
            : i18n.t(
                zhHans: '未找到相关用户或群聊',
                zhHant: '未找到相關使用者或群聊',
                en: 'No matching users or groups',
                ja: '該当するユーザーまたはグループが見つかりません',
                ko: '관련 사용자 또는 그룹을 찾을 수 없습니다',
              ),
      );
      return;
    }
    if (results.length == 1) {
      final result = results.first;
      if (result.kind == _UnifiedSearchResultKind.user) {
        await _openAddFriendFromResult(result);
      } else if (result.groupInfo != null) {
        await _openGroupResult(result.groupInfo!);
      }
      return;
    }

    final userResults =
        results.where((r) => r.kind == _UnifiedSearchResultKind.user).toList();
    final groupResults =
        results.where((r) => r.kind == _UnifiedSearchResultKind.group).toList();

    if (userResults.length == 1 && groupResults.isEmpty) {
      await _openAddFriendFromResult(userResults.first);
      return;
    }
    if (groupResults.length == 1 && userResults.isEmpty) {
      final groupInfo = groupResults.first.groupInfo;
      if (groupInfo != null) {
        await _openGroupResult(groupInfo);
      }
      return;
    }
    if (userResults.length == 1) {
      await _openAddFriendFromResult(userResults.first);
      return;
    }

    _setInlineNotice(i18n.t(
      zhHans: '未找到相关用户或群聊',
      zhHant: '未找到相關使用者或群聊',
      en: 'No matching users or groups',
      ja: '該当するユーザーまたはグループが見つかりません',
      ko: '관련 사용자 또는 그룹을 찾을 수 없습니다',
    ));
  }

  Future<void> _appendGroupSearchResults(
    String keyword,
    List<_UnifiedSearchResult> results,
  ) async {
    final existingGroupIds = results
        .where((r) => r.kind == _UnifiedSearchResultKind.group)
        .map((r) => r.groupInfo?.groupID ?? '')
        .where((id) => id.isNotEmpty)
        .toSet();

    V2TimGroupInfo? groupInfo;
    try {
      groupInfo = await GroupJoinLookup.resolve(
        groupKey: keyword,
        joinSource: GroupJoinSource.search,
      );
    } on GroupJoinLookupDisabledException catch (error) {
      if (mounted) {
        _setInlineNotice(GroupJoinLookup.disabledMessage(
          AppI18n.of(context),
          error,
        ));
      }
      return;
    }
    if (groupInfo == null) {
      return;
    }
    final resolvedId =
        ChatIdFormat.canonicalGroupStorageId(groupInfo.groupID);
    if (resolvedId.isEmpty || existingGroupIds.contains(resolvedId)) {
      return;
    }
    if (resolvedId != groupInfo.groupID) {
      groupInfo.groupID = resolvedId;
    }
    results.add(_UnifiedSearchResult.group(groupInfo));
  }

  bool _isUserSearchKeyword(String keyword) {
    if (keyword.toUpperCase().contains('TGS#')) {
      return false;
    }
    if (keyword.isEmpty) {
      return false;
    }
    if (keyword.startsWith('+')) {
      return true;
    }
    if (RegExp(r'^[0-9]+$').hasMatch(keyword)) {
      return true;
    }
    if (RegExp(r'^[A-Za-z][A-Za-z0-9_]{1,31}$').hasMatch(keyword)) {
      return true;
    }
    return false;
  }

  bool _needsPhoneCountry(String keyword) {
    return !keyword.startsWith('+') && RegExp(r'^[0-9]+$').hasMatch(keyword);
  }

  Future<void> _openAddFriendFromResult(_UnifiedSearchResult result) async {
    final userInfo = result.userInfo;
    if (userInfo == null) {
      return;
    }
    final userID = userInfo.userID ?? "";
    if (userID.isEmpty) {
      return;
    }
    final isSelf = userID == _selfInfoViewModel.loginInfo?.userID;
    var isFriend = false;
    if (!isSelf) {
      isFriend = await ProfilePageNav.isFriendUser(userID);
    }

    if (!mounted) {
      return;
    }

    if (isSelf || isFriend) {
      // 桌面：先开主壳侧栏资料，再关搜索弹窗，避免嵌在弹窗内或盖住列表无法返回。
      if (widget.embeddedInPopup || DesktopModalLayout.isDesktop(context)) {
        DesktopProfileHost.open(userID);
        widget.closeFunc?.call();
        return;
      }
      await Navigator.of(context).push(
        NavigationRoutes.cupertino(
          builder: (context) => UserProfile(userID: userID),
        ),
      );
      return;
    }

    final addSource = result.addSource ??
        _lastUserAddSource ??
        FriendAddSource.resolveSearchKeywordSource(
          _lastSearchKeyword.isNotEmpty ? _lastSearchKeyword : userID,
        );
    V2TimUserFullInfo? sdkUserInfo;
    final sdkRes =
        await TIMUIKitCore.getSDKInstance().getUsersInfo(userIDList: [userID]);
    if (sdkRes.code == 0 && sdkRes.data != null && sdkRes.data!.isNotEmpty) {
      sdkUserInfo = sdkRes.data!.first;
    }

    final showName = TencentUtils.checkString(sdkUserInfo?.nickName) ??
        ((userInfo.nickName?.isNotEmpty ?? false)
            ? userInfo.nickName!
            : userID);

    if (!mounted) {
      return;
    }

    await AddFriendPage.open(
      context,
      userID: userID,
      nickname: showName,
      initialUserInfo: sdkUserInfo ?? userInfo,
      addSource: addSource,
      lastActiveAt: result.lastActiveAt,
      lastActiveVisibility: result.lastActiveVisibility,
    );
  }

  Future<void> _openGroupResult(V2TimGroupInfo groupInfo) async {
    final groupID = groupInfo.groupID;
    if (groupID.isEmpty) {
      return;
    }

    if (!mounted) {
      return;
    }

    final isDesktop = widget.embeddedInPopup ||
        DesktopModalLayout.isDesktop(context);
    if (isDesktop) {
      // 弹窗内：局部 push，避免再开弹窗被 isShow 互斥挡住或全屏。
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => JoinGroupApplicationPage(
            groupInfo: groupInfo,
            directToChat: widget.directToChat,
            joinSource: GroupJoinSource.search,
          ),
        ),
      );
      return;
    }

    Navigator.push(
      context,
      NavigationRoutes.cupertino(
        builder: (context) => JoinGroupApplicationPage(
          groupInfo: groupInfo,
          directToChat: widget.directToChat,
          joinSource: GroupJoinSource.search,
        ),
      ),
    );
  }

  void _clearSearch() {
    _searchController.clear();
    setState(() {
      _inlineNotice = null;
    });
  }

  Widget _buildSearchField(dynamic theme, AppI18n i18n, {required bool desktop}) {
    final fillColor =
        theme.inputFillColor ?? theme.selectPanelBgColor ?? AppTokens.ink25;
    final hintColor = theme.weakTextColor ?? AppTokens.ink300;
    final textColor = theme.darkTextColor ?? AppTokens.ink800;
    final borderColor = theme.weakDividerColor ?? const Color(0xFFE5E6EB);
    final showClear = _searchController.text.isNotEmpty;
    final fieldHeight = desktop ? 36.0 : 46.0;
    final fieldRadius = desktop ? 8.0 : 10.0;
    final fontSize = desktop ? 13.5 : 15.0;
    return Container(
      height: fieldHeight,
      decoration: BoxDecoration(
        color: fillColor,
        borderRadius: BorderRadius.circular(fieldRadius),
        border: desktop
            ? Border.all(color: borderColor.withValues(alpha: 0.9), width: 1)
            : null,
      ),
      child: TextField(
        controller: _searchController,
        autofocus: widget.embeddedInPopup,
        onChanged: (_) {
          setState(() {
            _inlineNotice = null;
          });
        },
        onSubmitted: (_) => _performSearch(),
        textInputAction: TextInputAction.search,
        style: AppTokens.body.copyWith(
          fontSize: fontSize,
          color: textColor,
          height: 1.2,
        ),
        cursorColor: theme.primaryColor ?? AppTokens.brand500,
        decoration: InputDecoration(
          hintText: i18n.t(
            zhHans: '搜索手机号/UID/群聊ID',
            zhHant: '搜尋手機號/UID/群聊ID',
            en: 'Search phone/UID/group chat ID',
            ja: '電話番号/UID/グループチャットIDを検索',
            ko: '전화번호/UID/그룹 채팅 ID 검색',
          ),
          hintStyle: AppTokens.body.copyWith(
            color: hintColor,
            fontSize: fontSize,
            height: 1.2,
          ),
          prefixIcon: Icon(
            Icons.search,
            color: hintColor,
            size: desktop ? 18 : 20,
          ),
          prefixIconConstraints: BoxConstraints(
            minWidth: desktop ? 36 : 38,
            minHeight: fieldHeight,
          ),
          suffixIcon: showClear
              ? IconButton(
                  onPressed: _clearSearch,
                  padding: EdgeInsets.zero,
                  constraints: BoxConstraints(
                    minWidth: desktop ? 36 : 38,
                    minHeight: fieldHeight,
                  ),
                  icon: Icon(
                    Icons.cancel,
                    color: hintColor,
                    size: desktop ? 18 : 20,
                  ),
                )
              : null,
          suffixIconConstraints: BoxConstraints(
            minWidth: desktop ? 36 : 38,
            minHeight: fieldHeight,
          ),
          border: InputBorder.none,
          filled: false,
          isDense: true,
          contentPadding: EdgeInsets.symmetric(vertical: desktop ? 8 : 12),
        ),
      ),
    );
  }

  Widget _buildSearchButton(dynamic theme, AppI18n i18n, {required bool desktop}) {
    final enabled = _searchController.text.trim().isNotEmpty && !_isSearching;
    return SizedBox(
      width: desktop ? 88 : double.infinity,
      height: desktop ? 36 : 46,
      child: ElevatedButton(
        onPressed: enabled ? _performSearch : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: enabled
              ? (theme.primaryColor ?? AppTokens.brand500)
              : (theme.weakDividerColor ?? AppTokens.ink100),
          foregroundColor: Colors.white,
          elevation: 0,
          padding: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(desktop ? 8 : 10),
          ),
        ),
        child: _isSearching
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
            : Text(
                i18n.t(
                  zhHans: '搜索',
                  zhHant: '搜尋',
                  en: 'Search',
                  ja: '検索',
                  ko: '검색',
                ),
                style: AppTokens.bodyStrong.copyWith(
                  fontSize: desktop ? 14 : 16,
                  color: Colors.white,
                ),
              ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final i18n = AppI18n.of(context);
    final theme = Provider.of<DefaultThemeData>(context).theme;
    final isDesktop = widget.embeddedInPopup ||
        DesktopModalLayout.isDesktop(context);
    final pageBaseColor =
        theme.appbarBgColor ?? theme.wideBackgroundColor ?? Colors.white;
    final isDark =
        ThemeData.estimateBrightnessForColor(pageBaseColor) == Brightness.dark;
    final pageBackgroundColor =
        isDark ? (theme.weakBackgroundColor ?? pageBaseColor) : Colors.white;
    final surfaceColor = isDark ? pageBaseColor : Colors.white;
    final dividerColor = isDark
        ? (theme.weakDividerColor ?? const Color(0xFF2A2A2A))
        : const Color(0xFFE7EBF0);

    final searchPanel = Container(
      color: surfaceColor,
      padding: EdgeInsets.fromLTRB(
        isDesktop ? 20 : 16,
        isDesktop ? 16 : 12,
        isDesktop ? 20 : 16,
        isDesktop ? 16 : 12,
      ),
      child: ValueListenableBuilder<TextEditingValue>(
        valueListenable: _searchController,
        builder: (context, value, child) {
          if (isDesktop) {
            return Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: _buildSearchField(theme, i18n, desktop: true),
                ),
                const SizedBox(width: 10),
                _buildSearchButton(theme, i18n, desktop: true),
              ],
            );
          }
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildSearchField(theme, i18n, desktop: false),
              const SizedBox(height: 12),
              _buildSearchButton(theme, i18n, desktop: false),
            ],
          );
        },
      ),
    );

    final body = ColoredBox(
      color: pageBackgroundColor,
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          searchPanel,
          _SearchAddGuideSection(
            notice: _inlineNotice,
            subtitleColor: theme.weakTextColor ?? const Color(0xFF999999),
            compact: isDesktop,
          ),
        ],
      ),
    );

    if (widget.embeddedInPopup) {
      // 外层弹窗已提供白底与圆角裁切，避免本层 Material 直角盖住底部圆角。
      return Material(
        color: Colors.transparent,
        child: body,
      );
    }

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
            zhHans: '搜索添加',
            zhHant: '搜尋添加',
            en: 'Search & Add',
            ja: '検索して追加',
            ko: '검색 및 추가',
          ),
          style: TextStyle(
            color: theme.appbarTextColor ?? theme.darkTextColor ?? Colors.black,
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
        centerTitle: true,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(
            height: 1,
            color: dividerColor,
          ),
        ),
      ),
      body: body,
    );
  }
}

class _SearchAddGuideSection extends StatelessWidget {
  const _SearchAddGuideSection({
    this.notice,
    required this.subtitleColor,
    this.compact = false,
  });

  final String? notice;
  final Color subtitleColor;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final i18n = AppI18n.of(context);
    final topGap = MediaQuery.of(context).size.height * (compact ? 0.06 : 0.12);

    return Padding(
      padding: EdgeInsets.fromLTRB(32, topGap, 32, 40),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Image.asset(
            AppEmptyState.assetPath,
            width: compact ? 140 : 180,
            fit: BoxFit.contain,
            errorBuilder: (_, __, ___) => Icon(
              Icons.person_search_rounded,
              size: 72,
              color: subtitleColor.withValues(alpha: 0.45),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            notice ??
                i18n.t(
                  zhHans: '输入手机号或账号、群聊ID搜索用户或群聊',
                  zhHant: '輸入手機號或帳號、群聊ID搜尋使用者或群聊',
                  en: 'Enter a phone number, account, or group chat ID to search',
                  ja: '電話番号・アカウント・グループチャットIDを入力して検索',
                  ko: '휴대전화 번호, 계정, 그룹 채팅 ID를 입력해 검색하세요',
                ),
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: subtitleColor,
              height: 1.45,
            ),
          ),
          if (notice == null) ...[
            const SizedBox(height: 8),
            Text(
              i18n.t(
                zhHans: '可通过手机号或账号、群聊ID添加用户或群聊',
                zhHant: '可透過手機號或帳號、群聊ID添加使用者或群聊',
                en: 'You can add users or group chats by phone number, account, or group chat ID',
                ja: '電話番号・アカウント・グループチャットIDから追加できます',
                ko: '휴대전화 번호, 계정, 그룹 채팅 ID로 사용자 또는 그룹을 추가할 수 있습니다',
              ),
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w400,
                color: subtitleColor,
                height: 1.45,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _SearchAddRowData {
  final String title;
  final IconData icon;
  final Color iconBackgroundColor;
  final VoidCallback onTap;

  const _SearchAddRowData({
    required this.title,
    required this.icon,
    required this.iconBackgroundColor,
    required this.onTap,
  });
}

enum _UnifiedSearchResultKind { user, group }

class _UnifiedSearchResult {
  final _UnifiedSearchResultKind kind;
  final V2TimUserFullInfo? userInfo;
  final V2TimGroupInfo? groupInfo;
  final String? phoneMasked;
  final String? addSource;
  final int? lastActiveAt;
  final String? lastActiveVisibility;
  final String? avatarUrl;

  const _UnifiedSearchResult.user(
    this.userInfo, {
    this.avatarUrl,
    this.phoneMasked,
    this.addSource,
    this.lastActiveAt,
    this.lastActiveVisibility,
  })  : kind = _UnifiedSearchResultKind.user,
        groupInfo = null;

  const _UnifiedSearchResult.group(this.groupInfo)
      : kind = _UnifiedSearchResultKind.group,
        userInfo = null,
        phoneMasked = null,
        addSource = null,
        lastActiveAt = null,
        lastActiveVisibility = null,
        avatarUrl = null;
}

class _SearchAddRowWidget extends StatelessWidget {
  final _SearchAddRowData row;
  final Color backgroundColor;

  const _SearchAddRowWidget({
    required this.row,
    required this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Provider.of<DefaultThemeData>(context).theme;
    return InkWell(
      onTap: row.onTap,
      child: Container(
        color: backgroundColor,
        padding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 12,
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: row.iconBackgroundColor,
                shape: BoxShape.circle,
              ),
              child: Icon(
                row.icon,
                color: Colors.white,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                row.title,
                style: TextStyle(
                  fontSize: 16,
                  color: theme.darkTextColor ?? const Color(0xFF111111),
                ),
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              color: theme.weakTextColor ?? const Color(0xFFB8B8B8),
              size: 20,
            ),
          ],
        ),
      ),
    );
  }
}
