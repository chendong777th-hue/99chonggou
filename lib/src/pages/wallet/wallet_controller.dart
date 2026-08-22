import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:tencent_cloud_chat_demo/src/errors/app_error.dart';

import 'order/wallet_order_events.dart';
import 'order/wallet_pending_recovery_service.dart';
import 'progress/wallet_withdraw_progress_service.dart';
import 'wallet_error_mapper.dart';
import 'wallet_repository.dart';
import 'wallet_repository_provider.dart';
import 'wallet_store.dart';

class WalletController extends ChangeNotifier {
  final WalletRepository _repo;
  WalletController({
    WalletRepository? repo,
  }) : _repo = repo ?? createWalletRepository() {
    WalletOrderEvents.balanceChanged.addListener(_onBalanceChanged);
  }

  bool loading = false;
  bool loadFailed = false;
  bool showBal = true;
  AppError? lastError;

  String totalBal = '0.00';
  String totalBalUsd = '';
  String trxAddr = '';
  List<CoinDto> coins = [];

  bool _dead = false;

  Future<void> load({bool force = false}) async {
    if (loading) return;

    final cached = WalletStore.instance.cachedWallet;
    if (cached != null) {
      totalBal = cached.totalBal;
      totalBalUsd = cached.totalBalUsd;
      trxAddr = cached.trxAddr;
      coins = cached.coins;
    }

    loading = cached == null;
    loadFailed = false;
    lastError = null;
    notifyListeners();

    try {
      _recoverPending().catchError((e) {
        debugPrint('recover pending wallet orders error: $e');
      });

      final data = await WalletStore.instance.getWallet(repo: _repo, force: force);
      totalBal = data.totalBal;
      totalBalUsd = data.totalBalUsd;
      trxAddr = data.trxAddr;
      coins = data.coins;
      loadFailed = false;
      lastError = null;
    } catch (e, st) {
      loadFailed = true;
      lastError = WalletErrorMapper.map(e, action: 'load');
      if (kDebugMode) {
        debugPrint('load wallet error: $e\n$st');
      }
    } finally {
      loading = false;
      if (!_dead) notifyListeners();
    }
  }

  Future<void> _recoverPending() async {
    await WalletPendingRecoveryService.instance.recover(
      reason: 'wallet_home',
    );
    await WalletWithdrawProgressService.instance.reconcile(
      reason: 'wallet_home',
    );
  }


  void _onBalanceChanged() {
    if (_dead) return;
    unawaited(load(force: true));
  }

  void toggleBal() {
    showBal = !showBal;
    notifyListeners();
  }

  @override
  void dispose() {
    _dead = true;
    WalletOrderEvents.balanceChanged.removeListener(_onBalanceChanged);
    super.dispose();
  }
}
