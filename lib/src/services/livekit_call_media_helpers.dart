import 'package:flutter/foundation.dart';
import 'package:livekit_client/livekit_client.dart';
import 'package:tencent_cloud_chat_demo/src/api/livekit_call_api.dart';
import 'package:tencent_cloud_chat_demo/src/models/livekit_call_credentials.dart';
import 'package:tencent_cloud_chat_demo/src/services/livekit_call_types.dart';
import 'package:tencent_cloud_chat_demo/src/services/livekit_call_ui_log.dart';

/// Thrown when local mic/camera publish fails after [Room.connect].
class LiveKitPublishException implements Exception {
  LiveKitPublishException(this.kind, [this.detail = '']);

  final String kind;
  final String detail;

  @override
  String toString() =>
      detail.isNotEmpty ? 'LiveKitPublishException($kind: $detail)' : 'LiveKitPublishException($kind)';
}

/// User-visible message when mic/camera publish fails after join.
String liveKitPublishFailureMessage(String kind) {
  switch (kind.trim().toLowerCase()) {
    case 'camera':
      return '无法开启摄像头，通话已结束';
    case 'mic':
    default:
      return '无法开启麦克风，通话已结束';
  }
}

bool _shouldFallbackAcceptToFetchToken(LiveKitCallApiException e) {
  return e.code == 'CALL_ALREADY_ANSWERED' || e.code == 'REQUEST_TIMEOUT';
}

/// When set by [LiveKitVoipBridge], iOS CallKit answer waits here before connect/camera.
/// Returns `true` when mic publish is allowed (`skip` / already activated).
Future<bool> Function({Duration timeout})? iosCallKitAudioReadyWaiter;

/// True while a CallKit system-answer still owns AVAudioSession (join in flight).
bool Function()? iosCallKitOwnsAudioSession;

/// Wait for CallKit `didActivate` when a VoIP answer is in progress.
///
/// Returns `true` when there is no CallKit answer in flight, or activate
/// is already latched. Timeout is `false` — do not publish on that path.
Future<bool> waitForIosCallKitAudioReady({
  Duration timeout = const Duration(seconds: 8),
}) async {
  final waiter = iosCallKitAudioReadyWaiter;
  if (waiter == null) {
    return true;
  }
  return waiter(timeout: timeout);
}

/// Before LiveKit join on iOS callee calls — CallKit must activate AVAudioSession first.
///
/// Applies to **audio and video**. Skipping audio-only left voice answers racing
/// CallKit `didActivate`, which intermittently yields one-way / no remote sound.
Future<void> prepareIosCallKitMediaJoin({
  required bool video,
  required bool isCallee,
}) async {
  if (kIsWeb || defaultTargetPlatform != TargetPlatform.iOS) {
    return;
  }
  if (!isCallee) {
    return;
  }
  if (kDebugMode) {
    debugPrint(
      'LiveKitCallMediaHelpers: prepareIosCallKitMediaJoin '
      'wait CallKit audio video=$video',
    );
  }
  await waitForIosCallKitAudioReady();
}

/// Accept once; on conflict/timeout fall back to token refresh.
Future<LiveKitCallCredentials> resolveAcceptCredentials({
  required String callId,
  LiveKitCallApi? api,
}) async {
  final client = api ?? LiveKitCallApi.instance;
  try {
    return await client.accept(callId: callId);
  } on LiveKitCallApiException catch (e) {
    if (!_shouldFallbackAcceptToFetchToken(e)) {
      rethrow;
    }
    if (kDebugMode) {
      debugPrint(
        'LiveKitCallMediaHelpers: accept returned ${e.code}, '
        'fetching token callId=$callId',
      );
    }
    return client.fetchToken(callId: callId);
  }
}

/// Publish mic (+ camera for video).
///
/// Returns `true` when tracks were published. Returns `false` when iOS
/// CallKit audio is not ready — caller must retry after `didActivate`.
/// Throws [LiveKitPublishException] only when publish itself fails.
Future<bool> publishLocalCallTracks({
  required Room room,
  required bool video,
}) async {
  final local = room.localParticipant;
  if (local == null) {
    throw LiveKitPublishException('mic', 'localParticipant missing');
  }

  // Mic publish needs an active CallKit session on iOS; wait even for audio-only.
  if (!kIsWeb && defaultTargetPlatform == TargetPlatform.iOS) {
    final ready = await waitForIosCallKitAudioReady();
    if (!ready) {
      liveKitCallUiLog(
        'publishLocalCallTracks defer mic — CallKit audio not ready',
      );
      return false;
    }
  }

  final micPub = await local.setMicrophoneEnabled(true);
  if (micPub == null || micPub.track == null) {
    throw LiveKitPublishException('mic', 'publishOk=false');
  }

  if (!video) {
    return true;
  }

  if (!kIsWeb && defaultTargetPlatform == TargetPlatform.iOS) {
    final ready = await waitForIosCallKitAudioReady();
    if (!ready) {
      liveKitCallUiLog(
        'publishLocalCallTracks defer camera — CallKit audio not ready',
      );
      return true;
    }
  }

  final camPub = await local.setCameraEnabled(true);
  if (camPub == null || camPub.track == null) {
    throw LiveKitPublishException('camera', 'publishOk=false');
  }
  return true;
}

/// Debug: log local mic/camera publications after publish.
void logLocalTrackPublications(Room? room, {required String tag}) {
  if (!kDebugMode || room == null) {
    return;
  }
  final local = room.localParticipant;
  if (local == null) {
    debugPrint('LiveKitCallMediaHelpers[$tag]: localParticipant=null');
    return;
  }
  for (final pub in local.trackPublications.values) {
    debugPrint(
      'LiveKitCallMediaHelpers[$tag]: LOCAL TRACK '
      'source=${pub.source} kind=${pub.kind} muted=${pub.muted} '
      'track=${pub.track?.runtimeType}',
    );
  }
}

/// Debug: log remote audio publication state for one participant.
void logRemoteAudioPublications(
  RemoteParticipant participant, {
  required String tag,
}) {
  if (!kDebugMode) {
    return;
  }
  for (final pub in participant.audioTrackPublications) {
    debugPrint(
      'LiveKitCallMediaHelpers[$tag]: REMOTE AUDIO '
      'identity=${participant.identity} '
      'source=${pub.source} kind=${pub.kind} '
      'subscribed=${pub.subscribed} muted=${pub.muted} '
      'track=${pub.track?.runtimeType}',
    );
  }
}

int countRemoteAudioTracks(Room? room) {
  if (room == null) {
    return 0;
  }
  var count = 0;
  for (final participant in room.remoteParticipants.values) {
    for (final pub in participant.audioTrackPublications) {
      if (pub.track != null && pub.subscribed) {
        count++;
      }
    }
  }
  return count;
}

int countLocalAudioTracks(Room? room) {
  if (room == null) {
    return 0;
  }
  var count = 0;
  for (final pub in room.localParticipant?.audioTrackPublications ?? const []) {
    if (pub.track != null) {
      count++;
    }
  }
  return count;
}

/// Compact always-on snapshot for one-way audio diagnosis.
String describeCallAudioState(Room? room) {
  if (room == null) {
    return 'room=null';
  }
  var localMuted = 0;
  for (final pub in room.localParticipant?.audioTrackPublications ?? const []) {
    if (pub.muted) {
      localMuted++;
    }
  }
  final remotes = room.remoteParticipants.values.toList();
  var remotePubs = 0;
  var remoteSub = 0;
  var remoteReady = 0;
  var remoteMuted = 0;
  final parts = <String>[];
  for (final participant in remotes) {
    final audios = participant.audioTrackPublications;
    if (audios.isEmpty) {
      parts.add('${participant.identity}(noAudioPub)');
      continue;
    }
    for (final pub in audios) {
      remotePubs++;
      if (pub.subscribed) {
        remoteSub++;
      }
      if (pub.subscribed && pub.track != null) {
        remoteReady++;
      }
      if (pub.muted) {
        remoteMuted++;
      }
      parts.add(
        '${participant.identity}('
        'src=${pub.source},sub=${pub.subscribed},'
        'muted=${pub.muted},track=${pub.track != null})',
      );
    }
  }
  return 'localAudio=${countLocalAudioTracks(room)} localMuted=$localMuted '
      'remotes=${remotes.length} remotePubs=$remotePubs '
      'remoteSub=$remoteSub remoteReady=$remoteReady remoteMuted=$remoteMuted '
      'hasLive=${hasLiveCallAudioTracks(room)} '
      'detail=${parts.isEmpty ? '-' : parts.join(';')}';
}

/// True when at least one local or remote audio track is attached.
bool hasLiveCallAudioTracks(Room? room) {
  if (room == null) {
    return false;
  }
  if (countRemoteAudioTracks(room) > 0) {
    return true;
  }
  for (final pub in room.localParticipant?.audioTrackPublications ?? const []) {
    if (pub.track != null) {
      return true;
    }
  }
  return false;
}

/// Start subscribed remote audio renderers (iOS may need this after CallKit handoff).
Future<void> ensureRemoteAudioPlayback(Room? room, {String tag = ''}) async {
  if (room == null) {
    return;
  }
  var started = 0;
  var skippedNotSub = 0;
  var skippedNoTrack = 0;
  var startFailed = 0;
  for (final participant in room.remoteParticipants.values) {
    for (final pub in participant.audioTrackPublications) {
      final track = pub.track;
      if (!pub.subscribed) {
        skippedNotSub++;
        continue;
      }
      if (track is! RemoteAudioTrack) {
        skippedNoTrack++;
        continue;
      }
      try {
        await track.start();
        started++;
      } catch (e, st) {
        startFailed++;
        liveKitCallUiLog(
          'ensureRemoteAudioPlayback startFailed tag=$tag '
          'identity=${participant.identity} error=$e',
        );
        if (kDebugMode) {
          debugPrint(
            'LiveKitCallMediaHelpers${tag.isEmpty ? '' : '[$tag]'}: '
            'remote audio start failed identity=${participant.identity}: '
            '$e\n$st',
          );
        }
      }
    }
  }
  liveKitCallUiLog(
    'ensureRemoteAudioPlayback tag=$tag started=$started '
    'skippedNotSub=$skippedNotSub skippedNoTrack=$skippedNoTrack '
    'startFailed=$startFailed ${describeCallAudioState(room)}',
  );
}

/// Ensure remote audio publications are subscribed (caller may join before callee publishes).
Future<int> ensureRemoteAudioSubscribed(Room? room, {String tag = ''}) async {
  if (room == null) {
    liveKitCallUiLog('ensureRemoteAudioSubscribed tag=$tag room=null');
    return 0;
  }
  var subscribedCount = 0;
  var emptyTrackWaitOk = 0;
  var resubscribed = 0;
  var subscribeRequested = 0;
  for (final participant in room.remoteParticipants.values) {
    for (final pub in participant.audioTrackPublications) {
      if (kDebugMode) {
        debugPrint(
          'LiveKitCallMediaHelpers${tag.isEmpty ? '' : '[$tag]'}: '
          'check remote audio identity=${participant.identity} '
          'source=${pub.source} subscribed=${pub.subscribed} '
          'muted=${pub.muted} track=${pub.track?.runtimeType}',
        );
      }
      if (pub.subscribed && pub.track != null) {
        subscribedCount++;
        continue;
      }
      if (pub.subscribed && pub.track == null) {
        // autoSubscribe may mark subscribed before track attaches — wait briefly.
        liveKitCallUiLog(
          'ensureRemoteAudioSubscribed emptyTrack tag=$tag '
          'identity=${participant.identity}',
        );
        for (var attempt = 0; attempt < 6 && pub.track == null; attempt++) {
          await Future<void>.delayed(const Duration(milliseconds: 80));
        }
        if (pub.track != null) {
          emptyTrackWaitOk++;
          subscribedCount++;
          continue;
        }
        try {
          await pub.unsubscribe();
          await pub.subscribe();
          resubscribed++;
          if (pub.subscribed || pub.track != null) {
            subscribedCount++;
          }
          liveKitCallUiLog(
            'ensureRemoteAudioSubscribed resubscribe tag=$tag '
            'identity=${participant.identity} subscribed=${pub.subscribed} '
            'track=${pub.track != null}',
          );
        } catch (e, st) {
          liveKitCallUiLog(
            'ensureRemoteAudioSubscribed resubscribeFailed tag=$tag '
            'identity=${participant.identity} error=$e',
          );
          if (kDebugMode) {
            debugPrint(
              'LiveKitCallMediaHelpers${tag.isEmpty ? '' : '[$tag]'}: '
              'resubscribe audio failed identity=${participant.identity}: '
              '$e\n$st',
            );
          }
        }
        continue;
      }
      try {
        await pub.subscribe();
        subscribeRequested++;
        if (pub.subscribed || pub.track != null) {
          subscribedCount++;
        }
        liveKitCallUiLog(
          'ensureRemoteAudioSubscribed subscribe tag=$tag '
          'identity=${participant.identity} subscribed=${pub.subscribed} '
          'track=${pub.track != null}',
        );
      } catch (e, st) {
        liveKitCallUiLog(
          'ensureRemoteAudioSubscribed subscribeFailed tag=$tag '
          'identity=${participant.identity} error=$e',
        );
        if (kDebugMode) {
          debugPrint(
            'LiveKitCallMediaHelpers${tag.isEmpty ? '' : '[$tag]'}: '
            'subscribe audio failed identity=${participant.identity}: '
            '$e\n$st',
          );
        }
      }
    }
  }
  liveKitCallUiLog(
    'ensureRemoteAudioSubscribed tag=$tag ready=$subscribedCount '
    'emptyTrackWaitOk=$emptyTrackWaitOk resubscribed=$resubscribed '
    'subscribeRequested=$subscribeRequested ${describeCallAudioState(room)}',
  );
  return subscribedCount;
}

/// Ensure remote video publications are subscribed (callee may publish after caller joined).
Future<int> ensureRemoteVideoSubscribed(Room? room, {String tag = ''}) async {
  if (room == null) {
    return 0;
  }
  var subscribedCount = 0;
  for (final participant in room.remoteParticipants.values) {
    for (final pub in participant.videoTrackPublications) {
      if (kDebugMode) {
        debugPrint(
          'LiveKitCallMediaHelpers${tag.isEmpty ? '' : '[$tag]'}: '
          'check remote video identity=${participant.identity} '
          'source=${pub.source} subscribed=${pub.subscribed} '
          'muted=${pub.muted} track=${pub.track?.runtimeType}',
        );
      }
      if (pub.subscribed && pub.track != null) {
        subscribedCount++;
        continue;
      }
      if (pub.subscribed && pub.track == null) {
        continue;
      }
      try {
        await pub.subscribe();
        if (pub.subscribed || pub.track != null) {
          subscribedCount++;
        }
      } catch (e, st) {
        if (kDebugMode) {
          debugPrint(
            'LiveKitCallMediaHelpers${tag.isEmpty ? '' : '[$tag]'}: '
            'subscribe video failed identity=${participant.identity}: '
            '$e\n$st',
          );
        }
      }
    }
  }
  return subscribedCount;
}

/// Retry subscribe + audio route — remote tracks may arrive after join.
Future<void> scheduleRemoteAudioRecovery(
  Room? room, {
  required String tag,
  Future<void> Function()? onAudioReady,
}) async {
  liveKitCallUiLog(
    'scheduleRemoteAudioRecovery begin tag=$tag ${describeCallAudioState(room)}',
  );
  await ensureRemoteAudioSubscribed(room, tag: tag);
  await ensureRemoteVideoSubscribed(room, tag: tag);
  await ensureRemoteAudioPlayback(room, tag: tag);
  if (hasLiveCallAudioTracks(room)) {
    await onAudioReady?.call();
  }
  await Future<void>.delayed(const Duration(milliseconds: 320));
  await ensureRemoteAudioSubscribed(room, tag: '$tag-retry');
  await ensureRemoteVideoSubscribed(room, tag: '$tag-retry');
  await ensureRemoteAudioPlayback(room, tag: '$tag-retry');
  if (hasLiveCallAudioTracks(room)) {
    await onAudioReady?.call();
  }
  await Future<void>.delayed(const Duration(milliseconds: 680));
  await ensureRemoteAudioSubscribed(room, tag: '$tag-retry2');
  await ensureRemoteAudioPlayback(room, tag: '$tag-retry2');
  if (hasLiveCallAudioTracks(room)) {
    await onAudioReady?.call();
  }
  liveKitCallUiLog(
    'scheduleRemoteAudioRecovery end tag=$tag ${describeCallAudioState(room)}',
  );
}

AppCallEndReason? disconnectReasonToEndReason(DisconnectReason? reason) {
  if (reason == null) {
    return null;
  }
  switch (reason) {
    case DisconnectReason.duplicateIdentity:
      return AppCallEndReason.otherDeviceAccepted;
    case DisconnectReason.participantRemoved:
    case DisconnectReason.roomDeleted:
      return AppCallEndReason.endByServer;
    default:
      return null;
  }
}
