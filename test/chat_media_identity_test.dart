import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_message.dart';
import 'package:tencent_cloud_chat_uikit/ui/utils/chat_media_send_utils.dart';

void main() {
  test('batch media tokens are unique and monotonic', () {
    final tokens =
        List<String>.generate(200, (_) => nextChatMediaUniqueToken());
    expect(tokens.toSet(), hasLength(tokens.length));
    for (var index = 1; index < tokens.length; index++) {
      expect(
          int.parse(tokens[index]), greaterThan(int.parse(tokens[index - 1])));
    }
  });

  test('outgoing stable id survives image layout metadata updates', () {
    final message = V2TimMessage.fromJson(<String, dynamic>{
      'message_elem_type': 3,
      'message_status': 2,
      'message_custom_str': '',
      'message_risk_type_identified': 0,
      'message_sender_group_member_info': <String, dynamic>{},
      'message_group_at_user_array': <String>[],
    });
    applyOutgoingStableIdToMessage(message, 'optimistic-42');
    applyImageLayoutToMessage(message, const Size(1206, 2622));

    expect(readOutgoingStableId(message), 'optimistic-42');
    expect(readPersistedImageLayoutSize(message), const Size(1206, 2622));
  });
}
