import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tencent_cloud_chat_sdk/enum/image_types.dart';
import 'package:tencent_cloud_chat_sdk/enum/message_elem_type.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_image.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_image.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_image_elem.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_image_elem.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_message.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_message.dart';
import 'package:tencent_cloud_chat_uikit/ui/constants/history_message_constant.dart';
import 'package:tencent_cloud_chat_uikit/ui/utils/chat_media_gallery_utils.dart';
import 'package:tencent_cloud_chat_uikit/ui/utils/chat_message_preview_image_resolver.dart';

V2TimMessage _imageMessage({
  String msgID = 'msg-1',
  List<V2TimImage?>? imageList,
  String? localPath,
  bool isSelf = false,
}) {
  final message = V2TimMessage.fromJson({
    'msgID': msgID,
    'timestamp': 1,
    'message_is_from_self': isSelf,
    'message_risk_type_identified': 0,
  });
  message.msgID = msgID;
  message.elemType = MessageElemType.V2TIM_ELEM_TYPE_IMAGE;
  message.imageElem = V2TimImageElem(
    path: localPath,
    imageList: imageList,
  );
  return message;
}

void main() {
  group('chatMediaBubbleImageCacheKey', () {
    test('uses msgID when available', () {
      expect(
        chatMediaBubbleImageCacheKey('msg-123'),
        'msg-123:bubble',
      );
    });

    test('uses url when msgID missing', () {
      const url = 'https://example.com/a.jpg';
      expect(
        chatMediaBubbleImageCacheKey(null, urlFallback: url),
        'bubble:$url',
      );
    });

    test('returns unknown when both msgID and url are empty', () {
      expect(chatMediaBubbleImageCacheKey(null), 'bubble:unknown');
      expect(chatMediaBubbleImageCacheKey(''), 'bubble:unknown');
    });

    test('combines msgID and url to isolate image renditions', () {
      expect(
        chatMediaBubbleImageCacheKey(
          'msg-1',
          urlFallback: 'https://example.com/a.jpg',
        ),
        'msg-1:bubble:https://example.com/a.jpg',
      );
    });

    test('same message thumbnail and large image never share cache entries',
        () {
      final thumb = chatMediaBubbleImageCacheKey(
        'msg-1',
        urlFallback: 'https://example.com/thumb.jpg',
      );
      final large = chatMediaBubbleImageCacheKey(
        'msg-1',
        urlFallback: 'https://example.com/large.jpg',
      );

      expect(thumb, isNot(large));
    });

    test('widget key stays stable when url changes', () {
      expect(
        chatBubbleImageWidgetKey(
          kind: 'net',
          msgID: 'msg-1',
          urlOrPathFallback: 'https://a/thumb.jpg',
        ),
        chatBubbleImageWidgetKey(
          kind: 'net',
          msgID: 'msg-1',
          urlOrPathFallback: 'https://b/large.jpg',
        ),
      );
      expect(
        chatBubbleImageWidgetKey(kind: 'net', msgID: 'msg-1'),
        'chat_img_bubble_msg-1',
      );
      expect(
        chatBubbleImageWidgetKey(kind: 'local', msgID: 'msg-1'),
        chatBubbleImageWidgetKey(kind: 'net', msgID: 'msg-1'),
      );
    });

    test('ready token is msg-scoped', () {
      expect(
        chatBubbleImageReadyToken(msgID: 'msg-1'),
        'bubble_ready:msg-1',
      );
      expect(
        chatBubbleImageReadyToken(msgID: null, idFallback: 'client-9'),
        'bubble_ready:id:client-9',
      );
    });
  });

  group('chatMediaPreviewImageCacheKey', () {
    test('uses preview type suffix', () {
      expect(
        chatMediaPreviewImageCacheKey('msg-1', imageType: 0),
        'msg-1:preview:0',
      );
    });

    test('differs from bubble cache key for same msgID', () {
      const msgID = 'msg-1';
      expect(
        chatMediaBubbleImageCacheKey(msgID),
        isNot(chatMediaPreviewImageCacheKey(msgID, imageType: 0)),
      );
    });
  });

  group('ChatMessagePreviewImageResolver.resolvePlaceholder', () {
    test('uses bubble cache key for network thumbnail', () {
      const thumbUrl = 'https://example.com/thumb.jpg';
      const bigUrl = 'https://example.com/big.jpg';
      const origUrl = 'https://example.com/orig.jpg';
      final message = _imageMessage(
        imageList: [
          V2TimImage(
            type: V2TIM_IMAGE_TYPE.V2TIM_IMAGE_TYPE_ORIGIN,
            url: origUrl,
          ),
          V2TimImage(
            type: V2TIM_IMAGE_TYPE.V2TIM_IMAGE_TYPE_THUMB,
            url: thumbUrl,
          ),
          V2TimImage(
            type: V2TIM_IMAGE_TYPE.V2TIM_IMAGE_TYPE_LARGE,
            url: bigUrl,
          ),
        ],
      );

      final placeholder = ChatMessagePreviewImageResolver.resolvePlaceholder(
        message,
      );

      expect(placeholder, isA<CachedNetworkImageProvider>());
      final provider = placeholder! as CachedNetworkImageProvider;
      expect(provider.url, thumbUrl);
      expect(
        provider.cacheKey,
        chatMediaBubbleImageCacheKey('msg-1', urlFallback: thumbUrl),
      );
    });

    test('received message prefers big url for initial preview', () {
      const thumbUrl = 'https://example.com/thumb.jpg';
      const bigUrl = 'https://example.com/big.jpg';
      const origUrl = 'https://example.com/orig.jpg';
      final message = _imageMessage(
        isSelf: false,
        imageList: [
          V2TimImage(
            type: V2TIM_IMAGE_TYPE.V2TIM_IMAGE_TYPE_ORIGIN,
            url: origUrl,
          ),
          V2TimImage(
            type: V2TIM_IMAGE_TYPE.V2TIM_IMAGE_TYPE_THUMB,
            url: thumbUrl,
          ),
          V2TimImage(
            type: V2TIM_IMAGE_TYPE.V2TIM_IMAGE_TYPE_LARGE,
            url: bigUrl,
          ),
        ],
      );

      final primary = ChatMessagePreviewImageResolver.resolve(message);
      final placeholder = ChatMessagePreviewImageResolver.resolvePlaceholder(
        message,
      );

      expect(primary, isA<CachedNetworkImageProvider>());
      expect((primary! as CachedNetworkImageProvider).url, bigUrl);
      expect(
        (primary as CachedNetworkImageProvider).cacheKey,
        chatMediaPreviewImageCacheKey(
          'msg-1',
          imageType: HistoryMessageDartConstant.V2_TIM_IMAGE_TYPES['BIG']!,
        ),
      );
      expect(placeholder, isA<CachedNetworkImageProvider>());
      expect((placeholder! as CachedNetworkImageProvider).url, thumbUrl);
    });

    test('all messages prefer big url for initial preview when both exist', () {
      const bigUrl = 'https://example.com/big.jpg';
      const origUrl = 'https://example.com/orig.jpg';
      final message = _imageMessage(
        isSelf: true,
        imageList: [
          V2TimImage(
            type: V2TIM_IMAGE_TYPE.V2TIM_IMAGE_TYPE_ORIGIN,
            url: origUrl,
          ),
          V2TimImage(
            type: V2TIM_IMAGE_TYPE.V2TIM_IMAGE_TYPE_LARGE,
            url: bigUrl,
          ),
        ],
      );

      final primary = ChatMessagePreviewImageResolver.resolve(message);

      expect(primary, isA<CachedNetworkImageProvider>());
      expect((primary! as CachedNetworkImageProvider).url, bigUrl);
    });

    test('resolveOriginal prefers original url', () {
      const bigUrl = 'https://example.com/big.jpg';
      const origUrl = 'https://example.com/orig.jpg';
      final message = _imageMessage(
        imageList: [
          V2TimImage(
            type: V2TIM_IMAGE_TYPE.V2TIM_IMAGE_TYPE_ORIGIN,
            url: origUrl,
          ),
          V2TimImage(
            type: V2TIM_IMAGE_TYPE.V2TIM_IMAGE_TYPE_LARGE,
            url: bigUrl,
          ),
        ],
      );

      final original = ChatMessagePreviewImageResolver.resolveOriginal(message);

      expect(original, isA<CachedNetworkImageProvider>());
      expect((original! as CachedNetworkImageProvider).url, origUrl);
    });

    test('shouldUpgradeToOriginal when big and original differ', () {
      const bigUrl = 'https://example.com/big.jpg';
      const origUrl = 'https://example.com/orig.jpg';
      final message = _imageMessage(
        imageList: [
          V2TimImage(
            type: V2TIM_IMAGE_TYPE.V2TIM_IMAGE_TYPE_ORIGIN,
            url: origUrl,
          ),
          V2TimImage(
            type: V2TIM_IMAGE_TYPE.V2TIM_IMAGE_TYPE_LARGE,
            url: bigUrl,
          ),
        ],
      );
      final bigProvider = CachedNetworkImageProvider(
        bigUrl,
        cacheKey: chatMediaPreviewImageCacheKey(
          'msg-1',
          imageType: HistoryMessageDartConstant.V2_TIM_IMAGE_TYPES['BIG']!,
        ),
      );

      expect(
        ChatMessagePreviewImageResolver.shouldUpgradeToOriginal(
          message,
          bigProvider,
        ),
        isTrue,
      );
    });

    test('prefers big image url for received when original missing', () {
      const thumbUrl = 'https://example.com/thumb.jpg';
      const bigUrl = 'https://example.com/big.jpg';
      final message = _imageMessage(
        isSelf: false,
        imageList: [
          V2TimImage(
            type: V2TIM_IMAGE_TYPE.V2TIM_IMAGE_TYPE_THUMB,
            url: thumbUrl,
          ),
          V2TimImage(
            type: V2TIM_IMAGE_TYPE.V2TIM_IMAGE_TYPE_LARGE,
            url: bigUrl,
          ),
        ],
      );

      final primary = ChatMessagePreviewImageResolver.resolve(message);
      final placeholder = ChatMessagePreviewImageResolver.resolvePlaceholder(
        message,
      );

      expect(primary, isA<CachedNetworkImageProvider>());
      expect((primary! as CachedNetworkImageProvider).url, bigUrl);
      expect(placeholder, isA<CachedNetworkImageProvider>());
      expect((placeholder! as CachedNetworkImageProvider).url, thumbUrl);
    });

    test('returns non-null when url matches primary but cache keys differ', () {
      const thumbUrl = 'https://example.com/thumb.jpg';
      const bigUrl = 'https://example.com/big.jpg';
      final message = _imageMessage(
        imageList: [
          V2TimImage(
            type: V2TIM_IMAGE_TYPE.V2TIM_IMAGE_TYPE_THUMB,
            url: thumbUrl,
          ),
          V2TimImage(
            type: V2TIM_IMAGE_TYPE.V2TIM_IMAGE_TYPE_LARGE,
            url: bigUrl,
          ),
        ],
      );

      final primary = ChatMessagePreviewImageResolver.resolve(message);
      final placeholder = ChatMessagePreviewImageResolver.resolvePlaceholder(
        message,
      );

      expect(primary, isA<CachedNetworkImageProvider>());
      expect(placeholder, isA<CachedNetworkImageProvider>());
      final primaryProvider = primary! as CachedNetworkImageProvider;
      final placeholderProvider = placeholder! as CachedNetworkImageProvider;
      expect(primaryProvider.url, bigUrl);
      expect(placeholderProvider.url, thumbUrl);
      expect(
        primaryProvider.cacheKey,
        chatMediaPreviewImageCacheKey(
          'msg-1',
          imageType: HistoryMessageDartConstant.V2_TIM_IMAGE_TYPES['BIG']!,
        ),
      );
      expect(
        placeholderProvider.cacheKey,
        chatMediaBubbleImageCacheKey('msg-1', urlFallback: thumbUrl),
      );
    });

    test('self-sent local original is used as first-screen preview', () async {
      final dir =
          await Directory.systemTemp.createTemp('preview_resolver_test');
      addTearDown(() => dir.delete(recursive: true));
      final file = File('${dir.path}/local.jpg');
      await file.writeAsBytes(const [0xFF, 0xD8, 0xFF]);

      final message = _imageMessage(
        localPath: file.path,
        isSelf: true,
        imageList: [
          V2TimImage(
            type: V2TIM_IMAGE_TYPE.V2TIM_IMAGE_TYPE_LARGE,
            url: 'https://example.com/big.jpg',
          ),
        ],
      );

      final primary = ChatMessagePreviewImageResolver.resolve(message);
      final placeholder = ChatMessagePreviewImageResolver.resolvePlaceholder(
        message,
      );

      expect(primary, isA<FileImage>());
      expect((primary! as FileImage).file.path, file.path);
      expect(placeholder, isNull);
      expect(ChatMessagePreviewImageResolver.hasLocalOriginal(message), isTrue);
    });

    test('resolve returns null when only SMALL url exists', () {
      final message = _imageMessage(
        imageList: [
          V2TimImage(
            type: V2TIM_IMAGE_TYPE.V2TIM_IMAGE_TYPE_THUMB,
            url: 'https://example.com/thumb.jpg',
          ),
        ],
      );
      expect(ChatMessagePreviewImageResolver.resolve(message), isNull);
      final placeholder =
          ChatMessagePreviewImageResolver.resolvePlaceholder(message);
      expect(placeholder, isA<CachedNetworkImageProvider>());
      expect(
        (placeholder! as CachedNetworkImageProvider).url,
        'https://example.com/thumb.jpg',
      );
    });

    test('resolveOriginal is null when only BIG url exists', () {
      final message = _imageMessage(
        imageList: [
          V2TimImage(
            type: V2TIM_IMAGE_TYPE.V2TIM_IMAGE_TYPE_LARGE,
            url: 'https://example.com/big.jpg',
          ),
        ],
      );
      expect(ChatMessagePreviewImageResolver.resolveOriginal(message), isNull);
      expect(
        ChatMessagePreviewImageResolver.resolve(message),
        isA<CachedNetworkImageProvider>(),
      );
      expect(
        (ChatMessagePreviewImageResolver.resolve(message)!
                as CachedNetworkImageProvider)
            .url,
        'https://example.com/big.jpg',
      );
    });

    test('shouldUpgrade when BIG current and only BIG url but msgID set', () {
      const bigUrl = 'https://example.com/big.jpg';
      final message = _imageMessage(
        imageList: [
          V2TimImage(
            type: V2TIM_IMAGE_TYPE.V2TIM_IMAGE_TYPE_LARGE,
            url: bigUrl,
          ),
        ],
      );
      final bigProvider = CachedNetworkImageProvider(
        bigUrl,
        cacheKey: chatMediaPreviewImageCacheKey(
          'msg-1',
          imageType: HistoryMessageDartConstant.V2_TIM_IMAGE_TYPES['BIG']!,
        ),
      );
      expect(
        ChatMessagePreviewImageResolver.shouldUpgradeToOriginal(
          message,
          bigProvider,
        ),
        isTrue,
      );
    });

    test('shouldUpgrade false when current is already ORIGIN provider', () {
      const origUrl = 'https://example.com/orig.jpg';
      final message = _imageMessage(
        imageList: [
          V2TimImage(
            type: V2TIM_IMAGE_TYPE.V2TIM_IMAGE_TYPE_ORIGIN,
            url: origUrl,
          ),
          V2TimImage(
            type: V2TIM_IMAGE_TYPE.V2TIM_IMAGE_TYPE_LARGE,
            url: 'https://example.com/big.jpg',
          ),
        ],
      );
      final originProvider = CachedNetworkImageProvider(
        origUrl,
        cacheKey: chatMediaPreviewImageCacheKey(
          'msg-1',
          imageType: HistoryMessageDartConstant.V2_TIM_IMAGE_TYPES['ORIGINAL']!,
        ),
      );
      expect(
        ChatMessagePreviewImageResolver.isOriginTierProvider(
          originProvider,
          message,
        ),
        isTrue,
      );
      expect(
        ChatMessagePreviewImageResolver.shouldUpgradeToOriginal(
          message,
          originProvider,
        ),
        isFalse,
      );
    });
  });

  group('ChatMessagePreviewImageResolver.hasResolvableOriginalUrl', () {
    test('returns true when original url exists', () {
      final message = _imageMessage(
        imageList: [
          V2TimImage(
            type: V2TIM_IMAGE_TYPE.V2TIM_IMAGE_TYPE_ORIGIN,
            url: 'https://example.com/orig.jpg',
          ),
        ],
      );
      expect(
        ChatMessagePreviewImageResolver.hasResolvableOriginalUrl(message),
        isTrue,
      );
    });

    test('returns false when only BIG url exists', () {
      final message = _imageMessage(
        imageList: [
          V2TimImage(
            type: V2TIM_IMAGE_TYPE.V2TIM_IMAGE_TYPE_LARGE,
            url: 'https://example.com/big.jpg',
          ),
        ],
      );
      expect(
        ChatMessagePreviewImageResolver.hasResolvableOriginalUrl(message),
        isFalse,
      );
    });

    test('returns false when only SMALL url exists', () {
      final message = _imageMessage(
        imageList: [
          V2TimImage(
            type: V2TIM_IMAGE_TYPE.V2TIM_IMAGE_TYPE_THUMB,
            url: 'https://example.com/thumb.jpg',
          ),
        ],
      );
      expect(
        ChatMessagePreviewImageResolver.hasResolvableOriginalUrl(message),
        isFalse,
      );
    });

    test('returns false when no http urls', () {
      final message = _imageMessage(imageList: []);
      expect(
        ChatMessagePreviewImageResolver.hasResolvableOriginalUrl(message),
        isFalse,
      );
    });
  });

  group('ChatMessagePreviewImageResolver.hasLocalOriginal', () {
    test('false when only BIG localUrl file exists', () async {
      final dir =
          await Directory.systemTemp.createTemp('preview_local_big_only');
      addTearDown(() => dir.delete(recursive: true));
      final file = File('${dir.path}/big.jpg');
      await file.writeAsBytes(const [0xFF, 0xD8, 0xFF]);

      final message = _imageMessage(
        imageList: [
          V2TimImage(
            type: V2TIM_IMAGE_TYPE.V2TIM_IMAGE_TYPE_LARGE,
            localUrl: file.path,
            url: 'https://example.com/big.jpg',
          ),
        ],
      );
      expect(ChatMessagePreviewImageResolver.hasLocalOriginal(message), isFalse);
      expect(
        ChatMessagePreviewImageResolver.resolveOriginal(message),
        isNull,
      );
    });

    test('true when ORIGIN localUrl file exists', () async {
      final dir =
          await Directory.systemTemp.createTemp('preview_local_origin');
      addTearDown(() => dir.delete(recursive: true));
      final file = File('${dir.path}/orig.jpg');
      await file.writeAsBytes(const [0xFF, 0xD8, 0xFF]);

      final message = _imageMessage(
        imageList: [
          V2TimImage(
            type: V2TIM_IMAGE_TYPE.V2TIM_IMAGE_TYPE_ORIGIN,
            localUrl: file.path,
            url: 'https://example.com/orig.jpg',
          ),
          V2TimImage(
            type: V2TIM_IMAGE_TYPE.V2TIM_IMAGE_TYPE_LARGE,
            url: 'https://example.com/big.jpg',
          ),
        ],
      );
      expect(ChatMessagePreviewImageResolver.hasLocalOriginal(message), isTrue);
      final original = ChatMessagePreviewImageResolver.resolveOriginal(message);
      expect(original, isA<FileImage>());
      expect((original! as FileImage).file.path, file.path);
    });
  });
}
