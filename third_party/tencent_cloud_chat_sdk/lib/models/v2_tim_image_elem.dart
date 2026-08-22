import 'dart:convert';

import 'package:tencent_cloud_chat_sdk/enum/image_types.dart';
import 'package:tencent_cloud_chat_sdk/enum/message_elem_type.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_elem.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_image.dart';
import 'package:tencent_cloud_chat_sdk/native_im/adapter/tim_c_enum.dart';
import 'package:tencent_cloud_chat_sdk/utils/utils.dart';

/// V2TimImageElem
///
/// {@category Models}
///

class V2TimImageElem extends V2TIMElem {
  /// 图片本地路径，仅在发送消息时有效，用做发消息提前上屏预览
  late String? path;

  /// 图片资源列表
  List<V2TimImage?>? imageList = List.empty(growable: true);

  V2TimImageElem({
    this.path,
    this.imageList,
  }): super(elemType: MessageElemType.V2TIM_ELEM_TYPE_IMAGE);

  V2TimImageElem.fromJson(Map json) {
    elemType = MessageElemType.V2TIM_ELEM_TYPE_IMAGE;
    json = Utils.formatJson(json);
    path = json['image_elem_orig_path'] ?? '';
    V2TimImage originalImage = V2TimImage(type: V2TIM_IMAGE_TYPE.V2TIM_IMAGE_TYPE_ORIGIN);
    originalImage.uuid = json['image_elem_orig_id'];
    originalImage.size = json['image_elem_orig_pic_size'];
    originalImage.width = json['image_elem_orig_pic_width'];
    originalImage.height = json['image_elem_orig_pic_height'];
    originalImage.url = json['image_elem_orig_url'];
    originalImage.localUrl = originalImage.getDefaultLocalUrl();
    imageList?.add(originalImage);

    V2TimImage thumbImage = V2TimImage(type: V2TIM_IMAGE_TYPE.V2TIM_IMAGE_TYPE_THUMB);
    thumbImage.uuid = json['image_elem_thumb_id'];
    thumbImage.size = json['image_elem_thumb_pic_size'];
    thumbImage.width = json['image_elem_thumb_pic_width'];
    thumbImage.height = json['image_elem_thumb_pic_height'];
    thumbImage.url = json['image_elem_thumb_url'];
    thumbImage.localUrl = thumbImage.getDefaultLocalUrl();
    imageList?.add(thumbImage);

    V2TimImage largeImage = V2TimImage(type: V2TIM_IMAGE_TYPE.V2TIM_IMAGE_TYPE_LARGE);
    largeImage.uuid = json['image_elem_large_id'];
    largeImage.size = json['image_elem_large_pic_size'];
    largeImage.width = json['image_elem_large_pic_width'];
    largeImage.height = json['image_elem_large_pic_height'];
    largeImage.url = json['image_elem_large_url'];
    largeImage.localUrl = largeImage.getDefaultLocalUrl();
    imageList?.add(largeImage);
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['elem_type'] = CElemType.ElemImage;
    data['image_elem_orig_path'] = path;
    for (var image in imageList ?? []) {
      if (image?.type == V2TIM_IMAGE_TYPE.V2TIM_IMAGE_TYPE_ORIGIN) {
        data['image_elem_orig_id'] = image?.uuid ?? '';
        data['image_elem_orig_pic_size'] = image?.size ?? 0;
        data['image_elem_orig_pic_width'] = image?.width ?? 0;
        data['image_elem_orig_pic_height'] = image?.height ?? 0;
        data['image_elem_orig_url'] = image?.url ?? '';
      } else if (image?.type == V2TIM_IMAGE_TYPE.V2TIM_IMAGE_TYPE_THUMB) {
        data['image_elem_thumb_id'] = image?.uuid ?? '';
        data['image_elem_thumb_pic_size'] = image?.size ?? 0;
        data['image_elem_thumb_pic_width'] = image?.width ?? 0;
        data['image_elem_thumb_pic_height'] = image?.height ?? 0;
        data['image_elem_thumb_url'] = image?.url ?? '';
      } else if (image?.type == V2TIM_IMAGE_TYPE.V2TIM_IMAGE_TYPE_LARGE) {
        data['image_elem_large_id'] = image?.uuid ?? '';
        data['image_elem_large_pic_size'] = image?.size ?? 0;
        data['image_elem_large_pic_width'] = image?.width ?? 0;
        data['image_elem_large_pic_height'] = image?.height ?? 0;
        data['image_elem_large_url'] = image?.url ?? '';
      }
    }

    return data;
  }
  String toLogString() {
    String res = "path:${path == null ? false : true}|imageList:${json.encode(imageList?.map((e) => e?.toLogString()).toList())}";
    return res;
  }
}
