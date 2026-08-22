import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:livekit_client/livekit_client.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:tencent_cloud_chat_demo/src/api/livekit_call_api.dart';
import 'package:tencent_cloud_chat_demo/src/models/livekit_call_telemetry.dart';
import 'package:tencent_cloud_chat_demo/src/services/livekit_call_media_helpers.dart';
import 'package:tencent_cloud_chat_demo/src/services/livekit_call_types.dart';

/// Per-call telemetry recorder; report once when the session ends.
class LiveKitCallTelemetryRecorder {
  LiveKitCallTelemetryRecorder({
    required this.callId,
    required this.role,
    required this.mediaType,
  });

  final String callId;
  final AppCallRole role;
  final AppCallMediaType mediaType;

  DateTime? _connectStartedAt;
  DateTime? _connectFinishedAt;
  DateTime? _publishFinishedAt;
  bool _publishOk = false;
  bool _duplicateIdentity = false;
  String? _error;
  String _micPermission = 'unknown';
  String _cameraPermission = 'n/a';

  void markConnectStarted() {
    _connectStartedAt ??= DateTime.now();
  }

  void markConnectFinished() {
    _connectFinishedAt = DateTime.now();
  }

  void markPublishFinished({required bool ok}) {
    _publishFinishedAt = DateTime.now();
    _publishOk = ok;
  }

  void markDuplicateIdentity() {
    _duplicateIdentity = true;
  }

  void setError(String? message) {
    final text = message?.trim() ?? '';
    if (text.isEmpty) {
      return;
    }
    _error = text.length > 240 ? text.substring(0, 240) : text;
  }

  Future<void> capturePermissions({required bool video}) async {
    _micPermission = await _permissionLabel(Permission.microphone);
    _cameraPermission =
        video ? await _permissionLabel(Permission.camera) : 'n/a';
  }

  LiveKitCallTelemetry build({
    required Room? room,
    required AppCallEndReason? endReason,
    required double durationSec,
  }) {
    final connectMs = _elapsedMs(_connectStartedAt, _connectFinishedAt);
    final publishMs = _elapsedMs(_connectFinishedAt, _publishFinishedAt);
    return LiveKitCallTelemetry(
      callId: callId,
      role: _roleLabel(role),
      mediaType: mediaType == AppCallMediaType.video ? 'video' : 'audio',
      micPermission: _micPermission,
      cameraPermission: _cameraPermission,
      connectMs: connectMs,
      publishMs: publishMs,
      publishOk: _publishOk,
      remoteAudioTrackCount: countRemoteAudioTracks(room),
      iceState: _iceStateLabel(room),
      duplicateIdentity: _duplicateIdentity,
      endReason: endReason?.name,
      error: _error,
      durationSec: durationSec.round(),
    );
  }

  static Future<String> _permissionLabel(Permission permission) async {
    if (kIsWeb) {
      return 'n/a';
    }
    final status = await permission.status;
    if (status.isGranted || status.isLimited) {
      return 'granted';
    }
    if (status.isDenied ||
        status.isPermanentlyDenied ||
        status.isRestricted) {
      return 'denied';
    }
    return 'unknown';
  }

  static int _elapsedMs(DateTime? start, DateTime? end) {
    if (start == null || end == null) {
      return 0;
    }
    return end.difference(start).inMilliseconds;
  }

  static String _roleLabel(AppCallRole role) {
    switch (role) {
      case AppCallRole.caller:
        return 'caller';
      case AppCallRole.callee:
        return 'callee';
      case AppCallRole.none:
        return 'none';
    }
  }

  static String _iceStateLabel(Room? room) {
    if (room == null) {
      return 'none';
    }
    return room.connectionState.name;
  }
}

/// Fire-and-forget telemetry upload for LiveKit calls.
class LiveKitCallTelemetryService {
  LiveKitCallTelemetryService._();

  static final LiveKitCallTelemetryService instance =
      LiveKitCallTelemetryService._();

  LiveKitCallTelemetryRecorder? _active;

  LiveKitCallTelemetryRecorder start({
    required String callId,
    required AppCallRole role,
    required AppCallMediaType mediaType,
  }) {
    final recorder = LiveKitCallTelemetryRecorder(
      callId: callId.trim(),
      role: role,
      mediaType: mediaType,
    );
    _active = recorder;
    return recorder;
  }

  LiveKitCallTelemetryRecorder? get active => _active;

  void clearActive(LiveKitCallTelemetryRecorder recorder) {
    if (identical(_active, recorder)) {
      _active = null;
    }
  }

  Future<void> report(LiveKitCallTelemetry payload) async {
    if (payload.callId.isEmpty) {
      return;
    }
    if (kDebugMode) {
      debugPrint('LiveKitCallTelemetry: ${payload.toJson()}');
    }
    try {
      await LiveKitCallApi.instance.reportTelemetry(payload);
    } catch (e, st) {
      if (kDebugMode) {
        debugPrint('LiveKitCallTelemetry: upload failed $e\n$st');
      }
    }
  }
}
