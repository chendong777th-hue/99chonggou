import 'dart:async';
import 'dart:convert';
import 'dart:io';

typedef FriendRealtimeLineHandler = void Function(String line);
typedef FriendRealtimeVoidHandler = void Function();

class FriendRealtimeConnection {
  FriendRealtimeConnection({
    required this.onLine,
    required this.onDisconnected,
  });

  final FriendRealtimeLineHandler onLine;
  final FriendRealtimeVoidHandler onDisconnected;

  Socket? _socket;
  StreamSubscription<dynamic>? _subscription;
  final StringBuffer _buffer = StringBuffer();

  Future<void> connect({
    required String host,
    required int port,
    bool useTls = false,
  }) async {
    await close();
    final socket = useTls
        ? await SecureSocket.connect(
            host,
            port,
            timeout: const Duration(seconds: 10),
          )
        : await Socket.connect(
            host,
            port,
            timeout: const Duration(seconds: 10),
          );
    _socket = socket;
    _subscription = socket.listen(
      (data) => _onChunk(utf8.decode(data)),
      onError: (_) => _handleDisconnect(),
      onDone: _handleDisconnect,
      cancelOnError: true,
    );
  }

  void _onChunk(String chunk) {
    _buffer.write(chunk);
    final text = _buffer.toString();
    final lines = text.split('\n');
    _buffer
      ..clear()
      ..write(lines.removeLast());
    for (final line in lines) {
      final trimmed = line.trim();
      if (trimmed.isEmpty) {
        continue;
      }
      onLine(trimmed);
    }
  }

  Future<void> send(Map<String, dynamic> message) async {
    final socket = _socket;
    if (socket == null) {
      return;
    }
    socket.add(utf8.encode('${jsonEncode(message)}\n'));
    await socket.flush();
  }

  Future<void> close() async {
    final subscription = _subscription;
    _subscription = null;
    await subscription?.cancel();
    final socket = _socket;
    _socket = null;
    _buffer.clear();
    if (socket != null) {
      try {
        await socket.close();
      } catch (_) {}
    }
  }

  void _handleDisconnect() {
    if (_socket == null && _subscription == null) {
      return;
    }
    unawaited(close());
    onDisconnected();
  }
}
