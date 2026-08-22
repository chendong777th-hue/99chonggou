import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('session implements token refresh and telemetry hooks', () {
    final source =
        File('lib/src/services/livekit_call_session.dart').readAsStringSync();
    expect(source, contains('_armTokenRefresh'));
    expect(source, contains('_refreshRoomTokenIfConnected'));
    expect(source, contains('_recoverRoomConnection'));
    expect(source, contains('_reportTelemetry'));
    expect(source, contains('RoomReconnectedEvent'));
  });

  test('API exposes telemetry upload endpoint', () {
    final source =
        File('lib/src/api/livekit_call_api.dart').readAsStringSync();
    expect(source, contains('/calls/livekit/telemetry'));
  });

  test('legacy av_call push tap is ignored for LiveKit', () {
    final source =
        File('lib/src/services/push_notification_router.dart').readAsStringSync();
    expect(source, contains('Legacy TRTC payloads'));
    expect(source, isNot(contains("case 'av_call':\n        _handleAvCallTap")));
  });
}
