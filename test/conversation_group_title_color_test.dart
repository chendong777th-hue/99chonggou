import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tencent_cloud_chat_demo/src/ui/app_tokens.dart';
import 'package:tencent_cloud_chat_demo/src/utils/conversation_group_title_color.dart';
import 'package:tencent_cloud_chat_sdk/enum/group_type.dart';

void main() {
  const fallback = Color(0xFF111827);

  test('Community uses AppTokens.danger', () {
    expect(
      conversationGroupTitleColor(
        fallback: fallback,
        groupType: GroupType.Community,
      ),
      AppTokens.danger,
    );
  });

  test('non-Community and empty keep fallback', () {
    expect(
      conversationGroupTitleColor(fallback: fallback, groupType: GroupType.Work),
      fallback,
    );
    expect(
      conversationGroupTitleColor(
        fallback: fallback,
        groupType: GroupType.Public,
      ),
      fallback,
    );
    expect(
      conversationGroupTitleColor(fallback: fallback, groupType: null),
      fallback,
    );
    expect(
      conversationGroupTitleColor(fallback: fallback, groupType: ''),
      fallback,
    );
    expect(
      conversationGroupTitleColor(fallback: fallback, groupType: '  '),
      fallback,
    );
  });

  test('null fallback falls back to AppTokens.textPrimaryLight when not Community',
      () {
    expect(
      conversationGroupTitleColor(fallback: null, groupType: GroupType.Work),
      AppTokens.textPrimaryLight,
    );
  });
}
