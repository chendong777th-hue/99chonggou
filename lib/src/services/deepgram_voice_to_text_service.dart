import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:tencent_cloud_chat_demo/config.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_message.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_message.dart';
import 'package:tencent_cloud_chat_demo/src/services/voice_to_text/voice_to_text_result.dart';

/// 已发送语音转文字：[Deepgram pre-recorded API](https://developers.deepgram.com/reference/speech-to-text-api/listen)
class DeepgramVoiceToTextService {
  DeepgramVoiceToTextService._();

  static const String _baseUrl = 'https://api.deepgram.com/v1/listen';
  static String? lastErrorMessage;

  static Future<VoiceToTextResult> convertMessage({
    required V2TimMessage message,
    String? msgID,
    Future<String?> Function(V2TimMessage message, String msgID)? resolveUrl,
  }) async {
    lastErrorMessage = null;
    if (kIsWeb) {
      return const VoiceToTextResult(errorMessage: '当前平台暂不支持语音转文字');
    }
    if (!_hasApiKey) {
      lastErrorMessage = 'Deepgram 语音转写未配置';
      return VoiceToTextResult(errorMessage: lastErrorMessage);
    }

    final audioUrl = await _resolveAudioUrl(
      message: message,
      msgID: msgID,
      resolveUrl: resolveUrl,
    );
    if (audioUrl == null || audioUrl.isEmpty) {
      lastErrorMessage = '语音文件不可用';
      return VoiceToTextResult(errorMessage: lastErrorMessage);
    }

    final byUrl = await _transcribeByUrl(audioUrl);
    if (byUrl.isSuccess) {
      return byUrl;
    }

    final downloaded = await _downloadAudio(audioUrl);
    if (downloaded == null) {
      lastErrorMessage = byUrl.errorMessage ?? '语音下载失败';
      return VoiceToTextResult(errorMessage: lastErrorMessage);
    }

    return _transcribeBytes(
      downloaded.bytes,
      contentType: downloaded.contentType,
    );
  }

  static Future<String?> _resolveAudioUrl({
    required V2TimMessage message,
    String? msgID,
    Future<String?> Function(V2TimMessage message, String msgID)? resolveUrl,
  }) async {
    final direct = message.soundElem?.url?.trim();
    if (direct != null && direct.isNotEmpty) {
      return direct;
    }
    final resolvedMsgID = msgID?.trim();
    if (resolveUrl != null &&
        resolvedMsgID != null &&
        resolvedMsgID.isNotEmpty) {
      return resolveUrl(message, resolvedMsgID);
    }
    return null;
  }

  static Future<VoiceToTextResult> _transcribeByUrl(String audioUrl) async {
    try {
      final dio = _newDio();
      final response = await dio.post<Map<String, dynamic>>(
        _listenUri().toString(),
        data: <String, String>{'url': audioUrl},
        options: Options(
          headers: {
            'Authorization': 'Token ${IMDemoConfig.deepgramApiKey}',
            'Content-Type': 'application/json',
          },
        ),
      );
      return _parseResponse(response.data);
    } on DioError catch (error) {
      return VoiceToTextResult(errorMessage: _mapDioError(error));
    } catch (_) {
      return const VoiceToTextResult(errorMessage: '转写失败，请重试');
    }
  }

  static Future<VoiceToTextResult> _transcribeBytes(
    Uint8List bytes, {
    required String contentType,
  }) async {
    if (bytes.isEmpty) {
      return const VoiceToTextResult(errorMessage: '语音文件不可用');
    }
    try {
      final dio = _newDio();
      final response = await dio.post<Map<String, dynamic>>(
        _listenUri().toString(),
        data: bytes,
        options: Options(
          headers: {
            'Authorization': 'Token ${IMDemoConfig.deepgramApiKey}',
            'Content-Type': contentType,
          },
        ),
      );
      return _parseResponse(response.data);
    } on DioError catch (error) {
      return VoiceToTextResult(errorMessage: _mapDioError(error));
    } catch (_) {
      return const VoiceToTextResult(errorMessage: '转写失败，请重试');
    }
  }

  static Uri _listenUri() {
    final params = <String, String>{
      'model': IMDemoConfig.deepgramModel,
      'smart_format': 'true',
      'punctuate': 'true',
    };
    final language = IMDemoConfig.deepgramLanguage.trim();
    if (language.isNotEmpty) {
      params['language'] = language;
    }
    return Uri.parse(_baseUrl).replace(queryParameters: params);
  }

  static Dio _newDio() {
    return Dio(
      BaseOptions(
        connectTimeout: 15000,
        receiveTimeout: 120000,
        sendTimeout: 120000,
        responseType: ResponseType.json,
      ),
    );
  }

  static VoiceToTextResult _parseResponse(Map<String, dynamic>? data) {
    final transcript = _extractTranscript(data);
    if (transcript.isNotEmpty) {
      return VoiceToTextResult(text: transcript);
    }
    return const VoiceToTextResult(errorMessage: '未识别到文字');
  }

  static String _extractTranscript(Map<String, dynamic>? data) {
    final channels = data?['results']?['channels'];
    if (channels is! List || channels.isEmpty) {
      return '';
    }
    final first = channels.first;
    if (first is! Map<String, dynamic>) {
      return '';
    }
    final alternatives = first['alternatives'];
    if (alternatives is! List || alternatives.isEmpty) {
      return '';
    }
    final alt = alternatives.first;
    if (alt is! Map<String, dynamic>) {
      return '';
    }
    return alt['transcript']?.toString().trim() ?? '';
  }

  static String _mapDioError(DioError error) {
    final status = error.response?.statusCode;
    if (status == 401 || status == 403) {
      return '语音转写鉴权失败，请检查 Deepgram 密钥';
    }
    if (status == 429) {
      return '转写请求过于频繁，请稍后再试';
    }
    final data = error.response?.data;
    if (data is Map) {
      final errMsg = data['err_msg'] ?? data['message'] ?? data['error'];
      final text = errMsg?.toString().trim() ?? '';
      if (text.isNotEmpty && _looksLikeUserFacing(text)) {
        return text;
      }
    }
    if (error.type == DioErrorType.connectTimeout ||
        error.type == DioErrorType.receiveTimeout ||
        error.type == DioErrorType.sendTimeout) {
      return '网络超时，请稍后重试';
    }
    return '转写失败，请重试';
  }

  static bool _looksLikeUserFacing(String text) {
    if (text.length > 80) return false;
    return RegExp(r'[\u4e00-\u9fa5]').hasMatch(text) ||
        (!text.toLowerCase().contains('dioerror') &&
            !text.toLowerCase().contains('exception'));
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
      final contentType = response.headers.value('content-type')?.split(';').first.trim();
      return _DownloadedAudio(
        bytes: Uint8List.fromList(bytes),
        contentType: contentType?.isNotEmpty == true
            ? contentType!
            : _contentTypeFromUrl(url),
      );
    } catch (_) {
      return null;
    }
  }

  static String _contentTypeFromUrl(String url) {
    final lower = url.toLowerCase();
    if (lower.contains('.amr')) return 'audio/amr';
    if (lower.contains('.aac')) return 'audio/aac';
    if (lower.contains('.m4a')) return 'audio/mp4';
    if (lower.contains('.mp3')) return 'audio/mpeg';
    if (lower.contains('.wav')) return 'audio/wav';
    if (lower.contains('.ogg')) return 'audio/ogg';
    if (lower.contains('.opus')) return 'audio/opus';
    return 'application/octet-stream';
  }

  static bool get _hasApiKey => IMDemoConfig.deepgramApiKey.trim().isNotEmpty;
}

class _DownloadedAudio {
  const _DownloadedAudio({
    required this.bytes,
    required this.contentType,
  });

  final Uint8List bytes;
  final String contentType;
}
