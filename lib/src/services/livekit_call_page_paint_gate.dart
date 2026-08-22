import 'package:flutter/foundation.dart';
import 'package:tencent_cloud_chat_demo/src/services/livekit_call_session.dart';
import 'package:tencent_cloud_chat_demo/src/services/livekit_call_types.dart';
import 'package:tencent_cloud_chat_demo/src/services/livekit_call_video_layer.dart';

/// Paint-relevant slice of [LiveKitCallSession] for [LiveKitCallPage] rebuilds.
@immutable
class LiveKitCallPagePaintSnapshot {
  const LiveKitCallPagePaintSnapshot({
    required this.phase,
    required this.role,
    required this.isVideo,
    required this.hasRoom,
    required this.showVideoLayer,
    required this.localTrackId,
    required this.remoteTrackId,
    required this.micEnabled,
    required this.camEnabled,
    required this.speakerOn,
    required this.peerUserId,
  });

  final LiveKitCallPhase phase;
  final AppCallRole role;
  final bool isVideo;
  final bool hasRoom;
  final bool showVideoLayer;
  final String localTrackId;
  final String remoteTrackId;
  final bool micEnabled;
  final bool camEnabled;
  final bool speakerOn;
  final String peerUserId;

  factory LiveKitCallPagePaintSnapshot.fromSession(LiveKitCallSession session) {
    final local = session.localVideoTrack;
    final remote = session.remoteVideoTrack;
    final isVideo = session.isVideo;
    final phase = session.phase;
    final role = session.role;
    final hasRoom = session.room != null;
    return LiveKitCallPagePaintSnapshot(
      phase: phase,
      role: role,
      isVideo: isVideo,
      hasRoom: hasRoom,
      showVideoLayer: shouldShowLiveKitVideoLayer(
        isVideo: isVideo,
        phase: phase,
        role: role,
        hasRoom: hasRoom,
      ),
      localTrackId: local?.sid ?? '',
      remoteTrackId: remote?.sid ?? '',
      micEnabled: session.micEnabled,
      camEnabled: session.camEnabled,
      speakerOn: session.speakerOn,
      peerUserId: session.peerUserId,
    );
  }

  static bool shouldRebuild({
    required LiveKitCallPagePaintSnapshot? previous,
    required LiveKitCallPagePaintSnapshot next,
  }) {
    return previous == null || previous != next;
  }

  @override
  bool operator ==(Object other) {
    return other is LiveKitCallPagePaintSnapshot &&
        other.phase == phase &&
        other.role == role &&
        other.isVideo == isVideo &&
        other.hasRoom == hasRoom &&
        other.showVideoLayer == showVideoLayer &&
        other.localTrackId == localTrackId &&
        other.remoteTrackId == remoteTrackId &&
        other.micEnabled == micEnabled &&
        other.camEnabled == camEnabled &&
        other.speakerOn == speakerOn &&
        other.peerUserId == peerUserId;
  }

  @override
  int get hashCode => Object.hash(
        phase,
        role,
        isVideo,
        hasRoom,
        showVideoLayer,
        localTrackId,
        remoteTrackId,
        micEnabled,
        camEnabled,
        speakerOn,
        peerUserId,
      );
}

/// Delay before enabling full-bleed peer-face decode on the call page.
@visibleForTesting
Duration liveKitCallHeavyBgDelay({
  required bool isVideo,
  required Duration enterTransition,
}) {
  const baseExtra = Duration(milliseconds: 250);
  final videoExtra =
      isVideo ? const Duration(milliseconds: 200) : Duration.zero;
  return enterTransition + baseExtra + videoExtra;
}

/// memCache edge for scrimmed full-bleed bg (softer under overlay is OK).
@visibleForTesting
int liveKitCallHeavyBgMemCachePx(double shortestSideLogical) {
  if (shortestSideLogical <= 0) {
    return 720;
  }
  final half = (shortestSideLogical * 0.5).round();
  return half.clamp(360, 720);
}
