import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';

/// 与 flutter_plugin_record_plus iOS 端 DPAudioRecorder 的处理逻辑对齐：
/// 去掉 AVAudioRecorder 文件前 4100 字节，重写 8kHz/16bit/mono WAV 头。
class IosVoiceWavNormalizer {
  IosVoiceWavNormalizer._();

  static const int _iosStripOffset = 4100;
  static const int _sampleRate = 8000;
  static const int _channels = 1;
  static const int _bitsPerSample = 16;

  static Uint8List normalizeIfNeeded(Uint8List bytes) {
    if (!Platform.isIOS || bytes.length <= _iosStripOffset) {
      return bytes;
    }
    if (!_isWav(bytes)) {
      return bytes;
    }
    final body = bytes.sublist(_iosStripOffset);
    if (body.isEmpty) {
      return bytes;
    }
    final header = _buildWavHeader(body.length + 44);
    return Uint8List.fromList([...header, ...body]);
  }

  static bool _isWav(Uint8List bytes) {
    if (bytes.length < 12) {
      return false;
    }
    return String.fromCharCodes(bytes.sublist(0, 4)) == 'RIFF' &&
        String.fromCharCodes(bytes.sublist(8, 12)) == 'WAVE';
  }

  static Uint8List _buildWavHeader(int lengthWithHeader) {
    final header = Uint8List(44);
    final data = ByteData.view(header.buffer);

    header.setRange(0, 4, 'RIFF'.codeUnits);
    data.setUint32(4, lengthWithHeader - 8, Endian.little);
    header.setRange(8, 12, 'WAVE'.codeUnits);
    header.setRange(12, 16, 'fmt '.codeUnits);
    data.setUint32(16, 16, Endian.little);
    data.setUint16(20, 1, Endian.little);
    data.setUint16(22, _channels, Endian.little);
    data.setUint32(24, _sampleRate, Endian.little);
    final byteRate = _sampleRate * _channels * _bitsPerSample ~/ 8;
    data.setUint32(28, byteRate, Endian.little);
    data.setUint16(32, _channels * _bitsPerSample ~/ 8, Endian.little);
    data.setUint16(34, _bitsPerSample, Endian.little);
    header.setRange(36, 40, 'data'.codeUnits);
    data.setUint32(40, lengthWithHeader - 44, Endian.little);
    return header;
  }

  static Future<Uint8List?> readNormalizedFile(String path) async {
    if (kIsWeb) {
      return null;
    }
    final file = File(path);
    if (!await file.exists()) {
      return null;
    }
    final bytes = await file.readAsBytes();
    if (bytes.isEmpty) {
      return null;
    }
    return normalizeIfNeeded(bytes);
  }
}
