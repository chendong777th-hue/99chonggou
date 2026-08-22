/// Client-side LiveKit call telemetry payload (POST /calls/livekit/telemetry).
class LiveKitCallTelemetry {
  const LiveKitCallTelemetry({
    required this.callId,
    required this.role,
    required this.mediaType,
    required this.micPermission,
    required this.cameraPermission,
    required this.connectMs,
    required this.publishMs,
    required this.publishOk,
    required this.remoteAudioTrackCount,
    required this.iceState,
    required this.duplicateIdentity,
    this.endReason,
    this.error,
    this.durationSec = 0,
  });

  final String callId;
  final String role;
  final String mediaType;
  final String micPermission;
  final String cameraPermission;
  final int connectMs;
  final int publishMs;
  final bool publishOk;
  final int remoteAudioTrackCount;
  final String iceState;
  final bool duplicateIdentity;
  final String? endReason;
  final String? error;
  final int durationSec;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'callId': callId,
        'role': role,
        'mediaType': mediaType,
        'micPermission': micPermission,
        'cameraPermission': cameraPermission,
        'connectMs': connectMs,
        'publishMs': publishMs,
        'publishOk': publishOk,
        'remoteAudioTrackCount': remoteAudioTrackCount,
        'iceState': iceState,
        'error': error,
        'duplicateIdentity': duplicateIdentity,
        if (endReason != null && endReason!.isNotEmpty) 'endReason': endReason,
        if (durationSec > 0) 'durationSec': durationSec,
      };
}
