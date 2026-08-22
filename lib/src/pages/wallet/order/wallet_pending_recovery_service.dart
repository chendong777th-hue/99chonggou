import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:tencent_cloud_chat_demo/src/services/network_status_service.dart';

import '../wallet_repository.dart';
import '../wallet_repository_provider.dart';
import 'wallet_order.dart';
import 'wallet_order_events.dart';
import 'wallet_order_service.dart';
import 'wallet_card_im_sender.dart';
import 'wallet_card_replay_guard.dart';
import 'wallet_card_send_service.dart';
import '../progress/wallet_withdraw_progress_service.dart';

class WalletPendingRecoveryResult {
  final int checkedOrders;
  final int refreshedOrders;
  final int queuedCards;

  const WalletPendingRecoveryResult({
    this.checkedOrders = 0,
    this.refreshedOrders = 0,
    this.queuedCards = 0,
  });

  bool get hasChanges => refreshedOrders > 0 || queuedCards > 0;
}

class WalletPendingRecoveryService {
  WalletPendingRecoveryService._()
      : _repo = createWalletRepository(),
        _orderSvc = WalletOrderService();

  static final WalletPendingRecoveryService instance =
      WalletPendingRecoveryService._();

  final WalletRepository _repo;
  final WalletOrderService _orderSvc;

  Future<WalletPendingRecoveryResult>? _task;
  DateTime? _lastRunAt;

  Future<WalletPendingRecoveryResult> recover({
    String reason = 'wallet_recover',
    bool force = false,
  }) {
    final running = _task;
    if (running != null) return running;

    final now = DateTime.now();
    final last = _lastRunAt;
    if (!force && last != null && now.difference(last) < const Duration(seconds: 5)) {
      return Future.value(const WalletPendingRecoveryResult());
    }
    _lastRunAt = now;

    final task = _run(reason: reason).whenComplete(() {
      _task = null;
    });
    _task = task;
    return task;
  }


  bool _shouldRefreshBalance(WalletOrderResult result) {
    if (!result.ok) return false;
    return result.state == WalletOrderState.success ||
        result.state == WalletOrderState.accepted ||
        result.state == WalletOrderState.pending ||
        result.state == WalletOrderState.refunded;
  }

  Future<WalletPendingRecoveryResult> _run({required String reason}) async {
    final pendingBefore = await _orderSvc.recoverPending();
    if (pendingBefore.isEmpty) {
      return const WalletPendingRecoveryResult();
    }

    final results = NetworkStatusService.instance.isOnline
        ? await _orderSvc.refreshPending(_repo.queryOrderStatus)
        : <WalletOrderResult>[];

    if (results.isNotEmpty) {
      WalletOrderEvents.notifyRecord();
    }
    if (results.any(_shouldRefreshBalance)) {
      WalletOrderEvents.notifyBalance();
    }

    await WalletWithdrawProgressService.instance.reconcile(
      reason: reason,
    );

    var queuedCards = 0;
    if (NetworkStatusService.instance.isOnline) {
      queuedCards = await resendRetryableImCards();
    }

    if (kDebugMode && (results.isNotEmpty || queuedCards > 0)) {
      debugPrint(
        'wallet pending recovered reason=$reason '
        'checked=${pendingBefore.length} refreshed=${results.length} '
        'queuedCards=$queuedCards',
      );
    }

    return WalletPendingRecoveryResult(
      checkedOrders: pendingBefore.length,
      refreshedOrders: results.length,
      queuedCards: queuedCards,
    );
  }

  /// REST 已成功、IM 未送达的卡片：在线时补发，失败不得记 alreadySent。
  @visibleForTesting
  static Future<int> sendRetryableCards({
    required bool online,
    required List<Map<String, dynamic>> payloads,
    required Future<bool> Function(Map<String, dynamic> payload) send,
  }) async {
    if (!online || payloads.isEmpty) {
      return 0;
    }
    var queued = 0;
    for (final payload in payloads) {
      if (await send(payload)) {
        queued++;
      }
    }
    return queued;
  }

  Future<int> resendRetryableImCards() async {
    final payloads = await WalletCardSendService().retryPayloads();
    return sendRetryableCards(
      online: true,
      payloads: payloads,
      send: (payload) => WalletCardImSender.instance.send(
        payload,
        source: WalletCardSendSource.recovery,
      ),
    );
  }

  Future<void> syncWithdrawProgress({String reason = 'wallet_recover'}) {
    return WalletWithdrawProgressService.instance.reconcile(reason: reason);
  }
}
