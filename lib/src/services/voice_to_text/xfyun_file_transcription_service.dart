import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:tencent_cloud_chat_demo/config.dart';
import 'package:tencent_cloud_chat_demo/src/services/voice_to_text/voice_to_text_result.dart';
import 'package:tencent_cloud_chat_demo/src/services/voice_to_text/xfyun_audio_utils.dart';
import 'package:tencent_cloud_chat_demo/src/services/voice_to_text/xfyun_auth.dart';

/// 讯飞 [录音文件转写大模型](https://www.xfyun.cn/doc/spark/asr_llm/Ifasr_llm.html)
class XfyunFileTranscriptionService {
  XfyunFileTranscriptionService._();

  static const String _baseUrl = 'https://office-api-ist-dx.iflyaisol.com';
  static const Duration _pollInterval = Duration(milliseconds: 800);
  static const int _maxPollAttempts = 90;

  static Future<VoiceToTextResult> transcribeRemoteUrl(
    String audioUrl, {
    int? durationMs,
  }) async {
    if (!_hasCredentials) {
      return const VoiceToTextResult(errorMessage: '讯飞语音转写未配置');
    }

    final url = audioUrl.trim();
    if (url.isEmpty) {
      return const VoiceToTextResult(errorMessage: '语音文件不可用');
    }

    final signatureRandom = XfyunAuth.randomSignatureNonce();
    final urlLinkResult = await _uploadByUrl(
      audioUrl: url,
      signatureRandom: signatureRandom,
      durationMs: durationMs,
    );
    if (urlLinkResult.isSuccess) {
      return urlLinkResult;
    }

    final downloaded = await _downloadAudio(url);
    if (downloaded == null) {
      return VoiceToTextResult(
        errorMessage: urlLinkResult.errorMessage ?? '语音下载失败',
      );
    }

  return _uploadByFileStream(
      bytes: downloaded.bytes,
      fileName: downloaded.fileName,
      signatureRandom: XfyunAuth.randomSignatureNonce(),
      durationMs: downloaded.durationMs,
    );
  }

  static Future<VoiceToTextResult> _uploadByUrl({
    required String audioUrl,
    required String signatureRandom,
    int? durationMs,
  }) async {
    final params = _baseUploadParams(
      signatureRandom: signatureRandom,
      fileName: _fileNameFromUrl(audioUrl),
      fileSize: '0',
      durationMs: durationMs,
      extra: {
        'audioMode': 'urlLink',
        'audioUrl': audioUrl,
        'durationCheckDisable': 'true',
      },
    );
    return _uploadAndPoll(params, body: Uint8List(0));
  }

  static Future<VoiceToTextResult> _uploadByFileStream({
    required Uint8List bytes,
    required String fileName,
    required String signatureRandom,
    int? durationMs,
  }) async {
    final effectiveDuration = durationMs ??
        XfyunAudioUtils.estimateDurationMs(
          XfyunAudioUtils.extractPcmFromWav(bytes) ?? bytes,
        );
    final params = _baseUploadParams(
      signatureRandom: signatureRandom,
      fileName: fileName,
      fileSize: bytes.length.toString(),
      durationMs: effectiveDuration,
      extra: const {
        'audioMode': 'fileStream',
      },
    );
    return _uploadAndPoll(params, body: bytes);
  }

  static Map<String, String> _baseUploadParams({
    required String signatureRandom,
    required String fileName,
    required String fileSize,
    int? durationMs,
    Map<String, String>? extra,
  }) {
    final params = <String, String>{
      'appId': IMDemoConfig.xfyunAppId,
      'accessKeyId': IMDemoConfig.xfyunApiKey,
      'dateTime': XfyunAuth.formatFileApiDateTime(),
      'signatureRandom': signatureRandom,
      'fileSize': fileSize,
      'fileName': fileName,
      'language': IMDemoConfig.xfyunFileLanguage,
      if (durationMs != null && durationMs > 0) 'duration': durationMs.toString(),
      ...?extra,
    };
    return params;
  }

  static Future<VoiceToTextResult> _uploadAndPoll(
    Map<String, String> params, {
    required Uint8List body,
  }) async {
    final signature = XfyunAuth.signFileApiParams(params, IMDemoConfig.xfyunApiSecret);
    final uploadUri = Uri.parse('$_baseUrl/v2/upload').replace(
      queryParameters: params.map((key, value) => MapEntry(key, value)),
    );

    try {
      final dio = Dio(
        BaseOptions(
          connectTimeout: 15000,
          receiveTimeout: 60000,
          sendTimeout: 60000,
          responseType: ResponseType.json,
        ),
      );
      final uploadResponse = await dio.post<Map<String, dynamic>>(
        uploadUri.toString(),
        data: body,
        options: Options(
          headers: {
            'Content-Type': 'application/octet-stream',
            'signature': signature,
          },
        ),
      );

      final uploadData = uploadResponse.data;
      final uploadCode = uploadData?['code']?.toString();
      if (uploadCode != '000000') {
        return VoiceToTextResult(
          errorMessage: uploadData?['descInfo']?.toString() ?? '讯飞上传失败',
        );
      }

      final orderId = uploadData?['content']?['orderId']?.toString();
      if (orderId == null || orderId.isEmpty) {
        return const VoiceToTextResult(errorMessage: '讯飞上传失败');
      }

      return _pollResult(
        orderId: orderId,
        signatureRandom: params['signatureRandom']!,
      );
    } on DioError catch (error) {
      return VoiceToTextResult(
        errorMessage: error.message.isNotEmpty ? error.message : '讯飞上传失败',
      );
    } catch (_) {
      return const VoiceToTextResult(errorMessage: '讯飞上传失败');
    }
  }

  static Future<VoiceToTextResult> _pollResult({
    required String orderId,
    required String signatureRandom,
  }) async {
    final dio = Dio(
      BaseOptions(
        connectTimeout: 15000,
        receiveTimeout: 30000,
        responseType: ResponseType.json,
      ),
    );

    for (var attempt = 0; attempt < _maxPollAttempts; attempt++) {
      final params = <String, String>{
        'accessKeyId': IMDemoConfig.xfyunApiKey,
        'dateTime': XfyunAuth.formatFileApiDateTime(),
        'signatureRandom': signatureRandom,
        'orderId': orderId,
        'resultType': 'transfer',
      };
      final signature = XfyunAuth.signFileApiParams(params, IMDemoConfig.xfyunApiSecret);
      final uri = Uri.parse('$_baseUrl/v2/getResult').replace(
        queryParameters: params,
      );

      try {
        final response = await dio.post<Map<String, dynamic>>(
          uri.toString(),
          data: const <String, dynamic>{},
          options: Options(
            headers: {
              'Content-Type': 'application/json',
              'signature': signature,
            },
          ),
        );
        final data = response.data;
        if (data?['code']?.toString() != '000000') {
          return VoiceToTextResult(
            errorMessage: data?['descInfo']?.toString() ?? '讯飞转写失败',
          );
        }

        final content = data?['content'];
        if (content is! Map<String, dynamic>) {
          await Future<void>.delayed(_pollInterval);
          continue;
        }

        final orderInfo = content['orderInfo'];
        final status = orderInfo is Map<String, dynamic> ? orderInfo['status'] : null;
        if (status == 4) {
          final text = _parseOrderResult(content['orderResult']?.toString());
          if (text.isEmpty) {
            return const VoiceToTextResult(errorMessage: '未识别到文字');
          }
          return VoiceToTextResult(text: text);
        }
        if (status == -1) {
          return const VoiceToTextResult(errorMessage: '讯飞转写失败');
        }
      } catch (_) {
        return const VoiceToTextResult(errorMessage: '讯飞转写失败');
      }

      await Future<void>.delayed(_pollInterval);
    }

    return const VoiceToTextResult(errorMessage: '讯飞转写超时');
  }

  static String _parseOrderResult(String? raw) {
    if (raw == null || raw.trim().isEmpty) {
      return '';
    }
    try {
      final root = jsonDecode(raw) as Map<String, dynamic>;
      final lattice = root['lattice'];
      if (lattice is! List) {
        return '';
      }
      final buffer = StringBuffer();
      for (final item in lattice) {
        if (item is! Map<String, dynamic>) {
          continue;
        }
        final json1best = item['json_1best'];
        if (json1best is! String || json1best.isEmpty) {
          continue;
        }
        final parsed = jsonDecode(json1best) as Map<String, dynamic>;
        final st = parsed['st'];
        if (st is! Map<String, dynamic>) {
          continue;
        }
        final rt = st['rt'];
        if (rt is! List) {
          continue;
        }
        for (final rtItem in rt) {
          if (rtItem is! Map<String, dynamic>) {
            continue;
          }
          final ws = rtItem['ws'];
          if (ws is! List) {
            continue;
          }
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
        }
      }
      return buffer.toString().trim();
    } catch (_) {
      return '';
    }
  }

  static Future<_DownloadedAudio?> _downloadAudio(String url) async {
    try {
      final dio = Dio(
        BaseOptions(
          connectTimeout: 15000,
          receiveTimeout: 60000,
          responseType: ResponseType.bytes,
        ),
      );
      final response = await dio.get<List<int>>(url);
      final bytes = response.data;
      if (bytes == null || bytes.isEmpty) {
        return null;
      }
      final data = Uint8List.fromList(bytes);
      return _DownloadedAudio(
        bytes: data,
        fileName: _fileNameFromUrl(url),
        durationMs: XfyunAudioUtils.estimateDurationMs(
          XfyunAudioUtils.extractPcmFromWav(data) ?? data,
        ),
      );
    } catch (_) {
      return null;
    }
  }

  static String _fileNameFromUrl(String url) {
    final uri = Uri.tryParse(url);
    final last = uri?.pathSegments.isNotEmpty == true ? uri!.pathSegments.last : '';
    if (last.isNotEmpty && last.contains('.')) {
      return last;
    }
    return 'voice.wav';
  }

  static bool get _hasCredentials =>
      IMDemoConfig.xfyunAppId.isNotEmpty &&
      IMDemoConfig.xfyunApiKey.isNotEmpty &&
      IMDemoConfig.xfyunApiSecret.isNotEmpty;
}

class _DownloadedAudio {
  const _DownloadedAudio({
    required this.bytes,
    required this.fileName,
    required this.durationMs,
  });

  final Uint8List bytes;
  final String fileName;
  final int durationMs;
}
