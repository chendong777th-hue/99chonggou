import 'package:flutter_test/flutter_test.dart';
import 'package:tencent_cloud_chat_demo/utils/custom_message/custom_message_parse_cache.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_message.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_message.dart';

V2TimMessage _message({
  required String messageID,
  String? groupID,
  String? userID,
}) {
  final message = V2TimMessage.fromJson(<String, dynamic>{
    'message_server_time': 1700000000,
    'message_msg_id': messageID,
    'message_is_from_self': false,
    'message_status': 2,
    'message_custom_str': '',
    'message_risk_type_identified': 0,
    'message_sender_group_member_info': <String, dynamic>{},
    'message_group_at_user_array': <String>[],
  });
  message.msgID = messageID;
  message.groupID = groupID;
  message.userID = userID;
  return message;
}

void main() {
  final cache = CustomMessageParseCache.instance;

  setUp(cache.clear);
  tearDown(cache.clear);

  test('same conversation identity payload and version parses once', () {
    final message = _message(messageID: 'm1', groupID: 'g1');
    var parseCount = 0;

    Map<String, dynamic>? parse() => cache.parse<Map<String, dynamic>>(
          message: message,
          payload: '{"value":1}',
          parserVersion: 'test-v1',
          parser: () {
            parseCount++;
            return <String, dynamic>{'value': 1};
          },
        );

    expect(parse(), <String, dynamic>{'value': 1});
    expect(parse(), <String, dynamic>{'value': 1});
    expect(parseCount, 1);
  });

  test('payload version and conversation changes invalidate independently', () {
    final groupOne = _message(messageID: 'same', groupID: 'g1');
    final groupTwo = _message(messageID: 'same', groupID: 'g2');
    var parseCount = 0;

    int? parse(V2TimMessage message, String payload, String version) =>
        cache.parse<int>(
          message: message,
          payload: payload,
          parserVersion: version,
          parser: () => ++parseCount,
        );

    expect(parse(groupOne, 'a', 'v1'), 1);
    expect(parse(groupOne, 'a', 'v1'), 1);
    expect(parse(groupOne, 'b', 'v1'), 2);
    expect(parse(groupOne, 'b', 'v2'), 3);
    expect(parse(groupTwo, 'b', 'v2'), 4);
    expect(parse(groupTwo, 'b', 'v2'), 4);
  });

  test('null parse result is cached and decoded maps are defensive copies', () {
    final message = _message(messageID: 'm2', userID: 'peer');
    var parseCount = 0;
    for (var i = 0; i < 2; i++) {
      expect(
        cache.parse<Object?>(
          message: message,
          payload: 'invalid',
          parserVersion: 'null-v1',
          parser: () {
            parseCount++;
            return null;
          },
        ),
        isNull,
      );
    }
    expect(parseCount, 1);

    final first = cache.decodeMap(
      message: message,
      payload: '{"nested":1}',
      parserVersion: 'map-v1',
    )!;
    first['nested'] = 9;
    final second = cache.decodeMap(
      message: message,
      payload: '{"nested":1}',
      parserVersion: 'map-v1',
    );
    expect(second, <String, dynamic>{'nested': 1});
  });
}
