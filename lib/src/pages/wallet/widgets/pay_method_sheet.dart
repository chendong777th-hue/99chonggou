import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:tencent_cloud_chat_demo/src/i18n/app_i18n.dart';
import 'package:tencent_cloud_chat_demo/src/ui/app_responsive.dart';
import 'package:tencent_cloud_chat_demo/src/widgets/app_network_image.dart';
import 'package:tencent_cloud_chat_uikit/ui/utils/image_mem_cache_utils.dart';

import '../wallet_default_pay_currency_store.dart';
import '../wallet_repository.dart';
import 'wallet_page_colors.dart';

/// 发红包 / 转账共用的「选择付款方式」底部弹层。
class WalletPayMethodSheet extends StatefulWidget {
  const WalletPayMethodSheet({
    super.key,
    required this.items,
    required this.sel,
  });

  final List<WalletPayMethodDto> items;
  final WalletPayMethodDto sel;

  @override
  State<WalletPayMethodSheet> createState() => _WalletPayMethodSheetState();
}

class _WalletPayMethodSheetState extends State<WalletPayMethodSheet> {
  late WalletPayMethodDto _selected;
  bool _setAsDefault = false;
  bool _defaultReady = false;

  @override
  void initState() {
    super.initState();
    _selected = widget.sel;
    _loadDefaultFlag();
  }

  Future<void> _loadDefaultFlag() async {
    final defaultId = await WalletDefaultPayCurrencyStore.readId();
    if (!mounted) return;
    setState(() {
      _setAsDefault = defaultId != null && defaultId == _selected.id.trim();
      _defaultReady = true;
    });
  }

  void _onTapItem(WalletPayMethodDto item) {
    if (!item.enabled) return;
    setState(() => _selected = item);
  }

  Future<void> _onConfirm() async {
    if (!_selected.enabled) return;
    if (_setAsDefault) {
      await WalletDefaultPayCurrencyStore.writeId(_selected.id);
    }
    if (!mounted) return;
    Navigator.of(context).pop(_selected);
  }

  /// 法币展示：≈¥x.xx；无有效金额时为 ≈¥0.00。
  static String formatApproxFiat(String fiat) {
    final raw = fiat
        .replaceAll(RegExp(r'[¥$￥,\s]'), '')
        .replaceAll('约等于', '')
        .replaceAll('≈', '')
        .trim();
    if (raw.isEmpty || raw == '--' || raw == '-') return '≈¥0.00';
    final value = double.tryParse(raw);
    if (value == null || value < 0) return '≈¥0.00';
    return '≈¥${value.toStringAsFixed(2)}';
  }

  String _tagText(WalletPayMethodDto item, AppI18n i18n) {
    if (item.platformCoin || item.id == '99') {
      return i18n.t(
        zhHans: '平台币',
        zhHant: '平台幣',
        en: 'Platform',
        ja: 'プラットフォーム',
        ko: '플랫폼',
      );
    }
    final net = item.net.trim();
    return net.isEmpty ? item.coin : net;
  }

  @override
  Widget build(BuildContext context) {
    final i18n = AppI18n.of(context);
    final cs = WalletPageColors.of(context);
    final bottom = MediaQuery.paddingOf(context).bottom;
    final textScale = AppResponsive.textScale(context);
    final maxHeight = (MediaQuery.sizeOf(context).height *
            (0.86 + math.max(0.0, textScale - 1.0) * 0.06))
        .clamp(420.0, MediaQuery.sizeOf(context).height * 0.94)
        .toDouble();

    return Container(
      constraints: BoxConstraints(
        maxHeight: maxHeight,
      ),
      padding: EdgeInsets.fromLTRB(36.w, 16.h, 36.w, 20.h + bottom),
      decoration: BoxDecoration(
        color: cs.card,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28.r)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Center(
            child: Container(
              width: 72.w,
              height: 8.h,
              decoration: BoxDecoration(
                color: cs.line.withValues(alpha: 0.9),
                borderRadius: BorderRadius.circular(99.r),
              ),
            ),
          ),
          SizedBox(height: 8.h),
          Align(
            alignment: Alignment.centerRight,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => Navigator.of(context).pop(),
              child: Container(
                width: 56.w,
                height: 56.w,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: cs.inputFill,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.close_rounded,
                  size: 28.sp,
                  color: cs.subText,
                ),
              ),
            ),
          ),
          SizedBox(height: 4.h),
          Align(
            alignment: Alignment.centerLeft,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  i18n.t(
                    zhHans: '选择付款方式',
                    zhHant: '選擇付款方式',
                    en: 'Select Payment Method',
                    ja: '支払い方法を選択',
                    ko: '결제 수단 선택',
                  ),
                  style: TextStyle(
                    fontSize: 36.sp,
                    color: cs.text,
                    fontWeight: FontWeight.w800,
                    height: 1.15,
                  ),
                ),
                SizedBox(height: 10.h),
                Text(
                  i18n.t(
                    zhHans: '选择用于本次支付的币种',
                    zhHant: '選擇用於本次支付的幣種',
                    en: 'Choose currency for this payment',
                    ja: '今回の支払いに使う通貨を選択',
                    ko: '이번 결제에 사용할 통화를 선택',
                  ),
                  style: TextStyle(
                    fontSize: 24.sp,
                    color: cs.subText,
                    fontWeight: FontWeight.w400,
                    height: 1.2,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: 28.h),
          Flexible(
            child: ListView.separated(
              shrinkWrap: true,
              padding: EdgeInsets.zero,
              itemCount: widget.items.length,
              separatorBuilder: (_, __) => SizedBox(height: 18.h),
              itemBuilder: (_, i) {
                final item = widget.items[i];
                final selected = item.id == _selected.id;
                return _PayMethodRow(
                  item: item,
                  selected: selected,
                  cs: cs,
                  tagText: _tagText(item, i18n),
                  fiatText: formatApproxFiat(item.fiat),
                  showWarning: !item.enabled ||
                      (double.tryParse(
                                item.bal.replaceAll(RegExp(r'[,\s]'), ''),
                              ) ??
                              0) <=
                          0,
                  onTap: item.enabled ? () => _onTapItem(item) : null,
                );
              },
            ),
          ),
          SizedBox(height: 22.h),
          _DefaultCurrencyBox(
            cs: cs,
            i18n: i18n,
            checked: _setAsDefault,
            enabled: _defaultReady,
            onChanged: (v) => setState(() => _setAsDefault = v),
          ),
          SizedBox(height: 22.h),
          _ConfirmPayButton(
            cs: cs,
            i18n: i18n,
            enabled: _selected.enabled,
            onTap: _onConfirm,
          ),
        ],
      ),
    );
  }
}

class _PayMethodRow extends StatelessWidget {
  const _PayMethodRow({
    required this.item,
    required this.selected,
    required this.cs,
    required this.tagText,
    required this.fiatText,
    required this.showWarning,
    required this.onTap,
  });

  final WalletPayMethodDto item;
  final bool selected;
  final WalletPageColors cs;
  final String tagText;
  final String fiatText;
  final bool showWarning;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final disabled = !item.enabled;
    final selectedBg = cs.blue.withValues(alpha: cs.dark ? 0.16 : 0.06);
    final tagBg = selected
        ? cs.blue.withValues(alpha: cs.dark ? 0.28 : 0.12)
        : cs.inputFill;
    final tagColor = selected
        ? cs.blue
        : cs.subText.withValues(alpha: disabled ? 0.45 : 0.85);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18.r),
        child: Container(
          height: 132.h,
          padding: EdgeInsets.fromLTRB(24.w, 16.h, 22.w, 16.h),
          decoration: BoxDecoration(
            color: selected
                ? selectedBg
                : (disabled
                    ? cs.inputFill.withValues(alpha: cs.dark ? 0.45 : 1.0)
                    : cs.card),
            borderRadius: BorderRadius.circular(18.r),
            border: Border.all(
              color: selected ? cs.blue : cs.line,
              width: selected ? 2.w : 1.5.w,
            ),
          ),
          child: Row(
            children: [
              WalletPayCoinIcon(
                item: item,
                size: 64.w,
                badgeBorderColor: selected ? selectedBg : cs.card,
                showWarning: showWarning,
              ),
              SizedBox(width: 20.w),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.coin,
                      style: TextStyle(
                        fontSize: 30.sp,
                        color: disabled
                            ? cs.subText.withValues(alpha: 0.55)
                            : cs.text,
                        fontWeight: FontWeight.w800,
                        height: 1,
                      ),
                    ),
                    SizedBox(height: 12.h),
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: 12.w,
                        vertical: 4.h,
                      ),
                      decoration: BoxDecoration(
                        color: tagBg,
                        borderRadius: BorderRadius.circular(8.r),
                      ),
                      child: Text(
                        tagText,
                        style: TextStyle(
                          fontSize: 20.sp,
                          color: tagColor,
                          fontWeight: FontWeight.w600,
                          height: 1.1,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(width: 12.w),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  _SelectionMark(selected: selected, cs: cs),
                  const Spacer(),
                  Text(
                    item.bal,
                    style: TextStyle(
                      fontSize: 30.sp,
                      color: disabled
                          ? cs.subText.withValues(alpha: 0.55)
                          : cs.text,
                      fontWeight: FontWeight.w700,
                      height: 1,
                    ),
                  ),
                  SizedBox(height: 8.h),
                  Text(
                    fiatText,
                    style: TextStyle(
                      fontSize: 22.sp,
                      color: disabled
                          ? cs.subText.withValues(alpha: 0.45)
                          : cs.subText,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SelectionMark extends StatelessWidget {
  const _SelectionMark({
    required this.selected,
    required this.cs,
  });

  final bool selected;
  final WalletPageColors cs;

  @override
  Widget build(BuildContext context) {
    if (selected) {
      return Container(
        width: 34.w,
        height: 34.w,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: cs.blue,
          shape: BoxShape.circle,
        ),
        child: Icon(
          Icons.check_rounded,
          size: 20.sp,
          color: Colors.white,
        ),
      );
    }
    return Container(
      width: 34.w,
      height: 34.w,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: cs.subText.withValues(alpha: 0.35),
          width: 2.w,
        ),
      ),
    );
  }
}

class _DefaultCurrencyBox extends StatelessWidget {
  const _DefaultCurrencyBox({
    required this.cs,
    required this.i18n,
    required this.checked,
    required this.enabled,
    required this.onChanged,
  });

  final WalletPageColors cs;
  final AppI18n i18n;
  final bool checked;
  final bool enabled;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: !enabled ? null : () => onChanged(!checked),
      child: Container(
        padding: EdgeInsets.fromLTRB(20.w, 18.h, 20.w, 18.h),
        decoration: BoxDecoration(
          color: cs.inputFill,
          borderRadius: BorderRadius.circular(16.r),
        ),
        child: Row(
          children: [
            SizedBox(
              width: 22.w,
              height: 22.w,
              child: Transform.scale(
                scale: 0.9,
                child: Checkbox(
                  value: checked,
                  onChanged: !enabled ? null : (v) => onChanged(v ?? false),
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  visualDensity: const VisualDensity(
                    horizontal: -4,
                    vertical: -4,
                  ),
                  side: BorderSide(
                    color: cs.subText.withValues(alpha: 0.45),
                    width: 1.4,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(4.r),
                  ),
                  activeColor: cs.blue,
                ),
              ),
            ),
            SizedBox(width: 12.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    i18n.t(
                      zhHans: '选中为默认币种',
                      zhHant: '選中為預設幣種',
                      en: 'Set as default currency',
                      ja: 'デフォルト通貨に設定',
                      ko: '기본 통화로 설정',
                    ),
                    style: TextStyle(
                      fontSize: 26.sp,
                      color: cs.text,
                      fontWeight: FontWeight.w600,
                      height: 1.15,
                    ),
                  ),
                  SizedBox(height: 6.h),
                  Text(
                    i18n.t(
                      zhHans: '下次支付将默认使用所选币种',
                      zhHant: '下次支付將預設使用所選幣種',
                      en: 'Used by default for next payment',
                      ja: '次回の支払いで既定として使用',
                      ko: '다음 결제 시 기본으로 사용',
                    ),
                    style: TextStyle(
                      fontSize: 20.sp,
                      color: cs.subText,
                      fontWeight: FontWeight.w400,
                      height: 1.2,
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(width: 10.w),
            Icon(
              Icons.verified_user_rounded,
              size: 34.sp,
              color: cs.blue,
            ),
          ],
        ),
      ),
    );
  }
}

class _ConfirmPayButton extends StatelessWidget {
  const _ConfirmPayButton({
    required this.cs,
    required this.i18n,
    required this.enabled,
    required this.onTap,
  });

  final WalletPageColors cs;
  final AppI18n i18n;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: enabled ? 1 : 0.45,
      child: GestureDetector(
        onTap: enabled ? onTap : null,
        child: Container(
          height: 96.h,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: cs.blue,
            borderRadius: BorderRadius.circular(99.r),
            boxShadow: [
              BoxShadow(
                color: cs.blue.withValues(alpha: 0.28),
                blurRadius: 18,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Text(
            i18n.t(
              zhHans: '确认支付',
              zhHant: '確認支付',
              en: 'Confirm Payment',
              ja: '支払いを確認',
              ko: '결제 확인',
            ),
            style: TextStyle(
              fontSize: 30.sp,
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }
}

/// 付款方式币种图标（列表行 / 钱包入口共用）。
class WalletPayCoinIcon extends StatelessWidget {
  const WalletPayCoinIcon({
    super.key,
    required this.item,
    required this.size,
    this.small = false,
    this.badgeBorderColor,
    this.showWarning = false,
  });

  final WalletPayMethodDto item;
  final double size;
  final bool small;
  final Color? badgeBorderColor;
  final bool showWarning;

  @override
  Widget build(BuildContext context) {
    final url = item.logoUrl?.trim() ?? '';
    final isUsdt = item.id.toUpperCase() == 'USDT';
    final isPlatform = item.id == '99' || item.platformCoin;
    final badgeSize = small ? 16.w : 23.w;

    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          if (url.isNotEmpty)
            ClipOval(
              child: AppNetworkImage(
                url: url,
                width: size,
                height: size,
                fit: BoxFit.cover,
                memCacheWidth: ImageMemCacheSize.forLogicalSize(size, context),
                memCacheHeight: ImageMemCacheSize.forLogicalSize(size, context),
                errorWidget: (_, __, ___) => _fallbackCoinFace(
                  isUsdt: isUsdt,
                  isPlatform: isPlatform,
                ),
              ),
            )
          else
            _fallbackCoinFace(isUsdt: isUsdt, isPlatform: isPlatform),
          if (showWarning)
            Positioned(
              right: -2.w,
              bottom: -2.w,
              child: Container(
                width: badgeSize,
                height: badgeSize,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: const Color(0xFFE53935),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: badgeBorderColor ?? Colors.white,
                    width: 2.w,
                  ),
                ),
                child: Icon(
                  Icons.priority_high_rounded,
                  size: small ? 10.sp : 14.sp,
                  color: Colors.white,
                ),
              ),
            )
          else if (!isPlatform || url.isEmpty)
            Positioned(
              right: -2.w,
              bottom: -2.w,
              child: Container(
                width: badgeSize,
                height: badgeSize,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: item.badgeColor,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: badgeBorderColor ?? Colors.white,
                    width: 2.w,
                  ),
                ),
                child: Text(
                  item.badge,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: small ? 8.sp : 10.sp,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _fallbackCoinFace({
    required bool isUsdt,
    required bool isPlatform,
  }) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: isUsdt ? const Color(0xFF26A17B) : item.color,
        shape: BoxShape.circle,
      ),
      child: Center(
        child: isUsdt
            ? CustomPaint(
                size: Size(size * 0.72, size * 0.72),
                painter: _UsdtPainter(),
              )
            : isPlatform
                ? Image.asset(
                    'assets/img/platform_99.webp',
                    width: size,
                    height: size,
                    fit: BoxFit.cover,
                  )
                : Text(
                    item.coin.isEmpty ? '?' : item.coin.substring(0, 1),
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: small ? 18.sp : 27.sp,
                      fontWeight: FontWeight.w800,
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
      Rect.fromLTWH(w * 0.35, h * 0.43, w * 0.30, h * 0.13),
      cover,
    );
    canvas.drawRRect(stem, fill);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// 兼容旧引用名。
typedef RedPacketPaySheet = WalletPayMethodSheet;
typedef RedPacketCoinIcon = WalletPayCoinIcon;
