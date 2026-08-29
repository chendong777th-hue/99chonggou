import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final source = File(
    'third_party/tencent_cloud_chat_uikit/lib/ui/views/TIMUIKitChat/'
    'TIMUIKItMessageList/tim_uikit_chat_history_message_list.dart',
  ).readAsStringSync();

  test('every direct Sliver message child retains its stable identity', () {
    final builderStart = source.indexOf('Widget _buildScrollMessageTile(');
    final builderEnd = source.indexOf('\n  _getMessageId(', builderStart);
    expect(builderStart, greaterThanOrEqualTo(0));
    expect(builderEnd, greaterThan(builderStart));

    final builder = source.substring(builderStart, builderEnd);
    expect(
      builder,
      contains(
        'final stableListKey = _stableMessageListKey(messageItem, index);',
      ),
    );
    expect(builder, contains('return KeyedSubtree('));
    expect(
      builder,
      contains('key: ValueKey<String>(stableListKey)'),
    );
    expect(
      builder.indexOf('return KeyedSubtree('),
      greaterThan(builder.indexOf('tile = Opacity(')),
    );
  });

  test('both message Slivers retain findChildIndexCallback', () {
    expect(
      RegExp(r'findChildIndexCallback: \(Key key\)').allMatches(source).length,
      greaterThanOrEqualTo(2),
    );
  });
}
