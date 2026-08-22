import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tencent_calls_uikit/src/call_define.dart';
import 'package:tencent_calls_uikit/src/impl/call_manager.dart';
import 'package:tencent_calls_uikit/src/impl/call_state.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  SharedPreferences.setMockInitialValues({});

  tearDown(() {
    CallState.instance.cleanState();
  });

  test('resolveScreenPowerPolicy returns off when idle', () {
    CallState.instance.selfUser.callStatus = TUICallStatus.none;

    expect(resolveScreenPowerPolicy(), CallScreenPowerPolicy.off);
  });

  test('resolveScreenPowerPolicy keeps screen awake while ringing', () {
    CallState.instance.selfUser.callStatus = TUICallStatus.waiting;
    CallState.instance.audioDevice = TUIAudioPlaybackDevice.earpiece;

    expect(resolveScreenPowerPolicy(), CallScreenPowerPolicy.keepAwake);
  });

  test('resolveScreenPowerPolicy uses proximity after accept on earpiece', () {
    CallState.instance.selfUser.callStatus = TUICallStatus.accept;
    CallState.instance.audioDevice = TUIAudioPlaybackDevice.earpiece;

    expect(resolveScreenPowerPolicy(), CallScreenPowerPolicy.proximityEarpiece);
  });

  test('resolveScreenPowerPolicy uses proximity after accept on speaker', () {
    CallState.instance.selfUser.callStatus = TUICallStatus.accept;
    CallState.instance.audioDevice = TUIAudioPlaybackDevice.speakerphone;

    expect(resolveScreenPowerPolicy(), CallScreenPowerPolicy.proximityEarpiece);
  });

  test('resolveScreenPowerPolicy uses proximity for video on speaker or earpiece', () {
    CallState.instance.selfUser.callStatus = TUICallStatus.accept;
    CallState.instance.mediaType = TUICallMediaType.video;
    CallState.instance.audioDevice = TUIAudioPlaybackDevice.speakerphone;
    expect(resolveScreenPowerPolicy(), CallScreenPowerPolicy.proximityEarpiece);

    CallState.instance.audioDevice = TUIAudioPlaybackDevice.earpiece;
    expect(resolveScreenPowerPolicy(), CallScreenPowerPolicy.proximityEarpiece);
  });

  test('audio call startup route defaults to earpiece even when voice route is speaker', () {
    CallState.instance.mediaType = TUICallMediaType.audio;
    CallState.instance.selfUser.callStatus = TUICallStatus.waiting;

    CallManager.instance.initAudioPlayDeviceAndCamera();

    expect(CallState.instance.audioDevice, TUIAudioPlaybackDevice.earpiece);
  });
}
