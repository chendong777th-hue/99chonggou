typedef FriendRealtimeLineHandler = void Function(String line);
typedef FriendRealtimeVoidHandler = void Function();

class FriendRealtimeConnection {
  FriendRealtimeConnection({
    required this.onLine,
    required this.onDisconnected,
  });

  final FriendRealtimeLineHandler onLine;
  final FriendRealtimeVoidHandler onDisconnected;

  Future<void> connect({
    required String host,
    required int port,
    bool useTls = false,
  }) async {}

  Future<void> send(Map<String, dynamic> message) async {}

  Future<void> close() async {}
}
