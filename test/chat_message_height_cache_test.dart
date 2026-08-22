import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_message.dart';
import 'package:tencent_cloud_chat_uikit/ui/utils/chat_message_height_cache.dart';
import 'package:tencent_cloud_chat_uikit/ui/utils/chat_media_send_utils.dart';

V2TimMessage _textMsg({
  required String text,
  String? id,
  String? msgID,
}) {
  final message = V2TimMessage.fromJson(<String, dynamic>{
    'message_elem_type': 1,
    'message_msg_id': msgID,
    'message_client_id': id,
    'message_status': 2,
    'message_custom_str': '',
    'message_risk_type_identified': 0,
    'message_sender_group_member_info': <String, dynamic>{},
    'message_group_at_user_array': <String>[],
    'text_elem_content': text,
  });
  message.id = id;
  message.msgID = msgID;
  return message;
}

V2TimMessage _imageMsg({
  String? id,
  String? msgID,
}) {
  final message = V2TimMessage.fromJson(<String, dynamic>{
    'message_elem_type': 3,
    'message_msg_id': msgID,
    'message_client_id': id,
    'message_status': 2,
    'message_custom_str': '',
    'message_risk_type_identified': 0,
    'message_sender_group_member_info': <String, dynamic>{},
    'message_group_at_user_array': <String>[],
  });
  message.id = id;
  message.msgID = msgID;
  message.elemType = 3;
  return message;
}

void main() {
  late ChatMessageHeightCache cache;

  setUp(() {
    cache = ChatMessageHeightCache.instance;
    cache.clear();
  });

  test('single-line text estimate is near measured short-bubble height', () {
    final message = _textMsg(text: '你好', id: 'temp-1');
    final estimated = cache.estimateRowHeight(message);
    expect(estimated, isNotNull);
    // 日志实测约 55；允许小幅浮动，但绝不能再回到旧的 ~71。
    expect(estimated!, inInclusiveRange(50.0, 62.0));
  });

  test('height survives temp id to server msgID alias', () {
    final sending = _textMsg(text: 'hello', id: 'created_temp_id-1');
    cache.remember(sending, 55);
    expect(cache.heightFor(sending), 55);

    final sent = _textMsg(
      text: 'hello',
      id: 'created_temp_id-1',
      msgID: '144115267812600597-1-1',
    );
    cache.rememberAlias(sending.id, sent.msgID);
    expect(cache.heightFor(sent), 55);
    final byMsgIdOnly = _textMsg(text: 'hello', msgID: sent.msgID);
    expect(cache.heightFor(byMsgIdOnly), 55);
  });

  test('no-meta image row estimate is near measured short row not 159', () {
    final message = _imageMsg(id: 'img-1', msgID: 'img-sdk-1');
    final estimated = cache.estimateRowHeight(message);
    expect(estimated, isNotNull);
    expect(estimated, ChatMessageHeightCache.imageRowFallbackHeight);
    expect(estimated!, lessThan(100));
  });

  test('seedEstimateIfAbsent does not overwrite existing height', () {
    final message = _imageMsg(id: 'img-2', msgID: 'img-sdk-2');
    cache.remember(message, 59);
    final seeded = cache.seedEstimateIfAbsent(message);
    expect(seeded, 59);
    expect(cache.heightFor(message), 59);
  });

  test('image estimate uses persisted layout size before first layout', () {
    final message = _imageMsg(id: 'img-3', msgID: 'img-sdk-3');
    applyImageLayoutToMessage(message, const Size(1206, 2622));
    final estimated = cache.estimateRowHeight(message);
    expect(estimated, isNotNull);
    expect(estimated!, greaterThan(100));
    expect(estimated, lessThan(260));
  });

  test('rememberAliasesBetween migrates measured height across ids', () {
    final sdk = _imageMsg(
      id: 'local-a',
      msgID: '144115268026882536-1785663586-566185649',
    );
    final archive = _imageMsg(
      id: 'local-b',
      msgID: '463257603_566185649_1785663586',
    );
    cache.remember(sdk, 59);
    cache.rememberAliasesBetween(sdk, archive);
    expect(cache.heightFor(archive), 59);
  });

  test('measured content height is keyed by conversation + signature', () {
    cache.rememberMeasuredContentHeight(
      conversationID: 'c2c_k6qxy77crk',
      identitySignature: 'sig-a',
      contentHeight: 416.5,
    );
    expect(
      cache.measuredContentHeightFor(
        conversationID: 'c2c_k6qxy77crk',
        identitySignature: 'sig-a',
      ),
      416.5,
    );
    expect(
      cache.measuredContentHeightFor(
        conversationID: 'c2c_k6qxy77crk',
        identitySignature: 'sig-b',
      ),
      isNull,
    );
  });
}
