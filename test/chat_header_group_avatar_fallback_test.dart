import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('chat header normalizes an unset group avatar to the placeholder path',
      () {
    final header = File(
      'lib/src/widgets/chat_header_title.dart',
    ).readAsStringSync();

    expect(
      header.contains('if (widget.convType == ConvType.group) {'),
      isTrue,
    );
    expect(
      header.contains('return UserAvatarHelper.usableAvatarOrEmpty(official);'),
      isTrue,
    );
  });
}
