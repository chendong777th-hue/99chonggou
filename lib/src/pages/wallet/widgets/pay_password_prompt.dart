import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:tencent_cloud_chat_demo/src/i18n/app_i18n.dart';
import 'package:tencent_cloud_chat_demo/src/ui/app_responsive.dart';
import 'package:tencent_cloud_chat_demo/src/ui/utils/adaptive_modal.dart';
import 'package:tencent_cloud_chat_demo/src/widgets/app_network_image.dart';
import 'package:tencent_cloud_chat_uikit/ui/utils/image_mem_cache_utils.dart';

import 'wallet_page_colors.dart';

/// 「更改付款方式」后回传给支付弹窗的展示数据。
/// 调用方在打开选择付款方式的弹窗、更新自身状态后，用最新值构造它，
/// 支付弹窗据此原地刷新金额与付款方式，无需关闭重开。
class PayMethodDisplay {
  final String amountText;
  final String? amountCoin;
  final String payText;
  final String? payCoinCode;
  final String? payLogoUrl;
  final String? walletSubtitle;

  const PayMethodDisplay({
    required this.amountText,
    this.amountCoin,
    required this.payText,
    this.payCoinCode,
    this.payLogoUrl,
    this.walletSubtitle,
  });
}

/// 钱包支付密码弹窗。
/// 视觉上与钱包页统一，采用卡片分层和独立键盘区。
class PayPasswordPrompt extends StatefulWidget {
  final String title;
  final String amountText;

  /// 选填：币种名（如 `99币`、`USDT`）。传入后大金额标题会把币种名
  /// 用更小、更灰的样式与金额分离展示，避免 `1 99币` 被误读成 `199`。
  final String? amountCoin;
  final String payText;
  final String? payCoinCode;
  final String? payLogoUrl;
  final Future<String?> Function(String pwd) onSubmit;
  final String? receiverName;
  final String? receiverId;
  final String? receiverAvatar;

  /// 选填：用于展示余额等副标题（如：9890 USDT）。
  final String? walletSubtitle;
  final String? biometricShortcutLabel;
  final Future<bool> Function()? onBiometricShortcut;

  /// 选填：点击「更改」时触发，用于切换付款方式（如 99币 / USDT）。
  /// 返回新的 [PayMethodDisplay] 则原地刷新，返回 null 表示未更改。
  final Future<PayMethodDisplay?> Function()? onChangePayMethod;

  const PayPasswordPrompt({
    super.key,
    required this.title,
    required this.amountText,
    this.amountCoin,
    required this.payText,
    this.payCoinCode,
    this.payLogoUrl,
    required this.onSubmit,
    this.receiverName,
    this.receiverId,
    this.receiverAvatar,
    this.walletSubtitle,
    this.biometricShortcutLabel,
    this.onBiometricShortcut,
    this.onChangePayMethod,
  });

  static Future<bool?> show(
    BuildContext context, {
    required String title,
    required String amountText,
    String? amountCoin,
    required String payText,
    String? payCoinCode,
    String? payLogoUrl,
    required Future<String?> Function(String pwd) onSubmit,
    String? receiverName,
    String? receiverId,
    String? receiverAvatar,
    String? walletSubtitle,
    String? biometricShortcutLabel,
    Future<bool> Function()? onBiometricShortcut,
    Future<PayMethodDisplay?> Function()? onChangePayMethod,
  }) {
    return showAdaptiveModalSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.55),
      enableDrag: true,
      desktopMaxWidth: 420,
      builder: (_) => PayPasswordPrompt(
        title: title,
        amountText: amountText,
        amountCoin: amountCoin,
        payText: payText,
        payCoinCode: payCoinCode,
        payLogoUrl: payLogoUrl,
        onSubmit: onSubmit,
        receiverName: receiverName,
        receiverId: receiverId,
        receiverAvatar: receiverAvatar,
        walletSubtitle: walletSubtitle,
        biometricShortcutLabel: biometricShortcutLabel,
        onBiometricShortcut: onBiometricShortcut,
        onChangePayMethod: onChangePayMethod,
      ),
    );
  }

  @override
  State<PayPasswordPrompt> createState() => _PayPasswordPromptState();
}

class _PayPasswordPromptState extends State<PayPasswordPrompt> {
  String pwd = '';
  String err = '';
  bool sending = false;
  bool biometricBusy = false;
  bool changingPay = false;

  // 付款方式相关的展示值：初始来自 widget，「更改」后可原地刷新。
  late String _amountText = widget.amountText;
  late String? _amountCoin = widget.amountCoin;
  late String _payText = widget.payText;
  late String? _payCoinCode = widget.payCoinCode;
  late String? _payLogoUrl = widget.payLogoUrl;
  late String? _walletSubtitle = widget.walletSubtitle;

  Future<void> _changePayMethod() async {
    final cb = widget.onChangePayMethod;
    if (cb == null || sending || biometricBusy || changingPay) return;
    setState(() => changingPay = true);
    try {
      final next = await cb();
      if (!mounted || next == null) return;
      setState(() {
        _amountText = next.amountText;
        _amountCoin = next.amountCoin;
        _payText = next.payText;
        _payCoinCode = next.payCoinCode;
        _payLogoUrl = next.payLogoUrl;
        _walletSubtitle = next.walletSubtitle;
        err = '';
      });
    } finally {
      if (mounted) setState(() => changingPay = false);
    }
  }

  Future<void> _tryBiometricShortcut() async {
    final action = widget.onBiometricShortcut;
    if (sending || biometricBusy || action == null) return;
    setState(() {
      biometricBusy = true;
      err = '';
    });
    final ok = await action();
    if (!mounted) return;
    if (ok) {
      Navigator.of(context).pop(true);
      return;
    }
    setState(() {
      biometricBusy = false;
      err = AppI18n.of(context).t(
        zhHans: '生物识别验证失败，请手动输入密码',
        zhHant: '生物辨識驗證失敗，請手動輸入密碼',
        en: 'Biometric verification failed. Enter your password manually.',
        ja: '生体認証に失敗しました。パスワードを手入力してください。',
        ko: '생체 인증에 실패했습니다. 비밀번호를 직접 입력해 주세요.',
      );
    });
  }

  bool get _showBiometric =>
      widget.onBiometricShortcut != null &&
      (widget.biometricShortcutLabel?.trim().isNotEmpty ?? false);

  /// 右上角「面容支付」入口。
  Widget _buildFacePayEntry(WalletPageColors cs, AppI18n i18n) {
    final label = (widget.biometricShortcutLabel?.trim().isNotEmpty ?? false)
        ? widget.biometricShortcutLabel!.trim()
        : i18n.t(
            zhHans: '指纹支付',
            zhHant: '指紋支付',
            en: 'Fingerprint Pay',
            ja: '指紋支払い',
            ko: '지문 결제',
          );
    final disabled = sending || biometricBusy;
    final color = disabled ? cs.blue.withValues(alpha: 0.4) : cs.blue;
    return InkWell(
      borderRadius: BorderRadius.circular(30.r),
      onTap: disabled ? null : _tryBiometricShortcut,
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 6.h),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 23.sp,
            color: color,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }

  Future<void> _tap(String v) async {
    if (sending || pwd.length >= 6) return;
    setState(() {
      pwd += v;
      err = '';
    });
    HapticFeedback.selectionClick();

    if (pwd.length == 6) {
      setState(() => sending = true);
      final msg = await widget.onSubmit(pwd);
      if (!mounted) return;
      if (msg == null || msg.isEmpty) {
        Navigator.of(context).pop(true);
        return;
      }
      setState(() {
        sending = false;
        pwd = '';
        err = msg;
      });
    }
  }

  void _del() {
    if (sending || pwd.isEmpty) return;
    setState(() {
      pwd = pwd.substring(0, pwd.length - 1);
      err = '';
    });
  }

  void _close() {
    if (sending) return;
    Navigator.of(context).pop(false);
  }

  /// 大金额标题：若提供了 [amountCoin]，则把币种名以更小、更灰的样式
  /// 与金额分离展示，避免 `1 99币` 中的 `99` 被误读为金额的一部分。
  Widget _buildBigAmount(WalletPageColors cs) {
    final full = _amountText;
    final coin = (_amountCoin ?? '').trim();
    var value = full;
    var unit = '';
    if (coin.isNotEmpty && full.trimRight().endsWith(coin)) {
      value = full.trimRight();
      value = value.substring(0, value.length - coin.length).trimRight();
      unit = coin;
    }
    if (unit.isEmpty) {
      return Text(
        full,
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: 66.sp,
          color: cs.text,
          fontWeight: FontWeight.w600,
          height: 1.05,
        ),
      );
    }
    return Center(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: 66.sp,
              color: cs.text,
              fontWeight: FontWeight.w600,
              height: 1.0,
            ),
          ),
          Padding(
            padding: EdgeInsets.only(left: 8.w, bottom: 12.h),
            child: Text(
              unit,
              style: TextStyle(
                fontSize: 28.sp,
                color: cs.subText,
                fontWeight: FontWeight.w500,
                height: 1.0,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final i18n = AppI18n.of(context);
    final cs = WalletPageColors.of(context);
    final subtitle = (_walletSubtitle ?? '').trim();
    final canChangePay =
        widget.onChangePayMethod != null && !sending && !biometricBusy;
    final textScale = AppResponsive.textScale(context);
    final maxSheetH = (MediaQuery.sizeOf(context).height *
            (0.88 + math.max(0.0, textScale - 1.0) * 0.05))
        .clamp(480.0, MediaQuery.sizeOf(context).height * 0.96)
        .toDouble();
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    final statusText = sending
        ? i18n.t(
            zhHans: '正在验证...',
            zhHant: '驗證中...',
            en: 'Verifying...',
            ja: '確認中...',
            ko: '확인 중...',
          )
        : (err.isEmpty ? '' : err);
    final statusColor = err.isEmpty ? cs.subText : cs.red;

    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: maxSheetH),
      child: Container(
        decoration: BoxDecoration(
          color: cs.card,
          borderRadius: BorderRadius.vertical(top: Radius.circular(30.r)),
          boxShadow: [
            BoxShadow(
              color: cs.shadow,
              blurRadius: 24,
              offset: const Offset(0, -6),
            ),
          ],
        ),
        child: SafeArea(
          top: false,
          bottom: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(height: 14.h),
              Container(
                width: 82.w,
                height: 6.5.h,
                decoration: BoxDecoration(
                  color: cs.line,
                  borderRadius: BorderRadius.circular(99.r),
                ),
              ),
              Padding(
                padding: EdgeInsets.fromLTRB(12.w, 12.h, 12.w, 4.h),
                child: SizedBox(
                  height: 56.h,
                  child: Stack(
                    children: [
                      Align(
                        alignment: Alignment.centerLeft,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(30.r),
                          onTap: sending ? null : _close,
                          child: Padding(
                            padding: EdgeInsets.all(8.w),
                            child: Icon(
                              Icons.close_rounded,
                              size: 39.sp,
                              color: sending
                                  ? cs.subText.withValues(alpha: 0.4)
                                  : cs.subText,
                            ),
                          ),
                        ),
                      ),
                      Center(
                        child: Text(
                          widget.title,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 25.sp,
                            color: cs.subText,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      if (_showBiometric)
                        Align(
                          alignment: Alignment.centerRight,
                          child: _buildFacePayEntry(cs, i18n),
                        ),
                    ],
                  ),
                ),
              ),
              Flexible(
                child: SingleChildScrollView(
                  physics: const ClampingScrollPhysics(),
                  padding: EdgeInsets.fromLTRB(32.w, 16.h, 32.w, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      SizedBox(height: 4.h),
                      _buildBigAmount(cs),
                      SizedBox(height: 28.h),
                      Row(
                        children: [
                          Text(
                            i18n.t(
                              zhHans: '付款方式',
                              zhHant: '付款方式',
                              en: 'Payment Method',
                              ja: '支払い方法',
                              ko: '결제 수단',
                            ),
                            style: TextStyle(
                              fontSize: 24.sp,
                              color: cs.subText,
                            ),
                          ),
                          const Spacer(),
                          if (widget.onChangePayMethod != null)
                            InkWell(
                              borderRadius: BorderRadius.circular(20.r),
                              onTap: canChangePay ? _changePayMethod : null,
                              child: Padding(
                                padding: EdgeInsets.symmetric(
                                    horizontal: 6.w, vertical: 4.h),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      i18n.t(
                                        zhHans: '更改',
                                        zhHant: '更改',
                                        en: 'Change',
                                        ja: '変更',
                                        ko: '변경',
                                      ),
                                      style: TextStyle(
                                        fontSize: 24.sp,
                                        color: cs.blue,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    Icon(
                                      Icons.keyboard_arrow_down_rounded,
                                      size: 30.sp,
                                      color: cs.blue,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                        ],
                      ),
                      SizedBox(height: 12.h),
                      _PayMethodCard(
                        payText: _payText,
                        payCoinCode: _payCoinCode,
                        payLogoUrl: _payLogoUrl,
                        highlight: true,
                        onTap: canChangePay ? _changePayMethod : null,
                        title: i18n.t(
                          zhHans: '我的钱包',
                          zhHant: '我的錢包',
                          en: 'My Wallet',
                          ja: 'マイウォレット',
                          ko: '내 지갑',
                        ),
                        subtitle: subtitle.isEmpty ? _payText : subtitle,
                      ),
                      SizedBox(height: 22.h),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(6, (i) {
                          return Padding(
                            padding: EdgeInsets.symmetric(horizontal: 7.w),
                            child: _PwdCell(
                              size: 58.w,
                              filled: pwd.length > i,
                              hasError: err.isNotEmpty,
                              active: false,
                              cs: cs,
                            ),
                          );
                        }),
                      ),
                      SizedBox(height: 8.h),
                      SizedBox(
                        height: 22.h,
                        child: Text(
                          statusText,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 15.sp,
                            color: statusColor,
                          ),
                        ),
                      ),
                      SizedBox(height: 10.h),
                    ],
                  ),
                ),
              ),
              // 与 sheet 同属一张底单：仅用 surfaceAlt 轻分区，不用硬编码灰块腰斩。
              Container(
                color: cs.surfaceAlt,
                padding: EdgeInsets.only(bottom: bottomInset),
                child: _KeyPad(
                  cs: cs,
                  enabled: !sending && !biometricBusy,
                  onTap: _tap,
                  onDel: _del,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PwdCell extends StatelessWidget {
  final double size;
  final bool filled;
  final bool hasError;
  final bool active;
  final WalletPageColors cs;

  const _PwdCell({
    required this.size,
    required this.filled,
    required this.hasError,
    required this.active,
    required this.cs,
  });

  @override
  Widget build(BuildContext context) {
    final dot = (size * 0.26).clamp(10.0, 14.0);
    final borderColor = hasError ? cs.red : cs.line;
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: cs.inputFill,
        borderRadius: BorderRadius.circular(8.r),
        border: Border.all(
          color: borderColor,
          width: hasError ? 1 : 0.5,
        ),
      ),
      child: filled
          ? Container(
              width: dot,
              height: dot,
              decoration: BoxDecoration(
                color: cs.text,
                shape: BoxShape.circle,
              ),
            )
          : null,
    );
  }
}

class _PayMethodCard extends StatelessWidget {
  final String payText;
  final String? payCoinCode;
  final String? payLogoUrl;
  final String title;
  final String subtitle;
  final bool highlight;
  final VoidCallback? onTap;

  const _PayMethodCard({
    required this.payText,
    this.payCoinCode,
    this.payLogoUrl,
    required this.title,
    required this.subtitle,
    this.highlight = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = WalletPageColors.of(context);
    final coinCode = (payCoinCode?.trim().isNotEmpty ?? false)
        ? payCoinCode!.trim().toUpperCase()
        : _coinFromPayText(payText);
    final bg = highlight
        ? cs.blue.withValues(alpha: cs.dark ? 0.18 : 0.08)
        : (cs.dark ? cs.inputFill : cs.surfaceAlt);
    return Material(
      color: bg,
      borderRadius: BorderRadius.circular(20.r),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20.r),
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 24.h),
          child: Row(
            children: [
              _PayCoinIcon(
                coinCode: coinCode,
                logoUrl: payLogoUrl,
                size: 74.w,
              ),
              SizedBox(width: 20.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 27.sp,
                        color: cs.text,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    SizedBox(height: 10.h),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 22.sp,
                        color: cs.subText,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.check_rounded,
                size: 42.sp,
                color: cs.blue,
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _coinFromPayText(String text) {
    final parts = text.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty) return '';
    return parts.first.toUpperCase();
  }
}

class _KeyPad extends StatelessWidget {
  final WalletPageColors cs;
  final bool enabled;
  final ValueChanged<String> onTap;
  final VoidCallback onDel;

  /// 微信支付密码键盘比例（约 54pt/行 @812 → design 1624 下 108.h）。
  static const double _rowHeight = 108;
  static const double _digitFontSize = 50;
  static const double _deleteIconSize = 48;

  const _KeyPad({
    required this.cs,
    required this.enabled,
    required this.onTap,
    required this.onDel,
  });

  @override
  Widget build(BuildContext context) {
    const rows = [
      ['1', '2', '3'],
      ['4', '5', '6'],
      ['7', '8', '9'],
      ['', '0', 'del'],
    ];
    final line = cs.line;
    return Table(
      defaultColumnWidth: const FlexColumnWidth(),
      border: TableBorder(
        top: BorderSide(color: line, width: 0.5),
        horizontalInside: BorderSide(color: line, width: 0.5),
        verticalInside: BorderSide(color: line, width: 0.5),
      ),
      children: [
        for (final row in rows)
          TableRow(
            children: [
              for (final k in row)
                _KeyPadButton(
                  cs: cs,
                  enabled: enabled,
                  keyValue: k,
                  rowHeight: _rowHeight,
                  digitFontSize: _digitFontSize,
                  deleteIconSize: _deleteIconSize,
                  onTap: onTap,
                  onDel: onDel,
                ),
            ],
          ),
      ],
    );
  }
}

class _KeyPadButton extends StatelessWidget {
  final WalletPageColors cs;
  final bool enabled;
  final String keyValue;
  final double rowHeight;
  final double digitFontSize;
  final double deleteIconSize;
  final ValueChanged<String> onTap;
  final VoidCallback onDel;

  const _KeyPadButton({
    required this.cs,
    required this.enabled,
    required this.keyValue,
    required this.rowHeight,
    required this.digitFontSize,
    required this.deleteIconSize,
    required this.onTap,
    required this.onDel,
  });

  @override
  Widget build(BuildContext context) {
    final isDigit = keyValue.isNotEmpty && keyValue != 'del';
    final isEmpty = keyValue.isEmpty;
    // 数字键用 card，空位/删除与键盘区 surfaceAlt 一致，灰阶跟钱包主题对齐。
    final bg = isDigit ? cs.card : cs.surfaceAlt;
    final tapHandler = (isEmpty || !enabled)
        ? null
        : (keyValue == 'del' ? onDel : () => onTap(keyValue));
    return TableCell(
      child: Material(
        color: bg,
        child: InkWell(
          onTap: tapHandler,
          child: SizedBox(
            height: rowHeight.h,
            child: Center(
              child: keyValue == 'del'
                  ? Icon(
                      Icons.backspace_rounded,
                      size: deleteIconSize.sp,
                      color: enabled ? cs.text : cs.subText,
                    )
                  : Text(
                      keyValue,
                      style: TextStyle(
                        fontSize: digitFontSize.sp,
                        color: enabled ? cs.text : cs.subText,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PayCoinIcon extends StatelessWidget {
  final String coinCode;
  final String? logoUrl;
  final double size;

  const _PayCoinIcon({
    required this.coinCode,
    this.logoUrl,
    required this.size,
  });

  @override
  Widget build(BuildContext context) {
    final upper = coinCode.toUpperCase();
    final url = logoUrl?.trim() ?? '';
    final isUsdt = upper == 'USDT';
    final isPlatform = upper == '99';
    if (url.isNotEmpty && !isPlatform) {
      final cacheSize = ImageMemCacheSize.forLogicalSize(size, context);
      return ClipOval(
        child: AppNetworkImage(
          url: url,
          width: size,
          height: size,
          fit: BoxFit.cover,
          memCacheWidth: cacheSize,
          memCacheHeight: cacheSize,
          errorWidget: (_, __, ___) => _fallback(upper, isUsdt, isPlatform),
        ),
      );
    }
    return _fallback(upper, isUsdt, isPlatform);
  }

  Widget _fallback(String upper, bool isUsdt, bool isPlatform) {
    return SizedBox(
      width: size,
      height: size,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: isUsdt ? const Color(0xFF26A17B) : const Color(0xFF20B282),
          shape: BoxShape.circle,
        ),
        child: Center(
          child: isUsdt
              ? CustomPaint(
                  size: Size(size * 0.72, size * 0.72),
                  painter: _UsdtPainter(),
                )
              : isPlatform
                  ? ClipOval(
                      child: Image.asset(
                        'assets/img/platform_99.webp',
                        width: size,
                        height: size,
                        fit: BoxFit.cover,
                      ),
                    )
                  : Text(
                      upper.isEmpty ? '?' : upper.substring(0, 1),
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 30.sp,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
        ),
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
        Rect.fromLTWH(w * 0.35, h * 0.43, w * 0.30, h * 0.13), cover);
    canvas.drawRRect(stem, fill);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
