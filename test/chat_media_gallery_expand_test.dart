import 'package:flutter_test/flutter_test.dart';
import 'package:tencent_cloud_chat_sdk/enum/history_msg_get_type_enum.dart';
import 'package:tencent_cloud_chat_sdk/enum/message_elem_type.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_image_elem.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_image_elem.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_message.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_message.dart';
import 'package:tencent_cloud_chat_uikit/ui/utils/chat_media_gallery_expand.dart';
import 'package:tencent_cloud_chat_uikit/ui/widgets/chat_media_preview_item.dart';

V2TimMessage _image({
  required String msgID,
  required int timestamp,
}) {
  final message = V2TimMessage.fromJson({
    'message_server_time': timestamp,
    'message_msg_id': msgID,
    'message_seq': '0',
    'message_risk_type_identified': 0,
    'message_sender_group_member_info': <String, dynamic>{},
  });
  message.elemType = MessageElemType.V2TIM_ELEM_TYPE_IMAGE;
  message.imageElem = V2TimImageElem();
  return message;
}

bool _isImage(V2TimMessage message) {
  return message.elemType == MessageElemType.V2TIM_ELEM_TYPE_IMAGE &&
      message.imageElem != null;
}

void main() {
  test('merge without maxItems keeps all local media oldest to newest', () {
    final seed = [
      _image(msgID: 'n2', timestamp: 500),
      _image(msgID: 'tap', timestamp: 300),
      _image(msgID: 'o1', timestamp: 200),
    ];
    final extra = [
      _image(msgID: 'o2', timestamp: 100),
      _image(msgID: 'n3', timestamp: 600),
    ];
    final merged = mergeChatMediaGalleryMessages(
      seedNewestFirst: seed,
      expanded: extra,
      tappedMessage: seed[1],
      isPreviewable: _isImage,
    );
    expect(merged.map((m) => m.msgID), ['o2', 'o1', 'tap', 'n2', 'n3']);
  });

  test('merge keeps tapped image and caps around it', () {
    final seed = [
      _image(msgID: 'n2', timestamp: 500),
      _image(msgID: 'n1', timestamp: 400),
      _image(msgID: 'tap', timestamp: 300),
      _image(msgID: 'o1', timestamp: 200),
    ];
    final extra = [
      _image(msgID: 'o2', timestamp: 100),
      _image(msgID: 'o3', timestamp: 50),
      _image(msgID: 'n3', timestamp: 600),
    ];
    final merged = mergeChatMediaGalleryMessages(
      seedNewestFirst: seed,
      expanded: extra,
      tappedMessage: seed[2],
      isPreviewable: _isImage,
      maxItems: 4,
    );
    expect(merged.length, 4);
    expect(merged.any((m) => m.msgID == 'tap'), isTrue);
    expect(merged.first.timestamp ?? 0,
        lessThanOrEqualTo(merged.last.timestamp ?? 0));
  });

  test('expand pulls older pages then stops at max pages', () async {
    ChatMediaGalleryExpandCache.clear();
    final seed = [
      _image(msgID: 'tap', timestamp: 300),
      _image(msgID: 'o1', timestamp: 200),
    ];
    var olderCalls = 0;
    final result = await expandChatMediaGalleryMessages(
      seedNewestFirst: seed,
      tappedMessage: seed.first,
      types: {ChatMediaPreviewType.image},
      isPreviewable: _isImage,
      maxPagesPerSide: 2,
      pageSize: 2,
      maxItems: 10,
      loader: ({
        required HistoryMsgGetTypeEnum getType,
        required int count,
        String? lastMsgID,
        V2TimMessage? lastMsg,
        required List<int> messageTypeList,
      }) async {
        if (getType == HistoryMsgGetTypeEnum.V2TIM_GET_LOCAL_OLDER_MSG) {
          olderCalls++;
          if (olderCalls == 1) {
            return ChatMediaGalleryExpandPage(
              messages: [
                _image(msgID: 'o2', timestamp: 150),
                _image(msgID: 'o3', timestamp: 140),
              ],
              isFinished: false,
            );
          }
          return ChatMediaGalleryExpandPage(
            messages: [
              _image(msgID: 'o4', timestamp: 130),
              _image(msgID: 'o5', timestamp: 120),
            ],
            isFinished: false,
          );
        }
        return const ChatMediaGalleryExpandPage(
          messages: [],
          isFinished: true,
        );
      },
    );
    expect(olderCalls, 2);
    expect(result.pageCount, lessThanOrEqualTo(4));
    expect(result.messagesOldestFirst.map((m) => m.msgID),
        containsAll(['o5', 'o1', 'tap']));
  });

  test('shouldExpand is true when either side has more', () {
    expect(
      chatMediaGalleryShouldExpand(
        currentCount: 10,
        hasMoreOlder: true,
        hasMoreNewer: false,
      ),
      isTrue,
    );
    expect(
      chatMediaGalleryShouldExpand(
        currentCount: ChatMediaGalleryExpandPolicy.maxItems,
        hasMoreOlder: true,
        hasMoreNewer: true,
      ),
      isFalse,
    );
    expect(ChatMediaGalleryExpandPolicy.maxItems, 500);
  });

  test('cache miss when tapped photo is outside cached window', () {
    final cached = [
      _image(msgID: 'a', timestamp: 1),
      _image(msgID: 'b', timestamp: 2),
    ];
    final seed = [_image(msgID: 'tap', timestamp: 9)];
    expect(
      resolveCachedChatMediaGallery(
        cachedOldestFirst: cached,
        seedNewestFirst: seed,
        tappedMessage: seed.first,
        isPreviewable: _isImage,
      ),
      isNull,
    );
  });

  test('cache hit merges latest seed around tapped photo', () {
    final cached = [
      _image(msgID: 'o1', timestamp: 100),
      _image(msgID: 'tap', timestamp: 200),
    ];
    final seed = [
      _image(msgID: 'n1', timestamp: 300),
      _image(msgID: 'tap', timestamp: 200),
    ];
    final resolved = resolveCachedChatMediaGallery(
      cachedOldestFirst: cached,
      seedNewestFirst: seed,
      tappedMessage: seed.last,
      isPreviewable: _isImage,
    );
    expect(resolved, isNotNull);
    expect(resolved!.map((m) => m.msgID), containsAll(['o1', 'tap', 'n1']));
  });

  test('expand cache evicts oldest entry after max conversations', () {
    ChatMediaGalleryExpandCache.clear();
    addTearDown(ChatMediaGalleryExpandCache.clear);
    for (var i = 0; i < ChatMediaGalleryExpandPolicy.maxCacheEntries + 1; i++) {
      ChatMediaGalleryExpandCache.put(
        'conv-$i',
        [_image(msgID: 'm$i', timestamp: i)],
      );
    }
    expect(ChatMediaGalleryExpandCache.get('conv-0'), isNull);
    expect(
      ChatMediaGalleryExpandCache.get(
        'conv-${ChatMediaGalleryExpandPolicy.maxCacheEntries}',
      ),
      isNotNull,
    );
  });

  test('append incoming without cap keeps oldest and newest', () {
    final current = [
      _image(msgID: 'o1', timestamp: 100),
      _image(msgID: 'tap', timestamp: 200),
    ];
    final appended = appendIncomingChatMediaGalleryMessage(
      currentOldestFirst: current,
      incoming: _image(msgID: 'n1', timestamp: 300),
      isPreviewable: _isImage,
    );
    expect(appended.map((m) => m.msgID), ['o1', 'tap', 'n1']);
  });

  test('append incoming adds newest and drops oldest at cap', () {
    final current = [
      _image(msgID: 'o1', timestamp: 100),
      _image(msgID: 'tap', timestamp: 200),
    ];
    final incoming = _image(msgID: 'n1', timestamp: 300);
    final appended = appendIncomingChatMediaGalleryMessage(
      currentOldestFirst: current,
      incoming: incoming,
      isPreviewable: _isImage,
      maxItems: 2,
    );
    expect(appended.map((m) => m.msgID), ['tap', 'n1']);
  });

  test('append incoming is no-op for duplicate and non-image', () {
    final current = [
      _image(msgID: 'tap', timestamp: 200),
    ];
    final same = appendIncomingChatMediaGalleryMessage(
      currentOldestFirst: current,
      incoming: current.first,
      isPreviewable: _isImage,
    );
    expect(identical(same, current), isTrue);

    final sameIdDifferentInstance = appendIncomingChatMediaGalleryMessage(
      currentOldestFirst: current,
      incoming: _image(msgID: 'tap', timestamp: 200),
      isPreviewable: _isImage,
    );
    expect(identical(sameIdDifferentInstance, current), isTrue);

    final ignored = appendIncomingChatMediaGalleryMessage(
      currentOldestFirst: current,
      incoming: V2TimMessage.fromJson({
        'message_server_time': 400,
        'message_msg_id': 'text',
        'message_seq': '0',
        'message_risk_type_identified': 0,
        'message_sender_group_member_info': <String, dynamic>{},
      }),
      isPreviewable: _isImage,
    );
    expect(identical(ignored, current), isTrue);
  });

  test('expand only requests local history types', () async {
    final seed = [_image(msgID: 'tap', timestamp: 300)];
    final seen = <HistoryMsgGetTypeEnum>{};
    await expandChatMediaGalleryMessages(
      seedNewestFirst: seed,
      tappedMessage: seed.first,
      types: {ChatMediaPreviewType.image},
      isPreviewable: _isImage,
      maxPagesPerSide: 1,
      pageSize: 1,
      maxItems: 10,
      loader: ({
        required HistoryMsgGetTypeEnum getType,
        required int count,
        String? lastMsgID,
        V2TimMessage? lastMsg,
        required List<int> messageTypeList,
      }) async {
        seen.add(getType);
        return const ChatMediaGalleryExpandPage(
          messages: [],
          isFinished: true,
        );
      },
    );
    expect(
      seen,
      containsAll([
        HistoryMsgGetTypeEnum.V2TIM_GET_LOCAL_OLDER_MSG,
        HistoryMsgGetTypeEnum.V2TIM_GET_LOCAL_NEWER_MSG,
      ]),
    );
    expect(
      seen.contains(HistoryMsgGetTypeEnum.V2TIM_GET_CLOUD_OLDER_MSG),
      isFalse,
    );
    expect(
      seen.contains(HistoryMsgGetTypeEnum.V2TIM_GET_CLOUD_NEWER_MSG),
      isFalse,
    );
  });

  test('expand without maxItems keeps pulling until local finished', () async {
    final seed = [_image(msgID: 'tap', timestamp: 300)];
    var olderCalls = 0;
    final result = await expandChatMediaGalleryMessages(
      seedNewestFirst: seed,
      tappedMessage: seed.first,
      types: {ChatMediaPreviewType.image},
      isPreviewable: _isImage,
      pageSize: 2,
      loader: ({
        required HistoryMsgGetTypeEnum getType,
        required int count,
        String? lastMsgID,
        V2TimMessage? lastMsg,
        required List<int> messageTypeList,
      }) async {
        if (getType != HistoryMsgGetTypeEnum.V2TIM_GET_LOCAL_OLDER_MSG) {
          return const ChatMediaGalleryExpandPage(
            messages: [],
            isFinished: true,
          );
        }
        olderCalls++;
        if (olderCalls < 5) {
          return ChatMediaGalleryExpandPage(
            messages: [
              _image(msgID: 'o$olderCalls-a', timestamp: 200 - olderCalls * 2),
              _image(msgID: 'o$olderCalls-b', timestamp: 199 - olderCalls * 2),
            ],
            isFinished: false,
          );
        }
        return ChatMediaGalleryExpandPage(
          messages: [
            _image(msgID: 'oldest', timestamp: 1),
          ],
          isFinished: true,
        );
      },
    );
    expect(olderCalls, 5);
    expect(result.messagesOldestFirst.first.msgID, 'oldest');
    expect(result.messagesOldestFirst.last.msgID, 'tap');
  });
}
