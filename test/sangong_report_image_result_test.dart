import 'package:flutter_test/flutter_test.dart';
import 'package:tencent_cloud_chat_demo/src/models/sangong_admin_models.dart';

void main() {
  group('SangongReportImageResult', () {
    test('parses bet-image preview response', () {
      final result = SangongReportImageResult.fromJson({
        'ok': true,
        'sent': true,
        'type': 'bet_report',
        'mode': 'preview',
        'periodNo': 28,
        'untilMessageId': 165,
        'betCount': 12,
        'grandTotal': 8600,
        'pendingMessageCount': 8,
        'excludedAfterCutoff': 2,
      });
      expect(result.ok, isTrue);
      expect(result.sent, isTrue);
      expect(result.isPreview, isTrue);
      expect(result.periodNo, 28);
      expect(result.untilMessageId, 165);
      expect(result.betCount, 12);
      expect(result.grandTotal, 8600);
      expect(result.pendingMessageCount, 8);
      expect(result.excludedAfterCutoff, 2);
    });

    test('parses settle-image snake_case fields', () {
      final result = SangongReportImageResult.fromJson({
        'ok': true,
        'sent': true,
        'type': 'settle_report',
        'round_id': 99,
      });
      expect(result.roundId, 99);
      expect(result.type, 'settle_report');
      expect(result.isPreview, isFalse);
    });

    test('parses trend-image response', () {
      final result = SangongReportImageResult.fromJson({
        'ok': true,
        'sent': true,
        'rowCount': 8,
        'doorCount': 6,
      });
      expect(result.ok, isTrue);
      expect(result.sent, isTrue);
      expect(result.rowCount, 8);
      expect(result.doorCount, 6);
    });
  });
}
