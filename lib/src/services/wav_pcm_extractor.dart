import 'dart:math';
import 'dart:typed_data';

class WavPcmData {
  const WavPcmData({
    required this.pcm,
    required this.sampleRate,
    required this.channels,
    required this.bitsPerSample,
  });

  final Uint8List pcm;
  final int sampleRate;
  final int channels;
  final int bitsPerSample;
}

class WavPcmExtractor {
  WavPcmExtractor._();

  static WavPcmData? extractLinear16Mono(Uint8List bytes) {
    if (bytes.length < 44) {
      return null;
    }
    if (String.fromCharCodes(bytes.sublist(0, 4)) != 'RIFF' ||
        String.fromCharCodes(bytes.sublist(8, 12)) != 'WAVE') {
      return null;
    }

    var offset = 12;
    var audioFormat = 1;
    var numChannels = 1;
    var sampleRate = 16000;
    var bitsPerSample = 16;
    Uint8List? pcmData;

    while (offset + 8 <= bytes.length) {
      final chunkId = String.fromCharCodes(bytes.sublist(offset, offset + 4));
      final chunkSize = bytes.buffer.asByteData().getUint32(offset + 4, Endian.little);
      offset += 8;
      if (offset + chunkSize > bytes.length) {
        break;
      }

      if (chunkId == 'fmt ' && chunkSize >= 16) {
        final fmt = ByteData.view(bytes.buffer, offset, chunkSize);
        audioFormat = fmt.getUint16(0, Endian.little);
        numChannels = fmt.getUint16(2, Endian.little);
        sampleRate = fmt.getUint32(4, Endian.little);
        bitsPerSample = fmt.getUint16(14, Endian.little);
      } else if (chunkId == 'data') {
        pcmData = bytes.sublist(offset, offset + chunkSize);
        break;
      }

      offset += chunkSize + (chunkSize.isOdd ? 1 : 0);
    }

    if (pcmData == null || pcmData.isEmpty) {
      return null;
    }
    if (audioFormat != 1 || bitsPerSample != 16) {
      return null;
    }

    final monoPcm = numChannels == 1 ? pcmData : _downmixToMono(pcmData, numChannels);
    return WavPcmData(
      pcm: monoPcm,
      sampleRate: sampleRate,
      channels: 1,
      bitsPerSample: 16,
    );
  }

  static Uint8List _downmixToMono(Uint8List interleaved, int channels) {
    final frameCount = interleaved.length ~/ (2 * channels);
    final mono = Uint8List(frameCount * 2);
    final inData = ByteData.view(interleaved.buffer);
    final outData = ByteData.view(mono.buffer);
    for (var i = 0; i < frameCount; i++) {
      var sum = 0;
      for (var ch = 0; ch < channels; ch++) {
        sum += inData.getInt16((i * channels + ch) * 2, Endian.little);
      }
      outData.setInt16(i * 2, (sum ~/ channels).clamp(-32768, 32767), Endian.little);
    }
    return mono;
  }

  /// 简单线性重采样到目标采样率（用于 8kHz → 16kHz）。
  static Uint8List resampleLinear16Mono(
    Uint8List pcm,
    int fromRate,
    int toRate,
  ) {
    if (fromRate == toRate || pcm.isEmpty) {
      return pcm;
    }
    final inputSamples = pcm.length ~/ 2;
    if (inputSamples == 0) {
      return pcm;
    }
    final ratio = toRate / fromRate;
    final outputSamples = max(1, (inputSamples * ratio).round());
    final output = Uint8List(outputSamples * 2);
    final inData = ByteData.view(pcm.buffer);
    final outData = ByteData.view(output.buffer);
    for (var i = 0; i < outputSamples; i++) {
      final srcIndex = min(inputSamples - 1, (i / ratio).floor());
      outData.setInt16(
        i * 2,
        inData.getInt16(srcIndex * 2, Endian.little),
        Endian.little,
      );
    }
    return output;
  }
}
