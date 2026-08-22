import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:tencent_cloud_chat_demo/src/ui/utils/adaptive_modal.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:tencent_cloud_chat_demo/src/i18n/app_i18n.dart';
import 'package:tencent_cloud_chat_demo/src/pages/wallet/order/wallet_order.dart';
import 'package:tencent_cloud_chat_demo/src/widgets/app_dialog.dart';
import 'package:tencent_cloud_chat_demo/utils/toast.dart';

import '../widgets/wallet_page_colors.dart';
import '../wallet_pay_pin_guard.dart';
import '../pay_auth_helper.dart';
import '../widgets/biometric_pay_enable_prompt.dart';
import '../widgets/pay_loading_overlay.dart';
import '../widgets/pay_success_main.dart';
import '../widgets/wallet_amount_input.dart';
import 'red_packet_controller.dart';
import 'red_packet_member.dart';
import 'red_packet_member_picker_page.dart';
import 'red_packet_models.dart';
import '../wallet_repository.dart';
import '../widgets/pay_method_sheet.dart';

class RedPacketScreen extends StatefulWidget {
  final String conversationId;
  final String receiverId;
  final String receiverName;
  final String groupNum;
  final bool isGroup;

  /// 进入页面时预选红包类型（群聊专属红包等）。
  final RpType? initialType;

  /// 专属红包收款人头像。
  final String exclusiveReceiverAvatar;

  const RedPacketScreen({
    super.key,
    this.conversationId = '',
    this.receiverId = '',
    this.receiverName = '',
    this.groupNum = '',
    this.isGroup = false,
    this.initialType,
    this.exclusiveReceiverAvatar = '',
  });

  @override
  State<RedPacketScreen> createState() => _RedPacketScreenState();
}

class _RedPacketScreenState extends State<RedPacketScreen> {
  late final RedPacketController ctl;

  final TextEditingController cntCtrl = TextEditingController();
  final TextEditingController amtCtrl = TextEditingController();
  final TextEditingController msgCtrl = TextEditingController();
  final FocusNode cntFocus = FocusNode();
  final FocusNode amtFocus = FocusNode();
  final FocusNode msgFocus = FocusNode();

  bool _sheetOpen = false;

  @override
  void initState() {
    super.initState();

    ctl = RedPacketController();

    if (widget.groupNum.isNotEmpty) {
      ctl.groupNum = widget.groupNum;
    }

    ctl.setChatInfo(
      conversationId: widget.conversationId,
      group: widget.isGroup,
      userId: widget.receiverId,
      name: widget.receiverName,
    );

    if (widget.isGroup) {
      final presetType = widget.initialType;
      if (presetType != null) {
        ctl.setType(presetType);
        if (presetType == RpType.exclusive) {
          cntCtrl.clear();
        }
      }
      final exclusiveId = widget.receiverId.trim();
      if (exclusiveId.isNotEmpty &&
          !RedPacketController.isSelfUserId(exclusiveId) &&
          (presetType == RpType.exclusive || ctl.type == RpType.exclusive)) {
        ctl.setType(RpType.exclusive);
        ctl.setReceiver(
          RedPacketMember(
            userId: exclusiveId,
            name: widget.receiverName.trim(),
            avatar: widget.exclusiveReceiverAvatar.trim(),
          ),
        );
        cntCtrl.clear();
      }
    }

    // Keep the blessing input empty. The default blessing is a grey placeholder
    // and is only used as a fallback when submitting.
    cntCtrl.text = ctl.cnt;
    ctl.loadPayMethods();

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final ok = await WalletPayPinGuard.ensureSet(context);
      if (!ok && mounted) {
        Navigator.of(context).pop();
      }
    });

    cntCtrl.addListener(() => ctl.setCnt(cntCtrl.text));
    amtCtrl.addListener(() => ctl.setAmt(amtCtrl.text));
    msgCtrl.addListener(_onBlessingChanged);
  }

  @override
  void dispose() {
    cntCtrl.dispose();
    amtCtrl.dispose();
    msgCtrl.dispose();
    cntFocus.dispose();
    amtFocus.dispose();
    msgFocus.dispose();
    ctl.dispose();
    super.dispose();
  }

  void _onBlessingChanged() {
    final before = msgCtrl.text;
    ctl.setMsg(before);
    if (ctl.msg != before && msgCtrl.text != ctl.msg) {
      msgCtrl.value = TextEditingValue(
        text: ctl.msg,
        selection: TextSelection.collapsed(offset: ctl.msg.length),
      );
    }
  }

  void _toast(String text) {
    ToastUtils.toast(text);
  }

  Future<void> _chooseType() async {
    if (!ctl.isGroup || _sheetOpen || ctl.isBusy) return;

    _sheetOpen = true;
    try {
      final i18n = AppI18n.of(context);
      final current = ctl.type;
      final ret = await AppDialog.actionSheet<RpType>(
        title: '',
        cancelText: i18n.t(
          zhHans: '取消',
          zhHant: '取消',
          en: 'Cancel',
          ja: 'キャンセル',
          ko: '취소',
        ),
        actions: [
          AppActionSheetItem(
            text: RpType.lucky.title,
            value: RpType.lucky,
            enabled: current != RpType.lucky,
          ),
          AppActionSheetItem(
            text: RpType.normal.title,
            value: RpType.normal,
            enabled: current != RpType.normal,
          ),
          AppActionSheetItem(
            text: RpType.exclusive.title,
            value: RpType.exclusive,
            enabled: current != RpType.exclusive,
          ),
        ],
      );

      if (!mounted || ret == null) return;
      ctl.setType(ret);
      if (ret == RpType.exclusive) {
        cntCtrl.clear();
      } else if (!ctl.isGroup && cntCtrl.text.isEmpty) {
        cntCtrl.text = '1';
      }
    } catch (_) {
      _toast(AppI18n.of(context).t(
        zhHans: '打开失败，请重试',
        zhHant: '開啟失敗，請重試',
        en: 'Failed to open. Please try again.',
        ja: '開けませんでした。もう一度お試しください。',
        ko: '열기에 실패했습니다. 다시 시도해 주세요.',
      ));
    } finally {
      if (mounted) _sheetOpen = false;
    }
  }

  /// 支付弹窗内点击「更改」：直接打开付款方式选择，切换 99币 / USDT 后
  /// 回传最新展示数据，让支付弹窗原地刷新（不关闭密码弹窗）。
  Future<PayMethodDisplay?> _changePayInline() async {
    final ret = await showAdaptiveModalSheet<WalletPayMethodDto>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.55),
      builder: (_) => WalletPayMethodSheet(
        items: ctl.pays,
        sel: ctl.pay,
      ),
    );
    if (!mounted || ret == null) return null;
    ctl.setPay(ret);
    return PayMethodDisplay(
      amountText: '${ctl.totalDisplayText} ${ctl.pay.coin}',
      amountCoin: ctl.pay.coin,
      payText: '${ctl.pay.coin} ${ctl.pay.net}',
      payCoinCode: ctl.pay.id,
      payLogoUrl: ctl.pay.logoUrl,
      walletSubtitle: '${ctl.pay.bal} ${ctl.pay.coin}',
    );
  }

  Future<void> _choosePay() async {
    if (_sheetOpen || ctl.isBusy) return;

    _sheetOpen = true;
    try {
      final ret = await showAdaptiveModalSheet<WalletPayMethodDto>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        barrierColor: Colors.black.withValues(alpha: 0.55),
        builder: (_) => WalletPayMethodSheet(
          items: ctl.pays,
          sel: ctl.pay,
        ),
      );

      if (!mounted || ret == null) return;
      ctl.setPay(ret);
    } catch (_) {
      _toast(AppI18n.of(context).t(
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
        _toast(AppI18n.of(context).t(
          zhHans: '暂无可选择成员',
          zhHant: '暫無可選擇成員',
          en: 'No members available to select.',
          ja: '選択できるメンバーがいません。',
          ko: '선택할 수 있는 멤버가 없습니다.',
        ));
        return;
      }

      final ret = await pickRedPacketMember(
        context,
        members: members,
      );
      if (!mounted || ret == null) return;
      ctl.setReceiver(ret);
    } catch (_) {
      _toast(AppI18n.of(context).t(
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

  Future<void> _submit() async {
    if (_sheetOpen || ctl.isBusy) return;

    final msg = ctl.check();
    if (msg != null) {
      _toast(msg);
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
          zhHans: '红包',
          zhHant: '紅包',
          en: 'Red Packet',
          ja: '紅包',
          ko: '홍바오',
        ),
        amountText: '${ctl.totalDisplayText} ${ctl.pay.coin}',
        amountCoin: ctl.pay.coin,
        payText: '${ctl.pay.coin} ${ctl.pay.net}',
        payCoinCode: ctl.pay.id,
        payLogoUrl: ctl.pay.logoUrl,
        onChangePayMethod: _changePayInline,
        receiverName: ctl.receiverName.isNotEmpty
            ? ctl.receiverName
            : widget.receiverName,
        receiverId:
            ctl.receiverId.isNotEmpty ? ctl.receiverId : widget.receiverId,
        receiverAvatar: ctl.receiverAvatar,
        walletSubtitle: '${ctl.pay.bal} ${ctl.pay.coin}',
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
              zhHans: '红包已发出',
              zhHant: '紅包已發出',
              en: 'Red packet sent',
              ja: '紅包を送信しました',
              ko: '홍바오를 보냈습니다',
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
    final i18n = AppI18n.of(context);
    final cs = WalletPageColors.of(context);
    final appBar = WalletAppBarColors.of(context);

    return AnimatedBuilder(
      animation: ctl,
      builder: (_, __) {
        return wrapWalletPage(
          context,
          Scaffold(
            backgroundColor: cs.bg,
            resizeToAvoidBottomInset: true,
            appBar: AppBar(
              iconTheme: IconThemeData(color: appBar.icon),
              elevation: 0,
              scrolledUnderElevation: 0,
              surfaceTintColor: Colors.transparent,
              backgroundColor: appBar.background,
              foregroundColor: appBar.title,
              systemOverlayStyle: walletPageOverlayStyle(context),
              centerTitle: true,
              title: Text(
                ctl.isGroup
                    ? i18n.t(
                        zhHans: '发送红包',
                        zhHant: '發送紅包',
                        en: 'Send Red Packet',
                        ja: '紅包を送る',
                        ko: '레드패킷 보내기',
                      )
                    : i18n.t(
                        zhHans: '普通红包',
                        zhHant: '普通紅包',
                        en: 'Regular Red Packet',
                        ja: '通常の紅包',
                        ko: '일반 레드패킷',
                      ),
                style: TextStyle(
                  color: appBar.title,
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            body: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onTap: () => FocusScope.of(context).unfocus(),
              child: Stack(
                children: [
                  SingleChildScrollView(
                    padding: EdgeInsets.fromLTRB(32.w, 16.h, 32.w, 34.h),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (ctl.isGroup)
                          _GroupRedPacketSendLayout(
                            cs: cs,
                            i18n: i18n,
                            ctl: ctl,
                            cntCtrl: cntCtrl,
                            amtCtrl: amtCtrl,
                            msgCtrl: msgCtrl,
                            cntFocus: cntFocus,
                            amtFocus: amtFocus,
                            msgFocus: msgFocus,
                            sheetOpen: _sheetOpen,
                            onChooseType: _chooseType,
                            onChooseReceiver: _chooseReceiver,
                            onChoosePay: _choosePay,
                            onSubmit: _submit,
                          )
                        else ...[
                          _AmtRow(
                            cs: cs,
                            ctl: ctl,
                            ctrl: amtCtrl,
                            focusNode: amtFocus,
                          ),
                          SizedBox(height: 24.h),
                          _MsgRow(
                            cs: cs,
                            ctrl: msgCtrl,
                            focusNode: msgFocus,
                          ),
                          SizedBox(height: 52.h),
                          Text(
                            i18n.t(
                              zhHans: '付款方式',
                              zhHant: '付款方式',
                              en: 'Payment Method',
                              ja: '支払い方法',
                              ko: '결제 수단',
                            ),
                            style: TextStyle(
                              fontSize: 22.sp,
                              color: cs.subText,
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                          SizedBox(height: 24.h),
                          _PayCard(
                            cs: cs,
                            ctl: ctl,
                            onTap: _choosePay,
                          ),
                          SizedBox(height: 110.h),
                          Center(
                            child: Text.rich(
                              TextSpan(
                                children: [
                                  TextSpan(
                                    text: ctl.totalDisplayText,
                                    style: TextStyle(
                                      fontSize: 78.sp,
                                      color: cs.text,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                  TextSpan(
                                    text: ' ${ctl.pay.coin}',
                                    style: TextStyle(
                                      fontSize: 46.sp,
                                      color: cs.text,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          SizedBox(height: 34.h),
                          _SendBtn(
                            cs: cs,
                            enabled: ctl.canPay && !_sheetOpen,
                            onTap: _submit,
                          ),
                          SizedBox(height: 150.h),
                          Center(
                            child: Text(
                              i18n.t(
                                zhHans: '未领取的红包，将于24小时后发起退款',
                                zhHant: '未領取的紅包，將於24小時後發起退款',
                                en: 'Unclaimed red packets will be refunded after 24 hours.',
                                ja: '未受取の紅包は24時間後に返金されます。',
                                ko: '수령하지 않은 레드패킷은 24시간 후 환불됩니다.',
                              ),
                              style: TextStyle(
                                fontSize: 26.sp,
                                color: cs.subText,
                                fontWeight: FontWeight.w400,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

BoxDecoration _rpFieldDecoration(WalletPageColors cs) {
  return BoxDecoration(
    color: cs.card,
    borderRadius: BorderRadius.circular(12.r),
  );
}

TextStyle _rpFieldLabelStyle(WalletPageColors cs) => TextStyle(
      fontSize: 30.sp,
      color: cs.text,
      fontWeight: FontWeight.w600,
      height: 1.2,
    );

TextStyle _rpFieldInputStyle(WalletPageColors cs) => TextStyle(
      fontSize: 32.sp,
      color: cs.text,
      fontWeight: FontWeight.w500,
      height: 1.2,
    );

TextStyle _rpFieldHintStyle(WalletPageColors cs) => TextStyle(
      fontSize: 32.sp,
      color: cs.inputHint,
      fontWeight: FontWeight.w400,
      height: 1.2,
    );

class _GroupRedPacketSendLayout extends StatelessWidget {
  final WalletPageColors cs;
  final AppI18n i18n;
  final RedPacketController ctl;
  final TextEditingController cntCtrl;
  final TextEditingController amtCtrl;
  final TextEditingController msgCtrl;
  final FocusNode cntFocus;
  final FocusNode amtFocus;
  final FocusNode msgFocus;
  final bool sheetOpen;
  final VoidCallback onChooseType;
  final VoidCallback onChooseReceiver;
  final VoidCallback onChoosePay;
  final VoidCallback onSubmit;

  const _GroupRedPacketSendLayout({
    required this.cs,
    required this.i18n,
    required this.ctl,
    required this.cntCtrl,
    required this.amtCtrl,
    required this.msgCtrl,
    required this.cntFocus,
    required this.amtFocus,
    required this.msgFocus,
    required this.sheetOpen,
    required this.onChooseType,
    required this.onChooseReceiver,
    required this.onChoosePay,
    required this.onSubmit,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, box) {
        final viewport = MediaQuery.sizeOf(context);
        final availableWidth =
            box.maxWidth.isFinite ? box.maxWidth : viewport.width - 64.w;
        final metrics = _GroupSendMetrics.from(
          Size(availableWidth, viewport.height),
        );

        return SingleChildScrollView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: EdgeInsets.only(bottom: metrics.bottomPadding),
          child: Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: metrics.maxWidth),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _TypeLine(
                    cs: cs,
                    ctl: ctl,
                    onTap: onChooseType,
                  ),
                  SizedBox(height: metrics.typeGap),
                  if (ctl.type == RpType.exclusive)
                    _ReceiverRow(
                      cs: cs,
                      name: ctl.receiverName,
                      avatar: ctl.receiverAvatar,
                      enabled: true,
                      onTap: onChooseReceiver,
                    )
                  else ...[
                    _CntRow(
                      cs: cs,
                      ctl: ctl,
                      ctrl: cntCtrl,
                      focusNode: cntFocus,
                    ),
                    if (ctl.groupNum.isNotEmpty)
                      Padding(
                        padding: EdgeInsets.only(
                          left: metrics.groupHintInset,
                          top: metrics.groupHintTop,
                        ),
                        child: Text(
                          i18n.format(
                            zhHans: '本群共{count}人',
                            zhHant: '本群共{count}人',
                            en: '{count} members in this group',
                            ja: 'このグループは{count}人',
                            ko: '이 그룹 {count}명',
                            vars: {'count': ctl.groupNum},
                          ),
                          style: TextStyle(
                            fontSize: metrics.hintText,
                            color: cs.subText,
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                      ),
                  ],
                  SizedBox(height: metrics.fieldGap),
                  _AmtRow(
                    cs: cs,
                    ctl: ctl,
                    ctrl: amtCtrl,
                    focusNode: amtFocus,
                  ),
                  SizedBox(height: metrics.fieldGap),
                  _MsgRow(
                    cs: cs,
                    ctrl: msgCtrl,
                    focusNode: msgFocus,
                  ),
                  SizedBox(height: metrics.payGap),
                  _PayCard(
                    cs: cs,
                    ctl: ctl,
                    onTap: onChoosePay,
                  ),
                  SizedBox(height: metrics.totalGap),
                  Center(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text.rich(
                        TextSpan(
                          children: [
                            TextSpan(
                              text: ctl.totalDisplayText,
                              style: TextStyle(
                                fontSize: metrics.totalText,
                                color: cs.text,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            TextSpan(
                              text: ' ${ctl.pay.coin}',
                              style: TextStyle(
                                fontSize: metrics.coinText,
                                color: cs.text,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  SizedBox(height: metrics.buttonGap),
                  Center(
                    child: SizedBox(
                      width: metrics.buttonWidth,
                      child: _SendBtn(
                        cs: cs,
                        enabled: ctl.canPay && !sheetOpen,
                        onTap: onSubmit,
                      ),
                    ),
                  ),
                  SizedBox(height: metrics.noticeGap),
                  Center(
                    child: Text(
                      i18n.t(
                        zhHans: '未领取的红包，将于24小时后发起退款',
                        zhHant: '未領取的紅包，將於24小時後發起退款',
                        en: 'Unclaimed red packets will be refunded after 24 hours.',
                        ja: '未受取の紅包は24時間後に返金されます。',
                        ko: '수령하지 않은 레드패킷은 24시간 후 환불됩니다.',
                      ),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: metrics.noticeText,
                        color: cs.subText,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _GroupSendMetrics {
  const _GroupSendMetrics({
    required this.maxWidth,
    required this.typeGap,
    required this.fieldGap,
    required this.payGap,
    required this.totalGap,
    required this.buttonGap,
    required this.noticeGap,
    required this.groupHintInset,
    required this.groupHintTop,
    required this.hintText,
    required this.totalText,
    required this.coinText,
    required this.buttonWidth,
    required this.noticeText,
    required this.bottomPadding,
  });

  final double maxWidth;
  final double typeGap;
  final double fieldGap;
  final double payGap;
  final double totalGap;
  final double buttonGap;
  final double noticeGap;
  final double groupHintInset;
  final double groupHintTop;
  final double hintText;
  final double totalText;
  final double coinText;
  final double buttonWidth;
  final double noticeText;
  final double bottomPadding;

  factory _GroupSendMetrics.from(Size size) {
    final width = size.width;
    final height = size.height;
    final shortest = math.min(width, height);
    final maxWidth = width > 720 ? math.min(width * 0.62, 560.0) : width;

    double byH(double value, double min, double max) {
      return (height * value).clamp(min, max).toDouble();
    }

    double byW(double value, double min, double max) {
      return (maxWidth * value).clamp(min, max).toDouble();
    }

    return _GroupSendMetrics(
      maxWidth: maxWidth,
      typeGap: byH(0.01, 8.h, 16.h),
      fieldGap: byH(0.02, 14.h, 24.h),
      payGap: byH(0.024, 18.h, 30.h),
      totalGap: byH(0.09, 58.h, 100.h),
      buttonGap: byH(0.04, 28.h, 44.h),
      noticeGap: byH(0.065, 44.h, 80.h),
      groupHintInset: byW(0.045, 18.w, 28.w),
      groupHintTop: byH(0.012, 8.h, 14.h),
      hintText: (shortest * 0.042).clamp(18.sp, 24.sp).toDouble(),
      totalText: (shortest * 0.14).clamp(64.sp, 86.sp).toDouble(),
      coinText: (shortest * 0.082).clamp(36.sp, 52.sp).toDouble(),
      buttonWidth: maxWidth * (width > 720 ? 0.56 : 0.52),
      noticeText: (shortest * 0.042).clamp(18.sp, 24.sp).toDouble(),
      bottomPadding: byH(0.035, 20.h, 36.h),
    );
  }
}

class _TypeLine extends StatelessWidget {
  final WalletPageColors cs;
  final RedPacketController ctl;
  final VoidCallback onTap;

  const _TypeLine({
    required this.cs,
    required this.ctl,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10.r),
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 5.h),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                ctl.type.title,
                style: TextStyle(
                  fontSize: 28.sp,
                  color: const Color(0xFFC26A18),
                  fontWeight: FontWeight.w500,
                ),
              ),
              SizedBox(width: 6.w),
              Icon(
                Icons.keyboard_arrow_down_rounded,
                color: const Color(0xFFC26A18),
                size: 34.sp,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CntRow extends StatelessWidget {
  final WalletPageColors cs;
  final RedPacketController ctl;
  final TextEditingController ctrl;
  final FocusNode focusNode;

  const _CntRow({
    required this.cs,
    required this.ctl,
    required this.ctrl,
    required this.focusNode,
  });

  @override
  Widget build(BuildContext context) {
    final i18n = AppI18n.of(context);
    return _InputBox(
      cs: cs,
      left: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 28.w,
            height: 34.w,
            decoration: BoxDecoration(
              color: const Color(0xFFC63D28),
              borderRadius: BorderRadius.circular(3.r),
            ),
            child: Align(
              alignment: Alignment.topRight,
              child: Container(
                width: 8.w,
                height: 8.w,
                margin: EdgeInsets.only(top: 5.h, right: 5.w),
                decoration: const BoxDecoration(
                  color: Color(0xFFE7C06E),
                  shape: BoxShape.circle,
                ),
              ),
            ),
          ),
          SizedBox(width: 20.w),
          Text(
            i18n.t(
              zhHans: '红包个数',
              zhHant: '紅包個數',
              en: 'Number of Packets',
              ja: '紅包の数',
              ko: '레드패킷 개수',
            ),
            style: _rpFieldLabelStyle(cs),
          ),
        ],
      ),
      right: Row(
        mainAxisSize: MainAxisSize.max,
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Flexible(
            child: WalletPlainTextInput(
              controller: ctrl,
              focusNode: focusNode,
              textAlign: TextAlign.right,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              minTapHeight: 104.h,
              style: _rpFieldInputStyle(cs),
              hintStyle: _rpFieldHintStyle(cs),
              cursorColor: cs.inputCursor,
              hint: i18n.t(
                zhHans: '填写红包个数',
                zhHant: '填寫紅包個數',
                en: 'Enter number of packets',
                ja: '紅包の数を入力',
                ko: '레드패킷 개수 입력',
              ),
            ),
          ),
          SizedBox(width: 8.w),
          Text(
            i18n.t(
              zhHans: '个',
              zhHant: '個',
              en: '',
              ja: '個',
              ko: '개',
            ),
            style: _rpFieldLabelStyle(cs),
          ),
        ],
      ),
    );
  }
}

class _ReceiverRow extends StatelessWidget {
  final WalletPageColors cs;
  final String name;
  final String avatar;
  final bool enabled;
  final VoidCallback onTap;

  const _ReceiverRow({
    required this.cs,
    required this.name,
    required this.avatar,
    required this.enabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final i18n = AppI18n.of(context);
    final showName = name.trim().isEmpty
        ? i18n.t(
            zhHans: '请选择接收人',
            zhHant: '請選擇接收人',
            en: 'Select a recipient',
            ja: '受取人を選択',
            ko: '수령인 선택',
          )
        : name;

    return InkWell(
      onTap: enabled ? onTap : null,
      borderRadius: BorderRadius.circular(16.r),
      child: _InputBox(
        cs: cs,
        left: Text(
          i18n.t(
            zhHans: '发给谁',
            zhHant: '發給誰',
            en: 'Send To',
            ja: '送信先',
            ko: '보낼 사람',
          ),
          style: _rpFieldLabelStyle(cs),
        ),
        right: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(23.r),
              child: Container(
                width: 46.w,
                height: 46.w,
                color: cs.avatarPlaceholder,
                child: avatar.trim().isEmpty
                    ? Icon(
                        Icons.person_rounded,
                        size: 28.sp,
                        color: cs.avatarIcon,
                      )
                    : Image.network(
                        avatar,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Icon(
                          Icons.person_rounded,
                          size: 28.sp,
                          color: cs.avatarIcon,
                        ),
                      ),
              ),
            ),
            SizedBox(width: 14.w),
            Expanded(
              child: Text(
                showName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: _rpFieldInputStyle(cs).copyWith(
                  fontSize: 28.sp,
                  color: name.trim().isEmpty ? cs.inputHint : cs.text,
                ),
              ),
            ),
            if (enabled) ...[
              SizedBox(width: 10.w),
              Icon(
                Icons.chevron_right_rounded,
                size: 34.sp,
                color: cs.subText,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _AmtRow extends StatelessWidget {
  final WalletPageColors cs;
  final RedPacketController ctl;
  final TextEditingController ctrl;
  final FocusNode focusNode;

  const _AmtRow({
    required this.cs,
    required this.ctl,
    required this.ctrl,
    required this.focusNode,
  });

  @override
  Widget build(BuildContext context) {
    return _InputBox(
      cs: cs,
      left: Text(
        ctl.type.amtLabel,
        style: _rpFieldLabelStyle(cs),
      ),
      right: WalletAmountInput(
        controller: ctrl,
        focusNode: focusNode,
        textAlign: TextAlign.right,
        scale: ctl.pay.scale,
        maxInt: 12,
        hint: '0',
        fontSize: 32,
        useSp: true,
        fontWeight: FontWeight.w500,
        color: cs.text,
        hintColor: cs.inputHint,
        cursorColor: cs.inputCursor,
        minTapHeight: 104.h,
        expandWidth: true,
      ),
    );
  }
}

class _MsgRow extends StatelessWidget {
  final WalletPageColors cs;
  final TextEditingController ctrl;
  final FocusNode focusNode;

  const _MsgRow({
    required this.cs,
    required this.ctrl,
    required this.focusNode,
  });

  @override
  Widget build(BuildContext context) {
    final i18n = AppI18n.of(context);
    return Container(
      height: 104.h,
      padding: EdgeInsets.symmetric(horizontal: 20.w),
      alignment: Alignment.centerLeft,
      decoration: _rpFieldDecoration(cs),
      child: WalletPlainTextInput(
        controller: ctrl,
        focusNode: focusNode,
        maxLength: kRedPacketBlessingMaxLength,
        maxLengthEnforcement: MaxLengthEnforcement.enforced,
        minTapHeight: 104.h,
        style: _rpFieldInputStyle(cs).copyWith(
          fontSize: 30.sp,
          fontWeight: FontWeight.w500,
        ),
        hintStyle: _rpFieldHintStyle(cs).copyWith(
          fontSize: 30.sp,
        ),
        cursorColor: cs.inputCursor,
        inputFormatters: [
          LengthLimitingTextInputFormatter(kRedPacketBlessingMaxLength),
        ],
        hint: i18n.t(
          zhHans: '恭喜发财，大吉大利',
          zhHant: '恭喜發財，大吉大利',
          en: 'Best wishes and good fortune.',
          ja: 'ご多幸をお祈りします。',
          ko: '행운과 복이 함께하시길 바랍니다.',
        ),
      ),
    );
  }
}

class _PayCard extends StatelessWidget {
  final WalletPageColors cs;
  final RedPacketController ctl;
  final VoidCallback onTap;

  const _PayCard({
    required this.cs,
    required this.ctl,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final i18n = AppI18n.of(context);
    final pay = ctl.pay;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16.r),
      child: Container(
        height: 132.h,
        padding: EdgeInsets.symmetric(horizontal: 22.w),
        decoration: BoxDecoration(
          color: cs.card,
          borderRadius: BorderRadius.circular(12.r),
        ),
        child: Row(
          children: [
            WalletPayCoinIcon(item: pay, size: 74.w),
            SizedBox(width: 24.w),
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
                    style: TextStyle(
                      fontSize: 27.sp,
                      color: cs.text,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  SizedBox(height: 12.h),
                  Text(
                    '${pay.bal} ${pay.coin}',
                    style: TextStyle(
                      fontSize: 27.sp,
                      color: cs.text,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
            Text(
              i18n.t(
                zhHans: '更换',
                zhHant: '更換',
                en: 'Change',
                ja: '変更',
                ko: '변경',
              ),
              style: TextStyle(
                fontSize: 24.sp,
                color: cs.subText,
                fontWeight: FontWeight.w400,
              ),
            ),
            SizedBox(width: 4.w),
            Icon(
              Icons.chevron_right_rounded,
              size: 34.sp,
              color: cs.subText,
            ),
          ],
        ),
      ),
    );
  }
}

class _InputBox extends StatelessWidget {
  final WalletPageColors cs;
  final Widget left;
  final Widget right;

  const _InputBox({
    required this.cs,
    required this.left,
    required this.right,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 104.h,
      padding: EdgeInsets.symmetric(horizontal: 20.w),
      decoration: _rpFieldDecoration(cs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          left,
          Expanded(
            child: Align(
              alignment: Alignment.centerRight,
              child: right,
            ),
          ),
        ],
      ),
    );
  }
}

class _SendBtn extends StatelessWidget {
  final WalletPageColors cs;
  final bool enabled;
  final VoidCallback onTap;

  const _SendBtn({
    required this.cs,
    required this.enabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final i18n = AppI18n.of(context);
    return Opacity(
      opacity: enabled ? 1 : 0.58,
      child: GestureDetector(
        onTap: enabled ? onTap : null,
        child: Container(
          width: double.infinity,
          height: 84.h,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: cs.red,
            borderRadius: BorderRadius.circular(12.r),
          ),
          child: Text(
            i18n.t(
              zhHans: '塞钱进红包',
              zhHant: '塞錢進紅包',
              en: 'Send Red Packet',
              ja: '紅包を送る',
              ko: '레드패킷 보내기',
            ),
            style: TextStyle(
              fontSize: 32.sp,
              color: Colors.white,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ),
    );
  }
}
