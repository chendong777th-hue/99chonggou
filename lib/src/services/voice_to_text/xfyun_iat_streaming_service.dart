import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:tencent_cloud_chat_demo/config.dart';
import 'package:tencent_cloud_chat_demo/src/services/voice_to_text/voice_to_text_result.dart';
import 'package:tencent_cloud_chat_demo/src/services/voice_to_text/xfyun_audio_utils.dart';
import 'package:tencent_cloud_chat_demo/src/services/voice_to_text/xfyun_auth.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

/// 讯飞 [语音听写流式版](https://www.xfyun.cn/doc/asr/voicedictation/API.html)
class XfyunIatStreamingService {
  XfyunIatStreamingService._();

  static const int _frameSize = 640;
  static const Duration _frameInterval = Duration(milliseconds: 40);
  static const Duration _connectTimeout = Duration(seconds: 10);
  static const Duration _resultTimeout = Duration(seconds: 30);

  static Future<VoiceToTextResult> transcribeLocalFile(String soundPath) async {
    if (!_hasCredentials) {
      return const VoiceToTextResult(errorMessage: '讯飞语音转写未配置');
    }

    final pcm = await XfyunAudioUtils.readPcmBytes(soundPath);
    if (pcm == null || pcm.isEmpty) {
      return const VoiceToTextResult(errorMessage: '语音文件不可用');
    }

    WebSocketChannel? channel;
    StreamSubscription<dynamic>? subscription;
    final completer = Completer<VoiceToTextResult>();
    final segments = <int, String>{};
    var latestText = '';
    var sawError = false;

    try {
      final url = XfyunAuth.buildIatWebSocketUrl(
        apiKey: IMDemoConfig.xfyunApiKey,
        apiSecret: IMDemoConfig.xfyunApiSecret,
      );
      channel = WebSocketChannel.connect(Uri.parse(url));
      await channel.ready.timeout(_connectTimeout);

      subscription = channel.stream.listen(
        (event) {
          if (completer.isCompleted) {
            return;
          }
          final text = event?.toString();
          if (text == null || text.isEmpty) {
            return;
          }
          Map<String, dynamic> payload;
          try {
            payload = jsonDecode(text) as Map<String, dynamic>;
          } catch (_) {
            return;
          }

          final code = payload['code'];
          if (code is int && code != 0) {
            sawError = true;
            completer.complete(
              VoiceToTextResult(
                errorMessage: payload['message']?.toString() ?? '讯飞听写失败',
              ),
            );
            return;
          }

          final data = payload['data'];
          if (data is! Map<String, dynamic>) {
            return;
          }

          final result = data['result'];
          if (result is Map<String, dynamic>) {
            latestText = _mergeResult(
              segments: segments,
              result: result,
              fallback: latestText,
            );
          }

          final status = data['status'];
          if (status == 2) {
            completer.complete(
              VoiceToTextResult(
                text: latestText.trim().isEmpty ? null : latestText.trim(),
                errorMessage: latestText.trim().isEmpty ? '未识别到文字' : null,
              ),
            );
          }
        },
        onError: (Object error) {
          if (!completer.isCompleted) {
            completer.complete(const VoiceToTextResult(errorMessage: '讯飞听写连接失败'));
          }
        },
      );

      await _sendAudioFrames(channel, pcm);

      final result = await completer.future.timeout(
        _resultTimeout,
        onTimeout: () {
          if (latestText.trim().isNotEmpty) {
            return VoiceToTextResult(text: latestText.trim());
          }
          return const VoiceToTextResult(errorMessage: '讯飞听写超时');
        },
      );
      if (!result.isSuccess && !sawError && latestText.trim().isNotEmpty) {
        return VoiceToTextResult(text: latestText.trim());
      }
      return result;
    } catch (_) {
      return const VoiceToTextResult(errorMessage: '讯飞听写失败，请重试');
    } finally {
      await subscription?.cancel();
      await channel?.sink.close();
    }
  }

  static bool get _hasCredentials =>
      IMDemoConfig.xfyunAppId.isNotEmpty &&
      IMDemoConfig.xfyunApiKey.isNotEmpty &&
      IMDemoConfig.xfyunApiSecret.isNotEmpty;

  static Future<void> _sendAudioFrames(
    WebSocketChannel channel,
    Uint8List pcm,
  ) async {
    var offset = 0;
    var status = 0;
    while (offset < pcm.length) {
      final end = (offset + _frameSize).clamp(0, pcm.length);
      final chunk = pcm.sublist(offset, end);
      offset = end;
      final isLast = offset >= pcm.length;
      final frameStatus = isLast ? 2 : status;
      final frame = <String, dynamic>{
        if (frameStatus == 0) ...{
          'common': {'app_id': IMDemoConfig.xfyunAppId},
          'business': {
            'language': IMDemoConfig.xfyunIatLanguage,
            'domain': 'iat',
            'accent': IMDemoConfig.xfyunIatAccent,
            'vad_eos': 3000,
            'ptt': 1,
          },
        },
        'data': {
          'status': frameStatus,
          'format': 'audio/L16;rate=${XfyunAudioUtils.defaultSampleRate}',
          'encoding': 'raw',
          'audio': base64.encode(chunk),
        },
      };
      channel.sink.add(jsonEncode(frame));
      status = 1;
      if (!isLast) {
        await Future<void>.delayed(_frameInterval);
      }
    }

    if (pcm.isEmpty) {
      channel.sink.add(
        jsonEncode({
          'common': {'app_id': IMDemoConfig.xfyunAppId},
          'business': {
            'language': IMDemoConfig.xfyunIatLanguage,
            'domain': 'iat',
            'accent': IMDemoConfig.xfyunIatAccent,
          },
          'data': {
            'status': 2,
            'format': 'audio/L16;rate=${XfyunAudioUtils.defaultSampleRate}',
            'encoding': 'raw',
            'audio': '',
          },
        }),
      );
    }
  }

  static String _mergeResult({
    required Map<int, String> segments,
    required Map<String, dynamic> result,
    required String fallback,
  }) {
    final words = _extractWords(result);
    if (words.isEmpty) {
      return fallback;
    }

    final sn = result['sn'];
    if (sn is! int) {
      return fallback.isEmpty ? words : '$fallback$words';
    }

    final pgs = result['pgs']?.toString();
    if (pgs == 'rpl') {
      final rg = result['rg'];
      if (rg is List && rg.length >= 2) {
        final start = (rg[0] as num).toInt();
        final end = (rg[1] as num).toInt();
        for (var i = start; i <= end; i++) {
          segments.remove(i);
        }
      }
      segments[sn] = words;
    } else {
      segments[sn] = words;
    }

    final buffer = StringBuffer();
    for (final key in segments.keys.toList()..sort()) {
      buffer.write(segments[key]);
    }
    return buffer.toString();
  }

  static String _extractWords(Map<String, dynamic> result) {
    final ws = result['ws'];
    if (ws is! List) {
      return '';
    }
    final buffer = StringBuffer();
    for (final wsItem in ws) {
      if (wsItem is! Map<String, dynamic>) {
        continue;
      }
      final cw = wsItem['cw'];
      if (cw is! List) {
        continue;
      }
      for (final cwItem in cw) {
        if (cwItem is Map<String, dynamic>) {
          final word = cwItem['w'];
          if (word is String) {
            buffer.write(word);
          }
        }
      }
    }
    return buffer.toString();
  }
}
