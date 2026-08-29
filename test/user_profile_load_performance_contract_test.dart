import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('peer profile does not prefetch common groups during initState', () {
    final source = File('lib/src/user_profile.dart').readAsStringSync();
    final start = source.indexOf('void initState()');
    final end = source.indexOf('\n  }', start);

    expect(start, greaterThanOrEqualTo(0));
    final body = source.substring(start, end);
    expect(body, isNot(contains('_loadCommonGroups')));
    expect(body, contains('_loadFriendRelation'));
  });

  test('local profile publishes before waiting for the conversation query', () {
    final source = File(
      'third_party/tencent_cloud_chat_uikit/lib/business_logic/'
      'separate_models/tui_profile_view_model.dart',
    ).readAsStringSync();
    final start = source.indexOf('loadData({required String userID');
    final local = source.indexOf('final localFriend = await', start);
    final publish = source.indexOf('conversation: null', local);
    final conversation =
        source.indexOf('var conversation = await conversationFuture', local);

    expect(start, greaterThanOrEqualTo(0));
    expect(local, greaterThan(start));
    expect(publish, greaterThan(local));
    expect(conversation, greaterThan(publish));
  });
}
