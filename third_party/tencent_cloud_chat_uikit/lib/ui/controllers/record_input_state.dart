/// Voice-input recording pipeline states (page-local).
enum RecordInputState {
  idle,
  preparing,
  recording,
  stopping,
  cancelled,
  error,
}

enum RecordReleaseZone {
  send,
  cancel,
  convertText,
}

enum RecordOverlayMode {
  recording,
  convertReview,
}
