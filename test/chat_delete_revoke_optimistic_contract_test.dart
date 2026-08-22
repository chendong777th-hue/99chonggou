import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  late String model;

  setUpAll(() {
    model = File(
      'third_party/tencent_cloud_chat_uikit/lib/business_logic/'
      'separate_models/tui_chat_separate_view_model.dart',
    ).readAsStringSync();
  });

  test('delete paints locally before SDK commit', () {
    final start = model.indexOf('deleteMsg(String msgID');
    expect(start, greaterThanOrEqualTo(0));
    final commitStart = model.indexOf('Future<void> _commitDeleteToSdk');
    expect(commitStart, greaterThan(start));
    final body = model.substring(start, commitStart);
    expect(body.contains('setMessageList'), isTrue);
    expect(body.contains('_commitDeleteToSdk'), isTrue);
    expect(
      body.indexOf('setMessageList'),
      lessThan(body.indexOf('_commitDeleteToSdk')),
    );
    expect(body.contains('await _messageService.deleteMessages'), isFalse);
  });

  test('self-revoke paints locally and does not modifyMessage first', () {
    final start = model.indexOf('Future<Object?> revokeMsg(');
    expect(start, greaterThanOrEqualTo(0));
    final commitStart = model.indexOf('Future<void> _commitRevokeToSdk');
    expect(commitStart, greaterThan(start));
    final body = model.substring(start, commitStart);
    expect(body.contains('markMessageRevokedNow'), isTrue);
    expect(body.contains('_commitRevokeToSdk'), isTrue);
    expect(
      body.indexOf('markMessageRevokedNow'),
      lessThan(body.indexOf('_commitRevokeToSdk')),
    );
    expect(
      body.contains('if (chatConfig.isGroupAdminRecallEnabled)'),
      isFalse,
    );
  });

  test('admin revoke still uses modifyMessage only when isAdmin', () {
    final start = model.indexOf('Future<void> _commitRevokeToSdk');
    expect(start, greaterThanOrEqualTo(0));
    final body = model.substring(start, start + 1600);
    expect(
      body.contains('isAdmin &&') && body.contains('modifyMessage'),
      isTrue,
    );
    expect(body.contains('revokeMessage'), isTrue);
  });
}
