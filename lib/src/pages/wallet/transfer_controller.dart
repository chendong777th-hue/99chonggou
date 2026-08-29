import 'dart:async';

import 'package:flutter/material.dart';
import 'package:tencent_cloud_chat_demo/src/i18n/app_i18n.dart';
import 'package:tencent_cloud_chat_uikit/tencent_cloud_chat_uikit.dart';

import 'order/wallet_card_im_sender.dart';
import 'order/wallet_card_replay_guard.dart';
import 'order/wallet_order.dart';
import 'order/wallet_order_checker.dart';
import 'order/wallet_order_events.dart';
import 'order/wallet_order_service.dart';
import 'transfer_party_name_resolver.dart';
import 'wallet_default_pay_currency_store.dart';
import 'wallet_repository.dart';
import 'wallet_repository_provider.dart';
import 'wallet_store.dart';
import 'red_packet/red_packet_controller.dart';
import 'red_packet/red_packet_member.dart';

enum PayFlow {
  none,
  loading,
  pending,
  success,
  failed,
}

/// 转账说明最大字数。
const int kWalletTransferMemoMaxLength = 10;

class TransferController extends ChangeNotifier {
  final WalletRepository _repo;
  final WalletOrderChecker _checker;
  final WalletOrderService _orderSvc;

  TransferController({
    WalletRepository? repo,
    WalletOrderChecker? checker,
    WalletOrderService? orderSvc,
  })  : _repo = repo ?? createWalletRepository(),
        _checker = checker ?? const WalletOrderChecker(),
        _orderSvc = orderSvc ?? WalletOrderService();

  List<WalletPayMethodDto> items = <WalletPayMethodDto>[];
  WalletPayMethodDto sel = WalletPayMethodDto.empty;
  bool payLoading = false;

  Future<void> loadPayMethods() async {
    if (payLoading) return;
    final preferredId = await WalletDefaultPayCurrencyStore.readId();
    final cached = WalletStore.instance.cachedPayMethods;
    if (cached != null && cached.isNotEmpty) {
      items = List<WalletPayMethodDto>.from(cached);
      sel = _pickDefaultPay(items, preferredId);
      notifyListeners();
    }
    payLoading = true;
    notifyListeners();
    try {
      final methods = await WalletStore.instance.getPayMethods(repo: _repo);
      items = List<WalletPayMethodDto>.from(methods);
      sel = items.isNotEmpty
          ? _pickDefaultPay(items, preferredId)
          : WalletPayMethodDto.empty;
    } catch (_) {
      items = <WalletPayMethodDto>[];
      sel = WalletPayMethodDto.empty;
    } finally {
      payLoading = false;
      if (!_disposed) notifyListeners();
    }
  }

  WalletPayMethodDto _pickDefaultPay(
    List<WalletPayMethodDto> list,
    String? preferredId,
  ) {
    return WalletDefaultPayCurrencyStore.pick(
      items: list,
      idOf: (e) => e.id,
      enabledOf: (e) => e.enabled,
      preferredId: preferredId,
    );
  }

  String amt = '';
  String memo = '';
  String err = '';
  String toUserId = '';
  String toName = '';
  String avatar = '';
  String conversationId = '';
  String orderId = '';
  String clientOrderId = '';
  bool isGroup = false;
  WalletOrderState state = WalletOrderState.idle;
  WalletOrderResult? lastResult;

  bool _disposed = false;

  PayFlow get flow {
    switch (state) {
      case WalletOrderState.submitting:
        return PayFlow.loading;
      case WalletOrderState.accepted:
      case WalletOrderState.pending:
      case WalletOrderState.unknown:
        return PayFlow.pending;
      case WalletOrderState.success:
        return PayFlow.success;
      case WalletOrderState.failed:
        return PayFlow.failed;
      default:
        return PayFlow.none;
    }
  }

  bool get isBusy => state == WalletOrderState.submitting;
  bool get hasAmt => amt.trim().isNotEmpty;
  int? get amountMinor => _checker.amountMinor(raw: amt, coin: sel.coin, scale: sel.scale);
  String get amountText => WalletAmount.parse(amt, coin: sel.coin, scale: sel.scale)?.text ?? amt;

  /// 展示用金额：至少保留 2 位小数（如 1 -> 1.00），仅用于 UI。
  String get amountDisplayText {
    final minor = amountMinor;
    if (minor == null) return amountText;
    return WalletAmount.formatDisplay(minor, sel.scale);
  }

  String get actualPayText {
    final minor = amountMinor ?? 0;
    final amount = '${WalletAmount.formatMinor(minor, sel.scale)} ${sel.coin}';
    if (sel.feeMinor <= 0) return amount;
    final feeCoin = sel.feeCoin.isEmpty ? sel.coin : sel.feeCoin;
    if (feeCoin == sel.coin) {
      return '${WalletAmount.formatMinor(minor + sel.feeMinor, sel.scale)} ${sel.coin}';
    }
    return '$amount + ${WalletAmount.formatMinor(sel.feeMinor, sel.feeScale)} $feeCoin';
  }

  bool get canConfirm => check() == null && state == WalletOrderState.idle;

  void setAmt(String v) {
    final next = v.trim();
    if (amt == next) return;
    amt = next;
    notifyListeners();
  }

  void setMemo(String v) {
    var cleaned = v.replaceAll(RegExp(r'[\n\r\t]'), ' ').trim();
    if (cleaned.length > kWalletTransferMemoMaxLength) {
      cleaned = cleaned.substring(0, kWalletTransferMemoMaxLength);
    }
    if (memo == cleaned) return;
    memo = cleaned;
    notifyListeners();
  }

  void setReceiver({
    required String userId,
    required String name,
    String avatarUrl = '',
    String convId = '',
    bool group = false,
  }) {
    final nextUserId = userId.trim();
    final nextName = name.trim();
    final nextAvatar = avatarUrl.trim();
    final nextConversationId = convId.trim();
    if (toUserId == nextUserId &&
        toName == nextName &&
        avatar == nextAvatar &&
        conversationId == nextConversationId &&
        isGroup == group) {
      return;
    }
    toUserId = nextUserId;
    final nick = TransferPartyNameResolver.nicknameOf(
      userId: nextUserId,
      nickHint: nextName,
    );
    toName = nick.isNotEmpty ? nick : nextName;
    avatar = nextAvatar;
    conversationId = nextConversationId;
    isGroup = group;
    notifyListeners();
    if (group && nextUserId.isNotEmpty) {
      unawaited(_enrichReceiverNickname(nextUserId));
    }
  }

  Future<void> _enrichReceiverNickname(String userId) async {
    final nick = await TransferPartyNameResolver.resolveNickname(
      userId: userId,
      nickHint: toName,
    );
    if (nick.isEmpty || nick == toName) {
      return;
    }
    toName = nick;
    notifyListeners();
  }

  Future<List<RedPacketMember>> loadMembers({bool excludeSelf = false}) async {
    final members =
        await WalletStore.instance.getMembers(conversationId, repo: _repo);
    final named = members.map((member) {
      final publicName = TransferPartyNameResolver.nicknameOf(
        userId: member.userId,
        nickHint: member.publicNameOrFallback,
      );
      final displayName = member.name.trim();
      return RedPacketMember(
        userId: member.userId,
        name: displayName.isNotEmpty ? displayName : member.userId,
        publicName:
            publicName.isNotEmpty ? publicName : member.publicNameOrFallback,
        avatar: member.avatar,
        qq: member.qq,
      );
    }).toList(growable: false);
    if (!excludeSelf) return named;
    return named
        .where((member) => !RedPacketController.isSelfUserId(member.userId))
        .toList(growable: false);
  }

  void select(WalletPayMethodDto item) {
    if (sel.id == item.id) return;
    sel = item;
    notifyListeners();
  }

  String? check() {
    final receiverErr = _checker.checkReceiver(toUserId);
    if (receiverErr != WalletOrderErr.none) return isGroup ? '请选择收款人' : receiverErr.text;
    if (!sel.enabled) return '当前付款方式不可用';

    final amountErr = _checker.checkAmount(
      raw: amt,
      coin: sel.coin,
      scale: sel.scale,
      balMinor: sel.balMinor,
    );
    if (amountErr != WalletOrderErr.none) return amountErr.text;

    final minor = amountMinor ?? 0;
    final balErr = _checker.checkPayBalance(
      amountMinor: minor,
      amountBalanceMinor: sel.balMinor,
      coin: sel.coin,
      feeMinor: sel.feeMinor,
      feeCoin: sel.feeCoin,
      feeBalanceMinor: sel.feeBalanceMinor,
    );
    if (balErr != WalletOrderErr.none) return balErr.text;
    return null;
  }

  String startOrder() {
    // 群转账底座为红包表 GROUP_TRANSFER，clientOrderId 用 red_packet_ 前缀。
    clientOrderId = _orderSvc.start(isGroup ? 'red_packet' : 'transfer');
    return clientOrderId;
  }

  void cancelOrderIfIdle() {
    _orderSvc.cancel();
    if (state == WalletOrderState.idle) clientOrderId = '';
  }

  Future<String?> submit(String pwd) async {
    if (state == WalletOrderState.submitting) return WalletOrderErr.duplicateSubmit.text;

    final msg = check();
    if (msg != null) return msg;

    final minor = amountMinor;
    if (minor == null) return WalletOrderErr.invalidAmount.text;
    final clientId = clientOrderId.isEmpty ? startOrder() : clientOrderId;

    state = WalletOrderState.submitting;
    err = '';
    notifyListeners();

    final draft = WalletOrderDraft(
      clientOrderId: clientId,
      type: isGroup ? WalletOrderType.redPacket : WalletOrderType.transfer,
      amountText: amountText,
      amountMinor: minor,
      coin: sel.coin,
      network: sel.net,
      feeMinor: sel.feeMinor,
      feeCoin: sel.feeCoin,
      feeScale: sel.feeScale,
      feeBalanceMinor: sel.feeBalanceMinor,
      receiverId: toUserId,
      receiverName: toName,
      memo: memo,
      createdAt: DateTime.now().toIso8601String(),
      conversationId: conversationId,
      // 群转账废弃 /wallet/transfer，改走红包 send + GROUP_TRANSFER。
      businessType: isGroup ? 'wallet_group_transfer' : 'wallet_transfer',
    );

    final ret = await _orderSvc.run(draft, (id) {
      if (isGroup) {
        return _repo.sendRedPacket(
          WalletRedPacketReq(
            clientOrderId: id,
            convId: conversationId,
            isGroup: true,
            rpType: 'group_transfer',
            cnt: '1',
            amt: amountText,
            amountMinor: minor.toString(),
            totalAmt: amountText,
            totalMinor: minor.toString(),
            coin: sel.coin,
            payId: sel.id,
            net: sel.net,
            pwd: pwd,
            msg: memo,
            toUserId: toUserId,
          ),
        );
      }
      return _repo.transfer(
        WalletTransferReq(
          clientOrderId: id,
          toUserId: toUserId,
          toName: toName,
          amt: amountText,
          amountMinor: minor.toString(),
          coin: sel.coin,
          payId: sel.id,
          net: sel.net,
          pwd: pwd,
          memo: memo,
        ),
      );
    });

    if (_disposed) {
      return AppI18n.current.t(
        zhHans: '页面已关闭',
        zhHant: '頁面已關閉',
        en: 'This page has been closed.',
        ja: 'ページは閉じられました。',
        ko: '페이지가 닫혔습니다.',
      );
    }
    lastResult = ret;

    if (!ret.ok) {
      state = WalletOrderState.idle;
      err = ret.msg.isEmpty ? ret.err.text : ret.msg;
      notifyListeners();
      return err;
    }

    orderId = ret.orderId;
    final sentClientOrderId = ret.clientOrderId.isNotEmpty
        ? ret.clientOrderId
        : clientOrderId;
    state = ret.state == WalletOrderState.success
        ? WalletOrderState.success
        : (ret.state == WalletOrderState.failed ||
                ret.state == WalletOrderState.expired ||
                ret.state == WalletOrderState.cancelled ||
                ret.state == WalletOrderState.refunded)
            ? ret.state
            : WalletOrderState.pending;
    clientOrderId = '';
    WalletOrderEvents.notifyRecord();
    if (_shouldReloadBalance(state)) {
      WalletOrderEvents.notifyBalance();
    }
    await _notifyChatCard(ret, sentClientOrderId);
    notifyListeners();
    return null;
  }

  Future<void> _notifyChatCard(
    WalletOrderResult ret,
    String sentClientOrderId,
  ) async {
    if (conversationId.trim().isEmpty) {
      debugPrint(
        'wallet-card skip empty-conv after REST orderId=${ret.orderId} '
        'clientOrderId=$sentClientOrderId',
      );
      return;
    }
    final minor = amountMinor;
    if (minor == null) {
      debugPrint(
        'wallet-card skip empty-amount after REST orderId=${ret.orderId} '
        'clientOrderId=$sentClientOrderId',
      );
      return;
    }

    await WalletCardReplayGuard.instance.rememberRestSuccess(
      orderId: ret.orderId,
      clientOrderId: sentClientOrderId,
    );

    if (isGroup) {
      final resolvedReceiver = await TransferPartyNameResolver.resolveNickname(
        userId: toUserId,
        nickHint: toName,
      );
      if (resolvedReceiver.isNotEmpty) {
        toName = resolvedReceiver;
      }
      // 群转账：IM customType=wallet_group_transfer，同步直达，无待领取。
      final login = TIMUIKitCore.getInstance().loginInfo;
      final senderId = login.userID.trim();
      final senderNick = login.loginUser?.nickName?.trim() ?? '';
      final senderName = senderNick.isNotEmpty ? senderNick : senderId;
      await WalletCardImSender.instance.sendAfterRest({
        'type': 'wallet_group_transfer',
        'sendSource': 'payment',
        'orderId': ret.orderId,
        'clientOrderId': sentClientOrderId,
        'conversationId': conversationId,
        'isGroup': true,
        'currency': sel.id,
        'amount': minor,
        'status': 'success',
        'packetType': 'GROUP_TRANSFER',
        if (memo.trim().isNotEmpty) 'memo': memo.trim(),
        'greeting': memo,
        if (senderId.isNotEmpty) 'senderId': senderId,
        if (senderId.isNotEmpty) 'senderUserId': senderId,
        if (senderId.isNotEmpty) 'fromUserId': senderId,
        if (senderName.isNotEmpty) 'senderName': senderName,
        if (senderName.isNotEmpty) 'fromUserName': senderName,
        'receiverId': toUserId,
        'receiverName': toName,
        'receiverAvatar': avatar,
        'toUserId': toUserId,
        'toUserName': toName,
        'toUserAvatar': avatar,
      });
      return;
    }

    await WalletCardImSender.instance.sendAfterRest({
      'type': 'wallet_transfer',
      'sendSource': 'payment',
      'orderId': ret.orderId,
      'clientOrderId': sentClientOrderId,
      'conversationId': conversationId,
      'isGroup': false,
      'currency': sel.id,
      'amount': minor,
      'status': _chatCardStatus(ret.state),
      if (memo.trim().isNotEmpty) 'memo': memo.trim(),
      'greeting': memo,
      'receiverId': toUserId,
      'receiverName': toName,
      'receiverAvatar': avatar,
      'toUserId': toUserId,
      'toUserName': toName,
      'toUserAvatar': avatar,
    });
  }

  bool _shouldReloadBalance(WalletOrderState state) {
    return state == WalletOrderState.success ||
        state == WalletOrderState.accepted ||
        state == WalletOrderState.pending ||
        state == WalletOrderState.unknown;
  }

  String _chatCardStatus(WalletOrderState state) {
    switch (state) {
      case WalletOrderState.success:
        return 'success';
      case WalletOrderState.failed:
      case WalletOrderState.expired:
      case WalletOrderState.cancelled:
      case WalletOrderState.refunded:
        return 'failed';
      case WalletOrderState.accepted:
      case WalletOrderState.pending:
      case WalletOrderState.unknown:
      case WalletOrderState.submitting:
      case WalletOrderState.confirming:
      case WalletOrderState.password:
      case WalletOrderState.created:
      case WalletOrderState.idle:
        return 'pending';
    }
  }

  void hideFlow() {
    if (state == WalletOrderState.failed || state == WalletOrderState.accepted || state == WalletOrderState.pending || state == WalletOrderState.unknown || state == WalletOrderState.success) {
      state = WalletOrderState.idle;
      clientOrderId = '';
      err = '';
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
