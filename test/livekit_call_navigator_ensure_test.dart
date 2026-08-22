import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:tencent_cloud_chat_demo/src/services/livekit_call_navigator.dart';

void main() {
  tearDown(LiveKitCallNavigator.resetRouteTrackingForTest);

  test('route tracking reflects push / cover / pop lifecycle', () {
    LiveKitCallNavigator.resetRouteTrackingForTest();
    expect(LiveKitCallNavigator.isCallPageCurrent, isFalse);

    LiveKitCallNavigator.notifyCallRoutePushed();
    expect(LiveKitCallNavigator.isCallPageCurrent, isTrue);

    LiveKitCallNavigator.notifyCallRouteCovered();
    expect(LiveKitCallNavigator.isCallPageCurrent, isFalse);

    LiveKitCallNavigator.notifyCallRouteUncovered();
    expect(LiveKitCallNavigator.isCallPageCurrent, isTrue);

    LiveKitCallNavigator.notifyCallRoutePopped();
    expect(LiveKitCallNavigator.isCallPageCurrent, isFalse);
  });

  test('page mount heal marks call page current', () {
    LiveKitCallNavigator.resetRouteTrackingForTest();
    LiveKitCallNavigator.notifyCallPageMounted();
    expect(LiveKitCallNavigator.isCallPageMounted, isTrue);
    expect(LiveKitCallNavigator.isCallPageCurrent, isTrue);
    LiveKitCallNavigator.notifyCallPageDisposed();
    expect(LiveKitCallNavigator.isCallPageMounted, isFalse);
  });

  test('ensureCallPageVisible does not await openCallPage until pop', () {
    final source = File(
      'lib/src/services/livekit_call_navigator.dart',
    ).readAsStringSync();
    expect(source, contains('unawaited('));
    expect(source, contains('openCallPage('));
    // Must not block ensure on the push future (completes only on pop).
    final ensure = source.indexOf('static Future<void> ensureCallPageVisible');
    final ensureBody = source.substring(
      ensure,
      source.indexOf('static Future<void> _waitForCallPageCurrent', ensure),
    );
    expect(ensureBody, contains('unawaited('));
    expect(ensureBody, isNot(contains('await openCallPage(')));
  });

  test('acceptFromUi awaits ensureCallPageVisible around accept', () {
    final source = File(
      'lib/src/services/livekit_voip_bridge.dart',
    ).readAsStringSync();
    final acceptFromUi = source.indexOf('Future<void> acceptFromUi()');
    expect(acceptFromUi, greaterThanOrEqualTo(0));

    final block = source.substring(
      acceptFromUi,
      source.indexOf('Future<void> _onAccept(', acceptFromUi),
    );
    expect(block, contains('await LiveKitCallNavigator.ensureCallPageVisible'));
    expect(
      block.indexOf('await LiveKitCallNavigator.ensureCallPageVisible'),
      lessThan(block.indexOf('await session.acceptIncoming()')),
    );
    expect(
      block.lastIndexOf('await LiveKitCallNavigator.ensureCallPageVisible'),
      greaterThan(block.indexOf('await session.acceptIncoming()')),
    );
  });

  test('CallKit accept awaits ensureCallPageVisible after LiveKit join', () {
    final source = File(
      'lib/src/services/livekit_voip_bridge.dart',
    ).readAsStringSync();
    expect(source, contains("reason: 'callKit/afterAccept'"));
    expect(
      source,
      contains('await LiveKitCallNavigator.ensureCallPageVisible('),
    );
  });

  test('always-on UI log helper exists', () {
    final source = File(
      'lib/src/services/livekit_call_ui_log.dart',
    ).readAsStringSync();
    expect(source, contains('[LK_CALL_UI]'));
    expect(source, isNot(contains('if (kDebugMode) {\n  print')));
  });
}
