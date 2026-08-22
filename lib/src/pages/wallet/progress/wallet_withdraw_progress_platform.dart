import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'wallet_withdraw_progress_models.dart';

class WalletWithdrawProgressPlatform {
  WalletWithdrawProgressPlatform({
    MethodChannel? channel,
  }) : _channel = channel ?? const MethodChannel('wallet_withdraw_progress');

  final MethodChannel _channel;

  Future<WalletWithdrawProgressNativeStartResult?> start(
    WalletWithdrawProgressSnapshot snapshot,
  ) async {
    if (kIsWeb) return null;
    if (!Platform.isIOS && !Platform.isAndroid) return null;

    try {
      final result = await _channel.invokeMethod<Map<dynamic, dynamic>>(
        'start',
        _snapshotArgs(snapshot),
      );
      if (result == null) return null;
      return WalletWithdrawProgressNativeStartResult(
        activityId: result['activityId']?.toString() ?? '',
        pushToken: result['pushToken']?.toString() ?? '',
        supported: result['supported'] as bool? ?? true,
      );
    } on PlatformException catch (e) {
      if (kDebugMode) {
        debugPrint('wallet_withdraw_progress.start failed: ${e.message}');
      }
      return null;
    }
  }

  Future<bool> update(WalletWithdrawProgressSnapshot snapshot) async {
    if (kIsWeb) return false;
    if (!Platform.isIOS && !Platform.isAndroid) return false;

    try {
      final ok = await _channel.invokeMethod<bool>(
        'update',
        _snapshotArgs(snapshot),
      );
      return ok ?? false;
    } on PlatformException catch (e) {
      if (kDebugMode) {
        debugPrint('wallet_withdraw_progress.update failed: ${e.message}');
      }
      return false;
    }
  }

  Future<bool> end(
    WalletWithdrawProgressSnapshot snapshot, {
    int dismissalSeconds = 4,
  }) async {
    if (kIsWeb) return false;
    if (!Platform.isIOS && !Platform.isAndroid) return false;

    try {
      final ok = await _channel.invokeMethod<bool>(
        'end',
        {
          ..._snapshotArgs(snapshot),
          'dismissalSeconds': dismissalSeconds,
        },
      );
      return ok ?? false;
    } on PlatformException catch (e) {
      if (kDebugMode) {
        debugPrint('wallet_withdraw_progress.end failed: ${e.message}');
      }
      return false;
    }
  }

  Future<WalletWithdrawProgressSnapshot?> getActive({String? orderId}) async {
    if (kIsWeb) return null;
    if (!Platform.isIOS && !Platform.isAndroid) return null;

    try {
      final result = await _channel.invokeMethod<Map<dynamic, dynamic>>(
        'getActive',
        {
          if (orderId != null && orderId.trim().isNotEmpty)
            'orderId': orderId.trim(),
        },
      );
      if (result == null || result.isEmpty) return null;
      return WalletWithdrawProgressSnapshot.fromJson(
        Map<String, dynamic>.from(result),
      );
    } on PlatformException {
      return null;
    }
  }

  Map<String, dynamic> _snapshotArgs(WalletWithdrawProgressSnapshot snapshot) {
    return {
      'orderId': snapshot.orderId,
      'clientOrderId': snapshot.clientOrderId,
      'stage': snapshot.stage.wireName,
      'amountText': snapshot.amountText,
      'coin': snapshot.coin,
      'network': snapshot.network,
      'confirmations': snapshot.confirmations,
      'requiredConfirmations': snapshot.requiredConfirmations,
      'txHashShort': snapshot.txHashShort,
      if (snapshot.nativeActivityId.isNotEmpty)
        'activityId': snapshot.nativeActivityId,
    };
  }
}

class WalletWithdrawProgressNativeStartResult {
  final String activityId;
  final String pushToken;
  final bool supported;

  const WalletWithdrawProgressNativeStartResult({
    required this.activityId,
    required this.pushToken,
    required this.supported,
  });
}
