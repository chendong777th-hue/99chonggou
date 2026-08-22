import 'package:dlibphonenumber/dlibphonenumber.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:tencent_cloud_chat_demo/src/api/auth_api.dart';
import 'package:tencent_cloud_chat_demo/src/i18n/app_i18n.dart';
import 'package:tencent_cloud_chat_demo/src/pages/life_payment/life_payment_models.dart';
import 'package:tencent_cloud_chat_demo/src/pages/life_payment/life_payment_theme.dart';
import 'package:tencent_cloud_chat_demo/src/pages/settings/change_phone_page.dart';
import 'package:tencent_cloud_chat_demo/src/theme/app_colors.dart';
import 'package:tencent_cloud_chat_demo/src/ui/app_tokens.dart';
import 'package:tencent_cloud_chat_demo/src/utils/immersive_app_system_ui.dart';
import 'package:tencent_cloud_chat_demo/src/utils/phone_binding_guard.dart';
import 'package:tencent_cloud_chat_demo/src/widgets/app_dialog.dart';
import 'package:tencent_cloud_chat_demo/utils/navigation_routes.dart';
import 'package:tencent_cloud_chat_demo/utils/phone_format.dart';
import 'package:tencent_cloud_chat_demo/utils/toast.dart';

class LifePaymentDetailPage extends StatefulWidget {
  const LifePaymentDetailPage({super.key, required this.type});

  final LifePaymentType type;

  @override
  State<LifePaymentDetailPage> createState() => _LifePaymentDetailPageState();
}

class _LifePaymentDetailPageState extends State<LifePaymentDetailPage> {
  final TextEditingController _accountCtrl = TextEditingController();
  final TextEditingController _amountCtrl = TextEditingController();

  String? _selectedCarrierId;
  LifePaymentRechargeRegion _rechargeRegion = LifePaymentRechargeRegion.domestic;
  bool _loadingPhone = false;
  bool _hasBoundPhone = false;
  String _phoneDisplay = '';
  String _countryCode = '+86';
  String _countryIso = 'CN';
  bool _phoneOnlyMasked = false;
  int? _selectedPresetAmount;
  bool _querying = false;
  bool _paying = false;
  bool _billQueried = false;
  String _queriedAmount = '';
  String _queriedPeriod = '';

  static const _mobilePresets = [30, 50, 100, 200, 300, 500];

  @override
  void initState() {
    super.initState();
    if (widget.type.isMobile) {
      _loadBoundPhone();
    }
  }

  @override
  void dispose() {
    _accountCtrl.dispose();
    _amountCtrl.dispose();
    super.dispose();
  }

  List<LifePaymentMobileCarrier> get _activeCarriers =>
      lifePaymentCarriersForRegion(_rechargeRegion);

  Future<void> _loadBoundPhone() async {
    setState(() => _loadingPhone = true);
    try {
      final me = await AuthApi.instance.fetchMe();
      if (!PhoneBindingGuard.isBound(me)) {
        if (!mounted) return;
        setState(() {
          _hasBoundPhone = false;
          _loadingPhone = false;
          _phoneDisplay = '';
        });
        return;
      }

      final masked = me.phoneMasked.trim();
      final raw = me.phone.trim();
      var countryIso = 'CN';
      var countryCode = '+86';
      var display = masked;
      var onlyMasked = masked.isNotEmpty;
      var national = '';

      if (!PhoneFormat.isMaskedPhone(raw)) {
        onlyMasked = false;
        final e164 = PhoneFormat.tryResolveContactPhone(raw) ??
            PhoneFormat.parseWithRegion(phone: raw, countryIso: 'CN')?.e164;
        if (e164 != null) {
          countryIso = _inferCountryIsoFromE164(e164) ?? 'CN';
          countryCode = _dialCodeFromIso(countryIso);
          national = _nationalFromE164(e164) ?? '';
          display = masked.isNotEmpty
              ? masked
              : _formatDisplayPhone(national, countryCode);
        } else {
          national = raw.replaceAll(RegExp(r'\D'), '');
          display = masked.isNotEmpty ? masked : national;
        }
      } else if (masked.isNotEmpty) {
        display = masked;
      }

      if (!mounted) return;
      setState(() {
        _hasBoundPhone = true;
        _phoneOnlyMasked = onlyMasked;
        _phoneDisplay = display;
        _countryIso = countryIso;
        _countryCode = countryCode;
        _rechargeRegion = countryIso == 'CN'
            ? LifePaymentRechargeRegion.domestic
            : LifePaymentRechargeRegion.overseas;
        if (national.isNotEmpty) {
          _accountCtrl.text = national;
        }
        _selectedCarrierId = null;
        _loadingPhone = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _hasBoundPhone = false;
        _loadingPhone = false;
      });
    }
  }

  String _dialCodeFromIso(String iso) {
    switch (iso.toUpperCase()) {
      case 'CN':
        return '+86';
      case 'HK':
        return '+852';
      case 'TW':
        return '+886';
      case 'MO':
        return '+853';
      case 'SG':
        return '+65';
      case 'MY':
        return '+60';
      case 'JP':
        return '+81';
      case 'KR':
        return '+82';
      case 'US':
        return '+1';
      case 'GB':
        return '+44';
      case 'AU':
        return '+61';
      default:
        return '+86';
    }
  }

  String? _inferCountryIsoFromE164(String e164) {
    try {
      final util = PhoneNumberUtil.instance;
      final parsed = util.parse(e164, null);
      return util.getRegionCodeForNumber(parsed);
    } catch (_) {
      return null;
    }
  }

  String? _nationalFromE164(String e164) {
    try {
      final util = PhoneNumberUtil.instance;
      final parsed = util.parse(e164, null);
      return util.getNationalSignificantNumber(parsed);
    } catch (_) {
      return null;
    }
  }

  String _formatDisplayPhone(String national, String countryCode) {
    if (national.isEmpty) return '';
    if (countryCode == '+86') return national;
    return '$countryCode $national';
  }

  void _onRegionChanged(LifePaymentRechargeRegion region) {
    if (_rechargeRegion == region) return;
    setState(() {
      _rechargeRegion = region;
      _selectedCarrierId = null;
    });
  }

  Future<void> _goBindPhone() async {
    final result = await Navigator.push<bool>(
      context,
      NavigationRoutes.cupertino(builder: (_) => const ChangePhonePage()),
    );
    if (!mounted) return;
    if (result == true || await PhoneBindingGuard.fetchIsBound()) {
      await _loadBoundPhone();
    }
  }

  String _title(AppI18n i18n) {
    switch (widget.type) {
      case LifePaymentType.mobile:
        return i18n.t(
          zhHans: '手机充值',
          zhHant: '手機充值',
          en: 'Mobile Top-up',
          ja: '携帯チャージ',
          ko: '휴대폰 충전',
        );
      case LifePaymentType.electricity:
        return i18n.t(
          zhHans: '电费缴纳',
          zhHant: '電費繳納',
          en: 'Electricity Bill',
          ja: '電気料金',
          ko: '전기요금',
        );
      case LifePaymentType.water:
        return i18n.t(
          zhHans: '水费缴纳',
          zhHant: '水費繳納',
          en: 'Water Bill',
          ja: '水道料金',
          ko: '수도요금',
        );
      case LifePaymentType.gas:
        return i18n.t(
          zhHans: '燃气费缴纳',
          zhHant: '燃氣費繳納',
          en: 'Gas Bill',
          ja: 'ガス料金',
          ko: '가스요금',
        );
    }
  }

  String _accountLabel(AppI18n i18n) {
    switch (widget.type) {
      case LifePaymentType.mobile:
        return i18n.t(
          zhHans: '手机号码',
          zhHant: '手機號碼',
          en: 'Phone Number',
          ja: '電話番号',
          ko: '휴대폰 번호',
        );
      default:
        return i18n.t(
          zhHans: '缴费户号',
          zhHant: '繳費戶號',
          en: 'Account Number',
          ja: 'お客様番号',
          ko: '고객번호',
        );
    }
  }

  String _accountHint(AppI18n i18n) {
    switch (widget.type) {
      case LifePaymentType.mobile:
        return i18n.t(
          zhHans: '请输入11位手机号',
          zhHant: '請輸入11位手機號',
          en: 'Enter 11-digit phone number',
          ja: '11桁の電話番号を入力',
          ko: '11자리 번호 입력',
        );
      default:
        return i18n.t(
          zhHans: '请输入缴费户号',
          zhHant: '請輸入繳費戶號',
          en: 'Enter your account number',
          ja: 'お客様番号を入力',
          ko: '고객번호 입력',
        );
    }
  }

  bool get _canPay {
    if (_paying) return false;
    if (widget.type.isMobile) {
      if (!_hasBoundPhone || _loadingPhone) return false;
      if (_selectedCarrierId == null) return false;
      return _selectedPresetAmount != null || _amountCtrl.text.trim().isNotEmpty;
    }
    final account = _accountCtrl.text.trim();
    if (account.isEmpty) return false;
    return _billQueried && _queriedAmount.isNotEmpty;
  }

  String get _payAmount {
    if (widget.type.isMobile) {
      if (_selectedPresetAmount != null) {
        return _selectedPresetAmount!.toStringAsFixed(2);
      }
      final raw = _amountCtrl.text.trim();
      if (raw.isEmpty) return '0.00';
      final parsed = double.tryParse(raw);
      return parsed == null ? '0.00' : parsed.toStringAsFixed(2);
    }
    return _queriedAmount;
  }

  Future<void> _queryBill() async {
    final i18n = AppI18n.of(context);
    final account = _accountCtrl.text.trim();
    if (account.isEmpty) {
      ToastUtils.toast(i18n.t(
        zhHans: '请先输入缴费户号',
        zhHant: '請先輸入繳費戶號',
        en: 'Please enter account number first',
        ja: 'お客様番号を入力してください',
        ko: '고객번호를 먼저 입력해 주세요',
      ));
      return;
    }

    setState(() => _querying = true);
    await Future<void>.delayed(const Duration(milliseconds: 800));
    if (!mounted) return;

    setState(() {
      _querying = false;
      _billQueried = true;
      _queriedAmount = widget.type == LifePaymentType.electricity
          ? '86.50'
          : widget.type == LifePaymentType.water
              ? '42.00'
              : '68.30';
      _queriedPeriod = i18n.t(
        zhHans: '2026年3月账单',
        zhHant: '2026年3月賬單',
        en: 'March 2026 bill',
        ja: '2026年3月分',
        ko: '2026년 3월 청구서',
      );
    });
  }

  Future<void> _submitPay() async {
    final i18n = AppI18n.of(context);
    if (!_canPay) return;

    if (widget.type.isMobile) {
      if (!_phoneOnlyMasked) {
        final national = _accountCtrl.text.trim();
        if (_rechargeRegion == LifePaymentRechargeRegion.domestic) {
          if (national.length != 11) {
            ToastUtils.toast(i18n.t(
              zhHans: '请输入正确的手机号码',
              zhHant: '請輸入正確的手機號碼',
              en: 'Please enter a valid phone number',
              ja: '正しい電話番号を入力してください',
              ko: '올바른 휴대폰 번호를 입력해 주세요',
            ));
            return;
          }
        } else if (!PhoneFormat.isValidNationalNumber(
          countryCode: _countryCode,
          nationalNumber: national,
          countryIso: _countryIso,
        )) {
          ToastUtils.toast(i18n.t(
            zhHans: '请输入正确的手机号码',
            zhHant: '請輸入正確的手機號碼',
            en: 'Please enter a valid phone number',
            ja: '正しい電話番号を入力してください',
            ko: '올바른 휴대폰 번호를 입력해 주세요',
          ));
          return;
        }
      }
    }

    setState(() => _paying = true);
    await Future<void>.delayed(const Duration(milliseconds: 1200));
    if (!mounted) return;
    setState(() => _paying = false);

    await AppDialog.alert(
      title: i18n.t(
        zhHans: '缴费成功',
        zhHant: '繳費成功',
        en: 'Payment Successful',
        ja: '支払い完了',
        ko: '납부 완료',
      ),
      message: i18n.format(
        zhHans: '已成功缴纳 ¥{amount}',
        zhHant: '已成功繳納 ¥{amount}',
        en: 'Paid ¥{amount} successfully',
        ja: '¥{amount} の支払いが完了しました',
        ko: '¥{amount} 납부가 완료되었습니다',
        vars: {'amount': _payAmount},
      ),
      buttonText: i18n.t(
        zhHans: '完成',
        zhHant: '完成',
        en: 'Done',
        ja: '完了',
        ko: '완료',
      ),
    );
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final i18n = AppI18n.of(context);
    final dark = Theme.of(context).brightness == Brightness.dark;
    final accent =
        LifePaymentTheme.serviceColor(widget.type.visual, dark);
    final bg = AppColors.background(dark: dark);
    final overlay = immersiveOverlayForColors(
      statusBarBackground: AppColors.card(dark: dark),
      navigationBarBackground: bg,
    );

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: overlay,
      child: Scaffold(
        backgroundColor: bg,
        appBar: AppBar(
          elevation: 0,
          scrolledUnderElevation: 0,
          centerTitle: true,
          backgroundColor: AppColors.card(dark: dark),
          surfaceTintColor: Colors.transparent,
          systemOverlayStyle: overlay,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded),
            color: AppTokens.accent,
            onPressed: () => Navigator.of(context).pop(),
          ),
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(0.6),
            child: Container(
              height: 0.6,
              color: AppColors.line(dark: dark),
            ),
          ),
          title: Text(
            _title(i18n),
            style: TextStyle(
              color: AppColors.text(dark: dark),
              fontSize: 17,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        body: TapRegion(
          onTapOutside: (_) => FocusManager.instance.primaryFocus?.unfocus(),
          child: Column(
            children: [
              Expanded(
                child: ListView(
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                  children: [
                    _DetailHeader(type: widget.type, dark: dark, i18n: i18n),
                    const SizedBox(height: 16),
                    if (widget.type.isMobile) ...[
                      if (_loadingPhone)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 32),
                          child: Center(
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: accent,
                            ),
                          ),
                        )
                      else if (!_hasBoundPhone)
                        _BindPhonePrompt(
                          dark: dark,
                          accent: accent,
                          i18n: i18n,
                          onBind: _goBindPhone,
                        )
                      else ...[
                        _RechargeRegionToggle(
                          dark: dark,
                          accent: accent,
                          i18n: i18n,
                          region: _rechargeRegion,
                          onChanged: _onRegionChanged,
                        ),
                        const SizedBox(height: 12),
                        _DetailFieldCard(
                          dark: dark,
                          label: i18n.t(
                            zhHans: '充值号码',
                            zhHant: '充值號碼',
                            en: 'Top-up Number',
                            ja: 'チャージ番号',
                            ko: '충전 번호',
                          ),
                          child: Row(
                            children: [
                              if (_rechargeRegion ==
                                      LifePaymentRechargeRegion.overseas &&
                                  _countryCode != '+86') ...[
                                Text(
                                  _countryCode,
                                  style: TextStyle(
                                    color: LifePaymentTheme.subText(dark),
                                    fontSize: 16,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                const SizedBox(width: 8),
                              ],
                              Expanded(
                                child: Text(
                                  _phoneDisplay,
                                  style: TextStyle(
                                    color: LifePaymentTheme.text(dark),
                                    fontSize: 17,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                        _DetailFieldCard(
                          dark: dark,
                          label: i18n.t(
                            zhHans: '运营商',
                            zhHant: '運營商',
                            en: 'Carrier',
                            ja: 'キャリア',
                            ko: '통신사',
                          ),
                          child: Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: _activeCarriers.map((carrier) {
                              final selected =
                                  _selectedCarrierId == carrier.id;
                              return FilterChip(
                                label: Text(carrier.label(i18n)),
                                selected: selected,
                                onSelected: (_) => setState(
                                  () => _selectedCarrierId = carrier.id,
                                ),
                                selectedColor: accent.withValues(
                                  alpha: dark ? 0.25 : 0.12,
                                ),
                                checkmarkColor: accent,
                                labelStyle: TextStyle(
                                  color: selected
                                      ? accent
                                      : LifePaymentTheme.text(dark),
                                  fontSize: 13,
                                ),
                                side: BorderSide(
                                  color: selected
                                      ? accent
                                      : LifePaymentTheme.inkFaint
                                          .withValues(alpha: 0.45),
                                ),
                                backgroundColor:
                                    LifePaymentTheme.accentSoft(dark),
                              );
                            }).toList(),
                          ),
                        ),
                        const SizedBox(height: 12),
                        _DetailFieldCard(
                          dark: dark,
                          label: i18n.t(
                            zhHans: '充值金额',
                            zhHant: '充值金額',
                            en: 'Top-up Amount',
                            ja: 'チャージ金額',
                            ko: '충전 금액',
                          ),
                          child: Column(
                            children: [
                              GridView.count(
                                crossAxisCount: 3,
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                mainAxisSpacing: 8,
                                crossAxisSpacing: 8,
                                childAspectRatio: 2.15,
                                children: _mobilePresets.map((amount) {
                                  final selected =
                                      _selectedPresetAmount == amount;
                                  return _AmountChip(
                                    amount: amount,
                                    selected: selected,
                                    accent: accent,
                                    dark: dark,
                                    onTap: () => setState(() {
                                      _selectedPresetAmount = amount;
                                      _amountCtrl.clear();
                                    }),
                                  );
                                }).toList(),
                              ),
                              const SizedBox(height: 10),
                              TextField(
                                controller: _amountCtrl,
                                keyboardType:
                                    const TextInputType.numberWithOptions(
                                  decimal: true,
                                ),
                                inputFormatters: [
                                  FilteringTextInputFormatter.allow(
                                    RegExp(r'^\d*\.?\d{0,2}'),
                                  ),
                                ],
                                onChanged: (_) => setState(
                                  () => _selectedPresetAmount = null,
                                ),
                                style: TextStyle(
                                  color: LifePaymentTheme.text(dark),
                                  fontSize: 16,
                                ),
                                decoration: InputDecoration(
                                  hintText: i18n.t(
                                    zhHans: '自定义金额',
                                    zhHant: '自定義金額',
                                    en: 'Custom amount',
                                    ja: '任意の金額',
                                    ko: '직접 입력',
                                  ),
                                  prefixText: '¥ ',
                                  filled: true,
                                  fillColor: LifePaymentTheme.accentSoft(dark),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10),
                                    borderSide: BorderSide.none,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ] else ...[
                      _DetailFieldCard(
                        dark: dark,
                        label: _accountLabel(i18n),
                        child: TextField(
                          controller: _accountCtrl,
                          keyboardType: TextInputType.text,
                          inputFormatters: [
                            LengthLimitingTextInputFormatter(20),
                          ],
                          onChanged: (_) {
                            setState(() {
                              _billQueried = false;
                              _queriedAmount = '';
                            });
                          },
                          style: TextStyle(
                            color: LifePaymentTheme.text(dark),
                            fontSize: 17,
                            fontWeight: FontWeight.w500,
                          ),
                          decoration: InputDecoration(
                            hintText: _accountHint(i18n),
                            hintStyle: TextStyle(
                              color: LifePaymentTheme.subText(dark),
                            ),
                            border: InputBorder.none,
                            isDense: true,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        height: 46,
                        child: OutlinedButton.icon(
                          onPressed: _querying ? null : _queryBill,
                          icon: _querying
                              ? SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: accent,
                                  ),
                                )
                              : Icon(Icons.search_rounded, size: 18, color: accent),
                          label: Text(
                            i18n.t(
                              zhHans: '查询账单',
                              zhHant: '查詢賬單',
                              en: 'Query Bill',
                              ja: '請求額を照会',
                              ko: '청구서 조회',
                            ),
                          ),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: accent,
                            side: BorderSide(color: accent),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                      if (_billQueried) ...[
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: accent.withValues(alpha: dark ? 0.12 : 0.08),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: accent.withValues(alpha: 0.22),
                            ),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      _queriedPeriod,
                                      style: TextStyle(
                                        color: LifePaymentTheme.text(dark),
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      i18n.t(
                                        zhHans: '待缴金额',
                                        zhHant: '待繳金額',
                                        en: 'Amount Due',
                                        ja: '未払い金額',
                                        ko: '납부 금액',
                                      ),
                                      style: TextStyle(
                                        color: LifePaymentTheme.subText(dark),
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Text(
                                '¥$_queriedAmount',
                                style: TextStyle(
                                  color: accent,
                                  fontSize: 20,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                    const SizedBox(height: 16),
                    _DetailTips(type: widget.type, dark: dark, i18n: i18n),
                  ],
                ),
              ),
              _DetailPayBar(
                dark: dark,
                i18n: i18n,
                accent: accent,
                amount: _payAmount,
                enabled: _canPay,
                loading: _paying,
                onPay: _submitPay,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DetailHeader extends StatelessWidget {
  const _DetailHeader({
    required this.type,
    required this.dark,
    required this.i18n,
  });

  final LifePaymentType type;
  final bool dark;
  final AppI18n i18n;

  @override
  Widget build(BuildContext context) {
    final accent = LifePaymentTheme.serviceColor(type.visual, dark);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: LifePaymentTheme.card(dark),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: accent.withValues(alpha: 0.18)),
      ),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: dark ? 0.18 : 0.1),
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: SvgPicture.asset(
              LifePaymentTheme.serviceIconAsset(type.visual),
              width: 28,
              height: 28,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  i18n.t(
                    zhHans: '官方渠道 · 实时到账',
                    zhHant: '官方渠道 · 即時到賬',
                    en: 'Official · Instant',
                    ja: '公式 · 即時反映',
                    ko: '공식 · 즉시 처리',
                  ),
                  style: TextStyle(
                    color: LifePaymentTheme.text(dark),
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  i18n.t(
                    zhHans: '请仔细核对账号信息',
                    zhHant: '請仔細核對賬號信息',
                    en: 'Verify account before paying',
                    ja: '支払い前にご確認ください',
                    ko: '결제 전 계정 정보를 확인하세요',
                  ),
                  style: TextStyle(
                    color: LifePaymentTheme.subText(dark),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DetailFieldCard extends StatelessWidget {
  const _DetailFieldCard({
    required this.dark,
    required this.label,
    required this.child,
  });

  final bool dark;
  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        color: LifePaymentTheme.card(dark),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              color: LifePaymentTheme.subText(dark),
              fontSize: 12,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }
}

class _AmountChip extends StatelessWidget {
  const _AmountChip({
    required this.amount,
    required this.selected,
    required this.accent,
    required this.dark,
    required this.onTap,
  });

  final int amount;
  final bool selected;
  final Color accent;
  final bool dark;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: Ink(
          decoration: BoxDecoration(
            color: selected
                ? accent.withValues(alpha: dark ? 0.22 : 0.1)
                : LifePaymentTheme.accentSoft(dark),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: selected
                  ? accent
                  : LifePaymentTheme.inkFaint.withValues(alpha: 0.4),
            ),
          ),
          child: Center(
            child: Text(
              '¥$amount',
              style: TextStyle(
                color: selected ? accent : LifePaymentTheme.text(dark),
                fontWeight: FontWeight.w600,
                fontSize: 15,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DetailTips extends StatelessWidget {
  const _DetailTips({
    required this.type,
    required this.dark,
    required this.i18n,
  });

  final LifePaymentType type;
  final bool dark;
  final AppI18n i18n;

  @override
  Widget build(BuildContext context) {
    final tips = type.isMobile
        ? [
            i18n.t(
              zhHans: '充值成功后一般 1-10 分钟内到账',
              zhHant: '充值成功後一般 1-10 分鐘內到賬',
              en: 'Top-up arrives within 1-10 minutes',
              ja: '通常1〜10分で反映',
              ko: '보통 1~10분 내 반영',
            ),
            i18n.t(
              zhHans: '请确认手机号、地区与运营商匹配',
              zhHant: '請確認手機號、地區與運營商匹配',
              en: 'Match number, region and carrier',
              ja: '番号・地域・キャリアを確認',
              ko: '번호·지역·통신사 일치 확인',
            ),
          ]
        : [
            i18n.t(
              zhHans: '户号可在纸质账单或短信中查看',
              zhHant: '戶號可在紙質賬單或短信中查看',
              en: 'Find account on bill or SMS',
              ja: '請求書やSMSで確認',
              ko: '청구서나 문자에서 확인',
            ),
            i18n.t(
              zhHans: '缴费成功后不支持退款',
              zhHant: '繳費成功後不支持退款',
              en: 'Payments are non-refundable',
              ja: '返金不可',
              ko: '환불 불가',
            ),
          ];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: LifePaymentTheme.paperDeep.withValues(alpha: dark ? 0.35 : 0.55),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            i18n.t(
              zhHans: '温馨提示',
              zhHant: '溫馨提示',
              en: 'Tips',
              ja: 'ご注意',
              ko: '안내',
            ),
            style: TextStyle(
              color: LifePaymentTheme.text(dark),
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          ...tips.map(
            (tip) => Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(
                '· $tip',
                style: TextStyle(
                  color: LifePaymentTheme.subText(dark),
                  fontSize: 12,
                  height: 1.45,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RechargeRegionToggle extends StatelessWidget {
  const _RechargeRegionToggle({
    required this.dark,
    required this.accent,
    required this.i18n,
    required this.region,
    required this.onChanged,
  });

  final bool dark;
  final Color accent;
  final AppI18n i18n;
  final LifePaymentRechargeRegion region;
  final ValueChanged<LifePaymentRechargeRegion> onChanged;

  @override
  Widget build(BuildContext context) {
    return _DetailFieldCard(
      dark: dark,
      label: i18n.t(
        zhHans: '充值地区',
        zhHant: '充值地區',
        en: 'Region',
        ja: '地域',
        ko: '지역',
      ),
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: LifePaymentTheme.accentSoft(dark),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            _RegionOption(
              label: i18n.t(
                zhHans: '国内',
                zhHant: '國內',
                en: 'Domestic',
                ja: '国内',
                ko: '국내',
              ),
              selected: region == LifePaymentRechargeRegion.domestic,
              accent: accent,
              dark: dark,
              onTap: () => onChanged(LifePaymentRechargeRegion.domestic),
            ),
            _RegionOption(
              label: i18n.t(
                zhHans: '海外',
                zhHant: '海外',
                en: 'Overseas',
                ja: '海外',
                ko: '해외',
              ),
              selected: region == LifePaymentRechargeRegion.overseas,
              accent: accent,
              dark: dark,
              onTap: () => onChanged(LifePaymentRechargeRegion.overseas),
            ),
          ],
        ),
      ),
    );
  }
}

class _RegionOption extends StatelessWidget {
  const _RegionOption({
    required this.label,
    required this.selected,
    required this.accent,
    required this.dark,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final Color accent;
  final bool dark;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: onTap,
          child: Ink(
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(
              color: selected
                  ? LifePaymentTheme.card(dark)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(8),
              boxShadow: selected && !dark
                  ? [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.06),
                        blurRadius: 4,
                        offset: const Offset(0, 1),
                      ),
                    ]
                  : null,
            ),
            child: Center(
              child: Text(
                label,
                style: TextStyle(
                  color: selected ? accent : LifePaymentTheme.subText(dark),
                  fontSize: 14,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _BindPhonePrompt extends StatelessWidget {
  const _BindPhonePrompt({
    required this.dark,
    required this.accent,
    required this.i18n,
    required this.onBind,
  });

  final bool dark;
  final Color accent;
  final AppI18n i18n;
  final VoidCallback onBind;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: LifePaymentTheme.card(dark),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          Icon(
            Icons.phone_android_rounded,
            size: 40,
            color: accent.withValues(alpha: 0.8),
          ),
          const SizedBox(height: 12),
          Text(
            i18n.t(
              zhHans: '请先绑定手机号',
              zhHant: '請先綁定手機號',
              en: 'Bind a phone number first',
              ja: '電話番号を登録してください',
              ko: '휴대폰 번호를 먼저 등록해 주세요',
            ),
            style: TextStyle(
              color: LifePaymentTheme.text(dark),
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            i18n.t(
              zhHans: '绑定后将自动使用您的手机号进行充值',
              zhHant: '綁定後將自動使用您的手機號進行充值',
              en: 'Your bound number will be used for top-up',
              ja: '登録後、番号が自動で使用されます',
              ko: '등록 후 번호가 자동으로 사용됩니다',
            ),
            textAlign: TextAlign.center,
            style: TextStyle(
              color: LifePaymentTheme.subText(dark),
              fontSize: 13,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 44,
            child: FilledButton(
              onPressed: onBind,
              style: FilledButton.styleFrom(
                backgroundColor: accent,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(
                i18n.t(
                  zhHans: '去绑定',
                  zhHant: '去綁定',
                  en: 'Bind Now',
                  ja: '登録する',
                  ko: '등록하기',
                ),
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DetailPayBar extends StatelessWidget {
  const _DetailPayBar({
    required this.dark,
    required this.i18n,
    required this.accent,
    required this.amount,
    required this.enabled,
    required this.loading,
    required this.onPay,
  });

  final bool dark;
  final AppI18n i18n;
  final Color accent;
  final String amount;
  final bool enabled;
  final bool loading;
  final VoidCallback onPay;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(
        20,
        12,
        20,
        12 + MediaQuery.paddingOf(context).bottom,
      ),
      decoration: BoxDecoration(
        color: LifePaymentTheme.card(dark),
        border: Border(
          top: BorderSide(
            color: LifePaymentTheme.inkFaint.withValues(alpha: 0.25),
          ),
        ),
      ),
      child: Row(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                i18n.t(
                  zhHans: '应付',
                  zhHant: '應付',
                  en: 'Due',
                  ja: '支払額',
                  ko: '결제',
                ),
                style: TextStyle(
                  color: LifePaymentTheme.subText(dark),
                  fontSize: 12,
                ),
              ),
              Text(
                '¥$amount',
                style: TextStyle(
                  color: LifePaymentTheme.text(dark),
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(width: 16),
          Expanded(
            child: SizedBox(
              height: 48,
              child: FilledButton(
                onPressed: enabled && !loading ? onPay : null,
                style: FilledButton.styleFrom(
                  backgroundColor: accent,
                  disabledBackgroundColor:
                      LifePaymentTheme.inkFaint.withValues(alpha: 0.35),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: loading
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Text(
                        i18n.t(
                          zhHans: '立即缴费',
                          zhHant: '立即繳費',
                          en: 'Pay Now',
                          ja: '支払う',
                          ko: '납부',
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
    );
  }
}
