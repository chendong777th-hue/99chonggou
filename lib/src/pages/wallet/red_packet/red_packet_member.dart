class RedPacketMember {
  final String userId;
  final String name;
  final String avatar;
  final String qq;

  const RedPacketMember({
    required this.userId,
    required this.name,
    this.avatar = '',
    this.qq = '',
  });
}
