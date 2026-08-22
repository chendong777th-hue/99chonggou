import 'package:tencent_cloud_chat_demo/config.dart';

class FriendRealtimeEndpoint {
  const FriendRealtimeEndpoint({
    required this.host,
    required this.port,
    required this.useTls,
  });

  final String host;
  final int port;
  final bool useTls;

  /// 解析 [IMDemoConfig.realtimeTcpBase]。
  ///
  /// - `https://tcp.example.com` → host + TLS + 443
  /// - `http://tcp.example.com:8082` → host + 明文 + 指定端口
  /// - `tcp.example.com` → host + 明文 + [fallbackPort]
  static FriendRealtimeEndpoint? parse(
    String raw, {
    int fallbackPort = IMDemoConfig.realtimeTcpPort,
  }) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) {
      return null;
    }
    final hasScheme = trimmed.contains('://');
    final uri = Uri.tryParse(hasScheme ? trimmed : 'tcp://$trimmed');
    if (uri == null) {
      return null;
    }
    final host = uri.host.trim();
    if (host.isEmpty) {
      return null;
    }
    final scheme = uri.scheme.toLowerCase();
    final useTls = scheme == 'https' || scheme == 'tls' || scheme == 'ssl';
    final port = uri.hasPort
        ? uri.port
        : (useTls ? 443 : (fallbackPort > 0 ? fallbackPort : 8082));
    if (port <= 0) {
      return null;
    }
    return FriendRealtimeEndpoint(
      host: host,
      port: port,
      useTls: useTls,
    );
  }
}
