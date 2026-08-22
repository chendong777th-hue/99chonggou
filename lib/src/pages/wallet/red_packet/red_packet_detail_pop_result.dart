class RedPacketDetailPopResult {
  final String status;
  final bool claimed;

  const RedPacketDetailPopResult({
    required this.status,
    this.claimed = false,
  });
}
