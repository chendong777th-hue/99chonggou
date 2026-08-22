import 'package:flutter_test/flutter_test.dart';
import 'package:tencent_cloud_chat_sdk/enum/message_elem_type.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_image.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_image.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_image_elem.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_image_elem.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_message.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_message.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_video_elem.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_video_elem.dart';
import 'package:tencent_cloud_chat_sdk/enum/image_types.dart';
import 'package:tencent_cloud_chat_uikit/ui/utils/chat_media_preview_builder.dart';
import 'package:tencent_cloud_chat_uikit/ui/widgets/chat_media_preview_item.dart';

/// 媒体页点图必须与聊天气泡一致：只收集图片，走 ImageScreen 路径
///（不要因会话里有视频就进混滑 ChatMediaGalleryScreen）。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  V2TimMessage imageMsg(String id) {
    final m = V2TimMessage.fromJson({
      'msgID': id,
      'timestamp': 1,
      'message_is_from_self': false,
      'message_risk_type_identified': 0,
    });
    m.msgID = id;
    m.elemType = MessageElemType.V2TIM_ELEM_TYPE_IMAGE;
    m.imageElem = V2TimImageElem(
      imageList: [
        V2TimImage(
          type: V2TIM_IMAGE_TYPE.V2TIM_IMAGE_TYPE_LARGE,
          url: 'https://example.com/$id-big.jpg',
        ),
        V2TimImage(
          type: V2TIM_IMAGE_TYPE.V2TIM_IMAGE_TYPE_THUMB,
          url: 'https://example.com/$id-thumb.jpg',
        ),
      ],
    );
    return m;
  }

  V2TimMessage videoMsg(String id) {
    final m = V2TimMessage.fromJson({
      'msgID': id,
      'timestamp': 2,
      'message_is_from_self': false,
      'message_risk_type_identified': 0,
    });
    m.msgID = id;
    m.elemType = MessageElemType.V2TIM_ELEM_TYPE_VIDEO;
    m.videoElem = V2TimVideoElem(
      videoUrl: 'https://example.com/$id.mp4',
      snapshotUrl: 'https://example.com/$id.jpg',
    );
    return m;
  }

  test('tapping image with videos in list still builds image-only preview', () {
    final img = imageMsg('img-1');
    final list = [img, videoMsg('vid-1'), imageMsg('img-2')];

    final allTypes = buildChatMediaPreviewItems(
      originList: list,
      tappedMessage: img,
      types: kChatMediaPreviewAllTypes,
      heroTagBuilder: (m) => 'h_${m.msgID}',
    );
    expect(allTypes.isMixed, isTrue);

    final imageOnly = buildChatMediaPreviewItems(
      originList: list,
      tappedMessage: img,
      types: kChatMediaPreviewImageTypes,
      heroTagBuilder: (m) => 'h_${m.msgID}',
    );
    expect(imageOnly.isMixed, isFalse);
    expect(imageOnly.hasVideo, isFalse);
    expect(imageOnly.hasImage, isTrue);
    expect(
      imageOnly.items.every((e) => e.type == ChatMediaPreviewType.image),
      isTrue,
    );
    expect(imageOnly.currentItem?.message.msgID, 'img-1');
    expect(imageOnly.currentItem?.imageProvider, isNotNull);
  });
}
