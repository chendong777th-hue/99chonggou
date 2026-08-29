import 'dart:async' show unawaited;

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tencent_cloud_chat_demo/src/services/group_game/privileged_game_user_service.dart';
import 'package:tencent_cloud_chat_demo/src/provider/presence_provider.dart';
import 'package:tencent_cloud_chat_demo/src/i18n/app_i18n.dart';
import 'package:tencent_cloud_chat_demo/src/api/friend_request_api.dart';
import 'package:tencent_cloud_chat_demo/src/friend_application_helper.dart';
import 'package:tencent_cloud_chat_demo/src/models/friend_request_record.dart';
import 'package:tencent_cloud_chat_demo/src/services/friend_local/friend_sync_service.dart';
import 'package:tencent_cloud_chat_demo/src/services/user_profile_local/user_profile_local_service.dart';
import 'package:tencent_cloud_chat_demo/src/api/user_api.dart';
import 'package:tencent_cloud_chat_demo/utils/custom_message/contact_card_message.dart';
import 'package:tencent_cloud_chat_demo/utils/custom_message/friend_became_friends_message.dart';
import 'package:tencent_cloud_chat_demo/utils/group_privacy_guard.dart';
import 'package:tencent_cloud_chat_demo/utils/group_member_join_meta_loader.dart';
import 'package:tencent_cloud_chat_demo/src/models/me_group_record.dart';
import 'package:tencent_cloud_chat_demo/src/widgets/group_member_join_meta_section.dart';
import 'package:tencent_cloud_chat_demo/src/provider/theme.dart';
import 'package:tencent_cloud_chat_demo/src/theme/app_colors.dart';
import 'package:tencent_cloud_chat_demo/src/ui/utils/desktop_modal_layout.dart';
import 'package:tencent_cloud_chat_demo/utils/friend_qr_add_policy.dart';
import 'package:tencent_cloud_chat_demo/utils/friend_add_source.dart';
import 'package:tencent_cloud_chat_demo/src/platform/clipboard_guard.dart';
import 'package:tencent_cloud_chat_demo/utils/chat_id_format.dart';
import 'package:tencent_cloud_chat_demo/utils/navigation_routes.dart';
import 'package:tencent_cloud_chat_demo/utils/toast.dart';
import 'package:tencent_cloud_chat_demo/utils/user_api_error_message.dart';
import 'package:tencent_cloud_chat_demo/src/widgets/user_profile/user_profile_game_admin_panel.dart';
import 'package:tencent_cloud_chat_demo/src/widgets/user_profile/profile_page_keyboard.dart';
import 'package:tencent_cloud_chat_demo/src/widgets/user_profile/user_profile_game_ledger_floating_entry.dart';
import 'package:tencent_cloud_chat_demo/src/widgets/user_profile/user_profile_game_ledger_sheet.dart';
import 'package:tencent_cloud_chat_sdk/manager/v2_tim_manager.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_user_full_info.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_user_full_info.dart';
import 'package:tencent_cloud_chat_uikit/business_logic/view_models/tui_self_info_view_model.dart';
import 'package:tencent_cloud_chat_uikit/business_logic/view_models/tui_friendship_view_model.dart';
import 'package:tencent_cloud_chat_uikit/data_services/conversation/conversation_services.dart';
import 'package:tencent_cloud_chat_uikit/data_services/core/tim_uikit_wide_modal_operation_key.dart';
import 'package:tencent_cloud_chat_uikit/data_services/services_locatar.dart';
import 'package:tencent_cloud_chat_uikit/tencent_cloud_chat_uikit.dart';
import 'package:tencent_cloud_chat_demo/src/widgets/presence_subtitle.dart';
import 'package:tencent_cloud_chat_uikit/ui/widgets/avatar.dart';
import 'package:tencent_cloud_chat_uikit/ui/widgets/wide_popup.dart';

class AddFriendPage extends StatefulWidget {
  final String userID;
  final String nickname;
  final V2TimUserFullInfo? initialUserInfo;
  final String? addSource;
  final int? lastActiveAt;
  final String? lastActiveVisibility;
  final String? groupId;
  final bool fromContactCard;
  final bool? contactCardAllowViaCard;

  /// 嵌在宽屏弹窗内：去掉内层 AppBar，避免与外层标题双头。
  final bool embedded;

  const AddFriendPage({
    Key? key,
    required this.userID,
    required this.nickname,
    this.initialUserInfo,
    this.addSource,
    this.lastActiveAt,
    this.lastActiveVisibility,
    this.groupId,
    this.fromContactCard = false,
    this.contactCardAllowViaCard,
    this.embedded = false,
  }) : super(key: key);

  /// 桌面 / Web：弹窗或弹窗内嵌套路由；移动端：全页 push。
  static Future<void> open(
    BuildContext context, {
    required String userID,
    required String nickname,
    V2TimUserFullInfo? initialUserInfo,
    String? addSource,
    int? lastActiveAt,
    String? lastActiveVisibility,
    String? groupId,
    bool fromContactCard = false,
    bool? contactCardAllowViaCard,
  }) async {
    final id = userID.trim();
    if (id.isEmpty || !context.mounted) {
      return;
    }

    AddFriendPage buildPage({bool embedded = false}) => AddFriendPage(
          userID: id,
          nickname: nickname,
          initialUserInfo: initialUserInfo,
          addSource: addSource,
          lastActiveAt: lastActiveAt,
          lastActiveVisibility: lastActiveVisibility,
          groupId: groupId,
          fromContactCard: fromContactCard,
          contactCardAllowViaCard: contactCardAllowViaCard,
          embedded: embedded,
        );

    if (!DesktopModalLayout.isDesktop(context)) {
      await Navigator.push(
        context,
        NavigationRoutes.cupertino(builder: (_) => buildPage()),
      );
      return;
    }

    // 已在宽屏弹窗内：走局部 Navigator，避免全屏盖住主界面。
    if (TUIKitWidePopup.isShow) {
      await Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => buildPage()),
      );
      return;
    }

    final size = DesktopModalLayout.medium(context);
    final i18n = AppI18n.of(context);
    await TUIKitWidePopup.showPopupWindow(
      operationKey: TUIKitWideModalOperationKey.addFriend,
      context: context,
      width: size.width,
      height: size.height,
      borderRadius: const BorderRadius.all(Radius.circular(20)),
      title: i18n.t(
        zhHans: '添加好友',
        zhHant: '添加好友',
        en: 'Add Friend',
        ja: '友達を追加',
        ko: '친구 추가',
      ),
      child: (_) => buildPage(embedded: true),
    );
  }

  @override
  State<AddFriendPage> createState() => _AddFriendPageState();
}

class _AddFriendPageState extends State<AddFriendPage> {
  final ConversationService _conversationService =
      serviceLocator<ConversationService>();
  final TUISelfInfoViewModel _selfInfoViewModel =
      serviceLocator<TUISelfInfoViewModel>();
  final V2TIMManager _sdkInstance = TIMUIKitCore.getSDKInstance();

  V2TimUserFullInfo? _userInfo;
  String _sdkFaceUrl = '';
  bool _loadingUserInfo = true;
  bool _adding = false;
  bool _checkingCardPolicy = false;
  bool _cardAddBlocked = false;
  bool _qrAddBlocked = false;
  bool _showAddButton = true;
  String? _addHiddenHint;
  bool _loadingGroupAddPolicy = false;
  bool _checkingQrPolicy = false;
  bool _isPrivilegedGameUser = PrivilegedGameUserService.instance.isPrivileged;
  GroupMemberRecord? _groupJoinMetaRecord;

  @override
  void initState() {
    super.initState();
    _userInfo = widget.initialUserInfo;
    _sdkFaceUrl = _faceUrlFromInfo(widget.initialUserInfo);
    _isPrivilegedGameUser = PrivilegedGameUserService.instance.isPrivileged;
    PrivilegedGameUserService.instance.gameEnabled
        .addListener(_onPrivilegedGameAccessChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _loadUserInfo();
      _resolveGroupAddUi();
      _refreshQrAddPolicy();
      _refreshPrivilegedGameAccess();
      unawaited(_loadGroupMemberJoinMeta());
      if (_isCardAddEntry && !_isGroupAddEntry) {
        _refreshCardAddPolicy();
      }
      final presence = Provider.of<PresenceProvider>(context, listen: false);
      presence.applyPresenceBatch(
        lastSeen: widget.lastActiveAt != null
            ? {widget.userID: widget.lastActiveAt!}
            : null,
        lastActiveVisibility: widget.lastActiveVisibility != null
            ? {widget.userID: widget.lastActiveVisibility!}
            : null,
      );
      presence.ensure([widget.userID]);
      presence.refresh([widget.userID], urgent: true);
    });
  }

  Future<void> _loadGroupMemberJoinMeta() async {
    final gid = widget.groupId?.trim() ?? '';
    if (gid.isEmpty) {
      if (mounted) {
        setState(() => _groupJoinMetaRecord = null);
      }
      return;
    }
    final record = await GroupMemberJoinMetaLoader.loadVisible(
      groupId: gid,
      userId: widget.userID,
    );
    if (!mounted) {
      return;
    }
    setState(() => _groupJoinMetaRecord = record);
  }

  @override
  void dispose() {
    PrivilegedGameUserService.instance.gameEnabled
        .removeListener(_onPrivilegedGameAccessChanged);
    super.dispose();
  }

  String _faceUrlFromInfo(V2TimUserFullInfo? info) {
    return TencentUtils.checkString(info?.faceUrl) ?? '';
  }

  bool get _isGroupAddEntry => GroupPrivacyGuard.isGroupAddEntry(
        groupId: widget.groupId,
        addSource: widget.addSource,
      );

  bool get _isCardAddEntry {
    if (widget.fromContactCard) {
      return true;
    }
    return _effectiveAddSource == FriendAddSource.card;
  }

  bool get _isQrAddEntry {
    if (_isCardAddEntry || _isGroupAddEntry) {
      return false;
    }
    final source = _effectiveAddSource.trim().toLowerCase();
    final normalized = source.replaceAll('_', '');
    return normalized == 'addsourcetypeqrcode' ||
        normalized == 'qrcode' ||
        normalized == 'qr';
  }

  Future<void> _resolveGroupAddUi() async {
    if (!_isGroupAddEntry) {
      return;
    }
    setState(() => _loadingGroupAddPolicy = true);
    try {
      final policy = await GroupPrivacyGuard.resolveAddFriendUi(
        groupId: widget.groupId,
        targetUserId: widget.userID,
        addSource: widget.addSource,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _showAddButton = policy.showAddButton;
        final hint = policy.hiddenHint;
        _addHiddenHint = hint == null
            ? null
            : UserApiErrorMessage.fromAddFriendReasonCode(
                hint,
                fallback: hint,
              );
      });
    } finally {
      if (mounted) {
        setState(() => _loadingGroupAddPolicy = false);
      }
    }
  }

  Future<void> _refreshCardAddPolicy() async {
    if (!_isCardAddEntry || widget.userID.isEmpty) {
      return;
    }
    setState(() => _checkingCardPolicy = true);
    try {
      final allowed = await resolveContactCardAllowViaCard(
        targetUserId: widget.userID,
        embeddedAllowViaCard: widget.contactCardAllowViaCard,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _cardAddBlocked = !allowed;
        if (!allowed) {
          _showAddButton = false;
          _addHiddenHint = AppI18n.current.t(
            zhHans: '对方未开放通过名片添加',
            zhHant: '對方未開放通過名片添加',
            en: 'This user does not allow adds via contact card.',
            ja: 'This user does not allow adds via contact card.',
            ko: 'This user does not allow adds via contact card.',
          );
        }
      });
    } finally {
      if (mounted) {
        setState(() => _checkingCardPolicy = false);
      }
    }
  }

  Future<void> _refreshQrAddPolicy() async {
    if (!_isQrAddEntry || widget.userID.isEmpty) {
      return;
    }
    setState(() => _checkingQrPolicy = true);
    try {
      final allowed = await UserApi.instance.canAddFriendViaQr(widget.userID);
      if (!mounted) {
        return;
      }
      setState(() {
        _qrAddBlocked = !allowed;
        if (!allowed) {
          _showAddButton = false;
          _addHiddenHint = _qrAddNotAllowedText();
        }
      });
    } finally {
      if (mounted) {
        setState(() => _checkingQrPolicy = false);
      }
    }
  }

  Future<void> _loadUserInfo() async {
    if (widget.userID.isEmpty) {
      if (mounted) setState(() => _loadingUserInfo = false);
      return;
    }

    V2TimUserFullInfo? loaded = widget.initialUserInfo;
    String faceUrl = _faceUrlFromInfo(loaded);

    for (var attempt = 0; attempt < 3; attempt++) {
      final res = await _sdkInstance.getUsersInfo(userIDList: [widget.userID]);
      if (res.code == 0 && res.data != null && res.data!.isNotEmpty) {
        loaded = res.data!.first;
        faceUrl = _faceUrlFromInfo(loaded);
        if (faceUrl.isNotEmpty) {
          break;
        }
      }
      if (attempt < 2) {
        await Future.delayed(const Duration(milliseconds: 400));
      }
    }

    if (faceUrl.isEmpty) {
      final conversation = await _conversationService.getConversation(
        conversationID: 'c2c_${widget.userID}',
      );
      faceUrl = TencentUtils.checkString(conversation?.faceUrl) ?? '';
    }

    if (!mounted) return;
    setState(() {
      _userInfo = loaded;
      _sdkFaceUrl = faceUrl;
      _loadingUserInfo = false;
    });
  }

  String _getShowName() {
    final profileNick = TencentUtils.checkString(_userInfo?.nickName);
    if (profileNick != null && profileNick.isNotEmpty) {
      return profileNick;
    }
    if (widget.nickname.trim().isNotEmpty) {
      return widget.nickname.trim();
    }
    return widget.userID;
  }

  String _displayUserID() {
    if (_qrAddBlocked) {
      final masked = _maskUserID(ChatIdFormat.rawUserUid(widget.userID));
      if (masked.isEmpty) {
        return '';
      }
      return masked.startsWith('@') ? masked : '@$masked';
    }
    return ChatIdFormat.display(widget.userID);
  }

  String _maskUserID(String userID) {
    final id = ChatIdFormat.rawUserUid(userID);
    if (id.length <= 2) {
      return id;
    }
    return '${id[0]}****${id[id.length - 1]}';
  }

  Future<void> _copyDisplayUserID() async {
    final text = _displayUserID().trim();
    if (text.isEmpty) {
      return;
    }
    await ClipboardGuard.copy(text);
    if (!mounted) {
      return;
    }
    ToastUtils.toast(AppI18n.of(context).t(
      zhHans: '用户ID已复制',
      zhHant: '使用者 ID 已複製',
      en: 'User ID copied',
      ja: 'ユーザーIDをコピーしました',
      ko: '사용자 ID 복사됨',
    ));
  }

  String _presenceTitle(PresenceProvider presence, {required bool imOnline}) {
    if (presence.isLastSeenLoading(userId: widget.userID, imOnline: imOnline)) {
      return '';
    }
    return presence.labelFor(
      userId: widget.userID,
      imOnline: imOnline,
      isMutualFriend: false,
      lastActiveAtOverride: widget.lastActiveAt,
    );
  }

  bool _isImOnline() {
    final friendship = serviceLocator<TUIFriendShipViewModel>();
    for (final status in friendship.userStatusList) {
      if (status.userID == widget.userID) {
        return status.statusType == 1;
      }
    }
    return false;
  }

  String _qrAddNotAllowedText() => qrAddNotAllowedText();

  String _getSdkFaceUrl() {
    final fromInfo = _faceUrlFromInfo(_userInfo);
    if (fromInfo.isNotEmpty) {
      return fromInfo;
    }
    return _sdkFaceUrl;
  }

  bool _isSelfUser() {
    final target = ChatIdFormat.rawUserUid(widget.userID);
    final self =
        ChatIdFormat.rawUserUid(_selfInfoViewModel.loginInfo?.userID ?? '');
    return target.isNotEmpty && self.isNotEmpty && target == self;
  }

  void _onPrivilegedGameAccessChanged() {
    if (!mounted) {
      return;
    }
    final next = PrivilegedGameUserService.instance.isPrivileged;
    if (next != _isPrivilegedGameUser) {
      setState(() => _isPrivilegedGameUser = next);
    }
  }

  void _refreshPrivilegedGameAccess() {
    unawaited(PrivilegedGameUserService.instance.refreshFromNetwork());
  }

  Widget _buildGameAdminPanel({bool embedded = false}) {
    if (!_isPrivilegedGameUser || _isSelfUser()) {
      return const SizedBox.shrink();
    }
    final targetUserId = widget.userID.trim();
    if (targetUserId.isEmpty) {
      return const SizedBox.shrink();
    }
    return UserProfileGameAdminPanel(
      targetUserId: targetUserId,
      displayName: _getShowName(),
      embedded: embedded,
    );
  }

  bool _shouldShowGameLedger() {
    return _isPrivilegedGameUser &&
        !_isSelfUser() &&
        widget.userID.trim().isNotEmpty;
  }

  void _openGameLedger() {
    final imUserId = widget.userID.trim();
    if (imUserId.isEmpty) {
      return;
    }
    unawaited(
      UserProfileGameLedgerSheet.show(
        context,
        imUserId: imUserId,
        displayName: _getShowName(),
      ),
    );
  }

  String _getGenderLabel(AppI18n i18n) {
    switch (_userInfo?.gender) {
      case 1:
        return i18n.t(
          zhHans: '男',
          zhHant: '男',
          en: 'Male',
          ja: 'Male',
          ko: 'Male',
        );
      case 2:
        return i18n.t(
          zhHans: '女',
          zhHant: '女',
          en: 'Female',
          ja: 'Female',
          ko: 'Female',
        );
      default:
        return i18n.t(
          zhHans: '保密',
          zhHant: '保密',
          en: 'Private',
          ja: 'Private',
          ko: 'Private',
        );
    }
  }

  String get _effectiveAddSource {
    if (widget.fromContactCard) {
      return FriendAddSource.card;
    }
    final raw = widget.addSource?.trim() ?? '';
    return raw.isNotEmpty ? raw : FriendAddSource.search;
  }

  String _buildAddWording() {
    final rawNick =
        TencentUtils.checkString(_selfInfoViewModel.loginInfo?.nickName);
    final rawUserId =
        TencentUtils.checkString(_selfInfoViewModel.loginInfo?.userID);
    final selfName = rawNick ?? rawUserId ?? '';
    if (widget.fromContactCard) {
      return FriendAddSource.embedInWording(
        _effectiveAddSource,
        selfName.isEmpty ? '我是' : '我是$selfName',
      );
    }
    return FriendAddSource.embedInWording(
      _effectiveAddSource,
      selfName.isEmpty ? '我是' : '我是：$selfName',
    );
  }

  Future<void> _handleAdd() async {
    if (_adding ||
        widget.userID.isEmpty ||
        _cardAddBlocked ||
        _qrAddBlocked ||
        !_showAddButton) {
      return;
    }
    if (_isGroupAddEntry) {
      final policy = await GroupPrivacyGuard.resolveAddFriendUi(
        groupId: widget.groupId,
        targetUserId: widget.userID,
        addSource: widget.addSource,
      );
      if (!policy.showAddButton) {
        if (mounted) {
          final hint = policy.hiddenHint == null
              ? null
              : UserApiErrorMessage.fromAddFriendReasonCode(
                  policy.hiddenHint,
                  fallback: policy.hiddenHint!,
                );
          setState(() {
            _showAddButton = false;
            _addHiddenHint = hint;
          });
          ToastUtils.toast(
            hint ??
                AppI18n.current.t(
                  zhHans: '对方未开放通过群聊添加',
                  zhHant: '對方未開放通過群聊添加',
                  en: 'This user does not allow adds from group chats.',
                  ja: 'This user does not allow adds from group chats.',
                  ko: 'This user does not allow adds from group chats.',
                ),
          );
        }
        return;
      }
    } else if (_isCardAddEntry) {
      final allowed = await resolveContactCardAllowViaCard(
        targetUserId: widget.userID,
        embeddedAllowViaCard: widget.contactCardAllowViaCard,
      );
      if (!allowed) {
        if (mounted) {
          setState(() {
            _cardAddBlocked = true;
            _showAddButton = false;
            _addHiddenHint = AppI18n.current.t(
              zhHans: '对方未开放通过名片添加',
              zhHant: '對方未開放通過名片添加',
              en: 'This user does not allow adds via contact card.',
              ja: 'This user does not allow adds via contact card.',
              ko: 'This user does not allow adds via contact card.',
            );
          });
          ToastUtils.toast(_addHiddenHint!);
        }
        return;
      }
    }
    setState(() => _adding = true);
    try {
      final result = await FriendRequestApi.instance.create(
        targetUserId: widget.userID,
        addWording: _buildAddWording(),
        addSource: _effectiveAddSource,
      );
      if (!mounted) return;

      if (result.isAutoAccepted || result.isRestored) {
        await FriendSyncService.instance.onBecameFriends(
          peerUserId: widget.userID,
          nickname: _getShowName(),
          avatarUrl: _getSdkFaceUrl(),
          reason:
              result.isRestored ? 'friend_restored' : 'friend_auto_accepted',
        );
        await FriendBecameFriendsNotifier.notifyIfBecameFriends(
          peerUserId: widget.userID,
        );
        unawaited(
          FriendApplicationHelper.recordBecameFriendsHistory(
            userID: widget.userID,
            nickname: _getShowName(),
            faceUrl: _getSdkFaceUrl(),
            addSource: _effectiveAddSource,
            direction: FriendRequestDirection.outgoing,
          ),
        );
      }

      final message = result.isPending
          ? AppI18n.current.t(
              zhHans: '好友申请已发送',
              zhHant: '好友申請已發送',
              en: 'Friend request sent',
              ja: 'Friend request sent',
              ko: 'Friend request sent',
            )
          : result.isRestored
              ? AppI18n.current.t(
                  zhHans: '已恢复好友关系',
                  zhHant: '已恢復好友關係',
                  en: 'Friend relationship restored',
                  ja: 'Friend relationship restored',
                  ko: 'Friend relationship restored',
                )
              : AppI18n.current.t(
                  zhHans: '添加成功',
                  zhHant: '添加成功',
                  en: 'Added successfully',
                  ja: 'Added successfully',
                  ko: 'Added successfully',
                );
      ToastUtils.toast(message);
      Navigator.of(context).pop(true);
    } on DioError catch (e) {
      debugPrint(
          'ADD_FRIEND_TRACE backend target=${widget.userID} source=$_effectiveAddSource status=${e.response?.statusCode} data=${e.response?.data}');
      ToastUtils.toast(UserApiErrorMessage.fromFriendRequest(e));
    } catch (e, st) {
      debugPrint(
          'ADD_FRIEND_TRACE exception target=${widget.userID} source=$_effectiveAddSource error=$e\n$st');
      ToastUtils.toast(AppI18n.current.t(
        zhHans: '添加失败，请稍后重试',
        zhHant: '添加失敗，請稍後重試',
        en: 'Failed to add friend. Try again later.',
        ja: '友だち追加に失敗しました。後でもう一度お試しください',
        ko: '친구 추가 실패. 나중에 다시 시도하세요',
      ));
    } finally {
      if (mounted) {
        setState(() => _adding = false);
      }
    }
  }

  Widget _buildInfoRow({
    required String title,
    required String value,
    required Color titleColor,
    required Color valueColor,
    required Color backgroundColor,
    VoidCallback? onTap,
  }) {
    final content = Container(
      color: backgroundColor,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            title,
            style: TextStyle(fontSize: 16, color: titleColor),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 16, color: valueColor),
            ),
          ),
        ],
      ),
    );
    if (onTap == null) {
      return content;
    }
    return Material(
      color: Colors.transparent,
      child: InkWell(onTap: onTap, child: content),
    );
  }

  Widget _buildAddFriendBottomBar({
    required AppI18n i18n,
    required Color primaryColor,
    required Color valueColor,
    required String addButtonLabel,
    double buttonBorderRadius = 6,
    bool showButtonWhenBlocked = true,
  }) {
    final buttonDisabled = _adding ||
        _checkingCardPolicy ||
        _checkingQrPolicy ||
        _loadingGroupAddPolicy ||
        !_showAddButton ||
        _cardAddBlocked ||
        _qrAddBlocked;
    final buttonLoading = _adding ||
        _checkingCardPolicy ||
        _checkingQrPolicy ||
        _loadingGroupAddPolicy;

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (!_showAddButton && (_addHiddenHint?.isNotEmpty ?? false))
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(
                  _addHiddenHint!,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    color: valueColor,
                  ),
                ),
              )
            else if (_cardAddBlocked)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(
                  i18n.t(
                    zhHans: '对方未开放通过名片添加',
                    zhHant: '對方未開放通過名片添加',
                    en: 'This user does not allow adds via contact card.',
                    ja: 'This user does not allow adds via contact card.',
                    ko: 'This user does not allow adds via contact card.',
                  ),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    color: valueColor,
                  ),
                ),
              ),
            if (showButtonWhenBlocked ||
                (!_cardAddBlocked &&
                    _showAddButton &&
                    (_addHiddenHint?.isEmpty ?? true)))
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: buttonDisabled ? null : _handleAdd,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryColor,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor:
                        primaryColor.withValues(alpha: 0.45),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(buttonBorderRadius),
                    ),
                  ),
                  child: buttonLoading
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Colors.white,
                            ),
                          ),
                        )
                      : Text(
                          addButtonLabel,
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileBody({
    required AppI18n i18n,
    required String showName,
    required String presenceTitle,
    required bool presenceLoading,
    required bool imOnline,
    required Color cardBackgroundColor,
    required Color titleColor,
    required Color valueColor,
    required Color dividerColor,
    required Color primaryColor,
  }) {
    final displayId = _displayUserID();
    final avatarOwnerId = ChatIdFormat.rawUserUid(widget.userID);
    final avatarVersion = UserProfileLocalService.instance
            .readCached(avatarOwnerId)
            ?.avatarVersion ??
        0;
    return ProfilePageKeyboard.dismissScope(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: SingleChildScrollView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    color: cardBackgroundColor,
                    padding: const EdgeInsets.fromLTRB(16, 18, 16, 18),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                showName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w700,
                                  color: titleColor,
                                ),
                              ),
                              if (displayId.isNotEmpty) ...[
                                const SizedBox(height: 6),
                                Row(
                                  children: [
                                    Text(
                                      i18n.t(
                                        zhHans: '99号ID: ',
                                        zhHant: '99號ID: ',
                                        en: '99 ID: ',
                                        ja: '99 ID: ',
                                        ko: '99 ID: ',
                                      ),
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: valueColor,
                                      ),
                                    ),
                                    Flexible(
                                      child: InkWell(
                                        onTap: () =>
                                            unawaited(_copyDisplayUserID()),
                                        borderRadius: BorderRadius.circular(4),
                                        child: Text(
                                          displayId,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            fontSize: 14,
                                            color: primaryColor,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                              const SizedBox(height: 4),
                              PresenceSubtitle(
                                label: presenceTitle,
                                loading: presenceLoading,
                                imOnline: imOnline,
                                fontSize: 13,
                                height: 1.2,
                                onlineColor: valueColor,
                                offlineColor: valueColor,
                                skeletonColor: valueColor,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 16),
                        SizedBox(
                          width: 72,
                          height: 72,
                          child: Avatar(
                            faceUrl: _getSdkFaceUrl(),
                            showName: showName,
                            type: 1,
                            borderRadius: BorderRadius.circular(36),
                            isShowBigWhenClick: true,
                            previewUrlResolver: () async {
                              final result = await UserApi.instance
                                  .fetchUserAvatarPreview(widget.userID);
                              return result.previewUrl;
                            },
                            avatarCacheKey: avatarOwnerId.isEmpty
                                ? null
                                : 'avatar|user|$avatarOwnerId|$avatarVersion|thumb',
                            previewCacheKey: avatarOwnerId.isEmpty
                                ? null
                                : 'avatar|user|$avatarOwnerId|$avatarVersion|preview',
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (_isPrivilegedGameUser && !_isSelfUser()) ...[
                    const SizedBox(height: 8),
                    _buildGameAdminPanel(embedded: true),
                  ],
                  const SizedBox(height: 12),
                  _buildInfoRow(
                    title: i18n.t(
                      zhHans: '性别',
                      zhHant: '性別',
                      en: 'Gender',
                      ja: 'Gender',
                      ko: 'Gender',
                    ),
                    value: _getGenderLabel(i18n),
                    titleColor: titleColor,
                    valueColor: valueColor,
                    backgroundColor: cardBackgroundColor,
                  ),
                  Container(height: 1, color: dividerColor),
                  _buildInfoRow(
                    title: i18n.t(
                      zhHans: '99号ID',
                      zhHant: '99號ID',
                      en: '99 ID',
                      ja: '99 ID',
                      ko: '99 ID',
                    ),
                    value: _displayUserID(),
                    titleColor: titleColor,
                    valueColor: primaryColor,
                    backgroundColor: cardBackgroundColor,
                    onTap: () => unawaited(_copyDisplayUserID()),
                  ),
                  if (_groupJoinMetaRecord != null &&
                      (widget.groupId?.trim().isNotEmpty ?? false))
                    GroupMemberJoinMetaSection(
                      groupId: widget.groupId!.trim(),
                      record: _groupJoinMetaRecord!,
                      titleColor: titleColor,
                      valueColor: valueColor,
                      linkColor: primaryColor,
                      backgroundColor: cardBackgroundColor,
                      dividerColor: dividerColor,
                      showTopDivider: true,
                    ),
                ],
              ),
            ),
          ),
          _buildAddFriendBottomBar(
            i18n: i18n,
            primaryColor: primaryColor,
            valueColor: valueColor,
            addButtonLabel: i18n.t(
              zhHans: '添加',
              zhHant: '添加',
              en: 'Add',
              ja: 'Add',
              ko: 'Add',
            ),
            buttonBorderRadius: 8,
            showButtonWhenBlocked: false,
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Provider.of<DefaultThemeData>(context).theme;
    const lightPageBackgroundColor = AppColors.lightBackground;
    const lightCardBackgroundColor = AppColors.lightCard;
    const lightTitleColor = AppColors.lightText;
    const lightValueColor = AppColors.lightSubText;
    const lightDividerColor = AppColors.lightLine;
    final appBarBaseColor =
        theme.appbarBgColor ?? theme.wideBackgroundColor ?? Colors.white;
    final isDarkBackground =
        ThemeData.estimateBrightnessForColor(appBarBaseColor) ==
            Brightness.dark;
    final pageBackgroundColor = isDarkBackground
        ? (theme.weakBackgroundColor ??
            theme.wideBackgroundColor ??
            const Color(0xFF0F0F0F))
        : lightPageBackgroundColor;
    final cardBackgroundColor = isDarkBackground
        ? (theme.conversationItemBgColor ??
            theme.wideBackgroundColor ??
            const Color(0xFF171717))
        : lightCardBackgroundColor;
    final titleColor = isDarkBackground
        ? (theme.darkTextColor ?? Colors.black)
        : lightTitleColor;
    final valueColor = isDarkBackground
        ? (theme.weakTextColor ?? const Color(0xFF999999))
        : lightValueColor;
    final dividerColor = isDarkBackground
        ? (theme.weakDividerColor ?? const Color(0xFFEDEDED))
        : lightDividerColor;
    final primaryColor = theme.primaryColor ?? const Color(0xFF1E90FF);
    final showName = _getShowName();

    return Consumer<PresenceProvider>(
      builder: (context, presence, _) {
        final i18n = AppI18n.of(context);
        final imOnline = _isImOnline();
        final presenceLoading = presence.isLastSeenLoading(
          userId: widget.userID,
          imOnline: imOnline,
        );
        final presenceTitle = _presenceTitle(presence, imOnline: imOnline);
        final body = Stack(
          fit: StackFit.expand,
          clipBehavior: Clip.none,
          children: [
            _loadingUserInfo
                ? const Center(child: CircularProgressIndicator())
                : _buildProfileBody(
                    i18n: i18n,
                    showName: showName,
                    presenceTitle: presenceTitle,
                    presenceLoading: presenceLoading,
                    imOnline: imOnline,
                    cardBackgroundColor: cardBackgroundColor,
                    titleColor: titleColor,
                    valueColor: valueColor,
                    dividerColor: dividerColor,
                    primaryColor: primaryColor,
                  ),
            if (!_loadingUserInfo && _shouldShowGameLedger())
              UserProfileGameLedgerFloatingEntry(
                theme: theme,
                onOpenLedger: _openGameLedger,
              ),
          ],
        );

        if (widget.embedded) {
          return Material(
            color: pageBackgroundColor,
            child: body,
          );
        }

        return Scaffold(
          resizeToAvoidBottomInset: false,
          backgroundColor: pageBackgroundColor,
          appBar: AppBar(
            leading: IconButton(
              onPressed: () => Navigator.of(context).pop(),
              icon: Icon(
                Icons.arrow_back_ios_new_rounded,
                color: primaryColor,
                size: 22,
              ),
            ),
            title: Text(
              i18n.t(
                zhHans: '详细资料',
                zhHant: '詳細資料',
                en: 'Profile',
                ja: 'Profile',
                ko: 'Profile',
              ),
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w600,
                color: titleColor,
              ),
            ),
            centerTitle: true,
            backgroundColor: theme.appbarBgColor ?? cardBackgroundColor,
            surfaceTintColor: Colors.transparent,
            elevation: 0,
            scrolledUnderElevation: 0,
            bottom: isDarkBackground
                ? null
                : PreferredSize(
                    preferredSize: const Size.fromHeight(0.5),
                    child: Container(
                      height: 0.5,
                      color: dividerColor,
                    ),
                  ),
          ),
          body: body,
        );
      },
    );
  }
}
