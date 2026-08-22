import 'package:flutter_test/flutter_test.dart';
import 'package:tencent_cloud_chat_sdk/enum/message_elem_type.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_image_elem.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_image_elem.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_message.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_message.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_video_elem.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_video_elem.dart';
import 'package:tencent_cloud_chat_uikit/ui/utils/chat_media_gallery_utils.dart';

const _sameTimestamp = 1700000000;

bool _isPreviewableMedia(V2TimMessage message) {
  return (message.elemType == MessageElemType.V2TIM_ELEM_TYPE_IMAGE &&
          message.imageElem != null) ||
      (message.elemType == MessageElemType.V2TIM_ELEM_TYPE_VIDEO &&
          message.videoElem != null);
}

V2TimMessage _messageShell({
  required int elemType,
  String? msgID,
  String? id,
  int timestamp = 100,
  String? seq,
}) {
  final message = V2TimMessage.fromJson({
    'message_server_time': timestamp,
    'message_msg_id': msgID,
    'message_seq': seq,
    'message_risk_type_identified': 0,
    'message_sender_group_member_info': <String, dynamic>{},
  });
  message.elemType = elemType;
  message.id = id;
  return message;
}

V2TimMessage _imageMessage({
  String? msgID,
  String? id,
  int timestamp = 100,
  String? seq,
}) {
  final message = _messageShell(
    elemType: MessageElemType.V2TIM_ELEM_TYPE_IMAGE,
    msgID: msgID,
    id: id,
    timestamp: timestamp,
    seq: seq,
  );
  message.imageElem = V2TimImageElem();
  return message;
}

V2TimMessage _videoMessage({
  String? msgID,
  String? id,
  int timestamp = 100,
  String? seq,
}) {
  final message = _messageShell(
    elemType: MessageElemType.V2TIM_ELEM_TYPE_VIDEO,
    msgID: msgID,
    id: id,
    timestamp: timestamp,
    seq: seq,
  );
  message.videoElem = V2TimVideoElem();
  return message;
}

List<V2TimMessage> _batchFourImagesSameTimestamp() {
  return [
    _imageMessage(msgID: 'm4', timestamp: _sameTimestamp, seq: '0'),
    _imageMessage(msgID: 'm3', timestamp: _sameTimestamp, seq: '0'),
    _imageMessage(msgID: 'm2', timestamp: _sameTimestamp, seq: '0'),
    _imageMessage(msgID: 'm1', timestamp: _sameTimestamp, seq: '0'),
  ];
}

void main() {
  group('filterChatGalleryOriginRows', () {
    test('removes time divider rows', () {
      final divider = _messageShell(elemType: 11, msgID: 'divider');
      final image = _imageMessage(msgID: 'img1');
      final filtered = filterChatGalleryOriginRows([image, divider]);
      expect(filtered.length, 1);
      expect(filtered.single.msgID, 'img1');
    });
  });

  group('countChatListPreviewableMedia', () {
    test('matches collectChatMediaMessages image count on display list', () {
      final display = [
        _videoMessage(msgID: 'v1', timestamp: 400),
        _imageMessage(msgID: 'i2', timestamp: 300),
        _messageShell(elemType: 11, msgID: 'divider'),
        _imageMessage(msgID: 'i1', timestamp: 200),
      ];
      bool isImage(V2TimMessage message) =>
          message.elemType == MessageElemType.V2TIM_ELEM_TYPE_IMAGE &&
          message.imageElem != null;

      final listCount = countChatListPreviewableMedia(
        displayListNewestFirst: display,
        isPreviewable: isImage,
      );
      final collected = collectChatMediaMessages(
        originList: filterChatGalleryOriginRows(display),
        tappedMessage: display[1],
        isPreviewable: isImage,
      );
      expect(listCount, collected.length);
      expect(listCount, 2);
    });
  });

  group('isSameChatMediaMessage', () {
    test('matches msgID when both present', () {
      final a = _imageMessage(msgID: 'server', id: 'local');
      final b = _imageMessage(msgID: 'server', id: 'other');
      expect(isSameChatMediaMessage(a, b), isTrue);
    });

    test('matches id when msgID missing', () {
      final a = _imageMessage(id: 'local');
      final b = _imageMessage(msgID: 'server', id: 'local');
      expect(isSameChatMediaMessage(a, b), isTrue);
    });
  });

  group('collectChatMediaMessages', () {
    test('T1 sorts batch-sent images oldest to newest by list index', () {
      final originList = _batchFourImagesSameTimestamp();
      final sorted = collectChatMediaMessages(
        originList: originList,
        tappedMessage: originList.last,
        isPreviewable: _isPreviewableMedia,
      );
      expect(sorted.map((m) => m.msgID).toList(),
          ['m1', 'm2', 'm3', 'm4']);
    });

    test('T4 does not duplicate when tapped message only has local id', () {
      final listMessage =
          _imageMessage(msgID: 'server-m1', id: 'local-1', timestamp: 100);
      final tapped = _imageMessage(id: 'local-1', timestamp: 100);
      final originList = [
        _imageMessage(msgID: 'm2', timestamp: 200),
        listMessage,
      ];
      final sorted = collectChatMediaMessages(
        originList: originList,
        tappedMessage: tapped,
        isPreviewable: _isPreviewableMedia,
      );
      expect(sorted.length, 2);
      expect(sorted.first.msgID, 'server-m1');
      expect(
        resolveCanonicalChatMediaMessage(tapped, originList).msgID,
        'server-m1',
      );
    });
  });

  group('findChatMediaGalleryIndex', () {
    test('T2 oldest image is index 0', () {
      final sorted = collectChatMediaMessages(
        originList: _batchFourImagesSameTimestamp(),
        tappedMessage: _imageMessage(msgID: 'm1'),
        isPreviewable: _isPreviewableMedia,
      );
      final index = findChatMediaGalleryIndex(
        sortedMessages: sorted,
        target: _imageMessage(msgID: 'm1'),
        canIncludeInGallery: (_) => true,
      );
      expect(index, 0);
    });

    test('T3 newest image is index 3', () {
      final sorted = collectChatMediaMessages(
        originList: _batchFourImagesSameTimestamp(),
        tappedMessage: _imageMessage(msgID: 'm4'),
        isPreviewable: _isPreviewableMedia,
      );
      final index = findChatMediaGalleryIndex(
        sortedMessages: sorted,
        target: _imageMessage(msgID: 'm4'),
        canIncludeInGallery: (_) => true,
      );
      expect(index, 3);
    });

    test('T5 skips messages that cannot be included in gallery', () {
      final sorted = [
        _imageMessage(msgID: 'a'),
        _imageMessage(msgID: 'b'),
        _imageMessage(msgID: 'c'),
        _imageMessage(msgID: 'd'),
      ];
      final index = findChatMediaGalleryIndex(
        sortedMessages: sorted,
        target: _imageMessage(msgID: 'c'),
        canIncludeInGallery: (message) => message.msgID != 'b',
      );
      expect(index, 1);
    });

    test('T6 mixed image and video keeps correct video index', () {
      final originList = [
        _videoMessage(msgID: 'v1', timestamp: 100),
        _imageMessage(msgID: 'i1', timestamp: 200),
        _imageMessage(msgID: 'i2', timestamp: 300),
      ];
      final sorted = collectChatMediaMessages(
        originList: originList,
        tappedMessage: originList.first,
        isPreviewable: _isPreviewableMedia,
      );
      final index = findChatMediaGalleryIndex(
        sortedMessages: sorted,
        target: _videoMessage(msgID: 'v1'),
        canIncludeInGallery: _isPreviewableMedia,
      );
      expect(index, 0);
      expect(sorted.length, 3);
    });

    test('T7 returns 0 when target is not found', () {
      final sorted = [
        _imageMessage(msgID: 'a'),
        _imageMessage(msgID: 'b'),
      ];
      final index = findChatMediaGalleryIndex(
        sortedMessages: sorted,
        target: _imageMessage(msgID: 'missing'),
        canIncludeInGallery: (_) => true,
      );
      expect(index, 0);
    });
  });

  group('resolveCanonicalChatMediaMessage', () {
    test('prefers list message with server msgID', () {
      final listMessage =
          _imageMessage(msgID: 'server', id: 'local', timestamp: 100);
      final tapped = _imageMessage(id: 'local', timestamp: 100);
      final canonical = resolveCanonicalChatMediaMessage(
        tapped,
        [listMessage],
      );
      expect(canonical.msgID, 'server');
    });
  });

  test('page label is 1 for oldest and count for newest', () {
    expect(
      chatMediaGalleryPageLabel(indexOldestFirst: 0, count: 5),
      '1 / 5',
    );
    expect(
      chatMediaGalleryPageLabel(indexOldestFirst: 4, count: 5),
      '5 / 5',
    );
  });

  test('retainChatMediaGalleryIndex keeps tapped photo after older prepend', () {
    final oldList = [
      _imageMessage(msgID: 'a', timestamp: 100),
      _imageMessage(msgID: 'tap', timestamp: 200),
      _imageMessage(msgID: 'c', timestamp: 300),
    ];
    final newList = [
      _imageMessage(msgID: 'older1', timestamp: 10),
      _imageMessage(msgID: 'older2', timestamp: 20),
      ...oldList,
    ];
    expect(
      retainChatMediaGalleryIndex(
        currentIndex: 1,
        oldOldestFirst: oldList,
        newOldestFirst: newList,
      ),
      3,
    );
  });

  test('retain maps 8th of memory window to 497th after older prepend', () {
    final memoryWindow = [
      for (var i = 0; i < 8; i++)
        _imageMessage(msgID: 'win$i', timestamp: 1000 + i),
    ];
    final expanded = [
      for (var i = 0; i < 489; i++)
        _imageMessage(msgID: 'old$i', timestamp: i),
      ...memoryWindow,
    ];
    expect(expanded.length, 497);
    expect(
      retainChatMediaGalleryIndex(
        currentIndex: 7,
        oldOldestFirst: memoryWindow,
        newOldestFirst: expanded,
      ),
      496,
    );
  });

  test('defer jump when target is beyond attached PageView children', () {
    expect(
      chatMediaGalleryMustDeferPageJump(
        targetIndex: 496,
        attachedChildCount: 8,
      ),
      isTrue,
    );
    expect(
      chatMediaGalleryMustDeferPageJump(
        targetIndex: 7,
        attachedChildCount: 8,
      ),
      isFalse,
    );
    expect(
      chatMediaGalleryMustDeferPageJump(
        targetIndex: 496,
        attachedChildCount: 497,
      ),
      isFalse,
    );
  });

  test('resolveChatMediaGalleryIndexAfterExpand prefers tapped message', () {
    final memoryWindow = [
      for (var i = 0; i < 8; i++)
        _imageMessage(msgID: 'win$i', timestamp: 1000 + i),
    ];
    final expanded = [
      for (var i = 0; i < 489; i++)
        _imageMessage(msgID: 'old$i', timestamp: i),
      ...memoryWindow,
    ];
    final tapped = memoryWindow.last;
    expect(
      resolveChatMediaGalleryIndexAfterExpand(
        currentIndex: 3,
        oldOldestFirst: memoryWindow,
        newOldestFirst: expanded,
        tappedMessage: tapped,
      ),
      496,
    );
  });

  test('resolveChatMediaGalleryIndexAfterExpand uses preferredIndex', () {
    final oldList = [
      _imageMessage(msgID: 'a', timestamp: 100),
      _imageMessage(msgID: 'b', timestamp: 200),
    ];
    final newList = [
      _imageMessage(msgID: 'older', timestamp: 50),
      ...oldList,
    ];
    expect(
      resolveChatMediaGalleryIndexAfterExpand(
        currentIndex: 0,
        oldOldestFirst: oldList,
        newOldestFirst: newList,
        preferredIndex: 2,
      ),
      2,
    );
  });

  test('findChatMediaGalleryMessageIndex returns -1 when missing', () {
    final list = [
      _imageMessage(msgID: 'a'),
      _imageMessage(msgID: 'b'),
    ];
    expect(
      findChatMediaGalleryMessageIndex(
        messagesOldestFirst: list,
        target: _imageMessage(msgID: 'missing'),
      ),
      -1,
    );
  });

  test('replace PageController when gallery item count changes', () {
    expect(
      chatMediaGalleryShouldReplacePageController(
        oldItemCount: 8,
        newItemCount: 497,
      ),
      isTrue,
    );
    expect(
      chatMediaGalleryShouldReplacePageController(
        oldItemCount: 497,
        newItemCount: 497,
      ),
      isFalse,
    );
  });
}
