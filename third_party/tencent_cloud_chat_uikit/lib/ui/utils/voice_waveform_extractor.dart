import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

/// 从本地语音文件提取竖条波形；无法解析时按文件内容生成近似包络。
class VoiceWaveformData {
  const VoiceWaveformData({
    required this.bars,
    this.durationMs,
  });

  final List<double> bars;
  final int? durationMs;
}

class VoiceWaveformExtractor {
  VoiceWaveformExtractor._();

  static const defaultBarCount = 26;

  static final Map<String, VoiceWaveformData> _memoryCache = {};

  static Future<VoiceWaveformData> load({
    required String cacheKey,
    String? localPath,
    required String fallbackSeed,
    int durationSec = 1,
    int barCount = defaultBarCount,
  }) async {
    final cached = _memoryCache[cacheKey];
    if (cached != null && cached.bars.length == barCount) {
      return cached;
    }

    if (localPath != null && localPath.isNotEmpty && !localPath.startsWith('http')) {
      try {
        final file = File(localPath);
        if (file.existsSync()) {
          final extracted = await extractFromFile(
            localPath,
            barCount: barCount,
          );
          if (extracted != null && extracted.bars.isNotEmpty) {
            _memoryCache[cacheKey] = extracted;
            return extracted;
          }
        }
      } catch (_) {
        // Fall through to seeded fallback.
      }
    }

    final fallback = VoiceWaveformData(
      bars: generateFallback(
        fallbackSeed,
        barCount: barCount,
        durationSec: durationSec,
      ),
    );
    _memoryCache[cacheKey] = fallback;
    return fallback;
  }

  static Future<List<double>> barsFor({
    required String cacheKey,
    String? localPath,
    required String fallbackSeed,
    int durationSec = 1,
    int barCount = defaultBarCount,
  }) async {
    final data = await load(
      cacheKey: cacheKey,
      localPath: localPath,
      fallbackSeed: fallbackSeed,
      durationSec: durationSec,
      barCount: barCount,
    );
    return data.bars;
  }

  static Future<VoiceWaveformData?> extractFromFile(
    String path, {
    int barCount = defaultBarCount,
  }) async {
    final file = File(path);
    if (!file.existsSync()) {
      return null;
    }
    final bytes = await file.readAsBytes();
    if (bytes.length < 16) {
      return null;
    }

    if (_isWav(bytes)) {
      final wavData = _extractFromWav(bytes, barCount);
      if (wavData != null) {
        return wavData;
      }
    }

    return VoiceWaveformData(
      bars: _extractEnvelope(bytes, barCount),
    );
  }

  static List<double> generateFallback(
    String seed, {
    int barCount = defaultBarCount,
    int durationSec = 1,
  }) {
    final rng = Random(Object.hash(seed, durationSec));
    return List<double>.generate(barCount, (index) {
      final wave = 0.28 + 0.44 * sin(index * (0.62 + durationSec * 0.04));
      return (wave + rng.nextDouble() * 0.24).clamp(0.22, 1.0);
    });
  }

  static bool _isWav(Uint8List bytes) {
    if (bytes.length < 12) {
      return false;
    }
    return _chunkId(bytes, 0) == 'RIFF' && _chunkId(bytes, 8) == 'WAVE';
  }

  static String _chunkId(Uint8List bytes, int offset) {
    return String.fromCharCodes(bytes.sublist(offset, offset + 4));
  }

  static VoiceWaveformData? _extractFromWav(Uint8List bytes, int barCount) {
    var offset = 12;
    var bitsPerSample = 16;
    var numChannels = 1;
    var audioFormat = 1;
    var sampleRate = 16000;
    Uint8List? pcmData;

    while (offset + 8 <= bytes.length) {
      final chunkId = _chunkId(bytes, offset);
      final chunkSize = bytes.buffer.asByteData().getUint32(offset + 4, Endian.little);
      offset += 8;
      if (offset + chunkSize > bytes.length) {
        break;
      }

      if (chunkId == 'fmt ' && chunkSize >= 16) {
        final fmt = bytes.buffer.asByteData(offset, chunkSize);
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

    final bytesPerFrame = max(1, numChannels) * max(1, bitsPerSample ~/ 8);
    final durationMs = sampleRate > 0
        ? ((pcmData.length / bytesPerFrame / sampleRate) * 1000).round()
        : null;

    List<double> bars;
    if (audioFormat == 1 && bitsPerSample == 16) {
      bars = _normalizeBars(
        _pcm16Peaks(pcmData, max(1, numChannels), barCount),
      );
    } else if (audioFormat == 1 && bitsPerSample == 8) {
      bars = _normalizeBars(_pcm8Peaks(pcmData, max(1, numChannels), barCount));
    } else {
      bars = _normalizeBars(_extractEnvelope(pcmData, barCount));
    }

    return VoiceWaveformData(
      bars: bars,
      durationMs: durationMs != null && durationMs > 0 ? durationMs : null,
    );
  }

  static List<double> _pcm16Peaks(
    Uint8List pcm,
    int channels,
    int barCount,
  ) {
    final totalSamples = pcm.length ~/ 2;
    final frames = totalSamples ~/ channels;
    if (frames <= 0) {
      return List<double>.filled(barCount, 0.35);
    }

    final framesPerBar = max(1, frames ~/ barCount);
    final peaks = List<double>.filled(barCount, 0.0);
    final data = pcm.buffer.asByteData();

    for (var bar = 0; bar < barCount; bar++) {
      final startFrame = bar * framesPerBar;
      final endFrame = min(frames, startFrame + framesPerBar);
      var peak = 0.0;
      for (var frame = startFrame; frame < endFrame; frame++) {
        for (var channel = 0; channel < channels; channel++) {
          final index = (frame * channels + channel) * 2;
          if (index + 1 >= pcm.length) {
            break;
          }
          final sample = data.getInt16(index, Endian.little).abs().toDouble();
          if (sample > peak) {
            peak = sample;
          }
        }
      }
      peaks[bar] = peak / 32768.0;
    }
    return peaks;
  }

  static List<double> _pcm8Peaks(
    Uint8List pcm,
    int channels,
    int barCount,
  ) {
    final frames = pcm.length ~/ channels;
    if (frames <= 0) {
      return List<double>.filled(barCount, 0.35);
    }

    final framesPerBar = max(1, frames ~/ barCount);
    final peaks = List<double>.filled(barCount, 0.0);

    for (var bar = 0; bar < barCount; bar++) {
      final startFrame = bar * framesPerBar;
      final endFrame = min(frames, startFrame + framesPerBar);
      var peak = 0.0;
      for (var frame = startFrame; frame < endFrame; frame++) {
        for (var channel = 0; channel < channels; channel++) {
          final index = frame * channels + channel;
          if (index >= pcm.length) {
            break;
          }
          final sample = (pcm[index] - 128).abs().toDouble();
          if (sample > peak) {
            peak = sample;
          }
        }
      }
      peaks[bar] = peak / 128.0;
    }
    return peaks;
  }

  static List<double> _extractEnvelope(Uint8List bytes, int barCount) {
    final start = min(bytes.length, 256);
    final payload = bytes.sublist(start);
    if (payload.isEmpty) {
      return List<double>.filled(barCount, 0.35);
    }

    final chunkSize = max(1, payload.length ~/ barCount);
    final peaks = List<double>.filled(barCount, 0.0);

    for (var bar = 0; bar < barCount; bar++) {
      final startIdx = bar * chunkSize;
      final endIdx = min(payload.length, startIdx + chunkSize);
      var sum = 0.0;
      for (var i = startIdx; i < endIdx; i++) {
        sum += (payload[i] - 128).abs();
      }
      peaks[bar] = sum / max(1, endIdx - startIdx);
    }
    return _normalizeBars(peaks);
  }

  static List<double> _normalizeBars(List<double> raw) {
    if (raw.isEmpty) {
      return raw;
    }
    final maxVal = raw.reduce(max).clamp(0.01, 1.0);
    return raw
        .map((value) => (0.22 + (value / maxVal) * 0.78).clamp(0.22, 1.0))
        .toList();
  }
}
