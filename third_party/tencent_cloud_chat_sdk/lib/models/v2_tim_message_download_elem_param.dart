import 'package:tencent_cloud_chat_sdk/models/v2_tim_message.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_image.dart';
import 'package:tencent_cloud_chat_sdk/enum/image_types.dart';
import 'package:tencent_cloud_chat_sdk/enum/message_elem_type.dart';


/// V2TimMessageDownloadElemParam
///
/// {@category Models}
///
class V2TimMessageDownloadElemParam {
    late V2TimMessage message;
    int? imageType;
    bool? isSnapshot;
    late String fileUUID;
    late int downloadType;
    late String downloadUrl;
    dynamic downloadElement;

    // 下载元素的类型
    // 图片
    static const int _downloadImage = 0;
    // 文件
    static const int _downloadFile = 1;
    // 视频
    static const int _downloadVideo = 2;
    // 声音
    static const int _downloadSound = 3;


  V2TimMessageDownloadElemParam({
    required this.message,
    this.imageType,
    this.isSnapshot,
  }) {
    fileUUID = '';
    downloadType = _downloadImage;
    downloadUrl = '';
    switch (message.elemType) {
      case MessageElemType.V2TIM_ELEM_TYPE_IMAGE:
        int requiredType = imageType ?? V2TIM_IMAGE_TYPE.V2TIM_IMAGE_TYPE_ORIGIN;
        for (V2TimImage? image in message.imageElem?.imageList ?? []) {
          if (image?.type != null && image?.type == requiredType) {
            fileUUID = '${requiredType}_${image?.uuid ?? ''}';
            downloadType = _downloadImage;
            downloadUrl = image?.url ?? '';

            downloadElement = image;
            break;
          }
        }

        break;

      case MessageElemType.V2TIM_ELEM_TYPE_VIDEO:
        bool requiredSnapshot = isSnapshot ?? false;
        if (requiredSnapshot) {
          fileUUID = message.videoElem?.snapshotUUID ?? '';
          downloadType = _downloadImage;
          downloadUrl = message.videoElem?.snapshotUrl ?? '';
        } else {
          fileUUID = message.videoElem?.UUID ?? '';
          downloadType = _downloadVideo;
          downloadUrl = message.videoElem?.videoUrl ?? '';
        }

        downloadElement = message.videoElem;

        break;

      case MessageElemType.V2TIM_ELEM_TYPE_SOUND:
        fileUUID = message.soundElem?.UUID ?? '';
        downloadType = _downloadSound;
        downloadUrl = message.soundElem?.url ?? '';

        downloadElement = message.soundElem;

        break;

      case MessageElemType.V2TIM_ELEM_TYPE_FILE:
        fileUUID = message.fileElem?.UUID ?? '';
        downloadType = _downloadFile;
        downloadUrl = message.fileElem?.url ?? '';

        downloadElement = message.fileElem;

        break;

      default:
        downloadElement = null;
        print('invalid message type');
    }
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['msg_download_elem_param_id'] = fileUUID;
    data['msg_download_elem_param_type'] = downloadType;
    data['msg_download_elem_param_url'] = downloadUrl;
    return data;
  }

  String toLogString() {
    String res = "fileUUID: $fileUUID|downloadType: $downloadType|downloadUrl: $downloadUrl";
    return res;
  }
}
