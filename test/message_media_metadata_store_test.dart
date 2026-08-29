import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:tencent_cloud_chat_demo/src/services/message_media_metadata_store.dart';
import 'package:tencent_cloud_chat_sdk/enum/message_elem_type.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_image.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_image_elem.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_message.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_video_elem.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  const owner = 'media_meta_test_owner';
  final store = MessageMediaMetadataStore.instance;

  setUp(() async {
    store.debugOwnerUserId = owner;
    await store.clearForOwner(owner);
  });

  tearDown(() async {
    await store.clearForOwner(owner);
    store.debugClearMemoryForOwner(owner);
    store.debugOwnerUserId = null;
    await store.closeDatabaseForTest();
  });

  test('hydrates persisted imageList URL into historical image message',
      () async {
    final resolved = _message(
      elemType: MessageElemType.V2TIM_ELEM_TYPE_IMAGE,
      msgID: 'image-msg-1',
    )..imageElem = V2TimImageElem(
        imageList: <V2TimImage?>[
          V2TimImage(
            type: 1,
            uuid: 'thumb-uuid',
            width: 320,
            height: 240,
            url: 'https://cdn.example.com/thumb.jpg',
          ),
        ],
      );

    await store.persistFromMessages(<V2TimMessage>[resolved]);
    store.debugClearMemoryForOwner(owner);

    final historical = _message(
      elemType: MessageElemType.V2TIM_ELEM_TYPE_IMAGE,
      msgID: 'image-msg-1',
    )..imageElem = V2TimImageElem(
        imageList: <V2TimImage?>[
          V2TimImage(type: 1, uuid: 'thumb-uuid'),
        ],
      );

    await store.hydrateMessages(<V2TimMessage>[historical]);

    expect(
      historical.imageElem?.imageList?.first?.url,
      'https://cdn.example.com/thumb.jpg',
    );
    expect(historical.imageElem?.imageList?.first?.width, 320);
  });

  test('hydrates persisted thumb localUrl into historical image message',
      () async {
    final resolved = _message(
      elemType: MessageElemType.V2TIM_ELEM_TYPE_IMAGE,
      msgID: 'image-msg-local-thumb',
    )..imageElem = V2TimImageElem(
        imageList: <V2TimImage?>[
          V2TimImage(
            type: 1,
            uuid: 'thumb-local-uuid',
            localUrl: '/tmp/chat-thumb-local.jpg',
          ),
        ],
      );

    await store.persistFromMessages(<V2TimMessage>[resolved]);
    store.debugClearMemoryForOwner(owner);

    final historical = _message(
      elemType: MessageElemType.V2TIM_ELEM_TYPE_IMAGE,
      msgID: 'image-msg-local-thumb',
    )..imageElem = V2TimImageElem(
        imageList: <V2TimImage?>[
          V2TimImage(type: 1, uuid: 'thumb-local-uuid'),
        ],
      );

    await store.hydrateMessages(<V2TimMessage>[historical]);

    expect(
      historical.imageElem?.imageList?.first?.localUrl,
      '/tmp/chat-thumb-local.jpg',
    );
  });

  test('hydrates persisted video snapshot and play URLs', () async {
    final resolved = _message(
      elemType: MessageElemType.V2TIM_ELEM_TYPE_VIDEO,
      msgID: 'video-msg-1',
    )..videoElem = V2TimVideoElem(
        UUID: 'video-uuid',
        snapshotUUID: 'snapshot-uuid',
        snapshotWidth: 360,
        snapshotHeight: 640,
        videoUrl: 'https://cdn.example.com/video.mp4',
        snapshotUrl: 'https://cdn.example.com/video-cover.jpg',
      );

    await store.persistFromMessages(<V2TimMessage>[resolved]);
    store.debugClearMemoryForOwner(owner);

    final historical = _message(
      elemType: MessageElemType.V2TIM_ELEM_TYPE_VIDEO,
      msgID: 'video-msg-1',
    )..videoElem = V2TimVideoElem(
        UUID: 'video-uuid',
        snapshotUUID: 'snapshot-uuid',
      );

    await store.hydrateMessages(<V2TimMessage>[historical]);

    expect(historical.videoElem?.videoUrl, 'https://cdn.example.com/video.mp4');
    expect(
      historical.videoElem?.snapshotUrl,
      'https://cdn.example.com/video-cover.jpg',
    );
    expect(historical.videoElem?.snapshotHeight, 640);
  });
}

V2TimMessage _message({
  required int elemType,
  required String msgID,
}) {
  final message = V2TimMessage.fromJson(<String, Object?>{
    'message_msg_id': msgID,
    'message_conv_type': 1,
    'message_conv_id': 'peer-user',
    'message_risk_type_identified': 0,
    'message_elem_array': const <Object?>[],
  });
  message
    ..msgID = msgID
    ..elemType = elemType
    ..userID = 'peer-user';
  return message;
}
