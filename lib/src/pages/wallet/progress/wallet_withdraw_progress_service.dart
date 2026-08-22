import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';

import 'package:tencent_cloud_chat_demo/src/api/wallet_api.dart';
import 'package:tencent_cloud_chat_demo/src/services/network_status_service.dart';

import '../order/wallet_order.dart';
import '../order/wallet_pending_store.dart';
import '../wallet_repository.dart';
import 'wallet_withdraw_progress_models.dart';
import 'wallet_withdraw_progress_platform.dart';
import 'wallet_withdraw_progress_store.dart';

class WalletWithdrawProgressService {
  WalletWithdrawProgressService._({
    WalletWithdrawProgressStore? store,
    WalletWithdrawProgressPlatform? platform,
  })  : _store = store ?? WalletWithdrawProgressStore(),
        _platform = platform ?? WalletWithdrawProgressPlatform();

  static final WalletWithdrawProgressService instance =
      WalletWithdrawProgressService._();

  final WalletWithdrawProgressStore _store;
  final WalletWithdrawProgressPlatform _platform;

  Timer? _pollTimer;
  bool _pollInFlight = false;

  Future<void> startChainWithdraw({
    required WalletOrderResult result,
    required WalletPayMethodDto payMethod,
    required int amountMinor,
  }) async {
    final orderId = _firstNonEmpty([
      result.orderId,
      result.data['id']?.toString(),
    ]);
    final clientOrderId = result.clientOrderId.trim();
    if (orderId.isEmpty && clientOrderId.isEmpty) return;

    final coin = payMethod.coin.trim().isEmpty ? 'USDT' : payMethod.coin.trim();
    final amountText = WalletAmount.formatMinor(amountMinor, payMethod.scale);
    final network =
        payMethod.net.trim().isEmpty ? 'TRC20' : payMethod.net.trim();

    var snapshot = WalletWithdrawProgressSnapshot.fromOrderMap(
      result.data,
      amountText: amountText,
      coin: coin,
      network: network,
    );
    if (snapshot.orderId.isEmpty) {
      snapshot = snapshot.copyWith(orderId: orderId);
    }
    if (snapshot.clientOrderId.isEmpty) {
      snapshot = snapshot.copyWith(clientOrderId: clientOrderId);
    }

    await _persistPendingDraft(
      snapshot: snapshot,
      payMethod: payMethod,
      amountMinor: amountMinor,
      result: result,
    );

    final native = await _platform.start(snapshot);
    if (native != null && native.activityId.isNotEmpty) {
      snapshot = snapshot.copyWith(nativeActivityId: native.activityId);
      if (native.pushToken.isNotEmpty && snapshot.orderId.isNotEmpty) {
        unawaited(_reportLiveActivityToken(
          orderId: snapshot.orderId,
          activityId: native.activityId,
          pushToken: native.pushToken,
        ));
      }
    }

    await _store.save(snapshot);
    _ensurePolling(snapshot.stage);
  }

  Future<void> reconcile({String reason = 'wallet_withdraw_progress'}) async {
    final active = await _store.loadActive();
    if (active == null) {
      _stopPolling();
      return;
    }
    if (active.stage.isTerminal) {
      await _finish(active);
      return;
    }
    if (!NetworkStatusService.instance.isOnline) {
      _ensurePolling(active.stage);
      return;
    }
    await _refreshSnapshot(active, reason: reason);
  }

  Future<void> dispose() async {
    _stopPolling();
  }

  Future<void> _refreshSnapshot(
    WalletWithdrawProgressSnapshot active, {
    required String reason,
  }) async {
    if (_pollInFlight) return;
    _pollInFlight = true;
    try {
      final result = await _queryWithdrawOrder(active);
      if (result == null) {
        _ensurePolling(active.stage);
        return;
      }

      final next = active.copyWith(
        orderId: _firstNonEmpty([
          result.orderId,
          active.orderId,
        ]),
        clientOrderId: result.clientOrderId.isNotEmpty
            ? result.clientOrderId
            : active.clientOrderId,
        stage: WalletWithdrawProgressStage.fromApi(
          stage: result.data['stage']?.toString(),
          status: result.data['status']?.toString(),
        ),
        confirmations: _asInt(result.data['confirmations']),
        requiredConfirmations: _asInt(
          result.data['requiredConfirmations'],
          fallback: active.requiredConfirmations,
        ),
        txHashShort: WalletWithdrawProgressSnapshot.shortHash(
          result.data['txId']?.toString() ?? '',
        ),
      );

      await _store.save(next);
      if (next.stage != active.stage ||
          next.confirmations != active.confirmations) {
        await _platform.update(next);
      }

      if (next.stage.isTerminal) {
        await _finish(next);
        return;
      }
      _ensurePolling(next.stage);
      if (kDebugMode) {
        debugPrint(
          'wallet withdraw progress refreshed reason=$reason '
          'orderId=${next.orderId} stage=${next.stage.wireName}',
        );
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('wallet withdraw progress refresh failed: $e');
      }
      _ensurePolling(active.stage);
    } finally {
      _pollInFlight = false;
    }
  }

  Future<void> _finish(WalletWithdrawProgressSnapshot snapshot) async {
    _stopPolling();
    await _platform.end(snapshot);
    await _store.clear();
    if (snapshot.clientOrderId.isNotEmpty) {
      final pending = await WalletPendingStore().load();
      for (final draft in pending) {
        if (draft.clientOrderId == snapshot.clientOrderId) {
          await WalletPendingStore().remove(draft.clientOrderId);
          break;
        }
      }
    }
  }

  Future<WalletOrderResult?> _queryWithdrawOrder(
    WalletWithdrawProgressSnapshot active,
  ) async {
    try {
      if (active.orderId.isNotEmpty) {
        return await WalletApi.instance.getWithdrawOrder(active.orderId);
      }
      if (active.clientOrderId.isNotEmpty) {
        return await WalletApi.instance.getWithdrawOrderByClientId(
          active.clientOrderId,
        );
      }
    } on DioError catch (e) {
      if (e.response?.statusCode == 404) return null;
      rethrow;
    }
    return null;
  }

  Future<void> _reportLiveActivityToken({
    required String orderId,
    required String activityId,
    required String pushToken,
  }) async {
    try {
      final info = await PackageInfo.fromPlatform();
      await WalletApi.instance.reportWithdrawLiveActivityToken(
        orderId: orderId,
        activityId: activityId,
        pushToken: pushToken,
        bundleId: info.packageName,
      );
    } catch (e) {
      if (kDebugMode) {
        debugPrint('report live activity token skipped: $e');
      }
    }
  }

  Future<void> _persistPendingDraft({
    required WalletWithdrawProgressSnapshot snapshot,
    required WalletPayMethodDto payMethod,
    required int amountMinor,
    required WalletOrderResult result,
  }) async {
    if (snapshot.clientOrderId.isEmpty) return;
    final now = DateTime.now().toIso8601String();
    await WalletPendingStore().put(
      WalletOrderDraft(
        clientOrderId: snapshot.clientOrderId,
        type: WalletOrderType.transfer,
        businessType: 'wallet_withdraw',
        amountText: snapshot.amountText,
        amountMinor: amountMinor,
        coin: snapshot.coin,
        network: snapshot.network,
        feeMinor: payMethod.feeMinor,
        feeCoin: payMethod.feeCoin,
        feeScale: payMethod.feeScale,
        feeBalanceMinor: payMethod.feeBalanceMinor,
        receiverId: result.data['toAddress']?.toString() ?? '',
        createdAt: now,
        updatedAt: now,
        serverOrderId: snapshot.orderId,
        orderState: result.state.name,
      ),
    );
  }

  void _ensurePolling(WalletWithdrawProgressStage stage) {
    if (stage.isTerminal) {
      _stopPolling();
      return;
    }
    _pollTimer ??= Timer.periodic(_pollInterval(stage), (_) {
      unawaited(reconcile(reason: 'poll'));
    });
  }

  Duration _pollInterval(WalletWithdrawProgressStage stage) {
    if (stage == WalletWithdrawProgressStage.confirming) {
      return const Duration(seconds: 10);
    }
    return const Duration(seconds: 30);
  }

  void _stopPolling() {
    _pollTimer?.cancel();
    _pollTimer = null;
  }

  static String _firstNonEmpty(List<String?> values) {
    for (final value in values) {
      final text = value?.trim() ?? '';
      if (text.isNotEmpty && text != '--') return text;
    }
    return '';
  }

  static int _asInt(Object? raw, {int fallback = 0}) {
    if (raw is int) return raw;
    if (raw is num) return raw.toInt();
    return int.tryParse(raw?.toString() ?? '') ?? fallback;
  }
}
