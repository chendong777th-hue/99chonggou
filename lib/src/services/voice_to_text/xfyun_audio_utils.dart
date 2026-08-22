import 'dart:io';
import 'dart:typed_data';

import 'package:tencent_cloud_chat_demo/src/services/ios_voice_wav_normalizer.dart';

class XfyunAudioUtils {
  XfyunAudioUtils._();

  static const int defaultSampleRate = 8000;

  static Future<Uint8List?> readPcmBytes(String path) async {
    final normalized = await IosVoiceWavNormalizer.readNormalizedFile(path);
    if (normalized == null || normalized.isEmpty) {
      return null;
    }
    return extractPcmFromWav(normalized);
  }

  static Uint8List? extractPcmFromWav(Uint8List bytes) {
    if (bytes.length <= 44) {
      return bytes;
    }
    if (!_isWav(bytes)) {
      return bytes;
    }
    return bytes.sublist(44);
  }

  static int estimateDurationMs(Uint8List pcmBytes, {int sampleRate = defaultSampleRate}) {
    if (pcmBytes.isEmpty || sampleRate <= 0) {
      return 0;
    }
    final bytesPerSecond = sampleRate * 2;
    return ((pcmBytes.length / bytesPerSecond) * 1000).ceil();
  }

  static int estimateWavDurationSec(String path) {
    try {
      final file = File(path);
      if (!file.existsSync()) {
        return 0;
      }
      final bytes = file.lengthSync();
      if (bytes <= 44) {
        return 0;
      }
      return ((bytes - 44) / (defaultSampleRate * 2)).ceil().clamp(1, 3600);
    } catch (_) {
      return 0;
    }
  }

  static bool _isWav(Uint8List bytes) {
    if (bytes.length < 12) {
      return false;
    }
    return String.fromCharCodes(bytes.sublist(0, 4)) == 'RIFF' &&
        String.fromCharCodes(bytes.sublist(8, 12)) == 'WAVE';
  }
}
