import 'package:file/file.dart';
import 'package:file/local.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:path_provider/path_provider.dart';
import 'package:tencent_calls_uikit/src/call_define.dart';
import 'package:tencent_calls_uikit/src/impl/call_state.dart';
import 'package:tencent_calls_uikit/src/extensions/trtc_logger.dart';
import 'package:tencent_calls_uikit/src/platform/call_kit_platform_interface.dart';
import 'package:tencent_calls_uikit/src/utils/preference.dart';

class CallingBellFeature {
  static FileSystem fileSystem = const LocalFileSystem();
  static String keyRingPath = "key_ring_path";
  static String package = "packages/";
  static String pluginName = "tencent_calls_uikit/";
  static String assetsPrefix = "assets/audios/";
  static String callerRingName = "phone_dialing.mp3";
  static String calledRingName = "phone_ringing.mp3";
  static int _ringGeneration = 0;

  static Future<void> startRing({int? callEpoch}) async {
    if (callEpoch != null && CallState.instance.callEpoch != callEpoch) {
      return;
    }
    final generation = ++_ringGeneration;
    TRTCLogger.info('CallingBellFeature startRing(generation:$generation)');
    if (!_canStartRing(generation)) {
      return;
    }
    String filePath =
        await PreferenceUtils.getInstance().getString(keyRingPath);
    if (filePath.isNotEmpty &&
        TUICallRole.called == CallState.instance.selfUser.callRole &&
        !CallState.instance.enableMuteMode) {
      if (_canStartRing(generation)) {
        await TUICallKitPlatform.instance.startRing(filePath);
      }
      return;
    }

    final String tempDirectory = await getTempDirectory();
    if (!_canStartRing(generation)) {
      return;
    }
    filePath = "$tempDirectory/$callerRingName";
    String assetsName = callerRingName;
    if (TUICallRole.called == CallState.instance.selfUser.callRole) {
      if (CallState.instance.enableMuteMode) {
        return;
      }
      filePath = "$tempDirectory/$calledRingName";
      assetsName = calledRingName;
    }
    final file = fileSystem.file(filePath);
    if (!await file.exists()) {
      ByteData byteData =
          await loadAsset('$package$pluginName$assetsPrefix$assetsName');
      await file.create();
      await file.writeAsBytes(byteData.buffer.asUint8List());
    }
    if (_canStartRing(generation)) {
      await TUICallKitPlatform.instance.startRing(file.path);
    }
  }

  static bool _canStartRing(int generation) {
    return generation == _ringGeneration &&
        CallState.instance.selfUser.callStatus == TUICallStatus.waiting;
  }

  static Future<String> getAssetsFilePath(String assetName) async {
    if (assetName.isEmpty) {
      return "";
    }
    final String tempDirectory = await getTempDirectory();
    String filePath = "$tempDirectory/$assetName";
    final file = fileSystem.file(filePath);
    if (!await file.exists()) {
      ByteData byteData = await loadAsset(assetName);
      await file.create(recursive: true);
      await file.writeAsBytes(byteData.buffer.asUint8List());
    }
    return file.path;
  }

  static Future<void> stopRing({int? callEpoch}) async {
    if (callEpoch != null && CallState.instance.callEpoch != callEpoch) {
      TRTCLogger.info(
          'CallingBellFeature ignore stale stopRing(epoch:$callEpoch, active:${CallState.instance.callEpoch})');
      return;
    }
    final generation = ++_ringGeneration;
    TRTCLogger.info('CallingBellFeature stopRing(generation:$generation)');
    await TUICallKitPlatform.instance.stopRing();
  }

  //path: The format of the path parameter in the plugin is 'package$pluginName$assetsPrefix$assetsName'
  @visibleForTesting
  static Future<ByteData> loadAsset(String path) => rootBundle.load(path);

  @visibleForTesting
  static Future<String> getTempDirectory() async =>
      (await getTemporaryDirectory()).path;
}
