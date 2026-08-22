import 'package:tencent_cloud_chat_sdk/models/v2_tim_custom_elem.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_face_elem.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_file_elem.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_group_tips_elem.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_image_elem.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_location_elem.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_merger_elem.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_message.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_sound_elem.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_text_elem.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_video_elem.dart';

/// V2TIMElem
///

class V2TIMElem {
  V2TimMessage? _message;
  int _elemIndex = 0;
  int? elemType;

  V2TIMElem({this.elemType});

  void setMessageInternal(V2TimMessage message) {
    _message = message;
  }

  void setElemIndexInternal(int index) {
    _elemIndex = index;
  }

  get nextElem {
    if (_message == null) {
      return null;
    }

    List<dynamic> elementList = _message?.elemList ?? [];
    int nextElemIndex = _elemIndex + 1;
    if (nextElemIndex >= elementList.length) {
      return null;
    }

    V2TIMElem v2timElem = elementList[nextElemIndex];
    if (v2timElem is V2TimTextElem ||
        v2timElem is V2TimImageElem ||
        v2timElem is V2TimVideoElem ||
        v2timElem is V2TimSoundElem ||
        v2timElem is V2TimFaceElem ||
        v2timElem is V2TimFileElem ||
        v2timElem is V2TimCustomElem ||
        v2timElem is V2TimLocationElem ||
        v2timElem is V2TimMergerElem ||
        v2timElem is V2TimGroupTipsElem)  {
      v2timElem.setMessageInternal(_message!);
      v2timElem.setElemIndexInternal(nextElemIndex);
    }

    return v2timElem;
  }
}
