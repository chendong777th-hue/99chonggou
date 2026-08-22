import 'package:flutter_test/flutter_test.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_image.dart';
import 'package:tencent_cloud_chat_uikit/ui/constants/history_message_constant.dart';
import 'package:tencent_cloud_chat_uikit/ui/utils/chat_media_send_utils.dart';
import 'package:tencent_cloud_chat_uikit/ui/utils/message.dart';

void main() {
  group('getImageFromImgList', () {
    List<V2TimImage?> buildImageList() {
      return [
        V2TimImage(type: 0, url: 'origin-url'),
        V2TimImage(type: 1, url: 'thumb-url'),
        V2TimImage(type: 2, url: 'large-url'),
      ];
    }

    test('smallImgPrior returns thumb first', () {
      final image = MessageUtils.getImageFromImgList(
        buildImageList(),
        HistoryMessageDartConstant.smallImgPrior,
      );
      expect(image?.type, 1);
      expect(image?.url, 'thumb-url');
    });

    test('oriImgPrior returns original first', () {
      final image = MessageUtils.getImageFromImgList(
        buildImageList(),
        HistoryMessageDartConstant.oriImgPrior,
      );
      expect(image?.type, 0);
      expect(image?.url, 'origin-url');
    });

    test('bigImgPrior returns large first', () {
      final image = MessageUtils.getImageFromImgList(
        buildImageList(),
        HistoryMessageDartConstant.bigImgPrior,
      );
      expect(image?.type, 2);
      expect(image?.url, 'large-url');
    });
  });

  group('resolveChatBubbleRenderedImageMeta', () {
    final images = <V2TimImage?>[
      V2TimImage(
        type: 0,
        url: 'origin-url',
        localUrl: '/tmp/origin.jpg',
        width: 1080,
        height: 2400,
      ),
      V2TimImage(
        type: 1,
        url: 'thumb-url',
        localUrl: '/tmp/thumb.jpg',
        width: 240,
        height: 240,
      ),
      V2TimImage(
        type: 2,
        url: 'large-url',
        localUrl: '/tmp/large.jpg',
        width: 720,
        height: 1280,
      ),
    ];

    test('uses metadata belonging to the rendered network resource', () {
      final image = resolveChatBubbleRenderedImageMeta(
        images: images,
        networkUrl: 'large-url',
      );

      expect(image?.type, 2);
      expect(image?.width, 720);
      expect(image?.height, 1280);
    });

    test('uses metadata belonging to the rendered local resource', () {
      final image = resolveChatBubbleRenderedImageMeta(
        images: images,
        localPath: '/tmp/thumb.jpg',
      );

      expect(image?.type, 1);
      expect(image?.width, 240);
      expect(image?.height, 240);
    });

    test('prefers network large metadata over local thumb fallback', () {
      final image = resolveChatBubbleRenderedImageMeta(
        images: images,
        networkUrl: 'large-url',
        localPath: '/tmp/thumb.jpg',
      );

      expect(image?.type, 2);
      expect(image?.width, 720);
      expect(image?.height, 1280);
    });

    test('ignores invalid or unrelated metadata', () {
      final image = resolveChatBubbleRenderedImageMeta(
        images: [
          V2TimImage(type: 0, url: 'broken-url', width: 0, height: 0),
          ...images,
        ],
        networkUrl: 'missing-url',
      );

      expect(image, isNull);
    });
  });

  group('preferChatBubbleImageLayoutMeta', () {
    test('prefers original then large, skipping square thumb', () {
      final image = preferChatBubbleImageLayoutMeta([
        V2TimImage(type: 0, url: 'origin-url', width: 0, height: 0),
        V2TimImage(type: 1, url: 'thumb-url', width: 240, height: 240),
        V2TimImage(type: 2, url: 'large-url', width: 720, height: 1600),
      ]);
      expect(image?.type, 2);
      expect(image?.width, 720);
      expect(image?.height, 1600);
    });

    test('falls back to thumb only when origin and large have no size', () {
      final image = preferChatBubbleImageLayoutMeta([
        V2TimImage(type: 0, url: 'origin-url', width: 0, height: 0),
        V2TimImage(type: 1, url: 'thumb-url', width: 198, height: 440),
      ]);
      expect(image?.type, 1);
      expect(image?.width, 198);
      expect(image?.height, 440);
    });
  });
}
