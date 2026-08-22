enum ReceiveAddrState {
  loading,
  ready,
  empty,
  failed,
}

class ReceiveAccount {
  final String coin;
  final String network;
  final String address;
  final String memo;
  final ReceiveAddrState state;

  const ReceiveAccount({
    required this.coin,
    required this.network,
    required this.address,
    this.memo = '',
    this.state = ReceiveAddrState.ready,
  });
}
