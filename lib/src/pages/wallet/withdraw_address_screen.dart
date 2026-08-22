import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:tencent_cloud_chat_demo/utils/toast.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:tencent_cloud_chat_demo/src/platform/clipboard_guard.dart';
import 'package:tencent_cloud_chat_demo/src/i18n/app_i18n.dart';
import 'package:tencent_cloud_chat_demo/src/utils/qr_scanner_launcher.dart';
import 'package:tencent_cloud_chat_demo/src/api/me_friend_api.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_friend_info.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_friend_info.dart';
import 'package:tencent_cloud_chat_demo/src/services/platform_official_account_service.dart';
import 'package:tencent_cloud_chat_uikit/ui/widgets/avatar.dart';

import 'wallet_repository.dart';
import 'wallet_repository_provider.dart';
import 'wallet_store.dart';
import 'widgets/wallet_my_wallet_icon.dart';
import 'widgets/wallet_page_colors.dart';
import 'withdraw_transfer_confirm_screen.dart';
import 'withdraw_transfer_target_validator.dart';
import 'package:tencent_cloud_chat_demo/src/navigation/app_page_transitions.dart';

enum _WithdrawTargetTab { wallet, friends }

class WithdrawAddressScreen extends StatefulWidget {
  final CoinDto coin;
  final WalletPayMethodDto payMethod;

  const WithdrawAddressScreen({
    super.key,
    required this.coin,
    required this.payMethod,
  });

  @override
  State<WithdrawAddressScreen> createState() => _WithdrawAddressScreenState();
}

class _WithdrawAddressScreenState extends State<WithdrawAddressScreen> {
  final TextEditingController _addrCtrl = TextEditingController();
  final TextEditingController _searchCtrl = TextEditingController();
  final FocusNode _addrFocus = FocusNode();
  List<V2TimFriendInfo> _friends = const [];
  bool _friendsLoading = true;
  _WithdrawTargetTab _activeTab = _WithdrawTargetTab.friends;
  String _walletAddress = '';
  bool _walletLoading = true;
  V2TimFriendInfo? _selectedFriend;

  @override
  void initState() {
    super.initState();
    _loadFriends();
    _loadWalletAddress();
  }

  @override
  void dispose() {
    _addrCtrl.dispose();
    _searchCtrl.dispose();
    _addrFocus.dispose();
    super.dispose();
  }

  bool get _canNext {
    return _addrCtrl.text.trim().isNotEmpty && _addressError == null;
  }

  WithdrawTransferTarget? get _resolvedTransferTarget {
    return WithdrawTransferTargetValidator.resolve(
      raw: _addrCtrl.text,
      isBlockedUserId: _isBlockedFriendUserId,
      resolveFriendUserId: _resolveFriendUserId,
    );
  }

  String? _invalidTargetMessage(AppI18n i18n) {
    return i18n.t(
      zhHans: '请输入有效的 TRON 地址或 99Chat 号/昵称',
      zhHant: '請輸入有效的 TRON 地址或 99Chat 號/暱稱',
      en: 'Enter a valid TRON address or 99Chat ID/nickname.',
      ja: '有効な TRON アドレスまたは 99Chat ID/ニックネームを入力してください。',
      ko: '유효한 TRON 주소 또는 99Chat ID/닉네임을 입력하세요.',
    );
  }

  bool get _isSameAsWalletAddress {
    final target = _resolvedTransferTarget;
    if (target == null || target.isFriend) return false;
    final walletAddress = WithdrawTransferTargetValidator.normalizePlainText(
      _walletAddress,
    );
    if (walletAddress.isEmpty) return false;
    return target.value == walletAddress;
  }

  String? get _addressError {
    final i18n = AppI18n.current;
    final raw = _addrCtrl.text;
    if (WithdrawTransferTargetValidator.normalizePlainText(raw).isEmpty) {
      return null;
    }
    if (_resolvedTransferTarget == null) {
      return _invalidTargetMessage(i18n);
    }
    if (_isSameAsWalletAddress) {
      return i18n.t(
        zhHans: '提现地址不能和转出地址相同',
        zhHant: '提現地址不能和轉出地址相同',
        en: 'The withdrawal address cannot be the same as the sending address.',
        ja: '出金先アドレスは送金元アドレスと同じにできません。',
        ko: '출금 주소는 보내는 주소와 같을 수 없습니다.',
      );
    }
    return null;
  }

  String _displayName(V2TimFriendInfo item) {
    final remark = item.friendRemark?.trim() ?? '';
    if (remark.isNotEmpty) return remark;
    final nick = item.userProfile?.nickName?.trim() ?? '';
    if (nick.isNotEmpty) return nick;
    return item.userID;
  }

  bool _isSelectableFriend(V2TimFriendInfo item) {
    return !PlatformOfficialAccountService.shouldHideFromContactAndPickers(
      item.userID,
    );
  }

  bool _isBlockedFriendUserId(String? userId) {
    return PlatformOfficialAccountService.shouldHideFromContactAndPickers(userId);
  }

  Future<void> _loadFriends() async {
    try {
      final list = (await MeFriendApi.instance.loadFriendsForPickers())
          .where((item) => item.userID.trim().isNotEmpty)
          .toList()
        ..sort((a, b) => _displayName(a).compareTo(_displayName(b)));
      if (!mounted) return;
      setState(() {
        _friends = list;
        _friendsLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _friends = const [];
        _friendsLoading = false;
      });
    }
  }

  Future<void> _loadWalletAddress() async {
    try {
      final wallet = await WalletStore.instance.getWallet(
        repo: createWalletRepository(),
      );
      if (!mounted) return;
      setState(() {
        _walletAddress = wallet.trxAddr.trim();
        _walletLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _walletAddress = '';
        _walletLoading = false;
      });
    }
  }

  bool _matchesFriend(V2TimFriendInfo item, String keyword) {
    if (keyword.isEmpty) return true;
    final k = keyword.toLowerCase();
    final displayName = _displayName(item).toLowerCase();
    final userId = item.userID.toLowerCase();
    return displayName.contains(k) || userId.contains(k);
  }

  V2TimFriendInfo? _findFriendByUserId(String value) {
    final userId = WithdrawTransferTargetValidator.normalizeChatUserId(value) ??
        WithdrawTransferTargetValidator.normalizePlainText(value);
    if (userId.isEmpty || _isBlockedFriendUserId(userId)) return null;
    for (final item in _friends) {
      if (item.userID.trim() == userId) {
        return _isSelectableFriend(item) ? item : null;
      }
    }
    return null;
  }

  V2TimFriendInfo? _findFriendByTarget(String value) {
    final normalized =
        WithdrawTransferTargetValidator.normalizePlainText(value);
    if (normalized.isEmpty) return null;

    final byId = _findFriendByUserId(normalized);
    if (byId != null) return byId;

    final lower = normalized.toLowerCase();
    V2TimFriendInfo? match;
    for (final item in _friends) {
      if (!_isSelectableFriend(item)) continue;
      if (_displayName(item).toLowerCase() == lower) {
        if (match != null) return null;
        match = item;
      }
    }
    return match;
  }

  String? _resolveFriendUserId(String value) {
    return _findFriendByTarget(value)?.userID.trim();
  }

  void _handleAddressChanged(String value) {
    final text = WithdrawTransferTargetValidator.normalizePlainText(value);
    setState(() {
      _selectedFriend = _findFriendByTarget(text);
    });
  }

  void _fillAddress(String value, {V2TimFriendInfo? friend}) {
    final text = WithdrawTransferTargetValidator.normalizedTargetValue(value);
    if (text.isEmpty) return;
    if (_isBlockedFriendUserId(text)) {
      return;
    }
    if (friend != null && !_isSelectableFriend(friend)) {
      return;
    }
    _addrCtrl.text = text;
    _addrCtrl.selection = TextSelection.fromPosition(
      TextPosition(offset: text.length),
    );
    setState(() {
      _selectedFriend = friend ?? _findFriendByTarget(text);
    });
  }

  void _showToast(String text) {
    ToastUtils.toast(text);
  }

  Future<void> _openNext() async {
    final i18n = AppI18n.of(context);
    final target = _resolvedTransferTarget;
    if (target == null) {
      _showToast(_invalidTargetMessage(i18n) ?? '');
      return;
    }
    if (target.isFriend && _isBlockedFriendUserId(target.value)) {
      _showToast(
        i18n.t(
          zhHans: '暂不支持向该用户转账',
          zhHant: '暫不支援向該用戶轉帳',
          en: 'Transfers to this user are not supported.',
          ja: 'このユーザーへの送金はサポートされていません。',
          ko: '해당 사용자에게 송금할 수 없습니다.',
        ),
      );
      return;
    }
    final error = _addressError;
    if (error != null) {
      _showToast(error);
      return;
    }

    final friend = _selectedFriend ?? _findFriendByTarget(_addrCtrl.text);
    final mode = target.isFriend
        ? WithdrawTransferMode.friend
        : WithdrawTransferMode.chain;
    final address = target.value;

    await Navigator.of(context).push<void>(
      AppMaterialPageRoute(
        builder: (_) => WithdrawTransferConfirmScreen(
          mode: mode,
          coin: widget.coin,
          payMethod: widget.payMethod,
          targetValue: address,
          targetName: friend == null ? null : _displayName(friend),
          targetAvatar: friend?.userProfile?.faceUrl?.trim(),
        ),
      ),
    );
  }

  void _selectTab(_WithdrawTargetTab tab) {
    if (_activeTab == tab) return;
    setState(() {
      _activeTab = tab;
    });
  }

  Future<void> _openScanner() async {
    final scannedAddress = await QRScannerLauncher.open<String>(
      context,
      walletAddressMode: true,
    );
    if (!mounted || scannedAddress == null || scannedAddress.trim().isEmpty) {
      return;
    }
    final addr = scannedAddress.trim();
    _addrCtrl.text = addr;
    _addrCtrl.selection = TextSelection.fromPosition(
      TextPosition(offset: addr.length),
    );
    FocusScope.of(context).requestFocus(_addrFocus);
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final i18n = AppI18n.of(context);
    final cs = WalletPageColors.of(context);
    final appBar = WalletAppBarColors.of(context);

    return wrapWalletPage(
      context,
      Scaffold(
      backgroundColor: cs.dark ? cs.bg : Colors.white,
      appBar: AppBar(
        centerTitle: true,
        elevation: 0,
        shadowColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        backgroundColor: appBar.background,
        foregroundColor: appBar.title,
        systemOverlayStyle: walletPageOverlayStyle(context),
        title: Text(
          i18n.t(
            zhHans: '收款地址',
            zhHant: '收款地址',
            en: 'Receiving Address',
            ja: '受取アドレス',
            ko: '수령 주소',
          ),
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w600,
            color: appBar.title,
          ),
        ),
      ),
      body: SafeArea(
        top: false,
        child: GestureDetector(
          behavior: HitTestBehavior.translucent,
          onTap: () => FocusScope.of(context).unfocus(),
          child: Column(
            children: [
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
                  children: [
                    Container(
                      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                      decoration: BoxDecoration(
                        color: cs.inputFill,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: cs.line),
                      ),
                      child: SizedBox(
                        height: 56,
                        child: TextField(
                        controller: _addrCtrl,
                        focusNode: _addrFocus,
                        maxLines: 1,
                        keyboardType: TextInputType.text,
                        textInputAction: TextInputAction.done,
                        enableSuggestions: false,
                        autocorrect: false,
                        smartDashesType: SmartDashesType.disabled,
                        smartQuotesType: SmartQuotesType.disabled,
                        inputFormatters: [
                          FilteringTextInputFormatter.deny(RegExp(r'[\r\n]')),
                        ],
                        cursorColor: cs.inputCursor,
                        onChanged: _handleAddressChanged,
                        style: TextStyle(
                          fontSize: 16,
                          color: cs.text,
                          fontWeight: FontWeight.w500,
                          height: 1.4,
                        ),
                        decoration: InputDecoration(
                          filled: false,
                          fillColor: Colors.transparent,
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          isCollapsed: true,
                          contentPadding: EdgeInsets.zero,
                          hintText: i18n.t(
                            zhHans: '请输入接收转账钱包地址/99Chat号',
                            zhHant: '請輸入接收轉帳錢包地址/99Chat號',
                            en: 'Enter wallet address or 99Chat ID',
                            ja: '受取ウォレットアドレス/99Chat IDを入力',
                            ko: '수령 지갑 주소/99Chat ID 입력',
                          ),
                          hintStyle: TextStyle(
                            fontSize: 16,
                            color: cs.inputHint,
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                      ),
                      ),
                    ),
                    if (_addressError != null) ...[
                      const SizedBox(height: 8),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          _addressError!,
                          style: TextStyle(
                            fontSize: 13,
                            color: cs.red,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        if (!kIsWeb) ...[
                          Expanded(
                            child: _AddressAction(
                              icon: SvgPicture.string(
                                _scanActionSvg(cs.text, cs.blue),
                                width: 16,
                                height: 16,
                              ),
                              label: i18n.t(
                                zhHans: '扫一扫',
                                zhHant: '掃一掃',
                                en: 'Scan',
                                ja: 'スキャン',
                                ko: '스캔',
                              ),
                              onTap: _openScanner,
                            ),
                          ),
                          const SizedBox(width: 14),
                        ],
                        Expanded(
                          child: _AddressAction(
                            icon: Icon(
                              Icons.content_copy_rounded,
                              size: 16,
                              color: cs.text,
                            ),
                            label: i18n.t(
                              zhHans: '粘贴',
                              zhHant: '貼上',
                              en: 'Paste',
                              ja: '貼り付け',
                              ko: '붙여넣기',
                            ),
                            onTap: () async {
                              final text = await ClipboardGuard.readText();
                              if (text.isEmpty) return;
                              _fillAddress(text);
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 26),
                    _AddressTabs(
                      activeTab: _activeTab,
                      onSelectWallet: () => _selectTab(_WithdrawTargetTab.wallet),
                      onSelectFriends: () => _selectTab(_WithdrawTargetTab.friends),
                    ),
                    const SizedBox(height: 18),
                    if (_activeTab == _WithdrawTargetTab.friends) ...[
                      _AddressSearchField(
                        controller: _searchCtrl,
                        onChanged: (_) => setState(() {}),
                      ),
                      const SizedBox(height: 12),
                      Divider(height: 1, color: cs.line),
                      const SizedBox(height: 8),
                      ..._buildFriendItems(cs, i18n),
                    ] else ...[
                      Divider(height: 1, color: cs.line),
                      const SizedBox(height: 8),
                      ..._buildWalletItems(cs, i18n),
                    ],
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: cs.dark ? Colors.transparent : Colors.white,
                    border: cs.dark
                        ? null
                        : Border(
                            top: BorderSide(color: cs.line),
                          ),
                  ),
                  child: Padding(
                    padding: EdgeInsets.only(top: cs.dark ? 0 : 12),
                    child: SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: _canNext ? _openNext : null,
                    style: ElevatedButton.styleFrom(
                      elevation: 0,
                      backgroundColor: cs.blue,
                      disabledBackgroundColor: cs.dark
                          ? cs.disabledButton
                          : cs.blue.withValues(alpha: 0.32),
                      foregroundColor: Colors.white,
                      disabledForegroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: Text(
                      i18n.t(
                        zhHans: '下一步',
                        zhHant: '下一步',
                        en: 'Next',
                        ja: '次へ',
                        ko: '다음',
                      ),
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
    );
  }

  List<Widget> _buildFriendItems(WalletPageColors cs, AppI18n i18n) {
    if (_friendsLoading) {
      return const [
        Padding(
          padding: EdgeInsets.symmetric(vertical: 24),
          child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
        ),
      ];
    }
    final keyword = _searchCtrl.text.trim();
    final list = _friends
        .where(_isSelectableFriend)
        .where((item) => _matchesFriend(item, keyword))
        .toList(growable: false);
    if (list.isEmpty) {
      return [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 24),
          child: Center(
            child: Text(
              keyword.isEmpty
                  ? i18n.t(
                      zhHans: '暂无好友',
                      zhHant: '暫無好友',
                      en: 'No friends yet',
                      ja: '友達がいません',
                      ko: '친구가 없습니다',
                    )
                  : i18n.t(
                      zhHans: '未找到相关联系人',
                      zhHant: '未找到相關聯絡人',
                      en: 'No matching contacts',
                      ja: '該当する連絡先が見つかりません',
                      ko: '관련 연락처를 찾을 수 없습니다',
                    ),
              style: TextStyle(
                fontSize: 14,
                color: cs.subText,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ),
      ];
    }
    return list.asMap().entries.map((entry) {
      final index = entry.key;
      final item = entry.value;
      final avatar = item.userProfile?.faceUrl?.trim() ?? '';
      final userId = item.userID.trim();
      final displayName = _displayName(item);
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (index > 0) Divider(height: 1, indent: 52, color: cs.line),
          InkWell(
            onTap: () => _fillAddress(userId, friend: item),
            borderRadius: BorderRadius.circular(10),
            child: SizedBox(
              height: 60,
              child: Row(
                children: [
                  SizedBox(
                    width: 42,
                    height: 42,
                    child: Avatar(
                      faceUrl: avatar,
                      showName: displayName,
                      borderRadius: BorderRadius.circular(24),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          displayName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 15,
                            color: cs.text,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          userId,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 13,
                            color: cs.subText,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      );
    }).toList(growable: false);
  }

  List<Widget> _buildWalletItems(WalletPageColors cs, AppI18n i18n) {
    if (_walletLoading) {
      return const [
        Padding(
          padding: EdgeInsets.symmetric(vertical: 24),
          child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
        ),
      ];
    }
    if (_walletAddress.isEmpty) {
      return [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 24),
          child: Center(
            child: Text(
              i18n.t(
                zhHans: '暂无钱包地址',
                zhHant: '暫無錢包地址',
                en: 'No wallet address yet',
                ja: 'ウォレットアドレスがありません',
                ko: '지갑 주소가 없습니다',
              ),
              style: TextStyle(
                fontSize: 14,
                color: cs.subText,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ),
      ];
    }
    return [
      InkWell(
        onTap: () => _fillAddress(_walletAddress),
        borderRadius: BorderRadius.circular(10),
        child: Container(
          height: 60,
          margin: const EdgeInsets.only(bottom: 8),
          child: Row(
            children: [
              const WalletMyWalletIcon(size: 42),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      i18n.t(
                        zhHans: '我的钱包',
                        zhHant: '我的錢包',
                        en: 'My Wallet',
                        ja: 'マイウォレット',
                        ko: '내 지갑',
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 15,
                        color: cs.text,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _walletAddress,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13,
                        color: cs.subText,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    ];
  }
}

class _AddressAction extends StatelessWidget {
  final Widget icon;
  final String label;
  final VoidCallback onTap;

  const _AddressAction({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = WalletPageColors.of(context);
    final borderColor = cs.dark ? cs.line : const Color(0xFFDDE1E6);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        height: 44,
        decoration: BoxDecoration(
          color: cs.card,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: borderColor),
          boxShadow: cs.dark
              ? null
              : [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            icon,
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                color: cs.text,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String _scanActionSvg(Color frameColor, Color accentColor) {
  final frame = _colorToHex(frameColor);
  final accent = _colorToHex(accentColor);
  return '<svg viewBox="0 0 1024 1024" xmlns="http://www.w3.org/2000/svg">'
      '<path d="M853.333333 938.666667h-128v-64h128a21.333333 21.333333 0 0 0 21.333334-21.333334v-138.666666a32 32 0 0 1 64 0V853.333333a85.333333 85.333333 0 0 1-85.333334 85.333334z m53.333334-597.333334a32 32 0 0 1-32-32V170.666667a21.333333 21.333333 0 0 0-21.333334-21.333334h-138.666666a32 32 0 0 1 0-64H853.333333a85.333333 85.333333 0 0 1 85.333334 85.333334v138.666666a32 32 0 0 1-32 32z m-597.333334-192H170.666667a21.333333 21.333333 0 0 0-21.333334 21.333334v138.666666a32 32 0 1 1-64 0V170.666667a85.333333 85.333333 0 0 1 85.333334-85.333334h138.666666a32 32 0 0 1 0 64z m-192 533.333334A32 32 0 0 1 149.333333 714.666667V853.333333a21.333333 21.333333 0 0 0 21.333334 21.333334h128v64H170.666667a85.333333 85.333333 0 0 1-85.333334-85.333334v-138.666666A32 32 0 0 1 117.333333 682.666667z" fill="$frame"/>'
      '<path d="M213.333333 480m32 0l533.333334 0q32 0 32 32l0 0q0 32-32 32l-533.333334 0q-32 0-32-32l0 0q0-32 32-32Z" fill="$accent"/>'
      '</svg>';
}

String _colorToHex(Color color) {
  final hex = color.value.toRadixString(16).padLeft(8, '0');
  return '#${hex.substring(2)}';
}

class _AddressSearchField extends StatelessWidget {
  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  const _AddressSearchField({
    required this.controller,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final i18n = AppI18n.of(context);
    final cs = WalletPageColors.of(context);
    return Container(
      height: 44,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: cs.inputFill,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: cs.line),
      ),
      child: Row(
        children: [
          Icon(Icons.search_rounded, color: cs.inputHint, size: 22),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: controller,
              cursorColor: cs.inputCursor,
              textInputAction: TextInputAction.search,
              onChanged: onChanged,
              decoration: InputDecoration(
                filled: false,
                fillColor: Colors.transparent,
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                isCollapsed: true,
                hintText: i18n.t(
                  zhHans: '搜索联系人',
                  zhHant: '搜尋聯絡人',
                  en: 'Search contacts',
                  ja: '連絡先を検索',
                  ko: '연락처 검색',
                ),
                hintStyle: TextStyle(
                  color: cs.inputHint,
                  fontSize: 15,
                ),
              ),
              style: TextStyle(color: cs.text, fontSize: 15),
            ),
          ),
        ],
      ),
    );
  }
}

class _AddressTabs extends StatelessWidget {
  final _WithdrawTargetTab activeTab;
  final VoidCallback onSelectWallet;
  final VoidCallback onSelectFriends;

  const _AddressTabs({
    required this.activeTab,
    required this.onSelectWallet,
    required this.onSelectFriends,
  });

  @override
  Widget build(BuildContext context) {
    final i18n = AppI18n.of(context);
    final cs = WalletPageColors.of(context);
    final selectedColor =
        cs.dark ? cs.filterActiveText : cs.blue;
    final inactiveColor = cs.dark
        ? const Color(0xFFADB0B8)
        : const Color(0xFF8E9399);
    final indicatorColor = cs.dark ? cs.inputCursor : cs.blue;

    return Row(
      mainAxisAlignment: MainAxisAlignment.start,
      children: [
        _AddressTabItem(
          label: i18n.t(
            zhHans: '我的钱包',
            zhHant: '我的錢包',
            en: 'My Wallet',
            ja: 'マイウォレット',
            ko: '내 지갑',
          ),
          selected: activeTab == _WithdrawTargetTab.wallet,
          accent: indicatorColor,
          selectedColor: selectedColor,
          inactiveColor: inactiveColor,
          onTap: onSelectWallet,
        ),
        const SizedBox(width: 28),
        _AddressTabItem(
          label: i18n.t(
            zhHans: '我的好友',
            zhHant: '我的好友',
            en: 'My Friends',
            ja: 'マイ友達',
            ko: '내 친구',
          ),
          selected: activeTab == _WithdrawTargetTab.friends,
          accent: indicatorColor,
          selectedColor: selectedColor,
          inactiveColor: inactiveColor,
          onTap: onSelectFriends,
        ),
      ],
    );
  }
}

class _AddressTabItem extends StatelessWidget {
  final String label;
  final bool selected;
  final Color accent;
  final Color selectedColor;
  final Color inactiveColor;
  final VoidCallback onTap;

  const _AddressTabItem({
    required this.label,
    required this.selected,
    required this.accent,
    required this.selectedColor,
    required this.inactiveColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 16,
              color: selected ? selectedColor : inactiveColor,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            height: 3,
            width: selected ? 28 : 0,
            decoration: BoxDecoration(
              color: accent,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ],
      ),
    );
  }
}
