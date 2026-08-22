import 'package:flutter/foundation.dart';
import 'package:tencent_cloud_chat_demo/config.dart';
import 'package:tencent_cloud_chat_demo/src/services/deepgram_voice_to_text_service.dart';
import 'package:tencent_cloud_chat_demo/src/services/tencent_voice_to_text_service.dart';
import 'package:tencent_cloud_chat_demo/src/services/voice_to_text/voice_to_text_result.dart';
import 'package:tencent_cloud_chat_demo/src/services/voice_to_text/xfyun_audio_utils.dart';
import 'package:tencent_cloud_chat_demo/src/services/voice_to_text/xfyun_iat_streaming_service.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_message.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_message.dart';
import 'package:tencent_cloud_chat_uikit/business_logic/view_models/tui_chat_global_model.dart';
import 'package:tencent_cloud_chat_uikit/data_services/message/message_services.dart';

/// 统一语音转文字入口（混合提供方）。
/// - 本地录音松手转文字：讯飞流式听写
/// - 已发送语音长按转文字：Deepgram pre-recorded API
class VoiceToTextService {
  VoiceToTextService._();

  static String? lastErrorMessage;

  /// 本地录音是否走讯飞；`VOICE_TO_TEXT_PROVIDER=tencent` 时本地也改走腾讯（需先上传语音）。
  static bool get usesXfyunForLocalRecording =>
      IMDemoConfig.voiceToTextProvider != 'tencent';

  static bool get hasPendingUpload => !usesXfyunForLocalRecording
      ? TencentVoiceToTextService.hasPendingUpload
      : false;

  static void acknowledgePendingUpload() {
    if (!usesXfyunForLocalRecording) {
      TencentVoiceToTextService.acknowledgePendingUpload();
    }
  }

  static dynamic takePendingUpload() {
    if (usesXfyunForLocalRecording) {
      return null;
    }
    return TencentVoiceToTextService.takePendingUpload();
  }

  static Future<VoiceToTextResult> convertMessage({
    required V2TimMessage message,
    String? msgID,
    Future<String?> Function(V2TimMessage message, String msgID)? resolveUrl,
  }) async {
    lastErrorMessage = null;
    if (kIsWeb) {
      return const VoiceToTextResult(errorMessage: '当前平台暂不支持语音转文字');
    }

    final result = await DeepgramVoiceToTextService.convertMessage(
      message: message,
      msgID: msgID,
      resolveUrl: resolveUrl,
    );
    return _finalize(result);
  }

  static Future<VoiceToTextResult> convertLocalFile({
    required String soundPath,
    required int duration,
    required String convID,
    required ConvType convType,
    required MessageService messageService,
    Future<String?> Function(V2TimMessage message, String msgID)? resolveUrl,
  }) async {
    lastErrorMessage = null;
    if (kIsWeb) {
      return const VoiceToTextResult(errorMessage: '当前平台暂不支持语音转文字');
    }

    final path = soundPath.trim();
    if (path.isEmpty) {
      lastErrorMessage = '语音文件不可用';
      return VoiceToTextResult(errorMessage: lastErrorMessage);
    }

    if (!usesXfyunForLocalRecording) {
      return _fromTencent(
        await TencentVoiceToTextService.convertLocalFile(
          soundPath: path,
          duration: duration,
          convID: convID,
          convType: convType,
          messageService: messageService,
          resolveUrl: resolveUrl,
        ),
      );
    }

    final effectiveDuration = duration > 0 ? duration : XfyunAudioUtils.estimateWavDurationSec(path);
    if (effectiveDuration <= 0) {
      lastErrorMessage = '说话时间太短';
      return VoiceToTextResult(errorMessage: lastErrorMessage);
    }

    final result = await XfyunIatStreamingService.transcribeLocalFile(path);
    return _finalize(result);
  }

  static VoiceToTextResult _fromTencent(TencentVoiceToTextResult result) {
    if (result.isSuccess) {
      return VoiceToTextResult(text: result.text);
    }
    lastErrorMessage = result.errorMessage;
    TencentVoiceToTextService.lastErrorMessage = result.errorMessage;
    return VoiceToTextResult(errorMessage: result.errorMessage);
  }

  static VoiceToTextResult _finalize(VoiceToTextResult result) {
    if (!result.isSuccess) {
      lastErrorMessage = result.errorMessage ?? '转文字失败，请重试';
    }
    return result;
  }
}
