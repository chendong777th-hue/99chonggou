/// App-local call enums (replaces TUICallKit media/role/end-reason types).
enum AppCallMediaType {
  audio,
  video,
}

enum AppCallRole {
  none,
  caller,
  callee,
}

enum AppCallEndReason {
  unknown,
  hangup,
  canceled,
  reject,
  noResponse,
  lineBusy,
  offline,
  otherDeviceAccepted,
  otherDeviceReject,
  endByServer,
}

enum LiveKitCallPhase {
  idle,
  ringingOut,
  ringingIn,
  connecting,
  connected,
  ended,
}

AppCallMediaType appCallMediaTypeFromString(String? raw) {
  final value = raw?.trim().toLowerCase() ?? '';
  return value == 'video' ? AppCallMediaType.video : AppCallMediaType.audio;
}
