import 'package:dio/dio.dart';

import 'package:tencent_cloud_chat_demo/src/api/wallet_amount.dart';
import 'package:tencent_cloud_chat_demo/src/api/wallet_api.dart';
import 'package:tencent_cloud_chat_demo/src/i18n/app_i18n.dart';
import 'package:tencent_cloud_chat_demo/utils/user_api_error_message.dart';

import 'order/wallet_order.dart';
import 'record/wallet_record_models.dart';
import 'red_packet/red_packet_member.dart';
import 'red_packet/red_packet_models.dart';
import 'wallet_repository.dart';

class ApiWalletRepository implements WalletRepository {
  const ApiWalletRepository();

  @override
  Future<WalletDto> getWallet() => WalletApi.instance.getWallet();

  @override
  Future<List<WalletPayMethodDto>> getPayMethods() =>
      WalletApi.instance.getPayMethods();

  @override
  Future<WalletOrderResult> transfer(WalletTransferReq req) async {
    try {
      final currency = _resolveCurrency(req.payId, req.coin);
      return await WalletApi.instance.createTransfer(
        toUserId: req.toUserId,
        currency: currency,
        amount: int.tryParse(req.amountMinor) ?? 0,
        payPin: req.pwd,
        clientOrderId: req.clientOrderId,
        memo: req.memo,
      );
    } on DioError catch (e) {
      _throwPendingWhenNoResponse(e);
      return _orderResultFromDio(e, clientOrderId: req.clientOrderId);
    }
  }

  @override
  Future<WalletOrderResult> withdraw(WalletWithdrawReq req) async {
    try {
      return await WalletApi.instance.createWithdraw(
        toAddress: req.toAddress,
        amountMicro: int.tryParse(req.amountMinor) ?? 0,
        payPin: req.pwd,
        clientOrderId: req.clientOrderId,
      );
    } on DioError catch (e) {
      _throwPendingWhenNoResponse(e);
      return _orderResultFromDio(e, clientOrderId: req.clientOrderId);
    }
  }

  @override
  Future<WalletOrderResult> sendRedPacket(WalletRedPacketReq req) async {
    try {
      final body = WalletApi.buildRedPacketBody(req: req, isGroup: req.isGroup);
      return await WalletApi.instance.sendRedPacket(body);
    } on DioError catch (e) {
      _throwPendingWhenNoResponse(e);
      return _orderResultFromDio(e, clientOrderId: req.clientOrderId);
    }
  }

  @override
  Future<WalletExchangeOrderDto> exchange(WalletExchangeReq req) async {
    try {
      return await WalletApi.instance.createExchange(
        direction: req.direction,
        amount: req.amount,
        payPin: req.payPin,
      );
    } on DioError catch (e) {
      throw WalletSubmitException(
        requestSent: e.response != null,
        message: UserApiErrorMessage.fromWallet(e),
      );
    }
  }

  @override
  Future<List<WalletExchangeOrderDto>> getExchangeRecords({
    int page = 0,
    int size = 20,
  }) {
    return WalletApi.instance.getExchangeOrders(page: page, size: size);
  }

  @override
  Future<WalletOrderResult> queryOrderStatus(WalletOrderDraft draft) async {
    final orderId = draft.serverOrderId.trim().isNotEmpty
        ? draft.serverOrderId
        : draft.clientOrderId;
    if (orderId.isEmpty) {
      return WalletOrderResult(
        ok: false,
        state: WalletOrderState.failed,
        err: WalletOrderErr.duplicateSubmit,
        msg: AppI18n.current.t(
          zhHans: '订单状态异常',
          zhHant: '訂單狀態異常',
          en: 'Order status error',
          ja: '注文状態が異常です',
          ko: '주문 상태가 비정상입니다',
        ),
      );
    }

    if (draft.type == WalletOrderType.redPacket ||
        draft.businessType == 'wallet_red_packet' ||
        draft.businessType == 'wallet_group_transfer') {
      final serverId = isRedPacketServerId(draft.serverOrderId)
          ? draft.serverOrderId.trim()
          : '';
      if (serverId.isEmpty) {
        return WalletOrderResult(
          ok: true,
          state: WalletOrderState.unknown,
          clientOrderId: draft.clientOrderId,
          msg: AppI18n.current.t(
            zhHans: '订单状态确认中',
            zhHant: '訂單狀態確認中',
            en: 'Order status is being confirmed',
            ja: '注文状態を確認中です',
            ko: '주문 상태 확인 중',
          ),
        );
      }
      try {
        return await WalletApi.instance.getRedPacketOrder(serverId);
      } on DioError catch (e) {
        return _orderResultFromDio(e, clientOrderId: draft.clientOrderId);
      }
    }

    if (draft.type == WalletOrderType.transfer ||
        draft.businessType == 'wallet_transfer') {
      try {
        if (draft.serverOrderId.trim().isNotEmpty) {
          return await WalletApi.instance.getTransferOrder(draft.serverOrderId);
        }
        if (draft.clientOrderId.trim().isNotEmpty) {
          return await WalletApi.instance.getTransferOrderByClientId(
            draft.clientOrderId,
          );
        }
      } on DioError catch (e) {
        if (e.response?.statusCode == 404) {
          return WalletOrderResult(
            ok: true,
            state: WalletOrderState.unknown,
            clientOrderId: draft.clientOrderId,
            msg: AppI18n.current.t(
              zhHans: '订单状态确认中',
              zhHant: '訂單狀態確認中',
              en: 'Order status is being confirmed',
              ja: '注文状態を確認中です',
              ko: '주문 상태 확인 중',
            ),
          );
        }
        return _orderResultFromDio(e, clientOrderId: draft.clientOrderId);
      }
    }

    if (draft.businessType == 'wallet_withdraw') {
      try {
        if (draft.serverOrderId.trim().isNotEmpty) {
          return await WalletApi.instance.getWithdrawOrder(draft.serverOrderId);
        }
        if (draft.clientOrderId.trim().isNotEmpty) {
          return await WalletApi.instance.getWithdrawOrderByClientId(
            draft.clientOrderId,
          );
        }
      } on DioError catch (e) {
        if (e.response?.statusCode == 404) {
          return WalletOrderResult(
            ok: true,
            state: WalletOrderState.unknown,
            clientOrderId: draft.clientOrderId,
            msg: AppI18n.current.t(
              zhHans: '订单状态确认中',
              zhHant: '訂單狀態確認中',
              en: 'Order status is being confirmed',
              ja: '注文状態を確認中です',
              ko: '주문 상태 확인 중',
            ),
          );
        }
        return _orderResultFromDio(e, clientOrderId: draft.clientOrderId);
      }
    }

    return WalletOrderResult(
      ok: true,
      state: WalletOrderState.unknown,
      orderId: orderId,
      clientOrderId: draft.clientOrderId,
      msg: AppI18n.current.t(
        zhHans: '订单状态确认中',
        zhHant: '訂單狀態確認中',
        en: 'Order status is being confirmed',
        ja: '注文状態を確認中です',
        ko: '주문 상태 확인 중',
      ),
    );
  }

  @override
  Future<WalletOrderCardDto> getWalletOrderCard({
    required String type,
    required String orderId,
    required String clientOrderId,
    String? currency,
    int? amount,
    String? status,
    String? greeting,
  }) {
    final lookupOrderId =
        orderId.trim().isNotEmpty ? orderId.trim() : clientOrderId.trim();
    return WalletApi.instance.getWalletOrderCard(
      type: type,
      orderId: lookupOrderId,
      currency: currency,
      amount: amount,
      status: status,
      greeting: greeting,
    );
  }

  @override
  Future<List<WalletRecordDto>> getWalletRecords() =>
      WalletApi.instance.getHistoryRecords();

  @override
  Future<List<WalletRecordDto>> getWalletRecordsByFilter(
    HistoryRecordFilter filter,
  ) =>
      WalletApi.instance.getHistoryRecordsByFilter(filter);

  @override
  Future<List<WalletRecordDto>> getWalletRecordsByType(
    WalletRecordType type,
  ) {
    return WalletApi.instance.getRecords(type: _recordTypeKey(type));
  }

  @override
  Future<List<WalletRecordDto>> getDepositRecords() {
    return WalletApi.instance.getDeposits();
  }

  @override
  Future<List<WalletRecordDto>> getWithdrawRecords() {
    return WalletApi.instance.getWithdrawals();
  }

  @override
  Future<WalletOrderResult> claimRedPacket({
    required String orderId,
    String? payPin,
  }) async {
    try {
      return await WalletApi.instance.claimRedPacket(
        orderId: orderId,
        payPin: payPin,
      );
    } on DioError catch (e) {
      return _orderResultFromDio(e, clientOrderId: '');
    }
  }

  @override
  Future<List<RedPacketMember>> getRedPacketMembers(String conversationId) =>
      WalletApi.instance.getRedPacketMembers(conversationId);

  String _resolveCurrency(String payId, String coin) {
    final id = payId.trim();
    if (isWalletPlatformCurrency(id)) return WalletCurrency.platform;
    if (isWalletPlatformCurrency(coin)) return WalletCurrency.platform;
    return WalletCurrency.usdt;
  }

  String _recordTypeKey(WalletRecordType type) {
    switch (type) {
      case WalletRecordType.receive:
        return 'receive';
      case WalletRecordType.transfer:
        return 'transfer';
      case WalletRecordType.redPacket:
        return 'redPacket';
      case WalletRecordType.swap:
        return 'swap';
      case WalletRecordType.all:
        return 'all';
    }
  }

  void _throwPendingWhenNoResponse(DioError e) {
    if (e.response != null) return;
    throw WalletSubmitException(
      requestSent: true,
      message: AppI18n.current.t(
        zhHans: '网络异常，交易状态确认中，可在记录中查看',
        zhHant: '網路異常，交易狀態確認中，可在記錄中查看',
        en: 'Network error. Transaction status is being confirmed. Check History for updates.',
        ja: 'ネットワークエラーです。取引状況を確認中です。履歴でご確認ください。',
        ko: '네트워크 오류입니다. 거래 상태를 확인 중입니다. 기록에서 확인해 주세요.',
      ),
    );
  }

  WalletOrderResult _orderResultFromDio(
    DioError e, {
    required String clientOrderId,
  }) {
    final body = e.response?.data;
    if (body is Map) {
      final map = Map<String, dynamic>.from(body);
      if (map.containsKey('id')) {
        return WalletApi.parseOrderResult(map).copyWithClient(clientOrderId);
      }
      final result = WalletApi.parseOrderResult(map);
      final fallbackMsg = UserApiErrorMessage.fromWallet(e);
      final msg = result.msg.isNotEmpty && !_looksLikeErrorCode(result.msg)
          ? result.msg
          : fallbackMsg;
      return WalletOrderResult(
        ok: result.ok,
        state: result.state,
        err: result.err != WalletOrderErr.none
            ? result.err
            : WalletOrderErr.networkError,
        orderId: result.orderId,
        clientOrderId: result.clientOrderId.isNotEmpty
            ? result.clientOrderId
            : clientOrderId,
        msg: msg,
        data: result.data,
      );
    }
    return WalletOrderResult(
      ok: false,
      state: WalletOrderState.failed,
      err: WalletOrderErr.networkError,
      msg: UserApiErrorMessage.fromWallet(e),
      clientOrderId: clientOrderId,
    );
  }

  bool _looksLikeErrorCode(String text) {
    final value = text.trim();
    if (value.isEmpty) return false;
    return RegExp(r'^[A-Z0-9_]+$').hasMatch(value);
  }
}

extension on WalletOrderResult {
  WalletOrderResult copyWithClient(String clientOrderId) {
    if (this.clientOrderId.isNotEmpty) return this;
    return WalletOrderResult(
      ok: ok,
      state: state,
      err: err,
      orderId: orderId,
      clientOrderId: clientOrderId,
      msg: msg,
      data: data,
    );
  }
}
