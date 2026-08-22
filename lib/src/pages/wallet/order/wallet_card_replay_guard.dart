import 'wallet_card_sent_store.dart';

enum WalletCardSendSource {
  /// 支付 REST 成功后的当场发卡。
  payment,

  /// 用户在失败弹窗 / 待处理列表里点「重新发送」。
  manual,

  /// 登录 / 回前台 recovery：REST 已成功但 IM 未送达时补发。
  recovery,

  /// 进会话、拉历史等顺手自动补发。必须跳过。
  autoRetry,
}

/// 钱包 IM 卡片发送闸门：同一 `orderId` 成功后禁止再发；自动补发一律禁止。
class WalletCardReplayGuard {
  WalletCardReplayGuard({WalletCardSentStore? store})
      : _store = store ?? WalletCardSentStore.instance;

  static final WalletCardReplayGuard instance = WalletCardReplayGuard();

  final WalletCardSentStore _store;
  final Set<String> _inflight = <String>{};

  Iterable<String> keysOf({
    String orderId = '',
    String clientOrderId = '',
  }) {
    return <String>[orderId, clientOrderId];
  }

  Future<void> rememberRestSuccess({
    String orderId = '',
    String clientOrderId = '',
  }) {
    return _store.markRestCommitted(keysOf(
      orderId: orderId,
      clientOrderId: clientOrderId,
    ));
  }

  Future<void> rememberImSent({
    String orderId = '',
    String clientOrderId = '',
  }) {
    return _store.markSent(keysOf(
      orderId: orderId,
      clientOrderId: clientOrderId,
    ));
  }

  Future<bool> allowSend({
    String orderId = '',
    String clientOrderId = '',
    required WalletCardSendSource source,
  }) async {
    final keys = keysOf(orderId: orderId, clientOrderId: clientOrderId);
    if (await _store.isSent(keys)) {
      return false;
    }
    if (source == WalletCardSendSource.autoRetry) {
      return false;
    }
    return source == WalletCardSendSource.payment ||
        source == WalletCardSendSource.manual ||
        source == WalletCardSendSource.recovery;
  }

  Future<bool> alreadySent({
    String orderId = '',
    String clientOrderId = '',
  }) {
    return _store.isSent(keysOf(
      orderId: orderId,
      clientOrderId: clientOrderId,
    ));
  }

  bool tryBeginSend({
    String orderId = '',
    String clientOrderId = '',
  }) {
    final keys = _inflightKeys(orderId: orderId, clientOrderId: clientOrderId);
    if (keys.isEmpty) return false;
    for (final key in keys) {
      if (_inflight.contains(key)) return false;
    }
    _inflight.addAll(keys);
    return true;
  }

  void endSend({
    String orderId = '',
    String clientOrderId = '',
  }) {
    _inflight.removeAll(
      _inflightKeys(orderId: orderId, clientOrderId: clientOrderId),
    );
  }

  Set<String> _inflightKeys({
    String orderId = '',
    String clientOrderId = '',
  }) {
    return keysOf(orderId: orderId, clientOrderId: clientOrderId)
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty && e != '--')
        .toSet();
  }
}
