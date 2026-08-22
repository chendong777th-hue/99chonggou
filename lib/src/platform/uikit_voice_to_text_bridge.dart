import 'package:tencent_cloud_chat_sdk/enum/message_elem_type.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_message.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_message.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_sound_elem.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_sound_elem.dart';
import 'package:tencent_cloud_chat_demo/src/services/voice_to_text_service.dart';
import 'package:tencent_cloud_chat_uikit/business_logic/services/voice_to_text_bridge.dart';

class UikitVoiceToTextBridge {
  UikitVoiceToTextBridge._();

  static void install() {
    VoiceToTextBridge.configure(
      transcriber: ({
        String? localAudioPath,
        String? remoteAudioUrl,
      }) async {
        if (remoteAudioUrl != null && remoteAudioUrl.trim().isNotEmpty) {
          final result = await VoiceToTextService.convertMessage(
            message: _messageWithSoundUrl(remoteAudioUrl.trim()),
          );
          if (result.isSuccess) {
            return result.text;
          }
          VoiceToTextBridge.lastErrorMessage = result.errorMessage;
          return null;
        }
        VoiceToTextBridge.lastErrorMessage = '语音文件不可用';
        return null;
      },
    );
  }
}

V2TimMessage _messageWithSoundUrl(String url) {
  return V2TimMessage(
    elemType: MessageElemType.V2TIM_ELEM_TYPE_SOUND,
    soundElem: V2TimSoundElem(url: url),
  );
}
