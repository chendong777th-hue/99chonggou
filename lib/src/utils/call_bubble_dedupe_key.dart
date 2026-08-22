/// Unified dedupe keys for call history bubbles.
class CallBubbleDedupeKey {
  CallBubbleDedupeKey._();

  /// C2C connected hangup: conversation + duration (+ optional roomId).
  /// Does not include sender / caller / peer.
  static String c2cHangup({
    required String conversationId,
    required int durationSec,
    String roomId = '',
  }) {
    final convId = conversationId.trim();
    if (convId.isEmpty || durationSec <= 0) {
      return '';
    }
    final room = roomId.trim();
    if (room.isNotEmpty && room != '0' && room != 'null') {
      return 'call-hangup:$convId:$room:$durationSec';
    }
    return 'call-hangup:$convId:$durationSec';
  }

  static bool isC2cConversation(String conversationId) {
    return conversationId.trim().startsWith('c2c_');
  }
}
