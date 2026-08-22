import 'package:flutter_test/flutter_test.dart';
import 'package:tencent_cloud_chat_demo/src/i18n/app_i18n.dart';
import 'package:tencent_cloud_chat_demo/src/models/sangong_admin_models.dart';
import 'package:tencent_cloud_chat_demo/src/utils/sangong_bet_submit_messages.dart';

void main() {
  group('sangongBetSubmitSuccessToast', () {
    test('formats first cutoff success', () {
      const result = SangongBetSubmitResult(placedCount: 3);
      final text = sangongBetSubmitSuccessToast(AppI18n.current, result);
      expect(text, contains('3'));
      expect(text.toLowerCase(), contains('closed'));
    });

    test('formats re-cutoff success with detail', () {
      const result = SangongBetSubmitResult(
        placedCount: 5,
        isRecutoff: true,
        recutoff: SangongBetSubmitRecutoffInfo(cancelled: 2, requeued: 1),
        recallSummary: SangongBetSubmitRecallSummary(recalled: 1),
      );
      final text = sangongBetSubmitSuccessToast(AppI18n.current, result);
      expect(text.toLowerCase(), contains('re-cutoff'));
      expect(text, contains('2 cancelled'));
      expect(text, contains('1 requeued'));
      expect(text.toLowerCase(), contains('recalled'));
    });
  });
}
