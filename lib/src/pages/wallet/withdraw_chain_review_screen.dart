import 'package:flutter/material.dart';
import 'package:tencent_cloud_chat_demo/utils/toast.dart';
import 'package:tencent_cloud_chat_demo/src/platform/clipboard_guard.dart';
import 'package:tencent_cloud_chat_demo/src/i18n/app_i18n.dart';

import 'order/wallet_order.dart';
import 'wallet_repository.dart';
import 'wallet_repository_provider.dart';
import 'wallet_store.dart';
import 'pay_auth_helper.dart';
import 'widgets/biometric_pay_enable_prompt.dart';
import 'widgets/pay_loading_overlay.dart';
import 'widgets/wallet_page_colors.dart';
import 'withdraw_success_navigation.dart';

class WithdrawChainReviewScreen extends StatefulWidget {
  final CoinDto coin;
  final WalletPayMethodDto payMethod;
  final String toAddress;
  final int amountMinor;
  final int feeMinor;
  final String fiatText;

  const WithdrawChainReviewScreen({
    super.key,
    required this.coin,
    required this.payMethod,
    required this.toAddress,
    required this.amountMinor,
    required this.feeMinor,
    required this.fiatText,
  });

  @override
  State<WithdrawChainReviewScreen> createState() =>
      _WithdrawChainReviewScreenState();
}

class _WithdrawChainReviewScreenState extends State<WithdrawChainReviewScreen> {
  final WalletRepository _repo = createWalletRepository();
  WalletOrderResult? _result;
  String _fromAddress = '';
  bool _loadingFrom = true;

  @override
  void initState() {
    super.initState();
    _loadFromAddress();
  }

  Future<void> _loadFromAddress() async {
    try {
      final wallet = await WalletStore.instance.getWallet(repo: _repo);
      if (!mounted) return;
      setState(() {
        _fromAddress = wallet.trxAddr.trim();
        _loadingFrom = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loadingFrom = false;
      });
    }
  }

  void _toast(String txt) {
    ToastUtils.toast(txt);
  }

  Future<void> _copy(String txt) async {
    final v = txt.trim();
    if (v.isEmpty || v == '--') return;
    await ClipboardGuard.copy(
      v,
      showToast: true,
      toastText: AppI18n.of(context).t(
        zhHans: '已复制',
        zhHant: '已複製',
        en: 'Copied',
        ja: 'コピーしました',
        ko: '복사되었습니다',
      ),
    );
  }

  String get _coin => widget.payMethod.coin;

  String get _amountText => WalletAmount.formatMinor(
        widget.amountMinor,
        widget.payMethod.scale,
      );

  String get _feeText => WalletAmount.formatFixed(
        widget.feeMinor,
        widget.payMethod.scale,
      );

  String get _arrivalText => WalletAmount.formatMinor(
        widget.amountMinor,
        widget.payMethod.scale,
      );

  String get _totalDebitText => WalletAmount.formatMinor(
        widget.amountMinor + widget.feeMinor,
        widget.payMethod.scale,
      );

  String get _totalDebitDisplayText => '$_totalDebitText $_coin';

  String get _fromDisplay {
    final a = _fromAddress.trim();
    if (a.isEmpty) return '--';
    if (a.length <= 16) return a;
    return '${a.substring(0, 10)}...${a.substring(a.length - 10)}';
  }

  String get _fiatDisplay {
    final t = widget.fiatText.trim();
    if (t.isEmpty) return '';
    return t.startsWith('≈') ? t : '≈$t';
  }

  Future<void> _confirm() async {
    final i18n = AppI18n.of(context);
    await PayLoadingOverlay.runBeforePayPrompt(context);
    if (!mounted) return;

    final auth = await PayAuthHelper.collectAndSubmit(
      context: context,
      title: i18n.t(
        zhHans: '链上提现',
        zhHant: '鏈上提現',
        en: 'On-chain Withdrawal',
        ja: 'オンチェーン出金',
        ko: '온체인 출금',
      ),
      amountText: _totalDebitDisplayText,
      payText: '$_coin ${widget.payMethod.net}',
      receiverName: i18n.t(
        zhHans: '收款地址',
        zhHant: '收款地址',
        en: 'Receiving Address',
        ja: '受取アドレス',
        ko: '수령 주소',
      ),
      receiverId: widget.toAddress.trim(),
      walletSubtitle: '${widget.payMethod.bal} $_coin',
      onSubmit: _submit,
    );
    if (!mounted || !auth.success) return;
    final result = _result;
    if (result != null &&
        (result.state == WalletOrderState.success ||
            result.state == WalletOrderState.accepted ||
            result.state == WalletOrderState.pending ||
            result.state == WalletOrderState.unknown)) {
      await BiometricPayEnablePrompt.maybeShowAfterPaySuccess(
        context,
        authMethod: auth.method ?? PayAuthMethod.manual,
        verifiedPayPin: auth.verifiedPayPin,
      );
      if (!mounted) return;
      await WithdrawSuccessNavigation.celebrateAndOpenChainWithdrawDetail(
        context,
        result: result,
        toAddress: widget.toAddress.trim(),
        fromAddress: _fromAddress,
        amountMinor: widget.amountMinor,
        feeMinor: widget.feeMinor,
        payMethod: widget.payMethod,
      );
    }
  }

  Future<String?> _submit(String pwd) async {
    final result = await _repo.withdraw(
      WalletWithdrawReq(
        clientOrderId: 'WD${DateTime.now().millisecondsSinceEpoch}',
        toAddress: widget.toAddress.trim(),
        amt: _amountText,
        amountMinor: widget.amountMinor.toString(),
        coin: widget.payMethod.coin,
        payId: widget.payMethod.id,
        net: widget.payMethod.net,
        pwd: pwd,
      ),
    );
    _result = result;
    if (result.ok &&
        (result.state == WalletOrderState.success ||
            result.state == WalletOrderState.accepted ||
            result.state == WalletOrderState.pending ||
            result.state == WalletOrderState.unknown)) {
      return null;
    }
    if (result.msg.trim().isNotEmpty) return result.msg.trim();
    if (result.err != WalletOrderErr.none) return result.err.text;
    return AppI18n.current.t(
      zhHans: '提现提交失败',
      zhHant: '提現提交失敗',
      en: 'Failed to submit withdrawal.',
      ja: '出金の送信に失敗しました。',
      ko: '출금 제출에 실패했습니다.',
    );
  }

  @override
  Widget build(BuildContext context) {
    final i18n = AppI18n.of(context);
    final cs = WalletPageColors.of(context);
    final appBar = WalletAppBarColors.of(context);
    return wrapWalletPage(
      context,
      Scaffold(
      backgroundColor: cs.bg,
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
            zhHans: '转账确认',
            zhHant: '轉帳確認',
            en: 'Confirm Transfer',
            ja: '送金確認',
            ko: '송금 확인',
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
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
                children: [
                  Center(
                    child: _ReviewTokenMark(
                      payMethod: widget.payMethod,
                      size: 64,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    '- $_amountText $_coin',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 36,
                      fontWeight: FontWeight.w700,
                      color: cs.text,
                      height: 1.0,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _fiatDisplay,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: cs.subText,
                    ),
                  ),
                  const SizedBox(height: 20),
                  _AddressCard(
                    label: i18n.t(
                      zhHans: '收款地址',
                      zhHant: '收款地址',
                      en: 'Receiving Address',
                      ja: '受取アドレス',
                      ko: '수령 주소',
                    ),
                    value: widget.toAddress.trim(),
                    onCopy: () => _copy(widget.toAddress),
                  ),
                  const SizedBox(height: 12),
                  _Card(
                    child: Column(
                      children: [
                        _RowLine(
                          label: i18n.t(
                            zhHans: '发送地址',
                            zhHant: '發送地址',
                            en: 'Sending Address',
                            ja: '送信アドレス',
                            ko: '보내는 주소',
                          ),
                          value: _loadingFrom ? '--' : _fromDisplay,
                          valueColor: cs.text,
                          onCopy: _loadingFrom ? null : () => _copy(_fromAddress),
                        ),
                        _RowLine(
                          label: i18n.t(
                            zhHans: '手续费',
                            zhHant: '手續費',
                            en: 'Fee',
                            ja: '手数料',
                            ko: '수수료',
                          ),
                          value: '$_feeText $_coin',
                          valueColor: cs.text,
                        ),
                        _RowLine(
                          label: i18n.t(
                            zhHans: '到账金额',
                            zhHant: '到賬金額',
                            en: 'Amount Received',
                            ja: '受取金額',
                            ko: '수령 금액',
                          ),
                          value: '$_arrivalText $_coin',
                          valueColor: cs.text,
                        ),
                        _RowLine(
                          label: i18n.t(
                            zhHans: '合计扣款',
                            zhHant: '合計扣款',
                            en: 'Total Debit',
                            ja: '合計引落',
                            ko: '총 차감',
                          ),
                          value: '$_totalDebitText $_coin',
                          valueColor: cs.text,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
              child: Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 56,
                      child: OutlinedButton(
                        onPressed: () => Navigator.of(context).maybePop(),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: cs.text,
                          side: BorderSide(color: cs.line),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(18),
                          ),
                        ),
                        child: Text(
                          i18n.t(
                            zhHans: '取消',
                            zhHant: '取消',
                            en: 'Cancel',
                            ja: 'キャンセル',
                            ko: '취소',
                          ),
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: SizedBox(
                      height: 56,
                      child: ElevatedButton(
                        onPressed: _confirm,
                        style: ElevatedButton.styleFrom(
                          elevation: 0,
                          backgroundColor: cs.blue,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(18),
                          ),
                        ),
                        child: Text(
                          i18n.t(
                            zhHans: '确认',
                            zhHant: '確認',
                            en: 'Confirm',
                            ja: '確認',
                            ko: '확인',
                          ),
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
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
    );
  }
}

class _Card extends StatelessWidget {
  final Widget child;

  const _Card({required this.child});

  @override
  Widget build(BuildContext context) {
    final cs = WalletPageColors.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 2),
      decoration: BoxDecoration(
        color: cs.dark ? cs.inputFill : cs.surfaceAlt,
        borderRadius: BorderRadius.circular(22),
      ),
      child: child,
    );
  }
}

class _AddressCard extends StatelessWidget {
  final String label;
  final String value;
  final VoidCallback onCopy;

  const _AddressCard({
    required this.label,
    required this.value,
    required this.onCopy,
  });

  @override
  Widget build(BuildContext context) {
    final cs = WalletPageColors.of(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 11, 16, 11),
      decoration: BoxDecoration(
        color: cs.dark ? cs.inputFill : cs.surfaceAlt,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: cs.subText,
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: cs.text,
                    height: 1.05,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              InkWell(
                onTap: onCopy,
                borderRadius: BorderRadius.circular(10),
                child: Padding(
                  padding: const EdgeInsets.all(2),
                  child: Icon(
                    Icons.copy_rounded,
                    size: 18,
                    color: cs.subText,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _RowLine extends StatelessWidget {
  final String label;
  final String value;
  final Color valueColor;
  final VoidCallback? onCopy;

  const _RowLine({
    required this.label,
    required this.value,
    required this.valueColor,
    this.onCopy,
  });

  @override
  Widget build(BuildContext context) {
    final cs = WalletPageColors.of(context);
    return SizedBox(
      height: 54,
      child: Row(
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: cs.subText,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.right,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: valueColor,
                height: 1.05,
              ),
            ),
          ),
          if (onCopy != null) ...[
            const SizedBox(width: 12),
            InkWell(
              onTap: onCopy,
              child: Icon(
                Icons.copy_rounded,
                size: 18,
                color: cs.subText,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ReviewTokenMark extends StatelessWidget {
  final WalletPayMethodDto payMethod;
  final double size;

  const _ReviewTokenMark({
    required this.payMethod,
    required this.size,
  });

  @override
  Widget build(BuildContext context) {
    final isUsdt = payMethod.coin.toUpperCase() == 'USDT';
    final isTrx = payMethod.coin.toUpperCase() == 'TRX';
    final isPlatform = payMethod.badge == '99' || payMethod.coin == '99';

    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              color: isUsdt
                  ? const Color(0xFF26A17B)
                  : (isTrx ? const Color(0xFFFF001F) : payMethod.color),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: isPlatform
                  ? ClipOval(
                      child: Image.asset(
                        'assets/img/platform_99.webp',
                        width: size,
                        height: size,
                        fit: BoxFit.cover,
                      ),
                    )
                  : isTrx
                      ? Image.asset(
                          'assets/img/TRX.png',
                          width: size * 0.72,
                          height: size * 0.72,
                          fit: BoxFit.contain,
                          color: Colors.white,
                          colorBlendMode: BlendMode.srcIn,
                        )
                      : isUsdt
                          ? CustomPaint(
                              size: Size(size * 0.72, size * 0.72),
                              painter: _UsdtPainter(),
                            )
                          : Text(
                              payMethod.coin.substring(0, 1),
                              style: TextStyle(
                                fontSize: size * 0.48,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                                height: 1,
                              ),
                            ),
            ),
          ),
          Positioned(
            right: -1,
            bottom: -1,
            child: Container(
              width: size * 0.38,
              height: size * 0.38,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: payMethod.badgeColor,
                shape: BoxShape.circle,
                border: Border.all(
                  color: const Color(0xFFF1F1F3),
                  width: 1.6,
                ),
              ),
              child: Text(
                payMethod.badge,
                style: TextStyle(
                  fontSize: size * 0.16,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                  height: 1,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _UsdtPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final fill = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
    final stroke = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.08
      ..strokeCap = StrokeCap.round;

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(w * 0.08, h * 0.12, w * 0.84, h * 0.16),
        Radius.circular(w * 0.02),
      ),
      fill,
    );

    final stem = RRect.fromRectAndRadius(
      Rect.fromLTWH(w * 0.41, h * 0.12, w * 0.18, h * 0.76),
      Radius.circular(w * 0.02),
    );
    canvas.drawRRect(stem, fill);

    final oval = Rect.fromCenter(
      center: Offset(w / 2, h * 0.53),
      width: w * 0.92,
      height: h * 0.28,
    );
    canvas.drawArc(oval, 0.06, 6.16, false, stroke);

    final cover = Paint()
      ..color = const Color(0xFF26A17B)
      ..style = PaintingStyle.fill;
    canvas.drawRect(
      Rect.fromLTWH(w * 0.35, h * 0.43, w * 0.30, h * 0.13),
      cover,
    );
    canvas.drawRRect(stem, fill);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
