class VoiceToTextResult {
  const VoiceToTextResult({
    this.text,
    this.errorMessage,
  });

  final String? text;
  final String? errorMessage;

  bool get isSuccess => text != null && text!.trim().isNotEmpty;
}
