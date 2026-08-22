import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:tencent_cloud_chat_demo/src/services/livekit_call_signaling.dart';

void main() {
  test('native VoIP path gates on call notification preference', () {
    final source = File('ios/Runner/AppDelegate.swift').readAsStringSync();
    expect(source, contains('callNotificationEnabledDefaultsKey'));
    expect(source, contains('isCallNotificationEnabled()'));
    expect(source, contains('cacheCallNotificationEnabled'));
    expect(source, contains('report then end'));
    expect(source, contains('CallKit 已立刻结束'));
    expect(source, contains('onVoipPush'));
  });

  test('Flutter voip handler still presents in-app UI when call notify is off', () {
    final coordinator =
        File('lib/src/services/incoming_call_coordinator.dart').readAsStringSync();
    final settings =
        File('lib/src/services/notification_settings_service.dart').readAsStringSync();
    expect(coordinator, contains('resolveAllowsCallNotify'));
    expect(coordinator, contains('present in-app fullscreen'));
    expect(
      coordinator,
      isNot(contains('voip push ignored — call notifications disabled')),
    );
    expect(settings, contains('_resolveAllowsCallNotify'));
    expect(settings, contains('ensureObserversAttached'));
    expect(
      settings,
      isNot(contains('voip push ignored — call notifications disabled')),
    );
  });

  test('lk_call invite still opens fullscreen when call notifications are off', () {
    final source =
        File('lib/src/services/livekit_call_signaling.dart').readAsStringSync();
    expect(source, contains('allowsCallNotify'));
    expect(source, contains('shouldOpenInAppIncomingCallPage'));
    expect(source, contains('still present in-app fullscreen'));
    expect(
      source,
      isNot(contains('invite ignored — call notifications disabled')),
    );
  });

  test('in-app fullscreen opens even when call notifications are off', () {
    expect(
      shouldOpenInAppIncomingCallPage(
        callNotificationEnabled: false,
        systemIncomingUiAlreadyPresent: true,
      ),
      isTrue,
    );
    expect(
      shouldOpenInAppIncomingCallPage(
        callNotificationEnabled: false,
        systemIncomingUiAlreadyPresent: false,
      ),
      isTrue,
    );
    expect(
      shouldOpenInAppIncomingCallPage(
        callNotificationEnabled: true,
        systemIncomingUiAlreadyPresent: true,
      ),
      isFalse,
    );
    expect(
      shouldOpenInAppIncomingCallPage(
        callNotificationEnabled: true,
        systemIncomingUiAlreadyPresent: false,
      ),
      isTrue,
    );
  });
}
