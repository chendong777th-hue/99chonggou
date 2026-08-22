import 'package:flutter_test/flutter_test.dart';
import 'package:tencent_cloud_chat_demo/src/models/sangong_admin_models.dart';
import 'package:tencent_cloud_chat_demo/src/utils/sangong_quick_setup_banker_input.dart';

void main() {
  group('SangongQuickSetupBankerResult', () {
    test('fromJson parses quick setup response', () {
      final result = SangongQuickSetupBankerResult.fromJson({
        'ok': true,
        'action': 'quick_setup_banker',
        'messageId': 128,
        'sent': true,
        'restarted': false,
        'parsed': {
          'door': 4,
          'limit': 9999,
          'limited': true,
          'text': '4.9999',
        },
        'round': {
          'id': 9,
          'bankerNickname': 'Alice',
          'bankerDoor': 4,
          'bankerLimit': 9999,
          'betWindowOpenAt': '2026-07-01T12:00:00+08:00',
        },
      });

      expect(result.ok, isTrue);
      expect(result.messageId, 128);
      expect(result.sent, isTrue);
      expect(result.parsed.door, 4);
      expect(result.parsed.limit, 9999);
      expect(result.parsed.limited, isTrue);
      expect(result.round?.id, 9);
      expect(result.round?.bankerDoor, 4);
      expect(result.round?.bankerLimit, 9999);
    });
  });

  group('parseSangongBankerSetupText', () {
    test('parses door only', () {
      final parsed = parseSangongBankerSetupText('2');
      expect(parsed.door, 2);
      expect(parsed.hasExplicitLimit, isFalse);
    });

    test('parses door.limit', () {
      final parsed = parseSangongBankerSetupText('2.5000');
      expect(parsed.door, 2);
      expect(parsed.limit, 5000);
      expect(parsed.hasExplicitLimit, isTrue);
    });
  });
}
