/// 服务端 BeforeSend 拒发分类（错误码以服务端文档为准）。
enum WalletCardImReject {
  none,
  duplicate,
  invalid,
}

class WalletCardImSendOutcome {
  final bool delivered;
  final WalletCardImReject reject;
  final bool outcomeUnknown;

  const WalletCardImSendOutcome.success()
      : delivered = true,
        reject = WalletCardImReject.none,
        outcomeUnknown = false;

  const WalletCardImSendOutcome.failed()
      : delivered = false,
        reject = WalletCardImReject.none,
        outcomeUnknown = false;

  const WalletCardImSendOutcome.unknown()
      : delivered = false,
        reject = WalletCardImReject.none,
        outcomeUnknown = true;

  const WalletCardImSendOutcome.reject(this.reject)
      : delivered = reject == WalletCardImReject.duplicate,
        outcomeUnknown = false;

  bool get shouldRetry =>
      !delivered && !outcomeUnknown && reject != WalletCardImReject.invalid;
}

class WalletCardSendFailure {
  const WalletCardSendFailure._();

  static WalletCardImReject classify({
    int? code,
    String? desc,
  }) {
    final haystack = '${code ?? ''} ${desc ?? ''}'.toUpperCase();
    if (_containsAny(haystack, const [
      'WALLET_CARD_DUP',
      'WALLET_CARD_DUPLICATE',
      'WALLET_CARD_ALREADY_SENT',
    ])) {
      return WalletCardImReject.duplicate;
    }
    if (_containsAny(haystack, const [
      'WALLET_CARD_INVALID',
      'WALLET_CARD_FORGED',
      'WALLET_CARD_FORBIDDEN',
    ])) {
      return WalletCardImReject.invalid;
    }
    return WalletCardImReject.none;
  }

  static WalletCardImSendOutcome outcomeOf({
    int? code,
    String? desc,
  }) {
    final reject = classify(code: code, desc: desc);
    if (reject != WalletCardImReject.none) {
      return WalletCardImSendOutcome.reject(reject);
    }
    if (code == null || code == 0) {
      return const WalletCardImSendOutcome.success();
    }
    return const WalletCardImSendOutcome.failed();
  }

  static bool _containsAny(String haystack, List<String> needles) {
    for (final needle in needles) {
      if (haystack.contains(needle)) return true;
    }
    return false;
  }
}
