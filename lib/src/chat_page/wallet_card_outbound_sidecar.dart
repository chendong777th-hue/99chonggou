/// Dedup / in-flight marks for wallet-card outbound sends (per conversation).
class WalletCardOutboundSidecar {
  WalletCardOutboundSidecar._();

  static final WalletCardOutboundSidecar instance = WalletCardOutboundSidecar._();

  final Map<String, Set<String>> sentByConv = <String, Set<String>>{};
  final Map<String, Set<String>> sendingMarksByConv = <String, Set<String>>{};
  final Set<String> retryingConvs = <String>{};

  Set<String> sentMarksFor(String convId) =>
      sentByConv.putIfAbsent(convId, () => <String>{});

  Set<String> sendingMarksFor(String convId) =>
      sendingMarksByConv.putIfAbsent(convId, () => <String>{});

  bool beginRetry(String convId) => retryingConvs.add(convId);

  void endRetry(String convId) => retryingConvs.remove(convId);

  void resetForConversation(String convId) {
    sentByConv.remove(convId);
    sendingMarksByConv.remove(convId);
    retryingConvs.remove(convId);
  }
}
