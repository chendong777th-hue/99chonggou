import 'package:tencent_cloud_chat_sdk/enum/message_elem_type.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_message.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_message.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_stream_elem.dart'
  if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_stream_elem.dart';

class Utils {
  static String getMessageContent(V2TimMessage message) {
    String m = "";
    if (message.elemType == MessageElemType.V2TIM_ELEM_TYPE_TEXT) {
      m = "text ${message.textElem?.text}";
    }
    // 使用自定义消息
    if (message.elemType == MessageElemType.V2TIM_ELEM_TYPE_CUSTOM) {
      m = "custom ${message.customElem?.data}";
    }
    // 使用图片消息
    if (message.elemType == MessageElemType.V2TIM_ELEM_TYPE_IMAGE) {
      m = "image ${message.imageElem?.path}";
    }
    // 处理视频消息
    if (message.elemType == MessageElemType.V2TIM_ELEM_TYPE_VIDEO) {
      m = "video ${message.videoElem?.videoPath}";
    }
    // 处理音频消息
    if (message.elemType == MessageElemType.V2TIM_ELEM_TYPE_SOUND) {
      m = "sound ${message.soundElem?.url}";
    }
    // 处理文件消息
    if (message.elemType == MessageElemType.V2TIM_ELEM_TYPE_FILE) {
      m = "file ${message.fileElem?.url}";
    }
    // 处理位置消息
    if (message.elemType == MessageElemType.V2TIM_ELEM_TYPE_LOCATION) {
      m = "location";
    }
    // 处理表情消息
    if (message.elemType == MessageElemType.V2TIM_ELEM_TYPE_FACE) {
      m = "face";
    }
    // 处理群组tips文本消息
    if (message.elemType == MessageElemType.V2TIM_ELEM_TYPE_GROUP_TIPS) {
      m = "group tips";
    }
    // 处理合并消息消息
    if (message.elemType == MessageElemType.V2TIM_ELEM_TYPE_MERGER) {
      m = "merger";
    }
    // 处理流式消息
    if (message.elemType == MessageElemType.V2TIM_ELEM_TYPE_STREAM) {
      V2TimStreamElem streamElem = message.streamElem!;
      m = "stream|${streamElem.toLogString()}";
    }
    return m;
  }
}
