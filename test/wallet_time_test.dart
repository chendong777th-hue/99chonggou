import 'package:flutter_test/flutter_test.dart';
import 'package:tencent_cloud_chat_demo/src/api/wallet_time.dart';

void main() {
  group('parseWalletApiTimeToLocal', () {
    test('converts UTC ISO string to local time', () {
      final utc = DateTime.utc(2026, 7, 5, 10, 30, 45);
      final parsed = parseWalletApiTimeToLocal('2026-07-05T10:30:45Z');
      expect(parsed, isNotNull);
      expect(parsed!.millisecondsSinceEpoch, utc.millisecondsSinceEpoch);
      expect(parsed.isUtc, isFalse);
    });

    test('converts red packet Instant samples to local time', () {
      final expires = parseWalletApiTimeToLocal('2026-07-04T22:56:33.426Z');
      final created = parseWalletApiTimeToLocal('2026-07-04T06:56:33.427Z');
      expect(expires, isNotNull);
      expect(created, isNotNull);
      expect(
        expires!.millisecondsSinceEpoch,
        DateTime.utc(2026, 7, 4, 22, 56, 33, 426).millisecondsSinceEpoch,
      );
      expect(
        created!.millisecondsSinceEpoch,
        DateTime.utc(2026, 7, 4, 6, 56, 33, 427).millisecondsSinceEpoch,
      );
    });

    test('converts Java Instant nanosecond precision', () {
      final parsed =
          parseWalletApiTimeToLocal('2026-07-04T22:56:33.426123456Z');
      expect(parsed, isNotNull);
      expect(
        parsed!.millisecondsSinceEpoch,
        DateTime.utc(2026, 7, 4, 22, 56, 33, 426).millisecondsSinceEpoch,
      );
    });

    test('treats timezone-less wallet Instant strings as UTC', () {
      final parsed = parseWalletApiTimeToLocal('2026-07-04T22:56:33.426');
      expect(parsed, isNotNull);
      expect(
        parsed!.millisecondsSinceEpoch,
        DateTime.utc(2026, 7, 4, 22, 56, 33, 426).millisecondsSinceEpoch,
      );
    });

    test('converts offset ISO string to local time', () {
      final parsed = parseWalletApiTimeToLocal('2026-07-05T18:30:45+08:00');
      expect(parsed, isNotNull);
      expect(
        parsed!.millisecondsSinceEpoch,
        DateTime.utc(2026, 7, 5, 10, 30, 45).millisecondsSinceEpoch,
      );
    });

    test('parses space-separated datetime without timezone as UTC', () {
      final parsed = parseWalletApiTimeToLocal('2026-07-05 18:30:45');
      expect(parsed, isNotNull);
      expect(
        parsed!.millisecondsSinceEpoch,
        DateTime.utc(2026, 7, 5, 18, 30, 45).millisecondsSinceEpoch,
      );
    });

    test('returns null for empty input', () {
      expect(parseWalletApiTimeToLocal(''), isNull);
      expect(parseWalletApiTimeToLocal('   '), isNull);
    });
  });

  group('parseWalletApiClaimTime', () {
    test('prefers claimedAt over createdAt for claim maps', () {
      final parsed = parseWalletApiClaimTime({
        'createdAt': '2026-07-04T06:56:33.427Z',
        'claimedAt': '2026-07-04T22:56:33.426Z',
      });
      expect(parsed, isNotNull);
      expect(
        parsed!.millisecondsSinceEpoch,
        DateTime.utc(2026, 7, 4, 22, 56, 33, 426).millisecondsSinceEpoch,
      );
    });
  });

  group('formatWalletApiClock', () {
    test('formats local clock from UTC Instant', () {
      expect(
        formatWalletApiClock('2026-07-04T22:56:33.426Z'),
        isNot('--:--:--'),
      );
    });
  });

  group('formatWalletApiClaimListTime', () {
    test('formats UTC Instant to local clock text', () {
      final text = formatWalletApiClaimListTime('2026-07-04T06:56:33.427Z');
      expect(text, isNot('--:--:--'));
      expect(text, contains(':'));
    });
  });
}
