import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:tencent_cloud_chat_demo/src/api/wallet_amount.dart';
import 'package:tencent_cloud_chat_demo/src/api/wallet_api.dart';
import 'package:tencent_cloud_chat_demo/src/api/wallet_models.dart';
import 'package:tencent_cloud_chat_demo/src/i18n/app_i18n.dart';
import 'package:tencent_cloud_chat_demo/src/pages/wallet/transfer_party_name_resolver.dart';
import 'package:tencent_cloud_chat_demo/src/pages/wallet/widgets/platform_coin_icon.dart';

import 'widgets/wallet_page_colors.dart';

class TransferDetailScreen extends StatefulWidget {
  const TransferDetailScreen({
    super.key,
    required this.isOutgoing,
    this.isGroupTransfer = false,
    required this.amount,
    required this.coin,
    this.currency,
    this.memo,
    required this.senderName,
    required this.receiverName,
    this.senderUserId,
    this.receiverUserId,
    this.groupId,
    required this.transferTime,
    required this.receiveTime,
  });

  final bool isOutgoing;
  final bool isGroupTransfer;
  final String amount;
  final String coin;
  final String? currency;
  final String? memo;
  final String senderName;
  final String receiverName;
  final String? senderUserId;
  final String? receiverUserId;
  final String? groupId;
  final String transferTime;
  final String receiveTime;

  @override
  State<TransferDetailScreen> createState() => _TransferDetailScreenState();
}

class _TransferDetailScreenState extends State<TransferDetailScreen> {
  static const _textColor = Color(0xFF17191C);
  static const _subTextColor = Color(0xFF888B90);
  static const _lineColor = Color(0xFFEEEEEE);

  WalletMe? _walletMe;
  WalletCurrencyItem? _currencyItem;
  bool _refreshingRate = false;
  late String _senderName;
  late String _receiverName;

  bool get _isPlatformCoin {
    return isWalletPlatformCurrency(_coinLabel) ||
        _looksLikePlatformFromWidget;
  }

  bool get _looksLikePlatformFromWidget {
    final currency = widget.currency?.trim() ?? '';
    final coin = widget.coin.trim();
    return isWalletPlatformCurrency(currency) ||
        isWalletPlatformCurrency(coin) ||
        coin == '元' ||
        coin.toUpperCase() == 'C' ||
        coin.toUpperCase() == 'CNY';
  }

  String get _coinLabel => walletDetailCoinCode(
        currency: widget.currency,
        coin: widget.coin,
      );

  double? get _amountValue =>
      double.tryParse(widget.amount.replaceAll(',', '').trim());

  double get _cnyRate {
    if (_isPlatformCoin) return 1;
    return _walletMe?.exchangeRate?.effectiveCnyPerUsdt ??
        _walletMe?.usdtPrice?.cnyPerUsdt ??
        0;
  }

  String _sanitizePartyName(String raw, String? userId) {
    final text = raw.trim();
    if (text.isEmpty) {
      return '';
    }
    if (TransferPartyNameResolver.isGroupDisplayName(
      text,
      groupId: widget.groupId,
    )) {
      return '';
    }
    if (TransferPartyNameResolver.isRawUserId(text, userId: userId)) {
      return '';
    }
    return text;
  }

  @override
  void initState() {
    super.initState();
    _senderName = _sanitizePartyName(widget.senderName, widget.senderUserId);
    _receiverName =
        _sanitizePartyName(widget.receiverName, widget.receiverUserId);
    _refreshingRate = true;
    unawaited(_refreshRate(fromInit: true));
    unawaited(_resolveDisplayNames());
  }

  Future<void> _resolveDisplayNames() async {
    final resolved = await TransferPartyNameResolver.resolvePair(
      senderName: _senderName,
      receiverName: _receiverName,
      senderUserId: widget.senderUserId?.trim() ?? '',
      receiverUserId: widget.receiverUserId?.trim() ?? '',
      groupId: widget.groupId,
    );
    if (!mounted) {
      return;
    }
    if (resolved.$1 == _senderName && resolved.$2 == _receiverName) {
      return;
    }
    setState(() {
      _senderName = resolved.$1;
      _receiverName = resolved.$2;
    });
  }

  Future<void> _refreshRate({bool fromInit = false}) async {
    if (_refreshingRate && !fromInit) return;
    if (!fromInit) {
      setState(() => _refreshingRate = true);
    }
    WalletMe? walletMe;
    WalletCurrenciesResponse? currencies;
    try {
      walletMe = await WalletApi.instance.getMe();
    } catch (_) {}
    try {
      currencies = await WalletApi.instance.getCurrencies();
    } catch (_) {}
    if (!mounted) return;
    setState(() {
      _walletMe = walletMe ?? _walletMe;
      _currencyItem = _findCurrencyItem(currencies) ?? _currencyItem;
      _refreshingRate = false;
    });
  }

  WalletCurrencyItem? _findCurrencyItem(
    WalletCurrenciesResponse? response,
  ) {
    if (response == null) return null;
    final currency = widget.currency?.trim().toUpperCase() ?? '';
    final coin = widget.coin.trim().toUpperCase();
    final detailCode = _coinLabel;
    for (final item in response.currencies) {
      final code = item.code.trim().toUpperCase();
      final name = item.name.trim().toUpperCase();
      if ((detailCode.isNotEmpty && code == detailCode) ||
          (currency.isNotEmpty && code == currency) ||
          (coin.isNotEmpty && (code == coin || name == coin)) ||
          (_isPlatformCoin && item.platformCoin)) {
        return item;
      }
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final i18n = AppI18n.of(context);
    // 群转账不展示祝福语/备注。
    final memoText =
        widget.isGroupTransfer ? '' : (widget.memo?.trim() ?? '');

    return wrapWalletPage(
      context,
      Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          iconTheme: const IconThemeData(color: Color(0xFF2399E5)),
          elevation: 0,
          shadowColor: Colors.transparent,
          surfaceTintColor: Colors.transparent,
          backgroundColor: Colors.white,
          foregroundColor: const Color(0xFF2399E5),
          systemOverlayStyle: SystemUiOverlayStyle.dark.copyWith(
            statusBarColor: Colors.transparent,
          ),
        ),
        body: SafeArea(
          top: false,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(32, 58, 32, 28),
            child: Column(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: const BoxDecoration(
                    color: Color(0xFF12C85A),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.check_rounded,
                    color: Colors.white,
                    size: 34,
                  ),
                ),
                const SizedBox(height: 44),
                Text(
                  _descriptionText(i18n),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 16,
                    color: _textColor,
                    fontWeight: FontWeight.w400,
                  ),
                ),
                const SizedBox(height: 22),
                _buildCoinLabel(),
                const SizedBox(height: 22),
                Text(
                  _formattedAmount,
                  style: TextStyle(
                    fontSize: 48,
                    height: 1,
                    color: _textColor,
                    fontWeight: FontWeight.w400,
                    letterSpacing: .3,
                  ),
                ),
                const SizedBox(height: 18),
                Text(
                  _fiatText,
                  style: TextStyle(
                    fontSize: 16,
                    color: _subTextColor,
                    fontWeight: FontWeight.w400,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '${i18n.t(
                        zhHans: '当前参考汇率：',
                        zhHant: '當前參考匯率：',
                        en: 'Reference rate: ',
                        ja: '参考レート：',
                        ko: '현재 기준 환율: ',
                      )}$_rateText',
                      style: const TextStyle(
                        fontSize: 14,
                        color: _subTextColor,
                      ),
                    ),
                    const SizedBox(width: 5),
                    GestureDetector(
                      onTap: _refreshingRate ? null : _refreshRate,
                      child: _refreshingRate
                          ? const SizedBox(
                              width: 15,
                              height: 15,
                              child: CircularProgressIndicator(
                                strokeWidth: 1.8,
                                color: Color(0xFF2399E5),
                              ),
                            )
                          : const Icon(
                              Icons.refresh_rounded,
                              size: 19,
                              color: Color(0xFF2399E5),
                            ),
                    ),
                  ],
                ),
                const SizedBox(height: 38),
                const Divider(height: 1, thickness: .5, color: _lineColor),
                const SizedBox(height: 18),
                _DetailRow(
                  label: i18n.t(
                    zhHans: '当前状态',
                    zhHant: '當前狀態',
                    en: 'Current status',
                    ja: '現在の状態',
                    ko: '현재 상태',
                  ),
                  value: '已接收',
                ),
                const SizedBox(height: 12),
                if (memoText.isNotEmpty) ...[
                  _DetailRow(
                    label: i18n.t(
                      zhHans: '转账备注',
                      zhHant: '轉帳備註',
                      en: 'Memo',
                      ja: '送金メモ',
                      ko: '이체 메모',
                    ),
                    value: memoText,
                  ),
                  const SizedBox(height: 12),
                ],
                _DetailRow(
                  label: i18n.t(
                    zhHans: '转账时间',
                    zhHant: '轉帳時間',
                    en: 'Transfer time',
                    ja: '送金時間',
                    ko: '이체 시간',
                  ),
                  value: widget.transferTime,
                ),
                const SizedBox(height: 12),
                _DetailRow(
                  label: i18n.t(
                    zhHans: '收款时间',
                    zhHant: '收款時間',
                    en: 'Received time',
                    ja: '受取時間',
                    ko: '수령 시간',
                  ),
                  value: widget.receiveTime,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCoinLabel() {
    final label = _coinLabel;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildCoinLogo(label),
        const SizedBox(width: 7),
        Text(
          label,
          style: const TextStyle(
            fontSize: 17,
            color: _textColor,
            fontWeight: FontWeight.w400,
          ),
        ),
      ],
    );
  }

  Widget _buildCoinLogo(String label) {
    if (_isPlatformCoin) {
      return const PlatformCoinIcon(size: 24);
    }
    final logoUrl = _currencyItem?.logoUrl.trim() ?? '';
    if (logoUrl.isNotEmpty) {
      return ClipOval(
        child: Image.network(
          logoUrl,
          width: 24,
          height: 24,
          fit: BoxFit.cover,
          gaplessPlayback: true,
          frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
            if (wasSynchronouslyLoaded || frame != null) {
              return child;
            }
            return _fallbackCoinLogo(label);
          },
          errorBuilder: (_, __, ___) => _fallbackCoinLogo(label),
        ),
      );
    }
    return _fallbackCoinLogo(label);
  }

  Widget _fallbackCoinLogo(String label) {
    if (_isPlatformCoin) return const PlatformCoinIcon(size: 24);
    return Container(
      width: 24,
      height: 24,
      alignment: Alignment.center,
      decoration: const BoxDecoration(
        color: Color(0xFF26A17B),
        shape: BoxShape.circle,
      ),
      child: Text(
        label.isEmpty ? '?' : label.substring(0, 1),
        style: const TextStyle(
          color: Colors.white,
          fontSize: 13,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  String _descriptionText(AppI18n i18n) {
    final sender = _senderName.trim().isEmpty
        ? (widget.isOutgoing ? '我' : '对方')
        : _senderName.trim();
    final receiver = _receiverName.trim().isEmpty
        ? (widget.isOutgoing ? '对方' : '我')
        : _receiverName.trim();
    if (widget.isGroupTransfer) {
      return i18n.format(
        zhHans: '{sender}群转账给{receiver}',
        zhHant: '{sender}群轉帳給{receiver}',
        en: '{sender} group-transferred to {receiver}',
        ja: '{sender}が{receiver}へグループ送金',
        ko: '{sender}님이 {receiver}님에게 그룹 이체',
        vars: {'sender': sender, 'receiver': receiver},
      );
    }
    return i18n.format(
      zhHans: '{sender}向{receiver}发起的转账',
      zhHant: '{sender}向{receiver}發起的轉帳',
      en: 'Transfer from {sender} to {receiver}',
      ja: '{sender}から{receiver}への送金',
      ko: '{sender}님이 {receiver}님에게 보낸 이체',
      vars: {'sender': sender, 'receiver': receiver},
    );
  }

  String get _formattedAmount {
    final value = _amountValue;
    if (value == null) {
      return widget.amount.trim().isEmpty ? '--' : widget.amount.trim();
    }
    return _formatMoney(value);
  }

  String get _fiatText {
    final amount = _amountValue;
    final rate = _cnyRate;
    if (amount == null || rate <= 0) return '≈ --';
    return '≈ ¥${_formatMoney(amount * rate)}';
  }

  String get _rateText {
    final rate = _cnyRate;
    return rate <= 0 ? '--' : '¥${_formatMoney(rate)}';
  }

  String _formatMoney(double value) {
    final fixed = value.toStringAsFixed(2).split('.');
    final formatted = fixed.first.replaceAllMapped(
      RegExp(r'\B(?=(\d{3})+(?!\d))'),
      (_) => ',',
    );
    return '$formatted.${fixed.last}';
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 94,
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 14,
              color: _TransferDetailScreenState._subTextColor,
              fontWeight: FontWeight.w400,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value.trim().isEmpty ? '--' : value,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.right,
            style: const TextStyle(
              fontSize: 14,
              color: _TransferDetailScreenState._textColor,
              fontWeight: FontWeight.w400,
            ),
          ),
        ),
      ],
    );
  }
}
