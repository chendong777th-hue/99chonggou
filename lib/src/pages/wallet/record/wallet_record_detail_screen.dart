import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:intl/intl.dart';
import 'package:tencent_chat_i18n_tool/language_json/strings.g.dart';

import 'package:tencent_cloud_chat_demo/src/api/wallet_amount.dart';
import 'package:tencent_cloud_chat_demo/src/api/wallet_api.dart';
import 'package:tencent_cloud_chat_demo/src/api/wallet_models.dart';
import 'package:tencent_cloud_chat_demo/src/api/wallet_time.dart';
import 'package:tencent_cloud_chat_demo/src/i18n/app_i18n.dart';

import 'package:tencent_cloud_chat_demo/src/platform/clipboard_guard.dart';
import 'package:tencent_cloud_chat_demo/utils/toast.dart';

import '../order/wallet_card_im_sender.dart';
import '../order/wallet_card_replay_guard.dart';
import '../order/wallet_card_send_service.dart';
import '../order/wallet_order.dart';
import '../order/wallet_pending_recovery_service.dart';
import '../order/wallet_pending_store.dart';
import '../widgets/wallet_page_colors.dart';
import 'wallet_record_models.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_user_full_info.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_user_full_info.dart';
import 'package:tencent_cloud_chat_sdk/tencent_im_sdk_plugin.dart';


class WalletRecordDetailScreen extends StatefulWidget {
  final WalletRecordDto item;

  const WalletRecordDetailScreen({
    super.key,
    required this.item,
  });

  @override
  State<WalletRecordDetailScreen> createState() =>
      _WalletRecordDetailScreenState();
}

class _WalletRecordDetailScreenState extends State<WalletRecordDetailScreen> {
  final WalletCardSendService _cardSvc = WalletCardSendService();
  WalletOrderDraft? _cardFail;
  WalletOrderDraft? _localDraft;
  bool _refreshingOrder = false;
  WalletMe? _walletMe;
  List<Map<String, dynamic>> _claims = const [];
  Map<String, V2TimUserFullInfo> _claimProfiles = const {};

  @override
  void initState() {
    super.initState();
    _loadWalletMe();
    _loadLocalDraft();
    _loadCardFail();
    _loadClaims();
  }

  Future<void> _loadLocalDraft() async {
    final items = await WalletPendingStore().load();
    final keys = <String>{
      widget.item.serverOrderId,
      widget.item.clientOrderId,
      widget.item.orderNo,
    }.map((e) => e.trim()).where((e) => e.isNotEmpty && e != '--').toSet();
    WalletOrderDraft? found;
    for (final draft in items) {
      final ids = <String>{
        draft.clientOrderId.trim(),
        draft.serverOrderId.trim(),
      }..removeWhere((e) => e.isEmpty || e == '--');
      if (ids.any(keys.contains)) {
        found = draft;
        break;
      }
    }
    if (!mounted) return;
    setState(() => _localDraft = found);
  }

  Future<void> _refreshOrderStatus() async {
    if (_refreshingOrder) return;
    setState(() => _refreshingOrder = true);
    try {
      await WalletPendingRecoveryService.instance.recover(
        reason: 'record_detail_refresh',
        force: true,
      );
      await _loadLocalDraft();
      await _loadCardFail();
    } finally {
      if (mounted) setState(() => _refreshingOrder = false);
    }
  }

  bool get _showOrderRefresh {
    if (_localDraft?.needsOrderStatusQuery == true) return true;
    return widget.item.status == WalletRecordStatus.pending;
  }

  Future<void> _loadWalletMe() async {
    try {
      final me = await WalletApi.instance.getMe();
      if (!mounted) return;
      setState(() {
        _walletMe = me;
      });
    } catch (_) {}
  }

  Future<void> _loadClaims() async {
    if (widget.item.type != WalletRecordType.redPacket) return;
    final orderId = widget.item.serverOrderId.isNotEmpty
        ? widget.item.serverOrderId
        : widget.item.orderNo;
    if (orderId.isEmpty) return;
    try {
      final claims = await WalletApi.instance.getRedPacketClaims(orderId);
      final profiles = await _loadClaimProfiles(claims);
      if (!mounted) return;
      setState(() {
        _claims = claims;
        _claimProfiles = profiles;
      });
    } catch (_) {}
  }

  Future<Map<String, V2TimUserFullInfo>> _loadClaimProfiles(
    List<Map<String, dynamic>> claims,
  ) async {
    final ids = <String>{};
    for (final claim in claims) {
      final userId = claim['userId']?.toString().trim() ?? '';
      if (userId.isNotEmpty) ids.add(userId);
    }
    if (ids.isEmpty) return const {};
    final map = <String, V2TimUserFullInfo>{};
    try {
      final res = await TencentImSDKPlugin.v2TIMManager
          .getUsersInfo(userIDList: ids.toList());
      for (final info in res.data ?? <V2TimUserFullInfo>[]) {
        final userId = info.userID?.trim() ?? '';
        if (userId.isNotEmpty) map[userId] = info;
      }
    } catch (_) {}
    return map;
  }

  Future<void> _loadCardFail() async {
    final draft = await _cardSvc.pendingCardForOrderKeys([
      widget.item.serverOrderId,
      widget.item.clientOrderId,
      widget.item.orderNo,
    ]);
    if (!mounted) return;
    setState(() {
      _cardFail = draft;
    });
  }

  Future<void> _retryCard() async {
    final draft = _cardFail;
    if (draft == null) return;

    final payload =
        await _cardSvc.resetForManualSendByClientId(draft.clientOrderId);
    if (!mounted) return;

    if (payload == null) {
      _toast(AppI18n.current.t(
        zhHans: '没有找到可重发的钱包消息',
        zhHant: '沒有找到可重新發送的錢包訊息',
        en: 'No wallet message is available for resending.',
        ja: '再送信できるウォレットメッセージが見つかりません。',
        ko: '다시 보낼 수 있는 지갑 메시지가 없습니다.',
      ));
      await _loadCardFail();
      return;
    }

    await WalletCardImSender.instance.sendAfterRest(
      payload,
      source: WalletCardSendSource.manual,
    );
    _toast(AppI18n.current.t(
      zhHans: '已加入重新发送队列',
      zhHant: '已加入重新發送佇列',
      en: 'Added to the resend queue.',
      ja: '再送信キューに追加しました。',
      ko: '재전송 대기열에 추가되었습니다.',
    ));
    await _loadCardFail();
  }

  Future<void> _ignoreCardFail() async {
    final draft = _cardFail;
    if (draft == null) return;

    final ok = await _cardSvc.ignoreCardFail(draft.clientOrderId);
    if (!mounted) return;

    if (ok) {
      setState(() {
        _cardFail = null;
      });
      _toast(AppI18n.current.t(
        zhHans: '已忽略本次消息发送失败',
        zhHant: '已忽略本次訊息發送失敗',
        en: 'This failed wallet message has been ignored.',
        ja: '今回の送信失敗は無視されました。',
        ko: '이번 지갑 메시지 전송 실패를 무시했습니다.',
      ));
    } else {
      _toast(AppI18n.current.t(
        zhHans: '处理失败，请重试',
        zhHant: '處理失敗，請重試',
        en: 'Operation failed. Please try again.',
        ja: '処理に失敗しました。もう一度お試しください。',
        ko: '처리에 실패했습니다. 다시 시도해 주세요.',
      ));
    }
  }

  void _toast(String txt) {
    ToastUtils.toastForce(txt);
  }

  String _formatShort(String value) {
    final v = value.trim();
    if (v.isEmpty) return '--';
    if (v.length <= 18) return v;
    return '${v.substring(0, 8)}...${v.substring(v.length - 8)}';
  }

  DateTime? _parseTime(String raw) => parseWalletApiTimeToLocal(raw);

  String get _formattedDetailTime {
    final parsed = _parseTime(widget.item.time);
    if (parsed == null) {
      return widget.item.time.trim().isEmpty ? '--' : widget.item.time.trim();
    }
    final locale = LocaleSettings.currentLocale;
    final tag = locale.languageTag;
    final lang = tag.startsWith('zh')
        ? 'zh_CN'
        : locale == AppLocale.ja
            ? 'ja'
            : locale == AppLocale.ko
                ? 'ko'
                : 'en';
    final pattern = tag.startsWith('en')
        ? 'MMM d, yyyy HH:mm'
        : locale == AppLocale.ja
            ? 'yyyy/MM/dd HH:mm'
            : locale == AppLocale.ko
                ? 'yyyy.MM.dd HH:mm'
                : 'yyyy年M月d日 HH:mm';
    return DateFormat(pattern, lang).format(parsed);
  }

  String get _detailStatusText {
    final item = widget.item;
    switch (item.status) {
      case WalletRecordStatus.success:
        return item.income
            ? AppI18n.current.t(
                zhHans: '已收到',
                zhHant: '已收到',
                en: 'Received',
                ja: '受取済み',
                ko: '수령 완료',
              )
            : AppI18n.current.t(
                zhHans: '已发出',
                zhHant: '已發出',
                en: 'Sent',
                ja: '送信済み',
                ko: '전송 완료',
              );
      case WalletRecordStatus.pending:
        return item.income
            ? AppI18n.current.t(
                zhHans: '确认中',
                zhHant: '確認中',
                en: 'Confirming',
                ja: '確認中',
                ko: '확인 중',
              )
            : AppI18n.current.t(
                zhHans: '处理中',
                zhHant: '處理中',
                en: 'Processing',
                ja: '処理中',
                ko: '처리 중',
              );
      case WalletRecordStatus.failed:
        return AppI18n.current.t(
          zhHans: '失败',
          zhHant: '失敗',
          en: 'Failed',
          ja: '失敗',
          ko: '실패',
        );
    }
  }

  String get _networkTitle {
    final raw = widget.item.network.trim();
    if (raw.toUpperCase().contains('TRC20') ||
        raw.toUpperCase().contains('TRON') ||
        widget.item.coin.toUpperCase() == 'TRX') {
      return 'Tron';
    }
    if (raw.isEmpty) return '--';
    return raw;
  }

  bool get _showTronNetworkIcon => _networkTitle == 'Tron';

  String get _incomingLabel {
    return widget.item.isChainDeposit
        ? AppI18n.current.t(
            zhHans: '收款地址',
            zhHant: '收款地址',
            en: 'Receiving Address',
            ja: '受取アドレス',
            ko: '수령 주소',
          )
        : AppI18n.current.t(
            zhHans: '转入地址',
            zhHant: '轉入地址',
            en: 'Incoming Address',
            ja: '入金先アドレス',
            ko: '입금 주소',
          );
  }

  String get _incomingValue {
    final item = widget.item;
    final isWithdraw = item.title == '提现';
    final isDeposit = item.title == '链上充值';
    final isTransfer = item.title == '收到转账' || item.title == '发起转账';
    final candidates = isWithdraw
        ? <String>[item.addr, item.payee]
        : isDeposit
            ? <String>[item.addr, item.payee]
            : isTransfer
                ? <String>[item.payee, item.addr]
                : <String>[item.addr, item.payee, item.payer];
    final v = candidates.map((e) => e.trim()).firstWhere(
          (e) => e.isNotEmpty && e != '--' && e != '外部地址' && e != '我的钱包',
          orElse: () => '--',
        );
    return v;
  }

  String get _outgoingValue {
    final item = widget.item;
    final isWithdraw = item.title == '提现';
    final isDeposit = item.title == '链上充值';
    final isTransfer = item.title == '收到转账' || item.title == '发起转账';
    final candidates = isWithdraw
        ? <String>[item.payer, '我的钱包']
        : isDeposit
            ? <String>[item.payer]
            : isTransfer
                ? <String>[item.payer, item.payee]
                : <String>[item.payer, item.addr, item.payee];
    final v = candidates.map((e) => e.trim()).firstWhere(
          (e) => e.isNotEmpty && e != '--' && e != '外部地址',
          orElse: () => '--',
        );
    return v;
  }

  String get _hashValue {
    final hash = widget.item.hash.trim();
    return hash.isEmpty ? '--' : hash;
  }

  String get _orderNoValue {
    final orderNo = widget.item.orderNo.trim();
    return orderNo.isEmpty ? '--' : orderNo;
  }

  bool get _isSwapDetail => widget.item.isSwap;

  bool get _isPlatformTransferDetail {
    final item = widget.item;
    if (item.isChainDeposit || item.isChainWithdraw) {
      return false;
    }
    final title = item.title.trim().toLowerCase();
    return title.contains('转账') || title.contains('transfer');
  }

  bool get _showHashRow => _hashValue != '--' && !_isPlatformTransferDetail;

  bool get _showAddressRows => !_isSwapDetail;

  String get _referenceValue => _isSwapDetail ? _orderNoValue : _hashValue;

  bool get _showReferenceRow =>
      _isSwapDetail ? _orderNoValue != '--' : _showHashRow;

  bool get _isPlatformCoin {
    final coin = widget.item.coin.trim();
    return coin.toUpperCase() == '99' || coin == '元';
  }

  String get _fiatText {
    final amount = double.tryParse(widget.item.amount.replaceAll(',', '')) ?? 0;
    if (_isPlatformCoin) {
      final cnyPerUsdt = _walletMe?.exchangeRate?.effectiveCnyPerUsdt ??
          _walletMe?.usdtPrice?.cnyPerUsdt ??
          0;
      if (cnyPerUsdt <= 0) return '--';
      final usd = amount / cnyPerUsdt;
      final digits = usd >= 1 ? 4 : 6;
      return '≈\$${usd.toStringAsFixed(digits)}';
    }
    final digits = amount >= 1 ? 4 : 6;
    return '≈\$${amount.toStringAsFixed(digits)}';
  }

  Widget _buildAmountHeader(WalletPageColors cs) {
    if (!_isPlatformCoin) {
      return Text(
        '${widget.item.amount} ${widget.item.coin}',
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: 51.sp,
          fontWeight: FontWeight.w700,
          color: cs.text,
          height: 1.05,
        ),
      );
    }
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          widget.item.amount,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 51.sp,
            fontWeight: FontWeight.w700,
            color: cs.text,
            height: 1.05,
          ),
        ),
        SizedBox(width: 12.w),
        ClipOval(
          child: Image.asset(
            'assets/img/platform_99.webp',
            width: 42.w,
            height: 42.w,
            fit: BoxFit.cover,
          ),
        ),
      ],
    );
  }

  bool get _isRedPacket => widget.item.type == WalletRecordType.redPacket;

  bool get _showOrderTimelineSection {
    if (widget.item.isChainWithdraw) {
      return false;
    }
    return _localDraft != null || _showOrderRefresh;
  }

  @override
  Widget build(BuildContext context) {
    if (_isRedPacket) {
      return _buildRedPacketView(context);
    }

    return _buildAssetView(context);
  }

  Widget _buildAssetView(BuildContext context) {
    final item = widget.item;
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
            zhHans: '交易详情',
            zhHant: '交易詳情',
            en: 'Transaction Details',
            ja: '取引詳細',
            ko: '거래 상세',
          ),
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w600,
            color: appBar.title,
          ),
        ),
        actions: [
          if (_showOrderRefresh)
            IconButton(
              onPressed: _refreshingOrder ? null : _refreshOrderStatus,
              icon: _refreshingOrder
                  ? SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: appBar.icon,
                      ),
                    )
                  : Icon(Icons.refresh_rounded, color: appBar.icon),
            ),
          SizedBox(width: 6.w),
        ],
      ),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: EdgeInsets.fromLTRB(22.w, 24.h, 22.w, 24.h),
          children: [
            Center(
              child: _DetailCoinLogo(
                coin: item.coin,
                size: 111.w,
              ),
            ),
            SizedBox(height: 27.h),
            _buildAmountHeader(cs),
            SizedBox(height: 15.h),
            Text(
              _fiatText,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 24.sp,
                fontWeight: FontWeight.w400,
                color: cs.subText,
              ),
            ),
            SizedBox(height: 51.h),
            if (_showOrderTimelineSection) ...[
              _OrderTimeline(item: item, draft: _localDraft),
              SizedBox(height: 18.h),
            ],
            if (_cardFail != null) ...[
              _CardSendFailBox(
                draft: _cardFail!,
                onRetry: _retryCard,
                onIgnore: _ignoreCardFail,
              ),
              SizedBox(height: 18.h),
            ],
            _AssetDetailCard(
              cs: cs,
              children: [
                if (_showAddressRows) ...[
                  _AssetDetailRow(
                    cs: cs,
                    label: _incomingLabel,
                    value: _formatShort(_incomingValue),
                    copyValue: _incomingValue == '--' ? null : _incomingValue,
                  ),
                  _AssetDetailRow(
                    cs: cs,
                    label: i18n.t(
                      zhHans: '转出地址',
                      zhHant: '轉出地址',
                      en: 'Outgoing Address',
                      ja: '送信元アドレス',
                      ko: '출금 주소',
                    ),
                    value: _formatShort(_outgoingValue),
                    copyValue: _outgoingValue == '--' ? null : _outgoingValue,
                  ),
                ],
                _AssetDetailRow(
                  cs: cs,
                  label: i18n.t(
                    zhHans: '网络',
                    zhHant: '網路',
                    en: 'Network',
                    ja: 'ネットワーク',
                    ko: '네트워크',
                  ),
                  valueWidget: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    mainAxisSize: MainAxisSize.max,
                    children: [
                      if (_showTronNetworkIcon) ...[
                        _DetailCoinLogo(
                          coin: 'TRX',
                          size: 33.w,
                        ),
                        SizedBox(width: 12.w),
                      ],
                      Text(
                        _networkTitle,
                        style: TextStyle(
                          fontSize: 22.5.sp,
                          fontWeight: FontWeight.w500,
                          color: cs.text,
                        ),
                      ),
                    ],
                  ),
                ),
                _AssetDetailRow(
                  cs: cs,
                  label: i18n.t(
                    zhHans: '交易状态',
                    zhHant: '交易狀態',
                    en: 'Status',
                    ja: 'ステータス',
                    ko: '상태',
                  ),
                  value: _detailStatusText,
                ),
                if (_showReferenceRow)
                  _AssetDetailRow(
                    cs: cs,
                    label: i18n.t(
                      zhHans: _isSwapDetail ? '订单号' : '交易哈希',
                      zhHant: _isSwapDetail ? '訂單號' : '交易雜湊',
                      en: _isSwapDetail ? 'Order No.' : 'Transaction Hash',
                      ja: _isSwapDetail ? '注文番号' : 'トランザクションハッシュ',
                      ko: _isSwapDetail ? '주문 번호' : '거래 해시',
                    ),
                    value: _formatShort(_referenceValue),
                    copyValue: _referenceValue == '--' ? null : _referenceValue,
                  ),
                _AssetDetailRow(
                  cs: cs,
                  label: i18n.t(
                    zhHans: '交易时间',
                    zhHant: '交易時間',
                    en: 'Time',
                    ja: '取引時間',
                    ko: '거래 시간',
                  ),
                  value: _formattedDetailTime,
                  showDivider: false,
                ),
              ],
            ),
          ],
        ),
      ),
    ),
    );
  }

  String get _redPacketStatusText {
    final item = widget.item;
    final i18n = AppI18n.current;
    if (item.isRedPacketRefund) {
      return i18n.t(
        zhHans: '已退回',
        zhHant: '已退回',
        en: 'Refunded',
        ja: '返金済み',
        ko: '환불됨',
      );
    }
    switch (item.status) {
      case WalletRecordStatus.pending:
        return i18n.t(
          zhHans: '处理中',
          zhHant: '處理中',
          en: 'Processing',
          ja: '処理中',
          ko: '처리 중',
        );
      case WalletRecordStatus.failed:
        return i18n.t(
          zhHans: '失败',
          zhHant: '失敗',
          en: 'Failed',
          ja: '失敗',
          ko: '실패',
        );
      case WalletRecordStatus.success:
        if (item.isRedPacketReceive) {
          return i18n.t(
            zhHans: '已领取',
            zhHant: '已領取',
            en: 'Claimed',
            ja: '受取済み',
            ko: '수령 완료',
          );
        }
        return i18n.t(
          zhHans: '已发出',
          zhHant: '已發出',
          en: 'Sent',
          ja: '送信済み',
          ko: '전송 완료',
        );
    }
  }

  String _formatClaimTime(Map<String, dynamic> claim) {
    final text = formatWalletApiClaimListTime(parseWalletApiClaimTime(claim));
    return text == '--:--:--' ? '' : text;
  }

  Widget _buildRedPacketView(BuildContext context) {
    final item = widget.item;
    final i18n = AppI18n.of(context);
    final cs = WalletPageColors.of(context);
    final appBar = WalletAppBarColors.of(context);

    bool hasValue(String v) {
      final t = v.trim();
      return t.isNotEmpty && t != '--';
    }

    final rowBuilders = <Widget Function(bool isLast)>[];
    rowBuilders.add(
      (isLast) => _AssetDetailRow(
        cs: cs,
        label: i18n.t(
          zhHans: '交易状态',
          zhHant: '交易狀態',
          en: 'Status',
          ja: 'ステータス',
          ko: '상태',
        ),
        value: _redPacketStatusText,
        showDivider: !isLast,
      ),
    );
    if (!item.isRedPacketRefund && hasValue(item.rpType)) {
      rowBuilders.add(
        (isLast) => _AssetDetailRow(
          cs: cs,
          label: i18n.t(
            zhHans: '红包类型',
            zhHant: '紅包類型',
            en: 'Red Packet Type',
            ja: '紅包の種類',
            ko: '홍바오 유형',
          ),
          value: item.rpType,
          showDivider: !isLast,
        ),
      );
    }
    if (hasValue(item.rpCnt)) {
      rowBuilders.add(
        (isLast) => _AssetDetailRow(
          cs: cs,
          label: i18n.t(
            zhHans: '红包个数',
            zhHant: '紅包個數',
            en: 'Count',
            ja: '個数',
            ko: '개수',
          ),
          value: item.rpCnt,
          showDivider: !isLast,
        ),
      );
    }
    if (hasValue(item.rpTotal)) {
      rowBuilders.add(
        (isLast) => _AssetDetailRow(
          cs: cs,
          label: i18n.t(
            zhHans: '红包总额',
            zhHant: '紅包總額',
            en: 'Total',
            ja: '合計',
            ko: '총액',
          ),
          value: item.rpTotal,
          showDivider: !isLast,
        ),
      );
    }
    if (!item.isRedPacketRefund && hasValue(item.rpClaim)) {
      rowBuilders.add(
        (isLast) => _AssetDetailRow(
          cs: cs,
          label: i18n.t(
            zhHans: '已领取',
            zhHant: '已領取',
            en: 'Claimed',
            ja: '受取済み',
            ko: '수령 완료',
          ),
          value: item.rpClaim,
          showDivider: !isLast,
        ),
      );
    }
    if (hasValue(item.rpMsg) &&
        item.rpType.trim().toUpperCase() != 'GROUP_TRANSFER') {
      rowBuilders.add(
        (isLast) => _AssetDetailRow(
          cs: cs,
          label: i18n.t(
            zhHans: '祝福语',
            zhHant: '祝福語',
            en: 'Greeting',
            ja: 'メッセージ',
            ko: '축하 메시지',
          ),
          value: item.rpMsg,
          showDivider: !isLast,
        ),
      );
    }
    rowBuilders.add(
      (isLast) => _AssetDetailRow(
        cs: cs,
        label: i18n.t(
          zhHans: '交易时间',
          zhHant: '交易時間',
          en: 'Time',
          ja: '取引時間',
          ko: '거래 시간',
        ),
        value: _formattedDetailTime,
        showDivider: !isLast,
      ),
    );
    if (hasValue(item.orderNo)) {
      rowBuilders.add(
        (isLast) => _AssetDetailRow(
          cs: cs,
          label: i18n.t(
            zhHans: '订单号',
            zhHant: '訂單號',
            en: 'Order No.',
            ja: '注文番号',
            ko: '주문 번호',
          ),
          value: _formatShort(item.orderNo),
          copyValue: item.orderNo,
          showDivider: !isLast,
        ),
      );
    }

    final detailRows = <Widget>[
      for (var i = 0; i < rowBuilders.length; i++)
        rowBuilders[i](i == rowBuilders.length - 1),
    ];

    final claimRows = <Widget>[];
    for (var i = 0; i < _claims.length; i++) {
      final claim = _claims[i];
      final userId = claim['userId']?.toString().trim() ?? '';
      final nick = _claimProfiles[userId]?.nickName?.trim() ?? '';
      final displayName = nick.isNotEmpty
          ? nick
          : (userId.isNotEmpty
              ? userId
              : i18n.t(
                  zhHans: '未知用户',
                  zhHant: '未知用戶',
                  en: 'Unknown user',
                  ja: '不明なユーザー',
                  ko: '알 수 없는 사용자',
                ));
      final amountRaw = claim['amount'];
      final amountMinor = amountRaw is int
          ? amountRaw
          : int.tryParse(amountRaw?.toString() ?? '');
      final currency = item.coin.toUpperCase() == 'USDT'
          ? WalletCurrency.usdt
          : WalletCurrency.platform;
      final amountText = amountMinor == null
          ? '--'
          : '${formatWalletAmount(currency, amountMinor)} ${walletDisplayCoin(currency)}';
      final timeText = _formatClaimTime(claim);
      claimRows.add(
        _ClaimDetailRow(
          cs: cs,
          name: displayName,
          amount: amountText,
          time: timeText,
          showDivider: i != _claims.length - 1,
        ),
      );
    }

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
            zhHans: '交易详情',
            zhHant: '交易詳情',
            en: 'Transaction Details',
            ja: '取引詳細',
            ko: '거래 상세',
          ),
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w600,
            color: appBar.title,
          ),
        ),
        actions: [
          if (_showOrderRefresh)
            IconButton(
              onPressed: _refreshingOrder ? null : _refreshOrderStatus,
              icon: _refreshingOrder
                  ? SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: appBar.icon,
                      ),
                    )
                  : Icon(Icons.refresh_rounded, color: appBar.icon),
            ),
          SizedBox(width: 6.w),
        ],
      ),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: EdgeInsets.fromLTRB(22.w, 24.h, 22.w, 24.h),
          children: [
            Center(
              child: _DetailCoinLogo(
                coin: item.coin,
                size: 111.w,
              ),
            ),
            SizedBox(height: 27.h),
            _buildAmountHeader(cs),
            SizedBox(height: 15.h),
            Text(
              _fiatText,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 24.sp,
                fontWeight: FontWeight.w400,
                color: cs.subText,
              ),
            ),
            SizedBox(height: 51.h),
            if (_cardFail != null) ...[
              _CardSendFailBox(
                draft: _cardFail!,
                onRetry: _retryCard,
                onIgnore: _ignoreCardFail,
              ),
              SizedBox(height: 18.h),
            ],
            _AssetDetailCard(
              cs: cs,
              children: detailRows,
            ),
            if (claimRows.isNotEmpty) ...[
              SizedBox(height: 24.h),
              Padding(
                padding: EdgeInsets.only(left: 12.w, bottom: 12.h),
                child: Text(
                  i18n.t(
                    zhHans: '领取明细',
                    zhHant: '領取明細',
                    en: 'Claim Details',
                    ja: '受取明細',
                    ko: '수령 내역',
                  ),
                  style: TextStyle(
                    fontSize: 24.sp,
                    fontWeight: FontWeight.w500,
                    color: cs.subText,
                  ),
                ),
              ),
              _AssetDetailCard(
                cs: cs,
                children: claimRows,
              ),
            ],
          ],
        ),
      ),
    ),
    );
  }
}

class _AssetDetailCard extends StatelessWidget {
  final WalletPageColors cs;
  final List<Widget> children;

  const _AssetDetailCard({
    required this.cs,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 27.w, vertical: 15.h),
      decoration: BoxDecoration(
        color: cs.dark ? cs.inputFill : cs.surfaceAlt,
        borderRadius: BorderRadius.circular(30.r),
      ),
      child: Column(children: children),
    );
  }
}

class _AssetDetailRow extends StatelessWidget {
  final WalletPageColors cs;
  final String label;
  final String? value;
  final Widget? valueWidget;
  final String? copyValue;
  final bool showDivider;

  const _AssetDetailRow({
    required this.cs,
    required this.label,
    this.value,
    this.valueWidget,
    this.copyValue,
    this.showDivider = true,
  });

  @override
  Widget build(BuildContext context) {
    final canCopy =
        copyValue != null && copyValue!.trim().isNotEmpty && copyValue != '--';
    return Container(
      padding: EdgeInsets.symmetric(vertical: 19.5.h),
      child: Row(
        children: [
          SizedBox(
            width: 129.w,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 24.sp,
                fontWeight: FontWeight.w400,
                color: cs.subText,
              ),
            ),
          ),
          SizedBox(width: 18.w),
          Expanded(
            child: valueWidget ??
                Text(
                  value ?? '--',
                  textAlign: TextAlign.right,
                  style: TextStyle(
                    fontSize: 24.sp,
                    fontWeight: FontWeight.w500,
                    color: cs.text,
                    height: 1.1,
                  ),
                ),
          ),
          if (canCopy) ...[
            SizedBox(width: 15.w),
            Builder(
              builder: (context) => InkWell(
                onTap: () async {
                  await ClipboardGuard.copy(
                    copyValue!,
                    showToast: true,
                    toastText: AppI18n.of(context).t(
                      zhHans: '已复制',
                      zhHant: '已複製',
                      en: 'Copied',
                      ja: 'コピーしました',
                      ko: '복사됨',
                    ),
                  );
                },
                borderRadius: BorderRadius.circular(10.r),
                child: Padding(
                  padding: EdgeInsets.all(3.w),
                  child: Icon(
                    Icons.copy_rounded,
                    size: 27.sp,
                    color: cs.subText,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ClaimDetailRow extends StatelessWidget {
  final WalletPageColors cs;
  final String name;
  final String amount;
  final String time;
  final bool showDivider;

  const _ClaimDetailRow({
    required this.cs,
    required this.name,
    required this.amount,
    required this.time,
    this.showDivider = true,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(vertical: 19.5.h),
      decoration: showDivider
          ? BoxDecoration(
              border: Border(
                bottom: BorderSide(color: cs.line, width: 1.w),
              ),
            )
          : null,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Text(
              name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 24.sp,
                fontWeight: FontWeight.w500,
                color: cs.text,
              ),
            ),
          ),
          SizedBox(width: 18.w),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                amount,
                style: TextStyle(
                  fontSize: 24.sp,
                  fontWeight: FontWeight.w600,
                  color: cs.text,
                  height: 1.1,
                ),
              ),
              if (time.isNotEmpty) ...[
                SizedBox(height: 6.h),
                Text(
                  time,
                  style: TextStyle(
                    fontSize: 20.sp,
                    fontWeight: FontWeight.w400,
                    color: cs.subText,
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _DetailCoinLogo extends StatelessWidget {
  final String coin;
  final double size;

  const _DetailCoinLogo({
    required this.coin,
    required this.size,
  });

  @override
  Widget build(BuildContext context) {
    final rawCoin = coin.trim();
    final upper = rawCoin.toUpperCase();
    if (upper == 'TRX') {
      return SizedBox(
        width: size,
        height: size,
        child: SvgPicture.string(
          _tronLogoSvg,
          width: size,
          height: size,
          fit: BoxFit.contain,
        ),
      );
    }
    if (upper == 'USDT') {
      return Container(
        width: size,
        height: size,
        decoration: const BoxDecoration(
          color: Color(0xFF26A17B),
          shape: BoxShape.circle,
        ),
        alignment: Alignment.center,
        child: CustomPaint(
          size: Size(size * 0.62, size * 0.62),
          painter: _UsdtPainter(),
        ),
      );
    }
    if (upper == '99' || rawCoin == '元') {
      return ClipOval(
        child: Image.asset(
          'assets/img/platform_99.webp',
          width: size,
          height: size,
          fit: BoxFit.cover,
        ),
      );
    }
    return Container(
      width: size,
      height: size,
      decoration: const BoxDecoration(
        color: Color(0xFF5B8CFF),
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: Text(
        upper.isEmpty ? '?' : upper.substring(0, 1),
        style: TextStyle(
          fontSize: size * 0.46,
          fontWeight: FontWeight.w800,
          color: Colors.white,
          height: 1,
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

const String _tronLogoSvg = '''
<svg viewBox="0 0 1024 1024" xmlns="http://www.w3.org/2000/svg">
  <path d="M512.85 511.04m-447.5 0a447.5 447.5 0 1 0 895 0 447.5 447.5 0 1 0-895 0Z" fill="#D80917"/>
  <path d="M477.1 787.2c-0.84 0-1.71-0.05-2.55-0.18a18.645 18.645 0 0 1-15.04-12.25L277.69 259.74c-2.31-6.56-0.78-13.86 3.97-18.94s11.96-7.12 18.63-5.23l366.29 102.15c2.37 0.66 4.63 1.8 6.56 3.35l68.87 54.7c7.76 6.15 9.36 17.3 3.64 25.36L492.32 779.31a18.628 18.628 0 0 1-15.22 7.89zM324.8 281.12l157.87 447.25L705 414.01l-52.08-41.37-328.12-91.52z" fill="#FFFFFF"/>
  <path d="M477.13 787.2c-0.69 0-1.35-0.04-2.04-0.11-10.23-1.11-17.63-10.31-16.53-20.54l27.42-253.89c1.09-10.27 10.6-17.48 20.54-16.53 10.23 1.11 17.63 10.31 16.53 20.54l-27.42 253.89c-1.02 9.55-9.1 16.64-18.5 16.64z" fill="#FFFFFF"/>
  <path d="M504.52 533.31c-4.73 0-9.47-1.78-13.11-5.37-7.32-7.25-7.39-19.05-0.15-26.38L648.3 342.57c7.25-7.32 19.05-7.39 26.37-0.16 7.32 7.25 7.39 19.05 0.15 26.38L517.77 527.77a18.59 18.59 0 0 1-13.25 5.54z" fill="#FFFFFF"/>
  <path d="M504.52 533.31c-7.03 0-13.77-4.01-16.93-10.83-4.3-9.34-0.22-20.43 9.1-24.75l225.9-104.28c9.4-4.32 20.43-0.24 24.76 9.12 4.3 9.34 0.22 20.43-9.1 24.75L512.35 531.6a18.857 18.857 0 0 1-7.83 1.71z" fill="#FFFFFF"/>
  <path d="M507.21 536.55c-5.46 0-10.85-2.39-14.53-6.99L280.73 265.19c-6.45-8.03-5.15-19.76 2.9-26.2 8.01-6.41 19.79-5.12 26.2 2.9l211.91 264.37c6.45 8.03 5.17 19.76-2.88 26.2a18.563 18.563 0 0 1-11.65 4.09z" fill="#FFFFFF"/>
</svg>
''';

class _CardSendFailBox extends StatelessWidget {
  final WalletOrderDraft draft;
  final VoidCallback onRetry;
  final VoidCallback onIgnore;

  const _CardSendFailBox({
    required this.draft,
    required this.onRetry,
    required this.onIgnore,
  });

  @override
  Widget build(BuildContext context) {
    final cs = WalletPageColors.of(context);
    final i18n = AppI18n.of(context);
    final manual = draft.cardSendStatus == 'manual';
    final retryText = draft.cardSendRetryCount > 0
        ? i18n.format(
            zhHans: '已自动重试{count}次',
            zhHant: '已自動重試{count}次',
            en: 'Auto-retried {count} times',
            ja: '自動再試行 {count} 回',
            ko: '자동 재시도 {count}회',
            vars: {'count': '${draft.cardSendRetryCount}'},
          )
        : i18n.t(
            zhHans: '聊天消息暂未发送成功',
            zhHant: '聊天訊息暫未發送成功',
            en: 'Chat message has not been sent yet.',
            ja: 'チャットメッセージはまだ送信されていません。',
            ko: '채팅 메시지가 아직 전송되지 않았습니다.',
          );

    return Container(
      padding: EdgeInsets.all(20.w),
      decoration: BoxDecoration(
        color: cs.card,
        borderRadius: BorderRadius.circular(20.r),
        boxShadow: [
          BoxShadow(
            color: cs.shadow,
            blurRadius: 12.r,
            offset: Offset(0, 4.h),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.error_outline_rounded,
                color: const Color(0xFFFF9F1C),
                size: 24.sp,
              ),
              SizedBox(width: 8.w),
              Expanded(
                child: Text(
                  manual
                      ? i18n.t(
                          zhHans: '聊天消息发送失败',
                          zhHant: '聊天訊息發送失敗',
                          en: 'Failed to send chat message',
                          ja: 'チャットメッセージの送信に失敗しました',
                          ko: '채팅 메시지 전송 실패',
                        )
                      : i18n.t(
                          zhHans: '聊天消息待发送',
                          zhHant: '聊天訊息待發送',
                          en: 'Chat message pending',
                          ja: 'チャットメッセージ送信待ち',
                          ko: '채팅 메시지 전송 대기',
                        ),
                  style: TextStyle(
                    fontSize: 19.sp,
                    color: cs.text,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 10.h),
          Text(
            manual
                ? i18n.format(
                    zhHans: '{detail}，请手动重新发送或忽略。',
                    zhHant: '{detail}，請手動重新發送或忽略。',
                    en: '{detail}. Resend manually or ignore.',
                    ja: '{detail}。手動で再送信するか無視してください。',
                    ko: '{detail}. 수동으로 다시 보내거나 무시하세요.',
                    vars: {'detail': retryText},
                  )
                : i18n.format(
                    zhHans: '{detail}，系统会自动重试。',
                    zhHant: '{detail}，系統會自動重試。',
                    en: '{detail}. The system will retry automatically.',
                    ja: '{detail}。システムが自動的に再試行します。',
                    ko: '{detail}. 시스템이 자동으로 재시도합니다.',
                    vars: {'detail': retryText},
                  ),
            style: TextStyle(
              fontSize: 15.sp,
              color: cs.subText,
              height: 1.35,
            ),
          ),
          if (manual) ...[
            SizedBox(height: 16.h),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: onIgnore,
                    child: Text(
                      i18n.t(
                        zhHans: '忽略',
                        zhHant: '忽略',
                        en: 'Ignore',
                        ja: '無視',
                        ko: '무시',
                      ),
                    ),
                  ),
                ),
                SizedBox(width: 12.w),
                Expanded(
                  child: ElevatedButton(
                    onPressed: onRetry,
                    child: Text(
                      i18n.t(
                        zhHans: '重新发送',
                        zhHant: '重新發送',
                        en: 'Resend',
                        ja: '再送信',
                        ko: '다시 보내기',
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _OrderTimeline extends StatelessWidget {
  const _OrderTimeline({
    required this.item,
    this.draft,
  });

  final WalletRecordDto item;
  final WalletOrderDraft? draft;

  String _formatTime(String raw) {
    if (raw.trim().isEmpty) return '--';
    final dt = DateTime.tryParse(raw);
    if (dt == null) return raw;
    return DateFormat('yyyy-MM-dd HH:mm').format(dt.toLocal());
  }

  @override
  Widget build(BuildContext context) {
    final cs = WalletPageColors.of(context);
    final i18n = AppI18n.of(context);
    final orderState = draft == null
        ? WalletOrderState.success
        : WalletOrderStateX.fromName(draft!.orderState);

    final steps = <_TimelineStepData>[
      _TimelineStepData(
        title: i18n.t(
          zhHans: '创建订单',
          zhHant: '創建訂單',
          en: 'Order created',
          ja: '注文作成',
          ko: '주문 생성',
        ),
        time: _formatTime(draft?.createdAt ?? item.time),
        done: true,
      ),
      _TimelineStepData(
        title: i18n.t(
          zhHans: '提交支付',
          zhHant: '提交支付',
          en: 'Payment submitted',
          ja: '支払い送信',
          ko: '결제 제출',
        ),
        time: _formatTime(draft?.lastQueryAt ?? ''),
        done: orderState != WalletOrderState.created &&
            orderState != WalletOrderState.idle,
        active: orderState == WalletOrderState.submitting ||
            orderState == WalletOrderState.unknown,
      ),
      _TimelineStepData(
        title: i18n.t(
          zhHans: '订单完成',
          zhHant: '訂單完成',
          en: 'Order completed',
          ja: '注文完了',
          ko: '주문 완료',
        ),
        time: _formatTime(draft?.updatedAt ?? item.time),
        done: item.status == WalletRecordStatus.success ||
            (draft?.isDoneOrder == true &&
                orderState == WalletOrderState.success),
        active: item.status == WalletRecordStatus.pending,
      ),
    ];

    if (draft?.needsChatCard == true) {
      final cardDone = draft!.cardSent;
      final cardIgnored = draft!.cardIgnored;
      steps.add(
        _TimelineStepData(
          title: i18n.t(
            zhHans: '发送聊天卡片',
            zhHant: '發送聊天卡片',
            en: 'Send chat card',
            ja: 'チャットカード送信',
            ko: '채팅 카드 전송',
          ),
          time: _formatTime(draft!.lastCardSendAt),
          done: cardDone || cardIgnored,
          active: !cardDone && !cardIgnored,
          subtitle: cardIgnored
              ? i18n.t(
                  zhHans: '已忽略',
                  zhHant: '已忽略',
                  en: 'Ignored',
                  ja: '無視済み',
                  ko: '무시됨',
                )
              : (cardDone
                  ? i18n.t(
                      zhHans: '已发送',
                      zhHant: '已發送',
                      en: 'Sent',
                      ja: '送信済み',
                      ko: '전송됨',
                    )
                  : null),
        ),
      );
    }

    return Container(
      padding: EdgeInsets.all(20.w),
      decoration: BoxDecoration(
        color: cs.card,
        borderRadius: BorderRadius.circular(20.r),
        boxShadow: [
          BoxShadow(
            color: cs.shadow,
            blurRadius: 12.r,
            offset: Offset(0, 4.h),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            i18n.t(
              zhHans: '订单进度',
              zhHant: '訂單進度',
              en: 'Order progress',
              ja: '注文進捗',
              ko: '주문 진행',
            ),
            style: TextStyle(
              fontSize: 18.sp,
              fontWeight: FontWeight.w800,
              color: cs.text,
            ),
          ),
          SizedBox(height: 16.h),
          for (final step in steps)
            Padding(
              padding: EdgeInsets.only(bottom: 14.h),
              child: _TimelineRow(step: step, cs: cs),
            ),
        ],
      ),
    );
  }
}

class _TimelineStepData {
  final String title;
  final String time;
  final bool done;
  final bool active;
  final String? subtitle;

  const _TimelineStepData({
    required this.title,
    required this.time,
    this.done = false,
    this.active = false,
    this.subtitle,
  });
}

class _TimelineRow extends StatelessWidget {
  const _TimelineRow({required this.step, required this.cs});

  final _TimelineStepData step;
  final WalletPageColors cs;

  @override
  Widget build(BuildContext context) {
    final color = step.done
        ? const Color(0xFF20B26B)
        : (step.active ? const Color(0xFFFF9F1C) : cs.subText);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          step.done
              ? Icons.check_circle_rounded
              : (step.active
                  ? Icons.access_time_filled_rounded
                  : Icons.radio_button_unchecked_rounded),
          color: color,
          size: 22.sp,
        ),
        SizedBox(width: 10.w),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                step.title,
                style: TextStyle(
                  fontSize: 15.sp,
                  fontWeight: FontWeight.w600,
                  color: cs.text,
                ),
              ),
              if (step.time != '--') ...[
                SizedBox(height: 2.h),
                Text(
                  step.time,
                  style: TextStyle(fontSize: 12.sp, color: cs.subText),
                ),
              ],
              if (step.subtitle != null) ...[
                SizedBox(height: 2.h),
                Text(
                  step.subtitle!,
                  style: TextStyle(fontSize: 12.sp, color: cs.subText),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}
