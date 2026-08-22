typedef VoiceToTextTranscriber = Future<String?> Function({
  String? localAudioPath,
  String? remoteAudioUrl,
});

/// App 侧注入语音识别实现（如腾讯 IM convertVoiceToText）。
class VoiceToTextBridge {
  VoiceToTextBridge._();

  static VoiceToTextTranscriber? transcribe;
  static String? lastErrorMessage;

  static void configure({VoiceToTextTranscriber? transcriber}) {
    transcribe = transcriber;
  }
}
