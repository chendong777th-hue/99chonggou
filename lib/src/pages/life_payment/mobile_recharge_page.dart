import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:uuid/uuid.dart';
import 'package:tencent_cloud_chat_demo/src/i18n/app_i18n.dart';
import 'package:tencent_cloud_chat_demo/src/pages/life_payment/life_payment_errors.dart';
import 'package:tencent_cloud_chat_demo/src/pages/life_payment/life_payment_theme.dart';
import 'package:tencent_cloud_chat_demo/src/pages/life_payment/mobile_recharge_repository.dart';
import 'package:tencent_cloud_chat_demo/src/pages/wallet/wallet_repository.dart';
import 'package:tencent_cloud_chat_demo/src/pages/wallet/widgets/pay_method_sheet.dart';
import 'package:tencent_cloud_chat_demo/src/pages/wallet/widgets/pay_password_prompt.dart';
import 'package:tencent_cloud_chat_demo/src/platform/permission_guard.dart';
import 'package:tencent_cloud_chat_demo/src/theme/app_colors.dart';
import 'package:tencent_cloud_chat_demo/src/utils/immersive_app_system_ui.dart';
import 'package:tencent_cloud_chat_demo/utils/custom_message/life_payment_order_update_message.dart';
import 'package:tencent_cloud_chat_demo/utils/toast.dart';

const Color _headerBlue = Color(0xFFD6EBFF);
const Color _headerBlueDeep = Color(0xFFC4E0FF);
const Color _alipayBlue = Color(0xFF1677FF);
const Color _errorRed = Color(0xFFFF411C);
const Color _amountBorder = Color(0xFFEEEEEE);
const Color _placeholderGrey = Color(0xFFD9D9D9);
const Color _mutedGrey = Color(0xFF999999);
const Color _amountText = Color(0xFF595959);
const Color _contactIconBg = Color(0xFFF0F3F8);
const Color _contactIconColor = Color(0xFFB8BEC8);
const Color _bodyText = Color(0xFF333333);

const List<int> _amountPresets = [50, 100, 200, 300, 500];
const String _defaultPaymentMethod = '99';

const List<WalletPayMethodDto> _rechargePayMethods = [
  WalletPayMethodDto(
    id: '99',
    coin: '99币',
    net: '平台余额',
    bal: '可用',
    fiat: '≈¥0.00',
    balMinor: 0,
    scale: 2,
    color: Color(0xFF1677FF),
    badgeColor: Color(0xFF1677FF),
    badge: '99',
    platformCoin: true,
  ),
  WalletPayMethodDto(
    id: 'USDT',
    coin: 'USDT',
    net: '数字资产',
    bal: '可用',
    fiat: '≈¥0.00',
    balMinor: 0,
    scale: 6,
    color: Color(0xFF26A17B),
    badgeColor: Color(0xFF26A17B),
    badge: 'T',
  ),
];

String _formatPhoneDisplay(String digits) {
  if (digits.isEmpty) return '';
  final buf = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    if (i == 3 || i == 7) buf.write(' ');
    buf.write(digits[i]);
  }
  return buf.toString();
}

class MobileRechargePage extends StatefulWidget {
  const MobileRechargePage({super.key});

  @override
  State<MobileRechargePage> createState() => _MobileRechargePageState();
}

class _MobileRechargePageState extends State<MobileRechargePage> {
  final TextEditingController _phoneCtrl = TextEditingController();
  final MobileRechargeRepository _repo = MobileRechargeRepository();

  int? _selectedAmount;
  List<int> _amountOptions = _amountPresets;
  String _amountOptionsPhone = '';
  bool _loadingAmountOptions = false;
  bool _showPhoneError = true;
  bool _paying = false;
  bool _keypadVisible = false;
  String _paymentMethodId = _defaultPaymentMethod;
  String _statusText = '请选择充值金额';
  String? _lastOrderNo;
  StreamSubscription<LifePaymentOrderUpdateEvent>? _orderUpdateSub;

  /// IM 推送到达时置位，打断轮询 sleep 以立刻 getOrder。
  Completer<void>? _orderPushWake;

  String get _phoneDigits => _phoneCtrl.text;
  WalletPayMethodDto get _selectedPayMethod => _rechargePayMethods.firstWhere(
        (item) => item.id == _paymentMethodId,
        orElse: () => _rechargePayMethods.first,
      );

  @override
  void initState() {
    super.initState();
    _phoneCtrl.addListener(_onPhoneChanged);
    _orderUpdateSub =
        LifePaymentOrderUpdateBus.instance.stream.listen(_onOrderUpdatePush);
  }

  @override
  void dispose() {
    _orderUpdateSub?.cancel();
    _phoneCtrl.removeListener(_onPhoneChanged);
    _phoneCtrl.dispose();
    super.dispose();
  }

  void _onOrderUpdatePush(LifePaymentOrderUpdateEvent event) {
    if (_lastOrderNo == null || event.orderNo != _lastOrderNo) return;
    final wake = _orderPushWake;
    if (wake != null && !wake.isCompleted) {
      wake.complete();
    }
  }

  void _onPhoneChanged() {
    final phone = _phoneCtrl.text.replaceAll(RegExp(r'\D'), '');
    if (phone.length == 11 && phone != _amountOptionsPhone) {
      _loadAmountOptions(phone);
    } else if (phone.length != 11 && _amountOptionsPhone.isNotEmpty) {
      _amountOptionsPhone = '';
      _amountOptions = _amountPresets;
      _selectedAmount = null;
    }
    if (mounted) setState(() {});
  }

  Future<void> _loadAmountOptions(String phone) async {
    _amountOptionsPhone = phone;
    setState(() => _loadingAmountOptions = true);
    try {
      final items = await _repo.getAmountOptions(phone);
      if (!mounted || _amountOptionsPhone != phone) return;
      setState(() {
        _amountOptions =
            items.map((item) => item.amount).toList(growable: false);
        if (_amountOptions.isEmpty) _amountOptions = _amountPresets;
        if (_selectedAmount != null &&
            !_amountOptions.contains(_selectedAmount)) {
          _selectedAmount = null;
        }
        _loadingAmountOptions = false;
      });
    } catch (_) {
      if (!mounted || _amountOptionsPhone != phone) return;
      setState(() {
        _amountOptions = _amountPresets;
        _loadingAmountOptions = false;
      });
    }
  }

  void _openKeypad() => setState(() => _keypadVisible = true);

  void _closeKeypad() => setState(() => _keypadVisible = false);

  void _appendDigit(String digit) {
    if (_phoneDigits.length >= 11) return;
    _phoneCtrl.text = _phoneDigits + digit;
    setState(() => _showPhoneError = false);
  }

  void _deleteDigit() {
    if (_phoneDigits.isEmpty) return;
    _phoneCtrl.text = _phoneDigits.substring(0, _phoneDigits.length - 1);
    setState(() => _showPhoneError = _phoneDigits.isEmpty);
  }

  void _clearPhone() {
    _phoneCtrl.clear();
    setState(() => _showPhoneError = true);
  }

  void _confirmKeypad() {
    if (!_isPhoneValid()) {
      setState(() {
        _showPhoneError = true;
        _keypadVisible = true;
      });
      return;
    }
    _closeKeypad();
  }

  bool _isPhoneValid() {
    final digits = _phoneCtrl.text.replaceAll(RegExp(r'\D'), '');
    return digits.length == 11;
  }

  Future<void> _pickFromContacts() async {
    final i18n = AppI18n.of(context);
    final ok = await PermissionGuard.requestContactsForDeviceSync();
    if (!ok) {
      if (!mounted) return;
      ToastUtils.toast(i18n.t(
        zhHans: '未开启通讯录权限',
        zhHant: '未開啟通訊錄權限',
        en: 'Contacts permission required',
        ja: '連絡先の許可が必要です',
        ko: '연락처 권한이 필요합니다',
      ));
      return;
    }

    try {
      final contact = await FlutterContacts.openExternalPick();
      if (contact == null || !mounted) return;
      final raw = contact.phones.isNotEmpty ? contact.phones.first.number : '';
      final digits = raw.replaceAll(RegExp(r'\D'), '');
      if (digits.length >= 11) {
        _phoneCtrl.text = digits.substring(digits.length - 11);
        setState(() => _showPhoneError = false);
      }
    } catch (_) {
      if (!mounted) return;
      ToastUtils.toast(i18n.t(
        zhHans: '无法读取联系人',
        zhHant: '無法讀取聯絡人',
        en: 'Unable to read contact',
        ja: '連絡先を読み取れません',
        ko: '연락처를 읽을 수 없습니다',
      ));
    }
  }

  Future<void> _onAmountTap(int? amount, {bool autoRecharge = false}) async {
    final i18n = AppI18n.of(context);
    if (!_isPhoneValid()) {
      setState(() {
        _showPhoneError = true;
        _keypadVisible = true;
      });
      return;
    }

    if (autoRecharge) {
      ToastUtils.toast(i18n.t(
        zhHans: '自动充功能即将上线',
        zhHant: '自動充功能即將上線',
        en: 'Auto top-up coming soon',
        ja: '自動チャージは近日公開',
        ko: '자동 충전 기능 준비 중',
      ));
      return;
    }

    if (amount == null) return;
    setState(() => _selectedAmount = amount);
    await _startRecharge(amount);
  }

  Future<void> _startRecharge(int amount) async {
    if (_paying) return;
    final phone = _phoneCtrl.text.replaceAll(RegExp(r'\D'), '');
    setState(() {
      _paying = true;
      _statusText = '正在查询手机号充值档案';
    });

    MobileRechargePhoneProfile profile;
    try {
      profile = await _repo.getPhoneProfile(phone);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _paying = false;
        _statusText = '查询手机号档案失败：$e';
      });
      return;
    }

    if (!mounted) return;
    String? ownerLastChar;
    var verificationType = 'owner_last_char';
    var phoneConfirmed = false;

    if (profile.verified) {
      final confirmed = await _confirmPhoneWithUser(phone);
      if (!mounted) return;
      if (!confirmed) {
        setState(() {
          _paying = false;
          _statusText = '已取消号码确认';
        });
        return;
      }
      phoneConfirmed = true;
      verificationType = 'phone_confirmed';
      setState(() => _statusText = '号码已确认，请输入支付密码');
    } else {
      ownerLastChar = await _askOwnerNameChar(phone);
      if (!mounted) return;
      if (ownerLastChar == null || ownerLastChar.trim().isEmpty) {
        setState(() {
          _paying = false;
          _statusText = '首次充值必须填写机主姓名最后一个字';
        });
        return;
      }
      setState(() => _statusText = '机主信息已保存，请输入支付密码');
    }

    await _submitOrderWithPayPin(
      phone: phone,
      amount: amount,
      phoneConfirmed: phoneConfirmed,
      verificationType: verificationType,
      ownerLastChar: ownerLastChar,
    );
  }

  Future<bool> _confirmPhoneWithUser(String phone) async {
    final result = await showCupertinoDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return CupertinoAlertDialog(
          title: const Text(
            '确认充值号码',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w600,
              height: 1.25,
            ),
          ),
          content: Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              '请核对号码：${_formatPhoneDisplay(phone)}',
              style: const TextStyle(
                fontSize: 14,
                height: 1.45,
                fontWeight: FontWeight.w400,
              ),
            ),
          ),
          actions: [
            CupertinoDialogAction(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('取消', style: TextStyle(fontSize: 16)),
            ),
            CupertinoDialogAction(
              isDefaultAction: true,
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('确认充值', style: TextStyle(fontSize: 16)),
            ),
          ],
        );
      },
    );
    return result == true;
  }

  Future<String?> _askOwnerNameChar(String phone) {
    return showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => _OwnerNameVerificationDialog(phone: phone),
    );
  }

  Future<WalletPayMethodDto?> _showPaymentMethodPicker() {
    return showModalBottomSheet<WalletPayMethodDto>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.38),
      builder: (_) => WalletPayMethodSheet(
        items: _rechargePayMethods,
        sel: _selectedPayMethod,
      ),
    );
  }

  Future<void> _submitOrderWithPayPin({
    required String phone,
    required int amount,
    required bool phoneConfirmed,
    required String verificationType,
    String? ownerLastChar,
  }) async {
    final method = _selectedPayMethod;
    MobileRechargeOrder? createdOrder;
    final paid = await PayPasswordPrompt.show(
      context,
      title: '话费充值',
      amountText: amount.toString(),
      amountCoin: '元',
      payText: method.coin,
      payCoinCode: method.id,
      walletSubtitle: method.net,
      onChangePayMethod: () async {
        final selected = await _showPaymentMethodPicker();
        if (selected == null) return null;
        if (mounted) {
          setState(() => _paymentMethodId = selected.id);
        }
        return PayMethodDisplay(
          amountText: amount.toString(),
          amountCoin: '元',
          payText: selected.coin,
          payCoinCode: selected.id,
          walletSubtitle: selected.net,
        );
      },
      onSubmit: (pwd) async {
        try {
          final order = await _repo.createOrder(
            CreateMobileRechargeOrderReq(
              // uuid 防撞单：毫秒时间戳在多设备/快速重试下存在撞 client_order_id 风险
              clientOrderId: 'mobile-${const Uuid().v4()}',
              phone: phone,
              amount: amount,
              paymentMethod: _paymentMethodId,
              payPin: pwd,
              phoneConfirmed: phoneConfirmed,
              verificationType: verificationType,
              ownerLastChar: ownerLastChar,
            ),
          );
          createdOrder = order;
          return null;
        } catch (e) {
          return '创建充值任务失败：${LifePaymentErrors.userMessage(e, fallbackAction: '创建充值任务')}';
        }
      },
    );
    if (!mounted) return;
    if (paid != true || createdOrder == null) {
      setState(() {
        _paying = false;
        _statusText = '支付已取消或任务未创建';
      });
      return;
    }
    setState(() {
      _lastOrderNo = createdOrder!.orderNo;
      _paying = false;
      _statusText = createdOrder!.message.isNotEmpty
          ? createdOrder!.message
          : '订单已入队，等待执行';
    });
    ToastUtils.toast('充值任务已提交');
    _pollOrderStatus(createdOrder!.orderNo, phone: phone);
  }

  /// 真机执行一单话费实测约 1 分钟（不含排队），轮询窗口必须覆盖
  /// 「排队 + 执行 + 人工确认付款」的完整时长，否则用户只能看到中间态。
  static const int _orderPollMaxRounds = 48;
  static const Duration _orderPollInterval = Duration(seconds: 5);

  Future<void> _pollOrderStatus(String orderNo, {required String phone}) async {
    // 同一单的姓名末字弹框只弹一次，防止后端状态未刷新时重复打扰
    var ownerCharPrompted = false;
    for (var i = 0; i < _orderPollMaxRounds; i++) {
      final wake = Completer<void>();
      _orderPushWake = wake;
      await Future.any<void>([
        Future<void>.delayed(_orderPollInterval),
        wake.future,
      ]);
      if (_orderPushWake == wake) {
        _orderPushWake = null;
      }
      if (!mounted || _lastOrderNo != orderNo) return;
      MobileRechargeOrder order;
      try {
        order = await _repo.getOrder(orderNo);
      } catch (_) {
        // 单次网络抖动不终止轮询，下一轮继续
        continue;
      }
      if (!mounted || _lastOrderNo != orderNo) return;
      setState(() => _statusText = _describeOrderStatus(order));

      switch (order.status) {
        case 'success':
        case 'failed':
        case 'retryable_failed':
        case 'cancelled':
          return;
        case 'need_owner_last_char':
          if (ownerCharPrompted) break;
          ownerCharPrompted = true;
          final handled = await _handleOwnerLastCharRequired(orderNo, phone);
          if (!mounted || _lastOrderNo != orderNo) return;
          if (!handled) return;
          // 补交成功后任务重新排队，放开限制以便极端情况下再次回补
          ownerCharPrompted = false;
      }
    }
    if (!mounted || _lastOrderNo != orderNo) return;
    setState(() => _statusText = '订单仍在处理中，可稍后在缴费记录中查看结果');
  }

  /// 插件在支付宝侧遇到姓名验证页但任务缺字时回写 need_owner_last_char，
  /// 前端弹框补字并回传后端，任务重新置为 ready（契约闭环的前端半程）。
  Future<bool> _handleOwnerLastCharRequired(
    String orderNo,
    String phone,
  ) async {
    setState(() => _statusText = '运营商要求验证机主姓名，请补充信息');
    final ownerChar = await _askOwnerNameChar(phone);
    if (!mounted || _lastOrderNo != orderNo) return false;
    if (ownerChar == null || ownerChar.trim().isEmpty) {
      setState(() => _statusText = '未填写机主姓名，充值暂停，可稍后重试');
      return false;
    }
    try {
      await _repo.submitOwnerLastChar(
        orderNo: orderNo,
        ownerLastChar: ownerChar,
      );
      if (mounted && _lastOrderNo == orderNo) {
        setState(() => _statusText = '机主信息已补交，订单重新排队执行');
      }
      return true;
    } catch (e) {
      if (mounted && _lastOrderNo == orderNo) {
        setState(() {
          _statusText =
              '补交机主信息失败：${LifePaymentErrors.userMessage(e, fallbackAction: '补交机主信息')}';
        });
      }
      return false;
    }
  }

  String _describeOrderStatus(MobileRechargeOrder order) {
    switch (order.status) {
      case 'success':
        return '充值成功';
      case 'failed':
      case 'retryable_failed':
        return order.message.isNotEmpty ? order.message : '充值失败，款项将原路退回';
      case 'cashier_confirm':
      case 'ready_to_pay':
        return '充值执行中，等待付款确认';
      case 'need_owner_last_char':
        return '需要补充机主姓名信息';
      case 'ready':
      case 'pending':
        return '订单排队中，请稍候';
      case 'running':
        return '充值执行中，请稍候';
      default:
        return order.message.isNotEmpty
            ? order.message
            : '订单状态：${order.status}';
    }
  }

  void _showInfoToast(String zhHans) {
    ToastUtils.toast(AppI18n.of(context).t(
      zhHans: zhHans,
      zhHant: zhHans,
      en: zhHans,
      ja: zhHans,
      ko: zhHans,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final i18n = AppI18n.of(context);
    final dark = Theme.of(context).brightness == Brightness.dark;
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    final overlay = immersiveOverlayForColors(
      statusBarBackground: dark ? AppColors.card(dark: dark) : _headerBlue,
      navigationBarBackground:
          dark ? AppColors.background(dark: dark) : _headerBlue,
    );

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: overlay,
      child: Scaffold(
        backgroundColor: dark ? AppColors.background(dark: dark) : _headerBlue,
        body: Column(
          children: [
            _MobileHeader(
              dark: dark,
              i18n: i18n,
              onBack: () => Navigator.of(context).pop(),
            ),
            Expanded(
              child: _RechargeTab(
                dark: dark,
                i18n: i18n,
                bottomInset: _keypadVisible ? 0 : bottomInset,
                phoneDigits: _phoneDigits,
                keypadVisible: _keypadVisible,
                showPhoneError: _showPhoneError,
                selectedAmount: _selectedAmount,
                amountOptions: _amountOptions,
                loadingAmountOptions: _loadingAmountOptions,
                paying: _paying,
                statusText: _statusText,
                onPhoneTap: _openKeypad,
                onClearPhone: _clearPhone,
                onPickContact: _pickFromContacts,
                onAmountTap: _onAmountTap,
                onFooterLink: _showInfoToast,
              ),
            ),
            if (_keypadVisible)
              _AlipayPhoneKeypad(
                bottomInset: bottomInset,
                onDigit: _appendDigit,
                onDelete: _deleteDigit,
                onConfirm: _confirmKeypad,
                onDismiss: _closeKeypad,
              ),
          ],
        ),
      ),
    );
  }
}

class _MobileHeader extends StatelessWidget {
  const _MobileHeader({
    required this.dark,
    required this.i18n,
    required this.onBack,
  });

  final bool dark;
  final AppI18n i18n;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.paddingOf(context).top;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(4, top + 4, 16, 12),
      decoration: BoxDecoration(
        gradient: dark
            ? null
            : const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [_headerBlue, _headerBlueDeep],
              ),
        color: dark ? AppColors.card(dark: dark) : null,
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: onBack,
            icon: Icon(
              Icons.arrow_back_ios_new_rounded,
              size: 20,
              color: dark ? AppColors.text(dark: dark) : _bodyText,
            ),
          ),
          Expanded(
            child: Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 8,
              runSpacing: 4,
              children: [
                Text(
                  i18n.t(
                    zhHans: '手机营业厅',
                    zhHant: '手機營業廳',
                    en: 'Mobile Service',
                    ja: '携帯サービス',
                    ko: '휴대폰 영업소',
                  ),
                  style: TextStyle(
                    color: dark ? AppColors.text(dark: dark) : _bodyText,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (!dark)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF7E6),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: const Color(0xFFFFD591),
                        width: 0.5,
                      ),
                    ),
                    child: Text(
                      i18n.t(
                        zhHans: '充值得会员积分',
                        zhHant: '充值得會員積分',
                        en: 'Earn member points',
                        ja: '会員ポイント獲得',
                        ko: '회원 포인트 적립',
                      ),
                      style: const TextStyle(
                        color: Color(0xFFD48806),
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                      ),
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

class _RechargeTab extends StatelessWidget {
  const _RechargeTab({
    required this.dark,
    required this.i18n,
    required this.bottomInset,
    required this.phoneDigits,
    required this.keypadVisible,
    required this.showPhoneError,
    required this.selectedAmount,
    required this.amountOptions,
    required this.loadingAmountOptions,
    required this.paying,
    required this.statusText,
    required this.onPhoneTap,
    required this.onClearPhone,
    required this.onPickContact,
    required this.onAmountTap,
    required this.onFooterLink,
  });

  final bool dark;
  final AppI18n i18n;
  final double bottomInset;
  final String phoneDigits;
  final bool keypadVisible;
  final bool showPhoneError;
  final int? selectedAmount;
  final List<int> amountOptions;
  final bool loadingAmountOptions;
  final bool paying;
  final String statusText;
  final VoidCallback onPhoneTap;
  final VoidCallback onClearPhone;
  final VoidCallback onPickContact;
  final Future<void> Function(int? amount, {bool autoRecharge}) onAmountTap;
  final void Function(String) onFooterLink;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        ListView(
          padding: EdgeInsets.only(bottom: 24 + bottomInset),
          children: [
            _PhoneInputCard(
              dark: dark,
              i18n: i18n,
              phoneDigits: phoneDigits,
              keypadVisible: keypadVisible,
              showPhoneError: showPhoneError,
              onPhoneTap: onPhoneTap,
              onClearPhone: onClearPhone,
              onPickContact: onPickContact,
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 0),
              child: _AmountGrid(
                dark: dark,
                selectedAmount: selectedAmount,
                amountOptions: amountOptions,
                loading: loadingAmountOptions,
                onAmountTap: onAmountTap,
              ),
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: _PromoBanner(dark: dark, i18n: i18n),
            ),
            const SizedBox(height: 24),
            _FooterSection(dark: dark, i18n: i18n, onLinkTap: onFooterLink),
          ],
        ),
        if (paying)
          Positioned.fill(
            child: ColoredBox(
              color: Colors.black.withValues(alpha: 0.08),
              child: Center(
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.62),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const CircularProgressIndicator(color: _alipayBlue),
                      const SizedBox(height: 12),
                      Text(
                        statusText,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _PhoneInputCard extends StatelessWidget {
  const _PhoneInputCard({
    required this.dark,
    required this.i18n,
    required this.phoneDigits,
    required this.keypadVisible,
    required this.showPhoneError,
    required this.onPhoneTap,
    required this.onClearPhone,
    required this.onPickContact,
  });

  final bool dark;
  final AppI18n i18n;
  final String phoneDigits;
  final bool keypadVisible;
  final bool showPhoneError;
  final VoidCallback onPhoneTap;
  final VoidCallback onClearPhone;
  final VoidCallback onPickContact;

  String get _warningText {
    if (phoneDigits.isEmpty) {
      return i18n.t(
        zhHans: '请输入手机号码',
        zhHant: '請輸入手機號碼',
        en: 'Enter phone number',
        ja: '電話番号を入力',
        ko: '휴대폰 번호를 입력하세요',
      );
    }
    return i18n.t(
      zhHans: '此号码可能为首次充值，请仔细核对',
      zhHant: '此號碼可能為首次充值，請仔細核對',
      en: 'First-time top-up? Please verify the number',
      ja: '初回チャージの可能性があります。番号をご確認ください',
      ko: '첫 충전일 수 있습니다. 번호를 확인해 주세요',
    );
  }

  @override
  Widget build(BuildContext context) {
    final cardColor = dark ? LifePaymentTheme.card(dark) : Colors.white;
    final fadeColor = dark ? AppColors.background(dark: dark) : _headerBlue;
    final phoneHint = i18n.t(
      zhHans: '请输入手机号码',
      zhHant: '請輸入手機號碼',
      en: 'Enter phone number',
      ja: '電話番号を入力',
      ko: '휴대폰 번호를 입력하세요',
    );
    final hasPhone = phoneDigits.isNotEmpty;
    final displayPhone = _formatPhoneDisplay(phoneDigits);

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            cardColor,
            cardColor,
            Color.lerp(cardColor, fadeColor, 0.35)!,
            Color.lerp(cardColor, fadeColor, 0.72)!,
            fadeColor,
          ],
          stops: const [0.0, 0.42, 0.68, 0.86, 1.0],
        ),
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(16),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (showPhoneError || hasPhone || keypadVisible)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      children: [
                        _ErrorBadge(dark: dark),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            _warningText,
                            style: TextStyle(
                              color:
                                  _errorRed.withValues(alpha: dark ? 0.9 : 1),
                              fontSize: 13,
                              height: 1.25,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                GestureDetector(
                  onTap: onPhoneTap,
                  behavior: HitTestBehavior.opaque,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(
                        child: hasPhone
                            ? Row(
                                children: [
                                  Flexible(
                                    child: Text(
                                      displayPhone,
                                      style: TextStyle(
                                        color: dark
                                            ? LifePaymentTheme.text(dark)
                                            : const Color(0xFF1A1A1A),
                                        fontSize: 30,
                                        fontWeight: FontWeight.w600,
                                        height: 1.15,
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                  ),
                                  if (keypadVisible)
                                    const _PhoneInputCursor(height: 30),
                                ],
                              )
                            : Row(
                                children: [
                                  if (keypadVisible)
                                    const _PhoneInputCursor(height: 28),
                                  Flexible(
                                    child: Text(
                                      phoneHint,
                                      style: TextStyle(
                                        color: dark
                                            ? LifePaymentTheme.subText(dark)
                                            : _placeholderGrey,
                                        fontSize: 28,
                                        fontWeight: FontWeight.w400,
                                        height: 1.15,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                      ),
                      if (hasPhone)
                        GestureDetector(
                          onTap: onClearPhone,
                          behavior: HitTestBehavior.opaque,
                          child: Container(
                            width: 22,
                            height: 22,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: dark
                                  ? LifePaymentTheme.subText(dark)
                                      .withValues(alpha: 0.45)
                                  : const Color(0xFFCCCCCC),
                            ),
                            alignment: Alignment.center,
                            child: const Icon(
                              Icons.close_rounded,
                              size: 14,
                              color: Colors.white,
                            ),
                          ),
                        )
                      else
                        GestureDetector(
                          onTap: onPickContact,
                          behavior: HitTestBehavior.opaque,
                          child: Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: dark
                                  ? LifePaymentTheme.accentSoft(dark)
                                  : _contactIconBg,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            alignment: Alignment.center,
                            child: Icon(
                              Icons.perm_contact_calendar_outlined,
                              size: 22,
                              color: dark
                                  ? LifePaymentTheme.subText(dark)
                                  : _contactIconColor,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}

class _PhoneInputCursor extends StatefulWidget {
  const _PhoneInputCursor({required this.height});

  final double height;

  @override
  State<_PhoneInputCursor> createState() => _PhoneInputCursorState();
}

class _PhoneInputCursorState extends State<_PhoneInputCursor>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 530),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _controller,
      child: Container(
        width: 2,
        height: widget.height * 0.92,
        margin: const EdgeInsets.only(left: 2, right: 4),
        color: _alipayBlue,
      ),
    );
  }
}

class _ErrorBadge extends StatelessWidget {
  const _ErrorBadge({required this.dark});

  final bool dark;

  @override
  Widget build(BuildContext context) {
    return Text(
      '①',
      style: TextStyle(
        color: _errorRed.withValues(alpha: dark ? 0.9 : 1),
        fontSize: 14,
        height: 1.1,
      ),
    );
  }
}

/// 支付宝风格自定义数字键盘：左侧 3×4 数字区 + 右侧删除/确认。
class _AlipayPhoneKeypad extends StatelessWidget {
  const _AlipayPhoneKeypad({
    required this.bottomInset,
    required this.onDigit,
    required this.onDelete,
    required this.onConfirm,
    required this.onDismiss,
  });

  final double bottomInset;
  final ValueChanged<String> onDigit;
  final VoidCallback onDelete;
  final VoidCallback onConfirm;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final i18n = AppI18n.of(context);
    final dark = Theme.of(context).brightness == Brightness.dark;
    // 键盘分区色：夜间用深底 + 细分割线，避免白键刺眼。
    final line = dark ? const Color(0xFF3A3D44) : const Color(0xFFE5E5E5);
    final keyBg = LifePaymentTheme.formCard(dark);
    final blankBg =
        dark ? LifePaymentTheme.paperDeepDark : const Color(0xFFF7F7F7);
    final barBg =
        dark ? LifePaymentTheme.paperDeepDark : const Color(0xFFF5F5F5);
    final keyText = LifePaymentTheme.text(dark);
    final iconMuted = LifePaymentTheme.formHint(dark);

    Widget hline() => SizedBox(
          height: 0.6,
          child: ColoredBox(color: line),
        );

    Widget actionKey({required VoidCallback onTap, required Widget child}) {
      return Material(
        color: keyBg,
        child: InkWell(
          onTap: onTap,
          child: Center(child: child),
        ),
      );
    }

    Widget buildKey(String value) {
      if (value.isEmpty) {
        return ColoredBox(color: blankBg);
      }
      return actionKey(
        onTap: () => onDigit(value),
        child: Text(
          value,
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w400,
            color: keyText,
          ),
        ),
      );
    }

    Widget numRow(List<String> keys) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < keys.length; i++) ...[
            if (i > 0) SizedBox(width: 0.6, child: ColoredBox(color: line)),
            Expanded(child: buildKey(keys[i])),
          ],
        ],
      );
    }

    return ColoredBox(
      color: line,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          GestureDetector(
            onTap: onDismiss,
            behavior: HitTestBehavior.opaque,
            child: Container(
              height: 36,
              color: barBg,
              alignment: Alignment.center,
              child: Icon(
                Icons.keyboard_arrow_down_rounded,
                size: 22,
                color: iconMuted,
              ),
            ),
          ),
          SizedBox(height: 0.6, child: ColoredBox(color: line)),
          Padding(
            padding: EdgeInsets.only(bottom: bottomInset),
            child: SizedBox(
              height: 216,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    flex: 3,
                    child: Column(
                      children: [
                        Expanded(child: numRow(['1', '2', '3'])),
                        hline(),
                        Expanded(child: numRow(['4', '5', '6'])),
                        hline(),
                        Expanded(child: numRow(['7', '8', '9'])),
                        hline(),
                        Expanded(child: numRow(['', '0', ''])),
                      ],
                    ),
                  ),
                  SizedBox(width: 0.6, child: ColoredBox(color: line)),
                  Expanded(
                    flex: 1,
                    child: Column(
                      children: [
                        Expanded(
                          child: actionKey(
                            onTap: onDelete,
                            child: Icon(
                              Icons.backspace_outlined,
                              size: 24,
                              color: keyText,
                            ),
                          ),
                        ),
                        hline(),
                        Expanded(
                          flex: 3,
                          child: Material(
                            color: _alipayBlue,
                            child: InkWell(
                              onTap: onConfirm,
                              child: Center(
                                child: Text(
                                  i18n.t(
                                    zhHans: '确认',
                                    zhHant: '確認',
                                    en: 'OK',
                                    ja: '確認',
                                    ko: '확인',
                                  ),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 17,
                                    fontWeight: FontWeight.w500,
                                  ),
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
        ],
      ),
    );
  }
}

class _AmountGrid extends StatelessWidget {
  const _AmountGrid({
    required this.dark,
    required this.selectedAmount,
    required this.amountOptions,
    required this.loading,
    required this.onAmountTap,
  });

  final bool dark;
  final int? selectedAmount;
  final List<int> amountOptions;
  final bool loading;
  final Future<void> Function(int? amount, {bool autoRecharge}) onAmountTap;

  @override
  Widget build(BuildContext context) {
    final i18n = AppI18n.of(context);

    if (loading) {
      return const SizedBox(
        height: 76,
        child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
      );
    }

    return GridView.count(
      crossAxisCount: 3,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 10,
      crossAxisSpacing: 10,
      childAspectRatio: 2.05,
      children: [
        ...amountOptions.map((amount) {
          final selected = selectedAmount == amount;
          return _AmountTile(
            dark: dark,
            label: i18n.t(
              zhHans: '$amount元',
              zhHant: '$amount元',
              en: '¥$amount',
              ja: '¥$amount',
              ko: '¥$amount',
            ),
            selected: selected,
            onTap: () => onAmountTap(amount),
          );
        }),
        _AmountTile(
          dark: dark,
          label: i18n.t(
            zhHans: '自动充',
            zhHant: '自動充',
            en: 'Auto',
            ja: '自動',
            ko: '자동충전',
          ),
          selected: false,
          onTap: () => onAmountTap(null, autoRecharge: true),
        ),
      ],
    );
  }
}

class _AmountTile extends StatelessWidget {
  const _AmountTile({
    required this.dark,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final bool dark;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Ink(
          decoration: BoxDecoration(
            color: dark ? LifePaymentTheme.card(dark) : Colors.white,
            borderRadius: BorderRadius.circular(10),
            border:
                selected ? Border.all(color: _alipayBlue, width: 1.5) : null,
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                color: selected
                    ? _alipayBlue
                    : (dark ? LifePaymentTheme.text(dark) : _amountText),
                fontSize: 16,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PromoBanner extends StatelessWidget {
  const _PromoBanner({required this.dark, required this.i18n});

  final bool dark;
  final AppI18n i18n;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: dark ? LifePaymentTheme.card(dark) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: dark
              ? LifePaymentTheme.inkFaint.withValues(alpha: 0.2)
              : _amountBorder,
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  i18n.t(
                    zhHans: '三网通充 · 快速到账',
                    zhHant: '三網通充 · 快速到賬',
                    en: 'All carriers · Fast',
                    ja: '全キャリア · 即時',
                    ko: '전 통신사 · 빠른 충전',
                  ),
                  style: TextStyle(
                    color: dark ? LifePaymentTheme.text(dark) : _bodyText,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  i18n.t(
                    zhHans: '移动/联通/电信官方渠道',
                    zhHant: '移動/聯通/電信官方渠道',
                    en: 'Official carrier channels',
                    ja: '公式キャリアチャネル',
                    ko: '공식 통신사 채널',
                  ),
                  style: TextStyle(
                    color: dark ? LifePaymentTheme.subText(dark) : _mutedGrey,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 10),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                  decoration: BoxDecoration(
                    color: _alipayBlue,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Text(
                    i18n.t(
                      zhHans: '立即充值',
                      zhHant: '立即充值',
                      en: 'Top up now',
                      ja: '今すぐチャージ',
                      ko: '지금 충전',
                    ),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.asset(
              'assets/shenghuo/service_mobile.webp',
              width: 88,
              height: 72,
              fit: BoxFit.cover,
            ),
          ),
        ],
      ),
    );
  }
}

class _FooterSection extends StatelessWidget {
  const _FooterSection({
    required this.dark,
    required this.i18n,
    required this.onLinkTap,
  });

  final bool dark;
  final AppI18n i18n;
  final void Function(String) onLinkTap;

  @override
  Widget build(BuildContext context) {
    final linkStyle = TextStyle(
      color: _alipayBlue.withValues(alpha: dark ? 0.85 : 1),
      fontSize: 13,
    );
    final mutedStyle = TextStyle(
      color: dark ? LifePaymentTheme.subText(dark) : _mutedGrey,
      fontSize: 12,
    );

    Widget link(String zh, VoidCallback onTap) => GestureDetector(
          onTap: onTap,
          child: Text(
            i18n.t(zhHans: zh, zhHant: zh, en: zh, ja: zh, ko: zh),
            style: linkStyle,
          ),
        );

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            link('常见问题', () => onLinkTap('常见问题')),
            _divider(mutedStyle.color!),
            link('客服帮助', () => onLinkTap('客服帮助')),
            _divider(mutedStyle.color!),
            link('服务说明', () => onLinkTap('服务说明')),
          ],
        ),
        const SizedBox(height: 20),
        Row(
          children: [
            Expanded(child: Divider(color: mutedStyle.color, height: 1)),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Text(
                i18n.t(
                  zhHans: '手机营业厅',
                  zhHant: '手機營業廳',
                  en: 'Mobile Service',
                  ja: '携帯サービス',
                  ko: '휴대폰 영업소',
                ),
                style: mutedStyle,
              ),
            ),
            Expanded(child: Divider(color: mutedStyle.color, height: 1)),
          ],
        ),
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Text(
            i18n.t(
              zhHans: '服务提供方及订单充值信息等介绍见服务说明',
              zhHant: '服務提供方及訂單充值信息等介紹見服務說明',
              en: 'See service description for provider details',
              ja: '詳細はサービス説明をご覧ください',
              ko: '자세한 내용은 서비스 설명을 참고하세요',
            ),
            textAlign: TextAlign.center,
            style: mutedStyle.copyWith(fontSize: 11, height: 1.4),
          ),
        ),
      ],
    );
  }

  Widget _divider(Color color) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10),
        child: Text('|', style: TextStyle(color: color, fontSize: 12)),
      );
}

/// 首次充值时的机主姓名末字验证弹窗。
///
/// 由弹窗自身持有并释放输入控制器，避免点击“取消充值”后路由
/// 仍在退场动画阶段时，外部提前释放控制器而触发红屏。
/// 布局全部由当前可用宽高比例计算，兼容窄屏、宽屏、横屏和键盘弹起。
class _OwnerNameVerificationDialog extends StatefulWidget {
  const _OwnerNameVerificationDialog({required this.phone});

  final String phone;

  @override
  State<_OwnerNameVerificationDialog> createState() =>
      _OwnerNameVerificationDialogState();
}

class _OwnerNameVerificationDialogState
    extends State<_OwnerNameVerificationDialog> {
  var _ownerLastChar = '';
  var _isClosing = false;

  bool get _canSubmit => _ownerLastChar.isNotEmpty;

  void _close([String? result]) {
    if (_isClosing || !mounted) return;
    _isClosing = true;
    FocusScope.of(context).unfocus();
    Navigator.of(context).pop(result);
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final keyboardInset = mediaQuery.viewInsets.bottom;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final dialogBg = LifePaymentTheme.formCard(dark);
    final titleColor = LifePaymentTheme.text(dark);
    final bodyColor = LifePaymentTheme.formValue(dark);
    final panelBg = LifePaymentTheme.searchFill(dark);
    final inputBg = dark ? LifePaymentTheme.paperDeepDark : Colors.white;
    final divider = LifePaymentTheme.formDivider(dark);

    return SafeArea(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final availableWidth = constraints.maxWidth;
          final availableHeight = constraints.maxHeight;
          final isLandscape = availableWidth > availableHeight;
          final keyboardVisible = keyboardInset > 0;

          // 所有边距、圆角和输入格均相对可用空间计算，不依赖固定尺寸。
          final sideInsetFactor = isLandscape ? 0.22 : 0.09;
          final sideInset = availableWidth * sideInsetFactor;
          final dialogWidth = availableWidth - sideInset * 2;
          final verticalInsetFactor = keyboardVisible
              ? (isLandscape ? 0.01 : 0.024)
              : (isLandscape ? 0.03 : 0.06);
          final verticalInset = availableHeight * verticalInsetFactor;
          final dialogRadius = dialogWidth * 0.08;
          final contentRadius = dialogWidth * 0.046;

          return AnimatedPadding(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOut,
            padding: EdgeInsets.fromLTRB(
              sideInset,
              verticalInset,
              sideInset,
              verticalInset + keyboardInset,
            ),
            child: Center(
              child: Material(
                color: dialogBg,
                clipBehavior: Clip.antiAlias,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(dialogRadius),
                ),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Padding(
                        padding: EdgeInsets.fromLTRB(
                          dialogWidth * 0.073,
                          availableHeight * (keyboardVisible ? 0.018 : 0.028),
                          dialogWidth * 0.073,
                          availableHeight * (keyboardVisible ? 0.016 : 0.026),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              '充值信息验证',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: titleColor,
                                fontSize: 17,
                                fontWeight: FontWeight.w700,
                                height: 1.25,
                              ),
                            ),
                            SizedBox(height: availableHeight * 0.017),
                            Text(
                              '请输入机主姓名最后一个字',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: bodyColor,
                                fontSize: 14,
                                fontWeight: FontWeight.w400,
                                height: 1.35,
                              ),
                            ),
                            SizedBox(height: availableHeight * 0.024),
                            Container(
                              width: double.infinity,
                              padding: EdgeInsets.symmetric(
                                horizontal: dialogWidth * 0.042,
                                vertical: availableHeight *
                                    (keyboardVisible ? 0.014 : 0.022),
                              ),
                              decoration: BoxDecoration(
                                color: panelBg,
                                borderRadius:
                                    BorderRadius.circular(contentRadius),
                              ),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  FittedBox(
                                    fit: BoxFit.scaleDown,
                                    child: Text(
                                      '充值号码  ${_formatPhoneDisplay(widget.phone)}',
                                      style: TextStyle(
                                        color: bodyColor,
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                        height: 1.3,
                                      ),
                                    ),
                                  ),
                                  SizedBox(height: availableHeight * 0.018),
                                  FractionallySizedBox(
                                    widthFactor: isLandscape ? 0.12 : 0.18,
                                    child: AspectRatio(
                                      aspectRatio: 1,
                                      child: DecoratedBox(
                                        decoration: BoxDecoration(
                                          color: inputBg,
                                          borderRadius: BorderRadius.circular(
                                            contentRadius * 0.7,
                                          ),
                                        ),
                                        child: TextField(
                                          autofocus: true,
                                          textAlign: TextAlign.center,
                                          textAlignVertical:
                                              TextAlignVertical.center,
                                          keyboardType: TextInputType.text,
                                          textInputAction: TextInputAction.done,
                                          maxLength: 1,
                                          inputFormatters: [
                                            LengthLimitingTextInputFormatter(1),
                                          ],
                                          onChanged: (value) {
                                            if (!mounted || _isClosing) return;
                                            setState(() {
                                              _ownerLastChar = value.trim();
                                            });
                                          },
                                          onSubmitted: (value) {
                                            final ownerLastChar = value.trim();
                                            if (ownerLastChar.isNotEmpty) {
                                              _close(ownerLastChar);
                                            }
                                          },
                                          decoration: const InputDecoration(
                                            border: InputBorder.none,
                                            enabledBorder: InputBorder.none,
                                            focusedBorder: InputBorder.none,
                                            counterText: '',
                                            contentPadding: EdgeInsets.zero,
                                          ),
                                          style: TextStyle(
                                            color: bodyColor,
                                            fontSize: 18,
                                            fontWeight: FontWeight.w600,
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
                      Divider(
                        height: 1,
                        thickness: 1,
                        color: divider,
                      ),
                      _OwnerNameVerificationActions(
                        canSubmit: _canSubmit,
                        onCancel: _close,
                        onSubmit: () => _close(_ownerLastChar),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _OwnerNameVerificationActions extends StatelessWidget {
  const _OwnerNameVerificationActions({
    required this.canSubmit,
    required this.onCancel,
    required this.onSubmit,
  });

  final bool canSubmit;
  final VoidCallback onCancel;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final disabled = LifePaymentTheme.formHint(dark);
    final divider = LifePaymentTheme.formDivider(dark);
    final cancelActionStyle = const TextStyle(
      color: _alipayBlue,
      fontSize: 16,
      fontWeight: FontWeight.w600,
    );
    final submitActionStyle = TextStyle(
      color: canSubmit ? _alipayBlue : disabled,
      fontSize: 16,
      fontWeight: FontWeight.w600,
    );

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: TextButton(
              onPressed: onCancel,
              style: TextButton.styleFrom(
                foregroundColor: _alipayBlue,
                shape: const RoundedRectangleBorder(),
              ),
              child: Text('取消充值', style: cancelActionStyle),
            ),
          ),
          VerticalDivider(
            width: 1,
            thickness: 1,
            color: divider,
          ),
          Expanded(
            child: TextButton(
              onPressed: canSubmit ? onSubmit : null,
              style: TextButton.styleFrom(
                foregroundColor: _alipayBlue,
                disabledForegroundColor: disabled,
                shape: const RoundedRectangleBorder(),
              ),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text('验证并充值', style: submitActionStyle),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
