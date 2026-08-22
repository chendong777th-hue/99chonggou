import 'dart:async';

import 'package:flutter/material.dart';
import 'package:tencent_cloud_chat_demo/src/ui/utils/adaptive_modal.dart';
import 'package:tencent_cloud_chat_demo/utils/group_privacy_guard.dart';
import 'package:tencent_cloud_chat_demo/utils/toast.dart';
import 'package:flutter/services.dart';
import 'package:tencent_cloud_chat_demo/src/i18n/app_i18n.dart';

import 'order/wallet_order.dart';
import 'red_packet/red_packet_member_picker_page.dart';
import 'transfer_controller.dart';
import 'wallet_pay_pin_guard.dart';
import 'wallet_repository.dart';
import 'pay_auth_helper.dart';
import 'widgets/biometric_pay_enable_prompt.dart';
import 'widgets/pay_loading_overlay.dart';
import 'widgets/pay_method_sheet.dart';
import 'widgets/pay_success_main.dart';
import 'widgets/wallet_amount_input.dart';
import 'widgets/wallet_page_colors.dart';

class WalletTransferScreen extends StatefulWidget {
  final String name;
  final String qq;
  final String? avatar;
  final String receiverId;
  final String conversationId;
  /// 群聊时为选人转账页；提交走红包 `GROUP_TRANSFER`，不再调用 `/wallet/transfer`。
  final bool isGroup;

  const WalletTransferScreen({
    super.key,
    this.name = '',
    this.qq = '',
    this.avatar,
    this.receiverId = '',
    this.conversationId = '',
    this.isGroup = false,
  });

  @override
  State<WalletTransferScreen> createState() => _WalletTransferScreenState();
}

class _WalletTransferScreenState extends State<WalletTransferScreen> {
  late final TransferController ctl;
  final TextEditingController amtCtrl = TextEditingController();
  final TextEditingController memoCtrl = TextEditingController();
  final FocusNode amtFocus = FocusNode();
  final FocusNode memoFocus = FocusNode();
  bool _sheetOpen = false;
  /// 群隐私保护开启时不展示收款人 99Chat ID。
  bool _hideReceiverUserId = false;

  @override
  void initState() {
    super.initState();
    ctl = TransferController();
    ctl.setReceiver(
      userId: widget.isGroup ? '' : widget.receiverId,
      name: widget.isGroup ? '' : widget.name,
      avatarUrl: widget.avatar ?? '',
      convId: widget.conversationId,
      group: widget.isGroup,
    );
    ctl.loadPayMethods();
    if (widget.isGroup) {
      unawaited(_loadGroupPrivacy());
    }

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final ok = await WalletPayPinGuard.ensureSet(context);
      if (!ok && mounted) {
        Navigator.of(context).pop();
      }
    });

    amtCtrl.addListener(() => ctl.setAmt(amtCtrl.text));
    memoCtrl.addListener(_onMemoChanged);
  }

  Future<void> _loadGroupPrivacy() async {
    final groupId = widget.conversationId.trim();
    if (groupId.isEmpty) {
      return;
    }
    final enabled = await GroupPrivacyCache.privacyProtectionEnabled(groupId);
    if (!mounted) {
      return;
    }
    if (_hideReceiverUserId == enabled) {
      return;
    }
    setState(() {
      _hideReceiverUserId = enabled;
    });
  }

  void _onMemoChanged() {
    final before = memoCtrl.text;
    ctl.setMemo(before);
    if (ctl.memo != before) {
      memoCtrl.value = TextEditingValue(
        text: ctl.memo,
        selection: TextSelection.collapsed(offset: ctl.memo.length),
      );
    }
  }

  @override
  void dispose() {
    amtCtrl.dispose();
    memoCtrl.dispose();
    amtFocus.dispose();
    memoFocus.dispose();
    ctl.dispose();
    super.dispose();
  }

  void _msg(String text) {
    ToastUtils.toast(text);
  }

  /// 支付弹窗内点击「更改」：切换 99币 / USDT 后回传最新展示数据，
  /// 让支付弹窗原地刷新（不关闭密码弹窗）。
  Future<PayMethodDisplay?> _changePayInline() async {
    final item = await showAdaptiveModalSheet<WalletPayMethodDto>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.58),
      builder: (_) => WalletPayMethodSheet(items: ctl.items, sel: ctl.sel),
    );
    if (!mounted || item == null) return null;
    ctl.select(item);
    return PayMethodDisplay(
      amountText: '${ctl.amountDisplayText} ${ctl.sel.coin}',
      amountCoin: ctl.sel.coin,
      payText: '${ctl.sel.coin} ${ctl.sel.net}',
      payCoinCode: ctl.sel.id,
      payLogoUrl: ctl.sel.logoUrl,
      walletSubtitle: '${ctl.sel.bal} ${ctl.sel.coin}',
    );
  }

  Future<void> _choosePay() async {
    if (_sheetOpen || ctl.isBusy) return;
    _sheetOpen = true;
    try {
      final item = await showAdaptiveModalSheet<WalletPayMethodDto>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        barrierColor: Colors.black.withValues(alpha: 0.58),
        builder: (_) => WalletPayMethodSheet(items: ctl.items, sel: ctl.sel),
      );
      if (!mounted || item == null) return;
      ctl.select(item);
    } catch (_) {
      _msg(AppI18n.of(context).t(
        zhHans: '付款方式加载失败',
        zhHant: '付款方式載入失敗',
        en: 'Failed to load payment methods.',
        ja: '支払い方法の読み込みに失敗しました。',
        ko: '결제 수단을 불러오지 못했습니다.',
      ));
    } finally {
      if (mounted) _sheetOpen = false;
    }
  }

  Future<void> _chooseReceiver() async {
    if (!ctl.isGroup || _sheetOpen || ctl.isBusy) return;
    _sheetOpen = true;
    try {
      if (!mounted) return;
      final members = await ctl.loadMembers(excludeSelf: true);
      if (!mounted) return;

      if (members.isEmpty) {
        _msg(AppI18n.of(context).t(
          zhHans: '暂无可选择成员',
          zhHant: '暫無可選擇成員',
          en: 'No members available to select.',
          ja: '選択できるメンバーがいません。',
          ko: '선택할 수 있는 멤버가 없습니다.',
        ));
        return;
      }

      // 与专属红包同一选人全页（RedPacketMemberPickerPage）。
      final ret = await pickRedPacketMember(
        context,
        members: members,
        hideMemberIds: _hideReceiverUserId,
      );
      if (!mounted || ret == null) return;
      ctl.setReceiver(
        userId: ret.userId,
        name: ret.name,
        avatarUrl: ret.avatar,
        convId: ctl.conversationId,
        group: true,
      );
    } catch (_) {
      _msg(AppI18n.of(context).t(
        zhHans: '成员加载失败，请重试',
        zhHant: '成員載入失敗，請重試',
        en: 'Failed to load members. Please try again.',
        ja: 'メンバーの読み込みに失敗しました。もう一度お試しください。',
        ko: '멤버를 불러오지 못했습니다. 다시 시도해 주세요.',
      ));
    } finally {
      if (mounted) _sheetOpen = false;
    }
  }

  Future<void> _confirm() async {
    if (_sheetOpen || ctl.isBusy) return;

    final msg = ctl.check();
    if (msg != null) {
      _msg(msg);
      return;
    }

    FocusManager.instance.primaryFocus?.unfocus();
    _sheetOpen = true;
    try {
      await PayLoadingOverlay.runBeforePayPrompt(
        context,
        prepare: () async {
          ctl.startOrder();
        },
      );
      if (!mounted) return;
      final auth = await PayAuthHelper.collectAndSubmit(
        context: context,
        title: AppI18n.of(context).t(
          zhHans: ctl.isGroup ? '群转账' : '转账',
          zhHant: ctl.isGroup ? '群轉帳' : '轉帳',
          en: ctl.isGroup ? 'Group Transfer' : 'Transfer',
          ja: ctl.isGroup ? 'グループ送金' : '送金',
          ko: ctl.isGroup ? '그룹 이체' : '이체',
        ),
        amountText: '${ctl.amountDisplayText} ${ctl.sel.coin}',
        amountCoin: ctl.sel.coin,
        payText: '${ctl.sel.coin} ${ctl.sel.net}',
        payCoinCode: ctl.sel.id,
        payLogoUrl: ctl.sel.logoUrl,
        onChangePayMethod: _changePayInline,
        receiverName: ctl.toName,
        receiverId: _hideReceiverUserId
            ? null
            : (widget.qq.isNotEmpty ? widget.qq : ctl.toUserId),
        receiverAvatar: ctl.avatar.isEmpty ? widget.avatar : ctl.avatar,
        walletSubtitle: '${ctl.sel.bal} ${ctl.sel.coin}',
        onSubmit: ctl.submit,
      );
      if (!mounted) return;
      if (auth.success) {
        if (ctl.state == WalletOrderState.success ||
            ctl.state == WalletOrderState.accepted ||
            ctl.state == WalletOrderState.pending ||
            ctl.state == WalletOrderState.unknown) {
          await PaySuccessOverlay.showFor(
            context,
            title: AppI18n.of(context).t(
              zhHans: '支付成功',
              zhHant: '支付成功',
              en: 'Payment successful',
              ja: '支払いが完了しました',
              ko: '결제가 완료되었습니다',
            ),
            message: AppI18n.of(context).t(
              zhHans: '转账已完成',
              zhHant: '轉帳已完成',
              en: 'Transfer completed',
              ja: '送金が完了しました',
              ko: '이체가 완료되었습니다',
            ),
          );
          if (!mounted) return;
          await BiometricPayEnablePrompt.maybeShowAfterPaySuccess(
            context,
            authMethod: auth.method ?? PayAuthMethod.manual,
            verifiedPayPin: auth.verifiedPayPin,
          );
          if (!mounted) return;
          Navigator.of(context).pop(true);
          return;
        }
      } else {
        ctl.cancelOrderIfIdle();
      }
    } finally {
      if (mounted) _sheetOpen = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: ctl,
      builder: (_, __) {
        final cs = WalletPageColors.of(context);
        final appBar = WalletAppBarColors.of(context);
        final receiverName = ctl.toName.isEmpty
            ? (ctl.isGroup
                ? AppI18n.of(context).t(
                    zhHans: '请选择收款人',
                    zhHant: '請選擇收款人',
                    en: 'Select a recipient',
                    ja: '受取人を選択',
                    ko: '수취인 선택',
                  )
                : widget.name)
            : ctl.toName;
        final scale = _mobileScale(context);

        return wrapWalletPage(
          context,
          Scaffold(
          backgroundColor: cs.bg,
          resizeToAvoidBottomInset: true,
          body: GestureDetector(
            behavior: HitTestBehavior.translucent,
            onTap: () => FocusScope.of(context).unfocus(),
            child: SafeArea(
              bottom: false,
              child: Column(
                children: [
                  SizedBox(
                    height: 52 * scale,
                    child: Row(
                      children: [
                        SizedBox(width: 4 * scale),
                        IconButton(
                          onPressed: () => Navigator.of(context).maybePop(),
                          icon: Icon(
                            Icons.arrow_back_ios_new_rounded,
                            color: appBar.icon,
                            size: 19 * scale,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Stack(
                      children: [
                        ListView(
                          padding: EdgeInsets.fromLTRB(0, 18 * scale, 0, 120 * scale),
                          children: [
                            _ReceiverBox(
                              cs: cs,
                              scale: scale,
                              name: receiverName,
                              qq: ctl.toUserId.isNotEmpty
                                  ? ctl.toUserId
                                  : widget.receiverId,
                              avatar: ctl.avatar.isEmpty
                                  ? widget.avatar
                                  : ctl.avatar,
                              hideUserId: _hideReceiverUserId,
                              enabled: ctl.isGroup,
                              onTap: _chooseReceiver,
                            ),
                            SizedBox(height: 18 * scale),
                            _TransferBody(
                              cs: cs,
                              scale: scale,
                              ctl: ctl,
                              amtCtrl: amtCtrl,
                              memoCtrl: memoCtrl,
                              amtFocus: amtFocus,
                              memoFocus: memoFocus,
                              onChoosePay: _choosePay,
                            ),
                          ],
                        ),
                        Positioned(
                          left: 0,
                          right: 0,
                          bottom: 24 * scale,
                          child: Center(
                            child: _ConfirmBtn(
                              cs: cs,
                              scale: scale,
                              onTap: _confirm,
                              enabled: ctl.canConfirm && !_sheetOpen,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        );
      },
    );
  }
}

class _ReceiverBox extends StatelessWidget {
  final WalletPageColors cs;
  final double scale;
  final String name;
  final String qq;
  final String? avatar;
  final bool hideUserId;
  final bool enabled;
  final VoidCallback? onTap;

  const _ReceiverBox({
    required this.cs,
    required this.scale,
    required this.name,
    required this.qq,
    this.avatar,
    this.hideUserId = false,
    this.enabled = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final i18n = AppI18n.of(context);
    final hasName = name.trim().isNotEmpty;
    final title = hasName
        ? i18n.format(
            zhHans: '转账给 {name}',
            zhHant: '轉帳給 {name}',
            en: 'Transfer to {name}',
            ja: '{name} へ送金',
            ko: '{name}님에게 이체',
            vars: {'name': name},
          )
        : i18n.t(
            zhHans: '请选择收款人',
            zhHant: '請選擇收款人',
            en: 'Select a recipient',
            ja: '受取人を選択',
            ko: '수취인 선택',
          );
    final showIdLine = !hideUserId;
    final sub = qq.trim().isNotEmpty
        ? i18n.format(
            zhHans: '99Chat ID号：{id}',
            zhHant: '99Chat ID號：{id}',
            en: '99Chat ID: {id}',
            ja: '99Chat ID: {id}',
            ko: '99Chat ID: {id}',
            vars: {'id': qq.trim()},
          )
        : i18n.t(
            zhHans: '99Chat ID号：--',
            zhHant: '99Chat ID號：--',
            en: '99Chat ID: --',
            ja: '99Chat ID: --',
            ko: '99Chat ID: --',
          );

    return InkWell(
      onTap: enabled ? onTap : null,
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 24 * scale),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 16 * scale,
                      fontWeight: FontWeight.w700,
                      color: cs.text,
                    ),
                  ),
                  if (showIdLine) ...[
                    SizedBox(height: 4 * scale),
                    Text(
                      sub,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 14 * scale,
                        color: cs.subText,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            SizedBox(width: 12 * scale),
            ClipRRect(
              borderRadius: BorderRadius.circular(28 * scale),
              child: Container(
                width: 56 * scale,
                height: 56 * scale,
                color: cs.avatarPlaceholder,
                child: avatar == null || avatar!.isEmpty
                    ? Icon(Icons.person_rounded, size: 26 * scale, color: cs.avatarIcon)
                    : Image.network(
                        avatar!,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Icon(
                          Icons.person_rounded,
                          size: 26 * scale,
                          color: cs.avatarIcon,
                        ),
                      ),
              ),
            ),
            if (enabled) ...[
              SizedBox(width: 6 * scale),
              Icon(Icons.chevron_right_rounded, size: 22 * scale, color: cs.subText),
            ],
          ],
        ),
      ),
    );
  }
}

class _TransferBody extends StatelessWidget {
  final WalletPageColors cs;
  final double scale;
  final TransferController ctl;
  final TextEditingController amtCtrl;
  final TextEditingController memoCtrl;
  final FocusNode amtFocus;
  final FocusNode memoFocus;
  final VoidCallback onChoosePay;

  const _TransferBody({
    required this.cs,
    required this.scale,
    required this.ctl,
    required this.amtCtrl,
    required this.memoCtrl,
    required this.amtFocus,
    required this.memoFocus,
    required this.onChoosePay,
  });

  @override
  Widget build(BuildContext context) {
    final i18n = AppI18n.of(context);
    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(
        24 * scale,
        18 * scale,
        24 * scale,
        12 * scale,
      ),
      decoration: BoxDecoration(
        color: cs.card,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(18 * scale),
          topRight: Radius.circular(18 * scale),
        ),
        boxShadow: [
          BoxShadow(
            color: cs.shadow,
            blurRadius: 12,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                i18n.t(
                  zhHans: '转账金额',
                  zhHant: '轉帳金額',
                  en: 'Transfer Amount',
                  ja: '送金額',
                  ko: '이체 금액',
                ),
                style: TextStyle(
                  fontSize: 14.5 * scale,
                  color: cs.text,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Spacer(),
              _CoinPill(
                cs: cs,
                scale: scale,
                item: ctl.sel,
                balance: ctl.sel.bal,
                onTap: onChoosePay,
              ),
            ],
          ),
          SizedBox(height: 18 * scale),
          WalletAmountInput(
            controller: amtCtrl,
            focusNode: amtFocus,
            textAlign: TextAlign.left,
            scale: ctl.sel.scale,
            maxInt: 12,
            hint: WalletAmountTypography.hint,
            fontSize: WalletAmountTypography.fontSize(context),
            fontWeight: WalletAmountTypography.fontWeight,
            color: cs.text,
            hintColor: cs.inputHint,
            minTapHeight: WalletAmountTypography.minTapHeight(context),
          ),
          Container(
            height: 1,
            margin: EdgeInsets.only(top: 8 * scale),
            color: cs.line,
          ),
          SizedBox(height: 14 * scale),
          WalletPlainTextInput(
            controller: memoCtrl,
            focusNode: memoFocus,
            maxLength: kWalletTransferMemoMaxLength,
            maxLengthEnforcement: MaxLengthEnforcement.enforced,
            textInputAction: TextInputAction.done,
            minTapHeight: 44 * scale,
            style: TextStyle(
              fontSize: 14.5 * scale,
              color: cs.text,
              fontWeight: FontWeight.w500,
            ),
            hintStyle: TextStyle(
              fontSize: 14.5 * scale,
              color: cs.inputHint,
              fontWeight: FontWeight.w500,
            ),
            cursorColor: cs.inputCursor,
            inputFormatters: [
              LengthLimitingTextInputFormatter(kWalletTransferMemoMaxLength),
            ],
            hint: i18n.t(
              zhHans: '添加转账说明',
              zhHant: '新增轉帳說明',
              en: 'Add a note',
              ja: '送金メモを追加',
              ko: '이체 메모 추가',
            ),
          ),
        ],
      ),
    );
  }
}

class _CoinPill extends StatelessWidget {
  final WalletPageColors cs;
  final double scale;
  final WalletPayMethodDto item;
  final String balance;
  final VoidCallback onTap;
  const _CoinPill({
    required this.cs,
    required this.scale,
    required this.item,
    required this.balance,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12 * scale),
      child: Container(
        height: 40 * scale,
        padding: EdgeInsets.fromLTRB(12 * scale, 0, 12 * scale, 0),
        decoration: BoxDecoration(
          color: cs.inputFill,
          borderRadius: BorderRadius.circular(12 * scale),
          border: Border.all(color: cs.line, width: 1),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            ConstrainedBox(
              constraints: BoxConstraints(maxWidth: 72 * scale),
              child: Text(
                balance.isEmpty ? '0.0' : balance,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 13.5 * scale,
                  color: cs.text,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            SizedBox(width: 6 * scale),
            WalletPayCoinIcon(
              item: item,
              size: 24 * scale,
              small: true,
              badgeBorderColor: cs.card,
            ),
            SizedBox(width: 6 * scale),
            Text(
              item.coin,
              style: TextStyle(
                fontSize: 13.5 * scale,
                color: cs.text,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ConfirmBtn extends StatelessWidget {
  final WalletPageColors cs;
  final double scale;
  final VoidCallback onTap;
  final bool enabled;
  const _ConfirmBtn({
    required this.cs,
    required this.scale,
    required this.onTap,
    required this.enabled,
  });

  @override
  Widget build(BuildContext context) {
    final i18n = AppI18n.of(context);
    final disabledBg = cs.dark ? const Color(0xFF2A2D33) : const Color(0xFFDDDDDD);

    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: Container(
        width: 232 * scale,
        height: 54 * scale,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: enabled ? cs.red : disabledBg,
          borderRadius: BorderRadius.circular(10 * scale),
        ),
        child: Text(
          i18n.t(
            zhHans: '确认',
            zhHant: '確認',
            en: 'Confirm',
            ja: '確認',
            ko: '확인',
          ),
          style: TextStyle(
            fontSize: 18 * scale,
            color: enabled ? Colors.white : cs.subText,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

double _mobileScale(BuildContext context) {
  final width = MediaQuery.sizeOf(context).width;
  return (width / 375).clamp(0.92, 1.0);
}
