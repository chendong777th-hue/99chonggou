import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tencent_cloud_chat_demo/src/create_group.dart';
import 'package:tencent_cloud_chat_demo/src/i18n/app_i18n.dart';
import 'package:tencent_cloud_chat_demo/src/pages/cross_platform/wide_screen/desktop_create_group_host.dart';
import 'package:tencent_cloud_chat_demo/src/services/conversation_local/conversation_sync_service.dart';
import 'package:tencent_cloud_chat_demo/src/services/conversation_pin_service.dart';
import 'package:tencent_cloud_chat_demo/src/services/c2c_receive_opt_service.dart';
import 'package:tencent_cloud_chat_demo/src/services/im/contracts/account_scoped_conversation_key.dart';
import 'package:tencent_cloud_chat_demo/src/services/session_identity.dart';
import 'package:tencent_cloud_chat_demo/src/services/conversation_pin_sync_service.dart';
import 'package:tencent_cloud_chat_demo/src/api/conversation_pin_api.dart';
import 'package:tencent_cloud_chat_demo/src/models/user_profile_record.dart';
import 'package:tencent_cloud_chat_demo/src/navigation/app_chat_route.dart';
import 'package:tencent_cloud_chat_demo/src/navigation/app_page_transitions.dart';
import 'package:tencent_cloud_chat_demo/src/pages/chat_background_page.dart';
import 'package:tencent_cloud_chat_demo/src/pages/complaint/complaint_reason_page.dart';
import 'package:tencent_cloud_chat_demo/src/provider/theme.dart';
import 'package:tencent_cloud_chat_demo/src/search.dart';
import 'package:tencent_cloud_chat_demo/src/services/user_profile_local/user_profile_local_service.dart';
import 'package:tencent_cloud_chat_demo/src/services/peer_profile_refresh_bus.dart';
import 'package:tencent_cloud_chat_demo/src/theme/app_colors.dart';
import 'package:tencent_cloud_chat_demo/src/ui/utils/desktop_modal_layout.dart';
import 'package:tencent_cloud_chat_demo/src/widgets/app_dialog.dart';
import 'package:tencent_cloud_chat_demo/utils/chat_id_format.dart';
import 'package:tencent_cloud_chat_demo/utils/conversation_face_url.dart';
import 'package:tencent_cloud_chat_demo/utils/friend_add_source.dart';
import 'package:tencent_cloud_chat_demo/utils/friend_display_name.dart';
import 'package:tencent_cloud_chat_demo/utils/profile_page_nav.dart';
import 'package:tencent_cloud_chat_demo/utils/theme.dart';
import 'package:tencent_cloud_chat_demo/utils/toast.dart';
import 'package:tencent_cloud_chat_demo/utils/user_avatar.dart';
import 'package:tencent_cloud_chat_sdk/enum/receive_message_opt_enum.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_conversation.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_conversation.dart';
import 'package:tencent_cloud_chat_uikit/business_logic/view_models/tui_conversation_view_model.dart';
import 'package:tencent_cloud_chat_uikit/business_logic/view_models/tui_friendship_view_model.dart';
import 'package:tencent_cloud_chat_uikit/data_services/message/message_services.dart';
import 'package:tencent_cloud_chat_uikit/data_services/services_locatar.dart';
import 'package:tencent_cloud_chat_uikit/tencent_cloud_chat_uikit.dart';
import 'package:tencent_cloud_chat_uikit/theme/tui_theme.dart';
import 'package:tencent_cloud_chat_uikit/data_services/core/tim_uikit_wide_modal_operation_key.dart';
import 'package:tencent_cloud_chat_uikit/ui/utils/message_anchor.dart';
import 'package:tencent_cloud_chat_uikit/ui/widgets/avatar.dart';
import 'package:tencent_cloud_chat_uikit/ui/widgets/wide_popup.dart';

/// 单聊「聊天设置」页（头部点头像/标题进入，不再直达用户资料）。
class C2cChatSettingsPage extends StatefulWidget {
  const C2cChatSettingsPage({
    super.key,
    required this.conversation,
    this.directToChat,
    this.onRemarkUpdate,

    /// 嵌在宽屏右侧边栏时去掉内层 AppBar，避免与「设置」双标题。
    this.embeddedInSidePanel = false,
  });

  final V2TimConversation conversation;
  final ValueChanged<V2TimConversation>? directToChat;
  final void Function(String remark)? onRemarkUpdate;
  final bool embeddedInSidePanel;

  @override
  State<C2cChatSettingsPage> createState() => _C2cChatSettingsPageState();
}

class _C2cChatSettingsPageState extends State<C2cChatSettingsPage> {
  final TUIConversationViewModel _conversationModel =
      serviceLocator<TUIConversationViewModel>();
  final MessageService _messageService = serviceLocator<MessageService>();
  final TUIFriendShipViewModel _friendship =
      serviceLocator<TUIFriendShipViewModel>();

  late V2TimConversation _conversation;
  UserProfileRecord? _localProfile;
  bool _busy = false;

  String get _peerId =>
      ChatIdFormat.rawUserUid(widget.conversation.userID ?? '');

  String get _conversationId {
    final id = _conversation.conversationID.trim();
    if (id.isNotEmpty) {
      return id;
    }
    final peer = _peerId;
    return peer.isEmpty ? '' : 'c2c_$peer';
  }

  @override
  void initState() {
    super.initState();
    _conversation = widget.conversation;
    PeerProfileRefreshBus.instance.revision.addListener(_onPeerProfileRefresh);
    unawaited(_bootstrap());
  }

  @override
  void dispose() {
    PeerProfileRefreshBus.instance.revision
        .removeListener(_onPeerProfileRefresh);
    super.dispose();
  }

  void _onPeerProfileRefresh() {
    final peer = _peerId;
    if (peer.isEmpty || !PeerProfileRefreshBus.instance.matches(peer)) {
      return;
    }
    unawaited(_reloadPeerAvatarAfterProfileChange());
  }

  Future<void> _reloadPeerAvatarAfterProfileChange() async {
    await _loadLocalProfile();
    await _resolvePeerFace();
  }

  Future<void> _bootstrap() async {
    await Future.wait([
      _refreshConversation(),
      _loadLocalProfile(),
    ]);
    if (!mounted) {
      return;
    }
    await _resolvePeerFace();
  }

  Future<void> _loadLocalProfile() async {
    final peer = _peerId;
    if (peer.isEmpty) {
      return;
    }
    final record = await UserProfileLocalService.instance.read(peer);
    if (!mounted) {
      return;
    }
    setState(() => _localProfile = record);
  }

  Future<void> _refreshConversation() async {
    final id = _conversationId;
    if (id.isEmpty) {
      return;
    }
    final previousFace =
        UserAvatarHelper.usableAvatarOrEmpty(_conversation.faceUrl);
    try {
      final latest = await TIMUIKitCore.getSDKInstance()
          .getConversationManager()
          .getConversation(conversationID: id);
      if (!mounted || latest.code != 0 || latest.data == null) {
        return;
      }
      final next = latest.data!;
      next.isPinned =
          ConversationPinSyncService.instance.isPinnedConversationId(id);
      final nextFace = UserAvatarHelper.usableAvatarOrEmpty(next.faceUrl);
      if (nextFace.isEmpty && previousFace.isNotEmpty) {
        next.faceUrl = previousFace;
      }
      setState(() => _conversation = next);
    } catch (_) {}
  }

  Future<void> _resolvePeerFace() async {
    final peer = _peerId;
    if (peer.isEmpty) {
      return;
    }
    final resolved = await UserAvatarHelper.resolveChatPeerFaceUrl(
      peerUserId: peer,
      conversationFaceUrl: _conversation.faceUrl,
      preferLiveProfile: true,
    );
    if (!mounted) {
      return;
    }
    final usable = UserAvatarHelper.usableAvatarOrEmpty(resolved);
    if (usable.isEmpty) {
      return;
    }
    if (UserAvatarHelper.usableAvatarOrEmpty(_conversation.faceUrl) == usable) {
      return;
    }
    setState(() {
      _conversation.faceUrl = usable;
    });
  }

  String _displayName() {
    return FriendDisplayName.resolveLocalFirst(
      localProfile: _localProfile,
      userId: _peerId,
      conversationShowName: _conversation.showName,
    );
  }

  String _faceUrl() {
    final fromList = ConversationFaceUrl.resolve(
      userId: _peerId,
      conversationFaceUrl: _conversation.faceUrl,
      friendList: _friendship.friendList,
    );
    return UserAvatarHelper.pickBestPreferBackend(
      imFaceUrl: fromList,
      backendAvatarUrl: _localProfile?.avatarUrl,
    );
  }

  bool get _isPinned => ConversationPinSyncService.instance
      .isPinnedConversationId(_conversationId);

  bool get _isMuted => (_conversation.recvOpt ?? 0) != 0;

  Future<void> _openPeerProfile() async {
    final peer = _peerId;
    if (peer.isEmpty) {
      return;
    }
    await ProfilePageNav.openUserProfileOrAddFriend(
      context,
      userID: peer,
      addSource: FriendAddSource.chat,
      onRemarkUpdate: widget.onRemarkUpdate,
    );
    if (mounted) {
      unawaited(_loadLocalProfile());
      unawaited(_resolvePeerFace());
    }
  }

  Future<void> _openCreateGroup() async {
    final peerId = _peerId;
    if (DesktopModalLayout.isDesktop(context)) {
      DesktopCreateGroupHost.open(
        scope: DesktopCreateGroupScope.c2c,
        convType: GroupTypeForUIKit.work,
        selectGroupTypeAfterMembers: true,
        initialSelectedUserIds: peerId.isEmpty ? null : <String>[peerId],
      );
      return;
    }
    await Navigator.of(context).push(
      AppMaterialPageRoute(
        builder: (_) => CreateGroup(
          // convType 仅作选人上限占位；真正类型在选完好友后进通用选择页决定。
          convType: GroupTypeForUIKit.work,
          selectGroupTypeAfterMembers: true,
          initialSelectedUserIds: peerId.isEmpty ? null : <String>[peerId],
          directToChat: (conversation) {
            if (widget.directToChat != null) {
              widget.directToChat!(conversation);
              return;
            }
            openOrReuseAppChat(context, conversation);
          },
        ),
      ),
    );
  }

  Future<void> _openSearch() async {
    // 手机：替换设置页，避免返回栈叠多层聊天。
    // 宽屏边栏：普通 push，关闭搜索后仍回到右侧设置。
    final route = AppMaterialPageRoute(
      settings: const RouteSettings(name: AppRoutes.searchInConversation),
      builder: (context) => Search(
        conversation: _conversation,
        onTapConversation:
            (V2TimConversation conversation, MessageAnchor? anchor) {
          openChatWithAnchor(context, conversation, anchor: anchor);
        },
      ),
    );
    if (widget.embeddedInSidePanel) {
      await Navigator.push(context, route);
    } else {
      await Navigator.pushReplacement(context, route);
    }
  }

  Future<void> _setPinned(bool value) async {
    if (_conversationId.isEmpty || _busy) {
      return;
    }
    // 勿先改 conversation.isPinned：PinService 用该字段判 prev==next 会直接空成功，
    // SDK/本地都不写，随后 refresh 又把开关拉回旧值（取消置顶无效果）。
    setState(() => _busy = true);
    try {
      final result = await ConversationPinService.instance.setPinned(
        conversation: _conversation,
        isPinned: value,
        source: 'c2c_chat_settings',
      );
      if (!mounted) {
        return;
      }
      if (!result.applied) {
        setState(() => _busy = false);
        ToastUtils.toast(AppI18n.of(context).t(
          zhHans: '设置失败',
          zhHant: '設置失敗',
          en: 'Failed to update',
          ja: '設定に失敗しました',
          ko: '설정에 실패했습니다',
        ));
        return;
      }
      setState(() {
        _conversation.isPinned = result.isPinned;
        _busy = false;
      });
    } on ConversationPinLimitExceededException {
      if (!mounted) {
        return;
      }
      setState(() => _busy = false);
      ToastUtils.toast(AppI18n.of(context).t(
        zhHans: '置顶已达上限（最多 100 个）',
        zhHant: '置頂已達上限（最多 100 個）',
        en: 'Pin limit reached (max 100)',
        ja: 'ピン留め上限です（最大100）',
        ko: '고정 한도에 도달했습니다(최대 100)',
      ));
    }
    unawaited(_refreshConversation());
  }

  Future<void> _setMuted(bool value) async {
    final peer = _peerId;
    if (peer.isEmpty || _busy) {
      return;
    }
    setState(() {
      _busy = true;
      _conversation.recvOpt = value ? 2 : 0;
    });
    // IM-09 ADR §10.1: c2c 免打扰收敛到 C2cReceiveOptService,
    // 在异步链入口处 capture() 拿到 SessionIdentity,跨账号 fence 生效.
    final captured = SessionIdentityService.instance.capture();
    final key = AccountScopedConversationKey.tryParse(
      ownerUserId: captured.ownerUserId,
      conversationType: ImConversationType.c2c,
      conversationId: peer,
    );
    if (key == null) {
      if (mounted) {
        setState(() {
          _conversation.recvOpt = value ? 0 : 2;
          _busy = false;
        });
        ToastUtils.toast(AppI18n.of(context).t(
          zhHans: '设置失败',
          zhHant: '設置失敗',
          en: 'Failed to update',
          ja: '設定に失敗しました',
          ko: '설정에 실패했습니다',
        ));
      }
      return;
    }
    final res = await C2cReceiveOptService.setOpt(
      messageService: _messageService,
      key: key,
      opt: value
          ? ReceiveMsgOptEnum.V2TIM_RECEIVE_NOT_NOTIFY_MESSAGE
          : ReceiveMsgOptEnum.V2TIM_RECEIVE_MESSAGE,
      capturedIdentity: captured,
    );
    if (!mounted) {
      return;
    }
    if (res.code != 0) {
      setState(() {
        _conversation.recvOpt = value ? 0 : 2;
        _busy = false;
      });
      ToastUtils.toast(AppI18n.of(context).t(
        zhHans: '设置失败',
        zhHant: '設置失敗',
        en: 'Failed to update',
        ja: '設定に失敗しました',
        ko: '설정에 실패했습니다',
      ));
      return;
    }
    setState(() => _busy = false);
    unawaited(_friendship.loadContactListData());
    unawaited(_refreshConversation());
  }

  Future<void> _openChatBackground() async {
    final conversationId = _conversationId;
    if (conversationId.isEmpty) {
      ToastUtils.toast(AppI18n.of(context).t(
        zhHans: '当前无法设置聊天背景',
        zhHant: '目前無法設定聊天背景',
        en: 'Cannot set chat background now',
        ja: '今は背景を設定できません',
        ko: '지금은 배경 설정 불가',
      ));
      return;
    }
    final page = ChatBackgroundPage(
      conversationId: conversationId,
      conversationName: _displayName(),
      embedded: DesktopModalLayout.isDesktop(context),
    );
    if (DesktopModalLayout.isDesktop(context)) {
      final size = DesktopModalLayout.dualPane(context);
      await TUIKitWidePopup.showPopupWindow(
        operationKey: TUIKitWideModalOperationKey.custom,
        context: context,
        title: AppI18n.of(context).t(
          zhHans: '聊天背景',
          zhHant: '聊天背景',
          en: 'Chat Background',
          ja: 'チャット背景',
          ko: '채팅 배경',
        ),
        width: size.width,
        height: size.height,
        borderRadius: const BorderRadius.all(Radius.circular(16)),
        child: (_) => page,
      );
      return;
    }
    await Navigator.push(
      context,
      AppMaterialPageRoute(builder: (context) => page),
    );
  }

  Future<void> _confirmAndClearHistory() async {
    final peer = _peerId;
    if (peer.isEmpty) {
      ToastUtils.toast(AppI18n.of(context).t(
        zhHans: '当前无法清空聊天记录',
        zhHant: '目前無法清空聊天記錄',
        en: 'Cannot clear chat history now',
        ja: '今は履歴を削除できません',
        ko: '지금은 채팅 기록을 삭제할 수 없습니다',
      ));
      return;
    }
    final confirmed = await AppDialog.confirm(
      title: AppI18n.of(context).t(
        zhHans: '清空聊天记录',
        zhHant: '清空聊天記錄',
        en: 'Clear Chat History',
        ja: 'チャット履歴を削除',
        ko: '채팅 기록 삭제',
      ),
      message: AppI18n.of(context).t(
        zhHans: '清空后无法恢复，该会话将从消息列表移除。确定继续吗？',
        zhHant: '清空後無法恢復，該會話將從訊息列表移除。確定繼續嗎？',
        en: 'This cannot be undone. The conversation will also be removed from your message list. Continue?',
        ja: '削除後は元に戻せません。会話はメッセージ一覧からも削除されます。続行しますか？',
        ko: '삭제 후 복구할 수 없습니다. 대화가 메시지 목록에서도 제거됩니다. 계속할까요?',
      ),
      confirmText: AppI18n.of(context).t(
        zhHans: '清空',
        zhHant: '清空',
        en: 'Clear',
        ja: '削除',
        ko: '삭제',
      ),
      destructive: true,
    );
    if (!confirmed || !mounted) {
      return;
    }

    unawaited(AppDialog.showLoading(
      text: AppI18n.of(context).t(
        zhHans: '正在清空...',
        zhHant: '正在清空...',
        en: 'Clearing...',
        ja: '削除中...',
        ko: '삭제 중...',
      ),
    ));
    // 等 loading 路由挂上，避免清空极快返回时 hideLoading 误 pop 设置页。
    await Future<void>.delayed(const Duration(milliseconds: 50));
    try {
      final result = await _conversationModel.clearHistoryMessage(
        convID: peer,
        convType: 1,
      );
      if (result?.code == 0) {
        final convId = _conversationId;
        if (convId.isNotEmpty) {
          await ConversationSyncService.instance.onConversationHistoryCleared(
            conversationID: convId,
            snapshot: _conversation,
          );
        }
        widget.conversation.lastMessage = null;
        _conversation.lastMessage = null;
        if (mounted) {
          ToastUtils.toast(AppI18n.of(context).t(
            zhHans: '聊天记录已清空',
            zhHant: '聊天記錄已清空',
            en: 'Chat history cleared',
            ja: 'チャット履歴を削除しました',
            ko: '채팅 기록을 삭제했습니다',
          ));
        }
        return;
      }
      if (mounted) {
        ToastUtils.toast(AppI18n.of(context).t(
          zhHans: '清空聊天记录失败',
          zhHant: '清空聊天記錄失敗',
          en: 'Failed to clear chat history',
          ja: 'チャット履歴の削除に失敗しました',
          ko: '채팅 기록 삭제에 실패했습니다',
        ));
      }
    } catch (_) {
      if (mounted) {
        ToastUtils.toast(AppI18n.of(context).t(
          zhHans: '清空聊天记录失败',
          zhHant: '清空聊天記錄失敗',
          en: 'Failed to clear chat history',
          ja: 'チャット履歴の削除に失敗しました',
          ko: '채팅 기록 삭제에 실패했습니다',
        ));
      }
    } finally {
      AppDialog.hideLoading();
    }
  }

  Future<void> _openComplaint() async {
    final peer = _peerId;
    if (peer.isEmpty || ProfilePageNav.isSelfUser(peer)) {
      ToastUtils.toast(AppI18n.of(context).t(
        zhHans: '不能投诉自己',
        zhHant: '不能投訴自己',
        en: 'You cannot report yourself.',
        ja: '自分自身を通報できません。',
        ko: '자신을 신고할 수 없습니다.',
      ));
      return;
    }
    await ComplaintReasonPage.openC2c(
      context,
      reportedUserId: peer,
      reportedUserName: _displayName(),
    );
  }

  Widget _sectionGap(Color pageBg) {
    return Container(height: 10, color: pageBg);
  }

  Widget _sectionCard(TUITheme theme, Color cardBg, List<Widget> children) {
    return Container(
      color: cardBg,
      child: Column(
        children: List.generate(children.length * 2 - 1, (index) {
          if (index.isOdd) {
            return Divider(
              height: 0.6,
              thickness: 0.6,
              indent: 16,
              color: theme.weakDividerColor ?? const Color(0xFFE5E5E5),
            );
          }
          return children[index ~/ 2];
        }),
      ),
    );
  }

  Widget _memberCard(TUITheme theme, Color cardBg) {
    final name = _displayName();
    final face = _faceUrl();
    final weak = theme.weakTextColor ?? const Color(0xFF999999);
    return Container(
      width: double.infinity,
      color: cardBg,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
      child: Wrap(
        spacing: 18,
        runSpacing: 12,
        children: [
          InkWell(
            onTap: _openPeerProfile,
            borderRadius: BorderRadius.circular(8),
            child: SizedBox(
              width: 54,
              child: Column(
                children: [
                  SizedBox(
                    width: 48,
                    height: 48,
                    child: Avatar(
                      faceUrl: face,
                      showName: name,
                      type: 1,
                      borderRadius: BorderRadius.circular(24),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 12, color: weak),
                  ),
                ],
              ),
            ),
          ),
          InkWell(
            onTap: _openCreateGroup,
            borderRadius: BorderRadius.circular(8),
            child: SizedBox(
              width: 54,
              child: Column(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: weak.withValues(alpha: 0.45)),
                    ),
                    child: Icon(Icons.add, color: weak, size: 28),
                  ),
                  const SizedBox(height: 6),
                  const SizedBox(height: 14),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _switchRow({
    required TUITheme theme,
    required String title,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    final titleColor = theme.darkTextColor ?? Colors.black;
    return SizedBox(
      height: 54,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          children: [
            Expanded(
              child: Text(
                title,
                style: TextStyle(fontSize: 16, color: titleColor),
              ),
            ),
            Transform.scale(
              scale: 0.9,
              child: CupertinoSwitch(
                value: value,
                onChanged: onChanged,
                activeTrackColor: theme.primaryColor ?? const Color(0xFF1E90FF),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _arrowRow({
    required TUITheme theme,
    required String title,
    VoidCallback? onTap,
    Widget? trailing,
    bool showArrow = true,
  }) {
    final titleColor = theme.darkTextColor ?? Colors.black;
    final weak = theme.weakTextColor ?? const Color(0xFF999999);
    return InkWell(
      onTap: onTap,
      child: SizedBox(
        height: 54,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(fontSize: 16, color: titleColor),
                ),
              ),
              if (trailing != null) ...[
                trailing,
                const SizedBox(width: 6),
              ],
              if (showArrow)
                Icon(Icons.chevron_right_rounded, color: weak, size: 22),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Provider.of<DefaultThemeData>(context).theme;
    final isDark = Provider.of<DefaultThemeData>(context, listen: false)
            .currentThemeType ==
        ThemeType.dark;
    final i18n = AppI18n.of(context);
    // 浅色强制灰底 + 白卡片，避免 weakBackground 接近白色导致分区糊成一片。
    final pageBg = isDark
        ? (theme.weakBackgroundColor ?? AppColors.background(dark: true))
        : const Color(0xFFF1F1F1);
    final cardBg = isDark
        ? (theme.conversationItemBgColor ??
            theme.wideBackgroundColor ??
            AppColors.card(dark: true))
        : Colors.white;
    final appBarBg = isDark
        ? (theme.appbarBgColor ?? cardBg)
        : (theme.appbarBgColor ?? Colors.white);
    final textColor = theme.darkTextColor ?? AppColors.text(dark: isDark);
    final primary = theme.primaryColor ?? AppColors.primaryBlue;

    final body = ListView(
      children: [
        _memberCard(theme, cardBg),
        _sectionGap(pageBg),
        _sectionCard(theme, cardBg, [
          _arrowRow(
            theme: theme,
            title: i18n.t(
              zhHans: '查找聊天内容',
              zhHant: '查找聊天內容',
              en: 'Search Chat Content',
              ja: 'チャット内容を検索',
              ko: '채팅 내용 검색',
            ),
            onTap: _openSearch,
          ),
        ]),
        _sectionGap(pageBg),
        _sectionCard(theme, cardBg, [
          _switchRow(
            theme: theme,
            title: i18n.t(
              zhHans: '置顶聊天',
              zhHant: '置頂聊天',
              en: 'Pin Chat',
              ja: 'チャットをピン留め',
              ko: '채팅 고정',
            ),
            value: _isPinned,
            onChanged: _setPinned,
          ),
          _switchRow(
            theme: theme,
            title: i18n.t(
              zhHans: '消息免打扰',
              zhHant: '訊息免打擾',
              en: 'Mute Notifications',
              ja: '通知をミュート',
              ko: '알림 끄기',
            ),
            value: _isMuted,
            onChanged: _setMuted,
          ),
        ]),
        _sectionGap(pageBg),
        _sectionCard(theme, cardBg, [
          _arrowRow(
            theme: theme,
            title: i18n.t(
              zhHans: '设置当前聊天背景',
              zhHant: '設定目前聊天背景',
              en: 'Set Chat Background',
              ja: 'チャット背景を設定',
              ko: '채팅 배경 설정',
            ),
            onTap: _openChatBackground,
          ),
        ]),
        _sectionGap(pageBg),
        _sectionCard(theme, cardBg, [
          _arrowRow(
            theme: theme,
            title: i18n.t(
              zhHans: '清空聊天记录',
              zhHant: '清空聊天記錄',
              en: 'Clear Chat History',
              ja: 'チャット履歴を削除',
              ko: '채팅 기록 삭제',
            ),
            showArrow: false,
            onTap: _confirmAndClearHistory,
          ),
        ]),
        _sectionGap(pageBg),
        _sectionCard(theme, cardBg, [
          _arrowRow(
            theme: theme,
            title: i18n.t(
              zhHans: '投诉',
              zhHant: '投訴',
              en: 'Complaint',
              ja: '通報',
              ko: '신고',
            ),
            onTap: _openComplaint,
          ),
        ]),
        const SizedBox(height: 24),
      ],
    );

    if (widget.embeddedInSidePanel) {
      return ColoredBox(
        color: pageBg,
        child: body,
      );
    }

    return Scaffold(
      backgroundColor: pageBg,
      appBar: AppBar(
        elevation: 0,
        centerTitle: true,
        backgroundColor: appBarBg,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          color: primary,
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          i18n.t(
            zhHans: '聊天设置',
            zhHant: '聊天設置',
            en: 'Chat Settings',
            ja: 'チャット設定',
            ko: '채팅 설정',
          ),
          style: TextStyle(
            color: theme.appbarTextColor ?? textColor,
            fontSize: 17,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: body,
    );
  }
}
