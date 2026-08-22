import 'wallet_order.dart';

class WalletOrderChecker {
  const WalletOrderChecker();

  WalletOrderErr checkReceiver(String userId) {
    return userId.trim().isEmpty ? WalletOrderErr.invalidReceiver : WalletOrderErr.none;
  }

  WalletOrderErr checkAmount({
    required String raw,
    required String coin,
    required int scale,
    required int balMinor,
    int maxInt = 12,
  }) {
    final s = raw.trim();
    if (s.isEmpty) return WalletOrderErr.emptyAmount;
    if (s.split('.').length > 2) return WalletOrderErr.invalidAmount;

    final amt = WalletAmount.parseStrict(s, coin: coin, scale: scale, maxInt: maxInt);
    if (amt == null) return WalletOrderErr.invalidAmount;
    if (amt.minor <= 0) return WalletOrderErr.invalidAmount;

    final dot = s.indexOf('.');
    if (dot >= 0 && s.length - dot - 1 > scale) return WalletOrderErr.invalidPrecision;

    final intPart = s.startsWith('.') ? '0' : s.split('.').first;
    if (intPart.length > maxInt) return WalletOrderErr.tooLong;
    if (amt.minor > balMinor) return WalletOrderErr.insufficientBalance;
    return WalletOrderErr.none;
  }

  WalletOrderErr checkPayBalance({
    required int amountMinor,
    required int amountBalanceMinor,
    required String coin,
    required int feeMinor,
    required String feeCoin,
    required int feeBalanceMinor,
  }) {
    final actualFeeCoin = feeCoin.trim().isEmpty ? coin : feeCoin.trim();
    if (amountMinor <= 0) return WalletOrderErr.invalidAmount;

    if (feeMinor <= 0 || actualFeeCoin == coin) {
      if (amountMinor + feeMinor > amountBalanceMinor) return WalletOrderErr.insufficientBalance;
      return WalletOrderErr.none;
    }

    if (amountMinor > amountBalanceMinor) return WalletOrderErr.insufficientBalance;
    if (feeMinor > feeBalanceMinor) return WalletOrderErr.insufficientFee;
    return WalletOrderErr.none;
  }

  WalletOrderErr checkCount({
    required String raw,
    required int? max,
  }) {
    final cnt = int.tryParse(raw.trim()) ?? 0;
    if (cnt <= 0) return WalletOrderErr.invalidCount;
    if (max == null) return WalletOrderErr.groupNotReady;
    if (cnt > max) return WalletOrderErr.countOverLimit;
    return WalletOrderErr.none;
  }

  int? amountMinor({
    required String raw,
    required String coin,
    required int scale,
    int maxInt = 12,
  }) {
    return WalletAmount.parseStrict(raw, coin: coin, scale: scale, maxInt: maxInt)?.minor;
  }
}
