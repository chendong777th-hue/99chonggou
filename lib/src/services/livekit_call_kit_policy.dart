import 'package:flutter/foundation.dart';

/// Whether callee may start a *new* outgoing CallKit call after media is connected.
///
/// Plan B: never — CallKit must be ensured before connect; connected only reports.
@visibleForTesting
bool calleeMayStartOutgoingCallKitOnConnected() => false;

/// Decision for the iOS CallKit media waiter.
enum IosCallKitAudioWaitDecision {
  /// App-in accept, caller, or Android — do not wait.
  skip,

  /// `didActivate` already latched (possibly before the completer existed).
  alreadyReady,

  /// Completer is in flight — await it; timeout is NOT ready.
  waitPending,
}

IosCallKitAudioWaitDecision iosCallKitAudioWaitDecision({
  required bool callKitAnswerInFlight,
  required bool activatedLatch,
}) {
  if (!callKitAnswerInFlight) return IosCallKitAudioWaitDecision.skip;
  if (activatedLatch) return IosCallKitAudioWaitDecision.alreadyReady;
  return IosCallKitAudioWaitDecision.waitPending;
}

/// Only CallKit-answer callees need the latch. Everyone else may publish.
bool iosCallKitAllowMicPublish({
  required bool isIosCalleeCallKitAnswer,
  required bool activatedLatch,
}) {
  if (!isIosCalleeCallKitAnswer) return true;
  return activatedLatch;
}

/// LiveKit `Hardware.setSpeakerphoneOn` fights CallKit's session.
/// Skip while the system incoming UI still owns audio.
bool iosCallKitShouldApplyLiveKitSpeakerRoute({
  required bool callKitOwnsAudioSession,
}) {
  return !callKitOwnsAudioSession;
}
