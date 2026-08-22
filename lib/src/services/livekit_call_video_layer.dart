import 'package:flutter/foundation.dart';
import 'package:tencent_cloud_chat_demo/src/services/livekit_call_types.dart';

/// When to mount LiveKit video textures on the call page.
///
/// Previously only [LiveKitCallPhase.connected] showed video, so callees in
/// `connecting` and callers waiting in `ringingOut` saw a blank avatar even
/// though camera/audio were already live.
@visibleForTesting
bool shouldShowLiveKitVideoLayer({
  required bool isVideo,
  required LiveKitCallPhase phase,
  required AppCallRole role,
  required bool hasRoom,
}) {
  if (!isVideo) return false;
  switch (phase) {
    case LiveKitCallPhase.connected:
      return true;
    case LiveKitCallPhase.connecting:
      return hasRoom;
    case LiveKitCallPhase.ringingOut:
      return hasRoom && role == AppCallRole.caller;
    case LiveKitCallPhase.ringingIn:
    case LiveKitCallPhase.ended:
    case LiveKitCallPhase.idle:
      return false;
  }
}
