import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('chat contact card send uses peer/group ids, not history cache key', () {
    final source = File('lib/src/chat.dart').readAsStringSync();
    final start = source.indexOf('Future<void> _pickAndSendContactCard');
    final end = source.indexOf('void _resetWalletCardState', start);
    expect(start, greaterThanOrEqualTo(0));
    expect(end, greaterThan(start));
    final body = source.substring(start, end);
    expect(body.contains('_c2cPeerUserId()'), isTrue);
    expect(body.contains('ChatIdFormat.canonicalGroupStorageId'), isTrue);
    expect(
      body.contains("receiverUserId: convType == ConvType.c2c ? convId"),
      isFalse,
    );
  });

  test('IM sendMessage strips c2c_ prefix like group_', () {
    final source = File(
      'third_party/tencent_cloud_chat_uikit/lib/business_logic/view_models/tui_chat_global_model.dart',
    ).readAsStringSync();
    final start = source.indexOf(
      "if (receiver.toLowerCase().startsWith('c2c_') && receiver.length > 4)",
    );
    expect(start, greaterThanOrEqualTo(0));
    expect(source.contains('receiver = receiver.substring(4);'), isTrue);
    expect(
      source.contains(
        "if (groupID.toLowerCase().startsWith('group_') && groupID.length > 6)",
      ),
      isTrue,
    );
  });
}
